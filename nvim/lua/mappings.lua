require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file explorer" })

-- search
map("n", "<leader>sg", "<cmd>Telescope live_grep<CR>", { desc = "Search by grep (cwd)" })
map("n", "<leader>sG", "<cmd>Telescope live_grep cwd=false<CR>", { desc = "Search by grep (root)" })
map("n", "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<CR>", { desc = "Search buffer" })
map("n", "<leader>sf", "<cmd>Telescope find_files<CR>", { desc = "Search files" })
map("n", "<leader>sh", "<cmd>Telescope help_tags<CR>", { desc = "Search help" })
map("n", "<leader>sk", "<cmd>Telescope keymaps<CR>", { desc = "Search keymaps" })
map("n", "<leader>sm", "<cmd>Telescope marks<CR>", { desc = "Search marks" })
map("n", "<leader>sr", "<cmd>Telescope resume<CR>", { desc = "Search resume" })
map("n", "<leader>sw", "<cmd>Telescope grep_string<CR>", { desc = "Search word under cursor" })
map("n", "<leader>s\"", "<cmd>Telescope registers<CR>", { desc = "Search registers" })
map("n", "<leader>sd", "<cmd>Telescope diagnostics<CR>", { desc = "Search diagnostics" })
map("n", "<leader>ss", "<cmd>Telescope lsp_document_symbols<CR>", { desc = "Search document symbols" })
map("n", "<leader>sS", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", { desc = "Search workspace symbols" })
