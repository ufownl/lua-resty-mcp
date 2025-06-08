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

function _M.request(method, params, rid)
  assert(type(method) == "string", "JSONRPC: method MUST be a string.")
  assert(params == nil or type(params) == "table" and #params == 0, "JSONRPC: params MUST be a dict.")
  return {
    jsonrpc = JSONRPC_VERSION,
    id = rid or mcp.utils.generate_id(),
    method = method,
    params = params
  }
end

function _M.notification(method, params)
  assert(type(method) == "string", "JSONRPC: method MUST be a string.")
  assert(params == nil or type(params) == "table" and #params == 0, "JSONRPC: params MUST be a dict.")
  return {
    jsonrpc = JSONRPC_VERSION,
    method = method,
    params = params
  }
end

function _M.succ_resp(rid, result)
  assert(type(rid) == "string" or type(rid) == "number" and rid % 1 == 0, "JSONRPC: ID MUST be a string or integer.")
  assert(result ~= nil, "JSONRPC: result MUST be set in a successful response.")
  return {
    jsonrpc = JSONRPC_VERSION,
    id = rid,
    result = result
  }
end

function _M.fail_resp(rid, code, message, data)
  assert(type(rid) == "string" or type(rid) == "number" and rid % 1 == 0 or rid == cjson.null, "JSONRPC: ID MUST be a string or integer, or null.")
  assert(type(code) == "number" and code % 1 == 0, "JSONRPC: error code MUST be an integer.")
  assert(type(message) == "string", "JSONRPC: error message MUST be a string.")
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

local function handle_impl(dm, methods, resp_cb)
  if dm.jsonrpc ~= JSONRPC_VERSION then
    return _M.fail_resp(cjson.null, -32600, "Invalid Request")
  end
  if dm.id ~= nil and type(dm.id) ~= "string" and (type(dm.id) ~= "number" or dm.id % 1 ~= 0) and dm.id ~= cjson.null then
    return _M.fail_resp(cjson.null, -32600, "Invalid Request")
  end
  if dm.method == nil then
    if not dm.id then
      return _M.fail_resp(cjson.null, -32600, "Invalid Request")
    end
    if dm.result == nil then
      if type(dm.error) ~= "table" or type(dm.error.code) ~= "number" or dm.error.code % 1 ~= 0 or type(dm.error.message) ~= "string" then
        return _M.fail_resp(dm.id, -32600, "Invalid Request")
      end
    else
      if dm.error ~= nil then
        return _M.fail_resp(dm.id, -32600, "Invalid Request")
      end
    end
    if resp_cb then
      resp_cb(dm.id, dm.result, dm.error)
    end
  else
    if type(dm.method) ~= "string" then
      return _M.fail_resp(dm.id or cjson.null, -32600, "Invalid Request")
    end
    local fn = methods[dm.method]
    if dm.id then
      if fn then
        local result, code, message, data = fn(dm.params, dm.id)
        if result ~= nil then
          return _M.succ_resp(dm.id, result)
        elseif code and message then
          return _M.fail_resp(dm.id, code, message, data)
        else
          -- NOTE: Error code >= 0 means this is not an actual error, it should
          -- only be used by the transport to handle some internal states
          -- (e.g., removing requests that are waiting for results).
          -- So, the transport MUST NOT send that to the peer.
          return _M.fail_resp(dm.id, 0, "Request cancelled")
        end
      else
        return _M.fail_resp(dm.id, -32601, "Method not found")
      end
    else
      if fn then
        fn(dm.params)
      end
    end
  end
end

function _M.handle(msg, methods, resp_cb)
  assert(type(msg) == "string", "JSONRPC: protocol message MUST be a string.")
  assert(methods, "JSONRPC: methods MUST be set.")
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
      if type(v) == "table" then
        local r = handle_impl(v, methods, resp_cb)
        if r then
          table.insert(replies, r)
        end
      else
        table.insert(replies, _M.fail_resp(cjson.null, -32600, "Invalid Request"))
      end
    end
    return #replies > 0 and replies or nil
  end
  return handle_impl(dm, methods, resp_cb)
end

return _M
