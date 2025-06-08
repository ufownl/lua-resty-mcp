local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils")
}

local _M = {
  _NAME = "resty.mcp.transport.websocket.server",
  _VERSION = mcp.version.module
}

local cjson = require("cjson.safe")
local websocket = require("resty.websocket.server")

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

function _MT.__index.send(self, msg, meta)
  assert(type(msg) == "table", "message MUST be a table.")
  if msg.error and msg.error.code >= 0 then
    return true
  end
  local data = assert(cjson.encode(msg))
  local res, err = self.conn:send_text(data)
  if not res then
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
        return nil, err
      end
      data = data..frag
    end
    if tp == "text" then
      return data
    elseif tp == "ping" then
      local res, err = self.conn:send_pong()
      if not res then
        return nil, err
      end
    elseif tp == "close" then
      return nil, "closed"
    elseif tp ~= "pong" then
      if err then
        return nil, self.conn.fatal and err or "timeout"
      end
      local res, err = self.conn:send_close(1003, "unsupported data type")
      if not res then
        return nil, err
      end
      return nil, "unsupported data type"
    end
  end
end

function _MT.__index.close(self)
  local res, err = self.conn:send_close()
  if not res then
    ngx.log(ngx.ERR, "websocket: ", err)
  end
end

function _M.new(options)
  local conn, err = websocket:new(options and options.websocket_opts)
  if not conn then
    return nil, err
  end
  return setmetatable({conn = conn}, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
