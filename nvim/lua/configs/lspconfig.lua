require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "gopls", "rust_analyzer", "kotlin_ls", "lemminx" }
vim.lsp.enable(servers)

require "configs.go"
require "configs.rust"
require "configs.kotlin"
require "configs.xml"

-- read :h vim.lsp.config for changing options of lsp servers
