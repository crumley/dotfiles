# wwcd -- cd to a workspace root, from any directory. A ward shorthand.
# Lazy stub; the full reasoning lives in functions/wrr.fish beside this file.
function wwcd
    command -q ward
    or begin
        echo 'wwcd: ward is not installed' >&2
        return 127
    end
    functions --erase wwcd
    ward shell init fish 2>/dev/null | source
    if functions -q wwcd
        wwcd $argv
    else
        echo 'wwcd: this ward cannot emit the shell layer (ward shell init fish) -- upgrade ward' >&2
        return 127
    end
end
