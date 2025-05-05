local mcp = require("resty.mcp")

local server, err = mcp.server(mcp.transport.stdio)
if not server then
  error(err)
end

local ok, err = server:register(mcp.tool("log_echo", function(args, ctx)
  local ok, err = ctx.session:log(args.level, args.data, args.logger)
  if not ok then
    return nil, err
  end
  return {}
end, "Echo a message as log.", {
  type = "object",
  properties = {
    level = {type = "string"},
    data = {type = "string"},
    logger = {type = "string"}
  },
  required = {"level", "data"}
}))
if not ok then
  error(err)
end

server:run({
  capabilities = {
    prompts = false,
    resources = false,
    completions = false
  }
})
