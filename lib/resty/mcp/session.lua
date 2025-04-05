local mcp = {
  version = require("resty.mcp.version"),
  rpc = require("resty.mcp.protocol.rpc"),
  protocol = require("resty.mcp.protocol")
}

local cjson = require("cjson.safe")
local ngx_semaphore = require("ngx.semaphore")
local ngx_log = ngx.log
local ngx_thread_spawn = ngx.thread.spawn
local ngx_thread_kill = ngx.thread.kill
local ngx_thread_wait = ngx.thread.wait
local unpack = table.unpack or unpack

local _M = {
  _NAME = "resty.mcp.session",
  _VERSION = mcp.version.module
}

function _M.new(conn, name, mt)
  return setmetatable({
    conn = conn,
    name = name,
    pending_requests = {}
  }, mt or {__index = _M})
end

function _M.initialize(self, methods)
  self.main_loop = ngx_thread_spawn(function()
    while true do
      local msg, err = self.conn:recv()
      if msg then
        local reply = mcp.rpc.handle(msg, methods, function(rid, result, errobj)
          local cb = self.pending_requests[rid]
          if not cb then
            ngx_log(ngx.ERR, "response: request id mismatch")
            return
          end
          self.pending_requests[rid] = nil
          cb(result, errobj)
        end)
        if reply then
          local ok, err = self.conn:send(reply)
          if not ok then
            ngx_log(ngx.ERR, "transport: ", err)
            break
          end
        end
      elseif err ~= "timeout" then
        break
      end
    end
    self.main_loop = nil
  end)
end

function _M.shutdown(self, kill)
  local co = self.main_loop
  if co then
    self.conn:close()
    local fn = kill and ngx_thread_kill or ngx_thread_wait
    local ok, err = fn(co)
    if not ok then
      ngx_log(ngx.ERR, "ngx thread: ", err)
    end
  end
end

function _M.send_request(self, name, args, timeout)
  if coroutine.running() == self.main_loop then
    error("cannot call send_request in main loop thread")
  end
  if type(name) ~= "string" or type(args) ~= "table" then
    error("invalid request format")
  end
  local msg, rid, err = mcp.protocol.request[name](unpack(args))
  if not msg then
    return nil, err
  end
  local co = ngx_thread_spawn(function()
    local sema, err = ngx_semaphore.new()
    if not sema then
      return nil, err
    end
    local ok, err = self.conn:send(msg)
    if not ok then
      return nil, err
    end
    local result, errobj
    self.pending_requests[rid] = function(r, e)
      result = r
      errobj = e
      sema:post()
    end
    local ok, err = sema:wait(tonumber(timeout) or 10)
    if not ok then
      return nil, err
    end
    if errobj then
      if errobj.data then
        local data, err = cjson.encode(errobj.data)
        return nil, string.format("%d %s %s", errobj.code, errobj.message, data or err)
      end
      return nil, string.format("%d %s", errobj.code, errobj.message)
    end
    return result
  end)
  local ok, res, err = ngx_thread_wait(co)
  if not ok then
    return nil, res
  end
  return res, err
end

function _M.send_notification(self, name, args)
  if type(name) ~= "string" or type(args) ~= "table" then
    error("invalid notification format")
  end
  local msg, err = mcp.protocol.notification[name](unpack(args))
  if not msg then
    return nil, err
  end
  local ok, err = self.conn:send(msg)
  if not ok then
    return nil, err
  end
  return true
end

return _M
