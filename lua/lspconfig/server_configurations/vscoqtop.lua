local util = require('lspconfig.util')

return {
  default_config = {
    cmd = { 'vscoqtop' },
    filetypes = { 'coq' },
    root_dir = function(fname)
      return util.root_pattern('_CoqProject')(fname) or util.find_git_ancestor(fname)
    end,
    -- TODO: single_file_support?
    single_file_support = true,
  },
  docs = {
    description = [[
https://github.com/coq-community/vscoq
]],
  },
}
