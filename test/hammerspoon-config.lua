-- Run from the repo root: lua test/hammerspoon-config.lua
-- Load the real configuration without macOS or any Spoons installed.
local grid, margins, muted, jumped, shown, missionControlToggled
hs = {
    window = {},
    grid = {
        setGrid = function(value) grid = value end,
        setMargins = function(value) margins = value end
    }
}

package.preload['hs.window.filter'] = function()
    local methods = {}
    function methods:setAppFilter(app, options)
        self.app, self.options = app, options
        return self
    end
    return {
        new = function(app)
            return setmetatable({ app = app }, { __index = methods })
        end
    }
end
for _, name in ipairs({ 'hs.eventtap', 'hs.timer', 'hs.spaces', 'hs.screen' }) do
    package.preload[name] = function() return {} end
end
package.preload.mutable = function()
    return {
        init = function() end,
        toggleMicMute = function() muted = true end
    }
end
-- Requiring wm would fail: no stub, no Spoons, and no configuration search path.
spoon = {
    AppJump = { jump = function(_, value) jumped = value end },
    SpaceManager = {
        show = function() shown = true end,
        toggleMissionControl = function() missionControlToggled = true end
    }
}
local config = dofile('hammerspoon/.hammerspoon/config.lua')
local hyper, hyperShift
for mods, bindings in pairs(config.key_bindings) do
    if type(mods) == 'table' then
        if #mods == 3 then hyper = bindings else hyperShift = bindings end
    end
end
assert(hyper and hyperShift)

local inbox = config.appFilters.ChromeInbox
assert(inbox.app == 'Google Chrome')
assert(inbox.options.currentSpace == nil, 'Inbox jump must not be restricted to this space')
local pattern = inbox.options.allowTitles
for _, title in ipairs({
    '📥 Inbox - Google Chrome - Ryan (Work)',
    '📥 Inbox - Audio playing - Google Chrome - Ryan (Work)',
    '📥 Inbox - Some active tab - Google Chrome'
}) do
    assert(title:match(pattern), 'Inbox title rejected: ' .. title)
end
for _, title in ipairs({
    '🟥 01 - Today - Google Chrome - Ryan (Work)',
    'Inbox - Gmail - Google Chrome',
    'Not 📥 Inbox - Google Chrome',
    '📥 Inbox Archive - Google Chrome'
}) do
    assert(not title:match(pattern), 'Non-Inbox title accepted: ' .. title)
end
hyper['1']()
assert(jumped == inbox, 'Hyper+1 must jump to the Inbox, not summon it')
hyper.S()
assert(jumped == config.appFilters.Chrome, 'Normal Chrome jump must be preserved')

assert(config.key_bindings[''].F18 == nil)
assert(config.key_bindings[''].F19 == nil)
assert(hyper['2'] == nil)
assert(hyper['4'] == nil)
assert(hyperShift.N == nil)
assert(hyperShift.M == nil)
config.key_bindings[''].F17()
assert(muted, 'F17 mic mute must be preserved')
hyper['5']()
assert(shown, 'Hyper+5 SpaceManager must be preserved')
hyper.T()
assert(missionControlToggled, 'Hyper+T must toggle Mission Control with space names')
assert(hyper.U == nil, 'The old Hyper+U space changer must be unbound')
assert(hyper.SPACE == nil, 'Hyper+Space must remain free for Raycast')
assert(type(hyperShift.U) == 'function', 'Hyper+Shift+U music control must be preserved')
assert(hs.window.animationDuration == 0)
assert(grid.w == 6 and grid.h == 4)
assert(margins.w == 0 and margins.h == 0)
print('Hammerspoon config: all checks passed')
