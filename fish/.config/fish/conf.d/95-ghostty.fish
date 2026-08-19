# Ghostty injects fish integration only into the first shell it launches. That
# shell may immediately hand the terminal to tmux, whose panes start fresh fish
# processes after the one-shot XDG_DATA_DIRS injection has been consumed. Load
# the documented integration manually in those panes. Restricting this to TMUX
# avoids double-loading it in Ghostty's directly launched fish.
status is-interactive; or return
set -q TMUX; or return
set -q GHOSTTY_RESOURCES_DIR; or return

set --local ghostty_fish_integration "$GHOSTTY_RESOURCES_DIR/shell-integration/fish/vendor_conf.d/ghostty-shell-integration.fish"
test -r "$ghostty_fish_integration"; or return
source "$ghostty_fish_integration"
