local app = require('app')

local config = {}

local mash = {"ctrl", "cmd", "option", "shift"};

-- TODO
-- make iterm toggle button over current app
-- Make spotify commands for playpause and show current track
-- Make auto arrangements for work dual screen and single screen
-- Move all windows for an app to screen location (eg Chrome)
-- Map caps lock to mash
-- create support for second level key mappings (mash k + <KEY>)

config.spoons = {
    "ReloadConfiguration",  -- https://www.hammerspoon.org/Spoons/ReloadConfiguration.html
    "KSheet", -- https://www.hammerspoon.org/Spoons/KSheet.html
    "MicMute", -- https://www.hammerspoon.org/Spoons/MicMute.html
}

config.modules = {
    "app_selector",
    "arrangement",
    "monitors",
    "repl",
    "arrows",
    "lock",
    "fullscreen",
    "hop",
    "music"
}

hyper = {"ctrl", "cmd", "option"}
hyperShift = {"ctrl", "cmd", "option", "shift"}

hs.window.animationDuration = 0
hs.grid.setGrid({ w = 2, h = 2 })
hs.grid.setMargins({ w = 0, h = 0 })


-- create auto layout that does good things for iTerm, p4merge, chrome?
-- create manual layout that cycles current two windows (maybe per monitor?)

-- auto_layout = hs.window.layout.new({
--     {"iTerm2", "tile [12,12,80,80] 0,0 | tile all [0,0,100,100] 0,0" },
-- })
-- auto_layout:start()


window_layout = hs.window.layout.new({
    -- { hs.window.filter.new({ Slack = { allowRoles = "AXStandardWindow" } }), "fit 1 [0,0,50,100] 0,0 | min" },
    -- { hs.window.filter.new(false):setAppFilter("Google Chrome", { visible = true, allowRoles = "AXStandardWindow"}), "tile 2 focused 1x2 [0,0,100,100] 0,0 | tile all [0,0,100,100] 0,0" },
    {"Google Chrome", "tile 2 focused 1x2 [0,0,100,100] 0,0 | tile all [0,0,100,100] 0,0" },

    -- Comms Screen (-1,0=left)
    -- Maximized
    -- { hs.window.filter.new({ Calendar = { allowRoles = "AXStandardWindow" } }), "move all focused [50,0,50,100] 1,0 | min" },
    -- { hs.window.filter.new(false):setAppFilter("Google Chrome", { visible = true, allowRoles = "AXStandardWindow", allowTitles = "Hangouts" }), "tile 2 focused 1x2 [0,0,100,100] 1,0 | min" },

    -- Left 50%
    -- { hs.window.filter.new({ Mail = { allowRoles = "AXStandardWindow" } }), "tile 2 focused 2x1 [0,0,50,100] 0,0 | min" },
    -- { hs.window.filter.new({ Spotify = { allowRoles = "AXStandardWindow" } }), "tile 2 focused 2x1 [0,0,50,100] 0,0 | min" },
    -- { hs.window.filter.new({ WhatsApp = { allowRoles = "AXStandardWindow" } }), "tile 2 focused 2x1 [0,0,50,100] 0,0 | min" },

    -- Right 50%
    -- { hs.window.filter.new({ iTunes = { allowRoles = "AXStandardWindow", rejectTitles = "MiniPlayer" } }), "fit 1 [50,0,100,100] -1,0 | min" },
    -- { hs.window.filter.new({ Slack = { allowRoles = "AXStandardWindow" } }), "fit 1 [50,0,100,100] 0,0 | min" },

    -- Top 60%
    -- Bottom 40%
    -- { hs.window.filter.new({ Messages = { allowRoles = "AXStandardWindow" } }), "fit 1 [50,60,100,100] -1,0 | min" },


    -- Tools Screen (0,0=center)
    -- Left 65%
    -- { hs.window.filter.new(false):setAppFilter("Google Chrome", { visible = true, allowRoles = "AXStandardWindow", rejectTitles = { "DevTools", "Lucidchart", "Hangouts" } }), "tile 2 focused 2x1 [0,0,70,100] 1,0 | min" },
    -- { hs.window.filter.new({ SourceTree = { allowRoles = "AXStandardWindow" } }), "tile 2 focused 2x1 [0,0,50,100] 0,0 | min" },
    -- { hs.window.filter.new(false):setAppFilter("Pulse SMS", { visible = true, allowRoles = "AXStandardWindow" }), "tile 2 focused 2x1 [0,50,50,100] 0,0 | min" },
    --{ hs.window.filter.new({ MySQLWorkbench = { allowRoles = "AXStandardWindow" } }), "tile 2 focused 2x1 [0,0,65,100] 0,0 | min" },

    -- Right 35%
    -- { hs.window.filter.new({ Terminal = { allowRoles = "AXStandardWindow" } }), "tile 4 focused 2x1 [70.0,0.0,100.0,100.0] 1,0 | min" },
    -- { hs.window.filter.new({ Firefox = { visible = true, allowRoles = "AXStandardWindow" } }), "tile 2 focused 2x1 [0,0,70,100] -1,-1 | min" },
    -- { hs.window.filter.new(false):setAppFilter("Google Chrome", { visible = true, allowRoles = "AXStandardWindow", allowTitles = "DevTools" }), "tile 2 focused 2x1 [70,0,100,100] 1,0 | min" },
    -- { hs.window.filter.new(false):setAppFilter("Google Chrome", { visible = true, allowRoles = "AXStandardWindow", allowTitles = "Developer Tools" }), "tile 2 focused 2x1 [70,0,100,100] 1,0 | min" },
    -- { hs.window.filter.new({ python = { allowRoles = "AXStandardWindow" } }), "tile 2 focused 2x1 [0,0,70,100] -1,-1 | min" },

    -- Code Screen (1,0=right)
    -- { hs.window.filter.new({ PyCharm = { allowRoles = "AXStandardWindow", allowTitles = "/Documents/GitHub", rejectTitles = "Replace Usage" } }), "move all focused [0,0,100,100] 0,-1" },

    -- { hs.window.filter.new({ GoLand = { allowRoles = "AXStandardWindow", allowTitles = "/", rejectTitles = "Replace Usage" } }), "move all focused [0,0,100,100] 2,0" },

    -- { hs.window.filter.new(false):setAppFilter("Google Chrome", { visible = true, allowRoles = "AXStandardWindow", allowTitles = "Lucidchart" }), "move all focused [0,0,100,100] 1,0" },
})

