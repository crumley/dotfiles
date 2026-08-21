# wrr -- ward repo refresh, from any directory. A ward shorthand.
#
# This is a lazy stub, the functions/ twin of completions/ward.fish: the real
# definition comes from `ward shell init fish`, which defines all three
# shorthands (wrr, wrcd, wwcd) plus their helpers and completions in one pass.
# Nothing runs at shell startup, nothing generated is committed, and an
# upgraded ward is picked up by the next shell -- the stub pays ward's ~180ms
# generation cost once, on first use, then hands off to the real function.
#
# The self-erase before sourcing is load-bearing: if the layer fails to load
# (a ward too old to know `shell init`), the stub must already be gone so the
# dispatch below fails honestly instead of recursing into itself forever.
function wrr
    command -q ward
    or begin
        echo 'wrr: ward is not installed' >&2
        return 127
    end
    functions --erase wrr
    ward shell init fish 2>/dev/null | source
    if functions -q wrr
        wrr $argv
    else
        echo 'wrr: this ward cannot emit the shell layer (ward shell init fish) -- upgrade ward' >&2
        return 127
    end
end
