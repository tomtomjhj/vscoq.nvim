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
    * `:VsCoq continuous`: Use the "Continuous" proof mode (default, show goals for the cursor position).
    * `:VsCoq manual`: Use the "Manual" proof mode, where the following four commands are used for navigation.
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
* [Commands from nvim-lspconfig](https://github.com/neovim/nvim-lspconfig#commands)
  work as expected.
  For example, run `:LspRestart` to restart `vscoqtop`.

## Configurations

```lua
require'vscoq'.setup {
  -- Configuration for vscoq, used in both the client and the server.
  -- See "configuration" in https://github.com/coq-community/vscoq/blob/main/client/package.json.
  -- "vscoq.path", "vscoq.args", and "vscoq.trace.server" should be configured in the "lsp" table below.
  -- The following is an example.
  vscoq = {
    proof = {
      mode = 0, -- manual mode
    },
  },

  -- The configuration forwarded to `:help lspconfig-setup`.
  -- The following is an example.
  lsp = {
    on_attach = function(client, bufnr)
      -- your mappings, etc
    end,
    autostart = false, -- use this if you want to manually `:LspStart vscoqtop`.
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
