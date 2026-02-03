require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file explorer" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
