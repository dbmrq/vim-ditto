" ditto.vim - Stop repeating yourself
" Author:   Daniel B. Marques
" Version:  0.4.0
" License:  Same as Vim

if exists('g:loaded_ditto') || &cp
  finish
endif
let g:loaded_ditto = 1


" Options {{{1

if !exists('g:ditto_min_word_length')
  let g:ditto_min_word_length = 4
endif

if !exists('g:ditto_min_repetitions')
  let g:ditto_min_repetitions = 3
endif

if !exists('g:ditto_hlgroups')
  let g:ditto_hlgroups = ['SpellRare']
endif

if !exists('g:ditto_mode')
  let g:ditto_mode = 'paragraph'
endif

if !exists('g:ditto_file')
  let g:ditto_file = 'dittofile.txt'
endif

" }}}1


" Commands {{{1

command! -range=% -bar Ditto <line1>,<line2>call ditto#ditto(1)
command! -bar NoDitto call ditto#noDitto()

command! -bar DittoSent call ditto#dittoSent(1)
command! -bar DittoPar call ditto#dittoPar(1)
command! -bar DittoFile call ditto#dittoFile(1)

command! -bar DittoSentOn call ditto#dittoSentOn()
command! -bar DittoParOn call ditto#dittoParOn()
command! -bar DittoFileOn call ditto#dittoFileOn()

command! -bang -bar DittoOn call ditto#dittoOn(<bang>0)
command! -bar DittoOff call ditto#dittoOff()
command! -bar ToggleDitto call ditto#toggleDitto()
command! -bar DittoUpdate call ditto#dittoUpdate()

" }}}1


" Plugs {{{1

nnoremap <Plug>DittoGood
      \ :<C-U>call ditto#addGoodWord(expand('<cword>'))<cr>

nnoremap <Plug>DittoBad
      \ :<C-U>call ditto#addBadWord(expand('<cword>'))<cr>

nnoremap <silent> <Plug>DittoMore
      \ :<C-U>call ditto#dittoMore()<cr>

nnoremap <silent> <Plug>DittoLess
      \ :<C-U>call ditto#dittoLess()<cr>

nnoremap <silent> <Plug>DittoNext
      \ :<C-U>silent keepp call ditto#dittoSearch('/')<cr>

nnoremap <silent> <Plug>DittoPrev
      \ :<C-U>silent keepp call ditto#dittoSearch('?')<cr>

nnoremap <silent> <Plug>DittoOn
      \ :<C-U>call ditto#dittoOn()<cr>

nnoremap <silent> <Plug>DittoOff
      \ :<C-U>call ditto#dittoOff()<cr>

nnoremap <silent> <Plug>ToggleDitto
      \ :<C-U>call ditto#toggleDitto()<cr>

nnoremap <silent> <Plug>DittoUpdate
      \ :<C-U>call ditto#dittoUpdate()<cr>

nnoremap <silent> <Plug>Ditto
      \ :<C-U>set opfunc=ditto#dittoOp<cr>g@

vnoremap <silent> <Plug>Ditto
      \ :<C-U>call ditto#dittoOp(visualmode(), 1)<cr>

" }}}1
