[ -n "$PS1" ] && source ~/.bash_profile
export NVM_DIR="/Users/rcrumley/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

# Atlassian security config
shopt -s histappend
export HISTFILESIZE=1048576
export HISTSIZE=1048576
export HISTTIMEFORMAT="%s "
export PROMPT_COMMAND="history -a; history -c; history -r"


