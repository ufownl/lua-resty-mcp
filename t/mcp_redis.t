use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: handshake
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      server:run({
        capabilities = {
          prompts = false,
          resources = false,
          tools = false,
          completions = false,
          logging = false
        },
        instructions = "Hello, MCP!"
      })
    end, {
      name = "MCP Handshake Streamable HTTP",
      version = "1.0_alpha",
      message_bus = {type = "redis"}
    })
  }
}

location = /t {
  content_by_lua_block {
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
    ngx.say(resp_body.result.serverInfo.version)
    ngx.say(resp_body.result.instructions)
    ngx.req.set_header("Mcp-Session-Id", session_id)
    local resp = ngx.location.capture("/mcp", {
      method = ngx.HTTP_POST,
      body = cjson.encode(protocol.notification.initialized())
    })
    ngx.say(resp.status)
    local resp = ngx.location.capture("/mcp", {method = ngx.HTTP_DELETE})
    ngx.say(resp.status)
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
200
application/json
MCP Handshake Streamable HTTP
1.0_alpha
Hello, MCP!
202
204
--- no_error_log
[error]


=== TEST 2: error handling
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      server:run({
        capabilities = {
          prompts = false,
          resources = false,
          tools = false,
          completions = false,
          logging = false
        }
      })
    end, {
      message_bus = {type = "redis"}
    })
  }
}

location = /t {
  content_by_lua_block {
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
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
400
400
400
400
-32700 Parse error
-32600 Invalid Request
400
404
404
404
404
application/json
-32700 Parse error
application/json
-32600 Invalid Request
application/json
-32600 Invalid Request
-32600 Invalid Request
200
application/json
202
200
text/event-stream
batch:
  -32600 Invalid Request
  -32600 Invalid Request
-32601 Method not found
-32601 Method not found
-32601 Method not found
-32601 Method not found
-32601 Method not found
-32601 Method not found
-32601 Method not found


=== TEST 3: tools
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      assert(server:register(mcp.tool("add", function(args)
        return args.a + args.b
      end, "Adds two numbers.", {
        type = "object",
        properties = {
          a = {type = "number"},
          b = {type = "number"}
        },
        required = {"a", "b"}
      })))

      assert(server:register(mcp.tool("enable_echo", function(args, ctx)
        local ok, err = ctx.session:register(mcp.tool("echo", function(args)
          return string.format("%s v%s say: %s", ctx.session.client.info.name, ctx.session.client.info.version, args.message)
        end, "Echoes back the input.", {
          type = "object",
          properties = {
            message = {
              type = "string",
              description = "Message to echo."
            }
          },
          required = {"message"}
        }))
        if not ok then
          return nil, err
        end
        return {}
      end, "Enables the echo tool.")))

      assert(server:register(mcp.tool("disable_echo", function(args, ctx)
        local ok, err = ctx.session:unregister_tool("echo")
        if not ok then
          return nil, err
        end
        return {}
      end, "Disables the echo tool.")))

      server:run({
        capabilities = {
          prompts = false,
          resources = false,
          completions = false,
          logging = false
        },
        pagination = {
          tools = 1
        }
      })
    end, {
      message_bus = {type = "redis"}
    })
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.streamable_http, {
      name = "MCP Tools",
      version = "1.0_alpha",
      endpoint_url = "http://127.0.0.1:1984/mcp"
    }))
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
      ngx.say(v.description)
    end
    ngx.say(tostring(client.server.discovered_tools == tools))
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
      ngx.say(v.description)
    end
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
add
Adds two numbers.
enable_echo
Enables the echo tool.
disable_echo
Disables the echo tool.
true
nil
text 3
-32602 Unknown tool {"name":"echo"}
tools/list_changed
nil
false
add
Adds two numbers.
enable_echo
Enables the echo tool.
disable_echo
Disables the echo tool.
echo
Echoes back the input.
true
nil
text MCP Tools v1.0_alpha say: Hello, world!
true
text tool (name: echo) had been registered
true
tools/list_changed
nil
false
true
add
Adds two numbers.
enable_echo
Enables the echo tool.
disable_echo
Disables the echo tool.
--- no_error_log
[error]


