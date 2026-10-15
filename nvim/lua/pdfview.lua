-- PDF viewer in an ordinary buffer: the whole document as one vertical strip, scrolled smoothly.
-- Each frame is the visible slice of the strip (pdftoppm renders only the cropped part of every
-- page in view, magick stacks them) drawn by snacks.image (kitty graphics protocol). Being a
-- buffer, it shows up in the tabufline, opens in whatever window nvim-tree targets and reloads on change.
-- Document coordinates are in pt (1 pt = `scale` pixels): zoom 1 fits the widest page to the window.
local M = {}

---@class pdfview.View
---@field pdf string
---@field page number page under the middle of the window
---@field n number
---@field mtime? string
---@field sizes table<number, number[]> page sizes in pt
---@field offs number[] top of each page in the strip (pt)
---@field maxw number widest page (pt)
---@field total number strip height (pt)
---@field zoom number 1 = widest page fits the window width
---@field sx number left edge of the window (pt), only meaningful when the strip is wider than the window
---@field sy number top edge of the window (pt)
---@field place? table current snacks placement
---@field stale table[] placements waiting to be closed once the current one is drawn
---@field frames string[] png files of the latest frames
---@field bands table<string, string> cached page bands: key -> png
---@field band_order string[] LRU order of `bands`
---@field inflight table<string, function[]>
---@field prefetching? boolean
---@field dir number direction of the last scroll (1 down, -1 up)
---@field prev_sy number
---@field seq number
---@field drawing? boolean
---@field redo? boolean
---@field epoch number bumped whenever the file changes on disk (drops stale async results)
---@field words? table<number, table[]> per page: {x0, y0, x1, y1, text} in pt, origin top-left
---@field links? table<number, table[]> per page: {x0, y0, x1, y1, page?, y?, uri?}
---@field waiting table<string, function[]> callbacks queued behind a running loader
---@field query? string
---@field hits table[] {page, rects}
---@field cur number index into hits
---@field by_page table<number, table[]> highlight rects per page {rects, cur}
---@field back table[] positions to return to after following a link
---@field timer? uv_timer_t
local views = {} ---@type table<number, pdfview.View>
-- per instance: snacks keeps an `identify` result next to each png path in its own persistent
-- cache, so a path reused by another session would be drawn with the wrong size
local dir = string.format("%s/pdfview/%d", vim.fn.stdpath "cache", vim.fn.getpid())
vim.api.nvim_create_autocmd("VimLeavePre", { callback = function() vim.fn.delete(dir, "rf") end })
local ZOOM_STEP, ZOOM_MIN, ZOOM_MAX = 1.25, 0.25, 8
local GAP = 10 -- pt between pages
local BG = "#303030"

local function stamp(pdf)
  local st = vim.uv.fs_stat(pdf)
  return st and (st.mtime.sec .. "." .. st.mtime.nsec) or nil
end

local function size_of(v, page)
  return v.sizes[page] or v.sizes[1] or { 595, 842 }
end

local function read_info(v)
  local r = vim.system({ "pdfinfo", "-f", "1", "-l", "100000", v.pdf }):wait()
  local out = r.stdout or ""
  v.n = tonumber(out:match "Pages:%s+(%d+)") or 1
  v.sizes = {}
  for page, w, h in out:gmatch "Page%s+(%d+)%s+size:%s+([%d.]+) x ([%d.]+)" do
    v.sizes[tonumber(page)] = { tonumber(w), tonumber(h) }
  end
  v.offs, v.maxw = {}, 1
  local y = 0
  for i = 1, v.n do
    local s = size_of(v, i)
    v.offs[i] = y
    y = y + s[2] + GAP
    v.maxw = math.max(v.maxw, s[1])
  end
  v.total = y - GAP
end

local function page_at(v, y)
  for i = v.n, 1, -1 do
    if v.offs[i] <= y then return i end
  end
  return 1
end

