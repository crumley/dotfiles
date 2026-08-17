#!/usr/bin/env bash
#
# install.sh -- link this repository's configuration into $HOME.
#
# Design notes, because the old version of this script violated all of them:
#
#   * Idempotent. Running it twice does nothing the second time and never
#     appends a duplicate line to any file.
#   * Cross-platform. Darwin and Linux. Nothing macOS-only runs on Linux, and
#     the installer never installs packages on Linux -- it only configures
#     whatever happens to be there.
#   * No hardcoded paths, no hardcoded package list. Packages are discovered
#     (see lib/packages.sh); $HOME is honoured and overridable.
#   * Refuses rather than damages. If something is in the way it says exactly
#     what, and --takeover moves it to a timestamped backup instead of
#     deleting it.

set -euo pipefail

DOTFILES_REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
export DOTFILES_REPO

# shellcheck source=lib/common.sh
. "$DOTFILES_REPO/lib/common.sh"
# shellcheck source=lib/packages.sh
. "$DOTFILES_REPO/lib/packages.sh"
# shellcheck source=lib/stow.sh
. "$DOTFILES_REPO/lib/stow.sh"

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------

DRY_RUN=0
TAKEOVER=0
STOW_ONLY=0
DO_UPDATE=0
SKIP_BREW=0
BREW_BUNDLE=0
SSH_KEYS=0
LIST_ONLY=0
PRUNE=1
DOTFILES_TARGET=${DOTFILES_TARGET:-$HOME}
DOTFILES_BACKUP_ROOT=${DOTFILES_BACKUP_ROOT:-}

usage() {
  cat <<'EOF'
Usage: ./install.sh [OPTIONS] [PACKAGE...]

Links this repository's configuration into your home directory with GNU Stow.
With no PACKAGE arguments, every package supported on this platform is
installed. Running it a second time changes nothing.

Options:
  -n, --dry-run           Show what would happen; change nothing.
  -f, --force, --takeover Move whatever is in the way into
                          ~/.dotfiles-backup/<timestamp>/ (paths preserved),
                          then link. Nothing is ever deleted.
  -t, --target DIR        Link into DIR instead of $HOME. Also settable as
                          DOTFILES_TARGET. When DIR is not your real home, the
                          machine-level steps below are skipped automatically.
      --stow-only         Only link packages: no Homebrew, no macOS defaults,
                          no agent skills, no submodules.
      --update            git pull, and update submodules to their latest
                          remote commits, before linking.
      --skip-brew         Never install or invoke Homebrew (macOS).
      --brew-bundle       Install everything in the Brewfile (macOS; slow, and
                          off by default -- see below).
      --ssh-authorized-keys
                          Add github.com/crumley.keys to
                          ~/.ssh/authorized_keys, deduplicated. Off by default.
      --no-prune          Keep symlinks that point at files this repository no
                          longer has. They are removed by default; nothing else
                          is ever deleted.
      --list              List the packages this platform would install.
  -q, --quiet             Only print warnings and errors.
  -h, --help              This.

Conflicts:
  A symlink that already points at the right file in this repository is never a
  conflict and is never touched -- that is what makes a second run free.
  Anything else occupying a target path is reported and the install stops
  without changing a thing: a real file, a directory, a symlink pointing
  outside the repository, or one stow will not take over (an absolute one, or
  one left behind by another package).

  Rerun with --takeover to move those aside and link over them. It moves and
  links in a single pass, which is what solves the Atuin case: Atuin recreates
  ~/.config/atuin/config.toml whenever the file is missing when a shell starts,
  so deleting it by hand and then running stow loses a race with your own
  terminals. --takeover never opens that gap.

  The mirror image is handled too: when a file is deleted from this repository
  the symlink it left in your home directory is removed, so a config that moved
  (~/.tmux.conf -> ~/.config/tmux/tmux.conf) does not leave something broken
  behind. Only symlinks pointing at a file this repository no longer has are
  ever removed. --no-prune turns that off.

Homebrew:
  --brew-bundle is opt-in because installing the whole Brewfile takes a long
  time and is rarely what you want on an existing machine. On a fresh Mac, run
  ./install.sh --brew-bundle once.

Environment:
  DOTFILES_TARGET       Where to link (default: $HOME). Same as --target.
  DOTFILES_BACKUP_ROOT  Where --takeover puts things
                        (default: $DOTFILES_TARGET/.dotfiles-backup).
  DOTFILES_PLATFORM     Force "darwin" or "linux" instead of detecting. For
                        testing the other platform's code path.
  DOTFILES_QUIET        1 is the same as --quiet.

Examples:
  ./install.sh --dry-run              # what would change
  ./install.sh                        # link everything, refuse on conflict
  ./install.sh --takeover             # link everything, move intruders aside
  ./install.sh fish git starship      # link just these
  DOTFILES_TARGET=/tmp/fakehome ./install.sh --takeover   # try it safely

Exits non-zero on any failure, including a refused install.
EOF
}

