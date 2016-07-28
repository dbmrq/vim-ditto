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


" Add good and bad words {{{

let g:ditto_good_words = []

function! s:updateGoodWords(...)
    if len(g:ditto_good_words) > 0 || a:0 > 0
        new
        setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
        for word in g:ditto_good_words
            call append(0, word)
        endfor
        execute 'silent! w! ' . g:dittofile
        q
        return
    endif
    if filereadable(g:dittofile)
        let g:ditto_good_words = filter(readfile(g:dittofile), 'v:val != ""')
    else
        new
        setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
        execute 'silent! w! ' . g:dittofile
        q
    endif
endfunction

call s:updateGoodWords()

" function! s:saveWord(word, file)
"     new
"     setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
"     call append(0, a:word)
"     execute 'w >>' . a:file
"     q
" endfun

function! s:addGoodWord(word)
    let l:dittoOn = 0
    if s:dittoParOn == 1 || s:dittoSentOn == 1 || s:dittoFileOn == 1
        let l:dittoOn = 1
    endif
    call s:clearMatches()
    call add(g:ditto_good_words, a:word)
    call s:updateGoodWords()
    " echo 'Ditto: "' . a:word . '"' . ' added to ' . g:dittofile
    if l:dittoOn == 1
        silent call s:dittoOn()
    endif
endfunction

function! s:addBadWord(word)
    let l:dittoOn = 0
    if s:dittoParOn == 1 || s:dittoSentOn == 1 || s:dittoFileOn == 1
        let l:dittoOn = 1
    endif
    call s:clearMatches()
    let index = index(g:ditto_good_words, a:word)
    if index >= 0
        call remove(g:ditto_good_words, index)
    endif
    call s:updateGoodWords(1)
    " echo 'Ditto: "' . a:word . '"' . ' removed from ' . g:dittofile
    if l:dittoOn == 1
        silent call s:dittoOn()
    endif
endfunction

"}}}


" Get most frequent words {{{

function! s:wordOrder(first, second)
    if a:first[1] < a:second[1]
        return 1
    elseif a:first[1] > a:second[1]
        return -1
    elseif len(a:first[0]) < len(a:second[0])
        return 1
    elseif len(a:first[0]) > len(a:second[0])
        return -1
    else
        return 0
    endif
endfunction

function! s:sortWords(dict)
    let list = items(a:dict)
    let sortedDict = sort(list, "s:wordOrder")
    return sortedDict
endfunction

function! s:getWords(first_line, last_line)
    let wordSeparators = '[[:blank:][:punct:]]\+'
    let allWords = split(tolower(join(getline(a:first_line, a:last_line))),
                        \ wordSeparators)
    let countedWords = {}
    for word in allWords
        if len(substitute(word, '.', 'x', 'g')) >= g:ditto_min_word_length &&
            \ !(join(g:ditto_good_words) =~ word)
                let countedWords[word] = get(countedWords, word, 0) + 1
        endif
    endfor
    call filter(countedWords, 'v:val >= g:ditto_min_repetitions')
    return s:sortWords(countedWords)
endfunction

"}}}


" Functions for highlighting {{{

let s:matchedids = []
let s:lastrange = ""

function! s:ditto(...) range
    if a:0 > 0
        let s:lastrange = a:firstline . ',' . a:lastline
    endif
    let l:winview = winsaveview()
    execute "normal! m]"
    let words = s:getWords(a:firstline, a:lastline)
    if len(words) <= 0 "
        echo "Ditto: Not enough words"
        return
    endif
    if s:matchcount != 0
        let i = abs(s:matchcount % len(words))
        let word = words[i][0]
        call add(s:matchedids, matchadd(g:ditto_hlgroups[0], '\c' . word .
            \ '\%>' . (a:firstline - 1) . 'l\%<' . (a:lastline + 1) . 'l'))
    else
        let i = 0
        while i < len(words) && i < len(g:ditto_hlgroups)
            let word = words[i][0]
            call add(s:matchedids, matchadd(g:ditto_hlgroups[i],
                        \ '\c' . word . '\%>' . (a:firstline - 1) .
                        \ 'l\%<' . (a:lastline + 1) . 'l'))
            let i += 1
        endwhile
    endif
    execute "normal! `]"
    call winrestview(l:winview)
endfunction

function! s:noDitto()
    call s:clearMatches()
    let s:matchcount = 0
    let s:dittoSentOn = 0
    let s:dittoParOn = 0
    let s:dittoFileOn = 0
endfunction

function! s:clearMatches()
    for id in s:matchedids
        silent! call matchdelete(id)
    endfor
    let s:matchedids = []
