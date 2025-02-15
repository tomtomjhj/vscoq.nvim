-- ## Lsp Options
-- Configuration for the language server
-- (is separate to *Config* because this is what's actually sent to the server)
-- is following setting of vscoqtop
--- https://github.com/coq/vscoq/blob/main/language-server/protocol/settings.ml

---@class vscoq.LspOptions
local LspOptions = {
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

    -- atomicFactor = 5.0,
    -- sizeFactor = 1.0,
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
    goals = {
      diff = vim.deepcopy(config.goals.diff),
      messages = vim.deepcopy(config.goals.messages),
    },
    proof = {
      mode = proof_mode_table[config.proof.mode],
      pointInterpretationMode = proof_pointInterpretationMode_table[config.proof.pointInterpretationMode],
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
