-- Treat $...$ / $$...$$ as Typst math, never LaTeX.
function Math(el)
  if el.mathtype == "DisplayMath" then
    return pandoc.RawInline("typst", "$ " .. el.text .. " $")
  end
  return pandoc.RawInline("typst", "$" .. el.text .. "$")
end
