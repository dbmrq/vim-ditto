" ditto.vim - Stop repeating yourself
" Author:   Daniel B. Marques
" Version:  0.1
" License:  Same as Vim

if exists("g:autoloaded_ditto") || &cp
  finish
endif
let g:autoloaded_ditto = 1


" Add and remove good words {{{

let g:ditto_good_words = []

function! s:getGoodWords()
    if filereadable(g:dittofile)
        let g:ditto_good_words = filter(readfile(g:dittofile), 'v:val != ""')
    else
        writefile([], g:dittofile)
    endif
endfunction

call s:getGoodWords()

function! ditto#addGoodWord(word)
    call s:getGoodWords()
    let l:dittoOn = b:dittoParOn == 1 ||
        \ b:dittoSentOn == 1 || b:dittoFileOn == 1
    call s:clearMatches()
    let error = -1
    if index(g:ditto_good_words, a:word) == -1
        call add(g:ditto_good_words, a:word)
        let error = writefile(g:ditto_good_words, g:dittofile)
    endif
    if l:dittoOn == 1
        call ditto#dittoOn()
    endif
    if error == 0
        redraw
        echo 'Ditto: "' . a:word . '" added to ' . g:dittofile
    endif
endfunction

function! ditto#addBadWord(word)
    silent call s:getGoodWords()
    let l:dittoOn = b:dittoParOn == 1 ||
        \ b:dittoSentOn == 1 || b:dittoFileOn == 1
    call s:clearMatches()
    let index = index(g:ditto_good_words, a:word)
    let error = -1
    if index >= 0
        call remove(g:ditto_good_words, index)
        let error = writefile(g:ditto_good_words, g:dittofile)
    endif
    if l:dittoOn == 1
        call ditto#dittoOn()
    endif
    if error == 0
        redraw
        echo 'Ditto: "' . a:word . '" removed from ' . g:dittofile
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


" Highlight words {{{

let w:matchedids = []
let b:matchedwords = []
let b:lastrange = ""

function! ditto#ditto(...) range
    if a:0 > 0
        let b:lastrange = a:firstline . ',' . a:lastline
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
        if !exists('w:matchedids')
            let w:matchedids = []
        endif
        if !exists('b:matchedwords')
            let b:matchedwords = []
        endif
        " call add(w:matchedids,
        "             \ matchadd(g:ditto_hlgroups[0], '\c' . word . '\%V'))
        " call add (b:matchedwords, word . '\%V'))
        call add(w:matchedids, matchadd(g:ditto_hlgroups[0], '\c' . word .
            \ '\%>' . (a:firstline - 1) . 'l\%<' . (a:lastline + 1) . 'l'))
        call add (b:matchedwords, word . '%>' . (a:firstline - 1) . 'l%<' . (a:lastline + 1) . 'l')
    else
        let i = 0
        while i < len(words) && i < len(g:ditto_hlgroups)
            let word = words[i][0]
            if !exists('w:matchedids')
                let w:matchedids = []
            endif
            if !exists('b:matchedwords')
                let b:matchedwords = []
            endif
            call add(w:matchedids, matchadd(g:ditto_hlgroups[i],
                        \ '\c' . word . '\%>' . (a:firstline - 1) .
                        \ 'l\%<' . (a:lastline + 1) . 'l'))
        call add (b:matchedwords, word . '%>' . (a:firstline - 1) . 'l%<' . (a:lastline + 1) . 'l')
            let i += 1
        endwhile
    endif
    execute "normal! `]"
    call winrestview(l:winview)
endfunction

function! ditto#noDitto()
    call s:clearMatches()
    let s:matchcount = 0
    let b:dittoSentOn = 0
    let b:dittoParOn = 0
    let b:dittoFileOn = 0
endfunction

function! s:clearMatches()
    if exists('w:matchedids')
        for id in w:matchedids
            silent! call matchdelete(id)
        endfor
        let w:matchedids = []
        let b:matchedwords = []
    endif
endfunction

