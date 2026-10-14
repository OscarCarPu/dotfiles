-- PDF viewer in an ordinary buffer: one page at a time, rasterised with pdftoppm to fit the window
-- (or a zoomed crop of it) and drawn by snacks.image (kitty graphics protocol). Being a buffer, it
-- shows up in the tabufline, opens in whatever window nvim-tree targets and reloads on change.
local M = {}

---@class pdfview.View
---@field pdf string
---@field page number
---@field n number
---@field mtime? string
---@field sizes table<number, number[]> page sizes in pt
---@field zoom number 1 = whole page fits the window
---@field cx number viewport centre as a fraction of the page width
---@field cy number viewport centre as a fraction of the page height
---@field place? table current snacks placement
---@field stale table[] placements waiting to be closed once the current one is drawn
---@field cache table<string, string> render key -> png
---@field seq number
---@field gen number
---@field last number page shown by the previous draw (direction of travel)
---@field ahead number[] pages queued for the prefetch worker
---@field busy? boolean
---@field timer? uv_timer_t
local views = {} ---@type table<number, pdfview.View>
-- per instance: snacks keeps an `identify` result next to each png path in its own persistent
-- cache, so a path reused by another session would be drawn with the wrong size
local dir = string.format("%s/pdfview/%d", vim.fn.stdpath "cache", vim.fn.getpid())
vim.api.nvim_create_autocmd("VimLeavePre", { callback = function() vim.fn.delete(dir, "rf") end })
local ZOOM_STEP, ZOOM_MAX = 1.25, 8

local function stamp(pdf)
  local st = vim.uv.fs_stat(pdf)
  return st and (st.mtime.sec .. "." .. st.mtime.nsec) or nil
end

local function read_info(v)
  local r = vim.system({ "pdfinfo", "-f", "1", "-l", "100000", v.pdf }):wait()
  local out = r.stdout or ""
  v.n = tonumber(out:match "Pages:%s+(%d+)") or 1
  v.sizes = {}
  for page, w, h in out:gmatch "Page%s+(%d+)%s+size:%s+([%d.]+) x ([%d.]+)" do
    v.sizes[tonumber(page)] = { tonumber(w), tonumber(h) }
  end
end

local function set_status(buf)
  local v = views[buf]
  local zoom = v.zoom > 1 and string.format("  %d%%", v.zoom * 100) or ""
  vim.b[buf].pdfview_status = string.format("%d/%d%s", v.page, v.n, zoom)
  vim.cmd.redrawstatus()
end

local function clear_cache(v)
  for _, f in pairs(v.cache) do os.remove(f) end
  v.cache = {}
end

local function close_all(list)
  for _, p in ipairs(list) do p:close() end
end

--- Window pixels of the window showing `buf`, or nil when it is hidden.
local function viewport(buf)
  local win = vim.fn.bufwinid(buf)
  if win < 0 then return end
  local t = Snacks.image.terminal.size()
  return win, vim.api.nvim_win_get_width(win) * t.cell_width, vim.api.nvim_win_get_height(win) * t.cell_height
end

--- pdftoppm arguments + cache key for `page` at the current zoom/pan.
local function plan(v, page, wpx, hpx)
  local size = v.sizes[page] or v.sizes[1] or { 595, 842 }
  local fit = math.min(wpx * 72 / size[1], hpx * 72 / size[2])
  if v.zoom <= 1 then
    local dpi = fit * 1.25
    return string.format("%d:%d:%d", page, wpx, hpx),
      { "-r", string.format("%.1f", dpi), "-f", page, "-l", page, "-singlefile" }
  end
  local dpi = math.min(fit * v.zoom, 500)
  local pw, ph = size[1] * dpi / 72, size[2] * dpi / 72
  local w, h = math.min(wpx, pw), math.min(hpx, ph)
  local x = math.max(0, math.min(v.cx * pw - w / 2, pw - w))
  local y = math.max(0, math.min(v.cy * ph - h / 2, ph - h))
  return string.format("%d:%d:%d:%.2f:%d:%d", page, wpx, hpx, v.zoom, x, y), {
    "-r", string.format("%.1f", dpi), "-x", math.floor(x), "-y", math.floor(y),
    "-W", math.floor(w), "-H", math.floor(h), "-f", page, "-l", page, "-singlefile",
  }
end

