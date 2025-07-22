# Security check function for host-specific config files
function my_check_config_permissions --description "Check if config file has secure permissions"
    set -l config_file $argv[1]
    
    if not test -f $config_file
        return 1
    end
    
    # Get file permissions (octal)
    set -l perms (stat -f %Lp $config_file)
    
    # Check if file is owned by current user
    set -l owner (stat -f %Su $config_file)
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