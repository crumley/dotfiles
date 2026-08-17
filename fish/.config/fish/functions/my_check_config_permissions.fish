# Security check for host-specific config files (~/.$FISH_HOSTNAME.fish).
# A file that anyone but the owner can write to is a file that can run arbitrary
# code in every shell, so refuse to source it.
function my_check_config_permissions --description "Check if config file has secure permissions"
    set -l config_file $argv[1]

    if not test -f $config_file
        return 1
    end

    set -l perms
    set -l owner

    if test (uname) = Darwin
        # BSD stat. /usr/bin/stat explicitly, so GNU coreutils earlier in PATH
        # (brew's `gstat`-as-`stat`) cannot change the flag meanings.
        set perms (/usr/bin/stat -f %Lp $config_file 2>/dev/null)
        set owner (/usr/bin/stat -f %Su $config_file 2>/dev/null)
    else if command -q stat
        # GNU coreutils stat.
        set perms (stat -c %a $config_file 2>/dev/null)
        set owner (stat -c %U $config_file 2>/dev/null)
    end

    # Fail closed: if the mode could not be read, do not source the file.
    if test -z "$perms"; or test -z "$owner"
        echo "Security warning: cannot determine permissions of $config_file"
        return 1
    end

    if test "$owner" != (whoami)
        echo "Security warning: $config_file is not owned by current user"
        return 1
    end

    # Check if file has restrictive permissions (owner read/write only, no group/other access)
    # 600 = rw------- (owner read/write, no group/other access)
    # 640 = rw-r----- (owner read/write, group read, no other access)
    # 644 = rw-r--r-- (owner read/write, group/other read)
    if test $perms -gt 644
        echo "Security warning: $config_file has overly permissive permissions ($perms)"
        echo "Recommended: chmod 600 $config_file"
        return 1
    end

    # Check if file has write permissions for group or others
    if test (math $perms % 10) -gt 0
        echo "Security warning: $config_file has write permissions for others"
        return 1
    end

    if test (math $perms / 10 % 10) -gt 4
        echo "Security warning: $config_file has write permissions for group"
        return 1
    end

    return 0
end
