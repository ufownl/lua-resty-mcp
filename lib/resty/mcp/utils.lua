local mcp = {
  version = require("resty.mcp.version")
}

local resty_random = require("resty.random")
local resty_sha256 = require("resty.sha256")
local ngx_base64 = require("ngx.base64")
local ngx_worker_pid = ngx.worker.pid
local ngx_time = ngx.time

local _M = {
  _NAME = "resty.mcp.utils",
  _VERSION = mcp.version.module
}

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

function _M.check_resource(resource)
  if type(resource.uri) ~= "string" then
    return false
  end
  if resource.text and type(resource.text) ~= "string" then
    return false
  end
  if resource.blob and type(resource.blob) ~= "string" then
    return false
  end
  if resource.text and resource.blob then
    return false
  end
  if resource.mimeType and type(resource.mimeType) ~= "string" then
    return false
  end
  return resource.text or resource.blob
end

local argument_checkers = {
  object = function(typ, val)
    return typ == "table" and #val == 0
  end,
  array = function(typ, val)
    return typ == "table"
  end,
  string = function(typ, val)
    return typ == "string"
  end,
  number = function(typ, val)
    return typ == "number"
  end,
  integer = function(typ, val)
    return typ == "number" and val % 1 == 0
  end,
  boolean = function(typ, val)
    return typ == "boolean"
  end,
  null = function(typ, val)
    return val == cjson.null
  end
}

function _M.check_argument(expected_type, actual_type, actual_value)
  local checker = argument_checkers[expected_type]
  return not checker or checker(actual_type, actual_value)
end

local content_checkers = {
  text = function(content)
    return type(content.text) == "string"
  end,
  image = function(content)
    return type(content.data) == "string" and type(content.mimeType) == "string"
  end,
  audio = function(content)
    return type(content.data) == "string" and type(content.mimeType) == "string"
  end,
  resource = function(content)
    return type(content.resource) == "table" and _M.check_resource(content.resource)
  end
}

function _M.check_content(content)
  local checker = content_checkers[content.type]
  return checker and checker(content)
end

function _M.check_role(role)
  return role == "user" or role == "assistant"
end

return _M
