--- === DoNotDisturb ===
---
---

local spoons = require("hs.spoons")
local logger = require("hs.logger")

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "DoNotDisturb"
obj.version = "0.1"
obj.author = "crumley@gmail.com"
obj.license = "MIT"
obj.homepage = "https://github.com/Hammerspoon/Spoons"

-- Settings

obj.logger = logger.new('DoNotDisturb', 'debug')
obj.shortcutName = "macos-focus-mode"
obj.shortcutPath = spoons.scriptPath() .. obj.shortcutName .. ".shortcut"

function obj:init()
  self.logger.i('init - installed:', self:isInstalled())
end

function obj:isInstalled()
  local shortcuts = hs.shortcuts.list()
  local focusShortcut = hs.fnutils.find(shortcuts, function (shortcut) 
    return shortcut['name'] == obj.shortcutName 
  end)

  return focusShortcut ~= nil
end

function obj:install()
  hs.execute("open " .. obj.shortcutPath)
end

function obj:enable(minutes)
  local input = minutes or "on"
  self.logger.i('enable')
  self:runShortcut(input)
end

function obj:disable()
  self.logger.i('disable')
  self:runShortcut("off")
end

function obj:runShortcut(input)
  self.logger.i('runShortcut', input)
  if self:isInstalled() then
    local task = hs.task.new("/usr/bin/shortcuts", nil, { "run", obj.shortcutName })
    task:setInput(input)
    task:start()
  else 
    self:install()
  end
end

return obj

