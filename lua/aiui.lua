function P(v)
	print(vim.inspect(v))
end

vim.api.nvim_create_user_command("AA", function()
	local diagnostics = require("aiui.diagnostics")
	local tbl = diagnostics.get_current_line_diagnostics()
	P(diagnostics.make_prompt(tbl.diagnostics, tbl.ts_node))
end, {})

return {
	add_defaults = function()
		require("defaults").initialize()
		require("defaults").add_chat_keybinds()
	end,
}
