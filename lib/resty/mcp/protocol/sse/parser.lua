local mcp = {
  version = require("resty.mcp.version")
}

local _M = {
  _NAME = "resty.mcp.protocol.sse.parser",
  _VERSION = mcp.version.module
}

local ngx_re_match = ngx.re.match

local function new_state()
  return {event = "", data = ""}
end

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

function _MT.__call(self, line)
  if line == "" then
    if self.current_fields.data ~= "" then
      self.event_callback(
        self.current_fields.event == "" and "message" or self.current_fields.event,
        string.sub(self.current_fields.data, 1, -2),
        self.current_fields.id,
        self.current_fields.retry
      )
    end
    self.current_fields = new_state()
    return
  end
  local m, err = ngx_re_match(line, "^([^:]+)(?:: ?(.*))?$", "o")
  if not m then
    if err then
      error(err)
    end
    return
  end
  local field = m[1]
  if field == "event" then
    self.current_fields.event = m[2] or ""
  elseif field == "data" then
    self.current_fields.data = self.current_fields.data..(m[2] or "").."\n"
  elseif field == "id" then
    local value = m[2]
    if not value or value == "" then
      self.last_event = nil
    elseif not string.find(value, "\0", 1, true) then
      self.current_fields.id = value
      self.last_event = value
    end
  elseif field == "retry" then
    self.current_fields.retry = tonumber(m[2])
  end
end

function _M.new(event_cb)
  if not event_cb then
    error("event callback of sse parser MUST be set.")
  end
  return setmetatable({
    current_fields = new_state(),
    event_callback = event_cb
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
