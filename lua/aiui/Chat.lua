local ModelCollection = require("aiui.ModelCollection")
local Waiter = require("aiui.Waiter")
local waiter_namespace = vim.api.nvim_create_namespace("ChatWaiter")

---@alias WindowOpts { relative: string, row: integer, col: integer, width: integer, height: integer, border: string, style: string, title: string, title_pos: string,}

---@alias InputWindow {window_handle: integer, buffer_handle: integer, window_opts: WindowOpts, keymaps: function[]}
---@alias OutputWindow {window_handle: integer, buffer_handle: integer, window_opts: WindowOpts, keymaps: function[], is_empty: boolean, waiter: Waiter}

---@class Chat
---@field input InputWindow
---@field output OutputWindow
---@field instance instance
---@field is_hidden boolean
local Chat = {}

---@param start_instance instance
function Chat:new(start_instance)
	if not next(self) then
		return
	end
	self.instance = start_instance
	local width = math.floor(vim.o.columns / 3)
	local output_height = math.floor(vim.o.lines * 0.8)
	local output_window_opts = {
		relative = "win",
		anchor = "NE",
		row = 0,
		col = vim.o.columns,
		width = width,
		height = output_height,
		border = "rounded",
		style = "minimal",
		title = start_instance.name,
		title_pos = "center",
		-- footer = "OUTPUT",
		-- footer_pos = "center",
	}
	local output_buffer = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_option(output_buffer, "filetype", "markdown")
	self.output = {
		window_opts = output_window_opts,
		buffer_handle = output_buffer,
		window_handle = vim.api.nvim_open_win(output_buffer, false, output_window_opts),
		is_empty = true,
		waiter = Waiter:new({ ".", "..", "..." }),
	}
	local input_window_opts = {
		relative = "win",
		anchor = "SE",
		row = vim.o.lines,
		col = vim.o.columns,
		width = width,
		height = vim.o.lines - output_height - 4,
		border = "rounded",
		style = "minimal",
		title = "INPUT",
		title_pos = "center",
	}
	local input_buffer = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(input_buffer, "filetype", "markdown")
	self.input = {
		window_opts = input_window_opts,
		buffer_handle = input_buffer,
		window_handle = vim.api.nvim_open_win(input_buffer, true, input_window_opts),
	}
	self.is_hidden = false
end

function Chat:show()
	if not self.is_hidden then
		return
	end
	self.is_hidden = false

	local output_height = math.floor(vim.o.lines * 0.8)
	self.output.window_opts.height = output_height
	self.input.window_opts.height = vim.o.lines - output_height - 4

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
			self:request_streamed_response()
		end, {}),
		self:make_keymap("n", "<leader><CR>", function()
			self:request_model()
		end, {}),
		self:make_keymap("n", "<leader>ac", function()
			if self.instance.job then
				-- 130 is some arbitrary value which is choosen to signify
				-- a user has stopped the process
				self.instance.job:shutdown(130, 1)
			end
			self.output.waiter:stop()
			vim.api.nvim_buf_clear_namespace(self.output.buffer_handle, waiter_namespace, 0, -1)
			self:append_output_lines({ "**CANCELLED**" })
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
		callback = function(_)
			self:save_current_chat()
			self:hide()
		end,
	})
	vim.api.nvim_create_autocmd({ "BufDelete", "QuitPre", "BufUnload" }, {
		buffer = self.output.buffer_handle,
		callback = function(_)
			self:save_current_chat()
			self:hide()
		end,
	})
end

function Chat:request_model()
	local prompt = self:get_input_lines()
	if #prompt == 0 then
		return
	end
	self:append_output_lines(prompt, { "# You:" })
	vim.api.nvim_buf_set_lines(self.input.buffer_handle, 0, -1, false, {})

	local function result_handler(result_lines)
		self:append_output_lines(result_lines, { "# Them:" })
		self.output.waiter:stop()
		vim.api.nvim_buf_clear_namespace(self.output.buffer_handle, waiter_namespace, 0, -1)
	end
	local function error_handler(err)
		self.output.waiter:stop()
		vim.api.nvim_buf_clear_namespace(self.output.buffer_handle, waiter_namespace, 0, -1)
		error("FAILED REQUEST")
	end

	self.output.waiter:start(500, function()
		vim.schedule(function()
			vim.api.nvim_buf_clear_namespace(self.output.buffer_handle, waiter_namespace, 0, -1)
			vim.api.nvim_buf_set_extmark(
				self.output.buffer_handle,
				waiter_namespace,
				vim.api.nvim_buf_line_count(self.output.buffer_handle) - 1,
				0,
				{ virt_text = { { self.output.waiter:next_frame(), "" } }, virt_text_pos = "right_align" }
			)
		end)
	end)
	ModelCollection:request_response(self.instance, prompt, result_handler, error_handler)
end

