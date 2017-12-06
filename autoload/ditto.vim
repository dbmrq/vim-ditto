" ditto.vim - Stop repeating yourself
" Author:   Daniel B. Marques
" Version:  0.3
" License:  Same as Vim

if exists("g:autoloaded_ditto") || &cp
  finish
endif
let g:autoloaded_ditto = 1


" Declarations {{{1

let w:dittoMatchedIDs = []
let b:dittoMatchedwords = []
let b:dittoLastRange = ""

let b:dittoSentOn = 0
let b:dittoParOn = 0
let b:dittoFileOn = 0

let b:dittoLastLine = 0

" }}}1


" dittofile {{{1

if !exists('g:ditto_file')
    let g:ditto_file = 'dittofile.txt'
endif

function! s:getDittoDir()
    if exists('g:ditto_dir')
        for dir in split(g:ditto_dir, ",")
            if isdirectory(expand(dir))
                let charlist = split(dir, '\zs')
                if charlist[len(charlist) - 1] != '/'
                    let dir .= '/'
                endif
                return expand(dir)
            endif
        endfor
    endif
endfunction

function! s:makeDittoDir()
    for dir in split(&l:runtimepath, ",")
        if isdirectory(expand(dir))
            if !isdirectory(expand(dir) . '/Ditto')
                call mkdir(expand(dir) . '/Ditto')
            endif
            return expand(dir) . '/Ditto/'
        endif
    endfor
endfunction

function! s:dittoDir()
    let dir = s:getDittoDir()
    if isdirectory(dir)
        return dir
    endif
    let dir = s:makeDittoDir()
    if isdirectory(dir)
        return dir
    endif
    echoerr "Ditto couldn't get a valid directory to save its good words in"
endfunction

function! s:dittoFile()
    let dir = s:dittoDir()
    let file = dir . g:ditto_file
    if !filereadable(file)
        let error = writefile([], file)
        if error != 0
            echoerr "Ditto couldn't write to " . file
            return
        endif
    endif
    return file
endfunction

let s:dittofile = s:dittoFile()

" }}}1


" Add and remove good words {{{1

function! s:getGoodWords()
    let g:dittoGoodWords = filter(readfile(s:dittofile), 'v:val != ""')
endfunction

call s:getGoodWords()

function! ditto#addGoodWord(word)
    let l:winview = winsaveview()
    call s:getGoodWords()
    let l:dittoOn = b:dittoParOn == 1 ||
        \ b:dittoSentOn == 1 || b:dittoFileOn == 1
    call s:clearMatches()
    let error = -1
    if index(g:dittoGoodWords, a:word) == -1
        call add(g:dittoGoodWords, a:word)
        let error = writefile(g:dittoGoodWords, s:dittofile)
    endif
    if l:dittoOn == 1
        call ditto#dittoOn()
    endif
    call winrestview(l:winview)
    if error == 0
        redraw
        echo 'Ditto: "' . a:word . '" added to ' . s:dittofile
    endif
endfunction

function! ditto#addBadWord(word)
    let l:winview = winsaveview()
    silent call s:getGoodWords()
    let l:dittoOn = b:dittoParOn == 1 ||
        \ b:dittoSentOn == 1 || b:dittoFileOn == 1
    call s:clearMatches()
    let index = index(g:dittoGoodWords, a:word)
    let error = -1
    if index >= 0
        call remove(g:dittoGoodWords, index)
        let error = writefile(g:dittoGoodWords, s:dittofile)
    endif
    if l:dittoOn == 1
        call ditto#dittoOn()
    endif
    call winrestview(l:winview)
    if error == 0
        redraw
        echo 'Ditto: "' . a:word . '" removed from ' . s:dittofile
    endif
endfunction

" }}}1


" Get most frequent words {{{1

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
            \ !(join(g:dittoGoodWords) =~ word)
                let countedWords[word] = get(countedWords, word, 0) + 1
        endif
    endfor
    call filter(countedWords, 'v:val >= g:ditto_min_repetitions')
    return s:sortWords(countedWords)
endfunction

" }}}1


" Highlight words {{{1

