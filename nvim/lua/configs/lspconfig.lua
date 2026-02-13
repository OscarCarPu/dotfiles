require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "gopls", "rust_analyzer" }
vim.lsp.enable(servers)

require "configs.go"
require "configs.rust"

-- read :h vim.lsp.config for changing options of lsp servers
