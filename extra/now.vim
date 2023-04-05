" Vim syntax file
" Language: Now
" Maintainer: Cléber Zavadniak

syn match nowHead '\[.\+\]'
syn keyword nowHeaderKey name description parameters command workdir
syn match nowComment '^#.\+'

syn match nowNumber '\d\+'
syn match nowNumber '[-+]\d\+'
syn match nowString '"[^"]\+"'
syn match nowString '\'[^"]\+\''
syn match nowString '{{[^"]\+}}'
syn match nowSubstAtom '$[a-z][^ ]*'
syn match nowName '[a-z0-9_.]\+'

syn match nowCommand '^ *[a-z][^ ]\+'
syn match nowCommand ' | *[a-z][^ ]\+'
syn match nowCommand ' | {.\+}'
" syn match nowPipe ' | '

syn region nowBlock start="{" end="}" transparent fold keepend extend
syn match nowContinuation '^ \+\. '


hi def link nowHead        Special
hi def link nowHeaderKey   Statement

hi def link nowComment       Comment

hi def link nowCommand       Statement
hi def link nowPipedCommand  Statement
hi def link nowPipe          Special
hi def link nowContinuation  Special

hi def link nowTodo        Todo
hi def link nowType        Type

hi def link nowConst       Constant
hi def link nowNumber      Constant
hi def link nowString      String
hi def link nowName        Identifier
hi def link nowSubstAtom   Identifier

hi def link nowBlock       Function

function! NowFoldExpr(lnum)
    let line = getline(a:lnum)

    if line =~# '^\[[^]]*\]'
        return '>1'
    endif

    return '='
endfunction

setlocal foldmethod=expr
setlocal foldexpr=NowFoldExpr(v:lnum)
setlocal foldcolumn=2
" setlocal foldlevel=0
" setlocal foldenable

let b:current_syntax = "now"
