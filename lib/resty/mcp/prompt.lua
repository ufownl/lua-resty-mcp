local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  validator = require("resty.mcp.protocol.validator")
}

local _M = {
  _NAME = "resty.mcp.prompt",
  _VERSION = mcp.version.module
}

local cjson = require("cjson.safe")

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

function _MT.__index.to_mcp(self)
  local arguments
  for name, decl in pairs(self.expected_args) do
    local prompt_arg = {}
    for k, v in pairs(decl) do
      prompt_arg[k] = v
    end
    prompt_arg.name = name
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

function _MT.__index.get(self, args, ctx)
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
  local messages, err = self.callback(args, ctx)
  if messages == nil then
    return nil, -32603, "Internal errors", {errmsg = err}
  end
  if type(messages) == "table" then
    local ok, err = mcp.validator.GetPromptResult({
      messages = messages
    })
    if not ok then
      error(err)
    end
    return {
      description = self.description,
      messages = setmetatable(messages, cjson.array_mt)
    }
  end
  return {
    description = self.description,
    messages = {
      {role = "user", content = {type = "text", text = tostring(messages)}}
    }
  }
end

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

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
