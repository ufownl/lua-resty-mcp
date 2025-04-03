local resty_signal = require("resty.signal")
local ngx_pipe = require("ngx.pipe")
local ngx_log = ngx.log

local _STDIO_MT = {
  __index = {}
}

function _STDIO_MT.__index.send(self, data)
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

function _STDIO_MT.__index.recv(self)
  local data = self.stdin:read("*l")
  if not data then
    return nil, "EOF"
  end
  return data
end

function _STDIO_MT.__index.close(self)
  if not self.stdout then
    return
  end
  self.stdout:close()
  self.stdout = nil
end

local _PIPE_MT = {
  __index = {}
}

function _PIPE_MT.__index.send(self, data)
  if type(data) ~= "string" then
    error("data MUST be a string.")
  end
  if not self.pipe then
    return nil, "closed"
  end
  local nbytes, err = self.pipe:write({data, "\n"})
  if not nbytes then
    return nil, err
  end
  return true
end

function _PIPE_MT.__index.recv(self)
  if not self.pipe then
    return nil, "closed"
  end
  local data, err, partial = self.pipe:stdout_read_line()
  if not data then
    return nil, err
  end
  return data
end

function _PIPE_MT.__index.close(self)
  if not self.pipe then
    return
  end
  local ok, err = self.pipe:shutdown("stdin")
  if not ok then
    ngx_log(ngx.ERR, "ngx pipe: ", err)
    self.pipe = nil
    return
  end
  for i, sig in ipairs({"TERM", "KILL"}) do
    local ok, err = self.pipe:kill(resty_signal.signum(sig))
    if not ok then
      ngx_log(ngx.ERR, "ngx pipe: ", err)
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

local _M = {
  _NAME = "resty.mcp.transport.stdio",
  _VERSION = "1.0"
}

function _M.new(subproc_opts)
  if not subproc_opts then
    return setmetatable({stdin = io.input(), stdout = io.output()}, _STDIO_MT)
  end
  if type(subproc_opts) ~= "table" then
    error("options of subprocess MUST be a table.")
  end
  if subproc_opts.pipe_opts then
    subproc_opts.pipe_opts.merge_stderr = false
  end
  local pipe, err = ngx_pipe.spawn(subproc_opts.command, subproc_opts.pipe_opts)
  if not pipe then
    return nil, err
  end
  return setmetatable({pipe = pipe}, _PIPE_MT)
end

return _M
