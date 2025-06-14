local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils")
}

local _M = {
  _NAME = "resty.mcp.transport.streamable_http.server",
  _VERSION = mcp.version.module
}

local cjson = require("cjson.safe")

local function route_single(msg, rrid)
  if msg.method then
    return rrid and tostring(rrid) or "get"
  elseif msg.id and msg.id ~= cjson.null then
    return tostring(msg.id)
  else
    local data = assert(cjson.encode(msg))
    ngx.log(ngx.ERR, "unable to route: "..data)
  end
end

local function route_messages(msgs, rrid)
  local msg_routing = {}
  for i, msg in ipairs(msgs) do
    local chk = route_single(msg, rrid)
    if chk then
      local target = msg_routing[chk]
      if target then
        table.insert(target, msg)
      else
        msg_routing[chk] = {msg}
      end
    end
  end
  return msg_routing
end

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

function _MT.__index.send(self, msg, meta)
  assert(type(msg) == "table", "message MUST be a table.")
  if not self.message_bus then
    return nil, "closed"
  end
  local rrid = meta and meta.related_request
  if #msg > 0 then
    for k, v in pairs(route_messages(msg, rrid)) do
      local ok, err = self.message_bus:push_cmsg(self.session_id, k, #v > 1 and v or v[1])
      if not ok then
        return nil, err
      end
      if not self.message_bus then
        return nil, "closed"
      end
    end
    return true
  end
  local chk = route_single(msg, rrid)
  if chk then
    return self.message_bus:push_cmsg(self.session_id, chk, msg)
  end
  return true
end

function _MT.__index.recv(self)
  if not self.message_bus then
    return nil, "closed"
  end
  local msg, err = self.message_bus:pop_smsg(self.session_id, self.read_timeout)
  if msg then
    self.last_active = ngx.now()
  elseif err == "timeout" and ngx.now() - self.last_active >= self.longest_standby then
    self:close()
    return nil, "closed"
  end
  return msg, err
end

function _MT.__index.close(self)
  if not self.message_bus then
    return
  end
  self.message_bus:del_session(self.session_id)
  self.message_bus = nil
end

function _M.new(options)
  assert(type(options) == "table", "options of streamable http server transport MUST be a table.")
  assert(type(options.session_id) == "string", "session ID MUST be a string")
  local bus_type = options.message_bus and options.message_bus.type or "builtin"
  local message_bus = require("resty.mcp.transport.streamable_http.message_bus."..bus_type)
  local bus, err = message_bus.new(options.message_bus)
  if not bus then
    return nil, err
  end
  return setmetatable({
    session_id = options.session_id,
    read_timeout = tonumber(options.read_timeout),
    longest_standby = tonumber(options.longest_standby) or 600,
    last_active = ngx.now(),
    message_bus = bus
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
