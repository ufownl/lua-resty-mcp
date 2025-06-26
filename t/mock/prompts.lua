local mcp = require("resty.mcp")

local server = assert(mcp.server(mcp.transport.stdio))

assert(server:register(mcp.prompt("simple_prompt", function(args)
  return "This is a simple prompt without arguments."
end, "A prompt without arguments.")))

assert(server:register(mcp.prompt("complex_prompt", function(args)
  return {
    {role = "user", content = {type = "text", text = string.format("This is a complex prompt with arguments: temperature=%s, style=%s", args.temperature, tostring(args.style))}},
    {role = "assistant", content = {type = "text", text = string.format("Assistant reply: temperature=%s, style=%s", args.temperature, tostring(args.style))}}
  }
end, "A prompt with arguments.", {
  temperature = {title = "Temperature", description = "Temperature setting.", required = true},
  style = {title = "Style", description = "Output style."}
})))

assert(server:register(mcp.tool("enable_mock_error", function(args, ctx)
  local ok, err = ctx.session:register(mcp.prompt("mock_error", function(args)
    return nil, "mock error"
  end, "Mock error message."))
  if not ok then
    return nil, err
  end
  return {}
end, "Enable mock error prompt.")))

assert(server:register(mcp.tool("disable_mock_error", function(args, ctx)
  local ok, err = ctx.session:unregister_prompt("mock_error")
  if not ok then
    return nil, err
  end
  return {}
end)))

server:run({
  capabilities = {
    resources = false,
    completions = false,
    logging = false
  },
  pagination = {
    prompts = 1
  }
})
