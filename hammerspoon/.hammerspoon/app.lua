local application = require 'hs.application'

local prev_app = nil
local prev_win = nil

local function jump2(name)
    curr_app = application.frontmostApplication()
    curr_win = curr_app:focusedWindow()

    new_app = application(name)
    new_win = new_app:focusedWindow()

    -- Is new_app really a hs.window?
    if new_app["focus"] ~= nil then
        new_win = new_app
        new_app = new_win:application()
    end

    logger.i('Switcher start', name)
    logger.i('curr_app', curr_app)
    logger.i('curr_win', curr_win)
    logger.i('new_app', new_app)
    logger.i('new_win', new_win)

    if prev_win ~= nil and new_win == curr_win  then
        prev_win:focus()
        prev_app = curr_app
        prev_win = curr_win
        return
    end

    if new_win ~= nil then
        new_win:focus()
        prev_app = curr_app
        prev_win = curr_win
    end
end

return {
    jump = jump2
}
