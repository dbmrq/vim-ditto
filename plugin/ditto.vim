let g:ditto_min_word_length = 4
let g:ditto_min_repetitions = 3
let g:ditto_hlgroup = "WarningMsg"
let g:ditto_good_words = []

let g:dittofile = expand('<sfile>:p:h:h') . '/Ditto' .
                    \ '/dittofile.' . &l:fileencoding . '.txt'

let s:matchedids = []

function! UpdateGoodWords()
    if filereadable(g:dittofile)
        let g:ditto_good_words = filter(readfile(g:dittofile), 'v:val != ""')
    else
        new
        setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
        execute 'w ' . g:dittofile
        q
    endif
endfunction

call UpdateGoodWords()


function! SortWords(dict)
    let list = items(a:dict)
    let sortedDict = sort(list, "WordOrder")
    return sortedDict
endfunction

function! WordOrder(first, second)
    if a:first[1] < a:second[1]
        return 1
    elseif a:first[1] > a:second[1]
        return -1
    else
        return 0
    endif
endfunction

function! GetWords(first_line, last_line)
    " Words are separated by whitespace or punctuation characters
    let wordSeparators = '[[:blank:][:punct:]]\+'
    let allWords =
        \ split(join(getline(a:first_line, a:last_line)), wordSeparators)
    let countedWords = {}
    for word in allWords
        if len(word) >= g:ditto_min_word_length &&
            \ !(join(g:ditto_good_words) =~ word)
                let countedWords[word] = get(countedWords, word, 0) + 1
        endif
    endfor
    call filter(countedWords, 'v:val >= g:ditto_min_repetitions')
    return SortWords(countedWords)
endfunction

let s:matchcount = 0

function! Ditto() range
    " if len(s:matchedids) > 0
    "     for id in s:matchedids
    "         call matchdelete(id)
    "     endfor
    "     let s:matchedids = []
    " endif
    if a:firstline - a:lastline == 0
        let firstline = 1
        let lastline = line('$')
    else
        let firstline = a:firstline
        let lastline = a:lastline
    endif
    let words = GetWords(firstline, lastline)
    if len(words) <= 0 || s:matchcount > len(words) - 1
        echo "Ditto: Not enough words"
        return
    endif
    let word = words[s:matchcount][0]
    let s:matchcount += 1
    call add(s:matchedids, matchadd(g:ditto_hlgroup,
        \ word . '\%>' . firstline . 'l\%<' . lastline . 'l'))
endfunction

function! UnDitto()
    for id in s:matchedids
        call matchdelete(id)
    endfor
    let s:matchedids = []
    let s:matchcount = 0
endfunction

function! ToggleDitto() range
    if len(s:matchedids) > 0
        call UnDitto()
    else
        execute a:firstline . ',' . a:lastline 'call Ditto()'
    endif
endfunction


function! AddGoodWord(word)
    call SaveWord(a:word, g:dittofile)
    let g:ditto_good_words = readfile(g:dittofile)
    call UnDitto()
endfunction

function! AddBadWord(word)
    let index =  index(g:ditto_good_words, a:word)
    if index >= 0
        call remove(g:ditto_good_words, index)
    endif
endfunction

function! SaveWord(word, file)
    new
    setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
    call append(0, a:word)
    execute 'w >>' . a:file
    q
endfun

" function! DittoPar()
"     execute ":g/\n\n\s*\zs.\_.\{-}\ze\n\n/execute 'normal! vip:Ditto\<cr>'<cr>"
" endfunction


command! -range=% Ditto <line1>,<line2>call Ditto()
command! UnDitto call UnDitto()
command! ToggleDitto call ToggleDitto()

nnoremap <leader>di :call ToggleDitto()<cr>
vnoremap <leader>di :call ToggleDitto()<cr>
nnoremap <leader>dg :call AddGoodWord(expand("<cword>"))<cr>
nnoremap <leader>dw :call AddBadWord(expand("<cword>"))<cr>

