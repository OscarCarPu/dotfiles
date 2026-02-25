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
| **conform.nvim** | Code formatting (stylua for Lua) |
| **nvim-lspconfig** | LSP support (HTML, CSS, Go) |
| **nvim-treesitter** | Syntax highlighting (vim, lua, vimdoc, html, css, go) |

## Editor Settings

- **Indentation**: 4 spaces (tabs expanded)
- **Word wrap**: Enabled with line break
- **Cursor line**: Full line + number highlight

## Go

- **LSP**: gopls with staticcheck and gofumpt enabled
- **Auto-import**: Organizes imports automatically on save
- Config: `configs/go.lua`

## Kotlin

- **LSP**: kotlin-language-server (diagnostics, completion, go-to-definition)
- **Formatter / Linter**: ktlint (format on save via conform.nvim, style checking)
- Config: `configs/kotlin.lua`

## File Explorer

nvim-tree opens automatically on startup and can be toggled with `Space + e`.
