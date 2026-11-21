" ditto.vim - Stop repeating yourself
" Author:   Daniel B. Marques
" Version:  0.4.0
" License:  Same as Vim

scriptencoding utf-8

if exists('g:autoloaded_ditto') || &cp
  finish
endif
let g:autoloaded_ditto = 1


" Small helpers {{{1

function! s:withSlash(dir) abort
  return substitute(a:dir, '/\+$', '', '') . '/'
endfunction

function! s:mode() abort
  return get(b:, 'ditto_mode', '')
endfunction

function! s:isOn() abort
  return s:mode() !=# ''
endfunction

function! s:matchCount() abort
  return get(b:, 'ditto_match_count', 0)
endfunction

" A range is used when it is given explicitly.  Otherwise the whole file is
" used, which matches the historical behaviour of the scope commands.
function! s:effectiveRange(first, last) abort
  if a:last <= a:first
    return [1, line('$')]
  endif
  return [a:first, a:last]
endfunction

function! s:sentenceEndPattern() abort
  return '\v[.!?][])"''>]*(\s|$)'
endfunction

function! s:sentenceEndsLine(lnum) abort
  return getline(a:lnum) =~# '\v[.!?][])"''>]*\s*$'
endfunction


" Good words file {{{1

function! s:goodWordsDir() abort
  let candidates = []
  if exists('g:ditto_dir')
    let candidates += split(g:ditto_dir, ',')
  endif
  for dir in split(&runtimepath, ',')
    call add(candidates, dir . '/Ditto')
  endfor

  for candidate in candidates
    let dir = expand(candidate)
    if !isdirectory(dir)
      try
        call mkdir(dir, 'p')
      catch
        continue
      endtry
    endif
    if isdirectory(dir) && filewritable(dir) > 0
      return s:withSlash(dir)
    endif
  endfor

  throw 'Ditto: could not find a writable directory for its good words'
endfunction

function! s:goodWordsFile() abort
  return s:goodWordsDir() . get(g:, 'ditto_file', 'dittofile.txt')
endfunction

function! s:readGoodWords() abort
  try
    let file = s:goodWordsFile()
    if !filereadable(file)
      return []
    endif
    return filter(readfile(file), 'v:val !=# ""')
  catch
    return []
  endtry
endfunction

function! s:goodWordSet() abort
  let words = {}
  for word in s:readGoodWords()
    let words[tolower(word)] = 1
  endfor
  return words
endfunction

function! s:writeGoodWords(words) abort
  let file = s:goodWordsFile()
  let error = writefile(a:words, file)
  if error != 0
    throw 'Ditto: could not write to ' . file
  endif
  return file
endfunction


" Word counting {{{1

function! s:wordOrder(first, second) abort
  if a:first[1] != a:second[1]
    return a:first[1] > a:second[1] ? -1 : 1
  endif

  let first_len = strchars(a:first[0])
  let second_len = strchars(a:second[0])
  if first_len != second_len
    return first_len > second_len ? -1 : 1
  endif

  return 0
endfunction

function! s:sortWords(counted) abort
  return sort(items(a:counted), 's:wordOrder')
endfunction

function! s:getWords(first, last) abort
  let text = tolower(join(getline(a:first, a:last), "\n"))
  let words = split(text, '[[:blank:][:punct:]]\+')
  let good_words = s:goodWordSet()
  let counted = {}
  let min_length = get(g:, 'ditto_min_word_length', 4)
  let min_repetitions = get(g:, 'ditto_min_repetitions', 3)

  for word in words
    if strchars(word) >= min_length && !has_key(good_words, word)
      let counted[word] = get(counted, word, 0) + 1
    endif
  endfor

  return s:sortWords(filter(counted, 'v:val >= ' . min_repetitions))
endfunction


" Highlighting {{{1

function! s:clearMatches(...) abort
  let all = a:0 == 0
  let first = all ? 0 : a:1
  let last = all ? line('$') : a:2

  let kept_ids = []
  for match in get(w:, 'ditto_matched_ids', [])
    if all || (match[0] <= last && match[1] >= first)
      silent! call matchdelete(match[2])
    else
      call add(kept_ids, match)
    endif
  endfor
  let w:ditto_matched_ids = kept_ids

  let kept_words = []
  for match in get(b:, 'ditto_matched_words', [])
    if all || (match[0] <= last && match[1] >= first)
      " Drop it.
    else
      call add(kept_words, match)
    endif
  endfor
  let b:ditto_matched_words = kept_words
endfunction

