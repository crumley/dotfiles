# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **macOS dotfiles repository** using GNU Stow for modular deployment. Each tool/application has its own directory with dot-prefixed files that Stow symlinks to `$HOME`.

**Key characteristics:**
- Fish is the primary shell (much more extensive than bash config)
- Uses mise (not asdf) for version management
- Hammerspoon provides extensive window management and automation
- Host-specific secrets live in `~/.{hostname}.*` files (not in repo)
- Git submodules manage Hammerspoon Spoons (custom plugins)

## Installation & Deployment

### Initial setup
```bash
./install.sh
```

This script:
1. Updates git repo and all submodules recursively
2. Installs Homebrew if needed
3. Sets macOS system preferences (keyboard repeat, dock animations, etc.)
4. Installs packages from Brewfile
5. Uses Stow to symlink all configs: `stow --dotfiles -t ~ bash fish git hammerspoon ...`
6. Installs tmuxinator gem

### Update all packages
```bash
./upgrade.sh    # Updates brew packages and regenerates Brewfile.lock.json
```

### Deploy configuration changes
After editing configs, re-stow the specific directory:
```bash
stow --dotfiles -t ~ <directory>    # e.g., fish, git, hammerspoon
```

To unstow (remove symlinks):
```bash
stow -D -t ~ <directory>
```

### Update Brewfile with currently installed packages
```bash
brew bundle dump --force    # Regenerates Brewfile from current state
```

## Working with Git Submodules

All Hammerspoon Spoons are git submodules. When working with them:

```bash
# Update all submodules to latest
git submodule update --recursive --remote

# Update specific submodule
cd hammerspoon/.hammerspoon/Spoons/SpaceManager.spoon
git pull origin main
cd ../../../..
git add hammerspoon/.hammerspoon/Spoons/SpaceManager.spoon
git commit -m "Update SpaceManager to latest"
```

## Architecture

### Stow Directory Structure
```
dotfiles/
├── <tool-name>/               # e.g., fish, git, hammerspoon
│   ├── .config/<tool>/...     # becomes ~/.config/<tool>/
│   └── .<dotfile>             # becomes ~/.<dotfile>
```

**Currently managed configs:**
bash, fish, git, hammerspoon, karabiner, vim, asdf, rg, ssh, rclone, tmux, direnv, atuin, espanso, ghostty, claude

### Host-Specific Configuration Pattern

Several configs load host-specific files with strict security checks:

**Fish shell:** `~/.{hostname}.fish`
```fish
# Must have 600 permissions and be owned by current user
# Checked by my_check_config_permissions function
```

**Hammerspoon:** `~/.{hostname}.hammerspoon.lua`
```lua
-- Loaded by utils.load_host_settings(logger)
-- Same security validation as fish
```

These files should contain:
- Machine-specific paths
- API keys and secrets
- Private configuration

### Fish Shell Architecture

**Entry point:** `fish/.config/fish/config.fish`

**Conditional feature system** - Set these env vars to enable/disable:
- `FISH_ATUIN` - Atuin history search
- `FISH_STARSHIP` - Starship prompt
- `FISH_TMUX` - Auto-start tmux
- `FISH_MISE` - Mise version manager
- `FISH_DIRENV` - Directory environments
- `FISH_DEV` - Shopify dev tool
- `FISH_KUBE` - Kubernetes config

**Plugin manager:** Fisher with 7 plugins:
- fish-abbreviation-tips, fzf integration, gitnow, bass, fish-fzy, kubectl completions

**Key abbreviations** (see config.fish:39-84):
- `gg` → git status
- `gp` → git push origin HEAD
- `grom` → git rebase origin/master
- `v` → open editor in current directory
- `r` → ripgrep with no-heading
- `ls` → eza with icons

### Hammerspoon Architecture

**Entry point:** `hammerspoon/.hammerspoon/init.lua`

**Custom Spoons (git submodules in `Spoons/`):**
- **SpaceManager** - Virtual desktop/space management, most complex
- **AppJump** - Fast app switching
- **Watermelon** - Pomodoro timer with logging
- **Unsplashed** - Auto-rotating wallpapers from Unsplash collections
- **DoNotDisturb** - DND mode management

**Supporting Lua modules:**
- `config.lua` - App filters, key bindings, space configuration
- `utils.lua` - Security checks for host settings, permission validation
- `wm.lua` - Window management actions
- `mutable.lua` - Microphone mute functionality
- `spaces.lua` - Virtual desktop utilities

**Key binding pattern:** Uses "hyper" modifier (Ctrl+Cmd+Option) defined in config.lua

**Background rotation:** Timers set to rotate wallpaper at 9am, 12pm, 3pm, 6pm, 9pm

### Git Configuration

**Primary workflow aliases** (git/.gitconfig:1-68):
- `git up` → pull --rebase --autostash
- `git nb <name>` → create new branch from origin/main
- `git pf` → force-with-lease push (safer force push)
- `git commend` → amend commit without editing message
- `git l` → pretty log with graph (40 commits)
- `git ll` → full detailed log with dates and authors

**Merge/diff tool:** p4merge

### Development Tools

**Version management:** mise (modern asdf replacement)
```bash
mise install           # Install versions from .tool-versions
mise use node@20       # Set node version for current directory
```

**Terminal:** Ghostty (configured in ghostty/.config/ghostty/)
- Uses Dracula+ theme
- Fish shell default
- Transparency enabled

**Editor:** Cursor (set in Fish as $EDITOR)

## Testing & Validation

### Test Hammerspoon changes
```bash
# Reload Hammerspoon configuration
# Use: Cmd+Ctrl+Opt+R (if bound) or from Hammerspoon console
hs.reload()
```

### Test Fish shell changes
```bash
# Reload fish config
. ~/.config/fish/config.fish

# Or use abbreviation
zx
```

### Validate Stow deployment
```bash
# Dry-run to see what would be symlinked
stow -n --dotfiles -t ~ <directory>

# Check existing symlinks
ls -la ~ | grep '\->'
```

## Important Notes

### Security
- Never commit host-specific files (`~/.{hostname}.*`)
- SSH uses 1Password agent: `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`
- Host configs require 600 permissions or they won't load

### Git Workflow
- Main branch is `main`, but upstream is `master`

### macOS-Specific
- Uses Homebrew exclusively for package management
- Sets aggressive key repeat rates (InitialKeyRepeat=15, KeyRepeat=1)
- Disables dock animations and delays for performance
- Requires macOS-specific tools: Hammerspoon, Karabiner, Ghostty
