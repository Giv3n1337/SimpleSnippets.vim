" Globals
let s:flash_snippets = {}
let s:active = 0
let s:snip_start = 0
let s:snip_end = 0
let s:snip_line_count = 0
let s:current_file = ''
let s:snip_edit_buf = 0
let s:snip_edit_win = 0
let s:trigger = ''
let s:escape_pattern = '/\*~.$^!#'
let s:visual_contents = ''

let s:snippet = []
let s:jump_stack = []
let s:type_stack = []
let s:current_jump = 0
let s:ph_start = []
let s:ph_end = []

"Functions
function! SimpleSnippets#init#expand()
	let l:trigger = s:trigger
	let s:trigger = ''
	let l:filetype = s:GetSnippetFiletype(l:trigger)
	if l:filetype == 'flash'
		call s:ExpandFlashSnippet(l:trigger)
	else
		let l:path = s:GetSnippetPath(l:trigger, l:filetype)
		let l:snippet = readfile(l:path)
		while l:snippet[0] == ''
			call remove(l:snippet, 0)
		endwhile
		while l:snippet[-1] == ''
			call remove(l:snippet, -1)
		endwhile
		call s:StoreSnippetToMemory(l:snippet)
		let s:snip_line_count = len(l:snippet)
		if s:snip_line_count != 0
			let l:snippet = s:ParseAndInit()
			let l:snip_as_str = join(l:snippet, "\n")
			let l:save_s = @s
			let @s = l:snip_as_str
			let l:save_quote = @"
			if l:trigger =~ "\\W"
				normal! ciW
			else
				normal! ciw
			endif
			normal! "sp
			let @" = l:save_quote
			let @s = l:save_s
		else
			echo '[ERROR] Snippet body is empty'
		endif
	endif
endfunction

function! s:StoreSnippetToMemory(snippet)
	let s:snippet = copy(a:snippet)
endfunction

function! s:ExpandFlashSnippet(snip)
	let l:save_quote = @"
	if a:snip =~ "\\W"
		normal! ciW
	else
		normal! ciw
	endif
	let l:save_s = @s
	let @s = s:flash_snippets[a:snip]
	let s:snip_line_count = len(substitute(s:flash_snippets[a:snip], '[^\n]', '', 'g')) + 1
	normal! "sp
	let @s = l:save_s
	if s:snip_line_count != 1
		let l:indent_lines = s:snip_line_count - 1
		silent exec 'normal! V' . l:indent_lines . 'j='
	else
		normal! ==
	endif
	silent call s:ParseAndInit()
endfunction

function! s:ParseAndInit()
	let s:jump_stack = []
	let s:type_stack = []
	let s:current_jump = 0
	let s:ph_start = []
	let s:ph_end = []
	let s:active = 1
	let s:current_file = @%

	let l:cursor_pos = getpos(".")
	let l:ph_amount = s:CountPlaceholders('\v\$\{[0-9]+(:|!|\|)')
	let l:ts_amount = s:CountPlaceholders('\v\$[0-9]+')
	if l:ph_amount != 0 || l:ts_amount
		call s:InitSnippet(l:ph_amount + l:ts_amount)
		if s:snip_line_count != 1
			let l:indent_lines = s:snip_line_count - 1
			call cursor(s:snip_start, 1)
			silent exec 'normal! V'
			silent exec 'normal!'. l:indent_lines .'j='
		else
			normal! ==
		endif
		call cursor(s:snip_start, 1)
	else
		let s:active = 0
		call cursor(l:cursor_pos[1], l:cursor_pos[2])
	endif
endfunction

