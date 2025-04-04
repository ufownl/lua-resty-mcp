local mcp = {
  version = require("resty.mcp.version"),
  rpc = require("resty.mcp.protocol.rpc"),
  protocol = require("resty.mcp.protocol")
}

local ngx_semaphore = require("ngx.semaphore")
local ngx_log = ngx.log
local ngx_thread_spawn = ngx.thread.spawn
local ngx_thread_wait = ngx.thread.wait
local unpack = table.unpack or unpack

local function send_request(self, req)
  if type(req.name) ~= "string" or type(req.args) ~= "table" or type(req.callback) ~= "function" then
    error("invalid request format")
  end
  local msg, rid, err = mcp.protocol.request[req.name](unpack(req.args))
  if not msg then
    return nil, err
  end
  local ok, err = self.conn:send(msg)
  if not ok then
    return nil, err
  end
  self.pending_requests[rid] = req.callback
  return true
end

local function send_notification(self, ntf)
  if type(ntf.name) ~= "string" or type(ntf.args) ~= "table" then
    error("invalid notification format")
  end
  local msg, err = mcp.protocol.notification[ntf.name](unpack(ntf.args))
  if not msg then
    return nil, err
  end
  local ok, err = self.conn:send(msg)
  if not ok then
    return nil, err
  end
  return true
end

local function main_loop(self)
  repeat
    local msg, err = self.conn:recv()
    if not msg and err ~= "timeout" then
      ngx_log(ngx.ERR, "transport: ", err)
      break
    end
    local term = false
    -- TODO: methods handler
    local reply = mcp.rpc.handle(msg, {}, function(rid, result, errobj)
      local cb = self.pending_requests[rid]
      if not cb then
        ngx_log(ngx.ERR, "response: request id mismatch")
        return
      end
      self.pending_requests[rid] = nil
      local ok, err = cb(result, errobj)
      if not ok then
        ngx_log(ngx.ERR, "response: ", err)
        term = true
      end
    end)
    if reply then
      local ok, err = self.conn:send(reply)
      if not ok then
        ngx_log(ngx.ERR, "transport: ", err)
        break
      end
    end
  until term
  self.main_loop = nil
end

local _MT = {
  __index = {}
}

function _MT.__index.initialize(self)
  local sema, err = ngx_semaphore.new()
  if not sema then
    return nil, err
  end
  local ok, err = send_request(self, {
    name = "initialize",
    args = {self.name},
    callback = function(result, errobj)
      if errobj then
        return nil, string.format("%d %s", errobj.code, errobj.message)
      end
      self.server = {
        protocol = result.protocolVersion,
        capabilities = {
          logging = result.capabilities.logging and true,
          prompts = result.capabilities.prompts and {
            list_changed = result.capabilities.prompts.listChanged
          },
          resources = result.capabilities.resources and {
            subscribe = result.capabilities.resources.subscribe,
            list_changed = result.capabilities.resources.listChanged
          },
          tools = result.capabilities.tools and {
            list_changed = result.capabilities.tools.listChanged
          }
        },
        info = result.serverInfo
      }
      sema:post()
      return true
    end
  })
  if not ok then
    self.conn:close()
    return nil, err
  end
  self.main_loop = ngx_thread_spawn(main_loop, self)
  repeat
    local ok, err = sema:wait(1)
    if not ok and err ~= "timeout" then
      return nil, err
    end
    if not self.main_loop then
      self.conn:close()
      return nil, "initialization aborted"
    end
  until self.server
  local ok, err = send_notification(self, {
    name = "initialized",
    args = {}
  })
  if not ok then
    self.conn:close()
    return nil, err
  end
  return true
end

function _MT.__index.shutdown(self)
  local co = self.main_loop
  if co then
    self.conn:close()
    local ok, err = ngx_thread_wait(co)
    if not ok then
      ngx_log(ngx.ERR, "ngx thread: ", err)
    end
  end
end

local _M = {
  _NAME = "resty.mcp.client",
  _VERSION = mcp.version.module,
}

function _M.new(transport, options)
  local conn, err = transport.new(options)
  if not conn then
    return nil, err
  end
  return setmetatable({
    name = options.name,
    conn = conn,
    pending_requests = {}
  }, _MT)
end

return _M
