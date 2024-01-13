-- This module is only for applying default configuration options

local defaults = {}

function defaults.decrypt_file_with_gpg(file_path)
	local decrypted_text = vim.fn.system({ "gpg", "--decrypt", "--quiet", file_path })
	-- remove the \n from the end of the string
	return string.sub(decrypted_text, 1, #decrypted_text - 1)
end

function defaults.initialize()
	-- adds Ollama
	local ModelCollection = require("aiui.ModelCollection")
	local ollama_client = require("models.clients.ollama.ollama_curl")
	ModelCollection:add_models(ollama_client:get_default_models())

	-- add MistralAI
	local mistral_client = require("models.clients.mistral.mistral_curl")
	mistral_client:set_api_key(defaults.decrypt_file_with_gpg("/home/mlflexer/.secrets/mistral.txt.gpg"))
	ModelCollection:add_models(mistral_client:get_default_models())

	-- add OpenAI
	local openai_client = require("models.clients.openai.openai_curl")
	openai_client:set_api_key(defaults.decrypt_file_with_gpg("/home/mlflexer/.secrets/open_ai.txt.gpg"))
	ModelCollection:add_models(openai_client:get_default_models())

	-- Add any agents you like
	ModelCollection:add_agents({
		default_agent = "You are a chatbot, answer short and concise.",
	})

	-- Initialize the Chat and set default keybinds and autocmds
	local Chat = require("aiui.Chat")
	Chat:new({ name = "Mistral Tiny", model = "mistral-tiny", context = {}, agent = "default_agent" })
	Chat:apply_default_keymaps()
	Chat:apply_autocmd()
end

function defaults.add_chat_keybinds()
	local Chat = require("aiui.Chat")
	local Picker = require("aiui.ModelPicker")
	local diff = require("aiui.diff")
	vim.keymap.set("n", "<leader>aa", function()
		Chat:toggle()
	end)

	vim.keymap.set("n", "<leader>apm", function()
		Picker:model_picker(Chat)
	end)
	vim.keymap.set("n", "<leader>api", function()
		Picker:instance_picker(Chat)
	end)
	vim.keymap.set("n", "<leader>apl", function()
		Picker:saved_picker(Chat)
	end)

	vim.keymap.set("v", "<leader>ad", function()
		vim.ui.input({ prompt = "Enter prompt: " }, function(prompt)
			if not prompt or prompt == "" then
				return
			end

			local function prompt_formatter(lines)
				return { prompt, vim.fn.join(lines, "\n") }
			end

			local function response_formatter(lines)
				local response = table.concat(lines, "\n")
				local exstracted_code = response:match("```.*\n(.-)```")
				if exstracted_code then
					local result = vim.fn.split(exstracted_code, "\n")
					return result
				else
					return lines
				end
			end

			diff.diff_visual_lines(
				{ name = "Mistral Tiny", model = "gpt-3.5-turbo", context = {}, agent = "default_agent" },
				prompt_formatter,
				response_formatter
			)
		end)
	end)

	vim.keymap.set("n", "<leader>da", function()
		diff.accept_all_changes(0)
	end)

	vim.keymap.set("n", "<leader>dc", function()
		diff.cancel_buffer_diffs(0)
	end)
end

return defaults
