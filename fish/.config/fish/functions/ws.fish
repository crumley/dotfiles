# ward — adopted fish shorthand `ws` — ward status, arguments and all.
#
# Yours now: `ward shell adopt fish ws` wrote it, and nothing in ward
# rewrites it unless you ask for ws again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish ws` shows what changed, and re-running the
# adopt command takes ward's version.

function ws --description 'ward status: where everything stands'
    command ward status $argv
end
