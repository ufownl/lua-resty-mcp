local mcp = require("resty.mcp")

local server = assert(mcp.server(mcp.transport.stdio))

assert(server:register(mcp.resource("mock://client_capabilities", "ClientCapabilities", function(uri, ctx)
  local contents = {}
  if ctx.session.client.capabilities.roots then
    table.insert(contents, {uri = uri.."/roots", text = "true"})
    if ctx.session.client.capabilities.roots.listChanged then
      table.insert(contents, {uri = uri.."/roots/listChanged", text = "true"})
    end
  end
  if ctx.session.client.capabilities.sampling then
    table.insert(contents, {uri = uri.."/sampling", text = "true"})
  end
  if ctx.session.client.capabilities.elicitation then
    table.insert(contents, {uri = uri.."/elicitation", text = "true"})
  end
  return contents
end, {description = "Capabilities of client."})))

assert(server:register(mcp.tool("simple_elicit", function(args, ctx)
  local res, err = ctx.session:elicit("Hello, world!", {
    type = "object",
    properties = {
      text = {type = "string"},
      seed = {type = "integer"}
    },
    required = {"text", "seed"}
  })
  if not res then
    return nil, err
  end
  return res
end, {
  description = "Elicit from client without arguments.",
  output_schema = {type = "object"}
})))

server:run({
  capabilities = {
    prompts = false,
    completions = false,
    logging = false
  }
})
