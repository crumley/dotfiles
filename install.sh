#!/bin/bash
cd "$(dirname "$0")"

git pull
git submodule init
git submodule sync --recursive
git submodule update --recursive --remote --init

if hash brew 2>/dev/null; then
   echo "Skipping brew install"
else
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   echo "brew has been installed. Follow steps above to fully enable brew on the path before proceeding. Exiting."
   (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/rcrumley/.zprofile
   eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "Setting MacOS settings..."
defaults write -g InitialKeyRepeat -int 15 # normal minimum is 15 (225 ms)
defaults write -g KeyRepeat -int 1 # normal minimum is 2 (30 ms)
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0
defaults write com.apple.dock launchanim -bool false
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
defaults -currentHost write -globalDomain NSStatusItemSpacing -int 12
defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 8

echo "Installing public key..."
mkdir -p $HOME/.ssh
curl -s https://github.com/crumley.keys >> $HOME/.ssh/authorized_keys

echo "(skipping)Installing brews from Brewfile..."
# brew bundle

# https://www.theguild.nl/how-to-manage-dotfiles-with-gnu-stow/
echo "Stowing configs..."
# Pre-create ~/.agents/skills so stow links only the lockfile inside it.
# Without this, stow "folds" the missing ~/.agents into a symlink to the repo
# and installed skill bodies would land inside this checkout as git noise.
mkdir -p $HOME/.agents/skills
stow --dotfiles -t ~ bash fish git hammerspoon home karabiner vim mise rg ssh rclone tmux direnv atuin espanso ghostty claude agents

# Agent skills: bodies live untracked in ~/.agents/skills; only the lockfile is
# stowed. Reinstall each locked skill from its source (the skills CLI has no
# global restore yet — `skills experimental_install` is project-scope only).
echo "Restoring agent skills..."
if [ -f $HOME/.agents/.skill-lock.json ] && command -v jq >/dev/null && command -v npx >/dev/null; then
   jq -r '.skills | to_entries[] | "\(.value.source)\t\(.key)"' $HOME/.agents/.skill-lock.json |
      while IFS=$'\t' read -r src name; do
         # </dev/null: npx must not eat the loop's stdin (it would swallow the
         # remaining lockfile lines and silently skip every skill after the first)
         npx -y skills add "$src" -s "$name" -g -y </dev/null
      done
else
   echo "(skipping — no lockfile, or jq/npx missing)"
fi

echo
echo "Done!"
