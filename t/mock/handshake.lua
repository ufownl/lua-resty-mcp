local mcp = require("resty.mcp")

local server, err = mcp.server(mcp.transport.stdio, {})
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
