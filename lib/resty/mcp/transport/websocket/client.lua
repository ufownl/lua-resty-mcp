local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils")
}

local _M = {
  _NAME = "resty.mcp.transport.websocket.client",
  _VERSION = mcp.version.module
}

local cjson = require("cjson.safe")
local websocket = require("resty.websocket.client")

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

function _MT.__index.send(self, msg, options)
  if type(msg) ~= "table" then
    error("message MUST be a table.")
  end
  if msg.error and msg.error.code >= 0 then
    return true
  end
  local data = assert(cjson.encode(msg))
  local res, err = self.conn:send_text(data)
  if not res then
    self.conn:close()
    return nil, err
  end
  return true
end

function _MT.__index.recv(self)
  while true do
    local data, tp, err = self.conn:recv_frame()
    while err == "again" do
      local frag, ct
      frag, ct, err = self.conn:recv_frame()
      if ct ~= "continuation" then
        self.conn:close()
        return nil, err
      end
      data = data..frag
    end
    if tp == "text" then
      return data
    elseif tp == "ping" then
      local res, err = self.conn:send_pong()
      if not res then
        self.conn:close()
        return nil, err
      end
    elseif tp == "close" then
      self.conn:set_keepalive()
      return nil, "closed"
    elseif tp ~= "pong" then
      if err then
        if self.conn.fatal then
          self.conn:close()
          return nil, err
        end
        return nil, "timeout"
      end
      local res, err = self.conn:send_close(1003, "unsupported data type")
      if not res then
        self.conn:close()
        return nil, err
      end
      self.conn:set_keepalive()
      return nil, "unsupported data type"
    end
  end
end

function _MT.__index.close(self)
  local res, err = self.conn:send_close()
  if not res then
    ngx.log(ngx.ERR, "websocket: ", err)
  end
  self.conn:set_keepalive()
end

function _M.new(options)
  if type(options) ~= "table" then
    error("options of websocket client transport MUST be a table.")
  end
  if type(options.endpoint_url) ~= "string" then
    error("endpoint URL MUST be a string")
  end
  local conn, err = websocket:new(options.websocket_opts and {
    max_payload_len = tonumber(options.websocket_opts.max_payload_len),
    max_recv_len = tonumber(options.websocket_opts.max_recv_len),
    max_send_len = tonumber(options.websocket_opts.max_send_len),
    send_unmasked = tonumber(options.websocket_opts.send_unmasked),
    timeout = tonumber(options.websocket_opts.timeout)
  })
  if not conn then
    return nil, err
  end
  local ok, err, res = conn:connect(options.endpoint_url, options.websocket_opts and {
    protocols = {"mcp"},
    origin = options.websocket_opts.origin,
    pool = options.websocket_opts.pool,
    pool_size = tonumber(options.websocket_opts.pool_size),
    backlog = tonumber(options.websocket_opts.backlog),
    ssl_verify = options.websocket_opts.ssl_verify,
    headers = options.websocket_opts.headers,
    client_cert = options.websocket_opts.client_cert,
    client_priv_key = options.websocket_opts.client_priv_key,
    host = options.websocket_opts.host,
    server_name = options.websocket_opts.server_name,
    key = options.websocket_opts.key
  })
  if not ok then
    return nil, err
  end
  return setmetatable({conn = conn}, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
