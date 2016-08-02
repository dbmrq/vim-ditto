" ditto.vim - Stop repeating yourself
" Author:   Daniel B. Marques
" Version:  0.2
" License:  Same as Vim

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

if !exists('g:ditto_file')
    let g:ditto_file = 'dittofile.txt'
endif

if !exists('g:ditto_dir')
    for dir in split(&l:runtimepath, ",")
        if isdirectory(expand(dir))
            if !isdirectory(expand(dir) . '/Ditto')
                call mkdir(expand(dir) . '/Ditto')
            endif
            let g:dittofile = expand(dir) . '/Ditto/'. g:ditto_file
            break
        endif
    endfor
else
    for file in split(g:dittofile, ",")
        if isdirectory(expand(dir))
            let g:dittofile = expand(dir) . g:ditto_file
            break
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

command! DittoSentOn call ditto#dittoSentOn()
command! DittoParOn call ditto#dittoParOn()
command! DittoFileOn call ditto#dittoFileOn()

command! DittoOn call ditto#dittoOn()
command! DittoOff call ditto#noDitto()
command! ToggleDitto call ditto#toggleDitto()

"}}}


" Plugs {{{

nnoremap <Plug>DittoGood
            \ :call ditto#addGoodWord(expand("<cword>"))<cr>

nnoremap <Plug>DittoBad
            \ :call ditto#addBadWord(expand("<cword>"))<cr>

nnoremap <silent> <Plug>DittoMore
            \ :call ditto#dittoMore()<cr>

nnoremap <silent> <Plug>DittoLess
            \ :call ditto#dittoLess()<cr>

nnoremap <silent> <Plug>DittoNext
            \ :call ditto#dittoSearch("/")<cr>

nnoremap <silent> <Plug>DittoPrev
            \ :call ditto#dittoSearch("?")<cr>

nnoremap <silent> <Plug>DittoOn
            \ :call ditto#dittoOn()<cr>

nnoremap <silent> <Plug>DittoOff
            \ :call ditto#dittoOff()<cr>

nnoremap <silent> <Plug>ToggleDitto
            \ :call ditto#toggleDitto()<cr>

nnoremap <silent> <Plug>DittoUpdate
            \ :call ditto#dittoUpdate()<cr>

"}}}

