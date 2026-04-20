vim.lsp.config("rust_analyzer", {
  settings = {
    ["rust-analyzer"] = {
      imports = {
        granularity = { group = "module" },
        prefix = "self",
      },
      cargo = {
        allFeatures = true,
        buildScripts = { enable = true },
      },
      procMacro = { enable = true },
      checkOnSave = true,
      check = {
        command = "clippy",
      },
      completion = {
        autoimport = { enable = true },
        fullFunctionSignatures = { enable = true },
        callable = { snippets = "fill_arguments" },
        postfix = { enable = true },
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
