local M = {}

local modes = {
	all = {
		exts = nil,
		find_args = {
			"-not",
			"-path",
			"*/.git/*",
			"-not",
			"-path",
			"*/node_modules/*",
			"-not",
			"-path",
			"*/.venv/*",
			"-not",
			"-path",
			"*/venv/*",
			"-not",
			"-path",
			"*/__pycache__/*",
			"-not",
			"-path",
			"*/.mypy_cache/*",
			"-not",
			"-path",
			"*/.pytest_cache/*",
			"-not",
			"-path",
			"*/.ruff_cache/*",
			"-not",
			"-path",
			"*/dist/*",
			"-not",
			"-path",
			"*/build/*",
		},
	},
	image = {
		exts = {
			png = true,
			jpg = true,
			jpeg = true,
			webp = true,
			gif = true,
			bmp = true,
			tif = true,
			tiff = true,
		},
		find_args = {
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
		},
	},
	python = {
		exts = {
			py = true,
			pyi = true,
			ipynb = true,
		},
		find_args = {
			"-iname",
			"*.py",
			"-o",
			"-iname",
			"*.pyi",
			"-o",
			"-iname",
			"*.ipynb",
		},
	},
	fg = {
		exts = nil,
		find_args = nil,
	},
}

M.cache = {
	entries = {},
}

local function norm(path)
	return path:gsub("//+", "/")
end

local function get_root()
	return vim.fn.getcwd()
end

