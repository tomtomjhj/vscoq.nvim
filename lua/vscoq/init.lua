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
local default_config = {
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
      full = false,
    },
  },
  proof = {
    ---@enum
    ---|0 # Manual
    ---|1 # Continuous
    mode = 1,
    cursor = {
      ---@type boolean
      sticky = true,
    },
    ---@type "None"|"Skip"|"Delegate"
    delegation = 'None',
    ---@type integer
    workers = 1,
  },
  completion = {
    ---@type boolean
    enable = false,
    ---@type integer
    unificationLimit = 100,
    ---@type 0|1
    algorithm = 1,
  },
  diagnostics = {
    ---@type boolean
    full = false,
  },
}

-- Assume that vscoq LSP client is unique.
-- TODO: This may not be true when working on multiple workspaces.
-- Maintain client_id ↦ VSCoqNvim map. In lsp-handlers, use ctx.client_id.
---@type VSCoqNvim?
local the_client

local function make_on_init(user_on_init)
  return function(client, initialize_result)
    local ok, VSCoqNvim = pcall(require, 'vscoq.client')
    if not ok then
      vim.print('[vscoq.nvim] on_init failed', VSCoqNvim)
      return
    end
    the_client = VSCoqNvim:new(client)
    the_client:open_panels()
    if user_on_init then
      user_on_init(client, initialize_result)
    end
  end
end

---@param user_on_attach? fun(client: lsp.Client, bufnr: buffer)
---@return fun(client: lsp.Client, bufnr: buffer)
local function make_on_attach(user_on_attach)
  return function(client, bufnr)
    assert(the_client)
    assert(the_client.lc == client)
    if not the_client.buffers[bufnr] then
      the_client:attach(bufnr)
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
      assert(the_client):on_exit()
      the_client = nil
    end)
  end
end

---@type lsp-handler
local function updateHighlights_notification_handler(_, result, _, _)
  assert(the_client)
  the_client:updateHighlights(result)
end

---@type lsp-handler
local function moveCursor_notification_handler(_, result, _, _)
  assert(the_client)
  the_client:moveCursor(result)
end

---@type lsp-handler
local function searchResult_notification_handler(_, result, _, _)
  assert(the_client)
  the_client:searchResult(result)
end

---@type lsp-handler
local function proofView_notification_handler(_, result, _, _)
  assert(the_client)
  the_client:proofView(result)
end

---@param opts { vscoq?: table<string,any>, lsp?: table<string,any> }
local function setup(opts)
  opts = opts or {}
  opts.vscoq = vim.tbl_deep_extend('keep', opts.vscoq or {}, default_config)
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
  opts.lsp.init_options = vim.deepcopy(opts.vscoq)
  require('lspconfig').vscoqtop.setup(opts.lsp)
end

return {
  client = function()
    return the_client
  end,
  setup = setup,
}
