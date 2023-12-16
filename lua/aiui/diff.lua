local slice = require("aiui.util").slice

local function hunks_to_line_hunks(org_lines, changed_lines, hunks)
	local line_hunks = {}
	local prev_end = 0
	for _, hunk in ipairs(hunks) do
		local start_a = hunk[1]
		local count_a = hunk[2]
		local start_b = hunk[3]
		local count_b = hunk[4]
		local end_a = start_a + count_a
		local end_b = start_b + count_b
		table.insert(line_hunks, {
			hunk = hunk,
			prev = slice(org_lines, prev_end, start_a),
			current = slice(org_lines, start_a, end_a),
			new = slice(changed_lines, start_b, end_b),
		})
		prev_end = end_a
	end
	local last_lines = slice(org_lines, prev_end, #org_lines + 1)
	return line_hunks, last_lines
end

local function insert_line(bufnr, start_index, lines, max_line_nr)
	local end_index = start_index + #lines
	vim.print("(" .. start_index .. ", " .. end_index .. ")")
	if end_index >= max_line_nr then
		vim.api.nvim_buf_set_lines(bufnr, start_index, max_line_nr, false, lines)
		return end_index, end_index
	else
		vim.api.nvim_buf_set_lines(bufnr, start_index, end_index, false, lines)
		return max_line_nr, end_index
	end
end

local function insert_and_highlight_lines(line_hunks, last_lines, start_index, end_index, bufnr)
	local max_line_nr = end_index
	for _, line_hunk in ipairs(line_hunks) do
		local max_line_nr, prev_end = insert_line(bufnr, start_index, line_hunk.prev, max_line_nr)
		local max_line_nr, current_end = insert_line(bufnr, prev_end, line_hunk.current, max_line_nr)
		local max_line_nr, new_end = insert_line(bufnr, current_end, line_hunk.new, max_line_nr)
		for i = prev_end, (prev_end + #line_hunk.current - 1) do
			vim.api.nvim_buf_add_highlight(bufnr, -1, "DiffDelete", i, 0, -1)
		end
		for i = current_end, (current_end + #line_hunk.new - 1) do
			vim.api.nvim_buf_add_highlight(bufnr, -1, "DiffAdd", i, 0, -1)
		end

		start_index = new_end
		end_index = max_line_nr
	end

	insert_line(bufnr, start_index, last_lines, end_index)
end

local function get_function_node()
	local function_node = vim.treesitter.get_node()
	if function_node == nil then
		error("No treesitter parser")
	end

	while function_node ~= nil and function_node:type() ~= "function_declaration" do
		function_node = function_node:parent()
	end

	return function_node
end

local function get_function_lines_and_range()
	local ts_node = get_function_node()
	if ts_node == nil then
		error("Could not find function")
	end

	local range = vim.treesitter.get_range(ts_node)
	local start_row = range[1]
	local end_row = range[4] + 1
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, true)
	return lines, range
end

local function get_diff(current_lines, new_lines)
	-- function printTableEntries(table)
	-- 	for key, value in pairs(table) do
	-- 		print(key, value)
	-- 	end
	-- end
	-- printTableEntries(current_lines)
	-- printTableEntries(new_lines)
	local current_lines_joined = table.concat(current_lines, "\n")
	local new_lines_joined = table.concat(new_lines, "\n")

	return vim.diff(current_lines_joined, new_lines_joined, { result_type = "indices" })
end

local function diff_lines(current_lines, new_lines, start_row, end_row, bufnr)
	local diff_hunk = get_diff(current_lines, new_lines)
	local line_hunks, last_lines = hunks_to_line_hunks(current_lines, new_lines, diff_hunk)
	insert_and_highlight_lines(line_hunks, last_lines, start_row, end_row, bufnr)
	return current_lines, new_lines
end

return {
	get_diff = get_diff,
	diff_lines = diff_lines,
}
