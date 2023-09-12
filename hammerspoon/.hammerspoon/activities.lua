
local chooser = require('hs.chooser')
local fnutils = require('hs.fnutils')
local logger = require('hs.logger')
local app = require('hs.application')

local m = {}
m.logger = logger.new('activities', 'debug')

function m:init()
    
end

function m:setActivities(activities)
    m.chooser = chooser.new(function (activity) 
        if activity then
            m.logger.i('select', hs.inspect(activity))
            m:startActivity(activities[activity["uuid"]])
        end
    end)
    local choices = {}
    for k, activity in pairs(activities) do
        table.insert( choices, {
            text = activity["text"],
            subText = activity["subText"],
            uuid = k
        }
    )
    end
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
