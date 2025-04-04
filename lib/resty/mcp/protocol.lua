local mcp = {
  version = require("resty.mcp.version"),
  rpc = require("resty.mcp.protocol.rpc")
}

local _M = {
  _NAME = "resty.mcp.protocol",
  _VERSION = mcp.version.module,
  request = {},
  response = {},
  notification = {}
}

function _M.request.initialize(name, roots, sampling, experimental)
  return mcp.rpc.request("initialize", {
    protocolVersion = mcp.version.protocol,
    capabilities = {
      roots = roots and {listChanged = true} or nil,
      sampling = sampling and {} or sampling,
      experimental = experimental
    },
    clientInfo = {
      name = name or "lua-resty-mcp",
      version = mcp.version.module
    }
  })
end

function _M.request.list_tools(cursor)
  return mcp.rpc.request("tools/list", {cursor = cursor})
end

function _M.request.call_tool(name, args)
  return mcp.rpc.request("tools/call", {name = name, arguments = args})
end

function _M.notification.initialized()
  return mcp.rpc.notification("notifications/initialized")
end

return _M
