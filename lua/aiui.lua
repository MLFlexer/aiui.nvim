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

vim.api.nvim_create_user_command("AN", function()
	local test_model = require("testing.models.clients.test_client")
	local ollama_model = require("models.clients.ollama.ollama_curl")
	local mistral_client = require("models.clients.mistral.mistral_curl")
	local openai_client = require("models.clients.openai.openai_curl")
	mistral_client:set_api_key(decrypt_file_with_gpg("/home/mlflexer/.secrets/mistral.txt.gpg"))
	openai_client:set_api_key(decrypt_file_with_gpg("/home/mlflexer/.secrets/open_ai.txt.gpg"))
	ModelCollection:add_models({
		testing_model = { name = "testing_model", client = test_model },
		orca_mini = { name = "orca-mini", client = ollama_model },
		mistral_tiny = { name = "mistral-tiny", client = mistral_client },
		mistral_small = { name = "mistral-small", client = mistral_client },
		mistral_medium = { name = "mistral-medium", client = mistral_client },
		gpt3 = { name = "gpt-3.5-turbo-1106", client = openai_client },
		gpt4 = { name = "gpt-4-1106-preview", client = openai_client },
	})
	ModelCollection:add_agents({
		mistral_agent = "You are a chatbot, answer short and concise.",
		gpt3_agent = "You are gpt3, a chatbot, answer short and concise.",
		testing_agent = "testing agent system prompt",
		random_agent = "always respond with a number between 0 and 10.",
		add_comments = "Only reply with code",
	})
	local instance = { name = "Mistral Tiny", model = "mistral_tiny", context = {}, agent = "mistral_agent" }
	-- instance = { name = "ollama instance", model = "orca_mini", context = {}, agent = "random_agent" }
	-- instance = { name = "gpt3 instance", model = "gpt3", context = {}, agent = "gpt3_agent" }
	-- instance = { name = "testing instance2", model = "testing_model", context = {}, agent = "testing_agent" }
	-- -- ModelCollection:add_instance(instance)
	-- instance = { name = "testing instance", model = "testing_model", context = {}, agent = "testing_agent" }
	-- ModelCollection:add_instance(instance)
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

return {
	chat = Chat,
}
