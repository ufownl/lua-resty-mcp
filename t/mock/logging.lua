local mcp = require("resty.mcp")

local server = assert(mcp.server(mcp.transport.stdio))

assert(server:register(mcp.tool("log_echo", function(args, ctx)
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
})))

server:run({
  capabilities = {
    prompts = false,
    resources = false,
    completions = false
  }
})
