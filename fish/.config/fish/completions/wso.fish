# ward — adopted fish completion for `wso`.
#
# Yours now: `ward shell adopt fish wso` wrote it, and nothing in ward
# rewrites it unless you ask for wso again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wso` shows what changed, and re-running the
# adopt command takes ward's version.

complete -c wso -w 'ward session observe'
