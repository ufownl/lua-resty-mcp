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
  end, timeout, {
    step = self.step,
    ratio = self.ratio,
    max_step = self.max_step
  })
  return val, spin_err or err
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
  return self.shm_dict:rpush(string.format("chan_mq#%s@%s", sid, chk), data)
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

function _MT.__index.alloc_eid(self, sid)
  return self.shm_dict:incr("sess_mk#"..sid, 1)
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
    step = options and tonumber(options.step),
    ratio = options and tonumber(options.ratio),
    max_step = options and tonumber(options.max_step)
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
