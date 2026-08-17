# Auto-attach to tmux. Numbered last because it hands the terminal over.
#
# Opt in with `set -gx FISH_TMUX true` in ~/.$FISH_HOSTNAME.fish.
#
# The guards matter more than the feature. This must not fire in a script, in a
# shell fish spawns for command substitution, inside an existing tmux session,
# or in an editor's "shell" that is not a real terminal -- any of those either
# hangs the caller or strands the session.

status is-interactive
and test "$FISH_TMUX" = true
and not set -q TMUX # already inside tmux
and not set -q INSIDE_EMACS
and not set -q VIMRUNTIME
and test "$TERM" != dumb
and isatty stdin
and isatty stdout
and command -q tmux
or return

# Not `exec tmux`: if the tmux server fails to start, exec has already replaced
# this shell and the terminal simply closes. Run it, and only leave once it has
# actually returned.
if tmux new-session -A -s (whoami)
    exit
end

echo "fish: FISH_TMUX is set but tmux would not start; continuing in a plain shell" >&2
