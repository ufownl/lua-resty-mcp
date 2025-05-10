local cjson = require("cjson")
local mcp = require("resty.mcp")

local client, err = mcp.client(mcp.transport.stdio, {
  command = 'resty --main-conf "env https_proxy;" --http-include ngx_conf/lua_ssl/conf -I ../../../lib/ run.lua',
  pipe_opts = {
    environ = {string.format("https_proxy=%s", os.getenv("https_proxy"))}
  }
})
if not client then
  error(err)
end
local ok, err = client:initialize()
if not ok then
  error(err)
end

local res, err = client:call_tool("upcoming_or_ungoing_race")
if not res then
  error(err)
end
print("call tool: ", cjson.encode(res))

local res, err = client:call_tool("race_calendar", {})
if not res then
  error(err)
end
print("call tool: ", cjson.encode(res))

local res, err = client:call_tool("race_calendar", {year = 2023})
if not res then
  error(err)
end
print("call tool: ", cjson.encode(res))

client:shutdown()
