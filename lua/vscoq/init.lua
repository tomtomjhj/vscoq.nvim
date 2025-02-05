local M = {}

-- Some options values are used both in the server and the client, e.g.,
-- vscoq.proof.mode is used in "check_mode" variable in server, and "goalsHook" in client.
--
-- The vscode client forwards the entire config as `initializationOptions` to the server.
-- The server itself doesn't have default config values,
-- so we should forward the config as `init_options`, not `settings`.
--
-- https://github.com/coq-community/vscoq/blob/main/client/package.json
-- https://github.com/coq-community/vscoq/blob/main/language-server/protocol/settings.ml
-- https://github.com/coq-community/vscoq/blob/main/docs/protocol.md#configuration
--
-- The "Coq configuration" (vscoq.trace.server, ...) are low-level client-only config handled by vim.lsp.start_client().
---@class vscoq.Config
M.default_config = {
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
    --- TODO: has a real mode ?
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

---@parameter opts_vscoq @vscoq.Config
local function check_config(opts_vscoq)
  local ok = true
  ok = check_type('number', opts_vscoq.memory.limit, 'vscoq.memory.limit') and ok

  ok = check_values({ 'Tabs', 'List' }, opts_vscoq.goals.display, 'vscoq.goals.display') and ok
  ok = check_values({ 'off', 'on', 'removed' }, opts_vscoq.goals.diff.mode, 'vscoq.goals.diff.mode')
    and ok
  ok = check_type('boolean', opts_vscoq.goals.messages.full, 'vscoq.goals.messages.full') and ok
  ok = check_type('number', opts_vscoq.goals.maxDepth, 'vscoq.goals.maxDepth') and ok

  ok = check_values({ 'Manual', 'Continuous' }, opts_vscoq.proof.mode, 'vscoq.proof.mode') and ok
  ok = check_values(
    { 'Cursor', 'NextCommand' },
    opts_vscoq.proof.pointInterpretationMode,
    'opts_vscoq.proof.pointInterpretationMode'
  ) and ok
  ok = check_type('boolean', opts_vscoq.proof.cursor.sticky, 'vscoq.proof.cursor.sticky') and ok
  ok = check_values(
    { 'None', 'Skip', 'Delegate' },
    opts_vscoq.proof.delegation,
    'opts_vscoq.proof.delegation'
  ) and ok
  ok = check_type('number', opts_vscoq.proof.workers, 'vscoq.proof.workers') and ok
  ok = check_type('boolean', opts_vscoq.proof.block, 'vscoq.proof.block') and ok

  ok = check_type('boolean', opts_vscoq.completion.enable, 'vscoq.completion.enable') and ok
  ok = check_type(
    'number',
    opts_vscoq.completion.unificationLimit,
    'vscoq.completion.unificationLimit'
  ) and ok
  ok = check_values(
    { 'StructuredSplitUnification', 'SplitTypeIntersection' },
    opts_vscoq.completion.algorithm,
    'opts_vscoq.completion.algorithm'
  ) and ok

  ok = check_type('boolean', opts_vscoq.diagnostics.full, 'vscoq.diagnostics.full') and ok

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
local function make_init_options(opts_vscoq)
  local init_options = vim.deepcopy(opts_vscoq)
  init_options.proof.mode = proof_mode_table[init_options.proof.mode]
  init_options.proof.pointInterpretationMode =
    proof_pointInterpretationMode_table[init_options.proof.pointInterpretationMode]
  init_options.completion.algorithm = completion_algorithm_table[init_options.completion.algorithm]
  return init_options
end

---@type table<integer, VSCoqNvim> map from client id
M.clients = {}

local function make_on_init(user_on_init)
  return function(client, initialize_result)
    local ok, VSCoqNvim = pcall(require, 'vscoq.client')
    if not ok then
      vim.print('[vscoq.nvim] on_init failed', VSCoqNvim)
      return
    end
    M.clients[client.id] = VSCoqNvim:new(client)
    M.clients[client.id]:panels()
    if user_on_init then
      user_on_init(client, initialize_result)
    end
  end
end

---@param user_on_attach? fun(client: vim.lsp.Client, bufnr: buffer)
---@return fun(client: vim.lsp.Client, bufnr: buffer)
local function make_on_attach(user_on_attach)
  return function(client, bufnr)
    if not M.clients[client.id].buffers[bufnr] then
      M.clients[client.id]:attach(bufnr)
    end
    if user_on_attach then
      user_on_attach(client, bufnr)
    end
  end
end

local function make_on_exit(user_on_exit)
  return function(code, signal, client_id)
    if user_on_exit then
      user_on_exit(code, signal, client_id)
    end
    -- NOTE: on_exit runs in_fast_event
    vim.schedule(function()
      M.clients[client_id]:on_exit()
      M.clients[client_id] = nil
    end)
  end
end

---@type lsp.Handler
local function updateHighlights_notification_handler(_, result, ctx, _)
  M.clients[ctx.client_id]:updateHighlights(result)
end

---@type lsp.Handler
local function moveCursor_notification_handler(_, result, ctx, _)
  M.clients[ctx.client_id]:moveCursor(result)
end

---@type lsp.Handler
local function searchResult_notification_handler(_, result, ctx, _)
  M.clients[ctx.client_id]:searchResult(result)
end

---@type lsp.Handler
local function proofView_notification_handler(_, result, ctx, _)
  M.clients[ctx.client_id]:proofView(result)
end

-- TODO: don't use custom setup and use lspconfig's add_hook_before?
---@param opts { vscoq?: table<string,any>, lsp?: table<string,any> }
function M.setup(opts)
  opts = opts or {}
  opts.vscoq = vim.tbl_deep_extend('keep', opts.vscoq or {}, M.default_config)
  check_config(opts.vscoq)
  opts.lsp = opts.lsp or {}
  opts.lsp.handlers = vim.tbl_extend('keep', opts.lsp.handlers or {}, {
    ['vscoq/updateHighlights'] = updateHighlights_notification_handler,
    ['vscoq/moveCursor'] = moveCursor_notification_handler,
    ['vscoq/searchResult'] = searchResult_notification_handler,
    ['vscoq/proofView'] = proofView_notification_handler,
  })
  local user_on_init = opts.lsp.on_init
  opts.lsp.on_init = make_on_init(user_on_init)
  local user_on_attach = opts.lsp.on_attach
  opts.lsp.on_attach = make_on_attach(user_on_attach)
  local user_on_exit = opts.lsp.on_exit
  opts.lsp.on_exit = make_on_exit(user_on_exit)
  assert(
    opts.lsp.init_options == nil and opts.lsp.settings == nil,
    "[vscoq.nvim] settings must be passed via 'vscoq' field"
  )
  opts.lsp.init_options = make_init_options(opts.vscoq)
  require('lspconfig').vscoqtop.setup(opts.lsp)
end

return M
