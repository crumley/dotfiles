# Environment variables.

set -g fish_greeting

# Editor. First one actually installed wins, so this degrades on a box that has
# no VS Code. `v` (see 30-abbr.fish) expands to whatever this resolves to.
for __editor in 'code -w' nvim vim vi
    if command -q (string split -f1 ' ' -- $__editor)
        set -gx EDITOR $__editor
        break
    end
end
set -e __editor

# gpg needs to know which tty to prompt on. `tty` prints "not a tty" and fails
# in a non-interactive shell, so only ask when there is one.
if status is-interactive
    set -gx GPG_TTY (tty)
end

# fzf. This used to set FZF_DEFAULT_COMMAND twice -- `rg --files --no-ignore-vcs
# --hidden`, then plain `fd` -- so the second silently won while
# FZF_CTRL_T_COMMAND had captured the first. One command now, with the intent of
# both preserved: fd if present (it is in the Brewfile), rg as the fallback, and
# in either case include hidden files and ignore VCS ignore rules, minus .git.
set -gx FZF_DEFAULT_OPTS --reverse

if command -q fd
    set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --no-ignore-vcs --exclude .git'
else if command -q rg
    set -gx FZF_DEFAULT_COMMAND 'rg --files --no-ignore-vcs --hidden --glob !.git'
end

if set -q FZF_DEFAULT_COMMAND
    set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
end

# SSH agent: the 1Password agent socket, when it is actually there. Guarded on
# the socket existing rather than on macOS, so this neither breaks a Linux box
# with a working ssh-agent nor points at a socket that was never created.
set -l __op_agent "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if test -S "$__op_agent"
    set -gx SSH_AUTH_SOCK "$__op_agent"
end

# Kubernetes: merge every config file under ~/.kube into KUBECONFIG. Opt in with
# `set -gx FISH_KUBE true` in ~/.$FISH_HOSTNAME.fish.
if test "$FISH_KUBE" = true; and test -d $HOME/.kube
    set -l __kubeconfigs (find $HOME/.kube -type f -name '*config*' 2>/dev/null)
    if test (count $__kubeconfigs) -gt 0
        set -gx KUBECONFIG (string join : $__kubeconfigs)
    end
end
