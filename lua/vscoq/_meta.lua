---Position for indexing used by most API functions (0-based line, 0-based column) (:h api-indexing).
---@class APIPosition: { [1]: integer, [2]: integer }

---Position for "mark-like" indexing (1-based line, 0-based column) (:h api-indexing).
---@class MarkPosition: { [1]: integer, [2]: integer }

-- https://github.com/coq-community/vscoq/blob/main/docs/protocol.md

-- # Configuration

-- # Highlights

---"vscoq/UpdateHighlights" notification (server → client) parameter.
---@class vscoq.Highlights
---@field uri lsp.DocumentUri
---@field parsedRange lsp.Range[]
---@field processingRange lsp.Range[]
---@field processedRange lsp.Range[]

-- # Goal view

---@alias vscoq.PpTag string

---@alias vscoq.BlockType
---| {[1]: "Pp_hbox"}
---| {[1]: "Pp_vbox", [2]: integer}
---| {[1]: "Pp_hvbox", [2]: integer}
---| {[1]: "Pp_hovbox", [2]: integer}

---@alias vscoq.PpString
---| {[1]: "Ppcmd_empty"}
---| {[1]: "Ppcmd_string", [2]: string}
---| {[1]: "Ppcmd_glue", [2]: vscoq.PpString[]}
---| {[1]: "Ppcmd_box", [2]: vscoq.BlockType, [3]: vscoq.PpString}
---| {[1]: "Ppcmd_tag", [2]: vscoq.PpTag, [3]: vscoq.PpString}
---| {[1]: "Ppcmd_print_break", [2]: integer, [3]: integer}
---| {[1]: "Ppcmd_force_newline"}
---| {[1]: "Ppcmd_comment", [2]: string[]};

---@class vscoq.Goal
---@field id integer
---@field goal vscoq.PpString
---@field hypotheses vscoq.PpString[]

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
