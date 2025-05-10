local mcp = require("resty.mcp")

local server, err = mcp.server(mcp.transport.stdio)
if not server then
  error(err)
end

local ok, err = require("server").declare(mcp, server)
if not ok then
  error(err)
end

server:run({
  capabilities = {
    completions = false,
    logging = false,
    prompts = false,
    resources = false,
    tools = {
      listChanged = true
    }
  }
})
