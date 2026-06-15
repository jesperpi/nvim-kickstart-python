local M = {}

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
	}
end

function M.setup()
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
end

return M
