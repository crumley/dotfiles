-- 03012024
-- SpaceManager
--   f:cleanUp to move windows back to their "owned" spaces, does closing space close its owned windows?
--   f:Order of spaces, keep it consistent
--   f:reconilation
--   f:Some desktop visual that will help keep track from space manager
--   f:Concept of a focused space. Then keystroke to send stuff there. space chooser (new/set focus) and remove auto focus,
--   b:closing all spaces but one doesnt unhide the dock
-- Ability for activity to select a specific window of an app (like Dendron)
-- Common spaces with windows already on it. use activities for "working spaces" to reconfigure as needed
-- 09052023
-- Cycle current space through various grid layouts
-- Common layouts 70 30 etc
-- Watermelon
--  b:Doing mash-b when melon is paused resets to a new 25m instead of unpausing
-- Mutable
--  f:change toolbar color or some other visual indicator
--  b:sometimes gets in a funk where toggling is super slow. noticed with meet.
-- New:MoreOrLessTimer
--  Will be able to handle a timer invocation that catches up when it misses something due to sleep
local config = require('config')
local utils = require('utils')

local logger = hs.logger.new('crumley', 'debug')

local hostname = hs.host.localizedName()

local localSettings = utils.load_host_settings(logger)
if localSettings == nil then
    logger.e('No settings found -- ABORTING')
    return
end

hs.settings.set("settings", localSettings)

package.path = package.path .. ";" .. os.getenv("HOME") .. "/Documents/code/hammerspoon/?.spoon/init.lua"

logger.i('Starting...', hs.inspect(package.path))

-- Configigure SpoonInstall (todo am I even using this?)
hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.use_syncinstall = true
spoon.SpoonInstall:andUse('ReloadConfiguration', {
    start = false
})

-- Configure Hammerdora
hs.loadSpoon('Watermelon')
spoon.Watermelon.logger.setLogLevel('INFO')
spoon.Watermelon.logFilePath = localSettings.melonPath

-- Configigure SpaceManager
hs.loadSpoon('SpaceManager')
spoon.SpaceManager.logger.setLogLevel('DEBUG')
spoon.SpaceManager.dockOnPrimaryOnly = true
spoon.SpaceManager.desktopLozenge = true
spoon.SpaceManager.activityTemplates = config.activities
spoon.SpaceManager:start()

-- Configure BrowserManager
-- hs.loadSpoon('BrowserManager')
-- if spoon.BrowserManager ~= nil then
--     spoon.BrowserManager.logger.setLogLevel('DEBUG')
--     spoon.BrowserManager.browserAppName = "Google Chrome"
--     spoon.BrowserManager:start()
-- end

-- Configure AppJump
hs.loadSpoon('AppJump')
spoon.AppJump.logger.setLogLevel('info')

-- Configure Unsplashed
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
BackgroundTimer9 = hs.timer.doAt("09:00", rotateBackground)
BackgroundTimer12 = hs.timer.doAt("12:00", rotateBackground)
BackgroundTimer15 = hs.timer.doAt("15:00", rotateBackground)
BackgroundTimer18 = hs.timer.doAt("18:00", rotateBackground)
BackgroundTimer21 = hs.timer.doAt("21:00", rotateBackground)

-- Make key bindings
for modifier, modifierTable in pairs(config.key_bindings) do
    for key, cb in pairs(modifierTable) do
        hs.hotkey.bind(modifier, key, cb)
    end
end

-- Uncomment to generate new annotations
-- spoon.SpoonInstall:andUse('EmmyLua')
