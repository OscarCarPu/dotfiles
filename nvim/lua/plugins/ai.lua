-- AI-powered code completion with GitHub Copilot
-- Note: LazyVim uses blink.cmp by default, which is incompatible with copilot-cmp
-- Copilot works standalone with inline suggestions (ghost text)
-- Copilot is disabled by default - use :Copilot enable to activate it
return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      suggestion = {
        enabled = false, -- Disabled by default
        auto_trigger = false, -- Don't auto-trigger when disabled
        hide_during_completion = true,
        debounce = 75,
        keymap = {
          accept = "<M-l>",
          accept_word = false,
          accept_line = false,
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
      panel = {
        enabled = true,
        auto_refresh = false,
        keymap = {
          jump_prev = "[[",
          jump_next = "]]",
          accept = "<CR>",
          refresh = "gr",
          open = "<M-CR>",
        },
        layout = {
          position = "bottom", -- | top | left | right
          ratio = 0.4,
        },
      },
      filetypes = {
        yaml = false,
        markdown = false,
        help = false,
        gitcommit = false,
        gitrebase = false,
        hgcommit = false,
        svn = false,
        cvs = false,
        ["."] = false,
      },
      copilot_node_command = "node", -- Node.js version must be > 18.x
      server_opts_overrides = {},
    },
  },
}
