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
        "ruff", -- Fast Python linter and formatter (replaces black, isort, flake8)
        "debugpy", -- Python debugger
      },
    },
  },

  -- Configure ruff as formatter and linter for Python
  -- Ruff combines black, isort, flake8, and more in a single fast tool
  -- Note: Ruff reads line-length=100 from pyproject.toml automatically
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "ruff_organize_imports", "ruff_format" },
      },
      -- No need to configure formatters here - ruff reads from pyproject.toml
    },
  },

  -- Configure ruff linter
  -- Note: Ruff LSP reads configuration from pyproject.toml automatically
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ruff_lsp = {
          -- Configuration is read from pyproject.toml
        },
      },
    },
  },
}
