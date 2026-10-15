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
---@field epoch number bumped whenever the file changes on disk (drops stale async results)
---@field words? table<number, table[]> per page: {x0, y0, x1, y1, text} in pt, origin top-left
---@field links? table<number, table[]> per page: {x0, y0, x1, y1, page?, y?, uri?}
---@field waiting table<string, function[]> callbacks queued behind a running loader
---@field query? string
---@field hits table[] {page, rects}
---@field cur number index into hits
---@field by_page table<number, table[]> highlight rects per page {rects, cur}
---@field hlver number
---@field shown? table geometry of the image on screen {dpi, x, y, w, h}
---@field back table[] positions to return to after following a link
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
  local find = ""
  if v.query then
    find = #v.hits > 0 and string.format("/%s %d/%d  ", v.query, v.cur, #v.hits) or string.format("/%s no match  ", v.query)
  end
  vim.b[buf].pdfview_status = string.format("%s%d/%d%s", find, v.page, v.n, zoom)
  vim.cmd.redrawstatus()
end

local function clear_cache(v)
  for _, f in pairs(v.cache) do os.remove(f) end
  v.cache = {}
end

local function drop_highlighted(v)
  for k, f in pairs(v.cache) do
    if k:find("|h", 1, true) then os.remove(f); v.cache[k] = nil end
  end
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

--- pdftoppm arguments + cache key + geometry (dpi and pixel offset of the render) for `page`
--- at the current zoom/pan. Pages with search hits get their own key.
local function plan(v, page, wpx, hpx)
  local size = v.sizes[page] or v.sizes[1] or { 595, 842 }
  local fit = math.min(wpx * 72 / size[1], hpx * 72 / size[2])
  local key, args, g
  if v.zoom <= 1 then
    local dpi = fit * 1.25
    key = string.format("%d:%d:%d", page, wpx, hpx)
    args = { "-r", string.format("%.1f", dpi), "-f", page, "-l", page, "-singlefile" }
    g = { dpi = dpi, x = 0, y = 0 }
  else
    local dpi = math.min(fit * v.zoom, 500)
    local pw, ph = size[1] * dpi / 72, size[2] * dpi / 72
    local w, h = math.min(wpx, pw), math.min(hpx, ph)
    local x = math.max(0, math.min(v.cx * pw - w / 2, pw - w))
    local y = math.max(0, math.min(v.cy * ph - h / 2, ph - h))
    key = string.format("%d:%d:%d:%.2f:%d:%d", page, wpx, hpx, v.zoom, x, y)
    args = {
      "-r", string.format("%.1f", dpi), "-x", math.floor(x), "-y", math.floor(y),
      "-W", math.floor(w), "-H", math.floor(h), "-f", page, "-l", page, "-singlefile",
    }
    g = { dpi = dpi, x = math.floor(x), y = math.floor(y) }
  end
  if v.by_page[page] then key = string.format("%s|h%d", key, v.hlver) end
  return key, args, g
end

