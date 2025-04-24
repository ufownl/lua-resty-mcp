local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils")
}

local _M = {
  _NAME = "resty.mcp.transport.stdio.client",
  _VERSION = mcp.version.module
}

local cjson = require("cjson.safe")
local resty_signal = require("resty.signal")
local ngx_pipe = require("ngx.pipe")

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
  if not self.pipe then
    return nil, "closed"
  end
  local data, err = cjson.encode(msg)
  if not data then
    error(err)
  end
  local nbytes, err = self.pipe:write({data, "\n"})
  if not nbytes then
    return nil, err
  end
  return true
end

function _MT.__index.recv(self)
  if not self.pipe then
    return nil, "closed"
  end
  local data, err, partial = self.pipe:stdout_read_line()
  if not data then
    return nil, err
  end
  return data
end

function _MT.__index.close(self)
  if not self.pipe then
    return
  end
  local ok, err = self.pipe:shutdown("stdin")
  if not ok then
    ngx.log(ngx.ERR, "ngx pipe: ", err)
    self.pipe = nil
    return
  end
  for i, sig in ipairs({"TERM", "KILL"}) do
    local ok, err = self.pipe:kill(resty_signal.signum(sig))
    if not ok then
      ngx.log(ngx.ERR, "ngx pipe: ", err)
      self.pipe = nil
      return
    end
    local ok, err = self.pipe:wait()
    if ok or err == "exit" or err == "signal" or err == "exited" then
      self.pipe = nil
      return
    end
  end
end

function _M.new(options)
  if type(options) ~= "table" then
    error("options of stdio client transport MUST be a table.")
  end
  if options.pipe_opts then
    options.pipe_opts.merge_stderr = false
  end
  local pipe, err = ngx_pipe.spawn(options.command, options.pipe_opts)
  if not pipe then
    return nil, err
  end
  return setmetatable({pipe = pipe}, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
