local eventtap = require('hs.eventtap')

local m = {}
m.__index = m

m.logger = hs.logger.new('crumlee.space', 'debug')

-- Hattip: https://github.com/Hammerspoon/Spoons/blob/master/Source/MicMute.spoon/init.lua#L11

-- Metadata
m.name = "MicMute"
m.version = "0.1"
m.author = "me"
m.homepage = "https://me.com"
m.license = "MIT - https://opensource.org/licenses/MIT"

m.muteState = nil

m.enableMenuBar = false
m.enableMuteIndicator = false
m.enableApplescriptMute = false
m.enableAppMute = false
m.enableAudioDeviceMute = false

function m:setIndicatorMuteState(mute)
    -- TODO desktop indicator!
    if m.showMenuBar then
        if mute then
            m.mute_menu:setTitle("📵 Muted")
        else
            m.mute_menu:setTitle("🎙 On")
        end
    end
end

function m:setAudioDeviceMuteState(mute)
    if mute then
        hs.audiodevice.defaultInputDevice():setInputMuted(true)
    else
        hs.audiodevice.defaultInputDevice():setInputMuted(false)
    end
end

function m:setApplescriptMuteState(mute)
    if mute then
        hs.osascript.applescript("set volume input volume 0")
    else
        hs.osascript.applescript("set volume input volume 8")
    end
end

function m:setAppMuteState(mute)
    m:setTeamsMuteState(mute)
    m:setZoomMuteState(mute)
    m:setMeetMuteState(mute)
    m:setTupleMuteState(mute)
end

function m:setTupleMuteState(mute)
    -- TODO is this the fastest way? maybe a window filter?
    local app = hs.application.find("tuple")
    if app then
        if mute then
            local ok = app:selectMenuItem('Mute')
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    eventtap.keyStroke({ "cmd", "shift" }, "m", 0, app)
                end)
            end
        else
            local ok = app:selectMenuItem('Unmute')
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    eventtap.keyStroke({ "cmd", "shift" }, "m", 0, app)
                end)
            end
        end
    end
end

function m:setMeetMuteState(mute)
    -- TODO this only supports toggle!
    local app = hs.application.find("Google Meet")
    if app then
        if mute then
            eventtap.keyStroke({ "cmd" }, "d", 0, app)
        else
            eventtap.keyStroke({ "cmd" }, "d", 0, app)
        end
    end
end

function m:setTeamsMuteState(mute)
    local app = hs.application.find("com.microsoft.teams")
    if app then
        if mute then
            local ok = app:selectMenuItem('Mute')
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    eventtap.keyStroke({ "cmd", "shift" }, "m", 0, app)
                end)
            end
        else
            local ok = app:selectMenuItem('Unmute')
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    eventtap.keyStroke({ "cmd", "shift" }, "m", 0, app)
                end)
            end
        end
    end
end

function m:setZoomMuteState(mute)
    local app = hs.application('Zoom')
    if app then
        if mute then
            local ok = app:selectMenuItem('Mute Audio')
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    app:selectMenuItem('Mute Audio')
                end)
            end
        else
            local ok = app:selectMenuItem('Unmute Audio')
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    app:selectMenuItem('Unmute Audio')
                end)
            end
        end
    end
end

function m:setMicMute(mute)
    m.logger.d('Setting mute state: ', mute)
    m.muteState = mute

    -- TODO pcall these

    if m.enableMuteIndicator then
        m:setIndicatorMuteState(mute)
    end

    if m.enableAppMute then
        m:setAppMuteState(mute)
    end

    if m.enableApplescriptMute then
        m:setApplescriptMuteState(mute)
    end

    if m.enableAudioDeviceMute then
        m:setAudioDeviceMuteState(mute)
    end
end

--- MicMute:toggleMicMute()
--- Method
--- Toggle mic mute on/off
---
--- Parameters:
---  * None
function m:toggleMicMute()
    m:setMicMute(not self.muteState)
end

--- MicMute:bindHotkeys(mapping, latch_timeout)
--- Method
--- Binds hotkeys for MicMute
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * toggle - This will cause the microphone mute status to be toggled. Hold for momentary, press quickly for toggle.
---  * latch_timeout - Time in seconds to hold the hotkey before momentary mode takes over, in which the mute will be toggled again when hotkey is released. Latch if released before this time. 0.75 for 750 milliseconds is a good value.
function m:bindHotkeys(mapping, latch_timeout)
    if (self.hotkey) then
        self.hotkey:delete()
    end

    local mods = mapping["toggle"][1]
    local key = mapping["toggle"][2]

    if latch_timeout then
        self.hotkey = hs.hotkey.bind(mods, key, function ()
            self:toggleMicMute()
            self.time_since_mute = hs.timer.secondsSinceEpoch()
        end, function ()
            if hs.timer.secondsSinceEpoch() > self.time_since_mute + latch_timeout then
                self:toggleMicMute()
            end
        end)
    else
        self.hotkey = hs.hotkey.bind(mods, key, function ()
            self:toggleMicMute()
        end)
    end

    return self
end

function m:init()
    m.time_since_mute = 0
    m:setMicMute(false)

    if m.showMenuBar then
        m.mute_menu = hs.menubar.new()
        m.mute_menu:setClickCallback(function ()
            m:toggleMicMute()
        end)
    end

    -- TODO need to watch anything?
    -- hs.audiodevice.watcher.setCallback(function (arg)
    --     if string.find(arg, "dIn ") then
    --         m:updateMicMute(-1)
    --     end
    -- end)
    -- hs.audiodevice.watcher.start()
end

return m
