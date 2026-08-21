# wrcd -- cd to a repository checkout, from any directory. A ward shorthand.
# Lazy stub; the full reasoning lives in functions/wrr.fish beside this file.
function wrcd
    command -q ward
    or begin
        echo 'wrcd: ward is not installed' >&2
        return 127
    end
    functions --erase wrcd
    ward shell init fish 2>/dev/null | source
    if functions -q wrcd
        wrcd $argv
    else
        echo 'wrcd: this ward cannot emit the shell layer (ward shell init fish) -- upgrade ward' >&2
        return 127
    end
end
