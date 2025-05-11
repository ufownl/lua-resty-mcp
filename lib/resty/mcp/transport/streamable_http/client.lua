local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  sse_parser = require("resty.mcp.protocol.sse.parser")
}

local _M = {
  _NAME = "resty.mcp.transport.streamable_http.client",
  _VERSION = mcp.version.module
}

local cjson = require("cjson.safe")
local http = require("resty.http")
local ngx_semaphore = require("ngx.semaphore")

local accepted_content = {
  json = "application/json",
  sse = "text/event-stream"
}

local function connect(self)
  local httpc, err = http.new()
  if not httpc then
    return nil, err
  end
  local ok, err, ssl_session = httpc:connect({
    scheme = self.endpoint.scheme,
    host = self.endpoint.host,
    port = self.endpoint.port,
    pool = self.http_opts and self.http_opts.pool,
    pool_size = self.http_opts and self.http_opts.pool_size,
    backlog = self.http_opts and self.http_opts.backlog,
    proxy_opts = self.http_opts and self.http_opts.proxy_opts,
    ssl_reused_session = self.http_opts and self.http_opts.ssl_reused_session,
    ssl_verify = self.http_opts and self.http_opts.ssl_verify,
    ssl_server_name = self.http_opts and self.http_opts.ssl_server_name,
    ssl_send_status_req = self.http_opts and self.http_opts.ssl_send_status_req,
    ssl_client_cert = self.http_opts and self.http_opts.ssl_client_cert,
    ssl_client_priv_key = self.http_opts and self.http_opts.ssl_client_priv_key
  })
  if not ok then
    return nil, err
  end
  return httpc
end

local function initiate_get(self, last_event)
  local httpc, err = connect(self)
  if not httpc then
    return nil, err
  end
  local res, err = httpc:request({
    method = "GET",
    path = self.endpoint.path,
    query = self.endpoint.query,
    headers = {
      ["Authorization"] = self.endpoint.authorization,
      ["Accept"] = "text/event-stream",
      ["Mcp-Session-Id"] = self.session_id,
      ["Last-Event-ID"] = last_event
    }
  })
  if not res then
    httpc:close()
    return nil, err
  end
  if res.status ~= ngx.HTTP_OK then
    httpc:close()
    return nil, string.format("http status %d: %s", res.status, res.reason)
  end
  return httpc, res
end

local function read_sse_stream(reader, sse_parser, stop_cond, timeout_cb)
  local buffer = ""
  local cursor = 1
  repeat
    local chunk, err = reader()
    if chunk then
      buffer = buffer..chunk
      repeat
        local l, r, err = ngx.re.find(buffer, "(\r\n?)|\n", "o", {pos = cursor})
        if err then
          error(err)
        end
        if l then
          sse_parser(string.sub(buffer, 1, l - 1))
          buffer = string.sub(buffer, r + 1)
          cursor = 1
        else
          cursor = #buffer + 1
          break
        end
      until buffer == ""
    elseif err then
      if err ~= "timeout" then
        return nil, err
      end
      if timeout_cb then
        timeout_cb()
      end
    else
      break
    end
  until stop_cond and stop_cond()
  return true
end

local function open_get_sse(self, last_event)
  local httpc, res = initiate_get(self, last_event)
  if not httpc then
    return nil, res
  end
  self.sse_counter = self.sse_counter + 1
  ngx.thread.spawn(function()
    local sse_id = self.sse_counter
    local sse_parser = mcp.sse_parser.new(function(event, data, id, retry)
      if self.pending_messages then
        table.insert(self.pending_messages, data)
        self.message_sema:post()
      end
    end)
    sse_parser.last_event = last_event
    local ok, err = read_sse_stream(res.body_reader, sse_parser, function()
      return not self.pending_messages or not last_event and sse_id < self.sse_counter
    end, function()
      last_event = nil
    end)
    if not ok then
      ngx.log(ngx.ERR, "http: ", err)
      httpc:close()
      local ok, err = open_get_sse(self, sse_parser.last_event)
      if not ok then
        ngx.log(ngx.ERR, "http: ", err)
      end
      return
    end
    httpc:set_keepalive()
  end)
  return true
end

local function resume_post_sse(self, last_event)
  local httpc, res = initiate_get(self, last_event)
  if not httpc then
    return nil, res
  end
  local sse_parser = mcp.sse_parser.new(function(event, data, id, retry)
    if self.pending_messages then
      table.insert(self.pending_messages, data)
      self.message_sema:post()
    end
  end)
  sse_parser.last_event = last_event
  local ok, err = read_sse_stream(res.body_reader, sse_parser, function()
    return not self.pending_messages
  end)
  if not ok then
    httpc:close()
    return resume_post_sse(self, sse_parser.last_event)
  end
  httpc:set_keepalive()
  return true
end

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

