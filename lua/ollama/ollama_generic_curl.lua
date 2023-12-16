---@alias Job any

---@alias error_handler fun(job: Job, return_value: integer): nil
---@alias context_handler fun(context: any): nil
---@alias result_handler fun(answer_lines: string[]): nil

local Job = require("plenary.job")

---@alias ollama_context number[]

---@class OllamaModel : Model
---@field context ollama_context
OllamaModel = {
	name = "",
	model = "",
	system_content = "",
	command = "",
	args = {},
	context = {},
}

---@param name string
---@param model string
---@param system_content string
---@param command string
---@param args string[]
---@param context ollama_context
---@return OllamaModel
function OllamaModel:new(name, model, system_content, command, args, context)
	local new_ollama_model = {}
	setmetatable(new_ollama_model, self)
	self.__index = self
	new_ollama_model.name = name
	new_ollama_model.model = model
	new_ollama_model.system_content = system_content
	new_ollama_model.command = command
	new_ollama_model.args = args
	new_ollama_model.context = context
	return new_ollama_model
end

---@param context ollama_context
function OllamaModel:append_context(context)
	self.context = context
end

-- ---@return fun(context: ollama_context): nil
-- function OllamaModel:get_append_message_function()
-- 	return function(context)
-- 		self:append_context(context)
-- 	end
-- end

---@return boolean
function OllamaModel:has_empty_context()
	return #self.context == 0
end

---@param index_arg_pairs {i: integer, arg: string}[]
function OllamaModel:replace_args(index_arg_pairs)
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
				---@type {response: string, context: ollama_context} | nil
				local response_table = vim.fn.json_decode(job:result())
				if response_table == nil then
					handle_error(job, return_val)
					return
				end
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

---@return fun(question_lines: string[], handle_result: result_handler, handle_error: error_handler): nil
function OllamaModel:get_ask_question_function()
	return function(question_lines, handle_result, handle_error)
		self:ask_question(question_lines, handle_result, handle_error)
	end
end

---@return fun(question_lines: string[], handle_result: result_handler, handle_error: error_handler): nil
function OllamaModel:get_ask_question_without_context_function()
	return function(question_lines, handle_result, handle_error)
		self:ask_question_without_context(question_lines, handle_result, handle_error)
	end
end

---@param question_lines string[]
---@param handle_result result_handler
---@param handle_error error_handler
function OllamaModel:ask_question_without_context(question_lines, handle_result, handle_error)
	local question = table.concat(question_lines, "\n")
	local request_table = { model = self.model, prompt = question, stream = false }
	if self.system_content ~= "" then
		request_table.system = self.system_content
	end
	local json_request = vim.json.encode(request_table)

	local index_arg_pairs = { { i = 5, arg = json_request } }
	self:replace_args(index_arg_pairs)

	Job:new({
		command = self.command,
		args = self.args,
		on_exit = on_exit_ask_question(handle_result, handle_error, function() end),
	}):start()
end

---@param question_lines string[]
---@param handle_result result_handler
---@param handle_error error_handler
function OllamaModel:ask_question(question_lines, handle_result, handle_error)
	local question = table.concat(question_lines, "\n")
	local request_table = { model = self.model, prompt = question, stream = false }
	if self:has_empty_context() then
		if self.system_content ~= "" then
			request_table.system = self.system_content
		end
	else
		request_table.context = self.context
	end
	local json_request = vim.json.encode(request_table)

	local index_arg_pairs = { { i = 5, arg = json_request } }
	self:replace_args(index_arg_pairs)

	Job:new({
		command = self.command,
		args = self.args,
		on_exit = on_exit_ask_question(handle_result, handle_error, self.append_context), -- WARN: could be wrong
	}):start()
end

return OllamaModel
