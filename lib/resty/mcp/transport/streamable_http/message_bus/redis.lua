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
  local keys = {"sess_mk#"..sid, "sess_mq#"..sid, "sess_ce#"..sid}
  local pattern = string.format("chan_mq#%s@*", sid)
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
  local mqk = "sess_mq#"..sid
  local res, err = conn:rpush(mqk, msg)
  if not res then
    conn:close()
    return nil, err
  end
  local res, err = conn:expire(mqk, self.mark_ttl)
  if not res then
    conn:close()
    return nil, err
  end
  conn:set_keepalive()
  return true
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
    local mqk = "sess_mq#"..sid
    local res, err = conn:expire(mqk, self.mark_ttl)
    if not res then
      conn:close()
      return nil, err
    end
    local res, err = conn:blpop(mqk, 1)
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
  local mqk = string.format("chan_mq#%s@%s", sid, chk)
  local res, err = conn:rpush(mqk, data)
  if not res then
    conn:close()
    return nil, err
  end
  local res, err = conn:expire(mqk, self.cache_ttl)
  if not res then
    conn:close()
    return nil, err
  end
  conn:set_keepalive()
  return true
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
  local cek = "sess_ce#"..sid
  local res, err = conn:rpush(cek, string.format("%u\n%s\n%s", eid, stream, data))
  if not res then
    conn:close()
    return nil, err
  end
  conn:init_pipeline(2)
  if res > self.event_capacity then
    conn:lpop(cek)
  end
  conn:expire(cek, self.cache_ttl)
  local res, err = conn:commit_pipeline()
  if not res then
    conn:close()
    return nil, err
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
  local res, err = conn:lrange("sess_ce#"..sid, 0, -1)
  if not res then
    conn:close()
    return nil, err
  end
  conn:set_keepalive()
  local events = {}
  local stream
  for i, v in ipairs(res) do
    local n1 = string.find(v, "\n", 1, true)
    if n1 then
      local n2 = string.find(v, "\n", n1 + 1, true)
      if n2 then
        local eid = tonumber(string.sub(v, 1, n1 - 1))
        if eid then
          if stream then
            if string.sub(v, n1 + 1, n2 - 1) == stream then
              table.insert(events, {
                data = string.sub(v, n2 + 1),
                id = eid
              })
            end
          elseif eid == tonumber(last_event) then
            stream = string.sub(v, n1 + 1, n2 - 1)
          elseif eid > tonumber(last_event) then
            break
          end
        end
      end
    end
  end
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
  local event_capacity = options and tonumber(options.event_capacity) or 1024
  if event_capacity <= 0 then
    error("event capacity MUST be a positive integer")
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
    cache_ttl = cache_ttl,
    event_capacity = event_capacity
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
