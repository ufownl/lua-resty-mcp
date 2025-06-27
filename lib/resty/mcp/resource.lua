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
    title = self.title,
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

function _M.new(uri, name, cb, options)
  assert(type(uri) == "string", "resource uri MUST be a string.")
  assert(type(name) == "string", "resource name MUST be a string.")
  assert(cb, "callback of resource MUST be set.")
  local title, desc, mime, annos, size
  if options then
    assert(type(options) == "table", "options of resource MUST be a dict.")
    assert(options.title == nil or type(options.title) == "string", "title of resource MUST be a string.")
    assert(options.description == nil or type(options.description) == "string", "description of resource MUST be a string.")
    assert(options.mime == nil or type(options.mime) == "string", "MIME type of resource MUST be a string.")
    assert(options.annotations == nil or type(options.annotations) == "table", "annotations of resource MUST be a dict.")
    title = options.title
    desc = options.description
    mime = options.mime
    annos = options.annotations and mcp.protocol.annotations(options.annotations)
    size = tonumber(options.size)
  end
  return setmetatable({
    uri = uri,
    name = name,
    callback = cb,
    title = title,
    description = desc,
    mime = mime,
    annotations = annos,
    size = size
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
