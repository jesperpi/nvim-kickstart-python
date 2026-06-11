# Neovim Python Kickstart Cheatsheet

This is the quick-reference source for this config.

## Assistant Lookup Preference
- For plugin/mapping questions, use this file first.
- Prefer this cheatsheet over scanning long config files unless details are missing or stale.
- If a keymap/plugin behavior is not documented here, then read `kickstart-python.lua`.

## General Mappings
- `<leader>` = `,`
- `<localleader>` = `;`

## Clipboard
- `clipboard` option: `unnamedplus` (uses system clipboard register `+`)
- `<leader>y` (normal/visual): yank to system clipboard
- `<leader>Y` (normal): yank current line to system clipboard

## Config-Level Commands and Mappings
- `<leader>settings`: edit `kickstart-python.lua`
- `<leader>load`: run `:Lazy sync`
- `<leader>?`: run `:NvimTips` (CodeCompanion prompt with this cheatsheet context)
- `:NvimTips`: ask for Neovim tips using this file as context

## File Picker
- `<leader>f`: select from the most recent non-empty file picker tab-completion filter for the current directory.
- `<leader>fii`: command-line image file picker.
- `<leader>fpi`: command-line Python file picker.
- `<leader>fgi`: command-line Git-changed file picker.
- `:FilePickerPrevious`: select from the most recent non-empty file picker tab-completion filter.
- `:FilePickerSelect [all|image|python|git]`: select from a cached picker set.
- `:F`, `:Fp`, `:Fi`, `:Fg`: open all, Python, image, or Git-changed files with command-line completion.
- `:f`, `:fp`, `:fi`, `:fg`: command-line shorthands for `:F`, `:Fp`, `:Fi`, and `:Fg`.
- Non-git picker scans are breadth-first, skip common cache/build/vendor directories, and stop at depth 6, 20,000 matches, 50,000 filesystem entries, or 4,000 directories.

## Installed Plugins (Declared)
- `folke/lazy.nvim` (bootstrapped plugin manager)
- `WhoIsSethDaniel/mason-tool-installer.nvim`
- `williamboman/mason.nvim`
- `williamboman/mason-lspconfig.nvim`
- `neovim/nvim-lspconfig`
- `saghen/blink.cmp`
- `Vigemus/iron.nvim`
- `akinsho/toggleterm.nvim`
- `nvim-treesitter/nvim-treesitter`
- `folke/tokyonight.nvim`
- `mfussenegger/nvim-dap`
- `rcarriga/nvim-dap-ui`
- `nvim-neotest/nvim-nio`
- `mfussenegger/nvim-dap-python`
- `danymat/neogen`
- `chrisgrieser/nvim-puppeteer`
- `lervag/vimtex`
- `sindrets/diffview.nvim`
- `nvim-lua/plenary.nvim`
- `tpope/vim-fugitive`
- `stevearc/overseer.nvim`
- `olimorris/codecompanion.nvim`
- `lewis6991/gitsigns.nvim`

## Hotkeys and Commands by Plugin

### Mason / LSP / Completion
- `mason-tool-installer.nvim`
  - Ensures: `pyright`, `ruff`, `debugpy`, `taplo`.
- `nvim-lspconfig`
  - `gd`: goto definition
  - `gr`: goto references
  - `<leader>c`: code action
  - `<C-f>`: format file
- `blink.cmp` (`keymap.preset = "default"`)
  - Common defaults include completion accept/select/navigation keys from Blink's default preset.
  - If behavior differs, check current Blink docs for exact default mapping set.

### REPL
- `iron.nvim`
  - `<leader>i`: toggle REPL
  - `<leader>I`: restart REPL
  - `+` (normal/visual): send motion/selection to REPL
  - `++`: send current line

### Terminal
- `toggleterm.nvim`
  - `<leader>tt`: toggle persistent floating terminal
  - `<Esc><Esc>` (terminal mode): exit terminal mode to normal mode

### Syntax / Theme
- `nvim-treesitter`
  - Plugin setup module: `nvim-treesitter` (not `nvim-treesitter.configs` in newer versions).
  - Highlight + indent enabled.
  - Parsers ensured: `python`, `toml`, `rst`, `ninja`, `yaml`, `markdown`, `markdown_inline`.
- `tokyonight.nvim`
  - Auto-loaded as colorscheme.

### Debugging
- `nvim-dap`
  - `<leader>dc`: continue/start debugger
  - `<leader>db`: toggle breakpoint
  - `<leader>dt`: terminate debugger
- `nvim-dap-ui`
  - `<leader>du`: toggle DAP UI
  - UI auto-opens on start and closes on terminate/exit.
- `nvim-dap-python`
  - Uses Mason `debugpy` interpreter path.

### Editing / Python Helpers
- `neogen`
  - `<leader>a`: generate docstring
- `nvim-puppeteer`
  - Auto f-string conversion behavior in Python strings.

### LaTeX
- `vimtex` (loaded for `tex` filetype)
  - Configured compiler: `make4ht` through VimTeX's generic compiler
  - HTML output directory: `build/`
  - Standard VimTeX mappings to remember:
    - `\ll`: build output file
    - `\lv`: view generated output file
    - `\lh`: view generated file (html only)
    - `\lk`: stop compilation
    - `\lc`: clean aux files

### Git / Diffs / Tasks
- `gitsigns.nvim`
  - `]c`: next hunk
  - `[c`: previous hunk
  - `<leader>gs`: stage hunk
  - `<leader>gr`: reset hunk
  - `<leader>gp`: preview hunk
  - `<leader>gb`: blame line
- `diffview.nvim`
  - No custom keymaps set here.
  - Standard commands:
    - `:DiffviewOpen`
    - `:DiffviewFileHistory`
    - `:DiffviewClose`
- `vim-fugitive`
  - Main command: `:Git ...` (runs Git from inside Neovim)
  - Basic workflow:
    - `:Git status`
    - `:Git add %`
    - `:Git commit`
    - `:Git push`
  - Rebase basics:
    - `:Git rebase -i HEAD~3`
    - `:Git rebase --continue`
    - `:Git rebase --abort`
- `overseer.nvim`
  - `:Make`: run `makeprg` as Overseer task (custom user command in this config)
  - Common Overseer commands:
    - `:OverseerRun`
    - `:OverseerToggle`
    - `:OverseerTaskAction`
    - `:OverseerQuickAction`

### AI Assistant
- `codecompanion.nvim`
  - `<C-a>`: `CodeCompanionActions`
  - `<localleader>a`: `CodeCompanionChat Toggle`
  - Visual `ga`: `CodeCompanionChat Add`
  - Command-line abbreviations:
    - `cc` -> `CodeCompanion`
    - `ccc` -> `CodeCompanionChat`
    - `bu` -> `#{buffer}`
    - `ch` -> `#{chat}`
    - `cl` -> `#{clipboard}`
    - `ag` -> `@{agent}`
    - `fi` -> `@{files}`
