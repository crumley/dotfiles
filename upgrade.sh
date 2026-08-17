#!/usr/bin/env bash
#
# upgrade.sh -- bring installed software up to date.
#
# What changed from the two-line version: it no longer assumes macOS and no
# longer runs `brew bundle dump --force`. That dump overwrote the Brewfile with
# whatever happened to be installed on the machine, which turns a curated,
# hand-maintained list into a snapshot of accumulated junk -- including
# everything pulled in by a one-off experiment. The Brewfile is now an
# intentional file, so `--dump` here writes Brewfile.generated instead and
# leaves it to you to diff.

set -euo pipefail

DOTFILES_REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
export DOTFILES_REPO

# shellcheck source=lib/common.sh
. "$DOTFILES_REPO/lib/common.sh"

DUMP=0

usage() {
  cat <<'EOF'
Usage: ./upgrade.sh [OPTIONS]

Updates installed software. On macOS that means Homebrew; on Linux it does
nothing, because these dotfiles configure packages there but never install or
upgrade them -- that is the system package manager's job.

Options:
      --dump    Write the current Homebrew state to Brewfile.generated so it can
                be diffed against the curated Brewfile. Never overwrites it.
  -q, --quiet   Only print warnings and errors.
  -h, --help    This.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)  usage; exit 0 ;;
    --dump)     DUMP=1 ;;
    -q|--quiet) DOTFILES_QUIET=1 ;;
    *)          die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

PLATFORM=$(dotfiles_platform)

if [ "$PLATFORM" != darwin ]; then
  say "$PLATFORM: nothing to upgrade (these dotfiles do not manage packages here)."
  exit 0
fi

if ! have brew; then
  die "Homebrew is not installed. Run ./install.sh first."
fi

say "Updating Homebrew..."
brew update

say "Upgrading formulae and casks..."
brew upgrade

if [ -f "$DOTFILES_REPO/Brewfile" ]; then
  say "Checking the Brewfile against what is installed..."
  # This is the inversion that matters. The old line was `brew bundle dump
  # --force`, which let the machine overwrite the manifest: everything ever
  # installed for a one-off experiment got written back into the Brewfile, and
  # every hand-written comment and deliberate omission was lost. It rewrote in
  # place rather than erroring, so the loss was silent. `check` runs the
  # relationship the right way round -- the curated manifest audits the machine
  # and reports what has drifted. --no-upgrade so it reports, rather than
  # quietly deciding to install things.
  if brew bundle check --file "$DOTFILES_REPO/Brewfile" --no-upgrade --verbose; then
    :
  else
    say "Run './install.sh --brew-bundle' to install what is missing."
  fi
fi

if [ "$DUMP" = 1 ]; then
  out="$DOTFILES_REPO/Brewfile.generated"
  warn "the Brewfile is hand-curated: this writes Brewfile.generated, and copying it"
  warn "over the Brewfile wholesale would throw that curation away."
  brew bundle dump --force --file "$out"
  say "Wrote $out. Diff it against the Brewfile and copy over what belongs:"
  say "    diff -u Brewfile Brewfile.generated"
fi

say "Done."
