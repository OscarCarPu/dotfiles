-- Disable friendly-snippets for markdown to prevent unwanted callout insertion
local ls = require("luasnip")
ls.filetype_set("markdown", {})

-- Live preview: pandoc (paper defaults) -> hidden .typ next to the buffer -> tinymist preview.
-- Pandoc reads the buffer from stdin, so the preview updates as you type, saved or not.
local buf = vim.api.nvim_get_current_buf()
local dir = vim.fn.expand "%:p:h"
local base = vim.fn.expand "%:t:r"
local typ = string.format("%s/.%s.preview.typ", dir, base)
local server, timer, last_error, view_buf
local tdf_key = "mdpreview-" .. buf

local function free_port()
  local sock = vim.uv.new_tcp()
  sock:bind("127.0.0.1", 0)
  local port = sock:getsockname().port
  sock:close()
  return port
end

-- Only documents that compile ever reach tinymist (a broken one leaves its preview gray/stuck),
-- so the preview keeps the last good render and the error is shown in the buffer instead.
local ns = vim.api.nvim_create_namespace "mdpreview"
local tmp = string.format("%s/.%s.preview.new.typ", dir, base)
local pdf = string.format("%s/mdpreview-%d.pdf", vim.fn.stdpath "cache", buf)
local pdf_tmp = pdf .. ".new"
local busy, dirty = false, false

