-- PDF viewer in an ordinary buffer. Every page is an image transmitted to kitty once and drawn
-- through unicode placeholders (the technique snacks.image and image.nvim use): the buffer holds
-- one line per terminal row of the page, so nvim itself scrolls, clips and pans it, instantly.
-- Pages near the window are rasterised ahead by a few parallel pdftoppm jobs (a quick low-res
-- pass first, then the sharp one), far pages are dropped again.
local M = {}

---@class pdfview.Page
---@field level number 0 nothing drawn, 1 low-res, 2 sharp
---@field busy? boolean
---@field failed? string version of the PDF that could not be rendered
---@field img? snacks.Image
---@field png? string
---@field mtime? string version of the PDF drawn
---@field hlkey string signature of the highlights painted on it (search hits, hovered link; "" = none)
---@field base? string the clean raster; `png` is the copy shown (with highlights) and sent to kitty
---@field dpi? number

---@class pdfview.View
---@field pdf string
---@field page number page in the middle of the window
---@field n number
---@field mtime? string
---@field sizes table<number, number[]> page sizes in pt
---@field maxw number widest page (pt)
---@field zoom number 1 = widest page as wide as the window
---@field lay? table[] per page {row, rows, cols, pad} in terminal cells, row 0-based
---@field cols_max number strip width in cells
---@field scale number px per pt at the current layout
---@field total_rows number
---@field W number window width the layout was made for
---@field left number blank cells left of the strip when it is narrower than the window
---@field cw number
---@field ch number
---@field pages table<number, pdfview.Page>
---@field gen number bumped on every layout change (drops stale async results)
---@field jobs number
---@field seq number
---@field epoch number bumped whenever the file changes on disk (drops stale async results)
---@field words? table<number, table[]> per page: {x0, y0, x1, y1, text} in pt, origin top-left
---@field links? table<number, table[]> per page: {x0, y0, x1, y1, page?, y?, uri?}
---@field waiting table<string, function[]> callbacks queued behind a running loader
---@field query? string
---@field hits table[] {page, rects}
---@field cur number index into hits
---@field by_page table<number, table[]> highlight rects per page {rects, cur}
---@field hlver number
---@field back table[] positions to return to after following a link
---@field timer? uv_timer_t
local views = {} ---@type table<number, pdfview.View>
-- per instance: snacks keeps an `identify` result next to each png path in its own persistent
-- cache, so a path reused by another session would be drawn with the wrong size
local dir = string.format("%s/pdfview/%d", vim.fn.stdpath "cache", vim.fn.getpid())
vim.api.nvim_create_autocmd("VimLeavePre", { callback = function() vim.fn.delete(dir, "rf") end })

