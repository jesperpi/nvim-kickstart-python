-- Goto the production implementation of the Java interface (or interface method) under the cursor.
-- jdtls finds the implementing classes; when production code has none or several, the Dagger
-- `@Binds`/`@Provides` methods for the interface decide, which also covers bindings made from
-- lambdas and adapters. On an actor call (`actor.tell().update(…)`) or an `Actor<X>` type, the
-- actor's interface is the target rather than the actor framework's own `Actor`.
local M = {}

local function production(uri) return uri:find("/src/main/java/", 1, true) ~= nil end

local function uri_of(location) return location.uri or location.targetUri end

local function range_of(location) return location.range or location.targetSelectionRange end

local function location_at(uri, row, col)
	local position = { line = row, character = col }
	return { uri = uri, range = { start = position, ["end"] = position } }
end

local function same_place(a, b)
	local ra, rb = range_of(a).start, range_of(b).start
	return uri_of(a) == uri_of(b) and ra.line == rb.line and ra.character == rb.character
end

local function request(client, method, params, bufnr)
	local co = coroutine.running()
	client:request(method, params, function(err, result)
		vim.schedule(function() coroutine.resume(co, err, result) end)
	end, bufnr)
	local err, result = coroutine.yield()
	if err or not result then return {} end
	return vim.islist(result) and result or { result }
end

local function position_params(uri, row, col)
	return { textDocument = { uri = uri }, position = { line = row, character = col } }
end

local parsed = {}

-- Parses the file behind `uri` with treesitter; open buffers are parsed as they are, unsaved edits included.
local function parse(uri)
	if parsed[uri] then return parsed[uri] end
	local bufnr = vim.uri_to_bufnr(uri)
	local source
	if vim.api.nvim_buf_is_loaded(bufnr) then
		source = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
	else
		local file = io.open(vim.uri_to_fname(uri))
		if not file then return nil end
		source = file:read("*a")
		file:close()
	end
	local ok, parser = pcall(vim.treesitter.get_string_parser, source, "java")
	if not ok then return nil end
	parsed[uri] = { root = parser:parse()[1]:root(), source = source }
	return parsed[uri]
end

local function node_at(tree, row, col) return tree.root:named_descendant_for_range(row, col, row, col) end

local function text(tree, node) return vim.treesitter.get_node_text(node, tree.source) end

local function ancestor(node, type)
	while node and node:type() ~= type do
		node = node:parent()
	end
	return node
end

local function contains(outer, inner)
	local orow, ocol, oerow, oecol = outer:range()
	local irow, icol, ierow, iecol = inner:range()
	return (irow > orow or irow == orow and icol >= ocol) and (ierow < oerow or ierow == oerow and iecol <= oecol)
end

-- The position to look up implementations for: the cursor, or the actor interface it points at.
local function target_position(bufnr, row, col)
	local tree = parse(vim.uri_from_bufnr(bufnr))
	local node = tree and node_at(tree, row, col)
	if not node then return row, col end

	local generic = ancestor(node, "generic_type")
	local base = generic and generic:named_child(0)
	if base and text(tree, base) == "Actor" and contains(base, node) then
		local argument = generic:named_child(1) and generic:named_child(1):named_child(0)
		if argument then
			local r, c = argument:start()
			return r, c
		end
	end

	local invocation = ancestor(node, "method_invocation")
	local name = invocation and invocation:field("name")[1]
	local outer = invocation and invocation:parent()
	local object = outer and outer:type() == "method_invocation" and outer:field("object")[1]
	if name and text(tree, name) == "tell" and object and object:id() == invocation:id() then
		local r, c = outer:field("name")[1]:start()
		return r, c
	end
	return row, col
end

-- The interface the definition at `location` belongs to, and the method name when it is a method.
local function contract_of(location)
	local uri = uri_of(location)
	local tree = parse(uri)
	local start = range_of(location).start
	local node = tree and node_at(tree, start.line, start.character)
	local interface = node and ancestor(node, "interface_declaration")
	if not interface then return nil end
	local method = ancestor(node, "method_declaration")
	local name = interface:field("name")[1]
	local row, col = name:start()
	return {
		uri = uri,
		row = row,
		col = col,
		method = method and contains(interface, method) and text(tree, method:field("name")[1]) or nil,
	}
end

local function annotated(tree, method, annotation)
	for child in method:iter_children() do
		if child:type() == "modifiers" and text(tree, child):find("@" .. annotation .. "%f[%W]") then return true end
	end
	return false
end

-- Dagger binding methods whose return type is the interface, from the interface's references.
local function bindings(client, contract, bufnr)
	local params = position_params(contract.uri, contract.row, contract.col)
	params.context = { includeDeclaration = false }
	local found = {}
	for _, reference in ipairs(request(client, "textDocument/references", params, bufnr)) do
		local uri = uri_of(reference)
		local tree = production(uri) and parse(uri)
		local start = range_of(reference).start
		local node = tree and node_at(tree, start.line, start.character)
		local method = node and ancestor(node, "method_declaration")
		local returned = method and method:field("type")[1]
		if returned and contains(returned, node) then
			local kind = annotated(tree, method, "Binds") and "Binds" or annotated(tree, method, "Provides") and "Provides"
			if kind then table.insert(found, { kind = kind, uri = uri, tree = tree, method = method }) end
		end
	end
	return found
