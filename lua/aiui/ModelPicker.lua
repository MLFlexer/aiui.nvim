-- telescope dependencies
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

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
	pickers
		.new(opts, {
			prompt_title = "Pick a chat to continue",
			finder = finders.new_table({
				results = ModelCollection.instances,
				entry_maker = function(instance)
					return {
						value = instance,
						display = instance.name,
						ordinal = instance.name,
					}
				end,
			}),
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

return ModelPicker
