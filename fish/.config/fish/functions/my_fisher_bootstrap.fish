# Install fisher and everything listed in fish_plugins.
#
# This replaces the old bootstrap that ran automatically at the top of every
# shell: it curled https://git.io/fisher, a URL GitHub shut down in 2022, so it
# had been silently failing (and adding a network call to shell startup) for
# years. Installing plugins is a setup step, not a startup step -- run this once
# by hand, or from install.sh.
function my_fisher_bootstrap --description "Install fisher and the plugins in fish_plugins"
    if not functions -q fisher
        if not command -q curl
            echo "my_fisher_bootstrap: curl is required" >&2
            return 1
        end

        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
        or begin
            echo "my_fisher_bootstrap: could not download fisher" >&2
            return 1
        end

        fisher install jorgebucaran/fisher
        or return 1
    end

    # `fisher update` with no arguments installs/updates everything in
    # fish_plugins, which this repository tracks.
    fisher update
end
