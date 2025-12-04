-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Show full diagnostic message in floating window
vim.keymap.set("n", "gl", function()
  vim.diagnostic.open_float(nil, { focusable = true, scope = "cursor" })
end, { desc = "Show full diagnostic message" })
