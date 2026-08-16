# Brewfile — the packages this machine is built from.
#
# HAND-MAINTAINED. Do not regenerate this file with `brew bundle dump --force`:
# a dump lists every installed formula, including transitive dependencies, which
# is how this file previously grew to 388 unreadable lines. Add and remove
# entries by hand, with a comment saying why.
#
#   install   brew bundle --file=Brewfile
#   check     brew bundle check --file=Brewfile --no-upgrade
#   cleanup   brew bundle cleanup --file=Brewfile        # --force to actually remove
#
# VS Code extensions live in Brewfile.vscode (opt-in, see the header there).
#
# LAYOUT
#   The cross-platform CLI section is everything that is worth having on any
#   machine, macOS or Linux. Everything below the "macOS only" banner is either
#   a GUI app, a font, a macOS-only utility, or a GNU replacement for a tool
#   that macOS ships in a BSD flavour (and that Linux already has). The
#   installer does not install Linux packages, but keeping the boundary visible
#   makes the eventual Linux story a matter of reading down to the banner.


# ─── Taps ────────────────────────────────────────────────────────────────────
# Homebrew 4.0+ has homebrew/core and homebrew/cask built in; homebrew/bundle
# and homebrew/services were folded into brew itself. Tapping any of them is a
# no-op at best and forces a slow git-based tap at worst — so none are listed.

tap "koekeishiya/formulae"                # yabai; driven by hammerspoon/wm.lua


# ═════════════════════════════════════════════════════════════════════════════
# CROSS-PLATFORM CLI
# ═════════════════════════════════════════════════════════════════════════════

# ─── Shell, prompt, history ──────────────────────────────────────────────────
brew "fish"                               # primary shell (fish/ stow package)
brew "starship"                           # prompt (starship/ stow package)
brew "atuin"                              # shell history (atuin/ stow package)
brew "zoxide"                             # smarter cd; replaced autojump
brew "direnv"                             # per-directory env (direnv/ package)
brew "fzf"                                # fuzzy finder; used by fish plugins
brew "fzy"                                # fuzzy finder; used by fish-fzy plugin
brew "grc"                                # colourises command output for fish
brew "stow"                               # what deploys this repo
brew "tmux"                               # tmux/ stow package
brew "tmuxinator"                         # named tmux sessions
# fisher is deliberately absent: fish/config.fish bootstraps it over curl, so
# installing it here too gave two competing copies.

# ─── Files, search, text ─────────────────────────────────────────────────────
brew "ripgrep"                            # rg; configured by rg/.ripgreprc
brew "fd"                                 # find replacement
brew "eza"                                # ls replacement (the `ls` abbr)
brew "sd"                                 # sed replacement for simple edits
brew "jq"                                 # JSON
brew "fx"                                 # interactive JSON viewer
brew "yamllint"                           # YAML lint
brew "xmlstarlet"                         # XML from the shell
brew "ccat"                               # cat with syntax colour
brew "highlight"                          # source highlighting for less/fzf
brew "lnav"                               # log file navigator
brew "the_silver_searcher"                # ag; predates ripgrep, still bound
brew "tree"
brew "pv"                                 # pipe throughput meter
brew "parallel"
brew "htop"                               # process viewer
brew "spacer"                             # inserts a rule between command runs

# ─── Git and version control ─────────────────────────────────────────────────
brew "git"                                # git/ stow package
brew "gh"                                 # GitHub CLI
brew "git-lfs"
brew "git-extras"                         # git summary, git effort, …
brew "git-branchless"                     # stacked-branch workflow
brew "subversion"                         # legacy checkouts

# ─── Languages and runtimes ──────────────────────────────────────────────────
brew "go"
brew "node"
brew "yarn"
brew "ruby"                               # newer than the system ruby
brew "ruby-install"
brew "lua"                                # Hammerspoon config is Lua
brew "luarocks"
brew "scala"
brew "sbt"
brew "maven"
brew "openjdk"                            # current JDK
brew "openjdk@17"                         # LTS JDK; scala builds against it
brew "ipython"
brew "jupyterlab"
brew "uv"                                 # Python packaging/runner

# ─── Version managers ────────────────────────────────────────────────────────
# mise is the one this repo configures (mise/ stow package). The rest are older,
# per-language managers that predate it and are still installed — see the PR.
brew "mise"
brew "jenv"                               # JDK switching
brew "nvm"                                # node; superseded by mise
brew "pyenv"                              # python; superseded by mise
brew "mvnvm"                              # maven wrapper

# ─── Containers and Kubernetes ───────────────────────────────────────────────
brew "docker"                             # CLI only; the GUI is a cask
brew "docker-compose"
brew "colima"                             # container runtime without Docker Desktop
brew "podman"
brew "podman-compose"
brew "minikube"
brew "helm"
brew "k9s"                                # cluster TUI
brew "velero"                             # cluster backup/restore

# ─── Cloud and networking ────────────────────────────────────────────────────
brew "awscli"
brew "cloudflared"                        # now in homebrew/core; tap dropped
brew "rclone"                             # rclone/ stow package + rclone-cron.sh
brew "httpie"
brew "wget"
brew "nmap"
brew "netcat"
brew "socat"
brew "sshuttle"                           # poor-man's VPN over ssh
brew "openconnect"                        # AnyConnect-compatible VPN client
brew "iperf3"                             # throughput testing
brew "siege"                              # HTTP load testing

