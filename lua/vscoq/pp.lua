-- Pretty printing PpString, based on Oppen's algorithm.
-- (http://i.stanford.edu/pub/cstr/reports/cs/tr/79/770/CS-TR-79-770.pdf)
-- 1. Compute the size of each token.
--    - string: length of string
--    - block open: the distance to the matching close
--    - break: distance to the next break or block close
--    - block close: zero
--    - In the paper, this is called Scan(). We don't implement the optimized
--      algorithm since the full PpString is already in memory.
-- 2. Print
--    - string: print
--    - block open: check breaking mode, ... push stack
--    - block close: pop satck
--    - break: break or space
--
-- See also
-- * https://ocaml.org/manual/5.2/api/Format_tutorial.html
-- * vscoq's implementation: https://github.com/coq-community/vscoq/pull/900
-- * related: https://www.reddit.com/r/ProgrammingLanguages/comments/vzp7td/pretty_printing_which_paper/

local TaggedLines = require('vscoq.tagged_lines')

---@alias Enter 0
local Enter = 0
---@alias Leave 1
local Leave = 1

-- Iterative traversal of PpString
---@param pp_root vscoq.PpString
---@return fun(): Enter|Leave?, vscoq.PpString
local function PpString_iter(pp_root)
  ---@type {pp: vscoq.PpString, i?: integer}[]
  local stack = { { pp = pp_root } }

  local function iter()
    while #stack > 0 do
      local frame = stack[#stack]
      local pp = frame.pp
      if not frame.i then
        frame.i = 1
        return Enter, pp
      end

      local child ---@type vscoq.PpString?
      if pp[1] == 'Ppcmd_glue' then
        ---@cast pp vscoq.PpString.Ppcmd_glue
        child = pp[2][frame.i]
      elseif pp[1] == 'Ppcmd_box' then
        ---@cast pp vscoq.PpString.Ppcmd_box
        if frame.i == 1 then
          child = pp[3]
        end
      elseif pp[1] == 'Ppcmd_tag' then
        ---@cast pp vscoq.PpString.Ppcmd_tag
        if frame.i == 1 then
          child = pp[3]
        end
      end
      if not child then
        table.remove(stack)
        return Leave, pp
      end

      frame.i = frame.i + 1
      table.insert(stack, { pp = child })
    end

    return nil
  end

  return iter
end

-- TODO: use window width. should take account of columns
local LINE_SIZE = 80

---Populates the `size` field in each PpString.
---The defintion of size follows the Oppen's algorithm.
---@param pp_root vscoq.PpString
local function PpString_compute_sizes(pp_root)
  -- first pass: size of tokens other than break.
  -- Initially, the size of break is set to the number of spaces.
  -- This gives the "righttotal" stuff in Oppen's algorithm.
  for cmd, pp in PpString_iter(pp_root) do
    if cmd == Leave then
      if pp[1] == 'Ppcmd_empty' then
        ---@cast pp vscoq.PpString.Ppcmd_empty
        pp.size = 0
      elseif pp[1] == 'Ppcmd_string' then
        ---@cast pp vscoq.PpString.Ppcmd_string
        pp.size = vim.fn.strdisplaywidth(pp[2])
      elseif pp[1] == 'Ppcmd_glue' then
        ---@cast pp vscoq.PpString.Ppcmd_glue
        pp.size = 0
        for _, child in ipairs(pp[2]) do
          pp.size = pp.size + child.size
        end
      elseif pp[1] == 'Ppcmd_box' then
        ---@cast pp vscoq.PpString.Ppcmd_box
        pp.size = pp[3].size
      elseif pp[1] == 'Ppcmd_tag' then
        ---@cast pp vscoq.PpString.Ppcmd_tag
        pp.size = pp[3].size
      elseif pp[1] == 'Ppcmd_print_break' then
        ---@cast pp vscoq.PpString.Ppcmd_print_break
        pp.size = pp[2]
      elseif pp[1] == 'Ppcmd_force_newline' then
        ---@cast pp vscoq.PpString.Ppcmd_force_newline
        pp.size = LINE_SIZE
      elseif pp[1] == 'Ppcmd_comment' then
        ---@cast pp vscoq.PpString.Ppcmd_comment
        pp.size = 0
      end
    end
  end

  -- second pass: size of breaks, i.e., distance to the next break/close
  for cmd, pp in PpString_iter(pp_root) do
    if cmd == Leave and pp[1] == 'Ppcmd_glue' then
      ---@cast pp vscoq.PpString.Ppcmd_glue
      local last_break_i ---@type integer?
      for i, child_i in ipairs(pp[2]) do
        if child_i[1] == 'Ppcmd_print_break' then
          ---@cast child_i vscoq.PpString.Ppcmd_print_break
          local size = 0
          for j = i + 1, #pp[2], 1 do
            local child_j = pp[2][j]
            if child_j[1] == 'Ppcmd_print_break' then
              break
            else
              size = size + child_j.size
            end
          end
          child_i.size = size
          last_break_i = i
        end
      end
      if last_break_i then
        local child_i = pp[2][last_break_i]
        local size = 0
        for j = last_break_i + 1, #pp[2], 1 do
          local child_j = pp[2][j]
          size = size + child_j.size
        end
        child_i.size = size
      end
    end
  end
end

---@class vscoq.Tag
---@field [1] integer 0-indexed offset of the start line
---@field [2] integer start col
---@field [3] integer end line offset
---@field [4] integer end col
---@field [0] string

---@param pp_root vscoq.PpString
---@return vscoq.TaggedLines
local function PpString(pp_root)
  if not pp_root.size then
    PpString_compute_sizes(pp_root)
  end

  local lines = {} ---@type string[]
  local cur_line = {} ---@type string[]
  local tags = {} ---@type vscoq.Tag[]
  local cursor = 0 ---@type integer the 0-indexed position (strdisplaywidth) of the next output
  local cursor_byte = 0 --- like `cursor`, but with byte length
  ---@type {indent: integer, mode: 0|1|2}[] 0: no break. 1: break as needed. 2: break all
  local box_stack = {}
  ---@type vscoq.Tag[]
  local tag_stack = {}

  local function output(str, size)
    cur_line[#cur_line + 1] = str
    cursor = cursor + size
    cursor_byte = cursor_byte + #str
  end

  for cmd, pp in PpString_iter(pp_root) do
    if cmd == Enter then
      if pp[1] == 'Ppcmd_string' then
        ---@cast pp vscoq.PpString.Ppcmd_string
        for i, s in ipairs(vim.split(pp[2], '\n')) do
          -- handle multi-line string. no indent.
          if i > 1 then
            cursor, cursor_byte = 0, 0
            lines[#lines + 1] = table.concat(cur_line)
            cur_line = {}
          end
          output(s, vim.fn.strdisplaywidth(s))
        end
      elseif pp[1] == 'Ppcmd_box' then
        ---@cast pp vscoq.PpString.Ppcmd_box
        local mode
        if pp[2][1] == 'Pp_hbox' then
          mode = 0
        elseif pp[2][1] == 'Pp_vbox' then
          mode = 2
        elseif pp[2][1] == 'Pp_hvbox' then
          mode = cursor + pp.size > LINE_SIZE and 2 or 0
        elseif pp[2][1] == 'Pp_hovbox' then
          mode = 1
        end
        table.insert(box_stack, { indent = cursor + (pp[2][2] or 0), mode = mode })
      elseif pp[1] == 'Ppcmd_tag' then
        ---@cast pp vscoq.PpString.Ppcmd_tag
        table.insert(tag_stack, { #lines, cursor_byte, [0] = pp[2] })
      elseif pp[1] == 'Ppcmd_print_break' then
        ---@cast pp vscoq.PpString.Ppcmd_print_break
        -- NOTE: CoqMessage contains breaks without enclosing box.
        -- This behaves like regular text wrapping.
        local top = #box_stack > 0 and box_stack[#box_stack] or { mode = 1, indent = 0 }
        if top.mode > 0 and (cursor + pp.size > LINE_SIZE or top.mode == 2) then
          cursor = top.indent + pp[3]
          cursor_byte = cursor
          lines[#lines + 1] = table.concat(cur_line)
          cur_line = { string.rep(' ', cursor) }
        else
          output(string.rep(' ', pp[2]), pp[2])
        end
      elseif pp[1] == 'Ppcmd_force_newline' then
        ---@cast pp vscoq.PpString.Ppcmd_force_newline
        local top = #box_stack > 0 and box_stack[#box_stack] or { mode = 1, indent = 0 }
        cursor = top.indent
        cursor_byte = cursor
        lines[#lines + 1] = table.concat(cur_line)
        cur_line = { string.rep(' ', cursor) }
      end
    else
      if pp[1] == 'Ppcmd_box' then
        table.remove(box_stack)
      elseif pp[1] == 'Ppcmd_tag' then
        local tag = table.remove(tag_stack) ---@type vscoq.Tag
        tag[3] = #lines
        tag[4] = cursor_byte
        table.insert(tags, tag)
      end
    end
  end

  if #cur_line > 0 then
    lines[#lines + 1] = table.concat(cur_line)
  end

  return TaggedLines.new(lines, tags)
end

return PpString
