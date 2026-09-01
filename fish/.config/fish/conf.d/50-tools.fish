# Opt-in tool integrations.
#
# Each block is off unless the matching FISH_* flag is set to "true" in the
# machine-owned conf.d/00-local.fish. That file sorts before this one; the also
# machine-owned config.fish runs after every conf.d fragment and is too late to
# set these inputs. Every block additionally checks that the tool is installed,
# so enabling one without its binary is quiet rather than an error.
#
# These all install prompts, keybindings or shell hooks, so none of it is
# meaningful in a non-interactive shell.

status is-interactive; or return

# mise -- version manager (replaced asdf).
# The vendor snippet that would otherwise activate it unconditionally is opted
# out of in conf.d/05-vendor-optout.fish, which has to run unconditionally and
# so cannot live in this file (see the is-interactive guard above).
#
# --shims, not plain activate: activate resolves tool versions for whatever
# directory the shell is standing in and prepends the resolved per-version bin
# dirs to PATH. Its prompt hook keeps that honest interactively, but child
# processes (agents, git hooks, app launchers) inherit the snapshot and never
# re-resolve -- inside a repo pinning bun 1.3.14, an inherited PATH still led
# with installs/bun/1/bin (1.4.0), which wrote a lockfile the pinned toolchain
# could not parse. The shims dir is version-agnostic and resolves per working
# directory at exec time, so the inherited PATH is correct everywhere.
if test "$FISH_MISE" = true; and command -q mise
    mise activate fish --shims | source
    # Shims export no tool env vars; JAVA_HOME used to arrive via activate's
    # hook-env, so keep providing it for the tools that read it.
    if set -l _mise_java (mise where java 2>/dev/null)
        set -gx JAVA_HOME $_mise_java
    end
end

# direnv -- per-directory environments
#
# Homebrew's vendor_conf.d/direnv.fish has the same problem and, unlike mise's,
# offers no opt-out -- it is a bare `direnv hook fish | source`. It is suppressed
# instead by conf.d/direnv.fish in this package, which shadows it by filename.
# See that file.
if test "$FISH_DIRENV" = true; and command -q direnv
    direnv hook fish | source
end

# starship -- prompt
if test "$FISH_STARSHIP" = true; and command -q starship
    starship init fish | source
end

# atuin -- shell history. ATUIN_NOBIND stops atuin binding keys itself; ctrl-r
# is then bound in exactly one place, functions/fish_user_key_bindings.fish,
# which fish calls after this file. The old tracked config.fish bound it twice.
if test "$FISH_ATUIN" = true; and command -q atuin
    set -gx ATUIN_NOBIND true
    atuin init fish | source
end

# zoxide -- smarter cd
if test "$FISH_ZOXIDE" = true; and command -q zoxide
    zoxide init fish | source
end
