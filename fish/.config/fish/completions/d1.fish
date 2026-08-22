# d1 -- Day One SaaS CLI completions.
#
# Same lazy bootstrap as ward.fish (see its comments for the full reasoning):
# fish autoloads this file on the first `d1 <TAB>`, the CLI derives the rules
# from its own command tree, and nothing generated is committed. The stderr
# drop keeps a d1 too old to know `completion` from spewing usage errors into
# the first TAB.
command -q d1; or return
d1 completion fish 2>/dev/null | source
