local Job = require("plenary.job")

---@alias message { role: string, content: string }
---@alias openai_context message[]

---@class OpenAIModel : Model
---@field get_api_key fun(): string
---@field context message[]
OpenAIModel = {
	name = "",
	model = "",
	system_content = "",
	get_api_key = function()
		error("No api key defined")
	end,
	command = "",
	args = {},
	context = {},
}

---@param name string
---@param model string
---@param system_content string
---@param get_api_key fun(): string
---@param command string
---@param args string[]
---@param context openai_context
---@return OpenAIModel
function OpenAIModel:new(name, model, system_content, get_api_key, command, args, context)
	local new_openai_model = {}
	setmetatable(new_openai_model, self)
	self.__index = self
	new_openai_model.name = name
	new_openai_model.model = model
	new_openai_model.system_content = system_content
	new_openai_model.get_api_key = get_api_key
	new_openai_model.command = command
	new_openai_model.args = args
	new_openai_model.context = context
	return new_openai_model
end

---@param message message
function OpenAIModel:append_context(message)
	table.insert(self.context, message)
end

-- ---@return fun(message: message): nil
-- function OpenAIModel:get_append_message_function()
-- 	return function(message)
-- 		self:append_message(message)
-- 	end
-- end

---@return boolean
function OpenAIModel:has_empty_context()
	return #self.context == 0
end

---@param index_arg_pairs {i: integer, arg: string}[]
function OpenAIModel:replace_args(index_arg_pairs)
	-- Remember lua is 1-indexed
	for _, index_arg in pairs(index_arg_pairs) do
		self.args[index_arg.i] = index_arg.arg
	end
end

---@param handle_result result_handler
---@param handle_error error_handler
---@param handle_context context_handler
---@return fun(job: Job, return_value: integer): nil
local function on_exit_ask_question(handle_result, handle_error, handle_context)
	return function(job, return_val)
		vim.schedule(function()
			if return_val == 0 then
				---@type {error: nil | string, choices: {message: message}} | nil
				local response_table = vim.fn.json_decode(job:result())
				if response_table == nil then
					handle_error(job, return_val)
					return
				elseif response_table.error == nil then
					local answer = response_table.choices[1].message.content
					local answer_line_table = {}
					for line in answer:gmatch("[^\n]+") do
						table.insert(answer_line_table, line)
					end
					handle_result(answer_line_table)
					handle_context(response_table.choices[1].message)
				else
					handle_error(job, return_val)
				end
			else
				handle_error(job, return_val)
			end
		end)
	end
end

---@return fun(question_lines: string[], handle_result: result_handler, handle_error: error_handler): nil
function OpenAIModel:get_ask_question_function()
	return function(question_lines, handle_result, handle_error)
		self:ask_question(question_lines, handle_result, handle_error)
	end
end

---@param question_lines string[]
---@param handle_result result_handler
---@param handle_error error_handler
function OpenAIModel:ask_question(question_lines, handle_result, handle_error)
	local question = table.concat(question_lines, "\n")
	local request_table = { model = self.model }
	if self:has_empty_context() then
		---@type message[]
		request_table.messages = {
			{ role = "system", content = self.system_content },
			{ role = "user", content = question },
		}
	else
		self:append_context({ role = "user", content = question })
		request_table.messages = self.context
	end
	local json_request = vim.json.encode(request_table)

	local index_arg_pairs = {
		{ i = 5, arg = "Authorization: Bearer " .. self.get_api_key() },
		{ i = 7, arg = json_request },
	}
	self:replace_args(index_arg_pairs)

	Job:new({
		command = self.command,
		args = self.args,
		on_exit = on_exit_ask_question(handle_result, handle_error, self.append_context), -- WARN: could be wrong
	}):start()
end

return OpenAIModel
