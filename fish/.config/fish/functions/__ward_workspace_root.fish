# ward — adopted fish helper `__ward_workspace_root` — resolve a workspace name — or none — to its root, and print it.
#
# Shared plumbing, not a shorthand of its own: it is written and refreshed
# alongside whichever of ward's shorthands need it (wwcd, wws).
# Yours to keep and to edit, like they are — `ward doctor` tells you when
# ward's own version has moved on, and re-adopting any of them takes it.

function __ward_workspace_root --description 'Resolve a workspace name, or none, to its root; print it'
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
    echo $target
end
