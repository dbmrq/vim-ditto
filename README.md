# ditto.vim
Ditto is a Vim plugin that highlights overused words.

![Ditto](https://cloud.githubusercontent.com/assets/15813674/17240247/86ae98dc-5540-11e6-9f20-f0f6ae8a9697.png)

### Quick start

1. Install Ditto using your favorite plugin manager or copy each file to its corresponding directory under `~/.vim/`.

2. Add this to your `.vimrc`:

    ```vim
    au FileType markdown,text,tex DittoOn " Turn on Ditto's autocmds
    
    nmap <leader>di <Plug>ToggleDitto     " Turn it on and off
    
    nmap =d <Plug>DittoNext               " Jump to the next word
    nmap -d <Plug>DittoPrev               " Jump to the previous word
    nmap +d <Plug>DittoGood               " Ignore the word under the cursor
    nmap _d <Plug>DittoBad                " Stop ignoring the word under the cursor
    nmap ]d <Plug>DittoMore               " Show the next matches
    nmap [d <Plug>DittoLess               " Show the previous matches
    ```

    (Chose the filetypes and mappings you prefer. These are only suggestions.)

3. Stop procrastinating and write (God knows I should).

`DittoOn` starts a set of `autocmd`s that keep the highlighting up to date. If you don't like that idea or run into any problems, keep reading for other options.


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

#### `:DittoOn` and `:DittoOff`

If you just go ahead and call one of the commands above, as soon as you make some changes in your file you'll notice that the highlighting doesn't keep up. That's where `:DittoOn` comes in: besides highlighting the most frequent words, it'll add `autocmd`s to keep the highlighting up to date and highlight new words as soon as you type them.

By default, `:DittoOn` will update the highlighting every time you insert a `<space>` or add/remove a line from your file. There are a few ways to change that, we'll get there soon.

`:DittoOn` will use `:DittoPar` out of the box, so it'll highlight the most frequent words in each paragraph as soon as you type them. We'll see how to change that too in a minute.

So there in the example config where it says `au FileType markdown,text,tex DittoOn`, what it does is run `:DittoOn` on every `markdown`, `text` or `tex` files. Whenever you edit one of those files, Ditto will automatically highlight overused words in each paragraph.

As for `:DittoOff`, you guessed it again, it removes the highlighting and the `autocmd`s (ok, you got me, `:NoDitto` does the exact same thing).

#### `:ToggleDitto`

Last but not least, `:ToggleDitto` does `:DittoOn` when it's off and `:DittoOff` when it's on. :sweat_smile:


## Mappings

#### `<Plug>DittoNext` and `<Plug>DittoPrev`

Map a couple of keys to these plugs and you will be able to jump to the next and previous highlighted words as if they were spelling mistakes or search results (ok, you got me again, they're just search results behind the scenes).

#### `<Plug>DittoGood` and `<Plug>DittoBad`

If you run Ditton on a big file, soon you will find a few words that you think it's ok to repeat (like "suspicious", say it out loud, it just slips through your tongue so smoothly).

Use these plugs to ignore or stop ignoring the word under the cursor.

By default, your good words are added to the first readable directory in your `runtimepath` plus `/Ditto/dittofile.txt`. Sure, you can change that too, we'll get to that, be a little patient.

#### `<Plug>DittoMore` and `<Plug>DittoLess`

When you run any of the Ditto commands you'll see the words you use the most. Use `<Plug>DittoMore` to show the second word you use the most, and then the third, fourth and so on. And then, of course, use`<Plug>DittoLess` to go back.

When two words are used the same amount of time, Ditto will highlight the longest one. If they're the same length it'll just pick one. So it's a good idea to use `<Plug>DittoMore` and `<Plug>DittoLess` and see what the other words are. And yes, you can highlight all the words at the same time, but hang on, we're not there yet.

#### `<Plug>DittoOn`, `<Plug>DittoOff` and `<Plug>ToggleDitto`

These are the same as the eponimous commands. They're here again just because, well, why not.


## Options

#### `g:ditto_min_word_length`

Words shorter than this will never be highlighted.

Default: `4`

#### `g:ditto_min_repetitions`

Words repeated fewer times than this in each scope won't be highlighted.

Default: `3`

#### `g:ditto_hlgroups`

This is a list of the highlight groups Ditto will use. It'll highlight as many different words per scope as there are strings in this list. So if there are 5 highlight groups in this variable, Ditto will highlight the 5 most used words in each sentence, paragraph or file.

Default: `['Error']`

#### `g:ditto_mode`

Use this variable to set the scope used by `:DittoOn`. The current options are:

```vim
let g:ditto_mode = "sentence"
let g:ditto_mode = "paragraph"
let g:ditto_mode = "file"
```

Default: `"paragraph"`

#### `g:ditto_autocmd`

This variable controls how often the highlighting is updated. The current options are:

```vim
let g:ditto_autocmd = "InsertCharPre"
let g:ditto_autocmd = "CursorHold"
let g:ditto_autocmd = "InsertLeave"
```

The highlighting is always updated when the number of lines in the file changes from normal mode. Besides that, if you set this variable to `"InsertChartPre"` (you don't need to, it's the default), the highlighting will be updated every time you insert a `<space>`. If you set it to `"CursorHold"`, the highlighting will be updated every time you spend `updatetime` without typing anything (check `:h updatetime`). If you set this to `"InsertLeave"` the highlighting will only be updated when you leave insert mode.

Default: `"InsertCharPre"`

#### `g:ditto_file`

The name of the file Ditto should use to save its ignored words.

Default: `dittofile.txt`

#### `g:ditto_dir`

The directory where Ditto should save `g:ditto_file`. It can be a comma separated list.

Default: `&l:runtimepath . "/Ditto`


## See also

Check out [Dialect](https://github.com/danielbmarques/vim-dialect), my other plugin.

You may also be interested in [wordy](https://github.com/reedes/vim-wordy) or [Reedes](https://github.com/reedes)' [many other great plugins](https://github.com/reedes?tab=repositories).

Also I'm very susceptible to compliments. Just saying.


----------

And that's it! You'll miss me, I know. But it's for the best.

Here's a song for you, replace "Lido" with "Ditto" in your head:

[![Ditto Shuffle](http://img.youtube.com/vi/HQZBaJAngH8/0.jpg)](http://www.youtube.com/watch?v=HQZBaJAngH8)
