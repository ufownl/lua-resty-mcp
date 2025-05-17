local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils")
}

local _M = {
  _NAME = "resty.mcp.transport.stdio",
  _VERSION = mcp.version.module,
  client = require("resty.mcp.transport.stdio.client").new,
  server = require("resty.mcp.transport.stdio.server").new
}

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
