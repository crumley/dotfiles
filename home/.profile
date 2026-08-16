# ~/.profile — the environment layer.
#
# Read by POSIX login shells (sh, dash, ksh), by display managers, and by
# ~/.bash_profile, which sources it explicitly. Fish does not read this file;
# its equivalent lives in fish/.config/fish/config.fish.
#
# Rules for this file:
#   * POSIX sh only. It must parse under dash — no [[ ]], no arrays, no local.
#   * Environment only: no aliases, no prompt, no shell options.
#   * Print nothing, ever. This runs before a terminal necessarily exists, and
#     stray output breaks scp/rsync and some display-manager logins.
#   * Stay idempotent: ~/.bashrc sources this too when no login shell has.

# Prepend to PATH, but only for directories that exist and are not there yet.
_path_prepend() {
	[ -d "$1" ] || return 0
	case ":${PATH}:" in
		*":$1:"*) return 0 ;;
	esac
	PATH="$1${PATH:+:${PATH}}"
}

# Homebrew, wherever this machine keeps it: Apple Silicon macOS, Intel macOS,
# system Linuxbrew, per-user Linuxbrew — or nowhere, which is fine too.
# `brew shellenv` sets HOMEBREW_PREFIX and the PATH/MANPATH/INFOPATH entries,
# so it must not be hardcoded to /opt/homebrew the way this file used to be.
if [ -z "${HOMEBREW_PREFIX:-}" ]; then
	for _brew_prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew "$HOME/.linuxbrew"; do
		if [ -x "$_brew_prefix/bin/brew" ]; then
			eval "$("$_brew_prefix/bin/brew" shellenv)"
			break
		fi
	done
	unset _brew_prefix
fi

# Personal bins. ~/.local/bin is the XDG-ish convention pip, pipx, cargo and
# most Linux installers use; ~/bin is the older habit.
_path_prepend "$HOME/.local/bin"
_path_prepend "$HOME/bin"
export PATH

# Prefer a UTF-8 locale, but only claim one the system has actually generated.
# en_US.UTF-8 always exists on macOS; a minimal Linux image often ships only
# C.UTF-8, and exporting a locale that is not generated makes perl, python and
# ncurses complain on every invocation. LC_ALL is deliberately not set: it
# overrides every category at once and leaves no way to vary one of them.
if [ -z "${LANG:-}" ] || [ "${LANG}" = "C" ] || [ "${LANG}" = "POSIX" ]; then
	if command -v locale >/dev/null 2>&1; then
		_available_locales=$(locale -a 2>/dev/null)
		case "${_available_locales}" in
			*en_US.UTF-8*|*en_US.utf8*) LANG=en_US.UTF-8; export LANG ;;
			*C.UTF-8*|*C.utf8*) LANG=C.UTF-8; export LANG ;;
		esac
		unset _available_locales
	else
		LANG=en_US.UTF-8
		export LANG
	fi
fi

# An editor that exists on this box. Fish sets EDITOR to the GUI editor; a
# login shell on a headless Linux host needs something that opens in a tty.
if [ -z "${EDITOR:-}" ]; then
	for _editor in nvim vim vi; do
		if command -v "$_editor" >/dev/null 2>&1; then
			EDITOR=$_editor
			export EDITOR
			break
		fi
	done
	unset _editor
fi

# Machine-local environment that is not committed: tokens, per-host paths,
# anything private. POSIX sh only — this file is sourced by dash too.
if [ -r "$HOME/.profile.local" ]; then
	# shellcheck source=/dev/null
	. "$HOME/.profile.local"
fi

# Marker so ~/.bashrc can tell whether this layer has already run.
DOTFILES_PROFILE_SOURCED=1
export DOTFILES_PROFILE_SOURCED
