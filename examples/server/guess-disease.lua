local mcp = require("resty.mcp")
local server = assert(mcp.server(mcp.transport.stdio))
local game = require("guess-disease.server").new()

server:run({
  capabilities = {
    completions = false,
    logging = false,
    prompts = false,
    resources = false
  },
  instructions = assert(game:initialize(mcp, server))
})
