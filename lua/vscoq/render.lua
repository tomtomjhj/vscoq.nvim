local M = {}

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

---@param pp_root vscoq.PpString
---@return string
function M.PpString(pp_root)
  if not pp_root.size then
    PpString_compute_sizes(pp_root)
  end

  local lines = {} ---@type string[]
  local cur_line = {} ---@type string[]
  local space = LINE_SIZE ---@type integer remaining space in cur_line
  ---@type {space: integer, mode: 0|1|2}[] box stack. 0: no break. 1: break as needed. 2: break all
  local stack = {}

  local function output(str, size)
    cur_line[#cur_line + 1] = str
    space = space - size
  end

  for cmd, pp in PpString_iter(pp_root) do
    if cmd == Enter then
      if pp[1] == 'Ppcmd_string' then
        ---@cast pp vscoq.PpString.Ppcmd_string
        output(pp[2], pp.size)
      elseif pp[1] == 'Ppcmd_box' then
        ---@cast pp vscoq.PpString.Ppcmd_box
        local mode
        if pp[2][1] == 'Pp_hbox' then
          mode = 0
        elseif pp[2][1] == 'Pp_vbox' then
          mode = 2
        elseif pp[2][1] == 'Pp_hvbox' then
          mode = pp.size > space and 2 or 0
        elseif pp[2][1] == 'Pp_hovbox' then
          mode = 1
        end
        table.insert(stack, { space = space - (pp[2][2] or 0), mode = mode })
      elseif pp[1] == 'Ppcmd_tag' then
        ---@cast pp vscoq.PpString.Ppcmd_tag
        -- TODO: handle tags. start extmark
      elseif pp[1] == 'Ppcmd_print_break' then
        ---@cast pp vscoq.PpString.Ppcmd_print_break
        -- NOTE: CoqMessage contains breaks without enclosing box.
        -- This behaves like regular text wrapping.
        local top = #stack > 0 and stack[#stack] or { mode = 1, space = LINE_SIZE }
        if top.mode > 0 and (pp.size > space or top.mode == 2) then
          space = top.space - pp[3]
          lines[#lines + 1] = table.concat(cur_line)
          cur_line = { string.rep(' ', LINE_SIZE - space) }
        else
          output(string.rep(' ', pp[2]), pp[2])
        end
      elseif pp[1] == 'Ppcmd_force_newline' then
        ---@cast pp vscoq.PpString.Ppcmd_force_newline
        if #stack > 0 then
          space = stack[#stack].space
        end
        lines[#lines + 1] = table.concat(cur_line)
        cur_line = { string.rep(' ', LINE_SIZE - space) }
      end
    else
      if pp[1] == 'Ppcmd_box' then
        table.remove(stack)
      elseif pp[1] == 'Ppcmd_tag' then
        -- TODO: handle tags. end extmark
      end
    end
  end

  if #cur_line > 0 then
    lines[#lines + 1] = table.concat(cur_line)
  end

  return table.concat(lines, '\n')
end

---@param goal vscoq.Goal
---@param i integer
---@param n integer
---@return string[]
function M.goal(i, n, goal)
  local lines = {}
  lines[#lines + 1] = string.format('Goal %d (%d / %d)', goal.id, i, n)
  for _, hyp in ipairs(goal.hypotheses) do
    vim.list_extend(lines, vim.split(M.PpString(hyp), '\n'))
  end
  lines[#lines + 1] = ''
  lines[#lines + 1] = '========================================'
  lines[#lines + 1] = ''
  vim.list_extend(lines, vim.split(M.PpString(goal.goal), '\n'))
  return lines
end

---@param goals vscoq.Goal[]
---@return string[]
function M.goals(goals)
  local lines = {}
  for i, goal in ipairs(goals) do
    if i > 1 then
      lines[#lines + 1] = ''
      lines[#lines + 1] = ''
      lines[#lines + 1] =
        '────────────────────────────────────────────────────────────'
      lines[#lines + 1] = ''
    end
    vim.list_extend(lines, M.goal(i, #goals, goal))
  end
  return lines
end

---@param messages vscoq.CoqMessage[]
---@return string[]
function M.CoqMessages(messages)
  local lines = {}
  for _, message in ipairs(messages) do
    lines[#lines + 1] = ({ 'Error', 'Warning', 'Information' })[message[1]] .. ':'
    vim.list_extend(lines, vim.split(M.PpString(message[2]), '\n'))
  end
  return lines
end

---@param proofView vscoq.ProofViewNotification
---@return string[]
function M.ProofView(proofView)
  local lines = {}
  if proofView.proof then
    vim.list_extend(lines, M.goals(proofView.proof.goals))
  end
  if #proofView.messages > 0 then
    lines[#lines + 1] = ''
    lines[#lines + 1] = ''
    lines[#lines + 1] =
      'Messages ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    lines[#lines + 1] = ''
    vim.list_extend(lines, M.CoqMessages(proofView.messages))
  end
  if proofView.proof then
    if #proofView.proof.shelvedGoals > 0 then
      lines[#lines + 1] = ''
      lines[#lines + 1] = ''
      lines[#lines + 1] =
        'Shelved ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
      lines[#lines + 1] = ''
      vim.list_extend(lines, M.goals(proofView.proof.shelvedGoals))
    end
    if #proofView.proof.givenUpGoals > 0 then
      lines[#lines + 1] = ''
      lines[#lines + 1] = ''
      lines[#lines + 1] =
        'Given Up ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
      lines[#lines + 1] = ''
      vim.list_extend(lines, M.goals(proofView.proof.givenUpGoals))
    end
  end
  return lines
end

---@param result vscoq.SearchCoqResult
---@return string[]
function M.searchCoqResult(result)
  local lines = {}
  vim.list_extend(lines, vim.split(M.PpString(result.name), '\n'))
  lines[#lines] = lines[#lines] .. ':'
  -- NOTE: the result from server doesn't have linebreaks
  local statement_lines = vim.split(M.PpString(result.statement), '\n')
  for _, l in ipairs(statement_lines) do
    lines[#lines + 1] = '  ' .. l
  end
  lines[#lines + 1] = ''
  return lines
end

return M
