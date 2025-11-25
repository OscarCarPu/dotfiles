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

  -- AI Chat with GitHub Copilot
  -- Provides interactive chat with GitHub Copilot (free for students)
  -- Requires GitHub Copilot authentication
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary",
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim" },
    },
    event = "VeryLazy",
    opts = {
      question_header = "## User ",
      answer_header = "## Copilot ",
      error_header = "## Error ",
      separator = "───",
      show_folds = false,
      show_help = false,
      auto_follow_cursor = true,
      auto_insert_mode = false,
      clear_chat_on_new_prompt = false,
      context = "buffers",
      window = {
        layout = "vertical", -- 'vertical', 'horizontal', 'float'
        width = 0.4,
        height = 0.6,
        relative = "editor",
      },
      mappings = {
        complete = {
          detail = "Use @<Tab> or /<Tab> for options.",
          insert = "<Tab>",
        },
        close = {
          normal = "q",
          insert = "<C-c>",
        },
        reset = {
          normal = "<C-r>",
          insert = "<C-r>",
        },
        submit_prompt = {
          normal = "<CR>",
          insert = "<C-s>",
        },
        accept_diff = {
          normal = "<C-y>",
          insert = "<C-y>",
        },
        yank_diff = {
          normal = "gy",
        },
        show_diff = {
          normal = "gd",
        },
        show_system_prompt = {
          normal = "gp",
        },
        show_user_selection = {
          normal = "gs",
        },
      },
    },
    config = function(_, opts)
      local chat = require("CopilotChat")
      chat.setup(opts)

      -- Custom :Ask command that opens chat with file context
      vim.api.nvim_create_user_command("Ask", function(cmd_opts)
        local input = vim.fn.input("Quick Chat: ")
        if input ~= "" then
          chat.ask(input, { selection = require("CopilotChat.select").buffer })
        end
      end, { nargs = "*", desc = "Ask Copilot about current file" })
    end,
  },
}
