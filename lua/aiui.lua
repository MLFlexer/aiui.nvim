local Chat = require("aiui.Chat")
local ModelCollection = require("aiui.ModelCollection")

local function decrypt_file_with_gpg(file_path)
	local command = string.format("gpg --decrypt %s", file_path)
	local handle = io.popen(command)
	if handle then
		local decrypted_text = handle:read("*a")
		handle:close()
		decrypted_text = decrypted_text:gsub("\n$", "")
		return decrypted_text
	else
		error("Unable to run command: " .. command)
	end
end

local diff = require("aiui.diff")
vim.api.nvim_create_user_command("DD", function()
	local prompt = "Add comments to the following code.\n"
	local instance = { name = "code commenter", model = "orca-mini", context = {}, agent = "mistral_agent" }
	local function response_formatter(lines)
		print(vim.inspect(lines))
		local response = table.concat(lines, "\n")
		local exstracted_code = response:match("```.*\n(.-)```")
		if exstracted_code then
			local result = vim.fn.split(exstracted_code, "\n")
			print(vim.inspect(result))
			return result
		else
			return lines
		end
	end
	local function prompt_formatter(lines)
		return { prompt, vim.fn.join(lines, "\n") }
	end
	diff.diff_visual_lines(instance, prompt_formatter, response_formatter)
end, { range = 2 })

vim.api.nvim_create_user_command("DA", function()
	diff.accept_all_changes(0)
end, {})

vim.api.nvim_create_user_command("DS", function()
	diff.cancel_buffer_diffs(0)
end, {})

vim.api.nvim_create_user_command("AN", function()
	local test_model = require("models.clients.test.test_client")
	local ollama_client = require("models.clients.ollama.ollama_curl")
	local mistral_client = require("models.clients.mistral.mistral_curl")
	local openai_client = require("models.clients.openai.openai_curl")
	mistral_client:set_api_key(decrypt_file_with_gpg("/home/mlflexer/.secrets/mistral.txt.gpg"))
	openai_client:set_api_key(decrypt_file_with_gpg("/home/mlflexer/.secrets/open_ai.txt.gpg"))
	ModelCollection:add_models({
		testing_model = { name = "testing_model", client = test_model },
	})
	ModelCollection:add_models(openai_client:get_default_models())
	ModelCollection:add_models(mistral_client:get_default_models())
	ModelCollection:add_models(ollama_client:get_default_models())
	ModelCollection:add_agents({
		mistral_agent = "You are a chatbot, answer short and concise.",
		gpt3_agent = "You are gpt3, a chatbot, answer short and concise.",
		testing_agent = "testing agent system prompt",
		random_agent = "always respond with a number between 0 and 10.",
		add_comments = "Only reply with code",
	})
	local instance = { name = "Mistral Tiny", model = "mistral-tiny", context = {}, agent = "mistral_agent" }
	Chat:new(instance)
	Chat:apply_default_keymaps()
	Chat:apply_autocmd()
end, {})

vim.api.nvim_create_user_command("AT", function()
	Chat:toggle()
end, {})

vim.api.nvim_create_user_command("AW", function()
	Chat:save_current_chat()
end, {})

local Picker = require("aiui.ModelPicker")
vim.api.nvim_create_user_command("AMP", function()
	Picker:model_picker(Chat)
end, {})

vim.api.nvim_create_user_command("AIP", function()
	Picker:instance_picker(Chat)
end, {})

vim.api.nvim_create_user_command("ASP", function()
	Picker:saved_picker(Chat)
end, {})

vim.api.nvim_create_user_command("AL", function()
	Chat:load_from_file("/home/mlflexer/.aiui/chats/test_model/testing_model/testing_instance/2023-12-31_13:32")
end, {})

local waiter = require("aiui.Waiter")
local waiter1
vim.api.nvim_create_user_command("ATS1", function()
	waiter1 = waiter:new({ "x", "xx", "xxx" })
	waiter1:start(500, function()
		vim.print(waiter1:next_frame())
	end)
end, {})
local waiter2
vim.api.nvim_create_user_command("ATS2", function()
	waiter2 = waiter:new({ ".", "..", "..." })
	waiter2:start(500, function()
		vim.print(waiter2:next_frame())
	end)
end, {})

vim.api.nvim_create_user_command("ATE1", function()
	waiter1:stop()
end, {})

vim.api.nvim_create_user_command("ATE2", function()
	waiter2:stop()
end, {})

return {
	chat = Chat,
}
