local app = require('app')
local spaces = require('spaces')

spaces.enableHideDock()

hs.window.animationDuration = 0
hs.grid.setGrid({ w = 8, h = 4 })
hs.grid.setMargins({ w = 0, h = 0 })

hyper = {"ctrl", "cmd", "option"}
hyperShift = {"ctrl", "cmd", "option", "shift"}

local wm = require('wm')
wm:init()

local config = {}
config.spoons = {
    "ReloadConfiguration",  -- https://www.hammerspoon.org/Spoons/ReloadConfiguration.html
}

config.key_bindings = {}
config.key_bindings[hyper] = {
    G = function() spaces:focusCurrentWindow() end,
    ["1"] = function() wm:action("rotate") end,
    ["2"] = function() wm:action("mirror_y") end,
    ["3"] = function() wm:showMenu() end,
    
    A = function() app.jump("Code") end,
    D = function() app.jump("iTerm") end,
    E = function() app.jump("Spotify") end,
    S = function() app.jump("Arc") end,
    W = function() app.jump("Slack") end,
    Q = function() app.jump("1Password") end,
    Z = function() app.jump("Zoom") end,
    C = function() app.jump("Calendar") end,
    M = function() app.jump("Messages") end,
    T = function() app.jump("Trello") end,
    X = function() app.jump("dendron") end,
    
    P = function() hs.spaces.toggleMissionControl() end,
    
    V = function() hs.openConsole() end,
    R = function() hs.reload() end,
    F12 = function() hs.caffeinate.startScreensaver() end,
    
    F = function() toggleMicMute() end,
    
    B = function() spoon.Hammerdora:toggle() end,
    Y = function() spoon.SerenityNow:enable("25") end,
    
    RETURN = function() hs.grid.show() end,
    ['\\'] = function() hs.grid.maximizeWindow(hs.window.focusedWindow()) end,
}

config.key_bindings[hyperShift] = {
    S = function() app.jump("Google Chrome Canary") end,
    
    Y = function() hs.spotify.pause() end,
    U = function() hs.spotify.playpause() end,
    I = function() hs.spotify.previous() end,
    O = function() hs.spotify.next() end,
    P = function() hs.spotify.displayCurrentTrack() end,
    
    N = function() wm:action("left") end,
    M = function() wm:action("right") end,

    -- RETURN = function() hs.window.focusedWindow():centerOnScreen(nil, true) end,
    RETURN = function() push(0.05, 0.05, 0.9, 0.9) end,
}

config.focus = {
    Mail = {
        text = "Gmail",
        subText = "Curate Email Inbox",
        apps = { 'Gmail', 'Arc' },
        layout = {
            {"Gmail", nil, nil, hs.layout.left70, 0, 0},
            {"Arc", nil, nil, hs.layout.right30, 0, 0}
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
            {"Slack", nil, nil, hs.layout.left30, 0, 0},
            {"Arc", nil, nil, hs.layout.right70, 0, 0}
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
            {"Arc", nil, nil, hs.layout.right70, 0, 0}
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
            {"Arc", nil, nil, hs.layout.right70, 0, 0}
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
            {"Arc", nil, nil, hs.layout.right70, 0, 0}
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
	local mic = hs.audiodevice.defaultEffectDevice()
	local zoom = hs.application'Zoom'
    if zoom then
        local ok = zoom:selectMenuItem'Unmute Audio'
        if not ok then
            hs.timer.doAfter(0.5, function()
                zoom:selectMenuItem'Unmute Audio'
            end)
        end
        if zoom then
			local ok = zoom:selectMenuItem'Mute Audio'
			if not ok then
				hs.timer.doAfter(0.5, function()
					zoom:selectMenuItem'Mute Audio'
				end)
			end
		end
    end
end

return config
