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
	local indices = vim.diff(before_joined, after_joined, { result_type = "indices" })
	if indices == nil then
		error("Could not create indices for diff")
	end
	return indices
end

---Creates text hunks and full text for highlighting
---@param index_list integer[][]
---@param before string[]
---@param after string[]
---@return { index: any, unchanged: integer[], before: integer[], after: integer[]}[] --FIX: Change index to an actual value or remove it
---@return string[]
function diff.indices_to_hunks(index_list, before, after)
	-- print(vim.inspect(index_list))
	-- function diff.indices_to_hunks(index_list)
	local diff_text = {}
	local line_hunks = {}
	local prev_end = 1
	for hunk_nr, index in ipairs(index_list) do
		local hunk = {}

		-- print("prev_end: " .. prev_end)
		-- print(vim.inspect(index))

		local start_a = index[1]
		local end_a = start_a

		if prev_end ~= start_a then
			if hunk_nr > 1 and prev_end == 1 then
				prev_end = 2
			end
			-- table.insert(diff_text, "U")
			for i = prev_end, start_a - 1, 1 do
				-- print("this is the unchanged")
				-- vim.print(vim.inspect(before[i]))
				table.insert(diff_text, before[i])
			end
			hunk.unchanged = { prev_end, start_a }
		end

		if start_a ~= #before then
			-- table.insert(diff_text, "B")
			if index[2] > 0 then
				-- start_a = index[1]
				end_a = index[1] + index[2] - 1
				for i = start_a, end_a, 1 do
					-- print("this is before")
					-- vim.print(vim.inspect(before[i]))
					table.insert(diff_text, before[i])
				end
				hunk.before = { start_a, end_a }
			end
		end

		local start_b = index[3]
		local end_b = start_b
		if index[4] > 0 then
			-- print("this is after")
			-- start_b = index[3]
			end_b = index[3] + index[4] - 1
			-- table.insert(diff_text, "A")
			for i = start_b, end_b, 1 do
				-- vim.print(vim.inspect(after[i]))
				table.insert(diff_text, after[i])
			end
			hunk.after = { start_b, end_b }
		end

		table.insert(line_hunks, hunk)
		-- print(vim.inspect(hunk))
		-- print(vim.inspect(line_hunks))

		if end_a > end_b then
			prev_end = end_a
		else
			prev_end = end_b
		end
	end

	--THIS IS THE OLD

	-- 	local start_a = index[1]
	-- 	local count_a = index[2]
	-- 	local start_b = index[3]
	-- 	local count_b = index[4]
	-- 	local end_a = start_a + count_a
	-- 	local end_b = start_b + count_b
	--
	-- 	-- local unchanged = {}
	-- 	-- for i = prev_end, start_a, 1 do
	-- 	-- 	table.insert(unchanged, before[i])
	-- 	-- end
	-- 	--
	-- 	-- local before_lines = {}
	-- 	-- for i = start_a, end_a, 1 do
	-- 	-- 	table.insert(before_lines, before[i])
	-- 	-- end
	-- 	--
	-- 	-- local after_lines = {}
	-- 	-- for i = start_b, end_b, 1 do
	-- 	-- 	table.insert(after_lines, after[i])
	-- 	-- end
	-- 	--
	-- 	-- table.insert(line_hunks, {
	-- 	-- 	index = index,
	-- 	-- 	unchanged = unchanged,
	-- 	-- 	before = before_lines,
	-- 	-- 	after = after_lines,
	-- 	-- })
	--
	-- 	table.insert(line_hunks, {
	-- 		index = index,
	-- 		unchanged = { prev_end, start_a },
	-- 		before = { start_a, end_a },
	-- 		after = { start_b, end_b },
	-- 	})
	--
	-- 	if prev_end ~= start_a then
	-- 		for i = prev_end, start_a - 1, 1 do
	-- 			print("this is the unchanged")
	-- 			vim.print(vim.inspect(before[i]))
	-- 			table.insert(diff_text, before[i])
	-- 		end
	-- 	end
	--
	-- 	if start_a ~= end_a then
	-- 		for i = start_a, end_a - 1, 1 do
	-- 			print("this is the before")
	-- 			vim.print(vim.inspect(before[i]))
	-- 			table.insert(diff_text, before[i])
	-- 		end
	-- 	end
	--
	-- 	if start_b ~= end_b then
	-- 		for i = start_b, end_b - 1, 1 do
	-- 			print("this is the after")
	-- 			vim.print(vim.inspect(after[i]))
	-- 			table.insert(diff_text, after[i])
	-- 		end
	-- 	end
	--
	-- 	prev_end = end_a
	-- end

	if prev_end == 1 then
		diff_text = before
	-- elseif prev_end + 1 ~= #before then
	elseif prev_end ~= #before then
		-- table.insert(diff_text, "L")
		for i = prev_end + 1, #before, 1 do
			-- print("this is last part")
			-- vim.print(vim.inspect(before[i]))
			table.insert(diff_text, before[i])
		end
	end
	-- print("this is the diff text")
	-- vim.print(vim.inspect(diff_text))

	-- local last_lines = { lines = before, start_row = prev_end, end_row = #before + 1 } -- slice(org_lines, prev_end, #org_lines + 1)
	return line_hunks, diff_text
	--return line_hunks, last_lines
end

return diff
