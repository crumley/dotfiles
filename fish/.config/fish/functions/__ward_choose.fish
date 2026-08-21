# ward — adopted fish helper `__ward_choose` — resolve a candidate kind to one name, or say why it can't.
#
# Shared plumbing, not a shorthand of its own: it is written and refreshed
# alongside whichever of ward's shorthands need it (wrcd, wwcd).
# Yours to keep and to edit, like they are — `ward doctor` tells you when
# ward's own version has moved on, and re-adopting any of them takes it.

function __ward_choose --description 'Resolve a candidate kind to one name, or say why not'
    set -l kind $argv[1]
    set -l prompt $argv[2]
    set -l query $argv[3]
    set -l candidates (command ward shell candidates $kind)
    if test (count $candidates) -eq 0
        echo "ward: nothing to pick from — ward knows no $kind from here" >&2
        return 1
    end
    if not __ward_picker_present
        # Degrade to a named lesser answer, never to a hang or a prompt: print
        # what could have been picked and let them name it.
        echo "ward: no picker installed — install fzf, or name one of these:" >&2
        printf '  %s\n' (string replace -a \t '  ' -- $candidates) >&2
        return 127
    end
    set -l chosen (printf '%s\n' $candidates | __ward_picker $prompt $query)
    # Backing out of the picker is a choice, not a failure: say nothing.
    test -n "$chosen"; or return 130
    echo $chosen
end
