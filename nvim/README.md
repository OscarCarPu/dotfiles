**This repo is supposed to be used as config by NvChad users!**

- The main nvchad repo (NvChad/NvChad) is used as a plugin by this repo.
- So you just import its modules , like `require "nvchad.options" , require "nvchad.mappings"`
- So you can delete the .git from this repo ( when you clone it locally ) or fork it :)

# File Explorer

nvim-tree is configured to show gitignored files by default (`git.ignore = false`).

# Formatting

Format-on-save is enabled via [conform.nvim](https://github.com/stevearc/conform.nvim) with a 500ms timeout and LSP fallback.

| Language | Formatters          |
|----------|---------------------|
| Lua      | stylua              |
| Go       | gofumpt, goimports  |
| Rust     | rustfmt             |

Go files also auto-organize imports on save via a `BufWritePre` autocmd in `lua/configs/go.lua`.

# Rust

Rust support is configured via:

- **LSP**: `rust-analyzer` with clippy check-on-save, auto-imports grouped by module (`lua/configs/rust.lua`)
- **Formatting**: `rustfmt` via conform.nvim (format-on-save)
- **Auto-import**: organizes imports on save via a `BufWritePre` autocmd in `lua/configs/rust.lua`
- **Crate versions**: [crates.nvim](https://github.com/saecki/crates.nvim) shows dependency versions inline when editing `Cargo.toml`
- **Treesitter**: `rust` and `toml` parsers for syntax highlighting

# Android / Java / Kotlin

Android development support is configured via:

- **Android plugin**: [android-nvim-plugin](https://github.com/iamironz/android-nvim-plugin) for building, running, and viewing Logcat directly in Nvim (loads on `kotlin`, `java`, `xml` files)
- **Java LSP**: [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) for enhanced jdtls support (auto-attaches on `java` files via `lua/configs/java.lua`)
- **Kotlin LSP**: `kotlin-language-server` installed via Mason, configured in `lua/configs/kotlin.lua` (JVM target 17)
- **XML LSP**: `lemminx` installed via Mason, configured in `lua/configs/xml.lua` (validation enabled)
- **Treesitter**: `kotlin`, `java`, and `xml` parsers for syntax highlighting

Mason automatically installs `kotlin-language-server` and `lemminx` on first launch.

# Credits

1) Lazyvim starter https://github.com/LazyVim/starter as nvchad's starter was inspired by Lazyvim's . It made a lot of things easier!
