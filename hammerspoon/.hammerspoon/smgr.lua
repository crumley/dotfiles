
local chooser = require('hs.chooser')

local m = {}
m.logger = hs.logger.new('smgr', 'debug')

function m:init(spaceManager)
    m.spaceManager = spaceManager
    m.functions = {
        closeAll = function() 
            spaceManager:removeAllSpaces() 
        end,
        new = function() 
            spaceManager:newManagedSpace() 
        end
    }
    m.chooser = chooser.new(function (choice)
        if choice ~= nil then
            m.functions[choice["uuid"]]()
        end
    end)
end

function m:show()
    local choices = {}
    table.insert( choices, {
        text = "Close all",
        subText = "Closes all spaces and returns to first space",
        uuid = "closeAll"
    })
    table.insert( choices, {
        text = "New Managed Space",
        subText = "...",
        uuid = "new"
    })
    m.chooser:choices( choices )
    m.chooser:show()
end

return m