local ZOOM_STEP, ZOOM_MIN = 1.25, 0.25
local MAXCELLS = 297 -- the placeholder protocol numbers rows and columns with 297 diacritics
local GAP = 1 -- blank rows between pages
local NEAR, FAR = 2, 6 -- pages beyond the window drawn sharp / at low resolution
local JOBS = 3 -- parallel pdftoppm processes
local LOW = 0.3 -- resolution of the quick first pass
local PLACEHOLDER = vim.fn.nr2char(0x10EEEE)
local ns = vim.api.nvim_create_namespace "pdfview"
local WINOPTS = {
  number = false, relativenumber = false, cursorline = false, signcolumn = "no", wrap = false, list = false,
  scrolloff = 0, sidescrolloff = 0, foldcolumn = "0", statuscolumn = "", colorcolumn = "", spell = false,
  winbar = "%=%{get(b:, 'pdfview_status', '')} ",
}
local diacritics = vim.split("0305,030D,030E,0310,0312,033D,033E,033F,0346,034A,034B,034C,0350,0351,0352,0357,035B,0363,0364,0365,0366,0367,0368,0369,036A,036B,036C,036D,036E,036F,0483,0484,0485,0486,0487,0592,0593,0594,0595,0597,0598,0599,059C,059D,059E,059F,05A0,05A1,05A8,05A9,05AB,05AC,05AF,05C4,0610,0611,0612,0613,0614,0615,0616,0617,0657,0658,0659,065A,065B,065D,065E,06D6,06D7,06D8,06D9,06DA,06DB,06DC,06DF,06E0,06E1,06E2,06E4,06E7,06E8,06EB,06EC,0730,0732,0733,0735,0736,073A,073D,073F,0740,0741,0743,0745,0747,0749,074A,07EB,07EC,07ED,07EE,07EF,07F0,07F1,07F3,0816,0817,0818,0819,081B,081C,081D,081E,081F,0820,0821,0822,0823,0825,0826,0827,0829,082A,082B,082C,082D,0951,0953,0954,0F82,0F83,0F86,0F87,135D,135E,135F,17DD,193A,1A17,1A75,1A76,1A77,1A78,1A79,1A7A,1A7B,1A7C,1B6B,1B6D,1B6E,1B6F,1B70,1B71,1B72,1B73,1CD0,1CD1,1CD2,1CDA,1CDB,1CE0,1DC0,1DC1,1DC3,1DC4,1DC5,1DC6,1DC7,1DC8,1DC9,1DCB,1DCC,1DD1,1DD2,1DD3,1DD4,1DD5,1DD6,1DD7,1DD8,1DD9,1DDA,1DDB,1DDC,1DDD,1DDE,1DDF,1DE0,1DE1,1DE2,1DE3,1DE4,1DE5,1DE6,1DFE,20D0,20D1,20D4,20D5,20D6,20D7,20DB,20DC,20E1,20E7,20E9,20F0,2CEF,2CF0,2CF1,2DE0,2DE1,2DE2,2DE3,2DE4,2DE5,2DE6,2DE7,2DE8,2DE9,2DEA,2DEB,2DEC,2DED,2DEE,2DEF,2DF0,2DF1,2DF2,2DF3,2DF4,2DF5,2DF6,2DF7,2DF8,2DF9,2DFA,2DFB,2DFC,2DFD,2DFE,2DFF,A66F,A67C,A67D,A6F0,A6F1,A8E0,A8E1,A8E2,A8E3,A8E4,A8E5,A8E6,A8E7,A8E8,A8E9,A8EA,A8EB,A8EC,A8ED,A8EE,A8EF,A8F0,A8F1,AAB0,AAB2,AAB3,AAB7,AAB8,AABE,AABF,AAC1,FE20,FE21,FE22,FE23,FE24,FE25,FE26,10A0F,10A38,1D185,1D186,1D187,1D188,1D189,1D1AA,1D1AB,1D1AC,1D1AD,1D242,1D243,1D244", ",")
local positions = setmetatable({}, {
  __index = function(t, k)
    t[k] = vim.fn.nr2char(tonumber(diacritics[k], 16))
    return t[k]
  end,
})

local pump, relayout

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
  v.maxw = 1
  for i = 1, v.n do v.maxw = math.max(v.maxw, size_of(v, i)[1]) end
end

local function win_of(buf)
  local win = vim.fn.bufwinid(buf)
  return win >= 0 and win or nil
end

local function win_cols(win)
  return vim.api.nvim_win_get_width(win) - vim.fn.getwininfo(win)[1].textoff
end

local function cell_size()
  local t = Snacks.image.terminal.size()
  return t.cell_width, t.cell_height
end

local function setlines(buf, first, last, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, first, last, false, lines)
  vim.bo[buf].modifiable = false
end

--- Page positions in terminal cells for a window `W` cells wide.
local function build_layout(v, W, cw, ch)
  local cols_max = math.max(1, math.min(MAXCELLS, math.floor(W * v.zoom + 0.5)))
  local scale = cols_max * cw / v.maxw
  local left = math.max(0, math.floor((W - cols_max) / 2))
  local lay, row = {}, 0
  for i = 1, v.n do
    local s = size_of(v, i)
    local cols = math.max(1, math.min(cols_max, math.floor(s[1] * scale / cw + 0.5)))
    local rows = math.max(1, math.min(MAXCELLS, math.floor(s[2] * scale / ch + 0.5)))
    lay[i] = { row = row, rows = rows, cols = cols, pad = left + math.floor((cols_max - cols) / 2) }
    row = row + rows + GAP
  end
  return { lay = lay, cols_max = cols_max, scale = scale, total_rows = row - GAP, W = W, cw = cw, ch = ch, left = left }
