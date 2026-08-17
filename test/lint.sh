#!/usr/bin/env bash
# test/lint.sh — shellcheck over every shell script in the repo.
#
# Scripts are discovered, not listed: anything with a shell shebang, plus the
# extensionless rc files (.bashrc, .bash_profile, .profile, direnvrc) that have
# no shebang to discover. A new script added by another task is picked up for
# free.
#
# Severity gate defaults to `warning`. Accepted findings live in
# test/shellcheck-baseline.txt with a reason attached, so an exception is
# annotated rather than the gate being lowered.
#
# Env:
#   SHELLCHECK_SEVERITY  style|info|warning|error   (default: warning)
#   SHELLCHECK_BASELINE  0 to ignore the baseline and see everything

set -uo pipefail
# shellcheck source=test/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

SEVERITY=${SHELLCHECK_SEVERITY:-warning}
BASELINE_FILE="$TESTS_DIR/shellcheck-baseline.txt"
USE_BASELINE=${SHELLCHECK_BASELINE:-1}

section "shellcheck (severity=$SEVERITY)"

if ! have shellcheck; then
    skip "shellcheck not installed — no shell scripts were linted. Install it: brew install shellcheck / apt-get install shellcheck"
    # A missing linter is a fresh-laptop condition, not a CI condition. On a
    # runner the workflow installed it, so its absence is a workflow bug.
    [ -n "${GITHUB_ACTIONS:-}" ] && fail "shellcheck must be present in CI"
    report_totals
    exit $?
fi
info "$(shellcheck --version | awk '/^version:/ {print "shellcheck " $2}')"

scripts=$(shell_scripts)
if [ -z "$scripts" ]; then
    fail "no shell scripts discovered — the discovery in test/lib.sh is broken"
    report_totals
    exit $?
fi
info "$(printf '%s\n' "$scripts" | wc -l | tr -d ' ') shell scripts discovered"

work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-lint.XXXXXX")
trap 'rm -rf "$work"' EXIT
: > "$work/findings"

# One invocation per dialect group, so that -s is right for the extensionless
# files. -x follows `source` where the target is a literal path.
for dialect in sh bash ksh; do
    files=$(printf '%s\n' "$scripts" | awk -F'\t' -v d="$dialect" '$1==d {print $2}')
    [ -z "$files" ] && continue
    # shellcheck disable=SC2086  # deliberate word-splitting of the file list
    (cd "$REPO_ROOT" && printf '%s\n' "$files" | xargs shellcheck \
        -s "$dialect" -S "$SEVERITY" -x -f gcc) >> "$work/findings" 2>&1
done

# --- classify findings against the baseline --------------------------------
# gcc format: path:line:col: level: message [SC1234]
: > "$work/new"
: > "$work/known"
: > "$work/matched-baseline"

while IFS= read -r line; do
    [ -z "$line" ] && continue
    code=$(printf '%s\n' "$line" | sed -n 's/.*\[\(SC[0-9]*\)\]$/\1/p')
    path=${line%%:*}
    if [ -z "$code" ]; then
        # Not a finding (usually shellcheck's own diagnostics) — always surface.
        printf '%s\n' "$line" >> "$work/new"
        continue
    fi
    if [ "$USE_BASELINE" = "1" ] && [ -f "$BASELINE_FILE" ] &&
        awk -v c="$code" -v p="$path" '
            # The path field is a glob, so an entry survives a file being moved
            # (git/.bin/foo -> git/bin/foo) instead of silently going stale and
            # failing the build for a finding that was already accepted.
            function glob2re(g,   r) {
                r = g
                gsub(/[.^$+(){}\[\]|\\]/, "\\\\&", r)
                gsub(/\*/, ".*", r)
                gsub(/\?/, ".", r)
                return "^" r "$"
            }
            /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
            { if ($1 == c && p ~ glob2re($2)) { print $1 " " $2; found=1 } }
            END { exit !found }' "$BASELINE_FILE" >> "$work/matched-baseline"
    then
        printf '%s\n' "$line" >> "$work/known"
    else
        printf '%s\n' "$line" >> "$work/new"
    fi
done < "$work/findings"

known_n=$(wc -l < "$work/known" | tr -d ' ')
new_n=$(wc -l < "$work/new" | tr -d ' ')

if [ "$known_n" -gt 0 ]; then
    info "$known_n baselined finding(s) suppressed (see test/shellcheck-baseline.txt)"
fi

if [ "$new_n" -gt 0 ]; then
    printf '\n'
    cat "$work/new" >&2
    printf '\n'
    fail "$new_n shellcheck finding(s) at severity>=$SEVERITY. Fix them, or add an annotated line to test/shellcheck-baseline.txt."
else
    pass "shellcheck clean at severity>=$SEVERITY across $(printf '%s\n' "$scripts" | wc -l | tr -d ' ') scripts"
fi

# --- stale baseline entries ------------------------------------------------
if [ "$USE_BASELINE" = "1" ] && [ -f "$BASELINE_FILE" ]; then
    # Entries scoped to `*` are policy, not debt (see the baseline's header):
    # they only match at lower severities, so never nag about them being stale.
    stale=$(awk '/^[[:space:]]*#/ || /^[[:space:]]*$/ || $2 == "*" { next } { print $1 " " $2 }' "$BASELINE_FILE" |
        LC_ALL=C sort -u |
        LC_ALL=C comm -23 - <(LC_ALL=C sort -u "$work/matched-baseline"))
    if [ -n "$stale" ]; then
        info "stale baseline entries (nothing matched them — delete these):"
        printf '%s\n' "$stale" | sed 's/^/      /'
    fi
fi

report_totals