function! ditto#ditto(...) range
    if a:0 > 0
        let b:dittoLastRange = a:firstline . ',' . a:lastline
    endif
    let l:winview = winsaveview()
    let words = s:getWords(a:firstline, a:lastline)
    if len(words) <= 0 "
        echo "Ditto: Not enough words"
        return
    endif
    if s:matchcount != 0
        let i = abs(s:matchcount % len(words))
        let word = words[i][0]
        if !exists('w:dittoMatchedIDs')
            let w:dittoMatchedIDs = []
        endif
        if !exists('b:dittoMatchedwords')
            let b:dittoMatchedwords = []
        endif
        let matches = [a:firstline, a:lastline,
                    \ matchadd(g:ditto_hlgroups[0],
                    \ '\c' . '\<' . word . '\>' . '\%>' .
                    \ (a:firstline - 1) . 'l\%<' . (a:lastline + 1) . 'l')]
        call add(w:dittoMatchedIDs, matches)

        call add(b:dittoMatchedwords, [a:firstline, a:lastline, word])
    else
        let i = 0
        while i < len(words) && i < len(g:ditto_hlgroups)
            let word = words[i][0]
            if !exists('w:dittoMatchedIDs')
                let w:dittoMatchedIDs = []
            endif
            if !exists('b:dittoMatchedwords')
                let b:dittoMatchedwords = []
            endif
            let matches = [a:firstline, a:lastline,
                \ matchadd(g:ditto_hlgroups[i],
                \ '\c' . '\<' . word . '\>' . '\%>' .
                \ (a:firstline - 1) . 'l\%<' . (a:lastline + 1) . 'l')]
            call add(w:dittoMatchedIDs, matches)
            call add(b:dittoMatchedwords, [a:firstline, a:lastline, word])
            let i += 1
        endwhile
    endif
    call winrestview(l:winview)
endfunction

function! ditto#dittoOp(type, ...)
    call ditto#noDitto()
    if a:0
        silent execute "normal! '<v'>:call ditto#ditto(1)\<cr>"
    elseif a:type == 'line'
        silent execute "normal! `[V`]:call ditto#ditto(1)\<cr>"
    else
        silent execute "normal! `[v`]:call ditto#ditto(1)\<cr>"
    endif
    augroup DittoOp
        au TextChanged <buffer> call ditto#noDitto() | au! DittoOp *
        au TextChangedI <buffer> call ditto#noDitto() | au! DittoOp *
    augroup END
endfunction

function! ditto#noDitto()
    call s:clearMatches()
    let s:matchcount = 0
    let b:dittoSentOn = 0
    let b:dittoParOn = 0
    let b:dittoFileOn = 0
endfunction

function! s:clearMatches(...)
    if exists('w:dittoMatchedIDs')
        if a:0 == 2
            let i = 0
            while i < len(w:dittoMatchedIDs)
                let id = w:dittoMatchedIDs[i]
                if id[0] >= a:1 && id[1] <= a:2
                    silent! call matchdelete(id[2])
                    silent! call remove(w:dittoMatchedIDs, i)
                endif
                let i += 1
            endwhile
            let i = 0
            if !exists('b:dittoMatchedwords')
                let b:dittoMatchedwords = []
            endif
            while i < len(b:dittoMatchedwords)
                let word = b:dittoMatchedwords[i]
                if word[0] >= a:1 && word[1] <= a:2
                    silent! call remove(b:dittoMatchedwords, i)
                endif
                let i += 1
            endwhile
        else
            for l:match in w:dittoMatchedIDs
                silent! call matchdelete(l:match[2])
            endfor
            let w:dittoMatchedIDs = []
            let b:dittoMatchedwords = []
        endif
    endif
endfunction

function! s:clearCurrentScope()
    if b:dittoSentOn == 1
        let sentstart = "'("
        let sentend = "')"
        let first_line = line(sentstart)
        let last_line = line(sentend)
    elseif b:dittoFileOn == 1
        let first_line = 0
        let last_line = line('$')
    else
        let parstart = "'{"
        let parend = "'}"
        let first_line = line(parstart)
        let last_line = line(parend)
    endif
    call s:clearMatches(first_line, last_line)
endfunction

