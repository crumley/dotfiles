# Opt out of vendor snippets that would activate tools this machine has not
# asked for.
#
# fish auto-sources vendor_conf.d from every directory in $__fish_vendor_confdirs
# on every start. Homebrew and distro packages drop snippets there that hook
# their tool into the shell unconditionally, purely because the tool is
# installed. That defeats the FISH_* flags: those exist precisely so a machine
# that does not use mise -- but has it installed, because it is in the Brewfile
# and `brew bundle` installs everything -- does not get mise in its shell.
#
# Two things make this file's placement load-bearing:
#
#   1. It must run unconditionally. conf.d/50-tools.fish, where the matching
#      opt-in lives, begins with `status is-interactive; or return`, so anything
#      set there never runs for a non-interactive shell -- while the vendor
#      snippet runs regardless. Putting the opt-out there looked right and did
#      nothing.
#   2. It must run before the vendor snippets. fish runs every user conf.d file
#      before any vendor one, so any name works; the 05- prefix is only to keep
#      it ahead of the tool config it governs.
#
# mise publishes a supported opt-out, so use it rather than shadowing the file
# by name -- this keeps working if the snippet is ever renamed.
set -gx MISE_FISH_AUTO_ACTIVATE 0

# direnv publishes no equivalent; its snippet is a bare `direnv hook fish |
# source`. It is neutralised by conf.d/direnv.fish instead, which shadows the
# vendor file by filename. See that file.