-- buffer line holding the offending Typst, found by the code shown in typst's error snippet
local function find_line(stderr)
  local snippet = stderr:match "\n%s*%d+ │ ([^\n]*)"
  if not snippet then return end
  local pad, carets = stderr:match "\n%s*│( *)(%^+)"
  local token = pad and vim.fn.strcharpart(snippet, #pad - 1, #carets) or ""
  local segs = {}
  for seg in snippet:gmatch "%$[^$]+%$" do
    table.insert(segs, token ~= "" and seg:find(token, 1, true) and 1 or #segs + 1, seg)
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for _, seg in ipairs(segs) do
    for i, l in ipairs(lines) do
      if l:find(seg, 1, true) then return i - 1 end
    end
  end
  local key = vim.trim(snippet):sub(1, 30)
  for i, l in ipairs(lines) do
    if key ~= "" and l:find(key, 1, true) then return i - 1 end
  end
end

local function show_error(stderr)
  local msg = stderr:match "error: ([^\n]*)" or "compile error"
  vim.diagnostic.set(ns, buf, { {
    lnum = find_line(stderr) or 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = "Typst: " .. msg,
  } })
  if msg ~= last_error then
    last_error = msg
    vim.notify("Typst: " .. msg, vim.log.levels.ERROR)
  end
end

-- page of the rendered PDF showing the text around the cursor: match the nearest prose line
-- (letters/digits only, so wrapping and markup don't matter), else scale by position in the file
local function alnum(str)
  return str:lower():gsub("[^%w\128-\255]", "")
end

local hay_stamp, hay_cache -- the PDF's text, per version of the file (the cursor moves far more often than it changes)

local function cursor_page()
  local st = vim.uv.fs_stat(pdf)
  local stamp = st and (st.mtime.sec .. "." .. st.mtime.nsec)
  if stamp ~= hay_stamp or not hay_cache then
    local r = vim.system({ "pdftotext", pdf, "-" }):wait()
    local pages = vim.split(r.stdout or "", "\f", { plain = true })
    if pages[#pages] == "" then table.remove(pages) end
    hay_stamp, hay_cache = stamp, vim.tbl_map(alnum, pages)
  end
  local hay = hay_cache
  local pages = hay
  if #pages == 0 then return 1 end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local row = vim.api.nvim_win_get_cursor(vim.fn.bufwinid(buf) > 0 and vim.fn.bufwinid(buf) or 0)[1]
  for d = 0, 12 do
    for _, i in ipairs(d == 0 and { row } or { row - d, row + d }) do
      local text = lines[i] and alnum((lines[i]:gsub("%$[^$]*%$", ""))) or ""
      if #text >= 12 then
        local needle = text:sub(1, 24)
        for page, h in ipairs(hay) do
          if h:find(needle, 1, true) then return page end
        end
      end
    end
  end
  return math.max(1, math.min(#pages, math.ceil(row / #lines * #pages)))
end

local function render(done)
  if busy then dirty = true; return end
  busy = true
  local function finish()
    busy = false
    if dirty and server then dirty = false; vim.schedule(render) end
    if done then vim.schedule(done) end
  end
  local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  local job = vim.fn.jobstart({ "pandoc", "-d", "paper", "--resource-path", dir, "-o", tmp }, {
    stdin = "pipe",
    on_exit = function(_, code)
      if not server then os.remove(tmp); busy = false; return end
      if code ~= 0 then return vim.schedule(function() show_error "error: pandoc failed"; finish() end) end
      vim.system({ "typst", "compile", "--root", dir, "--format", "pdf", tmp, pdf_tmp }, {}, function(r)
        vim.schedule(function()
          if not server then os.remove(tmp); busy = false; return end
          if r.code == 0 then
            os.rename(tmp, typ)
            os.rename(pdf_tmp, pdf)
            if view_buf and vim.api.nvim_buf_is_valid(view_buf) then
              require("pdfview").refresh(view_buf, cursor_page())
            else
              -- tdf reloads by itself a moment after the file changes: let it, then point it at the cursor
              vim.defer_fn(function()
                if server then require("tdfview").goto_page(tdf_key, cursor_page()) end
              end, 400)
            end
            vim.diagnostic.reset(ns, buf)
            last_error = nil
          else
            show_error(r.stderr or "")
            os.remove(tmp)
            if vim.fn.filereadable(typ) == 0 then
              vim.fn.writefile({ "#set page(width: 12cm, height: 3cm)", "Corrige el error en el editor." }, typ)
            end
          end
          finish()
        end)
      end)
    end,
  })
  vim.fn.chansend(job, text)
  vim.fn.chanclose(job, "stdin")
end

local function stop()
  if timer then timer:stop(); timer:close(); timer = nil end
  if server then vim.fn.jobstop(server); server = nil end
  if view_buf then
    local vb = view_buf
    view_buf = nil
    if vim.api.nvim_buf_is_valid(vb) then vim.api.nvim_buf_delete(vb, { force = true }) end
  end
  require("tdfview").close(tdf_key)
  os.remove(typ)
  os.remove(tmp)
  os.remove(pdf)
  os.remove(pdf_tmp)
  vim.diagnostic.reset(ns, buf)
  busy, dirty, last_error = false, false, nil
  vim.api.nvim_clear_autocmds { group = "MdPreview" .. buf }
end

-- a fresh browser window (not a tab in whatever window is open), like typst-preview.nvim's open_cmd
local function open_browser(url)
  local desktop = vim.trim(vim.fn.system { "xdg-settings", "get", "default-web-browser" })
  local bin = desktop:gsub("%.desktop$", "")
  if vim.v.shell_error == 0 and vim.fn.executable(bin) == 1 then
    vim.fn.jobstart { bin, "--new-window", url }
  else
    vim.ui.open(url)
  end
end

local function launch_browser()
  -- own free ports so previews never collide
  local data, control = free_port(), free_port()
  server = vim.fn.jobstart {
    "tinymist", "preview", "--no-open", "--root", dir,
    "--data-plane-host", "127.0.0.1:" .. data,
    "--control-plane-host", "127.0.0.1:" .. control,
    typ,
  }
  local tries, done = 0, false
  local poll = vim.uv.new_timer()
  poll:start(100, 100, vim.schedule_wrap(function()
    tries = tries + 1
    if done or tries > 50 then
      poll:stop(); poll:close()
      return
    end
    local sock = vim.uv.new_tcp()
    sock:connect("127.0.0.1", data, function(err)
      sock:close()
      if not err and not done then
        done = true
        vim.schedule(function() open_browser("http://127.0.0.1:" .. data) end)
      end
    end)
  end))
end

-- the preview is a normal (listed) buffer, so it sits in the tabufline like any other file
local function show_preview()
  local win = vim.api.nvim_get_current_win()
  vim.cmd "rightbelow vsplit"
  vim.api.nvim_win_set_buf(0, view_buf)
  vim.api.nvim_set_current_win(win)
end

local function launch_terminal()
  local tdf = require "tdfview"
  if tdf.available() then
    return tdf.open(pdf, { key = tdf_key, keep_focus = true })
  end
  view_buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(view_buf, base .. " (preview)")
  require("pdfview").attach(view_buf, pdf)
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = view_buf,
    once = true,
    callback = function()
      if view_buf then view_buf = nil; vim.schedule(stop) end
    end,
  })
  show_preview()
  require("pdfview").refresh(view_buf, cursor_page())
end

local function start(mode)
  vim.api.nvim_create_augroup("MdPreview" .. buf, { clear = true })
  server = -1 -- starting
  render(function()
    if not server then return end
    if mode == "terminal" then launch_terminal() else launch_browser() end
  end)

  timer = vim.uv.new_timer()
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = "MdPreview" .. buf,
    buffer = buf,
    callback = function()
      timer:stop()
      timer:start(150, 0, vim.schedule_wrap(render))
    end,
  })
  -- moving the cursor (without editing) makes tdf follow too
  local follow = vim.uv.new_timer()
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = "MdPreview" .. buf,
    buffer = buf,
    callback = function()
      follow:stop()
      follow:start(250, 0, vim.schedule_wrap(function()
        if server and not busy then require("tdfview").goto_page(tdf_key, cursor_page()) end
      end))
    end,
  })
  vim.api.nvim_create_autocmd({ "BufUnload", "VimLeavePre" }, { group = "MdPreview" .. buf, callback = stop })
end

vim.keymap.set("n", "<leader>mp", function()
  if server then stop() else start "browser" end
end, { desc = "Markdown: live Typst preview (browser window)", buffer = true })

vim.keymap.set("n", "<leader>mt", function()
  local tdf = require "tdfview"
  if server and tdf.available() and not tdf.alive(tdf_key) then launch_terminal()
  elseif server and view_buf and vim.fn.bufwinid(view_buf) < 0 then show_preview()
  elseif server then stop()
  else start "terminal" end
end, { desc = "Markdown: live Typst preview (tdf split, or a buffer outside kitty)", buffer = true })

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
