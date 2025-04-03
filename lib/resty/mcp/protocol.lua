local PROTOCOL_VERSION = "2025-03-26"

local mcp = {
  rpc = require("resty.mcp.protocol.rpc")
}

local _M = {
  _NAME = "resty.mcp.protocol",
  _VERSION = "1.0",
  request = {},
  response = {},
  notification = {}
}

function _M.request.initialize(name, roots, sampling, experimental)
  return mcp.rpc.request("initialize", {
    protocolVersion = PROTOCOL_VERSION,
    capabilities = {
      roots = roots and {listChanged = true} or nil,
      sampling = sampling and {} or sampling,
      experimental = experimental
    },
    clientInfo = {
      name = name or "lua-resty-mcp",
      version = "1.0"
    }
  })
end

function _M.notification.initialized()
  return mcp.rpc.notification("notifications/initialized")
end

return _M
