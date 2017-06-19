local hotkey = require 'hs.hotkey'
local window = require 'hs.window'
local find = import('utils/find')

local function get_window(name)
  local win = find.window.by_application_title(name)
  if win ~= nil then
    return win
  end

  return find.window.by_title(name)
end

local prev_window = nil

local function module_init()
  local mash = config:get("app_jumper.mash", { "cmd", "ctrl", "alt" })
  for key, name in pairs(config:get("app_jumper.keys", {})) do
    hotkey.bind(mash, key, function()
        local win = get_window(name)
        local current_win = window.focusedWindow()
        if win ~= nil then
            if prev_window ~= nill and win == current_win then
              prev_window:focus()
            else
              prev_window = current_win
              win:focus()
            end
        end
    end)
  end
end

return {
    init = module_init
}
