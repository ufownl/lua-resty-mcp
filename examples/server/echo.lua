local mcp = require("resty.mcp")

local server = assert(mcp.server(mcp.transport.stdio))

assert(server:register(mcp.prompt("echo", function(args)
  return "Please process this message: "..args.message
end, {
  description = "Create an echo prompt",
  arguments = {
    message = {required = true}
  }
})))

assert(server:register(mcp.resource_template("echo://{message}", "echo", function(uri, vars)
  return true, "Resource echo: "..ngx.unescape_uri(vars.message)
end, "Echo a message as a resource", "text/plain")))

assert(server:register(mcp.tool("echo", function(args)
  return "Tool echo: "..args.message
end, "Echo a message as a tool", {
  type = "object",
  properties = {
    message = {type = "string"}
  },
  required = {"message"}
})))

server:run()