local function set_status(buf)
  local v = views[buf]
  local zoom = v.zoom ~= 1 and string.format("  %d%%", v.zoom * 100) or ""
  local find = ""
  if v.query then
    find = #v.hits > 0 and string.format("/%s %d/%d  ", v.query, v.cur, #v.hits) or string.format("/%s no match  ", v.query)
  end
  vim.b[buf].pdfview_status = string.format("%s%d/%d%s", find, v.page, v.n, zoom)
  vim.cmd.redrawstatus()
end

local function clear_frames(v)
  for _, f in ipairs(v.frames) do os.remove(f) end
  v.frames = {}
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

--- Clamp the scroll position and return the scale (px per pt), the window size (pt) and its left edge.
local function geometry(v, wpx, hpx)
  local scale = wpx / v.maxw * v.zoom
  local vw, vh = wpx / scale, hpx / scale
  v.sy = math.max(0, math.min(v.sy, v.total - vh))
  local sx
  if vw >= v.maxw then
    sx = -(vw - v.maxw) / 2
  else
    v.sx = math.max(0, math.min(v.sx, v.maxw - vw))
    sx = v.sx
  end
  return scale, vw, vh, sx
end

--- Window size in pt (nil when hidden).
local function view_pt(buf)
  local v = views[buf]
  local win, wpx, hpx = viewport(buf)
  if not win then return end
  local _, vw, vh = geometry(v, wpx, hpx)
  return vw, vh
end

-- Pages are rasterised once into full-width bands one window tall (cached, evicted LRU) and a
-- frame only crops and stacks them: scrolling never waits for pdftoppm unless it outruns the prefetch.
local BAND_CAP = 60

local function touch(v, key)
  for i, k in ipairs(v.band_order) do
    if k == key then table.remove(v.band_order, i); break end
  end
  table.insert(v.band_order, key)
end

local function clear_bands(v)
  for _, f in pairs(v.bands) do os.remove(f) end
  v.bands, v.band_order = {}, {}
end

---@return table band descriptor for rows k*B.. of `page` at `scale`
local function band(v, buf, scale, B, page, k)
  local s = size_of(v, page)
  local ph = math.ceil(s[2] * scale)
  local dpi = string.format("%.2f", scale * 72)
  return {
    page = page, k = k, dpi = dpi, y = k * B, w = math.ceil(s[1] * scale), h = math.min(B, ph - k * B),
    key = string.format("%d:%d:%s:%d", page, k, dpi, B),
    prefix = string.format("%s/%d-b%d-%d-%s-%d", dir, buf, page, k, dpi, B),
  }
end

--- Make sure the band is on disk; cb(ok).
local function get_band(v, buf, b, cb)
  if v.bands[b.key] then touch(v, b.key); return cb(true) end
  if v.inflight[b.key] then return table.insert(v.inflight[b.key], cb) end
  v.inflight[b.key] = { cb }
  vim.fn.mkdir(dir, "p")
  local epoch = v.epoch
  local cmd = { "pdftoppm", "-png", "-singlefile", "-r", b.dpi }
  vim.list_extend(cmd, vim.tbl_map(tostring, { "-x", 0, "-y", b.y, "-W", b.w, "-H", b.h, "-f", b.page, "-l", b.page }))
  vim.list_extend(cmd, { v.pdf, b.prefix })
  vim.system(cmd, {}, vim.schedule_wrap(function(r)
    local waiting = v.inflight[b.key]
    v.inflight[b.key] = nil
    local ok = r.code == 0 and views[buf] == v and v.epoch == epoch
    if ok then
      v.bands[b.key] = b.prefix .. ".png"
      touch(v, b.key)
      while #v.band_order > BAND_CAP do
        local old = table.remove(v.band_order, 1)
        os.remove(v.bands[old])
        v.bands[old] = nil
      end
    else
      os.remove(b.prefix .. ".png")
    end
    for _, f in ipairs(waiting) do f(ok) end
  end))
end