PACKAGES_REQUESTED=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)    usage; exit 0 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -f|--force|--takeover) TAKEOVER=1 ;;
    -t|--target)  [ $# -ge 2 ] || die "--target needs a directory"
                  DOTFILES_TARGET=$2; shift ;;
    --target=*)   DOTFILES_TARGET=${1#*=} ;;
    --stow-only)  STOW_ONLY=1 ;;
    --update)     DO_UPDATE=1 ;;
    --skip-brew)  SKIP_BREW=1 ;;
    --brew-bundle) BREW_BUNDLE=1 ;;
    --ssh-authorized-keys) SSH_KEYS=1 ;;
    --no-prune)   PRUNE=0 ;;
    --list)       LIST_ONLY=1 ;;
    -q|--quiet)   DOTFILES_QUIET=1 ;;
    --)           shift; break ;;
    -*)           die "unknown option: $1 (try --help)" ;;
    *)            PACKAGES_REQUESTED="$PACKAGES_REQUESTED $1" ;;
  esac
  shift
done
while [ $# -gt 0 ]; do
  PACKAGES_REQUESTED="$PACKAGES_REQUESTED $1"
  shift
done

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

[ -d "$DOTFILES_TARGET" ] || die "target directory does not exist: $DOTFILES_TARGET"
DOTFILES_TARGET=$(cd -- "$DOTFILES_TARGET" && pwd -P)
export DOTFILES_TARGET

PLATFORM=$(dotfiles_platform)
[ "$PLATFORM" = unknown ] && warn "unrecognised platform $(uname -s); treating it as Linux-like"

# Anything that touches the machine rather than the target directory is
# suppressed when we are aiming at a throwaway home: testing the installer must
# never mutate the machine it runs on. Comparing resolved paths, so
# --target "$HOME" behaves exactly like no --target at all.
HOME_RESOLVED=$(cd -- "$HOME" 2>/dev/null && pwd -P) || HOME_RESOLVED=$HOME
SYSTEM_STEPS=1
if [ "$STOW_ONLY" = 1 ] || [ "$DOTFILES_TARGET" != "$HOME_RESOLVED" ]; then
  SYSTEM_STEPS=0
fi

have stow || die "GNU Stow is not installed. macOS: brew install stow. Debian/Ubuntu: apt install stow. Fedora: dnf install stow."

# ---------------------------------------------------------------------------
# Which packages
# ---------------------------------------------------------------------------

ALL_SUPPORTED=$(dotfiles_packages_for_platform "$PLATFORM")

if [ -n "$PACKAGES_REQUESTED" ]; then
  PACKAGES=""
  for pkg in $PACKAGES_REQUESTED; do
    if [ ! -d "$DOTFILES_REPO/$pkg" ]; then
      die "no such package: $pkg (run ./install.sh --list)"
    fi
    if ! dotfiles_package_supported "$pkg" "$PLATFORM"; then
      warn "$pkg is not supported on $PLATFORM; skipping"
      continue
    fi
    PACKAGES="$PACKAGES$pkg
"
  done
else
  PACKAGES="$ALL_SUPPORTED
"
fi
PACKAGES=$(printf '%s' "$PACKAGES" | sed '/^$/d')

if [ "$LIST_ONLY" = 1 ]; then
  printf '%s\n' "$PACKAGES"
  exit 0
fi

[ -n "$PACKAGES" ] || die "nothing to install"

PKG_COUNT=$(printf '%s\n' "$PACKAGES" | wc -l | tr -d ' ')

say "dotfiles: $DOTFILES_REPO"
say "target:   $DOTFILES_TARGET  ($PLATFORM)"
[ "$DRY_RUN" = 1 ] && say "dry run:  nothing will be changed"
[ "$SYSTEM_STEPS" = 0 ] && say "mode:     linking only (no Homebrew, macOS defaults, or agent skills)"

# ---------------------------------------------------------------------------
# Repository freshness
# ---------------------------------------------------------------------------

update_repo() {
  have git || { warn "git not found; skipping repository update"; return 0; }
  git -C "$DOTFILES_REPO" rev-parse --git-dir >/dev/null 2>&1 || return 0

  if [ "$DO_UPDATE" = 1 ]; then
    say "Updating repository..."
    if [ "$DRY_RUN" = 1 ]; then
      info "would git pull --ff-only and update submodules"
      return 0
    fi
    git -C "$DOTFILES_REPO" pull --ff-only || warn "git pull failed; continuing with the checkout as it is"
    git -C "$DOTFILES_REPO" submodule sync --recursive >/dev/null
    git -C "$DOTFILES_REPO" submodule update --init --recursive --remote ||
      warn "some submodules did not update (a private one needs SSH access); continuing"
    return 0
  fi

  # Without --update we still make sure submodules are checked out at the
  # commits this repository pins -- Hammerspoon's Spoons are submodules and an
  # empty directory would stow as nothing at all. We do not move them forward.
  [ -f "$DOTFILES_REPO/.gitmodules" ] || return 0
  if [ "$DRY_RUN" = 1 ]; then
    info "would check out any missing submodules"
    return 0
  fi
  git -C "$DOTFILES_REPO" submodule update --init --recursive >/dev/null 2>&1 ||
    warn "some submodules are not checked out (a private one needs SSH access); continuing"
}

[ "$SYSTEM_STEPS" = 1 ] && update_repo

# ---------------------------------------------------------------------------
# macOS: Homebrew and system preferences
# ---------------------------------------------------------------------------

ensure_homebrew() {
  if have brew; then return 0; fi
  say "Installing Homebrew..."
  if [ "$DRY_RUN" = 1 ]; then
    info "would install Homebrew and add its shellenv to ~/.zprofile"
    return 0
  fi
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Find it where this Mac actually put it rather than assuming /opt/homebrew:
  # Apple Silicon and Intel differ, and the old script hardcoded both the path
  # and someone else's home directory.
  local brew_bin=''
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    [ -x "$candidate" ] && { brew_bin=$candidate; break; }
  done
  [ -n "$brew_bin" ] || { warn "Homebrew installed but its brew binary was not found; skipping shell setup"; return 0; }

  if append_line_once "$HOME/.zprofile" "eval \"\$($brew_bin shellenv)\""; then
    info "added brew shellenv to ~/.zprofile"
  fi
  eval "$("$brew_bin" shellenv)"
}

if [ "$SYSTEM_STEPS" = 1 ] && [ "$PLATFORM" = darwin ]; then
  if [ "$SKIP_BREW" = 0 ]; then
    ensure_homebrew
  fi

  if [ "$BREW_BUNDLE" = 1 ]; then
    if have brew; then
      say "Installing from Brewfile..."
      if [ "$DRY_RUN" = 1 ]; then
        info "would run brew bundle --file $DOTFILES_REPO/Brewfile"
      else
        brew bundle --file "$DOTFILES_REPO/Brewfile"
      fi
    else
      warn "--brew-bundle given but brew is not installed; skipping"
    fi
  elif [ "$SKIP_BREW" = 0 ] && have brew && [ "$DRY_RUN" = 0 ]; then
    info "Brewfile not installed (rerun with --brew-bundle for that)"
  fi

  say "Applying macOS preferences..."
  if [ "$DRY_RUN" = 1 ]; then
    info "would run macos/defaults.sh"
  else
    "$DOTFILES_REPO/macos/defaults.sh"
  fi
elif [ "$SYSTEM_STEPS" = 1 ] && [ "$PLATFORM" != darwin ]; then
  # By design: on Linux this repository configures tools, it does not install
  # them. No apt, no dnf, no Homebrew.
  info "Linux: configuring only; no packages are installed"
fi

# ---------------------------------------------------------------------------
# Conflicts
# ---------------------------------------------------------------------------

TMPDIR_RUN=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")
cleanup() { rm -rf "$TMPDIR_RUN"; }
trap cleanup EXIT
CONFLICTS="$TMPDIR_RUN/conflicts"

say "Checking for conflicts..."
printf '%s\n' "$PACKAGES" | dotfiles_scan_packages >"$CONFLICTS"
CONFLICT_COUNT=$(wc -l <"$CONFLICTS" | tr -d ' ')

if [ "$CONFLICT_COUNT" -gt 0 ]; then
  if [ "$TAKEOVER" = 0 ]; then
    err "$CONFLICT_COUNT path(s) are in the way; nothing has been changed."
    printf '\n' >&2
    while IFS="$(printf '\t')" read -r kind rel; do
      printf '  %-14s %s\n' "$kind" "$DOTFILES_TARGET/$rel" >&2
    done <"$CONFLICTS"
    cat >&2 <<EOF

These are real files or directories, or symlinks stow will not take over: ones
pointing outside this repository, ones written as absolute paths, or ones left
behind by a different package. Symlinks that already point at the right file
here are not listed and are never touched.

Rerun with --takeover to move them into a timestamped backup directory under
$DOTFILES_TARGET/.dotfiles-backup and link over them. Nothing is deleted.

    $0 --takeover
EOF
    exit 1
  fi

  BACKUP_ROOT=${DOTFILES_BACKUP_ROOT:-$DOTFILES_TARGET/.dotfiles-backup}
  BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%dT%H%M%S)"
  say "Taking over $CONFLICT_COUNT path(s) -> $BACKUP_DIR"
  DOTFILES_MOVED=0
  if [ "$DRY_RUN" = 0 ]; then
    mkdir -p "$BACKUP_DIR"
  fi
  dotfiles_takeover "$CONFLICTS" "$BACKUP_DIR" "$DRY_RUN"
  if [ "$DRY_RUN" = 1 ]; then
    say "Dry run: $DOTFILES_MOVED path(s) would be moved, then $PKG_COUNT package(s) linked."
    exit 0
  fi
  say "Backed up $DOTFILES_MOVED path(s). Recover anything you need from $BACKUP_DIR"
