local hotkey = require 'hs.hotkey'
local music = import('utils/music/spotify')

local function module_init()
    local mash = config:get("lock.mash", {})
    local key = config:get("lock.key", "F13")

    hotkey.bind(mash, key, function()
        os.execute("sleep 1 && open -a ScreenSaverEngine")
        music.pause()
    end)

end

return {
    init = module_init
}
