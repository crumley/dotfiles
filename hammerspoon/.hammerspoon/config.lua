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

config.key_bindings = {}

config.key_bindings[hyper] = {
    A = function() app.jump("Code") end,
    D = function() app.jump("iTerm") end,
    F = function() app.jump("Finder") end,
    E = function() app.jump("Spotify") end,
    S = function() app.jump("Google Chrome") end,
    W = function() app.jump("Slack") end,
    Q = function() app.jump("1Password") end,
    Z = function() app.jump("Zoom") end,
    C = function() app.jump("Calendar") end,
    N = function() app.jump("Notes") end,
    M = function() app.jump("Messages") end,
    T = function() app.jump("Trello") end,

    P = function() spoon.KSheet:show() end,

    X = function() hs.openConsole() end,
    R = function() hs.reload() end,
}

config.key_bindings[hyperShift] = {
    Y = function() hs.spotify.pause() end,
    U = function() hs.spotify.playpause() end,
    I = function() hs.spotify.previous() end,
    O = function() hs.spotify.next() end,
    P = function() hs.spotify.displayCurrentTrack() end,
    T = function() spoon.KSheet:hide() end,

    M = function() spoon.MicMute:toggleMicMute() end,
}

return config
