scriptencoding utf-8

augroup TabJumper
    autocmd!
augroup END

function! tabjumper#log() abort
    for l in s:log
        echo l
    endfor
endfunction

function! s:set_config() abort
    let s:height = get(g:, 'tabjumper_height', 10)
    let s:bufname = 'TabJumper'
    let s:bottop = 'botright'
    let s:mod_func = get(g:, 'tabjumper_mod_func', '')
    let s:last_tab = tabpagenr('#')
    let s:cur_tab = tabpagenr()
    let s:lines = []
    let s:search = ''
    let s:win_mode = 0
    let s:done = []
    let s:pre_enable = get(g:, 'tabjumper_preview_enable', 1)
    let s:pid = -1
    let s:pre_w = get(g:, 'tabjumper_preview_width', 40)
    let s:pre_h = get(g:, 'tabjumper_preview_height', 15)
    let s:debug = get(g:, 'tabjumper_debug', 0)
    let s:log = []
endfunction

function! s:set_info() abort
    let cnt = 1
    let s:lines = []

    for i in range(1, tabpagenr('$'))
        let tmp = []
        let info = {}
        if i == s:cur_tab
            let status = '>'
        elseif i == s:last_tab
            let status = '#'
        else
            let status = ' '
        endif
        let info.str = printf('%s tab %d:', status, i)
        let info.line = cnt
        let info.tabnr = i
        let info.winnr = tabpagewinnr(i)
        let info.bufnr = tabpagebuflist(i)[info.winnr-1]
        let info.winid = win_getid(info.winnr, i)
        call add(tmp, info)
        let cnt += 1
        for j in range(1, tabpagewinnr(i, '$'))
            let info = {}
            let bufnr = tabpagebuflist(i)[j-1]
            if !empty(s:mod_func)
                let mod = call(s:mod_func, [i, j])
            else
                let wid = win_getid(j, i)
                let mod = ''
                let mod .= getbufvar(bufnr, '&modified') ? ',+' : ''
                let mod .= getbufvar(bufnr, '&modifiable') ? '' : ',-'
                let mod .= getbufvar(bufnr, '&readonly') ? ',RO' : ''
                if !empty(mod)
                    let mod = printf(' (%s)', mod[1:])
                endif
                let mod .= printf(' %d/%d', line('.', wid), line('$', wid))
            endif
            let name = bufname(bufnr)
            if empty(name)
                if getbufvar(bufnr, '&filetype') == 'qf'
                    let name = '[Quickfix]'
                else
                    let name = '[No name]'
                endif
            endif
            let info.str = printf('   └ %s%s', name, mod)
            let info.line = cnt
            let info.bufnr = bufnr
            let info.tabnr = i
            let info.winnr = j
            let info.winid = win_getid(j, i)
            let info.name = name
            call add(tmp, info)
            let cnt += 1
        endfor
        call add(s:lines, tmp)
    endfor
endfunction

function! s:get_lines() abort
    let res = []
    for wins in s:lines
        for info in wins
            call add(res, info.str)
        endfor
    endfor
    return res
endfunction

function! s:set_highlight() abort
    highlight default link TJSelect PmenuSel
    highlight default link TJSearch Search
endfunction

function! s:set_st_line() abort
    let res = '  move:j,k,g,G close:q,<ESC> search:/,n,N '
    if s:win_mode
        let res .= 'tab-mode:h '
    else
        let res .= 'win-mode:l '
    endif
    if s:pre_enable
        let res .= 'preview:p '
    endif
    let res .= '%='
    let res .= s:get_cur_tab(0)+1
    let res .= '/'
    let res .= len(s:lines)
    let res .= ' '
    return res
endfunction

function! s:set_win() abort
    let s:las = &laststatus
    let s:ch = &cmdheight
    setlocal modifiable
    silent %delete _
    setlocal noreadonly
    setlocal noswapfile
    setlocal nobackup
    setlocal noundofile
    setlocal buftype=nofile
    setlocal nobuflisted
    setlocal nomodeline
    " setlocal nowrap
    setlocal wrap
    setlocal foldlevel=9999
    setlocal report=9999
    setlocal nolist
    setlocal nonumber
    setlocal filetype=TabJumper
    setlocal laststatus=2
    setlocal cmdheight=1
    setlocal statusline=%!s:set_st_line()
    setlocal nocursorline
    setlocal nocursorcolumn

    autocmd TabJumper WinLeave <buffer> ++once call s:close_win()
endfunction

function! s:get_cur_tab(win) abort
    let ln = line('.')
    for i in range(len(s:lines))
        for info in s:lines[i]
            if ln == info.line
                if a:win
                    return [i, info.winnr-1]
                else
                    return i
                endif
            endif
        endfor
    endfor
    if a:win
        return [-1, -1]
    else
        return -1
    endif
endfunction

