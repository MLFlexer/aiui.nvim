local ModelCollection = require("aiui.ModelCollection")
local namespace = vim.api.nvim_create_namespace("aiui_diff")
local diff = {}

---returns a table of lines, position and buffer number
---@return {lines: string[], start_row: integer, start_col: integer, end_col: integer, end_row: integer, bufnr: integer}
function diff.get_visual_text_selection()
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
function diff.get_visual_line_selection()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local result = {
		start_row = start_pos[2] - 1,
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
	local indices = vim.diff(before_joined, after_joined, { result_type = "indices" })
	if indices == nil then
		error("Could not create indices for diff")
	end
	return indices
end

---Creates text hunks and full text for highlighting
---If there is a bug in this code there are tests *USE THEM*.
---If the function seems complicated it is because it it... sorry...
---@param index_list integer[][]
---@param before string[]
---@param after string[]
---@return { unchanged: integer[], before: integer[], after: integer[]}[]
---@return string[]
function diff.indices_to_hunks(index_list, before, after)
	local diff_lines = {}
	local line_hunks = {}
	local hunk_start = 1

	local function add_unchanged(from, to, hunk)
		local start = #diff_lines + 1
		for i = from, to do
			table.insert(diff_lines, before[i])
		end
		hunk.unchanged = { start, #diff_lines }
	end

	local function add_before(from, to, hunk)
		local start = #diff_lines + 1
		if to > #before then
			to = to - 1
		end

		for i = from, to do
			table.insert(diff_lines, before[i])
		end
		hunk.before = { start, #diff_lines }
	end

	local function add_after(from, to, hunk)
		local start = #diff_lines + 1
		if to > #after then
			to = to - 1
		end

		for i = from, to do
			table.insert(diff_lines, after[i])
		end
		hunk.after = { start, #diff_lines }
	end

	for _, index in ipairs(index_list) do
		local hunk = {}
		local overwrite_hunk_val = -1

		local count_unchanged = index[1] - hunk_start
		local end_unchanged = hunk_start + count_unchanged

		local start_a = index[1]
		local count_a = index[2]
		local end_a = start_a + count_a

		local start_b = index[3]
		local count_b = index[4]
		local end_b = start_b + count_b

		if start_a == end_a then
			if start_a == 0 then
				-- No lines from a is removed
				-- No unchanged lines are added
				-- Everything from b is added
				add_after(start_b, end_b - 1, hunk)
			else
				-- add unchanged lines
				-- add everything from b
				add_unchanged(hunk_start, end_unchanged, hunk)
				add_after(start_b, end_b - 1, hunk)
				overwrite_hunk_val = end_unchanged + 1
			end
		elseif start_a == 1 and end_a == #before + 1 then
			-- Everything from a is removed

			-- No unchanged lines are added
			-- If b is not empty add it
			add_before(start_a, end_a, hunk)

			if count_b > 0 then
				add_after(start_b, end_b, hunk)
			end
		elseif start_a == #before and end_a == #before + 1 then
			if before[start_a] == after[start_b] then
				-- add unchanged lines + before[start_a]
				-- add lines from b
				add_unchanged(hunk_start, end_unchanged, hunk)
				add_after(start_b + 1, end_b - 1, hunk)
			else
				-- add unchanged
				-- remove line from a
				-- add lines from b
				add_unchanged(hunk_start, end_unchanged - 1, hunk)
				add_before(start_a, end_a - 1, hunk)
				add_after(start_b, end_b - 1, hunk)
			end
		elseif end_a == #before + 1 then
			-- Add all unchanged lines
			-- remove a lines from start_a to and including the last line
			-- add b
			add_unchanged(hunk_start, end_unchanged, hunk)
			add_before(start_a + 1, end_a - 1, hunk)
			if count_b > 0 then
				if count_b > 1 then
					add_after(start_b, end_b, hunk)
				end
			end
		elseif start_a == 1 then
			--remove from start to end a
			-- add b
			add_before(start_a, end_a - 1, hunk)
			if count_b > 0 then
				add_after(start_b, end_b - 1, hunk)
			end
		else
			-- add unchanged lines
			-- remove from start to end_a
			-- add b
			add_unchanged(hunk_start, end_unchanged - 1, hunk)
			add_before(start_a, end_a - 1, hunk)
			if count_b > 0 then
				add_after(start_b, end_b - 1, hunk)
			end
		end

		if overwrite_hunk_val > -1 then
			hunk_start = overwrite_hunk_val
			overwrite_hunk_val = -1
		else
			hunk_start = start_a + count_a
		end

		if hunk_start < 1 then
			hunk_start = 1
		end
		table.insert(line_hunks, hunk)
	end

	-- add lines after last diff
	for i = hunk_start, #before, 1 do
		table.insert(diff_lines, before[i])
	end
	return line_hunks, diff_lines
end

function diff.insert_and_highlight_diff(bufnr, start_row, end_row, before, after)
	vim.print("THIS IS THE BEFORE")
	vim.print(vim.inspect(before))
	vim.print("THIS IS THE AFTER")
	vim.print(vim.inspect(after))
	local indices = diff.get_diff_indices(before, after)
	local line_hunks, diff_lines = diff.indices_to_hunks(indices, before, after)
	-- if start_row == 1 then
	-- 	vim.api.nvim_buf_set_lines(bufnr, 0, #before, false, diff_lines)
	-- else
	print("Start_row: " .. start_row)
	print("#before: " .. #before)
	print("#diff_lines: " .. #diff_lines)
	print("line_hunks: ")
	print(vim.inspect(line_hunks))
	vim.api.nvim_buf_set_lines(bufnr, start_row, end_row, false, diff_lines)
	-- end
	start_row = start_row - 1
	for _, hunk in ipairs(line_hunks) do
		if hunk.before then
			vim.api.nvim_buf_set_extmark(bufnr, namespace, start_row + hunk.before[1], 0, {
				end_row = start_row + hunk.before[2],
				line_hl_group = "DiffDelete",
			})
			-- vim.highlight.range(
			-- 	bufnr,
			-- 	namespace,
			-- 	"DiffDelete",
			-- 	{ start_row + hunk.before[1], 0 },
			-- 	{ start_row + hunk.before[2], 2147483646 },
			-- 	{ inclusive = false }
			-- )
		end
		if hunk.after then
			vim.api.nvim_buf_set_extmark(
				bufnr,
				namespace,
				start_row + hunk.after[1],
				0,
				{ end_row = start_row + hunk.after[2], line_hl_group = "DiffAdd" }
			)
			-- print("start: " .. start_row + hunk.after[1])
			-- print("end: " .. start_row + hunk.after[2])
			-- vim.highlight.range(
			-- 	bufnr,
			-- 	namespace,
			-- 	"DiffAdd",
			-- 	{ start_row + hunk.after[1], 0 },
			-- 	{ start_row + hunk.after[2], 2147483646 },
			-- 	{ inclusive = false }
			-- )
		end
	end
	return #diff_lines
end

function diff.diff_prompt(prompt, instance, response_formatter)
	local line_selection = diff.get_visual_line_selection()
	print("THIS IS THE LINES SELECTED")
	vim.print(vim.inspect(line_selection))
	prompt = { prompt, vim.fn.join(line_selection.lines, "\n") }

	local function result_handler(result_lines)
		result_lines = response_formatter(result_lines)
		local num_diff_lines = diff.insert_and_highlight_diff(
			line_selection.bufnr,
			line_selection.start_row,
			line_selection.end_row,
			line_selection.lines,
			result_lines
		)
		local confirm = vim.fn.input("Replace? (y): ")
		vim.api.nvim_buf_clear_namespace(
			line_selection.bufnr,
			namespace,
			line_selection.start_row,
			line_selection.start_row + num_diff_lines
		)

		if confirm:lower() == "y" or confirm:lower() == "yes" then
			vim.api.nvim_buf_set_lines(
				line_selection.bufnr,
				line_selection.start_row,
				line_selection.start_row + num_diff_lines,
				true,
				result_lines
			)
		else
			vim.api.nvim_buf_set_lines(
				line_selection.bufnr,
				line_selection.start_row,
				line_selection.start_row + num_diff_lines,
				false,
				line_selection.lines
			)
		end
	end
	local function error_handler(error)
		error("FAILED REQUEST")
	end

	result_handler({
		"-- Function to calculate the nth number in the Fibonacci sequence",
		"function fibonacci(n)",
		"\t-- Base case: if n is less than or equal to 0, return 0",
		"\tif n <= 0 then",
		"\t\treturn 0",
		"\t-- Base case: if n is equal to 1, return 1",
		"\telseif n == 1 then",
		"\t\treturn 1",
		"\t-- Recursive case: return the sum of the previous two numbers in the sequence",
		"\telse",
		"\t\treturn fibonacci(n - 1) + fibonacci(n - 2)",
		"\tend",
		"end",
	})

	-- ModelCollection:request_response(instance, prompt, result_handler, error_handler)
end

return diff
