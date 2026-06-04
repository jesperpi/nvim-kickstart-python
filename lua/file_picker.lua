local M = {}

local MAX_SCAN_DEPTH = 6
local MAX_SCAN_FILES = 20000
local MAX_SCAN_ENTRIES = 50000
local MAX_SCAN_DIRS = 4000
local NOTIFY_COOLDOWN_MS = 2000
local SCAN_LIMIT_LABEL = ("depth %d, %d matches, %d entries, or %d directories"):format(
	MAX_SCAN_DEPTH,
	MAX_SCAN_FILES,
	MAX_SCAN_ENTRIES,
	MAX_SCAN_DIRS
)

local ignored_dirs = {
	[".git"] = true,
	[".mypy_cache"] = true,
	[".pytest_cache"] = true,
	[".ruff_cache"] = true,
	[".venv"] = true,
	["__pycache__"] = true,
	build = true,
	dist = true,
	node_modules = true,
	venv = true,
}

local modes = {
	all = {
		exts = nil,
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
	},
	python = {
		exts = {
			py = true,
			pyi = true,
			ipynb = true,
		},
	},
	git = {
		exts = nil,
	},
}

local mode_aliases = {
	fg = "git",
}

M.cache = {
	entries = {},
	previous = {
		root = nil,
		mode = nil,
		lead = nil,
		paths = {},
	},
	last_notify = {},
}

local function norm(path) return path:gsub("//+", "/") end

local function get_root() return vim.fn.getcwd() end