function! s:ctrl_win() abort
    let search_id = -1
    let start_lines = map(copy(s:lines[s:cur_tab-1]), 'v:val.line')
    if s:debug
        call add(s:log, 'start line; '.join(start_lines))
    endif
    call cursor(start_lines[0], 1)
    let sel_id = matchaddpos('TJSelect', start_lines)
    redraw
    redrawstatus
    let srch = ''

    while 1
        let key = getcharstr()
        if s:pre_enable
            call s:close_preview()
        endif
        if key ==# 'q'
            break
        elseif key ==# "\<esc>"
            break
        elseif key ==# "\<c-c>"  " don't work?
            break
        elseif key ==# "\<CR>"
            let s:done = map(s:get_cur_tab(1), 'v:val+1')
            break
        elseif key ==# 'j' || key ==# "\<Down>"
            let cur = s:get_cur_tab(0)
            if s:win_mode
                let wins = map(copy(s:lines[cur]), 'v:val.line')[1:]
                if s:debug
                    call add(s:log, printf('%d vs %d~%d',
                                \ line('.'), wins[0], wins[-1]))
                endif
                if line('.') < wins[-1]
                    cal cursor(line('.')+1, 1)
                endif
            else
                if cur < len(s:lines)-1
                    call cursor(s:lines[cur+1][0].line, 1)
                endif
            endif
        elseif key ==# 'k' || key ==# "\<Up>"
            let cur = s:get_cur_tab(0)
            if s:win_mode
                let wins = map(copy(s:lines[cur]), 'v:val.line')[1:]
                if s:debug
                    call add(s:log, printf('%d vs %d~%d',
                                \ line('.'), wins[0], wins[-1]))
                endif
                if line('.') > wins[0]
                    cal cursor(line('.')-1, 1)
                endif
            else
                if cur > 0
                    call cursor(s:lines[cur-1][0].line, 1)
                endif
            endif
        elseif key ==# 'g'
            if s:win_mode
                let cur = s:get_cur_tab(0)
                call cursor(s:lines[cur][1].line, 1)
            else
                call cursor(1, 1)
            endif
        elseif key ==# 'G'
            if s:win_mode
                let cur = s:get_cur_tab(0)
                call cursor(s:lines[cur][-1].line, 1)
            else
                call cursor(s:lines[-1][0].line, 1)
            endif
        elseif key ==# 'l' || key ==# "\<Right>"
            if !s:win_mode
                let cur = s:get_cur_tab(0)
                let s:win_mode = 1
                call cursor(s:lines[cur][1].line, 1)
            endif
        elseif key ==# 'h' || key ==# "\<Left>"
            if s:win_mode
                let cur = s:get_cur_tab(0)
                let s:win_mode = 0
                call cursor(s:lines[cur][0].line, 1)
            endif
        elseif key ==# '/'
            let s:search = input('/', '', 'buffer')
            if search_id != -1
                call matchdelete(search_id)
                let search_id = -1
            endif
            if !empty(s:search)
                let search_id = matchadd('TJSearch', s:search, 15)
            endif
            call search(s:search)
        elseif key ==# 'n'
            if !empty(s:search)
                if s:win_mode
                    call cursor(line('.'), 100)
                else
                    let cur = s:get_cur_tab(0)
                    call cursor(s:lines[cur][-1].line, 100)
                endif
                call search(s:search)
            endif
        elseif key ==# 'N'
            if !empty(s:search)
                if s:win_mode
                    call cursor(line('.'), 1)
                else
                    let cur = s:get_cur_tab(0)
                    call cursor(s:lines[cur][0].line, 1)
                endif
                call search(s:search, 'b')
            endif
        elseif key ==# 'p'
            if s:pre_enable
                call s:show_preview()
            endif
        endif
        call matchdelete(sel_id)
        if s:win_mode
            let sel_id = matchaddpos('TJSelect', [[line('.'), 4, col('$')-4]], 10)
        else
            let cur = s:get_cur_tab(0)
            let sel_id = matchaddpos('TJSelect',
                        \ map(copy(s:lines[cur]), 'v:val.line'), 10)
        endif
        redraw
        redrawstatus
    endwhile
endfunction

function! s:close_win() abort
    let &cmdheight = s:ch
    let &laststatus = s:las
    if bufname() == s:bufname
        quit
    endif
endfunction

function! s:jump_tab() abort
    if s:debug
        call add(s:log, 'done: '.join(s:done))
    endif
    if empty(s:done)
        return
    endif
    execute printf('%dtabnext', s:done[0])
    execute printf('%dwincmd w', s:done[1])
endfunction

function! s:set_preview(winid) abort
    " setlocal nomodifiable
    setlocal nonumber
    call cursor(line('.', a:winid), 1)
    normal! zz
endfunction

function! s:show_preview() abort
    let [tabn, winn] = s:get_cur_tab(1)
    let info = s:lines[tabn][winn+1]  " +1 ... tab line
    if s:debug
        call add(s:log, printf('preview win %d - %d', tabn, winn))
    endif
    let bufn = info.bufnr
    let winid = info.winid
    if has('popupwin')
        let config = {
                    \ 'line': 'cursor',
                    \ 'col': strchars(getline('.'))+3,
                    \ 'pos': 'botleft',
                    \ 'maxwidth': s:pre_w,
                    \ 'maxheight': s:pre_h,
                    \ 'cursorline': v:true,
                    \ }
        let s:pid = popup_create(bufn, config)
    elseif has('nvim')
        let config = {
                    \ 'relative': 'editor',
                    \ 'row': &lines/2,
                    \ 'col': strchars(getline('.'))+3,
                    \ 'anchor': 'SW',
                    \ 'width': s:pre_w,
                    \ 'height': s:pre_h,
                    \ }
        let s:pid = nvim_open_win(bufn, v:false, config)
    endif
    call win_execute(s:pid, printf("call %sset_preview(%d)", expand('<SID>'), winid))
endfunction

function! s:close_preview() abort
    if s:pid > 0
        if has('popupwin')
            call popup_close(s:pid)
        elseif has('nvim')
            call nvim_win_close(s:pid, v:false)
        endif
        let s:pid = -1
    endif
endfunction

function! tabjumper#jump() abort
    call s:set_config()
    call s:set_info()
    let res = s:get_lines()

    execute printf('%s %dsplit %s', s:bottop, s:height, s:bufname)
    call s:set_win()
    call append(0, res)
    silent $delete _
    setlocal nomodifiable
    redraw!
    call s:set_highlight()
    call s:ctrl_win()
    call s:close_win()
    call s:jump_tab()
endfunction
