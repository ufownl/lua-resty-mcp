local _M = {
  _NAME = "t.case",
  _VERSION = "1.0"
}

function _M.handshake(mcp, client)
  assert(client:initialize())
  client:shutdown()
  ngx.say(client.server.info.name)
  ngx.say(client.server.info.title)
  ngx.say(client.server.info.version)
  ngx.say(client.server.instructions)
end

function _M.handshake_http()
  local cjson = require("cjson")
  local protocol = require("resty.mcp.protocol")
  local init_req = protocol.request.initialize()
  ngx.req.set_header("Accept", "application/json, text/event-stream")
  ngx.req.set_header("Content-Type", "application/json")
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = cjson.encode(init_req.msg)
  })
  ngx.say(resp.status)
  ngx.say(resp.header["Content-Type"])
  local session_id = resp.header["Mcp-Session-Id"]
  local resp_body = cjson.decode(resp.body)
  assert(init_req.validator(resp_body.result))
  ngx.say(resp_body.result.serverInfo.name)
  ngx.say(resp_body.result.serverInfo.title)
  ngx.say(resp_body.result.serverInfo.version)
  ngx.say(resp_body.result.instructions)
  ngx.req.set_header("Mcp-Protocol-Version", resp_body.result.serverInfo.version)
  ngx.req.set_header("Mcp-Session-Id", session_id)
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = cjson.encode(protocol.notification.initialized())
  })
  ngx.say(resp.status)
  local resp = ngx.location.capture("/mcp", {method = ngx.HTTP_DELETE})
  ngx.say(resp.status)
end

function _M.handshake_error(mcp, client)
  local _, err = client:initialize()
  client:shutdown()
  ngx.say(err)
end

function _M.error_handling_http()
  local cjson = require("cjson")
  local protocol = require("resty.mcp.protocol")
  local sse_parser = require("resty.mcp.protocol.sse.parser")
  local init_req = protocol.request.initialize()
  local list_prompts = protocol.request.list("prompts")
  local get_prompt = protocol.request.get_prompt("foobar")
  local list_resources = protocol.request.list("resources")
  local list_templates = protocol.request.list("resources/templates")
  local read_resource = protocol.request.read_resource("mock://foobar")
  local list_tools = protocol.request.list("tools")
  local call_tool = protocol.request.call_tool("foobar")
  ngx.req.set_header("Accept", "application/json, text/event-stream")
  ngx.req.set_header("Content-Type", "application/json")
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = cjson.encode(protocol.notification.initialized())
  })
  ngx.say(resp.status)
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = cjson.encode(call_tool.msg)
  })
  ngx.say(resp.status)
  local resp = ngx.location.capture("/mcp", {method = ngx.HTTP_GET})
  ngx.say(resp.status)
  local resp = ngx.location.capture("/mcp", {method = ngx.HTTP_DELETE})
  ngx.say(resp.status)
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = '{"foo":"bar'
  })
  local resp_body = cjson.decode(resp.body)
  ngx.say(string.format("%d %s", resp_body.error.code, resp_body.error.message))
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = '{"jsonrpc":"2.0"}'
  })
  local resp_body = cjson.decode(resp.body)
  ngx.say(string.format("%d %s", resp_body.error.code, resp_body.error.message))
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = '[{"jsonrpc":"2.0"},{"jsonrpc":"2.0"}]'
  })
  ngx.say(resp.status)
  ngx.req.set_header("Mcp-Session-Id", "foobar")
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = cjson.encode(protocol.notification.initialized())
  })
  ngx.say(resp.status)
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = cjson.encode(call_tool.msg)
  })
  ngx.say(resp.status)
  local resp = ngx.location.capture("/mcp", {method = ngx.HTTP_GET})
  ngx.say(resp.status)
  local resp = ngx.location.capture("/mcp", {method = ngx.HTTP_DELETE})
  ngx.say(resp.status)
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = '{"foo":"bar'
  })
  ngx.say(resp.header["Content-Type"])
  local resp_body = cjson.decode(resp.body)
  ngx.say(string.format("%d %s", resp_body.error.code, resp_body.error.message))
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = '{"jsonrpc":"2.0"}'
  })
  ngx.say(resp.header["Content-Type"])
  local resp_body = cjson.decode(resp.body)
  ngx.say(string.format("%d %s", resp_body.error.code, resp_body.error.message))
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = '[{"jsonrpc":"2.0"},{"jsonrpc":"2.0"}]'
  })
  ngx.say(resp.header["Content-Type"])
  local resp_body = cjson.decode(resp.body)
  for i, v in ipairs(resp_body) do
    ngx.say(string.format("%d %s", v.error.code, v.error.message))
  end
  ngx.req.set_header("Mcp-Session-Id", nil)
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = cjson.encode(init_req.msg)
  })
  ngx.say(resp.status)
  ngx.say(resp.header["Content-Type"])
  local session_id = resp.header["Mcp-Session-Id"]
  local resp_body = cjson.decode(resp.body)
  assert(init_req.validator(resp_body.result))
  ngx.req.set_header("Mcp-Protocol-Version", resp_body.result.serverInfo.version)
  ngx.req.set_header("Mcp-Session-Id", session_id)
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = cjson.encode(protocol.notification.initialized())
  })
  ngx.say(resp.status)
  local resp = ngx.location.capture("/mcp", {
    method = ngx.HTTP_POST,
    body = cjson.encode({
      list_prompts.msg,
      get_prompt.msg,
      '{"jsonrpc":"2.0"}',
      list_resources.msg,
      list_templates.msg,
      '{"jsonrpc":"2.0"}',
      read_resource.msg,
      list_tools.msg,
      call_tool.msg
    })
  })
  ngx.say(resp.status)
  ngx.say(resp.header["Content-Type"])
  local sse = sse_parser.new(function(event, data, id, retry)
    local de = assert(cjson.decode(data))
    if #de > 0 then
      ngx.say("batch:")
      for i, v in ipairs(de) do
        ngx.say(string.format("  %d %s", v.error.code, v.error.message))
      end
    else
      ngx.say(string.format("%d %s", de.error.code, de.error.message))
    end
  end)
  local l = 1
  while l <= #resp.body do
    local r = string.find(resp.body, "\n", l, true)
    sse(string.sub(resp.body, l, r and r - 1 or -1))
    l = r + 1
  end
  ngx.location.capture("/mcp", {method = ngx.HTTP_DELETE})
