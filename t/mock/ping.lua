local mcp = require("resty.mcp")

local server, err = mcp.server(mcp.transport.stdio)
if not server then
  error(err)
end

local ok, err = server:register(mcp.tool("ping", function(args, ctx)
  local ok, err = ctx.session:ping()
  if not ok then
    return nil, err
  end
  return {}
end, "Send a ping request."))
if not ok then
  error(err)
end

server:run({
  capabilities = {
    logging = false,
    prompts = false,
    resources = false,
    completions = false
  }
})
