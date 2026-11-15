# ward — adopted fish completion for `wsr`.
#
# Yours now: `ward shell adopt fish wsr` wrote it, and nothing in ward
# rewrites it unless you ask for wsr again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wsr` shows what changed, and re-running the
# adopt command takes ward's version.

complete -c wsr -w 'ward session resume'
