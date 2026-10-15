# Neovim Configuration

Based on [NvChad v2.5](https://github.com/NvChad/NvChad) with the **oxocarbon** theme. Browse themes with `:Telescope themes`.

## Keybindings

| Key | Mode | Action |
|-----|------|--------|
| `Space + e` | Normal | Toggle file explorer |

### Search (`Space + s`)

| Key | Action |
|-----|--------|
| `Space + sg` | Grep (cwd) |
| `Space + sG` | Grep (root) |
| `Space + sb` | Fuzzy find in current buffer |
| `Space + sf` | Find files |
| `Space + sh` | Help tags |
| `Space + sk` | Keymaps |
| `Space + sm` | Marks |
| `Space + sr` | Resume last search |
| `Space + sw` | Grep word under cursor |
| `Space + s"` | Registers |
| `Space + sd` | Diagnostics |
| `Space + ss` | Document symbols (LSP) |
| `Space + sS` | Workspace symbols (LSP) |

### Supermaven (AI Completion)

| Key | Action |
|-----|--------|
| `Ctrl + k` | Accept suggestion |
| `Ctrl + j` | Accept word |

## Plugins

| Plugin | Purpose |
|--------|---------|
| **nvim-tree** | File explorer sidebar, opens on startup |
| **supermaven** | AI code completion |
| **conform.nvim** | Code formatting (stylua, gofumpt, ktlint, rustfmt, ruff) |
| **nvim-lspconfig** | LSP support (HTML, CSS, Go, Rust, Kotlin, XML, Svelte, Python) |
| **nvim-treesitter** | Syntax highlighting (vim, lua, vimdoc, html, css, go, rust, kotlin, java, xml, markdown, svelte, js, ts, python) |
| **typst-preview.nvim** | Live browser preview for Typst (`<leader>mp`, needs `tinymist`; LSP `tinymist`, formatter `typstyle`) |
| **nvim-surround** | Surround text with brackets, quotes, tags, etc. |

## Editor Settings

- **Indentation**: 4 spaces (tabs expanded)
- **Word wrap**: Enabled with line break
- **Cursor line**: Full line + number highlight

## Rust

- **LSP**: rust-analyzer with clippy on save and auto-import organization
- **Formatter**: rustfmt (format on save via conform.nvim)
- **Indentation**: Uses treesitter-based indentation (`after/indent/rust.lua`) instead of the built-in cindent. The default `indent/rust.vim` falls back to `cindent`, which is a C indenter and misindents code after Rust structs (no trailing `;` like C requires), causing wrong indentation in subsequent `impl` blocks.
- Config: `configs/rust.lua`

## Go

- **LSP**: gopls with staticcheck and gofumpt enabled
- **Auto-import**: Organizes imports automatically on save
- Config: `configs/go.lua`

## Kotlin

- **LSP**: kotlin-language-server (diagnostics, completion, go-to-definition)
- **Formatter / Linter**: ktlint (format on save via conform.nvim, style checking)
- Config: `configs/kotlin.lua`

## Python

- **LSP**: pyright with automatic venv detection (looks for `.venv` in project root)
- **Formatter**: ruff (format on save via conform.nvim)
- Config: `configs/python.lua`
- **Install**: `pyright` and `ruff` are installed via `uv tool install` by
  `install-packages.sh`. Both must be on `PATH` or nvim silently no-ops on
  diagnostics and format-on-save.

## Surround (nvim-surround)

| Key | Action |
|-----|--------|
| `ys{motion}{char}` | Add surround (e.g. `ysiw"` wraps word in quotes) |
| `ds{char}` | Delete surround (e.g. `ds"` removes quotes) |
| `cs{old}{new}` | Change surround (e.g. `cs"'` changes `"` to `'`) |
| `S{char}` | Surround selection (visual mode) |

## File Explorer

nvim-tree opens automatically on startup and can be toggled with `Space + e`.

## Markdown → Typst

Markdown is rendered through Typst, never LaTeX: `pandoc -d paper` (defaults in
`configs/pandoc/paper.yaml`, math filter `typst-math.lua`) turns the buffer into a
hidden `.name.preview.typ`, previewed with `tinymist`. `$...$` is **Typst math**
(`a_(i j)`, `times`, `sum_(k = 1)^m`).

| Key (markdown buffer) | Action |
|---|---|
| `<leader>mp` | live preview in a new browser window, updates as you type; compile errors show as a warning |
| `<leader>mt` | live preview as a buffer in a vertical split (listed in the tabufline like any file); redraws as you type and jumps to the page of the text you are editing; press again to close it, or to re-show it if hidden. Page keys as in PDFs below |
| `<leader>me` | export `name.pdf` next to the note |

Framed blocks use pandoc fenced divs (`typst-boxes.lua`): `::: box` ... `:::` draws a bordered square
(`::: {.box title="Definición"}` adds a bold title), `::: nota` a shaded block with a left bar. Math,
lists, etc. work inside.

Raw Typst goes in a ```` ```{=typst} ```` block. Math and those blocks are tinted in the buffer.

## PDFs

Inside kitty (with `tdf` installed) opening a `*.pdf` (`nvim file.pdf`, `:e`, the file tree) launches
[`tdf`](https://github.com/itsjunetime/tdf) in a kitty split to the right of nvim
(`lua/tdfview.lua`, via `kitten @ launch`; kitty remote control and the `splits` layout are set in
`kitty/kitty.conf`). tdf does the rendering, search and page keys itself (`?` inside it lists them);
it reloads whenever the file changes. The split is closed when nvim exits. Opening a PDF that is
already shown just focuses its split.

The `<leader>mt` Markdown preview works the same way: the note is compiled to a hidden PDF as you type
and tdf shows it (the split opens without taking focus; press `<leader>mt` again to close it, or to
reopen it if you closed it with `q`). tdf has no way to be told where to go, so nvim reads its page
counter and types `g<page>` into it: after each render and a moment after the cursor moves, tdf is
taken to the page holding the text around the cursor (page precision only, matched by text).

Outside kitty, or without `tdf`, PDFs fall back to a built-in viewer in an ordinary buffer
(`lua/pdfview.lua`).

### Built-in viewer (fallback)

Opening a `*.pdf` (`nvim file.pdf`, `:e`, the file tree) shows it in a normal buffer
(`lua/pdfview.lua`): the whole document is one vertical strip, scrolled smoothly (pages follow one
another with a small gap). Each frame is the visible slice: `pdftoppm` renders only the cropped part
of every page in view, `magick` stacks them, and `snacks.nvim`'s image module draws the result (kitty
graphics protocol, needs `imagemagick`/`poppler`). It lives in the tabufline, opens in the window
the file tree targets and reloads when the file changes.
Keys: `k`/`<Down>`/scroll wheel scroll down, `j`/`<Up>` up (a tenth of the window),
`<PageDown>`/`<C-f>` and `<PageUp>`/`<C-b>` a screen, `<C-d>`/`<C-u>` half a screen,
`gg`/`G` top/bottom, `+`/`-`/`<C-ScrollWheel>` zoom around the middle of the window (scrolling keeps
working at that size), `0` fit width, `h`/`l`/arrows left-right pan while zoomed, `q` close.
The page in the middle of the window (and zoom) is in the window bar. In the `<leader>mt` preview
the view only jumps when the text you edit is on another page.

Search and links (also in the `<leader>mt` preview): `/` searches the text (case-insensitive,
`pdftotext -bbox`), highlights every hit on the page, `n`/`N` next/previous hit, `<Esc>` clears;
the window bar shows `/query 3/12`. Internal links (index, cross-references) and URLs are read
with `qpdf --json`: click one with the mouse, or `f` to pick from the links on the page; `<C-o>`
or `<BS>` returns to where you were. Markdown anchors work as in pandoc: `[Intro](#intro)` points
at the heading `# Intro`.
