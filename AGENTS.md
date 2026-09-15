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
- Machine-specific settings and secrets are never committed: fish reads them from the gitignored
  `conf.d/00-local.fish`, Hammerspoon from `~/.$hostname.hammerspoon.lua`, Claude Code from a
  `~/.claude/settings.json` copied out of a tracked template. Fish's
  `~/.config/fish/config.fish` is also machine-owned, so third-party installers can append to it
  without writing through a symlink into the checkout.

## The invariants

These are the properties that should survive whatever you are about to change. If a change
would break one, that is the thing to raise rather than the thing to do.

1. **The platform map lives in `lib/packages.sh`, and only there.** It holds exactly two facts:
   which top-level directories are not stow packages (`DOTFILES_NOT_PACKAGES`), and which
   packages are platform-specific (`DOTFILES_DARWIN_ONLY`, `DOTFILES_LINUX_ONLY`). Today
   macOS-only is exactly `hammerspoon karabiner switchboard`.
2. **Packages are discovered, not listed.** Adding a directory is the whole change needed to
   get it installed. There is no list of packages in `install.sh` and there must not be one
   again — a hardcoded list is precisely why `starship` sat in this repo for years without ever
   being linked.
3. **Nothing is hardcoded to a Homebrew prefix**, or to any absolute path under `/Users` or
   `/home`. Resolve at runtime (`command -v`, `brew shellenv`, `$HOME`), and treat "no Homebrew
   at all" as a supported outcome.
4. **A tool may be absent.** Every integration is guarded on the binary existing and degrades
   quietly. On Linux this repo *configures* software; it never installs it.
5. **Secrets are never committed, and neither is per-machine state.** Fish's per-machine config
   is `~/.config/fish/conf.d/00-local.fish`, a real file in `$HOME` that the user creates by
   copying the tracked `00-local.fish.example`. Hammerspoon's is `~/.$hostname.hammerspoon.lua`,
   permission-checked before loading. Claude Code's is `~/.claude/settings.json`, copied from the
   tracked `settings.json.example` by the installer. Track none of them. The `.example` suffix is
   the whole safety property: if the live file and the tracked template shared a path,
   uncommenting one line — or toggling one setting — would make the machine's state a diff away
   from being committed.
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
test/switchboard-test.sh  the launchd wrapper, against stubbed d1/security/op
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
./test/run.sh                 # lint, syntax, install, smoke, switchboard
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

## Clobber-safe stubs

The Atuin race is a tool that recreates a *missing* file; a different problem is a tool that
rewrites an *existing* one it already owns. `git config --global` rewrites `~/.gitconfig`
directly, and shell installers (nvm, pyenv, rustup, sdkman, ...) routinely append straight into
`~/.bashrc`, `~/.bash_profile`, and `~/.profile`. If any of those paths were a stow symlink into
this repo, the rewrite lands in tracked content and the checkout is dirty from then on —
`--takeover` does not help, because nothing is *in the way* at install time; the file becomes
dirty afterward, from ordinary use.

The fix is the same shape for both: the `git`, `bash`, and `home` packages stow their content
under a name nothing else targets (`.gitconfig.global`, `.bashrc.tracked`,
`.bash_profile.tracked`, `.profile.tracked`), so `git config --global` or an installer's `>>`
can never reach it. `install.sh` then ensures the real path exists and reaches the tracked
content — the `ensure_gitconfig_include` and `ensure_shell_stub` functions, run after prune, once
per relevant package if selected:

- **`~/.gitconfig`** gets `[include]\n\tpath = ~/.gitconfig.global` **prepended** if not already
  present. Prepended, not appended: `git config --global` always appends, so anything it adds
  lands later in the file and wins — the same "last wins" precedence `~/.gitconfig.local` and
  `~/.gitconfig-work` already rely on inside the tracked file itself.
