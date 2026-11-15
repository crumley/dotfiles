-- Run from the repo root: lua test/hammerspoon-config.lua
-- Load the real configuration without macOS or any Spoons installed.
local grid, margins, muted, jumped, shown, missionControlToggled
local spotifyRunning, spotifyCalls, alerts = false, {}, {}
local function spotifyCommand(name)
    return function() spotifyCalls[#spotifyCalls + 1] = name end
end
local screenId = 'primary'
local allSpaces = { primary = { 101, 202 }, secondary = { 303 } }
hs = {
    window = {},
    grid = {
        setGrid = function(value) grid = value end,
        setMargins = function(value) margins = value end
    },
    -- config.lua reads hs.spotify.* while it loads, to wrap each command, so
    -- the stub has to exist before the dofile below, not just before a keypress.
    spotify = {
        pause = spotifyCommand('pause'),
        playpause = spotifyCommand('playpause'),
        previous = spotifyCommand('previous'),
        next = spotifyCommand('next'),
        displayCurrentTrack = spotifyCommand('displayCurrentTrack')
    },
    application = {
        get = function(hint)
            assert(hint == 'com.spotify.client', 'Look Spotify up by bundle ID, got: ' .. tostring(hint))
            return spotifyRunning and {} or nil
        end
    },
    alert = { show = function(message) alerts[#alerts + 1] = message end }
}

package.preload['hs.window.filter'] = function()
    local methods = {}
    function methods:setAppFilter(app, options)
        self.app, self.options = app, options
        return self
    end
    function methods:isWindowAllowed(win)
        return win.app == self.app and win.visible ~= false
    end
    function methods:getFilters()
        return { [self.app] = self.options or {} }
    end
    return {
        new = function(app)
            local result = setmetatable({ app = app }, { __index = methods })
            if type(app) == 'function' then
                result.isWindowAllowed = function(_, win) return app(win) end
            end
            return result
        end
    }
end
package.preload['hs.spaces'] = function()
    return {
        allSpaces = function() return allSpaces end,
        windowSpaces = function(win) return win.spaces end
    }
end
package.preload['hs.screen'] = function()
    return { primaryScreen = function()
        return { getUUID = function() return screenId end }
    end }
end
for _, name in ipairs({ 'hs.eventtap', 'hs.timer' }) do
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

local ghostty = config.appFilters.GhosttySpaceOne
hyper['2']()
assert(jumped == ghostty, 'Hyper+2 must jump to Ghostty on Space 1, not summon it')
assert(ghostty:getFilters().Ghostty, 'AppJump must be able to discover exposed Ghostty windows')
assert(ghostty:isWindowAllowed({ app = 'Ghostty', spaces = { 101 } }))
assert(ghostty:isWindowAllowed({ app = 'Ghostty', spaces = { 202, 101 } }))
assert(not ghostty:isWindowAllowed({ app = 'Ghostty', spaces = { 202 } }))
assert(not ghostty:isWindowAllowed({ app = 'Ghostty', spaces = { 303 } }))
assert(not ghostty:isWindowAllowed({ app = 'Google Chrome', spaces = { 101 } }))
assert(not ghostty:isWindowAllowed({ app = 'Ghostty', spaces = { 101 }, visible = false }))
assert(not ghostty:isWindowAllowed({ app = 'Ghostty', spaces = {} }), 'Reject ordered-out tabs')
assert(not ghostty:isWindowAllowed({ app = 'Ghostty' }), 'Missing window spaces must be safe')
allSpaces.primary = { 404, 101 }
assert(ghostty:isWindowAllowed({ app = 'Ghostty', spaces = { 404 } }), 'Resolve Space 1 dynamically')
assert(not ghostty:isWindowAllowed({ app = 'Ghostty', spaces = { 101 } }))
screenId = 'secondary'
assert(ghostty:isWindowAllowed({ app = 'Ghostty', spaces = { 303 } }), 'Follow the primary display')
screenId = 'missing'
assert(not ghostty:isWindowAllowed({ app = 'Ghostty', spaces = { 101 } }))
allSpaces.missing = {}
assert(not ghostty:isWindowAllowed({ app = 'Ghostty', spaces = { 101 } }))
hyper.D()
assert(jumped == config.appFilters.Ghostty, 'Normal Ghostty jump must be preserved')

assert(config.key_bindings[''].F18 == nil)
assert(config.key_bindings[''].F19 == nil)
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

-- hs.spotify launches a Spotify that is not running, which can stall
-- Hammerspoon's main thread; the music keys must only reach a running one.
local music = { Y = 'pause', U = 'playpause', I = 'previous', O = 'next', P = 'displayCurrentTrack' }
for key, command in pairs(music) do
    spotifyRunning, spotifyCalls, alerts = false, {}, {}
    hyperShift[key]()
    assert(#spotifyCalls == 0, 'Hyper+Shift+' .. key .. ' must not talk to a Spotify that is not running')
    assert(#alerts == 1, 'Hyper+Shift+' .. key .. ' must say that Spotify is not running')
    spotifyRunning, spotifyCalls, alerts = true, {}, {}
    hyperShift[key]()
    assert(#spotifyCalls == 1 and spotifyCalls[1] == command,
        'Hyper+Shift+' .. key .. ' must run ' .. command .. ' when Spotify is running')
    assert(#alerts == 0, 'Hyper+Shift+' .. key .. ' must not alert when Spotify is running')
end
assert(hs.window.animationDuration == 0)
assert(grid.w == 6 and grid.h == 4)
assert(margins.w == 0 and margins.h == 0)
print('Hammerspoon config: all checks passed')
