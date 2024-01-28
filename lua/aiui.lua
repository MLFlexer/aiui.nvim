function P(v)
	print(vim.inspect(v))
	return v
end

vim.api.nvim_create_user_command("AA", function()
	package.loaded["aiui.context"] = nil
	local context = require("aiui.context")
	context.get_cwd_files()
	context.get_buffers()
end, {})

return {
	add_defaults = function()
		require("defaults").initialize()
		require("defaults").add_chat_keybinds()
	end,
}
