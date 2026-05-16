require "nvchad.autocmds"

vim.api.nvim_create_autocmd("User", {
  pattern = "FilePost",
  once = true,
  callback = function()
    local arg = vim.fn.argv(0)
    if arg ~= "" and vim.fn.isdirectory(arg) == 1 then
      vim.schedule(function()
        require("nvim-tree.api").tree.open { focus = false }
      end)
    end
  end,
})
