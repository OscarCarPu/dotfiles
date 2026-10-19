-- Live preview: the buffer already is Typst, so it is compiled as is
require("mdpreview").attach("Typst", function(text, out, done)
  vim.fn.writefile(vim.split(text, "\n", { plain = true }), out)
  done(0, "")
end)

vim.keymap.set("n", "<leader>me", function()
  local pdf = vim.fn.expand "%:p:r" .. ".pdf"
  vim.system({ "typst", "compile", "--root", vim.fn.expand "%:p:h", vim.fn.expand "%:p", pdf }, {}, function(r)
    vim.schedule(function()
      vim.notify(r.code == 0 and ("Exported " .. pdf) or r.stderr, r.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
    end)
  end)
end, { desc = "Typst: export PDF", buffer = true })
