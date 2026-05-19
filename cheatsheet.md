# Neovim Python Kickstart Cheatsheet

A summary of plugins, their roles, and main hotkeys/config for this setup.

## General Mappings
- `<leader>` = `,`
- `<localleader>` = `;`

---

## Plugin List & Key Hotkeys

### Tooling: LSP, Formatting, Linters
- **mason-tool-installer.nvim**
  - Bootstraps external tools: pyright (LSP), ruff (lint/format), debugpy (debugger), taplo (TOML LSP).

- **nvim-lspconfig**
  - Sets up LSPs (pyright, taplo, ruff)
  - `gd`: goto definition
  - `gr`: goto references
  - `<leader>c`: code action
  - `<C-f>`: format file

- **blink.cmp**
  - Completion engine (Rust-powered, requires v0.* release)

---

### Python REPL
- **iron.nvim**
  - Toggle Python REPL: `<leader>i`
  - Restart REPL: `<leader>I`
  - Send selection: `+` (operator, visual)
  - Send line: `++`

---

### Syntax Highlighting & Color
- **nvim-treesitter**
  - Modern syntax highlighting (auto-installs Python, TOML, etc.)

- **tokyonight.nvim**
  - Colorscheme (auto-loaded at startup)

---

### Debugging
- **nvim-dap**
  - Start/Continue: `<leader>dc`
  - Add Breakpoint: `<leader>db`
  - Terminate: `<leader>dt`

- **nvim-dap-ui**
  - Toggle DAP UI: `<leader>du`
  - UI auto-opens/closes with debugger

- **nvim-dap-python**
  - Python debugpy integration (auto-used from Mason install)

---

### Editing & Utilities
- **neogen**
  - Generate Python docstrings: `<leader>a`

- **nvim-puppeteer**
  - f-string auto-conversion in Python

---

### Writing/Docs/LaTeX
- **vimtex**
  - Only for LaTeX (`*.tex`)
  - PDF view: zathura

---

### Git
- **gitsigns.nvim**
  - Next hunk: `]c`
  - Prev hunk: `[c`
  - Stage hunk: `<leader>gs`
  - Reset hunk: `<leader>gr`
  - Preview hunk: `<leader>gp`
  - Blame line: `<leader>gb`

---

### Diffs & Builds
- **diffview.nvim**
  - Git diff UI (no default hotkey)

- **overseer.nvim**
  - Task runner. Run with `:Make`

---

### AI
- **codecompanion.nvim**
  - Action menu: `<C-a>`
  - Open/Toggle chat: `<localleader>a`
  - Add chat: Visual + `ga`

---

## Config Edit
- Edit config: `<leader>settings`
- Reload/sync plugins: `<leader>load`
