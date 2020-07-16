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

    # Notify if a command took more than 5 minutes
    if [ "$CMD_DURATION" -gt 300000 ]
        echo The last command took (math "$CMD_DURATION/1000") seconds.
    end

    if test -d .git
        set -g __fish_git_prompt_show_informative_status true
        set -g __fish_git_prompt_showupstream auto
        set -g __fish_git_prompt_showcolorhints true
        set -g __fish_git_prompt_char_stateseparator ' '
        set -g __fish_git_prompt_color_branch blue
        set prompt_git (fish_git_prompt | string trim -c ' ()')
        set git_info "$normal git:($prompt_git$normal)"
    end

    echo -n -s $initial_indicator $whitespace $cwd $git_info $whitespace $status_indicator $whitespace
end