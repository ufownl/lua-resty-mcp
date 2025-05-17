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

local ngx_semaphore = require("ngx.semaphore")

local function push_progress(self, progress_token, rid)
  return function(progress, total, message)
    if type(progress) ~= "number" then
      error("progress MUST be a number")
    end
    if total and type(total) ~= "number" then
      error("total MUST be a number")
    end
    if message and type(message) ~= "string" then
      error("message MUST be a string")
    end
    if not self.processing_requests[rid] then
      return nil, "cancelled"
    end
    if not progress_token then
      return true
    end
    return mcp.session.send_notification(self, "progress", {progress_token, progress, total, message})
  end
end

local function get_list(self, category, timeout, field_name)
  local list = {}
  local cursor
  repeat
    local res, err, errobj = mcp.session.send_request(self, "list", {category, cursor}, tonumber(timeout))
    if not res then
      return nil, err, errobj
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
    ["roots/list"] = function(params, rid)
      if not rid then
        return
      end
      return {
        roots = self.exposed_roots or {}
      }
    end,
    ["sampling/createMessage"] = self.sampling_callback and function(params, rid)
      if not rid then
        return
      end
      local ok, err = mcp.validator.CreateMessageRequest(params)
      if not ok then
        return nil, -32602, "Invalid params", {errmsg = err}
      end
      local progress_token = type(params._meta) == "table" and params._meta.progressToken
      if progress_token and type(progress_token) ~= "string" and (type(progress_token) ~= "number" or progress_token % 1 ~= 0) then
        progress_token = nil
      end
      self.processing_requests[rid] = true
      local result, code, message, data = self.sampling_callback(params, {
        session = self,
        _meta = params._meta,
        push_progress = push_progress(self, progress_token, rid),
        cancelled = function()
          return not self.processing_requests[rid]
        end
      })
      if not self.processing_requests[rid] then
        return
      end
      self.processing_requests[rid] = nil
      if not result then
        return nil, code, message, data
      end
      if type(result) == "table" then
        if not result.role then
          result.role = "assistant"
        end
        if not result.model then
          result.model = "unknown"
        end
        assert(mcp.validator.CreateMessageResult(result))
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
        ngx.log(ngx.ERR, err)
        return
      end
      local cap = self.server.capabilities.resources
      if not cap or not cap.subscribe or
         not self.subscribed_resources or not self.subscribed_resources[params.uri] then
        return
      end
      self.subscribed_resources[params.uri](params.uri, {session = self})
    end,
    ["notifications/message"] = function(params)
      local ok, err = mcp.validator.LoggingMessageNotification(params)
      if not ok then
        ngx.log(ngx.ERR, err)
        return
      end
      local handler = self.event_handlers and self.event_handlers.message
      if handler then
        handler(params, {session = self})
      end
    end
  }
  local categories = {
    prompts = {"discovered_prompts"},
    resources = {"discovered_resources", "discovered_resource_templates"},
    tools = {"discovered_tools"}
  }
  for k, v in pairs(categories) do
    methods[string.format("notifications/%s/list_changed", k)] = function(params)
      local cap = self.server.capabilities[k]
      if not cap or not cap.listChanged then
        return
      end
      for i, key in ipairs(v) do
        if self.server[key] then
          if type(self.server[key]) == "number" then
            self.server[key] = self.server[key] + 1
            local ok, err = self.semaphores[key]:wait(10)
            if not ok then
              self.server[key] = self.server[key] - 1
              ngx.log(ngx.ERR, err)
              return
            end
          end
          self.server[key] = nil
        end
      end
      local handler = self.event_handlers and self.event_handlers[k.."/list_changed"]
      if handler then
        handler(params, {session = self})
      end
    end
  end
  return mcp.session.inject_common(self, methods)
end

local function list_impl(self, category, timeout)
  if not self.server.capabilities[category] then
    return nil, string.format("%s v%s has no %s capability", self.server.info.name, self.server.info.version, category)
  end
  if not self.server.capabilities[category].listChanged then
    return get_list(self, category, timeout)
  end
  local key = "discovered_"..category
  repeat
    if self.server[key] then
      if type(self.server[key]) == "number" then
        self.server[key] = self.server[key] + 1
        local ok, err = self.semaphores[key]:wait(tonumber(timeout) or 10)
        if not ok then
          self.server[key] = self.server[key] - 1
          return nil, err
        end
      end
    else
      self.server[key] = 0
      local list, err, errobj = get_list(self, category, timeout)
      local n = self.server[key]
      self.server[key] = list
      if n > 0 then
        self.semaphores[key]:post(n)
      end
      if err then
        return nil, err, errobj
      end
    end
  until self.server[key]
  return self.server[key]