function Chat:request_streamed_response()
	local prompt = self:get_input_lines()
	if #prompt == 0 then
		return
	end
	self:append_output_lines(prompt, { "# You:" })
	vim.api.nvim_buf_set_lines(self.input.buffer_handle, 0, -1, false, {})
	local function chunk_handler(chunk)
		self:append_output_chunk(chunk)
		vim.api.nvim_buf_clear_namespace(self.output.buffer_handle, waiter_namespace, 0, -1)
		vim.api.nvim_buf_set_extmark(
			self.output.buffer_handle,
			waiter_namespace,
			vim.api.nvim_buf_line_count(self.output.buffer_handle) - 2,
			0,
			{ virt_text = { { self.output.waiter:next_frame(), "" } }, virt_text_pos = "right_align" }
		)
	end

	vim.api.nvim_buf_set_lines(self.output.buffer_handle, -1, -1, false, { "# Them:", "" })

	local function result_handler(_)
		vim.schedule(function()
			self.output.waiter:stop()
			vim.api.nvim_buf_clear_namespace(self.output.buffer_handle, waiter_namespace, 0, -1)
		end)
	end

	self.output.waiter:start(500, function()
		vim.schedule(function()
			vim.api.nvim_buf_clear_namespace(self.output.buffer_handle, waiter_namespace, 0, -1)
			vim.api.nvim_buf_set_extmark(
				self.output.buffer_handle,
				waiter_namespace,
				vim.api.nvim_buf_line_count(self.output.buffer_handle) - 2,
				0,
				{ virt_text = { { self.output.waiter:next_frame(), "" } }, virt_text_pos = "right_align" }
			)
		end)
	end)
	ModelCollection:request_streamed_response(self.instance, prompt, chunk_handler, result_handler)
end

---Append text to output buffer
---@param chunk string
function Chat:append_output_chunk(chunk)
	local lines = vim.split(chunk, "\n")
	local row = vim.api.nvim_buf_line_count(self.output.buffer_handle) - 1
	local current_line = vim.api.nvim_buf_get_lines(self.output.buffer_handle, row, row + 1, false)
	local col = 0

	if #current_line > 0 then
		col = string.len(current_line[1])
		vim.api.nvim_buf_set_text(self.output.buffer_handle, row, col, row, col, lines)
	else
		vim.api.nvim_buf_set_text(self.output.buffer_handle, row, col, row, col, lines)
	end
	vim.api.nvim_win_set_cursor(self.output.window_handle, { row + 1, col })
end

function Chat:get_input_lines()
	return vim.api.nvim_buf_get_lines(self.input.buffer_handle, 0, -1, false)
end

---Append lines of output buffer
---@param lines string[]
---@param prefix_lines string[] | nil
function Chat:append_output_lines(lines, prefix_lines)
	local starting_line = -1
	if self.output.is_empty then
		starting_line = 0
		self.output.is_empty = false
	end
	if prefix_lines ~= nil then
		vim.api.nvim_buf_set_lines(self.output.buffer_handle, starting_line, -1, false, prefix_lines)
		starting_line = -1
	end
	vim.api.nvim_buf_set_lines(self.output.buffer_handle, starting_line, -1, false, lines)
	vim.api.nvim_win_set_cursor(
		self.output.window_handle,
		{ vim.api.nvim_buf_line_count(self.output.buffer_handle), 0 }
	)
end

function Chat:save_current_chat()
	if self.output.is_empty then
		return
	end
	if self.instance.file == nil then
		local file_path = ModelCollection:get_instance_path(self.instance)
		local time = os.time()
		local formatted_time = os.date("%Y-%m-%d_%H:%M", time)
		self.instance.file = string.format("%s/%s", file_path, formatted_time)
	end

	vim.api.nvim_buf_call(self.output.buffer_handle, function()
		vim.api.nvim_command(string.format("silent write! ++p %s.md", self.instance.file))
	end)

	local instance_file = io.open(self.instance.file .. ".json", "w")

	if instance_file then
		instance_file:write(vim.json.encode(self.instance))
		instance_file:close()
	else
		error("Could not write save chat instance to " .. instance_file)
	end
end

---changes the instance
---@param instance instance
function Chat:change_instance(instance)
	self:save_current_chat()
	self.instance = instance
	local file_content = {}
	if instance.file ~= nil then
		file_content = vim.fn.readfile(instance.file .. ".md")
	end
	vim.api.nvim_buf_set_lines(self.input.buffer_handle, 0, -1, false, {})
	vim.api.nvim_buf_set_lines(self.output.buffer_handle, 0, -1, false, file_content)
	if #file_content == 0 then
		self.output.is_empty = true
	else
		self.output.is_empty = false
	end

	self.output.window_opts.title = instance.name

	-- FIX: Why does the placement only work with 2 * toggle and not nvim_win_set_config???

	-- vim.api.nvim_win_set_config(self.output.window_handle, self.output.window_opts)
	-- vim.api.nvim_win_set_config(self.input.window_handle, self.input.window_opts)
	self:toggle()
	self:toggle()
end

---Loads a saved chat from a specified file
---@param instance_path string
function Chat:load_from_file(instance_path)
	local instance_file = io.open(instance_path .. ".json", "r")
	local json_str = nil

	if instance_file == nil then
		error(instance_path .. ".json not found or unable to open.")
	end

	json_str = instance_file:read("*a")
	instance_file:close()

	local instance = vim.json.decode(json_str, { object = true, array = true })
	if instance == nil then
		error("Loaded instance was nil")
	end

	self:change_instance(instance)
	ModelCollection:add_instance(instance)
end

return Chat
