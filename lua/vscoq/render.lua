local M = {}

local pp = require('vscoq.pp')


---@param goal vscoq.Goal
---@param i integer
---@param n integer
---@return string[]
function M.goal(i, n, goal)
  local lines = {}
  lines[#lines + 1] = string.format('Goal %d (%d / %d)', goal.id, i, n)
  for _, hyp in ipairs(goal.hypotheses) do
    vim.list_extend(lines, vim.split(pp(hyp), '\n'))
  end
  lines[#lines + 1] = ''
  lines[#lines + 1] = '========================================'
  lines[#lines + 1] = ''
  vim.list_extend(lines, vim.split(pp(goal.goal), '\n'))
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
    vim.list_extend(lines, vim.split(pp(message[2]), '\n'))
  end
  return lines
end

---@param result vscoq.SearchCoqResult
---@return string[]
function M.searchCoqResult(result)
  local lines = {}
  vim.list_extend(lines, vim.split(pp(result.name), '\n'))
  lines[#lines] = lines[#lines] .. ':'
  -- NOTE: the result from server doesn't have linebreaks
  local statement_lines = vim.split(pp(result.statement), '\n')
  for _, l in ipairs(statement_lines) do
    lines[#lines + 1] = '  ' .. l
  end
  lines[#lines + 1] = ''
  return lines
end

return M
