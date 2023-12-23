local api = vim.api

---@alias WindowOpts { relative: string, row: integer, col: integer, width: integer, height: integer, border: string, style: string, title: string, title_pos: string,}

---@alias InputWindow {window_handle: integer, buffer_handle: integer, window_opts: WindowOpts, keymaps: function[]}
---@alias OutputWindow {window_handle: integer, buffer_handle: integer, window_opts: WindowOpts, keymaps: function[]}

---@class Chat
---@field input InputWindow
---@field output OutputWindow
---@field is_hidden boolean
local Chat = {}

function Chat:new()
	local width = math.floor(vim.o.columns / 3)
	local output_height = math.floor(vim.o.lines * 0.8)
	local output_window_opts = {
		relative = "win",
		row = 0,
		col = vim.o.columns,
		width = width,
		height = output_height,
		border = "rounded",
		style = "minimal",
		title = "OUTPUT",
		title_pos = "center",
	}
	local output_buffer = api.nvim_create_buf(false, false)
	self.output = {
		window_opts = output_window_opts,
		buffer_handle = output_buffer,
		window_handle = api.nvim_open_win(output_buffer, true, output_window_opts),
	}
	local input_window_opts = {
		relative = "win",
		row = output_height + 4,
		col = vim.o.columns,
		width = width,
		height = vim.o.lines - output_height - 4,
		border = "rounded",
		style = "minimal",
		title = "INPUT",
		title_pos = "center",
	}
	local input_buffer = api.nvim_create_buf(false, false)
	self.input = {
		window_opts = input_window_opts,
		buffer_handle = input_buffer,
		window_handle = api.nvim_open_win(input_buffer, true, input_window_opts),
	}
end

function Chat:show()
	self.output.window_handle = vim.api.nvim_open_win(self.output.buffer_handle, true, self.output.window_opts)
	self.input.window_handle = vim.api.nvim_open_win(self.input.buffer_handle, true, self.input.window_opts)
end

function Chat:hide()
	vim.api.nvim_win_hide(self.output.window_handle)
	vim.api.nvim_win_hide(self.input.window_handle)
end

function Chat:toggle()
	if self.is_hidden then
		self:show()
		self.is_hidden = false
	else
		self:hide()
		self.is_hidden = true
	end
end

vim.api.nvim_create_user_command("AN", function()
	vim.print(api.nvim_list_wins())
	Chat:new()
	Chat:set_keymaps({ Chat:make_keymap("n", "<CR>", function()
		Chat:request_model()
	end, {}) }, {})
	Chat:apply_autocmd()
	vim.print(api.nvim_list_wins())
end, {})

vim.api.nvim_create_user_command("AT", function()
	vim.print(api.nvim_list_wins())
	Chat:toggle()
	vim.print(api.nvim_list_wins())
end, {})

return Chat
