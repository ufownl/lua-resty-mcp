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

local function send_request(self, name, args, timeout)
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

local function send_notification(self, name, args)
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

local function main_loop(self)
  while true do
    local msg, err = self.conn:recv()
    if not msg and err ~= "timeout" then
      break
    end
    -- TODO: methods handler
    local reply = mcp.rpc.handle(msg, {}, function(rid, result, errobj)
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
  end
  self.main_loop = nil
end

local _MT = {
  __index = {}
}

function _MT.__index.initialize(self)
  self.main_loop = ngx_thread_spawn(main_loop, self)
  local res, err = send_request(self, "initialize", {self.name})
  if not res then
    self.conn:close()
    return nil, err
  end
  self.server = {
    protocol = res.protocolVersion,
    capabilities = {
      logging = res.capabilities.logging and true,
      prompts = res.capabilities.prompts and {
        list_changed = res.capabilities.prompts.listChanged
      },
      resources = res.capabilities.resources and {
        subscribe = res.capabilities.resources.subscribe,
        list_changed = res.capabilities.resources.listChanged
      },
      tools = res.capabilities.tools and {
        list_changed = res.capabilities.tools.listChanged
      }
    },
    info = res.serverInfo
  }
  local ok, err = send_notification(self, "initialized", {})
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
