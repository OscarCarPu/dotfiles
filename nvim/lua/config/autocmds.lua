vim.api.nvim_create_autocmd("LspAttach", {
  callback = function()
    vim.diagnostic.config({
      virtual_text = {
        format = function(diagnostic)
          -- Truncate long messages
          local max_width = 40
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
