
logger = hs.logger.new('crumlee.config','debug')

hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.use_syncinstall = true

hs.application.enableSpotlightForNameSearches(true)

local config = require('config')

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