function! ditto#dittoSearch(cmd)
    if !exists('b:dittoMatchedwords')
        let b:dittoMatchedwords = []
    endif
    let len = len(b:dittoMatchedwords)
    if len == 0
        return
    elseif len == 1
        silent keepp execute "normal! "
                    \ . a:cmd . '\c' . s:makeWordPattern(0) . "\<cr>"
        redraw
        return
    endif
    let command = "normal! " . a:cmd . '\c' . '\('
    let i = 0
    while i < len - 1
        let command .= s:makeWordPattern(i) . '\|'
        let i += 1
    endwhile
    let command .= s:makeWordPattern(len - 1) . "\\)\<cr>"
    echo b:dittoMatchedwords
    silent keepp execute command
    redraw
endfunction

function! s:makeWordPattern(index)
    let word = b:dittoMatchedwords[a:index]
    return '\%>' . (word[0] - 1) . 'l\%<' . (word[1] + 1) . 'l' .
                \ '\<' . word[2] . '\>'
endfunction



    " Show next and previous matches {{{2

    let s:matchcount = 0

    function! ditto#dittoMore()
        if b:dittoParOn == 1 || b:dittoSentOn == 1 || b:dittoFileOn == 1
            if exists('w:dittoMatchedIDs') && len(w:dittoMatchedIDs) != 0
                let s:matchcount += 1
            endif
            call ditto#dittoOn()
        elseif b:dittoLastRange != ""
            call s:clearMatches()
            let s:matchcount += 1
            execute b:dittoLastRange 'call ditto#ditto()'
        else
            execute 'call ditto#ditto()'
        endif
    endfunction

    function! ditto#dittoLess()
        if b:dittoParOn == 1 || b:dittoSentOn == 1 || b:dittoFileOn == 1
            if exists('w:dittoMatchedIDs') && len(w:dittoMatchedIDs) != 0
                let s:matchcount -= 1
            endif
            call ditto#dittoOn()
        elseif b:dittoLastRange != ""
            call s:clearMatches()
            let s:matchcount -= 1
            execute b:dittoLastRange 'call ditto#ditto()'
        else
            execute 'call ditto#ditto()'
        endif
    endfunction

    " }}}2

    " Functions for specific scopes {{{2

    function! ditto#dittoSent() range
    let l:winview = winsaveview()
        if a:lastline - a:firstline > 0
            let first_line = a:firstline
            let last_line = a:lastline
        else
            let first_line = 0
            let last_line = line('$')
        endif
        let pattern = '\v[.!?][])"'']*($|\s)'
        let l:lastSelectionStart = getpos("`<")
        let l:lastSelectionEnd = getpos("`>")
        silent execute first_line . ',' . last_line . 'g/' .
                \ pattern . '/execute "normal! V(:call ditto#ditto()\<cr>"'
        call setpos("'<", l:lastSelectionStart)
        call setpos("'>", l:lastSelectionEnd)
    silent execute "normal! `]"
    call winrestview(l:winview)
    endfunction

    function! ditto#dittoPar() range
    let l:winview = winsaveview()
        if a:lastline - a:firstline > 0
            let first_line = a:firstline
            let last_line = a:lastline
        else
            let first_line = 0
            let last_line = line('$')
        endif
        let l:lastSelectionStart = getpos("`<")
        let l:lastSelectionEnd = getpos("`>")
        silent execute first_line . ',' . last_line .
            \ 'g/\v.(\n\n|\n*%$)/execute "normal! V{:call ditto#ditto()\<cr>"'
        call setpos("'<", l:lastSelectionStart)
        call setpos("'>", l:lastSelectionEnd)
    call winrestview(l:winview)
    endfunction

    function! ditto#dittoFile()
    let l:winview = winsaveview()
        silent execute line(0) . ',' . line('$') 'call ditto#ditto()'
    call winrestview(l:winview)
    endfunction

    function! s:dittoCurrentScope()
        if b:dittoSentOn == 1
            silent execute "'(,')" . "call ditto#dittoSent()"
        elseif b:dittoFileOn == 1
            call ditto#dittoFile()
        else
            silent execute "'{,'}" . "call ditto#dittoPar()"
        endif
    endfunction

    " }}}2

" }}}1


" Functions for autocmds {{{1

