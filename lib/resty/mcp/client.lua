local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  session = require("resty.mcp.session"),
  validator = require("resty.mcp.protocol.validator")
}

local _M = {
  _NAME = "resty.mcp.client",
  _VERSION = mcp.version.module
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
  local methods = {
    ["roots/list"] = function(params)
      return {
        roots = self.exposed_roots or {}
      }
    end,
    ["sampling/createMessage"] = self.sampling_callback and function(params)
      local ok, err = mcp.validator.CreateMessageRequest(params)
      if not ok then
        return nil, -32602, "Invalid params", {errmsg = err}
      end
      for i, v in ipairs(params.messages) do
        if not mcp.utils.check_role(v.role) then
          return nil, -32602, "Invalid params", {errmsg = string.format("messages[%d].role=%s", i, tostring(v.role))}
        end
        if type(v.content) ~= "table" then
          return nil, -32602, "Invalid params", {errmsg = string.format("messages[%d].content=%s", i, tostring(v.content))}
        end
        if type(v.content.type) ~= "string" or v.content.type == "resource" then
          return nil, -32602, "Invalid params", {errmsg = string.format("messages[%d].content.type=%s", i, tostring(v.content.type))}
        end
        if not mcp.utils.check_content(v.content) then
          return nil, -32602, "Invalid params", {errmsg = string.format("messages[%d].content: invalid %s content format", i, v.content.type)}
        end
      end
      local result, code, message, data = self.sampling_callback(params)
      if not result then
        return nil, code, message, data
      end
      if type(result) == "table" then
        if result.role then
          if not mcp.utils.check_role(result.role) then
            error("role MUST be \"user\" or \"assistant\"")
          end
        else
          result.role = "assistant"
        end
        if type(result.content) ~= "table" or result.content.type == "resource" or not mcp.utils.check_content(result.content) then
          error("invalid content format")
        end
        if result.model then
          if type(result.model) ~= "string" then
            error("model MUST be a string")
          end
        else
          result.model = "unknown"
        end
        if result.stopReason and type(result.stopReason) ~= "string" then
          error("stopReason MUST be a string")
        end
        return result
      end
      return {
        role = "assistant",
        content = {
          type = "text",
          text = tostring(result)
        },
        model = "unknown"
      }
    end or nil,
    ["notifications/resources/updated"] = function(params)
      local ok, err = mcp.validator.ResourceUpdatedNotification(params)
      if not ok then
        ngx_log(ngx.ERR, err)
        return
      end
      local cap = self.server.capabilities.resources
      if not cap or not cap.subscribe or
         not self.subscribed_resources or not self.subscribed_resources[params.uri] then
        return
      end
      self.subscribed_resources[params.uri](params.uri)
    end
  }
  for i, v in ipairs({"prompts", "resources", "tools"}) do
    methods[string.format("notifications/%s/list_changed", v)] = function(params)
      local cap = self.server.capabilities[v]
      if not cap or not cap.listChanged then
        return
      end
      local list, err = get_list(self, v)
      if not list then
        ngx_log(ngx.ERR, err)
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

local function expose_roots_impl(self, roots)
  local template, err = mcp.utils.uri_template("file://{+path}")
  if not template then
    error(err)
  end
  self.exposed_roots = {}
  for i, v in ipairs(roots) do
    if v.path and v.path ~= "" then
      table.insert(self.exposed_roots, {
        uri = template:expand({path = v.path}),
        name = type(v.name) == "string" and v.name or nil
      })
    end
  end
end

local _MT = {
  __index = {
    _NAME = _M._NAME,
    wait_background_tasks = mcp.session.wait_background_tasks
  }
}

function _MT.__index.initialize(self, roots, sampling_cb)
  if type(roots) == "table" and #roots > 0 then
    expose_roots_impl(self, roots)
  end
  self.sampling_callback = sampling_cb
  mcp.session.initialize(self, define_methods(self))
  local capabilities = {roots = true, sampling = sampling_cb}
  local res, err = mcp.session.send_request(self, "initialize", {capabilities, self.name, self.version})
  if not res then
    self.conn:close()
    return nil, err
  end
  self.server = {
    protocol = res.protocolVersion,
    capabilities = res.capabilities,
    info = res.serverInfo,
    instructions = res.instructions
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

function _MT.__index.expose_roots(self, roots)
  local original_roots = self.exposed_roots
  if type(roots) == "table" and #roots > 0 then
    expose_roots_impl(self, roots)
  else
    self.exposed_roots = nil
  end
  local ok, err = mcp.session.send_notification(self, "list_changed", {"roots"})
  if not ok then
    self.exposed_roots = original_roots
    return nil, err
  end
  return true
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

function _MT.__index.subscribe_resource(self, uri, cb)
  if type(uri) ~= "string" then
    error("resource uri MUST be a string.")
  end
  if not cb then
    error("callback of subscribed resource MUST be set")
  end
  if not self.server.capabilities.resources then
    return nil, string.format("%s v%s has no resources capability", self.server.info.name, self.server.info.version)
  end
  if not self.server.capabilities.resources.subscribe then
    return nil, string.format("%s v%s has no resource subscription capability", self.server.info.name, self.server.info.version)
  end
  if self.subscribed_resources and self.subscribed_resources[uri] then
    return nil, string.format("resource %s had been subscribed", uri)
  end
  local res, err = mcp.session.send_request(self, "subscribe_resource", {uri})
  if not res then
    return nil, err
  end
  if self.subscribed_resources then
    self.subscribed_resources[uri] = cb
  else
    self.subscribed_resources = {[uri] = cb}
  end
  return true
end

function _MT.__index.unsubscribe_resource(self, uri)
  if type(uri) ~= "string" then
    error("resource uri MUST be a string.")
  end
  if not self.server.capabilities.resources then
    return nil, string.format("%s v%s has no resources capability", self.server.info.name, self.server.info.version)
  end
  if not self.server.capabilities.resources.subscribe then
    return nil, string.format("%s v%s has no resource subscription capability", self.server.info.name, self.server.info.version)
  end
  local res, err = mcp.session.send_request(self, "unsubscribe_resource", {uri})
  if not res then
    return nil, err
  end
  if self.subscribed_resources then
    self.subscribed_resources[uri] = nil
  end
  return true
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

function _M.new(transport, options)
  local conn, err = transport.client(options)
  if not conn then
    return nil, err
  end
  return mcp.session.new(conn, options.name, options.version, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
