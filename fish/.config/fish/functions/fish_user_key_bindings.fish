# The single home for key bindings. fish calls this after config sourcing and
# after the default bindings are installed, so it is the one place a binding is
# guaranteed to take effect. config.fish used to bind ctrl-r twice -- once here
# and once inline in the atuin block -- which is now reconciled to just this.
function fish_user_key_bindings
    if test "$FISH_ATUIN" = true; and command -q atuin
        bind \cr _atuin_search
    end
end
