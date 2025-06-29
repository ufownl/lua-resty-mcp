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
    title = self.title,
    description = self.description,
    inputSchema = self.input_schema or {type = "object"},
    outputSchema = self.output_schema,
    annotations = self.annotations
  }
end

function _MT.__call(self, args, ctx)
  local ok, err = self.args_validator(args)
  if not ok then
    return nil, -32602, "Invalid arguments", {errmsg = err}
  end
  local content, err = self.callback(args, ctx)
  local is_error
  if content == nil then
    if err == nil then
      return
    end
    content = err
    is_error = true
  end
  if self.ret_validator then
    assert(self.ret_validator(content))
    return {
      content = {
        {type = "text", text = assert(cjson.encode(content))}
      },
      structuredContent = content,
      isError = is_error
    }
  end
  if type(content) == "table" then
    local result = {
      content = setmetatable(content, cjson.array_mt),
      isError = is_error
    }
    assert(mcp.validator.CallToolResult(result))
    return result
  end
  return {
    content = {
      {type = "text", text = tostring(content)}
    },
    isError = is_error
  }
end

function _M.new(name, cb, options)
  assert(type(name) == "string", "tool name MUST be a string.")
  assert(cb, "callback of tool MUST be set.")
  local title, desc, input_schema, output_schema, annos
  if options then
    assert(type(options) == "table", "options of tool MUST be a dict.")
    assert(options.title == nil or type(options.title) == "string", "title of tool MUST be a string.")
    assert(options.description == nil or type(options.description) == "string", "description of tool MUST be a string.")
    assert(options.input_schema == nil or type(options.input_schema) == "table", "input schema of tool MUST be a dict.")
    assert(options.output_schema == nil or type(options.output_schema) == "table", "output schema of tool MUST be a dict.")
    assert(options.annotations == nil or type(options.annotations) == "table", "annotations of tool MUST be a dict.")
    title = options.title
    desc = options.description
    input_schema = options.input_schema
    output_schema = options.output_schema
    annos = options.annotations and mcp.protocol.tool_annotations(options.annotations)
  end
  assert(mcp.validator.Tool({
    name = name,
    title = title,
    description = desc,
    inputSchema = input_schema or {type = "object"},
    outputSchema = output_schema,
    annotations = annos
  }))
  return setmetatable({
    name = name,
    callback = cb,
    title = title,
    description = desc,
    args_validator = input_schema and jsonschema.generate_validator(input_schema) or function(args)
      return true
    end,
    input_schema = input_schema,
    ret_validator = output_schema and jsonschema.generate_validator(output_schema),
    output_schema = output_schema,
    annotations = annos
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
