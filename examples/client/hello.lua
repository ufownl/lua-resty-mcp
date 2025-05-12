local cjson = require("cjson")
local mcp = require("resty.mcp")

local client = assert(mcp.client(mcp.transport.stdio, {
  command = "resty -I ../../lib ../server/echo.lua"
}))
assert(client:initialize())

local res = assert(client:get_prompt("echo", {message = "Hello, MCP!"}))
print("get prompt: ", cjson.encode(res))

local res = assert(client:read_resource(ngx.escape_uri("echo://Hello, MCP!", 0)))
print("read resource: ", cjson.encode(res))

local res = assert(client:call_tool("echo", {message = "Hello, MCP!"}))
print("call tool: ", cjson.encode(res))

client:shutdown()
