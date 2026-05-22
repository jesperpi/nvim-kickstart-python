local M = {}

M.config = {
	root = "/home/jesper/mnt/su_maths/data/trainer/training_outputs",
}

local exts = {
	png = true,
	jpg = true,
	jpeg = true,
	webp = true,
	gif = true,
	bmp = true,
	tif = true,
	tiff = true,
}

M.cache = {
	root = nil,
	paths = {},
	refreshing = false,
}

local function norm(path)
	return path:gsub("//+", "/")
end

local function rel(path)
	local root = norm(M.config.root)
	local with_sep = root .. "/"
	if path:sub(1, #with_sep) == with_sep then
		return path:sub(#with_sep + 1)
	end
	return path
end

local function is_image(name)
	local ext = name:match("%.([^%.]+)$")
	return ext and exts[ext:lower()] or false
end

local function reset_cache()
	M.cache.root = nil
	M.cache.paths = {}
	M.cache.refreshing = false
end

local function refresh_cache_async()
	local root = M.config.root
	if root == "" then
		return
	end
	if M.cache.refreshing and M.cache.root == root then
		return
	end

	M.cache.refreshing = true
	M.cache.root = root

	vim.system({
		"find",
		root,
		"-type",
		"f",
		"(",
		"-iname",
		"*.png",
		"-o",
		"-iname",
		"*.jpg",
		"-o",
		"-iname",
		"*.jpeg",
		"-o",
		"-iname",
		"*.webp",
		"-o",
		"-iname",
		"*.gif",
		"-o",
		"-iname",
		"*.bmp",
		"-o",
		"-iname",
		"*.tif",
		"-o",
		"-iname",
		"*.tiff",
		")",
	}, { text = true }, function(result)
		vim.schedule(function()
			if M.cache.root ~= root then
				return
			end

			M.cache.refreshing = false
			if result.code ~= 0 then
				return
			end

			local out = {}
			for line in (result.stdout or ""):gmatch("[^\r\n]+") do
				out[#out + 1] = rel(norm(line))
			end
			table.sort(out)
			M.cache.paths = out
		end)
	end)
end

local function complete_images(arg_lead)
	if M.cache.root ~= M.config.root then
		reset_cache()
	end
	if not M.cache.refreshing and #M.cache.paths == 0 then
		refresh_cache_async()
	end

	local lead = arg_lead or ""
	local matches = {}
	for _, path in ipairs(M.cache.paths) do
		if lead == "" or path:sub(1, #lead) == lead then
			matches[#matches + 1] = path
		end
	end
	return matches
end

local function open_relative_image(path)
	local rel_path = vim.trim(path or "")
	if rel_path == "" then
		vim.notify("PlotPicker: provide a relative image path", vim.log.levels.WARN)
		return
	end

	local full_path = norm(M.config.root .. "/" .. rel_path)
	if vim.fn.filereadable(full_path) ~= 1 then
		vim.notify(("PlotPicker: not found: %s"):format(rel_path), vim.log.levels.ERROR)
		return
	end
	if not is_image(full_path) then
		vim.notify(("PlotPicker: not an image: %s"):format(rel_path), vim.log.levels.ERROR)
		return
	end

	vim.cmd(("edit %s"):format(vim.fn.fnameescape(full_path)))
	local bufnr = vim.api.nvim_get_current_buf()
	vim.bo[bufnr].readonly = true
	vim.bo[bufnr].modifiable = false
end

local function set_root(path)
	local next_root = vim.fn.fnamemodify(vim.trim(path or ""), ":p")
	next_root = norm(next_root):gsub("/$", "")
	if next_root == "" then
		vim.notify("PlotPicker: root cannot be empty", vim.log.levels.ERROR)
		return
	end
	if vim.fn.isdirectory(next_root) ~= 1 then
		vim.notify(("PlotPicker: not a directory: %s"):format(next_root), vim.log.levels.ERROR)
		return
	end
	M.config.root = next_root
	reset_cache()
	refresh_cache_async()
	vim.notify(("PlotPicker root set: %s"):format(M.config.root), vim.log.levels.INFO)
end

local function show_root()
	vim.notify(("PlotPicker root: %s"):format(M.config.root), vim.log.levels.INFO)
end

function M.setup(opts)
	if opts then
		M.config = vim.tbl_extend("force", M.config, opts)
	end
	reset_cache()
	refresh_cache_async()

	vim.api.nvim_create_user_command("PlotPicker", function(cmdopts)
		open_relative_image(cmdopts.args)
	end, {
		nargs = 1,
		complete = function(arg_lead)
			return complete_images(arg_lead)
		end,
	})

	vim.api.nvim_create_user_command("PlotPickerSetRoot", function(cmdopts)
		set_root(cmdopts.args)
	end, {
		nargs = 1,
		complete = "dir",
	})

	vim.api.nvim_create_user_command("PlotPickerRoot", function()
		show_root()
	end, {})
end

return M
