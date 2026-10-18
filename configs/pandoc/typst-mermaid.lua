-- ```mermaid  -> diagram rendered by mmdc into <doc dir>/.mermaid/<hash>.png (cached by content);
-- without mmdc or chromium, or when the diagram does not compile, the block stays as plain code
local function sh(cmd)
  local p = io.popen(cmd .. " 2>/dev/null")
  local out = p:read("a")
  return p:close() and out or nil
end

local chromium
for _, bin in ipairs { "chromium", "google-chrome-stable", "chrome" } do
  chromium = chromium or sh("command -v " .. bin)
end
local mmdc = sh("command -v mmdc") or sh("command -v ~/.bun/bin/mmdc")

local dir
function Meta(meta)
  if meta.mermaid_dir then dir = pandoc.utils.stringify(meta.mermaid_dir) end
  dir = dir or (PANDOC_STATE.input_files[1] or ""):match("^(.*)/[^/]*$") or "."
end

function CodeBlock(el)
  if not el.classes:includes("mermaid") or not mmdc or not chromium then return end
  local name = pandoc.sha1(el.text) .. ".png"
  local out = dir .. "/.mermaid/" .. name
  if not io.open(out, "r") then
    os.execute("mkdir -p '" .. dir .. "/.mermaid'")
    local src, cfg = os.tmpname(), os.tmpname()
    io.open(src, "w"):write(el.text):close()
    io.open(cfg, "w"):write(('{"executablePath":"%s","args":["--no-sandbox"]}'):format(chromium:gsub("%s+$", ""))):close()
    local ok = os.execute(("%s -p %s -i %s -o '%s' -b white -s 3 >/dev/null 2>&1"):format(mmdc:gsub("%s+$", ""), cfg, src, out))
    os.remove(src); os.remove(cfg)
    if not ok then return end
  end
  -- rendered at 3x: show it at natural size (1px = 1pt), never wider than the text block
  local w = tonumber(sh("magick identify -format %w '" .. out .. "'")) or 1350
  local width = ("%dpt"):format(math.min(w / 3, 450))
  return pandoc.Para { pandoc.Image({}, ".mermaid/" .. name, "", pandoc.Attr("", {}, { width = width })) }
end

return { { Meta = Meta }, { CodeBlock = CodeBlock } }
