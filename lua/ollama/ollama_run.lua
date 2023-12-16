local job = require("plenary.job")
local M = {}

M.model = "codellama:instruct"
M.system_content = ""
M.command = "ollama"
M.args = {
	"run",
	"$MODEL",
	"$SYSTEM_CONTENT \n $USER_CONTENT",
}

local function replace_args(arg_table, temp_to_arg_map)
	print("this is the arg_str")
	print(arg_table)
	local new_arg_table = {}
	for i, arg_str in ipairs(arg_table) do
		local new_arg_str = arg_str
		for key, value in pairs(temp_to_arg_map) do
			print(key)
			new_arg_str = new_arg_str:gsub("%$" .. key, value)
		end
		table.insert(new_arg_table, i, new_arg_str)
	end
	return new_arg_table
end

local function request_answer(command, args, temp_to_arg_map, on_exit)
	args = replace_args(args, temp_to_arg_map)
	vim.print(args)
	job:new({
		command = command,
		args = args,
		on_exit = on_exit,
	}):start()
end

local function on_exit_ask_question(handle_result, handle_error)
	return function(job, return_val)
		vim.schedule(function()
			if return_val == 0 then
				local new_lines = job:result()
				handle_result(new_lines)
			else
				handle_error(job, return_val)
			end
		end)
	end
end

local function default_error_handler(job, return_val)
	error("Job: " .. job .. " finished with exitcode: " .. return_val)
end

local function ask_question(question_lines, result_handler, error_handler)
	local question = table.concat(question_lines, "\n")
	-- ask_question(question, result_handler, error_handler)
	request_answer(M.command, M.args, {
		MODEL = M.model,
		SYSTEM_CONTENT = "you are a chatbot which answers short and percise.",
		USER_CONTENT = question,
	}, on_exit_ask_question(result_handler, error_handler))
end

M.ask_question = ask_question

return M