local function rasterise(v, buf, key, args, cb)
  if v.cache[key] then return cb(v.cache[key]) end
  vim.fn.mkdir(dir, "p")
  v.seq = v.seq + 1
  local prefix = string.format("%s/%d-%d", dir, buf, v.seq)
  local cmd = { "pdftoppm", "-png" }
  vim.list_extend(cmd, vim.tbl_map(tostring, args))
  vim.list_extend(cmd, { v.pdf, prefix })
  vim.system(cmd, {}, vim.schedule_wrap(function(r)
    if r.code ~= 0 or views[buf] ~= v then
      os.remove(prefix .. ".png")
      return
    end
    local png = prefix .. ".png"
    -- hand snacks the `identify` result so it skips spawning magick for every page
    local size = Snacks.image.util.dim(png)
    local info = Snacks.image.convert.convert({ src = png })
    local step = info.steps[#info.steps]
    vim.fn.writefile({ string.format("PNG %dx%d 72x72", size.width, size.height) }, step.file)
    v.cache[key] = png
    cb(png)
  end))
end

--- Centre the image in the window; the buffer needs enough lines for the top padding.
local function center(self)
  local win = self:wins()[1]
  if not win then return end
  local w, h = vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)
  local img = self.img
  -- snacks never scales an image up (it trusts the dpi): claim a tiny dpi so it fits the window
  img.info = img.info or { size = Snacks.image.util.dim(img.file) }
  img.info.dpi = { width = 1, height = 1 }
  local size = Snacks.image.util.fit(img.file, { width = w, height = h }, { info = img.info })
  local top = math.max(0, math.floor((h - size.height) / 2))
  self.opts.pos = { top + 1, math.max(0, math.floor((w - size.width) / 2)) }
  if vim.api.nvim_buf_line_count(self.buf) < top + 1 then
    vim.bo[self.buf].modifiable = true
    vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, vim.fn.split(string.rep("\n", top), "\n", true))
    vim.bo[self.buf].modifiable = false
  end
end

--- Swap in a new placement and only drop the old one once the new one is on screen (no flash).
local function show(buf, png)
  local v = views[buf]
  if not v then return end
  if v.place then table.insert(v.stale, v.place) end
  local place
  place = Snacks.image.placement.new(buf, png, {
    conceal = true,
    auto_resize = true,
    on_update_pre = center,
    on_update = function()
      if v.place == place and #v.stale > 0 then
        local old = v.stale
        v.stale = {}
        close_all(old)
      end
      vim.cmd.redraw() -- the extmarks were set from an async callback: nothing else repaints them
    end,
  })
  v.place = place
end

-- One background worker renders the pages ahead (in the direction of travel first), so fast
-- paging never queues several pdftoppm processes against the foreground render.
local function pump(buf, v)
  if v.busy then return end
  local page = table.remove(v.ahead, 1)
  if not page then return end
  local win, wpx, hpx = viewport(buf)
  if not win or v.zoom > 1 then v.ahead = {}; return end
  local key, args = plan(v, page, wpx, hpx)
  if v.cache[key] then return pump(buf, v) end
  v.busy = true
  rasterise(v, buf, key, args, function(png)
    v.busy = false
    if views[buf] == v then
      Snacks.image.image.new(png) -- convert + upload ahead of time
      pump(buf, v)
    end
  end)
end

local function prefetch(buf, v, page)
  local d = page >= v.last and 1 or -1
  v.last = page
  v.ahead = {}
  for _, p in ipairs { page + d, page + 2 * d, page + 3 * d, page - d } do
    if p >= 1 and p <= v.n then table.insert(v.ahead, p) end
  end
  pump(buf, v)
end

local function draw(buf)
  local v = views[buf]
  local win, wpx, hpx = viewport(buf)
  if not win then return end
  local page = v.page
  v.gen = v.gen + 1
  local gen = v.gen -- renders finish out of order (a fit render is slower than a crop): only the newest request may show
  local key, args = plan(v, page, wpx, hpx)
  rasterise(v, buf, key, args, function(png)
    if views[buf] ~= v or v.gen ~= gen or not vim.api.nvim_buf_is_valid(buf) then return end
    show(buf, png)
    set_status(buf)
    prefetch(buf, v, page)
  end)
end

--- Redraw, optionally jumping to `page`; re-reads the PDF when it changed on disk.
function M.refresh(buf, page)
  local v = views[buf]
  if not v then return end
  local now = stamp(v.pdf)
  if now ~= v.mtime then
    v.mtime = now
    clear_cache(v)
    read_info(v)
  end
  v.page = math.max(1, math.min(page or v.page, v.n))
  draw(buf)
