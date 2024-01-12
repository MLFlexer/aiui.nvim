# aiui.nvim
> A unified set of modules to interact with different LLM providers.

## Why aiui.nvim?
Unify your development experience across different LLM providers with aiui.nvim's adaptable UI modules, allowing for easy model switching without changing your workflow.

## Features

- **Unified LLM Interface**: Swap LLM providers on-the-fly while keeping your workflow consistent.
- **In-Editor Chat**: Engage with LLMs in a familiar chat interface inside neovim.
  - _**Demo Link**_![chat_demo](https://github.com/MLFlexer/aiui.nvim/assets/75012728/cf77ce24-ca48-491d-89b2-da4b8e79f82c)

- **Single buffer Code Difference**: Visualize LLM-suggested code changes directly within your buffer, akin to a git diff.
  - _**Demo Link**_
- **Chat Selection Convenience**: Fuzzy search-enabled model and instance switching or resuming past chats.
  - _**Demo Link**_
- **Conversations as files**: Store chat logs as readable markdown and session data as json for external access.

*Checkout the [roadmap](#Roadmap) for upcomming features*

## Getting Started
Assuming you are using [Lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
  "MLFlexer/aiui.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },

  init = function()
    --adds default keybindings and initializes
    require("aiui").add_defaults()

    -- If NOT using the default setup:
    -- add you LLM provider
    -- local ModelCollection = require("aiui.ModelCollection")
    -- local ollama_client = require("models.clients.ollama.ollama_curl")
    -- ModelCollection:add_models(ollama_client:get_default_models())

    -- Add any agents you like
    -- ModelCollection:add_agents({
    -- 	default_agent = "You are a chatbot, answer short and concise.",
    -- })

    -- Initialize the Chat and set default keybinds and autocmds
    -- local Chat = require("aiui.Chat")
    -- Chat:new({
    --   name = "Mistral Tiny",
    --   model = "mistral-tiny",
    --   context = {},
    --   agent = "default_agent",
    -- })
    -- Chat:apply_default_keymaps()
    -- Chat:apply_autocmd()
  end,
}
```

Need help? Checkout how the default setup is done in: [aiui/defaults.lua](https://github.com/MLFlexer/aiui.nvim/blob/main/lua/defaults.lua) or ask in the [Discussions tab](https://github.com/MLFlexer/aiui.nvim/discussions).

## Adding your own LLM client
This section is unfinished, however you should implement the function annotations for the [ModelClient](https://github.com/MLFlexer/aiui.nvim/blob/main/lua/models/clients/ModelClient.lua). Need help, see [clients directory](https://github.com/MLFlexer/aiui.nvim/tree/main/lua/models/clients) or ask in the [Discussions tab](https://github.com/MLFlexer/aiui.nvim/discussions).

## Roadmap

### Chat Features
- [x] Highly customizable.
- [x] Support for concurrent chat instances.
- [x] Persisting and retrieving chat history.
- [ ] Code reference shortcuts (like `@some_function` or `/some_file`) within chats.
- [x] New chat creation and retrieval via fuzzy search.
- [x] Real-time chat streaming.
- [x] Popup chat window.
- [ ] Buffer chat window.

### Inline Code Interactions
- [x] Integrated diff views for in-buffer modifications.
- [x] Quickly add comments, fix errors, ect. for visual selection.
- [ ] LSP interactions to fix errors or other LSP warnings.
- [ ] Start a Chat window with the visual selection.