--- Bands (as descriptors) covering the strip between `y0` and `y1` (pt), top to bottom.
local function bands_between(v, buf, scale, B, y0, y1)
  local list = {}
  for p = page_at(v, y0), v.n do
    if v.offs[p] >= y1 then break end
    local ph = math.ceil(size_of(v, p)[2] * scale)
    local r0 = math.max(0, math.floor((y0 - v.offs[p]) * scale))
    local r1 = math.min(ph, math.ceil((y1 - v.offs[p]) * scale))
    for k = math.floor(r0 / B), math.floor((r1 - 1) / B) do
      if k >= 0 and k * B < ph then table.insert(list, band(v, buf, scale, B, p, k)) end
    end
  end
  return list
end

-- Read ahead in the direction of travel (and a little behind), one band at a time.
local function prefetch(buf)
  local v = views[buf]
  if not v or v.prefetching then return end
  local win, wpx, hpx = viewport(buf)
  if not win then return end
  local scale, _, vh = geometry(v, wpx, hpx)
  local d = v.dir
  local list = bands_between(v, buf, scale, hpx, v.sy - (d < 0 and 2 or 0.7) * vh, v.sy + vh + (d < 0 and 0.7 or 2) * vh)
  if d < 0 then list = vim.fn.reverse(list) end
  for _, b in ipairs(list) do
    if not v.bands[b.key] then
      v.prefetching = true
      return get_band(v, buf, b, function()
        v.prefetching = false
        if views[buf] == v then prefetch(buf) end
      end)
    end
  end
end

--- Build the frame for the current scroll position: crop the cached bands of the pages in view,
--- stack them on a background with magick and paint the search hits. cb(png, shown) or cb() on failure.
local function render(buf, cb)
  local v = views[buf]
  local win, wpx, hpx = viewport(buf)
  if not win then return cb() end
  local scale, vw, vh, sx = geometry(v, wpx, hpx)
  local sy = v.sy
  v.dir = sy > v.prev_sy and 1 or sy < v.prev_sy and -1 or v.dir
  v.prev_sy = sy
  v.page = page_at(v, sy + vh / 2)
  v.seq = v.seq + 1
  local out = string.format("%s/%d-f%d.png", dir, buf, v.seq)

  local pieces = {}
  for p = page_at(v, sy), v.n do
    if v.offs[p] >= sy + vh then break end
    local s = size_of(v, p)
    local x0 = (v.maxw - s[1]) / 2
    local xa, xb = math.max(sx, x0) - x0, math.min(sx + vw, x0 + s[1]) - x0
    local ya, yb = math.max(sy, v.offs[p]) - v.offs[p], math.min(sy + vh, v.offs[p] + s[2]) - v.offs[p]
    if xb > xa and yb > ya then
      local px = math.floor(xa * scale)
      local cw = math.max(1, math.ceil(xb * scale) - px)
      local r0, r1 = math.floor(ya * scale), math.ceil(yb * scale)
      local left = math.floor((x0 - sx) * scale + 0.5)
      local top = math.floor((v.offs[p] - sy) * scale + 0.5)
      for k = math.floor(r0 / hpx), math.floor((r1 - 1) / hpx) do
        local b = band(v, buf, scale, hpx, p, k)
        local a, e = math.max(r0, b.y), math.min(r1, b.y + b.h)
        if e > a then
          table.insert(pieces, { band = b, page = p, x0 = x0, x = left + px, y = top + a, crop = string.format("%dx%d+%d+%d", cw, e - a, px, a - b.y) })
        end
      end
    end
  end
  if #pieces == 0 then return cb() end

  local function compose()
    local cmd = { "magick", "-size", string.format("%dx%d", wpx, hpx), "xc:" .. BG }
    for _, pc in ipairs(pieces) do
      vim.list_extend(cmd, {
        "(", v.bands[pc.band.key], "-crop", pc.crop, "+repage", ")",
        "-geometry", string.format("%+d%+d", pc.x, pc.y), "-composite",
      })
    end
    for _, pass in ipairs { false, true } do -- the current hit goes on top, stronger
      local rects = {}
      local done = {}
      for _, pc in ipairs(pieces) do
        if not done[pc.page] then -- once per page, whichever band is on screen
          done[pc.page] = true
          for _, hit in ipairs(v.by_page[pc.page] or {}) do
            if hit.cur == pass then
              for _, r in ipairs(hit.rects) do
                table.insert(rects, string.format(
                  "rectangle %d,%d %d,%d",
                  (pc.x0 + r[1] - sx) * scale - 1, (v.offs[pc.page] + r[2] - sy) * scale - 1,
                  (pc.x0 + r[3] - sx) * scale + 1, (v.offs[pc.page] + r[4] - sy) * scale + 1
                ))
              end
            end
          end
        end
      end
      if #rects > 0 then
        vim.list_extend(cmd, { "-fill", pass and "rgba(255,140,0,0.45)" or "rgba(255,225,0,0.4)" })
        for _, rect in ipairs(rects) do vim.list_extend(cmd, { "-draw", rect }) end
      end
    end
    vim.list_extend(cmd, { "-define", "png:compression-level=1", out })
    vim.system(cmd, {}, vim.schedule_wrap(function(r)
      if r.code ~= 0 or views[buf] ~= v then
        os.remove(out)
        return cb()
      end
      -- hand snacks the `identify` result so it skips spawning magick for every frame
      local info = Snacks.image.convert.convert({ src = out })
      local step = info.steps[#info.steps]
      vim.fn.writefile({ string.format("PNG %dx%d 72x72", wpx, hpx) }, step.file)
      cb(out, { sy = sy, sx = sx, scale = scale, w = wpx, h = hpx })
    end))
  end

  local left, failed = 0, false
  local seen = {}
  for _, pc in ipairs(pieces) do
    if not seen[pc.band.key] then
      seen[pc.band.key] = true
      left = left + 1
    end
  end
  for key in pairs(seen) do
    local b
    for _, pc in ipairs(pieces) do
      if pc.band.key == key then b = pc.band; break end
    end
    get_band(v, buf, b, function(ok)
      failed = failed or not ok
      left = left - 1
      if left > 0 then return end
      if failed or views[buf] ~= v then return cb() end
      compose()
    end)
  end
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
  local left = math.max(0, math.floor((w - size.width) / 2))
  self.opts.pos = { top + 1, left }
  self.geom = { left = left, top = top, w = size.width, h = size.height } -- cells, for mouse hit-testing
  if vim.api.nvim_buf_line_count(self.buf) < top + 1 then
    vim.bo[self.buf].modifiable = true
    vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, vim.fn.split(string.rep("\n", top), "\n", true))
    vim.bo[self.buf].modifiable = false
  end
