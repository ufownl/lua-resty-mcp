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
local ngx_worker_pid = ngx.worker.pid
local ngx_time = ngx.time
local ngx_sleep = ngx.sleep

local id_counter = 0

function _M.generate_id()
  local sha256 = resty_sha256.new()
  sha256:update(ngx_worker_pid().."&")
  sha256:update(ngx_time().."&")
  sha256:update(id_counter.."&")
  id_counter = (id_counter + 1) % 10000
  sha256:update(resty_random.bytes(8))
  return ngx_base64.encode_base64url(sha256:final())
end

function _M.check_mcp_type(module, v)
  return type(v) == "table" and v._NAME == module._NAME and v or nil
end

function _M.spin_until(stop_cond, options)
  if stop_cond() then
    return 0
  end
  local timeout = options and tonumber(options.timeout) or 10
  if timeout <= 0 then
    return nil, "timeout"
  end
  local step = options and tonumber(options.step) or 0.001
  local ratio = options and tonumber(options.ratio) or 2
  local max_step = options and tonumber(options.max_step) or 0.5
  local elapsed = 0
  while true do
    ngx_sleep(step)
    elapsed = elapsed + step
    if stop_cond() then
      return elapsed
    end
    if elapsed >= timeout then
      return nil, "timeout"
    end
    step = math.min(math.max(0.001, step * ratio), timeout - elapsed, max_step)
  end
end

return _M