fi

# ---------------------------------------------------------------------------
# Link
# ---------------------------------------------------------------------------

say "Linking $PKG_COUNT package(s)..."
# shellcheck disable=SC2086  # PACKAGES is a newline-separated list of names
dotfiles_stow "$DRY_RUN" $PACKAGES

# ---------------------------------------------------------------------------
# Prune links to files this repository no longer has
# ---------------------------------------------------------------------------

if [ "$PRUNE" = 1 ]; then
  STALE="$TMPDIR_RUN/stale"
  printf '%s\n' "$PACKAGES" | dotfiles_scan_stale >"$STALE"
  STALE_COUNT=$(wc -l <"$STALE" | tr -d ' ')
  if [ "$STALE_COUNT" -gt 0 ]; then
    say "Removing $STALE_COUNT stale link(s) to files this repo no longer has..."
    dotfiles_prune "$STALE" "$DRY_RUN"
  fi
fi

if [ "$DRY_RUN" = 1 ]; then
  say "Dry run complete; nothing was changed."
  exit 0
fi

# ---------------------------------------------------------------------------
# Optional extras
# ---------------------------------------------------------------------------

# Agent skills: the bodies live untracked in ~/.agents/skills and only the
# lockfile is stowed, so each locked skill has to be reinstalled from source.
# (The skills CLI has no global restore yet: `skills experimental_install` is
# project-scoped.)
restore_agent_skills() {
  local lock="$DOTFILES_TARGET/.agents/.skill-lock.json"
  [ -f "$lock" ] || return 0
  if ! have jq || ! have npx; then
    info "agent skills: skipped (jq or npx missing)"
    return 0
  fi
  say "Restoring agent skills..."
  jq -r '.skills | to_entries[] | "\(.value.source)\t\(.key)"' "$lock" |
    while IFS="$(printf '\t')" read -r src name; do
      # </dev/null: npx must not eat the loop's stdin, or it swallows the
      # remaining lockfile lines and silently skips every skill after the first.
      npx -y skills add "$src" -s "$name" -g -y </dev/null || warn "skill $name failed to install"
    done
}

