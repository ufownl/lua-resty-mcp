local mcp = require("resty.mcp")
local server = assert(mcp.server(mcp.transport.stdio))

assert(require("f1-calendar.server").declare(mcp, server))

server:run({
  capabilities = {
    completions = false,
    logging = false,
    prompts = false,
    resources = false
  }
})
