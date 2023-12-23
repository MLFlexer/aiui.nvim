---@alias Job any

---@alias error_handler fun(job: Job, return_value: integer)
---@alias context_handler fun(context: any)
---@alias result_handler fun(answer_lines: string[])

---@class ModelClient
---@field name string
---@field private command string
---@field private args string[]
---@field context_handler fun(new_context: any, old_context: any)
---@field request fun(self: ModelClient, model_name: string, request_msg: string[], system_msg: string, context: any, result_handler: result_handler, error_handler: error_handler, context_handler: context_handler)
