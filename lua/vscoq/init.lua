-- Suppress warnings about private methods of lsp.Client.
---@diagnostic disable: invisible

-- utils {{{

---@param bufnr buffer
---@param position lsp.Position
---@param offset_encoding lsp.PositionEncodingKind
---@return APIPosition
local function position_lsp_to_api(bufnr, position, offset_encoding)
  local idx = vim.lsp.util._get_line_byte_from_position(
    bufnr,
    { line = position.line, character = position.character },
    offset_encoding
  )
  return { position.line, idx }
end

---@param bufnr buffer
---@param position MarkPosition
---@param offset_encoding lsp.PositionEncodingKind
---@return lsp.Position
local function make_position_params(bufnr, position, offset_encoding)
  local row, col = unpack(position)
  row = row - 1
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]
  if not line then
    return { line = 0, character = 0 }
  end

  col = vim.lsp.util._str_utfindex_enc(line, col, offset_encoding)

  return { line = row, character = col }
end

---@param bufnr buffer
---@return MarkPosition
local function guess_position(bufnr)
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) ~= bufnr then
    error("can't guess position")
  end
  return vim.api.nvim_win_get_cursor(win)
end

---@param client lsp.Client
---@param bufnr integer
---@param method string
---@param params table
---@param handler? lsp-handler
---@return fun()|nil cancel function to cancel the request
local function request_async(client, bufnr, method, params, handler)
  local request_success, request_id = client.request(method, params, handler, bufnr)
  if request_success then
    return function()
      client.cancel_request(assert(request_id))
    end
  end
end

-- }}}

-- Assume that vscoq LSP client is unique.
---@type VSCoqNvim?
local the_client

