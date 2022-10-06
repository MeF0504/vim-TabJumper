" tabjumper
" Version: 1.0.1
" Author: MeF
" License: MIT

if exists('g:loaded_tabjumper')
  finish
endif
let g:loaded_tabjumper = 1

let s:save_cpo = &cpo
set cpo&vim

command! TabJump call tabjumper#jump()

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
