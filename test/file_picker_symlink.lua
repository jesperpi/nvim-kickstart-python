local repo = vim.fn.getcwd()
local uv = vim.uv or vim.loop

vim.opt.runtimepath:prepend(repo)
package.path = repo .. "/lua/?.lua;" .. repo .. "/lua/?/init.lua;" .. package.path

local function fail(message)
	vim.api.nvim_err_writeln(message)
	vim.cmd("cquit")
end

local function assert_contains(list, expected)
	for _, item in ipairs(list or {}) do
		if item == expected then return end
	end
	fail(("expected %q in: %s"):format(expected, vim.inspect(list)))
end

local root = vim.fn.tempname()
local real_dir = root .. "/real_pkg"
local symlink_dir = root .. "/linked_pkg"

vim.fn.mkdir(real_dir, "p")
vim.fn.writefile({ "print('ok')" }, real_dir .. "/module.py")
vim.fn.writefile({ "/linked_pkg" }, root .. "/.gitignore")

local ok, err = uv.fs_symlink("real_pkg", symlink_dir, { dir = true })
if not ok then fail("failed to create test symlink: " .. tostring(err)) end

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
vim.cmd("cd " .. vim.fn.fnameescape(root))

vim.fn.getcompletion("FilePicker python linked", "cmdline")

local loaded = vim.wait(3000, function()
	local entry = picker.cache.entries.python
	return entry and not entry.refreshing and vim.tbl_contains(entry.paths, "linked_pkg/module.py")
end, 20)

if not loaded then
	local entry = picker.cache.entries.python
	fail("symlinked Python file was not cached: " .. vim.inspect(entry and entry.paths or nil))
end

local matches = vim.fn.getcompletion("FilePicker python linked", "cmdline")
assert_contains(matches, "linked_pkg/module.py")

vim.fn.delete(root, "rf")
print("file_picker symlink test passed")
vim.cmd("quit")
