-- Rust Language Support
-- Note: LazyVim Rust extras are imported in lazy.lua for correct load order
return {
  -- Override LSP configuration for better Rust support
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true,
                loadOutDirsFromCheck = true,
                buildScripts = {
                  enable = true,
                },
              },
              -- Add clippy lints on save
              checkOnSave = {
                command = "clippy",
              },
              procMacro = {
                enable = true,
              },
            },
          },
        },
      },
    },
  },

  -- Additional Rust tools
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "rust-analyzer", -- Rust LSP
        "codelldb", -- Rust debugger
      },
    },
  },

  -- Configure rustfmt as formatter for Rust
  -- Note: rustfmt reads configuration from rustfmt.toml or .rustfmt.toml automatically
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        rust = { "rustfmt" },
      },
    },
  },
}
