local diff = require("aiui.diff")
local example = require("example.ollama_diff")
local openai_generic_curl = require("openai.openai_generic_curl")
local chat_window = require("aiui.chat_window")
local chat_window_class = require("aiui.chat_window_class")
local openai_curl = require("openai.openai_curl")
local ollama_curl = require("ollama.ollama_curl")
local ollama_run = require("ollama.ollama_run")
local ollama_generic_curl = require("ollama.ollama_generic_curl")
local util = require("aiui.util")

return {
	example = example.add_comments, -- OLD
	diff = diff.do_it_all, -- OLD
	chat_window = chat_window, -- OLD
	openai_curl = openai_curl, -- OLD
	ollama_run = ollama_run, -- OLD
	ollama_curl = ollama_curl, -- OLD
	openai_generic_curl = openai_generic_curl,
	ollama_generic_curl = ollama_generic_curl,
	chat_window_class = chat_window_class,
	util = util,
}
