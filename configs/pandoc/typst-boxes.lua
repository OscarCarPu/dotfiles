-- ::: box  /  ::: {.box title="Definición"}  -> framed square;  ::: nota -> shaded block
local styles = {
  box = 'stroke: 0.8pt + black, inset: 0.8em, radius: 2pt',
  nota = 'fill: luma(240), stroke: (left: 2pt + luma(120)), inset: 0.8em',
}

function Div(el)
  for _, class in ipairs(el.classes) do
    local style = styles[class]
    if style then
      local blocks = { pandoc.RawBlock("typst", "#block(width: 100%, breakable: false, " .. style .. ")[") }
      local title = el.attributes.title
      if title then
        table.insert(blocks, pandoc.RawBlock("typst", "*" .. title .. "*#v(0.3em)"))
      end
      for _, b in ipairs(el.content) do table.insert(blocks, b) end
      table.insert(blocks, pandoc.RawBlock("typst", "]"))
      return blocks
    end
  end
end