function _MT.__index.send(self, msg, options)
  if type(msg) ~= "table" then
    error("message MUST be a table.")
  end
  if msg.error and msg.error.code >= 0 then
    return true
  end
  if not self.pending_messages then
    return nil, "closed"
  end
  local data, err = cjson.encode(msg)
  if not data then
    error(err)
  end
  local httpc, err = connect(self)
  if not httpc then
    return nil, err
  end
  local res, err = httpc:request({
    method = "POST",
    path = self.endpoint.path,
    query = self.endpoint.query,
    headers = {
      ["Authorization"] = self.endpoint.authorization,
      ["Content-Type"] = "application/json",
      ["Content-Length"] = #data,
      ["Accept"] = "application/json, text/event-stream",
      ["Mcp-Session-Id"] = self.session_id
    },
    body = data
  })
  if not res then
    httpc:close()
    return nil, err
  end
  if res.status ~= ngx.HTTP_OK then
    if res.status ~= ngx.HTTP_ACCEPTED then
      httpc:close()
      return nil, string.format("http status %d: %s", res.status, res.reason)
    end
    repeat
      local body, err = res:read_body()
      if err and err ~= "timeout" then
        httpc:close()
        return nil, err
      end
    until body
    if options and options.get_sse and self.enable_get_sse then
      local ok, err = open_get_sse(self)
      if not ok then
        httpc:close()
        return nil, err
      end
    end
    httpc:set_keepalive()
    return true
  end
  if not self.session_id then
    self.session_id = res.headers["Mcp-Session-Id"]
  end
  local content_type = res.headers["Content-Type"]
  if not content_type then
    httpc:close()
    return nil, "unable to obtain Content-Type"
  end
  if string.sub(content_type, 1, #accepted_content.json) == accepted_content.json then
    ngx.thread.spawn(function()
      local body, err
      repeat
        body, err = res:read_body()
        if err and err ~= "timeout" then
          ngx.log(ngx.ERR, "http: ", err)
          httpc:close()
          return
        end
      until body
      httpc:set_keepalive()
      if self.pending_messages then
        table.insert(self.pending_messages, body)
        self.message_sema:post()
      end
    end)
  elseif string.sub(content_type, 1, #accepted_content.sse) == accepted_content.sse then
    ngx.thread.spawn(function()
      local sse_parser = mcp.sse_parser.new(function(event, data, id, retry)
        if self.pending_messages then
          table.insert(self.pending_messages, data)
          self.message_sema:post()
        end
      end)
      local ok, err = read_sse_stream(res.body_reader, sse_parser, function()
        return not self.pending_messages
      end)
      if not ok then
        ngx.log(ngx.ERR, "http: ", err)
        httpc:close()
        if sse_parser.last_event then
          local ok, err = resume_post_sse(self, sse_parser.last_event)
          if not ok then
            ngx.log(ngx.ERR, "http: ", err)
          end
        end
        return
      end
      httpc:set_keepalive()
    end)
  else
    httpc:close()
    return nil, "unsupported Content-Type"
  end
  return true
end

function _MT.__index.recv(self)
  local ok, err = self.message_sema:wait(self.read_timeout)
  if not ok then
    return nil, err
  end
  if not self.pending_messages then
    return nil, "closed"
  end
  return table.remove(self.pending_messages, 1)
end

function _MT.__index.close(self)
  self.pending_messages = nil
  self.message_sema:post()
  local httpc, err = connect(self)
  if not httpc then
    ngx.log(ngx.ERR, "http: ", err)
    return
  end
  local res, err = httpc:request({
    method = "DELETE",
    path = self.endpoint.path,
    query = self.endpoint.query,
    headers = {
      ["Authorization"] = self.endpoint.authorization,
      ["Mcp-Session-Id"] = self.session_id
    },
    body = data
  })
  if not res then
    ngx.log(ngx.ERR, "http: ", err)
    httpc:close()
    return
  end
  if res.status ~= ngx.HTTP_NO_CONTENT then
    httpc:close()
    return
  end
  httpc:set_keepalive()
end

function _M.new(options)
  if type(options) ~= "table" then
    error("options of streamable_http client transport MUST be a table.")
  end
  if type(options.endpoint_url) ~= "string" then
    error("endpoint URL MUST be a string")
  end
  local parsed_url, err = http:parse_uri(options.endpoint_url)
  if not parsed_url then
    return nil, err
  end
  local sema, err = ngx_semaphore.new()
  if not sema then
    return nil, err
  end
  return setmetatable({
    endpoint = {
      scheme = parsed_url[1],
      host = parsed_url[2],
      port = parsed_url[3],
      path = parsed_url[4],
      query = parsed_url[5],
      authorization = options.endpoint_auth
    },
    read_timeout = tonumber(options.read_timeout) or 10,
    http_opts = options.http_opts,
    enable_get_sse = options.enable_get_sse,
    sse_counter = 0,
    message_sema = sema,
    pending_messages = {}
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