end

--- Swap in a new placement and only drop the old one once the new one is on screen (no flash).
local function show(buf, png, shown)
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
  place.shown = shown
  v.place = place
end

-- One frame at a time: scrolling faster than frames render just re-aims the next one.
local function draw(buf)
  local v = views[buf]
  if not v then return end
  if v.drawing then v.redo = true; return end
  v.drawing = true
  render(buf, function(png, shown)
    v.drawing = false
    if views[buf] ~= v or not vim.api.nvim_buf_is_valid(buf) then
      if png then os.remove(png) end
      return
    end
    if png then
      table.insert(v.frames, png)
      while #v.frames > 4 do os.remove(table.remove(v.frames, 1)) end
      show(buf, png, shown)
      set_status(buf)
      prefetch(buf)
    end
    if v.redo then
      v.redo = false
      draw(buf)
    end
  end)
end

--- Redraw, optionally scrolling to the top of `page` if it is not the one on screen;
--- re-reads the PDF when it changed on disk.
function M.refresh(buf, page)
  local v = views[buf]
  if not v then return end
  local now = stamp(v.pdf)
  if now ~= v.mtime then
    v.mtime = now
    v.epoch = v.epoch + 1
    v.words, v.links, v.hits, v.by_page = nil, nil, {}, {}
    clear_frames(v)
    clear_bands(v)
    read_info(v)
    if v.query then M.search(buf, v.query, true) end
  end
  if page and page ~= v.page then v.sy = v.offs[math.max(1, math.min(page, v.n))] end
  draw(buf)
end

function M.goto_page(buf, page)
  local v = views[buf]
  if not v then return end
  v.sy = v.offs[math.max(1, math.min(page, v.n))]
  draw(buf)
