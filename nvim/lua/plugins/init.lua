return {
  { "folke/which-key.nvim", event = "VeryLazy" },

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

  -- accept completion with Shift+Enter; plain Enter always inserts a newline
  {
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      local cmp = require "cmp"
      opts.mapping["<CR>"] = cmp.config.disable
      opts.mapping["<S-CR>"] = cmp.mapping.confirm {
        behavior = cmp.ConfirmBehavior.Insert,
        select = true,
      }
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
        "typst",
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

  -- Highlight and search TODO, NOTE, WARNING, etc. in comments
  {
    "folke/todo-comments.nvim",
    dependencies = "nvim-lua/plenary.nvim",
    event = "VeryLazy",
    opts = {
      signs = true,
      keywords = {
        TODO = { icon = " ", color = "info" },
        NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
        WARNING = { icon = " ", color = "warning", alt = { "WARN", "XXX" } },
      },
    },
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

  -- Typst live preview (browser, updates as you type)
  {
    "chomosuke/typst-preview.nvim",
    ft = "typst",
    opts = {
      dependencies_bin = { tinymist = "tinymist" },
    },
  },

  -- Inline images (kitty graphics protocol) in buffers: PDF viewer and Typst preview
  {
    "folke/snacks.nvim",
    lazy = false,
    opts = {
      image = {
        enabled = true,
        -- snacks' own viewer only draws a PDF's first page: pdfview (lua/pdfview.lua) handles *.pdf
        formats = { "png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff", "heic", "avif", "mp4", "mov", "avi", "mkv", "webm", "icns" },
      },
    },
  },
}
