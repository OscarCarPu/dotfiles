-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
--

-- Configure diagnostics virtual text to truncate after LazyVim loads
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function()
    vim.diagnostic.config({
      virtual_text = {
        format = function(diagnostic)
          -- Calculate max width based on screen size and cursor position
          local max_width = 40 -- Conservative default
          if #diagnostic.message > max_width then
            return diagnostic.message:sub(1, max_width - 3) .. "..."
          end
          return diagnostic.message
        end,
        prefix = "●",
        spacing = 4,
      },
    })
  end,
})