local function doit(name)
    -- so tab, tab, down, enter, tab, down, enter, tab, down, enter, tab, enter
    hs.eventtap.keyStroke(nil, "tab", 1000)
    hs.eventtap.keyStroke(nil, "tab", 1000)
    hs.eventtap.keyStroke(nil, "tab", 1000)
    hs.eventtap.keyStroke(nil, "tab", 1000)
    hs.eventtap.keyStroke(nil, "return", 1000)
    hs.eventtap.keyStroke(nil, "return", 10000)
    hs.eventtap.keyStroke(nil, "return", 10000)
    hs.eventtap.keyStroke(nil, "tab", 1000)
    hs.eventtap.keyStroke(nil, "return", 1000)
    hs.eventtap.keyStroke(nil, "return", 10000)
    hs.eventtap.keyStroke(nil, "return", 10000)
    hs.eventtap.keyStroke(nil, "tab", 1000)
    hs.eventtap.keyStroke(nil, "return", 1000)
end

config.key_bindings = {}

config.key_bindings[hyper] = {
    G = function() doit() end,
    A = function() app.jump("Code") end,
    D = function() app.jump("iTerm") end,
    E = function() app.jump("Spotify") end,
    S = function() app.jump("Google Chrome") end,
    W = function() app.jump("Slack") end,
    Q = function() app.jump("1Password") end,
    Z = function() app.jump("Zoom") end,
    C = function() app.jump("Calendar") end,
    N = function() app.jump("Notes") end,
    M = function() app.jump("Messages") end,
    T = function() app.jump("Trello") end,
    X = function() app.jump("dendron") end,

    P = function() spoon.KSheet:show() end,

    V = function() hs.openConsole() end,
    R = function() hs.reload() end,
    F12 = function() hs.caffeinate.startScreensaver() end,

    F = function() toggleMicMute() end,

    RETURN = function() hs.grid.show() end,
    ['\\'] = function() hs.grid.maximizeWindow(hs.window.focusedWindow()) end,
}

function toggleMicMute()
	local mic = hs.audiodevice.defaultEffectDevice()
	local zoom = hs.application'Zoom'
	logger.i('zo')
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

config.key_bindings[hyperShift] = {
    A = function() app.jump("IDEA") end,
    S = function() app.jump("Google Chrome Canary") end,
    Y = function() hs.spotify.pause() end,
    U = function() hs.spotify.playpause() end,
    I = function() hs.spotify.previous() end,
    O = function() hs.spotify.next() end,
    P = function() hs.spotify.displayCurrentTrack() end,
    T = function() spoon.KSheet:hide() end,

    M = function() spoon.MicMute:toggleMicMute() end,
    RETURN = function() window_layout:apply() end,
}

return config
