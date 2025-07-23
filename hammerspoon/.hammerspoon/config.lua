local filter = require('hs.window.filter')
local eventtap = require('hs.eventtap')
local hstimer = require("hs.timer")
local hsspaces = require("hs.spaces")
local hsscreen = require("hs.screen")

local wm = require('wm')
wm:init()

local mutable = require('mutable')
mutable.enableAppMute = true
mutable:init()

local hyper = {"ctrl", "cmd", "option"}
local hyperShift = {"ctrl", "cmd", "option", "shift"}

local config = {}

config.appFilters = {
    -- Browser
    Arc = filter.new('Arc'),
    Chrome = filter.new('Google Chrome'),
    ChromeCanary = filter.new('Google Chrome Canary'),

    -- Nerd
    iTerm = filter.new('iTerm2'),
    Ghostty = filter.new('Ghostty'),
    Code = filter.new('Code'),
    Cursor = filter.new('Cursor'),
    Intellij = filter.new('IntelliJ IDEA'),

    -- Communication: Collaboration
    Figma = filter.new('Figma'),
    Meet = filter.new('Google Meet'),
    Zoom = filter.new('zoom.us'),
    Tuple = filter.new('Tuple'),

    -- Communications: Chat
    Slack = filter.new('Slack'),
    Discord = filter.new('Discord'),
    Messages = filter.new('Messages'),
    Whatsapp = filter.new('WhatsApp'),

    -- Personal: Organization
    Calendar = filter.new('Calendar'),
    Email = filter.new('Gmail'),

    -- Apps
    Spotify = filter.new('Spotify'),
    YouTubeMusic = filter.new('YouTube Music'),
    ["1Password"] = filter.new('1Password'),

    -- Notes
    Dendron = filter.new(false):setAppFilter('Code', {
        allowTitles = 'dendron',
        currentSpace = nil
    }),
    Logseq = filter.new('Logseq')
}

config.activities = {{
    id = "Communicate",
    text = "Communicate",
    subText = "Communicate with others.",
    apps = {config.appFilters.Meet, config.appFilters.Zoom, config.appFilters.Tuple, config.appFilters.Figma,
            config.appFilters.Discord, config.appFilters.Slack, config.appFilters.Whatsapp, config.appFilters.Messages,
            config.appFilters.Calendar, config.appFilters.Email},
    space = true,
    singleton = true,
    permanent = true
}, {
    id = "Park",
    text = "Park",
    subText = "Windows parked for later.",
    apps = {},
    space = true,
    singleton = true,
    permanent = true
}, {
    id = "Today",
    text = "Today",
    subText = "Windows related to on today.",
    apps = {},
    space = true,
    singleton = true,
    permanent = true
}, {
    id = "Code",
    text = "Code",
    subText = "Code.",
    apps = {config.appFilters.Cursor, config.appFilters.Ghostty},
    space = true,
    singleton = true,
    permanent = true
}, {
    id = "Focus",
    text = "Focus",
    subText = "Collect windows that are related to a specific task.",
    apps = {},
    space = true,
    singleton = false,
    permanent = false
}}

-- No longer need activityOrder since the array order defines it

config.key_bindings = {}

config.key_bindings[""] = {
    F17 = function()
        mutable:toggleMicMute()
    end,
    F18 = function()
        wm:action("rotate")
    end,
    F19 = function()
        wm:horizontal_cycle()
    end
}

config.key_bindings[hyper] = {
    ["1"] = function()
        wm:action("rotate")
    end,
    ["2"] = function()
        wm:horizontal_cycle()
    end,
    ["4"] = function()
        wm:showMenu()
    end,
    ["5"] = function()
        spoon.SpaceManager:show()
    end,

    Q = function()
        spoon.AppJump:jump(config.appFilters["1Password"])
    end,
    W = function()
        spoon.AppJump:jump(config.appFilters.Slack)
    end,
    E = function()
        spoon.AppJump:jump(config.appFilters.Spotify)
    end,
    R = function()
        hs.reload()
    end,
    U = function()
        hs.spaces.toggleMissionControl()
    end,
    P = function()
        hs.openConsole()
    end,
    ['\\'] = function()
        hs.grid.maximizeWindow(hs.window.focusedWindow())
    end,

    A = function()
        spoon.AppJump:jump(config.appFilters.Cursor)
    end,
    S = function()
        spoon.AppJump:jump(config.appFilters.Chrome)
    end,
    D = function()
        spoon.AppJump:jump(config.appFilters.Ghostty)
    end,
    F = function()
        mutable:toggleMicMute()
    end,
    G = function()
        -- Start a Focus with the current window
        spoon.SpaceManager:startActivityFromTemplate("Focus", {hs.window.frontmostWindow()})
    end,
    RETURN = function()
        local screenId = hsscreen.primaryScreen():getUUID()
        hsspaces.addSpaceToScreen(screenId)
        local spaces = hsspaces.allSpaces()[screenId]
        spaceId = spaces[#spaces]
        hsspaces.gotoSpace(spaceId)
        hstimer.doAfter(2, function()
            hsspaces.closeMissionControl()
        end)
    end,

    Z = function()
        spoon.AppJump:jump(config.appFilters.Meet)
    end,
    X = function()
        spoon.AppJump:jump(config.appFilters.Logseq)
    end,
    C = function()
        spoon.AppJump:jump(config.appFilters.Calendar)
    end,
    V = function()
        spoon.AppJump:jump(config.appFilters.Figma)
    end,
    B = function()
        spoon.Watermelon:toggle()
    end,
    M = function()
        spoon.AppJump:jump(config.appFilters.Messages)
    end,

    F12 = function()
        hs.caffeinate.startScreensaver()
    end
}

config.key_bindings[hyperShift] = {
    -- Jamming to tunes...
    Y = function()
        hs.spotify.pause()
    end,
    U = function()
        hs.spotify.playpause()
    end,
    I = function()
        hs.spotify.previous()
    end,
    O = function()
        hs.spotify.next()
    end,
    P = function()
        hs.spotify.displayCurrentTrack()
    end,

    -- Summon windows
    Q = function()
        spoon.AppJump:summon(config.appFilters["1Password"])
    end,
    W = function()
        spoon.AppJump:summon(config.appFilters.Slack)
    end,
    X = function()
        spoon.AppJump:summon(config.appFilters.Logseq)
    end,
    Z = function()
        spoon.AppJump:summon(config.appFilters.Meet)
    end,
    -- New window functions
    -- D = function ()
    --     hs.osascript.applescript(string.format([[
    --         tell application "iTerm2"
    --             create window with default profile
    --             activate
    --         end tell
    --     ]], nil))
    -- end,
    A = function()
        local app = hs.application.find("Cursor")
        if app then
            eventtap.keyStroke({"cmd", "shift"}, "n", 0, app)
        end
    end,
    S = function()
        hs.osascript.applescript(string.format([[
            tell application "Google Chrome"
                make new window
                activate
                open location "chrome-extension://edacconmaakjimmfgnblocblbcdcpbko/session-buddy.html"
                delay 1
                activate
            end tell
        ]], nil))
    end,

    -- Window resizing fns
    N = function()
        wm:action("left")
    end,
    M = function()
        wm:action("right")
    end,

    R = function()
        spoon.Unsplashed:setRandomDesktopPhotoFromCollection(hs.settings.get("settings").unsplashCollectionId)
    end
}

return config
