#!/bin/bash
cd "$(dirname "$0")"
git pull
git submodule sync --recursive
git submodule update --recursive --remote --init

/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

defaults write -g InitialKeyRepeat -int 10 # normal minimum is 15 (225 ms)
defaults write -g KeyRepeat -int 2 # normal minimum is 2 (30 ms)

brew install stow

stow hammerspoon
stow karabiner
