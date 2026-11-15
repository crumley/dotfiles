# ward — adopted fish shorthand `wsc` — ward session close.
#
# Yours now: `ward shell adopt fish wsc` wrote it, and nothing in ward
# rewrites it unless you ask for wsc again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wsc` shows what changed, and re-running the
# adopt command takes ward's version.

function wsc --description 'ward session close'
    command ward session close $argv
end