end

--- Scroll by a fraction of the window height (positive = down).
function M.scroll(buf, frac)
  local v = views[buf]
  local _, vh = view_pt(buf)
  if not vh then return end
  v.sy = v.sy + frac * vh
  draw(buf)
end

function M.to_end(buf)
  local v = views[buf]
  if v then v.sy = v.total; draw(buf) end
end

--- Zoom around the middle of the window; no factor = fit the width.
function M.zoom(buf, factor)
  local v = views[buf]
  local win, wpx, hpx = viewport(buf)
  if not win then return end
  local _, vw, vh, sx = geometry(v, wpx, hpx)
  local mx, my = sx + vw / 2, v.sy + vh / 2
  local zoom = factor and math.max(ZOOM_MIN, math.min(v.zoom * factor, ZOOM_MAX)) or 1
  if zoom == v.zoom then return end
  v.zoom = zoom
  v.sx, v.sy = mx - v.maxw / zoom / 2, my - hpx * v.maxw / (wpx * zoom) / 2
  draw(buf)
end

--- Move sideways by a fraction of the window width (only matters when zoomed in).
function M.pan(buf, dx)
  local v = views[buf]
  local win, wpx, hpx = viewport(buf)
  if not win then return end
  local _, vw, _, sx = geometry(v, wpx, hpx)
  if vw >= v.maxw then return end
  v.sx = sx + dx * 0.2 * vw
  draw(buf)
end

local ENTITIES = { amp = "&", lt = "<", gt = ">", quot = '"', apos = "'" }
local function unescape(str)
  return (str:gsub("&(#?%w+);", function(e)
    if ENTITIES[e] then return ENTITIES[e] end
    local dec, hex = e:match "^#(%d+)$", e:match "^#x(%x+)$"
    if dec then return vim.fn.nr2char(tonumber(dec)) end
    if hex then return vim.fn.nr2char(tonumber(hex, 16)) end
  end))
end

--- Run `cmd` once per file version and share the parsed result between callers.
local function load(v, name, cmd, parse, cb)
  if v[name] then return cb() end
  v.waiting[name] = v.waiting[name] or {}
  table.insert(v.waiting[name], cb)
  if #v.waiting[name] > 1 then return end
  local epoch = v.epoch
  vim.system(cmd, { text = true }, vim.schedule_wrap(function(r)
    local queue = v.waiting[name]
    v.waiting[name] = nil
    if v.epoch ~= epoch then -- the file changed meanwhile: go again for the callers still waiting
      for _, f in ipairs(queue) do load(v, name, cmd, parse, f) end
      return
    end
    v[name] = r.code == 0 and parse(r.stdout or "") or {}
    for _, f in ipairs(queue) do f() end
  end))
end

local function load_words(v, cb)
  load(v, "words", { "pdftotext", "-bbox", v.pdf, "-" }, function(out)
    local words, page = {}, 0
    for line in out:gmatch "[^\n]+" do
      if line:find("<page ", 1, true) then
        page = page + 1
        words[page] = {}
      else
        local x0, y0, x1, y1, text = line:match '<word xMin="([%d.]+)" yMin="([%d.]+)" xMax="([%d.]+)" yMax="([%d.]+)">(.*)</word>'
        if text then
          table.insert(words[page], { tonumber(x0), tonumber(y0), tonumber(x1), tonumber(y1), unescape(text) })
        end
      end
    end
    return words
  end, cb)
end

