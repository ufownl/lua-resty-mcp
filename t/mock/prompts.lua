local mcp = {
  transport = {
    stdio = require("resty.mcp.transport.stdio")
  },
  session = require("resty.mcp.session"),
  protocol = require("resty.mcp.protocol"),
  prompt = require("resty.mcp.prompt"),
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

local available_prompts = {}

local prompt = mcp.prompt.new("simple_prompt", function(args)
  return {
    {role = "user", content = {type = "text", text = "This is a simple prompt without arguments."}}
  }
end, "A prompt without arguments.")
available_prompts[prompt.name] = prompt

local prompt = mcp.prompt.new("complex_prompt", function(args)
  return {
    {role = "user", content = {type = "text", text = string.format("This is a complex prompt with arguments: temperature=%s, style=%s", args.temperature, tostring(args.style))}},
    {role = "assistant", content = {type = "text", text = string.format("Assistant reply: temperature=%s, style=%s", args.temperature, tostring(args.style))}}
  }
end, "A prompt with arguments.", {
  temperature = {description = "Temperature setting.", required = true},
  style = {description = "Output style."}
})
available_prompts[prompt.name] = prompt

local enable_mock_error = mcp.tool.new("enable_mock_error", function(args)
  if available_prompts.mock_error then
    return {
      {type = "text", text = "Mock error prompt has been enabled!"}
    }, true
  end
  local prompt = mcp.prompt.new("mock_error", function(args)
    return nil, "mock error"
  end, "Mock error message.")
  available_prompts[prompt.name] = prompt
  local ok, err = sess:send_notification("list_changed", {"prompts"})
  if not ok then
    return {
      {type = "text", text = err}
    }, true
  end
  return {}
end, "Enable mock error prompt.")

sess:initialize({
  initialize = function(params)
    return mcp.protocol.result.initialize({
      prompts = true,
      tools = {listChanged = false}
    })
  end,
  ["prompts/list"] = function(params)
    local prompts = {}
    for k, v in pairs(available_prompts) do
      table.insert(prompts, v)
    end
    table.sort(prompts, function(a, b)
      return a.name < b.name
    end)
    local idx = tonumber(params.cursor) or 1
    return mcp.protocol.result.list("prompts", {prompts[idx]}, idx < #prompts and tostring(idx + 1) or nil)
  end,
  ["prompts/get"] = function(params)
    local prompt = available_prompts[params.name]
    if not prompt then
      return nil, -32602, "Invalid prompt name", {name = params.name}
    end
    return prompt:get(params.arguments)
  end,
  ["tools/list"] = function(params)
    return mcp.protocol.result.list("tools", {enable_mock_error})
  end,
  ["tools/call"] = function(params)
    if params.name ~= "enable_mock_error" then
      return nil, -32602, "Unknown tool", {name = params.name}
    end
    return enable_mock_error(params.arguments)
  end
})
