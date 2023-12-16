---@type Job
local Job = require("plenary.job")

---@type { model: string, system_content: string | nil, command: command, args: args_list, context: context, ask_question: nil | fun(question_lines: string[], handle_result: result_handler, handle_error: error_handler): nil }
local M = {
	model = "codellama:instruct",
	system_content = nil,
	command = "curl",
	args = {
		"-X",
		"POST",
		"http://localhost:11434/api/generate",
		"-d",
		"$JSON",
	},
	context = {},
	ask_question = nil,
}

---replace args prefixed with '$'
---@param arg_table args_list
---@param temp_to_arg_map table<string, string>
---@return args_list
local function replace_args(arg_table, temp_to_arg_map)
	local new_arg_table = {}
	for i, arg_str in ipairs(arg_table) do
		local new_arg_str = arg_str
		for key, value in pairs(temp_to_arg_map) do
			new_arg_str = new_arg_str:gsub("%$" .. key, value)
		end
		table.insert(new_arg_table, i, new_arg_str)
	end
	return new_arg_table
end

---@param command command
---@param args args_list
---@param temp_to_arg_map table<string, string>
---@param on_exit fun(): nil
---@return nil
local function request_answer(command, args, temp_to_arg_map, on_exit)
	args = replace_args(args, temp_to_arg_map)
	Job:new({
		command = command,
		args = args,
		on_exit = on_exit,
	}):start()
end

---@param handle_result result_handler
---@param handle_error error_handler
---@param handle_context context_handler
---@return fun(job: Job, return_value: integer): nil
local function on_exit_ask_question(handle_result, handle_error, handle_context)
	return function(job, return_val)
		vim.schedule(function()
			if return_val == 0 then
				local response_table = vim.fn.json_decode(job:result())
				vim.print(response_table)
				local answer = response_table.response
				local answer_line_table = {}
				for line in answer:gmatch("[^\n]+") do
					table.insert(answer_line_table, line)
				end
				handle_result(answer_line_table)
				if response_table.context ~= nil then
					handle_context(response_table.context)
				end
			else
				handle_error(job, return_val)
			end
		end)
	end
end

-- local function default_error_handler(job, return_val)
-- 	error("Job: " .. job .. " finished with exitcode: " .. return_val)
-- end

---send a request to the model
---@param question_lines string[]
---@param handle_result result_handler
---@param handle_error error_handler
---@return nil
local function ask_question(question_lines, handle_result, handle_error)
	local replace_context = function(context)
		M.context = context
	end
	local question = table.concat(question_lines, "\n")
	local json_request = { model = M.model, prompt = question, stream = false }
	if #M.context > 0 then
		json_request.context = M.context
	end
	if M.system_content ~= nil then
		json_request.system = M.system_content
	end
	json_request = vim.json.encode(json_request)
	vim.print(json_request)
	request_answer(M.command, M.args, {
		JSON = json_request,
	}, on_exit_ask_question(handle_result, handle_error, replace_context))
end

M.ask_question = ask_question
return M