# github.com/crumley.keys -> ~/.ssh/authorized_keys.
#
# Opt-in, and deduplicated. It used to run on every install and append
# unconditionally, so the file grew a duplicate copy of every key each time.
# It is also arguably server provisioning rather than dotfiles -- a laptop does
# not usually accept inbound ssh -- so it no longer runs unless asked for.
install_authorized_keys() {
  have curl || { warn "curl not found; skipping authorized_keys"; return 0; }
  local ssh_dir="$DOTFILES_TARGET/.ssh"
  local keyfile="$ssh_dir/authorized_keys"
  local tmp="$TMPDIR_RUN/keys" added=0 line

  say "Installing public keys..."
  if ! curl -fsSL https://github.com/crumley.keys -o "$tmp"; then
    warn "could not fetch public keys; skipping"
    return 0
  fi
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if append_line_once "$keyfile" "$line"; then added=$((added + 1)); fi
  done <"$tmp"
  chmod 600 "$keyfile"
  info "$added new key(s) added to ${keyfile#"$DOTFILES_TARGET/"}"
}

# Fish plugins. Bootstrapping used to happen from fish's own startup, curling a
# URL (git.io/fisher) that no longer resolves -- so it ran on every shell start
# and achieved nothing. It belongs here, once, at install time. The function is
# stowed with the fish package; if it is not there yet, this is a no-op.
bootstrap_fisher() {
  have fish || return 0
  printf '%s\n' "$PACKAGES" | grep -qx fish || return 0
  say "Bootstrapping fish plugins..."
  fish -c 'if functions -q my_fisher_bootstrap; my_fisher_bootstrap; end' ||
    warn "fisher bootstrap failed; run 'fish -c my_fisher_bootstrap' by hand"
}

if [ "$SYSTEM_STEPS" = 1 ]; then
  bootstrap_fisher
  restore_agent_skills
fi
if [ "$SSH_KEYS" = 1 ]; then
  install_authorized_keys
fi

say "Done."
