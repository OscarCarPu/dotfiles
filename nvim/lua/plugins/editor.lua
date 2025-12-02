-- Editor behavior customizations
return {
  -- Configure Trouble.nvim to wrap long diagnostic messages
  {
    "folke/trouble.nvim",
    opts = {
      auto_preview = false,
      modes = {
        diagnostics = {
          auto_open = false,
          auto_close = false,
          auto_preview = false,
          -- Enable word wrap for long messages
          win = {
            type = "split",
            position = "bottom",
            size = 10,
            wo = {
              wrap = true,
              linebreak = true,
            },
          },
        },
      },
    },
  },
  -- Configure Snacks file explorer to show gitignored files
  {
    "folke/snacks.nvim",
    opts = {
      explorer = {
        filters = {
          git_ignored = false,
          hidden = false,
        },
      },
    },
  },
}
