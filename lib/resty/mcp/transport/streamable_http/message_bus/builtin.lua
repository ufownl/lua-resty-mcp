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
  local val, err = pop_impl()
  if val then
    return val
  end
  if err then
    return nil, err
  end
  local ttl = tonumber(timeout) or 10
  if ttl <= 0 then
    return nil, "timeout"
  end
  local step = self.step
  local ratio = self.ratio
  local max_step = self.max_step
  while true do
    ngx.sleep(step)
    ttl = ttl - step
    local val, err = pop_impl()
    if val then
      return val
    end
    if err then
      return nil, err
    end
    if ttl <= 0 then
      return nil, "timeout"
    end
    step = math.min(math.max(0.001, step * ratio), ttl, max_step)
  end
end

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

function _MT.__index.new_session(self)
  local sid = mcp.utils.generate_id()
  local ok, err = self.shm_dict:safe_add("sess_mk#"..sid, 0, self.ttl)
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
  local prefix = string.format("chan_mq#%s@", sid)
  for i, k in ipairs(self.shm_dict:get_keys(0)) do
    if string.sub(k, 1, #prefix) == prefix then
      self.shm_dict:delete(k)
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
  return self.shm_dict:rpush("sess_mq#"..sid, msg)
end

function _MT.__index.pop_smsg(self, sid, timeout)
  if type(sid) ~= "string" then
    error("session ID MUST be a string")
  end
  local function pop_impl()
    local ok, err = self.shm_dict:expire("sess_mk#"..sid, self.ttl)
    if not ok then
      return nil, err
    end
    local val, err = self.shm_dict:lpop("sess_mq#"..sid)
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
  local data, err = cjson.encode(msg)
  if not data then
    error(err)
  end
  local eid, err = self.shm_dict:incr("sess_mk#"..sid, 1)
  if not eid then
    return nil, err
  end
  return self.shm_dict:rpush(string.format("chan_mq#%s@%s", sid, chk), string.format("%u\n%s", eid, data))
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
        local sep = string.find(val, "\n", 1, true)
        if sep then
          table.insert(msgs, {
            id = string.sub(val, 1, sep - 1),
            data = string.sub(val, sep + 1)
          })
        end
      end
    end
    return #msgs > 0 and msgs or nil
  end
  return pop_sync(self, pop_impl, timeout)
end

function _M.new(options)
  local shm_zone = options and options.shm_zone or "mcp_message_bus"
  local shm_dict = ngx.shared[shm_zone]
  if not shm_dict then
    error(string.format("shm-zone named %s MUST be defined by `lua_shared_dict` directive", shm_zone))
  end
  local ttl = options and tonumber(options.ttl) or 10
  if ttl <= 0 then
    error("TTL MUST be a positive number")
  end
  return setmetatable({
    shm_dict = shm_dict,
    ttl = ttl,
    step = options and tonumber(options.step) or 0.001,
    ratio = options and tonumber(options.ratio) or 2,
    max_step = options and tonumber(options.max_step) or 0.5
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