end

local function same_layout(a, b)
  if not a or #a.lay ~= #b.lay or a.W ~= b.W or a.cw ~= b.cw or a.ch ~= b.ch then return false end
  for i, l in ipairs(a.lay) do
    local m = b.lay[i]
    if l.row ~= m.row or l.rows ~= m.rows or l.cols ~= m.cols or l.pad ~= m.pad then return false end
  end
  return true
end

local function page_at_row(v, row)
  local lo, hi = 1, v.n
  while lo < hi do
    local mid = math.ceil((lo + hi) / 2)
    if v.lay[mid].row <= row then lo = mid else hi = mid - 1 end
  end
  return lo
end

local function top_bot(win)
  return vim.fn.line("w0", win), vim.fn.line("w$", win)
end

local function leftcol(win)
  return vim.api.nvim_win_call(win, function() return vim.fn.winsaveview().leftcol end)
end

--- The document point in the middle of the window: page, fraction down the page, fraction across the strip.
local function get_anchor(v, win)
  local top, bot = top_bot(win)
  local row = (top + bot) / 2 - 1
  local p = page_at_row(v, row)
  local L = v.lay[p]
  return {
    page = p,
    fy = math.max(0, math.min(1, (row - L.row) / L.rows)),
    fx = (leftcol(win) + win_cols(win) / 2) / v.cols_max,
  }
end

--- Put `row` (0-based) at `frac` of the window height (and optionally `col`, a cell, in the middle).
local function scroll_to(v, win, row, frac, col)
  local h = vim.api.nvim_win_get_height(win)
  local top = math.max(1, math.min(math.floor(row - h * frac + 1.5), math.max(1, v.total_rows - h + 1)))
  local view = { topline = top, lnum = math.min(v.total_rows, top + math.floor(h / 2)) }
  if col then
    view.leftcol = math.max(0, math.floor(col - win_cols(win) / 2))
    view.col = view.leftcol
  end
  vim.api.nvim_win_call(win, function() vim.fn.winrestview(view) end)
end

local function set_anchor(v, win, a)
  local L = v.lay[math.min(a.page, v.n)]
  scroll_to(v, win, L.row + a.fy * L.rows, 0.5, a.fx * v.cols_max)
end

local function set_status(buf)
  local v = views[buf]
  local win = win_of(buf)
  if not win or not v.lay then return end
  local top, bot = top_bot(win)
  v.page = page_at_row(v, math.floor((top + bot) / 2) - 1)
  local zoom = v.zoom ~= 1 and string.format("  %d%%", v.zoom * 100) or ""
  local find = ""
  if v.query then
    find = #v.hits > 0 and string.format("/%s %d/%d  ", v.query, v.cur, #v.hits) or string.format("/%s no match  ", v.query)
  end
  vim.b[buf].pdfview_status = string.format("%s%d/%d%s", find, v.page, v.n, zoom)
  vim.cmd.redrawstatus()
end

--- Signature of what has to be painted on `page`: search hits and the hovered link.
local function hl_for(v, page)
  local sig = v.by_page[page] and ("s" .. v.hlver) or ""
  if v.hover and v.hover.page == page then sig = sig .. "h" .. v.hover.link[1] .. "," .. v.hover.link[2] end
  return sig
end

--- Free a page's image and blank its rows.
local function clear_page(v, buf, page)
  local st = v.pages[page]
  local L = v.lay[page]
  if not st or st.level == 0 then return end
  if st.img then Snacks.image.terminal.request { a = "d", d = "I", i = st.img.id } end
  if st.png then os.remove(st.png) end
  if st.base then os.remove(st.base) end
  v.pages[page] = { level = 0, hlkey = "" }
  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_del_extmark, buf, ns, page)
    local blank = string.rep(" ", v.left + v.cols_max)
    setlines(buf, L.row, L.row + L.rows, vim.fn["repeat"]({ blank }, L.rows))
  end
end

