-- Disable friendly-snippets for markdown to prevent unwanted callout insertion
local ls = require("luasnip")
ls.filetype_set("markdown", {})

local function preview()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local content = vim.json.encode(table.concat(lines, "\n"))
  local head = [=[<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.css">
<script src="https://cdn.jsdelivr.net/npm/marked@12/marked.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/katex@0.16/dist/contrib/auto-render.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
<style>
body{max-width:860px;margin:40px auto;padding:0 24px;font-family:system-ui,sans-serif;line-height:1.6}
pre{background:#f5f5f5;padding:12px;border-radius:6px;overflow-x:auto}
code{background:#f5f5f5;padding:2px 4px;border-radius:3px}
pre code{background:none;padding:0}
</style>
</head>
<body>
<div id="app"></div>
<script>
var html = marked.parse(]=]
  local tail = [=[);
html = html.replace(/<pre><code class="language-mermaid">([\s\S]*?)<\/code><\/pre>/g, function(_, c) {
  c = c.replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>');
  return '<pre class="mermaid">'+c+'</pre>';
});
document.getElementById('app').innerHTML = html;
mermaid.initialize({startOnLoad:false});
mermaid.run({querySelector:'.mermaid'});
renderMathInElement(document.body,{
  delimiters:[{left:'$$',right:'$$',display:true},{left:'$',right:'$',display:false}],
  throwOnError:false
});
</script>
</body>
</html>]=]
  local tmp = vim.fn.tempname() .. ".html"
  local f = io.open(tmp, "w")
  f:write(head .. content .. tail)
  f:close()
  vim.fn.jobstart({ "xdg-open", tmp })
end

vim.keymap.set("n", "<leader>mp", preview, { desc = "Markdown: browser preview", buffer = true })
