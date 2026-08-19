# ~/.config/fish/config.fish
#
# Deliberately thin. Real configuration lives in conf.d/, which fish sources
# automatically, in sorted order, *before* this file:
#
#   conf.d/00-local.fish  this machine's own config -- untracked, may not exist
#   conf.d/10-path.fish   PATH (Homebrew discovered, never hardcoded)
#   conf.d/20-env.fish    environment variables
#   conf.d/30-abbr.fish   abbreviations (interactive only)
#   conf.d/50-tools.fish  the FISH_* opt-in tool integrations
#   conf.d/90-tmux.fish   FISH_TMUX auto-attach
#   conf.d/95-ghostty.fish  restore Ghostty integration inside tmux panes
#
# Functions live in functions/, one file per function, autoloaded on first use.
#
# Machine-local and third-party configuration does NOT belong in this file.
# Anything that wants to append shell setup should drop a file into
# ~/.config/fish/conf.d/ whose name does not start with two digits -- e.g.
# conf.d/local.fish. Those are gitignored by design, so an installer that
# appends to your shell config can never again cause repo drift.
#
# Secrets and per-machine settings belong in conf.d/00-local.fish, which is
# gitignored and therefore never leaves this machine. It sorts first, so the
# FISH_* flags it sets are in place before 50-tools.fish reads them. There is no
# indirection through ~/.$hostname.fish any more and no hostname to derive: the
# file is either there or it is not, and fish sources it like any other fragment.
