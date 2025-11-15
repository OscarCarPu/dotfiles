-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
--
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4

-- HTML-specific settings (2 spaces for HTML)
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "html", "htm", "htmldjango" },
  callback = function()
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
    vim.bo.expandtab = true
  end,
})

-- Enable line wrapping
vim.opt.wrap = true -- Wrap long lines
vim.opt.linebreak = true -- Break lines at word boundaries
vim.opt.breakindent = true -- Maintain indent when wrapping

-- Configure diagnostic floating windows to wrap text
vim.diagnostic.config({
  float = {
    wrap = true, -- Enable text wrapping in diagnostic windows
    max_width = 80, -- Maximum width before wrapping
    border = "rounded",
    wrap_at = 80, -- Alternative wrap configuration
  },
  virtual_text = {
    -- Truncate long virtual text messages to prevent overflow
    format = function(diagnostic)
      if #diagnostic.message > 80 then
        return diagnostic.message:sub(1, 77) .. "..."
      end
      return diagnostic.message
    end,
    -- Alternative: you can also add a prefix and spacing
    prefix = "●",
    spacing = 4,
  },
})

-- Configure LSP hover windows to wrap
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
  border = "rounded",
  max_width = 80,
  wrap = true,
  wrap_at = 80,
})

-- Configure LSP signature help to wrap
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
  border = "rounded",
  max_width = 80,
  wrap = true,
  wrap_at = 80,
})
