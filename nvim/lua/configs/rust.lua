vim.lsp.config("rust_analyzer", {
  settings = {
    ["rust-analyzer"] = {
      imports = {
        granularity = { group = "module" },
        prefix = "self",
      },
      cargo = {
        allFeatures = true,
      },
      checkOnSave = {
        command = "clippy",
      },
    },
  },
})

-- auto-import on save
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.rs",
  callback = function()
    vim.lsp.buf.code_action({
      context = { only = { "source.organizeImports" } },
      apply = true,
    })
    vim.wait(100)
  end,
})
