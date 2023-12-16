local job = require("plenary.job")
local M = {}

local function get_api_key(command)
	local handle = io.popen(command)
	local result = handle:read("*a")
	handle:close()
	return result
end

M.model = "gpt-3.5-turbo"
M.system_content = "You are a coding assistant, answer short and percise."
M.api_key = get_api_key("echo $OPENAI_API_KEY")
M.command = "curl"
M.args = {
	"https://api.openai.com/v1/chat/completions",
	"-H",
	"Content-Type: application/json",
	"-H",
	"Authorization: Bearer $OPENAI_API_KEY",
	"-d",
	"$JSON",
	-- [[{
	--    "model": "$MODEL",
	--    "messages": [
	--      {
	--        "role": "system",
	--        "content": "$SYSTEM_CONTENT"
	--      },
	--      {
	--        "role": "user",
	--        "content": "$USER_CONTENT"
	--      }
	--    ]
	--  }]],
}
M.messages = {}

local function replace_args(arg_table, temp_to_arg_map)
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

local function on_exit_ask_question(handle_result, handle_error, replace_context)
	return function(job, return_val)
		vim.schedule(function()
			if return_val == 0 then
				local response_table = vim.fn.json_decode(job:result())
				if response_table.error == nil then
					local answer = response_table.choices[1].message.content
					local answer_line_table = {}
					for line in answer:gmatch("[^\n]+") do
						table.insert(answer_line_table, line)
					end
					handle_result(answer_line_table)
					replace_context(response_table.choices[1].message)
				else
					handle_error(job, return_val)
				end
			else
				handle_error(job, return_val)
			end
		end)
	end
end

local function default_error_handler(job, return_val)
	error("Job: " .. job .. " finished with exitcode: " .. return_val)
end

local function ask_question(question_lines, handle_result, handle_error)
	local replace_context = function(answer)
		table.insert(M.messages, answer)
	end
	local question = table.concat(question_lines, "\n")
	local json_request = { model = M.model }
	if #M.messages == 0 then
		json_request.messages =
			{ { role = "system", content = M.system_content }, { role = "user", content = question } }
	else
		table.insert(M.messages, { role = "user", content = question })
		json_request.messages = M.messages
	end
	json_request = vim.json.encode(json_request)
	vim.print(json_request)
	request_answer(M.command, M.args, {
		-- MODEL = "gpt-3.5-turbo",
		OPENAI_API_KEY = "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",
		-- SYSTEM_CONTENT = "you are a chatbot which answers short and percise.",
		-- USER_CONTENT = question,
		JSON = json_request,
	}, on_exit_ask_question(handle_result, handle_error, replace_context))
end
M.ask_question = ask_question
return M
