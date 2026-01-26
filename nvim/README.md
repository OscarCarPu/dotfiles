[&#11013; Back to main README](../README.md)

# Neovim configuration

Customized [LazyVim](https://github.com/LazyVim/LazyVim) configuration for Neovim.

# Structure

- 'after/ftplugin': Per-filetype configuration
- 'lua/config': Global configuration
- 'lua/plugins': Plugins

# Plugins

- [ai.lua](lua/plugins/ai.lua): AI-powered code completion with [Supermaven](https://github.com/supermaven-inc/supermaven-nvim)
- [codeforces.lua](lua/plugins/codeforces.lua): Competitive programming integration with [assistant.nvim](https://github.com/A7lavinraj/assistant.nvim)
- [cpp.lua](lua/plugins/cpp.lua): C++ Language Support
- [editor.lua](lua/plugins/editor.lua): Diagnostic and file explorer behaviours
- [json.lua](lua/plugins/json.lua): JSON formatting configuration
- [python.lua](lua/plugins/python.lua): Python Language Support
- [run.lua](lua/plugins/run.lua): Custom :Run command for executing Rust and Python files
- [rust.lua](lua/plugins/rust.lua): Rust Language Support

# Custome Features 

## Codeforces

- Codeforces integration with [assistant.nvim](https://github.com/A7lavinraj/assistant.nvim)
- Assistant.nvim configuration
    1. Press `<leader>a` to open Assistant.nvim
    2. Run with `r`

## Run 

- Custom :Run command for executing Rust and Python files
    - Rust: execute cargo or cargo --bin, and rustc if no bin
    - Python: execute python having venv or system python

## Rust

- Rust Language Support
- Rust formatter with [conform.nvim](https://github.com/stevearc/conform.nvim)

## Python

- Python Language Support
- Ruff formatter and linter with [conform.nvim](https://github.com/stevearc/conform.nvim)
- Ruff linter with [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)

## C++

- C++ Language Support
- Clang-format formatter with [conform.nvim](https://github.com/stevearc/conform.nvim)

# Configuration

- [autocmds.lua](lua/config/autocmds.lua): Autocmds
- [lazy.lua](lua/config/lazy.lua): LazyVim configuration
- [options.lua](lua/config/options.lua): Options
