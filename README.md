# aiui.nvim

## Why Choose aiui?
### TLDR

aiui.nvim offers a unified set of UI modules for interacting with various LLM backends, whether proprietary or open parameter. Which enables switching models without swtiching tools.

### Non-TLDR

In today's landscape, numerous LLMs are available for use, ranging from proprietary models like OpenAI's GPT4 to open parameter models like Mistral7B, which can be self-hosted.

Despite the similarities in how users interact with these models, the interfaces to access them differ significantly.

The primary aim of aiui is to create a cohesive suite of tools and modules that ensure a consistent user experience across diverse models.

This is achieved by abstracting the model-specific RPC (Remote Procedure Call) into a Lua module. This abstraction simplifies plugin implementation or user-driven development.

## Milestones

### Chat window
- [ ] Having multiple chats at the same time
- [ ] Saving and loading old chats
- [ ] @ and/or # references to reference specific code without having to paste it into the chat
- [ ] Use fuzzy search to create new chats with different models
- [ ] Use fuzzy search to load chats
- [ ] Streaming answers
- [ ] Batching answers
- [ ] buffer AND popup window support

### Inline interactions
- [ ] module to abstract inline interactions
- [ ] git-like Diff-view when modifing codeblocks within a buffer
- [ ] Fix-bug for visual mode, function and method interactions
- [ ] Fix-error for visual mode, function and method interactions
- [ ] improve readability for visual mode, function and method interactions
