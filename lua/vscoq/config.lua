local Config = {}

---@type vscoq.Config
Config.default = {
  memory = {
    limit = 4,
  },
  goals = {
    -- used for initAppSettings
    display = 'List',
    diff = {
      mode = 'off',
    },
    messages = {
      full = true,
    },
    maxDepth = 17,
  },
  proof = {
    mode = 'Manual',
    pointInterpretationMode = 'Cursor',
    cursor = {
      sticky = true,
    },
    delegation = 'None',
    workers = 1,
    block = true,
  },
  completion = {
    enable = false,
    unificationLimit = 100,
    algorithm = 'SplitTypeIntersection',
  },
  diagnostics = {
    full = false,
  },
}

---@paramter value any
---@paramter type_expected string
---@paramter key_name string
---@return boolean
local function check_type(type_expected, value, key_name)
  local type_value = type(value)
  if type_value == type_expected then
    return true
  else
    local msg = string.format(
      "[vscoq.nvim] Key '%s' have type '%s' expected type '%s'.",
      key_name,
      type_value,
      type_expected
    )
    print(msg)
    return false
  end
end

---@parameter expected @string
---@return boolean
local function check_values(list_expected, value, key_name)
  for _, expected in pairs(list_expected) do
    if expected == value then
      return true
    end
  end
  local msg = string.format(
    "[vscoq.nvim] Key '%s' as value '%s' but expected '%s'.",
    key_name,
    value,
    table.concat(list_expected, "' or '")
  )
  print(msg)
  return false
end

local goal_display_keys = { 'Tabs', 'List' }
local goal_diff_keys = { 'off', 'on', 'removed' }
local proof_mode_keys = { 'Manual', 'Continuous' }
local proof_pointInterpretationMode_keys = { 'Cursor', 'NextCommand' }
local proof_delegation_keys = { 'None', 'Skip', 'Delegate' }
local completion_algorithm_keys = { 'StructuredSplitUnification', 'SplitTypeIntersection' }

---@parameter config @vscoq.Config
function Config.check(config)
  local ok = true
  ok = check_type('number', config.memory.limit, 'vscoq.memory.limit') and ok

  ok = check_values(goal_display_keys, config.goals.display, 'vscoq.goals.display') and ok
  ok = check_values(goal_diff_keys, config.goals.diff.mode, 'vscoq.goals.diff.mode') and ok
  ok = check_type('boolean', config.goals.messages.full, 'vscoq.goals.messages.full') and ok
  ok = check_type('number', config.goals.maxDepth, 'vscoq.goals.maxDepth') and ok

  ok = check_values(proof_mode_keys, config.proof.mode, 'vscoq.proof.mode') and ok
  ok = check_values(
    proof_pointInterpretationMode_keys,
    config.proof.pointInterpretationMode,
    'config.proof.pointInterpretationMode'
  ) and ok
  ok = check_type('boolean', config.proof.cursor.sticky, 'vscoq.proof.cursor.sticky') and ok
  ok = check_values(proof_delegation_keys, config.proof.delegation, 'config.proof.delegation')
    and ok
  ok = check_type('number', config.proof.workers, 'vscoq.proof.workers') and ok
  ok = check_type('boolean', config.proof.block, 'vscoq.proof.block') and ok

  ok = check_type('boolean', config.completion.enable, 'vscoq.completion.enable') and ok
  ok = check_type('number', config.completion.unificationLimit, 'vscoq.completion.unificationLimit')
    and ok
  ok = check_values(
    completion_algorithm_keys,
    config.completion.algorithm,
    'vscoq.completion.algorithm'
  ) and ok

  ok = check_type('boolean', config.diagnostics.full, 'vscoq.diagnostics.full') and ok

  assert(ok)
end

local proof_mode_table = {
  Manual = 0,
  Continuous = 1,
}

local proof_pointInterpretationMode_table = {
  Cursor = 0,
  NextCommand = 1,
}

local completion_algorithm_table = {
  StructuredSplitUnification = 0,
  SplitTypeIntersection = 1,
}

---@param opts_vscoq vscoq.Config
---@return vscoq.LspConfig
function Config.make_lsp_options(opts_vscoq)
  local opts = vim.deepcopy(opts_vscoq)

  if opts.proof and opts.proof.mode then
    opts.proof.mode = proof_mode_table[opts.proof.mode]
  end

  if opts.proof and opts.proof.pointInterpretationMode then
    opts.proof.pointInterpretationMode =
      proof_pointInterpretationMode_table[opts.proof.pointInterpretationMode]
  end

  if opts.completion and opts.completion.algorithm then
    opts.completion.algorithm = completion_algorithm_table[opts.completion.algorithm]
  end

  return opts
end

return Config
