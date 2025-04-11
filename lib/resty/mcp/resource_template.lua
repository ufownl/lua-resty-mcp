local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  protocol = require("resty.mcp.protocol")
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

function _MT.__index.read(self, uri)
  local vars, err = self.uri_template:match(uri)
  if not vars then
    return nil, -32002, "Resource not found", {uri = uri}
  end
  local found, contents, err = self.callback(uri, vars)
  if not contents then
    if found then
      return nil, -32603, "Internal errors", {errmsg = err}
    else
      return nil, -32002, "Resource not found", {uri = uri}
    end
  end
  for i, v in ipairs(contents) do
    v.uri = v.uri or uri
    v.mimeType = v.mimeType or self.mime
    if not mcp.utils.check_resource(v, self.mime) then
      error("invalid resource format")
    end
    if self.mime and v.uri == uri and v.mimeType ~= self.mime then
      error("resource MIME type mismatch")
    end
  end
  return {contents = setmetatable(contents, cjson.array_mt)}
end

function _M.new(pattern, name, cb, desc, mime, annos)
  if type(pattern) ~= "string" then
    error("pattern of resource template MUST be a string.")
  end
  if type(name) ~= "string" then
    error("name of resource template MUST be a string.")
  end
  if not cb then
    error("callback of resource template MUST be set.")
  end
  if desc and type(desc) ~= "string" then
    error("description of resource template MUST be a string.")
  end
  if mime and type(mime) ~= "string" then
    error("MIME type of resource template MUST be a string.")
  end
  local template, err = mcp.utils.uri_template(pattern)
  if not template then
    return nil, err
  end
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
