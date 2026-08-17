# shellcheck shell=bash
#
# ============================================================================
#  THE PACKAGE MAP — this is the only file to edit when packages change.
# ============================================================================
#
# Stow packages are *discovered*, not listed: every non-hidden directory at the
# top level of this repository is a stow package. Adding `zellij/` to the repo
# is enough to get it installed; no script needs to change. (The old installer
# carried a hardcoded list, which is exactly why `starship` sat in the repo for
# years without ever being linked.)
#
# There are only two reasons to touch this file:
#
#   1. A new top-level directory is NOT a stow package (installer machinery,
#      documentation, CI helpers) -> add it to DOTFILES_NOT_PACKAGES.
#   2. A package only makes sense on one platform -> add it to
#      DOTFILES_DARWIN_ONLY or DOTFILES_LINUX_ONLY.
#
# Both lists are plain space-separated strings so they work under bash 3.2,
# which is what macOS ships.

# Top-level directories that belong to the repository itself rather than to
# $HOME. Hidden directories (.git, .github, ...) are skipped automatically and
# do not need to be listed.
DOTFILES_NOT_PACKAGES="lib bin macos scripts script test tests docs"

# Packages that are macOS-only: the applications they configure genuinely do
# not exist on Linux. Everything else stows everywhere.
#
# Removing a package from this list is the whole change needed to install it
# everywhere. Two came off it after their configs were actually checked:
#
#   ghostty  Ghostty's config schema is platform-independent and it
#            parses-and-ignores keys that do not apply to the running platform
#            (verified against 1.3.1, which accepts gtk-titlebar and
#            linux-cgroup on macOS without complaint). One config serves both.
#   espanso  Officially supports Linux as of 2.3.0, and the config is plain
#            text replacements plus the 1Password CLI, which runs on both.
#            Installing it on Linux differs -- X11 and Wayland need different
#            espanso packages and the Wayland build is upstream-flagged
#            experimental -- but that is a packaging matter, and this installer
#            does not install packages on Linux anyway.
DOTFILES_DARWIN_ONLY="hammerspoon karabiner"

# Packages that are Linux-only. None today; kept so the map is symmetric and
# the next person has an obvious place to put one.
DOTFILES_LINUX_ONLY=""

# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

# True when NEEDLE ($1) appears in the space-separated LIST ($2).
_in_list() {
  local needle=$1 list=$2 item
  # shellcheck disable=SC2086  # the list is deliberately word-split
  for item in $list; do
    if [ "$item" = "$needle" ]; then return 0; fi
  done
  return 1
}

# Every stow package in the repository, one per line, regardless of platform.
dotfiles_all_packages() {
  local path name
  for path in "$DOTFILES_REPO"/*/; do
    [ -d "$path" ] || continue
    name=${path%/}
    name=${name##*/}
    case "$name" in .*) continue ;; esac
    _in_list "$name" "$DOTFILES_NOT_PACKAGES" && continue
    printf '%s\n' "$name"
  done
}

# True when PACKAGE ($1) should be installed on PLATFORM ($2).
dotfiles_package_supported() {
  local pkg=$1 platform=$2
  if _in_list "$pkg" "$DOTFILES_DARWIN_ONLY"; then
    [ "$platform" = darwin ] && return 0
    return 1
  fi
  if _in_list "$pkg" "$DOTFILES_LINUX_ONLY"; then
    [ "$platform" = linux ] && return 0
    return 1
  fi
  return 0
}

# The packages to install on PLATFORM ($1), one per line.
dotfiles_packages_for_platform() {
  local platform=$1 pkg
  dotfiles_all_packages | while IFS= read -r pkg; do
    dotfiles_package_supported "$pkg" "$platform" && printf '%s\n' "$pkg"
  done
}
