# shellcheck shell=bash
#
# Linking, conflict detection, and takeover.
#
# Why this file exists at all: `stow` refuses to link over a real file, and it
# reports that failure in its own vocabulary, after doing part of the work. The
# recurring pain is Atuin, which rewrites ~/.config/atuin/config.toml every time
# a shell starts, so by the time you have deleted the file and rerun the
# installer the file is back. The answer is to decide up front, before touching
# anything, exactly which paths are in the way -- and then either report them
# precisely or move them out of the way in one atomic-feeling step.
#
# The rules, in order of importance:
#
#   * A symlink that already points at the file this package would install is
#     NOT a conflict. It is the successful end state. It is never backed up,
#     never removed, never re-created. This is what makes a second run a no-op.
#   * A symlink pointing anywhere else inside this repository is stow's own
#     bookkeeping (a fold, or a link left by a rename). Stow re-owns those; we
#     leave them alone rather than backing up a symlink.
#   * Anything else that occupies a target path -- a plain file, a directory, a
#     symlink pointing outside the repository -- is a conflict.
#
# We deliberately do NOT use `stow --adopt`. Adopt resolves a conflict by
# pulling the intruding file *into the repository*, overwriting the tracked
# version, and leaving you to notice with `git status`. For the Atuin case that
# is precisely backwards: the machine-generated config would silently replace
# the curated one. Moving the intruder aside into a timestamped backup gets the
# same "these dotfiles win" outcome, is reversible, and can never damage the
# repository.

# Path components GNU Stow ignores by default (stow(8), "Ignore Lists"). We
# mirror them so the scan does not report conflicts for files stow will never
# try to link -- .git in particular, which every Hammerspoon Spoon submodule
# has.
_stow_ignored() {
  local rel=$1 comp rest
  case "$rel" in
    README*|LICENSE*|COPYING) return 0 ;;  # ignored at package top level
  esac
  rest=$rel
  while [ -n "$rest" ]; do
    comp=${rest%%/*}
    if [ "$comp" = "$rest" ]; then rest=''; else rest=${rest#*/}; fi
    case "$comp" in
      .git|.gitignore|.gitmodules|.svn|.hg|CVS|_darcs|RCS) return 0 ;;
      *~|.\#*) return 0 ;;
    esac
  done
  return 1
}

# Apply stow's --dotfiles translation to a package-relative path: a component
# literally named `dot-foo` is installed as `.foo`. This repository does not use
# the convention today, but the installer passes --dotfiles, so the scan has to
# agree with stow about where files land.
_translate_dotfiles() {
  local rel=$1 out='' comp rest
  rest=$rel
  while [ -n "$rest" ]; do
    comp=${rest%%/*}
    if [ "$comp" = "$rest" ]; then rest=''; else rest=${rest#*/}; fi
    case "$comp" in
      dot-*) comp=".${comp#dot-}" ;;
    esac
    if [ -z "$out" ]; then out=$comp; else out="$out/$comp"; fi
  done
  printf '%s\n' "$out"
}

