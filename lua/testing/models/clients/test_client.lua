local Job = require("plenary.job")

---@class TestClient : ModelClient
local TestClient = {
	name = "test_model",
	command = "THIS IS A TEST COMMAND",
	args = {
		"THIS IS A TEST ARGUMENT",
	},
}

---@param message string[]
---@return string[]
function TestClient.context_handler(message, _)
	return message
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
	error("This is not supposed to be called")
	return function(job, return_val) end
end

---Request response from model API
---@param model_name string
---@param request_msg string[]
---@param system_msg string
---@param context message[]
---@param result_handler result_handler
---@param error_handler error_handler
---@param context_handler context_handler
function TestClient:request(
	model_name,
	request_msg,
	system_msg,
	context,
	result_handler,
	error_handler,
	context_handler
)
	if request_msg[1] == "error" then
		error("THIS IS AN ERROR")
	elseif request_msg[1] == "diff" then
		result_handler({
			"---Request response from model API",
			"---@param model_name string",
			"---@param request_msg string[]",
			"---@param system_msg string",
			"---@param context message[]",
			"---@param result_handler result_handler",
			"---@param error_handler error_handler",
			"---@param context_handler context_handler",
		})
	else
		local output = {}
		if has_empty_context(context) then
			if string.len(system_msg) > 0 then
				table.insert(output, system_msg)
			end
			-- table.insert(output, request_msg)
			for _, v in ipairs(request_msg) do
				table.insert(output, v)
			end
		else
			output = context
			for _, v in ipairs(request_msg) do
				table.insert(output, v)
			end
		end
		context_handler(output)
		result_handler(output)
		return
	end
end

return TestClient
