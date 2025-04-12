local mcp = require("resty.mcp")

local server, err = mcp.server(mcp.transport.stdio, {})
if not server then
  error(err)
end

local ok, err = server:register(mcp.tool("add", function(args)
  return {
    {type = "text", text = tostring(args.a + args.b)}
  }
end, "Adds two numbers.", {
  a = {
    type = "number",
    required = true
  },
  b = {
    type = "number",
    required = true
  }
}))
if not ok then
  error(err)
end

local ok, err = server:register(mcp.tool("enable_echo", function(args)
  local ok, err = server:register(mcp.tool("echo", function(args)
    return {
      {type = "text", text = args.message}
    }
  end, "Echoes back the input.", {
    message = {
      type = "string",
      description = "Message to echo.",
      required = true
    }
  }))
  if not ok then
    return {
      {type = "text", text = err}
    }, true
  end
  return {}
end, "Enables the echo tool."))

server:run({
  capabilities = {
    prompts = false,
    resources = false,
    completions = false,
    logging = false
  },
  pagination = {
    tools = 1
  }
})
