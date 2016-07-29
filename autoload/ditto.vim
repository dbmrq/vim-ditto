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

function! ditto#getGoodWords()
    if filereadable(g:dittofile)
        let g:ditto_good_words = filter(readfile(g:dittofile), 'v:val != ""')
    else
        writefile([], g:dittofile)
    endif
endfunction

call ditto#getGoodWords()

function! ditto#addGoodWord(word)
    call ditto#getGoodWords()
    let l:dittoOn = s:dittoParOn == 1 ||
        \ s:dittoSentOn == 1 || s:dittoFileOn == 1
    call ditto#clearMatches()
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
    silent call ditto#getGoodWords()
    let l:dittoOn = s:dittoParOn == 1 ||
        \ s:dittoSentOn == 1 || s:dittoFileOn == 1
    call ditto#clearMatches()
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

function! ditto#wordOrder(first, second)
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

function! ditto#sortWords(dict)
    let list = items(a:dict)
    let sortedDict = sort(list, "ditto#wordOrder")
    return sortedDict
endfunction

function! ditto#getWords(first_line, last_line)
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
    return ditto#sortWords(countedWords)
endfunction

"}}}


" Highlight words {{{

let s:matchedids = []
let s:matchedwords = []
let s:lastrange = ""

function! ditto#ditto(...) range
    if a:0 > 0
        let s:lastrange = a:firstline . ',' . a:lastline
    endif
    let l:winview = winsaveview()
    execute "normal! m]"
    let words = ditto#getWords(a:firstline, a:lastline)
    if len(words) <= 0 "
        echo "Ditto: Not enough words"
        return
    endif
    if s:matchcount != 0
        let i = abs(s:matchcount % len(words))
        let word = words[i][0]
        call add(s:matchedids, matchadd(g:ditto_hlgroups[0], '\c' . word .
            \ '\%>' . (a:firstline - 1) . 'l\%<' . (a:lastline + 1) . 'l'))
        call add (s:matchedwords, word . '%>' . (a:firstline - 1) . 'l%<' . (a:lastline + 1) . 'l')
    else
        let i = 0
        while i < len(words) && i < len(g:ditto_hlgroups)
            let word = words[i][0]
            call add(s:matchedids, matchadd(g:ditto_hlgroups[i],
                        \ '\c' . word . '\%>' . (a:firstline - 1) .
                        \ 'l\%<' . (a:lastline + 1) . 'l'))
        call add (s:matchedwords, word . '%>' . (a:firstline - 1) . 'l%<' . (a:lastline + 1) . 'l')
            let i += 1
        endwhile
    endif
    execute "normal! `]"
    call winrestview(l:winview)
endfunction

function! ditto#noDitto()
    call ditto#clearMatches()
    let s:matchcount = 0
    let s:dittoSentOn = 0
    let s:dittoParOn = 0
    let s:dittoFileOn = 0
endfunction

function! ditto#clearMatches()
    for id in s:matchedids
        silent! call matchdelete(id)
    endfor
    let s:matchedids = []
    let s:matchedwords = []
endfunction

function! ditto#dittoSearch(cmd)
    let len = len(s:matchedwords)
    if len == 0
        return
    elseif len == 1
        execute "normal! " . a:cmd . s:matchedwords[0] . "\<cr>"
        redraw
    endif
    let command = "normal! " . a:cmd . "\\v("
    let i = 0
    while i < len - 1
        let command .= s:matchedwords[i] . "|"
        let i += 1
    endwhile
    let command .= s:matchedwords[len - 1] . ")\<cr>"
    execute command
    redraw