=== TEST 4: prompts
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      assert(server:register(mcp.prompt("simple_prompt", function(args)
        return "This is a simple prompt without arguments."
      end, "A prompt without arguments.")))

      assert(server:register(mcp.prompt("complex_prompt", function(args)
        return {
          {role = "user", content = {type = "text", text = string.format("This is a complex prompt with arguments: temperature=%s, style=%s", args.temperature, tostring(args.style))}},
          {role = "assistant", content = {type = "text", text = string.format("Assistant reply: temperature=%s, style=%s", args.temperature, tostring(args.style))}}
        }
      end, "A prompt with arguments.", {
        temperature = {description = "Temperature setting.", required = true},
        style = {description = "Output style."}
      })))

      assert(server:register(mcp.tool("enable_mock_error", function(args, ctx)
        local ok, err = ctx.session:register(mcp.prompt("mock_error", function(args)
          return nil, "mock error"
        end, "Mock error message."))
        if not ok then
          return nil, err
        end
        return {}
      end, "Enable mock error prompt.")))

      assert(server:register(mcp.tool("disable_mock_error", function(args, ctx)
        local ok, err = ctx.session:unregister_prompt("mock_error")
        if not ok then
          return nil, err
        end
        return {}
      end)))

      server:run({
        capabilities = {
          resources = false,
          completions = false,
          logging = false
        },
        pagination = {
          prompts = 1
        }
      })
    end, {
      message_bus = {type = "redis"}
    })
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.streamable_http, {
      endpoint_url = "http://127.0.0.1:1984/mcp"
    }))
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
      ngx.say(v.description)
    end
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
simple_prompt
A prompt without arguments.
complex_prompt
A prompt with arguments.
true
A prompt without arguments.
user text This is a simple prompt without arguments.
A prompt with arguments.
user text This is a complex prompt with arguments: temperature=0.4, style=json
assistant text Assistant reply: temperature=0.4, style=json
-32602 Invalid prompt name {"name":"mock_error"}
prompts/list_changed
nil
false
simple_prompt
A prompt without arguments.
complex_prompt
A prompt with arguments.
mock_error
Mock error message.
true
-32603 Internal errors {"errmsg":"mock error"}
true
text prompt (name: mock_error) had been registered
true
prompts/list_changed
nil
false
true
simple_prompt
A prompt without arguments.
complex_prompt
A prompt with arguments.
--- no_error_log
[error]


