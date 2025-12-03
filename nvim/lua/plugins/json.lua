-- JSON formatting configuration
return {
  -- Configure Python's json module as formatter for JSON (no external dependencies)
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        json = { "python_json" },
        jsonc = { "python_json" },
      },
      formatters = {
        python_json = {
          command = "python3",
          args = { "-m", "json.tool", "--indent", "2" },
          stdin = true,
        },
      },
    },
  },
}
