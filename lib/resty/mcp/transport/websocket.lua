local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils")
}

local _M = {
  _NAME = "resty.mcp.transport.websocket",
  _VERSION = mcp.version.module,
  client = require("resty.mcp.transport.websocket.client").new,
  server = require("resty.mcp.transport.websocket.server").new
}

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
