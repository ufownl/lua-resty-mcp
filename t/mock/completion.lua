local mcp = require("resty.mcp")

local server = assert(mcp.server(mcp.transport.stdio))

assert(server:register(mcp.prompt("simple_prompt", function(args)
  return "This is a simple prompt without arguments."
end, {description = "A prompt without arguments."})))

assert(server:register(mcp.prompt("complex_prompt", function(args)
  return {
    {role = "user", content = {type = "text", text = string.format("This is a complex prompt with arguments: temperature=%s, style=%s", args.temperature, tostring(args.style))}},
    {role = "assistant", content = {type = "text", text = string.format("Assistant reply: temperature=%s, style=%s", args.temperature, tostring(args.style))}}
  }
end, {
  description = "A prompt with arguments.",
  arguments = {
    temperature = {description = "Temperature setting.", required = true},
    style = {description = "Output style."}
  },
  completions = {
    style = function(value, prev_args)
      if prev_args and prev_args.style then
        return {prev_args.style}
      end
      local available_values = {"a01", "a02"}
      for i = 0, 99 do
        table.insert(available_values, string.format("b%02d", i))
      end
      local values = {}
      for i, v in ipairs(available_values) do
        if string.find(v, value, 1, true) then
          table.insert(values, v)
        end
      end
      return values, #values
    end
  }
})))

assert(server:register(mcp.resource_template("mock://no_completion/text/{id}", "NoCompletion", function(uri, vars)
  if vars.id == "" then
    return false
  end
  return true, {
    {text = string.format("content of no_completion text resource %s, id=%s", uri, vars.id)},
  }
end, {description = "No completion text resource.", mime = "text/plain"})))

assert(server:register(mcp.resource_template("mock://dynamic/text/{id}", "DynamicText", function(uri, vars)
  if vars.id == "" then
    return false
  end
  return true, {
    {text = string.format("content of dynamic text resource %s, id=%s", uri, vars.id)},
  }
end, {
  desciption = "Dynamic text resource.",
  mime = "text/plain",
  completions = {
    id = function(value, prev_args)
      if prev_args and prev_args.id then
        return {prev_args.id}
      end
      local available_values = {"a01", "a02"}
      for i = 0, 99 do
        table.insert(available_values, string.format("b%02d", i))
      end
      local values = {}
      for i, v in ipairs(available_values) do
        if string.find(v, value, 1, true) then
          table.insert(values, v)
        end
      end
      return values, nil, #values > 2
    end
  }
})))

server:run({
  capabilities = {
    logging = false,
    tools = false
  }
})