-- Some options values are used both in the server and the client, e.g.,
-- vscoq.proof.mode is used in "check_mode" variable in server, and "goalsHook" in client.
--
-- The vscode client forwards the entire config as `initializationOptions` to the server.
-- The server itself doesn't have default config values,
-- so we should forward the config as `init_options`, not `settings`.
--
-- TODO: Config change should both change client config and send didChangeConfiguration notifcation.
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
    display = "List",
    diff = {
      ---@type "off"|"on"|"removed"
      mode = "off",
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
    delegation = "None",
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

---@class VSCoqNvim
---@field lc lsp.Client
---@field config vscoq.Config the current configuration
---@field buffers table<buffer, { info_bufnr: buffer }>
---@field debounce_timer uv_timer_t
---@field highlight_ns integer
---@field ag integer
local VSCoqNvim = {}
VSCoqNvim.__index = VSCoqNvim

---@param client lsp.Client
function VSCoqNvim:new(client)
  local new = {}
  new.lc = client
  new.config = vim.deepcopy(client.config.init_options) --[[@as vscoq.Config]]
  new.buffers = {}
  new.debounce_timer = assert(vim.loop.new_timer(), 'Could not create timer')
  new.config = default_config
  new.highlight_ns = vim.api.nvim_create_namespace('vscoq-progress-' .. client.id)
  new.ag = vim.api.nvim_create_augroup("vscoq-" .. client.id, { clear = true })
  return setmetatable(new, self)
end

---@type lsp-handler
---vscoq.MoveCursorNotification
local function updateHighlights_notification_handler(_, result, _, _)
  local params = result ---@type vscoq.Highlights
  assert(the_client)
  local bufnr = vim.uri_to_bufnr(params.uri)
  vim.api.nvim_buf_clear_namespace(bufnr, the_client.highlight_ns, 0, -1)
  -- TODO: ranges are not disjoint? processingRange is always the entire buffer????
  -- TODO: buffer text may have changed, so the positions may not be valid
  for _, range in ipairs(params.parsedRange) do
    vim.highlight.range(
      bufnr,
      the_client.highlight_ns,
      'CoqtailSent',
      position_lsp_to_api(bufnr, range['start'], the_client.lc.offset_encoding),
      position_lsp_to_api(bufnr, range['end'], the_client.lc.offset_encoding),
      { priority = vim.highlight.priorities.user }
    )
  end
  for _, range in ipairs(params.processedRange) do
    vim.highlight.range(
      bufnr,
      the_client.highlight_ns,
      'CoqtailChecked',
      position_lsp_to_api(bufnr, range['start'], the_client.lc.offset_encoding),
      position_lsp_to_api(bufnr, range['end'], the_client.lc.offset_encoding),
      { priority = vim.highlight.priorities.user + 1 }
    )
  end
end

---@type lsp-handler
local function moveCursor_notification_handler(_, result, _, _)
  local params = result ---@type vscoq.MoveCursorNotification
  assert(the_client)
  vim.print('moveCursor', params)
  -- if sticky and manual, set cursor to params.range['end']
end

---@type lsp-handler
local function searchResult_notification_handler(_, result, _, _)
  local params = result ---@type vscoq.SearchCoqResult
  vim.print('searchResult', params)
  assert(the_client)
end

-- See pp.tsx.
---@param pp vscoq.PpString
---@param mode? "horizontal"|"vertical"
---@return string
local function render_PpString(pp, mode)
  mode = mode or "horizontal"
  if pp[1] == "Ppcmd_empty" then
    return ''
  elseif pp[1] == "Ppcmd_string" then
    return pp[2]
  elseif pp[1] == "Ppcmd_glue" then
    return table.concat(vim.tbl_map(render_PpString, pp[2]), '')
  elseif pp[1] == "Ppcmd_box" then
    if pp[2][1] == "Pp_hbox" then
      mode = "horizontal"
    elseif pp[2][1] == "Pp_vbox" then
      mode = "vertical"
    -- TODO: proper support for hvbox and hovbox (not implemented in vscode client either)
    elseif pp[2][1] == "Pp_hvbox" then
      mode = "horizontal"
    elseif pp[2][1] == "Pp_hovbox" then
      mode = "horizontal"
    end
    return render_PpString(pp[3], mode)
  elseif pp[1] == "Ppcmd_tag" then
    -- TODO: use PpTag for highlighting (difficult)
    return render_PpString(pp[3])
  elseif pp[1] == "Ppcmd_print_break" then
    if mode == "horizontal" then
      return string.rep(" ", pp[2])
    elseif mode == "vertical" then
      return "\n"
    end
    error()
  elseif pp[1] == "Ppcmd_force_newline" then
    return "\n"
  elseif pp[1] == "Ppcmd_comment" then
    return vim.inspect(pp[2])
  end
  error(pp[1])
end

---@param goal vscoq.Goal
---@param i integer
---@param n integer
---@return string[]
local function render_goal(i, n, goal)
  local lines = {}
  lines[#lines+1] = string.format('Goal %d (%d / %d)', goal.id, i, n)
  for _, hyp in ipairs(goal.hypotheses) do
    vim.list_extend(lines, vim.split(render_PpString(hyp), '\n'))
  end
  lines[#lines+1] = ''
  lines[#lines+1] = '========================================'
  lines[#lines+1] = ''
  vim.list_extend(lines, vim.split(render_PpString(goal.goal), '\n'))
  return lines
end

---@param goals vscoq.Goal[]
function VSCoqNvim:render_goals(goals)
  local lines = {}
  for i, goal in ipairs(goals) do
    if i > 1 then
      lines[#lines+1] = ''
      lines[#lines+1] = ''
      lines[#lines+1] = '────────────────────────────────────────────────────────────'
      lines[#lines+1] = ''
    end
    vim.list_extend(lines, render_goal(i, #goals, goal))
  end
  -- TODO: proofView doesn't send what document it is for; file an issue
  vim.api.nvim_buf_set_lines(self:get_info_bufnr(vim.api.nvim_get_current_buf()), 0, -1, false, lines)
end

---@type lsp-handler
local function proofView_notification_handler(_, result, _, _)
  local params = result ---@type vscoq.ProofViewNotification
  assert(the_client)
  if params.proof then
    the_client:render_goals(params.proof.goals)
  end
end

---@param bufnr buffer
function VSCoqNvim:create_info_panel(bufnr)
  local info_bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[info_bufnr].filetype = 'coq-goals'
  self.buffers[bufnr].info_bufnr = info_bufnr
end

---@param bufnr buffer
function VSCoqNvim:get_info_bufnr(bufnr)
  local info_bufnr = self.buffers[bufnr].info_bufnr
  if info_bufnr and vim.api.nvim_buf_is_valid(info_bufnr) then
    return info_bufnr
  end
  self:create_info_panel(bufnr)
  return self.buffers[bufnr].info_bufnr
end

---@param bufnr? buffer
function VSCoqNvim:open_info_panel(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  vim.cmd.sbuffer {
    args = { self:get_info_bufnr(bufnr) },
    -- TODO: customization
    -- See `:h nvim_parse_cmd`. Note that the "split size" is `range`.
    mods = { keepjumps = true, keepalt = true, vertical = true, split = 'belowright' },
  }
  vim.cmd.clearjumps()
  vim.api.nvim_set_current_win(win)
end

---@param bufnr? buffer registered buffer
---@param position? MarkPosition
function VSCoqNvim:interpretToPoint(bufnr, position)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  position = position or guess_position(bufnr)
  local params = {
    textDocument = {
      uri = vim.uri_from_bufnr(bufnr),
      -- TODO: this is not used in the server; file an issue to use TextDocumentIdentifier
      version = vim.lsp.util.buf_versions[bufnr],
    },
    position = make_position_params(bufnr, position, self.lc.offset_encoding)
  }
  return self.lc.notify("vscoq/interpretToPoint", params)
end

function VSCoqNvim:on_CursorMoved()
  if self.config.proof.mode == 1 then
    -- TODO: debounce_timer
    assert(self:interpretToPoint())
  end
end

---@param bufnr buffer
function VSCoqNvim:detach(bufnr)
  assert(self.buffers[bufnr])
  vim.api.nvim_buf_clear_namespace(bufnr, self.highlight_ns, 0, -1)
  vim.api.nvim_clear_autocmds { group = self.ag, buffer = bufnr }
  if self.buffers[bufnr].info_bufnr then
    vim.api.nvim_buf_delete(self.buffers[bufnr].info_bufnr, { force = true })
  end
  self.buffers[bufnr] = nil
end

---@param bufnr buffer
function VSCoqNvim:attach(bufnr)
  assert(self.buffers[bufnr] == nil)
  self.buffers[bufnr] = {}
  self:create_info_panel(bufnr)
  self:open_info_panel(bufnr)
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = self.ag,
    buffer = bufnr,
    callback = function() self:on_CursorMoved() end,
  })
  vim.api.nvim_create_autocmd({ "BufDelete", "LspDetach" }, {
    group = self.ag,
    buffer = bufnr,
    desc = "Unregister deleted/detached buffer",
    callback = function(ev) self:detach(ev.buf) end,
  })
  self:interpretToPoint(bufnr)
end

function VSCoqNvim:on_exit()
  self.debounce_timer:stop()
  self.debounce_timer:close()
  for bufnr, _ in pairs(self.buffers) do
    self:detach(bufnr)
  end
  vim.api.nvim_clear_autocmds { group = self.ag }
end

local function make_on_init(user_on_init)
  return function(client, initialize_result)
    the_client = VSCoqNvim:new(client)
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

---@param opts { vscoq_nvim?: table<string,any>, lsp?: table<string,any> }
local function setup(opts)
  opts = opts or {}
  opts.vscoq_nvim = vim.tbl_deep_extend('keep', opts.vscoq_nvim or {}, default_config)
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
  assert(opts.lsp.init_options == nil)
  opts.lsp.init_options = vim.deepcopy(opts.vscoq_nvim)
  assert(opts.lsp.settings == nil)
  require('lspconfig').vscoqtop.setup(opts.lsp)
end

return {
  client = function() return the_client end,
  panels = function() assert(the_client):open_info_panel() end,
  setup = setup,
}

-- TODO: change tracking is broken?
-- Sometimes change tracking seems to be broken
-- * vscoqtop randomly crashes(?) when editing
-- * edit and interpretToPoint elsewhere → the same proofview or wrong highlight region
