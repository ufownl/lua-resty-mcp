local cjson = require("cjson")
local mcp = require("resty.mcp")

local https_proxy = os.getenv("https_proxy")
local client = assert(mcp.client(mcp.transport.stdio, {
  command = 'resty --main-conf "env https_proxy;" --http-include ngx_conf/lua_ssl/conf -I ../../lib/ f1-calendar.lua',
  pipe_opts = {
    environ = {https_proxy and string.format("https_proxy=%s", https_proxy)}
  }
}))
assert(client:initialize())

local res = assert(client:call_tool("upcoming_or_ungoing_race"))
print("call tool: ", cjson.encode(res))

local res = assert(client:call_tool("race_calendar", {}))
print("call tool: ", cjson.encode(res))

local res = assert(client:call_tool("race_calendar", {year = 2023}))
print("call tool: ", cjson.encode(res))

client:shutdown()
