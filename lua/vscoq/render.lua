local M = {}

-- See pp.tsx.
---@param pp vscoq.PpString
---@param mode? "horizontal"|"vertical"
---@return string
function M.PpString(pp, mode)
  mode = mode or 'horizontal'
  if pp[1] == 'Ppcmd_empty' then
    return ''
  elseif pp[1] == 'Ppcmd_string' then
    return pp[2] --[[@as string]]
  elseif pp[1] == 'Ppcmd_glue' then
    return table.concat(
      vim.tbl_map(function(p)
        return M.PpString(p, mode)
      end, pp[2] --[=[@as vscoq.PpString[]]=]),
      ''
    )
  elseif pp[1] == 'Ppcmd_box' then
    if pp[2][1] == 'Pp_hbox' then
      mode = 'horizontal'
    elseif pp[2][1] == 'Pp_vbox' then
      mode = 'vertical'
    -- TODO: proper support for hvbox and hovbox (not implemented in vscode client either)
    elseif pp[2][1] == 'Pp_hvbox' then
      mode = 'horizontal'
    elseif pp[2][1] == 'Pp_hovbox' then
      mode = 'horizontal'
    end
    return M.PpString(pp[3] --[[@as vscoq.PpString]], mode)
  elseif pp[1] == 'Ppcmd_tag' then
    -- TODO: use PpTag for highlighting (difficult)
    return M.PpString(pp[3] --[[@as vscoq.PpString]], mode)
  elseif pp[1] == 'Ppcmd_print_break' then
    if mode == 'horizontal' then
      return string.rep(' ', pp[2] --[[@as integer]])
    elseif mode == 'vertical' then
      return '\n'
    end
    error()
  elseif pp[1] == 'Ppcmd_force_newline' then
    return '\n'
  elseif pp[1] == 'Ppcmd_comment' then
    return vim.inspect(pp[2])
  end
  error(pp[1])
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
