let s:flash_snippets = {}
let s:escape_pattern = '/\*~.$^!#'

function! SimpleSnippets#core#isInside()
	if s:snippet.curr_file == @%
		let l:current_line = line(".")
		if l:current_line >= s:snippet.start && l:current_line <= s:snippet.end
			return 1
		endif
	endif
	return 0
endfunction

function! SimpleSnippets#core#getAvailableSnippetsDict()
	let l:filetype = s:GetMainFiletype(g:SimpleSnippets_similar_filetypes)
	let l:snippets = {}
	let l:user_snips = g:SimpleSnippets_search_path
	let l:snippets = s:GetSnippetDictonary(l:snippets, l:user_snips, l:filetype)
	if exists('g:SimpleSnippets_snippets_plugin_path')
		let l:plugin_filetype = s:GetMainFiletype(g:SimpleSnippets_snippets_similar_filetypes)
		let l:plug_snips = g:SimpleSnippets_snippets_plugin_path
		let l:snippets = s:GetSnippetDictonary(l:snippets, l:plug_snips, l:plugin_filetype)
	endif
	if l:filetype != 'all'
		let l:snippets = s:GetSnippetDictonary(l:snippets, l:user_snips, 'all')
		if exists('g:SimpleSnippets_snippets_plugin_path')
			let l:snippets = s:GetSnippetDictonary(l:snippets, l:plug_snips, 'all')
		endif
	endif
	if s:flash_snippets != {}
		for trigger in keys(s:flash_snippets)
			let l:snippets[trigger] = substitute(s:flash_snippets[trigger], '\v\$\{[0-9]+(:|!)(.{-})\}', '\2', &gd ? 'gg' : 'g')
		endfor
	endif
	return l:snippets
endfunction

function! s:GetSnippetDictonary(dict, path, filetype)
	if isdirectory(a:path . a:filetype . '/')
		let l:dir = system('ls '. a:path . a:filetype . '/')
		let l:dir = substitute(l:dir, '\n\+$', '', '')
		let l:dir_list = split(l:dir)
		for i in l:dir_list
			let l:descr = ''
			for line in readfile(a:path.a:filetype.'/'.i)
				let l:descr .= substitute(line, '\v\$\{[0-9]+(:|!)(.{-})\}', '\2', &gd ? 'gg' : 'g')
				break
			endfor
			let l:descr = substitute(l:descr, '\v(\S+)(\})', '\1 \2', &gd ? 'gg' : 'g')
			let l:descr = substitute(l:descr, '\v\{(\s+)?$', '', &gd ? 'gg' : 'g')
			let a:dict[i] = l:descr
		endfor
	endif
	if filereadable(a:path . a:filetype . '/' . a:filetype .'.snippets.descriptions.txt')
		for i in readfile(a:path . a:filetype. '/' . a:filetype . '.snippets.descriptions.txt')
			let l:trigger = matchstr(i, '\v^.{-}(:)@=')
			let l:descr = substitute(matchstr(i, '\v(^.{-}:)@<=.*'), '^\s*\(.\{-}\)\s*$', '\1', '')
			let a:dict[l:trigger] = l:descr
		endfor
	endif
	if has_key(a:dict, a:filetype.'.snippets.descriptions.txt')
		unlet! a:dict[a:filetype.'.snippets.descriptions.txt']
	endif
	if a:filetype != 'all'
		if has_key(a:dict, 'all.snippets.descriptions.txt')
			unlet! a:dict['all.snippets.descriptions.txt']
		endif
	endif
	for key in keys(a:dict)
		if key =~ '\v'.escape(&bex, s:escape_pattern).'$'
			unlet! a:dict[key]
		endif
	endfor
	return a:dict
endfunction



