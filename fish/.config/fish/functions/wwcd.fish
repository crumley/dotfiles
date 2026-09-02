# ward — adopted fish shorthand `wwcd` — cd to a workspace root, from any directory.
#
# Yours now: `ward shell adopt fish wwcd` wrote it, and nothing in ward
# rewrites it unless you ask for wwcd again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wwcd` shows what changed, and re-running the
# adopt command takes ward's version.

function wwcd --description 'cd to a workspace root, from any directory'
    set -l target (__ward_workspace_root $argv[1])
    or return $status
    cd $target
end
