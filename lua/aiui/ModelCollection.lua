---@alias client_list ModelClient[]

---alias agent {agent_name: string, system_prompt: string}
---alias agent_list agent[]

---key: agent name, value: system prompt
---@alias agent_map table<string, string>

---alias Model {model_name: string, client: ModelClient}
---alias model_list Model[]

---key: model name, value: client
---@alias model_map table<string, ModelClient>

---@alias instance {name: string, model: string, context: any[], agent: string}
---@alias instance_list instance[]

---@class ModelCollection
---@field clients client_list
---@field models model_map
---@field agents agent_map
---@field instances instance_list

local ModelCollection = { agents = {}, clients = {}, instances = {}, models = {} }

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

---@param clients client_list
function ModelCollection:add_clients(clients)
	for _, client in ipairs(clients) do
		table.insert(self.clients, client)
	end
end

---Request response to msg_lines for an instance
---@param instance instance
---@param msg_lines string[]
---@param result_handler result_handler
---@param error_handler error_handler
function ModelCollection:request_response(instance, msg_lines, result_handler, error_handler)
	local client = self.models[instance.model]
	client:request(
		instance.model,
		msg_lines,
		self.agents[instance.agent],
		instance.context,
		result_handler,
		error_handler,
		function(new_context)
			instance.context = client.context_handler(new_context, instance.context)
		end
	)
end

return ModelCollection
