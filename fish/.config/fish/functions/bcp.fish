function bcp --description "Remove brew packages"
    command -q brew; and command -q fzf; or return 1

    set -l inst (brew leaves | eval "fzf $FZF_DEFAULT_OPTS -m --header='[brew:uninstall]'")

    for prog in $inst
        brew uninstall "$prog"
    end
end