function! s:InitRemainingVisuals()
	let l:visual_amount = s:CountPlaceholders('\v\$\{VISUAL\}')
	let i = 0
	while i < l:visual_amount
		call cursor(s:snip_start, 1)
		call search('\v\$\{VISUAL\}', 'c', s:snip_end)
		exe "normal! f{%vF$c"
		let l:result = s:InitVisual('', '')
		let l:result_line_count = len(substitute(l:result, '[^\n]', '', 'g'))
		if l:result_line_count > 1
			silent exec 'normal! V'
			silent exec 'normal!'. l:result_line_count .'j='
			let s:snip_end += l:result_line_count
		endif
		let i += 1
	endwhile
	let s:visual_contents = ''
endfunction

function! s:GetSnippetFiletype(snip)
	call s:CheckExternalSnippetPlugin()
	let l:filetype = s:GetMainFiletype(g:SimpleSnippets_similar_filetypes)
	if filereadable(g:SimpleSnippets_search_path . l:filetype . '/' . a:snip)
		return l:filetype
	endif
	if s:FlashSnippetExists(a:snip)
		return 'flash'
	endif
	if s:SimpleSnippets_snippets_plugin_installed == 1
		let l:plugin_filetype = s:GetMainFiletype(g:SimpleSnippets_snippets_similar_filetypes)
		if filereadable(g:SimpleSnippets_snippets_plugin_path . l:plugin_filetype . '/' . a:snip)
			return l:plugin_filetype
		endif
	endif
	if filereadable(g:SimpleSnippets_search_path . 'all/' . a:snip)
		return 'all'
	endif
	if s:SimpleSnippets_snippets_plugin_installed == 1
		if filereadable(g:SimpleSnippets_snippets_plugin_path . 'all/' . a:snip)
			return 'all'
		endif
	endif
	return -1
endfunction

function! s:FlashSnippetExists(snip)
	if has_key(s:flash_snippets, a:snip)
		return 1
	endif
	return 0
endfunction

function! s:GetMainFiletype(similar_filetypes)
	let l:ft = &ft
	if l:ft == ''
		return 'all'
	endif
	for l:filetypes in a:similar_filetypes
		if index(l:filetypes, l:ft) != -1
			return l:filetypes[0]
		endif
	endfor
	return l:ft
endfunction

function! s:InitNormal(current)
	let l:placeholder = '\v(\$\{'.a:current.':)@<=.{-}(\}($|[^\}]))@='
	let l:save_quote = @"
	let l:before = ''
	let l:after = ''
	if search('\v(\$\{'.a:current.':(.{-})?)@<=\$\{VISUAL\}((.{-})?\}($|[^\}]))@=', 'c', line('.')) != 0
		let l:cursor_pos = getpos(".")
		call cursor(line('.'), 1)
		if search('\v(\$\{'.a:current.':)@<=.{-}(\$\{VISUAL\}.*\})@=', 'cn', line('.')) != 0
			let l:before = matchstr(getline('.'), '\v(\$\{'.a:current.':)@<=.{-}(\$\{VISUAL\}.*\})@=')
		endif
		if search('\v(\$\{'.a:current.':.{-}\$\{VISUAL\})@<=.{-}(\})@=', 'cn', line('.')) != 0
			let l:after = matchstr(getline('.'), '\v(\$\{'.a:current.':.{-}\$\{VISUAL\})@<=.{-}(\})@=')
		endif
		call cursor(l:cursor_pos[1], l:cursor_pos[2])
		exe "normal! F{%vF$;c"
		let l:result = s:InitVisual(l:before, l:after)
		let l:result_line_count = len(substitute(l:result, '[^\n]', '', 'g'))
		if l:result_line_count > 1
			silent exec 'normal! V'
			silent exec 'normal!'. l:result_line_count .'j='
			let s:snip_end += l:result_line_count
		endif
	else
		let save_q_mark = getpos("'q")
		exe "normal! f{mq%i\<Del>\<Esc>g`qF$df:"
		call setpos("'q", save_q_mark)
	endif
	let @" = l:save_quote
	let l:repeater_count = s:CountPlaceholders('\v\$' . a:current)
	if l:repeater_count != 0
		call s:InitRepeaters(a:current, l:result, l:repeater_count)
	endif
