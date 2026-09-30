#!/usr/bin/env bash
# test/run.sh — the local entry point for every check CI runs.
#
# CI runs exactly these scripts; there is no second copy of the logic living in
# a YAML file. If it passes here it should pass there, and vice versa.
#
#   test/run.sh                  # everything
#   test/run.sh lint             # shellcheck over every shell script
#   test/run.sh syntax           # parse checks: fish, bash, lua, json, toml, yaml
#   test/run.sh install          # test/install-test.sh — the installer's own suite
#   test/run.sh b3sync           # the b3 sync runner, plist and Hammerspoon hooks, against stubs
#   test/run.sh smoke            # install into a throwaway home, then start the shells
#   test/run.sh lint syntax      # any combination
#
# Optional linters that are not installed are reported as SKIP, loudly, and do
# not fail the run — so this is usable on a fresh machine — but a skip is never
# silent and never counted as a pass.
#
# Nothing here touches your real home directory. The install and smoke checks
# work inside a mktemp directory and refuse to run if the target resolves to
# $HOME.

set -uo pipefail
unset CDPATH

TESTS_DIR=$(cd -- "$(dirname -- "$0")" && pwd)

usage() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

checks=""
want_all=0
for arg in "$@"; do
    case "$arg" in
        -h | --help) usage 0 ;;
        b3sync) checks="$checks $arg" ;;
        all) want_all=1 ;;
        lint | syntax | install | smoke) checks="$checks $arg" ;;
        *)
            printf 'run.sh: unknown argument %s\n\n' "$arg" >&2
            usage 1
            ;;
    esac
done
# Nothing named is the same as `all`.
[ -z "$checks" ] && want_all=1

# Matched as a whole word, never as a substring. `case "$checks" in *all*)`
# looks equivalent and is not: "install" contains "all", so `run.sh install`
# quietly ran the entire suite.
if [ "$want_all" = 1 ] || [ -z "$checks" ]; then
    checks="lint syntax install smoke"
fi
# A package's own suite joins "everything" on its own line.
if [ "$want_all" = 1 ]; then
    checks="$checks b3sync"
fi

rc=0
failed=""
skipped=""
for check in $checks; do
    case "$check" in
        # The b3sync package's suite: the runner launchd and Hammerspoon call,
        # run against a stubbed b3 in a throwaway home, plus brainsync.lua under
        # a fake hs. It needs no macOS, so it runs on both halves of the matrix
        # -- the package is macOS-only and would otherwise be tested nowhere.
        b3sync) script="$TESTS_DIR/b3sync-test.sh" ;;
        lint) script="$TESTS_DIR/lint.sh" ;;
        syntax) script="$TESTS_DIR/syntax.sh" ;;
        smoke) script="$TESTS_DIR/smoke-test.sh" ;;
        # The installer's end-to-end suite belongs to the installer and lives
        # with it (test/install-test.sh). It is invoked here rather than
        # reimplemented: it already covers clean install, idempotency, five
        # kinds of conflict, --takeover and its backups, folded-tree migration,
        # subsets and bad input. Running it from here is what puts it on the
        # ubuntu-latest / macos-latest matrix, which is the part it could not
        # give itself.
        install) script="$TESTS_DIR/install-test.sh" ;;
        *) continue ;;
    esac

    if [ ! -f "$script" ]; then
        printf '\n\033[33mSKIP %s — %s does not exist on this branch\033[0m\n' \
            "$check" "${script#"$(dirname "$TESTS_DIR")"/}"
        if [ -n "${GITHUB_ACTIONS:-}" ]; then
            printf '::notice title=check skipped::%s: %s does not exist on this branch\n' \
                "$check" "$script"
        fi
        skipped="$skipped $check"
        continue
    fi

    printf '\n\033[1m######## %s ########\033[0m\n' "$check"
    if ! bash "$script"; then
        rc=1
        failed="$failed $check"
    fi
done

printf '\n'
[ -n "$skipped" ] && printf '\033[33mskipped:%s\033[0m\n' "$skipped"
if [ "$rc" -eq 0 ]; then
    printf '\033[32mall checks passed\033[0m (%s)\n' "$(printf '%s' "$checks" | tr -s ' ')"
else
    printf '\033[31mfailed:%s\033[0m\n' "$failed"
fi
exit "$rc"
