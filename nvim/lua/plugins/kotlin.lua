-- Kotlin Language Support
return {
  -- Ensure Kotlin treesitter parser is installed
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "kotlin", "xml" },
    },
  },

  -- Configure Kotlin language server
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        kotlin_language_server = {
          root_dir = function(fname)
            return require("lspconfig").util.root_pattern(
              "settings.gradle",
              "settings.gradle.kts",
              "build.gradle",
              "build.gradle.kts"
            )(fname)
          end,
          settings = {
            kotlin = {
              compiler = {
                jvm = {
                  target = "17",
                },
              },
            },
          },
        },
      },
    },
  },

  -- Configure ktlint as formatter for Kotlin
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        kotlin = { "ktlint" },
      },
    },
  },
}
