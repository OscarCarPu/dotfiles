vim.api.nvim_create_autocmd("LspAttach", {
  callback = function()
    vim.diagnostic.config({
      virtual_text = {
        format = function(diagnostic)
          local source_prefix = ""
          if diagnostic.source then
            source_prefix = "[" .. diagnostic.source .. "] "
          end
          -- Truncate long messages
          local max_width = 40
          local full_message = source_prefix .. diagnostic.message
          if #full_message > max_width then
            return full_message:sub(1, max_width - 3) .. "..."
          end
          return full_message
        end,
        prefix = "●",
        spacing = 4,
      },
    })
  end,
})
