set -gx FISH_HOSTNAME (scutil --get LocalHostName)

if not test -f $HOME/.$FISH_HOSTNAME.fish
    echo "Warning: Host-specific config file $HOME/.$FISH_HOSTNAME.fish does not exist"
    return -1
end


[ -f $HOME/.$FISH_HOSTNAME.fish ]; and source $HOME/.$FISH_HOSTNAME.fish 

# Settings {{{
set fish_greeting
set -x EDITOR 'cursor -w'
set -gx GPG_TTY (tty)
set -gx FZF_DEFAULT_OPTS '--height=50% --min-height=15 --reverse'
set -gx FZF_DEFAULT_COMMAND 'rg --files --no-ignore-vcs --hidden'
set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
set -gx FZF_DEFAULT_COMMAND 'fd'
set -x ENHANCD_FILTER fzy:fzf:peco
set -x AWS_IAM_HOME /usr/local/opt/aws-iam-tools/libexec
set -x AWS_CREDENTIAL_FILEs ~/.aws-credentials-master
# set -x SSH_AUTH_SOCK /Users/$USER/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
set -x SSH_AUTH_SOCK ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
# }}}

# PATH {{{
fish_add_path /usr/local/bin
fish_add_path /usr/local/sbin
fish_add_path /opt/homebrew/bin
fish_add_path /opt/homebrew/sbin
fish_add_path $HOME/bin
# }}}

# Abbreviations {{{

# config files
abbr zx ". ~/.config/fish/config.fish"

# git
abbr ls 'eza -F -H1 --icons --group-directories-first'
abbr g. 'git add .'
abbr gam 'git commit -am'
abbr gc 'git commit -m'
abbr gco 'git checkout'
abbr ggo 'git checkout (git branch | grep -v "^*" | sed -E "s/^ +//" | fzf)'
abbr gd 'git diff'
abbr gl 'git log'
abbr gpl 'git pull'
abbr gg 'git status'
abbr gs 'git status'
abbr gsp 'git stash pop'
abbr gp 'git push origin HEAD'
abbr gpf 'git push -f origin HEAD'
abbr gpof 'git push origin +@:staging'
abbr grom 'git rebase origin/master'
abbr gu 'git up'
abbr mt 'git mergetool'

abbr k "kubectl"

abbr r "rg --no-heading"
abbr rt "rg --no-heading -tjs -tts"
abbr rf "rg --files | r"

abbr t "tmux"
abbr ta "tmux a -t"
abbr tls "tmux ls"
abbr tn "tmux new -t"

abbr ports "sudo lsof -i -n -P | grep TCP"

abbr fe 'open -a "Google Chrome Canary" --args --profile-directory=dev-profile --no-first-run --no-default-browser-check --user-data-dir=/Users/rcrumley/.chrome-debug-user-dir --remote-debugging-port=9222'

abbr mux "tmuxinator"

# vim / vim-isms
abbr v "$EDITOR ."
# }}}

# Utility functions {{{
function upall -d "Upgrades all the things"
    brew upgrade
    fisher update
end

function p4merge -d "merge two things"
    /opt/homebrew-cask/Caskroom/p4merge/2014.1/p4merge.app/Contents/Resources/launchp4merge $argv &
end

function diffmerge -d "merge two things"
    /Applications/DiffMerge.app/Contents/MacOS/DiffMerge $argv &
end

function ts -d "Unix timestamp to localtime"
    echo $argv | perl -nE 'say scalar localtime $_'
end

function kp --description "Kill processes"
    set -l __kp__pid ''
    set __kp__pid (ps -ef | sed 1d | eval "fzf $FZF_DEFAULT_OPTS -m --header='[kill:process]'" | awk '{print $2}')

    if test "x$__kp__pid" != "x"
        if test "x$argv[1]" != "x"
            echo $__kp__pid | xargs kill $argv[1]
        else
            echo $__kp__pid | xargs kill -9
        end
        kp
    end
end

function gcb --description "Delete git branches"
    set delete_mode '-d'

    if contains -- '--force' $argv
        set force_label ':force'
        set delete_mode '-D'
    end

    set -l branches_to_delete (git branch | sed -E 's/^[* ] //g' | fzf -m --header="[git:branch:delete$force_label]")

    if test -n "$branches_to_delete"
        git branch $delete_mode $branches_to_delete
    end
end

function bip --description "Install brew plugins"
    set -l inst (brew search | eval "fzf $FZF_DEFAULT_OPTS -m --header='[brew:install]'")

    if not test (count $inst) = 0
        for prog in $inst
            brew install "$prog"
        end
    end
