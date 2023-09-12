
logger = hs.logger.new('crumlee.config','debug')

hs.loadSpoon("DoNotDisturb")
hs.loadSpoon("Hammerdora")
hs.loadSpoon("SpoonInstall")

-- todo
-- fix not finding dendron when not on current space
-- make space management keyboard shortcuts just to get started
-- allow collecting windows into an activity within 10s goes to the same new workspace then switches
-- Fix bug where dock doesn't come back to primary space after deleting a space
-- add activity for zoom meeting with dendron (interviews?)
-- cleanup closed spaces that might still be tracked
-- default to new space at certain amount of time

-- 08082023
-- b:closing all spaces but one doesnt unhide the dock
-- f:space chooser (new/set focus) and remove auto focus, 
-- 08142023
-- empty space close
-- github prep + commit

-- 09052023
-- Cycle current space through various grid layouts
-- Activity to close current space (if not on primary space)
-- Alternativly a close activity action that can remove the extra Arc window.

-- 09062023
-- Ability for activity to select a specific window of an app (like Dendron)
-- Fix bug where app(v) doesn't exist... e.g. zoom is closed. May be similar area to feature above

-- 09082023
-- Doing mash-b when melon is paused resets to a new 25m instead of unpausing

-- Common layouts 70 30 etc
-- Common spaces with windows already on it. use activities for "working spaces" to reconfigure as needed
-- Terminal on each space, arc on each space?
-- Keystroke to bring app to space from anywhere... e.g get calendar here, then put it back?


spoon.SpoonInstall.use_syncinstall = true

hs.application.enableSpotlightForNameSearches(true)

local config = require('config')
local activities = require('activities')
local spaces = require('spaces')
local smgr = require('smgr')

activities:setActivities( config.focus )

spaces:init()
smgr:init(spaces)

hs.hotkey.bind({"ctrl", "cmd", "option"}, "5", function ()
    activities:start()
end)

-- Load those Spoons
for _, v in pairs(config.spoons) do
    spoon.SpoonInstall:andUse(v, {
        start = false,
    })
    if spoon[v] ~= nil and spoon[v].start ~= nil then
        spoon[v]:start()
    end
end

-- Make key bindings
for modifier, modifierTable in pairs(config.key_bindings) do
    for key, cb in pairs(modifierTable) do
        hs.hotkey.bind(modifier, key, cb)
    end
end

-- Move Window
-- hotkey.bind(mod_move, 'j', grid.pushWindowDown)
-- hotkey.bind(mod_move, 'k', grid.pushWindowUp)
-- hotkey.bind(mod_move, 'h', grid.pushWindowLeft)
-- hotkey.bind(mod_move, 'l', grid.pushWindowRight)

-- -- Resize Window
-- hotkey.bind(mod_resize, 'k', grid.resizeWindowShorter)
-- hotkey.bind(mod_resize, 'j', grid.resizeWindowTaller)
-- hotkey.bind(mod_resize, 'l', grid.resizeWindowWider)
-- hotkey.bind(mod_resize, 'h', grid.resizeWindowThinner)