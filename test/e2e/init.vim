set nocompatible
set nomore
set noswapfile
set nowrap
set number
set numberwidth=3
set laststatus=2
set cmdheight=2
set showcmd
set scrolloff=3
set shortmess+=I
set noignorecase
set background=dark
set termguicolors
syntax off

let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let &runtimepath = s:root . ',' . &runtimepath

let g:ditto_dir = !empty($DITTO_E2E_DIR) ? $DITTO_E2E_DIR : expand('<sfile>:p:h') . '/out/ditto'
let g:ditto_file = 'dittofile.txt'
let g:ditto_mode = 'paragraph'
let g:ditto_hlgroups = ['DittoE2E1', 'DittoE2E2']

highlight DittoE2E1 guifg=#101014 guibg=#ffd866 gui=bold ctermfg=16 ctermbg=226 cterm=bold
highlight DittoE2E2 guifg=#101014 guibg=#78dce8 gui=bold ctermfg=16 ctermbg=51 cterm=bold

set statusline=\ vim-ditto\ E2E\ \|\ %f\ \|\ mode:\ %{get(b:,'ditto_mode','off')}\ \|\ %l:%c\ \|\ %p%%

function! s:ScreenAttrForWord(word) abort
  let pos = searchpos('\<' . a:word . '\>', 'nw')
  if pos == [0, 0]
    return []
  endif

  let screen_pos = screenpos(win_getid(), pos[0], pos[1])
  if screen_pos.row == 0
    return []
  endif

  return [pos[0], pos[1], screen_pos.row, screen_pos.col,
        \ screenattr(screen_pos.row, screen_pos.col)]
endfunction

function! s:AutocmdCount(event) abort
  try
    return len(filter(
          \ split(execute('autocmd ditto ' . a:event . ' <buffer>'), "\n"),
          \ 'v:val =~# "call "'))
  catch
    return 0
  endtry
endfunction

function! DittoE2EState() abort
  let autocmds = {}
  for event in ['TextChanged', 'TextChangedI', 'WinEnter']
    let autocmds[event] = s:AutocmdCount(event)
  endfor

  let screen_attrs = {}
  for word in ['beagle', 'writing', 'needs', 'quick']
    let screen_attrs[word] = s:ScreenAttrForWord(word)
  endfor

  return {
        \ 'mode': get(b:, 'ditto_mode', ''),
        \ 'matches': map(getmatches(),
        \   '{"group": v:val.group, "pattern": v:val.pattern}'),
        \ 'cursor': [line('.'), col('.')],
        \ 'word': expand('<cword>'),
        \ 'autocmds': autocmds,
        \ 'good_words': filereadable(g:ditto_dir . '/' . g:ditto_file) ?
        \   readfile(g:ditto_dir . '/' . g:ditto_file) : [],
        \ 'screen_attrs': screen_attrs,
        \ 'lines': getline(1, '$'),
        \ }
endfunction
