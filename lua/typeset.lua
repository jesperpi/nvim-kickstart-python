local M = {}

local function current_file_dir() return vim.fn.expand("%:p:h") end

local function current_file_html_in_out()
	return current_file_dir() .. "/out/" .. vim.fn.expand("%:t:r") .. ".html"
end

local function notify_quarto_result(result)
	if result.code == 0 then
		vim.notify("Rendered Quarto HTML to out/", vim.log.levels.INFO)
		return
	end

	local message = result.stderr
	if message == nil or message == "" then message = result.stdout end
	if message == nil or message == "" then message = "Quarto render failed" end
	vim.notify(message, vim.log.levels.ERROR)
end

local function render_quarto_html()
	if vim.fn.executable("quarto") == 0 then
		vim.notify("quarto executable not found", vim.log.levels.ERROR)
		return
	end

	vim.cmd.write()
	vim.fn.mkdir(current_file_dir() .. "/out", "p")
	vim.system({
		"quarto",
		"render",
		vim.fn.expand("%:p"),
		"--to",
		"html",
		"--output-dir",
		"out",
	}, {
		cwd = current_file_dir(),
		text = true,
	}, function(result) vim.schedule(function() notify_quarto_result(result) end) end)
end

local function view_quarto_html()
	local html = current_file_html_in_out()
	if vim.fn.filereadable(html) == 0 then
		vim.notify("No rendered HTML found at " .. html, vim.log.levels.WARN)
		return
	end

	vim.fn.jobstart({ "xdg-open", html }, { detach = true })
end

function M.plugins()
	return {
		{
			"lervag/vimtex",
			ft = "tex", -- load only for LaTeX files
			config = function()
				vim.g.vimtex_compiler_method = "generic"
				vim.g.vimtex_compiler_generic = {
					command = "mkdir -p build && cd build && make4ht -s -f html5 -d . @tex",
				}
			end,
		},
		{
			"quarto-dev/quarto-nvim",
			ft = "quarto",
			dependencies = {
				"jmbuhr/otter.nvim",
				"nvim-treesitter/nvim-treesitter",
			},
			opts = {
				lspFeatures = {
					enabled = true,
					chunks = "curly",
					languages = { "python", "bash", "html" },
					diagnostics = {
						enabled = true,
						triggers = { "BufWritePost" },
					},
					completion = {
						enabled = true,
					},
				},
				codeRunner = {
					enabled = true,
					default_method = "iron",
					ft_runners = {
						python = "iron",
					},
					never_run = { "yaml" },
				},
			},
		},
	}
end

function M.setup()
	vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
		pattern = "*.qmd",
		callback = function() vim.cmd.setfiletype("quarto") end,
	})

	vim.api.nvim_create_autocmd("FileType", {
		pattern = "tex",
		callback = function()
			vim.api.nvim_buf_create_user_command(0, "TexViewHtml", function()
				local html = vim.fn.expand("%:p:h") .. "/build/" .. vim.fn.expand("%:t:r") .. ".html"
				vim.fn.jobstart({ "xdg-open", html }, { detach = true })
			end, {})
			vim.keymap.set("n", "<localleader>lh", "<cmd>TexViewHtml<cr>", {
				buffer = true,
				desc = "View TeX HTML output",
			})
		end,
	})

	vim.api.nvim_create_autocmd("FileType", {
		pattern = "quarto",
		callback = function()
			local runner = require("quarto.runner")

			vim.api.nvim_buf_create_user_command(0, "QuartoRenderHtml", render_quarto_html, {})
			vim.api.nvim_buf_create_user_command(0, "QuartoViewHtml", view_quarto_html, {})

			vim.keymap.set("n", "<localleader>qp", function() require("quarto").quartoPreview() end, {
				buffer = true,
				desc = "Preview Quarto document",
			})
			vim.keymap.set("n", "<localleader>rh", "<cmd>QuartoRenderHtml<cr>", {
				buffer = true,
				desc = "Render Quarto HTML to out/",
			})
			vim.keymap.set("n", "<localleader>vh", "<cmd>QuartoViewHtml<cr>", {
				buffer = true,
				desc = "View Quarto HTML output",
			})
			vim.keymap.set("n", "<localleader>rc", runner.run_cell, {
				buffer = true,
				desc = "Run Quarto cell",
			})
			vim.keymap.set("n", "<localleader>ra", runner.run_above, {
				buffer = true,
				desc = "Run Quarto cells above",
			})
			vim.keymap.set("n", "<localleader>rA", runner.run_all, {
				buffer = true,
				desc = "Run all Quarto cells",
			})
			vim.keymap.set("n", "<localleader>rl", runner.run_line, {
				buffer = true,
				desc = "Run Quarto line",
			})
			vim.keymap.set("v", "<localleader>r", runner.run_range, {
				buffer = true,
				desc = "Run selected Quarto code",
			})
		end,
	})
end

return M
