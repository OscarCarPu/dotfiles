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
        "isort", -- Python import sorter
        "debugpy", -- Python debugger
      },
    },
  },

  -- Configure formatters for Python
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "isort", "black" },
      },
      formatters = {
        black = {
          prepend_args = { "--line-length", "100" },
        },
        isort = {
          prepend_args = { "--profile", "black" },
        },
      },
    },
  },
}
