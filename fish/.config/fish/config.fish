# Settings {{{
set fish_greeting
set -gx FZF_DEFAULT_OPTS '--height=50% --min-height=15 --reverse'
set -gx FZF_DEFAULT_COMMAND 'rg --files --no-ignore-vcs --hidden'
set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
set -gx FZF_DEFAULT_COMMAND 'fd'
set -x ENHANCD_FILTER fzy:fzf:peco
set -x EDITOR 'vim --nofork'
set -x SHELL '/usr/local/bin/fish'
set -x GOPATH ~/.go
set -gx EVENT_NOKQUEUE 1
set -gx GPG_TTY (tty)
set -x AWS_IAM_HOME /usr/local/opt/aws-iam-tools/libexec
set -x AWS_CREDENTIAL_FILEs ~/.aws-credentials-master
set -U fish_user_paths /usr/local/opt/openssl/bin $HOME/bin $HOME/.asdf/shims $HOME/.asdf/bin $HOME/.fzf/bin
set -x PATH $PATH ~/.bin ~/.go/bin /usr/local/opt/go/libexec/bin /usr/local/opt/util-linux/bin /opt/homebrew/bin
# }}}

# Abbreviations {{{

# config files
abbr zx ". ~/.config/fish/config.fish"

# git
abbr g. 'git add .'
abbr gam 'git commit -am'
abbr gc 'git commit -m'
abbr gco 'git checkout'
abbr ggo 'git checkout (git branch | grep -v "^*" | sed -E "s/^ +//" | fzf)'
abbr gd 'git diff'
abbr gl 'git log'
abbr gp 'git push'
abbr gpl 'git pull'
abbr gg 'git status'
abbr gs 'git stash'
abbr gsp 'git stash pop'
abbr gph 'git push origin HEAD'
abbr gu 'git up'

abbr r "rg --no-heading"
abbr rt "rg --no-heading -tjs"
abbr rf "rg --files | r"

abbr ports "sudo lsof -i -n -P | grep TCP"

# vim / vim-isms
abbr v "$EDITOR ."
# }}}

# Utility functions {{{
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

function fish_prompt
    # based on isacikgoz/sashimi
    set -l last_status $status
    set -l cyan (set_color -o cyan)
    set -l yellow (set_color -o yellow)
    set -g red (set_color -o red)
    set -g blue (set_color -o blue)
    set -l green (set_color -o green)
    set -g normal (set_color normal)

    set -g whitespace ' '

    if test $last_status = 0
        set initial_indicator "$green◆"
        set status_indicator "$normal❯$cyan❯$green❯"
    else
        set initial_indicator "$red✖ $last_status"
        set status_indicator "$red❯$red❯$red❯"
    end
    set -l cwd $cyan(basename (prompt_pwd))

    # Notify if a command took more than 1 minute
    if [ "$CMD_DURATION" -gt 60000 ]
        echo The last command took (math "$CMD_DURATION/1000") seconds.
    end

    if test -d .git
        # git config --local bash.showInformativeStatus false
        # set -g __fish_git_prompt_show_informative_status true
        set -g __fish_git_prompt_show_informative_status false
        set -g __fish_git_prompt_showupstream auto
        set -g __fish_git_prompt_showcolorhints true
        set -g __fish_git_prompt_char_stateseparator ' '
        set -g __fish_git_prompt_color_branch blue
        set prompt_git (fish_git_prompt | string trim -c ' ()')
        set git_info "$normal git:($prompt_git$normal)"
    end

    echo -n -s $initial_indicator $whitespace $cwd $git_info $whitespace $status_indicator $whitespace
end

# function fish_prompt --description 'Write out the prompt'
#     switch $status
#         case 0
#             set_color green
#         case 127
#             set_color yellow
#         case '*'
#             set_color red
#     end

#     set_color -od
#     echo -n '• '
#     set_color blue
#     echo -n (prompt_pwd)

#     if test (git rev-parse --git-dir 2>/dev/null)
#         set_color yellow
#         echo -n " on "
#         set_color green
#         echo -n (git status | head -1 | string split ' ')[-1]

#         if test -n (echo (git status -s))
#             set_color magenta
#         end

#         echo -n ' ⚑'
#     end

#     set_color yellow
#     echo ' ❯ '
#     set_color -normal
# end

if not functions -q fisher
    set -q XDG_CONFIG_HOME; or set XDG_CONFIG_HOME ~/.config
    curl https://git.io/fisher --create-dirs -sLo $XDG_CONFIG_HOME/fish/functions/fisher.fish
    fish -c fisher
end

function fish_user_key_bindings
    bind \eg 'test -d .git; and git checkout (string trim -- (git branch | fzf)); and commandline -f repaint'
    bind \eG 'test -d .git; and git checkout (string trim -- (git branch --all | fzf)); and commandline -f repaint'
end
# }}}


# Sourcing {{{
# macOS homebrew installs into /usr/local/share, apt uses /usr/share
[ -f /usr/local/share/autojump/autojump.fish ]; and source /usr/local/share/autojump/autojump.fish
[ -f /usr/local/share/fish/vendor_completions.d/asdf.fish ]; and source /usr/local/share/fish/vendor_completions.d/asdf.fish
[ -f /usr/local/share/fish/vendor_completions.d/brew.fish ]; and source /usr/local/share/fish/vendor_completions.d/brew.fish
[ -f /usr/local/share/fish/vendor_completions.d/brew-cask.fish ]; and source /usr/local/share/fish/vendor_completions.d/brew-cask.fish
[ -f /usr/local/share/fish/vendor_completions.d/docker-compose.fish ]; and source /usr/local/share/fish/vendor_completions.d/docker-compose.fish
[ -f /usr/local/share/fish/vendor_completions.d/fd.fish ]; and source /usr/local/share/fish/vendor_completions.d/fd.fish
[ -f /usr/local/share/fish/vendor_completions.d/rg.fish ]; and source /usr/local/share/fish/vendor_completions.d/rg.fish

# iTerm shell integration
[ -f $HOME/.iterm2_shell_integration.fish ]; and source $HOME/.iterm2_shell_integration.fish
# }}}

# TMUX {{{
# if status --is-interactive
#     and command -s tmux >/dev/null
#     and not set -q TMUX
#     exec tmux new -A -s (whoami)
# end
# }}}
