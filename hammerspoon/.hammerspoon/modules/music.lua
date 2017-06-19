local hotkey = require 'hs.hotkey'
local music = import('utils/music/spotify')

local function module_init()
    local mash = config:get("music.mash", { "cmd", "ctrl", "alt" })
    local keys = config:get("music.keys", {
        H = "pause",
        J = "play",
        K = "previous",
        L = "next",
        U = "currentTrack"
    })

    for key, action_string in pairs(keys) do
        local music_fn = music[action_string]

        if music_fn == nil then
            error("music: " .. action_string .. " is not a valid music action")
        end

        hotkey.bind(mash, key, music_fn)
    end

end

return {
    init = module_init
}
