#!/usr/bin/env bash
#
# Give applications launched by macOS launchd (Dock, Finder, Spotlight, login
# items) the same minimal Homebrew-aware PATH assumption as terminal shells.
# GUI applications do not run ~/.zprofile or `brew shellenv`, so a terminal
# configured with `command = fish` otherwise cannot find Homebrew's fish.
#
# The Homebrew prefix is supplied by `brew --prefix`; this file never assumes
# Apple Silicon's /opt/homebrew or Intel macOS's /usr/local. `launchctl config`
# persists the PATH for future user service domains (a reboot is required), and
# `launchctl setenv` makes it available to applications started later in the
# current login session.
#
# Usage: macos/launchd-path.sh HOMEBREW_PREFIX
# Env:   DOTFILES_DRY_RUN=1 prints the change without making it.

set -euo pipefail

[ $# -eq 1 ] || { printf 'usage: %s HOMEBREW_PREFIX\n' "$0" >&2; exit 2; }
brew_prefix=$1
dry_run=${DOTFILES_DRY_RUN:-0}

launchctl_bin=$(command -v launchctl 2>/dev/null || true)
[ -n "$launchctl_bin" ] || {
  printf 'warning: launchctl not found; GUI application PATH was not configured\n' >&2
  exit 0
}

brew_bin=$brew_prefix/bin
brew_sbin=$brew_prefix/sbin
[ -d "$brew_bin" ] || {
  printf 'warning: Homebrew bin directory not found at %s; GUI application PATH was not configured\n' "$brew_bin" >&2
  exit 0
}

path_has() {
  case ":$1:" in
    *":$2:"*) return 0 ;;
    *) return 1 ;;
  esac
}

path_prepend() {
  if path_has "$1" "$2"; then
    printf '%s\n' "$1"
  elif [ -n "$1" ]; then
    printf '%s:%s\n' "$2" "$1"
  else
    printf '%s\n' "$2"
  fi
}

current=$($launchctl_bin getenv PATH 2>/dev/null || true)
if path_has "$current" "$brew_bin" && { [ ! -d "$brew_sbin" ] || path_has "$current" "$brew_sbin"; }; then
  exit 0
fi

# launchd has a built-in fallback when PATH is unset. Spell it out before
# adding Homebrew so configuring PATH never accidentally removes system tools.
desired=${current:-/usr/bin:/bin:/usr/sbin:/sbin}
[ ! -d "$brew_sbin" ] || desired=$(path_prepend "$desired" "$brew_sbin")
desired=$(path_prepend "$desired" "$brew_bin")

if [ "$dry_run" = 1 ]; then
  printf '    would set the macOS launchd user PATH to %s\n' "$desired"
  exit 0
fi

sudo_bin=$(command -v sudo 2>/dev/null || true)
[ -n "$sudo_bin" ] || {
  printf 'warning: sudo not found; GUI application PATH was not configured\n' >&2
  exit 0
}

printf 'Configuring Homebrew on the PATH for macOS GUI applications...\n'
"$sudo_bin" "$launchctl_bin" config user path "$desired"

# The persistent setting takes effect after reboot. Also update this login
# session so newly launched applications work immediately.
if ! "$launchctl_bin" setenv PATH "$desired"; then
  printf 'warning: persistent launchd PATH was configured, but this login session could not be updated; reboot to apply it\n' >&2
  exit 0
fi
printf '    launchd PATH configured (persistent after the next reboot)\n'