end

function bup --description "Update brew plugins"
    set -l inst (brew leaves | eval "fzf $FZF_DEFAULT_OPTS -m --header='[brew:update]'")

    if not test (count $inst) = 0
        for prog in $inst
            brew upgrade "$prog"
        end
    end
end

function bcp --description "Remove brew plugins"
    set -l inst (brew leaves | eval "fzf $FZF_DEFAULT_OPTS -m --header='[brew:uninstall]'")

    if not test (count $inst) = 0
        for prog in $inst
            brew uninstall "$prog"
        end
    end
end

function posix-source
    for i in (cat $argv)
        set arr (string match -r '([A-Za-z0-9_]+)\=(.*)' $i)
        if test -n "$arr"
            set -gx $arr[2] $arr[3]
        end
    end
end

if not functions -q fisher
    set -q XDG_CONFIG_HOME; or set XDG_CONFIG_HOME ~/.config
    curl https://git.io/fisher --create-dirs -sLo $XDG_CONFIG_HOME/fish/functions/fisher.fish
    fish -c fisher
end
# }}}

if status --is-interactive
    # Sourcing {{{
    # macOS homebrew installs into /usr/local/share, apt uses /usr/share
    [ -f /usr/local/share/autojump/autojump.fish ]; and source /usr/local/share/autojump/autojump.fish
    [ -f /usr/local/share/fish/vendor_completions.d/brew.fish ]; and source /usr/local/share/fish/vendor_completions.d/brew.fish
    [ -f /usr/local/share/fish/vendor_completions.d/brew-cask.fish ]; and source /usr/local/share/fish/vendor_completions.d/brew-cask.fish
    [ -f /usr/local/share/fish/vendor_completions.d/docker-compose.fish ]; and source /usr/local/share/fish/vendor_completions.d/docker-compose.fish
    [ -f /usr/local/share/fish/vendor_completions.d/fd.fish ]; and source /usr/local/share/fish/vendor_completions.d/fd.fish
    [ -f /usr/local/share/fish/vendor_completions.d/rg.fish ]; and source /usr/local/share/fish/vendor_completions.d/rg.fish
    # }}}

    # rpk {{{
    if test "$FISH_RPK" = "true"
        command -s rpk >/dev/null; and rpk generate shell-completion fish | source
    end
    #}}}

    # asdf {{{
    if test "$FISH_ASDF" = "true"
        [ -f /usr/local/share/fish/vendor_completions.d/asdf.fish ]; and source /usr/local/share/fish/vendor_completions.d/asdf.fish
        [ -f (brew --prefix asdf)/libexec/asdf.fish ]; and source (brew --prefix asdf)/libexec/asdf.fish
        [ -f ~/.asdf/plugins/java/set-java-home.fish ]; and . ~/.asdf/plugins/java/set-java-home.fish
    end
    # }}}

    # mise {{{
    if test "$FISH_MISE" = "true"
        mise activate fish | source
    end
    #}}}

    # direnv {{{
    if test "$FISH_DIRENV" = "true"
        direnv hook fish | source
    end
    #}}}

    # iTerm shell integration {{{
    if test "$FISH_ITERM" = "true"
        [ -f $HOME/.iterm2_shell_integration.fish ]; and source $HOME/.iterm2_shell_integration.fish
    end
    # }}}

    # starship {{{
    if test "$FISH_STARSHIP" = "true"
        starship init fish | source
        [ -f /usr/local/share/fish/vendor_completions.d/starship.fish ]; and source /usr/local/share/fish/vendor_completions.d/starship.fish
    end
    #}}}

    # atuin {{{
    if test "$FISH_ATUIN" = "true"
        set -gx ATUIN_NOBIND "true"
        atuin init fish | source
        bind \cr _atuin_search
    end
    #}}}

    # dev {{{
    if test "$FISH_DEV" = "true"
        [ -f /opt/dev/dev.fish ]; and source /opt/dev/dev.fish
    end
    # }}}

    # TMUX {{{
    if test "$FISH_TMUX" = "true"
        and command -s tmux >/dev/null
        and not set -q TMUX
        exec tmux new -A -s (whoami)
    end
    # }}}

    # kube {{{
    if test "$FISH_KUBE" = "true"
        set -x KUBECONFIG (find ~/.kube -type f -name '*config*' | tr '\n' ':' | sed 's/:$//')
    end
    # }}}
end
