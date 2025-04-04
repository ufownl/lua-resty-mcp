local mcp = require("resty.mcp")
local cjson = require("cjson")

local client, err = mcp.client(mcp.transport.stdio, {
  command = {"npx", "-y", "@modelcontextprotocol/server-everything"}
})
if not client then
  error(err)
end
local ok, err = client:initialize()
if not ok then
  error(err)
end
print(ngx.localtime(), " initialized")
print("serverInfo: ", cjson.encode(client.server))

local tools, err = client:list_tools()
if not tools then
  error(err)
end
print("tools: ", cjson.encode(tools))

local res, err = client:call_tool("echo", {message = "Hello, world!"})
if not res then
  error(err)
end
print("tool calling: ", cjson.encode(res))

local res, err = client:call_tool("add", {a = 1, b = 2})
if not res then
  error(err)
end
print("tool calling: ", cjson.encode(res))

local _, err = client:call_tool("foobar")
print("invalid tool: ", err)

local _, err = client:call_tool("echo", {foo = "bar"})
print("invalid arguments: ", err)

client:shutdown()
print(ngx.localtime(), " shutdown")