local function load_links(v, cb)
  if vim.fn.executable "qpdf" == 0 then
    v.links = {}
    return cb()
  end
  local cmd = { "qpdf", "--json=2", "--json-key=pages", "--json-key=qpdf", v.pdf }
  load(v, "links", cmd, function(out)
    local ok, d = pcall(vim.json.decode, out, { luanil = { object = true, array = true } })
    if not ok then return {} end
    local objs = d.qpdf[2]
    local function res(x)
      while type(x) == "string" and x:match "^%d+ %d+ R$" do
        local o = objs["obj:" .. x]
        x = o and o.value
      end
      return x
    end
    local page_of = {}
    for i, p in ipairs(d.pages) do page_of[p.object] = i end

    -- named destinations: catalog /Names /Dests name tree (or the old /Dests dictionary)
    local names = {}
    local function walk(node)
      node = res(node)
      if type(node) ~= "table" then return end
      local list = res(node["/Names"])
      for i = 1, list and #list or 0, 2 do names[list[i]] = list[i + 1] end
      for _, kid in ipairs(res(node["/Kids"]) or {}) do walk(kid) end
    end
    local catalog = res(objs.trailer.value["/Root"])
    walk((res(catalog["/Names"]) or {})["/Dests"])
    for k, val in pairs(res(catalog["/Dests"]) or {}) do names["u:" .. k:sub(2)] = val end

    local function dest(x)
      x = res(x)
      if type(x) == "string" then x = res(names[x]) end
      if type(x) == "table" and not vim.islist(x) then x = res(x["/D"]) end
      if type(x) ~= "table" then return end
      local page = page_of[x[1]]
      if not page then return end
      local size = v.sizes[page] or { 595, 842 }
      local y = x[2] == "/XYZ" and x[4] or x[2] == "/FitH" and x[3] or nil
      return page, type(y) == "number" and size[2] - y or nil
    end
    local function text(x)
      return type(x) == "string" and x:sub(3) or nil
    end

    local links = {}
    for i, p in ipairs(d.pages) do
      links[i] = {}
      local size = v.sizes[i] or { 595, 842 }
      for _, ref in ipairs(res((res(p.object) or {})["/Annots"]) or {}) do
        local a = res(ref)
        if type(a) == "table" and a["/Subtype"] == "/Link" and a["/Rect"] then
          local r = a["/Rect"]
          local link = {
            math.min(r[1], r[3]), size[2] - math.max(r[2], r[4]), math.max(r[1], r[3]), size[2] - math.min(r[2], r[4]),
          }
          local act = res(a["/A"])
          if a["/Dest"] then
            link.page, link.y = dest(a["/Dest"])
          elseif type(act) == "table" and act["/S"] == "/GoTo" then
            link.page, link.y = dest(act["/D"])
          elseif type(act) == "table" and act["/S"] == "/URI" then
            link.uri = text(act["/URI"])
          end
          if link.page or link.uri then table.insert(links[i], link) end
        end
      end
    end
    return links
  end, cb)
end

--- Where the viewport is, to come back to after following a link.
local function position(v)
  return { sy = v.sy, sx = v.sx, zoom = v.zoom }
end

function M.back(buf)
  local v = views[buf]
  local pos = v and table.remove(v.back)
  if not pos then return end
  v.sy, v.sx, v.zoom = pos.sy, pos.sx, pos.zoom
  draw(buf)
end

--- Follow a link: another place in the document (remembered for `back`) or a URL.
function M.follow(buf, link)
  local v = views[buf]
  if link.uri then return vim.ui.open(link.uri) end
  table.insert(v.back, position(v))
  v.sy = v.offs[link.page] + (link.y or 0) - 12
  draw(buf)
end

local function link_label(v, page, link)
  local out = {}
  for _, w in ipairs((v.words or {})[page] or {}) do
    local cx, cy = (w[1] + w[3]) / 2, (w[2] + w[4]) / 2
    if cx >= link[1] and cx <= link[3] and cy >= link[2] and cy <= link[4] then table.insert(out, w[5]) end
  end
  local label = table.concat(out, " ")
  local target = link.uri or ("p." .. link.page)
  return label ~= "" and (label .. "  → " .. target) or target
end

--- Pick one of the links on the page in the middle of the window.
function M.pick_link(buf)
  local v = views[buf]
  if not v then return end
  local page = v.page
  load_words(v, function()
    load_links(v, function()
      local list = v.links[page] or {}
      if #list == 0 then return vim.notify("No links on this page", vim.log.levels.INFO) end
      vim.ui.select(list, {
        prompt = "Link",
        format_item = function(l) return link_label(v, page, l) end,
      }, function(l)
        if l and views[buf] == v then M.follow(buf, l) end
      end)
    end)
  end)
