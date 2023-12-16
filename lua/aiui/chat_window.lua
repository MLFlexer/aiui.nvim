local util = require("aiui.util")
local Popup = require("nui.popup")
local Layout = require("nui.layout")

-- telescope dependencies
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}
M.chats = {}

local function add_chat_to_picker(chat_window)
	table.insert(M.chats, chat_window)
end
M.add_chat_to_picker = add_chat_to_picker

local function apply_keymaps(chat_window, keymaps)
	for _, keymap in pairs(keymaps.input) do
		chat_window.input:map(keymap.mode, keymap.key, keymap.handler, keymap.opts)
	end
	for _, keymap in pairs(keymaps.output) do
		chat_window.output:map(keymap.mode, keymap.key, keymap.handler, keymap.opts)
	end
end
M.apply_keymaps = apply_keymaps

local function create_chat_window(model)
	local output_window, input_window =
		Popup({
			border = { style = "single", text = { top = model.name } },
			buf_options = { modifiable = false, readonly = true, filetype = "markdown" },
		}), Popup({
			enter = true,
			border = { style = "double", text = { top = "Send a message" } },
		})
	local chat_window = { output = output_window, input = input_window, model = model }
	return chat_window
end
M.create_chat_window = create_chat_window

local output_window, input_window =
	Popup({
		border = { style = "single" },
		buf_options = { modifiable = false, readonly = true, filetype = "markdown" },
	}), Popup({
		enter = true,
		border = { style = "double", text = { top = "Send a message" } },
	})

local layout = Layout(
	{
		position = "100%",
		size = {
			width = 80,
			height = "100%",
		},
	},
	Layout.Box({
		Layout.Box(output_window, { size = "85%" }),
		Layout.Box(input_window, { size = "15%" }),
	}, { dir = "col" })
)

-- have to be here otherwise the show/hide functions will not load the layout appropriately
local hidden = true
local is_mounted = false

local function hide_layout()
	layout:hide()
	hidden = true
end

local function show_layout()
	-- if not is_mounted then
	-- 	layout:mount()
	-- 	is_mounted = true
	-- elseif hidden then
	if hidden then
		layout:mount()
		layout:show()
	end
	hidden = false
end

local function toggle_hidden()
	if hidden then
		show_layout()
	else
		hide_layout()
	end
end
M.toggle_hidden = toggle_hidden

local function mount_chat_window(chat_window)
	local new_layout = Layout.Box({
		Layout.Box(chat_window.output, { size = "85%" }),
		Layout.Box(chat_window.input, { size = "15%" }),
	}, { dir = "col" })
	layout:update(new_layout)
	show_layout()
end
M.mount_chat_window = mount_chat_window

local chat_picker = function(opts)
	opts = opts or {}
	pickers
		.new(opts, {
			prompt_title = "Pick a chat",
			finder = finders.new_table({
				results = M.chats,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.model.name,
						ordinal = entry.model.name,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					vim.schedule(function()
						mount_chat_window(selection.value)
					end)
				end)
				return true
			end,
		})
		:find()
end
M.chat_picker = chat_picker

local function areLinesWhitespace(table)
	for _, str in ipairs(table) do
		if not string.match(str, "^%s*$") then
			return false
		end
	end
	return true
end

local function send_message(chat_window, get_response)
	local input_window = chat_window.input
	local output_window = chat_window.output
	local bufnr = input_window.bufnr
	local question_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	-- dont do anything if input is only whitespace
	if areLinesWhitespace(question_lines) then
		error("Question is empty")
	end
	vim.api.nvim_buf_set_option(output_window.bufnr, "readonly", false)
	vim.api.nvim_buf_set_option(output_window.bufnr, "modifiable", true)

	local num_lines_before = vim.api.nvim_buf_line_count(output_window.bufnr)
	vim.api.nvim_buf_set_lines(output_window.bufnr, -1, -1, false, question_lines)
	util.highlight_lines(output_window.bufnr, num_lines_before, num_lines_before + #question_lines - 1, "DiffChange")
	vim.api.nvim_buf_set_option(output_window.bufnr, "readonly", true)
	vim.api.nvim_buf_set_option(output_window.bufnr, "modifiable", false)
	local output_window_id = vim.fn.bufwinid(output_window.bufnr)
	vim.api.nvim_win_set_cursor(output_window_id, { vim.api.nvim_buf_line_count(output_window.bufnr), 0 })
	vim.api.nvim_buf_set_lines(input_window.bufnr, 0, -1, false, {})

	local function result_handler(response_lines)
		vim.api.nvim_buf_set_option(output_window.bufnr, "readonly", false)
		vim.api.nvim_buf_set_option(output_window.bufnr, "modifiable", true)
		vim.api.nvim_buf_set_lines(output_window.bufnr, -1, -1, false, response_lines)
		vim.api.nvim_buf_set_option(output_window.bufnr, "readonly", true)
		vim.api.nvim_buf_set_option(output_window.bufnr, "modifiable", false)
		vim.api.nvim_win_set_cursor(output_window_id, { vim.api.nvim_buf_line_count(output_window.bufnr), 0 })
		util.highlight_lines(output_window.bufnr, num_lines_before, num_lines_before + #question_lines - 1, "DiffAdd")
	end

	local function error_handler(job, return_val)
		util.highlight_lines(
			output_window.bufnr,
			num_lines_before,
			num_lines_before + #question_lines - 1,
			"DiffDelete"
		)
		error("Could not get an answer, return value was: " .. return_val)
	end

	vim.print("getting response")
	vim.print("getting response")
	get_response(question_lines, result_handler, error_handler)
end
M.send_message = send_message

local function default_keymaps(chat_window, ask_question)
	return {
		input = {
			{
				mode = "n",
				key = "<CR>",
				handler = function()
					send_message(chat_window, ask_question)
				end,
				opts = {},
			},
			{ mode = "n", key = "<esc>", handler = toggle_hidden, opts = {} },
		},
		output = { { mode = "n", key = "<esc>", handler = toggle_hidden, opts = {} } },
	}
end
M.default_keymaps = default_keymaps

M.default_chat = {}
local function set_default_chat(chat_window)
	M.default_chat = chat_window
end
M.set_default_chat = set_default_chat

local function open_default()
	mount_chat_window(M.default_chat)
end
M.open_default = open_default

return M
