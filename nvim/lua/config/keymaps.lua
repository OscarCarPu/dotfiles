-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Show full diagnostic message in floating window
vim.keymap.set("n", "gl", function()
  vim.diagnostic.open_float(nil, { focusable = true, scope = "cursor" })
end, { desc = "Show full diagnostic message" })

-- AI Chat Keybindings (CopilotChat)
-- <leader>aa - Ask Copilot about current file (opens chat with file context)
vim.keymap.set("n", "<leader>aa", ":Ask<cr>", { desc = "Ask Copilot about current file" })

-- <leader>ac - Toggle existing chat window
vim.keymap.set("n", "<leader>ac", "<cmd>CopilotChatToggle<cr>", { desc = "Toggle Copilot chat" })

-- <leader>ae - Explain current code
vim.keymap.set("n", "<leader>ae", "<cmd>CopilotChatExplain<cr>", { desc = "Explain code" })

-- <leader>at - Generate tests for current code
vim.keymap.set("n", "<leader>at", "<cmd>CopilotChatTests<cr>", { desc = "Generate tests" })

-- <leader>af - Fix code issues
vim.keymap.set("n", "<leader>af", "<cmd>CopilotChatFix<cr>", { desc = "Fix code issues" })

-- <leader>ao - Optimize code
vim.keymap.set("n", "<leader>ao", "<cmd>CopilotChatOptimize<cr>", { desc = "Optimize code" })

-- <leader>ad - Generate documentation
vim.keymap.set("n", "<leader>ad", "<cmd>CopilotChatDocs<cr>", { desc = "Generate docs" })

-- Visual mode - Ask Copilot about selected code
vim.keymap.set("v", "<leader>aa", function()
  local input = vim.fn.input("Quick Chat: ")
  if input ~= "" then
    require("CopilotChat").ask(input, { selection = require("CopilotChat.select").visual })
  end
end, { desc = "Ask Copilot about selection" })

-- Visual mode - Explain selected code
vim.keymap.set("v", "<leader>ae", "<cmd>CopilotChatExplain<cr>", { desc = "Explain selection" })

-- Visual mode - Fix selected code
vim.keymap.set("v", "<leader>af", "<cmd>CopilotChatFix<cr>", { desc = "Fix selection" })

-- Visual mode - Optimize selected code
vim.keymap.set("v", "<leader>ao", "<cmd>CopilotChatOptimize<cr>", { desc = "Optimize selection" })

-- <leader>an - Open full chat window
vim.keymap.set("n", "<leader>an", "<cmd>CopilotChat<cr>", { desc = "Open Copilot chat" })
