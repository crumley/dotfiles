# shellcheck shell=bash
#
# Shared helpers for install.sh and upgrade.sh. Sourced, never executed.
#
# Nothing in here is bash-4 only: macOS still ships bash 3.2, and the scripts
# have to run under it.

# --- output ----------------------------------------------------------------
#
# Quiet on success is the goal: say() is for progress, info() for detail under
# a progress line, and warnings/errors always go to stderr regardless of
# DOTFILES_QUIET.

DOTFILES_QUIET=${DOTFILES_QUIET:-0}

say()  { [ "$DOTFILES_QUIET" = 1 ] || printf '%s\n' "$*"; }
info() { [ "$DOTFILES_QUIET" = 1 ] || printf '    %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
err()  { printf 'error: %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# --- platform --------------------------------------------------------------

# Prints "darwin", "linux", or "unknown". Everything platform specific in this
# repository branches on this one value.
#
# DOTFILES_PLATFORM overrides the detection. That exists so the Linux code path
# can be exercised from a Mac (and vice versa) without a VM -- it is a testing
# affordance, not something to set in a shell profile.
dotfiles_platform() {
  if [ -n "${DOTFILES_PLATFORM:-}" ]; then
    printf '%s\n' "$DOTFILES_PLATFORM"
    return 0
  fi
  case "$(uname -s)" in
    Darwin) printf 'darwin\n' ;;
    Linux)  printf 'linux\n' ;;
    *)      printf 'unknown\n' ;;
  esac
}

# --- paths -----------------------------------------------------------------

# Lexically normalize an absolute path: collapse empty, "." and ".." segments.
# Purely textual, so it works on paths that do not exist (a dangling symlink's
# destination, for instance).
normalize_path() {
  local path=$1 out='' comp rest
  rest=$path
  while [ -n "$rest" ]; do
    comp=${rest%%/*}
    if [ "$comp" = "$rest" ]; then rest=''; else rest=${rest#*/}; fi
    case "$comp" in
      ''|.) ;;
      ..)   out=${out%/*} ;;
      *)    out="$out/$comp" ;;
    esac
  done
  printf '%s\n' "${out:-/}"
}

# Absolute destination of a symlink, without requiring `readlink -f` (BSD
# readlink did not have it for most of this repository's life). The
# destination need not exist.
link_target_abs() {
  local link=$1 dest dir
  dest=$(readlink -- "$link") || return 1
  case "$dest" in
    /*) printf '%s\n' "$dest" ;;
    *)  dir=$(cd -- "$(dirname -- "$link")" && pwd -P) || return 1
        printf '%s\n' "$dir/$dest" ;;
  esac
}

# --- idempotent file edits -------------------------------------------------

# Append LINE to FILE only if an identical line is not already there. Returns 0
# when the line was added, non-zero when it was not. This is the whole answer to
# "running it twice must not duplicate a line".
append_line_once() {
  local file=$1 line=$2 dir dest

  # If the file is a symlink into the repository -- because some package stows
  # it -- appending would edit tracked content behind the user's back. Refuse.
  if [ -L "$file" ] && [ -n "${DOTFILES_REPO:-}" ]; then
    dest=$(link_target_abs "$file") && dest=$(normalize_path "$dest")
    case "$dest" in
      "$DOTFILES_REPO"/*)
        warn "not editing $file: it is a symlink into this repository"
        return 2
        ;;
    esac
  fi

  dir=$(dirname -- "$file")
  [ -d "$dir" ] || mkdir -p "$dir"
  [ -f "$file" ] || : >"$file"
  if grep -qxF -- "$line" "$file"; then
    return 1
  fi
  printf '%s\n' "$line" >>"$file"
}
