# ~/.bashrc — interactive bash.
#
# Fish is the primary shell on macOS, but bash is the default login shell on
# most Linux boxes: it is what ssh lands you in, what runs before fish, and
# what a fresh machine gives you when fish is not installed yet. This file aims
# to be a competent, portable, minimal fallback — not a second fish.
#
# See ~/.bash_profile for the layering. In short: ~/.profile holds the
# environment, this file holds everything that only makes sense with a keyboard
# attached.
#
# Must run under bash 3.2 (macOS /bin/bash) as well as bash 5.x (Linux,
# Homebrew), and must work with no Homebrew, no starship, no fzf and no mise.

# Not interactive? Do nothing — and above all print nothing. scp, sftp and
# rsync parse the remote shell's output, and a single stray byte here breaks
# them with a confusing "protocol error".
case $- in
	*i*) ;;
	*) return ;;
esac

# Interactive non-login shells (a new terminal tab on Linux, a tmux pane, most
# desktop terminal emulators) never read ~/.bash_profile, so the environment
# layer has to be reachable from here too. ~/.profile is idempotent; the marker
# just avoids re-running `brew shellenv` on every new shell.
if [ -z "${DOTFILES_PROFILE_SOURCED:-}" ] && [ -r "$HOME/.profile" ]; then
	# shellcheck source=/dev/null
	. "$HOME/.profile"
fi

# Shell behaviour {{{

shopt -s histappend   # append to the history file instead of overwriting it
shopt -s checkwinsize # keep LINES/COLUMNS correct after a window resize
shopt -s cdspell      # autocorrect small typos in `cd` arguments
shopt -s nocaseglob   # case-insensitive pathname expansion

# bash 4+ only. macOS still ships 3.2 as /bin/bash, where these do not exist
# and `shopt -s` would print an error, hence the redirect.
#   autocd   — `cd` is implied when a command is a directory name
#   globstar — `**` matches across directories
for _option in autocd globstar; do
	shopt -s "$_option" 2>/dev/null
done
unset _option

# }}}

# History {{{

HISTCONTROL=ignoreboth # drop duplicates and anything typed with a leading space
HISTSIZE=100000
HISTFILESIZE=200000
HISTTIMEFORMAT='%F %T '
HISTIGNORE='ls:ll:la:cd:pwd:exit:clear:history'

# }}}

# Aliases {{{

# Colour flags differ by implementation: GNU coreutils uses --color, BSD/macOS
# ls uses -G. Probe once rather than branching on uname.
if ls --color=auto >/dev/null 2>&1; then
	alias ls='ls --color=auto'
else
	alias ls='ls -G'
fi
alias ll='ls -lh'
alias la='ls -lha'

# }}}

# Completion {{{

# bash-completion, wherever this machine keeps it: Homebrew's
# bash-completion@2, the modern Linux path, then the legacy Linux path.
# BASH_COMPLETION_VERSINFO is set by v2; the guard keeps a re-source cheap.
if [ -z "${BASH_COMPLETION_VERSINFO:-}" ]; then
	for _bash_completion in \
		"${HOMEBREW_PREFIX:-/nonexistent}/etc/profile.d/bash_completion.sh" \
		/usr/share/bash-completion/bash_completion \
		/etc/bash_completion; do
		if [ -r "$_bash_completion" ]; then
			# shellcheck source=/dev/null
			. "$_bash_completion"
			break
		fi
	done
	unset _bash_completion
fi

# Complete ssh/scp/sftp with the hosts named in ~/.ssh/config, skipping
# patterns. awk (not grep|grep|cut) so `Host alpha beta` yields both names.
if [ -r "$HOME/.ssh/config" ]; then
	complete -o default -o nospace \
		-W "$(awk 'tolower($1) == "host" { for (i = 2; i <= NF; i++) if ($i !~ /[*?!]/) print $i }' "$HOME/.ssh/config" 2>/dev/null)" \
		scp sftp ssh
fi

# Darwin-only completions. $OSTYPE is a bash builtin variable, so this costs no
# fork, and on Linux neither command exists in the first place.
case "$OSTYPE" in
	darwin*)
		complete -W "NSGlobalDomain" defaults
		complete -o nospace \
			-W "Calendar Contacts Dock Finder Mail Messages Music Notes Photos Safari SystemUIServer Terminal" \
			killall
		;;
esac

# }}}

# Tools, each optional {{{

# mise manages runtimes for this account (fish activates it under FISH_MISE).
if command -v mise >/dev/null 2>&1; then
	eval "$(mise activate bash)"
fi

# fzf key bindings and completion. `fzf --bash` is fzf >= 0.48; ~/.fzf.bash is
# what fzf's old install script wrote and may still exist on an older box.
if command -v fzf >/dev/null 2>&1; then
	if _fzf_init=$(fzf --bash 2>/dev/null); then
		eval "$_fzf_init"
	elif [ -r "$HOME/.fzf.bash" ]; then
		# shellcheck source=/dev/null
		. "$HOME/.fzf.bash"
	fi
	unset _fzf_init
fi

# Prompt: starship when it is installed (config in the starship stow package),
# otherwise a small dependency-free prompt. This used to be an unguarded eval,
# which errored on every machine without starship.
if command -v starship >/dev/null 2>&1; then
	eval "$(starship init bash)"
else
	PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
fi

# }}}

# Machine-local interactive extras that are not committed: aliases, functions,
# host-specific bits. (~/.path, ~/.bash_prompt, ~/.exports, ~/.aliases and
# ~/.functions were sourced here in the inherited upstream config; none of them
# has ever existed in this repo, so the hook is now this one file plus
# ~/.profile.local for environment.)
if [ -r "$HOME/.extra" ]; then
	# shellcheck source=/dev/null
	. "$HOME/.extra"
fi
