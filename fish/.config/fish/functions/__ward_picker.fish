# ward — adopted fish helper `__ward_picker` — pick one NAME<TAB>CUE line and print its NAME.
#
# Shared plumbing, not a shorthand of its own: it is written and refreshed
# alongside whichever of ward's shorthands need it (wrcd, wwcd).
# Yours to keep and to edit, like they are — `ward doctor` tells you when
# ward's own version has moved on, and re-adopting any of them takes it.

function __ward_picker --description 'Pick one NAME<TAB>CUE line from stdin; print its NAME'
    set -l prompt $argv[1]
    set -l query $argv[2]
    # --select-1 takes the choice when the prefilled query leaves exactly one
    # candidate standing, so a near-miss Ward could not resolve still costs no
    # keystroke. No --exit-0: a query that matches nothing should leave the
    # human in the picker, editing, not drop them back with silence.
    # --with-nth shapes only what fzf DISPLAYS; what it prints on selection is
    # the whole input line, so the NAME this function promises is cut here —
    # never hand the CUE to a verb expecting a name.
    command fzf --prompt "$prompt> " --query "$query" --select-1 --no-multi \
        --delimiter \t --with-nth 1,2 | string split -m1 -f1 -- \t
end