function! s:ListSnippets()
	let l:filetype = s:GetMainFiletype(g:SimpleSnippets_similar_filetypes)
	let l:user_snips = g:SimpleSnippets_search_path
	call s:PrintSnippets("User snippets:", l:user_snips, l:filetype)
	if s:flash_snippets != {}
		let l:string = ''
		echo 'Flash snippets:'
		for snippet in s:flash_snippets
			let l:item = join(snippet, ": ")
			let l:string .= l:item .'\n'
		endfor
		echo system('echo ' . shellescape(l:string) . '| nl')
	endif
	if exists('g:SimpleSnippets_snippets_plugin_path')
		let l:plug_snips = g:SimpleSnippets_snippets_plugin_path
		let l:plugin_filetype = s:GetMainFiletype(g:SimpleSnippets_snippets_similar_filetypes)
		call s:PrintSnippets("Plugin snippets:", l:plug_snips, l:plugin_filetype)
	endif
	if l:filetype != 'all'
		call s:PrintSnippets('User \"all\" snippets:', l:user_snips, 'all')
		if exists('g:SimpleSnippets_snippets_plugin_path')
			call s:PrintSnippets('Plugin \"all\" snippets:', l:plug_snips, 'all')
		endif
	endif
endfunction

function! s:PrintSnippets(message, path, filetype)
	let l:snippets = {}
	let l:snippets = s:GetSnippetDictonary(l:snippets, a:path, a:filetype)
	if !empty(l:snippets)
		let l:max = 0
		for key in keys(l:snippets)
			let l:len = len(key) + 2
			if l:len > l:max
				let l:max = l:len
			endif
		endfor
		echo a:message
		echo "\n"
		let l:string = string(l:snippets)
		let l:string = substitute(l:string, "',", '\n', &gd ? 'gg' : 'g')
		let l:string = substitute(l:string, " '", '', &gd ? 'gg' : 'g')
		let l:string = substitute(l:string, "{'", '', &gd ? 'gg' : 'g')
		let l:string = substitute(l:string, "'}", '', &gd ? 'gg' : 'g')
		let l:list = split(l:string, '\n')
		let i = 0
		for l:str in l:list
			let l:trigger_len = len(matchstr(l:list[i], ".*':"))
			let l:amount_of_spaces = l:max - l:trigger_len + 3
			let j = 0
			let l:delimeter = ':'
			while j <= l:amount_of_spaces
				let l:delimeter .= ' '
				let j += 1
			endwhile
			let l:list[i] = substitute(l:str, "':", l:delimeter, &gd ? 'gg' : 'g')
			let i += 1
		endfor
		let l:string = join(l:list, "\n")
		let l:string = substitute(l:string, "':", ': ', &gd ? 'gg' : 'g')
		let l:string = substitute(l:string, '\\n', '\\\n', &gd ? 'gg' : 'g')
		let l:string = substitute(l:string, '\\r', '\\\\r', &gd ? 'gg' : 'g')
		echon l:string
		echo "\n"
	endif
endfunction

function! SimpleSnippets#core#expand()
	let s:snippet = {
		\'start': 0,
		\'end': 0,
		\'line_count': 0,
		\'curr_file': '',
		\'ft': '',
		\'trigger': '',
		\'visual': '',
		\'body': [],
		\'ph_amount': 0,
		\'ts_amount': 0,
		\'ph_data': {},
		\'jump_cnt': 0,
	\}
	let s:snippet.trigger = s:trigger
	let s:snippet.ft = s:GetSnippetFiletype(s:snippet.trigger)
	if s:snippet.ft == 'flash'
		let s:snippet.body = split(s:flash_snippets[s:snippet.trigger], '\n')
		let s:snippet.body = s:PrepareSnippetBodyForParser(s:snippet.body)
		let s:snippet.line_count = len(s:snippet.body)
		call s:ExpandFlash()
	else
		let s:snippet.body = s:ObtainSnippet()
		let s:snippet.body = s:PrepareSnippetBodyForParser(s:snippet.body)
		let s:snippet.line_count = len(s:snippet.body)
		call s:ExpandNormal()
	endif
endfunction

