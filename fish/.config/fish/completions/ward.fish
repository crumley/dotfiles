# ward -- workspace CLI completions.
#
# fish autoloads completions/<command>.fish the first time a completion is
# requested for that command, so this file is a lazy bootstrap: nothing runs
# at shell startup, and the ~130ms it costs ward to generate its script is
# paid once per shell, on the first `ward <TAB>`. A conf.d snippet doing the
# same `| source` eagerly would pay that on every interactive shell start.
#
# `ward completion fish` derives the rules from the CLI's own command tree,
# and the installed rules ask the live workspace for suggestions (task codes,
# repository names) on each TAB -- so there is nothing to keep in sync by
# hand and no generated file to commit. Because this regenerates per shell,
# an upgraded ward is picked up by the next shell, not by editing anything.
#
# The filename is load-bearing: it must be exactly `ward.fish` for fish to
# associate it with the `ward` command. The stderr drop keeps a ward too old
# to know `completion` from spewing usage errors into the first TAB.
command -q ward; or return
ward completion fish 2>/dev/null | source
