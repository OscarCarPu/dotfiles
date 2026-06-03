vim.lsp.config("svelte", {
  on_attach = function(client)
    -- Notify svelte LSP when TS/JS dependencies change so it re-checks types
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = vim.api.nvim_create_augroup("svelte_ts_notify", { clear = true }),
      pattern = { "*.js", "*.ts" },
      callback = function(ctx)
        client.notify("$/onDidChangeTsOrJsFile", { uri = ctx.match })
      end,
    })
  end,
})
