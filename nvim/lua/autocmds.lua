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

-- PDFs are not text: open them in tdf (a kitty split) when possible, else draw them in a buffer
-- (pdfview) instead of a binary one
vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = "*.pdf",
  callback = function(args)
    local tdf = require "tdfview"
    if not tdf.available() then return require("pdfview").attach(args.buf, args.file) end
    tdf.open(args.file)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(args.buf) then vim.api.nvim_buf_delete(args.buf, { force = true }) end
    end)
  end,
})
