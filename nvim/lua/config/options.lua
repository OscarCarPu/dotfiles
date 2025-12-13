-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Enable system clipboard integration
vim.opt.clipboard = "unnamedplus"

-- Use OSC 52 for clipboard when in SSH session (works with Kitty)
if os.getenv("SSH_TTY") then
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
      ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
    },
  }
end

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

-- JSON-specific settings (2 spaces for JSON)
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "json", "jsonc" },
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
    -- Show source and error code for easier suppression with noqa/type: ignore
    format = function(diagnostic)
      local code = diagnostic.code and string.format("[%s]", diagnostic.code) or ""
      local source = diagnostic.source and string.format("(%s)", diagnostic.source) or ""
      local msg = diagnostic.message
      if #msg > 60 then
        msg = msg:sub(1, 57) .. "..."
      end
      return string.format("%s %s %s", source, code, msg)
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
