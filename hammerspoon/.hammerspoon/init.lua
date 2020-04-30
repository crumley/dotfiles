local alert = require 'hs.alert'

import = require('utils/import')
import.clear_cache()

config = import('config')

hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.use_syncinstall = true


-- Load those Spoons
for _, v in pairs(config.spoons) do
    spoon.SpoonInstall:andUse(v, {
        start = false,
    })
end

if spoon.ReloadConfiguration then
    spoon.ReloadConfiguration:start()
end


local function catcher(event)
    if event:getFlags()['fn'] then
        keys = event:getCharacters()
        if(keys) then
            cb = config.fn_bindings[string.upper(keys)]
            if(cb) then
                cb()
                return true
            end
        end
    end
    return false
end
hs.eventtap.new({hs.eventtap.event.types.keyDown}, catcher):start()


function config:get(key_path, default)
    local root = self
    for part in string.gmatch(key_path, "[^\\.]+") do
        root = root[part]
        if root == nil then
            return default
        end
    end
    return root
end

local modules = {}

for _, v in ipairs(config.modules) do
    local module_name = 'modules/' .. v
    local module = import(module_name)

    if type(module.init) == "function" then
        module.init()
    end

    table.insert(modules, module)
end

local buf = {}

if hs.wasLoaded == nil then
    hs.wasLoaded = true
    table.insert(buf, "Hammerspoon loaded: ")
else
    table.insert(buf, "Hammerspoon re-loaded: ")
end

table.insert(buf, #modules .. " modules.")

alert.show(table.concat(buf))
