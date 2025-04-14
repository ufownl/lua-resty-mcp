local mcp = require("resty.mcp")

local server, err = mcp.server(mcp.transport.stdio, {})
if not server then
  error(err)
end

local ok, err = server:register(mcp.resource("mock://client_capabilities", "ClientCapabilities", function(uri, ctx)
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
end, "Capabilities of client."))
if not ok then
  error(err)
end

local ok, err = server:register(mcp.prompt("simple_sampling", function(args, ctx)
  local messages =  {
    {role = "user", content = {type = "text", text = "Hey, man!"}}
  }
  local res, err = ctx.session:create_message(messages, 128)
  if not res then
    return nil, err
  end
  table.insert(messages, res)
  return messages
end, "Sampling prompt from client without arguments."))

server:run({
  capabilities = {
    tools = false,
    completions = false,
    logging = false
  }
})
