local mcp = {
  version = require("resty.mcp.version"),
  session = require("resty.mcp.session")
}

local ngx_log = ngx.log

local function get_list_tools(self)
  local tools = {}
  local cursor
  repeat
    local res, err = mcp.session.send_request(self, "list_tools", {cursor})
    if not res then
      return nil, err
    end
    for i, v in ipairs(res.tools) do
      table.insert(tools, v)
    end
    cursor = res.nextCursor
  until not cursor
  return tools
end

local function define_methods(self)
  return {
    ["notifications/tools/list_changed"] = function(params)
      local tools, err = get_list_tools(self)
      if not tools then
        ngx_log(ngx.ERR, "client: ", err)
        return
      end
      self.server.discovered_tools = tools
    end
  }
end

local _MT = {
  __index = {}
}

function _MT.__index.initialize(self)
  mcp.session.initialize(self, define_methods())
  local res, err = mcp.session.send_request(self, "initialize", {self.name})
  if not res then
    self.conn:close()
    return nil, err
  end
  self.server = {
    protocol = res.protocolVersion,
    capabilities = res.capabilities,
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

function _MT.__index.list_tools(self)
  if not self.server.capabilities.tools then
    return nil, string.format("%s v%s has no tools capability", self.server.info.name, self.server.info.version)
  end
  if not self.server.capabilities.tools.listChanged then
    return get_list_tools(self)
  end
  if not self.server.discovered_tools then
    local tools, err = get_list_tools(self)
    if not tools then
      return nil, err
    end
    self.server.discovered_tools = tools
  end
  return self.server.discovered_tools
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
