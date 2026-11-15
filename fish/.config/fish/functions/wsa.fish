# ward — adopted fish shorthand `wsa` — attach to a session — with no id, the coordinator, opened first if none is.
#
# Yours now: `ward shell adopt fish wsa` wrote it, and nothing in ward
# rewrites it unless you ask for wsa again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wsa` shows what changed, and re-running the
# adopt command takes ward's version.

function wsa --description 'Attach to a session: with no id, the coordinator, opened first if none is'
    # An id goes straight through: attach joins a live window, and re-creates
    # one that has ended or gone, from its record.
    if test (count $argv) -gt 0
        command ward session attach $argv
        return $status
    end
    set -l open (command ward shell candidates coordinators)
    if test (count $open) -eq 0
        # Nothing to join: open the coordinator detached, then join it. tmux
        # is checked first because without it --detach falls back to the
        # foreground, and attaching after that run exits would start it again.
        if not command -q tmux
            echo "ward: wsa hosts the coordinator in tmux, which is not installed — install it, or run: ward session open" >&2
            return 127
        end
        command ward session open --detach
        or return $status
        set open (command ward shell candidates coordinators)
    end
    set -l id
    if test (count $open) -eq 1
        set id (string split -m1 -f1 -- \t $open[1])
    else if test (count $open) -gt 1
        # Several coordinators open: which one is a choice, so ask for it.
        set id (__ward_choose coordinators coordinator '')
        or return $status
    end
    if test -z "$id"
        echo "ward: no coordinator answers here — see: ward status" >&2
        return 1
    end
    command ward session attach $id
end