- **`~/.bashrc`, `~/.bash_profile`, `~/.profile`** each get one line appended via
  `append_line_once` (`lib/common.sh`) — `[ -r "$HOME/<name>.tracked" ] && . "$HOME/<name>.tracked"`
  — so the tracked config loads first and whatever a tool appends afterward runs layered on top,
  never overwritten.

Both are one-way and additive only: neither function ever rewrites content that is already
there, and `append_line_once` separately refuses to touch a file that is still a stow symlink
into the repo (a machine mid-migration from before this existed) rather than editing tracked
content by surprise. This is why the steps run unconditionally (not gated on `--stow-only` or a
throwaway `--target`) — they are the completion of linking these three packages, not a
machine-level side effect, and `test/install-test.sh` exercises them the same way it exercises
stow itself.

Fish needs no generated stub: it natively auto-loads the tracked `conf.d/*.fish` fragments.
The repo therefore does not provide `~/.config/fish/config.fish` at all. If a third-party tool
creates or appends to that conventional path, it remains a real, machine-owned file in `$HOME`
and cannot dirty the checkout.

`~/.claude/settings.json` has the same clobber problem and cannot be solved the same way:
Claude Code rewrites the *entire* file whenever a setting is toggled, with no include mechanism,
so there is nowhere to point a stub. It gets the other half of the idea instead — the
`00-local.fish` shape. The repository tracks only `claude/.claude/settings.json.example`
(stowed to `~/.claude/settings.json.example`); the live path is a real, machine-owned file that
`install.sh` materializes once, in `ensure_claude_settings`, and never touches again. Root
`.gitignore` ignores the live name so it cannot come back by accident. Track the intent, ignore
the state — the same trade as the skills lockfile, with the same `.example` safety property:
the live file and the tracked one can never be the same path.

**`ensure_claude_settings` runs above the prune block, not below it with the stub functions.**
It is the step that reads the machine's only copy of its settings — a symlink into this repo —
and prune's whole business is deleting symlinks into this repo. As prune is written today the
two cannot actually collide (it removes only *dangling* links, and a dangling link has no
content left to rescue), and moving the call below prune leaves the suite green; that is a fact
about prune's current narrowness, not a reason to file it there. Read first, delete second, so
that widening prune later can never become lost settings. The three paths in and out — repo
symlink → real file with the content preserved, absent → template copied, real file → untouched
— plus a foreign symlink left alone and the end-to-end migration are covered in
`test/install-test.sh`.

Two things follow that are easy to trip over. A machine whose live settings were toggled hits a
modify/delete conflict on the `git pull` that lands this change: **run `./install.sh` while the
conflicted file is still on disk** and the content is migrated into `$HOME`; resolve the
conflict by deleting the file first and it is gone. And a leftover
`claude/.claude/settings.json` in a checkout keeps stow linking it back over the migrated file,
so the installer warns about it — and does not delete it, because nothing in this installer ever
deletes anything inside the repository.

`~/.config/karabiner/karabiner.json` still has the clobber problem and is deliberately left
as-is. The same shape would fit, but not identically enough to do in passing: Karabiner is
macOS-only (so half of CI cannot exercise the migration at all), the file is GUI-owned state
that Karabiner-Elements rewrites on every profile change, and it already has its
`automatic_backups/` ignored here. Give it this treatment as its own task if it starts dirtying
the checkout — do not assume the Claude code generalizes to it unread.

## Per-package notes

### Fish

Configuration is **split**, not a single file. Fish sources `conf.d/*.fish` automatically in
sorted order, even when `config.fish` is absent. The repo deliberately does not track
`config.fish`: that conventional path belongs to the machine and to third-party installers that
insist on appending there.

