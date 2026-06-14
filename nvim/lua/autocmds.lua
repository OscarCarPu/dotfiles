require "nvchad.autocmds"

-- Auto-install treesitter parsers from ensure_installed on startup
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local ok, lazy = pcall(require, "lazy.core.config")
    if not ok then return end
    local spec = lazy.plugins["nvim-treesitter"]
    local opts = spec and type(spec.opts) == "table" and spec.opts or {}
    if opts.ensure_installed then
      require("nvim-treesitter").install(opts.ensure_installed)
    end
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "FilePost",
  once = true,
  callback = function()
    local arg = vim.fn.argv(0)
    if arg ~= "" and vim.fn.isdirectory(arg) == 1 then
      vim.schedule(function()
        vim.cmd("cd " .. vim.fn.fnameescape(arg))
        require("nvim-tree.api").tree.open { focus = true }
      end)
    end
  end,
})
