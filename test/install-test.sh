#!/usr/bin/env bash
#
# End-to-end tests for install.sh.
#
# Every test runs against a throwaway home under $TMPDIR. Nothing here touches
# the real $HOME -- that is what DOTFILES_TARGET is for, and it is why the
# installer suppresses every machine-level step (Homebrew, macOS defaults,
# agent skills) as soon as the target is not your home directory.
#
#   ./test/install-test.sh
#
# Exit status is 0 only if every check passed.

set -uo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
PASS=0
FAIL=0
HOMES=""

ok()    { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()   { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
group() { printf '\n%s\n' "$1"; }

# assert "description" cmd...   -- passes when cmd succeeds
# refute "description" cmd...   -- passes when cmd fails
assert() { local d=$1; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
refute() { local d=$1; shift; if "$@"; then bad "$d"; else ok "$d"; fi; }

real_dir()   { [ -d "$1" ] && [ ! -L "$1" ]; }
dangling()   { [ -L "$1" ] && [ ! -e "$1" ]; }
relative_link() { local t; t=$(readlink "$1") && case "$t" in /*) return 1 ;; *) return 0 ;; esac; }
same()       { [ "$1" = "$2" ]; }
grep_out()   { printf '%s' "$2" | grep -q -- "$1"; }
entry_count() { [ "$(find "$1" ! -type d | wc -l | tr -d ' ')" = "$2" ]; }

newhome() {
  local d
  d=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")
  HOMES="$HOMES $d"
  printf '%s\n' "$d"
}

STALE_SRC=""
cleanup() {
  local d
  [ -n "$STALE_SRC" ] && rm -f "$STALE_SRC"
  for d in $HOMES; do
    case "$d" in
      "$HOME"|"$HOME"/*|/|'') printf 'refusing to clean %s\n' "$d" >&2 ;;
      *) rm -rf "$d" ;;
    esac
  done
}
trap cleanup EXIT

# mode, size, mtime -- BSD and GNU stat spell this differently.
statline() {
  if stat -c '%a %s %Y' "$1" >/dev/null 2>&1; then
    stat -c '%a %s %Y' "$1"
  else
    stat -f '%Lp %z %m' "$1"
  fi
}

# A fingerprint of a tree, used to prove that a run changed nothing.
snapshot() {
  local root=$1 p
  find "$root" -mindepth 1 | sort | while IFS= read -r p; do
    printf '%s|%s|%s\n' "$(statline "$p")" "$(readlink "$p" 2>/dev/null || printf -- '-')" "${p#"$root"}"
  done
}

install_into() {
  local target=$1
  shift
  DOTFILES_TARGET="$target" "$REPO/install.sh" "$@"
}

# Same, with all output swallowed: used when only the exit status matters.
install_quietly() {
  install_into "$@" >/dev/null 2>&1
}

install_linux() {
  local target=$1
  shift
  DOTFILES_PLATFORM=linux DOTFILES_TARGET="$target" "$REPO/install.sh" "$@" >/dev/null 2>&1
}

shellcheck_all() {
  (cd "$REPO" && shellcheck -x install.sh upgrade.sh macos/defaults.sh \
      macos/launchd-path.sh lib/common.sh lib/packages.sh lib/stow.sh \
      test/install-test.sh)
}

# ---------------------------------------------------------------------------

group "Guardrails"
assert "the real HOME is never the target" [ -z "${DOTFILES_TARGET:-}" ]

group "Package discovery and the platform map"
darwin_list=$(DOTFILES_PLATFORM=darwin "$REPO/install.sh" --list)
linux_list=$(DOTFILES_PLATFORM=linux "$REPO/install.sh" --list)
assert "starship is discovered (the old hardcoded list missed it)" grep_out '^starship$' "$darwin_list"
assert "macOS keeps hammerspoon" grep_out '^hammerspoon$' "$darwin_list"
refute "Linux skips hammerspoon" grep_out '^hammerspoon$' "$linux_list"
refute "Linux skips karabiner"   grep_out '^karabiner$' "$linux_list"
assert "Linux gets espanso (supported since 2.3.0)" grep_out '^espanso$' "$linux_list"
assert "Linux gets ghostty (its config schema is platform-independent)" \
  grep_out '^ghostty$' "$linux_list"
assert "Linux still gets fish"   grep_out '^fish$' "$linux_list"

group "Clean install"
h1=$(newhome)
assert "install exits 0" install_into "$h1" -q
assert "the atuin config is a symlink" [ -L "$h1/.config/atuin/config.toml" ]
assert "starship is linked" [ -L "$h1/.config/starship.toml" ]
assert "links are relative, so stow owns them" relative_link "$h1/.config/atuin/config.toml"
assert "--no-folding: ~/.config is a real directory, not a link into the repo" real_dir "$h1/.config"
assert "git-by-date lands in ~/bin, which is on PATH" [ -L "$h1/bin/git-by-date" ]
assert "rclone-cron.sh lands in ~/bin too" [ -L "$h1/bin/rclone-cron.sh" ]
refute "nothing is installed into ~/.bin any more" [ -e "$h1/.bin" ]

assert "git's tracked config stows to .gitconfig.global" [ -L "$h1/.gitconfig.global" ]
refute "the home .gitconfig itself is never a symlink" [ -L "$h1/.gitconfig" ]
assert "the home .gitconfig is a real generated file" [ -f "$h1/.gitconfig" ]
assert "the home .gitconfig includes .gitconfig.global" grep -qxF "$(printf '\tpath = ~/.gitconfig.global')" "$h1/.gitconfig"
assert "bash's tracked config stows to .bashrc.tracked" [ -L "$h1/.bashrc.tracked" ]
assert "bash's tracked login config stows to .bash_profile.tracked" [ -L "$h1/.bash_profile.tracked" ]
refute "the home .bashrc itself is never a symlink" [ -L "$h1/.bashrc" ]
assert "the home .bashrc is a real generated stub" [ -f "$h1/.bashrc" ]
assert "the home .bashrc sources .bashrc.tracked" grep -qF '.bashrc.tracked' "$h1/.bashrc"
assert "the home .bash_profile sources .bash_profile.tracked" grep -qF '.bash_profile.tracked' "$h1/.bash_profile"
assert "home's tracked profile stows to .profile.tracked" [ -L "$h1/.profile.tracked" ]
refute "the home .profile itself is never a symlink" [ -L "$h1/.profile" ]
assert "the home .profile sources .profile.tracked" grep -qF '.profile.tracked' "$h1/.profile"

group "Idempotency"
before=$(snapshot "$h1")
assert "second run exits 0" install_into "$h1" -q
assert "second run leaves the tree byte-identical" same "$before" "$(snapshot "$h1")"

group "Conflicts are refused by default"
h2=$(newhome)
install_into "$h2" -q
rm "$h2/.config/atuin/config.toml"
printf '## generated by atuin\n' >"$h2/.config/atuin/config.toml"          # (a) plain file
rm "$h2/.ripgreprc"; mkdir "$h2/.ripgreprc"; touch "$h2/.ripgreprc/junk"   # (b) directory
rm "$h2/.gitconfig.global"; ln -s /etc/hosts "$h2/.gitconfig.global"       # (c) foreign symlink
rm "$h2/.inputrc"; ln -s "$REPO/home/.inputrc" "$h2/.inputrc"              # (d) absolute link
rm -r "$h2/.config/mise"; printf 'x\n' >"$h2/.config/mise"                 # (e) file where a dir goes
before=$(snapshot "$h2")
out=$(install_into "$h2" 2>&1)
refute "install refuses and exits non-zero" install_quietly "$h2"
assert "a refused install changes nothing at all" same "$before" "$(snapshot "$h2")"
assert "names the Atuin file"                 grep_out '.config/atuin/config.toml' "$out"
assert "names the directory"                  grep_out '.ripgreprc' "$out"
assert "names the foreign symlink"            grep_out '.gitconfig.global' "$out"
assert "names the absolute symlink"           grep_out '.inputrc' "$out"
assert "names the file blocking a directory"  grep_out '.config/mise' "$out"
assert "says what to do about it"             grep_out '\-\-takeover' "$out"

group "Dry run"
before=$(snapshot "$h2")
assert "dry run with --takeover exits 0" install_into "$h2" --dry-run --takeover -q
assert "dry run changes nothing" same "$before" "$(snapshot "$h2")"

group "Takeover"
assert "takeover exits 0" install_into "$h2" --takeover -q
assert "the atuin config is linked again"        [ -L "$h2/.config/atuin/config.toml" ]
assert "the directory was replaced by a link"    [ -L "$h2/.ripgreprc" ]
assert "the foreign symlink was replaced"        [ -L "$h2/.gitconfig.global" ]
assert "the absolute symlink was replaced"       relative_link "$h2/.inputrc"
assert "the blocked directory exists again"      real_dir "$h2/.config/mise"
backup=$(find "$h2/.dotfiles-backup" -mindepth 1 -maxdepth 1 -type d | head -1)
assert "the Atuin file is in the backup, path preserved" [ -f "$backup/.config/atuin/config.toml" ]
assert "with its contents intact" grep -q 'generated by atuin' "$backup/.config/atuin/config.toml"
assert "the directory was backed up whole"  [ -f "$backup/.ripgreprc/junk" ]
assert "the foreign symlink was backed up"  [ -L "$backup/.gitconfig.global" ]
assert "exactly the five conflicting paths were backed up, nothing else" entry_count "$backup" 5
before=$(snapshot "$h2")
install_into "$h2" -q
assert "post-takeover rerun is still a no-op" same "$before" "$(snapshot "$h2")"

group "A tree the old installer folded into the repository"
h3=$(newhome)
stow --dir "$REPO" --target "$h3" --dotfiles atuin home   # stow's default: folding
assert "setup: ~/.config is a fold into the repo" [ -L "$h3/.config" ]
assert "install over a folded tree exits 0" install_into "$h3" -q
assert "the fold was unfolded into a real directory" real_dir "$h3/.config"
assert "repository content was not moved out of the repo" [ -f "$REPO/atuin/.config/atuin/config.toml" ]
refute "nothing was backed up: none of it was a real conflict" [ -d "$h3/.dotfiles-backup" ]

group "Pruning links to files the repository no longer has"
h6=$(newhome)
STALE_SRC="$REPO/rg/.ripgreprc-stale-test"
printf 'temporary\n' >"$STALE_SRC"
install_into "$h6" -q
assert "setup: a new file in a package gets linked" [ -L "$h6/.ripgreprc-stale-test" ]
rm -f "$STALE_SRC"
assert "setup: deleting it from the repo leaves a dangling link" dangling "$h6/.ripgreprc-stale-test"
printf 'mine\n' >"$h6/.a-real-file"
ln -s /etc/hosts "$h6/.a-foreign-link"
ln -s /nowhere/at/all "$h6/.a-foreign-dangling-link"
mkdir -p "$h6/.dotfiles-backup/manual"
ln -s "$REPO/rg/.ripgreprc-stale-test" "$h6/.dotfiles-backup/manual/rescued"
assert "--no-prune leaves the stale link alone" install_into "$h6" -q --no-prune
assert "  ... it is still there" [ -L "$h6/.ripgreprc-stale-test" ]
assert "the default run prunes it" install_into "$h6" -q
refute "the stale link is gone" [ -e "$h6/.ripgreprc-stale-test" ]
refute "  ... really gone, not just broken" [ -L "$h6/.ripgreprc-stale-test" ]
assert "a real file is untouched" [ -f "$h6/.a-real-file" ]
assert "a symlink pointing outside the repo is untouched" [ -L "$h6/.a-foreign-link" ]
assert "even a dangling one, if it points outside the repo" [ -L "$h6/.a-foreign-dangling-link" ]
assert "backups are never pruned" [ -L "$h6/.dotfiles-backup/manual/rescued" ]
assert "working links survive" [ -L "$h6/.ripgreprc" ]
before=$(snapshot "$h6")
install_into "$h6" -q
assert "and the run after a prune is a no-op again" same "$before" "$(snapshot "$h6")"

group "Subsets and bad input"
h4=$(newhome)
assert "installing a subset exits 0" install_into "$h4" -q fish git starship
refute "packages outside the subset are left alone" [ -e "$h4/.vimrc" ]
refute "an unknown package is an error" install_quietly "$h4" nosuchpackage
refute "asking for a macOS package on Linux is refused" install_linux "$h4" hammerspoon
assert "git was selected: ~/.gitconfig was generated" [ -f "$h4/.gitconfig" ]
refute "bash was not selected: ~/.bashrc was not generated" [ -e "$h4/.bashrc" ]
refute "home was not selected: ~/.profile was not generated" [ -e "$h4/.profile" ]

group "Clobber-safe stubs"
h7=$(newhome)
printf '[user]\n\tname = Someone Else\n' >"$h7/.gitconfig"      # pre-existing, unrelated content
install_into "$h7" -q
assert "a pre-existing ~/.gitconfig is not replaced" grep -qF 'name = Someone Else' "$h7/.gitconfig"
assert "the include was prepended, not appended" \
  [ "$(grep -n 'path = ~/.gitconfig.global' "$h7/.gitconfig" | cut -d: -f1)" -lt \
    "$(grep -n 'name = Someone Else' "$h7/.gitconfig" | cut -d: -f1)" ]
before=$(snapshot "$h7")
install_into "$h7" -q
assert "rerunning does not duplicate the include" \
  [ "$(grep -c 'path = ~/.gitconfig.global' "$h7/.gitconfig")" = 1 ]
assert "and touches nothing" same "$before" "$(snapshot "$h7")"

h8=$(newhome)
install_into "$h8" -q
printf '\n# >>> some installer >>>\nexport SOME_TOOL_HOME=/opt/some-tool\n' >>"$h8/.bashrc"
before_tracked=$(readlink "$h8/.bashrc.tracked")
install_into "$h8" -q
assert "a tool's append to ~/.bashrc survives a rerun" grep -qF 'SOME_TOOL_HOME' "$h8/.bashrc"
assert "the source line is still there too, exactly once" \
  [ "$(grep -c '.bashrc.tracked' "$h8/.bashrc")" = 1 ]
assert "the .bashrc.tracked symlink itself was untouched" same "$before_tracked" "$(readlink "$h8/.bashrc.tracked")"

h9=$(newhome)
mkdir -p "$h9"
# Simulates a machine last installed before .bashrc moved to .bashrc.tracked:
# a symlink into the repo, at the *old* path, which no longer exists there.
ln -s "$REPO/bash/.bashrc" "$h9/.bashrc"
assert "setup: .bashrc is a dangling symlink into the repo (the file was renamed away)" dangling "$h9/.bashrc"
assert "install migrates it cleanly" install_into "$h9" -q
refute "the old symlink is gone" [ -L "$h9/.bashrc" ]
assert "the home .bashrc is now a real generated stub" [ -f "$h9/.bashrc" ]
assert "and it sources the tracked file" grep -qF '.bashrc.tracked' "$h9/.bashrc"

group "macOS launchd PATH"
h10=$(newhome)
mock_bin="$h10/mock-bin"
brew_prefix="$h10/homebrew"
launchd_log="$h10/launchd.log"
mkdir -p "$mock_bin" "$brew_prefix/bin" "$brew_prefix/sbin"
cat >"$mock_bin/launchctl" <<'EOF'
#!/bin/sh
case "$1" in
  getenv) printf '%s\n' "${FAKE_LAUNCHD_PATH:-}" ;;
  *)      printf 'launchctl %s\n' "$*" >>"$FAKE_LAUNCHD_LOG" ;;
esac
EOF
cat >"$mock_bin/sudo" <<'EOF'
#!/bin/sh
printf 'sudo %s\n' "$*" >>"$FAKE_LAUNCHD_LOG"
exec "$@"
EOF
chmod +x "$mock_bin/launchctl" "$mock_bin/sudo"
expected_path="$brew_prefix/bin:$brew_prefix/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
: >"$launchd_log"
FAKE_LAUNCHD_LOG="$launchd_log" FAKE_LAUNCHD_PATH='' \
  PATH="$mock_bin:/usr/bin:/bin" "$REPO/macos/launchd-path.sh" "$brew_prefix" >/dev/null
assert "persists the detected Homebrew prefix in launchd's user PATH" \
  grep -qxF "launchctl config user path $expected_path" "$launchd_log"
assert "uses sudo only for launchd's persistent configuration" \
  grep -qxF "sudo $mock_bin/launchctl config user path $expected_path" "$launchd_log"
assert "updates the current login session immediately" \
  grep -qxF "launchctl setenv PATH $expected_path" "$launchd_log"

: >"$launchd_log"
FAKE_LAUNCHD_LOG="$launchd_log" FAKE_LAUNCHD_PATH="$expected_path" \
  PATH="$mock_bin:/usr/bin:/bin" "$REPO/macos/launchd-path.sh" "$brew_prefix" >/dev/null
assert "an already-correct launchd PATH is a no-op" [ ! -s "$launchd_log" ]

: >"$launchd_log"
out=$(FAKE_LAUNCHD_LOG="$launchd_log" FAKE_LAUNCHD_PATH='' \
  DOTFILES_DRY_RUN=1 PATH="$mock_bin:/usr/bin:/bin" \
  "$REPO/macos/launchd-path.sh" "$brew_prefix")
assert "launchd PATH dry-run reports the resolved path" grep_out "$expected_path" "$out"
assert "launchd PATH dry-run changes nothing" [ ! -s "$launchd_log" ]

group "No duplicated lines, ever"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
. "$REPO/lib/common.sh"
h5=$(newhome)
append_line_once "$h5/f" "a line" || true
append_line_once "$h5/f" "a line" || true
append_line_once "$h5/f" "a line" || true
assert "append_line_once is idempotent" [ "$(grep -c 'a line' "$h5/f")" = 1 ]

group "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  assert "every script is shellcheck-clean" shellcheck_all
else
  printf '  skip shellcheck is not installed\n'
fi

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