| file | responsibility |
| --- | --- |
| `conf.d/00-local.fish` | this machine's own config — a real file in `$HOME`, **never in the repo**, often absent |
| `conf.d/00-local.fish.example` | the tracked, fully commented template it is copied from |
| `conf.d/05-vendor-optout.fish` | disarms vendor snippets that would ignore the `FISH_*` flags |
| `conf.d/direnv.fish` | inert; shadows the vendor `direnv.fish` by filename |
| `conf.d/10-path.fish` | `PATH`; Homebrew discovered, never hardcoded |
| `conf.d/20-env.fish` | environment: `EDITOR`, `GPG_TTY`, fzf, ssh agent, `KUBECONFIG` |
| `conf.d/30-abbr.fish` | abbreviations, interactive only |
| `conf.d/50-tools.fish` | the `FISH_*` opt-in tool integrations |
| `conf.d/60-claude.fish` | says so when `~/.claude/settings.json.example` has moved ahead of the live file; silent otherwise |
| `conf.d/90-tmux.fish` | `FISH_TMUX` auto-attach; returns immediately inside an existing tmux pane |
| `conf.d/95-ghostty.fish` | restores Ghostty's one-shot fish integration inside tmux panes |
| `functions/*.fish` | one function per file, autoloaded on first use |
| `functions/{wrr,wrcd,wwcd,wws}.fish` + `functions/__ward_*.fish` + `completions/{wrr,wrcd,wwcd,wws}.fish` | ward's shorthands, **adopted**: snapshots this repo owns |

The numbering is load-bearing: `00-local.fish` runs first because the `FISH_*` flags it sets
have to be in place before `50-tools.fish` reads them. This is also the whole reason it carries
a `NN-` prefix despite being untracked — nothing else sorts ahead of `10-path.fish`.

Flags, each off unless set to `true` in `00-local.fish`, and each additionally guarded on the
tool being installed: `FISH_STARSHIP`, `FISH_ATUIN`, `FISH_MISE`, `FISH_DIRENV`, `FISH_ZOXIDE`,
`FISH_TMUX`, `FISH_KUBE`. (`FISH_DEV`, `FISH_ASDF`, `FISH_ITERM`, `FISH_RPK`, `FISH_GT` and
`FISH_CARAPACE` were removed and should not come back.)

**Adding a config fragment or function:** the repo owns `conf.d/NN-*.fish` (two-digit prefix)
and an explicit allowlist of function files. `fish/.gitignore` re-opens the stow-folded
directories and re-includes exactly those, so **a new function file must be added to
`fish/.gitignore` or it will be silently untracked.** Anything without a numeric prefix —
fisher plugins, third-party appends, `conf.d/local.fish` — stays ignored by design. Do not add
`config.fish` to the package: unlike a drop-in, it is a path installers commonly rewrite.

`conf.d/00-local.fish` is the one deliberate exception: it has a `NN-` prefix (it must sort
first) but is re-ignored by a pattern *below* the negation, since in gitignore the last matching
pattern wins. Do not "tidy" that rule by moving it above the negation — that silently makes the
machine's secrets committable. Its template, `00-local.fish.example`, *is* tracked, via a
negation below that again; fish only sources `*.fish`, so the template is inert where it lands.
`install.sh` prints a copy-this reminder when the real file is absent.

**Vendor snippets are the thing that quietly breaks the `FISH_*` flags.** fish auto-sources
`vendor_conf.d` from every directory in `$__fish_vendor_confdirs`, and Homebrew and distro
packages drop snippets there that hook their tool in unconditionally — so merely *installing*
mise or direnv (both are in the `Brewfile`) activated them regardless of the flag. The flags
exist so a machine that does not use a tool does not get it; a vendor snippet overrides that.

Two mechanisms, and the choice between them is deliberate:

- **mise** publishes a supported opt-out, `MISE_FISH_AUTO_ACTIVATE=0`, set in
  `conf.d/05-vendor-optout.fish`. Preferred, because it survives the snippet being renamed.
- **direnv** publishes none — its snippet is a bare `direnv hook fish | source`. It is shadowed
  instead by `conf.d/direnv.fish`, an inert file whose *name* must stay byte-identical to the
  vendor one, since fish runs only the first conf.d file with a given basename and the user's
  directory wins.