=== TEST 5: resources
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      assert(server:register(mcp.resource("mock://static/text", "TextResource", function(uri)
        return {
          {text = "Hello, world!"}
        }
      end, "Static text resource.", "text/plain")))

      assert(server:register(mcp.resource("mock://static/blob", "BlobResource", function(uri)
        return {
          {blob = ngx.encode_base64("Hello, world!")}
        }
      end, "Static blob resource.", "application/octet-stream")))

      assert(server:register(mcp.resource_template("mock://dynamic/text/{id}", "DynamicText", function(uri, vars)
        if vars.id == "" then
          return false
        end
        return true, {
          {text = string.format("content of dynamic text resource %s, id=%s", uri, vars.id)},
        }
      end, "Dynamic text resource.", "text/plain")))

      assert(server:register(mcp.resource_template("mock://dynamic/blob/{id}", "DynamicBlob", function(uri, vars)
        if vars.id == "" then
          return false
        end
        return true, {
          {blob = ngx.encode_base64(string.format("content of dynamic blob resource %s, id=%s", uri, vars.id))},
        }
      end, "Dynamic blob resource.", "application/octet-stream")))

      assert(server:register(mcp.tool("enable_hidden_resource", function(args, ctx)
        local ok, err = ctx.session:register(mcp.resource("mock://static/hidden", "HiddenResource", function(uri)
          return {
            {blob = ngx.encode_base64("content of hidden resource"), mimeType = "application/octet-stream"}
          }
        end, "Hidden blob resource."))
        if not ok then
          return nil, err
        end
        return {}
      end, "Enable hidden resource.")))

      assert(server:register(mcp.tool("disable_hidden_resource", function(args, ctx)
        local ok, err = ctx.session:unregister_resource("mock://static/hidden")
        if not ok then
          return nil, err
        end
        return {}
      end, "Disable hidden resource.")))

      assert(server:register(mcp.tool("enable_hidden_template", function(args, ctx)
        local ok, err = ctx.session:register(mcp.resource_template("mock://dynamic/hidden/{id}", "DynamicHidden", function(uri, vars)
          if vars.id == "" then
            return false
          end
          return true, string.format("content of dynamic hidden resource %s, id=%s", uri, vars.id)
        end, "Dynamic hidden resource.", "text/plain"))
        if not ok then
          return nil, err
        end
        return {}
      end)))

      assert(server:register(mcp.tool("disable_hidden_template", function(args, ctx)
        local ok, err = ctx.session:unregister_resource_template("mock://dynamic/hidden/{id}")
        if not ok then
          return nil, err
        end
        return {}
      end)))

      assert(server:register(mcp.tool("touch_resource", function(args, ctx)
        local ok, err = ctx.session:resource_updated(args.uri)
        if not ok then
          return nil, err
        end
        return {}
      end, "Trigger resource updated notification.", {
        type = "object",
        properties = {
          uri = {
            type = "string",
            description = "URI of updated resource."
          }
        },
        required = {"uri"}
      })))

      server:run({
        capabilities = {
          prompts = false,
          completions = false,
          logging = false
        },
        pagination = {
          resources = 1
        }
      })
    end, {
      message_bus = {type = "redis"}
    })
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.streamable_http, {
      endpoint_url = "http://127.0.0.1:1984/mcp"
    }))
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
      ngx.say(tostring(v.description))
      ngx.say(tostring(v.mimeType))
    end
    ngx.say(tostring(client.server.discovered_resources == resources))
    local templates = assert(client:list_resource_templates())
    ngx.say(tostring(client.server.discovered_resource_templates == templates))
    for i, v in ipairs(templates) do
      ngx.say(v.uriTemplate)
      ngx.say(v.name)
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
      ngx.say(tostring(v.description))
      ngx.say(tostring(v.mimeType))
    end
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
mock://static/text
TextResource
Static text resource.
text/plain
mock://static/blob
BlobResource
Static blob resource.
application/octet-stream
true
mock://static/text
text/plain
Hello, world!
nil
mock://static/blob
application/octet-stream
nil
Hello, world!
-32002 Resource not found {"uri":"mock:\/\/static\/hidden"}
resources/list_changed
nil
mock://static/hidden
application/octet-stream
nil
content of hidden resource
false
mock://static/text
TextResource
Static text resource.
text/plain
mock://static/blob
BlobResource
Static blob resource.
application/octet-stream
mock://static/hidden
HiddenResource
Hidden blob resource.
nil
true
true
mock://dynamic/text/{id}
DynamicText
Dynamic text resource.
text/plain
mock://dynamic/blob/{id}
DynamicBlob
Dynamic blob resource.
application/octet-stream
mock://dynamic/text/abc
text/plain
content of dynamic text resource mock://dynamic/text/abc, id=abc
nil
mock://dynamic/blob/123
application/octet-stream
nil
content of dynamic blob resource mock://dynamic/blob/123, id=123
-32002 Resource not found {"uri":"mock:\/\/dynamic\/blob\/"}
-32002 Resource not found {"uri":"mock:\/\/dynamic\/hidden\/foobar"}
resources/list_changed
nil
mock://dynamic/hidden/foobar
text/plain
content of dynamic hidden resource mock://dynamic/hidden/foobar, id=foobar
nil
false
true
mock://dynamic/text/{id}
DynamicText
Dynamic text resource.
text/plain
mock://dynamic/blob/{id}
DynamicBlob
Dynamic blob resource.
application/octet-stream
mock://dynamic/hidden/{id}
DynamicHidden
Dynamic hidden resource.
text/plain
nil
-32002 Resource not found {"uri":"mock:\/\/unknown"}
sub 1: mock://static/text
nil
sub 2: mock://dynamic/text/123
nil
nil
nil
sub 2: mock://dynamic/text/123
nil
nil
true
resources/list_changed
nil
false
true
mock://dynamic/text/{id}
DynamicText
Dynamic text resource.
text/plain
mock://dynamic/blob/{id}
DynamicBlob
Dynamic blob resource.
application/octet-stream
true
resources/list_changed
nil
false
true
mock://static/text
TextResource
Static text resource.
text/plain
mock://static/blob
BlobResource
Static blob resource.
application/octet-stream
--- no_error_log
[error]


