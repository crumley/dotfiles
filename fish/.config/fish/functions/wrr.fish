# ward — adopted fish shorthand `wrr` — ward repo refresh, arguments and all, from any directory.
#
# Yours now: `ward shell adopt fish wrr` wrote it, and nothing in ward
# rewrites it unless you ask for wrr again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wrr` shows what changed, and re-running the
# adopt command takes ward's version.

function wrr --description 'ward repo refresh, from any directory'
    command ward repo refresh $argv
end