The opt-out cannot live in `50-tools.fish`: that file starts with `status is-interactive; or
return`, while vendor snippets run regardless. If a `FISH_*` flag ever appears to be ignored,
check `ls $__fish_vendor_confdirs` before anything else.

**The ward shorthands are adopted snapshots, not generated at runtime.** `ward shell adopt fish
--all --dir fish/.config/fish` wrote `functions/{wrr,wrcd,wwcd,wws}.fish`, their `completions/`
twins, and the four `functions/__ward_*.fish` helpers they call (the picker seam, and the
workspace resolution `wwcd` and `wws` share). From that moment the
files are this repository's: ward never rewrites one unless the adopt command names it again,
`ward doctor` reports per alias when ward's own definition has moved on, and `ward shell diff
fish NAME` shows what changed. Refresh by re-running the same command and committing the diff —
do not hand-edit them into a shape a diff can no longer explain.

**Never add a `conf.d/ward.fish` layer to this package.** `ward shell init fish` emits a
monolithic layer that *defines* every shorthand at startup, and a defined function always
wins over an autoloaded one — so an installed layer would silently shadow every adopted file
here, and the tracked definitions would never run. The two install styles are alternatives, not
companions; this repo has picked adoption. (`completions/ward.fish` is unrelated: it bootstraps
ward's *own* completions and defines no shorthand.)

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
- The tracked file stows to `~/.gitconfig.global`, not `~/.gitconfig` — see "Clobber-safe
  stubs" below.

### Terminal

tmux config lives at `~/.config/tmux/tmux.conf` (tmux 3.1+ search path), **not** `~/.tmux.conf`.
`default-shell` is resolved at load time via `run-shell`, so a machine without fish keeps its
login shell rather than failing to start sessions. Version-sensitive options are feature-detected
with `show-options`, not compared against version strings.

Ghostty starts `/bin/sh -l` and has it `exec fish -l`. The login bootstrap is deliberate: macOS
Spotlight/LaunchServices replaces even a correctly configured user launchd PATH with its system-only
PATH, so a bare `fish` cannot find Homebrew. `~/.profile` discovers the package-manager prefix without
embedding it in Ghostty's cross-platform config. The wrapper hides fish from automatic shell detection,
so `shell-integration = fish` is forced; `conf.d/95-ghostty.fish` manually restores that one-shot
integration in tmux panes. `config-file = ?config.local` is the per-machine escape hatch.

### Brewfile

Hand-maintained and sectioned, with a hard `macOS ONLY` banner partway down. `Brewfile.vscode`
is a separate, opt-in manifest of VS Code extensions.

**Never `brew bundle dump --force` over the `Brewfile`.** That is what produced the 388-line
unreadable dump this file replaced, and it does it silently. `upgrade.sh` runs
`brew bundle check` instead — the curated manifest audits the machine, not the reverse.
`./upgrade.sh --dump` writes `Brewfile.generated` for diffing and never touches the `Brewfile`.

### Agent skills

`agents/.agents/skills.list` is the tracked source of truth: one `<source>  <name>` per line,
comments and blank lines ignored. `install.sh` walks it and runs `npx skills add` for each entry.

**`.skill-lock.json` is deliberately not tracked.** The skills CLI rewrites its
`skillFolderHash` and `updatedAt` on every skill update, so a stowed, tracked copy left this
repository permanently dirty — which also blocks `ward repo refresh` in the workspace that
deploys it. Nothing ever read those fields; only the source and the name were used. Track the
intent, ignore the state. Do not re-add the lockfile to git to "fix" a fresh machine having no
skills — add the skill to `skills.list` instead.

The skill bodies live untracked in `~/.agents/skills`, which is why the installer pre-creates
that directory: without it, stow folds the missing `~/.agents` into a symlink to the checkout and
every installed skill body lands in the repo as untracked noise.

### Claude Code

The package tracks exactly one file, `claude/.claude/settings.json.example`, and it is the
curated baseline: schema, attribution defaults, and the permission allowlist. The live
`~/.claude/settings.json` is machine-owned and gitignored, because Claude Code rewrites the whole
file the moment a setting is toggled — see "Clobber-safe stubs" for the mechanics and the
migration.

Consequences worth keeping straight:

- **Never re-add `claude/.claude/settings.json` to git**, and never edit it in a checkout
  expecting the change to travel. Machine toggles (`skipDangerousModePermissionPrompt` and the
  like) belong in the live file only; a permission every machine should have belongs in the
  template.
- Changing the template does not change any machine. `install.sh` seeds the live file once and
  after that treats it as untouchable, so a template edit reaches a machine only when a human
  merges it — which is what `conf.d/60-claude.fish` and the installer's own note are for. Both
  ask the same question, `settings.json.example -nt settings.json`, so they can never disagree;
  `touch ~/.claude/settings.json` is the "I have looked and I am keeping mine" answer.
- `test/syntax.sh` parses `*.json.example` as JSON alongside `*.json`. A template that does not
  parse is a broken machine one `cp` later.

### Switchboard (macOS only)

The night shift's Mac half: `bin/switchboard-runner` (stowed to `~/bin`) and the LaunchAgent
plist that runs it every five minutes (the VM's timer is the one-minute one: it is woken for a job and should notice it fast; the Mac is never woken and its slots are on the hour). The operating story — keychain items, `runner.env`,
`launchctl bootstrap`, the log, TCC — is in the README section of the same name. What an agent
changing this needs to know is narrower:

- **The wrapper exists to keep `op` out of the loop.** `d1 switchboard pull` resolves its
  configuration as "the environment wins, the vault is the fallback", and on the Mac that
  fallback is 1Password. From launchd, every `op` call is a fresh process the 1Password app may
  ask to approve — every tick, forever. So the wrapper's contract is that `SWITCHBOARD_URL`
  and `SWITCHBOARD_TOKEN_MAC` are **always** in the environment before `d1` starts. Anything
  that could leave one of them unset must fail the tick loudly instead, and
  `test/switchboard-test.sh` asserts a stub `op` is never invoked. Do not soften that into a
  warning.

- **`SWITCHBOARD_CHECKOUT_FF2K`, `WARD_WORKSPACE` and `DAYONE_HOME` are an interface**, shared
  with dayone's checkout-aware runner. They are spelled the same on both sides on purpose; a
  rename here is a rename there.

- **Never `exec` the `d1` call.** `exec` throws away the EXIT trap along with the shell, the
  lock directory survives forever, and every later tick skips — the night shift stops happening
  and nothing says so. `rclone/bin/rclone-cron.sh` carries the same warning for the same reason.

- **The plist is copied, not stowed into place.** It is tracked at
  `switchboard/.config/switchboard/com.crumley.switchboard-runner.plist` and `install.sh`
  (`ensure_switchboard_agent`) copies it to `~/Library/LaunchAgents/`. Apple documents nothing
  either way about launchd following a symlink there, and "works until the next reboot" is the
  worst failure mode available. The tracked file carries no username and no home path — launchd
  expands neither — which is why the job runs through `/bin/sh -lc`, the same login-shell trick
  Ghostty uses to get a real `PATH`. Keep it that way: rendering a path into the installed copy
  would put machine state in a generated file and make "is this machine current?" a judgement
  instead of a byte comparison.

- **It is macOS-only but tested everywhere.** `test/switchboard-test.sh` runs the real wrapper
  against a throwaway `$HOME` with a stubbed `d1`, `security` and `op`, so it runs on both halves
  of the CI matrix. Without that, the package would be exercised on exactly one machine in the
  world. What genuinely cannot be checked from Linux — that launchd loads the agent, that
  `security` does not prompt, that `d1` finds `claude` — is listed at the top of that file.

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
