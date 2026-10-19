-- Disable friendly-snippets for markdown to prevent unwanted callout insertion
local ls = require("luasnip")
ls.filetype_set("markdown", {})

-- Live preview: pandoc (paper defaults) -> Typst. Pandoc reads the buffer from stdin.
local dir = vim.fn.expand "%:p:h"
local base = vim.fn.expand "%:t:r"
require("mdpreview").attach("Markdown", function(text, out, done)
  local job = vim.fn.jobstart({ "pandoc", "-d", "paper", "--resource-path", dir, "-M", "mermaid_dir=" .. dir, "-o", out }, {
    stdin = "pipe",
    on_exit = function(_, code) done(code, code ~= 0 and "error: pandoc failed" or "") end,
  })
  vim.fn.chansend(job, text)
  vim.fn.chanclose(job, "stdin")
end)

vim.keymap.set("n", "<leader>me", function()
  local pdf = string.format("%s/%s.pdf", dir, base)
  vim.system({ "pandoc", "-d", "paper", "--pdf-engine=typst", vim.fn.expand "%:p", "-o", pdf }, {}, function(r)
    vim.schedule(function()
      vim.notify(r.code == 0 and ("Exported " .. pdf) or r.stderr, r.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
    end)
  end)
end, { desc = "Markdown: export PDF (Typst)", buffer = true })

-- Make math ($...$ / $$...$$) and raw Typst blocks stand out from prose
local function color(group, attr)
  return vim.api.nvim_get_hl(0, { name = group, link = false })[attr]
end
local bg = color("CursorLine", "bg")
vim.api.nvim_set_hl(0, "MdMath", { fg = color("Number", "fg"), bg = bg })
vim.api.nvim_set_hl(0, "@typst.block.markdown", { bg = bg })

-- the markdown_inline parser doesn't expose math, so match it by pattern
vim.fn.matchadd("MdMath", [[\$\$\_.\{-1,}\$\$]], 10)
vim.fn.matchadd("MdMath", [[\\\@<!\$[^$ \t]\%([^$]*[^$ \t\\]\)\?\$]], 10)
