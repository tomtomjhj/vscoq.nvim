local Config = {}

---@class vscoq.Config
Config.default = {
  memory = {
    ---@type integer
    limit = 4,
  },
  goals = {
    -- used for initAppSettings
    ---@type "Tabs"|"List"
    display = 'List',
    diff = {
      ---@type "off"|"on"|"removed"
      mode = 'off',
    },
    messages = {
      ---@type boolean
      full = true,
    },
    maxDepth = 17,
  },
  proof = {
    ---@type "Manual"|"Continuous"
    mode = 'Manual',
    ---@type "Cursor"|"NextCommand"
    pointInterpretationMode = 'Cursor',
    cursor = {
      ---@type boolean
      sticky = true,
    },
    ---@type "None"|"Skip"|"Delegate"
    delegation = 'None',
    ---@type integer
    workers = 1,
    block = true,
  },
  completion = {
    ---@type boolean
    enable = false,
    ---@type integer
    unificationLimit = 100,
    ---@type "StructuredSplitUnification" | "SplitTypeIntersection"
    algorithm = 'SplitTypeIntersection',
  },
  diagnostics = {
    ---@type boolean
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
---@return table<string,any>
function Config.make_lsp_init_options(opts_vscoq)
  local init_options = vim.deepcopy(opts_vscoq)
  init_options.proof.mode = proof_mode_table[init_options.proof.mode]
  init_options.proof.pointInterpretationMode =
    proof_pointInterpretationMode_table[init_options.proof.pointInterpretationMode]
  init_options.completion.algorithm = completion_algorithm_table[init_options.completion.algorithm]
  return init_options
end

return Config
