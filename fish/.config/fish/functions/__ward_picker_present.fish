# ward — adopted fish helper `__ward_picker_present` — whether an interactive picker is installed.
#
# Shared plumbing, not a shorthand of its own: it is written and refreshed
# alongside whichever of ward's shorthands need it (wrcd, wwcd).
# Yours to keep and to edit, like they are — `ward doctor` tells you when
# ward's own version has moved on, and re-adopting any of them takes it.

function __ward_picker_present --description 'Whether an interactive picker is installed'
    command -q fzf
end
