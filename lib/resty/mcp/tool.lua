local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  protocol = require("resty.mcp.protocol"),
  validator = require("resty.mcp.protocol.validator")
}

local _M = {
  _NAME = "resty.mcp.tool",
  _VERSION = mcp.version.module
}

local cjson = require("cjson.safe")
local jsonschema = require("jsonschema")

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

function _MT.__index.to_mcp(self)
  return {
    name = self.name,
    description = self.description,
    inputSchema = self.input_schema or {type = "object"},
    annotations = self.annotations
  }
end

function _MT.__call(self, args, ctx)
  local ok, err = self.args_validator(args)
  if not ok then
    return nil, -32602, "Invalid arguments", {errmsg = err}
  end
  local content, is_error = self.callback(args, ctx)
  local ok, err = mcp.validator.CallToolResult({
    content = content,
    isError = is_error
  })
  if not ok then
    error(err)
  end
  return {
    content = setmetatable(content, cjson.array_mt),
    isError = is_error
  }
end

function _M.new(name, cb, desc, input_schema, annos)
  if not cb then
    error("callback of tool MUST be set.")
  end
  local annotations = annos and mcp.protocol.tool_annotations(annos) or nil
  local ok, err = mcp.validator.Tool({
    name = name,
    description = desc,
    inputSchema = input_schema or {type = "object"},
    annotations = annotations
  })
  if not ok then
    error(err)
  end
  return setmetatable({
    name = name,
    callback = cb,
    description = desc,
    args_validator = input_schema and jsonschema.generate_validator(input_schema) or function(args)
      return true
    end,
    input_schema = input_schema,
    annotations = annotations
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
