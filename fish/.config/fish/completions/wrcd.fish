# wrcd -- completions, lazily. Same idiom as ward.fish beside this file: the
# ward shell layer registers completions for all three shorthands when it is
# sourced, and fish autoloads this file on the first `wrcd <TAB>`. If the
# shorthand itself already ran in this shell the layer is live and re-sourcing
# is a harmless one-time cost; the stderr drop keeps an old ward quiet.
command -q ward; or return
ward shell init fish 2>/dev/null | source
