vim.lsp.config("pyright", {
  settings = {
    python = {
      venvPath = ".",
      venv = ".venv",
      analysis = {
        typeCheckingMode = "off",
        diagnosticSeverityOverrides = {
          reportUndefinedVariable = "error",
          reportMissingImports = "error",
        },
      },
    },
  },
})
