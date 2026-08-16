function posix-source --description "Export KEY=VALUE pairs from a posix-style env file"
    for i in (cat $argv)
        set -l arr (string match -r '([A-Za-z0-9_]+)\=(.*)' -- $i)
        if test -n "$arr"
            set -gx $arr[2] $arr[3]
        end
    end
end
