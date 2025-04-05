local mcp = {
  transport = {
    stdio = require("resty.mcp.transport.stdio")
  },
  session = require("resty.mcp.session")
}

local conn, err = mcp.transport.stdio.new()
if not conn then
  error(err)
end
local sess, err = mcp.session.new(conn)
if not sess then
  error(err)
end

sess:initialize({})
sess:shutdown()

