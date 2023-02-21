scriptencoding utf-8

augroup TabJumper
    autocmd!
augroup END

function! tabjumper#log() abort
    for l in s:log
        echo l
    endfor

    echo 'bookmarks: '
    echon s:bookmarks
endfunction

let s:bookmarks = {}
function! s:set_config() abort
    let s:height = get(g:, 'tabjumper_height', 10)
    let s:bufname = 'TabJumper'
    let s:bottop = 'botright'
    let s:mod_func = get(g:, 'tabjumper_mod_func', '')
    let s:last_tab = tabpagenr('#')
    let s:cur_tab = tabpagenr()
    " tabjumper がwinnr最大以外だとずれるかも
    let s:cur_winnr = winnr()
    let s:lines = []
    let s:search = ''
    let s:win_mode = 0
    let s:done = []
    let s:tabmove = []
    let s:pre_enable = get(g:, 'tabjumper_preview_enable', 'auto')
    let s:pid = -1
    let s:pre_w = get(g:, 'tabjumper_preview_width', 40)
    let s:pre_h = get(g:, 'tabjumper_preview_height', 15)
    let s:debug = get(g:, 'tabjumper_debug', 0)
    let s:tid = -1
    let s:t_time = get(g:, 'tabjumper_preview_time', 1000)
    let s:log = []
endfunction

function! s:debug_log(log) abort
    if s:debug
        cal add(s:log, a:log)
    endif
endfunction

function! s:set_info() abort
    let cnt = 1
    let s:lines = []

    for i in range(1, tabpagenr('$'))
        let tmp = []
        let info = {}
        if i == s:cur_tab
            let info.status = '>'
        elseif i == s:last_tab
            let info.status = '#'
        else
            let info.status = ' '
        endif
        let winnr = tabpagewinnr(i)
        let mark = info.status
        for j in range(1, tabpagewinnr(i, '$'))
            let winid = win_getid(j, i)
            let idx = match(keys(s:bookmarks), winid)
            if idx != -1
                let mark = s:bookmarks[winid]
            endif
        endfor

        let info.str = printf('%s tab %d:', mark, i)
        let info.line = cnt
        let info.tabnr = i
        let info.winnr = winnr
        let info.bufnr = tabpagebuflist(i)[info.winnr-1]
        let info.winid = win_getid(info.winnr, i)
        call add(tmp, info)
        let cnt += 1
        for j in range(1, tabpagewinnr(i, '$'))
            if s:is_popup(i, j)
                continue
            endif
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
    let res = '  move:j,k,g,G'
    if s:win_mode
        let res .= ' '
    else
        let res .= ',[1-9] '
    endif
    let res .= 'close:q search:/,n,N '
    if s:win_mode
        let res .= 'tab:h '
    else
        let res .= 'pre:# win:l tabmove:+,- '
    endif
    if s:pre_enable == 'manual'
        let res .= 'preview:p '
    endif
    let res .= 'bookmark:b '
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

function! s:rewrite_win() abort
    let res = s:get_lines()
    setlocal modifiable
    silent %delete _
    call append(0, res)
    silent $delete _
    setlocal nomodifiable
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
    call s:debug_log('start line; '.join(start_lines))
    call cursor(start_lines[0], 1)
    let sel_id = matchaddpos('TJSelect', start_lines)
    redraw
    redrawstatus
    let srch = ''
    call s:set_timer()

    while 1
        try
            let key = getcharstr()
        catch /^Vim:Interrupt$/
            " ctrl-c (interrupt)
            call s:close_preview()
            break
        endtry
        call s:close_preview()
        call s:stop_timer()
        call s:set_timer()
        if key ==# 'q'
            break
        elseif key ==# "\<esc>"
            break
        elseif key ==# "\<CR>"
            let s:done = map(s:get_cur_tab(1), 'v:val+1')
            break
        elseif key ==# 'j' || key ==# "\<Down>"
            let cur = s:get_cur_tab(0)
            if s:win_mode
                let wins = map(copy(s:lines[cur]), 'v:val.line')[1:]
                call s:debug_log(printf('j; %d vs %d~%d',
                            \ line('.'), wins[0], wins[-1]))
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
                call s:debug_log(printf('k; %d vs %d~%d',
                            \ line('.'), wins[0], wins[-1]))
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
        elseif key =~# '[1-9]'
            if !s:win_mode
                if key <= len(s:lines)
                    call cursor(s:lines[key-1][0].line, 1)
                endif
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
        elseif key ==# '#'
            if !s:win_mode
                for ln in s:lines
                    if ln[0].status ==# '#'
                        call cursor(ln[0].line, 1)
                        break
                    endif
                endfor
            endif
        elseif key ==# '/'
            call s:stop_timer()
            let s:search = input('/', '', 'buffer')
            if search_id != -1
                call matchdelete(search_id)
                let search_id = -1
            endif
            if !empty(s:search)
                let search_id = matchadd('TJSearch', s:search, 15)
            endif
            call search(s:search)
            call s:set_timer()
        elseif key ==# 'n'
            if !empty(s:search)
                if s:win_mode
                    call cursor(line('.'), col('$'))
                else
                    let cur = s:get_cur_tab(0)
                    call cursor(s:lines[cur][-1].line, col('$'))
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
            if s:pre_enable == 'manual'
                call s:show_preview(0)
            endif
        elseif key ==# '+' || key ==# '-'
            if s:win_mode
                continue
            endif
            let cur = s:get_cur_tab(0)
            if key ==# '+' && s:lines[cur][0].tabnr == len(s:lines)
                continue
            elseif key ==# '-' && s:lines[cur][0].tabnr == 1
                continue
            endif
            call add(s:tabmove, printf('%dtabdo tabmove %s', cur+1, key))
            let tmp = remove(s:lines, cur)
            if key ==# '+'
                let new_cur = cur+1
            else
                let new_cur = cur-1
            endif
            call extend(s:lines, [tmp], new_cur)
            let cnt = 1
            for i in range(len(s:lines))
                for info in s:lines[i]
                    let info.line = cnt
                    let info.tabnr = i+1
                    let cnt += 1
                endfor
            endfor
            call s:rewrite_win()
            call cursor(s:lines[new_cur][0].line, 1)
            " redraw!
        elseif key ==# 'b'
            call s:stop_timer()
            call s:debug_log('bookmark')
            let mark = input('bookmark (a-zA-Z): ')
            if mark =~# '^[a-zA-Z]$'
                let cur = s:get_cur_tab(0)
                let tabnr = s:lines[cur][0].tabnr
                let winid = s:lines[cur][0].winid
                let s:bookmarks[winid] = mark
                let s:lines[cur][0].str = printf('%s tab %d:', mark, tabnr)
                call s:rewrite_win()
                call cursor(s:lines[cur][0].line, 1)
                call s:debug_log(printf('set %d = %s', winid, mark))
            endif
            call s:set_timer()
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
    call s:stop_timer()
