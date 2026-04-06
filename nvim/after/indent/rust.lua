-- Override cindent-based indentation with treesitter.
-- cindent misindents after Rust structs (no trailing ;) since it's a C indenter.
vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