=== TEST 6: roots
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      assert(server:register(mcp.resource("mock://client_capabilities", "ClientCapabilities", function(uri, ctx)
        local contents = {}
        if ctx.session.client.capabilities.roots then
          table.insert(contents, {uri = uri.."/roots", text = "true"})
          if ctx.session.client.capabilities.roots.listChanged then
            table.insert(contents, {uri = uri.."/roots/listChanged", text = "true"})
          end
        end
        if ctx.session.client.capabilities.sampling then
          table.insert(contents, {uri = uri.."/sampling", text = "true"})
        end
        return contents
      end, "Capabilities of client.")))

      assert(server:register(mcp.resource("mock://discovered_roots", "DiscoveredRoots", function(uri, ctx)
        local roots, err = ctx.session:list_roots()
        if not roots then
          return nil, err
        end
        local contents = {}
        for i, v in ipairs(roots) do
          table.insert(contents, {uri = v.uri, text = v.name or ""})
        end
        return contents
      end, "Discovered roots from client.")))

      server:run({
        capabilities = {
          prompts = false,
          tools = false,
          completions = false,
          logging = false
        },
        event_handlers = {
          ["roots/list_changed"] = function(params, ctx)
            assert(ctx.session:resource_updated("mock://discovered_roots"))
          end
        }
      })
    end, {
      message_bus = {type = "redis"}
    })
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.streamable_http, {
      endpoint_url = "http://127.0.0.1:1984/mcp",
      enable_get_sse = true
    }))
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
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
mock://client_capabilities/roots
true
mock://client_capabilities/roots/listChanged
true
2
file:///path/to/foo/bar
Foobar
file:///path/to/hello/world

0
2
file:///path/to/foo/bar

file:///path/to/hello/world
Hello, world!
END
--- no_error_log
[error]


=== TEST 7: sampling (simple string)
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      assert(server:register(mcp.resource("mock://client_capabilities", "ClientCapabilities", function(uri, ctx)
        local contents = {}
        if ctx.session.client.capabilities.roots then
          table.insert(contents, {uri = uri.."/roots", text = "true"})
          if ctx.session.client.capabilities.roots.listChanged then
            table.insert(contents, {uri = uri.."/roots/listChanged", text = "true"})
          end
        end
        if ctx.session.client.capabilities.sampling then
          table.insert(contents, {uri = uri.."/sampling", text = "true"})
        end
        return contents
      end, "Capabilities of client.")))

      assert(server:register(mcp.prompt("simple_sampling", function(args, ctx)
        local messages =  {
          {role = "user", content = {type = "text", text = "Hey, man!"}}
        }
        local res, err = ctx.session:create_message(messages, 128)
        if not res then
          return nil, err
        end
        table.insert(messages, res)
        return messages
      end, "Sampling prompt from client without arguments.")))

      server:run({
        capabilities = {
          tools = false,
          completions = false,
          logging = false
        }
      })
    end, {
      message_bus = {type = "redis"}
    })
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.streamable_http, {
      endpoint_url = "http://127.0.0.1:1984/mcp"
    }))
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
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
mock://client_capabilities/roots
true
mock://client_capabilities/roots/listChanged
true
mock://client_capabilities/sampling
true
Sampling prompt from client without arguments.
user text Hey, man! nil
assistant text Hey there! What's up? unknown
--- no_error_log
[error]


