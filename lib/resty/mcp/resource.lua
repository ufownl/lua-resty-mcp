local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  protocol = require("resty.mcp.protocol")
}

local cjson = require("cjson.safe")

local _MT = {
  __index = {}
}

function _MT.__index.to_mcp(self)
  return {
    uri = self.uri,
    name = self.name,
    description = self.description,
    mimeType = self.mime,
    annotations = self.annotations
  }
end

function _MT.__index.read(self)
  local contents, err = self.callback(self.uri)
  if not contents then
    return nil, -32603, "Internal errors", {errmsg = err}
  end
  for i, v in ipairs(contents) do
    v.uri = v.uri or self.uri
    v.mimeType = v.mimeType or self.mime
    if not mcp.utils.check_resource(v) then
      error("invalid resource format")
    end
    if self.mime and v.uri == self.uri and v.mimeType ~= self.mime then
      error("resource MIME type mismatch")
    end
  end
  return {contents = setmetatable(contents, cjson.array_mt)}
end

local _M = {
  _NAME = "resty.mcp.resource",
  _VERSION = mcp.version.module
}

function _M.new(uri, name, cb, desc, mime, annos)
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
    annotations = annos and mcp.protocol.annotations(annos) or nil
  }, _MT)
end

return _M