end

local function expose_roots_impl(self, roots)
  local template = assert(mcp.utils.uri_template("file://{+path}"))
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

function _MT.__index.initialize(self, options, timeout)
  if options and type(options.roots) == "table" and #options.roots > 0 then
    expose_roots_impl(self, options.roots)
  end
  self.sampling_callback = options and options.sampling_callback
  mcp.session.initialize(self, define_methods(self))
  local capabilities = {roots = true, sampling = self.sampling_callback}
  local res, err, errobj = mcp.session.send_request(self, "initialize", {capabilities, self.options.name, self.options.version}, tonumber(timeout))
  if not res then
    self.conn:close()
    return nil, err, errobj
  end
  self.server = {
    protocol = res.protocolVersion,
    capabilities = res.capabilities,
    info = res.serverInfo,
    instructions = res.instructions
  }
  self.semaphores = {}
  local categories = {
    prompts = {"discovered_prompts"},
    resources = {"discovered_resources", "discovered_resource_templates"},
    tools = {"discovered_tools"}
  }
  for category, keys in pairs(categories) do
    local cap = self.server.capabilities[category]
    if cap and cap.listChanged then
      for i, k in ipairs(keys) do
        local sema, err = ngx_semaphore.new()
        if not sema then
          return nil, err
        end
        self.semaphores[k] = sema
      end
    end
  end
  self.event_handlers = options and options.event_handlers
  local ok, err = mcp.session.send_notification(self, "initialized", {}, {
    -- NOTE: This option acts as a hint flag to tell the transport to initiate a
    -- GET SSE stream at this point if necessary.
    get_sse = true
  })
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
  if type(roots) == "table" and #roots > 0 then
    expose_roots_impl(self, roots)
  else
    self.exposed_roots = nil
  end
  local ok, err = mcp.session.send_notification(self, "list_changed", {"roots"})
  if not ok then
    return nil, err
  end
  return true
end

function _MT.__index.list_prompts(self, timeout)
  return list_impl(self, "prompts", timeout)
end

