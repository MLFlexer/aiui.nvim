local util = require("aiui.util")
local nui_event = require("nui.utils.autocmd").event
local Popup = require("nui.popup")
local Layout = require("nui.layout")

-- TODO: Enable user to change this
local chat_directory = vim.fn.expand("$HOME") .. "/.aiui_chats"

---@class NuiPopup
---@field border any NuiPopupBorder
---@field bufnr integer
---@field ns_id integer
---@field win_config any nui_popup_win_config
---@field winid number
---@field map function
---@field on function

---@class NuiLayout
---@field mount function
---@field unmount function
---@field update function
---@field hide function
---@field show function

---@alias Chat {model: string, name: string, file_path: string}
---@alias keymap { mode: string, key: string, handler: function, opts: table | nil }

---@class ChatWindow
---@diagnostic disable-next-line: undefined-doc-name
---@field layout NuiLayout | nil
---@field chats Chat[]
---@field current_chat Chat
---@field keymaps { input: keymap[], output: keymap[] }
---@field model_map table<string, Model>
---@field input NuiPopup | nil
---@field output NuiPopup | nil
local ChatWindow = {}

---@type nil | ChatWindow
local instance = nil

---get instance of singleton ChatWindow
---@return ChatWindow
function ChatWindow:get_instance()
	if instance ~= nil then
		return instance
	else
		error("attempted to get nil instance of ChatWindow")
	end
end

---Create or get ChatWindow instance (singleton)
---@param model_map<string, Model>
---@param starter_model string
---@param keymaps { input: keymap[], output: keymap[] }
---@return ChatWindow
function ChatWindow:new(model_map, starter_model, keymaps)
	if instance == nil then
		local new_chat_window = ChatWindow
		setmetatable(new_chat_window, { __index = self })
		new_chat_window.chats = {}
		new_chat_window.model_map = model_map
		new_chat_window.keymaps = keymaps
		new_chat_window.current_chat = { model = starter_model, name = starter_model, file_path = "" }
		table.insert(new_chat_window.chats, new_chat_window.current_chat)

		instance = new_chat_window
	end
	return instance
end

---@param model Model
function ChatWindow:add_model(model)
	self.model_map[model.name] = model
end

function ChatWindow:apply_keymaps()
	for _, keymap in pairs(self.keymaps.input) do
		self.input:map(keymap.mode, keymap.key, keymap.handler, keymap.opts)
	end
	for _, keymap in pairs(self.keymaps.output) do
		self.output:map(keymap.mode, keymap.key, keymap.handler, keymap.opts)
	end
end

---@private
function ChatWindow:update_output_border_text()
	self.output.border:set_text("top", self.current_chat.model.name, "center")
end

local has_been_mounted = false
local is_shown = false
function ChatWindow:open()
	if is_shown then
		return
	end
	if not has_been_mounted then
		self.output = Popup({
			border = { style = "single", text = { top = self.current_chat.model.name } },
			buf_options = { modifiable = false, readonly = true, filetype = "markdown" },
		})
		self.input = Popup({
			enter = true,
			border = { style = "double", text = { top = "Send a message" } },
		})
		self.layout = Layout(
			{
				position = "100%",
				size = {
					width = 80,
					height = "100%",
				},
			},
			Layout.Box({
				Layout.Box(self.output, { size = "85%" }),
				Layout.Box(self.input, { size = "15%" }),
			}, { dir = "col" })
		)
		self.layout:mount()
		self.output:on({ nui_event.BufDelete, nui_event.WinClosed }, function()
			self:close()
		end)
		self.input:on({ nui_event.BufDelete, nui_event.WinClosed }, function()
			self:close()
		end)
		self:apply_keymaps()
		has_been_mounted = true
	else
		self.layout:show()
	end

	is_shown = true
end

function ChatWindow:close()
	if not is_shown then
		return
	end
	self:save_current_chat()
	self.layout:hide()
	-- self.layout:unmount()
	-- has_been_mounted = false
	is_shown = false
end

function ChatWindow:toggle()
	if is_shown then
		self:close()
	else
		self:open()
	end
end

function ChatWindow:save_current_chat()
	if not is_shown then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(self.output.bufnr, 0, -1, false)
	if #lines == 1 then
		return
	end

	if string.len(self.current_chat.file_path) == 0 then
		local success, error_msg = vim.fn.mkdir(
			string.format("%s/%s/%s", chat_directory, self.current_chat.model.model, self.current_chat.model.name),
			"p"
		)
		if success == 0 then
			error(error_msg)
			return
		end

		local currentTime = os.time()
		local timestampFormat = "%Y-%m-%d_%H-%M"
		local timestampString = os.date(timestampFormat, currentTime)
		self.current_chat.file_path = string.format(
			"%s/%s/%s/%s.md",
			chat_directory,
			self.current_chat.model.model,
			self.current_chat.model.name,
			timestampString
		)
	end

	vim.api.nvim_buf_call(self.output.bufnr, function()
		vim.cmd("write! " .. self.current_chat.file_path)
	end)

	-- Write context
	if #self.current_chat.model.context > 0 then
		---@type string | nil
		local json_context = vim.json.encode(self.current_chat.model.context)
		if json_context ~= nil and #json_context > 1 then
			local file = io.open(self.current_chat.file_path:gsub("%.md$", ".json"), "w")
			if file ~= nil then
				file:write(json_context)
				file:close()
			else
				error("file is nil: " .. self.current_chat.file_path:gsub("%.md$", ".json"))
			end
		else
			error("could not encode context to json")
		end
	end