function! s:ObtainSnippet()
	let l:path = s:GetSnippetPath(s:snippet.trigger, s:snippet.ft)
	let l:snippet = readfile(l:path)
	while l:snippet[0] == ''
		call remove(l:snippet, 0)
	endwhile
	while l:snippet[-1] == ''
		call remove(l:snippet, -1)
	endwhile
	return l:snippet
endfunction

function! s:GetSnippetPath(snip, filetype)
	if filereadable(g:SimpleSnippets_search_path . a:filetype . '/' . a:snip)
		return g:SimpleSnippets_search_path . a:filetype . '/' . a:snip
	elseif exists('g:SimpleSnippets_snippets_plugin_path')
		if filereadable(g:SimpleSnippets_snippets_plugin_path . a:filetype . '/' . a:snip)
			return g:SimpleSnippets_snippets_plugin_path . a:filetype . '/' . a:snip
		endif
	endif
endfunction

function! s:ExpandNormal()
	if s:snippet.line_count != 0
		let l:save_s = @s
		let @s = join(s:snippet.body, "\n")
		let l:save_quote = @"
		if s:snippet.trigger =~ "\\W"
			normal! ciW
		else
			normal! ciw
		endif
		normal! "sp
		let s:snippet.start = line(".")
		let s:snippet.end = s:snippet.start + s:snippet.line_count - 1
		let @" = l:save_quote
		let @s = l:save_s
		call s:ParseAndInit()
	else
		echohl ErrorMsg
		echo '[ERROR] Snippet body is empty'
		echohl None
	endif
endfunction

function! s:ExpandFlash()
	let l:save_quote = @"
	if s:snippet.trigger =~ "\\W"
		normal! ciW
	else
		normal! ciw
	endif
	let l:save_s = @s
	let @s = s:snippet.body
	normal! "sp
	let s:snippet.start = line(".")
	let s:snippet.end = s:snippet.start + s:snippet.line_count - 1
	let @s = l:save_s
	if s:snippet.line_count != 1
		let l:indent_lines = s:snippet.line_count - 1
		silent exec 'normal! V' . l:indent_lines . 'j='
	else
		normal! ==
	endif
	silent call s:ParseAndInit()
endfunction

function! s:GetSnippetFiletype(snip)
	let l:filetype = s:GetMainFiletype(g:SimpleSnippets_similar_filetypes)
	if filereadable(g:SimpleSnippets_search_path . l:filetype . '/' . a:snip)
		return l:filetype
	endif
	if s:checkFlashSnippetExists(a:snip)
		return 'flash'
	endif
	if exists('g:SimpleSnippets_snippets_plugin_path')
		let l:plugin_filetype = s:GetMainFiletype(g:SimpleSnippets_snippets_similar_filetypes)
		if filereadable(g:SimpleSnippets_snippets_plugin_path . l:plugin_filetype . '/' . a:snip)
			return l:plugin_filetype
		endif
	endif
	if filereadable(g:SimpleSnippets_search_path . 'all/' . a:snip)
		return 'all'
	endif
	if exists('g:SimpleSnippets_snippets_plugin_path')
		if filereadable(g:SimpleSnippets_snippets_plugin_path . 'all/' . a:snip)
			return 'all'
		endif
	endif
	return -1
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

function! s:checkFlashSnippetExists(snip)
	if has_key(s:flash_snippets, a:snip)
		return 1
	endif
	return 0
endfunction

function! SimpleSnippets#core#addFlashSnippet(trigger, snippet_defenition)
	let s:flash_snippets[a:trigger] = a:snippet_defenition
endfunction

function! SimpleSnippets#core#removeFlashSnippet(trigger)
	let l:i = 0
	if has_key(s:flash_snippets, a:trigger)
		unlet![a:trigger]
	endif
endfunction

function! SimpleSnippets#core#obtainVisual()
	let l:save_v = @v
	normal! g`<vg`>"vc
	let s:snippet.visual = @v
	let @v = l:save_v
	startinsert!
endif