" ditto.vim - Stop repeating yourself
" Author:   Daniel B. Marques
" Version:  0.1
" License:  Same as ViM

if exists("g:loaded_ditto") || &cp
  finish
endif
let g:loaded_ditto = 1


" Options {{{

if !exists('g:ditto_min_word_length')
    let g:ditto_min_word_length = 4
endif

if !exists('g:ditto_min_repetitions')
    let g:ditto_min_repetitions = 3
endif

if !exists('g:ditto_hlgroups')
    let g:ditto_hlgroups = ['Error',]
                        " \ 'Title',]
endif

if !exists('g:ditto_mode')
    let g:ditto_mode = 'paragraph'
endif

if !exists('g:ditto_autocmd')
    let g:ditto_autocmd = 'InsertCharPre'
endif

if !exists('g:dittofile')
    for dir in split(&l:runtimepath, ",")
        if isdirectory(expand(dir))
            if !isdirectory(expand(dir) . '/Ditto')
                call mkdir(expand(dir) . '/Ditto')
            endif
            let g:dittofile = expand(dir) . '/Ditto/dittofile.txt'
            break
        endif
    endfor
else
    for file in split(g:dittofile, ",")
        if isdirectory(expand(dir))
            let g:dittofile = expand(dir) . '/dittofile.txt'
            break
        else
            let g:dittofile = expand(dir)
        endif
    endfor
endif

"}}}


" Commands {{{

command! -range=% Ditto <line1>,<line2>call ditto#ditto(1)
command! NoDitto call ditto#noDitto()

command! DittoSent call ditto#dittoSent()
command! DittoPar call ditto#dittoPar()
command! DittoFile call ditto#dittoFile()

command! DittoOn call ditto#dittoOn()
command! DittoOff call ditto#dittoOff()
command! ToggleDitto call ditto#toggleDitto()

"}}}


" Plugs {{{

nnoremap <Plug>DittoGood
            \ :call ditto#addGoodWord(expand("<cword>"))<cr>

nnoremap <Plug>DittoBad
            \ :call ditto#addBadWord(expand("<cword>"))<cr>

nnoremap <silent> <Plug>DittoNext
            \ :call ditto#dittoNext()<cr>

nnoremap <silent> <Plug>DittoPrev
            \ :call ditto#dittoPrev()<cr>

nnoremap <silent> <Plug>DittoOn
            \ :call ditto#dittoOn()<cr>

nnoremap <silent> <Plug>DittoOff
            \ :call ditto#dittoOff()<cr>

nnoremap <silent> <Plug>ToggleDitto
            \ :call ditto#toggleDitto()<cr>

"}}}