end

---Exstract model and name from file path
---@param file_path string
---@return string
---@return string
local function get_model_name_from_file_path(file_path)
	local model, name = file_path:match("/([^/]+)/([^/]+)/([^/]+)%.md$")
	if model and name then
		return model, name
	else
		error("Could not exstract model and name from: " .. file_path)
	end
end

---@param file_path string
function ChatWindow:load_chat(file_path)
	local model, name = get_model_name_from_file_path(file_path)
	local chat = { model = model, name = name, file_path = file_path }
	self:start_chat(chat)
end

---@param chat Chat
function ChatWindow:start_chat(chat)
	self:open()
	if self.current_chat.file_path == chat.file_path then
		return
	end
	self:save_current_chat()
	self.current_chat = chat
	self:update_output_border_text()

	vim.print("current_chat")
	vim.print(vim.inspect(self.current_chat))
	vim.print("chat")
	vim.print(vim.inspect(chat))
	vim.print("chats")
	vim.print(vim.inspect(self.chats))

	vim.api.nvim_buf_set_option(self.output.bufnr, "modifiable", true)
	if string.len(chat.file_path) == 0 then
		vim.api.nvim_buf_set_lines(self.output.bufnr, 0, -1, false, {})
		vim.api.nvim_buf_set_lines(self.input.bufnr, 0, -1, false, {})
	else
		vim.api.nvim_buf_call(self.output.bufnr, function()
			local command = string.format("edit %s", chat.file_path)
			vim.cmd(command)
		end)
		vim.api.nvim_buf_set_lines(self.input.bufnr, 0, -1, false, {})
	end
	vim.api.nvim_buf_set_option(self.output.bufnr, "modifiable", false)
end

---@param model Model
function ChatWindow:new_chat(model)
	self:open()
	self:save_current_chat()
	self.current_chat = { model = model, file_path = "" }
	table.insert(self.chats, self.current_chat)
	self:update_output_border_text()

	vim.api.nvim_buf_set_option(self.output.bufnr, "modifiable", true)
	vim.api.nvim_buf_set_lines(self.output.bufnr, 0, -1, false, {})
	vim.api.nvim_buf_set_lines(self.input.bufnr, 0, -1, false, {})
	vim.api.nvim_buf_set_option(self.output.bufnr, "modifiable", false)
end

---@param lines string[]
---@return boolean
local function is_lines_whitespace(lines)
	for _, str in ipairs(lines) do
		if not string.match(str, "^%s*$") then
			return false
		end
	end
	return true
end

function ChatWindow:send_message()
	local input = self.input
	local output = self.output
	if input == nil or output == nil then
		error("Tried to send a message, when the input or output buffer is nil")
	end
	local question_lines = vim.api.nvim_buf_get_lines(input.bufnr, 0, -1, false)
	-- dont do anything if input is only whitespace
	if is_lines_whitespace(question_lines) then
		return
	end
	vim.api.nvim_buf_set_option(output.bufnr, "modifiable", true)
	local num_lines_before = vim.api.nvim_buf_line_count(output.bufnr)
	vim.api.nvim_buf_set_lines(output.bufnr, -1, -1, false, question_lines)
	util.highlight_lines(output.bufnr, num_lines_before, num_lines_before + #question_lines - 1, "DiffChange")
	vim.api.nvim_buf_set_option(output.bufnr, "modifiable", false)

	local output_window_id = vim.fn.bufwinid(output.bufnr)
	vim.api.nvim_win_set_cursor(output_window_id, { vim.api.nvim_buf_line_count(output.bufnr), 0 })
	vim.api.nvim_buf_set_lines(input.bufnr, 0, -1, false, {})

	local function result_handler(response_lines)
		vim.api.nvim_buf_set_option(output.bufnr, "modifiable", true)
		vim.api.nvim_buf_set_lines(output.bufnr, -1, -1, false, response_lines)
		vim.api.nvim_buf_set_option(output.bufnr, "modifiable", false)
		vim.api.nvim_win_set_cursor(output_window_id, { vim.api.nvim_buf_line_count(output.bufnr), 0 })
		util.highlight_lines(output.bufnr, num_lines_before, num_lines_before + #question_lines - 1, "DiffAdd")
		self:save_current_chat()
	end

	local function error_handler(_, return_val)
		util.highlight_lines(output.bufnr, num_lines_before, num_lines_before + #question_lines - 1, "DiffDelete")
		error("Could not get an answer, return value was: " .. return_val)
	end

	vim.print("getting response")
	self.current_chat.model:ask_question(question_lines, result_handler, error_handler)
	-- get_response(question_lines, result_handler, error_handler)
end

return ChatWindow