--- Show the transmitted image `img` in the rows of `page`; the previous image of the page is freed.
local function install(v, buf, page, img, png, base, dpi, level, mtime, hlkey)
  local L = v.lay[page]
  local st = v.pages[page]
  local old_img, old_png, old_base = st.img, st.png, st.base
  Snacks.image.terminal.request { a = "p", U = 1, i = img.id, p = page, C = 1, c = L.cols, r = L.rows }
  local group = string.format("PdfView%d_%d", buf, page)
  Snacks.util.set_hl { [group] = { fg = img.id, sp = page, bg = "none", nocombine = true } }
  if not old_img then
    local pad = string.rep(" ", L.pad)
    local tail = string.rep(" ", math.max(0, v.left + v.cols_max - L.pad - L.cols))
    local lines, cells = {}, {}
    for r = 1, L.rows do
      for c = 1, L.cols do cells[c] = PLACEHOLDER .. positions[r] .. positions[c] end
      lines[r] = pad .. table.concat(cells, "", 1, L.cols) .. tail
    end
    setlines(buf, L.row, L.row + L.rows, lines)
    vim.api.nvim_buf_set_extmark(buf, ns, L.row, 0, {
      id = page, end_row = L.row + L.rows - 1, end_col = #lines[L.rows] - #tail, hl_group = group,
      undo_restore = false, strict = false,
    })
  end
  v.pages[page] = { level = level, img = img, png = png, base = base, dpi = dpi, mtime = mtime, hlkey = hlkey }
  if old_img then Snacks.image.terminal.request { a = "d", d = "I", i = old_img.id } end
  if old_png then os.remove(old_png) end
  if old_base and old_base ~= base then os.remove(old_base) end
end

