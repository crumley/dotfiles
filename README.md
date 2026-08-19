# dotfiles

My personal configuration, managed with [GNU Stow](https://www.gnu.org/software/stow/).
Each top-level directory is a stow package whose contents are symlinked into `$HOME`, so
`fish/.config/fish/config.fish` in this repo becomes `~/.config/fish/config.fish` on the machine.

Fish is the primary shell; bash is kept as a competent fallback because it is what Linux and
`ssh` drop you into. Everything here is meant to work on **macOS and Linux** — the installer
configures tools on both, but it only *installs* packages on macOS.

## Install

You need `git`, `bash`, and GNU Stow. Everything else is optional and degrades cleanly when
it is absent.

```sh
# macOS
brew install stow
# Debian/Ubuntu
sudo apt install stow
# Fedora
sudo dnf install stow
```

Then clone anywhere and run the installer. The checkout is permanent — the links point back
into it, so don't clone to a temp directory.

```sh
git clone https://github.com/crumley/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --dry-run    # see exactly what would happen
./install.sh              # link everything for this platform
```

A second run is free: a symlink that already points at the right file here is never touched,
so `./install.sh` is safe to rerun whenever the repo changes.

On a fresh Mac, one extra pass installs the software the configs assume:

```sh
./install.sh --brew-bundle          # everything in Brewfile (slow; opt-in on purpose)
./install.sh --vscode-extensions    # the 92 editor extensions in Brewfile.vscode
```

The normal macOS install also adds the detected Homebrew `bin` and `sbin` directories to
launchd's user-service `PATH`. Finder, Dock, Spotlight, and login-item applications do not run
shell profiles, so without this step GUI configuration such as Ghostty's portable
`command = fish -l` cannot find Homebrew-installed commands. The installer asks for `sudo` only
when that launchd `PATH` is missing Homebrew, updates the current login session immediately, and
persists it for subsequent boots. It does not change the account's login shell. `--skip-brew`
skips this along with all other Homebrew setup.

### When something is already in the way

A plain `./install.sh` **refuses rather than damages.** If a real file, a directory, or a
foreign symlink occupies a path a package wants, it names every one of them, changes nothing
at all, and exits non-zero:

```
error: 1 path(s) are in the way; nothing has been changed.

  file           /Users/ryan/.config/atuin/config.toml
```

`--takeover` is the answer:

```sh
./install.sh --takeover
```

It moves each conflicting path into `~/.dotfiles-backup/<timestamp>/`, preserving the path
relative to `$HOME`, and then links — **in the same pass**. Nothing is ever deleted, modes are
preserved (a move, not a copy), and you can recover anything from the backup directory.

The reason it works this way is Atuin, and the reason is worth stating precisely because the
folklore version is wrong. **Atuin does not rewrite its config.** It creates
`~/.config/atuin/config.toml` if and only if the file does not exist; a symlinked config
survives `atuin init` and normal use untouched, and no setting disables the generation
(checked against upstream `settings.rs` and Atuin 18.16.1). The failure is a *race*: you delete
the file so stow can get past it, one of your open terminals starts a shell in the gap, Atuin
recreates it, and stow refuses again. Moving aside and linking in one pass never opens that gap,
so there is no retry loop here and no instruction to close your terminals first.

The mirror image is handled too. When a file is deleted from this repo, the symlink it left in
`$HOME` is removed, so a config that moved (`~/.tmux.conf` → `~/.config/tmux/tmux.conf`) does
not leave a dangling link behind — tmux 3.1+ reads both paths and would error on every start.
Only symlinks pointing at a file this repo no longer has are ever removed; that is the one and
only thing the installer deletes. `--no-prune` turns it off.

### Flags worth knowing

`./install.sh --help` is authoritative. The ones that matter on a fresh box:

| flag | what it does |
| --- | --- |
| `-n`, `--dry-run` | show everything, change nothing |
| `-f`, `--force`, `--takeover` | move conflicts to `~/.dotfiles-backup/<timestamp>/`, then link |
| `-t`, `--target DIR` | link into `DIR` instead of `$HOME` (also `DOTFILES_TARGET`) |
| `--list` | print the packages this platform would install |
| `--stow-only` | link only: no Homebrew, no macOS defaults, no agent skills, no submodules |
| `--update` | `git pull` and advance submodules before linking |
| `--brew-bundle` | install the Brewfile (macOS) |
| `--vscode-extensions` | install `Brewfile.vscode` (separate on purpose) |
| `--skip-brew` | never install or invoke Homebrew, or configure its launchd `PATH` |
| `--no-prune` | keep symlinks pointing at files this repo no longer has |

Named packages install a subset: `./install.sh fish git starship`.

Environment: `DOTFILES_TARGET` (where to link), `DOTFILES_BACKUP_ROOT` (where takeover puts
things), `DOTFILES_PLATFORM` (force `darwin`/`linux`, for exercising the other code path),
`DOTFILES_QUIET`.

Pointing `--target` at anything other than your real home automatically suppresses every
machine-level step — Homebrew, macOS defaults, agent skills — so trying the installer out can
never mutate the machine:

```sh
mkdir /tmp/fakehome && ./install.sh --target /tmp/fakehome --takeover
```

## What's in it

Nineteen packages. All of them install on Linux except the two marked macOS-only.

| package | lands at | configures |
| --- | --- | --- |
| `agents` | `~/.agents/skills.list` | which agent skills to reinstall, and from where |
| `atuin` | `~/.config/atuin/config.toml` | shell history search |
| `bash` | `~/.bashrc.tracked`, `~/.bash_profile.tracked` | interactive bash and login-shell layering — see the note below |
| `claude` | `~/.claude/settings.json` | Claude Code permissions |
| `direnv` | `~/.config/direnv/direnvrc` | per-directory environments, with the mise hook |
| `espanso` | `~/.config/espanso/` | text expansion |
| `fish` | `~/.config/fish/` | the primary shell: `config.fish`, `conf.d/`, `functions/`, `fish_plugins` |
| `ghostty` | `~/.config/ghostty/config` | terminal |
| `git` | `~/.gitconfig.global`, `~/.gitignore_global`, `~/.gitattributes`, `~/bin/git-by-date` | git — see the note below |
| `hammerspoon` | `~/.hammerspoon/` | window management and automation — **macOS only** |
| `home` | `~/.profile.tracked`, `~/.inputrc`, `~/.wgetrc`, `~/.hushlogin` | POSIX environment, readline, wget — see the note below |
| `karabiner` | `~/.config/karabiner/karabiner.json` | keyboard remapping — **macOS only** |
| `mise` | `~/.config/mise/config.toml` | language runtime versions |
| `rclone` | `~/bin/rclone-cron.sh` | the scheduled rclone sync |
| `rg` | `~/.ripgreprc` | ripgrep defaults — see the note below |
| `ssh` | `~/.ssh/config` | ssh, and the 1Password agent socket on either platform |
| `starship` | `~/.config/starship.toml` | prompt |
| `tmux` | `~/.config/tmux/tmux.conf` | tmux |
| `vim` | `~/.vimrc`, `~/.gvimrc` | vim, dependency-free and plugin-free |

**`git`, `bash`, and `home` stow to a `.tracked`/`.global` name, not the real path.** `git config
--global` rewrites `~/.gitconfig` directly, and shell installers (nvm, pyenv, rustup, sdkman, ...)
routinely append straight into `~/.bashrc`, `~/.bash_profile`, and `~/.profile`. If any of those
paths were a symlink into this repo, that rewrite would land in the tracked checkout and leave it
permanently dirty. So the repo's content stows to a name nothing else targets
(`~/.gitconfig.global`, `~/.bashrc.tracked`, `~/.bash_profile.tracked`, `~/.profile.tracked`),
and `install.sh` separately ensures the real path exists and reaches it: `~/.gitconfig` gets a
prepended `include.path`, the shell files get a one-line `source`, in both cases only ever adding
that one thing and never touching whatever a tool has written there. See "Clobber-safe stubs" in
`AGENTS.md` for the mechanics.

Packages are **discovered, not listed** — every non-hidden top-level directory is one. Adding
`zellij/` to the repo is enough to get it installed; no script needs editing.
[`lib/packages.sh`](lib/packages.sh) is the one file that knows otherwise, and it holds only two
things: which top-level directories are repo machinery rather than packages, and which packages
are platform-specific.

Not packages: `lib/` (installer machinery), `macos/` (the `defaults write` block), `test/`,
and `.github/`.

Two packages install executables into `~/bin` — `git-by-date` and `rclone-cron.sh`. Both the
fish config and `~/.profile` put `~/bin` on `$PATH`, which is what makes `git by-date` work in
Git's subcommand form.

One note on `rg`: ripgrep reads `.ripgreprc` **only** when `RIPGREP_CONFIG_PATH` points at it —
there is no lookup by name or location. Both `conf.d/20-env.fish` and `~/.profile` set it, each
guarded on the file existing, because pointing the variable at a missing file makes `rg` print
an error to stderr on every single invocation.

`rg --debug --files 2>&1 | head -1` names the config actually loaded.

## Platform support

Everything is expected to work on Linux except `hammerspoon` and `karabiner`, whose
applications genuinely do not exist there. `ghostty` and `espanso` both ship for Linux and their
configs are platform-independent, so they stow everywhere.

**The installer does not install Linux packages.** That is deliberate: on Linux this repo
configures whatever happens to be there and stays out of your package manager's way. No `apt`,
no `dnf`, no Homebrew. Every config assumes the tool it configures may be absent and degrades
without complaining — a missing `starship` falls back to a plain prompt, a missing `fish` means
tmux keeps your login shell, a missing `eza` leaves `ls` alone.

The `Brewfile` is macOS-only and says so in a hard banner partway down; everything above the
banner is cross-platform CLI, everything below is casks, fonts, macOS-only utilities, and GNU
replacements for tools macOS ships in BSD flavour. If a Linux package list is ever wanted, it is
a mechanical cut at that line.

Nothing here hardcodes a Homebrew prefix. `/opt/homebrew`, `/usr/local`,
`/home/linuxbrew/.linuxbrew` and `~/.linuxbrew` are all discovered at runtime, and no brew at
all is a supported outcome. On macOS, `brew --prefix` also supplies the launchd GUI-service
`PATH`; the account's login shell remains unchanged.

## Day to day

**After editing a config**, re-run the installer. Existing correct links are left alone, and
anything new gets linked:

```sh
./install.sh
```

Stow directly also works for a single package, but the installer's conflict handling and prune
pass do not:

```sh
stow --dotfiles --no-folding -t ~ fish     # link one package
stow -D --dotfiles -t ~ fish               # unlink one package
```

**To add a package**, make the directory and lay the files out as they should appear under
`$HOME`, then run `./install.sh`. Nothing else. If it should only exist on one platform, add it
to `DOTFILES_DARWIN_ONLY` or `DOTFILES_LINUX_ONLY` in `lib/packages.sh`.

**To update software:**

```sh
./install.sh --update      # git pull + submodules, then relink
./upgrade.sh               # brew update && brew upgrade, then audit against the Brewfile
```

`upgrade.sh` deliberately does **not** run `brew bundle dump`. The `Brewfile` is hand-maintained;
a dump would overwrite it with whatever happens to be installed, silently, including everything
a one-off experiment dragged in. It runs `brew bundle check` instead — the manifest audits the
machine rather than the other way round. `./upgrade.sh --dump` writes `Brewfile.generated`
(gitignored) for diffing, and never touches the `Brewfile`.

### Host-specific config and secrets

Nothing private is ever committed here.

- **fish** — `~/.config/fish/conf.d/00-local.fish`, a real file you create, not a symlink and
  not in the repo. A commented-out template ships as
  `conf.d/00-local.fish.example` and is stowed alongside it, so a fresh machine starts with:

  ```bash
  cp ~/.config/fish/conf.d/00-local.fish.example \
     ~/.config/fish/conf.d/00-local.fish
  ```

  Then uncomment what that machine wants. `./install.sh` prints this reminder whenever the real
  file is missing, so a shell coming up without its integrations is never a mystery. The `00-`
  prefix is what puts the `FISH_*` flags in place before `conf.d/50-tools.fish` reads them.
  Missing is fine — fish sources what is there.

  The two names are deliberately different. If the live file were the tracked one, uncommenting
  a single line would show up as a modification to a tracked file, and one `git commit -a` later
  the machine's settings would be in the history.
- **Hammerspoon** — `~/.$hostname.hammerspoon.lua`, outside the repo, named after
  `hs.host.localizedName()`, and **permission-checked before loading**: owned by you and not
  group- or world-writable, or it is refused. Hammerspoon has no stow-visible drop-in directory,
  so the host-file pattern still earns its keep there.

Fish used to work the Hammerspoon way — `~/.$hostname.fish`, a derived hostname, and the same
permission check. It was replaced because the indirection bought nothing: a per-machine file in
a gitignored path is already per-machine, and deriving a hostname to find it added a moving part
that differed across macOS and Linux. If you had a `~/.$hostname.fish`, move its contents into
`conf.d/00-local.fish`; nothing reads the old path any more.

Because the live file is in `$HOME` rather than the checkout, `git clean -x` in the repo cannot
delete it — but nothing backs it up either. Keep a copy somewhere durable if it holds anything
you cannot regenerate.

`00-local.fish` is also where the fish feature flags go, since which integrations you want
differs per machine. Each is off unless set to `true`, and each additionally checks the tool is
installed:

```fish
set -gx FISH_STARSHIP true    # prompt
set -gx FISH_ATUIN true       # history search on ctrl-r
set -gx FISH_MISE true        # runtime version manager
set -gx FISH_DIRENV true      # per-directory environments
set -gx FISH_ZOXIDE true      # smarter cd
set -gx FISH_TMUX true        # auto-attach to tmux on login
set -gx FISH_KUBE true        # merge every ~/.kube/*config* into KUBECONFIG
```

The point of the flags is that a machine which does not use a tool does not get it, even when
the tool is installed — and everything in the `Brewfile` is installed on every macOS machine.
That needs defending: Homebrew and distro packages ship fish snippets in `vendor_conf.d`, which
fish sources on every start, and those hook their tool in unconditionally. Both mise and direnv
did exactly that. They are disarmed by `conf.d/05-vendor-optout.fish` and `conf.d/direnv.fish`
respectively, so the flags are the real switch. If a flag ever seems to be ignored, look at
`ls $__fish_vendor_confdirs` for a newly installed package doing the same thing.

Other escape hatches, none of them repo-provided and all of them optional:

| file | read by |
| --- | --- |
| `~/.config/fish/conf.d/<name>.fish` | fish — any name **not** starting with two digits; gitignored, and the right home for third-party appends |
| `~/.profile.local` | `~/.profile` (POSIX environment) |
| `~/.extra` | `~/.bashrc` (interactive bash) |
| `~/.gitconfig.local` | `~/.gitconfig`, last, so it wins |
| `~/.gitconfig-work` | `~/.gitconfig`, for clones under `~/work/` |
| `~/.config/ghostty/config.local` | `ghostty/config`, included last |

Different from the above: `~/.gitconfig`, `~/.bashrc`, `~/.bash_profile`, and `~/.profile`
themselves are also not tracked, but `install.sh` writes them (see the note above the package
table) — they are redirect targets for tools that insist on rewriting their own config file, not
somewhere to put your own settings. Put those in the escape hatches above instead: they are
sourced from further down the chain regardless.

## Testing

```sh
./test/run.sh            # everything
./test/run.sh lint       # shellcheck over every shell script
./test/run.sh syntax     # parse checks: fish, bash/sh, lua, json, toml, yaml, Brewfile
./test/run.sh install    # the installer's own end-to-end suite
./test/run.sh smoke      # install into a throwaway home, then start the shells against it
```

Nothing touches your real home directory: the install and smoke checks work inside a `mktemp`
directory and refuse to run if the target resolves to `$HOME`. Optional linters that are not
installed are reported as a loud `SKIP` — never silently counted as a pass.

CI (`.github/workflows/ci.yml`) runs exactly these scripts, so there is no second copy of the
logic to drift: shellcheck on Ubuntu (gate at `severity>=warning`, a `style` pass as advisory),
parse checks on Ubuntu and macOS, and the installer suite plus the shell-startup smoke test on
both. Putting the install path on a two-OS matrix is the point — it is what actually answers
"does a clean install work on Linux?"
