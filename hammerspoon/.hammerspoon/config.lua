local wm = require('wm')
local filter = require('hs.window.filter')
wm:init()

local hyper = { "ctrl", "cmd", "option" }
local hyperShift = { "ctrl", "cmd", "option", "shift" }

local appFilters = {
    Code = filter.new(false):setAppFilter('Code', { rejectTitles='dendron' }),
    Arc = filter.new('Arc'),
    iTerm = filter.new('iTerm2'),
    Spotify = filter.new('Spotify'),
    Slack = filter.new('Slack'),
    ["1Password"] = filter.new('1Password'),
    Zoom = filter.new('zoom.us'),
    Calendar = filter.new('Calendar'),
    Messages = filter.new('Messages'),
    Dendron = filter.new(false):setAppFilter('Code', {allowTitles='dendron', currentSpace=nil}),
    ChromeCanary = filter.new('Google Chrome Canary'),
}

local config = {}
config.key_bindings = {}
config.key_bindings[hyper] = {
    G = function () spoon.SpaceManager:focusCurrentWindow() end,
    ["1"] = function () wm:horizontal_cycle() end,
    ["2"] = function () wm:action("mirror_y") end,
    ["3"] = function () wm:showMenu() end,
    ["4"] = function () wm:action("rotate") end,
    ["5"] = function () spoon.SpaceManager:show() end,

    A = function () spoon.AppJump:jump(appFilters.Code) end,
    D = function () spoon.AppJump:jump(appFilters.iTerm) end,
    E = function () spoon.AppJump:jump(appFilters.Spotify) end,
    S = function () spoon.AppJump:jump(appFilters.Arc) end,
    W = function () spoon.AppJump:jump(appFilters.Slack) end,
    Q = function () spoon.AppJump:jump(appFilters["1Password"]) end,
    Z = function () spoon.AppJump:jump(appFilters.Zoom) end,
    C = function () spoon.AppJump:jump(appFilters.Calendar) end,
    M = function () spoon.AppJump:jump(appFilters.Messages) end,
    X = function () spoon.AppJump:jump(appFilters.Dendron) end,

    P = function () hs.spaces.toggleMissionControl() end,

    V = function () hs.openConsole() end,
    R = function () hs.reload() end,
    F12 = function () hs.caffeinate.startScreensaver() end,

    F = function () toggleMicMute() end,

    B = function () spoon.Watermelon:toggle() end,

    RETURN = function () hs.grid.show() end,
    ['\\'] = function () hs.grid.maximizeWindow(hs.window.focusedWindow()) end,
}

config.key_bindings[hyperShift] = {
    S = function () spoon.AppJump:jump(appFilters.ChromeCanary) end,

    Y = function () hs.spotify.pause() end,
    U = function () hs.spotify.playpause() end,
    I = function () hs.spotify.previous() end,
    O = function () hs.spotify.next() end,
    P = function () hs.spotify.displayCurrentTrack() end,

    N = function () wm:action("left") end,
    M = function () wm:action("right") end,

    -- RETURN = function() hs.window.focusedWindow():centerOnScreen(nil, true) end,
    RETURN = function () push(0.05, 0.05, 0.9, 0.9) end,
}

config.activities = {
    Mail = {
        text = "Gmail",
        subText = "Curate Email Inbox",
        apps = { 'Gmail', 'Arc' },
        layout = {
            { "Gmail", nil, nil, hs.layout.left70,  0, 0 },
            { "Arc",   nil, nil, hs.layout.right30, 0, 0 }
        },
        space = true,
        setup = function ()
            -- Create Arc window with new tab
            hs.osascript.applescript(string.format([[
                tell application "Arc"
                    make new window
                    tell front window
                        tell space "Daily" to focus
                    end tell
                    activate
                end tell
            ]], nil))
        end
    },
    PullRequests = {
        text = "Pull Requests",
        subText = "Review Pull Requests",
        apps = { 'Slack', 'Spotify' },
        layout = {
            { "Slack", nil, nil, hs.layout.left30,  0, 0 },
            { "Arc",   nil, nil, hs.layout.right70, 0, 0 }
        },
        space = true,
        setup = function ()
            -- Create chrome window with new tab
            hs.osascript.applescript(string.format([[
                tell application "Arc"
                    make new window
                    tell front window
                        tell space "PR" to focus
                        make new tab with properties {URL:"https://bitbucket.org/atlassian/workspace/pull-requests"}
                    end tell
                end tell
            ]], nil))
        end
    },
    Focus = {
        text = "Focus Arc",
        subText = "Created a space with a single (new) Arc window",
        apps = { 'Arc' },
        layout = {
            { "Arc", nil, nil, hs.layout.right70, 0, 0 }
        },
        space = true,
        setup = function ()
            -- Create chrome window with new tab
            hs.osascript.applescript(string.format([[
                tell application "Arc"
                    make new window
                    tell front window
                        tell space "Focus" to focus
                    end tell
                end tell
            ]], nil))
        end
    },
    Meeting = {
        text = "Have a Meeting",
        subText = "Zoom + Arc",
        apps = { 'Zoom', 'Arc' },
        layout = {
            { "Arc", nil, nil, hs.layout.right70, 0, 0 }
        },
        space = true,
        setup = function ()
            -- Create chrome window with new tab
            hs.osascript.applescript(string.format([[
                tell application "Arc"
                    make new window
                    tell front window
                        tell space "Atlassian" to focus
                    end tell
                end tell
            ]], nil))
        end
    },
    Interview = {
        text = "Give an Interview",
        subText = "Zoom + Arc + Dendron",
        apps = { 'Zoom', 'Arc', 'Dendron' },
        layout = {
            { "Arc", nil, nil, hs.layout.right70, 0, 0 }
        },
        space = true,
        setup = function ()
            -- Create chrome window with new tab
            hs.osascript.applescript(string.format([[
                tell application "Arc"
                    make new window
                    tell front window
                        tell space "Atlassian" to focus
                    end tell
                end tell
            ]], nil))
        end
    },
}
function toggleMicMute()
    local zoom = hs.application 'Zoom'
    if zoom then
        local ok = zoom:selectMenuItem 'Unmute Audio'
        if not ok then
            hs.timer.doAfter(0.5, function ()
                zoom:selectMenuItem 'Unmute Audio'
            end)
        end
        if zoom then
            local ok = zoom:selectMenuItem 'Mute Audio'
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    zoom:selectMenuItem 'Mute Audio'
                end)
            end
        end
    end
end

return config
