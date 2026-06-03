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
        "markdown",
        "svelte",
        "javascript",
        "typescript",
        "python",
      },
      indent = {
        enable = true,
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
        "svelte-language-server",
        "typescript-language-server",
        "vscode-langservers-extracted",
        "prettier",
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

  -- Surround selections with brackets, quotes, tags, etc.
  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    opts = {},
  },

  -- Competitive programming (Codeforces, AtCoder, ...) via Competitive Companion
  {
    "xeluxee/competitest.nvim",
    dependencies = "MunifTanjim/nui.nvim",
    cmd = "CompetiTest",
    opts = {
      received_files_extension = "rs",
      template_file = vim.fn.expand "~/dev/CP/templates/template.rs",
      evaluate_template_modifiers = true,
      -- "A. Koshary and Some Numbers" -> "A.rs"
      received_problems_path = function(task, ext)
        local letter = task.name:match "^(%w+)" or "problem"
        return string.format("%s/%s.%s", vim.fn.getcwd(), letter, ext)
      end,
      received_contests_problems_path = function(task, ext)
        local letter = task.name:match "^(%w+)" or "problem"
        return string.format("%s.%s", letter, ext)
      end,
      compile_command = {
        rust = { exec = "rustc", args = { "-O", "--crate-name", "sol", "$(FNAME)", "-o", "sol" } },
      },
      run_command = {
        rust = { exec = "./sol" },
      },
    },
  },

}
