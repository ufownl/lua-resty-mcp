local mcp = {
  version = require("resty.mcp.version")
}

local _M = {
  _NAME = "resty.mcp.transport.streamable_http",
  _VERSION = mcp.version.module,
  server = require("resty.mcp.transport.streamable_http.server").new
}

return _M
