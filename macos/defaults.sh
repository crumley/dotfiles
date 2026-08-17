#!/usr/bin/env bash
#
# macOS system preferences.
#
# Lifted verbatim out of install.sh, where it ran unconditionally and would
# have failed on any Linux machine. The settings themselves are unchanged; the
# only edit is dropping a line that was written twice (com.apple.dock
# launchanim appeared at both the top and the bottom of the block).
#
# `defaults write` is idempotent by nature: writing the same value twice is a
# no-op, so this script is safe to rerun.
#
# Run directly, or let install.sh call it on Darwin.

set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  printf 'macos/defaults.sh: not macOS, nothing to do\n' >&2
  exit 0
fi

if ! command -v defaults >/dev/null 2>&1; then
  printf 'macos/defaults.sh: the defaults command was not found, skipping\n' >&2
  exit 0
fi

# Keyboard: repeat as fast as the OS allows.
defaults write -g InitialKeyRepeat -int 15   # normal minimum is 15 (225 ms)
defaults write -g KeyRepeat -int 1           # normal minimum is 2 (30 ms)

# Dock: no animation, no delay.
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0

# Windows: near-instant resize.
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Menu bar: tighter spacing for status items.
defaults -currentHost write -globalDomain NSStatusItemSpacing -int 12
defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 8
