local diff = {}

---returns a table of lines, position and buffer number
---@return {lines: string[], start_row: integer, start_col: integer, end_col: integer, end_row: integer, bufnr: integer}
function diff.get_visual_text()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local result = {
		start_row = start_pos[2],
		start_col = start_pos[3],
		end_row = end_pos[2],
		end_col = end_pos[3],
		bufnr = start_pos[1],
	}

	if result.end_col == 2147483647 then
		result.lines = vim.api.nvim_buf_get_lines(result.bufnr, result.start_row, result.end_row, false)
	else
		result.lines = vim.api.nvim_buf_get_text(
			result.bufnr,
			result.start_row,
			result.start_col,
			result.end_row,
			result.end_col,
			{}
		)
	end

	return result
end

---returns a table of lines, position and buffer number
---@return {lines: string[], start_row: integer, end_row: integer, bufnr: integer}
function diff.get_visual_lines()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local result = {
		start_row = start_pos[2],
		end_row = end_pos[2],
		bufnr = start_pos[1],
	}

	result.lines = vim.api.nvim_buf_get_lines(result.bufnr, result.start_row, result.end_row, false)
	return result
end

---@param before string[]
---@param after string[]
---@return integer[][]
function diff.get_diff_indices(before, after)
	local before_joined = table.concat(before, "\n")
	local after_joined = table.concat(after, "\n")
	return vim.diff(before_joined, after_joined, { algorithm = "minimal", result_type = "indices" })
end

return diff
