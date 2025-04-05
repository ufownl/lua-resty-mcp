local mcp = {
  version = require("resty.mcp.version")
}

local cjson = require("cjson.safe")

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
    if type(content.resource) ~= "table" then
      return false
    end
    if type(content.resource.uri) ~= "string" then
      return false
    end
    if content.resource.text and type(content.resource.text) ~= "string" then
      return false
    end
    if content.resource.blob and type(content.resource.blob) ~= "string" then
      return false
    end
    if content.resource.text and content.resource.blob then
      return false
    end
    if content.resource.mimeType and type(content.resource.mimeType) ~= "string" then
      return false
    end
    return content.resource.text or content.resource.blob
  end
}

local _MT = {
  __index = {}
}

function _MT.__index.to_mcp(self)
  local properties, required
  for name, schema in pairs(self.expected_args) do
    local prop = {}
    for k, v in pairs(schema) do
      if k == "required" then
        if v then
          if required then
            table.insert(required, name)
          else
            required = {name}
          end
        end
      else
        prop[k] = v
      end
    end
    if properties then
      properties[name] = prop
    else
      properties = {[name] = prop}
    end
  end
  return {
    name = self.name,
    description = self.description,
    inputSchema = {
      type = "object",
      properties = properties,
      required = required
    },
    annotations = self.annotations
  }
end

function _MT.__call(self, args)
  if args then
    if type(args) ~= "table" or #args > 0 then
      return nil, -32602, "Invalid arguments"
    end
  else
    args = {}
  end
  for k, v in pairs(self.expected_args) do
    local actual_value = args[k]
    local actual_type = type(actual_value)
    if actual_type == "nil" then
      if v.required then
        return nil, -32602, "Invalid arguments", {
          argument = k,
          expected = v.type,
          required = true
        }
      end
    else
      local checker = argument_checkers[v.type]
      if checker and not checker(actual_type, actual_value) then
        return nil, -32602, "Invalid arguments", {
          argument = k,
          expected = v.type,
          actual = actual_type
        }
      end
    end
  end
  local content, is_error = self.callback(args)
  for i, v in ipairs(content) do
    local checker = content_checkers[v.type]
    if not checker or not checker(v) then
      error("invalid content format")
    end
  end
  setmetatable(content, cjson.array_mt)
  return {
    content = content,
    isError = is_error and true or false
  }
end

local _M = {
  _NAME = "resty.mcp.tool",
  _VERSION = mcp.version.module
}

function _M.new(name, desc, args, cb, annos)
  if type(name) ~= "string" then
    error("tool name MUST be a string.")
  end
  if type(desc) ~= "string" then
    error("description of tool MUST be a string.")
  end
  if args and (type(args) ~= "table" or #args > 0) then
    error("expected arguments of tool MUST be a dict.")
  end
  if not cb then
    error("callback of tool MUST be set.")
  end
  local annotations
  if annos then
    annotations = {title = type(annos.title) == "string" and annos.title or nil}
    for i, k in ipairs({"readOnlyHint", "destructiveHint", "idempotentHint", "openWorldHint"}) do
      if type(annos[k]) == "boolean" then
        annotations[k] = annos[k]
      end
    end
  end
  return setmetatable({
    name = name,
    description = desc,
    expected_args = args or {},
    callback = cb,
    annotations = annotations
  }, _MT)
end

return _M
