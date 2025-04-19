local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  session = require("resty.mcp.session"),
  protocol = require("resty.mcp.protocol"),
  validator = require("resty.mcp.protocol.validator"),
  prompt = require("resty.mcp.prompt"),
  resource = require("resty.mcp.resource"),
  resource_template = require("resty.mcp.resource_template"),
  tool = require("resty.mcp.tool")
}

local _M = {
  _NAME = "resty.mcp.server",
  _VERSION = mcp.version.module
}

local function wrapper(server, rid)
  local function rrid()
    return {related_request = rid}
  end
  return setmetatable({
    register = function(_, component)
      return server:register(component, rrid)
    end,
    unregister_prompt = function(_, name)
      return server:unregister_prompt(name, rrid)
    end,
    unregister_resource = function(_, uri)
      return server:unregister_resource(uri, rrid)
    end,
    resource_updated = function(_, uri)
      return server:resource_updated(uri, rrid)
    end,
    unregister_tool = function(_, name)
      return server:unregister_tool(name, rrid)
    end,
    list_roots = function(_, timeout)
      return server:list_roots(timeout, rrid)
    end,
    create_message = function(_, messages, max_tokens, options, timeout)
      return server:create_message(messages, max_tokens, options, timeout, rrid)
    end
  }, {
    __index = function(self, key)
      return rawget(self, key) or server[key]
    end,
    __newindex = function(_, key, val)
      server[key] = val
    end
  })
end

local function paginate(cursor, page_size, total_size)
  local i = 1
  if cursor then
    local dc = ngx.decode_args(cursor)
    if not dc or not tonumber(dc.idx) or tonumber(dc.idx) < 1 then
      return nil, nil, "invalid cursor"
    end
    i = math.floor(dc.idx)
  end
  return i, math.min(i + page_size - 1, total_size)
end

