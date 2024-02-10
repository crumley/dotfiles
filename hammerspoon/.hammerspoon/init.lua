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


local logger = hs.logger.new('crumley', 'debug')

local localSettings = hs.json.read(".settings.json")
if localSettings == nil then
    logger.f("Missing .hammerspoon/.settings.json file.")
end

hs.settings.set("settings", localSettings)

package.path = package.path .. ";" .. os.getenv("HOME") .. "/Documents/code/hammerspoon/?.spoon/init.lua"

logger.i('Starting...', hs.inspect(package.path))

local config = require('config')

-- Configigure SpoonInstall (todo am I even using this?)
hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.use_syncinstall = true
spoon.SpoonInstall:andUse('ReloadConfiguration', {
    start = false,
})

-- Configure Hammerdora
hs.loadSpoon('Watermelon')
spoon.Watermelon.logger.setLogLevel('INFO')
spoon.Watermelon.logFilePath = localSettings.melonPath

-- Configigure SpaceManager
hs.loadSpoon('SpaceManager')
spoon.SpaceManager.logger.setLogLevel('info')
spoon.SpaceManager.dockOnPrimaryOnly = true
spoon.SpaceManager.desktopLozenge = true
spoon.SpaceManager.activities = config.activities
spoon.SpaceManager:start()

hs.loadSpoon('AppJump')
spoon.AppJump.logger.setLogLevel('info')

hs.loadSpoon('Unsplashed')
spoon.Unsplashed.logger.setLogLevel('info')
spoon.Unsplashed.clientId = localSettings.unsplashApiKey
spoon.Unsplashed:start()

local function rotateBackground()
    logger.i('Rotating background image')
    spoon.Unsplashed:setRandomDesktopPhotoFromCollection(localSettings.unsplashCollectionId)
end

-- Rotate background at specific times of day
-- Capture timers in global variables so they are not harvested
backgroundTimer9 = hs.timer.doAt("09:00", rotateBackground)
backgroundTimer12 = hs.timer.doAt("12:00", rotateBackground)
backgroundTimer15 = hs.timer.doAt("15:00", rotateBackground)
backgroundTimer18 = hs.timer.doAt("18:00", rotateBackground)
backgroundTimer21 = hs.timer.doAt("21:00", rotateBackground)

-- Make key bindings
for modifier, modifierTable in pairs(config.key_bindings) do
    for key, cb in pairs(modifierTable) do
        hs.hotkey.bind(modifier, key, cb)
    end
end

-- Uncomment to generate new annotations
-- spoon.SpoonInstall:andUse('EmmyLua')
