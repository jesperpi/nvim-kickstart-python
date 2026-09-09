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
- `<leader>h`: open this cheatsheet in a floating window
- `<leader>?`: run `:NvimTips` (CodeCompanion prompt with this cheatsheet context)
- `:Cheatsheet`: open this cheatsheet in a floating window
- `:NvimTips`: ask for Neovim tips using this file as context

## Project Picker
- Requires the external `fzf` binary.
- `<leader>ff`: find Git-tracked project files.
- `<leader>fF`: find files under the current working directory.
- `<leader>fs`: live grep project text.
- `<leader>fb`: find open buffers.
- `<leader>fr`: find recently opened files.
- `<leader>fR`: resume the previous picker.
- `<leader>fc`: find and run Vim commands.
- `:FzfLua`: run any fzf-lua picker by name, e.g. `:FzfLua live_grep`.

## Installed Plugins (Declared)
- `folke/lazy.nvim` (bootstrapped plugin manager)
- `WhoIsSethDaniel/mason-tool-installer.nvim`
- `williamboman/mason.nvim`
- `williamboman/mason-lspconfig.nvim`
- `neovim/nvim-lspconfig`
- `mfussenegger/nvim-jdtls`
- `saghen/blink.cmp`
- `ibhagwan/fzf-lua`
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
- `quarto-dev/quarto-nvim`
- `jmbuhr/otter.nvim`
- `sindrets/diffview.nvim`
- `nvim-lua/plenary.nvim`
- `tpope/vim-fugitive`
- `stevearc/overseer.nvim`
- `olimorris/codecompanion.nvim`
- `lewis6991/gitsigns.nvim`

## Hotkeys and Commands by Plugin

### Mason / LSP / Completion
- `mason-tool-installer.nvim`
  - Ensures: `pyright`, `ruff`, `debugpy`, `taplo`, `jdtls`.
- `nvim-lspconfig`
  - `gd`: goto definition
  - `gr`: goto references
  - `<leader>c`: code action
  - `<C-f>`: format file
- `nvim-jdtls` (Java files)
  - Requires Java 21 or newer to run the language server; projects may target older Java versions.
  - Recognizes Maven, Gradle, Ant, wrapper, and Git project roots.
  - Completion can insert imports for types already on the project classpath.
  - `<leader>c`: choose an `Add import` quick fix for an unresolved type.
  - `<leader>co`: organize, add, remove, and sort imports in the current Java file.
  - `<leader>ja`: ask CodeCompanion to infer missing imports/dependencies, edit Maven or Gradle files, and compile with the project wrapper.
  - `:JdtUpdateConfig`: reload the Java project after a build-file change if it is not detected automatically.
  - Java debug and test bundles are intentionally not installed.
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
  - Parsers ensured: `python`, `java`, `toml`, `rst`, `ninja`, `yaml`, `markdown`, `markdown_inline`.
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
  - Local leader for LaTeX mappings is `;`.
  - `;ll`: build HTML output with VimTeX / `make4ht`
  - `;lh`: view generated HTML output
  - `;lv`: build and view PDF output with `latexmk`
  - `;lk`: stop compilation
  - `;lc`: clean aux files

### Quarto
- `quarto-nvim` (loaded for `quarto` filetype / `*.qmd`)
  - Embedded Python support uses `otter.nvim` for LSP-style completion/diagnostics in code chunks.
  - Code execution uses the existing `iron.nvim` REPL runner.
  - HTML rendering command writes generated output under `out/` next to the `.qmd` file.
  - `:QuartoRenderHtml`: render current `.qmd` to HTML in `out/`
  - `:QuartoViewHtml`: open `out/<current-file>.html`
  - `<localleader>qp`: preview current Quarto document
  - `<localleader>rh`: render current Quarto document to HTML
  - `<localleader>vh`: view rendered HTML output
  - `<localleader>rc`: run current code cell
  - `<localleader>ra`: run current cell and cells above
  - `<localleader>rA`: run all cells matching the current cell language
  - `<localleader>rl`: run current line
  - Visual `<localleader>r`: run selected code

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
  - `<leader>ja` (Java buffers): run the `javafix` prompt for imports and Maven/Gradle dependencies.
  - `/javafix` (chat): run the same Java import/dependency workflow.
  - Command-line abbreviations:
    - `cc` -> `CodeCompanion`
    - `ccc` -> `CodeCompanionChat`
    - `bu` -> `#{buffer}`
    - `ch` -> `#{chat}`
    - `cl` -> `#{clipboard}`
    - `ag` -> `@{agent}`
    - `fi` -> `@{files}`
