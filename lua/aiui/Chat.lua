local ModelCollection = require("aiui.ModelCollection")
local Waiter = require("aiui.Waiter")
local waiter_namespace = vim.api.nvim_create_namespace("ChatWaiter")

---@alias WindowOpts { relative: string, row: integer, col: integer, width: integer, height: integer, border: string, style: string, title: string, title_pos: string,}

---@alias InputWindow {winnr: integer | nil, bufnr: integer, win_opts: WindowOpts, keymaps: function[], win_opts_updater: fun(WindowOpts): WindowOpts}
---@alias OutputWindow {winnr: integer | nil, bufnr: integer, win_opts: WindowOpts, keymaps: function[], is_empty: boolean, waiter: Waiter, chat_headers: {you: string, them: string, interrupted: string}, win_opts_updater: fun(WindowOpts): WindowOpts}

---@class Chat
---@field input InputWindow
---@field output OutputWindow
---@field instance instance
---@field is_hidden boolean
local Chat = {}

---@param start_instance instance
---@param opts nil | {input: {win_opts: WindowOpts, win_opts_updater: fun(WindowOpts): WindowOpts}, output: {win_opts: WindowOpts, waiter: Waiter, chat_headers: {you: string, them: string, interrupted: string}, win_opts_updater: fun(WindowOpts): WindowOpts}}
---@return Chat
function Chat:new(start_instance, opts)
	if not next(self) then
		return self
	end
	self.instance = start_instance

	-- if opts not passed as input
	if not opts then
		opts = { input = {}, output = {} }
	end

	local output_win_opts_updater = opts.output.win_opts_updater
	if not output_win_opts_updater then
		output_win_opts_updater = function(win_opts)
			win_opts.row = 0
			win_opts.col = vim.o.columns
			win_opts.width = math.floor(vim.o.columns / 3)
			win_opts.height = math.floor(vim.o.lines * 0.8)
			return win_opts
		end
	end

	local output_win_opts = opts.output.win_opts
	if not output_win_opts then
		output_win_opts = {
			relative = "win",
			anchor = "NE",
			row = 0,
			col = 0,
			width = 0,
			height = 0,
			border = "rounded",
			style = "minimal",
			title = start_instance.name,
			title_pos = "center",
			-- footer = "OUTPUT",
			-- footer_pos = "center",
		}
	end
	output_win_opts = output_win_opts_updater(output_win_opts)

	local waiter = opts.output.waiter
	if not waiter then
		waiter = Waiter:new({ ".", "..", "..." })
	end

	local output_chat_headers = opts.output.chat_headers
	if not output_chat_headers then
		output_chat_headers = { you = "# You:", them = "# Them:", interrupted = "**CANCELLED**" }
	end

	local output_buffer = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_option(output_buffer, "filetype", "markdown")
	self.output = {
		win_opts = output_win_opts,
		bufnr = output_buffer,
		winnr = nil,
		is_empty = true,
		waiter = waiter,
		win_opts_updater = output_win_opts_updater,
		chat_headers = output_chat_headers,
	}

	local input_win_opts_updater = opts.input.win_opts_updater
	if not input_win_opts_updater then
		input_win_opts_updater = function(win_opts)
			win_opts.row = vim.o.lines
			win_opts.col = vim.o.columns
			win_opts.width = self.output.win_opts.width
			win_opts.height = vim.o.lines - self.output.win_opts.height - 4
			return win_opts
		end
	end

	local input_win_opts = opts.input.win_opts
	if not input_win_opts then
		input_win_opts = {
			relative = "win",
			anchor = "SE",
			row = 0,
			col = 0,
			width = 0,
			height = 0,
			border = "rounded",
			style = "minimal",
			title = "INPUT",
			title_pos = "center",
		}
	end
	input_win_opts = input_win_opts_updater(input_win_opts)

	local input_buffer = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(input_buffer, "filetype", "markdown")
	self.input = {
		win_opts = input_win_opts,
		bufnr = input_buffer,
		winnr = nil,
		win_opts_updater = input_win_opts_updater,
	}
	self.is_hidden = true
	return self
end

function Chat:show()
	if not self.is_hidden then
		return
	end
	self.is_hidden = false

	self.output.win_opts = self.output.win_opts_updater(self.output.win_opts)
	self.input.win_opts = self.input.win_opts_updater(self.input.win_opts)

	-- output has to be shown before input, otherwise the placement will be off
	self.output.winnr = vim.api.nvim_open_win(self.output.bufnr, false, self.output.win_opts)
	self.input.winnr = vim.api.nvim_open_win(self.input.bufnr, true, self.input.win_opts)
end

