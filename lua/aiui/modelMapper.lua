---@alias model_metadata {name: string, model: string, interface_key: string, system_msg: string, context: any, context_handler: function}

---@class ModelMapper
---@field private instance_table table<string, model_metadata>
---@field private interface_table table<string, ModelAPI>
local ModelMapper = { interface_table = {}, instance_table = {} }

---@private
---@param model_interface ModelAPI
function ModelMapper:add_model_interface(model_interface)
	self.interface_table[model_interface.name] = model_interface
end

---@private
---@param model model_metadata
function ModelMapper:add_model_instance(model)
	self.interface_table[model.name] = model
end

---@param model_name string
---@param request_msg string[]
---@param result_handler result_handler
---@param error_handler error_handler
function ModelMapper:request(model_name, request_msg, result_handler, error_handler)
	local model_instance = self.instance_table[model_name]
	local model_interface = self.interface_table[model_instance.interface_key]
	model_interface:request(
		model_name,
		request_msg,
		model_instance.system_msg,
		model_instance.context,
		result_handler,
		error_handler,
		model_instance.context_handler
	)
end

return ModelMapper