function! s:addMatch(first, last, word, group) abort
  let pattern = '\c\<' . escape(a:word, '\.*$^~[]') . '\>' .
        \ '\%>' . (a:first - 1) . 'l\%<' . (a:last + 1) . 'l'

  try
    let id = matchadd(a:group, pattern)
  catch
    try
      let id = matchadd('SpellRare', pattern)
    catch
      return
    endtry
  endtry

  if !exists('w:ditto_matched_ids')
    let w:ditto_matched_ids = []
  endif
  if !exists('b:ditto_matched_words')
    let b:ditto_matched_words = []
  endif
  call add(w:ditto_matched_ids, [a:first, a:last, id])
  call add(b:ditto_matched_words, [a:first, a:last, a:word])
endfunction

function! s:addMatches(first, last) abort
  let words = s:getWords(a:first, a:last)
  if empty(words)
    return 0
  endif

  let groups = get(g:, 'ditto_hlgroups', ['SpellRare'])
  if empty(groups)
    let groups = ['SpellRare']
  endif

  let match_count = s:matchCount()
  if match_count != 0
    let index = match_count % len(words)
    if index < 0
      let index += len(words)
    endif
    call s:addMatch(a:first, a:last, words[index][0], groups[0])
  else
    let i = 0
    while i < len(words) && i < len(groups)
      call s:addMatch(a:first, a:last, words[i][0], groups[i])
      let i += 1
    endwhile
  endif

  return 1
endfunction

function! s:highlightFile() abort
  let first = 1
  let last = line('$')
  call s:clearMatches(first, last)
  call s:addMatches(first, last)
endfunction

function! s:mergeRanges(ranges) abort
  let merged = []
  for range in a:ranges
    if !empty(merged) && range[0] <= merged[-1][1]
      let merged[-1][1] = max([merged[-1][1], range[1]])
    else
      call add(merged, [range[0], range[1]])
    endif
  endfor
  return merged
endfunction

function! s:sentenceRanges(first, last) abort
  let ranges = []
  let pattern = s:sentenceEndPattern()
  let sentence_start = a:first
  let lnum = a:first

  while lnum <= a:last
    let text = getline(lnum)
    let start_idx = 0
    let found = 0
    let next_start = sentence_start

    while 1
      let found_match = matchstrpos(text, pattern, start_idx)
      if found_match[1] < 0
        break
      endif

      let found = 1
      let rest = found_match[2] < len(text) ? text[found_match[2]:] : ''
      let next_start = rest =~# '\S' ? lnum : lnum + 1
      let start_idx = found_match[2]
    endwhile

    if found
      call add(ranges, [sentence_start, lnum])
      let sentence_start = next_start
    endif

    let lnum += 1
  endwhile

  if sentence_start <= a:last
    call add(ranges, [sentence_start, a:last])
  endif

  return s:mergeRanges(ranges)
endfunction

function! s:paragraphRanges(first, last) abort
  let ranges = []
  let paragraph_start = a:first
  let lnum = a:first

  while lnum <= a:last
    if getline(lnum) =~# '^\s*$'
      if paragraph_start < lnum
        call add(ranges, [paragraph_start, lnum - 1])
      endif
      let paragraph_start = lnum + 1
    endif
    let lnum += 1
  endwhile

  if paragraph_start <= a:last
    call add(ranges, [paragraph_start, a:last])
  endif

  return ranges
endfunction

function! s:highlightRanges(ranges) abort
  for range in a:ranges
    call s:clearMatches(range[0], range[1])
    call s:addMatches(range[0], range[1])
  endfor
endfunction

function! s:highlightSentences(first, last) abort
  call s:highlightRanges(s:sentenceRanges(a:first, a:last))
endfunction

function! s:highlightParagraphs(first, last) abort
  call s:highlightRanges(s:paragraphRanges(a:first, a:last))
endfunction

function! s:highlightMode(first, last) abort
  let mode = s:mode()
  if mode ==# 'file'
    call s:highlightFile()
  elseif mode ==# 'sentence'
    call s:highlightSentences(a:first, a:last)
  else
    call s:highlightParagraphs(a:first, a:last)
  endif
endfunction

function! s:paragraphAtCursor() abort
  let first = line('.')
  let last = line('.')

  while first > 1 && getline(first - 1) !~# '^\s*$'
    let first -= 1
  endwhile
  while last < line('$') && getline(last + 1) !~# '^\s*$'
    let last += 1
  endwhile

  return [first, last]
endfunction

function! s:sentenceAtCursor() abort
  let first = line('.')
  let last = line('.')

  while first > 1 && !s:sentenceEndsLine(first - 1)
    let first -= 1
  endwhile
  while last < line('$') && !s:sentenceEndsLine(last)
    let last += 1
  endwhile

  return [first, last]
