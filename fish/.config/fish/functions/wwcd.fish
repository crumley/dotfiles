# ward — adopted fish shorthand `wwcd` — cd to a workspace root, from any directory.
#
# Yours now: `ward shell adopt fish wwcd` wrote it, and nothing in ward
# rewrites it unless you ask for wwcd again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wwcd` shows what changed, and re-running the
# adopt command takes ward's version.

function wwcd --description 'cd to a workspace root, from any directory'
    set -l name $argv[1]
    set -l target
    if test -n "$name"
        set target (command ward workspace path $name)
    else if not __ward_picker_present
        # Nothing named and nothing to pick with: a bare `ward workspace path`
        # means the default workspace, which is the answer worth having.
        echo "ward: no picker installed — going to the default workspace" >&2
        set target (command ward workspace path)
        or return $status
    end
    if test -z "$target"
        set name (__ward_choose workspaces workspace "$name")
        or return $status
        set target (command ward workspace path $name)
        or return $status
    end
    cd $target
end
