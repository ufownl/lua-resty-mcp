local mcp = require("resty.mcp")

local server, err = mcp.server(mcp.transport.stdio)
if not server then
  error(err)
end

local ok, err = server:register(mcp.prompt("echo", function(args)
  return "Please process this message: "..args.message
end, "Create an echo prompt", {message = {required = true}}))
if not ok then
  error(err)
end

local ok, err = server:register(mcp.resource_template("echo://{message}", "echo", function(uri, vars)
  return true, "Resource echo: "..ngx.unescape_uri(vars.message)
end, "Echo a message as a resource", "text/plain"))
if not ok then
  error(err)
end

local ok, err = server:register(mcp.tool("echo", function(args)
  return "Tool echo: "..args.message
end, "Echo a message as a tool", {
  type = "object",
  properties = {
    message = {type = "string"}
  },
  required = {"message"}
}))
if not ok then
  error(err)
end

server:run()
