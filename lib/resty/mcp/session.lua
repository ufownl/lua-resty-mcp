local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  rpc = require("resty.mcp.protocol.rpc"),
  validator = require("resty.mcp.protocol.validator"),
  protocol = require("resty.mcp.protocol")
}

local _M = {
  _NAME = "resty.mcp.session",
  _VERSION = mcp.version.module
}

local cjson = require("cjson.safe")
local ngx_semaphore = require("ngx.semaphore")
local unpack = table.unpack or unpack

local function handle_message(self, msg)
  local reply = mcp.rpc.handle(msg, self.methods, function(rid, result, errobj)
    local cb = self.pending_requests[rid]
    if not cb then
      ngx.log(ngx.WARN, "response: request id mismatch")
      return
    end
    self.pending_requests[rid] = nil
    cb(result, errobj)
  end)
  if reply then
    local ok, err = self.conn:send(reply)
    if not ok then
      ngx.log(ngx.ERR, "transport: ", err)
      return nil, err
    end
  end
  return true
end

local function main_loop(self)
  local running_tasks = self.bg_tasks and {} or nil
  while true do
    local msg, err = self.conn:recv()
    if msg then
      if running_tasks then
        local tid = mcp.utils.generate_id()
        running_tasks[tid] = ngx.thread.spawn(function()
          coroutine.yield()
          self.bg_tasks.count = self.bg_tasks.count + 1
          handle_message(self, msg)
          self.bg_tasks.count = self.bg_tasks.count - 1
          running_tasks[tid] = nil
          if self.bg_tasks.count < 1 and self.bg_tasks.waiting > 0 then
            self.bg_tasks.sema:post(self.bg_tasks.waiting)
          end
        end)
      else
        local ok, err = handle_message(self, msg)
        if not ok then
          break
        end
      end
    elseif err ~= "timeout" then
      break
    end
  end
  if running_tasks then
    for k, v in pairs(running_tasks) do
      ngx.thread.wait(v)
    end
  end
  self.main_loop = nil
end

local function return_result(result, errobj, validator)
  if errobj then
    if errobj.data then
      local data, err = cjson.encode(errobj.data)
      return nil, string.format("%d %s %s", errobj.code, errobj.message, data or err), errobj
    end
    return nil, string.format("%d %s", errobj.code, errobj.message), errobj
  end
  local ok, err = validator(result)
  if not ok then
    return nil, err
  end
  return result
end

local function request_async(self, req, cb, meta, cleanup)
  local ok, err = self.conn:send(req.msg, meta)
  if not ok then
    cleanup()
    return nil, err
  end
  self.pending_requests[req.msg.id] = function(result, errobj)
    cleanup()
    cb(return_result(result, errobj, req.validator))
  end
  return true
end

local function request_sync_blocking(self, req, meta, cleanup)
  local ok, err = self.conn:send(req.msg, meta)
  if not ok then
    cleanup()
    return nil, err
  end
  local result, errobj
  self.pending_requests[req.msg.id] = function(res, err)
    cleanup()
    result = res
    errobj = err
  end
  repeat
    local msg, err = self.conn:recv()
    if msg then
      local ok, err = handle_message(self, msg)
      if not ok then
        cleanup()
        return nil, err
      end
    elseif err ~= "timeout" then
      cleanup()
      return nil, err
    end
  until result or errobj
  return return_result(result, errobj, req.validator)
end

local function request_sync_nonblocking(self, req, timeout, meta, cleanup)
  local sema, err = ngx_semaphore.new()
  if not sema then
    cleanup()
    return nil, err
  end
  local ok, err = self.conn:send(req.msg, meta)
  if not ok then
    cleanup()
    return nil, err
  end
  local result, errobj
  self.pending_requests[req.msg.id] = function(res, err)
    cleanup()
    result = res
    errobj = err
    sema:post()
  end
  local ok, err = sema:wait(tonumber(timeout) or 10)
  if not ok then
    cleanup()
    return nil, err
  end
  return return_result(result, errobj, req.validator)
end

function _M.new(conn, options, mt)
  if type(options) == "table" then
    assert(options.name == nil or type(options.name) == "string", "name of session MUST be a string")
    assert(options.title == nil or type(options.title) == "string", "title of session MUST be a string")
    assert(options.version == nil or type(options.version) == "string", "version of session MUST be a string")
  else
    options = {}
  end
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
    options = options,
    pending_requests = {},
    processing_requests = {},
    monitoring_progress = {},
    bg_tasks = bg_tasks
  }, mt or {__index = _M})
end

function _M.inject_common(self, methods)
  methods["notifications/progress"] = function(params)
    local ok, err = mcp.validator.ProgressNotification(params)
    if not ok then
      ngx.log(ngx.ERR, err)
      return
    end
    local monitor = self.monitoring_progress[params.progressToken]
    if not monitor then
      return
    end
    local ok, reason = monitor.callback(params.progress, params.total, params.message)
    if ok then
      return
    end
    assert(reason == nil or type(reason) == "string", "reason MUST be a string")
    local ok, err = _M.send_notification(self, "cancelled", {monitor.rid, reason})
    if not ok then
      ngx.log(ngx.ERR, err)
      return
    end
    local cb = self.pending_requests[monitor.rid]
    if cb then
      self.pending_requests[monitor.rid] = nil
      cb(nil, {code = -1, message = "Request cancelled", data = reason and {reason = reason}})
    end
  end
  methods["notifications/cancelled"] = function(params)
    local ok, err = mcp.validator.CancelledNotification(params)
    if not ok then
      ngx.log(ngx.ERR, err)
      return
    end
    self.processing_requests[params.requestId] = nil
  end
  methods.ping = function(params, rid)
    if not rid then
      return
    end
    local ok, err = mcp.validator.PingRequest(params)
    if not ok then
      return nil, -32602, "Invalid params", {errmsg = err}
    end
    return {}
  end
  return methods
end

function _M.initialize(self, methods)
  self.methods = methods
  self.main_loop = ngx.thread.spawn(main_loop, self)
end

function _M.shutdown(self, dont_wait)
  local co = self.main_loop
  if co then
    self.conn:close()
    if not dont_wait then
      ngx.thread.wait(co)
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

function _M.send_request(self, name, args, cb_or_to, meta)
  assert(type(name) == "string" and type(args) == "table", "invalid request format")
  local req = mcp.protocol.request[name](unpack(args))
  if meta and meta.progress_callback then
    meta.progress_token = mcp.utils.generate_id()
    self.monitoring_progress[meta.progress_token] = {
      rid = req.msg.id,
      callback = meta.progress_callback
    }
    local req_params = req.msg.params
    if req_params then
      if req_params._meta then
        req_params._meta.progressToken = meta.progress_token
      else
        req_params._meta = {progressToken = meta.progress_token}
      end
    else
      req.msg.params = {_meta = {progressToken = meta.progress_token}}
    end
  end
  local cleanup = function()
    if meta and meta.progress_token then
      self.monitoring_progress[meta.progress_token] = nil
    end
  end
  if cb_or_to and not tonumber(cb_or_to) then
    return request_async(self, req, cb_or_to, meta, cleanup)
  elseif self.conn.blocking_io then
    return request_sync_blocking(self, req, meta, cleanup)
  else
    return request_sync_nonblocking(self, req, cb_or_to, meta, cleanup)
  end
end

function _M.send_notification(self, name, args, meta)
  assert(type(name) == "string" and type(args) == "table", "invalid notification format")
  return self.conn:send(mcp.protocol.notification[name](unpack(args)), meta)
end

return _M
