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
  type = "object",
  properties = {
    a = {type = "number"},
    b = {type = "number"}
  },
  required = {"a", "b"}
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
    type = "object",
    properties = {
      message = {
        type = "string",
        description = "Message to echo."
      }
    },
    required = {"message"}
  }))
  if not ok then
    return {
      {type = "text", text = err}
    }, true
  end
  return {}
end, "Enables the echo tool."))
if not ok then
  error(err)
end

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
