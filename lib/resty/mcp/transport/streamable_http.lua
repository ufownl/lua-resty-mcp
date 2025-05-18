local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  rpc = require("resty.mcp.protocol.rpc"),
  validator = require("resty.mcp.protocol.validator")
}

local _M = {
  _NAME = "resty.mcp.transport.streamable_http",
  _VERSION = mcp.version.module,
  client = require("resty.mcp.transport.streamable_http.client").new,
  server = require("resty.mcp.transport.streamable_http.server").new
}

local cjson = require("cjson.safe")
local ngx_semaphore = require("ngx.semaphore")
local unpack = table.unpack or unpack

local function deliver_event(message_bus, session_id, data, stream)
  if stream then
    local eid, err = message_bus:cache_event(session_id, stream, data)
    if not eid then
      return nil, err
    end
    ngx.say(string.format("data:%s\nid:%u\n", data, eid))
  else
    ngx.say(string.format("data:%s\n", data))
  end
  return ngx.flush(true)
end

local function do_POST(req_body, message_bus, session_id, options)
  local ntf_prefix = "notifications/"
  local received_rids = {}
  local pending_msgs = {}
  local reply = mcp.rpc.handle(req_body, setmetatable({}, {
    __index = function(_, key)
      if string.sub(key, 1, #ntf_prefix) == ntf_prefix then
        return function(params)
          table.insert(pending_msgs, mcp.rpc.notification(key, params))
        end
      end
      return function(params, rid)
        if not rid or received_rids[rid] then
          ngx.exit(ngx.HTTP_BAD_REQUEST)
        end
        received_rids[rid] = true
        table.insert(pending_msgs, mcp.rpc.request(key, params, rid))
        return true
      end
    end
  }), function(rid, result, errobj)
    if result ~= nil then
      table.insert(pending_msgs, mcp.rpc.succ_resp(rid, result))
    else
      table.insert(pending_msgs, mcp.rpc.fail_resp(rid, errobj.code, errobj.message, errobj.data))
    end
  end)
  if #pending_msgs > 0 then
    local data = assert(cjson.encode(#pending_msgs > 1 and pending_msgs or pending_msgs[1]))
    local ok, err = message_bus:push_smsg(session_id, data)
    if not ok then
      ngx.log(ngx.ERR, err)
      ngx.exit(err == "not found" and ngx.HTTP_NOT_FOUND or ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
  end
  if not reply then
    ngx.status = ngx.HTTP_ACCEPTED
    ngx.exit(ngx.OK)
  end
  local waiting_rids = {}
  for k, v in pairs(received_rids) do
    table.insert(waiting_rids, k)
  end
  if #waiting_rids == 0 then
    local res_body = assert(cjson.encode(reply))
    ngx.header["Content-Type"] = "application/json"
    ngx.header["Content-Length"] = #res_body
    ngx.header["Cache-Control"] = "no-store, no-transform"
    ngx.print(res_body)
    ngx.exit(ngx.OK)
  end
  ngx.header["Content-Type"] = "text/event-stream"
  ngx.header["Cache-Control"] = "no-store, no-transform"
  ngx.header["Connection"] = "keep-alive"
  local stream = options.enable_resumability and "P:"..mcp.utils.generate_id()
  if #reply > 0 then
    local pending_errs = {}
    for i, v in ipairs(reply) do
      if not v.result then
        table.insert(pending_errs, v)
      end
    end
    if #pending_errs > 0 then
      local data = assert(cjson.encode(#pending_errs > 1 and pending_errs or pending_errs[1]))
      local ok, err = deliver_event(message_bus, session_id, data, stream)
      if not ok then
        ngx.log(ngx.ERR, err)
        if ngx.headers_sent then
          ngx.exit(ngx.ERROR)
        else
          ngx.exit(err == "not found" and ngx.HTTP_NOT_FOUND or ngx.HTTP_INTERNAL_SERVER_ERROR)
        end
      end
    end
  end
  repeat
    local msgs, err = message_bus:pop_cmsgs(session_id, waiting_rids, tonumber(options.read_timeout) or 10)
    if msgs then
      for i, msg in ipairs(msgs) do
        local event_msgs = {}
        mcp.rpc.handle(msg, setmetatable({}, {
          __index = function(_, key)
            if string.sub(key, 1, #ntf_prefix) == ntf_prefix then
              return function(params)
                table.insert(event_msgs, mcp.rpc.notification(key, params))
              end
            end
            return function(params, rid)
              table.insert(event_msgs, mcp.rpc.request(key, params, rid))
              return true
            end
          end
        }), function(rid, result, errobj)
          for j, v in ipairs(waiting_rids) do
            if v == rid then
              table.remove(waiting_rids, j)
              break
            end
          end
          if result ~= nil then
            table.insert(event_msgs, mcp.rpc.succ_resp(rid, result))
          elseif errobj.code < 0 then
            table.insert(event_msgs, mcp.rpc.fail_resp(rid, errobj.code, errobj.message, errobj.data))
          end
        end)
        if #event_msgs > 0 then
          local data = assert(cjson.encode(#event_msgs > 1 and event_msgs or event_msgs[1]))
          local ok, err = deliver_event(message_bus, session_id, data, stream)
          if not ok then
            ngx.log(ngx.ERR, err)
            if ngx.headers_sent then
              ngx.exit(ngx.ERROR)
            else
              ngx.exit(err == "not found" and ngx.HTTP_NOT_FOUND or ngx.HTTP_INTERNAL_SERVER_ERROR)
            end
          end
        end
      end
    elseif err ~= "timeout" then
      ngx.log(ngx.ERR, err)
      if ngx.headers_sent then
        ngx.exit(ngx.ERROR)
      else
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
      end
    end
  until #waiting_rids == 0
end

local function session_worker(message_bus, custom_fn, options, session_id)
  options.session_id = session_id
  local mcp = require("resty.mcp")
  local server, err = mcp.server(_M, options)
  if not server then
    ngx.log(ngx.ERR, err)
    message_bus:del_session(session_id)
    return
  end
  custom_fn(mcp, server)
end

local session_scheduler

local function do_POST_init_phase(req_body, message_bus, custom_fn, options)
  local reply = mcp.rpc.handle(req_body, setmetatable({}, {
    __index = function(_, key)
      if key ~= "initialize" then
        ngx.exit(ngx.HTTP_BAD_REQUEST)
      end
      return function(params, rid)
        if not rid then
          ngx.exit(ngx.HTTP_BAD_REQUEST)
        end
        local ok, err = mcp.validator.InitializeRequest(params)
        if not ok then
          return nil, -32602, "Invalid params", {errmsg = err}
        end
        return true
      end
    end
  }), function()
    ngx.exit(ngx.HTTP_BAD_REQUEST)
  end)
  if #reply > 0 then
    ngx.exit(ngx.HTTP_BAD_REQUEST)
  end
  if reply.error then
    local res_body = assert(cjson.encode(reply))
    ngx.header["Content-Type"] = "application/json"
    ngx.header["Content-Length"] = #res_body
    ngx.header["Cache-Control"] = "no-store, no-transform"
    ngx.print(res_body)
    return
  end
  local session_id, err = message_bus:new_session()
  if not session_id then
    ngx.log(ngx.ERR, err)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end
  if session_scheduler then
    table.insert(session_scheduler.pending, {message_bus, custom_fn, options, session_id})
    session_scheduler.sema:post()
  else
    local sema, err = ngx_semaphore.new(1)
    if not sema then
      ngx.log(ngx.ERR, err)
      message_bus:del_session(session_id)
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    session_scheduler = {
      sema = sema,
      pending = {
        {message_bus, custom_fn, options, session_id}
      }
    }
    local ok, err = ngx.timer.at(0, function(premature)
      while not ngx.worker.exiting() do
        local ok, err = session_scheduler.sema:wait(1)
        if ok then
          ngx.thread.spawn(session_worker, unpack(table.remove(session_scheduler.pending, 1)))
        elseif err ~= "timeout" then
          ngx.log(ngx.ERR, err)
        end
      end
    end)
    if not ok then
      ngx.log(ngx.ERR, err)
      session_scheduler = nil
      message_bus:del_session(session_id)
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
  end
  local ok, err = message_bus:push_smsg(session_id, req_body)
  if not ok then
    ngx.log(ngx.ERR, err)
    if err ~= "not found" then
      message_bus:del_session(session_id)
    end
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end
  local function init_process_error()
    ngx.log(ngx.ERR, "initialization process error")
    message_bus:del_session(session_id)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end
  while true do
    local msgs, err = message_bus:pop_cmsgs(session_id, {reply.id}, tonumber(options.read_timeout) or 10)
    if msgs then
      if #msgs > 1 then
        init_process_error()
      else
        mcp.rpc.handle(msgs[1], {}, function(rid)
          if rid ~= reply.id then
            init_process_error()
          end
          ngx.header["Content-Type"] = "application/json"
          ngx.header["Content-Length"] = #msgs[1]
          ngx.header["Mcp-Session-Id"] = session_id
          ngx.print(msgs[1])
          ngx.exit(ngx.OK)
        end)
        init_process_error()
      end
    else
      ngx.log(ngx.ERR, err)
      if err ~= "not found" then
        message_bus:del_session(session_id)
      end
      ngx.exit(err == "timeout" and ngx.HTTP_SERVICE_UNAVAILABLE or ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
  end
end

local function do_GET(message_bus, session_id, options)
  local mk, err = message_bus:check_session(session_id)
  if not mk then
    if err then
      ngx.log(ngx.ERR, err)
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    ngx.exit(ngx.HTTP_NOT_FOUND)
  end
  ngx.header["Content-Type"] = "text/event-stream"
  ngx.header["Cache-Control"] = "no-store, no-transform"
  ngx.header["Connection"] = "keep-alive"
  ngx.send_headers()
  local ok, err = ngx.flush(true)
  if not ok then
    ngx.log(ngx.ERR, err)
    ngx.exit(ngx.ERROR)
  end
  local stream
  if options.enable_resumability then
    local last_event = tonumber(ngx.var.http_last_event_id)
    if last_event then
      local events, evs = message_bus:replay_events(session_id, last_event)
      if not events then
        ngx.log(ngx.ERR, evs)
        ngx.exit(ngx.ERROR)
      end
      if #events > 0 then
        for i, v in ipairs(events) do
          ngx.say(string.format("data:%s\nid:%u\n", v.data, v.id))
        end
        local ok, err = ngx.flush(true)
        if not ok then
          ngx.log(ngx.ERR, err)
          ngx.exit(ngx.ERROR)
        end
      end
      stream = evs
      if not stream or string.sub(stream, 1, 2) ~= "G:" then
        ngx.exit(ngx.OK)
      end
    else
      stream = "G:"..mcp.utils.generate_id()
    end
  end
  while true do
    local msgs, err = message_bus:pop_cmsgs(session_id, {"get"}, tonumber(options.read_timeout) or 10)
    if msgs then
      for i, msg in ipairs(msgs) do
        local ok, err = deliver_event(message_bus, session_id, msg, stream)
        if not ok then
          ngx.log(ngx.ERR, err)
          if ngx.headers_sent then
            ngx.exit(ngx.ERROR)
          else
            ngx.exit(err == "not found" and ngx.HTTP_NOT_FOUND or ngx.HTTP_INTERNAL_SERVER_ERROR)
          end
        end
      end
    elseif err == "not found" then
      ngx.exit(ngx.OK)
    else
      ngx.log(ngx.ERR, err)
      ngx.exit(ngx.ERROR)
    end
  end
end

local function do_DELETE(message_bus, session_id)
  local mk, err = message_bus:check_session(session_id)
  if not mk then
    if err then
      ngx.log(ngx.ERR, err)
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    ngx.exit(ngx.HTTP_NOT_FOUND)
  end
  message_bus:del_session(session_id)
  ngx.status = ngx.HTTP_NO_CONTENT
end

function _M.endpoint(custom_fn, options)
  local bus_type = options and options.message_bus and options.message_bus.type or "builtin"
  local message_bus, err = require("resty.mcp.transport.streamable_http.message_bus."..bus_type).new(options and options.message_bus)
  if not message_bus then
    ngx.log(ngx.ERR, err)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end
  local session_id = ngx.var.http_mcp_session_id
  local req_method = ngx.req.get_method()
  if req_method == "POST" then
    local accept = ngx.var.http_accept
    if not accept or
       not string.find(accept, "application/json", 1, true) or
       not string.find(accept, "text/event-stream", 1, true) then
      ngx.req.discard_body()
      ngx.exit(ngx.HTTP_NOT_ACCEPTABLE)
    end
    ngx.req.read_body()
    local req_body = ngx.req.get_body_data()
    if not req_body then
      if ngx.req.get_body_file() then
        ngx.log(ngx.ERR, "unable to read request body into memory")
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
      else
        ngx.exit(ngx.HTTP_BAD_REQUEST)
      end
    end
    if session_id then
      do_POST(req_body, message_bus, session_id, options or {})
    else
      do_POST_init_phase(req_body, message_bus, custom_fn, options or {})
    end
  elseif req_method == "GET" then
    ngx.req.discard_body()
    if not session_id then
      ngx.exit(ngx.HTTP_BAD_REQUEST)
    end
    local accept = ngx.var.http_accept
    if not accept or not string.find(accept, "text/event-stream", 1, true) then
      ngx.exit(ngx.HTTP_NOT_ACCEPTABLE)
    end
    do_GET(message_bus, session_id, options or {})
  elseif req_method == "DELETE" then
    ngx.req.discard_body()
    if not session_id then
      ngx.exit(ngx.HTTP_BAD_REQUEST)
    end
    do_DELETE(message_bus, session_id)
  end
end

return _M
