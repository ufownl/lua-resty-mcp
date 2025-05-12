local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  protocol = require("resty.mcp.protocol"),
  validator = require("resty.mcp.protocol.validator")
}

local _M = {
  _NAME = "resty.mcp.resource",
  _VERSION = mcp.version.module
}

local cjson = require("cjson.safe")

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

function _MT.__index.to_mcp(self)
  return {
    uri = self.uri,
    name = self.name,
    description = self.description,
    mimeType = self.mime,
    annotations = self.annotations,
    size = self.size and math.floor(self.size)
  }
end

function _MT.__index.read(self, ctx)
  local contents, err = self.callback(self.uri, ctx)
  if contents == nil then
    return nil, -32603, "Internal errors", {errmsg = err}
  end
  if type(contents) == "table" then
    for i, v in ipairs(contents) do
      v.uri = v.uri or self.uri
      v.mimeType = v.mimeType or self.mime
    end
    local result = {contents = setmetatable(contents, cjson.array_mt)}
    assert(mcp.validator.ReadResourceResult(result))
    for i, v in ipairs(contents) do
      if self.mime and v.uri == self.uri and v.mimeType ~= self.mime then
        error("resource MIME type mismatch")
      end
    end
    return result
  end
  return {
    contents = {
      {uri = self.uri, mimeType = self.mime, text = tostring(contents)}
    }
  }
end

function _M.new(uri, name, cb, desc, mime, annos, size)
  if type(uri) ~= "string" then
    error("resource uri MUST be a string.")
  end
  if type(name) ~= "string" then
    error("resource name MUST be a string.")
  end
  if not cb then
    error("callback of resource MUST be set.")
  end
  if desc and type(desc) ~= "string" then
    error("description of resource MUST be a string.")
  end
  if mime and type(mime) ~= "string" then
    error("MIME type of resource MUST be a string.")
  end
  return setmetatable({
    uri = uri,
    name = name,
    callback = cb,
    description = desc,
    mime = mime,
    annotations = annos and mcp.protocol.annotations(annos) or nil,
    size = tonumber(size)
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
