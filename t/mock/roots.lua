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
  return contents
end, "Capabilities of client.")))

assert(server:register(mcp.resource("mock://discovered_roots", "DiscoveredRoots", function(uri, ctx)
  local roots, err = ctx.session:list_roots()
  if not roots then
    return nil, err
  end
  local contents = {}
  for i, v in ipairs(roots) do
    table.insert(contents, {uri = v.uri, text = v.name or ""})
  end
  return contents
end, "Discovered roots from client.")))

server:run({
  capabilities = {
    prompts = false,
    tools = false,
    completions = false,
    logging = false
  },
  event_handlers = {
    ["roots/list_changed"] = function(params, ctx)
      assert(ctx.session:resource_updated("mock://discovered_roots"))
    end
  }
})
