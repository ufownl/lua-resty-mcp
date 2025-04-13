local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  session = require("resty.mcp.session"),
  protocol = require("resty.mcp.protocol"),
  validator = require("resty.mcp.protocol.validator"),
  prompt = require("resty.mcp.prompt"),
  tool = require("resty.mcp.tool")
}

local _M = {
  _NAME = "resty.mcp.server",
  _VERSION = mcp.version.module
}

local ngx_decode_args = ngx.decode_args
local ngx_encode_args = ngx.encode_args

local function define_methods(self)
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
      return mcp.protocol.result.initialize(self.capabilities, self.name, self.version, self.instructions)
    end,
    ["notifications/initialized"] = function(params)
      self.initialized = true
    end,
    ["prompts/get"] = self.capabilities.prompts and function(params)
      local ok, err = mcp.validator.GetPromptRequest(params)
      if not ok then
        return nil, -32602, "Invalid params", {errmsg = err}
      end
      local prompt = self.available_prompts and self.available_prompts.dict[params.name]
      if not prompt then
        return nil, -32602, "Invalid prompt name", {name = params.name}
      end
      return prompt:get(params.arguments, {
        session = self,
        _meta = params._meta
      })
    end or nil,
    ["tools/call"] = self.capabilities.tools and function(params)
      local ok, err = mcp.validator.CallToolRequest(params)
      if not ok then
        return nil, -32602, "Invalid params", {errmsg = err}
      end
      local tool = self.available_tools and self.available_tools.dict[params.name]
      if not tool then
        return nil, -32602, "Unknown tool", {name = params.name}
      end
      return tool(params.arguments, {
        session = self,
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
          local l = 1
          if params and params.cursor then
            local cursor = ngx_decode_args(params.cursor)
            if not cursor or not tonumber(cursor.idx) or tonumber(cursor.idx) < 1 then
              return nil, -32602, "Invalid params", {errmsg = "invalid cursor"}
            end
            l = math.floor(cursor.idx)
          end
          local r = math.min(l + page_size - 1, #prop.list)
          local page = {}
          for j = l, r do
            table.insert(page, prop.list[j])
          end
          return mcp.protocol.result.list(cap_k, page, r < #prop.list and ngx_encode_args({idx = r + 1}) or nil)
        else
          return mcp.protocol.result.list(cap_k, prop.list)
        end
      end
    end
  end
  return methods
end

local function list_changed(self, category)
  if self.initialized and self.capabilities[category] and self.capabilities[category].listChanged then
    local ok, err = mcp.session.send_notification(self, "list_changed", {category})
    if not ok then
      return nil, err
    end
  end
  return true
end

local function register_impl(self, component, category, key_field)
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
  return list_changed(self, category)
end

local function unregister_impl(self, key, category, key_field)
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
  return list_changed(self, category)
end

local _MT = {
  __index = {
    _NAME = _M._NAME,
    wait_background_tasks = mcp.session.wait_background_tasks
  }
}

function _MT.__index.register(self, component)
  if mcp.prompt.check(component) then
    return register_impl(self, component, "prompts", "name")
  end
  if mcp.tool.check(component) then
    return register_impl(self, component, "tools", "name")
  end
  error("unsupported component")
end

function _MT.__index.unregister_prompt(self, name)
  return unregister_impl(self, name, "prompts", "name")
end

function _MT.__index.unregister_tool(self, name)
  return unregister_impl(self, name, "tools", "name")
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
  mcp.session.initialize(self, define_methods(self))
end

function _MT.__index.shutdown(self)
  mcp.session.shutdown(self, true)
end

function _M.new(transport, options)
  local conn, err = transport.server(options)
  if not conn then
    return nil, err
  end
  return mcp.session.new(conn, options.name, options.version, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
