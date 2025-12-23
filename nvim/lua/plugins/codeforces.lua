-- Competitive programming integration with assistant.nvim
return {
  {
    "A7lavinraj/assistant.nvim",
    lazy = false,
    keys = {
      { "<leader>a", "<cmd>Assistant<cr>", desc = "Assistant.nvim" },
    },
    opts = {
      commands = {
        python = vim.NIL, -- Remove default python
        cpp = {
          extension = "cpp",
          template = vim.fn.expand("~/dev/codeforces/templates/template.cpp"),
          compile = {
            main = "g++",
            args = { "-std=c++23", "-O2", "$FILENAME_WITH_EXTENSION", "-o", "$FILENAME_WITHOUT_EXTENSION" },
          },
          execute = {
            main = "./$FILENAME_WITHOUT_EXTENSION",
            args = nil,
          },
        },
      },
      core = {
        process_budget = 5000,
        port = 10043,
        -- Converts "ATaskName" -> "A_Task_Name" to match your existing file naming
        filename_generator = function(task_class)
          -- Insert underscore before each capital letter (except first), then uppercase all
          local name = task_class:gsub("(%u)", "_%1"):sub(2)
          return name
        end,
      },
      ui = {
        border = "rounded",
      },
    },
  },
}
