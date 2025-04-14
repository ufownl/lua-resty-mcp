local cjson = require("cjson")
local mcp = require("resty.mcp")

local client, err = mcp.client(mcp.transport.stdio, {
  command = "resty -I ../../lib ../server/echo.lua"
})
if not client then
  error(err)
end
local ok, err = client:initialize()
if not ok then
  error(err)
end

local res, err = client:get_prompt("echo", {message = "Hello, MCP!"})
if not res then
  error(err)
end
print("get prompt: ", cjson.encode(res))

local res, err = client:read_resource(ngx.escape_uri("echo://Hello, MCP!", 0))
if not res then
  error(err)
end
print("read resource: ", cjson.encode(res))

local res, err = client:call_tool("echo", {message = "Hello, MCP!"})
if not res then
  error(err)
end
print("call tool: ", cjson.encode(res))

client:shutdown()
