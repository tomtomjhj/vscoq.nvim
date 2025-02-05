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

local config = require('vscoq.config')
---@class vscoq.Config
M.default_config = config.default

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
  config.check(opts.vscoq)
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
  opts.lsp.init_options = config.make_lsp_options(opts.vscoq)
  require('lspconfig').vscoqtop.setup(opts.lsp)
end

return M
