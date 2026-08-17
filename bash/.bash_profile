# ~/.bash_profile — bash login shells.
#
# The layering, which this repo used to have inverted (.bashrc sourced
# .bash_profile, so an interactive non-login shell pulled in login-only setup):
#
#   ~/.profile       environment; POSIX sh; every login shell reads it
#   ~/.bash_profile  bash login shells: this file. Pulls in ~/.profile, then
#                    hands off to ~/.bashrc when the shell is interactive.
#   ~/.bashrc        interactive bash: options, history, completion, prompt
#
# Bash reads exactly one of ~/.bash_profile, ~/.bash_login, ~/.profile at
# login, so as soon as this file exists ~/.profile is skipped unless sourced
# here by hand. That is the only reason this file has any content at all.

if [ -r "$HOME/.profile" ]; then
	# shellcheck source=/dev/null
	. "$HOME/.profile"
fi

# A login shell that is also interactive (ssh with a tty, a macOS terminal tab,
# `bash -l`) gets the interactive layer as well. A login shell that is not
# interactive (`ssh host command`, some cron and systemd setups) must not.
case $- in
	*i*)
		if [ -r "$HOME/.bashrc" ]; then
			# shellcheck source=/dev/null
			. "$HOME/.bashrc"
		fi
		;;
esac
