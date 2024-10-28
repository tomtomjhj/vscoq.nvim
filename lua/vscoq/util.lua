local M = {}

-- TODO: The position sent by the server may be no longer valid in the current buffer text
---@param bufnr buffer
---@param position lsp.Position
---@param offset_encoding lsp.PositionEncodingKind
---@return APIPosition
function M.position_lsp_to_api(bufnr, position, offset_encoding)
  local idx = vim.lsp.util._get_line_byte_from_position(
    bufnr,
    { line = position.line, character = position.character },
    offset_encoding
  )
  return { position.line, idx }
end

---@param position APIPosition
---@return MarkPosition
function M.position_api_to_mark(position)
  return { position[1] + 1, position[2] }
end

---@param p1 APIPosition
---@param p2 APIPosition
---@return boolean
function M.api_position_lt(p1, p2)
  if p1[1] < p2[1] then
    return true
  elseif p1[1] == p2[1] then
    return p1[2] < p2[2]
  else
    return false
  end
end

local str_utfindex = vim.fn.has('nvim-0.11') == 1 and function(s, encoding, index)
  return vim.str_utfindex(s, encoding, index, false)
end or function(s, encoding, index)
  return vim.lsp.util._str_utfindex_enc(s, index, encoding)
end

---@param bufnr buffer
---@param position MarkPosition
---@param offset_encoding lsp.PositionEncodingKind
---@return lsp.Position
function M.make_position_params(bufnr, position, offset_encoding)
  local row, col = unpack(position)
  row = row - 1
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]
  if not line then
    return { line = 0, character = 0 }
  end

  col = str_utfindex(line, offset_encoding, col)

  return { line = row, character = col }
end

-- TODO: version is not used in the server, but errors if not included.
-- file an issue to use TextDocumentIdentifier.
---@param bufnr buffer
---@return lsp.VersionedTextDocumentIdentifier
function M.make_versioned_text_document_params(bufnr)
  return {
    uri = vim.uri_from_bufnr(bufnr),
    version = vim.lsp.util.buf_versions[bufnr],
  }
end

---@param bufnr buffer
---@return MarkPosition
function M.guess_position(bufnr)
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) ~= bufnr then
    error("can't guess position")
  end
  return vim.api.nvim_win_get_cursor(win)
end

---@param client vim.lsp.Client
---@param bufnr integer
---@param method string
---@param params table
---@param handler? lsp.Handler
---@return fun()|nil cancel function to cancel the request
function M.request_async(client, bufnr, method, params, handler)
  local request_success, request_id = client.request(method, params, handler, bufnr)
  if request_success then
    return function()
      client.cancel_request(assert(request_id))
    end
  end
end

return M
