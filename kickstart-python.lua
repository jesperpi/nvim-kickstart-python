_G.KICKSTART_PROJECT_DIR = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
package.path = table.concat({
	_G.KICKSTART_PROJECT_DIR .. "/lua/?.lua",
	_G.KICKSTART_PROJECT_DIR .. "/lua/?/init.lua",
	package.path,
}, ";")

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.wildmode = "longest:full,full"
vim.opt.wildoptions = "pum,fuzzy"
vim.opt.wildignorecase = true

-- In command-line mode, typing `%%` expands to the current buffer's directory.
-- This makes `:e %%<Tab>` complete files next to the file you are editing.
vim.cmd([[cnoremap <expr> %% getcmdtype() == ":" ? expand("%:h") .. "/" : "%%"]])

-- BOOTSTRAP the plugin manager `lazy.nvim` https://lazy.folke.io/installation
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local lazyLocallyAvailable = vim.uv.fs_stat(lazypath) ~= nil
if not lazyLocallyAvailable then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath }):wait()
	if out.code ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

--------------------------------------------------------------------------------

-- define what key is used for `<leader>`. Here, we use `,`.
-- (`:help mapleader` for information what the leader key is)
vim.g.mapleader = ","
vim.g.maplocalleader = ";"

local typeset = require("typeset")

