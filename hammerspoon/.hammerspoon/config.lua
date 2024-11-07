local filter = require('hs.window.filter')
local hswindow = require('hs.window')

local wm = require('wm')
wm:init()

local mutable = require('mutable')
mutable.enableAppMute = true
mutable:init()

local hyper = { "ctrl", "cmd", "option" }
local hyperShift = { "ctrl", "cmd", "option", "shift" }

local config = {}

config.appFilters = {
    -- Browser
    Arc = filter.new('Arc'),
    Chrome = filter.new('Google Chrome'),
    ChromeCanary = filter.new('Google Chrome Canary'),

    -- Nerd
    iTerm = filter.new('iTerm2'),
    Code = filter.new('Code'),
    Cursor = filter.new('Cursor'),
    Intellij = filter.new('IntelliJ IDEA'),
    Dotfiles = filter.new(false):setAppFilter('Code', {
        allowTitles = 'dotfiles',
        currentSpace = nil
    }),

    -- Communication/Collab
    Figma = filter.new('Figma'),
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
    Dendron = filter.new(false):setAppFilter('Code', {
        allowTitles = 'dendron',
        currentSpace = nil
    }),
    Logseq = filter.new('Logseq')
}

config.activities = {
    Inbox = {
        text = "Inbox",
        subText = "Windows useful for triaging the day.",
        apps = { "Slack", "Gmail", "Google Chrome" },
        space = true,
        permanent = true,
        singleton = true,
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
        singleton = true,
        permanent = true
    },
    Today = {
        text = "Today",
        subText = "Windows to focus on today.",
        apps = {},
        layout = {},
        space = true,
        singleton = true,
        permanent = true
    },
    Mail = {
        text = "Gmail",
        subText = "Curate Email Inbox",
        apps = { 'Gmail', 'Google Chrome' },
        layout = { { "Gmail", nil, nil, hs.layout.left70, 0, 0 }, { 'Google Chrome', nil, nil, hs.layout.right30, 0, 0 } },
        space = true,
        singleton = true,
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
        singleton = true,
        setup = function ()
            -- TODO, this isn't working for some reason, maybe race condition on space switching.
            spoon.AppJump:summon(config.appFilters.Dotfiles)
        end
    },
    Meet = {
        text = "Meet",
        subText = "Have a meeting.",
        apps = {},
        layout = {},
        space = true,
        setup = function ()
            -- TODO, this isn't working for some reason, maybe race condition on space switching.
            -- TODO, if no such window exists should it be created?
            spoon.AppJump:summon(config.appFilters.Meet)
        end
    },
    Focus = {
        text = "Focus",
        subText = "Created a space for focus on a specific task",
        apps = {},
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
    }
}

config.key_bindings = {}

config.key_bindings[""] = {
    F17 = function ()
        mutable:toggleMicMute()
    end,
    F18 = function ()
        wm:action("rotate")
    end,
    F19 = function ()
        wm:horizontal_cycle()
    end
}

config.key_bindings[hyper] = {
    ["1"] = function ()
        wm:action("rotate")
    end,
    ["2"] = function ()
        wm:horizontal_cycle()
    end,
    ["4"] = function ()
        wm:showMenu()
    end,
    ["5"] = function ()
        spoon.SpaceManager:show()
    end,

    Q = function ()
        spoon.AppJump:jump(config.appFilters["1Password"])
    end,
    W = function ()
        spoon.AppJump:jump(config.appFilters.Slack)
    end,
    E = function ()
        spoon.AppJump:jump(config.appFilters.Spotify)
    end,
    R = function ()
        hs.reload()
    end,
    U = function ()
        hs.spaces.toggleMissionControl()
    end,
    P = function ()
        hs.openConsole()
    end,
    ['\\'] = function ()
        hs.grid.maximizeWindow(hs.window.focusedWindow())
    end,

    A = function ()
        spoon.AppJump:jump(config.appFilters.Cursor)
    end,
    S = function ()
        spoon.AppJump:jump(config.appFilters.Chrome)
    end,
    D = function ()
        spoon.AppJump:jump(config.appFilters.iTerm)
    end,
    F = function ()
        mutable:toggleMicMute()
    end,
    G = function ()
        -- Start a Focus with the current window
        spoon.SpaceManager:startActivity("Focus", { hs.window.frontmostWindow() })
    end,
    RETURN = function ()
        hs.grid.show()
    end,

    Z = function ()
        spoon.AppJump:jump(config.appFilters.Meet)
    end,
    X = function ()
        spoon.AppJump:jump(config.appFilters.Logseq)
    end,
    C = function ()
        spoon.AppJump:jump(config.appFilters.Calendar)
    end,
    V = function ()
        spoon.AppJump:jump(config.appFilters.Figma)
    end,
    B = function ()
        spoon.Watermelon:toggle()
    end,
    M = function ()
        spoon.AppJump:jump(config.appFilters.Messages)
    end,

    F12 = function ()
        hs.caffeinate.startScreensaver()
    end
}

config.key_bindings[hyperShift] = {
    -- Top Row
    Q = function ()
        spoon.AppJump:summon(config.appFilters["1Password"])
    end,
    W = function ()
        spoon.AppJump:summon(config.appFilters.Slack)
    end,
    R = function ()
        spoon.Unsplashed:setRandomDesktopPhotoFromCollection(
            hs.settings.get("settings").unsplashCollectionId
        )
    end,
    Y = function ()
        hs.spotify.pause()
    end,
    U = function ()
        hs.spotify.playpause()
    end,
    I = function ()
        hs.spotify.previous()
    end,
    O = function ()
        hs.spotify.next()
    end,
    P = function ()
        hs.spotify.displayCurrentTrack()
    end,

    -- Middle Row
    A = function ()
        spoon.AppJump:jump(config.appFilters.Intellij)
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
    S = function ()
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

    -- Bottom Row
    Z = function ()
        spoon.AppJump:summon(config.appFilters.Meet)
    end,
    X = function ()
        spoon.AppJump:summon(config.appFilters.Logseq)
    end,
    V = function ()
        spoon.AppJump:summon(config.appFilters.Figma)
    end,
    N = function ()
        wm:action("left")
    end,
    M = function ()
        wm:action("right")
    end
}

return config
