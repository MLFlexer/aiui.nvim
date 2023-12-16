# aiui.nvim

## Why Choose aiui?
### TLDR

aiui.nvim offers a unified set of UI modules for interacting with various LLM backends, whether proprietary or open source. Which enables switching models without swtiching tools.

### Non-TLDR

In today's landscape, numerous LLMs are available for use, ranging from proprietary models like OpenAI's GPT4 to open parameter models like Mistral7B, which can be self-hosted.

Despite the similarities in how users interact with these models, the interfaces to access them differ significantly.

The primary aim of aiui is to create a cohesive suite of tools and modules that ensure a consistent user experience across diverse models.

This is achieved by abstracting the model-specific RPC (Remote Procedure Call) into a Lua module. This abstraction simplifies plugin implementation or user-driven development.
