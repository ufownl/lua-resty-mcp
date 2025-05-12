local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils")
}

local _M = {
  _NAME = "resty.mcp.transport.streamable_http.message_bus.builtin",
  _VERSION = mcp.version.module
}

local cjson = require("cjson.safe")

local function pop_sync(self, pop_impl, timeout)
  local val, err
  local ok, spin_err = mcp.utils.spin_until(function()
    val, err = pop_impl()
    return val or err
  end, timeout, self.spin_opts)
  return val, spin_err or err
end

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

function _MT.__index.new_session(self)
  local sid = mcp.utils.generate_id()
  local ok, err = self.shm_dict:safe_add("sess_mk#"..sid, 0, self.mark_ttl)
  if not ok then
    return nil, err
  end
  return sid
end

function _MT.__index.del_session(self, sid)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  self.shm_dict:delete("sess_mk#"..sid)
  self.shm_dict:delete("sess_mq#"..sid)
  local pattern = string.format("^(chan_mq|sess_ce)#%s@", sid)
  for i, k in ipairs(self.shm_dict:get_keys(0)) do
    local l, r, err = ngx.re.find(k, pattern)
    if l == 1 then
      self.shm_dict:delete(k)
    elseif err then
      error(err)
    end
  end
end

function _MT.__index.check_session(self, sid)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  local val, err = self.shm_dict:get("sess_mk#"..sid)
  if not val and err then
    return nil, err
  end
  return val
end

function _MT.__index.push_smsg(self, sid, msg)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  if type(msg) ~= "string" then
    error("message MUST be a string")
  end
  local val, err = self.shm_dict:get("sess_mk#"..sid)
  if not val then
    return nil, err or "not found"
  end
  local mqk = "sess_mq#"..sid
  local res, err = self.shm_dict:rpush(mqk, msg)
  if not res then
    return nil, err
  end
  self.shm_dict:expire(mqk, self.mark_ttl)
  return true
end

function _MT.__index.pop_smsg(self, sid, timeout)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  local function pop_impl()
    local ok, err = self.shm_dict:expire("sess_mk#"..sid, self.mark_ttl)
    if not ok then
      return nil, err
    end
    local mqk = "sess_mq#"..sid
    local ok, err = self.shm_dict:expire(mqk, self.mark_ttl)
    if not ok then
      return nil, err ~= "not found" and err or nil
    end
    local val, err = self.shm_dict:lpop(mqk)
    if val then
      return val
    end
    return nil, err
  end
  return pop_sync(self, pop_impl, timeout)
end

function _MT.__index.push_cmsg(self, sid, chk, msg)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  if type(chk) ~= "string" then
    error("channel key MUST be a string")
  end
  local data = assert(cjson.encode(msg))
  local mqk = string.format("chan_mq#%s@%s", sid, chk)
  local res, err = self.shm_dict:rpush(mqk, data)
  if not res then
    return nil, err
  end
  self.shm_dict:expire(mqk, self.cache_ttl)
  return true
end

function _MT.__index.pop_cmsgs(self, sid, chks, timeout)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  if type(chks) ~= "table" or #chks < 1 then
    error("channel keys MUST be a non-empty array-like table")
  end
  local function pop_impl()
    local val, err = self.shm_dict:get("sess_mk#"..sid)
    if not val then
      return nil, err or "not found"
    end
    local msgs = {}
    for i, k in ipairs(chks) do
      while true do
        local val, err = self.shm_dict:lpop(string.format("chan_mq#%s@%s", sid, k))
        if not val then
          if err then
            return nil, err
          end
          break
        end
        table.insert(msgs, val)
      end
    end
    return #msgs > 0 and msgs or nil
  end
  return pop_sync(self, pop_impl, timeout)
end

function _MT.__index.cache_event(self, sid, stream, data)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  if type(stream) ~= "string" then
    error("stream ID MUST be a string")
  end
  if type(data) ~= "string" then
    error("data of event MUST be a string")
  end
  local eid, err = self.shm_dict:incr("sess_mk#"..sid, 1)
  if not eid then
    return nil, err
  end
  local key = string.format("sess_ce#%s@%u", sid, eid)
  local val = string.format("%s\n%s", stream, data)
  local ok, err = self.shm_dict:safe_add(key, val, self.cache_ttl)
  if not ok then
    return nil, err
  end
  return eid
end

function _MT.__index.replay_events(self, sid, last_event)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  if not tonumber(last_event) then
    error("last event ID MUST be set")
  end
  local val, err = self.shm_dict:get("sess_mk#"..sid)
  if not val then
    return nil, err or "not found"
  end
  local events = {}
  local prefix = string.format("sess_ce#%s@", sid)
  local evt, err = self.shm_dict:get(prefix..last_event)
  if not evt then
    if err then
      return nil, err
    end
    return events
  end
  local n = string.find(evt, "\n", 1, true)
  if not n then
    return events
  end
  local stream = string.sub(evt, 1, n - 1)
  for i, k in ipairs(self.shm_dict:get_keys(0)) do
    local l, r = string.find(k, prefix, 1, true)
    if l == 1 then
      local eid = tonumber(string.sub(k, r + 1))
      if eid and eid > tonumber(last_event) then
        local evt, err = self.shm_dict:get(k)
        if evt then
          local n = string.find(evt, "\n", 1, true)
          if n then
            if string.sub(evt, 1, n - 1) == stream then
              table.insert(events, {
                data = string.sub(evt, n + 1),
                id = eid
              })
            end
          end
        elseif err then
          return nil, err
        end
      end
    end
  end
  table.sort(events, function(a, b)
    return a.id < b.id
  end)
  return events, stream
end

function _M.new(options)
  local shm_zone = options and options.shm_zone or "mcp_message_bus"
  local shm_dict = ngx.shared[shm_zone]
  if not shm_dict then
    error(string.format("shm-zone named %s MUST be defined by `lua_shared_dict` directive", shm_zone))
  end
  local mark_ttl = options and tonumber(options.mark_ttl) or 10
  if mark_ttl <= 0 then
    error("session mark TTL MUST be a positive number")
  end
  local cache_ttl = options and tonumber(options.cache_ttl) or 90
  if cache_ttl <= 0 then
    error("cache TTL MUST be a positive number")
  end
  return setmetatable({
    shm_dict = shm_dict,
    mark_ttl = mark_ttl,
    cache_ttl = cache_ttl,
    spin_opts = options and options.spin_opts and {
      step = tonumber(options.spin_opts.step),
      ratio = tonumber(options.spin_opts.ratio),
      max_step = tonumber(options.spin_opts.max_step)
    }
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
