local diagnostics = {}

function diagnostics.get_current_line_diagnostics()
	local line = vim.fn.line(".")
	local diagnostics = vim.diagnostic.get(0, { lnum = line - 1 })

	local node = vim.treesitter.get_node()
	while node:parent() ~= node:root() do
		node = node:parent()
	end

	-- local start_row, _, end_row, _ = vim.treesitter.get_node_range(node)

	-- local text = vim.treesitter.get_node_text(node, 0)
	-- P(text)
	P(diagnostics)
	return { diagnostics = diagnostics, ts_node = node }
end

local function severity_to_text(severity)
	if severity == vim.diagnostic.severity.ERROR then
		return "error"
	elseif severity == vim.diagnostic.severity.WARN then
		return "warning"
	elseif severity == vim.diagnostic.severity.INFO then
		return "info"
	elseif severity == vim.diagnostic.severity.HINT then
		return "hint"
	else
		error("unsupported severity of type: " .. severity)
	end
end

function diagnostics.make_prompt(diagnostics, ts_node)
	local text = vim.treesitter.get_node_text(ts_node, 0)
	local filetype = vim.api.nvim_get_option_value("filetype", { buf = 0 })
	local prompt_list = {
		string.format("fix the errors in the %s code:\n```%s```\n", filetype, text),
	}

	for _, diagnostic in ipairs(diagnostics) do
		if diagnostic.severity == vim.diagnostic.severity.ERROR then
			table.insert(
				prompt_list,
				string.format(
					"error on line %s to %s, column %s to %s:\n%s\n",
					diagnostic.lnum,
					diagnostic.end_lnum,
					diagnostic.col,
					diagnostic.end_col,
					diagnostic.message
				)
			)
		end
	end
	return prompt_list
end

return diagnostics
