
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

return m
