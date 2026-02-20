vim.lsp.config("kotlin_ls", {
  settings = {
    kotlin = {
      compiler = {
        jvm = {
          target = "17",
        },
      },
    },
  },
})
