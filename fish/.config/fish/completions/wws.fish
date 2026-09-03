# ward — adopted fish completion for `wws`.
#
# Yours now: `ward shell adopt fish wws` wrote it, and nothing in ward
# rewrites it unless you ask for wws again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wws` shows what changed, and re-running the
# adopt command takes ward's version.

complete -c wws -f -a '(ward shell candidates workspaces)'
