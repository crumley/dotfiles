#!/usr/bin/env bash
# test/lib.sh — shared helpers for the dotfiles check suite.
#
# Sourced by test/run.sh and the individual check scripts. Written for bash 3.2
# (the bash that ships with macOS), so: no associative arrays, no ${var,,}, no
# `mapfile`.
#
# Every check script reports through pass/fail/skip so that the local runner and
# GitHub Actions produce the same summary, and so that "this check could not run"
# is always distinguishable from "this check passed".

# Note: intentionally no `set -e`. The suite is meant to run every check and
# report all failures, not stop at the first one.
set -uo pipefail

# `cd` must never consult CDPATH here; a user's CDPATH would silently redirect
# the path resolution this whole suite's safety checks depend on.
unset CDPATH

# ---------------------------------------------------------------------------
# Locations
# ---------------------------------------------------------------------------

# Directory holding this library, resolved even when invoked via a relative path.
TESTS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export TESTS_DIR

if REPO_ROOT=$(git -C "$TESTS_DIR" rev-parse --show-toplevel 2>/dev/null); then
    :
else
    REPO_ROOT=$(cd -- "$TESTS_DIR/.." && pwd)
fi
export REPO_ROOT

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ -z "${GITHUB_ACTIONS:-}" ]; then
    C_RESET=$'\033[0m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_DIM=$'\033[2m'
else
    C_RESET='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_DIM=''
fi

CHECK_FAILURES=0
CHECK_SKIPS=0
CHECK_PASSES=0

section() {
    printf '\n%s==> %s%s\n' "$C_BLUE" "$*" "$C_RESET"
}

pass() {
    CHECK_PASSES=$((CHECK_PASSES + 1))
    printf '  %sok%s   %s\n' "$C_GREEN" "$C_RESET" "$*"
}

fail() {
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
    printf '  %sFAIL%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        printf '::error title=dotfiles check::%s\n' "$*"
    fi
}

# skip() is deliberately loud. A check that cannot run is not a check that
# passed, and on a moving target (install.sh is being rewritten) the skips are
# the most important thing in the log.
skip() {
    CHECK_SKIPS=$((CHECK_SKIPS + 1))
    printf '  %sSKIP%s %s\n' "$C_YELLOW" "$C_RESET" "$*"
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        printf '::notice title=dotfiles check skipped::%s\n' "$*"
    fi
}

info() {
    printf '  %s%s%s\n' "$C_DIM" "$*" "$C_RESET"
}

# Print the tallies and return 1 if anything failed.
report_totals() {
    printf '\n%s%d passed, %d failed, %d skipped%s\n' \
        "$C_DIM" "$CHECK_PASSES" "$CHECK_FAILURES" "$CHECK_SKIPS" "$C_RESET"
    [ "$CHECK_FAILURES" -eq 0 ]
}

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# Known-broken files
#
# Files that genuinely do not work today, on a repo that has never had CI.
# Reported as a loud SKIP with the reason instead of a FAIL, so that adopting
# this suite does not paint every in-flight PR red for a defect none of them
# caused. Each entry names its owner; delete it when that task lands.
#
# This list is for *pre-existing* breakage only. A file that worked yesterday
# and does not today must fail — never add one here to go green.
#
# It lives in lib.sh because two checks consult it: syntax.sh (does the file
# parse?) and smoke-test.sh (does a shell that reads it start?). One list, so an
# entry cannot be deleted from one place and linger in the other.
# ---------------------------------------------------------------------------

KNOWN_BROKEN_PATHS="home/.profile"
KNOWN_BROKEN_USED=""
# shellcheck disable=SC2034  # read by syntax.sh and smoke-test.sh, which source this
KNOWN_BROKEN_REASON=""

# Sets KNOWN_BROKEN_REASON and returns 0 when PATH (repo-relative) is known
# broken.
#
# The reason comes back in a global rather than on stdout on purpose: a command
# substitution runs in a subshell, so the record of which entries actually fired
# would be discarded with it — and a stale entry that never reports itself is
# exactly the failure mode this list has to avoid.
known_broken() {
    KNOWN_BROKEN_REASON=""
    case "$1" in
        home/.profile)
            # eval \$($(brew --prefix)/bin/brew shellenv)
            # The backslash makes it a literal `$`, so this line has never
            # worked on any platform. macOS's /bin/sh only warns; Ubuntu's dash
            # refuses to start at all. Owned by t3 (POSIX shell config).
            # shellcheck disable=SC2016,SC2034  # a literal, not an expansion; read by the scripts that source this
            KNOWN_BROKEN_REASON='pre-existing breakage, owned by t3: the escaped `\$` on line 1 has never worked'
            KNOWN_BROKEN_USED="$KNOWN_BROKEN_USED $1"
            return 0
            ;;
    esac
    return 1
}

# A known-broken entry that no longer fires is a lie waiting to be believed.
report_stale_known_broken() {
    local kb
    for kb in $KNOWN_BROKEN_PATHS; do
        case " $KNOWN_BROKEN_USED " in
            *" $kb "*) ;;
            *) info "stale known_broken entry: $kb now works (or is gone) — delete it from test/lib.sh" ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# File discovery
