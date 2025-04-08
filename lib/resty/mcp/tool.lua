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
        return nil, -32602, "Missing required arguments", {
          argument = k,
          expected = v.type,
          required = true
        }
      end
    elseif not mcp.utils.check_argument(v.type, actual_type, actual_value) then
      return nil, -32602, "Invalid arguments", {
        argument = k,
        expected = v.type,
        actual = actual_type
      }
    end
  end
  local content, is_error = self.callback(args)
  for i, v in ipairs(content) do
    if not mcp.utils.check_content(v) then
      error("invalid content format")
    end
  end
  return {
    content = setmetatable(content, cjson.array_mt),
    isError = is_error and true or false
  }
end

local _M = {
  _NAME = "resty.mcp.tool",
  _VERSION = mcp.version.module
}

function _M.new(name, cb, desc, args, annos)
  if type(name) ~= "string" then
    error("tool name MUST be a string.")
  end
  if not cb then
    error("callback of tool MUST be set.")
  end
  if desc and type(desc) ~= "string" then
    error("description of tool MUST be a string.")
  end
  if args and (type(args) ~= "table" or #args > 0) then
    error("expected arguments of tool MUST be a dict.")
  end
  return setmetatable({
    name = name,
    callback = cb,
    description = desc,
    expected_args = args or {},
    annotations = annos and mcp.protocol.tool_annotations(annos) or nil
  }, _MT)
end

return _M
