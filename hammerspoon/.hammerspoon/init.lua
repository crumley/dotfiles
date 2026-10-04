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

-- Command-line access: `hs -c 'lua'` runs code in this instance and prints the
-- result, so state can be inspected without the console (e.g. what AppJump
-- sees for an app: hs -c 'return hs.inspect(hs.application.get("Ghostty"):allWindows())').
require("hs.ipc")

-- Configigure SpoonInstall (todo am I even using this?)
hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.use_syncinstall = true

-- Reload when the configuration changes on disk. ~/.hammerspoon is stow links
-- into the dotfiles checkout, and a change to a link's target raises no event
-- under ~/.hammerspoon, so the real directory is watched too. That is how a
-- merged change goes live: the checkout's post-merge hook checks out the
-- pinned Spoons and relinks (dotfiles .githooks/post-merge), the files change
-- here, and this reloads. One reload per burst, a second after the last .lua
-- change, so a relink of many files is not many reloads. Global so the
-- watchers are not collected.
ConfigWatchers = {}
do
    local pending
    local function onChange(paths)
        for _, path in ipairs(paths) do
            if path:match("%.lua$") then
                if pending then
                    pending:stop()
                end
                pending = hs.timer.doAfter(1, function()
                    logger.i('Configuration changed on disk, reloading')
                    hs.reload()
                end)
                return
            end
        end
    end
    local dirs = { hs.configdir }
    local real = hs.fs.pathToAbsolute(hs.configdir .. "/init.lua")
    local realDir = real and real:match("^(.*)/[^/]*$")
    if realDir and realDir ~= hs.configdir then
        table.insert(dirs, realDir)
    end
    for _, dir in ipairs(dirs) do
        ConfigWatchers[dir] = hs.pathwatcher.new(dir, onChange):start()
    end
end

-- Configure Hammerdora
hs.loadSpoon('Watermelon')
spoon.Watermelon.logger.setLogLevel('INFO')
spoon.Watermelon.logFilePath = localSettings.melonPath

-- Configigure SpaceManager
hs.loadSpoon('SpaceManager')
spoon.SpaceManager.logger.setLogLevel('DEBUG')
spoon.SpaceManager.dockOnPrimaryOnly = true
spoon.SpaceManager.desktopLozenge = true
spoon.SpaceManager.spaceConfig = config.spaceConfig
-- Chrome windows carry the name of the space they are on.
spoon.SpaceManager.chromeWindowNames = true
-- ...and keep a pinned tab showing that space's number and color (drawn by
-- the SpaceManager extension, below).
spoon.SpaceManager.chromeWindowLabels = true
-- Links clicked in other apps open in the 📥 Inbox when it is on the space
-- showing, else in a Chrome window there, else in the Inbox wherever it is
-- (or a new one here). Hammerspoon becomes the default browser; macOS asks
-- once. The Inbox's tabs are grouped by day by the SpaceManager
-- extension: load Spoons/SpaceManager.spoon/chrome-extension unpacked.
spoon.SpaceManager.linkRouting = true
spoon.SpaceManager.inbox = true
spoon.SpaceManager.linkRoutingNoChrome = "inbox"
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
-- 'debug' traces every jump (window chosen, why, its spaces before and after)
-- in the console; drop back to 'info' once the Ghostty tab/space jumping is settled.
spoon.AppJump.logger.setLogLevel('debug')
-- The window picker (hyper+`) labels each window with its space as
-- SpaceManager names it. Neither spoon knows the other; this line joins them.
spoon.AppJump.spaceLabel = function(spaceId)
    return spoon.SpaceManager:spaceLabel(spaceId)
end

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

-- Brain sync: `b3 sync` when this machine is left (lock/sleep) and arrived at
-- (wake/unlock), plus a hotkey. A no-op unless the host settings file says
-- brainSync = true -- see brainsync.lua. Global so `hs -c 'BrainSync.run()'`
-- can reach it.
BrainSync = require('brainsync')
BrainSync.start(localSettings)

-- Uncomment to generate new annotations
-- spoon.SpoonInstall:andUse('EmmyLua')
