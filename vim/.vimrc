" ~/.vimrc
"
" $EDITOR here is `code -w`; vim is the quick-terminal-edit fallback — commit
" messages, a config file over ssh, a scratch buffer. So this file is built to
" one rule: it must work, unchanged and without error, on whatever vim is
" already on the box. No plugins, no plugin manager, no runtime downloads,
" nothing that assumes a feature is compiled in. Stock Linux vim, macOS's
" /usr/bin/vim, a busybox-adjacent vim on some server — all fine.
"
" Every feature-dependent setting is behind a has()/exists() guard for that
" reason. Adding a plugin manager here would trade that away for capability vim
" is not being asked to provide.

set nocompatible

" ---------------------------------------------------------------------------
" Files and writing
" ---------------------------------------------------------------------------

set encoding=utf-8
set fileformats=unix,dos,mac

" NOT set: `binary` and `noeol`, which the previous version of this file had.
" Together they wrote every new file with no trailing newline (verified: a
" one-line file saved as 5 bytes, `hello`, where vim's default writes 6,
" `hello\n`) — malformed by POSIX and noisy in every diff. `binary` also
" force-disables expandtab, textwidth, smarttab and wrapmargin, which is why
" tabstop=2 below was previously fighting a shiftwidth of 8.

set backupdir=~/.vim/backups
set directory=~/.vim/swaps
if has('persistent_undo')
  set undodir=~/.vim/undo
  set undofile
endif

" Create those directories rather than shipping placeholder files to make stow
" materialise them. A vim that cannot write its swapfile falls back to the
" file's own directory and litters, and previously `undodir` pointed at a
" directory that never existed at all, so persistent undo silently did nothing.
for s:dir in [&backupdir, &directory, (has('persistent_undo') ? &undodir : '')]
  if !empty(s:dir) && !isdirectory(expand(s:dir))
    call mkdir(expand(s:dir), 'p', 0700)
  endif
endfor

" ---------------------------------------------------------------------------
" Clipboard
" ---------------------------------------------------------------------------

" `unnamed` is the * register. On macOS that IS the system clipboard, but on
" X11 it is the PRIMARY selection (middle-click paste), not what Cmd/Ctrl-V
" reads — so the old unconditional `set clipboard=unnamed` quietly did the
" wrong thing on Linux. `unnamedplus` is the + register, i.e. the real
" clipboard, and exists only where vim was built with +clipboard.
if has('clipboard')
  if has('unnamedplus')
    set clipboard=unnamedplus
  else
    set clipboard=unnamed
  endif
endif

" ---------------------------------------------------------------------------
" Editing
" ---------------------------------------------------------------------------

set backspace=indent,eol,start
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set autoindent
set nostartofline
let mapleader=","

" ---------------------------------------------------------------------------
" Display
" ---------------------------------------------------------------------------

set number
set cursorline
set ruler
set showcmd
set showmode
set laststatus=2
set title
set scrolloff=3
set shortmess=atI
set noerrorbells
set wildmenu

if has('syntax')
  syntax enable
endif
if has('autocmd')
  filetype plugin indent on
endif

" Show invisibles. The glyphs are Unicode, so require a UTF-8 terminal; fall
" back to ASCII where the locale cannot render them.
set list
if &encoding ==# 'utf-8'
  set listchars=tab:▸\ ,trail:·,extends:>,precedes:<,nbsp:_
else
  set listchars=tab:>\ ,trail:.,extends:>,precedes:<,nbsp:_
endif

" ---------------------------------------------------------------------------
" Search
" ---------------------------------------------------------------------------

set hlsearch
set incsearch
set ignorecase
set smartcase

" ---------------------------------------------------------------------------
" Mouse
" ---------------------------------------------------------------------------

if has('mouse')
  set mouse=a
endif

" ---------------------------------------------------------------------------
" Modelines
" ---------------------------------------------------------------------------

set modeline
set modelines=4

" NOT set: `exrc`, which the previous version enabled. It makes vim source a
" .vimrc found in the current directory — so cd'ing into any cloned repo hands
" that repo a say in your editor's configuration. `secure` blanket-blocks the
" worst of it, but the safe move is simply not to read the file.

" ---------------------------------------------------------------------------
" Mappings
" ---------------------------------------------------------------------------

" ,ss — strip trailing whitespace without moving the cursor or clobbering
" the last search.
function! s:StripWhitespace() abort
  let l:save_cursor = getpos('.')
  let l:old_query = getreg('/')
  keeppatterns %s/\s\+$//e
  call setpos('.', l:save_cursor)
  call setreg('/', l:old_query)
endfunction
nnoremap <silent> <leader>ss :call <SID>StripWhitespace()<CR>

" ,W — write a file you opened without the rights to save it.
nnoremap <leader>W :w !sudo tee % > /dev/null<CR>

" ,<space> — clear search highlighting.
nnoremap <silent> <leader><space> :nohlsearch<CR>

" Removed: an autocmd forcing *.json to `setfiletype json syntax=javascript`.
" Vim has shipped a json filetype and syntax since 7.4; the autocmd set the
" filetype vim had already detected, and the trailing `syntax=javascript` was
" never a valid argument to :setfiletype and was silently ignored (verified:
" &syntax is 'json' either way).
"
" Removed: `set esckeys` and `set ttyfast`. esckeys is a no-op on any terminal
" from this century and does not exist in neovim; ttyfast has defaulted on
" since vim 8.
