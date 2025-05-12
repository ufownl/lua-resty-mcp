local mcp = {
  transport = {
    stdio = require("resty.mcp.transport.stdio")
  },
  session = require("resty.mcp.session")
}

local conn = assert(mcp.transport.stdio.server())
local sess = assert(mcp.session.new(conn))
sess:initialize({})
