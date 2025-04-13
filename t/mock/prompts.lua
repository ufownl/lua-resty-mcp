local mcp = require("resty.mcp")

local server, err = mcp.server(mcp.transport.stdio, {})
if not server then
  error(err)
end

local ok, err = server:register(mcp.prompt("simple_prompt", function(args)
  return {
    {role = "user", content = {type = "text", text = "This is a simple prompt without arguments."}}
  }
end, "A prompt without arguments."))
if not ok then
  error(err)
end

local ok, err = server:register(mcp.prompt("complex_prompt", function(args)
  return {
    {role = "user", content = {type = "text", text = string.format("This is a complex prompt with arguments: temperature=%s, style=%s", args.temperature, tostring(args.style))}},
    {role = "assistant", content = {type = "text", text = string.format("Assistant reply: temperature=%s, style=%s", args.temperature, tostring(args.style))}}
  }
end, "A prompt with arguments.", {
  temperature = {description = "Temperature setting.", required = true},
  style = {description = "Output style."}
}))
if not ok then
  error(err)
end

local ok, err = server:register(mcp.tool("enable_mock_error", function(args)
  local ok, err = server:register(mcp.prompt("mock_error", function(args)
    return nil, "mock error"
  end, "Mock error message."))
  if not ok then
    return {
      {type = "text", text = err}
    }, true
  end
  return {}
end, "Enable mock error prompt."))
if not ok then
  error(err)
end

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
