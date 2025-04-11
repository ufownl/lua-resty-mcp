local mcp = {
  version = require("resty.mcp.version")
}

local _MT = {
  __index = {}
}

function _MT.__index.send(self, data)
  if type(data) ~= "string" then
    error("data MUST be a string.")
  end
  if not self.stdout then
    return nil, "closed"
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

local _M = {
  _NAME = "resty.mcp.transport.stdio.server",
  _VERSION = mcp.version.module
}

function _M.new(options)
  return setmetatable({
    stdin = io.input(),
    stdout = io.output(),
    blocking_io = true
  }, _MT)
end

return _M
