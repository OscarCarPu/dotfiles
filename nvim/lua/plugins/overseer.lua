-- Task runner with beautiful output display
return {
  {
    "stevearc/overseer.nvim",
    cmd = {
      "OverseerRun",
      "OverseerToggle",
      "OverseerOpen",
      "OverseerBuild",
    },
    keys = {
      { "<leader>mt", "<cmd>OverseerToggle<cr>", desc = "Toggle task list" },
      { "<leader>mr", "<cmd>OverseerRun<cr>", desc = "Run task" },
      { "<leader>mb", "<cmd>OverseerBuild<cr>", desc = "Build (make)" },
    },
    opts = {
      task_list = {
        direction = "bottom",
        min_height = 15,
        max_height = 25,
        default_detail = 2,
      },
      -- Automatically open the task output when running
      task_launcher = {
        bindings = {
          n = {
            ["<CR>"] = "Submit",
            ["<C-c>"] = "Cancel",
          },
        },
      },
    },
    config = function(_, opts)
      local overseer = require("overseer")
      overseer.setup(opts)

      -- Override :make to use overseer
      vim.api.nvim_create_user_command("Make", function(params)
        local args = params.args
        local cmd = vim.o.makeprg
        if args and args ~= "" then
          cmd = cmd .. " " .. args
        end
        overseer.run_template({ name = "shell", params = { cmd = cmd } }, function(task)
          if task then
            overseer.open({ enter = false })
          end
        end)
      end, { nargs = "*", desc = "Run make with overseer" })

      -- Keymap to run make quickly
      vim.keymap.set("n", "<leader>mm", function()
        overseer.run_template({ name = "shell", params = { cmd = vim.o.makeprg } }, function(task)
          if task then
            overseer.open({ enter = false })
          end
        end)
      end, { desc = "Make (overseer)" })
    end,
  },
}
