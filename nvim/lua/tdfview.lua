-- PDFs in tdf, in a kitty split next to this nvim window (kitty remote control, see kitty.conf).
-- tdf reloads by itself when the file changes, so a live preview only has to replace the PDF.
local M = {}
local wins = {} ---@type table<string, number> key -> kitty window id

function M.available()
  return vim.env.KITTY_LISTEN_ON ~= nil and vim.fn.executable "tdf" == 1 and vim.fn.executable "kitten" == 1
end

local function kitten(...)
  return vim.system({ "kitten", "@", ... }, { text = true }):wait()
end

function M.alive(key)
  return wins[key] ~= nil and kitten("ls", "--match", "id:" .. wins[key]).code == 0
end

--- Show `pdf` in a split on the right. An already open one is just focused (unless `keep_focus`).
function M.open(pdf, opts)
  opts = opts or {}
  local key = opts.key or pdf
  if M.alive(key) then
    if not opts.keep_focus then kitten("focus-window", "--match", "id:" .. wins[key]) end
    return
  end
  local args = { "launch", "--type=window", "--location=vsplit", "--title", "tdf", "--cwd=current" }
  if opts.keep_focus then table.insert(args, "--keep-focus") end
  vim.list_extend(args, { "tdf", vim.fn.fnamemodify(pdf, ":p") })
  local r = kitten(unpack(args))
  wins[key] = r.code == 0 and tonumber(vim.trim(r.stdout)) or nil
  if r.code ~= 0 then vim.notify("tdf: " .. (r.stderr or ""), vim.log.levels.ERROR) end
end

--- Show page `page` (tdf has no CLI/IPC for it: read the page counter off its screen, type `g<n>`).
function M.goto_page(key, page)
  local id = wins[key]
  if not id then return end
  vim.system({ "kitten", "@", "get-text", "--match", "id:" .. id }, { text = true }, vim.schedule_wrap(function(r)
    if r.code ~= 0 then return end
    local header = table.concat(vim.list_slice(vim.split(r.stdout or "", "\n"), 1, 4), "\n")
    local cur = tonumber(header:match "(%d+) / %d+")
    if cur and cur ~= page then
      vim.system { "kitten", "@", "send-text", "--match", "id:" .. id, "g" .. page .. "\r" }
    end
  end))
end

function M.close(key)
  if wins[key] then kitten("close-window", "--match", "id:" .. wins[key]) end
  wins[key] = nil
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    for key in pairs(vim.deepcopy(wins)) do M.close(key) end
  end,
})

return M
