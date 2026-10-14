#!/usr/bin/env bash
# Exercise the real Hammerspoon keybindings against stubs, on either platform.
set -uo pipefail
# shellcheck source=test/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

section "Hammerspoon config"
if have lua; then
    if (cd "$REPO_ROOT" && lua test/hammerspoon-config.lua); then
        pass "Inbox shortcut, removed yabai bindings, retained grid and mic mute"
    else
        fail "Hammerspoon config"
    fi
else
    skip "lua not installed — Hammerspoon config behavior unchecked"
fi
report_totals
