function gcb --description "Delete git branches"
    if not command -q fzf
        echo "gcb: fzf is required" >&2
        return 1
    end

    set -l delete_mode -d
    set -l force_label ''

    if contains -- --force $argv
        set force_label ':force'
        set delete_mode -D
    end

    set -l branches_to_delete (git branch | sed -E 's/^[* ] //g' | fzf -m --header="[git:branch:delete$force_label]")

    if test -n "$branches_to_delete"
        git branch $delete_mode $branches_to_delete
    end
end
