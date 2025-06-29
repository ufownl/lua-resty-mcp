local mcp = require("resty.mcp")

local server = assert(mcp.server(mcp.transport.stdio))

assert(server:register(mcp.tool("ping", function(args, ctx)
  local ok, err = ctx.session:ping()
  if not ok then
    return nil, err
  end
  return {}
end, {description = "Send a ping request."})))

server:run({
  capabilities = {
    logging = false,
    prompts = false,
    resources = false,
    completions = false
  }
})
