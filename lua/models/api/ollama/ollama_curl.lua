local Job = require("plenary.job")

---@class OllamaCurl : ModelAPI
local OllamaModel = {
	name = "ollama_curl",
	command = "curl",
	args = {
		"-X",
		"POST",
		"http://localhost:11434/api/generate",
		"-d",
		"json request body",
	},
}

---@return boolean
local function has_empty_context(context)
	return #context == 0
end

---@param json string
---@param args string[]
---@return string[]
local function insert_request_body(json, args)
	args[5] = json
	return args
end

---Callback function for when a job exits
---@param result_handler result_handler
---@param error_handler error_handler
---@param context_handler context_handler
---@return fun(job: Job, return_value: integer)
local function on_exit_request(result_handler, error_handler, context_handler)
	return function(job, return_val)
		vim.schedule(function()
			if return_val == 0 then
				---@type {response: string, context: number[]} | nil
				local response_table = vim.fn.json_decode(job:result())
				if response_table == nil then
					error_handler(job, return_val)
					return
				end
				local response = response_table.response
				local response_lines = {}
				for line in response:gmatch("[^\n]+") do
					table.insert(response_lines, line)
				end

				result_handler(response_lines)
				if response_table.context ~= nil then
					context_handler(response_table.context)
				end
			else
				error_handler(job, return_val)
			end
		end)
	end
end

---Request response from model API
---@param model_name string
---@param request_msg string[]
---@param system_msg string
---@param context number[]
---@param result_handler result_handler
---@param error_handler error_handler
---@param context_handler context_handler
function OllamaModel:request(
	model_name,
	request_msg,
	system_msg,
	context,
	result_handler,
	error_handler,
	context_handler
)
	local prompt = table.concat(request_msg, "\n")
	local request_table = { model = model_name, prompt = prompt, stream = false }
	if has_empty_context(context) then
		if string.len(system_msg) ~= "" then
			request_table.system = system_msg
		end
	else
		request_table.context = context
	end

	local json_body = vim.json.encode(request_table)
	if not json_body then
		error("Could not encode table to json: " .. vim.inspect(request_table))
	end
	local args = insert_request_body(json_body, self.args)
	Job:new({
		command = self.command,
		args = args,
		on_exit = on_exit_request(result_handler, error_handler, context_handler),
	}):start()
end

---@param new_context number[]
---@return number[]
function OllamaModel.context_handler(new_context, _)
	return new_context
end

return OllamaModel
