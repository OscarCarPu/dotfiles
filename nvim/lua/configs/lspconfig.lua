require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "gopls", "rust_analyzer", "kotlin_ls", "lemminx", "svelte", "pyright" }
vim.lsp.enable(servers)

require "configs.go"
require "configs.rust"
require "configs.kotlin"
require "configs.xml"
require "configs.python"

-- read :h vim.lsp.config for changing options of lsp servers