function! ditto#dittoSearch(cmd)
    if !exists('b:matchedwords')
        let b:matchedwords = []
    endif
    let len = len(b:matchedwords)
    if len == 0
        return
    elseif len == 1
        execute "normal! " . a:cmd . b:matchedwords[0] . "\<cr>"
        redraw
    endif
    let command = "normal! " . a:cmd . "\\v("
    let i = 0
    while i < len - 1
        let command .= b:matchedwords[i] . "|"
        let i += 1
    endwhile
    let command .= b:matchedwords[len - 1] . ")\<cr>"
    execute command
    redraw
endfunction


    " Show next and previous matches {{{2

    let s:matchcount = 0

    function! ditto#dittoMore()
        if b:dittoParOn == 1 || b:dittoSentOn == 1 || b:dittoFileOn == 1
            if exists('w:matchedids') && len(w:matchedids) != 0
                let s:matchcount += 1
            endif
            call ditto#dittoOn()
        elseif b:lastrange != ""
            call s:clearMatches()
            let s:matchcount += 1
            execute b:lastrange 'call ditto#ditto()'
        endif
    endfunction

    function! ditto#dittoLess()
        if b:dittoParOn == 1 || b:dittoSentOn == 1 || b:dittoFileOn == 1
            if exists('w:matchedids') && len(w:matchedids) != 0
                let s:matchcount -= 1
            endif
            call ditto#dittoOn()
        elseif b:lastrange != ""
            call s:clearMatches()
            let s:matchcount -= 1
            execute b:lastrange 'call ditto#ditto()'
        endif
    endfunction

    "}}}2

    " Functions for specific scopes {{{

    function! ditto#dittoSent() range
    let l:winview = winsaveview()
    silent execute "normal! m]"
        if a:lastline - a:firstline > 0
            let first_line = a:firstline
            let last_line = a:lastline
        else
            let first_line = 0
            let last_line = line('$')
        endif
        let pattern = '\v[.!?][])"'']*($|\s)'
        silent execute first_line . ',' . last_line . 'g/' . pattern . '/execute "normal! v(:call ditto#ditto()\<cr>"'
    silent execute "normal! `]"
    call winrestview(l:winview)
    endfunction

    function! ditto#dittoPar() range
    let l:winview = winsaveview()
    silent execute "normal! m]"
        if a:lastline - a:firstline > 0
            let first_line = a:firstline
            let last_line = a:lastline
        else
            let first_line = 0
            let last_line = line('$')
        endif
        silent execute first_line . ',' . last_line 'g/\v.(\n\n|\n*%$)/execute "normal! v{:call ditto#ditto()\<cr>"'
    silent execute "normal! `]"
    call winrestview(l:winview)
    endfunction

    function! ditto#dittoFile()
    let l:winview = winsaveview()
    silent execute "normal! m]"
        silent execute line(0) . ',' . line('$') 'call ditto#ditto()'
    silent execute "normal! `]"
    call winrestview(l:winview)
    endfunction

    function! s:dittoCurrentScope()
        if b:dittoSentOn == 1
            silent execute "normal! vas:call ditto#ditto()\<cr>"
        elseif b:dittoFileOn == 1
            silent execute line(0) . ',' . line('$') 'call ditto#ditto()'
        else
            silent execute "normal! vap:call ditto#ditto()\<cr>"
        endif
    endfunction

    "}}}

"}}}


" Functions for autocmds {{{

let b:dittoSentOn = 0
let b:dittoParOn = 0
let b:dittoFileOn = 0

let b:lastline = 0

function! s:dittoUpdate() range
    if a:lastline - a:firstline > 0
        let first_line = a:firstline
        let last_line = a:lastline
    else
        let first_line = 0
        let last_line = line('$')
    endif
    if exists('b:dittoSentOn') &&
                \ exists('b:dittoParOn') && exists('b:dittoFileOn')
        if b:dittoSentOn == 1
            call s:clearMatches()
            execute first_line . ',' . last_line 'call ditto#dittoSent()'
        elseif b:dittoParOn == 1
            call s:clearMatches()
            execute first_line . ',' . last_line 'call ditto#dittoPar()'
        elseif b:dittoFileOn == 1
            call ditto#dittoFile()
            call s:clearMatches()
        endif
    endif