end

local function last_return(node)
	local found
	for child in node:iter_children() do
		if child:type() == "return_statement" then
			found = child
		elseif child:named_child_count() > 0 and child:type() ~= "lambda_expression" and child:type() ~= "class_body" then
			found = last_return(child) or found
		end
	end
	return found
end

local function parameter_type(tree, method, name)
	for parameter in method:field("parameters")[1]:iter_children() do
		local parameter_name = parameter:type() == "formal_parameter" and parameter:field("name")[1]
		if parameter_name and text(tree, parameter_name) == name then return parameter:field("type")[1] end
	end
end

-- Where a binding leads: the bound or constructed class, or else the expression a `@Provides` returns.
local function binding_targets(client, binding, bufnr)
	local tree, method = binding.tree, binding.method
	local type_node
	if binding.kind == "Binds" then
		local parameter = method:field("parameters")[1]:named_child(0)
		type_node = parameter and parameter:field("type")[1]
	else
		local statement = last_return(method:field("body")[1] or method)
		local value = statement and statement:named_child(0)
		if not value then
			local r, c = method:start()
			return { location_at(binding.uri, r, c) }
		end
		if value:type() == "identifier" then
			type_node = parameter_type(tree, method, text(tree, value))
		elseif value:type() == "object_creation_expression" and not value:field("body")[1] then
			type_node = value:field("type")[1]
		end
		if not type_node then
			local r, c = value:start()
			return { location_at(binding.uri, r, c) }
		end
	end
	if not type_node then return {} end
	if type_node:type() == "generic_type" or type_node:type() == "scoped_type_identifier" then
		type_node = type_node:named_child(type_node:type() == "generic_type" and 0 or type_node:named_child_count() - 1)
	end
	local r, c = type_node:start()
	return request(client, "textDocument/definition", position_params(binding.uri, r, c), bufnr)
end

-- Moves a location on a class's name to the method of that name declared in the class, when there is one.
local function to_method(location, name)
	local tree = parse(uri_of(location))
	local start = range_of(location).start
	local node = tree and node_at(tree, start.line, start.character)
	local class = node and node:parent()
	local body = class and class:type():find("_declaration$") and class:field("body")[1]
	if not body then return location end
	for member in body:iter_children() do
		local member_name = member:type() == "method_declaration" and member:field("name")[1]
		if member_name and text(tree, member_name) == name then
			local r, c = member_name:start()
			return location_at(uri_of(location), r, c)
		end
	end
	return location
end

local function jump(client, location)
	vim.lsp.util.show_document(location, client.offset_encoding, { focus = true })
end

local function choose(client, locations)
	if #locations == 1 then return jump(client, locations[1]) end
	vim.ui.select(locations, {
		prompt = "Implementations",
		format_item = function(location)
			local start = range_of(location).start
			local tree = parse(uri_of(location))
			local line = tree and vim.split(tree.source, "\n")[start.line + 1] or ""
			return vim.fn.fnamemodify(vim.uri_to_fname(uri_of(location)), ":t")
				.. ":"
				.. (start.line + 1)
				.. "  "
				.. vim.trim(line)
		end,
	}, function(location)
		if location then jump(client, location) end
	end)
end

local function unique(locations)
	local result = {}
	for _, location in ipairs(locations) do
		local seen = vim.iter(result):any(function(other) return same_place(other, location) end)
		if not seen then table.insert(result, location) end
	end
	return result
end

local function goto_implementation(client, bufnr)
	parsed = {}
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = target_position(bufnr, cursor[1] - 1, cursor[2])
	local params = position_params(vim.uri_from_bufnr(bufnr), row, col)

	-- jdtls answers with the interface itself when nothing implements it
	local definition = request(client, "textDocument/definition", params, bufnr)[1]
	local implementations = vim.tbl_filter(
		function(location)
			return production(uri_of(location)) and not (definition and same_place(location, definition))
		end,
		request(client, "textDocument/implementation", params, bufnr)
	)
	if #implementations == 1 then return jump(client, implementations[1]) end

	local contract = definition and contract_of(definition)
	local targets = {}
	if contract then
		for _, binding in ipairs(bindings(client, contract, bufnr)) do
			for _, location in ipairs(binding_targets(client, binding, bufnr)) do
				table.insert(targets, contract.method and to_method(location, contract.method) or location)
			end
		end
	end
	targets = unique(targets)

	if #targets > 0 then return choose(client, targets) end
	if #implementations > 0 then return choose(client, implementations) end
	vim.notify("No production implementation found", vim.log.levels.WARN)
end

function M.goto_implementation()
	local bufnr = vim.api.nvim_get_current_buf()
	local client = vim.lsp.get_clients({ bufnr = bufnr, name = "jdtls" })[1]
	if not client then return vim.lsp.buf.implementation() end
	coroutine.wrap(goto_implementation)(client, bufnr)
end

return M