# ---------------------------------------------------------------------------

# Paths never inspected, one extended-glob-free pattern per line. Kept here
# rather than in a root-level config file so the exclusion always carries its
# reason with it.
#
#   Spoons/          — git submodules (vendored Hammerspoon plugins, not ours)
#   .iterm2_shell_*  — vendored verbatim from iTerm2's installer; not our style
#                      to enforce. (Slated for deletion; a pattern that matches
#                      nothing is harmless.)
_is_excluded() {
    case "$1" in
        */Spoons/*) return 0 ;;
        *.iterm2_shell_integration.*) return 0 ;;
        .git/*) return 0 ;;
    esac
    return 1
}

# repo_files [glob]
# Every tracked file (or, outside git, every file on disk), NUL-free, one per
# line, relative to REPO_ROOT, with excluded paths already dropped. An optional
# `case` glob filters the list.
#
# shellcheck disable=SC2120  # the glob is optional; callers in syntax.sh pass it
repo_files() {
    local filter="${1:-*}" f
    {
        if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
            # --others --exclude-standard adds files that exist but are not
            # committed yet (and are not gitignored), so a script you just wrote
            # is checked before you commit it rather than after CI rejects it.
            git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard
        else
            (cd "$REPO_ROOT" && find . -type f | sed 's|^\./||')
        fi
    } | LC_ALL=C sort | while IFS= read -r f; do
        _is_excluded "$f" && continue
        # shellcheck disable=SC2254  # $filter is a glob on purpose
        case "$f" in
            $filter) [ -f "$REPO_ROOT/$f" ] && printf '%s\n' "$f" ;;
        esac
    done
}

# shell_dialect PATH
# Prints the shellcheck dialect for a file ("bash" or "sh"), or nothing if the
# file is not a shell script. Name-based rules come first because the files that
# most need checking — .bashrc, .bash_profile, .profile — have neither an
# extension nor a shebang. Everything else is discovered from its shebang, so a
# new script added by another task is picked up without editing this list.
shell_dialect() {
    local path="$1" base first
    base=${path##*/}

    case "$base" in
        .bashrc | .bash_profile | .bash_login | .bash_logout | .bash_aliases | .bash_functions)
            printf 'bash\n'; return 0 ;;
        .profile | .shrc)
            printf 'sh\n'; return 0 ;;
        direnvrc | .envrc)
            printf 'bash\n'; return 0 ;;
        *.bash) printf 'bash\n'; return 0 ;;
        *.sh) : ;;  # fall through to the shebang, which is authoritative
        *.fish | *.lua | *.json | *.toml | *.yml | *.yaml | *.md)
            return 0 ;;
    esac

    IFS= read -r first < "$REPO_ROOT/$path" 2>/dev/null || return 0
    case "$first" in
        '#!'*bash*) printf 'bash\n' ;;
        '#!'*dash*) printf 'sh\n' ;;
        '#!'*ksh*) printf 'ksh\n' ;;
        '#!'*sh*) printf 'sh\n' ;;
        *)
            # No shebang: only trust the .sh extension.
            case "$path" in *.sh) printf 'bash\n' ;; esac
            ;;
    esac
}

# shell_scripts
# Every shell script in the repo as "dialect<TAB>path".
shell_scripts() {
    local f d
    repo_files | while IFS= read -r f; do
        d=$(shell_dialect "$f")
        [ -n "$d" ] && printf '%s\t%s\n' "$d" "$f"
    done
}

# ---------------------------------------------------------------------------
# Parser shims
#
# Each of these tries the interpreters most likely to exist on a bare runner and
# on a laptop, in order, and returns 127 when none is available so the caller can
# skip loudly instead of passing silently.
# ---------------------------------------------------------------------------

check_json() {
    if have python3; then
        python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1"
    elif have node; then
        node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$1"
    else
        return 127
    fi
}

check_toml() {
    if have python3 && python3 -c 'import tomllib' 2>/dev/null; then
        python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1],"rb"))' "$1"
    elif have python3 && python3 -c 'import tomli' 2>/dev/null; then
        python3 -c 'import tomli,sys; tomli.load(open(sys.argv[1],"rb"))' "$1"
    elif have taplo; then
        taplo check "$1"
    else
        return 127
    fi
}

check_yaml() {
    if have python3 && python3 -c 'import yaml' 2>/dev/null; then
        python3 -c 'import yaml,sys; list(yaml.safe_load_all(open(sys.argv[1])))' "$1"
    elif have ruby; then
        # Psych is in ruby's stdlib, so this works on a stock macOS and on the
        # GitHub runners without installing anything.
        ruby -ryaml -e 'YAML.load_file(ARGV[0])' "$1"
    elif have yq; then
        yq eval '.' "$1" >/dev/null
    else
        return 127
    fi
}

check_lua() {
    if have luac; then
        luac -p "$1"
    elif have luac5.4; then
        luac5.4 -p "$1"
    elif have luac5.3; then
        luac5.3 -p "$1"
    elif have lua; then
        lua -e 'assert(loadfile(arg[1]))' "$1"
    else
        return 127
    fi
}
