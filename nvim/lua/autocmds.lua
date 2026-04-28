require "nvchad.autocmds"

vim.api.nvim_create_autocmd("User", {
  pattern = "FilePost",
  once = true,
  callback = function()
    vim.schedule(function()
      require("nvim-tree.api").tree.open { focus = false }
    end)
  end,
})
