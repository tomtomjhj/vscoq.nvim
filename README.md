# vscoq.nvim
A Neovim client for [VsCoq 2 `vscoqtop`](https://github.com/coq-community/vscoq).

## Prerequisites
* [Latest stable version of Neovim](https://github.com/neovim/neovim/releases/tag/stable)
* [`vscoqtop`](https://github.com/coq-community/vscoq#installing-the-language-server)

## Setup
### [vim-plug](https://github.com/junegunn/vim-plug)
```vim
Plug 'neovim/nvim-lspconfig'
Plug 'whonore/Coqtail' " for ftdetect, syntax, basic ftplugin, etc
Plug 'tomtomjhj/vscoq.nvim'

...

" Don't load Coqtail
let g:loaded_coqtail = 1
let g:coqtail#supported = 0

" Setup vscoq.nvim
lua require'vscoq'.setup()
```

### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
  'whonore/Coqtail',
  init = function()
      vim.g.loaded_coqtail = 1
      vim.g["coqtail#supported"] = 0
  end,
},
{
  'tomtomjhj/vscoq.nvim',
  filetypes = 'coq',
  dependecies = {
    'neovim/nvim-lspconfig',
    'whonore/Coqtail',
  },
  opts = {
    vscoq = { ... }
    lsp = { ... }
  },
},
```

## Interface
* vscoq.nvim uses Neovim's built-in LSP client and nvim-lspconfig.
  See [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim/)
  for basic example configurations for working with LSP.
* `:VsCoq` command
    * `:VsCoq continuous`: Use the "Continuous" proof mode. It shows goals for the cursor position.
    * `:VsCoq manual`: Use the "Manual" proof mode (default), where the following four commands are used for navigation.
        * `:VsCoq stepForward`
        * `:VsCoq stepBackward`
        * `:VsCoq interpretToEnd`
        * `:VsCoq interpretToPoint`
    * `:VsCoq panels`: Open the proofview panel and query panel.
    * Queries
        * `:VsCoq search {pattern}`
        * `:VsCoq about {pattern}`
        * `:VsCoq check {pattern}`
        * `:VsCoq print {pattern}`
        * `:VsCoq locate {pattern}`
    * Proofview
        * `:VsCoq admitted`: Show the admitted goals.
        * `:VsCoq shelved`: Show the shelved goals.
        * `:VsCoq goals`: Show the normal goals and messages (default).
    * etc
        * `:VsCoq jumpToEnd`: Jump to the end of the checked region.
* [Commands from nvim-lspconfig](https://github.com/neovim/nvim-lspconfig#commands)
  work as expected.
  For example, run `:LspRestart` to restart `vscoqtop`.

## Configurations
The `setup()` function takes a table with the followings keys:
* `vscoq`: Settings specific to VsCoq.
  This is used in both the client and the server.
  See the `"configuration"` key in <https://github.com/coq-community/vscoq/blob/main/client/package.json>.
    * NOTE: `"vscoq.path"`, `"vscoq.args"`, and `"vscoq.trace.server"` should be configured in the `lsp` table below.
* `lsp`: The settings forwarded to `:help lspconfig-setup`.

#### Coq configuration
* `"lsp.path": ""`
    -- specify the path to `vscoqtop` (e.g. `path/to/vscoq/bin/vscoqtop`)
* `"lsp.args": []`
    -- an array of strings specifying additional command line arguments for `vscoqtop` (typically accepts the same flags as `coqtop`)
* `"lsp.trace.server": string` `"off" | "messages" | "verbose"`
    -- Toggles the tracing of communications between the server and client

#### Memory management (since >= vscoq 2.1.7)
* `"vscoq.memory.limit: int`
    -- specifies the memory limit (in Gb) over which when a user closes a tab, the corresponding document state is discarded in the server to free up memory.
    Defaults to 4Gb.

#### Goal and info view panel
* `"vscoq.goals.display": string` `"Tabs" | "List"`
    -- Decide whether to display goals in separate tabs or as a list of collapsibles.
* `"vscoq.goals.diff.mode": string` `"on" | "off" | "removed"`
    -- Toggles diff mode. If set to `removed`, only removed characters are shown (defaults to `off`)
* `"vscoq.goals.messages.full": bool`
    -- A toggle to include warnings and errors in the proof view (defaults to `false`)
* `"vscoq.goals.maxDepth": int`
    -- A setting to determine at which point the goal display starts elliding. Defaults to 17. (since version >= 2.1.7)

#### Proof checking
* `"vscoq.proof.mode": string` `"Continuous" | "Manual"`
    -- Decide whether documents should checked continuously or using the classic navigation commmands (defaults to `Manual`)
* `"vscoq.proof.pointInterpretationMode":` `"stringCursor" | "NextCommand"`
    -- Determines the point to which the proof should be check to when using the 'Interpret to point' command.
* `"vscoq.proof.cursor.sticky": bool`
    -- a toggle to specify whether the cursor should move as Coq interactively navigates a document (step forward, backward, etc...)
* `"vscoq.proof.delegation": string` `"None" | "Skip" | "Delegate"`
    -- Decides which delegation strategy should be used by the server.
  `Skip` allows to skip proofs which are out of focus and should be used in manual mode. `Delegate` allocates a settable amount of workers
  to delegate proofs.
* `"vscoq.proof.workers": int`
    -- Determines how many workers should be used for proof checking
* `"vscoq.proof.block": bool`
    -- Determines if the the execution of a document should halt on first error.  Defaults to true (since version >= 2.1.7).
* `"vscoq.proof.display-buttons": bool`
    -- A toggle to control whether buttons related to Coq (step forward/back, reset, etc.) are displayed in the editor actions menu (defaults to `true`)

#### Code completion (experimental)
* `"vscoq.completion.enable": bool`
    -- Toggle code completion (defaults to `false`)
* `"vscoq.completion.algorithm": string` `"StructuredSplitUnification" | "SplitTypeIntersection"`
    -- Which completion algorithm to use
* `"vscoq.completion.unificationLimit": int`
    -- Sets the limit for how many theorems unification is attempted

#### Diagnostics
* `"vscoq.diagnostics.full": bool`
    -- Toggles the printing of `Info` level diagnostics (defaults to `false`)



Example:
```lua
require'vscoq'.setup {
  vscoq = {
    proof = {
      -- In manual mode, don't move the cursor when stepping forward/backward a command
      cursor = { sticky = false },
    },
  },
  lsp = {
    on_attach = function(client, bufnr)
      -- your mappings, etc

      -- In manual mode, use ctrl-alt-{j,k,l} to step.
      vim.keymap.set({'n', 'i'}, '<C-M-j>', '<Cmd>VsCoq stepForward<CR>', { buffer = bufnr })
      vim.keymap.set({'n', 'i'}, '<C-M-k>', '<Cmd>VsCoq stepBackward<CR>', { buffer = bufnr })
      vim.keymap.set({'n', 'i'}, '<C-M-l>', '<Cmd>VsCoq interpretToPoint<CR>', { buffer = bufnr })
    end,
    -- autostart = false, -- use this if you want to manually `:LspStart vscoqtop`.
    -- cmd = { 'vscoqtop', '-bt', '-vscoq-d', 'all' }, -- for debugging the server
  },
}
```

NOTE:
Do not call `lspconfig.vscoqtop.setup()` yourself.
`require'vscoq'.setup` does it for you.

## Features not implemented yet
* Fancy proofview rendering
    * proof diff highlights
* Make lspconfig optional

## See also
* [coq.ctags](https://github.com/tomtomjhj/coq.ctags) for go-to-definition.
* [coq-lsp.nvim](https://github.com/tomtomjhj/coq-lsp.nvim) for `coq-lsp` client.
