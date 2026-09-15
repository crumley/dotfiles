#!/usr/bin/env bash
#
# Tests for the switchboard package: the launchd wrapper and the installer step
# that puts its plist where launchd looks.
#
#   ./test/switchboard-test.sh        (or: ./test/run.sh switchboard)
#
# The wrapper's job is to build an environment for `d1 switchboard pull` out of
# almost nothing, and *that* is what is tested here: precedence, the keychain
# read, the lock, argument pass-through, what reaches the log, and the property
# the whole design exists for -- that `op` is never invoked, because every
# tick the 1Password app would ask to approve it.
#
# Every test runs the real wrapper against a throwaway $HOME with stubs on PATH:
# a `d1` that records its argv and environment, a `security` backed by a
# directory of files standing in for the login keychain, and an `op` that leaves
# a marker if it is ever run. Nothing here needs macOS, a keychain, a network,
# or a real `d1`.
#
# What cannot be tested from here, and is listed in the README instead: whether
# launchd actually loads the agent, whether `security` prompts, and whether
# `d1` finds `claude` once it starts.
#
# Exit status is 0 only if every check passed.

set -uo pipefail
unset CDPATH

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
WRAPPER="$REPO/switchboard/bin/switchboard-runner"
PLIST="$REPO/switchboard/.config/switchboard/com.crumley.switchboard-runner.plist"
ENV_EXAMPLE="$REPO/switchboard/.config/switchboard/runner.env.example"

PASS=0
FAIL=0
SKIP=0
HOMES=""

ok() {
    PASS=$((PASS + 1))
    printf '  ok   %s\n' "$1"
}
bad() {
    FAIL=$((FAIL + 1))
    printf '  FAIL %s\n' "$1" >&2
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        printf '::error title=switchboard check::%s\n' "$1"
    fi
}
skipped() {
    SKIP=$((SKIP + 1))
    printf '  SKIP %s\n' "$1"
}
group() { printf '\n%s\n' "$1"; }

assert() {
    local d=$1
    shift
    if "$@"; then ok "$d"; else bad "$d"; fi
}
refute() {
    local d=$1
    shift
    if "$@"; then bad "$d"; else ok "$d"; fi
}
same() {
    if [ "$2" = "$3" ]; then
        ok "$1"
    else
        bad "$1 (expected '$3', got '$2')"
    fi
}
contains() {
    local d=$1 hay=$2 needle=$3
    case "$hay" in
        *"$needle"*) ok "$d" ;;
        *) bad "$d (no '$needle' in: $(printf '%s' "$hay" | tr '\n' '|'))" ;;
    esac
}
lacks() {
    local d=$1 hay=$2 needle=$3
    case "$hay" in
        *"$needle"*) bad "$d (found '$needle')" ;;
        *) ok "$d" ;;
    esac
}

