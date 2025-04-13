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

local id_counter = 0

function _M.generate_id()
  local sha256 = resty_sha256.new()
  sha256:update(ngx_worker_pid().."&")
  sha256:update(ngx_time().."&")
  sha256:update(id_counter.."&")
  id_counter = (id_counter + 1) % 1000
  sha256:update(resty_random.bytes(8))
  return ngx_base64.encode_base64url(sha256:final())
end

function _M.check_mcp_type(module, v)
  return type(v) == "table" and v._NAME == module._NAME and v or nil
end

return _M
