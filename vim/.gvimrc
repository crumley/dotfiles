" ~/.gvimrc — GUI vim only (MacVim, gvim). Read after .vimrc.
"
" 'guifont' syntax is per-GUI and not interchangeable: MacVim/Windows want
" "Name:h<size>", GTK wants "Name <size>". Setting the wrong one throws E596
" and leaves you on the default font, so branch rather than guess. Each name is
" one the platform ships by default, so this needs no font install.

if has('gui_macvim') || has('gui_mac')
  set guifont=Menlo:h14
elseif has('gui_gtk2') || has('gui_gtk3')
  set guifont=DejaVu\ Sans\ Mono\ 12
elseif has('gui_win32')
  set guifont=Consolas:h12
endif

" Extra leading. GTK gvim has no 'linespace', so guard it.
if exists('&linespace')
  set linespace=8
endif