endfunction

function! s:currentScopeRange() abort
  if s:mode() ==# 'file'
    return [1, line('$')]
  elseif s:mode() ==# 'sentence'
    return s:sentenceAtCursor()
  endif
  return s:paragraphAtCursor()
endfunction


" Public highlighting commands {{{1

function! ditto#ditto(...) range abort
  if a:0 > 0
    let b:ditto_match_count = 0
  endif
  let b:ditto_last_range = a:firstline . ',' . a:lastline
  call s:clearMatches(a:firstline, a:lastline)
  return s:addMatches(a:firstline, a:lastline)
endfunction

function! ditto#dittoFile(...) abort
  if a:0 > 0
    let b:ditto_match_count = 0
  endif
  let b:ditto_last_range = '1,' . line('$')
  call s:highlightFile()
endfunction

function! ditto#dittoSent(...) range abort
  if a:0 > 0
    let b:ditto_match_count = 0
  endif
  let range = s:effectiveRange(a:firstline, a:lastline)
  let b:ditto_last_range = range[0] . ',' . range[1]
  call s:highlightSentences(range[0], range[1])
endfunction

function! ditto#dittoPar(...) range abort
  if a:0 > 0
    let b:ditto_match_count = 0
  endif
  let range = s:effectiveRange(a:firstline, a:lastline)
  let b:ditto_last_range = range[0] . ',' . range[1]
  call s:highlightParagraphs(range[0], range[1])
endfunction

function! ditto#dittoMore() abort
  if s:isOn()
    if !empty(get(w:, 'ditto_matched_ids', []))
      let b:ditto_match_count = s:matchCount() + 1
    endif
    call ditto#dittoUpdate()
  elseif get(b:, 'ditto_last_range', '') !=# ''
    let b:ditto_match_count = s:matchCount() + 1
    execute b:ditto_last_range . 'call ditto#ditto()'
  else
    call ditto#ditto()
  endif
endfunction

function! ditto#dittoLess() abort
  if s:isOn()
    if !empty(get(w:, 'ditto_matched_ids', []))
      let b:ditto_match_count = s:matchCount() - 1
    endif
    call ditto#dittoUpdate()
  elseif get(b:, 'ditto_last_range', '') !=# ''
    let b:ditto_match_count = s:matchCount() - 1
    execute b:ditto_last_range . 'call ditto#ditto()'
  else
    call ditto#ditto()
  endif
endfunction


" Turning Ditto on and off {{{1

augroup ditto
  autocmd!
augroup END

augroup ditto_operator
  autocmd!
augroup END

function! s:addAutoCmds() abort
  let b:ditto_last_line = line('$')
  augroup ditto
    autocmd! * <buffer>
    autocmd TextChanged <buffer> call s:onTextChanged()
    autocmd TextChangedI <buffer> call s:onTextChangedI()
    autocmd WinEnter <buffer> call ditto#dittoUpdate()
  augroup END
endfunction

function! s:removeAutoCmds() abort
  augroup ditto
    autocmd! * <buffer>
  augroup END
endfunction

function! s:removeOperatorAutoCmds() abort
  augroup ditto_operator
    autocmd! * <buffer>
  augroup END
endfunction

function! s:clearAll() abort
  call s:clearMatches()
  let b:ditto_mode = ''
  let b:ditto_last_range = ''
  let b:ditto_match_count = 0
endfunction

function! ditto#dittoOff() abort
  call s:removeAutoCmds()
  call s:removeOperatorAutoCmds()
  call s:clearAll()
endfunction

function! ditto#noDitto() abort
  call ditto#dittoOff()
endfunction

function! s:turnOn(mode) abort
  let b:ditto_mode = a:mode
  let b:ditto_match_count = 0
  call s:addAutoCmds()
  call ditto#dittoUpdate()
endfunction

function! ditto#dittoSentOn() abort
  call s:turnOn('sentence')
endfunction

function! ditto#dittoParOn() abort
  call s:turnOn('paragraph')
endfunction

function! ditto#dittoFileOn() abort
  call s:turnOn('file')
endfunction

function! ditto#dittoOn(...) abort
  let bang = a:0 > 0 ? a:1 : 0
  if &l:readonly && !bang
    return
  endif

  if s:isOn()
    call ditto#dittoUpdate()
    return
  endif

  let mode = tolower(get(g:, 'ditto_mode', 'paragraph'))
  if mode =~# 'file'
    call ditto#dittoFileOn()
  elseif mode =~# 'sent'
    call ditto#dittoSentOn()
  else
    call ditto#dittoParOn()
  endif
