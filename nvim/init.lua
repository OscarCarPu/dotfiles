-- Basic settings
vim.opt.number = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.g.mapleader = " "

-- lazy.nvim
local lazypath = vim.fn.stdpath('data') .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- lazy.nvim setup
require("lazy").setup({
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000
  },
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = { "nvim-lua/plenary.nvim" }
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate"
  },
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" }
  },
  { "github/copilot.vim" }
})

-- Catppuccin
require("catppuccin").setup({
  flavour = "mocha",
  transparent_background = false
})
vim.cmd [[colorscheme catppuccin]]

-- Treesitter setup
require("nvim-treesitter.configs").setup {
  ensure_installed = { "lua", "python", "javascript", "cpp", "bash", "html", "css", "json", "yaml", "sql" },
  highlight = {
    enable = true
  }
}

-- Telescope setup
local telescope = require("telescope.builtin")
vim.keymap.set("n","<leader>ff", telescope.find_files, {})
vim.keymap.set("n","<leader>fg",telescope.live_grep, {}) -- Seach text
vim.keymap.set("n","<leader>fb",telescope.buffers, {})

-- Nvim Tree
require("nvim-tree").setup({
  view = { width = 30 },
  renderer = { icons = { show = {
    file = true,
    folder = true,
    folder_arrow = true,
    git = true
  }}}
})

vim.keymap.set("n","<leader>e",":NvimTreeToggle<CR>", {})

-- Copilot setup
vim.g.copilot_no_tab_map = true
local map = function (type, key, value, opts)
  local options = { noremap = true, silent = true }
  if opts then options = vim.tbl_extend("force", options, opts) end
  vim.api.nvim_set_keymap(type, key, value, options)
end
map("i", "<C-j>", 'copilot#Accept("<CR>")', { expr = true, silent = true, expr=true })


