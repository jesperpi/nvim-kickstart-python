local repo = vim.fn.getcwd()

vim.opt.runtimepath:prepend(repo)
package.path = repo .. "/lua/?.lua;" .. repo .. "/lua/?/init.lua;" .. package.path

local function fail(message)
	vim.api.nvim_err_writeln(message)
	vim.cmd("cquit")
end

local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/assets", "p")
vim.fn.writefile({ "fake image" }, root .. "/assets/warmed.png")

local picker = require("file_picker")
picker.cache.entries = {}
picker.cache.filters = {}
picker.cache.previous = {
	root = nil,
	mode = nil,
	lead = nil,
}
picker.cache.last_notify = {}

picker.setup()
vim.cmd("tcd " .. vim.fn.fnameescape(root))

local loaded = vim.wait(3000, function()
	local entry = picker.cache.entries.image
	return entry and not entry.refreshing and vim.tbl_contains(entry.paths, "assets/warmed.png")
end, 20)

if not loaded then
	local entry = picker.cache.entries.image
	fail("image cache was not warmed after tcd: " .. vim.inspect(entry and entry.paths or nil))
end

vim.fn.delete(root, "rf")
print("file_picker tcd warm test passed")
vim.cmd("quit")
