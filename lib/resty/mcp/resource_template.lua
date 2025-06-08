local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  protocol = require("resty.mcp.protocol"),
  validator = require("resty.mcp.protocol.validator")
}

local _M = {
  _NAME = "resty.mcp.resource_template",
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
    uriTemplate = self.uri_template.pattern,
    name = self.name,
    description = self.description,
    mimeType = self.mime,
    annotations = self.annotations
  }
end

function _MT.__index.test(self, uri)
  return self.uri_template:test(uri)
end

function _MT.__index.read(self, uri, ctx)
  local vars, err = self.uri_template:match(uri)
  if vars == nil then
    return nil, -32002, "Resource not found", {uri = uri}
  end
  local found, contents, err = self.callback(uri, vars, ctx)
  if contents == nil then
    if found then
      return nil, -32603, "Internal errors", {errmsg = err}
    else
      return nil, -32002, "Resource not found", {uri = uri}
    end
  end
  if type(contents) == "table" then
    for i, v in ipairs(contents) do
      v.uri = v.uri or uri
      v.mimeType = v.mimeType or self.mime
    end
    local result = {contents = setmetatable(contents, cjson.array_mt)}
    assert(mcp.validator.ReadResourceResult(result))
    for i, v in ipairs(contents) do
      assert(self.mime == nil or v.uri ~= uri or v.mimeType == self.mime, "resource MIME type mismatch")
    end
    return result
  end
  return {
    contents = {
      {uri = uri, mimeType = self.mime, text = tostring(contents)}
    }
  }
end

function _MT.__index.complete(self, cbs)
  assert(cbs, "completion callbacks of resource template MUST be set.")
  self.completion_callbacks = {}
  for i, v in ipairs(self.uri_template.variables) do
    self.completion_callbacks[v] = cbs[v]
  end
  return self
end

function _M.new(pattern, name, cb, desc, mime, annos)
  assert(type(pattern) == "string", "pattern of resource template MUST be a string.")
  assert(type(name) == "string", "name of resource template MUST be a string.")
  assert(cb, "callback of resource template MUST be set.")
  assert(desc == nil or type(desc) == "string", "description of resource template MUST be a string.")
  assert(mime == nil or type(mime) == "string", "MIME type of resource template MUST be a string.")
  local template = assert(mcp.utils.uri_template(pattern))
  return setmetatable({
    uri_template = template,
    name = name,
    callback = cb,
    description = desc,
    mime = mime,
    annotations = annos and mcp.protocol.annotations(annos) or nil
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
