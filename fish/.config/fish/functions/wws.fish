# ward — adopted fish shorthand `wws` — open a session in a workspace — cd to its root and start the agent there.
#
# Yours now: `ward shell adopt fish wws` wrote it, and nothing in ward
# rewrites it unless you ask for wws again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wws` shows what changed, and re-running the
# adopt command takes ward's version.

function wws --description 'Open a session in a workspace: cd to its root and start the agent there'
    # The first argument names the workspace unless it is a flag; everything
    # after it goes to `ward session open` untouched, so
    # `wws main --purpose TEXT` says what the session is for.
    set -l name
    if test (count $argv) -gt 0; and not string match -q -- '-*' $argv[1]
        set name $argv[1]
        set -e argv[1]
    end
    set -l target (__ward_workspace_root $name)
    or return $status
    # cd in the calling shell, not a subshell: when the agent exits you are
    # standing in the workspace, exactly where wwcd would have left you.
    cd $target
    or return $status
    command ward session open $argv
end
