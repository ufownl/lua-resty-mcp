local mcp = require("resty.mcp")

local server = assert(mcp.server(mcp.transport.stdio))

assert(server:register(mcp.prompt("echo", function(args, ctx)
  for i, v in ipairs({0.25, 0.5, 1}) do
    local ok, err = ctx.push_progress(v, 1, "prompt")
    if not ok then
      return
    end
  end
  return "Please process this message: "..args.message
end, {
  description = "Create an echo prompt",
  arguments = {
    message = {required = true}
  }
})))

assert(server:register(mcp.resource("echo://static", "echo static", function(uri, ctx)
  for i, v in ipairs({0.25, 0.5, 1}) do
    local ok, err = ctx.push_progress(v, 1, "resource")
    if not ok then
      return
    end
  end
  return "Resource echo: static"
end, "Echo a static message as a resource", "text/plain")))

assert(server:register(mcp.resource_template("echo://{message}", "echo", function(uri, vars, ctx)
  for i, v in ipairs({0.25, 0.5, 1}) do
    local ok, err = ctx.push_progress(v, 1, "resource_template")
    if not ok then
      return
    end
  end
  return true, "Resource echo: "..ngx.unescape_uri(vars.message)
end, "Echo a message as a resource", "text/plain")))

assert(server:register(mcp.tool("echo", function(args, ctx)
  for i, v in ipairs({0.25, 0.5, 1}) do
    local ok, err = ctx.push_progress(v, 1, "tool")
    if not ok then
      return
    end
  end
  return "Tool echo: "..args.message
end, "Echo a message as a tool", {
  type = "object",
  properties = {
    message = {type = "string"}
  },
  required = {"message"}
})))

assert(server:register(mcp.prompt("simple_sampling", function(args, ctx)
  local messages =  {
    {role = "user", content = {type = "text", text = "Hey, man!"}}
  }
  local res, err = ctx.session:create_message(messages, 128, nil, 180, function(progress, total, message)
    table.insert(messages, {
      role = "assistant",
      content = {
        type = "text",
        text = string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message))
      }
    })
    return true
  end)
  if not res then
    return nil, err
  end
  table.insert(messages, res)
  return messages
end, {description = "Sampling prompt from client without arguments."})))

assert(server:register(mcp.prompt("cancel_sampling", function(args, ctx)
  local messages =  {
    {role = "user", content = {type = "text", text = "Hey, man!"}}
  }
  local res, err = ctx.session:create_message(messages, 128, nil, 180, function(progress, total, message)
    table.insert(messages, {
      role = "assistant",
      content = {
        type = "text",
        text = string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message))
      }
    })
    return nil, "test cancellation"
  end)
  if not res then
    return nil, err
  end
  table.insert(messages, res)
  return messages
end, {description = "Sampling prompt from client without arguments."})))

server:run()
