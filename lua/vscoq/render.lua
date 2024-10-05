local M = {}

local pp = require('vscoq.pp')
local TaggedLines = require('vscoq.tagged_lines')

---@param goal vscoq.Goal
---@param i integer
---@param n integer
---@return vscoq.TaggedLines
function M.goal(i, n, goal)
  local tl = TaggedLines.new()
  tl:add_line(string.format('Goal %d (%d / %d)', goal.id, i, n))
  for _, hyp in ipairs(goal.hypotheses) do
    tl:append(pp(hyp))
  end
  tl:add_line('')
  tl:add_line('========================================')
  tl:add_line('')
  tl:append(pp(goal.goal))
  return tl
end

---@param goals vscoq.Goal[]
---@return string[]
function M.goals(goals)
  local tl = TaggedLines.new()
  for i, goal in ipairs(goals) do
    if i > 1 then
      tl:add_line('')
      tl:add_line('')
      tl:add_line(
        '────────────────────────────────────────────────────────────'
      )
      tl:add_line('')
    end
    tl:append(M.goal(i, #goals, goal))
  end
  return tl
end

vim.cmd([[
hi def link VsCoqError DiagnosticError
hi def link VsCoqWarn DiagnosticWarn
hi def link VsCoqInfo DiagnosticInfo
hi def link VsCoqHint DiagnosticHint
]])

-- NOTE
-- * no severity tag in pp
-- * output of `info_eauto` is multiple messages
---@param messages vscoq.CoqMessage[]
---@return vscoq.TaggedLines
function M.CoqMessages(messages)
  local tl = TaggedLines.new()
  for _, message in ipairs(messages) do
    tl:append(pp {
      'Ppcmd_tag',
      ({ 'VsCoqError', 'VsCoqWarn', 'VsCoqInfo', 'VsCoqHint' })[message[1]],
      message[2],
    })
  end
  return tl
end

---@param proofView vscoq.ProofViewNotification
---@param items ('goals'|'messages'|'shelvedGoals'|'givenUpGoals')[]
---@return vscoq.TaggedLines
function M.proofView(proofView, items)
  local tl = TaggedLines.new()

  if proofView.proof then
    local stat = {}
    if #proofView.proof.goals > 0 then
      stat[#stat + 1] = #proofView.proof.goals .. ' goals'
    end
    if #proofView.proof.shelvedGoals > 0 then
      stat[#stat + 1] = #proofView.proof.shelvedGoals .. ' shelved'
    end
    if #proofView.proof.givenUpGoals > 0 then
      stat[#stat + 1] = #proofView.proof.givenUpGoals .. ' admitted'
    end
    if #stat > 0 then
      tl:add_line(table.concat(stat, ', '))
    end
  end

  for i, item in ipairs(items) do
    local function padding()
      if i > 1 then
        tl:add_line('')
        tl:add_line('')
      end
    end
    if proofView.proof then
      if item == 'goals' then
        if #proofView.proof.goals > 0 then
          tl:append(M.goals(proofView.proof.goals))
        elseif #proofView.proof.unfocusedGoals > 0 then
          tl:add_line('This subproof is complete.')
          tl:add_line('')
          tl:add_line(
            'Next unfocused subgoals ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
          )
          tl:add_line('')
          tl:append(M.goals(proofView.proof.unfocusedGoals))
        elseif #proofView.proof.givenUpGoals > 0 then
          tl:add_line('No more subgoals, but there are some admitted subgoals.')
          tl:add_line('Go back and solve them, or use `Admitted.`')
        elseif #proofView.proof.shelvedGoals > 0 then
          tl:add_line('No more subgoals, but there are some shelved subgoals. Try `Unshelve.`')
        else
          tl:add_line('There are no more subgoals')
        end
      elseif item == 'shelvedGoals' then
        padding()
        tl:add_line(
          'Shelved ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
        )
        tl:add_line('')
        tl:append(M.goals(proofView.proof.shelvedGoals))
      elseif item == 'givenUpGoals' then
        padding()
        tl:add_line(
          'Given Up ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
        )
        tl:add_line('')
        tl:append(M.goals(proofView.proof.givenUpGoals))
      end
    end
  end

  return tl
end

---@param result vscoq.SearchCoqResult
---@return vscoq.TaggedLines
function M.searchCoqResult(result)
  local tl = TaggedLines.new()
  tl:append(pp(result.name))
  tl:append(pp(result.statement))
  tl:add_line('')
  return tl
end

return M