# Classify a symlink found at a target path.
#
#   $1  the symlink
#   $2  the file we intend to install there ('' when checking a parent dir)
#   $3  the package being installed ('' when checking a parent dir)
#
# Exit status:
#   0  already points exactly where we want it              -- done, leave it
#   1  relative link into the same package (or, for a parent
#      directory, anywhere in the repo: a fold stow made)    -- stow re-owns it
#   2  points outside the repository, or at a different
#      package, which stow refuses to overwrite             -- conflict
#   3  unreadable
#   4  absolute link. Stow only recognises the relative links it writes itself
#      ("Ignoring an absolute symlink"), so even an absolute link to exactly
#      the right file makes stow abort. Conflict, verified against stow 2.4.1.
_classify_link() {
  local link=$1 want=$2 owner=$3 raw dest
  raw=$(readlink -- "$link") || return 3
  case "$raw" in
    /*) return 4 ;;
  esac
  dest=$(link_target_abs "$link") || return 3
  dest=$(normalize_path "$dest")
  [ -n "$want" ] && [ "$dest" = "$want" ] && return 0
  if [ -n "$owner" ]; then
    case "$dest" in
      "$DOTFILES_REPO/$owner"/*)
        # A link into this package pointing at something that no longer exists
        # (a renamed or deleted file) is stow's own stale bookkeeping and stow
        # cleans it up. A link to a file that does exist but is not the one
        # being installed here is a conflict: stow 2.4.1 aborts with "existing
        # target is stowed to a different package". Verified, not assumed.
        [ -e "$dest" ] || return 1
        ;;
    esac
    return 2
  fi
  case "$dest" in
    "$DOTFILES_REPO"/*) return 1 ;;
  esac
  return 2
}

# The conflict kind to report for a _classify_link status, given a base name.
_conflict_kind() {
  if [ "$1" = 4 ]; then printf 'absolute-symlink\n'; else printf '%s\n' "$2"; fi
}

# Print every conflict a package would hit, one per line, as
# "<kind><TAB><path relative to the target directory>".
#
# All four shapes the task cares about are covered here: a plain file, a
# directory sitting where a file goes, a symlink pointing elsewhere, and a
# symlink that already points into this repo (which prints nothing).
dotfiles_scan_package() {
  local pkg=$1
  local src rel dst_rel dst dirrel acc comp rest st blocked

  while IFS= read -r src; do
    rel=${src#"$DOTFILES_REPO/$pkg/"}
    [ "$rel" = "$src" ] && continue
    if _stow_ignored "$rel"; then continue; fi
    dst_rel=$(_translate_dotfiles "$rel")

    # Every parent directory has to be a real directory (or a directory stow
    # already folded into the repo). A parent that is a plain file, or a
    # symlink pointing off somewhere else, blocks the whole subtree.
    case "$dst_rel" in
      */*) dirrel=${dst_rel%/*} ;;
      *)   dirrel='' ;;
    esac
    acc=''
    rest=$dirrel
    blocked=0
    while [ -n "$rest" ]; do
      comp=${rest%%/*}
      if [ "$comp" = "$rest" ]; then rest=''; else rest=${rest#*/}; fi
      if [ -z "$acc" ]; then acc=$comp; else acc="$acc/$comp"; fi
      if [ -L "$DOTFILES_TARGET/$acc" ]; then
        st=0; _classify_link "$DOTFILES_TARGET/$acc" '' '' || st=$?
        if [ "$st" = 1 ]; then
          # A directory stow folded into the repository: the whole subtree
          # under here IS repository content reached through the link. Looking
          # any further would report tracked files as if the user had put them
          # in the way -- and a takeover would then move files out of the repo.
          # Stow unfolds these itself; stop here.
          blocked=1
          break
        fi
        if [ "$st" -ge 2 ]; then
          printf '%s\t%s\n' "$(_conflict_kind "$st" symlinked-dir)" "$acc"
          blocked=1
          break
        fi
      elif [ -e "$DOTFILES_TARGET/$acc" ] && [ ! -d "$DOTFILES_TARGET/$acc" ]; then
        printf 'file-in-path\t%s\n' "$acc"
        blocked=1
        break
      fi
    done
    [ "$blocked" = 1 ] && continue

    dst="$DOTFILES_TARGET/$dst_rel"
    if [ -d "$src" ] && [ ! -L "$src" ]; then
      # A directory in the package only needs a directory (or nothing) at the
      # target. Stow creates it; a file or a foreign symlink in its place blocks
      # everything underneath.
      if [ -L "$dst" ]; then
        st=0; _classify_link "$dst" '' '' || st=$?
        if [ "$st" -ge 2 ]; then printf '%s\t%s\n' "$(_conflict_kind "$st" symlinked-dir)" "$dst_rel"; fi
      elif [ -e "$dst" ] && [ ! -d "$dst" ]; then
        printf 'file-in-path\t%s\n' "$dst_rel"
      fi
    elif [ -L "$dst" ]; then
      st=0; _classify_link "$dst" "$src" "$pkg" || st=$?
      if [ "$st" -ge 2 ]; then printf '%s\t%s\n' "$(_conflict_kind "$st" symlink)" "$dst_rel"; fi
    elif [ -d "$dst" ]; then
      printf 'directory\t%s\n' "$dst_rel"
    elif [ -e "$dst" ]; then
      printf 'file\t%s\n' "$dst_rel"
    fi
  done <<EOF
