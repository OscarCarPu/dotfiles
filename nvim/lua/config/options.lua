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

-- (2 spaces )
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "html", "htm", "htmldjango", "lua", "svelte", "typescript", "typescriptreact", "javascript", "javascriptreact" },
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
    wrap = true,
    max_width = 80,
    border = "rounded",
    wrap_at = 80,
  },
  virtual_text = {
    prefix = "●",
    spacing = 4,
    -- Filter out "unnecessary" tagged diagnostics and format the rest
    format = function(diagnostic)

      -- Hide diagnostics with "unnecessary" tag (LSP tag 1)
      if diagnostic._tags and diagnostic._tags.unnecessary then
        return ""
      end
      -- Also check user_data.lsp.tags for tag 1 (Unnecessary)
      if diagnostic.user_data and diagnostic.user_data.lsp and diagnostic.user_data.lsp.tags then
        for _, tag in ipairs(diagnostic.user_data.lsp.tags) do
          if tag == 1 then
            return ""
          end
        end
      end
      local code = diagnostic.code and string.format("[%s]", diagnostic.code) or ""
      local source = diagnostic.source and string.format("(%s)", diagnostic.source) or ""
      local msg = diagnostic.message
      if #msg > 60 then
        msg = msg:sub(1, 57) .. "..."
      end
      return string.format("%s %s %s", source, code, msg)
    end,
  },
  signs = true,
  underline = {
    -- Don't underline "unnecessary" diagnostics
    severity = { min = vim.diagnostic.severity.HINT },
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
