# ward — adopted fish completion for `wwcd`.
#
# Yours now: `ward shell adopt fish wwcd` wrote it, and nothing in ward
# rewrites it unless you ask for wwcd again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wwcd` shows what changed, and re-running the
# adopt command takes ward's version.

complete -c wwcd -f -a '(ward shell candidates workspaces)'
