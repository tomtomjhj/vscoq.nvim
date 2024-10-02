# vscoq.nvim
A Neovim client for [VsCoq 2 `vscoqtop`](https://github.com/coq-community/vscoq).

## Prerequisites
* [Latest stable version of Neovim](https://github.com/neovim/neovim/releases/tag/stable)
* [`vscoqtop`](https://github.com/coq-community/vscoq#installing-the-language-server)

## Setup
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
