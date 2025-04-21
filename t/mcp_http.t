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
    mcp.transport.streamable_http.endpoint(function(server)
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
    mcp.transport.streamable_http.endpoint(function(server)
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
    local resp = ngx.location.capture("/mcp", {
      method = ngx.HTTP_GET,
    })
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
405
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
    mcp.transport.streamable_http.endpoint(function(server)
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
    local cjson = require("cjson")
    local protocol = require("resty.mcp.protocol")
    local sse_parser = require("resty.mcp.protocol.sse.parser")
    local init_req = protocol.request.initialize()
    local list_tools = protocol.request.list("tools")
    local call_tool = protocol.request.call_tool("enable_echo")
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
    ngx.req.set_header("Mcp-Session-Id", session_id)
    local resp = ngx.location.capture("/mcp", {
      method = ngx.HTTP_POST,
      body = cjson.encode(protocol.notification.initialized())
    })
    ngx.say(resp.status)
    local function parse(data, sse)
      local l = 1
      while l <= #data do
        local r = string.find(data, "\n", l, true)
        sse(string.sub(data, l, r and r - 1 or -1))
        l = r + 1
      end
    end
    local resp = ngx.location.capture("/mcp", {
      method = ngx.HTTP_POST,
      body = cjson.encode(list_tools.msg)
    })
    ngx.say(resp.status)
    ngx.say(resp.header["Content-Type"])
    parse(resp.body, sse_parser.new(function(event, data, id, retry)
      local de, err = cjson.decode(data)
      if not de then
        error(err)
      end
      local ok, err = list_tools.validator(de.result)
      if not ok then
        error(err)
      end
      ngx.say(de.result.tools[1].name.." "..de.result.tools[1].description)
      ngx.say(de.result.nextCursor)
    end))
    local resp = ngx.location.capture("/mcp", {
      method = ngx.HTTP_POST,
      body = cjson.encode(call_tool.msg)
    })
    ngx.say(resp.status)
    ngx.say(resp.header["Content-Type"])
    parse(resp.body, sse_parser.new(function(event, data, id, retry)
      local de, err = cjson.decode(data)
      if not de then
        error(err)
      end
      if de.method then
        ngx.say(de.method)
      else
        local ok, err = call_tool.validator(de.result)
        if not ok then
          error(err)
        end
        ngx.say(type(de.result.content))
      end
    end))
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
lua-resty-mcp
1.0
202
200
text/event-stream
add Adds two numbers.
idx=2
200
text/event-stream
notifications/tools/list_changed
table
204
--- no_error_log
[error]
