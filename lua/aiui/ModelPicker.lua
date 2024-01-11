-- telescope dependencies
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local previewers = require("telescope.previewers")

local ModelCollection = require("aiui.ModelCollection")

---@class ModelPicker
local ModelPicker = {}

---returns default chat instance
---@param model_name string
---@return instance
local function create_default_instance(model_name)
	local instance = {
		name = model_name,
		model = model_name,
		context = {},
		agent = "default_chat",
		file = nil,
	}
	return instance
end

---Spawn fuzzy finder with to pick models
---@param chat Chat
---@param opts any
function ModelPicker:model_picker(chat, opts)
	opts = opts or {}
	pickers
		.new(opts, {
			prompt_title = "Pick a model to start a new chat",
			finder = finders.new_table({
				results = ModelCollection:get_models(),
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					vim.schedule(function()
						local instance = create_default_instance(selection.value)
						ModelCollection:add_instance(instance)
						chat:change_instance(instance)
					end)
				end)
				return true
			end,
		})
		:find()
end

---Spawn fuzzy finder with to pick instances
---@param chat Chat
---@param opts any
function ModelPicker:instance_picker(chat, opts)
	opts = opts or {}
	local previewer = previewers.new_termopen_previewer({
		get_command = function(entry, status)
			if entry.path == nil then
				return
			else
				-- from: https://github.com/nvim-telescope/telescope.nvim/blob/3466159b0fcc1876483f6f53587562628664d850/lua/telescope/previewers/term_previewer.lua#L31
				return {
					"bat",
					"--pager",
					"less -RS",
					"--style=plain",
					"--color=always",
					"--paging=always",
					entry.path .. ".md",
				}
			end
		end,
		title = "Chat preview",
	})
	pickers
		.new(opts, {
			prompt_title = "Pick a chat to continue",
			finder = finders.new_table({
				results = ModelCollection.instances,
				entry_maker = function(instance)
					return {
						path = instance.file,
						value = instance,
						display = instance.name,
						ordinal = instance.name,
					}
				end,
			}),
			previewer = previewer,
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					vim.schedule(function()
						local instance = selection.value
						chat:change_instance(instance)
					end)
				end)
				return true
			end,
		})
		:find()
end

---Spawn fuzzy finder with to pick saved chats
---@param chat Chat
---@param opts any
function ModelPicker:saved_picker(chat, opts)
	opts = opts or {}
	opts.entry_maker = function(path)
		return {
			value = path,
			-- remove the common prefix path from all displayed paths
			display = string.sub(path, #ModelCollection.chat_dir + 2),
			ordinal = path,
		}
	end
	local find_command =
		{ "fd", "--type", "f", "--color", "never", "-e", "md", ".", ModelCollection.chat_dir, "|", "tac" }
	pickers
		.new(opts, {
			prompt_title = "Pick a saved chat to continue",
			finder = finders.new_oneshot_job(find_command, opts),
			previewer = conf.file_previewer(opts),
			sorter = conf.file_sorter(opts),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					vim.schedule(function()
						local path = selection.value:gsub("%.md$", "")
						chat:load_from_file(path)
					end)
				end)
				return true
			end,
		})
		:find()
end

return ModelPicker
