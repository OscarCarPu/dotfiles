require "nvchad.autocmds"

-- Auto-install treesitter parsers from ensure_installed on startup
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local ok, lazy = pcall(require, "lazy.core.config")
    if not ok then return end
    local spec = lazy.plugins["nvim-treesitter"]
    local opts = spec and type(spec.opts) == "table" and spec.opts or {}
    if opts.ensure_installed then
      require("nvim-treesitter").install(opts.ensure_installed)
    end
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "FilePost",
  once = true,
  callback = function()
    local arg = vim.fn.argv(0)
    if arg ~= "" and vim.fn.isdirectory(arg) == 1 then
      vim.schedule(function()
        vim.cmd("cd " .. vim.fn.fnameescape(arg))
        require("nvim-tree.api").tree.open { focus = true }
      end)
    end
  end,
})

-- PDFs are not text: show them in a kitty split (pdf-term-view) instead of a binary buffer
vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = "*.pdf",
  callback = function(args)
    local pdf = vim.fn.fnamemodify(args.file, ":p")
    local to = vim.env.KITTY_LISTEN_ON
    if to and to ~= "" then
      vim.system({ "kitten", "@", "--to", to, "close-window", "--match", "cmdline:pdf-term-view" }):wait()
      vim.system { "kitten", "@", "--to", to, "launch", "--location=vsplit", "--keep-focus", "pdf-term-view", pdf }
    else
      vim.fn.jobstart { "kitty", "--class", "pdf-view", "pdf-term-view", pdf }
    end
    vim.bo[args.buf].buftype = "nofile"
    vim.bo[args.buf].modifiable = false
    vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, { "PDF opened in viewer: " .. pdf })
  end,
})
