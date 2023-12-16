local util = require("aiui.util")
local nui_event = require("nui.utils.autocmd").event
local Popup = require("nui.popup")
local Layout = require("nui.layout")

-- telescope dependencies
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local chat_directory = "$HOME/.aiui_chats"

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

---@alias Chat {model: Model, name: string, output: string[]}
---@alias keymap { mode: string, key: string, handler: function, opts: table | nil }

---@class ChatWindow
---@diagnostic disable-next-line: undefined-doc-name
---@field layout NuiLayout | nil
---@field chats Chat[]
---@field current_chat Chat
---@field keymaps { input: keymap[], output: keymap[] }
---@field models Model[]
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
---@param models Model[]
---@param starter_model Model
---@param keymaps { input: keymap[], output: keymap[] }
---@return ChatWindow
function ChatWindow:new(models, starter_model, keymaps)
	if instance == nil then
		local new_chat_window = ChatWindow
		setmetatable(new_chat_window, { __index = self })
		new_chat_window.chats = {}
		new_chat_window.models = models
		new_chat_window.keymaps = keymaps
		new_chat_window.current_chat = { model = starter_model, output = {} }
		table.insert(new_chat_window.chats, new_chat_window.current_chat)

		instance = new_chat_window
	end
	return instance
end

---@param model Model
function ChatWindow:add_model(model)
	table.insert(self.models, model)
end

function ChatWindow:apply_keymaps()
	for _, keymap in pairs(self.keymaps.input) do
		self.input:map(keymap.mode, keymap.key, keymap.handler, keymap.opts)
	end
	for _, keymap in pairs(self.keymaps.output) do
		self.output:map(keymap.mode, keymap.key, keymap.handler, keymap.opts)
	end
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
	vim.print("THIS IS FROM SAVE CURRENT CHAT")
	vim.print(vim.inspect(self))
	if self.output == nil then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(self.output.bufnr, 0, -1, false)
	if lines[1] == "" and #lines == 1 then
		return
	end

	local currentTime = os.time()
	local timestampFormat = "%Y-%m-%d_%H-%M"
	local timestampString = os.date(timestampFormat, currentTime)

	local command = string.format("write! %s/%s/%s.md", chat_directory, self.current_chat.model.name, timestampString)
	vim.api.nvim_buf_call(self.output.bufnr, function()
		vim.cmd(command)
	end)

	-- Write context to file
	if #self.current_chat.model.context > 0 then
		---@type string | nil
		local json_context = vim.json.encode(self.current_chat.model.context)
		if json_context ~= nil and #json_context > 1 then
			local success, error_msg = vim.fn.mkdir(chat_directory, "p")
			if success == 0 then
				error(error_msg)
				return
			end

			local file = io.open(
				string.format("%s/%s/%s.json", chat_directory, self.current_chat.model.name, timestampString),
				"w"
			)
			if file ~= nil then
				file:write(json_context)
				file:close()
			else
				error(
					"file is nil: "
						.. string.format(
							"write! %s/%s/%s.json",
							chat_directory,
							self.current_chat.model.name,
							timestampString
						)
				)
			end
		else
			error("could not encode context to json")
		end
	end
end

---@param file_path string
function ChatWindow:load_chat(file_path)
	local command = string.format(":edit %s", file_path)
	vim.api.nvim_buf_call(self.output.bufnr, function()
		vim.cmd(command)
	end)
end

---@param chat Chat
function ChatWindow:start_chat(chat)
	vim.api.nvim_buf_set_lines(self.output.bufnr, 0, -1, false, chat.output)
	vim.api.nvim_buf_set_lines(self.input.bufnr, 0, -1, false, {})

	self.current_chat = chat
end

---@param model Model
function ChatWindow:new_chat(model)
	self:save_current_chat()
	self.current_chat = { model = model, output = {} }
	table.insert(self.chats, self.current_chat)
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

