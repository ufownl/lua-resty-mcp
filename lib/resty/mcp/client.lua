local mcp = {
  version = require("resty.mcp.version"),
  session = require("resty.mcp.session")
}

local _MT = {
  __index = {}
}

function _MT.__index.initialize(self)
  --TODO: methods handler
  mcp.session.initialize(self, {})
  local res, err = mcp.session.send_request(self, "initialize", {self.name})
  if not res then
    self.conn:close()
    return nil, err
  end
  self.server = {
    protocol = res.protocolVersion,
    capabilities = {
      logging = res.capabilities.logging and true,
      prompts = res.capabilities.prompts and {
        list_changed = res.capabilities.prompts.listChanged
      },
      resources = res.capabilities.resources and {
        subscribe = res.capabilities.resources.subscribe,
        list_changed = res.capabilities.resources.listChanged
      },
      tools = res.capabilities.tools and {
        list_changed = res.capabilities.tools.listChanged
      }
    },
    info = res.serverInfo
  }
  local ok, err = mcp.session.send_notification(self, "initialized", {})
  if not ok then
    self.conn:close()
    return nil, err
  end
  return true
end

function _MT.__index.shutdown(self)
  mcp.session.shutdown(self)
end

local _M = {
  _NAME = "resty.mcp.client",
  _VERSION = mcp.version.module
}

function _M.new(transport, options)
  local conn, err = transport.new(options)
  if not conn then
    return nil, err
  end
  return mcp.session.new(options.name, conn, _MT)
end

return _M
