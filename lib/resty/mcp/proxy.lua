local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  session = require("resty.mcp.session"),
  protocol = require("resty.mcp.protocol"),
  validator = require("resty.mcp.protocol.validator"),
  transport = {
    stdio = require("resty.mcp.transport.stdio"),
    streamable_http = require("resty.mcp.transport.streamable_http"),
    websocket = require("resty.mcp.transport.websocket")
  },
  client = require("resty.mcp.client")
}

local _M = {
  _NAME = "resty.mcp.proxy",
  _VERSION = mcp.version.module
}

local cjson = require("cjson.safe")

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

local function define_methods(self, options)
  local methods = {
    initialize = function(params, rid)
      if not rid then
        return
      end
      if self.proxy_client then
        return nil, -32601, "Method not found"
      end
      local ok, err = mcp.validator.InitializeRequest(params)
      if not ok then
        return nil, -32602, "Invalid params", {errmsg = err}
      end
      local proxy_opts = {
        name = params.clientInfo.name,
        version = params.clientInfo.version
      }
      for k, v in pairs(self.options.proxy) do
        proxy_opts[k] = v;
      end
      local client, err = mcp.client.new(mcp.transport[proxy_opts.transport], proxy_opts)
      if not client then
        return nil, -32603, "Internal error", {errmsg = err}
      end
      self.proxy_client = client
      local client_opts = {roots = options.roots}
      -- TODO: sampling callback and event handlers
      local ok, err, errobj = client:initialize(client_opts, tonumber(options.request_timeout))
      if not ok then
        if errobj then
          return nil, errobj.code, errobj.message, errobj.data
        else
          return nil, -32603, "Internal error", {errmsg = err}
        end
      end
      return {
        protocolVersion = client.server.protocol,
        capabilities = client.server.capabilities,
        serverInfo = client.server.info,
        instructions = client.server.instructions
      }
    end,
    ["notifications/initialized"] = function(params)
      if not self.proxy_client or self.initialized then
        return
      end
      self.initialized = true
    end
  }
  return mcp.session.inject_common(self, methods)
end

function _MT.__index.run(self, options)
  mcp.session.initialize(self, define_methods(self, options or {}))
  local ok, err = ngx.thread.wait(self.main_loop)
  if not ok then
    ngx.log(ngx.ERR, "ngx thread: ", err)
  end
  if self.proxy_client then
    mcp.session.shutdown(self.proxy_client, true)
  end
end

function _MT.__index.shutdown(self)
  mcp.session.shutdown(self, true)
end

function _M.new(transport, options)
  if type(options) ~= "table" or type(options.proxy) ~= "table" then
    error("options of proxy MUST be a table.")
  end
  if type(options.proxy.transport) ~= "string" then
    error("transport type of proxy MUST be a string.")
  end
  local proxy_transport = mcp.transport[options.proxy.transport]
  if not proxy_transport or proxy_transport.check(transport)  then
    error(string.format("invalid transport for proxy: %s", options.proxy.transport))
  end
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
