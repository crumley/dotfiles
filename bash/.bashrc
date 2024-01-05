[ -n "$PS1" ] && source ~/.bash_profile
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

if [[ -f /opt/dev/dev.sh ]] ; then
	source /opt/dev/dev.sh
fi

eval "$(starship init bash)"

[[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }
[[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)