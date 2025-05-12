local cjson = require("cjson")
local stdio = require("resty.mcp.transport.stdio")
local conn = assert(stdio.server())
while true do
  local data, err = conn:recv()
  if data then
    assert(conn:send(cjson.decode(data)))
  elseif err ~= "timeout" then
    break
  end
end
conn:close()
