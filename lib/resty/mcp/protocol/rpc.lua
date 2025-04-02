local _M = {
  _NAME = "resty.mcp.protocol.rpc",
  _VERSION = "1.0"
}

local mcp = {
  utils = require("resty.mcp.utils")
}

local cjson = require("cjson.safe")

function _M.request(method, params)
  if type(method) ~= "string" then
    error("JSONRPC: method MUST be a string.")
  end
  if params and (type(params) ~= "table" or #params > 0) then
    error("JSONRPC: params MUST be a dict.")
  end
  local rid = mcp.utils.generate_id()
  local body, err = cjson.encode({
    jsonrpc = "2.0",
    id = rid,
    method = method,
    params = params or nil
  })
  return body, rid, err
end

function _M.succ_resp(rid, result)
  if type(rid) ~= "string" and (type(rid) ~= "number" or rid % 1 ~= 0) then
    error("JSONRPC: ID MUST be a string or integer.")
  end
  if type(result) == "nil" then
    error("JSONRPC: result MUST be set in a successful response.")
  end
  local body, err = cjson.encode({
    jsonrpc = "2.0",
    id = rid,
    result = result
  })
  return body, err
end

function _M.fail_resp(rid, code, message, data)
  if type(rid) ~= "string" and (type(rid) ~= "number" or rid % 1 ~= 0) then
    error("JSONRPC: ID MUST be a string or integer.")
  end
  if type(code) ~= "number" or code % 1 ~= 0 then
    error("JSONRPC: error code MUST be an integer.")
  end
  if type(message) ~= "string" then
    error("JSONRPC: error message MUST be a string.")
  end
  local body, err = cjson.encode({
    jsonrpc = "2.0",
    id = rid,
    error = {
      code = code,
      message = message,
      data = data
    }
  })
  return body, err
end

function _M.notification(method, params)
  if type(method) ~= "string" then
    error("JSONRPC: method MUST be a string.")
  end
  if params and (type(params) ~= "table" or #params > 0) then
    error("JSONRPC: params MUST be a dict.")
  end
  local body, err = cjson.encode({
    jsonrpc = "2.0",
    method = method,
    params = params or nil
  })
  return body, err
end

function _M.batch(protocols)
  return "["..table.concat(protocols, ",").."]"
end

return _M