function Chat:hide()
	if self.is_hidden or self.output.winnr == nil then
		return
	end
	self.is_hidden = true
	vim.api.nvim_win_hide(self.output.winnr)
	vim.api.nvim_win_hide(self.input.winnr)
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
		keymap(self.input.bufnr)
	end
	for _, keymap in ipairs(self.output.keymaps) do
		keymap(self.output.bufnr)
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
		self:make_keymap("n", "<leader>pm", function()
			require("aiui.ModelPicker"):model_picker(self)
		end, {}),
		self:make_keymap("n", "<leader>pl", function()
			require("aiui.ModelPicker"):saved_picker(self)
		end, {}),
		self:make_keymap("n", "<leader>pi", function()
			require("aiui.ModelPicker"):instance_picker(self)
		end, {}),
		self:make_keymap("n", "<leader>ac", function()
			if self.instance.job then
				-- 130 is some arbitrary value which is choosen to signify
				-- a user has stopped the process
				self.instance.job:shutdown(130, 1)
			end
			self.output.waiter:stop()
			vim.api.nvim_buf_clear_namespace(self.output.bufnr, waiter_namespace, 0, -1)
			self:append_output_lines({ self.output.chat_headers.interrupted })
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
		buffer = self.input.bufnr,
		callback = function(_)
			self:save_current_chat()
			self:hide()
		end,
	})
	vim.api.nvim_create_autocmd({ "BufDelete", "QuitPre", "BufUnload" }, {
		buffer = self.output.bufnr,
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
	self:append_output_lines(prompt, { self.output.chat_headers.you })
	vim.api.nvim_buf_set_lines(self.input.bufnr, 0, -1, false, {})

	local function result_handler(result_lines)
		self:append_output_lines(result_lines, { self.output.chat_headers.them })
		self.output.waiter:stop()
		vim.api.nvim_buf_clear_namespace(self.output.bufnr, waiter_namespace, 0, -1)
	end
	local function error_handler(err)
		self.output.waiter:stop()
		vim.api.nvim_buf_clear_namespace(self.output.bufnr, waiter_namespace, 0, -1)
		error("FAILED REQUEST")
	end

	self.output.waiter:start(500, function()
		vim.schedule(function()
			vim.api.nvim_buf_clear_namespace(self.output.bufnr, waiter_namespace, 0, -1)
			vim.api.nvim_buf_set_extmark(
				self.output.bufnr,
				waiter_namespace,
				vim.api.nvim_buf_line_count(self.output.bufnr) - 1,
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
	self:append_output_lines(prompt, { self.output.chat_headers.you })
	vim.api.nvim_buf_set_lines(self.input.bufnr, 0, -1, false, {})
	local function chunk_handler(chunk)
		self:append_output_chunk(chunk)
		vim.api.nvim_buf_clear_namespace(self.output.bufnr, waiter_namespace, 0, -1)
		vim.api.nvim_buf_set_extmark(
			self.output.bufnr,
			waiter_namespace,
			vim.api.nvim_buf_line_count(self.output.bufnr) - 2,
			0,
			{ virt_text = { { self.output.waiter:next_frame(), "" } }, virt_text_pos = "right_align" }
		)
	end

	vim.api.nvim_buf_set_lines(self.output.bufnr, -1, -1, false, { self.output.chat_headers.them, "" })

	local function result_handler(_)
		vim.schedule(function()
			self.output.waiter:stop()
			vim.api.nvim_buf_clear_namespace(self.output.bufnr, waiter_namespace, 0, -1)
		end)
	end

	self.output.waiter:start(500, function()
		vim.schedule(function()
			vim.api.nvim_buf_clear_namespace(self.output.bufnr, waiter_namespace, 0, -1)
			vim.api.nvim_buf_set_extmark(
				self.output.bufnr,
				waiter_namespace,
				vim.api.nvim_buf_line_count(self.output.bufnr) - 2,
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
	local row = vim.api.nvim_buf_line_count(self.output.bufnr) - 1
	local current_line = vim.api.nvim_buf_get_lines(self.output.bufnr, row, row + 1, false)
	local col = 0

	if #current_line > 0 then
		col = string.len(current_line[1])
		vim.api.nvim_buf_set_text(self.output.bufnr, row, col, row, col, lines)
	else
		vim.api.nvim_buf_set_text(self.output.bufnr, row, col, row, col, lines)
	end
	vim.api.nvim_win_set_cursor(self.output.winnr, { row + 1, col })
end

function Chat:get_input_lines()
	return vim.api.nvim_buf_get_lines(self.input.bufnr, 0, -1, false)
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
		vim.api.nvim_buf_set_lines(self.output.bufnr, starting_line, -1, false, prefix_lines)
		starting_line = -1
	end
	vim.api.nvim_buf_set_lines(self.output.bufnr, starting_line, -1, false, lines)
	vim.api.nvim_win_set_cursor(self.output.winnr, { vim.api.nvim_buf_line_count(self.output.bufnr), 0 })
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

	vim.api.nvim_buf_call(self.output.bufnr, function()
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
	vim.api.nvim_buf_set_lines(self.input.bufnr, 0, -1, false, {})
	vim.api.nvim_buf_set_lines(self.output.bufnr, 0, -1, false, file_content)
	if #file_content == 0 then
		self.output.is_empty = true
	else
		self.output.is_empty = false
	end

	self.output.win_opts.title = instance.name

	-- FIX: Why does the placement only work with 2 * toggle and not nvim_win_set_config???

	-- vim.api.nvim_win_set_config(self.output.winnr, self.output.win_opts)
	-- vim.api.nvim_win_set_config(self.input.winnr, self.input.win_opts)
	self:show()
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

	local instance = vim.json.decode(json_str, { luanil = { object = true, array = true } })
	if instance == nil then
		error("Loaded instance was nil")
	end

	self:change_instance(instance)
	ModelCollection:add_instance(instance)
end

return Chat
