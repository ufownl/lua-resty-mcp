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
      assert(self.mime == nil or v.uri ~= self.uri or v.mimeType == self.mime, "resource MIME type mismatch")
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
  assert(type(uri) == "string", "resource uri MUST be a string.")
  assert(type(name) == "string", "resource name MUST be a string.")
  assert(cb, "callback of resource MUST be set.")
  assert(desc == nil or type(desc) == "string", "description of resource MUST be a string.")
  assert(mime == nil or type(mime) == "string", "MIME type of resource MUST be a string.")
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
