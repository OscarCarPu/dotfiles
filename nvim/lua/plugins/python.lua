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
        -- Configure ruff-lsp for linting (includes E501 line-too-long)
        ruff_lsp = {
          settings = {
            lineLength = 100,
            lint = {
              select = { "E", "F", "W" }, -- Enable pycodestyle errors, pyflakes, warnings
              -- E501 is line-too-long - will show warnings for lines > 100 chars
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
  -- NOTE: Auto-format on save is DISABLED for Python because Black collapses
  -- long strings to exceed 100 chars, breaking flake8 E501 compliance.
  --
  -- MANUAL FORMATTING:
  --   - Format entire file: <leader>cf (LazyVim default)
  --   - Format selection: Select text in visual mode, then <leader>cf
  --
  -- WORKFLOW:
  --   1. Write/edit code normally
  --   2. Manually format when ready: <leader>cf
  --   3. If ruff-lsp shows E501 errors (red squiggles on long lines):
  --      - Split long strings:
  --        result = (
  --            f"Part 1 {var1} "
  --            f"Part 2 {var2}"
  --        )
  --   4. Format again to ensure isort + black are applied
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      -- Disable format on save for Python files only
      opts.format_on_save = function(bufnr)
        if vim.bo[bufnr].filetype == "python" then
          return nil -- Disable auto-format for Python
        end
        return { timeout_ms = 500, lsp_fallback = true }
      end

      -- Configure formatters
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.python = { "isort", "black" }

      opts.formatters = opts.formatters or {}
      opts.formatters.black = {
        prepend_args = { "--line-length", "100" },
      }
      opts.formatters.isort = {
        prepend_args = { "--profile", "black" },
      }

      return opts
    end,
  },
}
