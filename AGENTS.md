# AGENTS.md

Guidance for coding agents working in this repository. `CLAUDE.md` is a relative symlink to
this file, so both names read the same text and neither can drift.

Read [`README.md`](README.md) first — it is the human-facing description of what this repo is
and how to install it, and it is kept true. This file is about the parts an agent needs and a
human reading the README does not: the invariants, the boundaries, and the things that are
easy to get subtly wrong.

## What this is

GNU Stow-managed personal dotfiles for **macOS and Linux**. Each non-hidden top-level directory
is a stow package; its contents are symlinked into `$HOME`.

- Fish is the primary shell. Bash and POSIX `sh` are a deliberate, minimal, portable fallback —
  they matter on Linux, where they are what `ssh` lands you in.
- `mise` manages language runtimes. `asdf` is gone.
- Hammerspoon provides window management and automation; its Spoons are git submodules.
- Host-specific settings and secrets live **outside the repo**, in `~/.$hostname.*` files.

## The invariants

These are the properties that should survive whatever you are about to change. If a change
would break one, that is the thing to raise rather than the thing to do.

1. **The platform map lives in `lib/packages.sh`, and only there.** It holds exactly two facts:
   which top-level directories are not stow packages (`DOTFILES_NOT_PACKAGES`), and which
   packages are platform-specific (`DOTFILES_DARWIN_ONLY`, `DOTFILES_LINUX_ONLY`). Today
   macOS-only is exactly `hammerspoon karabiner`.
2. **Packages are discovered, not listed.** Adding a directory is the whole change needed to
   get it installed. There is no list of packages in `install.sh` and there must not be one
   again — a hardcoded list is precisely why `starship` sat in this repo for years without ever
   being linked.
3. **Nothing is hardcoded to a Homebrew prefix**, or to any absolute path under `/Users` or
   `/home`. Resolve at runtime (`command -v`, `brew shellenv`, `$HOME`), and treat "no Homebrew
   at all" as a supported outcome.
4. **A tool may be absent.** Every integration is guarded on the binary existing and degrades
   quietly. On Linux this repo *configures* software; it never installs it.
5. **Secrets never enter the repo.** Per-host config is `~/.$hostname.fish` and
   `~/.$hostname.hammerspoon.lua`, both permission-checked before being sourced.
6. **The `Brewfile` is hand-maintained.** Never run `brew bundle dump --force` against it — see
   below.
7. **Work reaches `main` only through a pull request.** Do not commit to `main`, do not push to
   it, do not merge.
8. **Never touch the real `$HOME` while testing.** Use `--target` / `DOTFILES_TARGET`.

## Layout

```
install.sh          CLI and orchestration
upgrade.sh          brew update/upgrade, then audit the machine against the Brewfile
lib/common.sh       logging, platform detection, path helpers, append_line_once
lib/packages.sh     THE PLATFORM MAP — discovery, exclusions, macOS-only set
lib/stow.sh         conflict detection, takeover, pruning, the stow invocation
macos/defaults.sh   the `defaults write` block, guarded on Darwin
test/run.sh         local entry point for every check CI runs
test/install-test.sh    the installer's own end-to-end suite
<package>/          a stow package; contents mirror their layout under $HOME
```

## Installing and testing safely

`./install.sh --help` is the authoritative interface. It is real and current — read it rather
than guessing at flags.

```sh
./install.sh --list                          # what this platform would install
./install.sh --dry-run                       # change nothing
./install.sh --takeover                      # move conflicts aside, then link
./install.sh fish git starship               # a subset
DOTFILES_PLATFORM=linux ./install.sh --list  # exercise the other platform's path
```

**Testing always goes through a throwaway target.** Pointing `--target` anywhere other than the
real home automatically suppresses every machine-level step — Homebrew, macOS `defaults`, agent
skills, submodule updates — so this cannot mutate the machine:

```sh
mkdir -p /tmp/fakehome && ./install.sh --target /tmp/fakehome --takeover
```

The checks:

```sh
./test/run.sh                 # lint, syntax, install, smoke
./test/run.sh lint syntax     # any combination
```

`test/install-test.sh` and `test/smoke-test.sh` both work inside `mktemp` directories and refuse
to run against `$HOME`. CI shells out to these same scripts on Ubuntu and macOS, so there is no
second copy of the logic in YAML.

## Conflicts, takeover, and pruning

This is the part of `install.sh` most likely to be misunderstood, so it is worth stating exactly.

- A symlink already pointing at the right file in this repo is **not** a conflict. It is the
  successful end state, is never touched, and is what makes a rerun free.
- Anything else occupying a target path — a real file, a directory, a symlink pointing outside
  the repo, an *absolute* symlink even to the correct file (stow refuses those), or one left by
  a different package — is a conflict. A default run names them all, changes nothing, exits 1.
- `--takeover` moves each into `~/.dotfiles-backup/<timestamp>/` and links **in the same pass**.
  Moves, never copies (so modes survive), and never deletes.
- **`stow --adopt` is deliberately not used.** Adopt resolves a conflict by pulling the
  intruding file *into the repository*, overwriting the tracked version — exactly backwards for
  the case this exists to solve.
- Stow runs with `--no-folding` and **without `--restow`**. Folding is how `~/.config` ends up
  as a single symlink into the checkout, with anything a tool writes there landing in the repo
  as untracked noise. Restow's unstow pass dies on a directory a previous run folded.
- The prune pass removes symlinks pointing at files this repo no longer has. It is the only
  thing the installer deletes, and every condition is re-checked at the moment of deletion.