endfunction

function! s:close_win() abort
    let &cmdheight = s:ch
    let &laststatus = s:las
    if bufname() == s:bufname
        quit
    endif
    execute s:cur_winnr..'wincmd w'
endfunction

function! s:jump_tab() abort
    call s:debug_log('done: '.join(s:done))
    for tm in s:tabmove
        execute tm
        call s:debug_log('  execute '..tm)
    endfor
    if empty(s:done)
        return
    endif
    execute printf('%dtabnext', s:done[0])
    execute printf('%dwincmd w', s:done[1])
endfunction

function! s:is_popup(tabnr, winnr) abort
    let wid = win_getid(a:winnr, a:tabnr)
    if has('popupwin')
        if match(popup_list(), wid) != -1
            return v:true
        endif
    elseif has('nvim')
        if (match(nvim_list_wins(), wid)!=-1) &&
                    \ !empty(nvim_win_get_config(wid)['relative'])
            return v:true
        endif
    endif
    return v:false
endfunction

function! s:set_preview(winid) abort
    " setlocal nomodifiable
    setlocal nonumber
    setlocal nowrap
    call cursor(getcurpos(a:winid)[1:])
    normal! zz
endfunction

function! s:show_preview(tid) abort
    call s:close_preview()
    let [tabn, winn] = s:get_cur_tab(1)
    let info = s:lines[tabn][winn+1]  " +1 ... tab line
    call s:debug_log(printf('preview win %d - %d', tabn, winn))
    let bufn = info.bufnr
    let winid = info.winid
    call s:debug_log(printf('preview bn:%d wid:%d', bufn, winid))
    if has('popupwin')
        if match(term_list(), printf('^%d$',bufn)) != -1
            call s:debug_log('buf find in term_list: '..bufn)
            return
        endif
        let config = {
                    \ 'line': 'cursor-1',
                    \ 'col': strchars(getline('.'))+3,
                    \ 'pos': 'botleft',
                    \ 'maxwidth': s:pre_w,
                    \ 'maxheight': s:pre_h,
                    \ 'cursorline': v:true,
                    \ }
        let s:pid = popup_create(bufn, config)
    elseif has('nvim')
        let config = {
                    \ 'relative': 'cursor',
                    \ 'row': 0,
                    \ 'col': strchars(getline('.'))+2-getcurpos()[2],
                    \ 'anchor': 'SW',
                    \ 'width': s:pre_w,
                    \ 'height': s:pre_h,
                    \ }
        let s:pid = nvim_open_win(bufn, v:false, config)
    endif
    call win_execute(s:pid, printf("call %sset_preview(%d)", expand('<SID>'), winid))
    redraw
endfunction

function! s:close_preview() abort
    if s:pid > 0
        call s:debug_log(printf('close win %d', s:pid))
        if has('popupwin')
            call popup_close(s:pid)
        elseif has('nvim')
            call nvim_win_close(s:pid, v:false)
        endif
        let s:pid = -1
        redraw
    endif
endfunction

function! s:stop_timer() abort
    if s:tid > 0
        call timer_stop(s:tid)
        let s:tid = -1
    endif
endfunction

function! s:set_timer() abort
    if s:pre_enable == 'auto'
        call s:stop_timer()
        let s:tid = timer_start(s:t_time, ('<SID>')..'show_preview', {'repeat': 1})
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
