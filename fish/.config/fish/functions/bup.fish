function bup --description "Upgrade brew packages"
    command -q brew; and command -q fzf; or return 1

    set -l inst (brew leaves | eval "fzf $FZF_DEFAULT_OPTS -m --header='[brew:upgrade]'")

    for prog in $inst
        brew upgrade "$prog"
    end
end