**The Atuin story, accurately.** Atuin does *not* rewrite its config: it creates
`~/.config/atuin/config.toml` if and only if the file does not exist, and a symlinked config
survives untouched (upstream `settings.rs`, verified against 18.16.1). The failure was a race in
the gap between deleting the file and re-running stow. Do not reintroduce "Atuin overwrites its
config" into any comment or doc — it is wrong, and it leads to the wrong fix.

## Per-package notes

### Fish

Configuration is **split**, not a single file. `config.fish` is a comment block documenting the
layout; fish sources `conf.d/*.fish` automatically, in sorted order, *before* `config.fish`.

| file | responsibility |
| --- | --- |
| `conf.d/00-host.fish` | hostname derivation, then `~/.$FISH_HOSTNAME.fish` |
| `conf.d/10-path.fish` | `PATH`; Homebrew discovered, never hardcoded |
| `conf.d/20-env.fish` | environment: `EDITOR`, `GPG_TTY`, fzf, ssh agent, `KUBECONFIG` |
| `conf.d/30-abbr.fish` | abbreviations, interactive only |
| `conf.d/50-tools.fish` | the `FISH_*` opt-in tool integrations |
| `conf.d/90-tmux.fish` | `FISH_TMUX` auto-attach — last, because it hands over the terminal |
| `functions/*.fish` | one function per file, autoloaded on first use |

The numbering is load-bearing: `00-host.fish` runs first because the `FISH_*` flags it picks up
from the host file have to be set before `50-tools.fish` reads them.

Flags, each off unless set to `true` in the host file, and each additionally guarded on the tool
being installed: `FISH_STARSHIP`, `FISH_ATUIN`, `FISH_MISE`, `FISH_DIRENV`, `FISH_ZOXIDE`,
`FISH_TMUX`, `FISH_KUBE`. (`FISH_DEV`, `FISH_ASDF`, `FISH_ITERM`, `FISH_RPK`, `FISH_GT` and
`FISH_CARAPACE` were removed and should not come back.)

**Adding a config fragment or function:** the repo owns `conf.d/NN-*.fish` (two-digit prefix)
and an explicit allowlist of function files. `fish/.gitignore` re-opens the stow-folded
directories and re-includes exactly those, so **a new function file must be added to
`fish/.gitignore` or it will be silently untracked.** Anything without a numeric prefix —
fisher plugins, third-party appends, `conf.d/local.fish` — stays ignored by design.

Plugins are managed by fisher against the tracked `fish_plugins`; `install.sh` bootstraps it
once via `my_fisher_bootstrap`, not from shell startup.

### Git

- Editor is `code -w`; **merge and diff tool are `vscode`**, spelled out explicitly rather than
  relying on Git's built-in backend (which only exists since 2.47). p4merge is still available
  as a backend (`git difftool -t p4merge`) but is no longer the default — the default has to
  work on Linux.
- `git nb` / `git newbranch` derive the base from `refs/remotes/origin/HEAD`, repairing it with
  `git remote set-head origin --auto` when missing, and fall back to `origin/main` only if the
  remote is unreachable. They do **not** hardcode `origin/main`.
- `credential.helper` is a dispatcher chosen at run time: osxkeychain → libsecret → cache.
- Machine-local overrides go at the bottom so they win: `~/.gitconfig.local`, plus
  `~/.gitconfig-work` for clones under `~/work/`. Git ignores a missing include silently.

### Terminal

tmux config lives at `~/.config/tmux/tmux.conf` (tmux 3.1+ search path), **not** `~/.tmux.conf`.
`default-shell` is resolved at load time via `run-shell`, so a machine without fish keeps its
login shell rather than failing to start sessions. Version-sensitive options are feature-detected
with `show-options`, not compared against version strings.

Ghostty's `command` is `fish -l` — a bare name, looked up on `PATH`. `config-file = ?config.local`
is the per-machine escape hatch.

### Brewfile

Hand-maintained and sectioned, with a hard `macOS ONLY` banner partway down. `Brewfile.vscode`
is a separate, opt-in manifest of VS Code extensions.

**Never `brew bundle dump --force` over the `Brewfile`.** That is what produced the 388-line
unreadable dump this file replaced, and it does it silently. `upgrade.sh` runs
`brew bundle check` instead — the curated manifest audits the machine, not the reverse.
`./upgrade.sh --dump` writes `Brewfile.generated` for diffing and never touches the `Brewfile`.

### Hammerspoon (macOS only)

Spoons are git submodules. `install.sh` checks them out at their pinned commits by default;
`--update` moves them forward. One (`BrowserManager`) is declared with an SSH remote, so it
cannot clone without key access — CI checks out with `submodules: false` for that reason, and
the installer warns and continues rather than failing.

## Conventions

- Shell scripts target **bash 3.2** — that is what macOS ships. No associative arrays, no
  `mapfile`, no `${var,,}`. `lib/*.sh` are sourced, never executed.
- Branch on `dotfiles_platform()` (or `uname`/`$OSTYPE`), never on the existence of a macOS
  path. BSD `stat -f %Lp` vs GNU `stat -c %a` is the recurring one.
- `shellcheck` is a merge gate at `severity>=warning`. Exceptions are **annotated** in
  `test/shellcheck-baseline.txt` with a reason, not silenced; entries that stop matching are
  reported as stale so they get deleted.
- Prefer naming a thing over citing a line number. The previous version of this file rotted
  mostly because it cited `config.fish:39-84`.
- Comments in this repo carry reasoning, not restatement — several explain why an obvious
  approach was rejected. When you change the code, change the reasoning with it.
