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

function _MT.__index.send(self, msg, meta)
  assert(type(msg) == "table", "message MUST be a table.")
  if msg.error and msg.error.code >= 0 then
    return true
  end
  local data = assert(cjson.encode(msg))
  local nbytes, err = self.pipe:write({data, "\n"})
  if not nbytes then
    return nil, err
  end
  return true
end

function _MT.__index.recv(self)
  local data, err, partial = self.pipe:stdout_read_line()
  if not data then
    return nil, err
  end
  return data
end

function _MT.__index.close(self)
  local ok, err = self.pipe:shutdown("stdin")
  if not ok then
    if err ~= "closed" then
      ngx.log(ngx.ERR, "ngx pipe: ", err)
    end
    return
  end
  for i, sig in ipairs({"TERM", "KILL"}) do
    local ok, err = self.pipe:kill(resty_signal.signum(sig))
    if not ok then
      if err ~= "closed" then
        ngx.log(ngx.ERR, "ngx pipe: ", err)
      end
      return
    end
    local ok, err = self.pipe:wait()
    if ok or err == "exit" or err == "signal" or err == "exited" then
      return
    end
  end
end

function _M.new(options)
  assert(type(options) == "table", "options of stdio client transport MUST be a table.")
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
