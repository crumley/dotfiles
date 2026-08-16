# ~/.config/fish/config.fish
#
# Deliberately thin. Real configuration lives in conf.d/, which fish sources
# automatically, in sorted order, *before* this file:
#
#   conf.d/00-host.fish   hostname derivation + ~/.$FISH_HOSTNAME.fish
#   conf.d/10-path.fish   PATH (Homebrew discovered, never hardcoded)
#   conf.d/20-env.fish    environment variables
#   conf.d/30-abbr.fish   abbreviations (interactive only)
#   conf.d/50-tools.fish  the FISH_* opt-in tool integrations
#   conf.d/90-tmux.fish   FISH_TMUX auto-attach, last because it may exec
#
# Functions live in functions/, one file per function, autoloaded on first use.
#
# Machine-local and third-party configuration does NOT belong in this file.
# Anything that wants to append shell setup should drop a file into
# ~/.config/fish/conf.d/ whose name does not start with two digits -- e.g.
# conf.d/local.fish. Those are gitignored by design, so an installer that
# appends to your shell config can never again cause repo drift.
#
# Secrets and per-host settings belong in ~/.$FISH_HOSTNAME.fish (chmod 600).
