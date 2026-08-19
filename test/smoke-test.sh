#!/usr/bin/env bash
# test/smoke-test.sh — install into a throwaway home, then actually start the
# shells against it.
#
# This is the check nothing else in the repo makes. test/install-test.sh proves
# the installer links the right files and refuses the right conflicts; it does
# not prove the linked configuration *works*. `fish -n` proves a file parses; it
# does not prove that sourcing it succeeds when atuin, starship, mise and direnv
# are all absent — which is precisely the Linux situation the owner cares about,
# and precisely where a macOS-shaped config falls over.
#
# So: install, then launch each shell as a login/interactive shell with HOME
# pointed at the throwaway target, and require it to exit 0.
#
# The hard assertion is the exit status: a shell that will not start is a broken
# machine. Diagnostics written to stderr by a shell that *did* start are reported
# as information, not failure — a config that says "starship not found, skipping"
# is behaving correctly.
#
# SAFETY: everything happens under a mktemp directory. HOME is overridden only
# for the child shells. The script refuses to run if the target resolves to the
# real $HOME (see assert_safe_target).

set -uo pipefail
# shellcheck source=test/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

REPO_PHYS=$(cd -- "$REPO_ROOT" && pwd -P)

# ---------------------------------------------------------------------------
# Safety
# ---------------------------------------------------------------------------

assert_safe_target() {
    local t="$1" real_t real_home
    if [ -z "$t" ] || [ "$t" = "/" ]; then
        printf 'smoke: refusing to use target %s\n' "${t:-<empty>}" >&2
        exit 1
    fi
    real_t=$(cd -- "$t" 2>/dev/null && pwd -P) || {
        printf 'smoke: target %s does not exist\n' "$t" >&2
        exit 1
    }
    real_home=$(cd -- "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || real_home=/nonexistent

    if [ "$real_t" = "$real_home" ]; then
        printf 'smoke: REFUSING — target resolves to your home directory (%s)\n' "$real_home" >&2
        exit 1
    fi
    case "$real_home" in
        "$real_t"/*)
            printf 'smoke: REFUSING — target %s contains your home directory\n' "$real_t" >&2
            exit 1
            ;;
    esac
    case "$real_t" in
        "$REPO_PHYS" | "$REPO_PHYS"/*)
            printf 'smoke: REFUSING — target %s is inside the repo\n' "$real_t" >&2
            exit 1
            ;;
    esac
}

TARGET=""
cleanup() {
    case "$TARGET" in
        */dotfiles-smoke.*) rm -rf "$TARGET" ;;
    esac
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Install into the throwaway home
# ---------------------------------------------------------------------------

section "smoke test: do the shells start with these configs?"

if ! have stow; then
    skip "GNU stow not installed — nothing could be installed, so no shell was started"
    [ -n "${GITHUB_ACTIONS:-}" ] && fail "stow must be present in CI"
    report_totals
    exit $?
fi

TARGET=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-smoke.XXXXXX") || exit 1
assert_safe_target "$TARGET"

INSTALLER="$REPO_ROOT/install.sh"

# NEVER execute install.sh to find out what it supports.
#
# This is not hypothetical caution. The pre-rewrite install.sh ignored its
# arguments entirely and went straight on to `git pull`, a Homebrew install,
# `defaults write`, `curl ... >> ~/.ssh/authorized_keys` and a stow into the
# real `~`. Probing it with `--list` runs all of that against the machine you
# are sitting at. Ask the file, statically, before running anything.
#
# All three markers must be present. The old installer has none of them.
installer_is_safe_to_run() {
    [ -x "$INSTALLER" ] || return 1
    grep -q -- '--list' "$INSTALLER" || return 1
    grep -q -- '--stow-only' "$INSTALLER" || return 1
    grep -qE -- '--target|DOTFILES_TARGET' "$INSTALLER" || return 1
    return 0
}

if installer_is_safe_to_run; then
    # --stow-only is the belt to the --target braces: it forces the installer's
    # machine-level steps off regardless of how the target resolves, so no
    # Homebrew, no macOS defaults, no agent skills, no submodules.
    INSTALL_MODE="install.sh --target ... --stow-only"
    PKGS=$("$INSTALLER" --list 2>/dev/null | tr '\n' ' ')
    if out=$("$INSTALLER" --target "$TARGET" --stow-only --quiet 2>&1); then
        pass "installed via $INSTALL_MODE"
    else
        fail "install into the throwaway home failed"
        printf '%s\n' "$out" | sed 's/^/         /' >&2
        report_totals
        exit $?
    fi
else
    # Fallback for a tree without the rewritten installer — main before t1's PR
    # lands, and the other in-flight branches, which all fork from main. Drives
    # stow directly, mirroring lib/packages.sh: every non-hidden top-level
    # directory that is not repo machinery.
    #
    # The duplicated knowledge here is deliberate and temporary. Once install.sh
    # carries --list on main, this branch is dead and should be deleted; the
    # installer's package map is the single source of truth.
    INSTALL_MODE="stow (this install.sh has no --list/--stow-only; using the fallback)"
    skip "$INSTALL_MODE — the shipping install path was NOT exercised, only the stow layout underneath it"
    PKGS=""
    for d in "$REPO_ROOT"/*/; do
        name=${d%/}
        name=${name##*/}
        case "$name" in
            .* | test | tests | lib | bin | macos | scripts | script | docs) continue ;;
        esac
        # Mirrors DOTFILES_DARWIN_ONLY in lib/packages.sh. ghostty and espanso
        # are NOT here: both were checked and are cross-platform.
        if [ "$(uname -s)" != "Darwin" ]; then
            case "$name" in hammerspoon | karabiner) continue ;; esac
        fi
        PKGS="$PKGS $name"
    done
    # shellcheck disable=SC2086  # deliberate word-split of the package list
    if out=$(stow --dotfiles -t "$TARGET" -d "$REPO_ROOT" $PKGS 2>&1); then
        pass "installed via stow: $(printf '%s' "$PKGS" | wc -w | tr -d ' ') packages"
    else
        fail "stow into the throwaway home failed"
        printf '%s\n' "$out" | sed 's/^/         /' >&2
        report_totals
        exit $?
    fi
