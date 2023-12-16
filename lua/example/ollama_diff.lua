local ollama_promt = require("ollama.promt")
local util = require("aiui.util")
local diff = require("aiui.diff")

M = {}

local function add_comments()
	local lines, start_row, end_row, bufnr = util.get_virtual_lines()
	local combined_lines = vim.fn.join(lines, "\n")
	local function on_exit(job, return_val)
		vim.schedule(function()
			if return_val == 0 then
				local new_lines = util.slice(job:result(), 2, #job:result() - 1)
				diff.diff_lines(lines, new_lines, start_row, end_row, bufnr)
				local confirm = vim.fn.input("Replace? (y): ")

				if confirm:lower() == "y" then
					vim.api.nvim_buf_set_lines(bufnr, start_row, end_row + #new_lines, false, new_lines)
				else
					vim.api.nvim_buf_set_lines(bufnr, start_row, end_row + #new_lines, false, lines)
				end
			else
				error("Job finished with exitcode: " .. return_val)
			end
		end)
	end
	ollama_promt.add_comments(combined_lines, on_exit)
end

M.add_comments = add_comments

--
-- local job = require("plenary.job")
--
-- job:new({
-- 	command = "ollama",
-- 	args = { "run", "mistral:instruct", "write hello world in python" },
-- 	-- cwd
-- 	-- env
-- 	on_exit = function(j, return_val)
-- 		vim.print(return_val)
-- 		local function printTableEntries(table)
-- 			for key, value in pairs(table) do
-- 				print(key, value)
-- 			end
-- 		end
-- 		printTableEntries(j:result())
-- 		vim.print("jobs done")
-- 	end,
-- }):start()

return M
