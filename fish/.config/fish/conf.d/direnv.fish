# Deliberately empty. This file exists to suppress a vendor snippet, not to do
# anything itself.
#
# Homebrew (and most Linux distro packages) ship a fish snippet at
# vendor_conf.d/direnv.fish containing a bare, unconditional:
#
#     direnv hook fish | source
#
# fish auto-sources vendor_conf.d on every start, so merely having direnv
# installed hooks it into the shell. That makes FISH_DIRENV a lie: the flag
# exists so a machine that does not want direnv does not get it, and the vendor
# snippet overrides that decision. Unlike mise's equivalent, it offers no
# environment variable to opt out of.
#
# fish resolves conf.d by basename across all its search directories and runs
# only the *first* file with a given name, with the user's directory taking
# precedence over vendor ones. So a file named exactly `direnv.fish` here
# replaces the vendor one and neutralises it. Verified: with this file present,
# __direnv_export_eval is undefined after startup; without it, direnv is hooked.
#
# The actual, conditional hook lives in conf.d/50-tools.fish, guarded on
# FISH_DIRENV and on direnv being installed. Keep the logic there; keep this
# file inert.
#
# The name is load-bearing and must stay byte-identical to the vendor file's.
# If a future direnv package renames its snippet, this stops shadowing anything
# and direnv silently becomes unconditional again -- so if FISH_DIRENV ever
# appears to be ignored, check the vendor directories first:
#
#     ls $__fish_vendor_confdirs
