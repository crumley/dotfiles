#!/usr/bin/env bash
# test/syntax.sh — per-language parse checks.
#
# Cheap, fast, and unambiguous: does each file in this repo actually parse with
# the thing that will read it? A config that does not parse is broken on every
# platform, so this is the check that should stay green at all times.
#
# Nothing here is hardcoded to a file list; everything is discovered by
# extension or by the known path of a format-less config.

set -uo pipefail
# shellcheck source=test/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

# known_broken PATH
# Files that genuinely do not parse today, on a repo that has never had CI.
# Reported as a loud SKIP with the reason instead of a FAIL, so that adopting
# this suite does not paint every in-flight PR red for a defect none of them
# caused. Each entry names its owner; delete it when that task lands.
#
# This list is for *pre-existing* breakage only. A file that parsed yesterday
# and does not today must fail — do not add it here to go green.
KNOWN_BROKEN_PATHS="home/.profile"
KNOWN_BROKEN_USED=""
KNOWN_BROKEN_REASON=""

# Sets KNOWN_BROKEN_REASON and returns 0 when PATH is a known-broken file.
#
# The reason comes back in a global rather than on stdout on purpose: a command
# substitution runs in a subshell, so the record of which entries actually fired
# would be thrown away with it — and a stale entry that never reports itself is
# exactly the failure mode this list has to avoid.
known_broken() {
    KNOWN_BROKEN_REASON=""
    case "$1" in
        home/.profile)
            # eval \$($(brew --prefix)/bin/brew shellenv)
            # The backslash makes it a literal `$`, so this line has never
            # worked on any platform. Owned by t3 (POSIX shell config).
            # shellcheck disable=SC2016  # quoting a literal, not expanding it
            KNOWN_BROKEN_REASON='pre-existing syntax error, owned by t3: the escaped `\$` on line 1 has never worked'
            KNOWN_BROKEN_USED="$KNOWN_BROKEN_USED $1"
            return 0
            ;;
    esac
    return 1
}

# report_parse_failure PATH LABEL OUTPUT
report_parse_failure() {
    local path="$1" label="$2" out="$3"
    if known_broken "$path"; then
        skip "$label $path — $KNOWN_BROKEN_REASON"
    else
        fail "$label $path"
        printf '%s\n' "$out" | sed 's/^/         /' >&2
    fi
}

# run_over LABEL GLOB CHECKER
# Applies CHECKER to every repo file matching GLOB. Reports one line per file so
# a failure names the file, and skips loudly (once) when the checker is missing.
run_over() {
    local label="$1" glob="$2" checker="$3"
    local files f rc out any=0 missing=0

    files=$(repo_files "$glob")
    if [ -z "$files" ]; then
        info "$label: no files matched '$glob'"
        return 0
    fi

    while IFS= read -r f; do
        [ -z "$f" ] && continue
        out=$("$checker" "$REPO_ROOT/$f" 2>&1)
        rc=$?
        if [ "$rc" -eq 127 ]; then
            missing=1
            break
        elif [ "$rc" -eq 0 ]; then
            any=1
            pass "$label $f"
        else
            report_parse_failure "$f" "$label" "$out"
        fi
    done <<EOF
$files
EOF

    if [ "$missing" -eq 1 ]; then
        skip "$label: no parser available — $(printf '%s\n' "$files" | wc -l | tr -d ' ') file(s) went unchecked"
    fi
    [ "$any" -ge 0 ]
}

# --- fish ------------------------------------------------------------------
section "fish syntax"
if have fish; then
    info "$(fish --version)"
    _fish_check() { fish -n "$1"; }
    run_over "fish -n" '*.fish' _fish_check
else
    # fish is NOT preinstalled on GitHub runners. If this skip shows up in CI,
    # the workflow's install step regressed — it is not a "fish is optional"
    # situation.
    n=$(repo_files '*.fish' | wc -l | tr -d ' ')
    skip "fish not installed — $n .fish file(s) unchecked. apt-get install fish / brew install fish"
fi

# --- bash / sh -------------------------------------------------------------
section "shell syntax"
scripts=$(shell_scripts)
if [ -z "$scripts" ]; then
    fail "no shell scripts discovered"
else
    while IFS=$'\t' read -r dialect path; do
        [ -z "$path" ] && continue
        case "$dialect" in
            bash) interp="bash" ;;
            sh) interp="sh" ;;
            *) interp="$dialect" ;;
        esac
        if ! have "$interp"; then
            skip "$interp not available — $path unchecked"
            continue
        fi
        if out=$("$interp" -n "$REPO_ROOT/$path" 2>&1); then
            pass "$interp -n $path"
        else
            report_parse_failure "$path" "$interp -n" "$out"
        fi
    done <<EOF
$scripts
EOF

    # A known-broken entry that no longer triggers is a lie waiting to be
    # believed. Report it so it gets deleted rather than quietly excusing a file
    # that someone already fixed.
    for kb in $KNOWN_BROKEN_PATHS; do
        case " $KNOWN_BROKEN_USED " in
            *" $kb "*) ;;
            *) info "stale known_broken entry: $kb parses (or is gone) — delete it from test/syntax.sh" ;;
        esac
    done
fi

# --- lua (Hammerspoon) -----------------------------------------------------
# Spoons are git submodules and are excluded by test/lib.sh; this covers the
# .lua files this repo actually owns.
section "lua syntax"
run_over "lua -p" '*.lua' check_lua

# --- structured configs ----------------------------------------------------
section "json"
run_over "json" '*.json' check_json

section "toml"
run_over "toml" '*.toml' check_toml

section "yaml"
run_over "yaml" '*.yml' check_yaml
run_over "yaml" '*.yaml' check_yaml

# --- Brewfile (Ruby DSL) ---------------------------------------------------
# `Brewfile` and `Brewfile.vscode` are Ruby, so `ruby -c` catches a stray quote
# or bracket without needing Homebrew installed. Ruby ships with macOS and with
# the Ubuntu runners, so this costs nothing.
section "brewfile"
_ruby_check() { ruby -c "$1" >/dev/null; }
if have ruby; then
    run_over "ruby -c" 'Brewfile*' _ruby_check
else
    skip "ruby not available — Brewfile(s) unchecked"
fi

# --- workflows -------------------------------------------------------------
# The CI definition is itself a config file in this repo; check it the same way.
section "github workflows"
if have actionlint; then
    # Explicit file arguments, not bare `actionlint`: with no arguments it hunts
    # for a git project root and errors out when there isn't one (a tarball, a
    # scratch copy), which is a tooling complaint, not a workflow defect.
    wf=$(repo_files '.github/workflows/*.yml'; repo_files '.github/workflows/*.yaml')
    if [ -z "$wf" ]; then
        info "actionlint: no workflow files"
    elif out=$(cd "$REPO_ROOT" && printf '%s\n' "$wf" | xargs actionlint 2>&1); then
        pass "actionlint ($(printf '%s\n' "$wf" | wc -l | tr -d ' ') workflow file(s))"
    else
        fail "actionlint"
        printf '%s\n' "$out" | sed 's/^/         /' >&2
    fi
else
    info "actionlint not installed — workflows only checked as YAML above (brew install actionlint)"
fi

report_totals