local plugins = {
	-- TOOLING: COMPLETION, DIAGNOSTICS, FORMATTING

	-- MASON
	-- * Manager for external tools (LSPs, linters, debuggers, formatters)
	-- * auto-install those external tools
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = {
			{ "williamboman/mason.nvim", opts = true },
			{ "williamboman/mason-lspconfig.nvim", opts = true },
		},
		opts = {
			ensure_installed = {
				"pyright", -- LSP for python
				"ruff", -- linter & formatter (includes flake8, pep8, black, isort, etc.)
				"debugpy", -- debugger
				"taplo", -- LSP for toml (e.g., for pyproject.toml files)
			},
		},
	},

	-- Setup the LSPs
	-- `gd` and `gr` for goto definition / references
	-- `<C-f>` for formatting
	-- `<leader>c` for code actions (organize imports, etc.)
	{
		"neovim/nvim-lspconfig",
		keys = {
			{ "gd", vim.lsp.buf.definition, desc = "Goto Definition" },
			{ "gr", vim.lsp.buf.references, desc = "Goto References" },
			{ "<leader>c", vim.lsp.buf.code_action, desc = "Code Action" },
			{ "<C-f>", vim.lsp.buf.format, desc = "Format File" },
		},
		init = function()
			-- this snippet enables auto-completion
			local lspCapabilities = vim.lsp.protocol.make_client_capabilities()
			lspCapabilities.general.positionEncodings = { "utf-16" }
			lspCapabilities.textDocument.completion.completionItem.snippetSupport = true

			-- setup pyright with completion capabilities
			vim.lsp.config["pyright"] = {
				capabilities = lspCapabilities,
			}
			-- setup taplo with completion capabilities
			vim.lsp.config["taplo"] = {
				capabilities = lspCapabilities,
			}
			-- ruff uses an LSP proxy, therefore it needs to be enabled as if it
			-- were a LSP. In practice, ruff only provides linter-like diagnostics
			-- and some code actions, and is not a full LSP yet.
			vim.lsp.config["ruff"] = {
				-- disable ruff as hover provider to avoid conflicts with pyright
				on_attach = function(client) client.server_capabilities.hoverProvider = false end,
			}

			-- Explicitly enable configured LSP servers.
			-- Without this, keymaps like `gd` work syntactically but no server attaches.
			vim.lsp.enable({ "pyright", "ruff", "taplo" })
		end,
	},

	-- COMPLETION
	{
		"saghen/blink.cmp",
		version = "v0.*", -- blink.cmp requires a release tag for its rust binary
		opts = {
			keymap = { preset = "default" },
		},
	},

	-- PROJECT PICKER
	-- * quick fuzzy access to project files, buffers, recent files, grep, and commands
	{
		"ibhagwan/fzf-lua",
		cmd = "FzfLua",
		keys = {
			{
				"<leader>ff",
				function() require("fzf-lua").git_files() end,
				desc = "Find Git Files",
			},
			{
				"<leader>fF",
				function() require("fzf-lua").files() end,
				desc = "Find Files",
			},
			{
				"<leader>fs",
				function() require("fzf-lua").live_grep() end,
				desc = "Search Project",
			},
			{
				"<leader>fb",
				function() require("fzf-lua").buffers() end,
				desc = "Find Buffers",
			},
			{
				"<leader>fr",
				function() require("fzf-lua").oldfiles() end,
				desc = "Find Recent Files",
			},
			{
				"<leader>fR",
				function() require("fzf-lua").resume() end,
				desc = "Resume Picker",
			},
			{
				"<leader>fc",
				function() require("fzf-lua").commands() end,
				desc = "Find Commands",
			},
		},
		opts = {},
	},
	-----------------------------------------------------------------------------
	-- PYTHON REPL
	-- A basic REPL that opens up as a horizontal split
	-- * use `<leader>i` to toggle the REPL
	-- * use `<leader>I` to restart the REPL
	-- * `+` serves as the "send to REPL" operator. That means we can use `++`
	-- to send the current line to the REPL, and `+j` to send the current and the
	-- following line to the REPL, like we would do with other vim operators.
	{
		"Vigemus/iron.nvim",
		keys = {
			{ "<leader>i", vim.cmd.IronRepl, desc = "󱠤 Toggle REPL" },
			{ "<leader>I", vim.cmd.IronRestart, desc = "󱠤 Restart REPL" },

			-- these keymaps need no right-hand-side, since that is defined by the
			-- plugin config further below
			{ "+", mode = { "n", "x" }, desc = "󱠤 Send-to-REPL Operator" },
			{ "++", desc = "󱠤 Send Line to REPL" },
		},

		-- since irons's setup call is `require("iron.core").setup`, instead of
		-- `require("iron").setup` like other plugins would do, we need to tell
		-- lazy.nvim which module to via the `main` key
		main = "iron.core",

		opts = {
			keymaps = {
				send_line = "++",
				visual_send = "+",
				send_motion = "+",
			},
			config = {
				-- This defines how the repl is opened. Here, we set the REPL window
				-- to open in a horizontal split to the bottom, with a height of 10.
				repl_open_cmd = "horizontal bot 10 split",

				-- This defines which binary to use for the REPL. If `ipython` is
				-- available, it will use `ipython`, otherwise it will use `python3`.
				-- since the python repl does not play well with indents, it's
				-- preferable to use `ipython` or `bypython` here.
				-- (see: https://github.com/Vigemus/iron.nvim/issues/348)
				repl_definition = {
					python = {
						command = function()
							local ipythonAvailable = vim.fn.executable("ipython") == 1
							local binary = ipythonAvailable and "ipython" or "python3"
							return { binary }
						end,
					},
				},
			},
		},
	},

	-----------------------------------------------------------------------------
	-- PERSISTENT TERMINAL
	-- * use `<leader>tt` to toggle a persistent floating terminal
	{
		"akinsho/toggleterm.nvim",
		version = "*",
		cmd = "ToggleTerm",
			keys = {
			{ "<leader>tt", "<cmd>ToggleTerm<CR>", mode = "n", desc = "Toggle Terminal" },
			{ "<leader>tt", [[<C-\><C-n><cmd>ToggleTerm<CR>]], mode = "t", desc = "Toggle Terminal" },
		},
		opts = {
			direction = "float",
			persist_size = true,
			start_in_insert = true,
			insert_mappings = true,
			terminal_mappings = true,
		},
	},

	-----------------------------------------------------------------------------
	-- SYNTAX HIGHLIGHTING & COLORSCHEME

	-- treesitter for syntax highlighting
	-- * auto-installs the parser for python
	{
		"nvim-treesitter/nvim-treesitter",
		-- automatically update the parsers with every new release of treesitter
		build = ":TSUpdate",

		-- use the top-level module so lazy.nvim calls `require("nvim-treesitter").setup`.
		-- newer nvim-treesitter releases moved internals from `configs` to `config`.
		main = "nvim-treesitter",

		opts = {
			highlight = { enable = true }, -- enable treesitter syntax highlighting
			indent = { enable = true }, -- better indentation behavior
			ensure_installed = {
				-- auto-install the Treesitter parser for python and related languages
				"python",
				"toml",
				"rst",
				"ninja",
				"yaml",
				"markdown",
				"markdown_inline",
			},
		},
	},

	-- COLORSCHEME
	-- In neovim, the choice of color schemes is unfortunately not purely
	-- aesthetic – treesitter-based highlighting or newer features like semantic
	-- highlighting are not always supported by a color scheme. It's therefore
	-- recommended to use one of the popular, and actively maintained ones to get
	-- the best syntax highlighting experience:
	-- https://dotfyle.com/neovim/colorscheme/top
	{
		"folke/tokyonight.nvim",
		-- ensure that the color scheme is loaded at the very beginning
		priority = 1000,
		-- enable the colorscheme
		config = function() vim.cmd.colorscheme("tokyonight") end,
	},

	-----------------------------------------------------------------------------
	-- DEBUGGING

	-- DAP Client for nvim
	-- * start the debugger with `<leader>dc`
	-- * add breakpoints with `<leader>db`
	-- * terminate the debugger `<leader>dt`
	{
		"mfussenegger/nvim-dap",
		keys = {
			{
				"<leader>dc",
				function() require("dap").continue() end,
				desc = "Start/Continue Debugger",
			},
			{
				"<leader>db",
				function() require("dap").toggle_breakpoint() end,
				desc = "Add Breakpoint",
			},
			{
				"<leader>dt",
				function() require("dap").terminate() end,
				desc = "Terminate Debugger",
			},
		},
	},

	-- UI for the debugger
	-- * the debugger UI is also automatically opened when starting/stopping the debugger
	-- * toggle debugger UI manually with `<leader>du`
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
		keys = {
			{
				"<leader>du",
				function() require("dapui").toggle() end,
				desc = "Toggle Debugger UI",
			},
		},
		-- automatically open/close the DAP UI when starting/stopping the debugger
		config = function()
			require("dapui").setup()

			local listener = require("dap").listeners
			listener.after.event_initialized["dapui_config"] = function() require("dapui").open() end
			listener.before.event_terminated["dapui_config"] = function() require("dapui").close() end
			listener.before.event_exited["dapui_config"] = function() require("dapui").close() end
		end,
	},

	{
		"mfussenegger/nvim-dap-python",
		dependencies = "mfussenegger/nvim-dap",
		config = function()
			-- Use Mason's debugpy venv python, with a compatibility fallback.
			local mason_path = vim.fn.stdpath("data") .. "/mason"
			local debugpyPythonPath = mason_path .. "/packages/debugpy/venv/bin/python"
			if vim.fn.executable(debugpyPythonPath) == 0 then
				local alt = mason_path .. "/packages/debugpy/venv/bin/python3"
				if vim.fn.executable(alt) == 1 then debugpyPythonPath = alt end
			end

			require("dap-python").setup(debugpyPythonPath, {}) ---@diagnostic disable-line: missing-fields
		end,
	},
	-----------------------------------------------------------------------------
	-- EDITING SUPPORT PLUGINS
	-- some plugins that help with python-specific editing operations

	-- Docstring creation
	-- * quickly create docstrings via `<leader>a`
	{
		"danymat/neogen",
		opts = true,
		keys = {
			{
				"<leader>a",
				function() require("neogen").generate() end,
				desc = "Add Docstring",
			},
		},
	},

	-- f-strings
	-- * auto-convert strings to f-strings when typing `{}` in a string
	-- * also auto-converts f-strings back to regular strings when removing `{}`
	{
		"chrisgrieser/nvim-puppeteer",
		dependencies = "nvim-treesitter/nvim-treesitter",
	},
	{
		"sindrets/diffview.nvim",
		dependencies = "nvim-lua/plenary.nvim",
		config = function()
			require("diffview").setup({
				use_icons = true,
			})
		end,
	},
	{
		"tpope/vim-fugitive",
	},
	{
		"stevearc/overseer.nvim",
		opts = {},
		config = function()
			require("overseer").setup({
				-- You may customize task configs here if you like
			})
			vim.api.nvim_create_user_command("Make", function(params)
				-- Insert args at the '$*' in the makeprg
				local cmd, num_subs = vim.o.makeprg:gsub("%$%*", params.args)
				if num_subs == 0 then cmd = cmd .. " " .. params.args end
				local task = require("overseer").new_task({
					cmd = vim.fn.expandcmd(cmd),
					components = {
						{
							"on_output_quickfix",
							open = not params.bang,
							open_height = 8,
							errorformat = vim.o.errorformat,
						},
						"default",
					},
				})
				task:start()
			end, {
				desc = "Run your makeprg as an Overseer task",
				nargs = "*",
				bang = true,
			})
		end,
	},
	{
		"3rd/image.nvim",
		opts = {
			backend = "kitty",
			processor = "magick_cli",
			integrations = {
				markdown = {
					enabled = false,
				},
			},
			max_width_window_percentage = 90,
			max_height_window_percentage = 90,
		},
	},
	-- AI Coding assistant
	{
		"olimorris/codecompanion.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
		},

		config = function()
			local function find_upward_file(file_name)
				return vim.fs.find(file_name, {
					upward = true,
					path = vim.fn.getcwd(),
					limit = 1,
				})[1]
			end

			require("codecompanion").setup({
				display = {
                                  chat = {
                                    window = {
                                      layout = "buffer",
                                    },
                                  },
                                },
				opts = { log_level = "TRACE" },
				interactions = {
					chat = {
						adapter = "codex",
					},
					inline = {
						adapter = "codex",
					},
					cmd = {
						adapter = "codex",
					},
				},

				adapters = {
					openai = function()
						return require("codecompanion.adapters").extend("openai", {
							schema = {
								model = {
									default = "gpt-5.5",
								},
							},
						})
					end,
					acp = {
						codex = function()
							return require("codecompanion.adapters").extend("codex", {
								commands = {
									default = {
										"npx",
										"@zed-industries/codex-acp",
									},
								},
								defaults = {
									auth_method = "chatgpt",
									session_config_options = {
										model = "gpt-5.5",
									},
								},
							})
						end,
					},
				},

				rules = {
					python_rules = {
						description = "Rules for python projects",
						enabled = function() return find_upward_file("pyproject.toml") ~= nil end,
						files = (function()
							local project_agent = find_upward_file("AGENT-python.md")

							if project_agent then
								return { project_agent } -- only load explicit project rule file
							end

							return { _G.KICKSTART_PROJECT_DIR .. "/AGENT-python.md" } -- fallback
						end)(),
					},

					opts = {
						chat = {
							enabled = true,
							autoload = function()
								if find_upward_file("pyproject.toml") ~= nil then
									return { "default", "python_rules" }
								end
								return "default"
							end,
						},
					},
				},
				prompt_library = {
					["Neovim Tips (Cheatsheet)"] = {
						interaction = "chat",
						description = "Ask for Neovim tips with cheatsheet context",
						opts = {
							is_default = true,
							is_slash_cmd = true,
							alias = "nvimtips",
							auto_submit = true,
							user_prompt = true,
						},
						context = {
							{
								type = "file",
								path = _G.KICKSTART_PROJECT_DIR .. "/cheatsheet.md",
							},
						},
						prompts = {
							{
								role = "system",
								content = "Answer tersely. Prefer concrete Neovim actions and key sequences.",
							},
						},
					},
				},
				vim.keymap.set(
					{ "n", "v" },
					"<C-a>",
					"<cmd>CodeCompanionActions<cr>",
					{ noremap = true, silent = true }
				),
				vim.keymap.set(
					{ "n", "v" },
					"<LocalLeader>a",
					"<cmd>CodeCompanionChat Toggle<cr>",
					{ noremap = true, silent = true }
				),
				vim.keymap.set("n", "<LocalLeader>r", function()
					local codecompanion = require("codecompanion")
					local run_rules = function(chat)
						if not chat then return end
						require("codecompanion.interactions.chat.slash_commands").run({
							label = "rules",
							config = require("codecompanion.config").interactions.chat.slash_commands["rules"],
						}, chat)
					end
					local chat = codecompanion.buf_get_chat(0) or codecompanion.last_chat()
					if chat then return run_rules(chat) end
					codecompanion.chat()
					vim.schedule(function() run_rules(codecompanion.buf_get_chat(0) or codecompanion.last_chat()) end)
				end, { noremap = true, silent = true, desc = "CodeCompanion rules picker" }),
				vim.keymap.set("v", "ga", "<cmd>CodeCompanionChat Add<cr>", { noremap = true, silent = true }),
				vim.cmd([[cab cc CodeCompanion]]),
				vim.cmd([[cab ccc CodeCompanionChat]]),
				vim.cmd([[cab bu #{buffer}]]),
				vim.cmd([[cab ch #{chat}]]),
				vim.cmd([[cab cl #{clipboard}]]),
				vim.cmd([[cab ag @{agent}]]),
				vim.cmd([[cab fi @{files}]]),
			})
		end,
	},
	{
		"lewis6991/gitsigns.nvim",
		opts = {},
		config = function()
			require("gitsigns").setup()
			local gs = package.loaded.gitsigns

			-- Navigation between hunks
			vim.keymap.set("n", "]c", gs.next_hunk, { desc = "Next hunk" })
			vim.keymap.set("n", "[c", gs.prev_hunk, { desc = "Prev hunk" })
			-- Stage/reset hunk
			vim.keymap.set("n", "<leader>gs", gs.stage_hunk, { desc = "Stage hunk" })
			vim.keymap.set("n", "<leader>gr", gs.reset_hunk, { desc = "Reset hunk" })
			-- Preview hunk
			vim.keymap.set("n", "<leader>gp", gs.preview_hunk, { desc = "Preview hunk" })
			-- Blame line
			vim.keymap.set("n", "<leader>gb", gs.blame_line, { desc = "Git Blame" })
		end,
	},
}
vim.list_extend(plugins, typeset.plugins())

local function open_cheatsheet_float()
	local path = _G.KICKSTART_PROJECT_DIR .. "/cheatsheet.md"
	if vim.fn.filereadable(path) == 0 then
		vim.notify("Cheatsheet not found: " .. path, vim.log.levels.ERROR)
		return
	end

	local lines = vim.fn.readfile(path)
	local width = math.min(100, math.max(60, math.floor(vim.o.columns * 0.8)))
	local height = math.min(#lines, math.max(20, math.floor(vim.o.lines * 0.8)))
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].modifiable = false

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		border = "rounded",
		title = " Cheatsheet ",
		title_pos = "center",
	})
	vim.wo[win].wrap = true
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true, desc = "Close cheatsheet" })
	vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, silent = true, desc = "Close cheatsheet" })
end

-- hotkey for asking about nvim stuff
vim.api.nvim_create_user_command("Cheatsheet", open_cheatsheet_float, { desc = "Open config cheatsheet" })
vim.api.nvim_create_user_command(
	"NvimTips",
	function() require("codecompanion").prompt("nvimtips") end,
	{ desc = "Ask CodeCompanion for Neovim tips with cheatsheet context" }
)

vim.keymap.set("n", "<leader>h", open_cheatsheet_float, { desc = "Open Cheatsheet" })
vim.keymap.set("n", "<leader>?", "<cmd>NvimTips<cr>", { desc = "CodeCompanion: Neovim tips (cheatsheet)" })
-- edit config
vim.keymap.set("n", "<leader>settings", ":e " .. KICKSTART_PROJECT_DIR .. "/kickstart-python.lua")
vim.keymap.set("n", "<leader>load", ":Lazy sync")

vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
--------------------------------------------------------------------------------

-- tell lazy.nvim to load and configure all the plugins
require("lazy").setup(plugins, {
	rocks = {
		enabled = false,
	},
})

-- yank to clipboard
vim.opt.clipboard = "unnamedplus"
vim.keymap.set({ "n", "x" }, "<leader>y", '"+y', { desc = "Yank to system clipboard" })
vim.keymap.set("n", "<leader>Y", '"+Y', { desc = "Yank line to system clipboard" })

typeset.setup()
--------------------------------------------------------------------------------
-- SETUP BASIC PYTHON-RELATED OPTIONS

-- The filetype-autocmd runs a function when opening a file with the filetype
-- "python". This method allows you to make filetype-specific configurations. In
-- there, you have to use `opt_local` instead of `opt` to limit the changes to
-- just that buffer. (As an alternative to using an autocmd, you can also put those
-- configurations into a file `/after/ftplugin/{filetype}.lua` in your
-- nvim-directory.)
vim.api.nvim_create_autocmd("FileType", {
	pattern = "python", -- filetype for which to run the autocmd
	callback = function()
		-- use pep8 standards
		vim.opt_local.expandtab = true
		vim.opt_local.shiftwidth = 4
		vim.opt_local.tabstop = 4
		vim.opt_local.softtabstop = 4

		-- folds based on indentation https://neovim.io/doc/user/fold.html#fold-indent
		-- if you are a heavy user of folds, consider using `nvim-ufo`
		vim.opt_local.foldmethod = "indent"

		local iabbrev = function(lhs, rhs) vim.keymap.set("ia", lhs, rhs, { buffer = true }) end
		-- automatically capitalize boolean values. Useful if you come from a
		-- different language, and lowercase them out of habit.
		iabbrev("true", "True")
		iabbrev("false", "False")

		-- we can also fix other habits we might have from other languages
		iabbrev("--", "#")
		iabbrev("null", "None")
		iabbrev("none", "None")
		iabbrev("nil", "None")
		iabbrev("function", "def")
	end,
})

-- Auto-load local session file on startup if present in current working directory.
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		local session_file = vim.fn.getcwd() .. "/.nvim_session.vim"
		if vim.fn.filereadable(session_file) == 1 then vim.cmd("silent source " .. vim.fn.fnameescape(session_file)) end
	end,
})

-- Run local config if it exists
local local_config = vim.fn.getcwd() .. "/.nvim.lua"
if vim.fn.filereadable(local_config) == 1 then dofile(local_config) end
