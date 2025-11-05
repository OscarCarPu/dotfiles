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
          init_options = {
            settings = {
              -- Ruff settings - will also read from pyproject.toml
              lineLength = 100,
              lint = {
                select = ["E", "F", "W"], -- pycodestyle errors, pyflakes, warnings
                -- E501 is line-too-long - shows errors for lines > 100 chars
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
        "ruff", -- Fast Python linter & formatter (replaces black, isort, flake8)
        "ruff-lsp", -- Ruff language server for real-time linting
        "debugpy", -- Python debugger
      },
    },
  },

  -- Configure Ruff formatter for Python
  -- NOTE: Auto-format on save is DISABLED for Python because Ruff (like Black)
  -- collapses long strings to exceed 100 chars, breaking E501 compliance.
  --
  -- MANUAL FORMATTING:
  --   - Format entire file: <leader>cf (LazyVim default)
  --   - Format selection: Select text in visual mode, then <leader>cf
  --
  -- WORKFLOW:
  --   1. Write/edit code normally
  --   2. Manually format when ready: <leader>cf (runs ruff format)
  --   3. If ruff-lsp shows E501 errors (red squiggles on long lines):
  --      - Split long strings:
  --        result = (
  --            f"Part 1 {var1} "
  --            f"Part 2 {var2}"
  --        )
  --   4. Format again: <leader>cf
  --
  -- Benefits of Ruff:
  --   - 10-100x faster than black + isort + flake8
  --   - Single tool for formatting + linting + import sorting
  --   - Black-compatible formatting style
  --   - Industry standard (used by FastAPI, pandas, pydantic)
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

      -- Configure Ruff formatter
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.python = { "ruff_format", "ruff_organize_imports" }

      opts.formatters = opts.formatters or {}
      opts.formatters.ruff_format = {
        prepend_args = { "--line-length", "100" },
      }
      opts.formatters.ruff_organize_imports = {
        prepend_args = { "--select", "I" },
      }

      return opts
    end,
  },
}