$(find "$DOTFILES_REPO/$pkg" -mindepth 1 \( -name .git -prune -o -print \) | sort)
EOF
}

# Scan a list of packages (one per line on stdin) and print deduplicated
# conflicts, sorted by path.
dotfiles_scan_packages() {
  local pkg
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    dotfiles_scan_package "$pkg"
  done | sort -u -t"$(printf '\t')" -k2,2 -k1,1
}

# Move every conflicting path into a timestamped backup directory, preserving
# the path relative to the target directory, so
# ~/.config/atuin/config.toml becomes
# ~/.dotfiles-backup/20260816T143001/.config/atuin/config.toml
#
# Nothing is ever deleted: this only ever moves. If the move fails the install
# fails with it.
# Sets DOTFILES_MOVED to the number of paths moved (or that would be moved).
dotfiles_takeover() {
  local conflicts=$1 backup=$2 dry=$3
  local kind rel src dstdir real moved=0

  while IFS="$(printf '\t')" read -r kind rel; do
    [ -n "$rel" ] || continue
    src="$DOTFILES_TARGET/$rel"
    # Something earlier in the run may already have moved a parent directory.
    if [ ! -e "$src" ] && [ ! -L "$src" ]; then continue; fi

    # Hard stop: never move anything that physically lives inside the
    # repository. If a path resolves in there, something upstream of here is
    # wrong, and moving tracked files out of a git checkout is not a mistake
    # worth risking.
    real=$(cd -- "$(dirname -- "$src")" 2>/dev/null && pwd -P) || real=''
    case "$real" in
      "$DOTFILES_REPO"|"$DOTFILES_REPO"/*)
        warn "refusing to move $rel: it resolves inside the repository"
        continue
        ;;
    esac
    if [ "$dry" = 1 ]; then
      info "would move $rel ($kind) -> $backup/$rel"
      moved=$((moved + 1))
      continue
    fi
    dstdir=$(dirname -- "$backup/$rel")
    mkdir -p "$dstdir"
    mv -- "$src" "$backup/$rel"
    info "moved $rel ($kind)"
    moved=$((moved + 1))
  done <"$conflicts"

  # shellcheck disable=SC2034  # read by install.sh after this returns
  DOTFILES_MOVED=$moved
}

# Run stow over the given packages. $1 is 1 for a dry run.
dotfiles_stow() {
  local dry=$1
  shift
  local args
  args=(--dir "$DOTFILES_REPO" --target "$DOTFILES_TARGET" --dotfiles --no-folding)
  # Deliberately NOT --restow. Restowing is unstow-then-stow, and stow 2.4.1's
  # unstow pass dies on a directory a previous run folded into the repository
  # ("unstow_contents() called with invalid target: .config") -- which is
  # exactly the state the old installer left machines in. A plain stow with
  # --no-folding unfolds those correctly. The cost is that a symlink left over
  # from a file a package no longer contains is not swept up; `stow -D <pkg>`
  # followed by ./install.sh does that by hand when it matters.
  # --no-folding keeps stow from replacing a whole missing directory with a
  # single symlink into the repository. Folding is how ~/.agents ended up
  # pointing at the checkout, so anything a tool wrote under it landed in the
  # repo as untracked noise; the old installer worked around that with a
  # pre-emptive mkdir. Real directories plus leaf symlinks make the workaround
  # unnecessary and the layout predictable.
  [ "$dry" = 1 ] && args+=(--simulate --verbose)
  stow "${args[@]}" "$@"
}
