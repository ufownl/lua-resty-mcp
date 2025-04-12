local mcp = {
  transport = {
    stdio = require("resty.mcp.transport.stdio")
  },
  server = require("resty.mcp.server")
}

local server, err = mcp.server.new(mcp.transport.stdio, {})
if not server then
  error(err)
end
server:run({
  prompts = false,
  resources = false,
  tools = false,
  completions = false,
  logging = false
})