end

function _M.no_capability(mcp, client)
  assert(client:initialize())
  local _, err = client:list_prompts()
  ngx.say(err)
  local _, err = client:get_prompt("foobar")
  ngx.say(err)
  local _, err = client:list_resources()
  ngx.say(err)
  local _, err = client:list_resource_templates()
  ngx.say(err)
  local _, err = client:read_resource("mock://foobar")
  ngx.say(err)
  local _, err = client:list_tools()
  ngx.say(err)
  local _, err = client:call_tool("foobar")
  ngx.say(err)
  local _, err = client:set_log_level("warning")
  ngx.say(err)
  local _, err = client:prompt_complete("foobar", "foo", "bar")
  ngx.say(err)
  local _, err = client:resource_complete("mock://foobar/{id}", "id", "foo")
  ngx.say(err)
  client:shutdown()
end

function _M.tools(mcp, client)
  assert(client:initialize({
    event_handlers = {
      ["tools/list_changed"] = function()
        ngx.say("tools/list_changed")
      end
    }
  }))
  local tools = assert(client:list_tools())
  for i, v in ipairs(tools) do
    ngx.say(v.name)
    ngx.say(v.title)
    ngx.say(v.description)
  end
  ngx.say(tostring(client.server.discovered_tools == tools))
  local res = assert(client:call_tool("client_info"))
  ngx.say(tostring(res.isError))
  ngx.say(res.structuredContent.name)
  ngx.say(res.structuredContent.title)
  ngx.say(res.structuredContent.version)
  local res = assert(client:call_tool("add", {a = 1, b = 2}))
  ngx.say(tostring(res.isError))
  for i, v in ipairs(res.content) do
    ngx.say(string.format("%s %s", v.type, v.text))
  end
  local _, err = client:call_tool("echo", {message = "Hello, world!"})
  ngx.say(err)
  local res = assert(client:call_tool("enable_echo"))
  ngx.say(tostring(res.isError))
  for i, v in ipairs(res.content) do
    ngx.say(string.format("%s %s", v.type, v.text))
  end
  ngx.say(tostring(client.server.discovered_tools == tools))
  local tools = assert(client:list_tools())
  for i, v in ipairs(tools) do
    ngx.say(v.name)
    ngx.say(v.title)
    ngx.say(v.description)
  end
  ngx.say(tostring(client.server.discovered_tools == tools))
  local res = assert(client:call_tool("echo", {message = "Hello, world!"}))
  ngx.say(tostring(res.isError))
  for i, v in ipairs(res.content) do
    ngx.say(string.format("%s %s", v.type, v.text))
  end
  local res = assert(client:call_tool("enable_echo"))
  ngx.say(tostring(res.isError))
  for i, v in ipairs(res.content) do
    ngx.say(string.format("%s %s", v.type, v.text))
  end
  ngx.say(tostring(client.server.discovered_tools == tools))
  local res = assert(client:call_tool("disable_echo"))
  ngx.say(tostring(res.isError))
  for i, v in ipairs(res.content) do
    ngx.say(string.format("%s %s", v.type, v.text))
  end
  ngx.say(tostring(client.server.discovered_tools == tools))
  local tools = assert(client:list_tools())
  ngx.say(tostring(client.server.discovered_tools == tools))
  for i, v in ipairs(tools) do
    ngx.say(v.name)
    ngx.say(v.title)
    ngx.say(v.description)
  end
  client:shutdown()
