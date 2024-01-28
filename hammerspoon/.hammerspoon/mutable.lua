local m = {}
m.__index = obj

m.logger = hs.logger.new('crumlee.space', 'mutable')

-- Hattip: https://github.com/Hammerspoon/Spoons/blob/master/Source/MicMute.spoon/init.lua#L11

-- Metadata
m.name = "MicMute"
m.version = "0.1"
m.author = "me"
m.homepage = "https://me.com"
m.license = "MIT - https://opensource.org/licenses/MIT"

function m:updateMicMute(muted)
    if muted == -1 then
        muted = hs.audiodevice.defaultInputDevice():muted()
    end

    if muted then
        m:mute_menu:setTitle("📵 Muted")
    else
        m:mute_menu:setTitle("🎙 On")
    end
end

function doapplescript(mute)
    if mute then
        hs.osascript.applescript("set volume input volume 0")
    else
        hs.osascript.applescript("set volume input volume 8")
    end
end

function m:doapps(mute)
    local zoom = hs.application 'Zoom'
    local teams = hs.application.find("com.microsoft.teams")
    if mute then
        if zoom then
            local ok = zoom:selectMenuItem 'Mute Audio'
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    zoom:selectMenuItem 'Mute Audio'
                end)
            end
        end
        if teams then
            local ok = teams:selectMenuItem 'Mute'
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    hs.eventtap.keyStroke({ "cmd", "shift" }, "m", 0, teams)
                end)
            end
        end
    else
        if zoom then
            local ok = zoom:selectMenuItem 'Unmute Audio'
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    zoom:selectMenuItem 'Unmute Audio'
                end)
            end
        end
        if teams then
            local ok = teams:selectMenuItem 'Unmute'
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    hs.eventtap.keyStroke({ "cmd", "shift" }, "m", 0, teams)
                end)
            end
        end
    end
end

--- MicMute:toggleMicMute()
--- Method
--- Toggle mic mute on/off
---
--- Parameters:
---  * None
function m:toggleMicMute()
    local mic = hs.audiodevice.defaultInputDevice()
    local zoom = hs.application 'Zoom'
    local teams = hs.application.find("com.microsoft.teams")
    if mic:muted() then
        mic:setInputMuted(false)
        if zoom then
            local ok = zoom:selectMenuItem 'Unmute Audio'
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    zoom:selectMenuItem 'Unmute Audio'
                end)
            end
        end
        if teams then
            local ok = teams:selectMenuItem 'Unmute'
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    hs.eventtap.keyStroke({ "cmd", "shift" }, "m", 0, teams)
                    -- hs.eventtap.keyStroke({ "cmd" }, "d", 0, hs.application("Google Meet"))
                end)
            end
        end
    else
        mic:setInputMuted(true)
        if zoom then
            local ok = zoom:selectMenuItem 'Mute Audio'
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    zoom:selectMenuItem 'Mute Audio'
                end)
            end
        end
        if teams then
            local ok = teams:selectMenuItem 'Mute'
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    hs.eventtap.keyStroke({ "cmd", "shift" }, "m", 0, teams)
                end)
            end
        end
    end
    m:updateMicMute(-1)
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
    m:time_since_mute = 0
    m:mute_menu = hs.menubar.new()
    m:mute_menu:setClickCallback(function ()
        m:toggleMicMute()
    end)
    m:updateMicMute(-1)

    hs.audiodevice.watcher.setCallback(function (arg)
        if string.find(arg, "dIn ") then
            m:updateMicMute(-1)
        end
    end)
    hs.audiodevice.watcher.start()
end


function toggleMicMute()
    local zoom = hs.application 'Zoom'
    if zoom then
        local ok = zoom:selectMenuItem 'Unmute Audio'
        if not ok then
            hs.timer.doAfter(0.5, function ()
                zoom:selectMenuItem 'Unmute Audio'
            end)
        end
        if zoom then
            local ok = zoom:selectMenuItem 'Mute Audio'
            if not ok then
                hs.timer.doAfter(0.5, function ()
                    zoom:selectMenuItem 'Mute Audio'
                end)
            end
        end
    end
end

return m
