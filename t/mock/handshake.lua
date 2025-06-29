local mcp = require("resty.mcp")
local server = assert(mcp.server(mcp.transport.stdio, {
  name = "handshake",
  title = "MCP Handshake",
  version = "1.0_alpha"
}))
require("t.mock").handshake(mcp, server)