end

function _M.prompts(mcp, client)
  assert(client:initialize({
    event_handlers = {
      ["prompts/list_changed"] = function()
        ngx.say("prompts/list_changed")
      end
    }
  }))
  local prompts = assert(client:list_prompts())
  for i, v in ipairs(prompts) do
    ngx.say(v.name)
    ngx.say(v.title)
    ngx.say(v.description)
  end
  ngx.say(tostring(client.server.discovered_prompts == prompts))
  local res = assert(client:get_prompt("simple_prompt"))
  ngx.say(res.description)
  for i, v in ipairs(res.messages) do
    ngx.say(string.format("%s %s %s", v.role, v.content.type, v.content.text))
  end
  local res = assert(client:get_prompt("complex_prompt", {
    temperature = "0.4",
    style = "json"
  }))
  ngx.say(res.description)
  for i, v in ipairs(res.messages) do
    ngx.say(string.format("%s %s %s", v.role, v.content.type, v.content.text))
  end
  local _, err = client:get_prompt("mock_error")
  ngx.say(err)
  local res = assert(client:call_tool("enable_mock_error"))
  ngx.say(tostring(res.isError))
  for i, v in ipairs(res.content) do
    ngx.say(string.format("%s %s", v.type, v.text))
  end
  ngx.say(tostring(client.server.discovered_prompts == prompts))
  local prompts = assert(client:list_prompts())
  for i, v in ipairs(prompts) do
    ngx.say(v.name)
    ngx.say(v.title)
    ngx.say(v.description)
  end
  ngx.say(tostring(client.server.discovered_prompts == prompts))
  local _, err = client:get_prompt("mock_error")
  ngx.say(err)
  local res = assert(client:call_tool("enable_mock_error"))
  ngx.say(tostring(res.isError))
  for i, v in ipairs(res.content) do
    ngx.say(string.format("%s %s", v.type, v.text))
  end
  ngx.say(tostring(client.server.discovered_prompts == prompts))
  local res = assert(client:call_tool("disable_mock_error"))
  ngx.say(tostring(res.isError))
  for i, v in ipairs(res.content) do
    ngx.say(string.format("%s %s", v.type, v.text))
  end
  ngx.say(tostring(client.server.discovered_prompts == prompts))
  local prompts = assert(client:list_prompts())
  ngx.say(tostring(client.server.discovered_prompts == prompts))
  for i, v in ipairs(prompts) do
    ngx.say(v.name)
    ngx.say(v.title)
    ngx.say(v.description)
  end
  client:shutdown()
end