function _MT.__index.get_prompt(self, name, args, timeout, progress_cb)
  if type(name) ~= "string" then
    error("prompt name MUST be a string.")
  end
  if args and (type(args) ~= "table" or #args > 0) then
    error("arguments of prompt MUST be a dict.")
  end
  if not self.server.capabilities.prompts then
    return nil, string.format("%s v%s has no prompts capability", self.server.info.name, self.server.info.version)
  end
  local req_opts = progress_cb and {progress_callback = progress_cb} or nil
  return mcp.session.send_request(self, "get_prompt", {name, args}, tonumber(timeout), req_opts)
end

function _MT.__index.list_resources(self, timeout)
  return list_impl(self, "resources", timeout)
end

function _MT.__index.list_resource_templates(self, timeout)
  if not self.server.capabilities.resources then
    return nil, string.format("%s v%s has no resources capability", self.server.info.name, self.server.info.version)
  end
  if not self.server.capabilities.resources.listChanged then
    return get_list(self, "resources/templates", timeout, "resourceTemplates")
  end
  repeat
    if self.server.discovered_resource_templates then
      if type(self.server.discovered_resource_templates) == "number" then
        self.server.discovered_resource_templates = self.server.discovered_resource_templates + 1
        local ok, err = self.semaphores.discovered_resource_templates:wait(tonumber(timeout) or 10)
        if not ok then
          self.server.discovered_resource_templates = self.server.discovered_resource_templates - 1
          return nil, err
        end
      end
    else
      self.server.discovered_resource_templates = 0
      local list, err, errobj = get_list(self, "resources/templates", timeout, "resourceTemplates")
      local n = self.server.discovered_resource_templates
      self.server.discovered_resource_templates = list
      if n > 0 then
        self.semaphores.discovered_resource_templates:post(n)
      end
      if err then
        return nil, err, errobj
      end
    end
  until self.server.discovered_resource_templates
  return self.server.discovered_resource_templates
end

function _MT.__index.read_resource(self, uri, timeout, progress_cb)
  if type(uri) ~= "string" then
    error("resource uri MUST be a string.")
  end
  if not self.server.capabilities.resources then
    return nil, string.format("%s v%s has no resources capability", self.server.info.name, self.server.info.version)
  end
  local req_opts = progress_cb and {progress_callback = progress_cb} or nil
  return mcp.session.send_request(self, "read_resource", {uri}, tonumber(timeout), req_opts)
end

function _MT.__index.subscribe_resource(self, uri, cb, timeout)
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
  local res, err, errobj = mcp.session.send_request(self, "subscribe_resource", {uri}, tonumber(timeout))
  if not res then
    return nil, err, errobj
  end
  if self.subscribed_resources then
    self.subscribed_resources[uri] = cb
  else
    self.subscribed_resources = {[uri] = cb}
  end
  return true
end

function _MT.__index.unsubscribe_resource(self, uri, timeout)
  if type(uri) ~= "string" then
    error("resource uri MUST be a string.")
  end
  if not self.server.capabilities.resources then
    return nil, string.format("%s v%s has no resources capability", self.server.info.name, self.server.info.version)
  end
  if not self.server.capabilities.resources.subscribe then
    return nil, string.format("%s v%s has no resource subscription capability", self.server.info.name, self.server.info.version)
  end
  local res, err, errobj = mcp.session.send_request(self, "unsubscribe_resource", {uri}, tonumber(timeout))
  if not res then
    return nil, err, errobj
  end
  if self.subscribed_resources then
    self.subscribed_resources[uri] = nil
  end
  return true
end

function _MT.__index.list_tools(self, timeout)
  return list_impl(self, "tools", timeout)
end

function _MT.__index.call_tool(self, name, args, timeout, progress_cb)
  if type(name) ~= "string" then
    error("tool name MUST be a string.")
  end
  if args and (type(args) ~= "table" or #args > 0) then
    error("arguments of tool calling MUST be a dict.")
  end
  if not self.server.capabilities.tools then
    return nil, string.format("%s v%s has no tools capability", self.server.info.name, self.server.info.version)
  end
  local req_opts = progress_cb and {progress_callback = progress_cb} or nil
  return mcp.session.send_request(self, "call_tool", {name, args}, tonumber(timeout), req_opts)
end

function _MT.__index.prompt_complete(self, name, arg_name, arg_value, timeout)
  if type(name) ~= "string" then
    error("prompt name MUST be a string.")
  end
  if type(arg_name) ~= "string" then
    error("argument name MUST be a string.")
  end
  if type(arg_value) ~= "string" then
    error("argument value MUST be a string.")
  end
  if not self.server.capabilities.completions then
    return nil, string.format("%s v%s has no completions capability", self.server.info.name, self.server.info.version)
  end
  return mcp.session.send_request(self, "prompt_complete", {name, arg_name, arg_value}, tonumber(timeout))
end

function _MT.__index.resource_complete(self, uri, arg_name, arg_value, timeout)
  if type(uri) ~= "string" then
    error("resource URI MUST be a string.")
  end
  if type(arg_name) ~= "string" then
    error("argument name MUST be a string.")
  end
  if type(arg_value) ~= "string" then
    error("argument value MUST be a string.")
  end
  if not self.server.capabilities.completions then
    return nil, string.format("%s v%s has no completions capability", self.server.info.name, self.server.info.version)
  end
  return mcp.session.send_request(self, "resource_complete", {uri, arg_name, arg_value}, tonumber(timeout))
end

function _MT.__index.set_log_level(self, level, timeout)
  if type(level) ~= "string" then
    error("log level MUST be a string.")
  end
  if not self.server.capabilities.logging then
    return nil, string.format("%s v%s has no logging capability", self.server.info.name, self.server.info.version)
  end
  return mcp.session.send_request(self, "set_log_level", {level}, tonumber(timeout))
end

function _MT.__index.ping(self, timeout)
  return mcp.session.send_request(self, "ping", {}, tonumber(timeout))
end

function _M.new(transport, options)
  local conn, err = transport.client(options)
  if not conn then
    return nil, err
  end
  return mcp.session.new(conn, options, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
