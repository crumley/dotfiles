local application = require 'hs.application'

local prev_app = nil

local function jump2(name)
    curr_app = application.frontmostApplication()
    new_app = application(name)
    logger.i(name, new_app)

    if prev_app ~= nil and new_app == curr_app then
        prev_app:activate()
        prev_app = curr_app
        return
    end

    if new_app ~= nil then
        new_app:activate()
        prev_app = curr_app
    end
end

return {
    jump = jump2
}
