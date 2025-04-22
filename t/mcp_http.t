use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: handshake
--- http_config
lua_package_path 'lib/?.lua;;';
lua_shared_dict mcp_message_bus 64m;
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      return {
        capabilities = {
          prompts = false,
          resources = false,
          tools = false,
          completions = false,
          logging = false
        },
        instructions = "Hello, MCP!"
      }
    end, {
      name = "MCP Handshake Streamable HTTP",
      version = "1.0_alpha"
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
    local ok, err = init_req.validator(resp_body.result)
    if not ok then
      error(err)
    end
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
lua_shared_dict mcp_message_bus 64m;
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      return {
        capabilities = {
          prompts = false,
          resources = false,
          tools = false,
          completions = false,
          logging = false
        }
      }
    end)
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
    local ok, err = init_req.validator(resp_body.result)
    if not ok then
      error(err)
    end
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
      local de, err = cjson.decode(data)
      if not de then
        error(err)
      end
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
lua_shared_dict mcp_message_bus 64m;
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      local ok, err = server:register(mcp.tool("add", function(args)
        return args.a + args.b
      end, "Adds two numbers.", {
        type = "object",
        properties = {
          a = {type = "number"},
          b = {type = "number"}
        },
        required = {"a", "b"}
      }))
      if not ok then
        error(err)
      end

      local ok, err = server:register(mcp.tool("enable_echo", function(args, ctx)
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
      end, "Enables the echo tool."))
      if not ok then
        error(err)
      end

      return {
        capabilities = {
          prompts = false,
          resources = false,
          completions = false,
          logging = false
        },
        pagination = {
          tools = 1
        }
      }
    end)
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.streamable_http, {
      name = "MCP Tools",
      version = "1.0_alpha",
      endpoint_url = "http://127.0.0.1:1984/mcp"
    })
    if not client then
      error(err)
    end
    local ok, err = client:initialize()
    if not ok then
      error(err)
    end
    local tools, err = client:list_tools()
    if not tools then
      error(err)
    end
    for i, v in ipairs(tools) do
      ngx.say(v.name)
      ngx.say(v.description)
    end
    ngx.say(tostring(client.server.discovered_tools == tools))
    local res, err = client:call_tool("add", {a = 1, b = 2})
    if not res then
      error(err)
    end
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    local _, err = client:call_tool("echo", {message = "Hello, world!"})
    ngx.say(err)
    local res, err = client:call_tool("enable_echo")
    if not res then
      error(err)
    end
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    ngx.say(tostring(client.server.discovered_tools == tools))
    local tools, err = client:list_tools()
    if not tools then
      error(err)
    end
    for i, v in ipairs(tools) do
      ngx.say(v.name)
      ngx.say(v.description)
    end
    ngx.say(tostring(client.server.discovered_tools == tools))
    local res, err = client:call_tool("echo", {message = "Hello, world!"})
    if not res then
      error(err)
    end
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    local res, err = client:call_tool("enable_echo")
    if not res then
      error(err)
    end
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
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
true
nil
text 3
-32602 Unknown tool {"name":"echo"}
nil
false
add
Adds two numbers.
enable_echo
Enables the echo tool.
echo
Echoes back the input.
true
nil
text MCP Tools v1.0_alpha say: Hello, world!
true
text tool (name: echo) had been registered
--- no_error_log
[error]


=== TEST 4: prompts
--- http_config
lua_package_path 'lib/?.lua;;';
lua_shared_dict mcp_message_bus 64m;
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      local ok, err = server:register(mcp.prompt("simple_prompt", function(args)
        return "This is a simple prompt without arguments."
      end, "A prompt without arguments."))
      if not ok then
        error(err)
      end

      local ok, err = server:register(mcp.prompt("complex_prompt", function(args)
        return {
          {role = "user", content = {type = "text", text = string.format("This is a complex prompt with arguments: temperature=%s, style=%s", args.temperature, tostring(args.style))}},
          {role = "assistant", content = {type = "text", text = string.format("Assistant reply: temperature=%s, style=%s", args.temperature, tostring(args.style))}}
        }
      end, "A prompt with arguments.", {
        temperature = {description = "Temperature setting.", required = true},
        style = {description = "Output style."}
      }))
      if not ok then
        error(err)
      end

      local ok, err = server:register(mcp.tool("enable_mock_error", function(args, ctx)
        local ok, err = ctx.session:register(mcp.prompt("mock_error", function(args)
          return nil, "mock error"
        end, "Mock error message."))
        if not ok then
          return nil, err
        end
        return {}
      end, "Enable mock error prompt."))
      if not ok then
        error(err)
      end

      return {
        capabilities = {
          resources = false,
          completions = false,
          logging = false
        },
        pagination = {
          prompts = 1
        }
      }
    end)
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.streamable_http, {
      endpoint_url = "http://127.0.0.1:1984/mcp"
    })
    if not client then
      error(err)
    end
    local ok, err = client:initialize()
    if not ok then
      error(err)
    end
    local prompts, err = client:list_prompts()
    if not prompts then
      error(err)
    end
    for i, v in ipairs(prompts) do
      ngx.say(v.name)
      ngx.say(v.description)
    end
    ngx.say(tostring(client.server.discovered_prompts == prompts))
    local res, err = client:get_prompt("simple_prompt")
    if not res then
      error(err)
    end
    ngx.say(res.description)
    for i, v in ipairs(res.messages) do
      ngx.say(string.format("%s %s %s", v.role, v.content.type, v.content.text))
    end
    local res, err = client:get_prompt("complex_prompt", {
      temperature = "0.4",
      style = "json"
    })
    if not res then
      error(err)
    end
    ngx.say(res.description)
    for i, v in ipairs(res.messages) do
      ngx.say(string.format("%s %s %s", v.role, v.content.type, v.content.text))
    end
    local _, err = client:get_prompt("mock_error")
    ngx.say(err)
    local res, err = client:call_tool("enable_mock_error")
    if not res then
      error(err)
    end
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    ngx.say(tostring(client.server.discovered_prompts == prompts))
    local prompts, err = client:list_prompts()
    if not prompts then
      error(err)
    end
    for i, v in ipairs(prompts) do
      ngx.say(v.name)
      ngx.say(v.description)
    end
    ngx.say(tostring(client.server.discovered_prompts == prompts))
    local _, err = client:get_prompt("mock_error")
    ngx.say(err)
    local res, err = client:call_tool("enable_mock_error")
    if not res then
      error(err)
    end
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
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
--- no_error_log
[error]
