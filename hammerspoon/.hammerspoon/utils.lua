local utils = {}

-- Security check function for host-specific config files
local function check_config_permissions(file_path)
    local file = io.open(file_path, "r")
    if not file then
        return false, "File does not exist"
    end
    file:close()

    -- Get file info using hs.fs.attributes
    local attrs = hs.fs.attributes(file_path)
    if not attrs then
        return false, "Cannot read file attributes"
    end

    -- Check if file is owned by current user
    local whoami_output = hs.execute("whoami")
    local current_user = whoami_output:match("^([^\t]+)"):gsub("%s+$", "")

    -- Use ls -l to get owner information more reliably
    local ls_output = hs.execute(string.format("ls -l '%s'", file_path))
    local owner = ls_output:match("^[^%s]+%s+%d+%s+([^%s]+)")

    if not owner then
        return false, "Cannot determine file owner"
    end

    if owner ~= current_user then
        return false, string.format("File is not owned by current user (owner: %s, current: %s)", owner, current_user)
    end

    -- Check permissions using hs.fs.attributes
    local perms_string = attrs.permissions
    if not perms_string then
        return false, "Cannot determine file permissions"
    end

    -- Convert symbolic permissions to octal
    local mode = 0
    local perms = perms_string

    -- Owner permissions (positions 1-3)
    if perms:sub(1, 1) == "r" then
        mode = mode + 400
    end
    if perms:sub(2, 2) == "w" then
        mode = mode + 200
    end
    if perms:sub(3, 3) == "x" then
        mode = mode + 100
    end

    -- Group permissions (positions 4-6)
    if perms:sub(4, 4) == "r" then
        mode = mode + 40
    end
    if perms:sub(5, 5) == "w" then
        mode = mode + 20
    end
    if perms:sub(6, 6) == "x" then
        mode = mode + 10
    end

    -- Other permissions (positions 7-9)
    if perms:sub(7, 7) == "r" then
        mode = mode + 4
    end
    if perms:sub(8, 8) == "w" then
        mode = mode + 2
    end
    if perms:sub(9, 9) == "x" then
        mode = mode + 1
    end

    local owner_perms = math.floor(mode / 100) % 10
    local group_perms = math.floor(mode / 10) % 10
    local other_perms = mode % 10

    -- Check if file has overly permissive permissions
    if mode > 644 then
        return false, string.format("File has overly permissive permissions (%d)", mode)
    end

    -- Check if others have write permissions
    if other_perms >= 2 then
        return false, "File has write permissions for others"
    end

    -- Check if group has write permissions
    if group_perms >= 6 then
        return false, "File has write permissions for group"
    end

    return true, "OK"
end

-- Function to load host-specific settings
function utils.load_host_settings(logger)
    local hostname = hs.host.localizedName()
    local settingsFileName = string.format(".%s.hammerspoon.lua", hostname)
    local genericFileName = ".settings.lua"

    local configDir = os.getenv("HOME")

    -- Try hostname-specific file first
    local file_path = configDir .. "/" .. settingsFileName
    local is_secure, message = check_config_permissions(file_path)

    if is_secure then
        logger.i(string.format("Loading hostname-specific settings: %s", settingsFileName))
        local success, settings = pcall(dofile, file_path)
        if success then
            return settings
        else
            logger.e(string.format("Error loading %s: %s", settingsFileName, settings))
        end
    else
        logger.w(string.format("Security check failed for %s: %s", settingsFileName, message))
        logger.w(string.format("To fix: chmod 600 %s", file_path))
    end

    -- Fall back to generic settings file
    file_path = configDir .. "/" .. genericFileName
    is_secure, message = check_config_permissions(file_path)

    if is_secure then
        logger.i(string.format("Loading generic settings: %s", genericFileName))
        local success, settings = pcall(dofile, file_path)
        if success then
            return settings
        else
            logger.e(string.format("Error loading %s: %s", genericFileName, settings))
        end
    else
        logger.w(string.format("Security check failed for %s: %s", genericFileName, message))
        logger.w(string.format("To fix: chmod 600 %s", file_path))
    end

    -- If both fail, return nil
    logger.f(string.format("No secure settings files found. Tried: %s, %s", settingsFileName, genericFileName))
    return nil
end

return utils