function _M.resources(mcp, client)
  assert(client:initialize({
    event_handlers = {
      ["resources/list_changed"] = function()
        ngx.say("resources/list_changed")
      end
    }
  }))
  local resources = assert(client:list_resources())
  for i, v in ipairs(resources) do
    ngx.say(v.uri)
    ngx.say(v.name)
    ngx.say(v.title)
    ngx.say(tostring(v.description))
    ngx.say(tostring(v.mimeType))
  end
  ngx.say(tostring(client.server.discovered_resources == resources))
  for i, uri in ipairs({"mock://static/text", "mock://static/blob", "mock://static/hidden"}) do
    local res, err = client:read_resource(uri)
    if res then
      for j, v in ipairs(res.contents) do
        ngx.say(v.uri)
        ngx.say(tostring(v.mimeType))
        ngx.say(tostring(v.text))
        ngx.say(v.blob and ngx.decode_base64(v.blob) or "nil")
      end
    else
      ngx.say(err)
    end
  end
  local res = assert(client:call_tool("enable_hidden_resource"))
  ngx.say(tostring(res.isError))
  for i, v in ipairs(res.content) do
    ngx.say(string.format("%s %s", v.type, v.text))
  end
  local res = assert(client:read_resource("mock://static/hidden"))
  for i, v in ipairs(res.contents) do
    ngx.say(v.uri)
    ngx.say(tostring(v.mimeType))
    ngx.say(tostring(v.text))
    ngx.say(v.blob and ngx.decode_base64(v.blob) or "nil")
  end
  ngx.say(tostring(client.server.discovered_resources == resources))
  local resources = assert(client:list_resources())
  for i, v in ipairs(resources) do
    ngx.say(v.uri)
    ngx.say(v.name)
    ngx.say(v.title)
    ngx.say(tostring(v.description))
    ngx.say(tostring(v.mimeType))
  end
  ngx.say(tostring(client.server.discovered_resources == resources))
  local templates = assert(client:list_resource_templates())
  ngx.say(tostring(client.server.discovered_resource_templates == templates))
  for i, v in ipairs(templates) do
    ngx.say(v.uriTemplate)
    ngx.say(v.name)
    ngx.say(v.title)
    ngx.say(tostring(v.description))
    ngx.say(tostring(v.mimeType))
  end
  for i, uri in ipairs({"mock://dynamic/text/abc", "mock://dynamic/blob/123", "mock://dynamic/blob/"}) do
    local res, err = client:read_resource(uri)
    if res then
      for j, v in ipairs(res.contents) do
        ngx.say(v.uri)
        ngx.say(tostring(v.mimeType))
        ngx.say(tostring(v.text))
        ngx.say(v.blob and ngx.decode_base64(v.blob) or "nil")
      end
    else
      ngx.say(err)
    end
  end
  local res, err = client:read_resource("mock://dynamic/hidden/foobar")
  ngx.say(err)
  local res = assert(client:call_tool("enable_hidden_template"))
  ngx.say(tostring(res.isError))
  for i, v in ipairs(res.content) do
    ngx.say(string.format("%s %s", v.type, v.text))
  end
  local res = assert(client:read_resource("mock://dynamic/hidden/foobar"))
  for i, v in ipairs(res.contents) do
    ngx.say(v.uri)
    ngx.say(tostring(v.mimeType))
    ngx.say(tostring(v.text))
    ngx.say(v.blob and ngx.decode_base64(v.blob) or "nil")
  end
  ngx.say(tostring(client.server.discovered_resource_templates == templates))
  local templates = assert(client:list_resource_templates())
  ngx.say(tostring(client.server.discovered_resource_templates == templates))
  for i, v in ipairs(templates) do
    ngx.say(v.uriTemplate)
    ngx.say(v.name)
    ngx.say(v.title)
    ngx.say(tostring(v.description))
    ngx.say(tostring(v.mimeType))
  end
  local res = assert(client:call_tool("touch_resource", {uri = "mock://static/text"}))
  ngx.say(tostring(res.isError))
  for i, v in ipairs(res.content) do
    ngx.say(string.format("%s %s", v.type, v.text))
  end
  local uris = {"mock://static/text", "mock://dynamic/text/123", "mock://unknown"}
  for i, v in ipairs(uris) do
    local ok, err = client:subscribe_resource(v, function(uri)
      ngx.say(string.format("sub %d: %s", i, uri))
    end)
    if not ok then
      ngx.say(err)
    end
  end
  for i, uri in ipairs(uris) do
    local res = assert(client:call_tool("touch_resource", {uri = uri}))
    ngx.say(tostring(res.isError))
    for j, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
  end
  assert(client:unsubscribe_resource(uris[1]))
  for i, uri in ipairs(uris) do
    local res = assert(client:call_tool("touch_resource", {uri = uri}))
    ngx.say(tostring(res.isError))
    for j, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
  end
  ngx.say(tostring(client.server.discovered_resource_templates == templates))
  local res = assert(client:call_tool("disable_hidden_template"))
  ngx.say(tostring(res.isError))
  for i, v in ipairs(res.content) do
    ngx.say(string.format("%s %s", v.type, v.text))
  end
  ngx.say(tostring(client.server.discovered_resource_templates == templates))
  local templates = assert(client:list_resource_templates())
  ngx.say(tostring(client.server.discovered_resource_templates == templates))
  for i, v in ipairs(templates) do
    ngx.say(v.uriTemplate)
    ngx.say(v.name)
    ngx.say(v.title)
    ngx.say(tostring(v.description))
    ngx.say(tostring(v.mimeType))
  end
  local resources = assert(client:list_resources())
  ngx.say(tostring(client.server.discovered_resources == resources))
  local res = assert(client:call_tool("disable_hidden_resource"))
  ngx.say(tostring(res.isError))
  for i, v in ipairs(res.content) do
    ngx.say(string.format("%s %s", v.type, v.text))
  end
  ngx.say(tostring(client.server.discovered_resources == resources))
  local resources = assert(client:list_resources())
  ngx.say(tostring(client.server.discovered_resources == resources))
  for i, v in ipairs(resources) do
    ngx.say(v.uri)
    ngx.say(v.name)
    ngx.say(v.title)
    ngx.say(tostring(v.description))
    ngx.say(tostring(v.mimeType))
  end
  client:shutdown()
