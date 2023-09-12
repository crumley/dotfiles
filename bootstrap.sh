#!/bin/bash
cd "$(dirname "$0")"
git pull
git submodule sync --recursive
git submodule update --recursive --remote --init

if hash brew 2>/dev/null; then
   echo "Skipping brew install"
else
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   echo "brew has been installed. Follow steps above to fully enable brew on the path before proceeding. Exiting."
   exit 1
fi

echo "Setting blazing fast keyrepeat..."
defaults write -g InitialKeyRepeat -int 15 # normal minimum is 15 (225 ms)
defaults write -g KeyRepeat -int 1 # normal minimum is 2 (30 ms)

defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0
defaults write com.apple.dock launchanim -bool false
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001


echo "Installing brews from Brewfile..."
brew bundle

# https://www.theguild.nl/how-to-manage-dotfiles-with-gnu-stow/
echo "Stowing configs..."
stow --dotfiles bash fish git hammerspoon home karabiner vim asdf rg ssh rclone tmux direnv atuin

echo "Install gems..."
sudo gem install tmuxinator