endfunction

function! s:InitCommand(current)
	let l:save_quote = @"
	let l:placeholder = '\v(\$\{'.a:current.'!)@<=.{-}(\}($|[^\}]))@='
	let l:command = matchstr(getline('.'), l:placeholder)
	let g:com = l:command
	if executable(substitute(l:command, '\v(^\w+).*', '\1', 'g')) == 1
		let l:result = system(l:command)
	else
		let l:result = s:Execute("echo " . l:command, "silent!")
		if l:result == ''
			let l:result = l:command
		endif
	endif
	let l:result = s:RemoveTrailings(l:result)
	let l:save_s = @s
	let @s = l:result
	let l:result_line_count = len(substitute(l:result, '[^\n]', '', 'g')) + 1
	if l:result_line_count > 1
		let s:snip_end += l:result_line_count
	endif
	let save_q_mark = getpos("'q")
	let save_p_mark = getpos("'p")
	normal! mq
	call search('\v\$\{'.a:current.'!.{-}\}($|[^\}])@=', 'ce', s:snip_end)
	normal! mp
	let s:ph_start = getpos("'q")
	let s:ph_end = getpos("'p")
	exe "normal! g`qvg`pr"
	normal! "sp
	call setpos("'q", save_q_mark)
	call setpos("'p", save_p_mark)
	let @s = l:save_s
	let @" = l:save_quote
	let l:repeater_count = s:CountPlaceholders('\v\$' . a:current)
	call add(s:jump_stack, l:result)
	if l:repeater_count != 0
		call add(s:type_stack, 'mirror')
		call s:InitRepeaters(a:current, l:result, l:repeater_count)
	else
		call add(s:type_stack, 'normal')
	endif
	noh
endfunction

function! s:InitVisual(before, after)
	if s:visual_contents != ''
		let l:visual = s:visual_contents
	else
		let l:visual = ''
	endif
	let l:save_s = @s
	let l:visual = s:RemoveTrailings(l:visual)
	let l:visual = a:before . l:visual . a:after
	let @s = l:visual
	normal! "sp
	let @s = l:save_s
	return l:visual
endfunction

function! s:InitChoice(current)
	let l:placeholder = '\v(\$\{'.a:current.'\|)@<=.{-}(\|\})@='
	let l:save_quote = @"
	let l:before = ''
	let l:after = ''
	let l:result = split(matchstr(getline('.'), l:placeholder), ',')
	let save_q_mark = getpos("'q")
	exe "normal! f,df|xF$df|"
	call setpos("'q", save_q_mark)
	call add(s:jump_stack, l:result)
	let @" = l:save_quote
	let l:repeater_count = s:CountPlaceholders('\v\$' . a:current)
	if l:repeater_count != 0
		call add(s:type_stack, 'mirror_choice')
		call s:InitRepeaters(a:current, l:result[0], l:repeater_count)
	else
		call add(s:type_stack, 'choice')
	endif
endfunction

function! s:CountPlaceholders(pattern)
	let l:cnt = s:Execute('%s/' . a:pattern . '//gn', "silent!")
	call histdel("/", -1)
	if match(l:cnt, 'not found') >= 0
		return 0
	endif
	let l:count = strpart(l:cnt, 0, stridx(l:cnt, " "))
	let l:count = substitute(l:count, '\v%^\_s+|\_s+%$', '', 'g')
	return l:count
endfunction

function! s:InitSnippet(amount)
	let l:type = 0
	let l:i = 1
	let l:max = a:amount + 1
	let l:current = l:i
	let s:snip_start = line(".")
	let s:snip_end = s:snip_start + s:snip_line_count - 1
	while l:i <= l:max
		call cursor(s:snip_start, 1)
		if l:i == l:max
			let l:current = 0
		endif
		if search('\v\$\{' . l:current, 'c') != 0
			let l:type = s:GetPlaceholderType()
			call s:InitPlaceholder(l:current, l:type)
		endif
		let l:i += 1
		let l:current = l:i
	endwhile
	call s:InitRemainingVisuals()
