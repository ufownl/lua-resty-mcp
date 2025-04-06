local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils")
}

local cjson = require("cjson.safe")

local _MT = {
  __index = {}
}

function _MT.__index.to_mcp(self)
  local arguments
  for name, schema in pairs(self.expected_args) do
    local prompt_arg = {name = name}
    for k, v in pairs(schema) do
      if k ~= "name" then
        prompt_arg[k] = v
      end
    end
    if arguments then
      table.insert(arguments, prompt_arg)
    else
      arguments = {prompt_arg}
    end
  end
  if arguments then
    table.sort(arguments, function(a, b)
      if a.required and not b.required then
        return true
      elseif not a.required and b.required then
        return false
      else
        return a.name < b.name
      end
    end)
  end
  return {
    name = self.name,
    description = self.description,
    arguments = arguments
  }
end

function _MT.__index.get(self, args)
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
          expected = "string",
          required = true
        }
      end
    elseif actual_type ~= "string" then
      return nil, -32602, "Invalid arguments", {
        argument = k,
        expected = "string",
        actual = actual_type
      }
    end
  end
  local messages, err = self.callback(args)
  if not messages then
    return nil, -32603, "Internal errors", {errmsg = err}
  end
  for i, v in ipairs(messages) do
    if not mcp.utils.check_role(v.role) then
      error("invalid message role")
    end
    if not mcp.utils.check_content(v.content) then
      error("invalid content format")
    end
  end
  setmetatable(messages, cjson.array_mt)
  return {
    description = self.description,
    messages = messages
  }
end

local _M = {
  _NAME = "resty.mcp.prompt",
  _VERSION = mcp.version.module
}

function _M.new(name, cb, desc, args)
  if type(name) ~= "string" then
    error("prompt name MUST be a string.")
  end
  if not cb then
    error("callback of prompt MUST be set.")
  end
  if desc and type(desc) ~= "string" then
    error("description of prompt MUST be a string.")
  end
  if args and (type(args) ~= "table" or #args > 0) then
    error("expected arguments of prompt MUST be a dict.")
  end
  return setmetatable({
    name = name,
    callback = cb,
    description = desc,
    expected_args = args or {}
  }, _MT)
end

return _M
