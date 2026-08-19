local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    go = { "gofumpt", "goimports" },
    kotlin = { "ktlint" },
    rust = { "rustfmt" },
    python = { "ruff_format" },
    sql = { "sqlfluff" },
    css = { "prettier" },
    html = { "prettier" },
    svelte = { "prettier" },
    javascript = { "prettier" },
    typescript = { "prettier" },
    javascriptreact = { "prettier" },
    typescriptreact = { "prettier" },
  },

  formatters = {
    -- `fix` exits 1 on unfixable lint violations, which conform reads as a
    -- failed format; `format` only rewrites layout and exits 0. require_cwd is
    -- off because ~/.sqlfluff supplies the dialect outside project trees.
    sqlfluff = {
      args = { "format", "-" },
      require_cwd = false,
    },
  },

  format_on_save = {
    timeout_ms = 2000,
    lsp_format = "fallback",
  },
}

return options
