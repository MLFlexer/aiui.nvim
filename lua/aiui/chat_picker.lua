-- telescope dependencies
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}
---Pick saved chats
---@param chat_window ChatWindow
---@param opts any
local function saved_chat_picker(chat_window, opts)
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
M.saved_chat_picker = saved_chat_picker

---Pick a chat from this session
---@param chat_window ChatWindow
---@param opts any
local function chat_picker(chat_window, opts)
	opts = opts or {}
	pickers
		.new(opts, {
			prompt_title = "Pick a chat",
			finder = finders.new_table({
				results = chat_window.chats,
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
						chat_window:start_chat(selection.value)
					end)
				end)
				return true
			end,
		})
		:find()
end
M.chat_picker = chat_picker

---Spawn fuzzy finder with to pick models
---@param chat_window ChatWindow
---@param opts any
local function model_picker(chat_window, opts)
	opts = opts or {}
	pickers
		.new(opts, {
			prompt_title = "Pick a model to start a new chat",
			finder = finders.new_table({
				results = chat_window.models,
				---@type fun(entry: Model): {value: Model, display: string, ordinal: string}
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.name,
						ordinal = entry.name,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					vim.schedule(function()
						chat_window:new_chat(selection.value)
					end)
				end)
				return true
			end,
		})
		:find()
end
M.model_picker = model_picker

return M