endfunction

function! SimpleSnippets#addFlashSnippet(trigger, snippet_defenition)
	let s:flash_snippets[a:trigger] = a:snippet_defenition
endfunction

function! SimpleSnippets#removeFlashSnippet(trigger)
	let l:i = 0
	if has_key(s:flash_snippets, a:trigger)
		unlet![a:trigger]
	endif
endfunction

function! s:GetPlaceholderType()
	let l:col = col('.')
	let l:ph = matchstr(getline('.'), '\v%'.l:col.'c\$\{[0-9]+.{-}\}')
	if match(l:ph, '\v\$\{[0-9]+:.{-}\}') == 0
		return 'normal'
	elseif match(l:ph, '\v\$\{[0-9]+!.{-}\}') == 0
		return 'command'
	elseif match(l:ph, '\v\$\{[0-9]+\|.{-}\|\}') == 0
		return 'choice'
	elseif match(l:ph, '\v\$[0-9]+') == 0
		return 'tabstop'
	endif
endfunction

function! s:InitPlaceholder(current, type)
	if a:type == 'normal'
		call s:InitNormal(a:current)
	elseif a:type == 'command'
		call s:InitCommand(a:current)
	elseif a:type == 'choice'
		call s:InitChoice(a:current)
	elseif a:type == 'tabstop'
		call s:InitTabstop(a:current)
	endif
endfunction

function! s:RemoveTrailings(text)
	let l:result = substitute(a:text, '\n\+$', '', '')
	let l:result = substitute(l:result, '\s\+$', '', '')
	let l:result = substitute(l:result, '^\s\+', '', '')
	let l:result = substitute(l:result, '^\n\+', '', '')
	return l:result
endfunction

function! s:InitRepeaters(current, content, count)
	let l:save_s = @s
	let l:save_quote = @"
	let @s = a:content
	let l:repeater_count = a:count
	let l:amount_of_lines = len(split(a:content, "\\n"))
	let l:i = 0
	let save_q_mark = getpos("'q")
	let save_p_mark = getpos("'p")
	while l:i < l:repeater_count
		call cursor(s:snip_start, 1)
		call search('\v\$'.a:current, 'c', s:snip_end)
		normal! mq
		call search('\v\$'.a:current, 'ce', s:snip_end)
		normal! mp
		exe "normal! g`qvg`pr"
		if l:amount_of_lines > 1
			let s:snip_end += l:amount_of_lines - 1
		endif
		normal! "sp
		let l:i += 1
	endwhile
	call setpos("'q", save_q_mark)
	call setpos("'p", save_p_mark)
	let @s = l:save_s
	let @" = l:save_quote
	call cursor(s:snip_start, 1)
	if l:amount_of_lines != 1
		let s:snip_end -= 1
	endif
endfunction

" 7.4 compability layer
function! s:Execute(command, ...)
	if a:0 != 0
		let l:silent = a:1
	else
		let l:silent = ""
	endif
	if exists("*execute")
		let l:result = execute(a:command, l:silent)
	else
		redir => l:result
		if l:silent == "silent"
			silent execute a:command
		elseif l:silent == "silent!"
			silent! execute a:command
		else
			execute a:command
		endif
		redir END
	endif
	return l:result
endfunction


" Debug functions
function! SimpleSnippets#printJumpStackState(t)
	let l:i = 0
	for item in s:jump_stack
		if l:i != s:current_jump - 1
			echon string(item)
		else
			echon "[".string(item)."]"
		endif
		if l:i != len(s:jump_stack) - 1
			echon ", "
		endif
		let l:i += 1
	endfor
	echon " | jump: ". s:current_jump
	echon " | type: ". s:type_stack[s:current_jump - 1]
	redraw
	exec "sleep ".a:t
endfunction

