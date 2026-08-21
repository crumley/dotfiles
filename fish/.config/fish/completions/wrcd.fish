# ward — adopted fish completion for `wrcd`.
#
# Yours now: `ward shell adopt fish wrcd` wrote it, and nothing in ward
# rewrites it unless you ask for wrcd again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wrcd` shows what changed, and re-running the
# adopt command takes ward's version.

complete -c wrcd -f -a '(ward shell candidates repos)'
