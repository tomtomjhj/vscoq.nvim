---@class vscoq.Config
local Config = {
  memory = {
    ---@type integer
    limit = 4,
  },

  goals = {
    diff = {
      ---@type "off"|"on"|"removed"
      mode = 'off',
    },

    messages = {
      ---@type boolean
      full = true,
    },

    ---@type integer
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

    ---@type boolean
    block = true,
  },

  completion = {
    ---@type boolean
    enable = false,

    ---@type integer
    unificationLimit = 100,

    ---@type "StructuredSplitUnification"|"SplitTypeIntersection"
    algorithm = 'SplitTypeIntersection',
  },

  diagnostics = {
    ---@type boolean
    full = false,
  },
}

Config.__index = Config

-- keys in config
local goals_diff_keys = { 'off', 'on', 'removed' }
local proof_delegation_keys = { 'None', 'Skip', 'Delegate' }
local proof_mode_keys = { 'Manual', 'Continuous' }
local proof_pointInterpretationMode_keys = { 'Cursor', 'NextCommand' }
local completion_algorithm_keys = { 'StructuredSplitUnification', 'SplitTypeIntersection' }

---@param opts table
---@return vscoq.Config
function Config:new(opts)
  local config = vim.tbl_deep_extend('keep', opts, self)
  vim.validate {
    ['vscoq'] = { config, 'table' },
    ['vscoq.memory'] = { config.memory, 'table' },
    ['vscoq.memory.limit'] = {
      config.memory.limit,
      function(x)
        return type(x) == 'number' and x > 0
      end,
      'positive number',
    },
    ['vscoq.goals'] = { config.goals, 'table' },
    ['vscoq.goals.diff'] = { config.goals.diff, 'table' },
    ['vscoq.goals.diff.mode'] = {
      config.goals.diff.mode,
      function(x)
        return type(x) == 'string' and vim.list_contains(goals_diff_keys, x)
      end,
      'one of ' .. table.concat(goals_diff_keys, ', '),
    },
    ['vscoq.goals.messages'] = { config.goals.messages, 'table' },
    ['vscoq.goals.messages.full'] = { config.goals.messages.full, 'boolean' },
    ['vscoq.goals.maxDepth'] = { config.goals.maxDepth, 'number' },
    ['vscoq.proof'] = { config.proof, 'table' },
    ['vscoq.proof.mode'] = {
      config.proof.mode,
      function(x)
        return type(x) == 'string' and vim.list_contains(proof_mode_keys, x)
      end,
      'one of ' .. table.concat(proof_mode_keys, ', '),
    },
    ['vscoq.proof.pointInterpretationMode'] = {
      config.proof.pointInterpretationMode,
      function(x)
        return type(x) == 'string' and vim.list_contains(proof_pointInterpretationMode_keys, x)
      end,
      'one of ' .. table.concat(proof_pointInterpretationMode_keys, ', '),
    },
    ['vscoq.proof.cursor'] = { config.proof.cursor, 'table' },
    ['vscoq.proof.cursor.sticky'] = { config.proof.cursor.sticky, 'boolean' },
    ['vscoq.proof.delegation'] = {
      config.proof.delegation,
      function(x)
        return type(x) == 'string' and vim.list_contains(proof_delegation_keys, x)
      end,
      'one of ' .. table.concat(proof_delegation_keys, ', '),
    },
    ['vscoq.proof.workers'] = { config.proof.workers, 'number' },
    ['vscoq.proof.block'] = { config.proof.block, 'boolean' },
    ['vscoq.completion'] = { config.completion, 'table' },
    ['vscoq.completion.enable'] = { config.completion.enable, 'boolean' },
    ['vscoq.completion.unificationLimit'] = { config.completion.unificationLimit, 'number' },
    ['vscoq.completion.algorithm'] = {
      config.completion.algorithm,
      function(x)
        return type(x) == 'string' and vim.list_contains(completion_algorithm_keys, x)
      end,
      'one of ' .. table.concat(completion_algorithm_keys, ', '),
    },
    ['vscoq.diagnostics'] = { config.diagnostics, 'table' },
    ['vscoq.diagnostics.full'] = { config.diagnostics.full, 'boolean' },
  }
  setmetatable(config, self)
  return config
end

---@return vscoq.LspOptions
function Config:to_lsp_options()
  local LspConfig = require('vscoq.lsp_options')
  return LspConfig:new(self)
end

return Config
