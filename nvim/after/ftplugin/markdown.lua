-- Disable friendly-snippets for markdown to prevent unwanted callout insertion
local ls = require("luasnip")
ls.filetype_set("markdown", {})
