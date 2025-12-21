-- Go Language Support
-- Note: LazyVim Go extras are imported in lazy.lua for correct load order
return {
  -- Ensure Go tools are installed via Mason
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "goimports",
        "gofumpt",
      },
    },
  },
  -- Configure nvim-lint to only run golangci-lint in Go modules
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters = {
        golangcilint = {
          -- Only run if go.mod exists in the project
          condition = function(ctx)
            return vim.fs.find({ "go.mod" }, { path = ctx.filename, upward = true })[1]
          end,
        },
      },
    },
  },
  -- Override LSP configuration for better Go support
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = {
          settings = {
            gopls = {
              analyses = {
                unusedparams = true,
                shadow = true,
                nilness = true,
                unusedwrite = true,
                useany = true,
              },
              staticcheck = true,
              gofumpt = true,
              usePlaceholders = true,
              completeUnimported = true,
            },
          },
        },
      },
    },
  },

  -- Configure goimports as formatter for Go
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        go = { "goimports", "gofumpt" },
      },
    },
  },
}
