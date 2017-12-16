# ditto.vim

Ditto is a Vim plugin that highlights overused words.

You can check the most frequent words in each sentence, paragraph or file, cycle through them, choose which words to ignore and more. 

![Ditto](https://cloud.githubusercontent.com/assets/15813674/17240247/86ae98dc-5540-11e6-9f20-f0f6ae8a9697.png)

### Quick start

1. Install Ditto using your favorite plugin manager or copy each file to its corresponding directory under `~/.vim/`.

2. Add this to your `.vimrc`:

    ```vim
    " Use autocmds to check your text automatically and keep the highlighting
    " up to date (easier):
    au FileType markdown,text,tex DittoOn  " Turn on Ditto's autocmds
    nmap <leader>di <Plug>ToggleDitto      " Turn Ditto on and off

    " If you don't want the autocmds, you can also use an operator to check
    " specific parts of your text:
    " vmap <leader>d <Plug>Ditto	       " Call Ditto on visual selection
    " nmap <leader>d <Plug>Ditto	       " Call Ditto on operator movement

    nmap =d <Plug>DittoNext                " Jump to the next word
    nmap -d <Plug>DittoPrev                " Jump to the previous word
    nmap +d <Plug>DittoGood                " Ignore the word under the cursor
    nmap _d <Plug>DittoBad                 " Stop ignoring the word under the cursor
    nmap ]d <Plug>DittoMore                " Show the next matches
    nmap [d <Plug>DittoLess                " Show the previous matches
    ```

    (Chose the filetypes and mappings you prefer. These are only suggestions.)

3. Stop procrastinating and write (God knows I should).


## Table of Contents

- [Commands](#commands)
- [Mappings](#mappings)
- [Options](#options)
- [See also](#see-also)


## Commands

#### `:Ditto` and `:NoDitto`

`:Ditto` is the command that actually does all the hard work. It highlights the most frequent word in the current file or in the current visual selection. Most other commands are just wrappers that run `:Ditto` on specific parts of your file and keep it up to date.

`:NoDitto`, you guessed it, takes the highlighting away.

#### `:DittoSent`, `:DittoPar` and `:DittoFile`

These three commands run `:Ditto` on *each sentence*, *each paragraph* or on your *whole file*, respectively.

#### `:DittoOn`, `:DittoOff` and `:DittoUpdate`

If you just go ahead and call one of the commands above, as soon as you make some changes in your file you'll notice that the highlighting doesn't keep up. That's where `:DittoOn` comes in: besides highlighting the most frequent words, it'll add `autocmd`s to keep the highlighting up to date and highlight new words as soon as you type them.

By default, `:DittoOn` will update the highlighting every time you insert a `<space>` or add/remove a line from your file. If you don't like that, you can also run `:DittoUpdate` from your own `autocmd`s:

    au CursorHold,CursorHoldI * DittoUpdate

So there in the example config where it says `au FileType markdown,text,tex DittoOn`, what it does is run `:DittoOn` on every `markdown`, `text` or `tex` files. Whenever you edit one of those files, Ditto will automatically highlight overused words in each paragraph (the default scope can be changed with `g:ditto_mode`).

`:DittoOn` is automatically disabled for readonly files, so you can call it for every text file, like in the example, and Vim's help files won't get all highlighted. If you're editing a readonly file and you still want to turn on Ditto's `autocmd`s, you can use `:DittoOn!`, with the exclamation mark.

As for `:DittoOff`, you guessed it again, it removes the highlighting and the `autocmd`s.

#### `:DittoSentOn`, `:DittoParOn` and `:DittoFileOn`

`:DittoOn` uses the [`g:ditto_mode`](#g:ditto_mode) variable to decide whether to highlight overused words in each sentence, paragraph or file. Whatever you set that variable to, you can also use these commands to turn Ditto on in a different mode in the current buffer.

#### `:ToggleDitto`

Last but not least, `:ToggleDitto` does `:DittoOn` when Ditto's off and `:DittoOff` when it's on. :sweat_smile:


## Mappings

#### `<Plug>Ditto`

Call Ditto for the current selection (in visual mode) or operator movement (in normal mode).

#### `<Plug>DittoNext` and `<Plug>DittoPrev`

Map a couple of keys to these plugs and you will be able to jump to the next and previous highlighted words as if they were spelling mistakes or search results.

#### `<Plug>DittoGood` and `<Plug>DittoBad`

If you run DittoOn on a big file, soon you will find a few words that you think it's ok to repeat.

Use these plugs to ignore or stop ignoring the word under the cursor.

By default, your good words are added to the first readable directory in your `runtimepath` plus `/Ditto/dittofile.txt`.

#### `<Plug>DittoMore` and `<Plug>DittoLess`

When you run any of the Ditto commands you'll see the words you use the most. Use `<Plug>DittoMore` to show the second word you use the most, and then the third, fourth and so on. And then, of course, use`<Plug>DittoLess` to go back.

When two words are used equally as often, Ditto will highlight the longest one. If they're the same length it'll just pick one. So it's a good idea to use `<Plug>DittoMore` and `<Plug>DittoLess` and see what the other words are.

#### `<Plug>DittoOn`, `<Plug>DittoOff`, `<Plug>DittoUpdate` and `<Plug>ToggleDitto`

These are the same as the eponymous commands.


## Options

#### `g:ditto_min_word_length`

Words shorter than this will never be highlighted.

Default: `4`

#### `g:ditto_min_repetitions`

Words repeated fewer times than this in each scope won't be highlighted.

Default: `3`

#### `g:ditto_hlgroups`

This is a list of the highlight groups Ditto will use. It'll highlight as many different words per scope as there are strings in this list. So if there are 5 highlight groups in this variable, Ditto will highlight the 5 most used words in each sentence, paragraph or file.

Default: `['SpellRare']`

#### `g:ditto_mode`

Use this variable to set the scope used by `:DittoOn`. The current options are:

```vim
let g:ditto_mode = "sentence"
let g:ditto_mode = "paragraph"
let g:ditto_mode = "file"
```

Default: `"paragraph"`

#### `g:ditto_file`

The name of the file Ditto should use to save its ignored words.

Default: `dittofile.txt`

#### `g:ditto_dir`

The directory where Ditto should save `g:ditto_file`. It can be a comma separated list.

Default: `&l:runtimepath . "/Ditto"`


## See also

You may also be interested in my other plugins:

- [Dialect: project specific spellfiles](https://github.com/dbmrq/vim-dialect) :speech_balloon:
- [Redacted: the best way to ████ the ████](https://github.com/dbmrq/vim-redacted) :no_mouth:
- [Chalk: better fold markers](https://github.com/dbmrq/vim-chalk) :pencil2:
- [Howdy: a tiny MRU start screen for Vim](https://github.com/dbmrq/vim-howdy) :wave:


Also check out [wordy](https://github.com/reedes/vim-wordy) and [Reedes](https://github.com/reedes)' [many other great plugins](https://github.com/reedes?tab=repositories).

Also I'm very susceptible to compliments. Just saying.


----------

And that's it!

Here's a song for you, replace "Lido" with "Ditto" in your head:

[![Ditto Shuffle](http://img.youtube.com/vi/HQZBaJAngH8/0.jpg)](http://www.youtube.com/watch?v=HQZBaJAngH8)

