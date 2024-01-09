---key: agent name, value: system prompt
---@alias agent_map table<string, string>

---key: model name, value: {name: string, client: ModelClient}
---@alias model_map table<string, {name: string, client: ModelClient}>

---@alias instance {name: string, model: string, context: any[], agent: string, file: string | nil}
---@alias instance_list instance[]

---@class ModelCollection
---@field models model_map
---@field agents agent_map
---@field instances instance_list
---@field chat_dir string
local ModelCollection = {
	agents = { default_chat = "You are a coding chatbot, answer short and concise." },
	instances = {},
	models = {},
	chat_dir = vim.fn.expand("$HOME/.aiui/chats"),
}

---@param instance instance
function ModelCollection:add_instance(instance)
	table.insert(self.instances, instance)
end

---@param instances instance_list
function ModelCollection:add_instances(instances)
	for _, instance in ipairs(instances) do
		table.insert(self.instances, instance)
	end
end

---@param agents agent_map
function ModelCollection:add_agents(agents)
	for name, system_prompt in pairs(agents) do
		self.agents[name] = system_prompt
	end
end

---@param models model_map
function ModelCollection:add_models(models)
	for name, model_client in pairs(models) do
		self.models[name] = model_client
	end
end

---returns a list of model names
---@return string[]
function ModelCollection:get_models()
	local models = {}
	for model, _ in pairs(self.models) do
		table.insert(models, model)
	end
	return models
end

---Request response to msg_lines for an instance
---@param instance instance
---@param msg_lines string[]
---@param result_handler result_handler
---@param error_handler error_handler
function ModelCollection:request_response(instance, msg_lines, result_handler, error_handler)
	local model = self.models[instance.model]
	model.client:request(
		model.name,
		msg_lines,
		self.agents[instance.agent],
		instance.context,
		result_handler,
		error_handler,
		function(new_context)
			instance.context = new_context
		end
	)
end

---Request response to msg_lines for an instance
---@param instance instance
---@param msg_lines string[]
---@param chunk_handler chunk_handler
---@param result_handler result_handler
function ModelCollection:request_streamed_response(instance, msg_lines, chunk_handler, result_handler)
	local model = self.models[instance.model]
	model.client:stream_request(
		model.name,
		msg_lines,
		self.agents[instance.agent],
		instance.context,
		chunk_handler,
		function(new_context)
			result_handler(new_context)
			instance.context = new_context
		end
	)
end

---@param instance instance
---@return string
function ModelCollection:get_instance_path(instance)
	local model = self.models[instance.model]
	local client = model.client
	local path = string.format("%s/%s/%s/%s", self.chat_dir, client.name, model.name, instance.name)
	local underscore_path = string.gsub(path, " ", "_")
	return underscore_path
end

return ModelCollection
