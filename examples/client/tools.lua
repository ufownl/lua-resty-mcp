local mcp = require("resty.mcp")
local cjson = require("cjson")

local client = assert(mcp.client(mcp.transport.stdio, {
  command = {"npx", "-y", "@modelcontextprotocol/server-everything"}
}))
assert(client:initialize())
print(ngx.localtime(), " initialized")
print("serverInfo: ", cjson.encode(client.server))

local tools = assert(client:list_tools())
print("tools: ", cjson.encode(tools))

local res = assert(client:call_tool("echo", {message = "Hello, world!"}))
print("tool calling: ", cjson.encode(res))

local res = assert(client:call_tool("add", {a = 1, b = 2}))
print("tool calling: ", cjson.encode(res))

local _, err = client:call_tool("foobar")
print("invalid tool: ", err)

local _, err = client:call_tool("echo", {foo = "bar"})
print("invalid arguments: ", err)

client:shutdown()
print(ngx.localtime(), " shutdown")