end

--- Mouse click: follow the link under the pointer.
function M.click(buf)
  local v = views[buf]
  local m = vim.fn.getmousepos()
  local win = vim.fn.bufwinid(buf)
  if not v or win < 0 or m.winid ~= win then return end
  vim.api.nvim_set_current_win(win)
  local place = v.place
  local geom, shown = place and place.geom, place and place.shown
  if not geom or not shown then return end
  local pos = vim.api.nvim_win_get_position(win)
  local bar = vim.wo[win].winbar ~= "" and 1 or 0
  local col = m.screencol - 1 - pos[2] - vim.fn.getwininfo(win)[1].textoff
  local row = m.screenrow - 1 - pos[1] - bar
  local fx, fy = (col - geom.left + 0.5) / geom.w, (row - geom.top + 0.5) / geom.h
  if fx < 0 or fx > 1 or fy < 0 or fy > 1 then return end
  local dx, dy = shown.sx + fx * shown.w / shown.scale, shown.sy + fy * shown.h / shown.scale
  local page = page_at(v, dy)
  local s = size_of(v, page)
  local px, py = dx - (v.maxw - s[1]) / 2, dy - v.offs[page]
  local tol = 0.5 * shown.h / geom.h / shown.scale -- half a cell, in pt
  load_links(v, function()
    if views[buf] ~= v then return end
    local best, dist = nil, math.huge
    for _, l in ipairs(v.links[page] or {}) do
      local ex = math.max(l[1] - px, 0, px - l[3])
      local ey = math.max(l[2] - py, 0, py - l[4])
      local d = math.sqrt(ex * ex + ey * ey)
      if d <= tol and d < dist then best, dist = l, d end
    end
    if best then M.follow(buf, best) end
  end)
end

local function highlight_pages(v)
  v.by_page = {}
  for i, hit in ipairs(v.hits) do
    v.by_page[hit.page] = v.by_page[hit.page] or {}
    table.insert(v.by_page[hit.page], { rects = hit.rects, cur = i == v.cur })
  end
end

--- Make hit `i` the current one: show its page, highlighted.
function M.goto_hit(buf, i)
  local v = views[buf]
  if not v or #v.hits == 0 then return end
  v.cur = (i - 1) % #v.hits + 1
  local hit = v.hits[v.cur]
  highlight_pages(v)
  local vw, vh = view_pt(buf)
  if vh then
    local r = hit.rects[1]
    local s = size_of(v, hit.page)
    v.sy = v.offs[hit.page] + r[2] - vh * 0.3
    v.sx = (v.maxw - s[1]) / 2 + (r[1] + r[3]) / 2 - vw / 2
  end
  draw(buf)
end

--- Next (`delta` 1) or previous (-1) hit.
function M.next_hit(buf, delta)
  local v = views[buf]
  if v then M.goto_hit(buf, v.cur + delta) end
end

--- Highlight every occurrence of `query` (case-insensitive, spaces match any gap between words)
--- and jump to the first one from the current page on (`stay`: only refresh the highlights).
function M.search(buf, query, stay)
  local v = views[buf]
  if not v then return end
  if not query or query == "" then
    local had = #v.hits > 0
    v.query, v.hits, v.cur = nil, {}, 0
    highlight_pages(v)
    if had then draw(buf) else set_status(buf) end
    return
  end
  v.query = query
  load_words(v, function()
    if views[buf] ~= v or v.query ~= query then return end
    local needle = vim.fn.tolower((query:gsub("%s+", " ")))
    local hits = {}
    for page, words in ipairs(v.words) do
      local parts, starts, pos = {}, {}, 1
      for i, w in ipairs(words) do
        starts[i] = pos
        parts[i] = vim.fn.tolower(w[5])
        pos = pos + #parts[i] + 1
      end
      local hay = table.concat(parts, " ")
      local init, first = 1, 1
      while true do
        local a, b = hay:find(needle, init, true)
        if not a then break end
        while first < #starts and starts[first + 1] <= a do first = first + 1 end
        local rects, last = {}, first
        while last <= #words and starts[last] <= b do
          table.insert(rects, words[last])
          last = last + 1
        end
        table.insert(hits, { page = page, rects = rects })
        init = b + 1
      end
    end
    v.hits = hits
    if #hits == 0 then
      v.cur = 0
      highlight_pages(v)
      vim.notify("Pattern not found: " .. query, vim.log.levels.WARN)
      return draw(buf)
    end
    local start = 1
    for i, hit in ipairs(hits) do
      if hit.page >= v.page then start = i; break end
    end
    if not stay then return M.goto_hit(buf, start) end
    v.cur = start
    highlight_pages(v)
    draw(buf)
  end)