endfunction

function! s:dittoTextChanged()
    let l:winview = winsaveview()
    silent execute "normal! m]"
    if line('$') != b:lastline
        call s:dittoUpdate()
        let b:lastline = line('$')
    endif
    silent execute "normal! `]"
    call winrestview(l:winview)
endfunction

function! s:dittoInsertCharPre(char)
    let l:winview = winsaveview()
    silent execute "normal! m]"
    if line('$') != b:lastline &&
                \ len(filter(getline(line('.') + 1, '$'), 'v:val != ""')) > 0
        call s:dittoUpdate()
        " execute b:lastline - 1 . ',' . line('$') 'call s:dittoUpdate()'
    elseif a:char == " "
        call s:dittoCurrentScope()
    endif
    let b:lastline = line('$')
    silent execute "normal! `]"
    call winrestview(l:winview)
endfunction

function! s:dittoCursorHold()
    let l:winview = winsaveview()
    silent execute "normal! m]"
    if line('$') != b:lastline
        call s:dittoUpdate()
        let b:lastline = line('$')
    endif
    silent execute "normal! `]"
    call winrestview(l:winview)
endfunction


    " Turn autocmds on and off {{{2

    function! s:addAutoCmds()
        au TextChanged,TextChangedI <buffer> call s:dittoTextChanged()
        if tolower(g:ditto_autocmd) =~ "cursorhold"
            au CursorHold <buffer> call s:dittoCursorHold()
            au CursorHoldI <buffer> call s:dittoUpdate()
        elseif tolower(g:ditto_autocmd) =~ "insertleave"
            au InsertLeave <buffer> call s:dittoUpdate()
        else
            au InsertCharPre <buffer> call s:dittoInsertCharPre(v:char)
        endif
        " au WinLeave * call s:clearMatches()
        au WinEnter <buffer> call s:dittoUpdate()
    endfunction


    function! ditto#dittoOn()
        call ditto#noDitto()
        if exists('b:ditto_mode')
            if tolower('b:ditto_mode') =~ 'file'
                call ditto#dittoFileOn()
            elseif tolower(b:ditto_mode) =~ 'sent'
                call ditto#dittoSentOn()
            else
                call ditto#dittoParOn()
            endif
        else
            if tolower('g:ditto_mode') =~ 'file'
                call ditto#dittoFileOn()
            elseif tolower(g:ditto_mode) =~ 'sent'
                call ditto#dittoSentOn()
            else
                call ditto#dittoParOn()
            endif
        endif
    endfunction

    function! ditto#dittoSentOn()
        let b:ditto_mode = 'sent'
        let b:dittoFileOn = 0
        let b:dittoParOn = 0
        let b:dittoSentOn = 1
        call s:addAutoCmds()
        call s:dittoUpdate()
    endfunction

    function! ditto#dittoParOn()
        let b:ditto_mode = 'par'
        let b:dittoFileOn = 0
        let b:dittoParOn = 1
        let b:dittoSentOn = 0
        call s:addAutoCmds()
        call s:dittoUpdate()
    endfunction

    function! ditto#dittoFileOn()
        let b:ditto_mode = 'file'
        let b:dittoFileOn = 1
        let b:dittoParOn = 0
        let b:dittoSentOn = 0
        call s:addAutoCmds()
        call s:dittoUpdate()
    endfunction

    function! s:dittoOff()
        call ditto#noDitto()
    endfunction

    function! ditto#toggleDitto()
        if b:dittoParOn == 1 || b:dittoSentOn == 1 || b:dittoFileOn == 1
            if exists('w:matchedids') && len(w:matchedids) != 0
                call s:dittoOff()
            else
                call s:dittoUpdate()
            endif
        else
            call ditto#dittoOn()
        endif
    endfunction

    "}}}2

"}}}

