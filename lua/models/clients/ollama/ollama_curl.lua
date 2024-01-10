local Job = require("plenary.job")

---@class OllamaCurl : ModelClient
local OllamaModel = {
	name = "ollama_curl",
}

local command = "curl"
local args = {
	"-X",
	"POST",
	"http://localhost:11434/api/generate",
	"-d",
	"json request body",
}

---returns a list of models to be used with the MistralAI API
---@return model_map
function OllamaModel:get_default_models()
	local model_map = {}
	model_map["llama2"] = { name = "llama2", client = self }
	model_map["mistral"] = { name = "mistral", client = self }
	model_map["dolphin-phi"] = { name = "dolphin-phi", client = self }
	model_map["phi"] = { name = "phi", client = self }
	model_map["neural-chat"] = { name = "neural-chat", client = self }
	model_map["starling-lm"] = { name = "starling-lm", client = self }
	model_map["codellama"] = { name = "codellama", client = self }
	model_map["llama2-uncensored"] = { name = "llama2-uncensored", client = self }
	model_map["llama2:13b"] = { name = "llama2:13b", client = self }
	model_map["llama2:70b"] = { name = "llama2:70b", client = self }
	model_map["orca-mini"] = { name = "orca-mini", client = self }
	model_map["vicuna"] = { name = "vicuna", client = self }
	model_map["llava"] = { name = "llava", client = self }
	return model_map
end

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
				local response_table = vim.json.decode(job:result()[1], { luanil = { object = true, array = true } })
				if response_table == nil then
					error_handler(job, return_val)
					return
				end
				if response_table.response then
					local response_lines = vim.split(response_table.response, "\n", { trimempty = true })
					result_handler(response_lines)
				end

				if response_table.context then
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
---@return Job
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
		if string.len(system_msg) > 0 then
			request_table.system = system_msg
		end
	else
		request_table.context = context
	end

	local json_body = vim.json.encode(request_table)
	if not json_body then
		error("Could not encode table to json: " .. vim.inspect(request_table))
	end
	local job_args = insert_request_body(json_body, args)
	local job = Job:new({
		command = command,
		args = job_args,
		on_exit = on_exit_request(result_handler, error_handler, context_handler),
	})
	job:start()
	return job
end

---Callback function for when there is stdout, when streaming
---@param chunk_handler chunk_handler
---@param context_handler context_handler
---@return fun(err: string, chunk: string)
local function on_stdout_stream(chunk_handler, context_handler)
	return function(_, line)
		vim.schedule(function()
			local success, chunk_table = pcall(vim.json.decode, line, { luanil = { object = true, array = true } })
			if success then
				if chunk_table == nil then
					error("Empty json object")
				end

				if chunk_table.response then
					chunk_handler(chunk_table.response)
				end
				if chunk_table.context then
					context_handler(chunk_table.context)
				end
			else
				return
			end
		end)
	end
end

---Request streamed response from model API
---@param model_name string
---@param request_msg string[]
---@param system_msg string
---@param context message[]
---@param chunk_handler chunk_handler
---@param context_handler context_handler
---@param result_handler result_handler
---@return Job
function OllamaModel:stream_request(
	model_name,
	request_msg,
	system_msg,
	context,
	chunk_handler,
	context_handler,
	result_handler
)
	local prompt = table.concat(request_msg, "\n")
	local request_table = { model = model_name, prompt = prompt, stream = true }
	if has_empty_context(context) then
		if string.len(system_msg) > 0 then
			request_table.system = system_msg
		end
	else
		request_table.context = context
	end

	local json_body = vim.json.encode(request_table)
	if not json_body then
		error("Could not encode table to json: " .. vim.inspect(request_table))
	end
	local job_args = insert_request_body(json_body, args)
	local job = Job:new({
		command = command,
		args = job_args,
		on_stdout = on_stdout_stream(chunk_handler, context_handler),
		on_exit = result_handler,
	})
	job:start()
	return job
end

return OllamaModel
