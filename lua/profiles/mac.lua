-- Mac profile: Java work machine. No Python tooling and no LaTeX/Quarto.
-- image.nvim needs the kitty terminal (iTerm2 does not speak the kitty graphics protocol).
return {
	python = false,
	java = {
		enabled = true,
		debug = true,
		lombok = true,
		depgraph_includes = "se.mynt*", -- only Rider's own modules in `:DepGraph`
	},
	typeset = false,
	image = true,
	mason = {
		"lemminx", -- LSP for XML (pom.xml, Maven settings)
	},
	treesitter = { "xml", "properties", "sql", "json" },
	lsp = { "lemminx" },
	plugins = {
		{
			"mfussenegger/nvim-dap",
			config = function()
				-- attach to a JVM started by `rider-debug` (see ~/.zshrc); the "java" adapter
				-- comes from nvim-jdtls, so open a Java file first
				local dap = require("dap")
				dap.configurations.java = dap.configurations.java or {}
				table.insert(dap.configurations.java, {
					type = "java",
					request = "attach",
					name = "Attach to rider-debug",
					hostName = "127.0.0.1",
					port = tonumber(vim.env.RIDER_DEBUG_PORT) or 5005,
				})
			end,
		},
	},
	setup = function()
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "java",
			callback = function()
				-- 4-space indent unless the project's .editorconfig says otherwise
				vim.opt_local.expandtab = true
				vim.opt_local.shiftwidth = 4
				vim.opt_local.tabstop = 4
				vim.opt_local.softtabstop = 4
			end,
		})
	end,
}
