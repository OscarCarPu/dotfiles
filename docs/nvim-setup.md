# Neovim Setup Guide

## Python Autocompletion

Python autocompletion is now enabled with:
- **LSP**: Pyright (automatically installed via Mason)
- **Formatter**: Black
- **Linter**: Ruff-LSP
- **Debugger**: debugpy (DAP support)

### First Launch

When you first open a Python file, LazyVim will automatically:
1. Install the Python language server (pyright)
2. Install formatters and linters (black, ruff-lsp)
3. Set up treesitter for Python syntax highlighting

### Features

- Intelligent code completion as you type
- Type checking and error detection
- Auto-imports
- Hover documentation (press `K` over a symbol)
- Go to definition (press `gd`)
- Find references (press `gr`)
- Code formatting (press `<leader>cf`)

## GitHub Copilot AI Autocompletion

AI-powered code suggestions using GitHub Copilot.

### Setup

1. **GitHub Copilot Subscription**:
   - You need an active GitHub Copilot subscription
   - Visit https://github.com/features/copilot
   - Sign up for individual ($10/month) or get it through GitHub Pro/Enterprise
   - Students can get it free through GitHub Student Developer Pack

2. **Install Node.js** (required, version >18.x):
   ```bash
   sudo pacman -S nodejs npm
   node --version  # Verify it's v18 or higher
   ```

3. **Launch Neovim**:
   The first time you open Neovim:
   - Copilot will be automatically installed by Lazy.nvim
   - Run `:Copilot auth` to authenticate
   - Follow the browser prompt to authorize with your GitHub account
   - You'll get a code to enter - copy it and paste in the browser

**Note**: Copilot is **disabled by default**. To enable it, run `:Copilot enable` in Neovim.

### Usage

**Inline Suggestions** (automatic):
- Suggestions appear automatically as you type in insert mode
- Ghost text will show the suggestion in gray
- Accept suggestion: `Alt+l` or `<M-l>`
- Next suggestion: `Alt+]` or `<M-]>`
- Previous suggestion: `Alt+[` or `<M-[>`
- Dismiss: `Ctrl+]`

**Copilot Panel** (multiple suggestions):
- Open panel: `Alt+Enter` or `<M-CR>`
- Navigate: `[[` (previous) and `]]` (next)
- Accept: `Enter`
- Refresh suggestions: `gr`

**Commands**:
- `:Copilot status` - Check connection status
- `:Copilot auth` - Authenticate with GitHub
- `:Copilot enable` - Enable Copilot
- `:Copilot disable` - Disable Copilot
- `:Copilot panel` - Open suggestions panel

### Key Mappings

| Key | Mode | Action |
|-----|------|--------|
| `Alt+l` | Insert | Accept Copilot suggestion |
| `Alt+]` | Insert | Next suggestion |
| `Alt+[` | Insert | Previous suggestion |
| `Ctrl+]` | Insert | Dismiss suggestion |
| `Alt+Enter` | Insert | Open Copilot panel |
| `]]` | Panel | Jump to next suggestion |
| `[[` | Panel | Jump to previous suggestion |
| `Enter` | Panel | Accept suggestion |
| `gr` | Panel | Refresh suggestions |

### Troubleshooting

**Authentication issues**:
- Run `:Copilot auth` again
- Check `:Copilot status` for connection info
- Verify your GitHub account has active Copilot subscription
- Try `:Copilot disable` then `:Copilot enable`

**Node.js version too old**:
- Copilot requires Node.js v18 or higher
- Update with: `sudo pacman -S nodejs`
- Verify: `node --version`

**Suggestions not appearing**:
- Check `:Copilot status` - should show "Ready"
- Check for error messages with `:messages`
- Ensure you're in insert mode
- Some filetypes are disabled (markdown, yaml, gitcommit)
- Try toggling: `:Copilot disable` then `:Copilot enable`

**Copilot with blink.cmp**:
- LazyVim uses blink.cmp (not nvim-cmp) as the default completion engine
- Copilot runs standalone with inline ghost text suggestions
- blink.cmp handles LSP completions (Pyright for Python)
- Both work together seamlessly without conflicts

## Dependencies

Ensure these packages are installed:

```bash
# Required for GitHub Copilot
sudo pacman -S nodejs npm

# Optional but recommended for Python development
sudo pacman -S python-pip python-virtualenv
```

## Configuration Customizations

This setup includes the following customizations from default LazyVim:

1. **Line Wrapping**: Enabled by default with smart word-boundary breaks
2. **Smart Quote Auto-pairing** (optimized for Python docstrings):
   - First quote `"` → auto-pairs to `""|` (cursor in middle)
   - Second quote `"` → moves cursor past closing quote to get `""`
   - Third quote `"` → just types `"` without pairing (perfect for Python docstrings)
   - Same behavior for `'` and `` ` ``
   - Brackets `()`, `[]`, `{}` always auto-pair normally

   Example for Python docstring:
   ```python
   def foo():
       """         # Type 3 quotes, no auto-pair on the third!
       Docstring   # Now you can type without having to delete extra quotes
       """         # Just type 3 more quotes to close
   ```
3. **Copilot Disabled by Default**: Run `:Copilot enable` when you want to use it
4. **Tab Size**: Set to 4 spaces (not 2)

## Tips

1. **Python Virtual Environments**: Pyright automatically detects virtualenvs in your project
2. **Code Actions**: Press `<leader>ca` to see available code actions
3. **Diagnostics**: Press `<leader>cd` to see all diagnostics in the current file
4. **Format on Save**: Enabled by default for Python files
5. **Copilot Context**: Copilot learns from your current file and open buffers - keep relevant files open for better suggestions
6. **Comment-Driven Development**: Write a comment describing what you want, then press Enter - Copilot often generates the code
7. **Two Completion Systems**: blink.cmp (LSP/snippets) and Copilot (AI suggestions) work independently - press Tab for completions, Alt+l for Copilot
8. **Enable/Disable Copilot**: `:Copilot enable` or `:Copilot disable` to toggle AI suggestions