=== TEST 8: sampling (result structure)
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      assert(server:register(mcp.resource("mock://client_capabilities", "ClientCapabilities", function(uri, ctx)
        local contents = {}
        if ctx.session.client.capabilities.roots then
          table.insert(contents, {uri = uri.."/roots", text = "true"})
          if ctx.session.client.capabilities.roots.listChanged then
            table.insert(contents, {uri = uri.."/roots/listChanged", text = "true"})
          end
        end
        if ctx.session.client.capabilities.sampling then
          table.insert(contents, {uri = uri.."/sampling", text = "true"})
        end
        return contents
      end, "Capabilities of client.")))

      assert(server:register(mcp.prompt("simple_sampling", function(args, ctx)
        local messages =  {
          {role = "user", content = {type = "text", text = "Hey, man!"}}
        }
        local res, err = ctx.session:create_message(messages, 128)
        if not res then
          return nil, err
        end
        table.insert(messages, res)
        return messages
      end, "Sampling prompt from client without arguments.")))

      server:run({
        capabilities = {
          tools = false,
          completions = false,
          logging = false
        }
      })
    end, {
      message_bus = {type = "redis"}
    })
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.streamable_http, {
      endpoint_url = "http://127.0.0.1:1984/mcp"
    }))
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
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
mock://client_capabilities/roots
true
mock://client_capabilities/roots/listChanged
true
mock://client_capabilities/sampling
true
Sampling prompt from client without arguments.
user text Hey, man! nil nil
assistant image SGV5LCBtYW4h image/jpeg mock
--- no_error_log
[error]


=== TEST 9: progress
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      assert(server:register(mcp.prompt("echo", function(args, ctx)
        for i, v in ipairs({0.25, 0.5, 1}) do
          local ok, err = ctx.push_progress(v, 1, "prompt")
          if not ok then
            return
          end
        end
        return "Please process this message: "..args.message
      end, "Create an echo prompt", {message = {required = true}})))

      assert(server:register(mcp.resource("echo://static", "echo static", function(uri, ctx)
        for i, v in ipairs({0.25, 0.5, 1}) do
          local ok, err = ctx.push_progress(v, 1, "resource")
          if not ok then
            return
          end
        end
        return "Resource echo: static"
      end, "Echo a static message as a resource", "text/plain")))

      assert(server:register(mcp.resource_template("echo://{message}", "echo", function(uri, vars, ctx)
        for i, v in ipairs({0.25, 0.5, 1}) do
          local ok, err = ctx.push_progress(v, 1, "resource_template")
          if not ok then
            return
          end
        end
        return true, "Resource echo: "..ngx.unescape_uri(vars.message)
      end, "Echo a message as a resource", "text/plain")))

      assert(server:register(mcp.tool("echo", function(args, ctx)
        for i, v in ipairs({0.25, 0.5, 1}) do
          local ok, err = ctx.push_progress(v, 1, "tool")
          if not ok then
            return
          end
        end
        return "Tool echo: "..args.message
      end, "Echo a message as a tool", {
        type = "object",
        properties = {
          message = {type = "string"}
        },
        required = {"message"}
      })))

      assert(server:register(mcp.prompt("simple_sampling", function(args, ctx)
        local messages =  {
          {role = "user", content = {type = "text", text = "Hey, man!"}}
        }
        local res, err = ctx.session:create_message(messages, 128, nil, 180, function(progress, total, message)
          table.insert(messages, {
            role = "assistant",
            content = {
              type = "text",
              text = string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message))
            }
          })
          return true
        end)
        if not res then
          return nil, err
        end
        table.insert(messages, res)
        return messages
      end, "Sampling prompt from client without arguments.")))

      assert(server:register(mcp.prompt("cancel_sampling", function(args, ctx)
        local messages =  {
          {role = "user", content = {type = "text", text = "Hey, man!"}}
        }
        local res, err = ctx.session:create_message(messages, 128, nil, 180, function(progress, total, message)
          table.insert(messages, {
            role = "assistant",
            content = {
              type = "text",
              text = string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message))
            }
          })
          return nil, "test cancellation"
        end)
        if not res then
          return nil, err
        end
        table.insert(messages, res)
        return messages
      end, "Sampling prompt from client without arguments.")))

      server:run()
    end, {
      message_bus = {type = "redis"}
    })
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.streamable_http, {
      endpoint_url = "http://127.0.0.1:1984/mcp"
    }))
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
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
progress=0.25, total=1, message=prompt
progress=0.5, total=1, message=prompt
progress=1, total=1, message=prompt
Create an echo prompt
user text Please process this message: Hello, MCP!
progress=0.25, total=1, message=resource
progress=0.5, total=1, message=resource
progress=1, total=1, message=resource
echo://static
text/plain
Resource echo: static
progress=0.25, total=1, message=resource_template
progress=0.5, total=1, message=resource_template
progress=1, total=1, message=resource_template
echo://foobar
text/plain
Resource echo: foobar
progress=0.25, total=1, message=tool
progress=0.5, total=1, message=tool
progress=1, total=1, message=tool
nil
text Tool echo: Hello, MCP!
Sampling prompt from client without arguments.
user text Hey, man! nil nil
assistant text progress=0.25, total=1, message=sampling nil nil
assistant text progress=0.5, total=1, message=sampling nil nil
assistant text progress=1, total=1, message=sampling nil nil
assistant text Hey there! What's up? nil unknown
--- no_error_log
[error]


