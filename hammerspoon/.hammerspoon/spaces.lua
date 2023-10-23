
local m = {}
m.logger = hs.logger.new('crumlee.space', 'debug')

m.managedSpaces = {}
m.focus = nil

function m:init()
end

function newSpaceRecord(space)
    local now = os.time()
    return {
        updated = now,
        created = now,
        space = space,
        windows = {}
    }
end

function addWindow(record, window)
    table.insert( record["windows"], window )
    hs.spaces.moveWindowToSpace(window, record["space"])
end

function m:newManagedSpace()
    local screenId = hs.screen.primaryScreen():getUUID()
    hs.spaces.addSpaceToScreen(screenId)
    local spaces = hs.spaces.allSpaces()[screenId]
    local newSpace = spaces[#spaces]
    local record = newSpaceRecord(newSpace)
    table.insert( self.managedSpaces, record )
    return record
end

function m:setFocusedRecord(record)
    self.focus = record
end

function m:hasCurrentFocus()
    return self.focus ~= nil
end

function m:isPrimarySpace()
    local screenId = hs.screen.primaryScreen():getUUID()
    local firstSpaceId = hs.spaces.allSpaces()[screenId][1]
    local currentSpaceId = hs.spaces.focusedSpace()
    return firstSpaceId == currentSpaceId
end

function m:focusCurrentWindow()
    if not m:isPrimarySpace() then
        local window = hs.window.focusedWindow()
        local screenId = hs.screen.primaryScreen():getUUID()
        local firstSpaceId = hs.spaces.allSpaces()[screenId][1]
        hs.spaces.moveWindowToSpace(window, firstSpaceId)

        -- Currently not working, "empty" space has windows
        -- local currentSpace = hs.spaces.focusedSpace()
        -- local windows = hs.spaces.windowsForSpace(currentSpace)
        -- print(hs.inspect(currentSpace))
        -- print(hs.inspect(windows))
        -- if next(windows) == nil then
        --     hs.spaces.removeSpace(currentSpace)
        -- end 
        return
    end

    if not self:hasCurrentFocus() then
        local record = self:newManagedSpace()
        self:setFocusedRecord(record)
        -- Clear out the focus after a minute under the assumption the focus space has complete
        -- and future window additions should go to a new focus space
        hs.timer.doAfter(60, function() 
            self:setFocusedRecord(nil)
        end)
    end
    
    local window = hs.window.focusedWindow()
    addWindow( self.focus, window )
end

function m:clearCurrentSpace()
    local screenId = hs.screen.primaryScreen():getUUID()
    local targetSpaceId = hs.spaces.allSpaces()[screenId][1]
    local sourceSpaceId = hs.spaces.focusedSpace()

    local windows = hs.spaces.windowsForSpace(sourceSpaceId)

    hs.fnutils.each( windows, function (w) 
        hs.spaces.moveWindowToSpace(w, targetSpaceId)
    end)
end

function m:removeAllSpaces()
    local screenId = hs.screen.primaryScreen():getUUID()
    local firstSpaceId = hs.spaces.allSpaces()[screenId][1]

    if not m:isPrimarySpace() then 
        hs.spaces.gotoSpace(firstSpaceId)
    end

    hs.timer.doAfter(2, function()  
        hs.fnutils.ieach( hs.spaces.allSpaces()[screenId], function (s) 
            if s ~= firstSpaceId then
                r = hs.spaces.removeSpace(s, false)
            end
        end)
        hs.spaces.closeMissionControl()
    end)
end

function m:enableHideDock()
    -- Hattip: https://apple.stackexchange.com/questions/419028/disable-the-dock-in-all-but-one-desktop-space-only
    local w = hs.spaces.watcher.new(function(s)
        m:_onSpaceChanged(true)
    end)
    w.start(w)
    m:_onSpaceChanged(true)
end

function m:toggleDock()
    hs.eventtap.keyStroke({"cmd", "alt"}, "d")
end

function m:_isDockHidden()
    local asCommand = "tell application \"System Events\" to return autohide of dock preferences"
    local ok, isDockHidden = hs.osascript.applescript(asCommand)

    if not ok then
        local msg = "An error occurred getting the value of autohide for the Dock."
        hs.notify.new({title="Hammerspoon", informativeText=msg}):send()
    end

    return isDockHidden
end

function m:_onSpaceChanged(checkTwice)
    local isDockHidden = m:_isDockHidden()

    if m:isPrimarySpace() and isDockHidden then
        m:toggleDock()
    end

    if not m:isPrimarySpace() and not isDockHidden then
        m:toggleDock()
    end

    -- Check once more after spaces settle...
    if checkTwice then
        hs.timer.doAfter(1, function() 
            self:_onSpaceChanged(false)
        end)
    end
end

return m
