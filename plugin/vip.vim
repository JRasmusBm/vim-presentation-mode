let s:MATCH_GROUP = 'Vip'
let s:UNSTARTED = 'unstarted'
let s:FINISHED = 'finished'
let s:ACTIVE = 'active'
let s:DISABLED = 'disabled'
let s:NULL_HIGHLIGHT = {}
let s:ZERO_STATE = { 'type': s:UNSTARTED, 'highlight': s:NULL_HIGHLIGHT }

" type State
"   = Unstarted
"   | Finished
"   | Active highlight
"   | Disabled highlight

execute printf('hi '.s:MATCH_GROUP.' ctermfg=%s', 240)

function! s:state_for_current_file() abort
  return s:STATE[s:current_file_name()]
endfunction

function! s:current_file_highlights() abort
  return s:FILE_HIGHLIGHTS[s:current_file_name()]
endfunction

function! s:current_file_name() abort
  return expand('%')
endfunction

function! VipRegister(file_highlights) abort
  let s:STATE = {}
  for file in keys(a:file_highlights)
    let s:STATE[file] = s:ZERO_STATE
  endfor
  let s:FILE_HIGHLIGHTS = a:file_highlights
endfunction

function! s:highlight(highlight) abort
  call s:dim_other_lines(a:highlight)
  call s:move_cursor_to_highlight_focus_line(a:highlight)
  call s:set_state(s:ACTIVE, a:highlight)
endfunction

function! s:move_cursor_to_highlight_focus_line(highlight)
  call cursor(a:highlight.cursorLine, 1)
  normal! ^
endfunction

function! s:set_state(type, ...) abort
  let highlight = get(a:, 1, s:NULL_HIGHLIGHT)
  let s:STATE[expand('%')] = { 'type': a:type, 'highlight': highlight }
endfunction

function! s:dim_other_lines(highlight) abort
  call s:remove_matches()
  let lines_to_dim = s:lines_to_dim_from_ranges(a:highlight.ranges)
  for line in lines_to_dim
    call matchaddpos(s:MATCH_GROUP, [line], 10)
  endfor
endfunction

function! s:remove_matches() abort
  let matches = filter(getmatches(), 'v:val.group == "'.s:MATCH_GROUP.'"')
  for id in map(matches, 'v:val.id')
    call matchdelete(id)
  endfor
endfunction

function! s:disable() abort
  if s:state_for_current_file().type != s:UNSTARTED
    call s:set_state(s:DISABLED, s:state_for_current_file().highlight)
  endif
  call s:remove_matches()
endfunction! abort

function! s:enable() abort
  call s:highlight(s:state_for_current_file().highlight)
endfunction

function! s:highlight_first() abort
  call s:highlight(s:current_file_highlights()[0])
endfunction

function! s:highlight_last() abort
  call s:highlight(s:current_file_highlights()[len(s:current_file_highlights()) - 1])
endfunction

function! s:lines_to_dim_from_ranges(ranges) abort
  let lines = range(1, line('$'))
  for range in a:ranges
    for line in range(range[0], range[1])
      let index = index(lines, line)
      if index == -1
        break
      else
        call remove(lines, index(lines, line))
      end
    endfor
  endfor
  return lines
endfunction

function! s:finish_highlights() abort
  call s:remove_matches()
  call s:set_state(s:FINISHED)
endfunction

function! s:reset_to_unstarted() abort
  call s:remove_matches()
  call s:set_state(s:UNSTARTED)
endfunction

function! s:vip_next_highlight() abort
  if s:state_for_current_file().type == s:UNSTARTED
    call s:highlight_first()
  elseif s:state_for_current_file().type == s:FINISHED " no-op
  elseif s:state_for_current_file().type == s:ACTIVE
    call s:actually_highlight_next()
  elseif s:state_for_current_file().type == s:DISABLED
    call s:enable()
  else
    throw "Unexpected state type"
  endif
endfunction

function! s:vip_previous_highlight() abort
  if s:state_for_current_file().type == s:UNSTARTED " no-op
  elseif s:state_for_current_file().type == s:FINISHED
    call s:highlight_last()
  elseif s:state_for_current_file().type == s:ACTIVE
    call s:actually_highlight_previous()
  elseif s:state_for_current_file().type == s:DISABLED
    call s:enable()
  else
    throw "Unexpected state type"
  endif
endfunction

function! s:actually_highlight_previous() abort
  let index = index(s:current_file_highlights(), s:state_for_current_file().highlight)
  if index == 0
    call s:reset_to_unstarted()
  else
    if index > 0
      call s:highlight(s:current_file_highlights()[index - 1])
    endif
  endif
endfunction

function! s:actually_highlight_next() abort
  let index = index(s:current_file_highlights(), s:state_for_current_file().highlight)
  if index + 1 < len(s:current_file_highlights())
    call s:highlight(s:current_file_highlights()[index + 1])
  else
    call s:finish_highlights()
  endif
endfunction

command! VipOff call s:disable()
command! VipNextHighlight call s:vip_next_highlight()
command! VipPreviousHighlight call s:vip_previous_highlight()
