local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils")
}

local _M = {
  _NAME = "resty.mcp.transport.stdio.server",
  _VERSION = mcp.version.module
}

local cjson = require("cjson.safe")

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
  if not self.stdout then
    return nil, "closed"
  end
  local data, err = cjson.encode(msg)
  if not data then
    error(err)
  end
  self.stdout:write(data, "\n")
  self.stdout:flush()
  return true
end

function _MT.__index.recv(self)
  local data = self.stdin:read("*l")
  if not data then
    return nil, "EOF"
  end
  return data
end

function _MT.__index.close(self)
  if not self.stdout then
    return
  end
  self.stdout:close()
  self.stdout = nil
end

function _M.new(options)
  return setmetatable({
    stdin = io.input(),
    stdout = io.output(),
    blocking_io = true
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
