" Self-contained test runner for vim-ditto.
"
" Run with:
"   vim -Nu NONE -n -es -S test/run.vim
"   nvim --headless -u NONE -n -S test/run.vim

set nocompatible
set nomore
set noignorecase

let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
let s:tmp = tempname() . '-ditto'
call mkdir(s:tmp, 'p')

let &runtimepath = s:root . ',' . &runtimepath
let g:ditto_dir = s:tmp
let g:ditto_file = 'dittofile.txt'

runtime plugin/ditto.vim

let s:tests = []

function! s:test(name, Func) abort
  call add(s:tests, [a:name, a:Func])
endfunction

function! s:fail(message) abort
  throw 'FAIL: ' . a:message
endfunction

function! s:assert(condition, message) abort
  if !a:condition
    call s:fail(a:message)
  endif
endfunction

function! s:assert_equal(expected, actual, message) abort
  if a:expected != a:actual
    call s:fail(a:message . ' (expected ' . string(a:expected) .
          \ ', got ' . string(a:actual) . ')')
  endif
endfunction

function! s:patterns() abort
  return map(getmatches(), 'v:val.pattern')
endfunction

function! s:autocmdCount(event) abort
  let lines = split(execute('autocmd ditto ' . a:event . ' <buffer>'), "\n")
  return len(filter(lines, 'v:val =~# "call "'))
endfunction

function! s:reset() abort
  silent! call ditto#dittoOff()
  silent! setlocal noreadonly
  silent! enew!
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal filetype=text

  let g:ditto_min_word_length = 4
  let g:ditto_min_repetitions = 3
  let g:ditto_hlgroups = ['SpellRare']
  let g:ditto_mode = 'paragraph'
  let g:ditto_file = 'dittofile.txt'
  let g:ditto_dir = s:tmp

  call writefile([], s:tmp . '/dittofile.txt')
endfunction

function! s:buffer(lines) abort
  call s:reset()
  call setline(1, a:lines)
  call cursor(1, 1)
endfunction


function! s:test_options_defaults() abort
  call s:reset()
  call s:assert_equal(4, g:ditto_min_word_length, 'default word length')
  call s:assert_equal(3, g:ditto_min_repetitions, 'default repetitions')
  call s:assert_equal(['SpellRare'], g:ditto_hlgroups, 'default hlgroups')
  call s:assert_equal('paragraph', g:ditto_mode, 'default mode')
  call s:assert_equal('dittofile.txt', g:ditto_file, 'default file')
endfunction

