function bip --description "Install brew packages"
    command -q brew; and command -q fzf; or return 1

    set -l inst (brew search | eval "fzf $FZF_DEFAULT_OPTS -m --header='[brew:install]'")

    for prog in $inst
        brew install "$prog"
    end
end
