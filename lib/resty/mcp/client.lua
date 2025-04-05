local mcp = {
  version = require("resty.mcp.version"),
  session = require("resty.mcp.session")
}

local ngx_log = ngx.log

local function get_list(self, category, field_name)
  local list = {}
  local cursor
  repeat
    local res, err = mcp.session.send_request(self, "list", {category, cursor})
    if not res then
      return nil, err
    end
    for i, v in ipairs(res[field_name or category]) do
      table.insert(list, v)
    end
    cursor = res.nextCursor
  until not cursor
  return list
end

local function define_methods(self)
  local methods = {}
  for i, v in ipairs({"prompts", "resources", "tools"}) do
    methods[string.format("notifications/%s/list_changed", v)] = function(params)
      local list, err = get_list(self, v)
      if not list then
        ngx_log(ngx.ERR, "client: ", err)
        return
      end
      self.server["discovered_"..v] = list
    end
  end
  return methods
end

local function list_impl(self, category)
  if not self.server.capabilities[category] then
    return nil, string.format("%s v%s has no %s capability", self.server.info.name, self.server.info.version, category)
  end
  if not self.server.capabilities[category].listChanged then
    return get_list(self, category)
  end
  local key = "discovered_"..category
  if not self.server[key] then
    local list, err = get_list(self, category)
    if not list then
      return nil, err
    end
    self.server[key] = list
  end
  return self.server[key]
end

local _MT = {
  __index = {}
}

function _MT.__index.initialize(self)
  mcp.session.initialize(self, define_methods(self))
  local res, err = mcp.session.send_request(self, "initialize", {nil, self.name})
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

function _MT.__index.list_prompts(self)
  return list_impl(self, "prompts")
end

function _MT.__index.get_prompt(self, name, args)
  if type(name) ~= "string" then
    error("prompt name MUST be a string.")
  end
  if args and (type(args) ~= "table" or #args > 0) then
    error("arguments of prompt MUST be a dict.")
  end
  if not self.server.capabilities.prompts then
    return nil, string.format("%s v%s has no prompts capability", self.server.info.name, self.server.info.version)
  end
  local res, err = mcp.session.send_request(self, "get_prompt", {name, args})
  if not res then
    return nil, err
  end
  return res
end

function _MT.__index.list_resources(self)
  return list_impl(self, "resources")
end

function _MT.__index.list_resource_templates(self)
  if not self.server.capabilities.resources then
    return nil, string.format("%s v%s has no resources capability", self.server.info.name, self.server.info.version)
  end
  return get_list(self, "resources/templates", "resourceTemplates")
end

function _MT.__index.read_resource(self, uri)
  if type(uri) ~= "string" then
    error("resource uri MUST be a string.")
  end
  if not self.server.capabilities.resources then
    return nil, string.format("%s v%s has no resources capability", self.server.info.name, self.server.info.version)
  end
  local res, err = mcp.session.send_request(self, "read_resource", {uri})
  if not res then
    return nil, err
  end
  return res
end

function _MT.__index.list_tools(self)
  return list_impl(self, "tools")
end

function _MT.__index.call_tool(self, name, args)
  if type(name) ~= "string" then
    error("tool name MUST be a string.")
  end
  if args and (type(args) ~= "table" or #args > 0) then
    error("arguments of tool calling MUST be a dict.")
  end
  if not self.server.capabilities.tools then
    return nil, string.format("%s v%s has no tools capability", self.server.info.name, self.server.info.version)
  end
  local res, err = mcp.session.send_request(self, "call_tool", {name, args})
  if not res then
    return nil, err
  end
  return res
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
  return mcp.session.new(conn, options.name, _MT)
end

return _M