endfunction


    " Show next and previous matches {{{2

    let s:matchcount = 0

    function! ditto#dittoMore()
        if s:dittoParOn == 1 || s:dittoSentOn == 1 || s:dittoFileOn == 1
            if len(s:matchedids) != 0
                let s:matchcount += 1
            endif
            call ditto#dittoOn()
        elseif s:lastrange != ""
            call ditto#clearMatches()
            let s:matchcount += 1
            execute s:lastrange 'call ditto#ditto()'
        endif
    endfunction

    function! ditto#dittoLess()
        if s:dittoParOn == 1 || s:dittoSentOn == 1 || s:dittoFileOn == 1
            if len(s:matchedids) != 0
                let s:matchcount -= 1
            endif
            call ditto#dittoOn()
        elseif s:lastrange != ""
            call ditto#clearMatches()
            let s:matchcount -= 1
            execute s:lastrange 'call ditto#ditto()'
        endif
    endfunction

    "}}}2

    " Functions for specific scopes {{{

    function! ditto#dittoSent()
        let l:winview = winsaveview()
        silent execute "normal! m]"
        silent g/\(\.\|!\|?\)\()\|]\|"\|'\)*\($\|\s\)/execute "normal! v(:call ditto#ditto()\<cr>"
        silent execute "normal! `]"
        call winrestview(l:winview)
    endfunction

    function! ditto#dittoPar()
        let l:winview = winsaveview()
        silent execute "normal! m]"
        silent g/\v.(\n\n|\n*%$)/execute "normal! v{:call ditto#ditto()\<cr>"
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

    "}}}

"}}}


" Functions for autocmds {{{

let s:dittoSentOn = 0
let s:dittoParOn = 0
let s:dittoFileOn = 0

let s:lastline = 0

function! ditto#dittoUpdate()
    if s:dittoSentOn == 1
        call ditto#clearMatches()
        call ditto#dittoSent()
    elseif s:dittoParOn == 1
        call ditto#clearMatches()
        call ditto#dittoPar()
    elseif s:dittoFileOn == 1
        call ditto#clearMatches()
        call ditto#dittoFile()
    endif
endfunction

function! ditto#dittoTextChanged()
    if line('$') != s:lastline
        call ditto#dittoUpdate()
        let s:lastline = line('$')
    endif
endfunction

function! ditto#dittoInsertCharPre(char)
    if a:char == " "
        call ditto#dittoUpdate()
    endif
endfunction

function! ditto#dittoCursorHold()
    if line('$') != s:lastline
        call ditto#dittoUpdate()
        let s:lastline = line('$')
    endif
endfunction


    " Turn autocmds on and off {{{2

    function! ditto#addAutoCmds()
        au TextChanged * call ditto#dittoTextChanged()
        if tolower(g:ditto_autocmd) =~ "cursorhold"
            au CursorHold * call ditto#dittoCursorHold()
            au CursorHoldI * call ditto#dittoUpdate()
        elseif tolower(g:ditto_autocmd) =~ "insertleave"
            au InsertLeave * call ditto#dittoUpdate()
        else
            au InsertCharPre * call ditto#dittoInsertCharPre(v:char)
        endif
        au WinLeave * call ditto#clearMatches()
        au WinEnter * call ditto#dittoUpdate()
    endfunction


    function! ditto#dittoOn()
        if s:dittoParOn == 1 || s:dittoSentOn == 1 || s:dittoFileOn == 1
            call ditto#dittoUpdate()
            return
        endif
        call ditto#noDitto()
        if tolower(g:ditto_mode) =~ 'file'
            let s:dittoFileOn = 1
        elseif tolower(g:ditto_mode) =~ 'sent'
            let s:dittoSentOn = 1
        else
            let s:dittoParOn = 1
        endif
        call ditto#addAutoCmds()
        call ditto#dittoUpdate()
    endfunction

    function! ditto#dittoOff()
        call ditto#noDitto()
    endfunction

    function! ditto#toggleDitto()
        if s:dittoParOn == 1 || s:dittoSentOn == 1 || s:dittoFileOn == 1
            call ditto#dittoOff()
        else
            call ditto#dittoOn()
        endif
    endfunction

    "}}}2

"}}}

