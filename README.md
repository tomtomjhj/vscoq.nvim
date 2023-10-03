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
* Ex commands
    * `:ToggleManual`: Toggle proof mode between "Continuous" (default, show goals for the cursor position) and "Manual" modes.
    * manual mode:
        * `:InterpretToPoint`
        * `:Forward`
        * `:Backward`
        * `:ToEnd`
    * `:Panels`: Open auxiliary panels for the current buffer.
* [Commands from nvim-lspconfig](https://github.com/neovim/nvim-lspconfig#commands)
  work as expected.
  For example, run `:LspRestart` to restart `vscoqtop`.

## Configurations

```lua
require'vscoq'.setup {
  -- Configuration for vscoq, used in both the client and the server.
  -- See "configuration" in https://github.com/coq-community/vscoq/blob/main/client/package.json.
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
    autostart = false, -- use this if you want to manually launch vscoqtop with :LspStart.
  },
}
```

NOTE:
Do not call `lspconfig.vscoqtop.setup()` yourself.
`require'vscoq'.setup` does it for you.

## Features not implmented yet
* Queries
* Messages
* Well-organized goal panel
