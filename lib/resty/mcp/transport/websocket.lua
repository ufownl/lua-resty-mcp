local mcp = {
  version = require("resty.mcp.version")
}

local _M = {
  _NAME = "resty.mcp.transport.websocket",
  _VERSION = mcp.version.module,
  client = require("resty.mcp.transport.websocket.client").new,
  server = require("resty.mcp.transport.websocket.server").new
}

return _M