--- magick arguments painting the search hits of `page` onto a render (current hit stronger).
local function highlight_cmd(v, page, g, png)
  local hits = v.by_page[page]
  if not hits then return end
  local k = g.dpi / 72
  local cmd = { "magick", png }
  for _, pass in ipairs { false, true } do
    cmd[#cmd + 1] = "-fill"
    cmd[#cmd + 1] = pass and "rgba(255,140,0,0.45)" or "rgba(255,225,0,0.4)"
    for _, hit in ipairs(hits) do
      if hit.cur == pass then
        for _, r in ipairs(hit.rects) do
          cmd[#cmd + 1] = "-draw"
          cmd[#cmd + 1] = string.format(
            "rectangle %d,%d %d,%d", r[1] * k - g.x - 1, r[2] * k - g.y - 1, r[3] * k - g.x + 1, r[4] * k - g.y + 1
          )
        end
      end
    end
  end
  cmd[#cmd + 1] = png
  return cmd
end

local function rasterise(v, buf, page, key, args, g, cb)
  if v.cache[key] then return cb(v.cache[key]) end
  vim.fn.mkdir(dir, "p")
  v.seq = v.seq + 1
  local prefix = string.format("%s/%d-%d", dir, buf, v.seq)
  local cmd = { "pdftoppm", "-png" }
  vim.list_extend(cmd, vim.tbl_map(tostring, args))
  vim.list_extend(cmd, { v.pdf, prefix })
  local png = prefix .. ".png"
  local function finish()
    -- hand snacks the `identify` result so it skips spawning magick for every page
    local size = Snacks.image.util.dim(png)
    local info = Snacks.image.convert.convert({ src = png })
    local step = info.steps[#info.steps]
    vim.fn.writefile({ string.format("PNG %dx%d 72x72", size.width, size.height) }, step.file)
    v.cache[key] = png
    cb(png)
  end
  vim.system(cmd, {}, vim.schedule_wrap(function(r)
    if r.code ~= 0 or views[buf] ~= v then
      os.remove(png)
      return
    end
    local paint = highlight_cmd(v, page, g, png)
    if not paint then return finish() end
    vim.system(paint, {}, vim.schedule_wrap(function()
      if views[buf] ~= v then return os.remove(png) end
      finish()
    end))
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

-- One background worker renders the pages ahead (in the direction of travel first), so fast
-- paging never queues several pdftoppm processes against the foreground render.
local function pump(buf, v)
  if v.busy then return end
  local page = table.remove(v.ahead, 1)
  if not page then return end
  local win, wpx, hpx = viewport(buf)
  if not win or v.zoom > 1 then v.ahead = {}; return end
  local key, args, g = plan(v, page, wpx, hpx)
  if v.cache[key] then return pump(buf, v) end
  v.busy = true
  rasterise(v, buf, page, key, args, g, function(png)
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
  local key, args, g = plan(v, page, wpx, hpx)
  rasterise(v, buf, page, key, args, g, function(png)
    if views[buf] ~= v or v.gen ~= gen or not vim.api.nvim_buf_is_valid(buf) then return end
    local px = Snacks.image.util.dim(png)
    show(buf, png, { dpi = g.dpi, x = g.x, y = g.y, w = px.width, h = px.height, page = page })
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
    v.epoch = v.epoch + 1
    v.words, v.links, v.hits, v.by_page = nil, nil, {}, {}
    clear_cache(v)
    read_info(v)
    if v.query then M.search(buf, v.query) end
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
  return { page = v.page, zoom = v.zoom, cx = v.cx, cy = v.cy }
end

local function restore(buf, pos)
  local v = views[buf]
  v.page, v.cx, v.cy = pos.page, pos.cx, pos.cy
  if pos.zoom ~= v.zoom then
    v.zoom = pos.zoom
    clear_cache(v)
  end
  draw(buf)
end

function M.back(buf)
  local v = views[buf]
  local pos = v and table.remove(v.back)
  if pos then restore(buf, pos) end
end

--- Follow a link: another place in the document (remembered for `back`) or a URL.
function M.follow(buf, link)
  local v = views[buf]
  if link.uri then return vim.ui.open(link.uri) end
  table.insert(v.back, position(v))
  v.page = link.page
  if link.y and v.zoom > 1 then
    v.cy = math.max(0, math.min(1, link.y / (v.sizes[link.page] or { 595, 842 })[2]))
  end
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

--- Pick one of the links on the current page.
function M.pick_link(buf)
  local v = views[buf]
  if not v then return end
  load_words(v, function()
    load_links(v, function()
      local list = v.links[v.page] or {}
      if #list == 0 then return vim.notify("No links on this page", vim.log.levels.INFO) end
      vim.ui.select(list, {
        prompt = "Link",
        format_item = function(l) return link_label(v, v.page, l) end,
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
  local k = 72 / shown.dpi
  local px, py = (shown.x + fx * shown.w) * k, (shown.y + fy * shown.h) * k
  local tol = 0.5 * shown.h * k / geom.h -- half a cell, in pt
  load_links(v, function()
    if views[buf] ~= v or v.page ~= shown.page then return end
    local best, dist = nil, math.huge
    for _, l in ipairs(v.links[shown.page] or {}) do
      local dx = math.max(l[1] - px, 0, px - l[3])
      local dy = math.max(l[2] - py, 0, py - l[4])
      local d = math.sqrt(dx * dx + dy * dy)
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
  v.hlver = v.hlver + 1
  drop_highlighted(v)
end

--- Make hit `i` the current one: show its page, highlighted.
function M.goto_hit(buf, i)
  local v = views[buf]
  if not v or #v.hits == 0 then return end
  v.cur = (i - 1) % #v.hits + 1
  local hit = v.hits[v.cur]
  highlight_pages(v)
  v.page = hit.page
  if v.zoom > 1 then
    local size = v.sizes[hit.page] or { 595, 842 }
    local r = hit.rects[1]
    v.cx, v.cy = (r[1] + r[3]) / 2 / size[1], (r[2] + r[4]) / 2 / size[2]
  end
  draw(buf)
end

--- Next (`delta` 1) or previous (-1) hit.
function M.next_hit(buf, delta)
  local v = views[buf]
  if v then M.goto_hit(buf, v.cur + delta) end
end

--- Highlight every occurrence of `query` (case-insensitive, spaces match any gap between words)
--- and jump to the first one from the current page on.
function M.search(buf, query)
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
    M.goto_hit(buf, start)
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
  clear_cache(v)
  if v.timer and not v.timer:is_closing() then v.timer:stop(); v.timer:close() end
end

--- Turn `buf` into a viewer of `pdf`.
function M.attach(buf, pdf)
  teardown(buf) -- :bdelete only unloads, so the next :e re-attaches the same buffer
  pdf = vim.fn.fnamemodify(pdf, ":p")
  local v = { pdf = pdf, page = 1, n = 1, sizes = {}, zoom = 1, cx = 0.5, cy = 0.5, stale = {}, cache = {}, seq = 0, gen = 0, last = 1, ahead = {},
    epoch = 0, waiting = {}, hits = {}, cur = 0, by_page = {}, hlver = 0, back = {} }
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
  map({ "k", "<PageDown>", "<C-d>", "<C-f>", "<ScrollWheelDown>" }, function() M.step(buf, 1) end, "next page")
  map({ "j", "<PageUp>", "<C-u>", "<C-b>", "<ScrollWheelUp>" }, function() M.step(buf, -1) end, "previous page")
  map({ "gg" }, function() M.goto_page(buf, 1) end, "first page")
  map({ "G" }, function() M.goto_page(buf, v.n) end, "last page")
  map({ "+", "=", "<C-ScrollWheelUp>" }, function() M.zoom(buf, ZOOM_STEP) end, "zoom in")
  map({ "-", "<C-ScrollWheelDown>" }, function() M.zoom(buf, 1 / ZOOM_STEP) end, "zoom out")
  map({ "0" }, function() M.zoom(buf) end, "fit page")
  map({ "<Left>", "h" }, function() M.pan(buf, -1, 0) end, "pan left")
  map({ "<Right>", "l" }, function() M.pan(buf, 1, 0) end, "pan right")
  map({ "<Up>" }, function() M.pan(buf, 0, -1) end, "pan up")
  map({ "<Down>" }, function() M.pan(buf, 0, 1) end, "pan down")
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
        if views[buf] == v then clear_cache(v); draw(buf) end
      end))
    end,
  })
  vim.wo.winbar = "%=%{get(b:, 'pdfview_status', '')} "

  Snacks.image.terminal.detect(function() vim.schedule(function() M.refresh(buf) end) end)
end

return M
