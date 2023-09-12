
local chooser = require('hs.chooser')
local fnutils = require('hs.fnutils')
local logger = require('hs.logger')

local m = {}
m.logger = logger.new('chooser', 'debug')

local actions = {
    restart_yabai = function (x) 
        yabai("--restart-service")
    end,

    off_yabai = function (x) 
        yabai("--stop-service")
    end,
    
    on_yabai = function (x) 
        yabai("--start-service")
    end,
    
    rotate = function (x) 
        yabai("-m space --rotate 90")
    end,
    
    mirror_x = function (x) 
        yabai("-m space --rotate 90")
    end,

    mirror_y = function (x) 
        yabai("-m space --mirror y-axis")
    end,

    left = function ()
        yabaish("/opt/homebrew/bin/yabai -m window --resize right:-20:0 || /opt/homebrew/bin/yabai -m window --resize left:-20:0")
    end,

    right = function ()
        yabaish("/opt/homebrew/bin/yabai yabai -m window --resize right:20:0 || /opt/homebrew/bin/yabai -m window --resize left:20:0")
    end,
}

function split (inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

function yabai(cli)
    -- Runs in background very fast
    hs.task.new("/opt/homebrew/bin/yabai", nil, function(ud, ...)
      print("stream", hs.inspect(table.pack(...)))
      return true
    end, split(cli)):start()
end

function yabaish(cli)
    -- Runs in background very fast
    hs.task.new("/bin/bash", nil, function(ud, ...)
      print("stream", hs.inspect(table.pack(...)))
      return true
    end, {"-c", cli}):start()
end

function m:init()
    m.chooser = chooser.new(function ( selection ) 
        if selection ~= nil then
            m:action(selection["uuid"])
        end
    end)

    m.chooser:choices( {
        {
         ["text"] = "Restart Yabai",
         ["subText"] = "",
         ["uuid"] = "restart_yabai"
        },
        { ["text"] = "Yabai off",
          ["subText"] = "Turn off",
          ["uuid"] = "off_yabai"
        },
        { ["text"] = "Yabai on",
          ["subText"] = "Turn on",
          ["uuid"] = "on_yabai"
        },
    } )
end

function m:action(actionName)
    actions[actionName]()
end

function m:showMenu()
    m.chooser:show()
end

return m
