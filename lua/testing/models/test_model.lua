local Job = require("plenary.job")

---@class TestModel : ModelClient
local TestModel = {
	name = "test_model",
	command = "echo",
	args = {
		"https://api.openai.com/v1/chat/completions",
		"-H",
		"Content-Type: application/json",
		"-H",
		"openai key",
		"-d",
		"json request body",
	},
}

---@param api_key string
function TestModel:set_api_key(api_key)
	self.args[5] = "Authorization: Bearer " .. api_key
end

---@param json string
---@param args string[]
---@return string[]
local function insert_request_body(json, args)
	args[7] = json
	return args
end

---@param message string
---@param old_context string[]
---@return string[]
function TestModel.context_handler(message, old_context)
	table.insert(old_context, message)
	return old_context
end

---@param context string[]
---@return boolean
local function has_empty_context(context)
	return #context == 0
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
				-- result_handler(job:result())
				-- context_handler(job:result())

				---@type {error: nil | string, choices: {message: message}} | nil
				local response_table = vim.fn.json_decode(job:result())
				if response_table == nil then
					error_handler(job, return_val)
					return
				else
					local response_content = vim.inspect(response_table)
					context_handler(response_table.messages)
					vim.print("THIS IS THE CONTENT")
					vim.print(vim.inspect(response_table))
					local content_lines = {}
					for line in response_content:gmatch("[^\n]+") do
						table.insert(content_lines, line)
					end
					result_handler(content_lines)
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
---@param context message[]
---@param result_handler result_handler
---@param error_handler error_handler
---@param context_handler context_handler
function TestModel:request(model_name, request_msg, system_msg, context, result_handler, error_handler, context_handler)
	local prompt = table.concat(request_msg, "\n")
	local request_table = { model = model_name, messages = {} }
	if has_empty_context(context) then
		if string.len(system_msg) > 0 then
			vim.print(vim.inspect(request_table))
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
	local args = insert_request_body(json_body, self.args)
	Job:new({
		command = self.command,
		args = { json_body },
		on_exit = on_exit_request(result_handler, error_handler, context_handler),
	}):start()
end

return TestModel
