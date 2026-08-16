# PATH.
#
# fish_add_path skips directories that do not exist and never duplicates an
# entry, so every line here is a no-op on a machine that lacks the directory.
# That is what makes this file safe on Linux.

# Homebrew, if it is installed at all. Discovered rather than hardcoded: this
# covers Apple Silicon (/opt/homebrew), Intel macOS (/usr/local) and Linuxbrew.
# HOMEBREW_PREFIX is exported so later config can locate brew-installed things
# without shelling out to `brew --prefix`.
if not set -q HOMEBREW_PREFIX
    for __prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew $HOME/.linuxbrew
        if test -x $__prefix/bin/brew
            set -gx HOMEBREW_PREFIX $__prefix
            break
        end
    end
end

if set -q HOMEBREW_PREFIX
    fish_add_path $HOMEBREW_PREFIX/bin $HOMEBREW_PREFIX/sbin
end

fish_add_path /usr/local/bin /usr/local/sbin
fish_add_path $HOME/.local/bin
fish_add_path $HOME/bin
fish_add_path $HOME/.bun/bin
