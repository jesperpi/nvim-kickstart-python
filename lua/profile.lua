-- Machine profiles: the shared config reads these switches, and each machine
-- picks a profile from `lua/profiles/`.
--
-- The profile is chosen by, in order:
-- 1. `vim.g.kickstart_profile`, set in `init.lua` before loading this config
-- 2. the `NVIM_PROFILE` environment variable
-- 3. the operating system: "mac" on macOS, otherwise "linux"

local defaults = {
	python = true, -- pyright, ruff, debugpy, REPL, pytest adapter, f-strings
	java = {
		enabled = true, -- jdtls, neotest-java
		debug = false, -- java-debug-adapter and java-test bundles for nvim-dap
		lombok = false, -- run jdtls with the lombok agent that ships with Mason's jdtls
		depgraph_includes = "", -- default filter for `:DepGraph`, e.g. "com.example*"; empty shows everything
	},
	typeset = true, -- LaTeX and Quarto support from `lua/typeset.lua`
	image = true, -- image.nvim (needs a kitty-protocol terminal and ImageMagick)
	mason = {}, -- extra Mason tools to install
	treesitter = {}, -- extra treesitter parsers
	lsp = {}, -- extra LSP servers to enable with `vim.lsp.enable`
	plugins = {}, -- extra lazy.nvim plugin specs
	setup = function() end, -- runs after the shared config is loaded
}

local function detect()
	if vim.g.kickstart_profile then return vim.g.kickstart_profile end
	if vim.env.NVIM_PROFILE and vim.env.NVIM_PROFILE ~= "" then return vim.env.NVIM_PROFILE end
	return vim.uv.os_uname().sysname == "Darwin" and "mac" or "linux"
end

local name = detect()
local ok, profile = pcall(require, "profiles." .. name)
if not ok then
	vim.notify("Profile '" .. name .. "' not loaded, using defaults:\n" .. profile, vim.log.levels.WARN)
	profile = {}
end

local M = vim.tbl_deep_extend("force", defaults, profile)
M.name = name
return M