function! s:test_highlights_repeated_word() abort
  call s:buffer(['alpha alpha alpha beta beta'])
  call ditto#dittoFile(1)

  let patterns = s:patterns()
  call s:assert_equal(1, len(patterns), 'one highlight group -> one match')
  call s:assert(patterns[0] =~# '\\<alpha\\>', 'most repeated word is highlighted')
  call ditto#dittoOff()
endfunction

function! s:test_commands_do_not_duplicate_matches() abort
  call s:buffer(['alpha alpha alpha'])
  call ditto#dittoFile(1)
  call ditto#dittoFile(1)
  call ditto#dittoFile(1)

  call s:assert_equal(1, len(getmatches()), 're-running a command replaces matches')
  call ditto#dittoOff()
endfunction

function! s:test_file_mode_is_selected() abort
  call s:buffer(['alpha alpha alpha'])
  let g:ditto_mode = 'file'

  call ditto#dittoOn()
  call s:assert_equal('file', get(b:, 'ditto_mode', ''), 'file mode is selected')

  call ditto#dittoOn()
  call s:assert_equal('file', get(b:, 'ditto_mode', ''), 'file mode survives DittoOn again')
  call ditto#dittoOff()
endfunction

function! s:test_autocmds_are_added_once_and_removed() abort
  call s:buffer(['alpha alpha alpha'])

  call ditto#dittoParOn()
  call ditto#dittoParOn()
  call ditto#dittoParOn()

  call s:assert_equal(1, s:autocmdCount('TextChanged'), 'TextChanged added once')
  call s:assert_equal(1, s:autocmdCount('TextChangedI'), 'TextChangedI added once')
  call s:assert_equal(1, s:autocmdCount('WinEnter'), 'WinEnter added once')

  call ditto#dittoOff()
  call s:assert_equal(0, s:autocmdCount('TextChanged'), 'TextChanged removed')
  call s:assert_equal(0, s:autocmdCount('TextChangedI'), 'TextChangedI removed')
  call s:assert_equal(0, s:autocmdCount('WinEnter'), 'WinEnter removed')
endfunction

function! s:test_plug_ditto_off() abort
  call s:buffer(['alpha alpha alpha'])
  call ditto#dittoParOn()
  call s:assert_equal('paragraph', get(b:, 'ditto_mode', ''), 'Ditto is on')

  execute "normal \<Plug>DittoOff"

  call s:assert_equal('', get(b:, 'ditto_mode', ''), '<Plug>DittoOff turns Ditto off')
  call s:assert_equal(0, len(getmatches()), '<Plug>DittoOff clears matches')
  call s:assert_equal(0, s:autocmdCount('TextChanged'), '<Plug>DittoOff removes autocmds')
endfunction

function! s:test_good_words_are_exact_and_case_insensitive() abort
  call s:buffer(['the theme there the theme there the theme there'])
  call writefile(['the'], s:tmp . '/dittofile.txt')
  let g:ditto_min_word_length = 3
  let g:ditto_hlgroups = ['SpellRare', 'SpellBad']

  call ditto#dittoFile(1)
  let joined = join(s:patterns(), ' ')
  call s:assert(joined !~# '\\<the\\>', 'good word is not highlighted')
  call s:assert(joined =~# '\\<theme\\>', 'longer word sharing a prefix is highlighted')
  call s:assert(joined =~# '\\<there\\>', 'another longer word sharing a prefix is highlighted')

  " A longer good word must not swallow a shorter word that is its prefix.
  call s:buffer(['the the the'])
  call writefile(['theme'], s:tmp . '/dittofile.txt')
  let g:ditto_min_word_length = 3
  call ditto#dittoFile(1)
  call s:assert(join(s:patterns(), ' ') =~# '\\<the\\>', 'short word is not swallowed by a longer good word')

  " Adding a capitalised word should ignore its lowercase occurrences.
  call writefile([], s:tmp . '/dittofile.txt')
  call s:buffer(['the the the'])
  let g:ditto_min_word_length = 3
  silent call ditto#addGoodWord('The')
  call s:assert_equal(['the'], readfile(s:tmp . '/dittofile.txt'), 'good words are saved lowercase')
  call ditto#dittoFile(1)
  call s:assert(join(s:patterns(), ' ') !~# '\\<the\\>', 'good words are case-insensitive')
endfunction

function! s:test_add_good_word_on_fresh_buffer() abort
  call s:buffer([''])
  silent call ditto#addGoodWord('foo')
  call s:assert_equal(['foo'], readfile(s:tmp . '/dittofile.txt'), 'good word was saved')
endfunction

function! s:test_add_bad_word() abort
  call s:buffer([''])
  call writefile(['foo', 'bar'], s:tmp . '/dittofile.txt')

  silent call ditto#addBadWord('FOO')
  call s:assert_equal(['bar'], readfile(s:tmp . '/dittofile.txt'), 'bad word was removed case-insensitively')
  silent call ditto#addBadWord('missing')
  call s:assert_equal(['bar'], readfile(s:tmp . '/dittofile.txt'), 'missing bad word is harmless')
endfunction

function! s:test_sentence_scope_does_not_move_cursor() abort
  call s:buffer(['alpha alpha alpha. beta beta beta.'])
  let view = winsaveview()

  call ditto#dittoSent(1)

  call s:assert_equal(view, winsaveview(), 'sentence scope leaves cursor and view alone')
  call s:assert(!empty(getmatches()), 'sentence scope highlights words')
  call ditto#dittoOff()
endfunction

function! s:test_paragraph_scope_highlights_each_paragraph() abort
  call s:buffer(['alpha alpha alpha.', '', 'beta beta beta.'])
  let view = winsaveview()

  call ditto#dittoPar(1)

  call s:assert_equal(view, winsaveview(), 'paragraph scope leaves cursor and view alone')
  call s:assert_equal(2, len(getmatches()), 'each paragraph gets its own match')
  call ditto#dittoOff()
endfunction

function! s:test_update_clears_overlapping_matches() abort
  call s:buffer([
        \ 'alpha alpha alpha',
        \ 'alpha alpha alpha',
        \ 'alpha alpha alpha',
        \ 'alpha alpha alpha',
        \ 'alpha alpha alpha',
        \ '',
        \ 'beta beta beta',
        \ 'beta beta beta',
        \ 'beta beta beta',
        \ 'beta beta beta',
        \ ])
  call ditto#dittoParOn()
  call s:assert_equal(2, len(getmatches()), 'both paragraphs highlighted initially')

  execute '3,4call ditto#dittoUpdate()'

  let patterns = s:patterns()
  call s:assert_equal(2, len(patterns), 'overlapping update does not leave stale matches')
  call s:assert(join(patterns, ' ') !~# '\\%<6l', 'old paragraph-wide match was removed')
  call ditto#dittoOff()
endfunction

function! s:test_autocmd_refreshes_highlights() abort
  call s:buffer(['alpha alpha alpha'])
  let g:ditto_mode = 'paragraph'
  call ditto#dittoOn()

  call setline(1, ['alpha alpha alpha beta beta beta beta'])
  doautocmd TextChanged

  call s:assert(join(s:patterns(), ' ') =~# '\\<beta\\>', 'TextChanged refreshes the current scope')
  call ditto#dittoOff()
endfunction

function! s:test_ditto_command_range() abort
  call s:buffer(['alpha alpha alpha', '', 'beta beta beta'])

  execute '1,1Ditto'
  let joined = join(s:patterns(), ' ')
  call s:assert(joined =~# '\\<alpha\\>', 'range command highlights the selected range')
  call s:assert(joined !~# '\\<beta\\>', 'range command leaves other ranges alone')

  execute '3,3Ditto'
  let joined = join(s:patterns(), ' ')
  call s:assert(joined =~# '\\<alpha\\>', 'existing match is kept')
  call s:assert(joined =~# '\\<beta\\>', 'new range is highlighted')
  call ditto#dittoOff()
endfunction

function! s:test_operator() abort
  call s:buffer(['alpha alpha alpha beta beta beta'])
  call setpos("'<", [0, 1, 1, 0])
  call setpos("'>", [0, 1, 10, 0])

  try
    call ditto#dittoOp('char', 1)
  catch
    call s:fail('operator failed: ' . v:exception)
  endtry

  call s:assert(!empty(getmatches()), 'operator highlights the selection')
  call ditto#dittoOff()
endfunction

function! s:test_more_and_less() abort
  call s:buffer(['alpha alpha alpha beta beta beta gamma gamma gamma'])
  let g:ditto_hlgroups = ['SpellRare', 'SpellBad', 'Title']

  call ditto#dittoFile(1)
  call s:assert_equal(3, len(getmatches()), 'all highlight groups are used initially')

  call ditto#dittoMore()
  call s:assert_equal(1, len(getmatches()), 'more shows one word at a time')

  call ditto#dittoLess()
  call s:assert_equal(3, len(getmatches()), 'less goes back to all words')
  call ditto#dittoOff()
endfunction

function! s:test_navigation_search() abort
  call s:buffer(['alpha alpha alpha beta beta beta'])
  call ditto#dittoFile(1)
  call cursor(1, col([1, '$']) - 1)

  try
    call ditto#dittoSearch('/')
  catch
    call s:fail('search failed: ' . v:exception)
  endtry

  call s:assert(line('.') == 1, 'search stays in the highlighted line')
  call ditto#dittoOff()
endfunction

function! s:test_toggle() abort
  call s:buffer(['alpha alpha alpha'])
  let g:ditto_mode = 'paragraph'

  call ditto#toggleDitto()
  call s:assert_equal('paragraph', get(b:, 'ditto_mode', ''), 'toggle turns Ditto on')
  call s:assert_equal(1, s:autocmdCount('TextChanged'), 'toggle on adds autocmds')

  call ditto#toggleDitto()
  call s:assert_equal('', get(b:, 'ditto_mode', ''), 'toggle turns Ditto off')
  call s:assert_equal(0, s:autocmdCount('TextChanged'), 'toggle off removes autocmds')
endfunction

function! s:test_readonly_guard() abort
  call s:buffer(['alpha alpha alpha'])
  setlocal readonly

  execute 'DittoOn'
  call s:assert_equal('', get(b:, 'ditto_mode', ''), 'readonly buffer is not enabled')

  execute 'DittoOn!'
  call s:assert_equal('paragraph', get(b:, 'ditto_mode', ''), 'DittoOn! overrides readonly')
  call ditto#dittoOff()
endfunction

function! s:test_adding_good_word_refreshes_highlights() abort
  call s:buffer(['alpha alpha alpha beta beta beta'])
  let g:ditto_mode = 'file'
  let g:ditto_hlgroups = ['SpellRare', 'SpellBad']
  call ditto#dittoOn()

  call s:assert(join(s:patterns(), ' ') =~# '\\<alpha\\>', 'alpha is highlighted initially')
  silent call ditto#addGoodWord('alpha')
  let joined = join(s:patterns(), ' ')
  call s:assert(joined !~# '\\<alpha\\>', 'alpha is no longer highlighted')
  call s:assert(joined =~# '\\<beta\\>', 'beta is still highlighted')

  silent call ditto#addBadWord('alpha')
  call s:assert(join(s:patterns(), ' ') =~# '\\<alpha\\>', 'alpha is highlighted again')
  call ditto#dittoOff()
endfunction


call s:test('options defaults', function('s:test_options_defaults'))
call s:test('highlights repeated word', function('s:test_highlights_repeated_word'))
call s:test('commands do not duplicate matches', function('s:test_commands_do_not_duplicate_matches'))
call s:test('file mode is selected', function('s:test_file_mode_is_selected'))
call s:test('autocmds added once and removed', function('s:test_autocmds_are_added_once_and_removed'))
call s:test('<Plug>DittoOff works', function('s:test_plug_ditto_off'))
call s:test('good words exact and case-insensitive', function('s:test_good_words_are_exact_and_case_insensitive'))
call s:test('add good word on fresh buffer', function('s:test_add_good_word_on_fresh_buffer'))
call s:test('add bad word', function('s:test_add_bad_word'))
call s:test('sentence scope keeps cursor', function('s:test_sentence_scope_does_not_move_cursor'))
call s:test('paragraph scope per paragraph', function('s:test_paragraph_scope_highlights_each_paragraph'))
call s:test('update clears overlapping matches', function('s:test_update_clears_overlapping_matches'))
call s:test('autocmd refreshes highlights', function('s:test_autocmd_refreshes_highlights'))
call s:test('Ditto command range', function('s:test_ditto_command_range'))
call s:test('operator', function('s:test_operator'))
call s:test('more and less', function('s:test_more_and_less'))
call s:test('navigation search', function('s:test_navigation_search'))
call s:test('toggle', function('s:test_toggle'))
call s:test('readonly guard', function('s:test_readonly_guard'))
call s:test('good word refreshes highlights', function('s:test_adding_good_word_refreshes_highlights'))

let s:failures = []
for [s:name, s:Func] in s:tests
  try
    call s:Func()
  catch
    call add(s:failures, s:name . ': ' . substitute(v:exception, '^FAIL: ', '', ''))
  endtry
endfor

if empty(s:failures)
  call writefile(['All ' . len(s:tests) . ' tests passed.'], '/dev/stdout')
  call delete(s:tmp, 'rf')
  qa!
else
  call writefile(['FAILED ' . len(s:failures) . ' of ' . len(s:tests) . ' tests:'] +
        \ map(s:failures, '"  - " . v:val'), '/dev/stdout')
  cquit
endif
