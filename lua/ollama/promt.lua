local job = require("plenary.job")
local promts = require("ollama.promts")
local M = {}

local function add_comments(command, args, on_exit)
	job:new({
		command = command,
		args = args,
		on_exit = on_exit,
	}):start()
end

M.command = "ollama"

M.promts = promts

M.add_comments = function(code_lines, on_exit)
	print("this is the code lines")
	print(code_lines)
	local promt = promts.add_comments.promt .. code_lines
	add_comments("ollama", { "run", "openhermes", promt }, on_exit)
end

return M
