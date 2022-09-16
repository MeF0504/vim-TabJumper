scriptencoding utf-8

augroup TabJumper
    autocmd!
augroup END

function! s:set_config() abort
    let s:height = get(g:, 'tabjumper_height', 10)
    let s:bufname = 'TabJumper'
    let s:bottop = 'botright'
    let s:mod_func = get(g:, 'tabjumper_mod_func', '')
    let s:last_tab = tabpagenr('#')
    let s:cur_tab = tabpagenr()
    let s:lines = []
    let s:search = ''
    let s:done = -1
endfunction

function! s:set_highlight() abort
    highlight default link TJSelect PmenuSel
    highlight default link TJSearch Search
endfunction

function! s:set_st_line() abort
    let res = ''
    let res .= s:get_cur_tab()+1
    let res .= '/'
    let res .= len(s:lines)
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
    setlocal laststatus=2
    setlocal cmdheight=1
    setlocal statusline=\ \ move:j,k,↑,↓\ close:q,<ESC>\ search:/,n,N\ %=%{s:set_st_line()}
    setlocal nocursorline
    setlocal nocursorcolumn

    autocmd TabJumper WinLeave <buffer> ++once call s:close_win()
endfunction

function! s:get_cur_tab() abort
    let ln = line('.')
    for i in range(len(s:lines))
        for j in s:lines[i]
            if ln == j
                return i
            endif
        endfor
    endfor
    return -1
endfunction

function! s:ctrl_win() abort
    let search_id = -1
    let start_line = s:lines[s:cur_tab-1]
    call cursor(start_line)
    let sel_id = matchaddpos('TJSelect', start_line)
    redraw
    let srch = ''
    while 1
        let key = getcharstr()
        if key ==# 'q'
            break
        elseif key ==# "\<esc>"
            break
        elseif key ==# "\<c-c>"  " don't work?
            break
        elseif key ==# "\<CR>"
            let s:done = s:get_cur_tab()+1
            break
        elseif key ==# 'j' || key ==# "\<Down>"
            let cur = s:get_cur_tab()
            if cur < len(s:lines)-1
                call cursor(s:lines[cur+1][0], 1)
            endif
        elseif key ==# 'k' || key ==# "\<Up>"
            let cur = s:get_cur_tab()
            if cur > 0
                call cursor(s:lines[cur-1][0], 1)
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
                let cur = s:get_cur_tab()
                call cursor(s:lines[cur][-1], 100)
                call search(s:search)
            endif
        elseif key ==# 'N'
            if !empty(s:search)
                let cur = s:get_cur_tab()
                call cursor(s:lines[cur][0], 1)
                call search(s:search, 'b')
            endif
        endif
        call matchdelete(sel_id)
        let cur = s:get_cur_tab()
        let sel_id = matchaddpos('TJSelect', s:lines[cur], 10)
        redraw
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
    if s:done < 0
        return
    endif
    execute printf('%dtabnext', s:done)
endfunction

function! tabjumper#jump() abort
    call s:set_config()
    let res = []
    let cnt = 1

    for i in range(1, tabpagenr('$'))
        let tmp = []
        if i == s:cur_tab
            let status = '>'
        elseif i == s:last_tab
            let status = '#'
        else
            let status = ' '
        endif
        call add(res, printf('%s tab %d:', status, i))
        call add(tmp, cnt)
        let cnt += 1
        for j in range(1, tabpagewinnr(i, '$'))
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
            call add(res, printf('   %s%s', name, mod))
            call add(tmp, cnt)
            let cnt += 1
        endfor
        call add(s:lines, tmp)
    endfor

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
