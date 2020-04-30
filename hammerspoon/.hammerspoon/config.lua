local app = import('modules/app')

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
    "AClock", -- https://www.hammerspoon.org/Spoons/AClock.html
    "Calendar", -- https://www.hammerspoon.org/Spoons/Calendar.html
    "CircleClock", -- https://www.hammerspoon.org/Spoons/CircleClock.html
    "ClipShow", -- https://www.hammerspoon.org/Spoons/ClipShow.html
    "CountDown", -- https://www.hammerspoon.org/Spoons/CountDown.html
    "HCalendar", -- https://www.hammerspoon.org/Spoons/HCalendar.html
    "HSearch", -- https://www.hammerspoon.org/Spoons/HSearch.html
    "KSheet", -- https://www.hammerspoon.org/Spoons/KSheet.html
    "WinWin", -- https://www.hammerspoon.org/Spoons/WinWin.html
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

config.reload = {
  mash = mash,
  key = "0"
}

config.repl = {
  mash = mash,
  key = "R"
}

-- Maps monitor id -> screen index.
config.monitors = {
    autodiscover = true,
    rows = 1
}

config.lock = {
  mash = mash,
  key = "F12"
}

config.arrows = {
  keys = {
      UP = "top",
      DOWN = "bottom",
      LEFT = "left",
      N = "left",
      RIGHT = "right",
      M = "right",
      RETURN = "full",
      HELP = "top_left",
      PAD8 = "middle_third",
      PAGEUP = "top_right",
      PAGEDOWN = "bottom_right",
      FORWARDDELETE = "bottom_left"
  }
}

config.app_selector = {
    mash = mash,
    key = "Z"
}

config.metas = {
    MASH = {"ctrl", "cmd", "option"},
    SMASH = {"ctrl", "cmd", "option", "shift"},
}

config.fn_bindings = {
    V = function() app.jump("Code") end,
    D = function() app.jump("iTerm") end,
    F = function() app.jump("Finder") end,
    S = function() app.jump("Spotify") end,
    C = function() app.jump("Chrome") end,
    Q = function() app.jump("Slack") end,
    ['3'] = function() app.jump("1Password") end
}

config.app_jumper = {
  mash = mash,
  keys = {
    V = "Code",
    E = "Eclipse",
    D = "iTerm2",
    F = "Finder",
    W = "Spotify",
    C = "Chrome",
    Q = "Slack",
    ['1'] = "Messages",
    ['2'] = "Adium",
    ['3'] = "1Password"
  }
}

-- Window arrangements.
config.arrangements = {
    fuzzy_search = {
        mash = mash,
        key = "T"
    },
    {
        name = "zen",
        alert = true,
        mash = mash,
        key = "9",
        arrangement = {
            {
                app_title = "^Mail",
                monitor = 1,
                position = "full_screen",
            },
            {
                app_title = "^Slack",
                monitor = 4,
                position = "left"
            },
            {
                app_title = "^Messages",
                monitor = 4,
                position = function(d)
                    return d:translate_from('bottom_right', {
                        y = 42,
                        h = -40
                    })
                end
            },
            {
                app_title = "^ChronoMate",
                monitor = 4,
                position = function(d)
                    return d:translate_from('top_right', {
                        h = 42
                    })
                end
            },
            {
                app_title = "^Spotify",
                monitor = 6,
                position = "full_screen",
            }
        }
    }
}

return config