end

function _M.roots(mcp, client)
  assert(client:initialize({
    roots = {
      {path = "/path/to/foo/bar", name = "Foobar"},
      {path = "/path/to/hello/world"}
    }
  }))
  local res = assert(client:read_resource("mock://client_capabilities"))
  for i, v in ipairs(res.contents) do
    ngx.say(v.uri)
    ngx.say(v.text)
  end
  local res = assert(client:read_resource("mock://discovered_roots"))
  ngx.say(#res.contents)
  for i, v in ipairs(res.contents) do
    ngx.say(v.uri)
    ngx.say(v.text)
  end
  local sema = assert(require("ngx.semaphore").new())
  local ok, err = client:subscribe_resource("mock://discovered_roots", function(uri, ctx)
    local res = assert(ctx.session:read_resource("mock://discovered_roots"))
    ngx.say(#res.contents)
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(v.text)
    end
    sema:post()
  end)
  if not ok then
    ngx.say(err)
  end
  assert(client:expose_roots())
  assert(sema:wait(5))
  assert(client:expose_roots({
    {path = "/path/to/foo/bar"},
    {path = "/path/to/hello/world", name = "Hello, world!"}
  }))
  assert(sema:wait(5))
  ngx.say("END")
  client:shutdown()
end

function _M.sampling_string(mcp, client)
  assert(client:initialize({
    sampling_callback = function(params)
      return "Hey there! What's up?"
    end
  }))
  local res = assert(client:read_resource("mock://client_capabilities"))
  for i, v in ipairs(res.contents) do
    ngx.say(v.uri)
    ngx.say(v.text)
  end
  local res = assert(client:get_prompt("simple_sampling"))
  ngx.say(res.description)
  for i, v in ipairs(res.messages) do
    ngx.say(string.format("%s %s %s %s", v.role, v.content.type, v.content.text, tostring(v.model)))
  end
  client:shutdown()
end

function _M.sampling_struct(mcp, client)
  assert(client:initialize({
    sampling_callback = function(params)
      return {
        content = {
          type = "image",
          data = "SGV5LCBtYW4h",
          mimeType = "image/jpeg"
        },
        model = "mock"
      }
    end
  }))
  local res = assert(client:read_resource("mock://client_capabilities"))
  for i, v in ipairs(res.contents) do
    ngx.say(v.uri)
    ngx.say(v.text)
  end
  local res = assert(client:get_prompt("simple_sampling"))
  ngx.say(res.description)
  for i, v in ipairs(res.messages) do
    ngx.say(string.format("%s %s %s %s %s", v.role, v.content.type, v.content.text or v.content.data, tostring(v.content.mimeType), tostring(v.model)))
  end
  client:shutdown()
end

function _M.progress(mcp, client)
  assert(client:initialize({
    sampling_callback = function(params, ctx)
      for i, v in ipairs({0.25, 0.5, 1}) do
        assert(ctx.push_progress(v, 1, "sampling"))
      end
      return "Hey there! What's up?"
    end
  }))
  local res = assert(client:get_prompt("echo", {message = "Hello, MCP!"}, 180, function(progress, total, message)
    ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
    return true
  end))
  ngx.say(res.description)
  for i, v in ipairs(res.messages) do
    ngx.say(string.format("%s %s %s", v.role, v.content.type, v.content.text))
  end
  local res = assert(client:read_resource("echo://static", 180, function(progress, total, message)
    ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
    return true
  end))
  for i, v in ipairs(res.contents) do
    ngx.say(v.uri)
    ngx.say(tostring(v.mimeType))
    ngx.say(tostring(v.text))
  end
  local res = assert(client:read_resource("echo://foobar", 180, function(progress, total, message)
    ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
    return true
  end))
  for i, v in ipairs(res.contents) do
    ngx.say(v.uri)
    ngx.say(tostring(v.mimeType))
    ngx.say(tostring(v.text))
  end
  local res = assert(client:call_tool("echo", {message = "Hello, MCP!"}, 180, function(progress, total, message)
    ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
    return true
  end))
  ngx.say(tostring(res.isError))
  for i, v in ipairs(res.content) do
    ngx.say(string.format("%s %s", v.type, v.text))
  end
  local res = assert(client:get_prompt("simple_sampling"))
  ngx.say(res.description)
  for i, v in ipairs(res.messages) do
    ngx.say(string.format("%s %s %s %s %s", v.role, v.content.type, v.content.text or v.content.data, tostring(v.content.mimeType), tostring(v.model)))
  end
  client:shutdown()
end

function _M.cancellation(mcp, client)
  local cancelled = false
  assert(client:initialize({
    sampling_callback = function(params, ctx)
      local progress = 0
      while true do
        local ok, err = ctx.push_progress(progress, nil, "sampling")
        if not ok then
          cancelled = ctx.cancelled()
          return
        end
        progress = progress + 0.001
      end
      return "Hey there! What's up?"
    end
  }))
  local res, err = client:get_prompt("echo", {message = "Hello, MCP!"}, 180, function(progress, total, message)
    ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
    return nil, "test cancellation"
  end)
  ngx.say(tostring(err))
  local res, err = client:read_resource("echo://static", 180, function(progress, total, message)
    ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
    return nil, "test cancellation"
  end)
  ngx.say(tostring(err))
  local res, err = client:read_resource("echo://foobar", 180, function(progress, total, message)
    ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
    return nil, "test cancellation"
  end)
  ngx.say(tostring(err))
  local res, err = client:call_tool("echo", {message = "Hello, MCP!"}, 180, function(progress, total, message)
    ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
    return nil, "test cancellation"
  end)
  ngx.say(tostring(err))
  local res, err = client:get_prompt("cancel_sampling")
  ngx.say(tostring(err))
  assert(client:wait_background_tasks())
  ngx.say(tostring(cancelled))
  client:shutdown()
end

function _M.batch_replace(mcp, client)
  assert(client:initialize({
    event_handlers = {
      ["prompts/list_changed"] = function()
        ngx.say("prompts/list_changed")
      end,
      ["resources/list_changed"] = function()
        ngx.say("resources/list_changed")
      end,
      ["tools/list_changed"] = function()
        ngx.say("tools/list_changed")
      end
    }
  }))
  local prompts = assert(client:list_prompts())
  ngx.say(#prompts)
  local res = assert(client:call_tool("batch_prompts"))
  ngx.say(tostring(res.isError))
  local prompts = assert(client:list_prompts())
  for i, v in ipairs(prompts) do
    ngx.say(v.name)
    local res = assert(client:get_prompt(v.name))
    ngx.say(res.messages[1].content.text)
  end
  local resources = assert(client:list_resources())
  ngx.say(#resources)
  local templates = assert(client:list_resource_templates())
  ngx.say(#templates)
  local res = assert(client:call_tool("batch_resources"))
  ngx.say(tostring(res.isError))
  local resources = assert(client:list_resources())
  for i, v in ipairs(resources) do
    ngx.say(v.uri)
    local res = assert(client:read_resource(v.uri))
    ngx.say(res.contents[1].text)
  end
  local templates = assert(client:list_resource_templates())
  for i, v in ipairs(templates) do
    ngx.say(v.uriTemplate)
    local res = assert(client:read_resource(string.format("mock://batch/dynamic_%d/foobar", i)))
    ngx.say(res.contents[1].text)
  end
  local tools = assert(client:list_tools())
  for i, v in ipairs(tools) do
    ngx.say(v.name)
  end
  local res = assert(client:call_tool("batch_tools"))
  ngx.say(tostring(res.isError))
  local tools = assert(client:list_tools())
  for i, v in ipairs(tools) do
    ngx.say(v.name)
    local res = assert(client:call_tool(v.name))
    ngx.say(res.content[1].text)
  end
  client:shutdown()
end

function _M.logging(mcp, client)
  assert(client:initialize({
    event_handlers = {
      message = function(params)
        ngx.say(string.format("[%s] %s %s", params.level, params.data, tostring(params.logger)))
      end
    }
  }))
  local res = assert(client:call_tool("log_echo", {level = "error", data = "Foobar"}))
  ngx.say(tostring(res.isError))
  assert(client:set_log_level("warning"))
  local res = assert(client:call_tool("log_echo", {level = "error", data = "Foobar"}))
  ngx.say(tostring(res.isError))
  local res = assert(client:call_tool("log_echo", {level = "warning", data = "Hello, MCP!", logger = "mock"}))
  ngx.say(tostring(res.isError))
  local res = assert(client:call_tool("log_echo", {level = "notice", data = "Hello, MCP!", logger = "mock"}))
  ngx.say(tostring(res.isError))
  client:shutdown()
end

function _M.ping(mcp, client)
  assert(client:initialize())
  assert(client:ping())
  local res = assert(client:call_tool("ping"))
  ngx.say(tostring(res.isError))
  client:shutdown()
end

function _M.completion(mcp, client)
  assert(client:initialize())
  local res = assert(client:prompt_complete("simple_prompt", "foo", "bar"))
  ngx.say(#res.completion.values)
  ngx.say(tostring(res.completion.total))
  ngx.say(tostring(res.completion.hasMore))
  local res = assert(client:prompt_complete("complex_prompt", "temperature", "0"))
  ngx.say(#res.completion.values)
  ngx.say(tostring(res.completion.total))
  ngx.say(tostring(res.completion.hasMore))
  local res = assert(client:prompt_complete("complex_prompt", "style", ""))
  ngx.say(#res.completion.values)
  ngx.say(tostring(res.completion.total))
  ngx.say(tostring(res.completion.hasMore))
  local res = assert(client:prompt_complete("complex_prompt", "style", "a"))
  ngx.say(#res.completion.values)
  ngx.say(tostring(res.completion.total))
  ngx.say(tostring(res.completion.hasMore))
  local res = assert(client:resource_complete("mock://no_completion/text/{id}", "id", ""))
  ngx.say(#res.completion.values)
  ngx.say(tostring(res.completion.total))
  ngx.say(tostring(res.completion.hasMore))
  local res = assert(client:resource_complete("mock://dynamic/text/{id}", "id", ""))
  ngx.say(#res.completion.values)
  ngx.say(tostring(res.completion.total))
  ngx.say(tostring(res.completion.hasMore))
  local res = assert(client:resource_complete("mock://dynamic/text/{id}", "id", "a"))
  ngx.say(#res.completion.values)
  ngx.say(tostring(res.completion.total))
  ngx.say(tostring(res.completion.hasMore))
  local res = assert(client:prompt_complete("complex_prompt", "style", "", {style = "foobar"}))
  ngx.say(#res.completion.values)
  ngx.say(res.completion.values[1])
  ngx.say(tostring(res.completion.total))
  ngx.say(tostring(res.completion.hasMore))
  local res = assert(client:resource_complete("mock://dynamic/text/{id}", "id", "", {id = "foobar"}))
  ngx.say(#res.completion.values)
  ngx.say(res.completion.values[1])
  ngx.say(tostring(res.completion.total))
  ngx.say(tostring(res.completion.hasMore))
  client:shutdown()
end

function _M.elicitation(mcp, client)
  local round = 0
  assert(client:initialize({
    elicitation_callback = function(params)
      round = round + 1
      if round == 1 then
        return {text = "Hello, world!", seed = 42}
      elseif round == 2 then
        return {text = "Hello, world!"}
      end
    end
  }))
  local res = assert(client:read_resource("mock://client_capabilities"))
  for i, v in ipairs(res.contents) do
    ngx.say(v.uri)
    ngx.say(v.text)
  end
  local res = assert(client:call_tool("simple_elicit"))
  ngx.say(res.structuredContent.action)
  ngx.say(res.structuredContent.content.text)
  ngx.say(res.structuredContent.content.seed)
  local res = assert(client:call_tool("simple_elicit"))
  ngx.say(res.structuredContent.action)
  local res = assert(client:call_tool("simple_elicit"))
  ngx.say(res.structuredContent.action)
  client:shutdown()
end

return _M