local function rel(path, root)
	root = norm(root)
	local with_sep = root .. "/"
	if path:sub(1, #with_sep) == with_sep then
		return path:sub(#with_sep + 1)
	end
	return path
end

local function has_ext(name, mode)
	if modes[mode].exts == nil then
		return true
	end
	local ext = name:match("%.([^%.]+)$")
	return ext and modes[mode].exts[ext:lower()] or false
end

local function reset_cache(mode)
	M.cache.entries[mode] = nil
end

local function cache_entry(mode, root)
	local entry = M.cache.entries[mode]
	if not entry or entry.root ~= root then
		entry = {
			root = root,
			paths = {},
			refreshing = false,
		}
		M.cache.entries[mode] = entry
	end
	return entry
end

local function refresh_cache_async(mode)
	local root = get_root()
	if root == "" then
		return
	end
	local entry = cache_entry(mode, root)
	if entry.refreshing then
		return
	end

	entry.refreshing = true

	local run_complete = function(out)
		vim.schedule(function()
			local next_entry = M.cache.entries[mode]
			if not next_entry or next_entry.root ~= root then
				return
			end

			next_entry.refreshing = false

			table.sort(out)
			next_entry.paths = out
		end)
	end

	if mode == "fg" then
		vim.system({
			"git",
			"-C",
			root,
			"status",
			"--porcelain=v1",
			"--untracked-files=normal",
			"--ignored=no",
		}, { text = true }, function(result)
			if result.code ~= 0 then
				run_complete({})
				return
			end

			local seen = {}
			local out = {}
			for line in (result.stdout or ""):gmatch("[^\r\n]+") do
				local rel_path = line:sub(4)
				local rename_to = rel_path:match(" %-%> (.+)$")
				if rename_to then
					rel_path = rename_to
				end
				local full_path = norm(root .. "/" .. rel_path)
				if rel_path ~= "" and vim.fn.filereadable(full_path) == 1 and not seen[rel_path] then
					seen[rel_path] = true
					out[#out + 1] = rel_path
				end
			end
			run_complete(out)
		end)
		return
	end

	local args = { "find", "-L", root, "-type", "f", "(" }
	vim.list_extend(args, modes[mode].find_args)
	args[#args + 1] = ")"

	vim.system(args, { text = true }, function(result)
		if result.code ~= 0 then
			run_complete({})
			return
		end

		local out = {}
		for line in (result.stdout or ""):gmatch("[^\r\n]+") do
			out[#out + 1] = rel(norm(line), root)
		end
		run_complete(out)
	end)
end

local function complete_files(mode, arg_lead)
	local root = get_root()
	local entry = cache_entry(mode, root)
	if not entry.refreshing and #entry.paths == 0 then
		refresh_cache_async(mode)
	end
	local lead = arg_lead or ""
	local matches = {}
	for _, path in ipairs(entry.paths) do
		if lead == "" or path:sub(1, #lead) == lead then
			matches[#matches + 1] = path
		end
	end
	return matches
end

local function open_relative(mode, path)
	local rel_path = vim.trim(path or "")
	if rel_path == "" then
		vim.notify(("FilePicker (%s): provide a relative path"):format(mode), vim.log.levels.WARN)
		return
	end

	local full_path = norm(get_root() .. "/" .. rel_path)
	if vim.fn.filereadable(full_path) ~= 1 then
		vim.notify(("FilePicker (%s): not found: %s"):format(mode, rel_path), vim.log.levels.ERROR)
		return
	end
	if not has_ext(full_path, mode) then
		vim.notify(("FilePicker (%s): unsupported extension: %s"):format(mode, rel_path), vim.log.levels.ERROR)
		return
	end

	vim.cmd(("edit %s"):format(vim.fn.fnameescape(full_path)))
	if mode == "image" then
		local bufnr = vim.api.nvim_get_current_buf()
		vim.bo[bufnr].readonly = true
		vim.bo[bufnr].modifiable = false
	end
end

local function parse_picker_args(cmdopts)
	local args = vim.split(vim.trim(cmdopts.args or ""), "%s+", { trimempty = true })
	local mode = args[1]
	local rel_path = args[2]
	return mode, rel_path
end

local function complete_picker(arg_lead, cmdline)
	local command = cmdline:match("^%s*%S+") or ""
	local rest = cmdline:sub(#command + 1)
	local args = vim.split(vim.trim(rest), "%s+", { trimempty = true })
	if #args == 0 then
		return vim.tbl_filter(function(m) return m:sub(1, #arg_lead) == arg_lead end, vim.tbl_keys(modes))
	end
	if #args == 1 and rest:sub(-1) ~= " " then
		return vim.tbl_filter(function(m) return m:sub(1, #arg_lead) == arg_lead end, vim.tbl_keys(modes))
	end

	local mode = args[1]
	if not modes[mode] then
		return {}
	end
	return complete_files(mode, arg_lead)
end

function M.setup()
	for mode, _ in pairs(modes) do
		refresh_cache_async(mode)
	end

	vim.api.nvim_create_user_command("FilePicker", function(cmdopts)
		local mode, rel_path = parse_picker_args(cmdopts)
		if not modes[mode] then
			vim.notify("FilePicker: first argument must be all, image, python, or fg", vim.log.levels.ERROR)
			return
		end
		open_relative(mode, rel_path)
	end, {
		nargs = "+",
		complete = complete_picker,
	})

	vim.api.nvim_create_user_command("FP", function(cmdopts)
		local mode, rel_path = parse_picker_args(cmdopts)
		if not modes[mode] then
			vim.notify("FilePicker: first argument must be all, image, python, or fg", vim.log.levels.ERROR)
			return
		end
		open_relative(mode, rel_path)
	end, {
		nargs = "+",
		complete = complete_picker,
	})

	vim.api.nvim_create_user_command("F", function(cmdopts)
		open_relative("all", cmdopts.args)
	end, {
		nargs = 1,
		complete = function(arg_lead) return complete_files("all", arg_lead) end,
	})

	vim.api.nvim_create_user_command("Fp", function(cmdopts)
		open_relative("python", cmdopts.args)
	end, {
		nargs = 1,
		complete = function(arg_lead) return complete_files("python", arg_lead) end,
	})

	vim.api.nvim_create_user_command("Fi", function(cmdopts)
		open_relative("image", cmdopts.args)
	end, {
		nargs = 1,
		complete = function(arg_lead) return complete_files("image", arg_lead) end,
	})

	vim.api.nvim_create_user_command("Fg", function(cmdopts)
		open_relative("fg", cmdopts.args)
	end, {
		nargs = 1,
		complete = function(arg_lead) return complete_files("fg", arg_lead) end,
	})

	vim.cmd([[cnoreabbrev <expr> f ((getcmdtype() == ':' && getcmdline() ==# 'f') ? 'F' : 'f')]])
	vim.cmd([[cnoreabbrev <expr> fp ((getcmdtype() == ':' && getcmdline() ==# 'fp') ? 'Fp' : 'fp')]])
	vim.cmd([[cnoreabbrev <expr> fi ((getcmdtype() == ':' && getcmdline() ==# 'fi') ? 'Fi' : 'fi')]])
	vim.cmd([[cnoreabbrev <expr> fg ((getcmdtype() == ':' && getcmdline() ==# 'fg') ? 'Fg' : 'fg')]])
end

return M
