# Host identity and per-host configuration.
#
# Runs first so that FISH_* feature flags set in ~/.$FISH_HOSTNAME.fish are in
# place before 50-tools.fish reads them.

# Derive a short hostname. scutil is preferred on Darwin because the existing
# ~/.<name>.fish files are named after LocalHostName, which is not always what
# `hostname -s` reports. Everywhere else, fall back until something answers.
if not set -q FISH_HOSTNAME; or test -z "$FISH_HOSTNAME"
    set -l __host

    if test (uname) = Darwin; and command -q scutil
        set __host (scutil --get LocalHostName 2>/dev/null)
    end

    if test -z "$__host"; and command -q hostname
        set __host (hostname -s 2>/dev/null)
    end

    if test -z "$__host"
        set __host (string split -f1 . (uname -n))
    end

    set -gx FISH_HOSTNAME $__host
end

# Per-host settings and secrets. Missing is the normal case on a fresh machine,
# so it is silent -- and, critically, not fatal. This file used to `return -1`
# here, which aborted the rest of the shell configuration entirely: no PATH, no
# abbreviations, no tools.
set -l __host_config $HOME/.$FISH_HOSTNAME.fish

if test -f $__host_config
    if my_check_config_permissions $__host_config
        source $__host_config
    else
        echo "fish: not sourcing $__host_config (see warning above)" >&2
        echo "fish: to fix: chmod 600 $__host_config" >&2
    end
end
