local context = {}

function context.get_cwd_files()
	local cwd = vim.fn.getcwd()
	local files = vim.fn.glob(cwd .. "/*", true, true)
	return files
end

function context.get_file_lines(path)
	local success, contents = pcall(vim.fn.readfile, path)
	if success then
		return contents
	else
		error("Could not read file: " .. path)
	end
end

function context.get_buffers()
	local buffers = P(vim.fn.getbufinfo({ buflisted = true }))
	return buffers
end

---insert text at a specified index in prompt
---@param prompt string[]
---@param index_text_pairs { [1]: integer, [2]: string | string[]}[]
---@return string[]
function context.replace_context(prompt, index_text_pairs)
	for _, index_text in ipairs(index_text_pairs) do
		table.insert(prompt, index_text[1], index_text[2])
	end
	return prompt
end

return context
