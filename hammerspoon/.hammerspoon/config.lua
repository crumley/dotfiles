local wm = require('wm')
wm:init()

local mutable = require('mutable')
mutable.enableAppMute = true
mutable:init()

local hyper = { "ctrl", "cmd", "option" }
local hyperShift = { "ctrl", "cmd", "option", "shift" }

local filter = require('hs.window.filter')
local appFilters = {
    -- Browser
    Arc = filter.new('Arc'),
    Chrome = filter.new('Google Chrome'),
    ChromeCanary = filter.new('Google Chrome Canary'),

    -- Nerd
    iTerm = filter.new('iTerm2'),
    Code = filter.new('Code'),
    Dotfiles = filter.new(false):setAppFilter('Code', { allowTitles = 'dotfiles', currentSpace = nil }),

    -- Communication/Collab
    Slack = filter.new('Slack'),
    Meet = filter.new('Google Meet'),
    Zoom = filter.new('zoom.us'),
    Tuple = filter.new('Tuple'),
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

config.key_bindings[""] = {
    F17 = function () mutable:toggleMicMute() end,
    F18 = function () wm:action("rotate") end,
    F19 = function () wm:horizontal_cycle() end,
}

config.key_bindings[hyper] = {
    ["1"] = function () wm:action("rotate") end,
    ["2"] = function () wm:horizontal_cycle() end,
    ["4"] = function () wm:showMenu() end,
    ["5"] = function () spoon.SpaceManager:show() end,

    -- nil starts activity with current window
    G = function () spoon.SpaceManager:startActivity(nil) end,

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

    F = function () mutable:toggleMicMute() end,

    B = function () spoon.Watermelon:toggle() end,

    RETURN = function () hs.grid.show() end,
    ['\\'] = function () hs.grid.maximizeWindow(hs.window.focusedWindow()) end,
}

config.key_bindings[hyperShift] = {
    -- Jamming to tunes...
    Y = function () hs.spotify.pause() end,
    U = function () hs.spotify.playpause() end,
    I = function () hs.spotify.previous() end,
    O = function () hs.spotify.next() end,
    P = function () hs.spotify.displayCurrentTrack() end,

    -- Summon windows
    Q = function () spoon.AppJump:summon(appFilters["1Password"]) end,
    W = function () spoon.AppJump:summon(appFilters.Slack) end,
    X = function () spoon.AppJump:summon(appFilters.Logseq) end,
    Z = function () spoon.AppJump:summon(appFilters.Meet) end,

    -- New window functions
    D = function ()
        hs.osascript.applescript(string.format([[
            tell application "iTerm2"
                create window with default profile
                activate
            end tell
        ]], nil))
    end,
    S = function ()
        hs.osascript.applescript(string.format([[
            tell application "Google Chrome"
                make new window
                activate
            end tell
        ]], nil))
    end,

    -- Window resizing fns
    N = function () wm:action("left") end,
    M = function () wm:action("right") end,

    R = function ()
        spoon.Unsplashed:setRandomDesktopPhotoFromCollection(hs.settings.get("settings")
            .unsplashCollectionId)
    end
}

config.activities = {
    Inbox = {
        text = "Inbox",
        subText = "Windows useful for triaging the day.",
        apps = { "Slack", "Gmail", "Google Chrome" },
        space = true,
        permanent = true,
        setup = function ()
            hs.osascript.applescript(string.format([[
                tell application "Google Chrome"
                    make new window
                    activate
                end tell
            ]], nil))
        end
    },
    Someday = {
        text = "Someday",
        subText = "Windows to make available for someday.",
        apps = {},
        layout = {},
        space = true,
        permanent = true,
    },
    Today = {
        text = "Today",
        subText = "Windows to focus on today.",
        apps = {},
        layout = {},
        space = true,
        permanent = true,
    },
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
    Dotfiles = {
        text = "Dotfiles",
        subText = "Work on dotfiles.",
        apps = {},
        layout = {},
        space = true,
        setup = function ()
            -- TODO, this isn't working for some reason, maybe race condition on space switching.
            spoon.AppJump:summon(appFilters.Dotfiles)
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

return config