fi
info "packages: $(printf '%s' "$PKGS" | tr -s ' ')"

# ---------------------------------------------------------------------------
# Start the shells
# ---------------------------------------------------------------------------

SHELL_TIMEOUT=${DOTFILES_SMOKE_TIMEOUT:-20}

# Follow an installed path back through its symlink to the repo-relative file it
# came from, so a startup failure can be matched against the known-broken list.
# Prints nothing when the path is not a link into the repo.
repo_path_of() {
    local p="$1" link hops=0
    [ -e "$p" ] || return 0
    while [ -L "$p" ] && [ "$hops" -lt 20 ]; do
        link=$(readlink "$p")
        case "$link" in
            /*) p="$link" ;;
            *) p="$(dirname -- "$p")/$link" ;;
        esac
        hops=$((hops + 1))
    done
    p="$(cd -- "$(dirname -- "$p")" 2>/dev/null && pwd -P)/$(basename -- "$p")"
    case "$p" in
        "$REPO_PHYS"/*) printf '%s\n' "${p#"$REPO_PHYS"/}" ;;
    esac
}

# A shell that never exits is as broken as one that exits nonzero, and it must
# not be allowed to hang CI. `timeout` is GNU-only and is absent from the macOS
# runners; perl's alarm is the portable stand-in and perl is present everywhere
# this runs.
run_with_timeout() {
    local secs="$1"
    shift
    if have timeout; then
        timeout "$secs" "$@"
    elif have gtimeout; then
        gtimeout "$secs" "$@"
    elif have perl; then
        perl -e 'alarm shift @ARGV; exec @ARGV or exit 127' "$secs" "$@"
    else
        "$@"
    fi
}

# try_shell LABEL FILE_THAT_MUST_EXIST CMD...
# Runs CMD with HOME=$TARGET and requires exit 0 within SHELL_TIMEOUT seconds.
try_shell() {
    local label="$1" needs="$2"
    shift 2
    if [ -n "$needs" ] && [ ! -e "$TARGET/$needs" ]; then
        info "$label: no $needs in the target — nothing to exercise"
        return 0
    fi
    if ! have "$1"; then
        skip "$label: $1 is not installed on this machine, so the config was never actually loaded"
        return 0
    fi

    local out rc
    # stdin from /dev/null: an interactive shell must not sit waiting on a
    # terminal, and a config that only behaves when stdin is a tty is a config
    # that breaks scp, cron and CI.
    out=$(run_with_timeout "$SHELL_TIMEOUT" env -i \
        HOME="$TARGET" \
        PATH="$PATH" \
        TERM="${TERM:-dumb}" \
        LANG="${LANG:-C.UTF-8}" \
        "$@" </dev/null 2>&1)
    rc=$?

    # 124 is GNU timeout; 142 is 128+SIGALRM from the perl fallback.
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 142 ]; then
        fail "$label did not exit within ${SHELL_TIMEOUT}s — it hangs on startup (auto-starting tmux, or waiting on a tty?)"
        [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/         /' >&2
        return 1
    fi

    if [ "$rc" -ne 0 ] && known_broken "$(repo_path_of "$TARGET/$needs")"; then
        # The startup file this shell reads is already on the known-broken list,
        # so this is the same defect the syntax check already reported, not a
        # new one. Ubuntu is where it bites hardest: /bin/sh is dash, which
        # refuses to start, where macOS's sh merely warns.
        skip "$label failed to start (exit $rc) — $KNOWN_BROKEN_REASON"
        printf '%s\n' "$out" | sed 's/^/           | /'
        return 0
    fi

    if [ "$rc" -eq 0 ]; then
        pass "$label starts cleanly (exit 0)"
        if [ -n "$out" ]; then
            # Not a failure: degrading with a message when a tool is missing is
            # the correct behaviour on a bare Linux box, and is what goal #1
            # asks for. Shown so it can be read.
            info "$label wrote to stdout/stderr while starting:"
            printf '%s\n' "$out" | sed 's/^/           | /'
        fi
    else
        fail "$label failed to start (exit $rc) — this config does not work on $(uname -s)"
        printf '%s\n' "$out" | sed 's/^/         /' >&2
    fi
}

# fish: the primary shell, and the one most likely to be macOS-shaped.
# -l -c runs the login path, which is what sources config.fish and conf.d/*.
try_shell "fish (login)" ".config/fish/config.fish" fish -l -c 'exit 0'

# fish again, non-login interactive-ish, to catch conf.d ordering problems that
# only bite outside the login path.
try_shell "fish (-c)" ".config/fish/config.fish" fish -c 'exit 0'

# Reproduce Ghostty's command from a GUI launcher's system-only environment.
# On Apple Silicon fish is outside this PATH, so success proves that the login
# profile discovers the package-manager prefix before resolving fish.
if run_with_timeout "$SHELL_TIMEOUT" env -i \
    HOME="$TARGET" USER="${USER:-dotfiles}" LOGNAME="${LOGNAME:-dotfiles}" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM="${TERM:-dumb}" LANG="${LANG:-C.UTF-8}" \
    /bin/sh -l -c 'exec fish -l -c "exit 0"' </dev/null >/dev/null 2>&1
then
    pass "Ghostty login bootstrap resolves fish from a system-only PATH"
else
    fail "Ghostty login bootstrap could not resolve fish from a system-only PATH"
fi

# Ghostty injects its fish vendor config into only the initial shell. A tmux
# pane inherits GHOSTTY_RESOURCES_DIR but not that consumed one-shot injection,
# so config.fish must source the integration itself. Use a tiny fake resource
# tree to prove both the nested-shell path and the duplicate-load guard without
# requiring Ghostty to be installed on the CI runner.
if have fish; then
    ghostty_resources="$TARGET/ghostty-resources"
    ghostty_vendor="$ghostty_resources/shell-integration/fish/vendor_conf.d"
    mkdir -p "$ghostty_vendor"
    cat >"$ghostty_vendor/ghostty-shell-integration.fish" <<'EOF'
set --global DOTFILES_GHOSTTY_LOADS (math "0$DOTFILES_GHOSTTY_LOADS + 1")
function __ghostty_setup
end
EOF

    if run_with_timeout "$SHELL_TIMEOUT" env -i \
        HOME="$TARGET" PATH="$PATH" TERM="${TERM:-dumb}" LANG="${LANG:-C.UTF-8}" \
        GHOSTTY_RESOURCES_DIR="$ghostty_resources" TMUX="$TARGET/tmux,1,0" \
        fish -i -c 'test "$DOTFILES_GHOSTTY_LOADS" = 1' </dev/null >/dev/null 2>&1
    then
        pass "tmux fish manually restores Ghostty shell integration"
    else
        fail "tmux fish did not restore Ghostty shell integration"
    fi

    if run_with_timeout "$SHELL_TIMEOUT" env -i \
        HOME="$TARGET" PATH="$PATH" TERM="${TERM:-dumb}" LANG="${LANG:-C.UTF-8}" \
        GHOSTTY_RESOURCES_DIR="$ghostty_resources" \
        XDG_DATA_DIRS="$ghostty_resources/shell-integration" \
        fish -i -c 'test "$DOTFILES_GHOSTTY_LOADS" = 1' </dev/null >/dev/null 2>&1
    then
        pass "initial fish does not double-load injected Ghostty integration"
    else
        fail "initial fish double-loaded or lost injected Ghostty integration"
    fi
fi

# bash as a login shell reads .bash_profile; as an interactive non-login shell
# it reads .bashrc. Both paths matter and they source different files.
try_shell "bash (login)" ".bash_profile" bash -l -c 'exit 0'
try_shell "bash (interactive rc)" ".bashrc" bash -i -c 'exit 0'

# /bin/sh reads .profile only as a login shell.
try_shell "sh (login)" ".profile" sh -l -c 'exit 0'

# Staleness is reported by syntax.sh, which exercises every file deterministically.
# It is not reported here: whether a given shell reads a given startup file is
# platform-dependent (macOS's /bin/sh tolerates what dash rejects), so an entry
# not firing on one OS says nothing about whether it is stale.
report_totals
