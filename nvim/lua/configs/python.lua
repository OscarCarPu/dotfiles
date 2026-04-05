vim.lsp.config("pyright", {
  settings = {
    python = {
      venvPath = ".",
      venv = ".venv",
    },
  },
})
