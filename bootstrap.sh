#!/bin/bash
cd "$(dirname "$0")"
git pull
git submodule sync --recursive
git submodule update --recursive --remote --init

if hash brew 2>/dev/null; then
   echo "Skipping brew install"
else
   /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo "Setting blazing fast keyrepeat..."
defaults write -g InitialKeyRepeat -int 15 # normal minimum is 15 (225 ms)
defaults write -g KeyRepeat -int 1 # normal minimum is 2 (30 ms)

echo "Installing brews from Brewfile..."
brew bundle

# https://www.theguild.nl/how-to-manage-dotfiles-with-gnu-stow/
echo "Stowing configs..."
stow --dotfiles bash fish git hammerspoon home karabiner term vim

echo "Install gems..."
gem install tmuxinator