---@param get_response fun(question_lines: string[], result_handler: result_handler, error_handler: error_handler): nil
function ChatWindow:send_message(get_response)
	local input = self.input
	local output = self.output
	if input == nil or output == nil then
		error("Tried to send a message, when the input or output buffer is nil")
	end
	local question_lines = vim.api.nvim_buf_get_lines(input.bufnr, 0, -1, false)
	-- dont do anything if input is only whitespace
	if is_lines_whitespace(question_lines) then
		error("Question is empty")
	end
	vim.api.nvim_buf_set_option(output.bufnr, "readonly", false)
	vim.api.nvim_buf_set_option(output.bufnr, "modifiable", true)

	local num_lines_before = vim.api.nvim_buf_line_count(output.bufnr)
	vim.api.nvim_buf_set_lines(output.bufnr, -1, -1, false, question_lines)
	util.highlight_lines(output.bufnr, num_lines_before, num_lines_before + #question_lines - 1, "DiffChange")
	vim.api.nvim_buf_set_option(output.bufnr, "readonly", true)
	vim.api.nvim_buf_set_option(output.bufnr, "modifiable", false)
	local output_window_id = vim.fn.bufwinid(output.bufnr)
	vim.api.nvim_win_set_cursor(output_window_id, { vim.api.nvim_buf_line_count(output.bufnr), 0 })
	vim.api.nvim_buf_set_lines(input.bufnr, 0, -1, false, {})

	local function result_handler(response_lines)
		vim.api.nvim_buf_set_option(output.bufnr, "readonly", false)
		vim.api.nvim_buf_set_option(output.bufnr, "modifiable", true)
		vim.api.nvim_buf_set_lines(output.bufnr, -1, -1, false, response_lines)
		vim.api.nvim_buf_set_option(output.bufnr, "readonly", true)
		vim.api.nvim_buf_set_option(output.bufnr, "modifiable", false)
		vim.api.nvim_win_set_cursor(output_window_id, { vim.api.nvim_buf_line_count(output.bufnr), 0 })
		util.highlight_lines(output.bufnr, num_lines_before, num_lines_before + #question_lines - 1, "DiffAdd")
	end

	local function error_handler(_, return_val)
		util.highlight_lines(output.bufnr, num_lines_before, num_lines_before + #question_lines - 1, "DiffDelete")
		error("Could not get an answer, return value was: " .. return_val)
	end

	vim.print("getting response")
	get_response(question_lines, result_handler, error_handler)
end

function ChatWindow:saved_chat_picker()
	print("STARTED")
	return function(opts)
		opts = opts or {}
		pickers
			.new(opts, {
				prompt_title = "Load chat",
				finder = finders.new_oneshot_job({ "find", "~/.aiui_chats", "-type", "f", "-name", '"*.md"' }, opts),
				sorter = conf.generic_sorter(opts),
				attach_mappings = function(prompt_bufnr, _)
					actions.select_default:replace(function()
						actions.close(prompt_bufnr)
						local selection = action_state.get_selected_entry()
						print(selection.value)
						-- vim.schedule(function()
						-- 	self:start_chat(selection.value)
						-- end)
					end)
					return true
				end,
			})
			:find()
	end
end

function ChatWindow:chat_picker()
	return function(opts)
		opts = opts or {}
		pickers
			.new(opts, {
				prompt_title = "Pick a chat",
				finder = finders.new_table({
					results = self.chats,
					entry_maker = function(entry)
						return {
							value = entry,
							display = entry.model.name,
							ordinal = entry.model.name,
						}
					end,
				}),
				sorter = conf.generic_sorter(opts),
				attach_mappings = function(prompt_bufnr, _)
					actions.select_default:replace(function()
						actions.close(prompt_bufnr)
						local selection = action_state.get_selected_entry()
						print(selection.value)
						-- vim.schedule(function()
						-- 	self:start_chat(selection.value)
						-- end)
					end)
					return true
				end,
			})
			:find()
	end
end

function ChatWindow:model_picker(opts)
	vim.print(self.models)
	opts = opts or {}
	pickers
		.new(opts, {
			prompt_title = "Pick a model to start a new chat",
			finder = finders.new_table({
				results = self.models,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.model.name,
						ordinal = entry.model.name,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					vim.schedule(function()
						self:new_chat(selection.value)
					end)
				end)
				return true
			end,
		})
		:find()
end

return ChatWindow
