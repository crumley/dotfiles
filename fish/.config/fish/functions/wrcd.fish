# ward — adopted fish shorthand `wrcd` — cd to a repository's canonical checkout, from any directory.
#
# Yours now: `ward shell adopt fish wrcd` wrote it, and nothing in ward
# rewrites it unless you ask for wrcd again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wrcd` shows what changed, and re-running the
# adopt command takes ward's version.

function wrcd --description 'cd to a repository checkout, from any directory'
    set -l name $argv[1]
    set -l target
    if test -n "$name"
        # Resolution is Ward's: exact, then a unique prefix, then a unique
        # substring, across the workspaces `ward repo path` searches. Its
        # stderr is deliberately not swallowed — an inexact match or a crossed
        # workspace is an implicit input, and reading why a name did not
        # resolve just before the picker opens is the point.
        set target (command ward repo path $name)
    end
    if test -z "$target"
        set name (__ward_choose repos repo "$name")
        or return $status
        set target (command ward repo path $name)
        or return $status
    end
    cd $target
end
