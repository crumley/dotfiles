# wrr -- completions, lazily; see completions/wrcd.fish for the idiom. The
# layer completes wrr by wrapping `ward repo refresh`, so this also pulls in
# ward's own completions via the ward.fish bootstrap when first needed.
command -q ward; or return
ward shell init fish 2>/dev/null | source
