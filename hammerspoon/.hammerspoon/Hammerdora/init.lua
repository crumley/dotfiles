--- === Hammerdora ===
---
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Hammerdora"
obj.version = "0.1"
obj.author = "crumley@gmail.com"
obj.license = "MIT"
obj.homepage = "https://github.com/Hammerspoon/Spoons"

-- Settings

-- set this to true to always show the menubar item
obj.alwaysShow = true

-- Font size for alert
obj.alertTextSize = 80

obj.logger = hs.logger.new('Hammerdora', 'debug')

function obj:init()
  self.logger.i('init')
  self.menu = hs.menubar.new(self.alwaysShow)
  self.timer = hs.timer.doEvery(hs.timer.seconds(10), 
    function(timer) 
      self:tick(timer) 
    end
  )
  self:reset()
end

function obj:start(onStart, onStop)
  if onStart ~= nil then
    self.onStart = onStart
    self.onStart()
  end

  if onStop ~= nil then
    self.onStart = onStop
  end

  self.logger.i('start/resume')
  self.startTime = os.time()
  self.stopTime = self.startTime + (25 * 60)
  self.pauseTime = nil
  self.timer:start()
  local items = {
    { title = "Pause", fn = function() self:pause() end },
    { title = "Abort", fn = function() self:reset() end }
  }
  self.menu:setMenu(items)
  self:tick()
end

function obj:isPaused()
 return self.pauseTime ~= nil
end

function obj:isIdle()
 return self.startTime == nil
end

function obj:pause()
  self.logger.i('pause')
  self.pauseTime = os.time()
  local items = {
    { title = "Resume", fn = function() self:start() end },
    { title = "Abort", fn = function() self:reset() end }
  }
  self.menu:setMenu(items)
  self.menu:setTitle("⏯️ 🍉")
end

function obj:toggle()
  self.logger.i('toggle')
  if not self:isPaused() and not self:isIdle() then
    self:pause()
  else
    self:start()
  end
end

function obj:reset()
  self.logger.i('reset')

  self.timer:stop()
  self.startTime = nil
  self.pauseTime = nil
  self.stopTime = nil

  if self.onStop ~= nil then
    self.onStop()
  end

  self.onStart = nil
  self.onStop = nil

  local items = {
    { title = "Start", fn = function() self:start() end }
  }
  self.menu:setMenu(items)
  self.menu:setTitle("🍉")
end

function obj:complete()
  self.logger.i('complete')
  hs.alert.show("🍉 Watermelon! 🍉", { textSize = self.alertTextSize }, self.alertDuration)
  hs.sound.getByName("Submarine"):play()
  hs.screen.setInvertedPolarity(true)
  hs.timer.doAfter(2, function()
      hs.sound.getByName("Submarine"):play()
      hs.screen.setInvertedPolarity(false)
  end)
  self:reset()
end

function obj:tick()
  if not self:isPaused() then
    local minutes = math.ceil((self.stopTime - os.time()) / 60)
    local title = string.format("%02dm 🍉", minutes)
    self.menu:setTitle(title)

    if os.time() >= self.stopTime then
      self:complete()
    end
  end

end

return obj