local mcp = {
  version = require("resty.mcp.version")
}

local _M = {
  _NAME = "resty.mcp.transport.stdio",
  _VERSION = mcp.version.module,
  client = require("resty.mcp.transport.stdio.client").new,
  server = require("resty.mcp.transport.stdio.server").new
}

return _M
