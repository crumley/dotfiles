# ward — adopted fish shorthand `wsa` — attach to a session — the coordinator, a floor N, or an id — opened first if none is.
#
# Yours now: `ward shell adopt fish wsa` wrote it, and nothing in ward
# rewrites it unless you ask for wsa again by name. Track it, edit it,
# keep it. When ward's own definition moves on, `ward doctor` says so —
# `ward shell diff fish wsa` shows what changed, and re-running the
# adopt command takes ward's version.

function wsa --description 'Attach to a session: the coordinator, a floor N, or an id — opened first if none is'
    # A floor number means that floor's own session; anything else is an id,
    # which goes straight through: attach joins a live window, and re-creates
    # one that has ended or gone, from its record.
    set -l feed coordinators
    set -l scope
    set -l label coordinator
    if test (count $argv) -gt 0
        if string match -qr '^[0-9]+$' -- $argv[1]
            set feed coordinators --floor $argv[1]
            set scope --floor $argv[1]
            set label "floor $argv[1] session"
        else
            command ward session attach $argv
            return $status
        end
    end
    set -l open (command ward shell candidates $feed)
    if test (count $open) -eq 0
        # Nothing to join: open one detached, then join it. tmux is checked
        # first because without it --detach falls back to the foreground, and
        # attaching after that run exits would start it again.
        if not command -q tmux
            echo "ward: wsa hosts the $label in tmux, which is not installed — install it, or run: ward session open $scope" >&2
            return 127
        end
        command ward session open $scope --detach
        or return $status
        set open (command ward shell candidates $feed)
    end
    set -l id
    if test (count $open) -eq 1
        set id (string split -m1 -f1 -- \t $open[1])
    else if test (count $open) -gt 1
        # Several open: which one is a choice, so ask for it — or, with no
        # picker, name them, exactly as __ward_choose degrades.
        if not __ward_picker_present
            echo "ward: no picker installed — install fzf, or name one of these:" >&2
            printf '  %s\n' (string replace -a \t '  ' -- $open) >&2
            return 127
        end
        set id (printf '%s\n' $open | __ward_picker $label '')
        # Backing out of the picker is a choice, not a failure: say nothing.
        test -n "$id"; or return 130
    end
    if test -z "$id"
        echo "ward: no $label answers here — see: ward status" >&2
        return 1
    end
    command ward session attach $id
end
