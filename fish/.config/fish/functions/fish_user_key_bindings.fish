# The single home for key bindings. fish calls this after config sourcing and
# after the default bindings are installed, so it is the one place a binding is
# guaranteed to take effect. The old tracked config.fish bound ctrl-r twice --
# once here and once inline in the atuin block -- which is now just this.
function fish_user_key_bindings
    if test "$FISH_ATUIN" = true; and command -q atuin
        bind \cr _atuin_search
    end
end