=== TEST 10: cancellation
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      local utils = require("resty.mcp.utils")

      assert(server:register(mcp.prompt("echo", function(args, ctx)
        assert(ctx.push_progress(0.25, 1, "prompt"))
        local ok, err = utils.spin_until(function()
          return ctx.cancelled()
        end, 1)
        if ok then
          return
        end
        error(err)
        return "Please process this message: "..args.message
      end, "Create an echo prompt", {message = {required = true}})))

      assert(server:register(mcp.resource("echo://static", "echo static", function(uri, ctx)
        assert(ctx.push_progress(0.25, 1, "resource"))
        local ok, err = utils.spin_until(function()
          return ctx.cancelled()
        end, 1)
        if ok then
          return
        end
        error(err)
        return "Resource echo: static"
      end, "Echo a static message as a resource", "text/plain")))

      assert(server:register(mcp.resource_template("echo://{message}", "echo", function(uri, vars, ctx)
        assert(ctx.push_progress(0.25, 1, "resource_template"))
        local ok, err = utils.spin_until(function()
          return ctx.cancelled()
        end, 1)
        if ok then
          return
        end
        error(err)
        return true, "Resource echo: "..ngx.unescape_uri(vars.message)
      end, "Echo a message as a resource", "text/plain")))

      assert(server:register(mcp.tool("echo", function(args, ctx)
        assert(ctx.push_progress(0.25, 1, "tool"))
        local ok, err = utils.spin_until(function()
          return ctx.cancelled()
        end, 1)
        if ok then
          return
        end
        error(err)
        return "Tool echo: "..args.message
      end, "Echo a message as a tool", {
        type = "object",
        properties = {
          message = {type = "string"}
        },
        required = {"message"}
      })))

      assert(server:register(mcp.prompt("simple_sampling", function(args, ctx)
        local messages =  {
          {role = "user", content = {type = "text", text = "Hey, man!"}}
        }
        local res, err = ctx.session:create_message(messages, 128, nil, 180, function(progress, total, message)
          table.insert(messages, {
            role = "assistant",
            content = {
              type = "text",
              text = string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message))
            }
          })
          return true
        end)
        if not res then
          return nil, err
        end
        table.insert(messages, res)
        return messages
      end, "Sampling prompt from client without arguments.")))

      assert(server:register(mcp.prompt("cancel_sampling", function(args, ctx)
        local messages =  {
          {role = "user", content = {type = "text", text = "Hey, man!"}}
        }
        local res, err = ctx.session:create_message(messages, 128, nil, 180, function(progress, total, message)
          table.insert(messages, {
            role = "assistant",
            content = {
              type = "text",
              text = string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message))
            }
          })
          return nil, "test cancellation"
        end)
        if not res then
          return nil, err
        end
        table.insert(messages, res)
        return messages
      end, "Sampling prompt from client without arguments.")))

      server:run()
    end, {
      message_bus = {type = "redis"}
    })
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.streamable_http, {
      endpoint_url = "http://127.0.0.1:1984/mcp",
      enable_get_sse = true
    }))
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
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
progress=0.25, total=1, message=prompt
-1 Request cancelled {"reason":"test cancellation"}
progress=0.25, total=1, message=resource
-1 Request cancelled {"reason":"test cancellation"}
progress=0.25, total=1, message=resource_template
-1 Request cancelled {"reason":"test cancellation"}
progress=0.25, total=1, message=tool
-1 Request cancelled {"reason":"test cancellation"}
-32603 Internal errors {"errmsg":"-1 Request cancelled {\"reason\":\"test cancellation\"}"}
true
--- no_error_log
[error]


