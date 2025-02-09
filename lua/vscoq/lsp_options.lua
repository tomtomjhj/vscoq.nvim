-- ## Lsp Options
-- Configuration for the language server
-- (is separate to *Config* because this is what's actually sent to the server)

---@class vscoq.LspOptions
local LspOptions = {
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

    ---@type integer
    maxDepth = 17,
  },
  proof = {
    ---@enum
    ---|0 # Manual
    ---|1 # Continuous
    mode = 0,

    ---@enum
    ---|0 # Cursor
    ---|1 # NextCommand
    pointInterpretationMode = 0,

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

    ---@enum
    ---|0 # StructuredSplitUnification
    ---|1 # SplitTypeIntersection
    algorithm = 1,
  },

  diagnostics = {
    ---@type boolean
    full = false,
  },
}

LspOptions.__index = LspOptions

-- table to convert string to LspOptions
local completion_algorithm_table = {
  StructuredSplitUnification = 0,
  SplitTypeIntersection = 1,
}
local proof_mode_table = {
  Manual = 0,
  Continuous = 1,
}
local proof_pointInterpretationMode_table = {
  Cursor = 0,
  NextCommand = 1,
}

---@param config vscoq.Config
---@return vscoq.LspOptions
function LspOptions:new(config)
  local lsp_opts = {
    memory = vim.deepcopy(config.memory),
    goals = vim.deepcopy(config.goals),
    proof = {
      mode = proof_mode_table[config.proof.mode],
      pointInterpretationMode = proof_pointInterpretationMode_table[config.proof.pointInterpretationMode],
      cursor = vim.deepcopy(config.proof.cursor),
      delegation = config.proof.delegation,
      workers = config.proof.workers,
      block = config.proof.block,
    },
    completion = {
      enable = config.completion.enable,
      unificationLimit = config.completion.unificationLimit,
      algorithm = completion_algorithm_table[config.completion.algorithm],
    },
    diagnostics = vim.deepcopy(config.diagnostics),
  }
  setmetatable(lsp_opts, self)
  return lsp_opts
end

return LspOptions
