#!/usr/bin/env bash
#
# Tests for the b3sync package: the wrapper launchd and Hammerspoon both call,
# the LaunchAgent plist, the installer step that copies it into place, and the
# Hammerspoon module's transition logic.
#
#   ./test/b3sync-test.sh        (or: ./test/run.sh b3sync)
#
# Every wrapper test runs the real b3-sync-runner against a throwaway $HOME
# with stubs on PATH: a `b3` that records its argv and PATH and prints canned
# JSON in the shape of b3's `sync --commit --json` contract, and an `osascript`
# that records the notification it was asked to raise. Nothing here needs
# macOS, launchd, Hammerspoon, a vault, a network, or a real b3.
#
# The Hammerspoon module is exercised by test/b3sync-hammerspoon.lua under a
# plain Lua interpreter with a fake `hs`; it is skipped, loudly, where no Lua
# is installed.
#
# What cannot be tested from here, and is said so in the README and the PR:
# that launchd loads the agent and fires it on schedule, that the login shell's
# PATH carries b3 (and bun) under launchd, that the caffeinate watcher's
# leaving sync starts before a closing lid puts the machine to sleep, and that
# the notification actually appears.
#
# Exit status is 0 only if every check passed.

set -uo pipefail
unset CDPATH

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
RUNNER="$REPO/b3sync/bin/b3-sync-runner"
PLIST="$REPO/b3sync/.config/b3sync/com.crumley.b3-sync.plist"
MODULE="$REPO/hammerspoon/.hammerspoon/brainsync.lua"
LUA_TEST="$REPO/test/b3sync-hammerspoon.lua"

PASS=0
FAIL=0
SKIP=0
HOMES=""

ok() {
    PASS=$((PASS + 1))
    printf '  ok   %s\n' "$1"
}
bad() {
    FAIL=$((FAIL + 1))
    printf '  FAIL %s\n' "$1" >&2
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        printf '::error title=b3sync check::%s\n' "$1"
    fi
}
skipped() {
    SKIP=$((SKIP + 1))
    printf '  SKIP %s\n' "$1"
}
group() { printf '\n%s\n' "$1"; }

assert() {
    local d=$1
    shift
    if "$@"; then ok "$d"; else bad "$d"; fi
}
refute() {
    local d=$1
    shift
    if "$@"; then bad "$d"; else ok "$d"; fi
}
same() {
    if [ "$2" = "$3" ]; then
        ok "$1"
    else
        bad "$1 (expected '$3', got '$2')"
    fi
}
contains() {
    local d=$1 hay=$2 needle=$3
    case "$hay" in
        *"$needle"*) ok "$d" ;;
        *) bad "$d (no '$needle' in: $(printf '%s' "$hay" | tr '\n' '|'))" ;;
    esac
}
lacks() {
    local d=$1 hay=$2 needle=$3
    case "$hay" in
        *"$needle"*) bad "$d (found '$needle')" ;;
        *) ok "$d" ;;
    esac
}

