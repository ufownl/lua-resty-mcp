local mcp = {
  version = require("resty.mcp.version")
}

local _M = {
  _NAME = "resty.mcp.utils",
  _VERSION = mcp.version.module,
  uri_template = require("resty.mcp.utils.uri_template").new
}

local resty_random = require("resty.random")
local resty_sha256 = require("resty.sha256")
local ngx_base64 = require("ngx.base64")

local hostname = os.getenv("HOSTNAME") or io.popen("uname -n"):read("*l")
local id_counter = 0

function _M.generate_id()
  local sha256 = resty_sha256.new()
  sha256:update(hostname.."&")
  sha256:update(ngx.worker.pid().."&")
  sha256:update(ngx.time().."&")
  sha256:update(id_counter.."&")
  id_counter = (id_counter + 1) % 10000
  sha256:update(resty_random.bytes(8))
  return ngx_base64.encode_base64url(sha256:final())
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