=== TEST 11: batch replacement APIs
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      assert(server:register(mcp.tool("batch_prompts", function(args, ctx)
        local ok, err = ctx.session:replace_prompts({
          mcp.prompt("batch_prompt_1", function(args, ctx)
            return "content of batch_prompt_1"
          end),
          mcp.prompt("batch_prompt_2", function(args, ctx)
            return "content of batch_prompt_2"
          end)
        })
        if not ok then
          return nil, err
        end
        return {}
      end)))

      assert(server:register(mcp.tool("batch_resources", function(args, ctx)
        local ok, err = ctx.session:replace_resources({
          mcp.resource("mock://batch/static_1", "static_1", function(uri, ctx)
            return "batch_static_1"
          end),
          mcp.resource("mock://batch/static_2", "static_2", function(uri, ctx)
            return "batch_static_2"
          end)
        }, {
          mcp.resource_template("mock://batch/dynamic_1/{id}", "dynamic_1", function(uri, vars, ctx)
            if vars.id == "" then
              return false
            end
            return true, "batch_dynamic_1: "..vars.id
          end),
          mcp.resource_template("mock://batch/dynamic_2/{id}", "dynamic_2", function(uri, vars, ctx)
            if vars.id == "" then
              return false
            end
            return true, "batch_dynamic_2: "..vars.id
          end)
        })
        if not ok then
          return nil, err
        end
        return {}
      end)))

      assert(server:register(mcp.tool("batch_tools", function(args, ctx)
        local ok, err = ctx.session:replace_tools({
          mcp.tool("batch_tool_1", function(args, ctx)
            return "result of batch_tool_1"
          end),
          mcp.tool("batch_tool_2", function(args, ctx)
            return "result of batch_tool_2"
          end)
        })
        if not ok then
          return nil, err
        end
        return {}
      end)))

      server:run()
    end, {
      message_bus = {type = "redis"}
    })
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.streamable_http, {
      endpoint_url = "http://127.0.0.1:1984/mcp",
      enable_get_sse = true
    }))
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
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
0
prompts/list_changed
nil
batch_prompt_1
content of batch_prompt_1
batch_prompt_2
content of batch_prompt_2
0
0
resources/list_changed
nil
mock://batch/static_1
batch_static_1
mock://batch/static_2
batch_static_2
mock://batch/dynamic_1/{id}
batch_dynamic_1: foobar
mock://batch/dynamic_2/{id}
batch_dynamic_2: foobar
batch_prompts
batch_resources
batch_tools
tools/list_changed
nil
batch_tool_1
result of batch_tool_1
batch_tool_2
result of batch_tool_2
--- no_error_log
[error]


