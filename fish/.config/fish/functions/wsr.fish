# ward — adopted fish shorthand `wsr` — ward session resume, arguments and all.
#
# Yours now: `ward shell adopt fish wsr` wrote it, and nothing in ward
# rewrites it unless you ask for wsr again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wsr` shows what changed, and re-running the
# adopt command takes ward's version.

function wsr --description 'ward session resume, arguments and all'
    command ward session resume $argv
end
