vim.lsp.config("gopls", {
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
      },
      staticcheck = true,
      gofumpt = true,
    },
  },
})

-- auto-import on save (silent: no-op when gopls is absent or imports are clean)
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function(ev)
    local client = vim.lsp.get_clients({ bufnr = ev.buf, name = "gopls" })[1]
    if not client then
      return
    end
    local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
    params.context = { only = { "source.organizeImports" }, diagnostics = {} }
    local result = client:request_sync("textDocument/codeAction", params, 1000, ev.buf)
    for _, action in ipairs(result and result.result or {}) do
      if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
      end
    end
  end,
})
