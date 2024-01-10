local Job = require("plenary.job")

---@class MistralCurl : ModelClient
local MistralModel = {
	name = "mistral_curl",
}

local command = "curl"
local args = {
	"https://api.mistral.ai/v1/chat/completions",
	"-H",
	"Content-Type: application/json",
	"-H",
	"Accept: application/json",
	"-H",
	"mistral api key",
	"-d",
	"json request body",
}

---returns a list of models to be used with the MistralAI API
---@return model_map
function MistralModel:get_default_models()
	local model_map = {}
	model_map["mistral-tiny"] = { name = "mistral-tiny", client = self }
	model_map["mistral-small"] = { name = "mistral-small", client = self }
	model_map["mistral-medium"] = { name = "mistral-medium", client = self }
	return model_map
end

---@param api_key string
function MistralModel:set_api_key(api_key)
	args[7] = "Authorization: Bearer " .. api_key
end

---@param json string
---@param args string[]
---@return string[]
local function insert_request_body(json, args)
	args[9] = json
	return args
end

---@param context message[]
---@return boolean
local function has_empty_context(context)
	return #context == 0
end

---Callback function for when a job exits
---@param result_handler result_handler
---@param error_handler error_handler
---@param context_handler context_handler
---@param context message[]
---@return fun(job: Job, return_value: integer)
local function on_exit_request(result_handler, error_handler, context_handler, context)
	return function(job, return_val)
		if return_val == 130 then
			return
		elseif return_val == 0 then
			vim.schedule(function()
				---@type {error: nil | string, choices: {message: message}} | nil
				local response_table = vim.json.decode(job:result()[1], { luanil = { object = true, array = true } })
				if response_table == nil then
					error_handler(job, return_val)
					return
				elseif response_table.error == nil then
					local content_lines =
						vim.split(response_table.choices[1].message.content, "\n", { trimempty = true })
					result_handler(content_lines)
					table.insert(context, response_table.choices[1].message)
					context_handler(context)
				else
					error_handler(job, return_val)
				end
			end)
		else
			error_handler(job, return_val)
		end
	end
end

---Request response from model API
---@param model_name string
---@param request_msg string[]
---@param system_msg string
---@param context message[]
---@param result_handler result_handler
---@param error_handler error_handler
---@param context_handler context_handler
---@return Job
function MistralModel:request(
	model_name,
	request_msg,
	system_msg,
	context,
	result_handler,
	error_handler,
	context_handler
)
	local prompt = table.concat(request_msg, "\n")
	local request_table = { model = model_name, messages = {} }
	if has_empty_context(context) then
		if string.len(system_msg) > 0 then
			table.insert(request_table.messages, { role = "system", content = system_msg })
		end
		table.insert(request_table.messages, { role = "user", content = prompt })
	else
		request_table.messages = context
		table.insert(request_table.messages, { role = "user", content = prompt })
	end

	local json_body = vim.json.encode(request_table)
	if not json_body then
		error("Could not encode table to json: " .. vim.inspect(request_table))
	end
	local job_args = insert_request_body(json_body, args)
	local job = Job:new({
		command = command,
		args = job_args,
		on_exit = on_exit_request(result_handler, error_handler, context_handler, request_table.messages),
	})
	job:start()
	return job
end

---Callback function for when there is stdout, when streaming
---@param chunk_handler chunk_handler
---@return fun(err: string, chunk: string)
local function on_stdout_stream(chunk_handler)
	return function(_, chunk)
		if chunk == nil or chunk == "" then
			return
		elseif chunk == "data: [DONE]" then
			return
		else
			vim.schedule(function()
				local json_chunk = chunk:gsub("data: ", "")
				local chunk_table = vim.json.decode(json_chunk, { luanil = { object = true, array = true } })
				if chunk_table == nil then
					error("Empty json object")
				end

				if chunk_table.choices[1].delta.content then
					local content = chunk_table.choices[1].delta.content
					chunk_handler(content)
				elseif chunk_table.choices[1].delta.role then
					return
				end
			end)
		end
	end
end

local function exstract_message(lines)
	local message = { role = nil, content_list = {} }
	for _, entry in ipairs(lines) do
		if entry ~= "" and entry ~= "data: [DONE]" then
			local json_chunk = entry:gsub("data: ", "")
			local chunk_table = vim.json.decode(json_chunk, { luanil = { object = true, array = true } })
			if chunk_table == nil then
				error("Empty json object")
			end

			if chunk_table.choices[1].delta.content then
				local content = chunk_table.choices[1].delta.content
				table.insert(message.content_list, content)
			elseif chunk_table.choices[1].delta.role then
				message.role = chunk_table.choices[1].delta.role
			end
		end
	end
	return { content = table.concat(message.content_list), role = message.role }
end

---Callback function for when a streamed job exits
---@param context_handler context_handler
---@param context message[]
---@return fun(job: Job, return_value: integer)
local function on_exit_stream(context_handler, context)
	return function(job, return_val)
		if return_val == 130 then
			return
		else
			vim.schedule(function()
				if return_val == 0 then
					local message = exstract_message(job:result())
					table.insert(context, message)
					context_handler(context)
				end
			end)
		end
	end
end

---Request streamed response from model API
---@param model_name string
---@param request_msg string[]
---@param system_msg string
---@param context message[]
---@param chunk_handler chunk_handler
---@param context_handler context_handler
---@return Job
function MistralModel:stream_request(model_name, request_msg, system_msg, context, chunk_handler, context_handler)
	local prompt = table.concat(request_msg, "\n")
	local request_table = { model = model_name, messages = {}, stream = true }
	if has_empty_context(context) then
		if string.len(system_msg) > 0 then
			table.insert(request_table.messages, { role = "system", content = system_msg })
		end
		table.insert(request_table.messages, { role = "user", content = prompt })
	else
		request_table.messages = context
		table.insert(request_table.messages, { role = "user", content = prompt })
	end

	local json_body = vim.json.encode(request_table)
	if not json_body then
		error("Could not encode table to json: " .. vim.inspect(request_table))
	end
	local job_args = insert_request_body(json_body, args)
	local job = Job:new({
		command = command,
		args = job_args,
		on_stdout = on_stdout_stream(chunk_handler),
		on_exit = on_exit_stream(context_handler, request_table.messages),
	})
	job:start()
	return job
end

return MistralModel
