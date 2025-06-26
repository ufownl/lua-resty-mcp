local mcp = require("resty.mcp")

local server = assert(mcp.server(mcp.transport.stdio))

assert(server:register(mcp.tool("add", function(args)
  return args.a + args.b
end, "Adds two numbers.", {
  type = "object",
  properties = {
    a = {type = "number"},
    b = {type = "number"}
  },
  required = {"a", "b"}
})))

assert(server:register(mcp.tool("enable_echo", function(args, ctx)
  local ok, err = ctx.session:register(mcp.tool("echo", function(args)
    return string.format("%s %s v%s say: %s", ctx.session.client.info.name, ctx.session.client.info.title, ctx.session.client.info.version, args.message)
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
    return nil, err
  end
  return {}
end, "Enables the echo tool.")))

assert(server:register(mcp.tool("disable_echo", function(args, ctx)
  local ok, err = ctx.session:unregister_tool("echo")
  if not ok then
    return nil, err
  end
  return {}
end, "Disables the echo tool.")))

assert(server:register(mcp.tool("client_info", function(args, ctx)
  return ctx.session.client.info
end, "Query the client information.", nil, {
  type = "object",
  properties = {
    name = {type = "string"},
    title = {type = "string"},
    version = {type = "string"}
  },
  required = {"name", "version"}
})))

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