endfunction

    " Show next and previous matches {{{2

    let s:matchcount = 0

    function! s:dittoNext()
        if s:dittoParOn == 1 || s:dittoSentOn == 1 || s:dittoFileOn == 1
            if len(s:matchedids) != 0
                let s:matchcount += 1
            endif
            call s:dittoOn()
        elseif s:lastrange != ""
            call s:clearMatches()
            let s:matchcount += 1
            execute s:lastrange 'call s:ditto()'
        endif
    endfunction

    function! s:dittoPrev()
        if s:dittoParOn == 1 || s:dittoSentOn == 1 || s:dittoFileOn == 1
            if len(s:matchedids) != 0
                let s:matchcount -= 1
            endif
            call s:dittoOn()
        elseif s:lastrange != ""
            call s:clearMatches()
            let s:matchcount -= 1
            execute s:lastrange 'call s:ditto()'
        endif
    endfunction

    "}}}2

    " Functions for specific scopes {{{

    function! s:dittoSent()
        let l:winview = winsaveview()
        silent execute "normal! m]"
        silent g/\(\.\|!\|?\)\()\|]\|"\|'\)*\($\|\s\)/execute "normal! v(:call s:ditto()\<cr>"
        silent execute "normal! `]"
        call winrestview(l:winview)
    endfunction

    function! s:dittoPar()
        let l:winview = winsaveview()
        silent execute "normal! m]"
        silent g/\v.(\n\n|\n*%$)/execute "normal! v{:call s:ditto()\<cr>"
        silent execute "normal! `]"
        call winrestview(l:winview)
    endfunction

    function! s:dittoFile()
        let l:winview = winsaveview()
        silent execute "normal! m]"
        silent execute line(0) . ',' . line('$') 'call s:ditto()'
        silent execute "normal! `]"
        call winrestview(l:winview)
    endfunction

    "}}}

"}}}


" Functions for autocmds {{{1

let s:dittoSentOn = 0
let s:dittoParOn = 0
let s:dittoFileOn = 0

let s:lastline = 0

function! s:dittoUpdate()
    if s:dittoSentOn == 1
        call s:clearMatches()
        call s:dittoSent()
    elseif s:dittoParOn == 1
        call s:clearMatches()
        call s:dittoPar()
    elseif s:dittoFileOn == 1
        call s:clearMatches()
        call s:dittoFile()
    endif
endfunction

function! s:dittoTextChanged()
    if line('$') != s:lastline
        call s:dittoUpdate()
        let s:lastline = line('$')
    endif
endfunction

function! s:dittoInsertCharPre(char)
    if a:char == " "
        call s:dittoUpdate()
    endif
endfunction

function! s:dittoCursorHold()
    if line('$') != s:lastline
        call s:dittoUpdate()
        let s:lastline = line('$')
    endif
endfunction


    " Turn autocmds on and off {{{2

    function! s:addAutoCmds()
        au TextChanged * call s:dittoTextChanged()
        if tolower(g:ditto_autocmd) =~ "cursorhold"
            au CursorHold * call s:dittoCursorHold()
            au CursorHoldI * call s:dittoUpdate()
        elseif tolower(g:ditto_autocmd) =~ "insertleave"
            au InsertLeave * call s:dittoUpdate()
        else
            au InsertCharPre * call s:dittoInsertCharPre(v:char)
        endif
        au WinLeave * call s:clearMatches()
        au WinEnter * call s:dittoUpdate()
    endfunction


    function! s:dittoOn()
        if s:dittoParOn == 1 || s:dittoSentOn == 1 || s:dittoFileOn == 1
            call s:dittoUpdate()
            return
        endif
        call s:noDitto()
        if tolower(g:ditto_mode) =~ 'file'
            let s:dittoFileOn = 1
        elseif tolower(g:ditto_mode) =~ 'sent'
            let s:dittoSentOn = 1
        else
            let s:dittoParOn = 1
        endif
        call s:addAutoCmds()
        call s:dittoUpdate()
    endfunction

    function! s:dittoOff()
        call s:noDitto()
    endfunction

    function! s:toggleDitto()
        if s:dittoParOn == 1 || s:dittoSentOn == 1 || s:dittoFileOn == 1
            call s:dittoOff()
        else
            call s:dittoOn()
        endif
    endfunction

    "}}}2

"}}}1


" Commands {{{

command! -range=% Ditto <line1>,<line2>call <SID>ditto(1)
command! NoDitto call <SID>noDitto()

command! DittoSent call <SID>dittoSent()
command! DittoPar call <SID>dittoPar()
command! DittoFile call <SID>dittoFile()

command! DittoOn call <SID>dittoOn()
command! DittoOff call <SID>dittoOff()
command! ToggleDitto call <SID>toggleDitto()

"}}}


" Plugs {{{

nnoremap <silent> <Plug>DittoGood
            \ :<C-U>call <SID>addGoodWord(expand("<cword>"))<cr>

nnoremap <silent> <Plug>DittoBad
            \ :<C-U>call <SID>addBadWord(expand("<cword>"))<cr>

nnoremap <silent> <Plug>DittoNext
            \ :<C-U>call <SID>dittoNext()<cr>

nnoremap <silent> <Plug>DittoPrev
            \ :<C-U>call <SID>dittoPrev()<cr>

nnoremap <silent> <Plug>DittoOn
            \ :<C-U>call <SID>dittoOn()<cr>

nnoremap <silent> <Plug>DittoOff
            \ :<C-U>call <SID>dittoOff()<cr>

nnoremap <silent> <Plug>ToggleDitto
            \ :<C-U>call <SID>toggleDitto()<cr>

"}}}