cleanup() {
    local d
    for d in $HOMES; do
        case "$d" in
            "$HOME" | "$HOME"/* | / | '') printf 'refusing to clean %s\n' "$d" >&2 ;;
            *) rm -rf "$d" ;;
        esac
    done
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# A sandbox: a throwaway home with the three stubs on PATH.
# ---------------------------------------------------------------------------

# newbox -> prints the sandbox path. $1/stubs holds d1, security and op; $1/keychain
# is what `security` reads; $1/d1.* configure and record the d1 stub.
newbox() {
    local h
    h=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-switchboard.XXXXXX") || return 1
    HOMES="$HOMES $h"
    mkdir -p "$h/stubs" "$h/keychain" "$h/.config/switchboard"

    cat >"$h/stubs/d1" <<EOF
#!/bin/sh
# Record exactly what the wrapper asked for, and in what environment.
printf '%s\n' "\$@" > "$h/d1.args"
env > "$h/d1.env"
[ -f "$h/d1.stdout" ] && cat "$h/d1.stdout"
[ -f "$h/d1.stderr" ] && cat "$h/d1.stderr" >&2
exit "\$(cat "$h/d1.exit" 2>/dev/null || echo 0)"
EOF

    # Stands in for the login keychain: one file per item name.
    cat >"$h/stubs/security" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$h/security.calls"
name=''
while [ \$# -gt 0 ]; do
  case "\$1" in -s) name=\$2; shift ;; esac
  shift
done
[ -n "\$name" ] || exit 2
[ -f "$h/keychain/\$name" ] || exit 44
cat "$h/keychain/\$name"
EOF

    # The thing that must never run. It leaves a marker and fails, so a wrapper
    # that reached for the vault is caught even if the run would have survived.
    cat >"$h/stubs/op" <<EOF
#!/bin/sh
: > "$h/op.invoked"
exit 1
EOF

    chmod +x "$h/stubs/d1" "$h/stubs/security" "$h/stubs/op"
    printf '{\n  "claimed": 0,\n  "reports": []\n}\n' >"$h/d1.stdout"
    printf '%s\n' "$h"
}

# run_box HOME [args...] -- runs the wrapper. Extra environment for the run goes
# in the RUNNER_ENV array, which is reset afterwards. Sets RUNNER_STATUS and
# RUNNER_OUT.
RUNNER_ENV=()
run_box() {
    local h=$1
    shift
    RUNNER_OUT=$(
        env -u SWITCHBOARD_URL -u SWITCHBOARD_TOKEN_MAC -u WARD_WORKSPACE \
            -u DAYONE_HOME -u SWITCHBOARD_CHECKOUT_FF2K -u HOMEBREW_PREFIX \
            -u SWITCHBOARD_RUNNER_ENV -u SWITCHBOARD_RUNNER_LOG \
            -u SWITCHBOARD_RUNNER_LOG_MAX_BYTES \
            HOME="$h" \
            PATH="$h/stubs:/usr/bin:/bin:/usr/sbin:/sbin" \
            USER="${USER:-dotfiles-test}" \
            SWITCHBOARD_RUNNER_LOCK="$h/lock" \
            ${RUNNER_ENV[@]+"${RUNNER_ENV[@]}"} \
            bash "$WRAPPER" ${@+"$@"} 2>&1
    )
    RUNNER_STATUS=$?
    RUNNER_ENV=()
}

logfile() { printf '%s\n' "$1/Library/Logs/switchboard-runner.log"; }
logtext() { cat "$(logfile "$1")" 2>/dev/null; }
d1env() { grep "^$2=" "$1/d1.env" 2>/dev/null | head -1 | sed "s/^$2=//"; }
ran_d1() { [ -f "$1/d1.args" ]; }

# ---------------------------------------------------------------------------

printf 'switchboard package tests\n'
if [ ! -x "$WRAPPER" ]; then
    bad "switchboard/bin/switchboard-runner is missing or not executable"
    printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
    exit 1
fi

group 'the command it runs'

BOX=$(newbox)
printf 'keychain-token\n' >"$BOX/keychain/SWITCHBOARD_TOKEN_MAC"
printf 'https://keychain.example\n' >"$BOX/keychain/SWITCHBOARD_URL"
run_box "$BOX" --dry-run --once
same 'a clean tick exits 0' "$RUNNER_STATUS" 0
# launchd sends a job's stdout and stderr to /dev/null unless told otherwise,
# and the plist deliberately does not tell it otherwise -- it cannot, because
# launchd will not expand `~` in StandardOutPath. So anything the wrapper has
# to say must reach the log, and nothing may be written where only a terminal
# would have seen it.
same 'and prints nothing when nobody is watching' "$RUNNER_OUT" ''
same 'runs `switchboard pull --runner mac --json` with the arguments appended' \
    "$(tr '\n' ' ' <"$BOX/d1.args")" 'switchboard pull --runner mac --json --dry-run --once '
refute 'the lock is released afterwards (the trap survives, so no exec)' \
    test -e "$BOX/lock"

group 'configuration precedence: the environment, then runner.env, then the keychain'

BOX=$(newbox)
printf 'keychain-token\n' >"$BOX/keychain/SWITCHBOARD_TOKEN_MAC"
printf 'https://keychain.example\n' >"$BOX/keychain/SWITCHBOARD_URL"
cat >"$BOX/.config/switchboard/runner.env" <<'EOF'
SWITCHBOARD_URL="https://file.example"
WARD_WORKSPACE="/srv/ward"
DAYONE_HOME="/srv/dayone"
SWITCHBOARD_CHECKOUT_FF2K="/srv/ff2k"
EOF
run_box "$BOX"
same 'runner.env beats the keychain for SWITCHBOARD_URL' \
    "$(d1env "$BOX" SWITCHBOARD_URL)" 'https://file.example'
same 'WARD_WORKSPACE from runner.env is exported to d1' \
    "$(d1env "$BOX" WARD_WORKSPACE)" '/srv/ward'
same 'DAYONE_HOME from runner.env is exported to d1' \
    "$(d1env "$BOX" DAYONE_HOME)" '/srv/dayone'
same 'SWITCHBOARD_CHECKOUT_FF2K from runner.env is exported to d1' \
    "$(d1env "$BOX" SWITCHBOARD_CHECKOUT_FF2K)" '/srv/ff2k'
lacks 'the keychain is not consulted for a value runner.env already set' \
    "$(cat "$BOX/security.calls" 2>/dev/null)" 'SWITCHBOARD_URL'

RUNNER_ENV=(SWITCHBOARD_URL=https://exported.example)
run_box "$BOX"
same 'an exported value beats runner.env' \
    "$(d1env "$BOX" SWITCHBOARD_URL)" 'https://exported.example'

BOX=$(newbox)
printf 'keychain-token\n' >"$BOX/keychain/SWITCHBOARD_TOKEN_MAC"
printf 'https://keychain.example\n' >"$BOX/keychain/SWITCHBOARD_URL"
run_box "$BOX"
same 'the keychain fills in SWITCHBOARD_URL when nothing else did' \
    "$(d1env "$BOX" SWITCHBOARD_URL)" 'https://keychain.example'
same 'the token comes from the keychain' \
    "$(d1env "$BOX" SWITCHBOARD_TOKEN_MAC)" 'keychain-token'

group 'op is never invoked'

refute 'a successful tick leaves no trace of `op`' test -e "$BOX/op.invoked"
lacks 'the wrapper does not mention op at all' "$(cat "$WRAPPER")" '
op '
lacks 'runner.env.example does not offer to hold the token' \
    "$(grep -v '^#' "$ENV_EXAMPLE" | tr -d ' ')" 'SWITCHBOARD_TOKEN_MAC='

group 'a keychain that cannot answer'

BOX=$(newbox)
printf 'https://keychain.example\n' >"$BOX/keychain/SWITCHBOARD_URL"
run_box "$BOX"
same 'a missing token fails the tick' "$RUNNER_STATUS" 1
refute 'and d1 is never started' ran_d1 "$BOX"
contains 'the log names the missing item' "$(logtext "$BOX")" 'SWITCHBOARD_TOKEN_MAC'
contains 'the log says exactly how to add it' "$(logtext "$BOX")" 'security add-generic-password'

if command -v security >/dev/null 2>&1; then
    skipped 'security(1) exists on this machine, so the "no security(1)" branch cannot be exercised without reaching the real login keychain'
else
    BOX=$(newbox)
    rm -f "$BOX/stubs/security"
    run_box "$BOX"
    same 'a machine without security(1) fails the tick' "$RUNNER_STATUS" 1
    contains 'and says why' "$(logtext "$BOX")" 'security(1) is not on PATH'
fi

group 'the lock'

BOX=$(newbox)
printf 'keychain-token\n' >"$BOX/keychain/SWITCHBOARD_TOKEN_MAC"
printf 'https://keychain.example\n' >"$BOX/keychain/SWITCHBOARD_URL"
mkdir -p "$BOX/lock"
run_box "$BOX"
same 'a tick that finds the lock exits 0' "$RUNNER_STATUS" 0
refute 'and starts nothing' ran_d1 "$BOX"
same 'and says nothing in the log' "$(logtext "$BOX")" ''
assert 'and leaves the lock for its owner' test -d "$BOX/lock"

group 'what reaches the log'

BOX=$(newbox)
printf 'keychain-token\n' >"$BOX/keychain/SWITCHBOARD_TOKEN_MAC"
printf 'https://keychain.example\n' >"$BOX/keychain/SWITCHBOARD_URL"
run_box "$BOX"
same 'a tick with nothing queued logs nothing' "$(logtext "$BOX")" ''

printf '{\n  "claimed": 1,\n  "reports": []\n}\n' >"$BOX/d1.stdout"
run_box "$BOX"
contains 'a claimed run logs one line' "$(logtext "$BOX")" 'claimed 1 run(s)'
lacks 'and the token is never written to the log' "$(logtext "$BOX")" 'keychain-token'

printf '3\n' >"$BOX/d1.exit"
printf 'boom\n' >"$BOX/d1.stderr"
run_box "$BOX"
same "d1's exit status is passed on" "$RUNNER_STATUS" 3
contains 'a failure is logged with its status' "$(logtext "$BOX")" 'exited 3'
contains "and d1's own output is kept" "$(logtext "$BOX")" 'boom'
rm -f "$BOX/d1.exit" "$BOX/d1.stderr"

BOX=$(newbox)
printf 'keychain-token\n' >"$BOX/keychain/SWITCHBOARD_TOKEN_MAC"
printf 'https://keychain.example\n' >"$BOX/keychain/SWITCHBOARD_URL"
printf '{\n  "claimed": 1\n}\n' >"$BOX/d1.stdout"
mkdir -p "$BOX/Library/Logs"
head -c 4096 /dev/zero | tr '\0' 'x' >"$(logfile "$BOX")"
RUNNER_ENV=(SWITCHBOARD_RUNNER_LOG_MAX_BYTES=100)
run_box "$BOX"
assert 'an oversized log is rotated to .log.1' test -f "$(logfile "$BOX").1"
assert 'and the live log starts again small' \
    test "$(wc -c <"$(logfile "$BOX")" | tr -d ' ')" -lt 4096

group 'a machine that is not ready'

BOX=$(newbox)
printf 'keychain-token\n' >"$BOX/keychain/SWITCHBOARD_TOKEN_MAC"
printf 'https://keychain.example\n' >"$BOX/keychain/SWITCHBOARD_URL"
rm -f "$BOX/stubs/d1"
run_box "$BOX"
same 'no d1 on PATH fails the tick' "$RUNNER_STATUS" 1
contains 'and names the command that registers it' "$(logtext "$BOX")" 'mise run link'

group 'the LaunchAgent'

assert 'the plist is tracked outside ~/Library/LaunchAgents' test -f "$PLIST"
lacks 'it hardcodes no home directory' "$(cat "$PLIST")" '/Users/'
lacks 'it hardcodes no /home path either' "$(cat "$PLIST")" '/home/'
contains 'it ticks every five minutes' "$(tr -d ' \n\t' <"$PLIST")" '<key>StartInterval</key><integer>300</integer>'
contains 'it runs at load' "$(tr -d ' \n\t' <"$PLIST")" '<key>RunAtLoad</key><true/>'
contains 'it is a background job' "$(tr -d ' \n\t' <"$PLIST")" '<key>ProcessType</key><string>Background</string>'
lacks 'it sets no KeepAlive (this is one-shot, not a daemon)' \
    "$(tr -d ' \n\t' <"$PLIST")" '<key>KeepAlive</key>'
contains 'it reaches the wrapper through a login shell, which is what fixes PATH' \
    "$(cat "$PLIST")" 'exec "$HOME/bin/switchboard-runner"'

group 'install.sh puts the plist where launchd looks'

if ! command -v stow >/dev/null 2>&1; then
    skipped 'stow is not installed, so the installer step cannot be exercised'
else
    BOX=$(newbox)
    OUT=$(cd "$REPO" && DOTFILES_PLATFORM=darwin ./install.sh --target "$BOX" switchboard 2>&1)
    INSTALL_STATUS=$?
    same 'installing the switchboard package succeeds' "$INSTALL_STATUS" 0
    assert 'the wrapper is linked to ~/bin' test -L "$BOX/bin/switchboard-runner"
    assert 'runner.env.example is linked, so there is something to copy' \
        test -L "$BOX/.config/switchboard/runner.env.example"
    assert 'the plist is a real file in ~/Library/LaunchAgents, not a symlink' \
        test -f "$BOX/Library/LaunchAgents/com.crumley.switchboard-runner.plist"
    refute 'and really not a symlink' \
        test -L "$BOX/Library/LaunchAgents/com.crumley.switchboard-runner.plist"
    assert 'the copy matches the tracked plist byte for byte' \
        cmp -s "$PLIST" "$BOX/Library/LaunchAgents/com.crumley.switchboard-runner.plist"
    contains 'the installer says how to load it' "$OUT" 'launchctl bootstrap'

    # A rerun must be free, and a stale copy must be replaced.
    printf 'stale\n' >"$BOX/Library/LaunchAgents/com.crumley.switchboard-runner.plist"
    OUT=$(cd "$REPO" && DOTFILES_PLATFORM=darwin ./install.sh --target "$BOX" switchboard 2>&1)
    assert 'a stale copy is refreshed' \
        cmp -s "$PLIST" "$BOX/Library/LaunchAgents/com.crumley.switchboard-runner.plist"
    OUT=$(cd "$REPO" && DOTFILES_PLATFORM=darwin ./install.sh --target "$BOX" switchboard 2>&1)
    lacks 'and a second run says nothing about it' "$OUT" 'installed ~/Library/LaunchAgents'

    BOX=$(newbox)
    OUT=$(cd "$REPO" && DOTFILES_PLATFORM=darwin ./install.sh --dry-run --target "$BOX" switchboard 2>&1)
    refute 'a dry run installs no plist' \
        test -e "$BOX/Library/LaunchAgents/com.crumley.switchboard-runner.plist"
    contains 'but says it would' "$OUT" 'would install'

    OUT=$(cd "$REPO" && DOTFILES_PLATFORM=linux ./install.sh --list 2>&1)
    lacks 'the package is not offered on Linux' "$OUT" 'switchboard'
    OUT=$(cd "$REPO" && DOTFILES_PLATFORM=darwin ./install.sh --list 2>&1)
    contains 'and is offered on macOS' "$OUT" 'switchboard'
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
