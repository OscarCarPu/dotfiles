local jdtls = require "jdtls"

vim.api.nvim_create_autocmd("FileType", {
  pattern = "java",
  callback = function()
    local config = {
      cmd = { "jdtls" },
      root_dir = vim.fs.root(0, { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }),
    }
    jdtls.start_or_attach(config)
  end,
})
