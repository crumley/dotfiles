# ward — adopted fish completion for `wsa`.
#
# Yours now: `ward shell adopt fish wsa` wrote it, and nothing in ward
# rewrites it unless you ask for wsa again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wsa` shows what changed, and re-running the
# adopt command takes ward's version.

complete -c wsa -w 'ward session attach'
