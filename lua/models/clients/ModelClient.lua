---@alias Job any

---@alias error_handler fun(job: Job, return_value: integer)
---@alias context_handler fun(context: any)
---@alias result_handler fun(answer_lines: string[])
---@alias chunk_handler fun(chunk: string)

---@class ModelClient
---@field name string
---@field private command string
---@field private args string[]
---@field context_handler fun(new_context: any, old_context: any): any
---@field request fun(self: ModelClient, model_name: string, request_msg: string[], system_msg: string, context: any, result_handler: result_handler, error_handler: error_handler, context_handler: context_handler)
---@field stream_request fun(self: ModelClient, model_name: string, request_msg: string[], system_msg: string, context: any, chunk_handler: chunk_handler, context_handler: context_handler)
