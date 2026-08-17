function kp --description "Kill processes"
    if not command -q fzf
        echo "kp: fzf is required" >&2
        return 1
    end

    set -l __kp__pid (ps -ef | sed 1d | eval "fzf $FZF_DEFAULT_OPTS -m --header='[kill:process]'" | awk '{print $2}')

    if test -n "$__kp__pid"
        if test -n "$argv[1]"
            echo $__kp__pid | xargs kill $argv[1]
        else
            echo $__kp__pid | xargs kill -9
        end
        kp $argv
    end
end