end

function M.prompt_search(buf)
  local v = views[buf]
  if not v then return end
  vim.ui.input({ prompt = "Search: ", default = v.query }, function(q)
    if q and views[buf] == v then M.search(buf, q) end
  end)
end

local function teardown(buf)
  local v = views[buf]
  views[buf] = nil
  if not v then return end
  if v.place then v.place:close() end
  close_all(v.stale)
  clear_frames(v)
  clear_bands(v)
  if v.timer and not v.timer:is_closing() then v.timer:stop(); v.timer:close() end
end

function M.attach(buf, pdf)
  teardown(buf) -- :bdelete only unloads, so the next :e re-attaches the same buffer
  pdf = vim.fn.fnamemodify(pdf, ":p")
  local v = {
    pdf = pdf, page = 1, n = 1, sizes = {}, offs = {}, maxw = 1, total = 1, zoom = 1, sx = 0, sy = 0, stale = {},
    frames = {}, bands = {}, band_order = {}, inflight = {}, dir = 1, prev_sy = 0, seq = 0, epoch = 0, waiting = {}, hits = {}, cur = 0, by_page = {}, back = {},
  }
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
  map({ "k", "<Down>", "<ScrollWheelDown>" }, function() M.scroll(buf, 0.12) end, "scroll down")
  map({ "j", "<Up>", "<ScrollWheelUp>" }, function() M.scroll(buf, -0.12) end, "scroll up")
  map({ "<PageDown>", "<C-f>" }, function() M.scroll(buf, 0.9) end, "page down")
  map({ "<PageUp>", "<C-b>" }, function() M.scroll(buf, -0.9) end, "page up")
  map({ "<C-d>" }, function() M.scroll(buf, 0.5) end, "half page down")
  map({ "<C-u>" }, function() M.scroll(buf, -0.5) end, "half page up")
  map({ "gg" }, function() M.goto_page(buf, 1) end, "top")
  map({ "G" }, function() M.to_end(buf) end, "bottom")
  map({ "+", "=", "<C-ScrollWheelUp>" }, function() M.zoom(buf, ZOOM_STEP) end, "zoom in")
  map({ "-", "<C-ScrollWheelDown>" }, function() M.zoom(buf, 1 / ZOOM_STEP) end, "zoom out")
  map({ "0" }, function() M.zoom(buf) end, "fit width")
  map({ "<Left>", "h", "<ScrollWheelLeft>" }, function() M.pan(buf, -1) end, "pan left")
  map({ "<Right>", "l", "<ScrollWheelRight>" }, function() M.pan(buf, 1) end, "pan right")
  map({ "/" }, function() M.prompt_search(buf) end, "search")
  map({ "n" }, function() M.next_hit(buf, 1) end, "next match")
  map({ "N" }, function() M.next_hit(buf, -1) end, "previous match")
  map({ "<Esc>" }, function() M.search(buf, nil) end, "clear search")
  map({ "<LeftMouse>" }, function() M.click(buf) end, "follow link")
  map({ "f" }, function() M.pick_link(buf) end, "pick a link on the page")
  map({ "<C-o>", "<BS>" }, function() M.back(buf) end, "back from a link")
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
        if views[buf] == v then draw(buf) end
      end))
    end,
  })
  vim.wo.winbar = "%=%{get(b:, 'pdfview_status', '')} "

  Snacks.image.terminal.detect(function() vim.schedule(function() M.refresh(buf) end) end)
end

return M
