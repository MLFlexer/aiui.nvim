local ModelCollection = require("aiui.ModelCollection")

---@alias WindowOpts { relative: string, row: integer, col: integer, width: integer, height: integer, border: string, style: string, title: string, title_pos: string,}

---@alias InputWindow {window_handle: integer, buffer_handle: integer, window_opts: WindowOpts, keymaps: function[]}
---@alias OutputWindow {window_handle: integer, buffer_handle: integer, window_opts: WindowOpts, keymaps: function[], is_empty: boolean}

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
	vim.print(self.output.window_opts)
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
			self:save_current_chat()
			self:hide()
		end,
	})
	vim.api.nvim_create_autocmd({ "BufDelete", "QuitPre", "BufUnload" }, {
		buffer = self.output.buffer_handle,
		callback = function(ev)
			vim.print(string.format("output! event fired: %s", vim.inspect(ev)))
			self:save_current_chat()
			self:hide()
		end,
	})
end

function Chat:request_model()
	-- FIX: change this function
	vim.print("REQUESTING MODEL")

	local prompt = self:get_input_lines()
	if #prompt == 0 then
		return
	end
	self:append_output_lines(prompt, { "# You:" })
	vim.api.nvim_buf_set_lines(Chat.input.buffer_handle, 0, -1, false, {})
	local function result_handler(result_lines)
		self:append_output_lines(result_lines, { "# them:" })
	end
	local function error_handler(error)
		error("FAILED REQUEST")
	end

	ModelCollection:request_response(self.instance, prompt, result_handler, error_handler)
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
	vim.print(vim.api.nvim_buf_line_count(self.output.buffer_handle))
	vim.print(vim.api.nvim_buf_get_lines(self.output.buffer_handle, 0, -1, false))
	if prefix_lines ~= nil then
		vim.api.nvim_buf_set_lines(self.output.buffer_handle, starting_line, -1, false, prefix_lines)
		starting_line = -1
	end
	vim.api.nvim_buf_set_lines(self.output.buffer_handle, starting_line, -1, false, lines)
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

local function decrypt_file_with_gpg(file_path)
	local command = string.format("gpg --decrypt %s", file_path)
	local handle = io.popen(command)
	local decrypted_text = handle:read("*a")
	handle:close()
	decrypted_text = decrypted_text:gsub("\n$", "")
	return decrypted_text
end

vim.api.nvim_create_user_command("AN", function()
	local test_model = require("testing.models.clients.test_client")
	local ollama_model = require("models.clients.ollama.ollama_curl")
	local mistral_client = require("models.clients.mistral.mistral_curl")
	local openai_client = require("models.clients.openai.openai_curl")
	mistral_client:set_api_key(decrypt_file_with_gpg("/home/mlflexer/.secrets/mistral.txt.gpg"))
	openai_client:set_api_key(decrypt_file_with_gpg("/home/mlflexer/.secrets/open_ai.txt.gpg"))
	ModelCollection:add_models({
		testing_model = { name = "testing_model", client = test_model },
		orca_mini = { name = "orca-mini", client = ollama_model },
		mistral_tiny = { name = "mistral-tiny", client = mistral_client },
		gpt3 = { name = "gpt-3.5-turbo-1106", client = openai_client },
	})
	ModelCollection:add_agents({
		mistral_agent = "You are a chatbot, answer short and concise.",
		gpt3_agent = "You are gpt3, a chatbot, answer short and concise.",
		testing_agent = "testing agent system prompt",
		random_agent = "always respond with a number between 0 and 10.",
	})
	local instance = { name = "Mistral Tiny", model = "mistral_tiny", context = {}, agent = "mistral_agent" }
	-- instance = { name = "ollama instance", model = "orca_mini", context = {}, agent = "random_agent" }
	-- instance = { name = "gpt3 instance", model = "gpt3", context = {}, agent = "gpt3_agent" }
	-- instance = { name = "testing instance2", model = "testing_model", context = {}, agent = "testing_agent" }
	-- -- ModelCollection:add_instance(instance)
	instance = { name = "testing instance", model = "testing_model", context = {}, agent = "testing_agent" }
	-- ModelCollection:add_instance(instance)
	Chat:new(instance)
	Chat:apply_default_keymaps()
	Chat:apply_autocmd()
end, {})

vim.api.nvim_create_user_command("AT", function()
	Chat:toggle()
end, {})

vim.api.nvim_create_user_command("AW", function()
	Chat:save_current_chat()
end, {})

local Picker = require("aiui.ModelPicker")
vim.api.nvim_create_user_command("AMP", function()
	Picker:model_picker(Chat)
end, {})

vim.api.nvim_create_user_command("AIP", function()
	Picker:instance_picker(Chat)
end, {})

vim.api.nvim_create_user_command("ASP", function()
	Picker:saved_picker(Chat)
end, {})

vim.api.nvim_create_user_command("AL", function()
	Chat:load_from_file("/home/mlflexer/.aiui/chats/test_model/testing_model/testing_instance/2023-12-31_13:32")
end, {})

return Chat