--- magick command painting the search hits (current one stronger) and the hovered link of `page`
--- onto the clean raster `src`, written to `out`; nil when there is nothing to paint.
local function highlight_cmd(v, page, dpi, src, out)
  local hits = v.by_page[page]
  local hover = v.hover and v.hover.page == page and v.hover.link
  if not hits and not hover then return end
  local k = dpi / 72
  local cmd = { "magick", src }
  local function rect(r)
    cmd[#cmd + 1] = "-draw"
    cmd[#cmd + 1] = string.format("rectangle %d,%d %d,%d", r[1] * k - 1, r[2] * k - 1, r[3] * k + 1, r[4] * k + 1)
  end
  for _, pass in ipairs { false, true } do
    cmd[#cmd + 1] = "-fill"
    cmd[#cmd + 1] = pass and "rgba(255,140,0,0.45)" or "rgba(255,225,0,0.4)"
    for _, hit in ipairs(hits or {}) do
      if hit.cur == pass then
        for _, r in ipairs(hit.rects) do rect(r) end
      end
    end
  end
  if hover then
    cmd[#cmd + 1] = "-fill"
    cmd[#cmd + 1] = "rgba(40,110,255,0.35)"
    rect(hover)
  end
  cmd[#cmd + 1] = out
  return cmd
end

--- Send the clean raster `base` of `page` to kitty (painted if needed) and show it. A job holds one of
--- the JOBS slots until it is shown (`counted`); a repaint of an already rendered page does not.
local function present(v, buf, page, gen, seq, base, dpi, level, mtime, hlkey, counted)
  local out = string.format("%s/%d-%d-%d-d.png", dir, buf, page, seq)
  local function alive()
    return views[buf] == v and v.gen == gen and vim.api.nvim_buf_is_valid(buf)
  end
  -- a layout change already zeroed the counters: only a job of the current layout gives its slot back
  local function release(failed)
    if not alive() then return end
    if counted then v.jobs = v.jobs - 1 end
    v.pages[page].busy = false
    if failed then v.pages[page].failed = mtime end
  end
  local function drop()
    os.remove(out)
    if counted then os.remove(base) end -- a new raster nobody owns yet
  end
  local function drawn()
    local size = Snacks.image.util.dim(out)
    local info = Snacks.image.convert.convert { src = out }
    local step = info.steps[#info.steps]
    -- hand snacks the `identify` result so it skips spawning magick for every page
    vim.fn.writefile({ string.format("PNG %dx%d 72x72", size.width, size.height) }, step.file)
    local img = Snacks.image.image.new(out)
    local function place()
      if not alive() then
        Snacks.image.terminal.request { a = "d", d = "I", i = img.id }
        return drop()
      end
      release()
      install(v, buf, page, img, out, base, dpi, level, mtime, hlkey)
      set_status(buf)
      pump(buf)
    end
    if img.sent then return place() end
    img.placements[-seq] = { update = function() img.placements[-seq] = nil; place() end }
  end
  local paint = highlight_cmd(v, page, dpi, base, out)
  if not paint then
    vim.uv.fs_copyfile(base, out)
    return drawn()
  end
  vim.system(paint, {}, vim.schedule_wrap(function(r)
    if r.code ~= 0 or not alive() then
      drop()
      return release(r.code ~= 0)
    end
    drawn()
  end))
end

local function start_job(v, buf, page, level)
  local st = v.pages[page]
  st.busy = true
  v.jobs = v.jobs + 1
  v.seq = v.seq + 1
  local seq, gen, mtime, hlkey = v.seq, v.gen, v.mtime, hl_for(v, page)
  local prefix = string.format("%s/%d-%d-%d", dir, buf, page, seq)
  local base = prefix .. ".png"
  local dpi = v.scale * 72 * (level == 1 and LOW or 1)
  vim.fn.mkdir(dir, "p")
  local cmd = { "pdftoppm", "-png", "-singlefile", "-r", string.format("%.2f", dpi), "-f", page, "-l", page, v.pdf, prefix }
  vim.system(vim.tbl_map(tostring, cmd), {}, vim.schedule_wrap(function(r)
    local alive = views[buf] == v and v.gen == gen and vim.api.nvim_buf_is_valid(buf)
    if r.code ~= 0 or not alive then
      os.remove(base)
      if alive then
        v.jobs = v.jobs - 1
        st.busy = false
        st.failed = mtime
      end
      return
    end
    present(v, buf, page, gen, seq, base, dpi, level, mtime, hlkey, true)
  end))
end

--- Repaint the highlights of an already rendered page from its clean raster (no pdftoppm).
local function start_repaint(v, buf, page)
  local st = v.pages[page]
  st.busy = true
  v.seq = v.seq + 1
  present(v, buf, page, v.gen, v.seq, st.base, st.dpi, st.level, st.mtime, hl_for(v, page), false)
end

--- Pages that should be drawn for the current window position: page -> level, in priority order.
local function wanted(v, win)
  local top, bot = top_bot(win)
  local p0, p1 = page_at_row(v, top - 1), page_at_row(v, bot - 1)
  local want, order = {}, {}
  local function add(p, level)
    if p >= 1 and p <= v.n and not want[p] then
      want[p] = level
      order[#order + 1] = p
    end
  end
  for p = p0, p1 do add(p, 2) end
  for d = 1, FAR do
    add(p1 + d, d <= NEAR and 2 or 1)
    add(p0 - d, d <= NEAR and 2 or 1)
  end
  return want, order, p0, p1
end

function pump(buf)
  local v = views[buf]
  local win = win_of(buf)
  if not v or not win or not v.lay then return end
  local want, order, p0, p1 = wanted(v, win)
  for p, st in pairs(v.pages) do
    if st.level > 0 and not st.busy and (p < p0 - FAR - 2 or p > p1 + FAR + 2) then clear_page(v, buf, p) end
  end
  for p, st in pairs(v.pages) do -- cheap: no rendering involved, so no slot needed
    if st.level > 0 and not st.busy and st.base and st.mtime == v.mtime and want[p] and st.hlkey ~= hl_for(v, p) then
      start_repaint(v, buf, p)
    end
  end
  for _, p in ipairs(order) do
    if v.jobs >= JOBS then break end
    v.pages[p] = v.pages[p] or { level = 0, hlkey = "" }
    local st = v.pages[p]
    if not st.busy and st.failed ~= v.mtime then
      local level
      if st.level == 0 then
        level = (p >= p0 and p <= p1 and want[p] == 2) and 1 or want[p]
      elseif st.level < want[p] then
        level = want[p]
      elseif st.mtime ~= v.mtime then
        level = st.level == 1 and 1 or 2
      end
      if level then start_job(v, buf, p, level) end
    end
  end
end

--- Rebuild the whole layout (zoom, window size, different document), keeping the point in the middle.
function relayout(buf, anchor)
  local v = views[buf]
  local win = win_of(buf)
  if not v or not win then return end
  local W = win_cols(win)
  local cw, ch = cell_size()
  anchor = anchor or (v.lay and get_anchor(v, win)) or { page = 1, fy = 0, fx = 0.5 }
  for p in pairs(v.pages) do
    local st = v.pages[p]
    if st.img then Snacks.image.terminal.request { a = "d", d = "I", i = st.img.id } end
    if st.png then os.remove(st.png) end
    if st.base then os.remove(st.base) end
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local b = build_layout(v, W, cw, ch)
  v.lay, v.cols_max, v.scale, v.total_rows, v.W, v.cw, v.ch, v.left = b.lay, b.cols_max, b.scale, b.total_rows, W, cw, ch, b.left
  v.pages, v.jobs, v.gen = {}, 0, v.gen + 1
  local blank = string.rep(" ", b.left + b.cols_max)
  setlines(buf, 0, -1, vim.fn["repeat"]({ blank }, v.total_rows))
  set_anchor(v, win, anchor)
  set_status(buf)
  pump(buf)
end

--- Redraw; re-reads the PDF when it changed on disk and scrolls to `page` if given and not on screen.
function M.refresh(buf, page)
  local v = views[buf]
  if not v then return end
  local now = stamp(v.pdf)
  local changed = now ~= v.mtime
  if changed then
    v.mtime = now
    v.epoch = v.epoch + 1
    v.words, v.links, v.hits, v.by_page, v.hover = nil, nil, {}, {}, nil
    read_info(v)
  end
  local win = win_of(buf)
  if not win then return end
  local cw, ch = cell_size()
  local b = build_layout(v, win_cols(win), cw, ch)
  if not v.lay or not same_layout(v, b) then
    relayout(buf)
  else
    set_status(buf)
    pump(buf)
  end
  if changed and v.query then M.search(buf, v.query, true) end
  if page and page ~= v.page then M.goto_page(buf, page) end
end

function M.goto_page(buf, page)
  local v = views[buf]
  local win = win_of(buf)
  if not v or not win or not v.lay then return end
  scroll_to(v, win, v.lay[math.max(1, math.min(page, v.n))].row, 0, nil)
end

--- Scroll by `lines` (positive = down).
function M.scroll(buf, lines)
  local win = win_of(buf)
  if not win then return end
  vim.api.nvim_win_call(win, function()
    vim.cmd("normal! " .. math.abs(lines) .. (lines > 0 and "\5" or "\25"))
  end)
end

--- Zoom around the middle of the window; no factor = fit the width.
function M.zoom(buf, factor)
  local v = views[buf]
  local win = win_of(buf)
  if not v or not win or not v.lay then return end
  local zmax = MAXCELLS / win_cols(win)
  local zoom = factor and math.max(ZOOM_MIN, math.min(v.zoom * factor, zmax)) or 1
  if zoom == v.zoom then return end
  local anchor = get_anchor(v, win)
  v.zoom = zoom
  relayout(buf, anchor)
end

--- Scroll sideways by `cells` (only matters when zoomed in).
function M.pan(buf, cells)
  local win = win_of(buf)
  if not win then return end
  vim.api.nvim_win_call(win, function() vim.cmd("normal! " .. math.abs(cells) .. (cells > 0 and "zl" or "zh")) end)
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
local function position(v, win)
  return { anchor = get_anchor(v, win), zoom = v.zoom }
end

function M.back(buf)
  local v = views[buf]
  local win = win_of(buf)
  local pos = v and win and table.remove(v.back)
  if not pos then return end
  if pos.zoom ~= v.zoom then
    v.zoom = pos.zoom
    relayout(buf, pos.anchor)
  else
    set_anchor(v, win, pos.anchor)
  end
end

--- Follow a link: another place in the document (remembered for `back`) or a URL.
function M.follow(buf, link)
  local v = views[buf]
  local win = win_of(buf)
  if link.uri then return vim.ui.open(link.uri) end
  if not v or not win then return end
  table.insert(v.back, position(v, win))
  local L = v.lay[link.page]
  scroll_to(v, win, L.row + (link.y or 0) / size_of(v, link.page)[2] * L.rows, 0.1)
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

--- The page and link under a mouse position (`m` from getmousepos), once the links are loaded.
local function link_at(v, win, m)
  local row = m.line - 1
  local page = page_at_row(v, row)
  local L = v.lay[page]
  if row > L.row + L.rows - 1 then return end
  local col = m.wincol - 1 - vim.fn.getwininfo(win)[1].textoff + leftcol(win)
  local fx, fy = (col - L.pad + 0.5) / L.cols, (row - L.row + 0.5) / L.rows
  if fx < 0 or fx > 1 then return end
  local s = size_of(v, page)
  local px, py = fx * s[1], fy * s[2]
  local tol = 0.5 * s[2] / L.rows -- half a cell, in pt
  local best, dist = nil, math.huge
  for _, l in ipairs((v.links or {})[page] or {}) do
    local ex = math.max(l[1] - px, 0, px - l[3])
    local ey = math.max(l[2] - py, 0, py - l[4])
    local d = math.sqrt(ex * ex + ey * ey)
    if d <= tol and d < dist then best, dist = l, d end
  end
  return page, best
end

--- Mouse click: follow the link under the pointer.
function M.click(buf)
  local v = views[buf]
  local m = vim.fn.getmousepos()
  local win = win_of(buf)
  if not v or not win or m.winid ~= win or not v.lay then return end
  vim.api.nvim_set_current_win(win)
  load_links(v, function()
    if views[buf] ~= v then return end
    local _, link = link_at(v, win, m)
    if link then M.follow(buf, link) end
  end)
end

--- Mouse moved: the link under the pointer turns blue (painted onto the page from its clean raster).
function M.hover(buf)
  local v = views[buf]
  local m = vim.fn.getmousepos()
  local win = win_of(buf)
  if not v or not win or m.winid ~= win or not v.lay then return end
  if not v.links then return load_links(v, function() end) end -- the next move finds them
  local page, link = link_at(v, win, m)
  if (v.hover and v.hover.link) == link then return end
  v.hover = link and { page = page, link = link } or nil
  pump(buf)
end

local function highlight_pages(v)
  v.by_page = {}
  for i, hit in ipairs(v.hits) do
    v.by_page[hit.page] = v.by_page[hit.page] or {}
    table.insert(v.by_page[hit.page], { rects = hit.rects, cur = i == v.cur })
  end
  v.hlver = v.hlver + 1
end

--- Make hit `i` the current one: show its page, highlighted.
function M.goto_hit(buf, i)
  local v = views[buf]
  local win = win_of(buf)
  if not v or not win or #v.hits == 0 then return end
  v.cur = (i - 1) % #v.hits + 1
  local hit = v.hits[v.cur]
  highlight_pages(v)
  local L, s, r = v.lay[hit.page], size_of(v, hit.page), hit.rects[1]
  local col = v.cols_max > win_cols(win) and (L.pad + (r[1] + r[3]) / 2 / s[1] * L.cols) or nil
  scroll_to(v, win, L.row + r[2] / s[2] * L.rows, 0.3, col)
  set_status(buf)
  pump(buf)
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
    v.query, v.hits, v.cur = nil, {}, 0
    highlight_pages(v)
    set_status(buf)
    return pump(buf)
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
      set_status(buf)
      return pump(buf)
    end
    local start = 1
    for i, hit in ipairs(hits) do
      if hit.page >= v.page then start = i; break end
    end
    if not stay then return M.goto_hit(buf, start) end
    v.cur = start
    highlight_pages(v)
    set_status(buf)
    pump(buf)
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
  for _, st in pairs(v.pages) do
    if st.img then Snacks.image.terminal.request { a = "d", d = "I", i = st.img.id } end
    if st.png then os.remove(st.png) end
    if st.base then os.remove(st.base) end
  end
  if v.timer and not v.timer:is_closing() then v.timer:stop(); v.timer:close() end
end

--- Turn `buf` into a viewer of `pdf`.
function M.attach(buf, pdf)
  teardown(buf) -- :bdelete only unloads, so the next :e re-attaches the same buffer
  pdf = vim.fn.fnamemodify(pdf, ":p")
  local v = {
    pdf = pdf, page = 1, n = 1, sizes = {}, maxw = 1, zoom = 1, cols_max = 1, scale = 1, total_rows = 1, W = 0,
    left = 0, cw = 10, ch = 20, pages = {}, gen = 0, jobs = 0, seq = 0, epoch = 0, waiting = {}, hits = {}, cur = 0,
    by_page = {}, hlver = 0, back = {},
  }
  views[buf] = v
  Snacks.image.setup()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].undolevels = -1
  vim.bo[buf].filetype = "pdfview"
  vim.bo[buf].modifiable = false

  local function map(keys, fn, desc)
    for _, k in ipairs(keys) do
      vim.keymap.set("n", k, fn, { buffer = buf, desc = "PDF: " .. desc })
    end
  end
  map({ "<Down>" }, function() M.scroll(buf, 3 * vim.v.count1) end, "scroll down")
  map({ "<Up>" }, function() M.scroll(buf, -3 * vim.v.count1) end, "scroll up")
  map({ "+", "=", "<C-ScrollWheelUp>" }, function() M.zoom(buf, ZOOM_STEP) end, "zoom in")
  map({ "-", "<C-ScrollWheelDown>" }, function() M.zoom(buf, 1 / ZOOM_STEP) end, "zoom out")
  map({ "0" }, function() M.zoom(buf) end, "fit width")
  map({ "<Left>", "h" }, function() M.pan(buf, -6) end, "pan left")
  map({ "<Right>", "l" }, function() M.pan(buf, 6) end, "pan right")
  map({ "/" }, function() M.prompt_search(buf) end, "search")
  map({ "n" }, function() M.next_hit(buf, 1) end, "next match")
  map({ "N" }, function() M.next_hit(buf, -1) end, "previous match")
  map({ "<Esc>" }, function() M.search(buf, nil) end, "clear search")
  map({ "<LeftMouse>" }, function() M.click(buf) end, "follow link")
  map({ "<MouseMove>" }, function() M.hover(buf) end, "highlight the link under the pointer")
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

  local saved = {} ---@type table<number, table>
  local moves ---@type boolean? mousemoveevent before the viewer turned it on (needed for link hover)
  local group = vim.api.nvim_create_augroup("pdfview" .. buf, { clear = true })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    buffer = buf,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      moves = moves or vim.o.mousemoveevent
      vim.o.mousemoveevent = true
      saved[win] = {}
      for name, value in pairs(WINOPTS) do
        saved[win][name] = vim.wo[win][name]
        vim.wo[win][name] = value
      end
      vim.schedule(function() M.refresh(buf) end)
    end,
  })
  vim.api.nvim_create_autocmd("BufWinLeave", {
    group = group,
    buffer = buf,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      for name, value in pairs(saved[win] or {}) do vim.wo[win][name] = value end
      saved[win] = nil
      if moves ~= nil then vim.o.mousemoveevent = moves; moves = nil end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
    group = group,
    buffer = buf,
    callback = function() teardown(buf) end,
  })
  -- scrolling brings new pages into range; resizing changes the size every page is drawn at
  local tick = vim.uv.new_timer()
  vim.api.nvim_create_autocmd("WinScrolled", {
    group = group,
    callback = function()
      if views[buf] ~= v or not win_of(buf) then return end
      tick:stop()
      tick:start(30, 0, vim.schedule_wrap(function()
        if views[buf] == v then set_status(buf); pump(buf) end
      end))
    end,
  })
  local resize = vim.uv.new_timer()
  vim.api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
    group = group,
    callback = function()
      if views[buf] ~= v then return end
      resize:stop()
      resize:start(120, 0, vim.schedule_wrap(function()
        if views[buf] == v then M.refresh(buf) end
      end))
    end,
  })

  Snacks.image.terminal.detect(function() vim.schedule(function() M.refresh(buf) end) end)
end

return M
