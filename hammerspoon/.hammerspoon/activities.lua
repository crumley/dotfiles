
local chooser = require('hs.chooser')
local fnutils = require('hs.fnutils')
local logger = require('hs.logger')
local app = require('hs.application')

-- TODO: refactor use of spaces
local spaces = require('spaces')
spaces:init()

local m = {}
m.logger = logger.new('activities', 'debug')

local actions = {
    implode = function (x) 
        -- Do the thing
        spaces:removeAllSpaces()
    end,
}

function m:init()
    
end

function m:setActivities(activities)
    m.chooser = chooser.new(function (activity) 
        if activity then
            local activityRecord = activities[activity["uuid"]]
            if activityRecord ~= nil then
                m.logger.i('Select activity', hs.inspect(activityRecord))
                m:startActivity(activityRecord)
            end
            
            local actionName = activity["uuid"]
            if actionName ~= nil then 
                m.logger.i('Select action', actionName)
                actions[actionName]()
            end
        end
    end)

    local choices = {}
    for k, activity in pairs(activities) do
        table.insert( choices, {
            text = activity["text"],
            subText = activity["subText"],
            uuid = k
        })
    end

    table.insert( choices, 
        {
        ["text"] = "Implode Spaces",
        ["subText"] = "",
        ["uuid"] = "implode"
       }
    )

    m.chooser:choices( choices )
end

function m:start()
    m.chooser:show()
end

function m:startActivity(activity)
    m.logger.i('startActivity', activity)

    if activity["setup"] ~= nil then
        activity["setup"]()
    end

    local activitySpace = nil
    if activity["space"] then
        local screenId = hs.screen.primaryScreen():getUUID()
        hs.spaces.addSpaceToScreen(screenId)
        local spaces = hs.spaces.allSpaces()[screenId]
        activitySpace = spaces[#spaces]
        hs.spaces.gotoSpace(activitySpace)
    end

    -- 2023-09-13 09:51:21: 09:51:21 activities: select {
    --     subText = "Zoom + Arc + Dendron",
    --     text = "Give an Interview",
    --     uuid = "Interview"
    --   }
    --   2023-09-13 09:51:21:          activities: startActivity table: 0x600003577940
    --   2023-09-13 09:51:22: 09:51:22 ERROR:   LuaSkin: hs.chooser:completionCallback: ...merspoon.app/Contents/Resources/extensions/hs/spaces.lua:592: ERROR: incorrect type 'nil' for argument 1 (expected number or integer)
    --   stack traceback:
    --       [C]: in upvalue '_moveWindowToSpace'
    --       ...merspoon.app/Contents/Resources/extensions/hs/spaces.lua:592: in function 'hs.spaces.moveWindowToSpace'
    --       /Users/rcrumley/.hammerspoon/activities.lua:56: in function 'activities.startActivity'
    --       /Users/rcrumley/.hammerspoon/activities.lua:18: in function </Users/rcrumley/.hammerspoon/activities.lua:15>

    for _, v in ipairs( activity["apps"] ) do
        local activityApp = app(v)
        if activitySpace ~= nil then
            hs.spaces.moveWindowToSpace(activityApp:focusedWindow(), activitySpace)
        else
            activityApp:activate()
        end
    end

    hs.layout.apply( activity["layout"] )
end

return m
