# Neovim Python Kickstart Cheatsheet

This is the quick-reference source for this config.

## Assistant Lookup Preference
- For plugin/mapping questions, use this file first.
- Prefer this cheatsheet over scanning long config files unless details are missing or stale.
- If a keymap/plugin behavior is not documented here, then read `kickstart-python.lua`.

## General Mappings
- `<leader>` = `,`
- `<localleader>` = `;`
- `%%` (command line): expands to the current file's directory, e.g. `:e %%<Tab>`

## Startup
- `.nvim_session.vim` in the working directory is sourced automatically on startup.
- `.nvim.lua` in the working directory is run as local config on startup.

## Clipboard
- `clipboard` option: `unnamedplus` (uses system clipboard register `+`)
- `<leader>y` (normal/visual): yank to system clipboard
- `<leader>Y` (normal): yank current line to system clipboard

## Config-Level Commands and Mappings
- `<leader>settings`: type `:e .../kickstart-python.lua` on the command line (press Enter to open)
- `<leader>load`: type `:Lazy sync` on the command line (press Enter to run)
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

## Hotkeys and Commands by Plugin

### Mason / LSP / Completion
- `mason-tool-installer.nvim`
  - Ensures: `pyright`, `ruff`, `debugpy`, `taplo`, `lemminx` (XML, e.g. `pom.xml`), `jdtls`, `java-debug-adapter`, `java-test`.
- `nvim-lspconfig`
  - `gd`: goto definition
  - `gr`: goto references
  - `<leader>c`: code action
  - `<leader>e`: show the complete diagnostic under the cursor
  - `<C-f>`: format file
- `nvim-jdtls` (Java files)
  - Requires Java 21 or newer to run the language server; projects may target older Java versions.
  - Recognizes Maven, Gradle, Ant, wrapper, and Git project roots.
  - Started by nvim-jdtls only; `mason-lspconfig` is told not to start jdtls a second time.
  - Completion can insert imports for types already on the project classpath.
  - `<leader>c`: choose an `Add import` quick fix for an unresolved type.
  - Runs with the Lombok agent, so Lombok-generated methods resolve.
  - Maven dependency sources are downloaded for goto definition.
  - Asks before reloading the project when a build file changes.
  - `<leader>co`: organize, add, remove, and sort imports in the current Java file.
  - `<leader>jv` (normal/visual): extract variable
  - `<leader>jc` (normal/visual): extract constant
  - `<leader>jm` (visual): extract method
  - `<leader>ju`: reload the project config (`:JdtUpdateConfig`)
  - `:JdtUpdateDebugConfig`: refresh the debug launch configurations for main classes.
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
  - Highlighting is started for every filetype with an installed parser. Treesitter indent is not enabled.
  - Parsers ensured: `python`, `java`, `toml`, `rst`, `ninja`, `yaml`, `xml`, `properties`, `sql`, `json`, `markdown`, `markdown_inline`.
  - Installing parsers requires the `tree-sitter` CLI and a C compiler.
- `tokyonight.nvim`
  - Auto-loaded as colorscheme.

### Debugging
- `nvim-dap`
  - `<leader>dc`: continue/start debugger
  - `<leader>db`: toggle breakpoint
  - `<leader>dt`: terminate debugger
  - `<leader>dn` / `<leader>di` / `<leader>do`: step over / into / out
- `nvim-dap-ui`
  - `<leader>du`: toggle DAP UI
  - `<leader>de` (normal/visual): evaluate the expression under the cursor or the selection
  - UI auto-opens on start and closes on terminate/exit.
- `nvim-dap-python`
  - Uses Mason `debugpy` interpreter path.
- Java (through `nvim-jdtls`)
  - `<leader>dc` in a Java project offers a launch configuration for each main class.
  - Hot code replace is applied automatically on save during a debug session.
  - `<leader>jt`: debug the test method under the cursor
  - `<leader>jT`: debug the current test class

### Testing
- `neotest` (`neotest-python` with pytest, `neotest-java` with Maven/Gradle)
  - `<leader>tn`: run the test under the cursor
  - `<leader>tc`: run the current test class/file
  - `<leader>ta`: run all tests
  - `<leader>ts`: toggle the test summary
  - The summary opens on the left after each run.
  - `:NeotestJava setup`: download the JUnit runner that `neotest-java` needs (once).

### Editing / Python Helpers
- `neogen`
  - `<leader>a`: generate docstring
- `nvim-puppeteer`
  - Auto f-string conversion behavior in Python strings.
- Python buffers
  - 4-space indent, indent-based folds.
  - Insert-mode abbreviations: `true` -> `True`, `false` -> `False`, `null`/`none`/`nil` -> `None`, `--` -> `#`, `function` -> `def`.

### Java Helpers
- Java buffers use a 4-space indent unless the project's `.editorconfig` sets otherwise.

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
  - Command-line abbreviations:
    - `diff` -> `Git diff`
    - `stat` -> `Git status`
    - `com` -> `Git commit`
    - `add` -> `Git add`
    - `adda` -> `Git add -A`
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
  - `<localleader>r`: open the rules picker in the current or a new chat
  - Command-line abbreviations:
    - `cc` -> `CodeCompanion`
    - `ccc` -> `CodeCompanionChat`
    - `bu` -> `#{buffer}`
    - `ch` -> `#{chat}`
    - `cl` -> `#{clipboard}`
    - `ag` -> `@{agent}`
    - `fi` -> `@{files}`
