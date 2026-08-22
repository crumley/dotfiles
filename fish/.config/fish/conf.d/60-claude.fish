# Notice when the tracked Claude Code settings template has moved ahead of this
# machine's live settings.
#
# ~/.claude/settings.json is deliberately not tracked: Claude Code rewrites the
# whole file whenever a setting is toggled, so a stow symlink would put that
# rewrite straight into the checkout. The repository tracks the template beside
# it (~/.claude/settings.json.example, stowed) and install.sh materializes the
# live file once, then never touches it again.
#
# That leaves one gap nothing else closes: `git pull` can move the template
# forward -- a new permission, a new default -- days before install.sh is run
# again, and the machine would never hear about it. This is the "suggest taking
# action" surface for that, and it is why the check lives at shell startup
# rather than only at install time.
#
# Cheap and silent by design: one mtime comparison, no subprocess, and nothing
# printed unless there is something to say. Either file missing (no claude
# package installed here, or a machine that has never run the installer) is
# silence, not an error.
#
# Numbered 60, not 9x: 90-tmux.fish may auto-attach a session, which would wipe
# the message off the screen before it could be read.

status is-interactive; or return

set -l claude_live ~/.claude/settings.json
set -l claude_template ~/.claude/settings.json.example

test -f $claude_live; or return
test -e $claude_template; or return
# -nt is false when the two are equal, so the file install.sh copies from the
# template is quiet from the moment it is created.
test $claude_template -nt $claude_live; or return

# stderr, not stdout: a startup notice must not end up inside the output of
# something that captured a shell's stdout.
echo "claude: ~/.claude/settings.json.example is newer than your ~/.claude/settings.json" >&2
echo "        diff ~/.claude/settings.json ~/.claude/settings.json.example   # merge what you want" >&2
echo "        touch ~/.claude/settings.json                                  # or keep what this machine has" >&2