=== TEST 12: logging
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      assert(server:register(mcp.tool("log_echo", function(args, ctx)
        local ok, err = ctx.session:log(args.level, args.data, args.logger)
        if not ok then
          return nil, err
        end
        return {}
      end, "Echo a message as log.", {
        type = "object",
        properties = {
          level = {type = "string"},
          data = {type = "string"},
          logger = {type = "string"}
        },
        required = {"level", "data"}
      })))

      server:run({
        capabilities = {
          prompts = false,
          resources = false,
          completions = false
        }
      })
    end, {
      message_bus = {type = "redis"}
    })
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.streamable_http, {
      endpoint_url = "http://127.0.0.1:1984/mcp"
    }))
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
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
nil
[error] Foobar nil
nil
[warning] Hello, MCP! mock
nil
nil


=== TEST 13: ping
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      assert(server:register(mcp.tool("ping", function(args, ctx)
        local ok, err = ctx.session:ping()
        if not ok then
          return nil, err
        end
        return {}
      end, "Send a ping request.")))

      server:run({
        capabilities = {
          logging = false,
          prompts = false,
          resources = false,
          completions = false
        }
      })
    end, {
      message_bus = {type = "redis"}
    })
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.streamable_http, {
      endpoint_url = "http://127.0.0.1:1984/mcp"
    }))
    assert(client:initialize())
    assert(client:ping())
    local res = assert(client:call_tool("ping"))
    ngx.say(tostring(res.isError))
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
nil
--- no_error_log
[error]


=== TEST 14: completion
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      assert(server:register(mcp.prompt("simple_prompt", function(args)
        return "This is a simple prompt without arguments."
      end, "A prompt without arguments.")))

      assert(server:register(mcp.prompt("complex_prompt", function(args)
        return {
          {role = "user", content = {type = "text", text = string.format("This is a complex prompt with arguments: temperature=%s, style=%s", args.temperature, tostring(args.style))}},
          {role = "assistant", content = {type = "text", text = string.format("Assistant reply: temperature=%s, style=%s", args.temperature, tostring(args.style))}}
        }
      end, "A prompt with arguments.", {
        temperature = {description = "Temperature setting.", required = true},
        style = {description = "Output style."}
      }):complete({
        style = function(value)
          local available_values = {"a01", "a02"}
          for i = 0, 99 do
            table.insert(available_values, string.format("b%02d", i))
          end
          local values = {}
          for i, v in ipairs(available_values) do
            if string.find(v, value, 1, true) then
              table.insert(values, v)
            end
          end
          return values, #values
        end
      })))

      assert(server:register(mcp.resource_template("mock://no_completion/text/{id}", "NoCompletion", function(uri, vars)
        if vars.id == "" then
          return false
        end
        return true, {
          {text = string.format("content of no_completion text resource %s, id=%s", uri, vars.id)},
        }
      end, "No completion text resource.", "text/plain")))

      assert(server:register(mcp.resource_template("mock://dynamic/text/{id}", "DynamicText", function(uri, vars)
        if vars.id == "" then
          return false
        end
        return true, {
          {text = string.format("content of dynamic text resource %s, id=%s", uri, vars.id)},
        }
      end, "Dynamic text resource.", "text/plain"):complete({
        id = function(value)
          local available_values = {"a01", "a02"}
          for i = 0, 99 do
            table.insert(available_values, string.format("b%02d", i))
          end
          local values = {}
          for i, v in ipairs(available_values) do
            if string.find(v, value, 1, true) then
              table.insert(values, v)
            end
          end
          return values, nil, #values > 2
        end
      })))

      server:run({
        capabilities = {
          logging = false,
          tools = false
        }
      })
    end, {
      message_bus = {type = "redis"}
    })
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.streamable_http, {
      endpoint_url = "http://127.0.0.1:1984/mcp"
    }))
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
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
0
nil
nil
0
nil
nil
100
102
true
2
2
false
0
nil
nil
100
nil
true
2
nil
nil
--- no_error_log
[error]

