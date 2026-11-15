#!/usr/bin/env bash
# Exercise the real Hammerspoon keybindings against stubs, on either platform.
set -uo pipefail
# shellcheck source=test/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

section "Hammerspoon config"
# Debian and Ubuntu may install the interpreter only under a versioned name.
lua_bin=""
for candidate in lua lua5.4 lua5.3; do
    if have "$candidate"; then
        lua_bin=$candidate
        break
    fi
done
if [ -n "$lua_bin" ]; then
    if (cd "$REPO_ROOT" && "$lua_bin" test/hammerspoon-config.lua); then
        pass "Inbox and Space 1 Ghostty shortcuts, Spotify-only-when-running music keys, removed yabai bindings, retained grid and mic mute"
    else
        fail "Hammerspoon config"
    fi
# A skip is not a failure, so on a runner it would hide this suite for good.
elif [ -n "${GITHUB_ACTIONS:-}" ]; then
    fail "no Lua interpreter on the CI runner — Hammerspoon config behavior unchecked"
else
    skip "lua not installed — Hammerspoon config behavior unchecked"
fi
report_totals
