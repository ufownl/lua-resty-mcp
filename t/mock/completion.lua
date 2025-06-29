local mcp = require("resty.mcp")
local server = assert(mcp.server(mcp.transport.stdio))
require("t.mock").completion(mcp, server)
