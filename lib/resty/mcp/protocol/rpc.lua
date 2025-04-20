local JSONRPC_VERSION = "2.0"

local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils")
}

local _M = {
  _NAME = "resty.mcp.protocol.rpc",
  _VERSION = mcp.version.module
}

local cjson = require("cjson.safe")

local function succ_resp(rid, result)
  if type(rid) ~= "string" and (type(rid) ~= "number" or rid % 1 ~= 0) then
    error("JSONRPC: ID MUST be a string or integer.")
  end
  if result == nil then
    error("JSONRPC: result MUST be set in a successful response.")
  end
  return {
    jsonrpc = JSONRPC_VERSION,
    id = rid,
    result = result
  }
end

local function fail_resp(rid, code, message, data)
  if type(rid) ~= "string" and (type(rid) ~= "number" or rid % 1 ~= 0) and rid ~= cjson.null then
    error("JSONRPC: ID MUST be a string or integer, or null.")
  end
  if type(code) ~= "number" or code % 1 ~= 0 then
    error("JSONRPC: error code MUST be an integer.")
  end
  if type(message) ~= "string" then
    error("JSONRPC: error message MUST be a string.")
  end
  return {
    jsonrpc = JSONRPC_VERSION,
    id = rid,
    error = {
      code = code,
      message = message,
      data = data
    }
  }
end

function _M.request(method, params)
  if type(method) ~= "string" then
    error("JSONRPC: method MUST be a string.")
  end
  if params and type(params) ~= "table" then
    error("JSONRPC: params MUST be a table.")
  end
  return {
    jsonrpc = JSONRPC_VERSION,
    id = mcp.utils.generate_id(),
    method = method,
    params = params or nil
  }
end

function _M.notification(method, params)
  if type(method) ~= "string" then
    error("JSONRPC: method MUST be a string.")
  end
  if params and type(params) ~= "table" then
    error("JSONRPC: params MUST be a dict.")
  end
  return {
    jsonrpc = JSONRPC_VERSION,
    method = method,
    params = params or nil
  }
end

local function handle_impl(dm, methods, resp_cb)
  if type(dm) ~= "table" or
     dm.jsonrpc ~= JSONRPC_VERSION or
     dm.method and type(dm.method) ~= "string" or
     not dm.id and not dm.method then
    return fail_resp(type(dm) == "table" and dm.id or cjson.null, -32600, "Invalid Request")
  end
  if not dm.method then
    if resp_cb then
      resp_cb(dm.id, dm.result, dm.error)
    end
    return
  end
  local fn = methods[dm.method]
  if not fn then
    return dm.id and fail_resp(dm.id, -32601, "Method not found") or nil
  end
  if dm.id then
    local result, code, message, data = fn(dm.params, dm.id)
    return result ~= nil and succ_resp(dm.id, result) or fail_resp(dm.id, code, message, data)
  end
  fn(dm.params)
end

function _M.handle(msg, methods, resp_cb)
  if type(msg) ~= "string" then
    error("JSONRPC: protocol message MUST be a string.")
  end
  if not methods then
    error("JSONRPC: methods MUST be set.")
  end
  local dm, err = cjson.decode(msg)
  if err then
    return fail_resp(cjson.null, -32700, "Parse error", {errmsg = err})
  end
  if type(dm) ~= "table" then
    return fail_resp(cjson.null, -32600, "Invalid Request")
  end
  if #dm > 0 then
    local replies = {}
    for i, v in ipairs(dm) do
      local r = handle_impl(v, methods, resp_cb)
      if r then
        table.insert(replies, r)
      end
    end
    return #replies > 0 and replies or nil
  end
  return handle_impl(dm, methods, resp_cb)
end

return _M