local function rel(path, root)
	root = norm(root)
	local with_sep = root .. "/"
	if path:sub(1, #with_sep) == with_sep then return path:sub(#with_sep + 1) end
	return path
end

local function has_ext(name, mode)
	if modes[mode].exts == nil then return true end
	local ext = name:match("%.([^%.]+)$")
	return ext and modes[mode].exts[ext:lower()] or false
end

local function normalize_mode(mode) return mode_aliases[mode] or mode end

local function reset_cache(mode) M.cache.entries[mode] = nil end

local function is_ignored_dir(name) return ignored_dirs[name] or false end

local function notify_once(key, message, level)
	local now = vim.uv.now()
	if M.cache.last_notify[key] and now - M.cache.last_notify[key] < NOTIFY_COOLDOWN_MS then return end
	M.cache.last_notify[key] = now
	vim.notify(message, level)
end

local function fd_binary()
	if vim.fn.executable("fd") == 1 then return "fd" end
	if vim.fn.executable("fdfind") == 1 then return "fdfind" end
	return nil
end

local function fd_args(mode)
	local args = {
		fd_binary(),
		"--type",
		"f",
		"--hidden",
		"--color",
		"never",
		"--strip-cwd-prefix",
		"--max-depth",
		tostring(MAX_SCAN_DEPTH),
		"--max-results",
		tostring(MAX_SCAN_FILES),
	}

	for name, _ in pairs(ignored_dirs) do
		args[#args + 1] = "--exclude"
		args[#args + 1] = name
	end

	if modes[mode].exts then
		for ext, _ in pairs(modes[mode].exts) do
			args[#args + 1] = "--extension"
			args[#args + 1] = ext
		end
	end

	args[#args + 1] = "."
	return args
end

local function scan_files_breadth_first(root, mode)
	local uv = vim.uv or vim.loop
	local out = {}
	local queue = {
		{
			path = root,
			depth = 0,
		},
	}
	local head = 1
	local truncated = false
	local scanned_entries = 0
	local scanned_dirs = 1

	while head <= #queue do
		local current = queue[head]
		head = head + 1

		local scanner = uv.fs_scandir(current.path)
		while scanner do
			local name, typ = uv.fs_scandir_next(scanner)
			if not name then break end
			scanned_entries = scanned_entries + 1
			if scanned_entries >= MAX_SCAN_ENTRIES then
				truncated = true
				return out, truncated
			end

			local child_depth = current.depth + 1
			local child_path = norm(current.path .. "/" .. name)
			if typ == "file" then
				if child_depth <= MAX_SCAN_DEPTH and has_ext(name, mode) then
					out[#out + 1] = rel(child_path, root)
					if #out >= MAX_SCAN_FILES then
						truncated = true
						return out, truncated
					end
				end
			elseif typ == "directory" and child_depth < MAX_SCAN_DEPTH and not is_ignored_dir(name) then
				if scanned_dirs >= MAX_SCAN_DIRS then
					truncated = true
				else
					scanned_dirs = scanned_dirs + 1
					queue[#queue + 1] = {
						path = child_path,
						depth = child_depth,
					}
				end
			end
		end
	end

	return out, truncated
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

local function remember_previous(mode, root, lead, paths)
	M.cache.previous = {
		root = root,
		mode = mode,
		lead = lead,
		paths = vim.deepcopy(paths),
	}
end

local function remember_completion_filter(mode, root, lead, paths, total_count)
	if lead == "" then return end
	if #paths == 0 then return end
	if total_count and #paths >= total_count then return end
	if #paths == 1 and paths[1] == lead then return end
	remember_previous(mode, root, lead, paths)
end

local function refresh_cache_async(mode)
	local root = get_root()
	if root == "" then return end
	local entry = cache_entry(mode, root)
	if entry.refreshing then return end

	entry.refreshing = true

	local run_complete = function(out)
		vim.schedule(function()
			local next_entry = M.cache.entries[mode]
			if not next_entry or next_entry.root ~= root then return end

			next_entry.refreshing = false

			table.sort(out)
			next_entry.paths = out
		end)
	end

	if mode == "git" then
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
				if rename_to then rel_path = rename_to end
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

	if fd_binary() then
		vim.system(fd_args(mode), { text = true, cwd = root }, function(result)
			if result.code ~= 0 then
				run_complete({})
				return
			end

			local out = {}
			for path in (result.stdout or ""):gmatch("[^\r\n]+") do
				if path ~= "" then out[#out + 1] = norm(path) end
			end
			run_complete(out)
		end)
		return
	end

	vim.schedule(function()
		local out, truncated = scan_files_breadth_first(root, mode)
		if truncated then
			notify_once(
				("scan-limit:%s:%s"):format(mode, root),
				("FilePicker (%s): stopped at scan limit: %s"):format(mode, SCAN_LIMIT_LABEL),
				vim.log.levels.WARN
			)
		end
		run_complete(out)
	end)
end

local function complete_files(mode, arg_lead, fresh)
	local root = get_root()
	local entry = cache_entry(mode, root)
	if fresh then reset_cache(mode) end
	if #entry.paths == 0 then
		refresh_cache_async(mode)
		notify_once(
			("warming:%s:%s"):format(mode, root),
			("FilePicker (%s): scanning in background; try completion again in a moment"):format(mode),
			vim.log.levels.INFO
		)
		return {}
	end
	local lead = arg_lead or ""
	local matches = {}
	if lead == "" then
		matches = vim.deepcopy(entry.paths)
	else
		for _, path in ipairs(vim.fn.matchfuzzy(entry.paths, lead)) do
			matches[#matches + 1] = path
		end
	end
	remember_completion_filter(mode, root, lead, matches, #entry.paths)
	return matches
end

local function remember_command_filter(mode, lead)
	lead = vim.trim(lead or "")
	if lead == "" then return end

	local root = get_root()
	local entry = cache_entry(mode, root)
	if #entry.paths == 0 then
		refresh_cache_async(mode)
		return
	end

	local matches = {}
	for _, path in ipairs(vim.fn.matchfuzzy(entry.paths, lead)) do
		matches[#matches + 1] = path
	end
	remember_completion_filter(mode, root, lead, matches, #entry.paths)
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

local function select_cached_file(mode)
	mode = normalize_mode(mode)
	if not modes[mode] then
		vim.notify("FilePicker: mode must be all, image, python, or git", vim.log.levels.ERROR)
		return
	end

	local root = get_root()
	local entry = cache_entry(mode, root)
	if #entry.paths == 0 then
		refresh_cache_async(mode)
		notify_once(
			("select-warming:%s:%s"):format(mode, root),
			("FilePicker (%s): scanning in background; open the picker again in a moment"):format(mode),
			vim.log.levels.INFO
		)
		return
	end

	local paths = vim.deepcopy(entry.paths)
	if #paths == 0 then
		vim.notify(("FilePicker (%s): no cached files available"):format(mode), vim.log.levels.WARN)
		return
	end
	vim.ui.select(paths, {
		prompt = ("FilePicker (%s)"):format(mode),
		format_item = function(path) return path end,
	}, function(choice)
		if choice then open_relative(mode, choice) end
	end)
end

local function select_previous_file()
	local root = get_root()
	local previous = M.cache.previous
	if previous.root == root and previous.mode and #previous.paths > 0 then
		local mode = previous.mode
		local paths = vim.deepcopy(previous.paths)
		vim.ui.select(paths, {
			prompt = ("FilePicker previous (%s: %s)"):format(mode, previous.lead or ""),
			format_item = function(path) return path end,
		}, function(choice)
			if choice then open_relative(mode, choice) end
		end)
		return
	end

	vim.notify("FilePicker: no previous tab-completion filter for this directory", vim.log.levels.WARN)
end

local function parse_picker_args(cmdopts)
	local args = vim.split(vim.trim(cmdopts.args or ""), "%s+", { trimempty = true })
	local fresh = false
	if args[1] == "-r" or args[1] == "--refresh" then
		fresh = true
		table.remove(args, 1)
	end
	local mode = args[1]
	local rel_path = args[2]
	return normalize_mode(mode), rel_path, fresh
end

local function parse_cmdline_args(cmdline)
	local command = cmdline:match("^%s*%S+") or ""
	local rest = cmdline:sub(#command + 1)
	local args = vim.split(vim.trim(rest), "%s+", { trimempty = true })
	return args, rest
end

local function complete_picker(arg_lead, cmdline)
	local args, rest = parse_cmdline_args(cmdline)
	if #args == 0 then
		return vim.tbl_filter(function(m) return m:sub(1, #arg_lead) == arg_lead end, vim.tbl_keys(modes))
	end
	if #args == 1 and rest:sub(-1) ~= " " and ("-r"):sub(1, #arg_lead) == arg_lead then return { "-r" } end
	if #args == 1 and rest:sub(-1) ~= " " and ("--refresh"):sub(1, #arg_lead) == arg_lead then
		return { "--refresh" }
	end
	if #args > 0 and (args[1] == "-r" or args[1] == "--refresh") and #args == 1 and rest:sub(-1) == " " then
		return vim.tbl_filter(function(m) return m:sub(1, #arg_lead) == arg_lead end, vim.tbl_keys(modes))
	end
	if #args > 0 and (args[1] == "-r" or args[1] == "--refresh") and #args == 2 and rest:sub(-1) ~= " " then
		return vim.tbl_filter(function(m) return m:sub(1, #arg_lead) == arg_lead end, vim.tbl_keys(modes))
	end

	local fresh = false
	if args[1] == "-r" or args[1] == "--refresh" then
		fresh = true
		table.remove(args, 1)
	end
	if #args == 1 and rest:sub(-1) ~= " " then
		return vim.tbl_filter(function(m) return m:sub(1, #arg_lead) == arg_lead end, vim.tbl_keys(modes))
	end

	local mode = normalize_mode(args[1])
	if not modes[mode] then return {} end
	return complete_files(mode, arg_lead, fresh)
end

function M.select(mode) select_cached_file(mode or "all") end

function M.select_previous() select_previous_file() end

function M.setup()
	vim.api.nvim_create_user_command("FilePicker", function(cmdopts)
		local mode, rel_path, fresh = parse_picker_args(cmdopts)
		if not modes[mode] then
			vim.notify("FilePicker: first argument must be all, image, python, or git", vim.log.levels.ERROR)
			return
		end
		if fresh then
			reset_cache(mode)
			refresh_cache_async(mode)
		end
		remember_command_filter(mode, rel_path)
		open_relative(mode, rel_path)
	end, {
		nargs = "+",
		complete = complete_picker,
	})

	vim.api.nvim_create_user_command("FP", function(cmdopts)
		local mode, rel_path, fresh = parse_picker_args(cmdopts)
		if not modes[mode] then
			vim.notify("FilePicker: first argument must be all, image, python, or git", vim.log.levels.ERROR)
			return
		end
		if fresh then
			reset_cache(mode)
			refresh_cache_async(mode)
		end
		remember_command_filter(mode, rel_path)
		open_relative(mode, rel_path)
	end, {
		nargs = "+",
		complete = complete_picker,
	})

	vim.api.nvim_create_user_command("FilePickerSelect", function(cmdopts)
		local mode = vim.trim(cmdopts.args or "")
		if mode == "" then mode = "all" end
		select_cached_file(mode)
	end, {
		nargs = "?",
		complete = function(arg_lead)
			return vim.tbl_filter(function(m) return m:sub(1, #arg_lead) == arg_lead end, vim.tbl_keys(modes))
		end,
	})

	vim.api.nvim_create_user_command("FilePickerPrevious", function() select_previous_file() end, {
		nargs = 0,
	})

	vim.api.nvim_create_user_command("F", function(cmdopts)
		local args = vim.split(vim.trim(cmdopts.args or ""), "%s+", { trimempty = true })
		local fresh = false
		if args[1] == "-r" or args[1] == "--refresh" then
			fresh = true
			table.remove(args, 1)
		end
		if fresh then
			reset_cache("all")
			refresh_cache_async("all")
		end
		remember_command_filter("all", args[1])
		open_relative("all", args[1] or "")
	end, {
		nargs = "+",
		complete = function(arg_lead, cmdline)
			local args, rest = parse_cmdline_args(cmdline)
			if #args == 1 and rest:sub(-1) ~= " " and ("-r"):sub(1, #arg_lead) == arg_lead then return { "-r" } end
			if #args == 1 and rest:sub(-1) ~= " " and ("--refresh"):sub(1, #arg_lead) == arg_lead then
				return { "--refresh" }
			end
			local fresh = false
			if args[1] == "-r" or args[1] == "--refresh" then fresh = true end
			return complete_files("all", arg_lead, fresh)
		end,
	})

	vim.api.nvim_create_user_command("Fp", function(cmdopts)
		local args = vim.split(vim.trim(cmdopts.args or ""), "%s+", { trimempty = true })
		local fresh = false
		if args[1] == "-r" or args[1] == "--refresh" then
			fresh = true
			table.remove(args, 1)
		end
		if fresh then
			reset_cache("python")
			refresh_cache_async("python")
		end
		remember_command_filter("python", args[1])
		open_relative("python", args[1] or "")
	end, {
		nargs = "+",
		complete = function(arg_lead, cmdline)
			local args, rest = parse_cmdline_args(cmdline)
			if #args == 1 and rest:sub(-1) ~= " " and ("-r"):sub(1, #arg_lead) == arg_lead then return { "-r" } end
			if #args == 1 and rest:sub(-1) ~= " " and ("--refresh"):sub(1, #arg_lead) == arg_lead then
				return { "--refresh" }
			end
			local fresh = false
			if args[1] == "-r" or args[1] == "--refresh" then fresh = true end
			return complete_files("python", arg_lead, fresh)
		end,
	})

	vim.api.nvim_create_user_command("Fi", function(cmdopts)
		local args = vim.split(vim.trim(cmdopts.args or ""), "%s+", { trimempty = true })
		local fresh = false
		if args[1] == "-r" or args[1] == "--refresh" then
			fresh = true
			table.remove(args, 1)
		end
		if fresh then
			reset_cache("image")
			refresh_cache_async("image")
		end
		remember_command_filter("image", args[1])
		open_relative("image", args[1] or "")
	end, {
		nargs = "+",
		complete = function(arg_lead, cmdline)
			local args, rest = parse_cmdline_args(cmdline)
			if #args == 1 and rest:sub(-1) ~= " " and ("-r"):sub(1, #arg_lead) == arg_lead then return { "-r" } end
			if #args == 1 and rest:sub(-1) ~= " " and ("--refresh"):sub(1, #arg_lead) == arg_lead then
				return { "--refresh" }
			end
			local fresh = false
			if args[1] == "-r" or args[1] == "--refresh" then fresh = true end
			return complete_files("image", arg_lead, fresh)
		end,
	})

	vim.api.nvim_create_user_command("Fg", function(cmdopts)
		local args = vim.split(vim.trim(cmdopts.args or ""), "%s+", { trimempty = true })
		local fresh = false
		if args[1] == "-r" or args[1] == "--refresh" then
			fresh = true
			table.remove(args, 1)
		end
		if fresh then
			reset_cache("git")
			refresh_cache_async("git")
		end
		remember_command_filter("git", args[1])
		open_relative("git", args[1] or "")
	end, {
		nargs = "+",
		complete = function(arg_lead, cmdline)
			local args, rest = parse_cmdline_args(cmdline)
			if #args == 1 and rest:sub(-1) ~= " " and ("-r"):sub(1, #arg_lead) == arg_lead then return { "-r" } end
			if #args == 1 and rest:sub(-1) ~= " " and ("--refresh"):sub(1, #arg_lead) == arg_lead then
				return { "--refresh" }
			end
			local fresh = false
			if args[1] == "-r" or args[1] == "--refresh" then fresh = true end
			return complete_files("git", arg_lead, fresh)
		end,
	})

	vim.cmd([[cnoreabbrev <expr> f ((getcmdtype() == ':' && getcmdline() ==# 'f') ? 'F' : 'f')]])
	vim.cmd([[cnoreabbrev <expr> fp ((getcmdtype() == ':' && getcmdline() ==# 'fp') ? 'Fp' : 'fp')]])
	vim.cmd([[cnoreabbrev <expr> fi ((getcmdtype() == ':' && getcmdline() ==# 'fi') ? 'Fi' : 'fi')]])
	vim.cmd([[cnoreabbrev <expr> fg ((getcmdtype() == ':' && getcmdline() ==# 'fg') ? 'Fg' : 'fg')]])
end

return M
