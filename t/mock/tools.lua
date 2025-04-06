local mcp = {
  transport = {
    stdio = require("resty.mcp.transport.stdio")
  },
  session = require("resty.mcp.session"),
  protocol = require("resty.mcp.protocol"),
  tool = require("resty.mcp.tool")
}

local conn, err = mcp.transport.stdio.new()
if not conn then
  error(err)
end
local sess, err = mcp.session.new(conn)
if not sess then
  error(err)
end

local available_tools = {}
available_tools.add = mcp.tool.new("add", "Adds two numbers.", {
  a = {
    type = "number",
    required = true
  },
  b = {
    type = "number",
    required = true
  }
}, function(args)
  return {
    {type = "text", text = tostring(args.a + args.b)}
  }
end)
available_tools.enable_echo = mcp.tool.new("enable_echo", "Enables the echo tool.", {}, function(args)
  if available_tools.echo then
    return {
      {type = "text", text = "Echo tool has been enabled!"}
    }, true
  end
  available_tools.echo = mcp.tool.new("echo", "Echoes back the input.", {
    message = {
      type = "string",
      description = "Message to echo.",
      required = true
    }
  }, function(args)
    return {
      {type = "text", text = args.message}
    }
  end)
  local ok, err = sess:send_notification("list_changed", {"tools"})
  if not ok then
    return {
      {type = "text", text = err}
    }, true
  end
  return {}
end)

sess:initialize({
  initialize = function(params)
    return mcp.protocol.result.initialize({tools = true})
  end,
  ["tools/list"] = function(params)
    local tools = {}
    for k, v in pairs(available_tools) do
      table.insert(tools, v)
    end
    table.sort(tools, function(a, b)
      return a.name < b.name
    end)
    local idx = tonumber(params.cursor) or 1
    return mcp.protocol.result.list_tools({tools[idx]}, idx < #tools and tostring(idx + 1) or nil)
  end,
  ["tools/call"] = function(params)
    local tool = available_tools[params.name]
    if not tool then
      return nil, -32602, "Unknown tool", {name = params.name}
    end
    return tool(params.arguments)
  end
})