local function define_methods(self, event_handlers)
  local methods = {
    initialize = function(params)
      local ok, err = mcp.validator.InitializeRequest(params)
      if not ok then
        return nil, -32602, "Invalid params", {errmsg = err}
      end
      self.client = {
        protocol = params.protocolVersion,
        capabilities = params.capabilities,
        info = params.clientInfo
      }
      return mcp.protocol.result.initialize(self.capabilities, self.options.name, self.options.version, self.instructions)
    end,
    ["notifications/initialized"] = function(params)
      self.initialized = true
      local handler = event_handlers and event_handlers.initialized
      if handler then
        handler(params, {session = self})
      end
    end,
    ["notifications/roots/list_changed"] = function(params)
      if not self.client.capabilities.roots or not self.client.capabilities.roots.listChanged then
        return
      end
      if self.client.discovered_roots then
        local ok, err = mcp.utils.spin_until(function()
          return type(self.client.discovered_roots) == "table" or not self.client.discovered_roots
        end)
        if not ok then
          ngx.log(ngx.ERR, err)
          return
        end
        self.client.discovered_roots = nil
      end
      local handler = event_handlers and event_handlers["roots/list_changed"]
      if handler then
        handler(params, {session = self})
      end
    end,
    ["prompts/get"] = self.capabilities.prompts and function(params, rid)
      local ok, err = mcp.validator.GetPromptRequest(params)
      if not ok then
        return nil, -32602, "Invalid params", {errmsg = err}
      end
      local prompt = self.available_prompts and self.available_prompts.dict[params.name]
      if not prompt then
        return nil, -32602, "Invalid prompt name", {name = params.name}
      end
      return prompt:get(params.arguments, {
        session = wrapper(self, rid),
        _meta = params._meta
      })
    end or nil,
    ["resources/templates/list"] = self.capabilities.resources and function(params)
      local ok, err = mcp.validator.ListResourceTemplatesRequest(params)
      if not ok then
        return nil, -32602, "Invalid params", {errmsg = err}
      end
      if not self.available_resource_templates then
        return mcp.protocol.result.list("resourceTemplates", {})
      end
      local page_size = self.pagination.resources
      if page_size > 0 and #self.available_resource_templates > page_size then
        local l, r, err = paginate(params and params.cursor, page_size, #self.available_resource_templates)
        if err then
          return nil, -32602, "Invalid params", {errmsg = err}
        end
        local page = {}
        for j = l, r do
          table.insert(page, self.available_resource_templates[j])
        end
        return mcp.protocol.result.list("resourceTemplates", page, r < #self.available_resource_templates and ngx.encode_args({idx = r + 1}) or nil)
      else
        return mcp.protocol.result.list("resourceTemplates", self.available_resource_templates)
      end
    end or nil,
    ["resources/read"] = self.capabilities.resources and function(params, rid)
      local ok, err = mcp.validator.ReadResourceRequest(params)
      if not ok then
        return nil, -32602, "Invalid params", {errmsg = err}
      end
      local resource = self.available_resources and self.available_resources.dict[params.uri]
      if resource then
        return resource:read({
          session = wrapper(self, rid),
          _meta = params._meta
        })
      end
      if self.available_resource_templates then
        local session = wrapper(self, rid)
        for i, resource_template in ipairs(self.available_resource_templates) do
          local result, code, message, data = resource_template:read(params.uri, {
            session = session,
            _meta = params._meta
          })
          if result then
            return result
          end
          if code ~= -32002 then
            return nil, code, message, data
          end
        end
      end
      return nil, -32002, "Resource not found", {uri = params.uri}
    end or nil,
    ["resources/subscribe"] = self.capabilities.resources and function(params)
      local ok, err = mcp.validator.SubscribeRequest(params)
      if not ok then
        return nil, -32602, "Invalid params", {errmsg = err}
      end
      if self.subscribed_resources and self.subscribed_resources[params.uri] then
        return {}
      end
      local resource = self.available_resources and self.available_resources.dict[params.uri]
      if resource then
        if self.subscribed_resources then
          self.subscribed_resources[params.uri] = true
        else
          self.subscribed_resources = {[params.uri] = true}
        end
        return {}
      end
      if self.available_resource_templates then
        for i, resource_template in ipairs(self.available_resource_templates) do
          if resource_template:test(params.uri) then
            if self.subscribed_resources then
              self.subscribed_resources[params.uri] = true
            else
              self.subscribed_resources = {[params.uri] = true}
            end
            return {}
          end
        end
      end
      return nil, -32002, "Resource not found", {uri = params.uri}
    end or nil,
    ["resources/unsubscribe"] = self.capabilities.resources and function(params)
      local ok, err = mcp.validator.UnsubscribeRequest(params)
      if not ok then
        return nil, -32602, "Invalid params", {errmsg = err}
      end
      if self.subscribed_resources then
        self.subscribed_resources[params.uri] = nil
      end
      return {}
    end or nil,
    ["tools/call"] = self.capabilities.tools and function(params, rid)
      local ok, err = mcp.validator.CallToolRequest(params)
      if not ok then
        return nil, -32602, "Invalid params", {errmsg = err}
      end
      local tool = self.available_tools and self.available_tools.dict[params.name]
      if not tool then
        return nil, -32602, "Unknown tool", {name = params.name}
      end
      return tool(params.arguments, {
        session = wrapper(self, rid),
        _meta = params._meta
      })
    end or nil
  }
  local validator = {
    mcp.validator.ListPromptsRequest,
    mcp.validator.ListResourcesRequest,
    mcp.validator.ListToolsRequest
  }
  for i, cap_k in ipairs({"prompts", "resources", "tools"}) do
    if self.capabilities[cap_k] then
      methods[cap_k.."/list"] = function(params)
        local ok, err = validator[i](params)
        if not ok then
          return nil, -32602, "Invalid params", {errmsg = err}
        end
        local prop = self["available_"..cap_k]
        if not prop then
          return mcp.protocol.result.list(cap_k, {})
        end
        local page_size = self.pagination[cap_k]
        if page_size > 0 and #prop.list > page_size then
          local l, r, err = paginate(params and params.cursor, page_size, #prop.list)
          if err then
            return nil, -32602, "Invalid params", {errmsg = err}
          end
          local page = {}
          for j = l, r do
            table.insert(page, prop.list[j])
          end
          return mcp.protocol.result.list(cap_k, page, r < #prop.list and ngx.encode_args({idx = r + 1}) or nil)
        else
          return mcp.protocol.result.list(cap_k, prop.list)
        end
      end
    end
  end
  return methods
end

local function list_changed(self, category, rrid)
  if self.initialized and self.capabilities[category] and self.capabilities[category].listChanged then
    return mcp.session.send_notification(self, "list_changed", {category}, rrid and rrid() or nil)
  end
  return true
end

local function register_impl(self, component, category, key_field, rrid)
  local prop = self["available_"..category]
  if prop then
    if prop.dict[component[key_field]] then
      return nil, string.format("%s (%s: %s) had been registered", string.sub(category, 1, -2), key_field, component[key_field])
    end
    table.insert(prop.list, component)
    prop.dict[component[key_field]] = component
  else
    self["available_"..category] = {
      list = {component},
      dict = {[component[key_field]] = component}
    }
  end
  return list_changed(self, category, rrid)
end

local function register_resource_template(self, resource_template)
  if self.available_resource_templates then
    for i, v in ipairs(self.available_resource_templates) do
      if resource_template.uri_template.pattern == v.uri_template.pattern then
        return nil, string.format("resource template (pattern: %s) had been registered", resource_template.uri_template.pattern)
      end
    end
    table.insert(self.available_resource_templates, resource_template)
  else
    self.available_resource_templates = {resource_template}
  end
  return true
end

local function unregister_impl(self, key, category, key_field, rrid)
  local prop = self["available_"..category]
  local component = prop and prop.dict[key]
  if not component then
    return nil, string.format("%s (%s: %s) is not registered", string.sub(category, 1, -2), key_field, key)
  end
  prop.dict[key] = nil
  for i, v in ipairs(prop.list) do
    if v == component then
      table.remove(prop.list, i)
      break
    end
  end
  return list_changed(self, category, rrid)
end

local _MT = {
  __index = {
    _NAME = _M._NAME,
    wait_background_tasks = mcp.session.wait_background_tasks
  }
}

function _MT.__index.register(self, component, rrid)
  if mcp.prompt.check(component) then
    return register_impl(self, component, "prompts", "name", rrid)
  end
  if mcp.resource.check(component) then
    return register_impl(self, component, "resources", "uri", rrid)
  end
  if mcp.resource_template.check(component) then
    return register_resource_template(self, component)
  end
  if mcp.tool.check(component) then
    return register_impl(self, component, "tools", "name", rrid)
  end
  error("unsupported component")
end

function _MT.__index.unregister_prompt(self, name, rrid)
  return unregister_impl(self, name, "prompts", "name", rrid)
end

function _MT.__index.unregister_resource(self, uri, rrid)
  return unregister_impl(self, uri, "resources", "uri", rrid)
end

function _MT.__index.unregister_resource_template(self, pattern)
  if self.available_resource_templates then
    for i, v in ipairs(self.available_resource_templates) do
      if pattern == v.uri_template.pattern then
        table.remove(self.available_resource_templates, i)
        return true
      end
    end
  end
  return nil, string.format("resource template (pattern: %s) is not registered", pattern)
end

function _MT.__index.resource_updated(self, uri, rrid)
  if not self.initialized then
    return nil, "session has not been initialized"
  end
  if not self.capabilities.resources then
    return nil, "resources capability has been disabled"
  end
  if self.subscribed_resources and self.subscribed_resources[uri] then
    return mcp.session.send_notification(self, "resource_updated", {uri}, rrid and rrid() or nil)
  end
  return true
end

function _MT.__index.unregister_tool(self, name, rrid)
  return unregister_impl(self, name, "tools", "name", rrid)
end

function _MT.__index.list_roots(self, timeout, rrid)
  if not self.initialized then
    return nil, "session has not been initialized"
  end
  if not self.client.capabilities.roots then
    return nil, string.format("%s v%s has no roots capability", self.client.info.name, self.client.info.version)
  end
  if not self.client.capabilities.roots.listChanged then
    local res, err = mcp.session.send_request(self, "list", {"roots"}, tonumber(timeout), rrid and rrid() or nil)
    if not res then
      return nil, err
    end
    return res.roots
  end
  repeat
    if self.client.discovered_roots then
      local ok, err = mcp.utils.spin_until(function()
        return type(self.client.discovered_roots) == "table" or not self.client.discovered_roots
      end, {timeout = timeout})
      if not ok then
        return nil, err
      end
    else
      self.client.discovered_roots = true
      local res, err = mcp.session.send_request(self, "list", {"roots"}, tonumber(timeout), rrid and rrid() or nil)
      if not res then
        self.client.discovered_roots = nil
        return nil, err
      end
      self.client.discovered_roots = res.roots
    end
  until self.client.discovered_roots
  return self.client.discovered_roots
end

function _MT.__index.create_message(self, messages, max_tokens, options, timeout, rrid)
  if not self.initialized then
    return nil, "session has not been initialized"
  end
  if not self.client.capabilities.sampling then
    return nil, string.format("%s v%s has no sampling capability", self.client.info.name, self.client.info.version)
  end
  return mcp.session.send_request(self, "create_message", {messages, max_tokens, options}, tonumber(timeout), rrid and rrid() or nil)
end

function _MT.__index.run(self, options)
  self.capabilities = {
    prompts = {
      listChanged = true
    },
    resources = {
      subscribe = true,
      listChanged = true
    },
    tools = {
      listChanged = true
    }
  }
  self.pagination = {
    prompts = 0,
    resources = 0,
    tools = 0
  }
  if options then
    if type(options.capabilities) == "table" then
      for k, v in pairs(self.capabilities) do
        local val = options.capabilities[k]
        local typ = type(val)
        if typ == "table" then
          self.capabilities[k] = val
        elseif typ ~= "nil" and not val then
          self.capabilities[k] = nil
        end
      end
    end
    if type(options.pagination) == "table" then
      for k, v in pairs(self.pagination) do
        local val = tonumber(options.pagination[k])
        if val and val > 0 then
          self.pagination[k] = math.floor(val)
        end
      end
    end
    if type(options.instructions) == "string" then
      self.instructions = options.instructions
    end
  end
  mcp.session.initialize(self, define_methods(self, options and options.event_handlers))
end

function _MT.__index.shutdown(self)
  mcp.session.shutdown(self, true)
end

function _M.new(transport, options)
  local conn, err = transport.server(options)
  if not conn then
    return nil, err
  end
  return mcp.session.new(conn, options, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
