-- Python Language Support
-- Note: LazyVim Python extras are imported in lazy.lua for correct load order
return {
  -- Override LSP configuration for better Python support
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "basic",
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "workspace",
              },
            },
          },
        },
      },
    },
  },

  -- Additional Python tools
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "pyright", -- Python LSP
        "ruff-lsp", -- Fast Python linter
        "black", -- Python formatter
        "debugpy", -- Python debugger
      },
    },
  },
}
