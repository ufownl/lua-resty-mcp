local stdio = require("resty.mcp.transport.stdio")
local conn, err = stdio.server()
if not conn then
  error(err)
end
while true do
  local data, err = conn:recv()
  if data then
    local ok, err = conn:send(data)
    if not ok then
      error(err)
    end
  elseif err ~= "timeout" then
    break
  end
end
conn:close()
