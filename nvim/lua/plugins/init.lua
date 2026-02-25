return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre", -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "vim",
        "lua",
        "vimdoc",
        "html",
        "css",
        "go",
        "gomod",
        "gosum",
        "rust",
        "toml",
        "kotlin",
        "java",
        "xml",
      },
    },
  },

  -- Show gitignored files in nvim-tree
  {
    "nvim-tree/nvim-tree.lua",
    opts = {
      git = {
        enable = true,
        ignore = false,
      },
    },
  },

  -- Rust crate dependency version checking
  {
    "saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    opts = {},
  },

  -- Mason: ensure Android/Java/XML tooling is installed
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "kotlin-language-server",
        "ktlint",
        "lemminx",
      },
    },
  },

  -- Enhanced Java LSP support via jdtls
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    config = function()
      require "configs.java"
    end,
  },

  -- Android: build, run, and Logcat in Nvim
  {
    "iamironz/android-nvim-plugin",
    ft = { "kotlin", "java", "xml" },
    opts = {},
  },
}
