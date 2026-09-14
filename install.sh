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
VSCODE_EXTENSIONS=0
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
      --vscode-extensions Install the VS Code extensions in Brewfile.vscode.
                          Separate from --brew-bundle on purpose.
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
  ./install.sh --brew-bundle once. The 92 VS Code extensions are a second,
  separate manifest and a second, separate flag: --vscode-extensions.

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
    --vscode-extensions) VSCODE_EXTENSIONS=1 ;;
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

  # `brew bundle` was commented out in the old installer, and that was not
  # laziness: the Brewfile required tap "shopify/private", which no longer
  # resolves, and named a dozen formulae and casks that have since been
  # disabled or removed from the catalog. Any one of those aborts the whole
  # run. The Brewfile has since been curated back to something installable, so
  # this is live again -- with an explicit --file, and still opt-in because
  # installing it takes a long time. If it starts failing, fix the Brewfile;
  # do not comment this out again.
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

  # VS Code extensions live in their own manifest and are deliberately NOT part
  # of --brew-bundle: 92 editor extensions have no business reinstalling
  # themselves during a fresh machine setup.
  if [ "$VSCODE_EXTENSIONS" = 1 ]; then
    if [ ! -f "$DOTFILES_REPO/Brewfile.vscode" ]; then
      warn "no Brewfile.vscode in this checkout; skipping"
    elif ! have brew; then
      warn "--vscode-extensions given but brew is not installed; skipping"
    elif [ "$DRY_RUN" = 1 ]; then
      info "would run brew bundle --file $DOTFILES_REPO/Brewfile.vscode"
    else
      say "Installing VS Code extensions..."
      brew bundle --file "$DOTFILES_REPO/Brewfile.vscode"
    fi
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
# Claude Code settings -- materialize BEFORE the prune pass below
# ---------------------------------------------------------------------------
#
# Claude Code rewrites the whole of ~/.claude/settings.json whenever a setting
# is toggled, and offers no include mechanism -- so unlike ~/.gitconfig there is
# nowhere to aim a stub. This repository therefore tracks only the template,
# claude/.claude/settings.json.example (stowed as ~/.claude/settings.json.example),
# and the live path is a real, machine-owned file. Track the intent, ignore the
# state; the .example suffix is the safety property, exactly as for
# conf.d/00-local.fish -- the live file and the tracked one can never be the
# same path.
#
# WHY THIS SITS HERE, above the prune block and not below it with
# ensure_gitconfig_include / ensure_shell_stub:
#
#   stow  ->  ensure_claude_settings  ->  prune
#
# On a machine installed before this change, ~/.claude/settings.json is a
# symlink into this repository, and whatever that link still reaches is the only
# copy of that machine's settings. Prune's business is exactly that shape of
# path -- a symlink whose destination resolves inside this repo -- so the two
# steps are looking at the same file for opposite reasons.
#
# Being accurate about the danger, because a comment that overstates gets
# disbelieved: as prune is written today the two cannot actually collide. It
# removes only *dangling* links, and a dangling link has no content left to
# rescue, so either order produces the same file. That is a property of prune's
# current rule, not of this step. Moving the call below the prune block does
# leave the suite green today -- checked, not assumed -- and it is still the
# wrong order: the step that reads the machine's only copy has to run before the
# step whose job is deleting links into this repo, so that widening prune later
# (a sweep for links no package installs any more, say) can never turn into lost
# settings. The stubs can live below prune because nothing prunes the paths they
# write; this cannot.
#
# The set this migrates is a superset of the set prune would take -- any symlink
# into the repo, dangling or not -- so once this has run there is nothing at
# this path left for prune to find.
claude_settings_hint() {
  local live=$1 example=$2 rel
  rel=${live#"$DOTFILES_TARGET"/}
  [ -e "$live" ] || return 0
  [ "$example" -nt "$live" ] || return 0
  info "the template ~/$rel.example has moved ahead of ~/$rel"
  info "  diff ~/$rel ~/$rel.example   # merge what you want"
  info "  touch ~/$rel                 # or keep what this machine has"
}

ensure_claude_settings() {
  local live="$DOTFILES_TARGET/.claude/settings.json"
  local example="$live.example"
  local rel=${live#"$DOTFILES_TARGET"/}
  local dir dest src='' what='created from the template'

  # Degrade quietly (invariant 4): no template here means the claude package was
  # never linked into this target, so there is nothing to migrate to.
  [ -e "$example" ] || return 0

  # Hard stop, same rule as dotfiles_takeover: never write inside the
  # repository. If ~/.claude is a directory an old run folded into the checkout,
  # the "live" file is repository content and materializing over it would put
  # machine state straight back into git.
  dir=$(cd -- "$(dirname -- "$live")" 2>/dev/null && pwd -P) || return 0
  case "$dir" in
    "$DOTFILES_REPO"|"$DOTFILES_REPO"/*)
      warn "not migrating ~/$rel: it resolves inside the repository"
      return 0
      ;;
  esac

  if [ -L "$live" ]; then
    if dest=$(link_target_abs "$live"); then dest=$(normalize_path "$dest"); else dest=''; fi
    case "$dest" in
      "$DOTFILES_REPO"/*)
        # A link into this repository, healthy or dangling. Read it *through*
        # the link before touching anything: while the file is still there that
        # content is this machine's settings, and it is the only copy.
        if [ -e "$live" ]; then
          src=$live
          what='migrated from the stow symlink'
        else
          what='replaced a dangling symlink with the template'
        fi
        ;;
      *)
        # Someone else's symlink (a private settings repo, say). Not ours to
        # migrate, and never pruned either.
        return 0
        ;;
    esac
  elif [ -e "$live" ]; then
    # Already a real file: the end state. Never touched -- that is what makes a
    # rerun free and what keeps a toggled setting from being reverted.
    claude_settings_hint "$live" "$example"
    return 0
  fi

  if [ "$DRY_RUN" = 1 ]; then
    info "would ensure ~/$rel is a real file ($what)"
    return 0
  fi

  [ -n "$src" ] || src=$example
  if ! cp -p -- "$src" "$live.dotfiles-tmp"; then
    rm -f -- "$live.dotfiles-tmp"
    warn "could not write ~/$rel; leaving it as it is"
    return 0
  fi
  # mv, not rm-then-copy. A single rename never opens a window in which a
  # running Claude Code could recreate the file underneath us -- the same gap
  # that makes the Atuin case a race rather than a rewrite. cp -p so a mode the
  # machine chose survives the migration.
  mv -- "$live.dotfiles-tmp" "$live"
  info "made ~/$rel a real file ($what)"
  claude_settings_hint "$live" "$example"
}

# Before this change the live name was tracked in the package. A copy can still
# be sitting there on a machine that resolved the modify/delete conflict `git
# pull` raises over a settings.json it had toggled -- untracked and ignored now,
# but still on disk, so stow keeps linking it over the real file. Say so; do not
# delete it. It is inside the repository, and this installer never deletes
# anything in there (see dotfiles_takeover's hard stop for the same rule).
warn_stale_claude_settings_in_repo() {
  local stale="$DOTFILES_REPO/claude/.claude/settings.json"
  [ -e "$stale" ] || return 0
  warn "this checkout still has claude/.claude/settings.json"
  info "It is no longer tracked -- the template is settings.json.example beside"
  info "it, and your live settings are now a real file in your home directory."
  info "Delete the leftover copy from the checkout; while it is there stow keeps"
  info "linking it back over them, and the next run will call that a conflict."
}

if printf '%s\n' "$PACKAGES" | grep -qx claude; then
  ensure_claude_settings
  warn_stale_claude_settings_in_repo
fi

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

# ---------------------------------------------------------------------------
# Clobber-safe stubs
# ---------------------------------------------------------------------------
#
# `git config --global`, and shell installers that append to .bashrc /
# .bash_profile / .profile, rewrite those files in place. If the path were a
# stow symlink into this repo, that rewrite would dirty the tracked checkout.
# So the git, bash, and home packages stow their content under a name nothing
# else targets (.gitconfig.global, .bashrc.tracked, .bash_profile.tracked,
# .profile.tracked), and the steps below ensure the real path exists and
# points at the tracked content -- without ever touching content already
# there.
#
# Claude Code has the same problem and no include mechanism to redirect, so it
# gets the other half of the same idea -- a template and a real file, done
# above in ensure_claude_settings, where it has to run before prune.

# ~/.gitconfig: ensure it exists and starts with an include of
# ~/.gitconfig.global. Prepended, not appended -- git config --global always
# appends, so anything it adds afterward comes later in the file and wins,
# the same "last wins" precedence ~/.gitconfig.local already relies on inside
# the tracked file.
ensure_gitconfig_include() {
  # want is a literal ~/-prefixed string, on purpose: git's own include.path
  # expands a leading ~/ itself (git-config(1)), and writing it out any other
  # way would tie the value to $DOTFILES_TARGET instead of the real $HOME a
  # shell resolves it against later.
  # shellcheck disable=SC2088
  local target="$DOTFILES_TARGET/.gitconfig" want='~/.gitconfig.global' marker
  marker=$(printf '\tpath = %s' "$want")
  if [ -f "$target" ] && grep -qxF "$marker" "$target"; then
    return 0
  fi
  if [ "$DRY_RUN" = 1 ]; then
    info "would add 'include.path = $want' to the top of ~/.gitconfig"
    return 0
  fi
  if [ -f "$target" ]; then
    { printf '[include]\n%s\n\n' "$marker"; cat "$target"; } >"$target.dotfiles-tmp"
    mv "$target.dotfiles-tmp" "$target"
  else
    printf '[include]\n%s\n' "$marker" >"$target"
  fi
  info "added include.path = $want to ~/.gitconfig"
}

# FILE ($1): ensure it exists and sources TRACKED ($2, a bare filename resolved
# against $HOME at shell-startup time). Never touches FILE's existing content:
# append_line_once only ever adds the one line, once, and refuses outright if
# FILE is itself still a stow symlink into the repo (a machine mid-migration
# from before this existed).
ensure_shell_stub() {
  local file=$1 tracked=$2 line
  line="[ -r \"\$HOME/$tracked\" ] && . \"\$HOME/$tracked\""
  if [ "$DRY_RUN" = 1 ]; then
    if [ -f "$file" ] && grep -qxF "$line" "$file"; then
      return 0
    fi
    info "would ensure $file sources \$HOME/$tracked"
    return 0
  fi
  if append_line_once "$file" "$line"; then
    info "$file now sources \$HOME/$tracked"
  fi
}

# ~/Library/LaunchAgents/com.crumley.switchboard-runner.plist: a real copy of
# the tracked plist, not a symlink to it.
#
# Stow would happily link it, and that is exactly the thing not to rely on:
# Apple documents nothing about launchd following a symlink in
# ~/Library/LaunchAgents (launchd.plist(5) and the retired Daemons and Services
# Programming Guide describe the directory and the format and are silent on
# symlinks), and an agent that works until the next reboot and then quietly
# does not is the worst failure available here. So the package stows the plist
# to ~/.config/switchboard/ beside runner.env -- inert there, and out of the
# path of anything that rewrites the live file -- and this copies it across.
#
# The tracked file is the source of truth: it carries no username, no home
# path and no machine state (see the comment inside it), so a live copy that
# differs is stale, not customized, and is replaced. That makes "is this
# machine current?" a byte comparison rather than a judgement call.
#
# Nothing here runs `launchctl`. Loading and unloading a user agent is a
# machine-level act and is the human's, so this prints the command instead.
ensure_switchboard_agent() {
  local rel=.config/switchboard/com.crumley.switchboard-runner.plist
  local src="$DOTFILES_TARGET/$rel"
  local dir="$DOTFILES_TARGET/Library/LaunchAgents"
  local live="$dir/com.crumley.switchboard-runner.plist"
  local real

  if [ ! -e "$src" ]; then
    # A dry run only simulated the stow, so the stowed path is not there yet.
    # Report against the repository's copy, which is what would be linked.
    if [ "$DRY_RUN" = 1 ] && [ -e "$DOTFILES_REPO/switchboard/$rel" ]; then
      src="$DOTFILES_REPO/switchboard/$rel"
    else
      # Degrade quietly (invariant 4): no stowed plist means the switchboard
      # package was never linked into this target.
      return 0
    fi
  fi

  if [ -f "$live" ] && [ ! -L "$live" ] && cmp -s "$src" "$live"; then
    return 0
  fi

  if [ "$DRY_RUN" = 1 ]; then
    info "would install ~/Library/LaunchAgents/com.crumley.switchboard-runner.plist"
    return 0
  fi

  mkdir -p -- "$dir"
  # Same hard stop as dotfiles_takeover: never write inside the repository.
  real=$(cd -- "$dir" 2>/dev/null && pwd -P) || return 0
  case "$real" in
    "$DOTFILES_REPO" | "$DOTFILES_REPO"/*)
      warn "not installing the switchboard LaunchAgent: ~/Library/LaunchAgents resolves inside the repository"
      return 0
      ;;
  esac

  if ! cp -- "$src" "$live.dotfiles-tmp"; then
    rm -f -- "$live.dotfiles-tmp"
    warn "could not write ~/Library/LaunchAgents/com.crumley.switchboard-runner.plist"
    return 0
  fi
  mv -- "$live.dotfiles-tmp" "$live"
  info "installed ~/Library/LaunchAgents/com.crumley.switchboard-runner.plist"
  info "  load it:  launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/com.crumley.switchboard-runner.plist"
  info "  reload:   launchctl bootout gui/\$(id -u)/com.crumley.switchboard-runner  # then bootstrap again"
}

if printf '%s\n' "$PACKAGES" | grep -qx git; then
  ensure_gitconfig_include
fi
if printf '%s\n' "$PACKAGES" | grep -qx switchboard; then
  ensure_switchboard_agent
fi
if printf '%s\n' "$PACKAGES" | grep -qx bash; then
  ensure_shell_stub "$DOTFILES_TARGET/.bashrc" .bashrc.tracked
  ensure_shell_stub "$DOTFILES_TARGET/.bash_profile" .bash_profile.tracked
fi
if printf '%s\n' "$PACKAGES" | grep -qx home; then
  ensure_shell_stub "$DOTFILES_TARGET/.profile" .profile.tracked
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
  local list="$DOTFILES_TARGET/.agents/skills.list"
  [ -f "$list" ] || return 0
  if ! have npx; then
    info "agent skills: skipped (npx missing)"
    return 0
  fi
  say "Restoring agent skills..."
  # Read the tracked source list rather than .skill-lock.json. The lockfile is
  # written by the skills CLI and rewrites skillFolderHash/updatedAt on every
  # skill update, so tracking it meant the repo was permanently dirty -- while
  # the only things read here were the source and the name. jq is no longer
  # needed either, which is one fewer thing that has to be installed first.
  while read -r src name _rest; do
    case "$src" in ''|\#*) continue ;; esac
    [ -n "$name" ] || { warn "skills.list: no name for '$src', skipping"; continue; }
    # </dev/null: npx must not eat the loop's stdin, or it swallows the
    # remaining lines and silently skips every skill after the first.
    npx -y skills add "$src" -s "$name" -g -y </dev/null || warn "skill $name failed to install"
  done <"$list"
}

# The machine's own fish config is deliberately not in the repository, so a
# fresh checkout cannot supply it. Say so once, at the end, rather than letting
# the shell come up silently missing every FISH_* integration -- which is what
# used to happen and looked like the config was broken.
check_local_fish() {
  local conf="$DOTFILES_TARGET/.config/fish/conf.d/00-local.fish"
  local example="$conf.example"
  local rel=${conf#"$DOTFILES_TARGET"/}
  local rel_example=${example#"$DOTFILES_TARGET"/}
  # Nothing to say if the machine already has one, or if the fish package is not
  # installed here (in which case the template was never linked either).
  [ -e "$conf" ] && return 0
  [ -e "$example" ] || return 0
  printf '\n'
  warn "no ~/$rel"
  info "It holds this machine's own fish settings -- the FISH_* flags that turn on"
  info "starship, atuin, mise, direnv and the rest. Without it they all stay off."
  info ""
  info "  cp ~/$rel_example ~/$rel"
  info ""
  info "then uncomment what this machine wants and start a new shell."
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

say "Done."

# Last, so it is the thing still on screen when the run finishes.
check_local_fish
