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

function _M.request(method, params)
  if type(method) ~= "string" then
    error("JSONRPC: method MUST be a string.")
  end
  if params and type(params) ~= "table" then
    error("JSONRPC: params MUST be a table.")
  end
  local rid = mcp.utils.generate_id()
  local msg, err = cjson.encode({
    jsonrpc = JSONRPC_VERSION,
    id = rid,
    method = method,
    params = params or nil
  })
  return msg, rid, err
end

function _M.succ_resp(rid, result)
  if type(rid) ~= "string" and (type(rid) ~= "number" or rid % 1 ~= 0) then
    error("JSONRPC: ID MUST be a string or integer.")
  end
  if result == nil then
    error("JSONRPC: result MUST be set in a successful response.")
  end
  local msg, err = cjson.encode({
    jsonrpc = JSONRPC_VERSION,
    id = rid,
    result = result
  })
  return msg, err
end

function _M.fail_resp(rid, code, message, data)
  if type(rid) ~= "string" and (type(rid) ~= "number" or rid % 1 ~= 0) and rid ~= cjson.null then
    error("JSONRPC: ID MUST be a string or integer, or null.")
  end
  if type(code) ~= "number" or code % 1 ~= 0 then
    error("JSONRPC: error code MUST be an integer.")
  end
  if type(message) ~= "string" then
    error("JSONRPC: error message MUST be a string.")
  end
  local msg, err = cjson.encode({
    jsonrpc = JSONRPC_VERSION,
    id = rid,
    error = {
      code = code,
      message = message,
      data = data
    }
  })
  return msg, err
end

function _M.notification(method, params)
  if type(method) ~= "string" then
    error("JSONRPC: method MUST be a string.")
  end
  if params and type(params) ~= "table" then
    error("JSONRPC: params MUST be a dict.")
  end
  local msg, err = cjson.encode({
    jsonrpc = JSONRPC_VERSION,
    method = method,
    params = params or nil
  })
  return msg, err
end

function _M.batch(msgs)
  return "["..table.concat(msgs, ",").."]"
end

local function handle_impl(dm, methods, resp_cb)
  if type(dm) ~= "table" or
     dm.jsonrpc ~= JSONRPC_VERSION or
     dm.method and type(dm.method) ~= "string" or
     not dm.id and not dm.method then
    return _M.fail_resp(type(dm) == "table" and dm.id or cjson.null, -32600, "Invalid Request")
  end
  if not dm.method then
    if resp_cb then
      resp_cb(dm.id, dm.result, dm.error)
    end
    return
  end
  local fn = methods[dm.method]
  if not fn then
    return dm.id and _M.fail_resp(dm.id, -32601, "Method not found") or nil
  end
  if dm.id then
    local result, code, message, data = fn(dm.params)
    return result ~= nil and _M.succ_resp(dm.id, result) or _M.fail_resp(dm.id, code, message, data)
  end
  fn(dm.params)
end

function _M.handle(msg, methods, resp_cb)
  if type(msg) ~= "string" then
    error("JSONRPC: protocol message MUST be a string.")
  end
  if type(methods) ~= "table" then
    error("JSONRPC: methods MUST be a table.")
  end
  local dm, err = cjson.decode(msg)
  if err then
    return _M.fail_resp(cjson.null, -32700, "Parse error", {errmsg = err})
  end
  if type(dm) ~= "table" then
    return _M.fail_resp(cjson.null, -32600, "Invalid Request")
  end
  if #dm > 0 then
    local replies = {}
    for i, v in ipairs(dm) do
      local r = handle_impl(v, methods, resp_cb)
      if r then
        table.insert(replies, r)
      end
    end
    return _M.batch(replies)
  end
  return handle_impl(dm, methods, resp_cb)
end

return _M