end

function M.goto_page(buf, page)
  local v = views[buf]
  if not v then return end
  page = math.max(1, math.min(page, v.n))
  if page ~= v.page then
    v.page = page
    v.cy = 0.5
    draw(buf)
  end
end

function M.step(buf, delta)
  local v = views[buf]
  if v then M.goto_page(buf, v.page + delta) end
end

function M.zoom(buf, factor)
  local v = views[buf]
  if not v then return end
  local zoom = factor and math.max(1, math.min(v.zoom * factor, ZOOM_MAX)) or 1
  if zoom == v.zoom then return end
  v.zoom = zoom
  if zoom == 1 then v.cx, v.cy = 0.5, 0.5 end
  clear_cache(v)
  draw(buf)
end

--- Move the zoomed viewport by a fraction of the window.
function M.pan(buf, dx, dy)
  local v = views[buf]
  if not v or v.zoom <= 1 then return end
  local size = v.sizes[v.page] or { 595, 842 }
  v.cx = math.max(0, math.min(1, v.cx + dx * 0.2 / v.zoom))
  v.cy = math.max(0, math.min(1, v.cy + dy * 0.2 / v.zoom * (size[1] / size[2])))
  draw(buf)
end

local function teardown(buf)
  local v = views[buf]
  views[buf] = nil
  if not v then return end
  if v.place then v.place:close() end
  close_all(v.stale)
  clear_cache(v)
  if v.timer and not v.timer:is_closing() then v.timer:stop(); v.timer:close() end
end

--- Turn `buf` into a viewer of `pdf`.
function M.attach(buf, pdf)
  teardown(buf) -- :bdelete only unloads, so the next :e re-attaches the same buffer
  pdf = vim.fn.fnamemodify(pdf, ":p")
  local v = { pdf = pdf, page = 1, n = 1, sizes = {}, zoom = 1, cx = 0.5, cy = 0.5, stale = {}, cache = {}, seq = 0, gen = 0, last = 1, ahead = {} }
  views[buf] = v
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "pdfview"
  vim.bo[buf].modifiable = false

  local function map(keys, fn, desc)
    for _, k in ipairs(keys) do
      vim.keymap.set("n", k, fn, { buffer = buf, desc = "PDF: " .. desc })
    end
  end
  map({ "k", "n", "<PageDown>", "<C-d>", "<C-f>", "<ScrollWheelDown>" }, function() M.step(buf, 1) end, "next page")
  map({ "j", "p", "<PageUp>", "<C-u>", "<C-b>", "<ScrollWheelUp>" }, function() M.step(buf, -1) end, "previous page")
  map({ "gg" }, function() M.goto_page(buf, 1) end, "first page")
  map({ "G" }, function() M.goto_page(buf, v.n) end, "last page")
  map({ "+", "=", "<C-ScrollWheelUp>" }, function() M.zoom(buf, ZOOM_STEP) end, "zoom in")
  map({ "-", "<C-ScrollWheelDown>" }, function() M.zoom(buf, 1 / ZOOM_STEP) end, "zoom out")
  map({ "0" }, function() M.zoom(buf) end, "fit page")
  map({ "<Left>", "h" }, function() M.pan(buf, -1, 0) end, "pan left")
  map({ "<Right>", "l" }, function() M.pan(buf, 1, 0) end, "pan right")
  map({ "<Up>" }, function() M.pan(buf, 0, -1) end, "pan up")
  map({ "<Down>" }, function() M.pan(buf, 0, 1) end, "pan down")
  map({ "q" }, function() vim.cmd.bdelete { bang = true } end, "close")

  local timer = vim.uv.new_timer()
  v.timer = timer
  timer:start(300, 300, vim.schedule_wrap(function()
    if views[buf] ~= v or not vim.api.nvim_buf_is_valid(buf) then return end
    local now = stamp(v.pdf)
    if now and now ~= v.mtime then M.refresh(buf) end
  end))

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
  -- the rendered pixels depend on the window size
  local resize = vim.uv.new_timer()
  vim.api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
    group = group,
    callback = function()
      if views[buf] ~= v then return end
      resize:stop()
      resize:start(120, 0, vim.schedule_wrap(function()
        if views[buf] == v then clear_cache(v); draw(buf) end
      end))
    end,
  })
  vim.wo.winbar = "%=%{get(b:, 'pdfview_status', '')} "

  Snacks.image.terminal.detect(function() vim.schedule(function() M.refresh(buf) end) end)
end

return M
