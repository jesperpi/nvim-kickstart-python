local M = {}

M.config = {
	root = "/home/jesper/mnt/su_maths/data/trainer/training_outputs",
}

M.state = {
	items = {},
	filtered = {},
	filter = "",
	bufnr = nil,
	winid = nil,
	config_bufnr = nil,
	config_winid = nil,
	preview = nil,
}

local function norm(path)
	return path:gsub("//+", "/")
end

local function rel(path)
	local root = M.config.root
	if path:sub(1, #root) == root then
		return path:sub(#root + 2)
	end
	return path
end

local current_item

local function apply_filter()
	local query = M.state.filter:lower()
	if query == "" then
		M.state.filtered = vim.deepcopy(M.state.items)
		return
	end

	M.state.filtered = {}
	for _, item in ipairs(M.state.items) do
		if item.rel:lower():find(query, 1, true) then
			table.insert(M.state.filtered, item)
		end
	end
end

local function header_lines()
	return {
		("Plot Picker | root: %s"):format(M.config.root),
		("filter: %s"):format(M.state.filter == "" and "<none>" or M.state.filter),
		("matches: %d / %d"):format(#M.state.filtered, #M.state.items),
		"",
	}
end

local function close_config_window()
	if M.state.config_winid and vim.api.nvim_win_is_valid(M.state.config_winid) then
		vim.api.nvim_win_close(M.state.config_winid, true)
	end
	M.state.config_winid = nil
	M.state.config_bufnr = nil
end

local function ensure_config_window()
	if M.state.config_winid and vim.api.nvim_win_is_valid(M.state.config_winid) then return end
	if not (M.state.winid and vim.api.nvim_win_is_valid(M.state.winid)) then return end

	local picker_win = M.state.winid
	vim.api.nvim_set_current_win(picker_win)
	vim.cmd("rightbelow vsplit")
	M.state.config_winid = vim.api.nvim_get_current_win()
	M.state.config_bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(M.state.config_winid, M.state.config_bufnr)

	vim.bo[M.state.config_bufnr].buftype = "nofile"
	vim.bo[M.state.config_bufnr].bufhidden = "wipe"
	vim.bo[M.state.config_bufnr].swapfile = false
	vim.bo[M.state.config_bufnr].filetype = "plotpickerconfig"
	vim.bo[M.state.config_bufnr].modifiable = false
	vim.wo[M.state.config_winid].number = false
	vim.wo[M.state.config_winid].relativenumber = false
	vim.wo[M.state.config_winid].wrap = false
	vim.api.nvim_win_set_width(M.state.config_winid, 72)

	vim.api.nvim_set_current_win(picker_win)
end

local function read_lines(path, max_lines)
	local fd = io.open(path, "r")
	if not fd then return nil end
	local lines = {}
	for line in fd:lines() do
		lines[#lines + 1] = line
		if #lines >= max_lines then
			lines[#lines + 1] = "... (truncated)"
			break
		end
	end
	fd:close()
	return lines
end

local function find_history_path(item)
	if not item then return nil end
	local dir = vim.fs.dirname(item.path)
	local root = norm(M.config.root)
	while dir and dir ~= "" do
		local p = norm(dir .. "/history.json")
		if vim.fn.filereadable(p) == 1 then return p end
		if dir == root then break end
		local parent = vim.fs.dirname(dir)
		if not parent or parent == dir then break end
		dir = parent
	end
	return nil
end

local function decode_config_lines(path)
	local raw = table.concat(read_lines(path, 100000) or {}, "\n")
	local ok, data = pcall(vim.json.decode, raw)
	if not ok or type(data) ~= "table" then return nil, "Invalid JSON in history.json" end
	if type(data.config) ~= "table" then return nil, "No root `config` entry in history.json" end
	local pretty = vim.inspect(data.config, { newline = "\n", indent = "  " })
	local out = vim.split(pretty, "\n", { plain = true, trimempty = false })
	return out, nil
end

local function render_config()
	if not (M.state.config_bufnr and vim.api.nvim_buf_is_valid(M.state.config_bufnr)) then return end

	local item = current_item()
	local history_path = find_history_path(item)
	local lines = { "History / Config", "" }
	if not item then
		lines[#lines + 1] = "No selected plot."
	elseif not history_path then
		lines[#lines + 1] = ("plot: %s"):format(item.rel)
		lines[#lines + 1] = ""
		lines[#lines + 1] = "No history.json found in parent folders."
	else
		local config_lines, err = decode_config_lines(history_path)
		lines[#lines + 1] = ("plot: %s"):format(item.rel)
		lines[#lines + 1] = ("source: %s"):format(rel(history_path))
		lines[#lines + 1] = ""
		if err then
			lines[#lines + 1] = err
			lines[#lines + 1] = ""
			lines[#lines + 1] = "First lines of history.json:"
			config_lines = read_lines(history_path, 120) or { "(failed to read file)" }
		end
		for _, line in ipairs(config_lines or {}) do
			lines[#lines + 1] = line
		end
	end

	vim.bo[M.state.config_bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(M.state.config_bufnr, 0, -1, false, lines)
	vim.bo[M.state.config_bufnr].modifiable = false
end

local function render()
	if not (M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr)) then return end

	local lines = header_lines()
	for i, item in ipairs(M.state.filtered) do
		lines[#lines + 1] = ("%4d  %s"):format(i, item.rel)
	end

	if #M.state.filtered == 0 then lines[#lines + 1] = "  (no matching plots)" end

	vim.bo[M.state.bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(M.state.bufnr, 0, -1, false, lines)
	vim.bo[M.state.bufnr].modifiable = false
	render_config()
end

current_item = function()
	if not M.state.winid or not vim.api.nvim_win_is_valid(M.state.winid) then return nil end
	local line = vim.api.nvim_win_get_cursor(M.state.winid)[1]
	local idx = line - 4
	if idx < 1 then return nil end
	return M.state.filtered[idx]
end

local function open_plot(path)
	local clear_preview = function()
		if M.state.preview and M.state.preview.clear then M.state.preview:clear() end
		M.state.preview = nil
	end

	local open_fallback_preview = function(reason)
		if reason and reason ~= "" then vim.notify(reason, vim.log.levels.WARN) end
		if vim.fn.executable("chafa") == 1 then
			vim.cmd("enew")
			local out = vim.fn.systemlist({ "chafa", "--format=symbols", "--size=100x35", path })
			if vim.v.shell_error == 0 and out and #out > 0 then
				local b = vim.api.nvim_get_current_buf()
				vim.bo[b].buftype = "nofile"
				vim.bo[b].bufhidden = "wipe"
				vim.bo[b].swapfile = false
				vim.bo[b].modifiable = true
				vim.api.nvim_buf_set_lines(b, 0, -1, false, out)
				vim.bo[b].modifiable = false
				vim.bo[b].filetype = "plotpreview"
				return
			end
		end
		vim.cmd(("edit %s"):format(vim.fn.fnameescape(path)))
	end

	local target_win = nil
	local alt_win = vim.fn.win_getid(vim.fn.winnr("#"))
	if alt_win ~= -1 and vim.api.nvim_win_is_valid(alt_win) and alt_win ~= M.state.winid then target_win = alt_win end

	if target_win then
		vim.api.nvim_set_current_win(target_win)
	else
		vim.cmd("aboveleft split")
	end

	clear_preview()

	if vim.env.KITTY_WINDOW_ID == nil or vim.env.KITTY_WINDOW_ID == "" then
		open_fallback_preview("Plot image backend is kitty, but this Neovim session is not running in Kitty.")
		return
	end

	local ok, image = pcall(require, "image")
	if not ok then
		open_fallback_preview("image.nvim is unavailable; using fallback plot preview.")
		return
	end

	local preview_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(preview_buf)
	vim.bo[preview_buf].buftype = "nofile"
	vim.bo[preview_buf].bufhidden = "wipe"
	vim.bo[preview_buf].swapfile = false
	vim.bo[preview_buf].modifiable = true
	vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { ("[plot] %s"):format(path), "" })
	vim.bo[preview_buf].modifiable = false
	vim.bo[preview_buf].filetype = "plotpreview"

	local img = image.from_file(path, {
		window = vim.api.nvim_get_current_win(),
		with_virtual_padding = true,
		x = 0,
		y = 2,
	})
	if not img then
		open_fallback_preview("Could not create image preview; using fallback plot preview.")
		return
	end

	local render_ok = pcall(function() img:render() end)
	if not render_ok then
		open_fallback_preview("Image render failed; using fallback plot preview.")
		return
	end

	M.state.preview = img
end

function M.reload()
	local files = vim.fs.find(function(name)
		return name:lower():match("%.png$") ~= nil
	end, { path = M.config.root, type = "file", limit = math.huge })

	table.sort(files)
	M.state.items = {}
	for _, file in ipairs(files) do
		table.insert(M.state.items, {
			path = norm(file),
			rel = rel(norm(file)),
		})
	end

	apply_filter()
	render()
	vim.notify(("Plot picker reloaded: %d png files"):format(#M.state.items), vim.log.levels.INFO)
end

function M.set_filter(filter)
	M.state.filter = vim.trim(filter or "")
	apply_filter()
	render()
end

function M.next_item()
	if not M.state.winid or not vim.api.nvim_win_is_valid(M.state.winid) then return end
	local line = vim.api.nvim_win_get_cursor(M.state.winid)[1]
	local last = 4 + math.max(#M.state.filtered, 1)
	vim.api.nvim_win_set_cursor(M.state.winid, { math.min(line + 1, last), 0 })
	render_config()
end

function M.prev_item()
	if not M.state.winid or not vim.api.nvim_win_is_valid(M.state.winid) then return end
	local line = vim.api.nvim_win_get_cursor(M.state.winid)[1]
	vim.api.nvim_win_set_cursor(M.state.winid, { math.max(line - 1, 5), 0 })
	render_config()
end

function M.open_current()
	local item = current_item()
	if not item then
		vim.notify("No plot selected", vim.log.levels.WARN)
		return
	end
	open_plot(item.path)
end

function M.open(opts)
	opts = opts or {}
	if opts.root and opts.root ~= "" then M.config.root = opts.root end
	if opts.filter and opts.filter ~= "" then M.state.filter = opts.filter end

	if M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
		if M.state.winid and vim.api.nvim_win_is_valid(M.state.winid) then
			ensure_config_window()
			vim.api.nvim_set_current_win(M.state.winid)
			render()
			return
		end
	end

	vim.cmd("botright 14split")
	M.state.winid = vim.api.nvim_get_current_win()
	M.state.bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(M.state.winid, M.state.bufnr)

	vim.bo[M.state.bufnr].buftype = "nofile"
	vim.bo[M.state.bufnr].bufhidden = "wipe"
	vim.bo[M.state.bufnr].swapfile = false
	vim.bo[M.state.bufnr].filetype = "plotpicker"
	vim.bo[M.state.bufnr].modifiable = false
	vim.wo[M.state.winid].number = false
	vim.wo[M.state.winid].relativenumber = false
	vim.wo[M.state.winid].cursorline = true

	local map = function(lhs, rhs, desc)
		vim.keymap.set("n", lhs, rhs, { buffer = M.state.bufnr, silent = true, desc = desc })
	end

	map("q", "<cmd>close<cr>", "Close Plot Picker")
	map("<CR>", M.open_current, "Open Selected Plot")
	map("r", M.reload, "Reload Plot Index")
	map("/", function()
		vim.ui.input({ prompt = "Plot filter: ", default = M.state.filter }, function(input)
			if input ~= nil then M.set_filter(input) end
		end)
	end, "Set Plot Filter")
	map("j", M.next_item, "Next Plot")
	map("k", M.prev_item, "Previous Plot")
	map("]p", M.next_item, "Next Plot")
	map("[p", M.prev_item, "Previous Plot")

	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = M.state.bufnr,
		callback = function() render_config() end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = M.state.bufnr,
		callback = close_config_window,
	})

	ensure_config_window()
	M.reload()
	if #M.state.filtered > 0 then vim.api.nvim_win_set_cursor(M.state.winid, { 5, 0 }) end
end

function M.setup(opts)
	if opts then M.config = vim.tbl_extend("force", M.config, opts) end

	vim.api.nvim_create_user_command("PlotPicker", function(cmdopts)
		M.open({ filter = cmdopts.args })
	end, { nargs = "?" })

	vim.api.nvim_create_user_command("PlotPickerFilter", function(cmdopts)
		M.set_filter(cmdopts.args)
	end, { nargs = "*" })

	vim.api.nvim_create_user_command("PlotPickerReload", function() M.reload() end, {})

	vim.api.nvim_create_user_command("PlotPickerNext", function() M.next_item() end, {})
	vim.api.nvim_create_user_command("PlotPickerPrev", function() M.prev_item() end, {})
end

return M
