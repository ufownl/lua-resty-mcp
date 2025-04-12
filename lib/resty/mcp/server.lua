local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  session = require("resty.mcp.session"),
  protocol = require("resty.mcp.protocol")
}

local _M = {
  _NAME = "resty.mcp.server",
  _VERSION = mcp.version.module
}

local ngx_log = ngx.log

local function define_methods(self)
  return {
    initialize = function(params)
      if type(params) ~= "table" or
         type(params.protocolVersion) ~= "string" or
         type(params.capabilities) ~= "table" or
         type(params.clientInfo) ~= "table" then
        return nil, -32602, "Invalid params"
      end
      self.client = {
        protocol = params.protocolVersion,
        capabilities = params.capabilities,
        info = params.clientInfo
      }
      return mcp.protocol.result.initialize(self.capabilities, self.name, self.version)
    end,
    ["notifications/initialized"] = function(params)
      self.initialized = true
    end
  }
end

local _MT = {
  __index = {
    _NAME = _M._NAME,
    wait_background_tasks = mcp.session.wait_background_tasks
  }
}

function _MT.__index.run(self, capabilities, pagination)
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
  if type(capabilities) == "table" then
    for k, v in pairs(self.capabilities) do
      local val = capabilities[k]
      local typ = type(val)
      if typ == "table" then
        self.capabilities[k] = val
      elseif typ ~= "nil" and not val then
        self.capabilities[k] = nil
      end
    end
  end
  self.pagination = {
    prompts = 0,
    resources = 0,
    tools = 0
  }
  if type(pagination) == "table" then
    for k, v in pairs(self.pagination) do
      local val = tonumber(pagination[k])
      if val and val > 0 then
        self.pagination[k] = math.floor(val)
      end
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