cleanup() {
    local d
    for d in $HOMES; do
        case "$d" in
            "$HOME" | "$HOME"/* | / | '') printf 'refusing to clean %s\n' "$d" >&2 ;;
            *) rm -rf "$d" ;;
        esac
    done
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# A sandbox: a throwaway home with the stubs on PATH.
# ---------------------------------------------------------------------------

# newbox -> prints the sandbox path. $1/stubs holds b3 and osascript; $1/b3.*
# configure and record the b3 stub.
newbox() {
    local h
    h=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-b3sync.XXXXXX") || return 1
    case "$h" in
        "$HOME" | "$HOME"/Library | "$HOME"/Library/*) return 1 ;;
    esac
    HOMES="$HOMES $h"
    mkdir -p "$h/stubs"

    # b3.hook, if present, runs once, inside the first b3 call -- that is,
    # while the runner under test holds the lock. It is how a second trigger
    # is made to arrive in the middle of a sync.
    cat >"$h/stubs/b3" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$h/b3.calls"
printf '%s\n' "\$PATH" > "$h/b3.path"
code=\$(cat "$h/b3.exit" 2>/dev/null || echo 0)
if [ -f "$h/b3.hook" ]; then
  mv "$h/b3.hook" "$h/b3.hook.run"
  sh "$h/b3.hook.run" >> "$h/hook.out" 2>&1
fi
[ -f "$h/b3.stdout" ] && cat "$h/b3.stdout"
[ -f "$h/b3.stderr" ] && cat "$h/b3.stderr" >&2
exit "\$code"
EOF

    cat >"$h/stubs/osascript" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$h/osascript.calls"
EOF

    chmod +x "$h/stubs/b3" "$h/stubs/osascript"
    cat >"$h/b3.stdout" <<'EOF'
{
  "committed": 2,
  "deferred": [],
  "converged": true,
  "pulled": 1,
  "pushed": 1,
  "commits": [],
  "files": []
}
EOF
    printf '%s\n' "$h"
}

# The environment every run gets: nothing of the caller's b3sync or Homebrew
# settings, a home that is the sandbox, and the stubs first on PATH.
box_env() {
    local h=$1
    printf '%s\n' env -u B3SYNC_LOG -u B3SYNC_LOCK -u B3SYNC_LOG_MAX_BYTES \
        -u B3SYNC_LOCK_STALE_MINUTES -u B3SYNC_PYTHON -u HOMEBREW_PREFIX \
        -u BUN_INSTALL -u MISE_DATA_DIR -u XDG_DATA_HOME -u B3_HOME \
        HOME="$h" PATH="$h/stubs:/usr/bin:/bin:/usr/sbin:/sbin"
}

# run_box HOME [args...] -- runs the runner. Extra environment goes in the
# RUNNER_ENV array, which is reset afterwards. Sets RUNNER_STATUS, RUNNER_OUT.
RUNNER_ENV=()
run_box() {
    local h=$1
    shift
    RUNNER_OUT=$(
        env -u B3SYNC_LOG -u B3SYNC_LOCK -u B3SYNC_LOG_MAX_BYTES \
            -u B3SYNC_LOCK_STALE_MINUTES -u B3SYNC_PYTHON -u HOMEBREW_PREFIX \
            -u BUN_INSTALL -u MISE_DATA_DIR -u XDG_DATA_HOME -u B3_HOME \
            HOME="$h" \
            PATH="$h/stubs:/usr/bin:/bin:/usr/sbin:/sbin" \
            ${RUNNER_ENV[@]+"${RUNNER_ENV[@]}"} \
            bash "$RUNNER" ${@+"$@"} 2>&1
    )
    RUNNER_STATUS=$?
    RUNNER_ENV=()
}

# A second trigger, fired from inside the first b3 call.
hook_waiter() {
    local h=$1
    shift
    printf '%s bash %s' "$(box_env "$h" | tr '\n' ' ')" "$RUNNER" >"$h/b3.hook"
    printf ' %s' "$@" >>"$h/b3.hook"
    printf '\n' >>"$h/b3.hook"
}

logfile() { printf '%s\n' "$1/Library/Logs/b3-sync.log"; }
logtext() { cat "$(logfile "$1")" 2>/dev/null; }
lockdir() { printf '%s\n' "$1/Library/Caches/b3-sync-runner.lock"; }
calls() { cat "$1/b3.calls" 2>/dev/null; }
ncalls() { if [ -f "$1/b3.calls" ]; then wc -l <"$1/b3.calls" | tr -d ' '; else echo 0; fi; }
ran_b3() { [ -f "$1/b3.calls" ]; }

# ---------------------------------------------------------------------------

printf 'b3sync package tests\n'
if [ ! -x "$RUNNER" ]; then
    bad "b3sync/bin/b3-sync-runner is missing or not executable"
    printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
    exit 1
fi

group 'the happy path'

BOX=$(newbox)
run_box "$BOX"
same 'a clean sync exits 0' "$RUNNER_STATUS" 0
same 'runs `b3 sync --commit --json`' "$(calls "$BOX")" 'sync --commit --json'
same 'prints exactly the summary line on stdout (what the hotkey alert shows)' \
    "$RUNNER_OUT" 'ok: committed 2, pulled 1, pushed 1'
contains 'logs one timestamped line with the reason' "$(logtext "$BOX")" \
    '[manual] ok: committed 2, pulled 1, pushed 1'
same 'and only one line' "$(logtext "$BOX" | wc -l | tr -d ' ')" 1
refute 'the lock is released afterwards (the trap survives, so no exec)' \
    test -e "$(lockdir "$BOX")"
refute 'no notification for a success' test -e "$BOX/osascript.calls"

BOX=$(newbox)
run_box "$BOX" --reason leave --settle 0
same 'extra arguments pass straight through; --reason is the runner'"'"'s own' \
    "$(calls "$BOX")" 'sync --commit --json --settle 0'
contains 'and labels the log line' "$(logtext "$BOX")" '[leave] ok:'

BOX=$(newbox)
printf '{"committed": 0, "deferred": [], "converged": true, "pulled": 0, "pushed": 0}\n' >"$BOX/b3.stdout"
run_box "$BOX"
same 'nothing to do says so' "$RUNNER_OUT" 'ok: already converged'

group 'a sync that deferred files still being edited'

BOX=$(newbox)
cat >"$BOX/b3.stdout" <<'EOF'
{
  "committed": 1,
  "deferred": ["journal/2026-09-29.md", "pages/Laptop Sync.md"],
  "converged": false,
  "pulled": 0,
  "pushed": 0
}
EOF
run_box "$BOX" --reason schedule
same 'exits 0 -- deferring is the design, not a failure' "$RUNNER_STATUS" 0
contains 'logs the deferred files by name' "$(logtext "$BOX")" 'journal/2026-09-29.md, pages/Laptop Sync.md'
contains 'says it did not converge' "$(logtext "$BOX")" 'not converged'
contains 'and what it did commit' "$(logtext "$BOX")" 'committed 1'
refute 'raises no notification' test -e "$BOX/osascript.calls"

group 'a b3 failure is loud'

BOX=$(newbox)
rm -f "$BOX/b3.stdout"
printf '1\n' >"$BOX/b3.exit"
cat >"$BOX/b3.stderr" <<'EOF'
{
  "error": "pull --rebase hit a conflict the union driver could not resolve -- the rebase is paused with markers in: journal/2026-09-29.md.",
  "hint": "Resolve the markers, then rerun `b3 sync`."
}
EOF
run_box "$BOX" --reason arrive
same "b3's failure is the runner's exit status" "$RUNNER_STATUS" 1
contains 'the log line carries the error' "$(logtext "$BOX")" \
    '[arrive] error: b3 sync exited 1: pull --rebase hit a conflict'
contains "and b3's hint is kept beneath it" "$(logtext "$BOX")" '    "hint": "Resolve the markers'
contains 'a notification is raised' "$(cat "$BOX/osascript.calls" 2>/dev/null)" 'display notification'
contains 'naming the failure' "$(cat "$BOX/osascript.calls" 2>/dev/null)" 'rebase is paused'
refute 'and the lock is released' test -e "$(lockdir "$BOX")"

BOX=$(newbox)
rm -f "$BOX/b3.stdout"
printf '128\n' >"$BOX/b3.exit"
printf 'fatal: could not read from remote repository\n' >"$BOX/b3.stderr"
run_box "$BOX"
same 'a non-JSON failure passes its status on too' "$RUNNER_STATUS" 128
contains 'and logs its last line' "$(logtext "$BOX")" 'exited 128: fatal: could not read from remote repository'

BOX=$(newbox)
rm -f "$BOX/stubs/osascript" "$BOX/b3.stdout"
printf '1\n' >"$BOX/b3.exit"
if command -v osascript >/dev/null 2>&1; then
    skipped 'osascript exists on this machine, so "no osascript" cannot be exercised without a real notification'
else
    run_box "$BOX"
    same 'without osascript (Linux) a failure still exits with its status' "$RUNNER_STATUS" 1
    contains 'and still logs' "$(logtext "$BOX")" 'error: b3 sync exited 1'
fi

group 'the lock queues a trigger instead of dropping it'

BOX=$(newbox)
mkdir -p "$(lockdir "$BOX")"
printf '%s\n' "$$" >"$(lockdir "$BOX")/pid"
run_box "$BOX" --reason leave --settle 0
same 'a trigger that finds a live lock exits 0' "$RUNNER_STATUS" 0
refute 'and starts no second b3' ran_b3 "$BOX"
contains 'it logs that it queued' "$(logtext "$BOX")" '[leave] queued:'
same 'and leaves one marker holding its settle and reason' \
    "$(cat "$(lockdir "$BOX").pending" 2>/dev/null)" '0 leave'
assert 'the lock is left for its owner' test -d "$(lockdir "$BOX")"

run_box "$BOX" --reason schedule
same 'a laxer request (default settle) does not weaken the marker' \
    "$(cat "$(lockdir "$BOX").pending" 2>/dev/null)" '0 leave'

BOX=$(newbox)
mkdir -p "$(lockdir "$BOX")"
printf '%s\n' "$$" >"$(lockdir "$BOX")/pid"
run_box "$BOX" --reason schedule
run_box "$BOX" --reason far --settle 30
same 'a laxer numeric settle (30 > default 5) does not replace the default' \
    "$(cat "$(lockdir "$BOX").pending" 2>/dev/null)" 'default schedule'
run_box "$BOX" --reason leave --settle=0
same 'a stricter one (--settle=0) replaces it' \
    "$(cat "$(lockdir "$BOX").pending" 2>/dev/null)" '0 leave'

# The real sequence: the 18:00 run is in b3 when the lid closes. Two triggers
# arrive during it; exactly one more run follows, with the strictest settle.
BOX=$(newbox)
hook_waiter "$BOX" --reason leave --settle 0
{
    box_env "$BOX" | tr '\n' ' '
    printf 'bash %s --reason arrive\n' "$RUNNER"
} >>"$BOX/b3.hook"
run_box "$BOX" --reason schedule
same 'the holder exits 0' "$RUNNER_STATUS" 0
same 'b3 ran exactly twice: its own run, then one queued run' "$(ncalls "$BOX")" 2
same 'the queued run used the strictest settle asked for' \
    "$(sed -n 2p "$BOX/b3.calls" 2>/dev/null)" 'sync --commit --json --settle 0'
same 'the first run kept its own (default) settle' \
    "$(sed -n 1p "$BOX/b3.calls" 2>/dev/null)" 'sync --commit --json'
contains 'the queued run is labelled with the trigger that set it' "$(logtext "$BOX")" '[leave (queued)] ok:'
refute 'the marker is consumed' test -e "$(lockdir "$BOX").pending"
refute 'the lock is released' test -e "$(lockdir "$BOX")"
contains 'stdout carries both summaries' "$RUNNER_OUT" 'ok: committed 2, pulled 1, pushed 1
ok: committed 2, pulled 1, pushed 1'

# A queued run's failure is the holder's exit status.
BOX=$(newbox)
hook_waiter "$BOX" --reason leave --settle 0
# The stub reads its exit code before running the hook, so a b3.exit the hook
# writes belongs to the queued run alone.
printf 'printf "3\\n" > "%s/b3.exit"\n' "$BOX" >>"$BOX/b3.hook"
run_box "$BOX"
same 'a queued run that fails fails the holder' "$RUNNER_STATUS" 3
same 'even though the first run succeeded' "$(logtext "$BOX" | grep -c '\[manual\] ok:')" 1

group 'a lock left behind by a run that is gone'

BOX=$(newbox)
mkdir -p "$(lockdir "$BOX")"
sh -c 'exit 0' &
DEAD=$!
wait "$DEAD"
printf '%s\n' "$DEAD" >"$(lockdir "$BOX")/pid"
run_box "$BOX"
same 'a lock whose pid is dead is taken over' "$(ncalls "$BOX")" 1
refute 'and released after' test -e "$(lockdir "$BOX")"

BOX=$(newbox)
mkdir -p "$(lockdir "$BOX")"
printf '%s\n' "$$" >"$(lockdir "$BOX")/pid"
touch -t 202001010000 "$(lockdir "$BOX")"
run_box "$BOX"
same 'a lock older than the stale limit is taken over even with a live pid' "$(ncalls "$BOX")" 1

group '--dry-run'

BOX=$(newbox)
run_box "$BOX" --dry-run --settle 0
same 'exits 0' "$RUNNER_STATUS" 0
refute 'runs no b3' ran_b3 "$BOX"
contains 'prints the command it would run, arguments included' "$RUNNER_OUT" \
    "would run: $BOX/stubs/b3 sync --commit --json --settle 0"
contains 'and where the log is' "$RUNNER_OUT" "$(logfile "$BOX")"
refute 'writes no log' test -e "$(logfile "$BOX")"
refute 'takes no lock' test -e "$(lockdir "$BOX")"

group 'a machine without b3'

BOX=$(newbox)
rm -f "$BOX/stubs/b3"
run_box "$BOX"
same 'exits 0 (a tool may be absent)' "$RUNNER_STATUS" 0
contains 'with one clear log line' "$(logtext "$BOX")" 'skipped: b3 not found on PATH'
contains 'that says how to fix it' "$(logtext "$BOX")" 'mise run link'
refute 'and no notification' test -e "$BOX/osascript.calls"

BOX=$(newbox)
rm -f "$BOX/stubs/b3"
run_box "$BOX" --dry-run
contains 'a dry run says it would skip' "$RUNNER_OUT" 'would skip: b3 is not on PATH'

group 'finding b3 the way launchd needs it'

BOX=$(newbox)
mkdir -p "$BOX/.bun/bin"
mv "$BOX/stubs/b3" "$BOX/.bun/bin/b3"
run_box "$BOX"
same 'b3 only in ~/.bun/bin (where bun link puts it) is found' "$(ncalls "$BOX")" 1
case "$(cat "$BOX/b3.path" 2>/dev/null)" in
    "$BOX/stubs:/usr/bin:/bin:/usr/sbin:/sbin"*) ok 'the inherited PATH comes first: discovered directories are appended' ;;
    *) bad "the inherited PATH comes first (got $(cat "$BOX/b3.path" 2>/dev/null))" ;;
esac
contains 'and ~/.bun/bin is on it for the bun shebang' "$(cat "$BOX/b3.path" 2>/dev/null)" "$BOX/.bun/bin"

BOX=$(newbox)
mkdir -p "$BOX/.bun/bin"
printf '#!/bin/sh\n: > "%s/wrong-b3"\n' "$BOX" >"$BOX/.bun/bin/b3"
chmod +x "$BOX/.bun/bin/b3"
run_box "$BOX"
refute 'a b3 on the inherited PATH wins over a discovered one' test -e "$BOX/wrong-b3"

group 'the log'

BOX=$(newbox)
mkdir -p "$BOX/Library/Logs"
head -c 4096 /dev/zero | tr '\0' 'x' >"$(logfile "$BOX")"
RUNNER_ENV=(B3SYNC_LOG_MAX_BYTES=100)
run_box "$BOX"
assert 'an oversized log is rotated to .log.1' test -f "$(logfile "$BOX").1"
same 'and the live log starts again with just this run' "$(logtext "$BOX" | wc -l | tr -d ' ')" 1

BOX=$(newbox)
RUNNER_ENV=(B3SYNC_PYTHON=no-such-python-dotfiles-test)
run_box "$BOX"
same 'without python3 the run still succeeds' "$RUNNER_STATUS" 0
contains 'and says why the summary is thin' "$(logtext "$BOX")" 'ok: b3 sync exited 0 (no no-such-python-dotfiles-test'

group 'the LaunchAgent'

assert 'the plist is tracked outside ~/Library/LaunchAgents' test -f "$PLIST"
for f in "$PLIST" "$RUNNER" "$MODULE"; do
    for p in /Users/ /home/ /opt/homebrew /usr/local /home/linuxbrew; do
        lacks "${f#"$REPO"/} names no $p path" "$(cat "$f")" "$p"
    done
done
if command -v python3 >/dev/null 2>&1; then
    PL=$(python3 -c '
import plistlib, sys
p = plistlib.load(open(sys.argv[1], "rb"))
print("label=%s" % p.get("Label"))
print("args=%s" % "|".join(p.get("ProgramArguments", [])))
print("times=%s" % ",".join("%02d:%02d" % (d.get("Hour", 0), d.get("Minute", 0)) for d in p.get("StartCalendarInterval", [])))
print("runatload=%s" % p.get("RunAtLoad"))
print("keys=%s" % ",".join(sorted(p)))
' "$PLIST" 2>&1)
    contains 'its label is com.crumley.b3-sync' "$PL" 'label=com.crumley.b3-sync'
    contains 'it reaches the runner through a login shell' "$PL" \
        'args=/bin/sh|-lc|exec "$HOME/bin/b3-sync-runner" --reason schedule'
    contains 'it fires at 08:00, 13:00 and 18:00' "$PL" 'times=08:00,13:00,18:00'
    contains 'it does not run at load' "$PL" 'runatload=False'
    lacks 'it sets no StandardOutPath (launchd would not expand ~)' "$PL" 'StandardOutPath'
    lacks 'it sets no KeepAlive (one-shot, not a daemon)' "$PL" 'KeepAlive'
else
    skipped 'python3 is not installed, so the plist cannot be read structurally'
fi

group 'install.sh puts the plist where launchd looks, and loads nothing'

if ! command -v stow >/dev/null 2>&1; then
    skipped 'stow is not installed, so the installer step cannot be exercised'
else
    BOX=$(newbox)
    mkdir -p "$BOX/fakebin" "$BOX/target"
    printf '#!/bin/sh\n: > "%s/launchctl.invoked"\n' "$BOX" >"$BOX/fakebin/launchctl"
    chmod +x "$BOX/fakebin/launchctl"
    T="$BOX/target"
    LIVE="$T/Library/LaunchAgents/com.crumley.b3-sync.plist"
    OUT=$(cd "$REPO" && PATH="$BOX/fakebin:$PATH" DOTFILES_PLATFORM=darwin ./install.sh --target "$T" b3sync 2>&1)
    same 'installing the b3sync package succeeds' "$?" 0
    assert 'the runner is linked to ~/bin' test -L "$T/bin/b3-sync-runner"
    assert 'the plist is stowed to ~/.config/b3sync/' test -L "$T/.config/b3sync/com.crumley.b3-sync.plist"
    assert 'and copied into ~/Library/LaunchAgents as a real file' test -f "$LIVE"
    refute 'not a symlink' test -L "$LIVE"
    assert 'byte for byte the tracked plist' cmp -s "$PLIST" "$LIVE"
    contains 'the installer prints the bootstrap line' "$OUT" \
        'launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.crumley.b3-sync.plist'
    refute 'and never runs launchctl itself' test -e "$BOX/launchctl.invoked"

    printf 'stale\n' >"$LIVE"
    OUT=$(cd "$REPO" && DOTFILES_PLATFORM=darwin ./install.sh --target "$T" b3sync 2>&1)
    assert 'a stale copy is refreshed' cmp -s "$PLIST" "$LIVE"
    OUT=$(cd "$REPO" && DOTFILES_PLATFORM=darwin ./install.sh --target "$T" b3sync 2>&1)
    lacks 'and a current one is left alone, silently' "$OUT" 'installed ~/Library/LaunchAgents'

    BOX=$(newbox)
    OUT=$(cd "$REPO" && DOTFILES_PLATFORM=darwin ./install.sh --dry-run --target "$BOX" b3sync 2>&1)
    refute 'a dry run installs no plist' test -e "$BOX/Library/LaunchAgents/com.crumley.b3-sync.plist"
    contains 'but says it would' "$OUT" 'would install ~/Library/LaunchAgents/com.crumley.b3-sync.plist'

    OUT=$(cd "$REPO" && DOTFILES_PLATFORM=linux ./install.sh --list 2>&1)
    lacks 'the package is not offered on Linux' "$OUT" 'b3sync'
    OUT=$(cd "$REPO" && DOTFILES_PLATFORM=darwin ./install.sh --list 2>&1)
    contains 'and is offered on macOS' "$OUT" 'b3sync'
fi

group 'the Hammerspoon module (brainsync.lua, under a fake hs)'

LUA=''
for candidate in lua lua5.4 lua5.3; do
    if command -v "$candidate" >/dev/null 2>&1; then
        LUA=$candidate
        break
    fi
done
if [ -z "$LUA" ]; then
    skipped 'no Lua interpreter, so brainsync.lua was not exercised (apt-get install lua5.4 / brew install lua)'
else
    LUA_OUT=$("$LUA" "$LUA_TEST" "$REPO" 2>&1)
    LUA_STATUS=$?
    while IFS= read -r line; do
        case "$line" in
            'ok '*) ok "${line#ok }" ;;
            'FAIL '*) bad "${line#FAIL }" ;;
            *) [ -n "$line" ] && printf '       %s\n' "$line" ;;
        esac
    done <<EOF
$LUA_OUT
EOF
    if [ "$LUA_STATUS" -ne 0 ] && ! printf '%s\n' "$LUA_OUT" | grep -q '^FAIL '; then
        bad "the Lua harness itself failed (exit $LUA_STATUS)"
    fi
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
