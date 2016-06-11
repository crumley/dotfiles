function __fzf_ctrl_t
  set -q FZF_CTRL_T_COMMAND; or set -l FZF_CTRL_T_COMMAND "
  command find -L . \\( -path '*/\\.*' -o -fstype 'dev' -o -fstype 'proc' \\) -prune \
    -o -type f -print \
    -o -type d -print \
    -o -type l -print 2> /dev/null | sed 1d | cut -b3-"
  eval "$FZF_CTRL_T_COMMAND | "(__fzfcmd)" -m > $TMPDIR/fzf.result"
  and sleep 0
  and commandline -i (cat $TMPDIR/fzf.result | __fzf_escape)
  commandline -f repaint
  rm -f $TMPDIR/fzf.result
end