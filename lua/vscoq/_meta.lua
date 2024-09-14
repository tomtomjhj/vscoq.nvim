---@alias buffer integer
---@alias window integer

---Position for indexing used by most API functions (0-based line, 0-based column) (:h api-indexing).
---@class APIPosition: { [1]: integer, [2]: integer }

---Position for "mark-like" indexing (1-based line, 0-based column) (:h api-indexing).
---@class MarkPosition: { [1]: integer, [2]: integer }

-- https://github.com/coq-community/vscoq/blob/main/docs/protocol.md

-- # Configuration

-- # Highlights

---"vscoq/UpdateHighlights" notification (server → client) parameter.
---@class vscoq.UpdateHighlightsNotification
---@field uri lsp.DocumentUri
---@field processingRange lsp.Range[]
---@field processedRange lsp.Range[]

-- # Goal view

---@alias vscoq.PpTag string

---@alias vscoq.BlockType
---| vscoq.BlockType.Pp_hbox
---| vscoq.BlockType.Pp_vbox
---| vscoq.BlockType.Pp_hvbox
---| vscoq.BlockType.Pp_hovbox

---@class vscoq.BlockType.Pp_hbox
---@field [1] "Pp_hbox"

---@class vscoq.BlockType.Pp_vbox
---@field [1] "Pp_vbox"
---@field [2] integer

---@class vscoq.BlockType.Pp_hvbox
---@field [1] "Pp_hvbox"
---@field [2] integer

---@class vscoq.BlockType.Pp_hovbox
---@field [1] "Pp_hovbox"
---@field [2] integer new lines in this box adds this amount of indent

---@alias vscoq.PpString
---| vscoq.PpString.Ppcmd_empty
---| vscoq.PpString.Ppcmd_string
---| vscoq.PpString.Ppcmd_glue
---| vscoq.PpString.Ppcmd_box
---| vscoq.PpString.Ppcmd_tag
---| vscoq.PpString.Ppcmd_print_break
---| vscoq.PpString.Ppcmd_force_newline
---| vscoq.PpString.Ppcmd_comment

---@class vscoq.PpString.Ppcmd_empty
---@field [1] "Ppcmd_empty"
---@field size integer

---@class vscoq.PpString.Ppcmd_string
---@field [1] "Ppcmd_string"
---@field [2] string
---@field size integer

---@class vscoq.PpString.Ppcmd_glue
---@field [1] "Ppcmd_glue"
---@field [2] (vscoq.PpString)[]
---@field size integer

---@class vscoq.PpString.Ppcmd_box
---@field [1] "Ppcmd_box"
---@field [2] vscoq.BlockType
---@field [3] vscoq.PpString
---@field size integer

---@class vscoq.PpString.Ppcmd_tag
---@field [1] "Ppcmd_tag"
---@field [2] vscoq.PpTag
---@field [3] vscoq.PpString
---@field size integer

---@class vscoq.PpString.Ppcmd_print_break
---@field [1] "Ppcmd_print_break"
---@field [2] integer number of spaces when this break is not line break
---@field [3] integer additional indent of the new lines (added to box's indent)
---@field size integer

---@class vscoq.PpString.Ppcmd_force_newline
---@field [1] "Ppcmd_force_newline"
---@field size integer

---@class vscoq.PpString.Ppcmd_comment
---@field [1] "Ppcmd_comment"
---@field [2] string[]
---@field size integer

--[[
  if pp[1] == 'Ppcmd_empty' then
    ---@cast pp vscoq.PpString.Ppcmd_empty
  elseif pp[1] == 'Ppcmd_string' then
    ---@cast pp vscoq.PpString.Ppcmd_string
  elseif pp[1] == 'Ppcmd_glue' then
    ---@cast pp vscoq.PpString.Ppcmd_glue
  elseif pp[1] == 'Ppcmd_box' then
    ---@cast pp vscoq.PpString.Ppcmd_box
  elseif pp[1] == 'Ppcmd_tag' then
    ---@cast pp vscoq.PpString.Ppcmd_tag
  elseif pp[1] == 'Ppcmd_print_break' then
    ---@cast pp vscoq.PpString.Ppcmd_print_break
  elseif pp[1] == 'Ppcmd_force_newline' then
    ---@cast pp vscoq.PpString.Ppcmd_force_newline
  elseif pp[1] == 'Ppcmd_comment' then
    ---@cast pp vscoq.PpString.Ppcmd_comment
  end
--]]

---@class vscoq.Goal
---@field id integer
---@field goal vscoq.PpString
---@field hypotheses (vscoq.PpString)[]

---@class vscoq.ProofViewGoals
---@field goals vscoq.Goal[]
---@field shelvedGoals vscoq.Goal[]
---@field givenUpGoals vscoq.Goal[]

---@alias vscoq.MessageSeverity "Error" | "Warning" | "Information"

---@alias vscoq.CoqMessage {[1]: vscoq.MessageSeverity, [2]: vscoq.PpString}

---"vscoq/proofView" notification (server → client) parameter.
---@class vscoq.ProofViewNotification
---@field proof? vscoq.ProofViewGoals
---@field messages vscoq.CoqMessage[]

---"vscoq/moveCursor" notification (server → client) parameter.
---Sent as response to "vscoq/stepForward" and "vscoq/stepBack" notifications.
---@class vscoq.MoveCursorNotification
---@field uri lsp.DocumentUri
---@field range lsp.Range

-- # Query panel

-- TODO: query response does not contain appropriate line breaks for window width (unlike coqide)

---"vscoq/search" request parameter.
---@class vscoq.SearchCoqRequest
---@field id string this doesn't need to be an actual UUID
---@field textDocument lsp.VersionedTextDocumentIdentifier
---@field pattern string
---@field position lsp.Position

---"vscoq/search" response parameter.
---@class vscoq.SearchCoqHandshake
---@field id string

---"vscoq/searchResult" notification parameter.
---@class vscoq.SearchCoqResult
---@field id string
---@field name vscoq.PpString
---@field statement vscoq.PpString

---Request parameter for "vscoq/about", "vscoq/check", "vscoq/print", "vscoq/locate"
---@class vscoq.SimpleCoqRequest
---@field textDocument lsp.VersionedTextDocumentIdentifier
---@field pattern string
---@field position lsp.Position

---Response parameter for "vscoq/about", "vscoq/check", "vscoq/print", "vscoq/locate"
---@alias vscoq.SimpleCoqReponse vscoq.PpString

---Request parameter for "vscoq/resetCoq"
---@class vscoq.ResetCoqRequest
---@field textDocument lsp.VersionedTextDocumentIdentifier
