# b3 -- Obsidian vault CLI completions.
#
# Same lazy bootstrap as ward.fish (see its comments for the full reasoning):
# fish autoloads this file on the first `b3 <TAB>`, the CLI derives the rules
# from its own command tree, and nothing generated is committed. The stderr
# drop keeps a b3 too old to know `completion` from spewing usage errors into
# the first TAB.
command -q b3; or return
b3 completion fish 2>/dev/null | source