endfunction

function! ditto#toggleDitto() abort
  if s:isOn()
    call ditto#dittoOff()
  else
    call ditto#dittoOn()
  endif
endfunction

function! ditto#dittoUpdate() range abort
  if !s:isOn()
    return
  endif

  let range = s:effectiveRange(a:firstline, a:lastline)
  call s:clearMatches(range[0], range[1])
  call s:highlightMode(range[0], range[1])
endfunction


" Autocmd handlers {{{1

function! s:onTextChanged() abort
  if !s:isOn()
    return
  endif

  let winview = winsaveview()
  if line('$') != get(b:, 'ditto_last_line', line('$'))
    call ditto#dittoUpdate()
  else
    let range = s:currentScopeRange()
    call s:clearMatches(range[0], range[1])
    call s:highlightMode(range[0], range[1])
  endif
  let b:ditto_last_line = line('$')
  call winrestview(winview)
endfunction

function! s:onTextChangedI() abort
  if !s:isOn()
    return
  endif

  let winview = winsaveview()
  let last_line = get(b:, 'ditto_last_line', line('$'))
  let added_line = line('$') != last_line &&
        \ len(filter(getline(line('.') + 1, '$'), 'v:val !=# ""')) > 0

  if added_line
    call ditto#dittoUpdate()
  else
    let before = col('.') > 1 ? getline('.')[col('.') - 2] : ''
    if before =~# '[ .!?]'
      let range = s:currentScopeRange()
      call s:clearMatches(range[0], range[1])
      call s:highlightMode(range[0], range[1])
    endif
  endif

  let b:ditto_last_line = line('$')
  call winrestview(winview)
endfunction


" Good and bad words {{{1

function! s:refresh() abort
  if s:isOn()
    call ditto#dittoUpdate()
  endif
endfunction

function! ditto#addGoodWord(word) abort
  let word = tolower(a:word)
  if word ==# ''
    return
  endif

  let words = s:readGoodWords()
  if index(map(copy(words), 'tolower(v:val)'), word) >= 0
    echo 'Ditto: "' . word . '" is already a good word'
    return
  endif

  call add(words, word)
  try
    let file = s:writeGoodWords(words)
  catch
    echoerr v:exception
    return
  endtry

  let winview = winsaveview()
  call s:refresh()
  call winrestview(winview)
  redraw
  echo 'Ditto: "' . word . '" added to ' . file
endfunction

function! ditto#addBadWord(word) abort
  let word = tolower(a:word)
  let words = s:readGoodWords()
  let found = 0
  let i = len(words) - 1

  while i >= 0
    if tolower(words[i]) ==# word
      call remove(words, i)
      let found = 1
    endif
    let i -= 1
  endwhile

  if !found
    echo 'Ditto: "' . word . '" is not a good word'
    return
  endif

  try
    let file = s:writeGoodWords(words)
  catch
    echoerr v:exception
    return
  endtry

  let winview = winsaveview()
  call s:refresh()
  call winrestview(winview)
  redraw
  echo 'Ditto: "' . word . '" removed from ' . file
endfunction


" Searching matches {{{1

function! s:makeWordPattern(index) abort
  let word = b:ditto_matched_words[a:index]
  return '\%>' . (word[0] - 1) . 'l\%<' . (word[1] + 1) . 'l' .
        \ '\<' . escape(word[2], '\.*$^~[]') . '\>'
endfunction

function! ditto#dittoSearch(cmd) abort
  let words = get(b:, 'ditto_matched_words', [])
  if empty(words)
    return
  endif

  let parts = []
  for i in range(len(words))
    call add(parts, s:makeWordPattern(i))
  endfor
  let pattern = len(parts) == 1 ? parts[0] : '\(' . join(parts, '\|') . '\)'

  silent keepp execute 'normal! ' . a:cmd . '\c' . pattern . "\<cr>"
  redraw
endfunction


" Operator {{{1

function! s:operatorChanged() abort
  call s:clearAll()
  call s:removeOperatorAutoCmds()
endfunction

function! ditto#dittoOp(type, ...) abort
  call s:clearAll()
  if a:0
    silent execute "normal! '<v'>:call ditto#ditto(1)\<cr>"
  elseif a:type ==# 'line'
    silent execute "normal! `[V`]:call ditto#ditto(1)\<cr>"
  else
    silent execute "normal! `[v`]:call ditto#ditto(1)\<cr>"
  endif

  augroup ditto_operator
    autocmd! * <buffer>
    autocmd TextChanged,TextChangedI <buffer> call s:operatorChanged()
  augroup END
endfunction

" }}}1
