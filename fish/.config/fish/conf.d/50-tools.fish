# Opt-in tool integrations.
#
# Each block is off unless the matching FISH_* flag is set to "true" -- normally
# from ~/.$FISH_HOSTNAME.fish, so integrations can differ per machine. Every
# block additionally checks that the tool is actually installed, so turning a
# flag on for a host that does not have the tool is quiet rather than an error.
#
# These all install prompts, keybindings or shell hooks, so none of it is
# meaningful in a non-interactive shell.

status is-interactive; or return

# mise -- version manager (replaced asdf).
# The vendor snippet that would otherwise activate it unconditionally is opted
# out of in conf.d/05-vendor-optout.fish, which has to run unconditionally and
# so cannot live in this file (see the is-interactive guard above).
if test "$FISH_MISE" = true; and command -q mise
    mise activate fish | source
end

# direnv -- per-directory environments
#
# Homebrew's vendor_conf.d/direnv.fish has the same problem and, unlike mise's,
# offers no opt-out -- it is a bare `direnv hook fish | source`. It is suppressed
# instead by conf.d/direnv.fish in this package, which shadows it by filename.
# See that file.
if test "$FISH_DIRENV" = true; and command -q direnv
    direnv hook fish | source
end

# starship -- prompt
if test "$FISH_STARSHIP" = true; and command -q starship
    starship init fish | source
end

# atuin -- shell history. ATUIN_NOBIND stops atuin binding keys itself; ctrl-r
# is then bound in exactly one place, functions/fish_user_key_bindings.fish,
# which fish calls after this file. config.fish used to bind it twice.
if test "$FISH_ATUIN" = true; and command -q atuin
    set -gx ATUIN_NOBIND true
    atuin init fish | source
end

# zoxide -- smarter cd
if test "$FISH_ZOXIDE" = true; and command -q zoxide
    zoxide init fish | source
end
