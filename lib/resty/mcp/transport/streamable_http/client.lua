local mcp = {
  version = require("resty.mcp.version"),
  utils = require("resty.mcp.utils"),
  sse_parser = require("resty.mcp.protocol.sse.parser")
}

local _M = {
  _NAME = "resty.mcp.transport.streamable_http.client",
  _VERSION = mcp.version.module
}

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

local cjson = require("cjson.safe")
local http = require("resty.http")

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

function _MT.__index.send(self, msg, options)
  if type(msg) ~= "table" then
    error("message MUST be a table.")
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
      end
    end)
  elseif string.sub(content_type, 1, #accepted_content.sse) == accepted_content.sse then
    ngx.thread.spawn(function()
      local sse = mcp.sse_parser.new(function(event, data, id, retry)
        if self.pending_messages then
          table.insert(self.pending_messages, data)
        end
      end)
      local buffer = ""
      local cursor = 1
      while true do
        local chunk, err = res.body_reader()
        if chunk then
          buffer = buffer..chunk
          repeat
            local l, r, err = ngx.re.find(buffer, "(\r\n?)|\n", "o", {pos = cursor})
            if err then
              error(err)
            end
            if l then
              sse(string.sub(buffer, 1, l - 1))
              buffer = string.sub(buffer, r + 1)
              cursor = 1
            else
              cursor = #buffer + 1
              break
            end
          until buffer == ""
        elseif err then
          if err ~= "timeout" then
            ngx.log(ngx.ERR, "http: ", err)
            httpc:close()
            return
          end
        else
          break
        end
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
  local ok, err = mcp.utils.spin_until(function()
    return not self.pending_messages or #self.pending_messages > 0
  end, self.read_timeout, self.spin_opts)
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
  return setmetatable({
    endpoint = {
      scheme = parsed_url[1],
      host = parsed_url[2],
      port = parsed_url[3],
      path = parsed_url[4],
      query = parsed_url[5],
      authorization = options.endpoint_auth
    },
    read_timeout = tonumber(options.read_timeout),
    spin_opts = options.spin_opts,
    http_opts = options.http_opts,
    pending_messages = {}
  }, _MT)
end

function _M.check(v)
  return mcp.utils.check_mcp_type(_M, v)
end

return _M
