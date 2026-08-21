# wwcd -- completions, lazily; see completions/wrcd.fish for the idiom.
command -q ward; or return
ward shell init fish 2>/dev/null | source
