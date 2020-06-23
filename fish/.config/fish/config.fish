# Path to your oh-my-fish.
set --erase fish_greeting

set -x EDITOR 'gvim --nofork'
set -x SHELL '/usr/local/bin/fish'
set -x JAVA_HOME /Library/Java/JavaVirtualMachines/jdk1.8.0_11.jdk/Contents/Home
set -x MAVEN_OPTS '-Xmx512m'
set -x AWS_IAM_HOME /usr/local/opt/aws-iam-tools/libexec
set -x AWS_CREDENTIAL_FILEs ~/.aws-credentials-master
set -x GOPATH ~/.go

set -x PATH $PATH ~/bin ~/.go/bin /usr/local/opt/go/libexec/bin

function p4merge -d "merge two things"
    /opt/homebrew-cask/Caskroom/p4merge/2014.1/p4merge.app/Contents/Resources/launchp4merge $argv &
end

function diffmerge -d "merge two things"
    /Applications/DiffMerge.app/Contents/MacOS/DiffMerge $argv &
end

function ts -d "Unix timestamp to localtime"
    echo $argv | perl -nE 'say scalar localtime $_'
end

alias r="ripgrep"
alias ports "sudo lsof -i -n -P | grep TCP"

source ~/.iterm2_shell_integration.fish

if not functions -q fisher
    set -q XDG_CONFIG_HOME; or set XDG_CONFIG_HOME ~/.config
    curl https://git.io/fisher --create-dirs -sLo $XDG_CONFIG_HOME/fish/functions/fisher.fish
    fish -c fisher
end