# vim-TabJumper

Vim plugin to show and jump tabs smartly.

tab jump  
<img src=images/tabjumper.gif width="70%">

tab move  
<img src=images/tabjumper2.gif width="70%">

## Usage
The following command shows the list of tabs.
```vim
TabJump
```
In this window,
- select: j/k/↑/↓
- go to the first line: g
- go to the last line: G
- jump: Enter
- search: /
- repeat the search: n/N
- tab/win mode: h/l/←/→
- preview: p
- tab move: +/-
- quit: q/\<esc>
- show help: ?

## Requirements

## Installation

For [vim-plug](https://github.com/junegunn/vim-plug) plugin manager:

```vim
Plug 'MeF0504/vim-TabJumper'
```

## Options

Variables
- `g:tabjumper_height` (number)  
    the height of TabJumper window.  
    default: 10
- `g:tabjumper_preview_enable` (string)  
    set the preview mode.  
    If this option is set to 'auto', a preview is shown automatically.  
    If this option is set to 'manual', a preview is shown when you put 'p' key.  
    Otherwise, a preview is off.
    default: 'auto'
- `g:tabjumper_preview_time` (number)  
    the waiting time until the preview is shown.
    The unit is milliseconds.  
    This option is effective when `g:tabjumper_preview_enable = 'auto'`.
- `g:tabjumper_preview_height` (number)  
    the height of the preview window.  
    default: 40
- `g:tabjumper_preview_width` (number)  
    the width of the preview window.  
    default: 15
- `g:tabjumper_mod_func` (string or funcref)  
    a funcref or function name.  
    This function shows the information of a file
    listed in this plugin.
    The arguments of this function are the tab number and window number.  
    default: ''  
    An example is following;
```vim
function! Tab_info(tabnr, winnr)
    let bufnr = tabpagebuflist(a:tabnr)[a:winnr-1]
    let winid = win_getid(a:winnr, a:tabnr)
    return printf(' %s:%d/%d', getbufvar(bufnr, '&filetype'), line('.', winid), line('$', winid))
endfunction
let g:tabjumper_mod_func = 'Tab_info'
```

Highlights
- `TJSelect`  
    Highlighting selected lines.  
    Linked to `PmenuSel` in default.
- `TJSearch`  
    Search pattern highlighting in TabJumper window.  
    Linked to `Search` in default.

## License
[MIT](https://github.com/MeF0504/vim-TabJumper/blob/main/LICENSE)

## Author
[MeF0504](https://github.com/MeF0504)
