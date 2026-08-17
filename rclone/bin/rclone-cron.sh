#!/usr/bin/env bash
#
# Mirror ~/Documents/brain2 to the `drive:` remote. Meant to be run from cron.
#
# Install (Linux, and macOS if you have granted cron Full Disk Access):
#
#   crontab -e
#   */10 * * * * "$HOME/bin/rclone-cron.sh" >>/tmp/rclone-cron.log 2>&1
#
# The path must be absolute. cron runs jobs with a near-empty environment and an
# unspecified working directory, which is why the previous version of this
# script — `./.bin/rclone-cron.sh` syncing a relative `./Documents/brain2` —
# only worked when cron happened to start in $HOME, and silently synced the
# wrong thing (or nothing) when it did not.
#
# On macOS, launchd is the better host for this than cron; see the note at the
# bottom of this file.
#
# If the Drive token expires:  rclone config reconnect drive:

set -euo pipefail

SRC="${RCLONE_CRON_SRC:-$HOME/Documents/brain2}"
DST="${RCLONE_CRON_DST:-drive:brain2}"

# cron's PATH is typically just /usr/bin:/bin, so `command -v rclone` alone
# finds nothing even when rclone is installed. Look where the package managers
# actually put it: Homebrew on Apple Silicon (/opt/homebrew), Homebrew on Intel
# and manual installs (/usr/local), and distro packages (/usr/bin). The old
# hardcoded /usr/local/bin/rclone is only ever right on one of those.
find_rclone() {
  if command -v rclone >/dev/null 2>&1; then
    command -v rclone
    return 0
  fi
  local candidate
  for candidate in /opt/homebrew/bin/rclone /usr/local/bin/rclone /usr/bin/rclone "$HOME/.local/bin/rclone"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

if ! RCLONE="$(find_rclone)"; then
  echo "rclone-cron: rclone not found on PATH or in the usual install locations" >&2
  exit 1
fi

if [ ! -d "$SRC" ]; then
  echo "rclone-cron: source directory does not exist: $SRC" >&2
  exit 1
fi

# Interlock. The previous version wrote a PID file and never read it back — its
# own comment said as much — so a sync slower than the cron interval would
# happily start on top of itself. `mkdir` is atomic on every POSIX filesystem,
# which makes a directory the simplest correct lock. Note that /tmp is
# per-machine, which is what we want: this guards concurrent runs here, not
# concurrent runs across hosts.
LOCKDIR="${TMPDIR:-/tmp}/rclone-cron.lock"
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  echo "rclone-cron: another run holds $LOCKDIR; skipping this tick" >&2
  exit 0
fi
# shellcheck disable=SC2064  # expand LOCKDIR now, on purpose: it never changes
trap "rm -rf -- '$LOCKDIR'" EXIT
echo "$$" > "$LOCKDIR/pid"

# Any arguments given to this script are passed through to rclone, so the exact
# thing cron runs can be rehearsed by hand:  rclone-cron.sh --dry-run -v
#
# ${@+"$@"} rather than "$@" so `set -u` does not trip on bash 3.2 (still what
# /bin/bash is on macOS) when there are no arguments.
#
# Deliberately NOT `exec`: exec replaces this shell with rclone, which throws
# away the EXIT trap along with it and leaves $LOCKDIR behind forever — after
# which every later run skips its tick and the sync quietly stops happening.
"$RCLONE" sync ${@+"$@"} -- "$SRC" "$DST"

# macOS note: cron still works, but it is deprecated on Darwin and a cron job
# cannot read ~/Documents without Full Disk Access granted to /usr/sbin/cron,
# so a sync that works by hand can fail silently from cron. A LaunchAgent
# (~/Library/LaunchAgents/*.plist with StartInterval) is the supported path and
# gets its own TCC prompt.
