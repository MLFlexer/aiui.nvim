local Job = require("plenary.job")

---Get API key from command
---@param command string
---@param set_api_key fun(key: string)
local function get_api_key(command, args, set_api_key)
	Job:new({
		command = command,
		args = args,
		on_exit = function(job, return_val)
			vim.schedule(function()
				if return_val == 0 then
					set_api_key(job:result()[1])
				else
					error("Could not get API-key from " .. command)
				end
			end)
		end,
	}):start()
end

---@param full_array any[]
---@param start_index integer
---@param end_index integer
---@return any[]
local function slice(full_array, start_index, end_index)
	local slice_arr = {}
	local i = start_index
	while i < end_index do
		table.insert(slice_arr, full_array[i])
		i = i + 1
	end

	return slice_arr
end

---@return string[]
---@return integer
---@return integer
---@return integer
local function get_virtual_lines()
	local start_row = vim.print(vim.fn.getpos("'<"))[2]
	local end_row = vim.print(vim.fn.getpos("'>"))[2]
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, true)
	return lines, start_row, end_row, bufnr
end

---@param bufnr integer
---@param start_row integer
---@param end_row integer
---@param hl_group string
local function highlight_lines(bufnr, start_row, end_row, hl_group)
	for i = start_row, end_row do
		vim.api.nvim_buf_add_highlight(bufnr, -1, hl_group, i, 0, -1)
	end
end

---@param directory string
---@param filename string
---@param content string
local function write_to_file(directory, filename, content)
	local success, error_msg = vim.fn.mkdir(directory, "p")
	if success == 0 then
		print("Failed to create directory: " .. error_msg)
		return
	end
	-- Set the file path
	local file_path = directory .. "/" .. filename

	-- Open the file in write mode
	local file = io.open(file_path, "w")

	if file then
		-- Write content to the file
		file:write(content)
		file:close()
		print("File '" .. filename .. "' created successfully at '" .. directory .. "'")
	else
		print("Failed to write to file: " .. file_path)
	end
end

return {
	slice = slice,
	get_virtual_lines = get_virtual_lines,
	highlight_lines = highlight_lines,
	write_to_file = write_to_file,
	get_api_key = get_api_key,
}
