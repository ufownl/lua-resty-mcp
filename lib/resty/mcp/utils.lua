local mcp = {
  version = require("resty.mcp.version")
}

local _M = {
  _NAME = "resty.mcp.utils",
  _VERSION = mcp.version.module,
  uri_template = require("resty.mcp.utils.uri_template").new
}

local bit = require("bit")
local ngx_base64 = require("ngx.base64")

local function crc16(s)
  local v = 0
  for i = 1, #s do
    v = bit.bxor(v, bit.band(bit.lshift(string.byte(s, i), 8), 0xFFFF))
    for j = 1, 8 do
      local u = bit.band(bit.lshift(v, 1), 0xFFFF)
      if bit.band(v, 0x8000) ~= 0 then
        v = bit.bxor(u, 0x1021)
      else
        v = u
      end
    end
  end
  return v
end

local hostname = crc16(os.getenv("HOSTNAME") or io.popen("uname -n"):read("*l"))
local id_counter = 0

function _M.generate_id(raw)
  local ts = ngx.time()
  local pid = ngx.worker.pid()
  local id = string.char(
    bit.band(bit.rshift(ts, 24), 0xFF),
    bit.band(bit.rshift(ts, 16), 0xFF),
    bit.band(bit.rshift(ts, 8), 0xFF),
    bit.band(ts, 0xFF),
    bit.band(hostname, 0xFF),
    bit.band(bit.rshift(hostname, 8), 0xFF),
    bit.band(pid, 0xFF),
    bit.band(bit.rshift(pid, 8), 0xFF),
    bit.band(bit.rshift(pid, 16), 0xFF),
    bit.band(bit.rshift(id_counter, 16), 0xFF),
    bit.band(bit.rshift(id_counter, 8), 0xFF),
    bit.band(id_counter, 0xFF)
  )
  id_counter = bit.band(id_counter + 1, 0xFFFFFF)
  return raw and id or ngx_base64.encode_base64url(id)
end

function _M.check_mcp_type(module, v)
  return type(v) == "table" and v._NAME == module._NAME and v or nil
end

function _M.spin_until(stop_cond, timeout, options)
  if stop_cond() then
    return 0
  end
  local ttl = tonumber(timeout) or 10
  if ttl <= 0 then
    return nil, "timeout"
  end
  local step = options and tonumber(options.step) or 0.001
  local ratio = options and tonumber(options.ratio) or 2
  local max_step = options and tonumber(options.max_step) or 0.5
  while true do
    ngx.sleep(step)
    ttl = ttl - step
    if stop_cond() then
      return (tonumber(timeout) or 10) - ttl
    end
    if ttl <= 0 then
      return nil, "timeout"
    end
    step = math.min(math.max(0.001, step * ratio), ttl, max_step)
  end
end

return _M
