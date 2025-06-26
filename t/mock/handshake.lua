local mcp = require("resty.mcp")
local server = assert(mcp.server(mcp.transport.stdio, {
  name = "handshake",
  title = "MCP Handshake",
  version = "1.0_alpha"
}))
server:run({
  capabilities = {
    prompts = false,
    resources = false,
    tools = false,
    completions = false,
    logging = false
  },
  instructions = "Hello, MCP!"
})