function! ditto#dittoUpdate() range
    let l:winview = winsaveview()
    if a:lastline - a:firstline > 0
        let first_line = a:firstline
        let last_line = a:lastline
        call s:clearMatches(first_line, last_line)
    else
        let first_line = 0
        let last_line = line('$')
        call s:clearMatches()
    endif
    if exists('b:dittoFileOn') && b:dittoFileOn == 1
        call ditto#dittoFile()
    elseif exists('b:dittoSentOn') && b:dittoSentOn == 1
        execute first_line . ',' . last_line 'call ditto#dittoSent()'
    elseif exists('b:dittoParOn') && b:dittoParOn == 1
        execute first_line . ',' . last_line 'call ditto#dittoPar()'
    endif
    call winrestview(l:winview)
endfunction

function! s:dittoTextChanged()
    if !exists('b:dittoParOn') | let b:dittoParOn = 0 | endif
    if !exists('b:dittoFileOn') | let b:dittoFileOn = 0 | endif
    if !exists('b:dittoSentOn') | let b:dittoSentOn = 0 | endif
    if !(b:dittoParOn || b:dittoFileOn || b:dittoSentOn) | return | endif
    let l:winview = winsaveview()
    if !exists('b:dittoLastLine') | let b:dittoLastLine = 0 | endif
    if line('$') != b:dittoLastLine
        " let start = 0
        " for id in w:dittoMatchedIDs
        "     if id[0] > start && id[0] < line("'[")
        "         let start = id[0]
        "     endif
        " endfor
        " echom start
        " let end = line('$')
        " if end >= start
        "     execute start . ',' end . 'call ditto#dittoUpdate()'
        " endif
        call ditto#dittoUpdate()
    else
        call s:clearCurrentScope()
        call s:dittoCurrentScope()
    endif
    let b:dittoLastLine = line('$')
    call winrestview(l:winview)
endfunction

function! s:dittoTextChangedI()
    if !(b:dittoParOn || b:dittoFileOn || b:dittoSentOn) | return | endif
    let l:winview = winsaveview()
    if line('$') != b:dittoLastLine &&
                \ len(filter(getline(line('.') + 1, '$'), 'v:val != ""')) > 0
        execute line("'[") . ',' line('$') . 'call ditto#dittoUpdate()'
    elseif getline('.')[col('.')-2]  =~ "[ .!?]"
        call s:clearCurrentScope()
        call s:dittoCurrentScope()
    endif
    let b:dittoLastLine = line('$')
    call winrestview(l:winview)
endfunction

    " Turn autocmds on and off {{{2

    function! s:addAutoCmds()
        let b:dittoLastLine = line('$')
        au TextChanged <buffer> call s:dittoTextChanged()
        au TextChangedI <buffer> call s:dittoTextChangedI()
        au WinEnter <buffer> call ditto#dittoUpdate()
    endfunction


    function! ditto#dittoOn()
        if exists('b:dittoParOn') &&
                \ exists('b:dittoSentOn') == 1 && exists('b:dittoFileOn')
            if b:dittoParOn == 1 || b:dittoSentOn == 1 || b:dittoFileOn == 1
                call ditto#dittoUpdate()
                return
            endif
        endif
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
        call ditto#dittoUpdate()
    endfunction

    function! ditto#dittoParOn()
        let b:ditto_mode = 'par'
        let b:dittoFileOn = 0
        let b:dittoParOn = 1
        let b:dittoSentOn = 0
        call s:addAutoCmds()
        call ditto#dittoUpdate()
    endfunction

    function! ditto#dittoFileOn()
        let b:ditto_mode = 'file'
        let b:dittoFileOn = 1
        let b:dittoParOn = 0
        let b:dittoSentOn = 0
        call s:addAutoCmds()
        call ditto#dittoUpdate()
    endfunction

    function! s:dittoOff()
        call ditto#noDitto()
    endfunction

    function! ditto#toggleDitto()
        if (exists('b:dittoParOn') &&
            \ exists('b:dittoSentOn') == 1 && exists('b:dittoFileOn')) &&
            \ (b:dittoParOn == 1 || b:dittoSentOn == 1 || b:dittoFileOn == 1)
                if exists('w:dittoMatchedIDs') && len(w:dittoMatchedIDs) != 0
                    call s:dittoOff()
                else
                    call ditto#dittoUpdate()
                endif
        else
            call ditto#dittoOn()
        endif
    endfunction

    " }}}2

" }}}1

