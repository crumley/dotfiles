local prev_app = nil
local prev_win = nil

local logger = hs.logger.new('jump2','debug')

local function jump2(name)
    local curr_app = hs.application.frontmostApplication()
    local curr_win = nil
    if curr_app ~= nil then
        curr_win = curr_app:focusedWindow()
    end

    local new_app = hs.application(name)
    local new_win = nil

    if new_app == nil then
        new_app = find(name)
    end

    if new_app == nil then
        logger.e( 'Unable to find new app', name)
        return
    end

    -- Is new_app really a hs.window?
    if new_app["focus"] ~= nil then
        new_win = new_app
        new_app = new_win:application()
    else
        new_win = new_app:focusedWindow()
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

function find(name)
    return hs.fnutils.find(
        hs.window.filter.new(true):getWindows(hs.window.sortByFocusedLast),
        function (w) return string.find(w:title(), name) ~= nil end
    )
end

return {
    jump = jump2
}

