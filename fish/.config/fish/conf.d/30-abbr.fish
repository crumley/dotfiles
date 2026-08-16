# Abbreviations. Interactive shells only -- they do nothing in a script, and
# defining ~40 of them is wasted work at the top of every non-interactive fish.

status is-interactive; or return

# config files
# Re-sourcing config.fish no longer reloads everything now that configuration is
# split across conf.d/, so this replaces the shell instead.
abbr zx 'exec fish'

# directories
abbr b3 'cd ~/Documents/brain3'

# ls -> eza. Guarded because this one shadows a real command: without eza
# installed, an unguarded abbr would break plain `ls`.
if command -q eza
    abbr ls 'eza -F -H1 --icons --group-directories-first'
end

# git
abbr g. 'git add .'
abbr gnb 'git nb rc/'
abbr gam 'git commit -am'
abbr gc 'git commit -m'
abbr gco 'git checkout'
abbr ggo 'git checkout (git branch | grep -v "^*" | sed -E "s/^ +//" | fzf)'
abbr gd 'git diff'
abbr gl 'git log'
abbr gpl 'git pull'
abbr gg 'git status'
abbr gs 'git stash'
abbr gsp 'git stash pop'
abbr gp 'git push origin HEAD'
abbr gpf 'git push -f origin HEAD'
abbr gpof 'git push origin +@:staging'
abbr grom 'git rebase origin/main'
abbr gu 'git up'
abbr mt 'git mergetool'

abbr k kubectl

# ripgrep
abbr r 'rg --no-heading'
abbr rt 'rg --no-heading -tjs -tts'
abbr rf 'rg --files | rg --no-heading'

# tmux
abbr t tmux
abbr ta 'tmux a -t'
abbr tls 'tmux ls'
abbr tn 'tmux new -s'
abbr mux tmuxinator

abbr ports 'sudo lsof -i -n -P | grep TCP'

# Chrome with a throwaway debug profile and the remote debugging port open.
# Darwin only -- `open -a` does not exist elsewhere.
if test (uname) = Darwin
    abbr fe "open -a 'Google Chrome Canary' --args --profile-directory=dev-profile --no-first-run --no-default-browser-check --user-data-dir=$HOME/.chrome-debug-user-dir --remote-debugging-port=9222"
end

# editor -- whatever 20-env.fish resolved $EDITOR to
if set -q EDITOR[1]
    abbr v "$EDITOR ."
end