# ─── Data stores and streaming ───────────────────────────────────────────────
brew "mysql"
brew "mysql-client@8.0"                   # 8.0 protocol client, pinned
brew "memcached"
brew "kafka"
brew "zookeeper"                          # required by the older Kafka setup
brew "kcat"                               # kafkacat; CLI Kafka producer/consumer
brew "temporal"                           # Temporal CLI + dev server

# ─── Dev tooling ─────────────────────────────────────────────────────────────
brew "shellcheck"                         # shell linting (also used in CI)
brew "golangci-lint"                      # now in homebrew/core; tap dropped
brew "buf"                                # now in homebrew/core; tap dropped
brew "protobuf"                           # protoc, alongside buf
brew "golang-migrate"                     # SQL migrations
brew "mockery"                            # Go mock generation
brew "rover"                              # Apollo GraphQL CLI
brew "jsonschema2pojo"                    # JSON Schema → Java
brew "graphviz"                           # dot
brew "qcachegrind"                        # callgrind/profile viewer
brew "watchman"                           # file-watching service
brew "llvm@14"                            # pinned toolchain for an old project

# ─── Media ───────────────────────────────────────────────────────────────────
brew "ffmpeg"                             # was pinned to ffmpeg@4
brew "imagemagick"
brew "vips"                               # fast image processing
brew "yt-dlp"

# ─── Security ────────────────────────────────────────────────────────────────
brew "gnupg"
brew "ykman"                              # YubiKey manager
brew "pwgen"


# ═════════════════════════════════════════════════════════════════════════════
# macOS ONLY — nothing below this line belongs on a Linux machine
# ═════════════════════════════════════════════════════════════════════════════

# ─── GNU userland ────────────────────────────────────────────────────────────
# macOS ships BSD versions of these (or none at all); Linux already has them.
brew "coreutils"
brew "gawk"
brew "util-linux"
brew "watch"
brew "rsync"                              # newer than the system rsync
brew "bash"                               # macOS ships bash 3.2
brew "bash-completion@2"                  # bash/ stow package expects it

# ─── macOS CLI utilities ─────────────────────────────────────────────────────
brew "blueutil"                           # Bluetooth from the CLI (Hammerspoon)
brew "terminal-notifier"                  # notifications from scripts
brew "koekeishiya/formulae/yabai"         # tiling WM, controlled by wm.lua

# ─── Terminal, editors, dev GUI ──────────────────────────────────────────────
cask "ghostty"                            # terminal (ghostty/ stow package)
cask "visual-studio-code"
cask "cursor"                             # $EDITOR
cask "claude-code@latest"                      # claude/ and agents/ stow packages
cask "macvim-app"                         # was cask "macvim" (renamed upstream)
cask "sublime-merge"
cask "github"                             # GitHub Desktop
cask "gitfox"
cask "gitup-app"                          # was cask "gitup" (renamed upstream)
cask "intellij-idea"
cask "eclipse-java"
cask "visualvm"                           # JVM profiler
cask "temurin"                            # Eclipse Temurin JDK (ex-AdoptOpenJDK)
cask "dash"                               # offline API docs
cask "postman"
cask "tableplus"                          # SQL client
cask "docker-desktop"

# ─── Cloud / infra GUI + CLI bundles ─────────────────────────────────────────
cask "gcloud-cli"                         # was cask "google-cloud-sdk" (renamed)

# ─── Desktop utilities ───────────────────────────────────────────────────────
cask "hammerspoon"                        # hammerspoon/ stow package
cask "karabiner-elements"                 # karabiner/ stow package
cask "espanso"                            # espanso/ stow package
cask "raycast"                            # launcher
cask "bartender"                          # menu bar management
cask "itsycal"                            # menu bar calendar
cask "jumpcut"                            # clipboard history
cask "1password"
cask "1password-cli"                      # `op`; SSH agent + secret injection
cask "secretive"                          # Secure Enclave SSH keys
cask "macfuse"                            # userspace filesystems (rclone mount)
cask "grandperspective"                   # disk usage
cask "licecap"                            # screen → GIF

# ─── Browsers and comms ──────────────────────────────────────────────────────
cask "google-chrome"
cask "google-chrome@canary"               # was cask "google-chrome-canary"
cask "slack"
cask "discord"
cask "signal"
cask "telegram"
cask "whatsapp"

# ─── Media, docs, personal ───────────────────────────────────────────────────
cask "spotify"
cask "vlc"
cask "vox"                                # audio player
cask "logseq"                             # notes
cask "figma"
cask "google-drive"

# ─── Fonts ───────────────────────────────────────────────────────────────────
# ghostty/.config/ghostty/config asks for "Hack Nerd Font Mono" and mentions
# "Atkinson Hyperlegible Mono". The old font-*-for-powerline family was dropped:
# Powerline patched fonts have been superseded by Nerd Fonts.
cask "font-hack-nerd-font"                # ghostty's font-family
cask "font-atkinson-hyperlegible-mono"    # ghostty alternate, commented in config
cask "font-roboto-mono-nerd-font"
cask "font-ia-writer-duo"
cask "font-ia-writer-quattro"
