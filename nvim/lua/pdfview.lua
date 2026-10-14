-- PDF viewer in an ordinary buffer: one page at a time, rasterised with pdftoppm and drawn by
-- snacks.image (kitty graphics protocol). Being a buffer, it shows up in the tabufline, opens in
-- whatever window nvim-tree targets and reloads when the file changes.
local M = {}

local views = {} ---@type table<number, {pdf:string, page:number, n:number, mtime:string, place:table?, seq:number}>
local dir = vim.fn.stdpath "cache" .. "/pdfview"

local function stamp(pdf)
  local st = vim.uv.fs_stat(pdf)
  return st and (st.mtime.sec .. "." .. st.mtime.nsec) or nil
end

local function page_count(pdf)
  local r = vim.system({ "pdfinfo", pdf }):wait()
  return tonumber((r.stdout or ""):match "Pages:%s+(%d+)") or 1
end

local function set_status(buf)
  local v = views[buf]
  vim.b[buf].pdfview_status = string.format("%d/%d", v.page, v.n)
end

local function draw(buf)
  local v = views[buf]
  v.seq = v.seq + 1
  local seq = v.seq
  vim.fn.mkdir(dir, "p")
  -- unique name per draw: snacks caches images by file
  local prefix = string.format("%s/%d-%d", dir, buf, seq)
  vim.system(
    { "pdftoppm", "-png", "-r", "150", "-f", v.page, "-l", v.page, "-singlefile", v.pdf, prefix },
    {},
    vim.schedule_wrap(function(r)
      if r.code ~= 0 or not views[buf] or seq ~= v.seq or not vim.api.nvim_buf_is_valid(buf) then
        os.remove(prefix .. ".png")
        return
      end
      local old = v.place
      v.place = Snacks.image.placement.new(buf, prefix .. ".png", { conceal = true, auto_resize = true })
      if old then old:close() end
      set_status(buf)
      vim.cmd.redrawstatus()
    end)
  )
end

--- Show `page` (default: keep the current one); re-reads the PDF's size, so safe after it changed.
function M.refresh(buf, page)
  local v = views[buf]
  if not v then return end
  v.mtime = stamp(v.pdf)
  v.n = page_count(v.pdf)
  v.page = math.max(1, math.min(page or v.page, v.n))
  draw(buf)
end

function M.goto_page(buf, page)
  local v = views[buf]
  if v then M.refresh(buf, math.max(1, math.min(page, v.n))) end
end

function M.step(buf, delta)
  local v = views[buf]
  if v then M.goto_page(buf, v.page + delta) end
end

local function teardown(buf)
  local v = views[buf]
  views[buf] = nil
  if v and v.place then v.place:close() end
  if v and v.timer and not v.timer:is_closing() then v.timer:stop(); v.timer:close() end
end

--- Turn `buf` into a viewer of `pdf`.
function M.attach(buf, pdf)
  teardown(buf) -- :bdelete only unloads, so the next :e re-attaches the same buffer
  pdf = vim.fn.fnamemodify(pdf, ":p")
  views[buf] = { pdf = pdf, page = 1, n = 1, seq = 0 }
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "pdfview"
  vim.bo[buf].modifiable = false

  local function map(keys, fn, desc)
    vim.keymap.set("n", keys, fn, { buffer = buf, desc = "PDF: " .. desc })
  end
  for _, k in ipairs { "j", "n", "<Down>", "<PageDown>", "<Right>", "<Space>", "<C-d>", "<C-f>", "<ScrollWheelDown>" } do
    map(k, function() M.step(buf, 1) end, "next page")
  end
  for _, k in ipairs { "k", "p", "<Up>", "<PageUp>", "<Left>", "<C-u>", "<C-b>", "<ScrollWheelUp>" } do
    map(k, function() M.step(buf, -1) end, "previous page")
  end
  map("gg", function() M.goto_page(buf, 1) end, "first page")
  map("G", function() M.goto_page(buf, views[buf].n) end, "last page")
  map("q", function() vim.cmd.bdelete { bang = true } end, "close")

  local timer = vim.uv.new_timer()
  views[buf].timer = timer
  timer:start(300, 300, vim.schedule_wrap(function()
    local v = views[buf]
    if not v or v.timer ~= timer or not vim.api.nvim_buf_is_valid(buf) then return end
    local now = stamp(v.pdf)
    if now and now ~= v.mtime then M.refresh(buf) end
  end))

  -- page number in the window bar, only while this buffer is shown in the window
  local group = vim.api.nvim_create_augroup("pdfview" .. buf, { clear = true })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    buffer = buf,
    callback = function()
      vim.wo.winbar = "%=%{get(b:, 'pdfview_status', '')} "
      -- snacks hides a placement whose buffer left every window and never un-hides it: redraw fresh
      vim.schedule(function() M.refresh(buf) end)
    end,
  })
  vim.api.nvim_create_autocmd("BufWinLeave", {
    group = group,
    buffer = buf,
    callback = function() vim.wo.winbar = "" end,
  })
  vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
    group = group,
    buffer = buf,
    callback = function() teardown(buf) end,
  })
  vim.wo.winbar = "%=%{get(b:, 'pdfview_status', '')} "

  Snacks.image.terminal.detect(function() vim.schedule(function() M.refresh(buf) end) end)
end

return M
