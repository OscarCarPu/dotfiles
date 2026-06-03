require("nvchad.configs.lspconfig").defaults()

require "configs.go"
require "configs.rust"
require "configs.kotlin"
require "configs.xml"
require "configs.python"
require "configs.svelte"

local servers = { "html", "cssls", "ts_ls", "gopls", "rust_analyzer", "kotlin_ls", "lemminx", "svelte", "pyright" }
vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers
