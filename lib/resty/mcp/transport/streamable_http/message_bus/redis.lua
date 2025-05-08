local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils")
}

local _M = {
  _NAME = "resty.mcp.transport.streamable_http.message_bus.redis",
  _VERSION = mcp.version.module
}

local cjson = require("cjson.safe")
local redis = require("resty.redis")
local unpack = table.unpack or unpack

local function redis_conn(self)
  local conn, err = redis:new()
  if not conn then
    return nil, err
  end
  local ok, err = conn:connect(self.redis_cfg.host, self.redis_cfg.port, self.redis_cfg.options)
  if not ok then
    return nil, err
  end
  if self.redis_cfg.password then
    local res, err = conn:auth(self.redis_cfg.password)
    if res ~= "OK" then
      if err then
        conn:close()
      else
        conn:set_keepalive()
      end
      return nil, err
    end
  end
  if self.redis_cfg.db then
    local res, err = conn:select(self.redis_cfg.db)
    if res ~= "OK" then
      if err then
        conn:close()
      else
        conn:set_keepalive()
      end
      return nil, err
    end
  end
  return conn
end

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

function _MT.__index.new_session(self)
  local conn, err = redis_conn(self)
  if not conn then
    return nil, err
  end
  local sid = mcp.utils.generate_id()
  local res, err = conn:set("sess_mk#"..sid, 0, "NX", "EX", self.mark_ttl)
  if res ~= "OK" then
    if err then
      conn:close()
      return nil, err
    end
    conn:set_keepalive()
    return nil, "duplicate session ID"
  end
  conn:set_keepalive()
  return sid
end

function _MT.__index.del_session(self, sid)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  local conn, err = redis_conn(self)
  if not conn then
    ngx.log(ngx.ERR, "redis: ", err)
    return
  end
  local keys = {"sess_mk#"..sid, "sess_mq#"..sid}
  for i, pattern in ipairs({string.format("chan_mq#%s@*", sid), string.format("sess_ce#%s@*", sid)}) do
    local cursor = "0"
    repeat
      local res, err = conn:scan(cursor, "MATCH", pattern)
      if not res then
        ngx.log(ngx.ERR, "redis: ", err)
        conn:close()
        return
      end
      cursor = res[1]
      for j, v in ipairs(res[2]) do
        table.insert(keys, v)
      end
    until cursor == "0"
  end
  local res, err = conn:del(unpack(keys))
  if not res then
    ngx.log(ngx.ERR, "redis: ", err)
    conn:close()
    return
  end
  conn:set_keepalive()
end

function _MT.__index.check_session(self, sid)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  local conn, err = redis_conn(self)
  if not conn then
    return nil, err
  end
  local res, err = conn:get("sess_mk#"..sid)
  if err then
    conn:close()
    return nil, err
  end
  conn:set_keepalive()
  return res ~= ngx.null and res or nil
end

function _MT.__index.push_smsg(self, sid, msg)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  if type(msg) ~= "string" then
    error("message MUST be a string")
  end
  local conn, err = redis_conn(self)
  if not conn then
    return nil, err
  end
  local res, err = conn:get("sess_mk#"..sid)
  if err then
    conn:close()
    return nil, err
  end
  if res == ngx.null then
    conn:set_keepalive()
    return nil, "not found"
  end
  local res, err = conn:rpush("sess_mq#"..sid, msg)
  if not res then
    conn:close()
    return nil, err
  end
  conn:set_keepalive()
  return res
end

function _MT.__index.pop_smsg(self, sid, timeout)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  local conn, err = redis_conn(self)
  if not conn then
    return nil, err
  end
  local ttl = tonumber(timeout) or 10
  while ttl > 0 do
    local ts = ngx.now()
    local res, err = conn:expire("sess_mk#"..sid, self.mark_ttl)
    if not res then
      conn:close()
      return nil, err
    end
    if tonumber(res) < 1 then
      conn:set_keepalive()
      return nil, "not found"
    end
    local res, err = conn:blpop("sess_mq#"..sid, 1)
    if not res then
      conn:close()
      return nil, err
    end
    if type(res) == "table" then
      conn:set_keepalive()
      return res[2]
    end
    ttl = ttl - (ngx.now() - ts)
  end
  conn:set_keepalive()
  return nil, "timeout"
end

function _MT.__index.push_cmsg(self, sid, chk, msg)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  if type(chk) ~= "string" then
    error("channel key MUST be a string")
  end
  local data, err = cjson.encode(msg)
  if not data then
    error(err)
  end
  local conn, err = redis_conn(self)
  if not conn then
    return nil, err
  end
  local res, err = conn:rpush(string.format("chan_mq#%s@%s", sid, chk), data)
  if not res then
    conn:close()
    return nil, err
  end
  conn:set_keepalive()
  return res
end

function _MT.__index.pop_cmsgs(self, sid, chks, timeout)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  if type(chks) ~= "table" or #chks < 1 then
    error("channel keys MUST be a non-empty array-like table")
  end
  local conn, err = redis_conn(self)
  if not conn then
    return nil, err
  end
  local params = {}
  for i, k in ipairs(chks) do
    table.insert(params, string.format("chan_mq#%s@%s", sid, k))
  end
  table.insert(params, 1)
  local ttl = tonumber(timeout) or 10
  while ttl > 0 do
    local ts = ngx.now()
    local res, err = conn:get("sess_mk#"..sid)
    if err then
      conn:close()
      return nil, err
    end
    if res == ngx.null then
      conn:set_keepalive()
      return nil, "not found"
    end
    local res, err = conn:blpop(unpack(params))
    if not res then
      conn:close()
      return nil, err
    end
    if type(res) == "table" then
      local msgs = {res[2]}
      while true do
        local res, err = conn:lpop(res[1])
        if not res then
          conn:close()
          return nil, err
        end
        if res == ngx.null then
          break
        end
        table.insert(msgs, res)
      end
      conn:set_keepalive()
      return msgs
    end
    ttl = ttl - (ngx.now() - ts)
  end
  conn:set_keepalive()
  return nil, "timeout"
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
  local conn, err = redis_conn(self)
  if not conn then
    return nil, err
  end
  local mk = "sess_mk#"..sid
  local old, err = conn:get(mk)
  if err then
    conn:close()
    return nil, err
  end
  if old == ngx.null then
    conn:set_keepalive()
    return nil, "not found"
  end
  local eid, err = conn:incr(mk)
  if not eid then
    conn:close()
    return nil, err
  end
  if eid <= tonumber(old) then
    local res, err = conn:del(mk)
    if not res then
      conn:close()
      return nil, err
    end
    conn:set_keepalive()
    return nil, "not found"
  end
  local key = string.format("sess_ce#%s@%u", sid, eid)
  local val = string.format("%s\n%s", stream, data)
  local res, err = conn:set(key, val, "NX", "EX", self.cache_ttl)
  if res ~= "OK" then
    if err then
      conn:close()
      return nil, err
    end
    conn:set_keepalive()
    return nil, "duplicate event ID"
  end
  conn:set_keepalive()
  return eid
end

function _MT.__index.replay_events(self, sid, last_event)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  if not tonumber(last_event) then
    error("last event ID MUST be set")
  end
  local conn, err = redis_conn(self)
  if not conn then
    return nil, err
  end
  local res, err = conn:get("sess_mk#"..sid)
  if err then
    conn:close()
    return nil, err
  end
  if res == ngx.null then
    conn:set_keepalive()
    return nil, "not found"
  end
  local events = {}
  local prefix = string.format("sess_ce#%s@", sid)
  local evt, err = conn:get(prefix..last_event)
  if err then
    conn:close()
    return nil, err
  end
  if evt == ngx.null then
    conn:set_keepalive()
    return events
  end
  local n = string.find(evt, "\n", 1, true)
  if not n then
    conn:set_keepalive()
    return events
  end
  local eid_filter = {}
  local stream = string.sub(evt, 1, n - 1)
  local pattern = prefix.."*"
  local cursor = "0"
  repeat
    local res, err = conn:scan(cursor, "MATCH", pattern)
    if not res then
      conn:close()
      return nil, err
    end
    cursor = res[1]
    for i, k in ipairs(res[2]) do
      local eid = tonumber(string.sub(k, #prefix + 1))
      if eid and eid > tonumber(last_event) and not eid_filter[eid] then
        eid_filter[eid] = true
        local evt, err = conn:get(k)
        if evt and evt ~= ngx.null then
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
          conn:close()
          return nil, err
        end
      end
    end
  until cursor == "0"
  conn:set_keepalive()
  table.sort(events, function(a, b)
    return a.id < b.id
  end)
  return events, stream
end

function _M.new(options)
  local mark_ttl = options and tonumber(options.mark_ttl) or 10
  if mark_ttl <= 0 then
    error("session mark TTL MUST be a positive number")
  end
  local cache_ttl = options and tonumber(options.cache_ttl) or 90
  if cache_ttl <= 0 then
    error("cache TTL MUST be a positive number")
  end
  return setmetatable({
    redis_cfg = options and options.redis and {
      host = options.redis.host or "127.0.0.1",
      port = tonumber(options.redis.port) or 6379,
      password = options.redis.password,
      db = tonumber(options.redis.db),
      options = options.redis.options
    } or {
      host = "127.0.0.1",
      port = 6379
    },
    mark_ttl = mark_ttl,
    cache_ttl = cache_ttl
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
