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
	if not next(self) then
		return
	end
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
	api.nvim_buf_set_option(output_buffer, "filetype", "markdown")
	self.output = {
		window_opts = output_window_opts,
		buffer_handle = output_buffer,
		window_handle = api.nvim_open_win(output_buffer, false, output_window_opts),
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
	api.nvim_buf_set_option(input_buffer, "filetype", "markdown")
	self.input = {
		window_opts = input_window_opts,
		buffer_handle = input_buffer,
		window_handle = api.nvim_open_win(input_buffer, true, input_window_opts),
	}
	self.is_hidden = false
end

function Chat:show()
	vim.print(self.output.window_opts)
	if not self.is_hidden then
		return
	end
	self.is_hidden = false
	-- output has to be shown before input, otherwise the placement will be off
	self.output.window_handle = vim.api.nvim_open_win(self.output.buffer_handle, false, self.output.window_opts)
	self.input.window_handle = vim.api.nvim_open_win(self.input.buffer_handle, true, self.input.window_opts)
end

function Chat:hide()
	if self.is_hidden then
		return
	end
	self.is_hidden = true
	vim.api.nvim_win_hide(self.output.window_handle)
	vim.api.nvim_win_hide(self.input.window_handle)
end

function Chat:toggle()
	if self.is_hidden then
		self:show()
	else
		self:hide()
	end
end

---sets keymaps for the input/output buffer
---@param input_keymaps fun(buffer)[]
---@param output_keymaps fun(buffer)[]
function Chat:set_keymaps(input_keymaps, output_keymaps)
	self.output.keymaps = output_keymaps
	self.input.keymaps = input_keymaps
	self:apply_keymaps()
end

function Chat:apply_keymaps()
	for _, keymap in ipairs(self.input.keymaps) do
		keymap(self.input.buffer_handle)
	end
	for _, keymap in ipairs(self.output.keymaps) do
		keymap(self.output.buffer_handle)
	end
end

---Creates a keymap function
---To be used with set_keymaps()
---@param mode string
---@param lhs string
---@param rhs string | function
---@param opts table
---@return function
function Chat:make_keymap(mode, lhs, rhs, opts)
	return function(buffer)
		opts.buffer = buffer
		vim.keymap.set(mode, lhs, rhs, opts)
	end
end

function Chat:apply_default_keymaps()
	local input_keymaps = {
		self:make_keymap("n", "<ESC>", function()
			self:toggle()
		end, {}),
		self:make_keymap("n", "<CR>", function()
			self:request_model()
		end, {}),
	}
	local output_keymaps = { self:make_keymap("n", "<ESC>", function()
		self:toggle()
	end, {}) }
	self:set_keymaps(input_keymaps, output_keymaps)
	self:apply_keymaps()
end

---Makes sure the windows are hidden when the user uses ":q" or other
---See https://neovim.io/doc/user/autocmd.html#autocmd-events
function Chat:apply_autocmd()
	vim.api.nvim_create_autocmd({ "BufDelete", "QuitPre", "BufUnload" }, {
		buffer = self.input.buffer_handle,
		callback = function(ev)
			vim.print(string.format("input! event fired: %s", vim.inspect(ev)))
			self:hide()
		end,
	})
	vim.api.nvim_create_autocmd({ "BufDelete", "QuitPre", "BufUnload" }, {
		buffer = self.output.buffer_handle,
		callback = function(ev)
			vim.print(string.format("output! event fired: %s", vim.inspect(ev)))
			self:hide()
		end,
	})
end

function Chat:request_model()
	-- FIX: change this function
	vim.print("REQUESTING MODEL")
	vim.api.nvim_buf_set_lines(Chat.input.buffer_handle, 0, -1, false, {})
	vim.api.nvim_buf_set_lines(Chat.output.buffer_handle, -1, -1, false, { "This is a line" })
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