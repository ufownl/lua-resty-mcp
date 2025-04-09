local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
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
  local bg_tasks
  if not conn.blocking_io then
    local sema, err = ngx_semaphore.new()
    if not sema then
      conn:close()
      return nil, err
    end
    bg_tasks = {
      sema = sema,
      count = 0,
      waiting = 0
    }
  end
  return setmetatable({
    conn = conn,
    name = name,
    pending_requests = {},
    bg_tasks = bg_tasks
  }, mt or {__index = _M})
end

function _M.initialize(self, methods)
  self.main_loop = ngx_thread_spawn(function()
    local running_tasks = self.bg_tasks and {} or nil
    while true do
      local msg, err = self.conn:recv()
      if msg then
        local function handle_message()
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
              return nil, err
            end
          end
          return true
        end
        if running_tasks then
          local tid = mcp.utils.generate_id()
          running_tasks[tid] = ngx_thread_spawn(function()
            self.bg_tasks.count = self.bg_tasks.count + 1
            handle_message()
            self.bg_tasks.count = self.bg_tasks.count - 1
            running_tasks[tid] = nil
            if self.bg_tasks.count < 1 and self.bg_tasks.waiting > 0 then
              self.bg_tasks.sema:post(self.bg_tasks.waiting)
            end
          end)
        else
          local ok, err = handle_message()
          if not ok then
            break
          end
        end
      elseif err ~= "timeout" then
        break
      end
    end
    if running_tasks then
      local tasks = {}
      for k, v in pairs(running_tasks) do
        table.insert(tasks, v)
      end
      if #tasks > 0 then
        local ok, err = ngx_thread_wait(unpack(tasks))
        if not ok then
          ngx_log(ngx.ERR, "ngx thread: ", err)
        end
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

function _M.wait_background_tasks(self, timeout)
  if not self.bg_tasks or self.bg_tasks.count < 1 then
    return true
  end
  self.bg_tasks.waiting = self.bg_tasks.waiting + 1
  local ok, err = self.bg_tasks.sema:wait(tonumber(timeout) or 10)
  self.bg_tasks.waiting = self.bg_tasks.waiting - 1
  return ok, err
end

function _M.send_request(self, name, args, cb_or_to)
  if type(name) ~= "string" or type(args) ~= "table" then
    error("invalid request format")
  end
  local msg, rid, err = mcp.protocol.request[name](unpack(args))
  if not msg then
    return nil, err
  end
  if cb_or_to and not tonumber(cb_or_to) then
    local ok, err = self.conn:send(msg)
    if not ok then
      return nil, err
    end
    self.pending_requests[rid] = cb_or_to
    return true
  else
    if self.conn.blocking_io then
      error("blocking IO transport MUST use async mode")
    end
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
    local ok, err = sema:wait(tonumber(cb_or_to) or 10)
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
  end
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
