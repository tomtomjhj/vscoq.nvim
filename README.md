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
* `lsp`: The settings forwarded to `:help lspconfig-setup`.
### Coq configuration
| Key               | Type                               | Default value                      | Description                                                                                                                    |
| ----------------- | ---------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `lsp.path`        | `string`                           | `""` (automaticaly get `vscoqtop`) | Specify the path to `vscoqtop` (e.g. `path/to/vscoq/bin/vscoqtop`)                                                             |
|`lsp.args`         | `array of string`                  | `[]`                               | An array of strings specifying additional command line arguments for `vscoqtop` (typically accepts the same flags as `coqtop`) |
|`lsp.trace.server` | `"off" \| "messages" \| "verbose"` |  `"off"`                           | Toggles the tracing of communications between the server and client                                                            |

NOTE: On `vscoq` key `"vscoq.path"`, `"vscoq.args"`,
and `"vscoq.trace.server"` should be configured in the `lsp` table.

### Memory management (since >= vscoq 2.1.7)

| Key                 | Type  | Default value | Description                                                                                                                                           |
| ------------------- | ----- | ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
|`vscoq.memory.limit` | `int` | 4             | specifies the memory limit (in Gb) over which when a user closes a tab, the corresponding document state is discarded in the server to free up memory |

### Goal and info view panel

| Key                         | Type                         | Default value | Description                                                                                                   |
| --------------------------- | ---------------------------- | ------------- | ------------------------------------------------------------------------------------------------------------- |
| `vscoq.goals.display`       | `"Tabs" \| "List"`           | `"List"`      | Decide whether to display goals in separate tabs or as a list of collapsibles.                                |
| `vscoq.goals.diff.mode`     | `"on" \| "off" \| "removed"` | `"off"`       | Toggles diff mode. If set to `removed`, only removed characters are shown                                     |
| `vscoq.goals.messages.full` | `bool`                       | `false`       | A toggle to include warnings and errors in the proof view                                                     |
| `vscoq.goals.maxDepth`      | `int`                        | `17`          | A setting to determine at which point the goal display starts elliding (since version >= 2.1.7 of `vscoqtop`) |

### Proof checking
| Key                                   | Type                             | Default value | Description                                                                                                                                                                                                                 |
| ------------------------------------- | -------------------------------- | ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `vscoq.proof.mode`                    | `"Continuous" \| "Manual"`       | `"Manual"`    | Decide whether documents should checked continuously or using the classic navigation commmands (defaults to `Manual`)                                                                                                       |
| `vscoq.proof.pointInterpretationMode` | `"Cursor" \| "NextCommand"`      | `"Cursor"`    | Determines the point to which the proof should be check to when using the 'Interpret to point' command                                                                                                                      |
| `vscoq.proof.cursor.sticky`           | `bool`                           | `true`        | A toggle to specify whether the cursor should move as Coq interactively navigates a document (step forward, backward, etc...)                                                                                               |
| `vscoq.proof.delegation"`             | `"None" \| "Skip" \| "Delegate"` | `"None"`      | Decides which delegation strategy should be used by the server. `Skip` allows to skip proofs which are out of focus and should be used in manual mode. `Delegate` allocates a settable amount of workers to delegate proofs |
| `vscoq.proof.workers`                 | `int`                            | `1`           | Determines how many workers should be used for proof checking                                                                                                                                                               |
| `vscoq.proof.block`                   | `bool`                           | `true`        | Determines if the the execution of a document should halt on first error (since version >= 2.1.7 of `vscoqtop`)                                                                                                             |

### Code completion (experimental)
| Key                                 | Type                                                      | Default value            | Description                                                   |
| ----------------------------------- | --------------------------------------------------------- | ------------------------ | ------------------------------------------------------------- |
| `vscoq.completion.enable`           | `bool`                                                    | `false`                  | Toggle code completion                                        |
| `vscoq.completion.algorithm`        | `"StructuredSplitUnification" \| "SplitTypeIntersection"` | `"SplitTypeIntersection"`| Which completion algorithm to use                             |
| `vscoq.completion.unificationLimit` | `int` (minimum 0)                                         | `100`                    | Sets the limit for how many theorems unification is attempted |

### Diagnostics
| Key                      | Type   | Default value | Description                                      |
| ------------------------ | ------ | ------------- | ------------------------------------------------ |
| `vscoq.diagnostics.full` | `bool` | `false`       | Toggles the printing of `Info` level diagnostics |

### Example:
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
