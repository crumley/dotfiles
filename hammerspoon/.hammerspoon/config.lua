local wm = require('wm')
local filter = require('hs.window.filter')
wm:init()

local hyper = { "ctrl", "cmd", "option" }
local hyperShift = { "ctrl", "cmd", "option", "shift" }

local appFilters = {
    -- Browser
    Arc = filter.new('Arc'),
    Chrome = filter.new('Google Chrome'),
    ChromeCanary = filter.new('Google Chrome Canary'),

    -- Nerd
    iTerm = filter.new('iTerm2'),
    Code = filter.new('Code'),

    -- Communication/Collab
    Slack = filter.new('Slack'),
    Meet = filter.new('Google Meet'),
    Zoom = filter.new('zoom.us'),
    Calendar = filter.new('Calendar'),
    Messages = filter.new('Messages'),

    -- Apps
    Spotify = filter.new('Spotify'),
    ["1Password"] = filter.new('1Password'),

    -- Notes
    Dendron = filter.new(false):setAppFilter('Code', { allowTitles = 'dendron', currentSpace = nil }),
    Logseq = filter.new('Logseq'),
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
    S = function () spoon.AppJump:jump(appFilters.Chrome) end,
    W = function () spoon.AppJump:jump(appFilters.Slack) end,
    Q = function () spoon.AppJump:jump(appFilters["1Password"]) end,
    Z = function () spoon.AppJump:jump(appFilters.Meet) end,
    C = function () spoon.AppJump:jump(appFilters.Calendar) end,
    M = function () spoon.AppJump:jump(appFilters.Messages) end,
    X = function () spoon.AppJump:jump(appFilters.Logseq) end,

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
    Y = function () hs.spotify.pause() end,
    U = function () hs.spotify.playpause() end,
    I = function () hs.spotify.previous() end,
    O = function () hs.spotify.next() end,
    P = function () hs.spotify.displayCurrentTrack() end,

    X = function () spoon.AppJump:summon(appFilters.Logseq) end,

    S = function ()
        hs.osascript.applescript(string.format([[
            tell application "Google Chrome"
                make new window
                activate
            end tell
        ]], nil))
    end,

    N = function () wm:action("left") end,
    M = function () wm:action("right") end,

    R = function ()
        spoon.Unsplashed:setRandomDesktopPhotoFromCollection(hs.settings.get("settings")
            .unsplashCollectionId)
    end,

    -- RETURN = function() hs.window.focusedWindow():centerOnScreen(nil, true) end,
    RETURN = function () push(0.05, 0.05, 0.9, 0.9) end,
}

config.activities = {
    Mail = {
        text = "Gmail",
        subText = "Curate Email Inbox",
        apps = { 'Gmail', 'Google Chrome' },
        layout = {
            { "Gmail",         nil, nil, hs.layout.left70,  0, 0 },
            { 'Google Chrome', nil, nil, hs.layout.right30, 0, 0 }
        },
        space = true,
        setup = function ()
            -- Create Arc window with new tab
            hs.osascript.applescript(string.format([[
                tell application "Google Chrome"
                    make new window
                    activate
                end tell
            ]], nil))
        end
    },
    Focus = {
        text = "Focus Chrome",
        subText = "Created a space with a single (new) Chrome window",
        apps = { 'Google Chrome' },
        layout = {},
        space = true,
        setup = function ()
            -- Create chrome window with new tab
            hs.osascript.applescript(string.format([[
                tell application "Google Chrome"
                    make new window
                    tell front window
                        open location "chrome-extension://edacconmaakjimmfgnblocblbcdcpbko/main.html"
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
