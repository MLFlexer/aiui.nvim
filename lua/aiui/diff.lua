local ModelCollection = require("aiui.ModelCollection")
local Waiter = require("aiui.Waiter")
local waiter_namespace = vim.api.nvim_create_namespace("DiffWaiter")

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
		result.lines = vim.api.nvim_buf_get_lines(result.bufnr, result.start_row - 1, result.end_row, false)
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
		start_row = start_pos[2],
		end_row = end_pos[2],
		bufnr = vim.api.nvim_get_current_buf(),
	}

	result.lines = vim.api.nvim_buf_get_lines(result.bufnr, result.start_row - 1, result.end_row, false)
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

---Creates diff hunks for inline diff highlighting
---If there is a bug in this code there are tests **USE THEM**.
---If the function seems complicated it is because it it... sorry...
---@param index_list integer[][]
---@param before string[]
---@param after string[]
---@return { delete: {[1]: integer, [2]: integer, [3]: string[]} | nil, add: integer[] | nil}[]
function diff.indices_to_hunks(index_list, before, after)
	local line_hunks = {}

	local l_num = 0
	for _, index in ipairs(index_list) do
		local hunk = {}

		local start_a = index[1]
		local count_a = index[2]

		local start_b = index[3]
		local count_b = index[4]

		if count_a == 0 then -- only things from b is added
			l_num = start_b - 1
			hunk.add = { l_num, l_num + count_b }
		elseif count_b == 0 then -- only deletes from a
			l_num = start_b
			hunk.delete = { l_num, l_num, vim.list_slice(before, start_a, start_a + count_a - 1) }
		else -- a is deleted, b is added
			if start_a == #before and count_a == 1 then
				-- if it is the last line of a
				if before[start_a] == after[start_b] then
					-- if start of a is the same as start of b
					-- means first line should be unchanged
					count_b = count_b - 1
					l_num = start_b
					hunk.add = { l_num, l_num + count_b }
					l_num = l_num + count_b
				else
					-- the first lines are not the same
					l_num = start_b - 1
					hunk.delete = { l_num, l_num, vim.list_slice(before, start_a, start_a + count_a - 1) }
					hunk.add = { l_num, l_num + count_b }
					l_num = l_num + count_b
				end
			else -- in the middle or top of a
				if start_a == 1 then -- top of a
					hunk.delete = { l_num, l_num, vim.list_slice(before, start_a, start_a + count_a - 1) }
					hunk.add = { l_num, l_num + count_b }
					l_num = l_num + count_b
				else -- middle of a
					if before[start_a] == after[start_b] then
						-- if start of a is the same as start of b
						-- means first line should be unchanged
						l_num = start_b
						start_a = start_a + 1
						count_a = count_a - 1
						hunk.delete = { l_num, l_num, vim.list_slice(before, start_a, start_a + count_a) }
					else
						-- the first lines are not the same
						l_num = start_b - 1
						hunk.delete = { l_num, l_num, vim.list_slice(before, start_a, start_a + count_a - 1) }
						hunk.add = { l_num, l_num + count_b }
						l_num = l_num + count_b
					end
				end
			end
		end
		table.insert(line_hunks, hunk)
	end

	return line_hunks
end

---insert and highlight diff
---@param bufnr integer
---@param start_row integer
---@param end_row integer
---@param after string[]
---@param diff_hunks { delete: {[1]: integer, [2]: integer, [3]: string[]} | nil, add: integer[] | nil}[]
function diff.insert_and_highlight_diff(bufnr, start_row, end_row, after, diff_hunks)
	vim.api.nvim_buf_set_lines(bufnr, start_row, end_row, false, after)

	for _, hunk in ipairs(diff_hunks) do
		if hunk.add then
			-- use range to highlight normal lines, extmark for virtual lines
			vim.highlight.range(
				bufnr,
				namespace,
				"DiffAdd",
				{ start_row + hunk.add[1], 0 },
				{ start_row + hunk.add[2] - 1, 2147483646 },
				{ inclusive = false }
			)
			if hunk.delete then -- add deletes after added lines
				local virt_lines = vim.tbl_map(function(line)
					return { { line, "DiffDelete" } }
				end, hunk.delete[3])
				vim.api.nvim_buf_set_extmark(bufnr, namespace, start_row + hunk.add[2] - 1, 0, {
					virt_lines = virt_lines,
				})
			end
		elseif hunk.delete then
			local virt_lines = vim.tbl_map(function(line)
				return { { line, "DiffDelete" } }
			end, hunk.delete[3])
			vim.api.nvim_buf_set_extmark(bufnr, namespace, math.max(start_row + hunk.delete[1] - 1, 0), 0, {
				virt_lines = virt_lines,
			})
		end
	end
end

---make an inline diff on lines before and after change
---@param bufnr integer
---@param start_row integer
---@param end_row integer
---@param prev_lines string[]
---@param new_lines string[]
function diff.diff_lines_inline(bufnr, start_row, end_row, prev_lines, new_lines)
	local indices = diff.get_diff_indices(prev_lines, new_lines)
	local diff_hunks = diff.indices_to_hunks(indices, prev_lines, new_lines)
	diff.insert_and_highlight_diff(bufnr, start_row, end_row, new_lines, diff_hunks)
end

---accepts all inline diff changes by removing diff highlighting
---and enableing modifing the buffer
---@param bufnr integer
function diff.accept_all_changes(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
end

---prompt a LLM with visual line selection and diff the response inline
---@param instance instance
---@param prompt_formatter fun(lines: string[]): string[]
---@param response_formatter fun(lines: string[]): string[]
function diff.diff_visual_lines(instance, prompt_formatter, response_formatter)
	local selection = diff.get_visual_line_selection()
	if selection == nil or selection.lines == 0 then
		error("Visual line selection not found")
	end
	vim.api.nvim_buf_set_option(selection.bufnr, "modifiable", false)
	local prompt_lines = prompt_formatter(selection.lines)

	local waiter = Waiter:new({ ".", "..", "..." })

	local function result_handler(response_lines)
		response_lines = response_formatter(response_lines)
		vim.api.nvim_buf_set_option(selection.bufnr, "modifiable", true)
		diff.diff_lines_inline(
			selection.bufnr,
			selection.start_row - 1,
			selection.end_row,
			selection.lines,
			response_lines
		)
		waiter:stop()
		vim.api.nvim_buf_clear_namespace(selection.bufnr, waiter_namespace, 0, -1)
	end

	local function error_handler()
		vim.api.nvim_buf_set_option(selection.bufnr, "modifiable", true)
		waiter:stop()
		vim.api.nvim_buf_clear_namespace(selection.bufnr, waiter_namespace, 0, -1)
		error("Could not get response for inline diff")
	end

	waiter:start(500, function()
		vim.schedule(function()
			vim.api.nvim_buf_clear_namespace(selection.bufnr, waiter_namespace, 0, -1)
			vim.api.nvim_buf_set_extmark(
				selection.bufnr,
				waiter_namespace,
				selection.start_row - 1,
				0,
				{ virt_lines = { { { waiter:next_frame(), "" } } } }
			)
		end)
	end)

	ModelCollection:request_response(instance, prompt_lines, result_handler, error_handler)
end

return diff
