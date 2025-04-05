use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: handshake
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "resty -I lib t/mock/handshake.lua"
    })
    if not client then
      error(err)
    end
    local ok, err = client:initialize()
    if not ok then
      error(err)
    end
    client:shutdown()
    ngx.say("Hello, MCP!")
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
Hello, MCP!


=== TEST 2: handshake error
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "resty -I lib t/mock/empty.lua"
    })
    if not client then
      error(err)
    end
    local _, err = client:initialize()
    client:shutdown()
    ngx.say(err)
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
-32601 Method not found


=== TEST 3: server has no capability
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "resty -I lib t/mock/handshake.lua"
    })
    if not client then
      error(err)
    end
    local ok, err = client:initialize()
    if not ok then
      error(err)
    end
    local _, err = client:list_prompts()
    ngx.say(err)
    local _, err = client:get_prompt("foobar")
    ngx.say(err)
    local _, err = client:list_resources()
    ngx.say(err)
    local _, err = client:read_resource("mock://foobar")
    ngx.say(err)
    local _, err = client:list_tools()
    ngx.say(err)
    local _, err = client:call_tool("foobar")
    ngx.say(err)
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body_like
lua-resty-mcp v\S+ has no prompts capability
lua-resty-mcp v\S+ has no prompts capability
lua-resty-mcp v\S+ has no resources capability
lua-resty-mcp v\S+ has no resources capability
lua-resty-mcp v\S+ has no tools capability
lua-resty-mcp v\S+ has no tools capability


=== TEST 4: tools
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "resty -I lib t/mock/tools.lua"
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
    ngx.say(#tools)
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
    local res, err = client:call_tool("echo", {message = "Hello, world!"})
    if not res then
      error(err)
    end
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    ngx.sleep(1)
    ngx.say(tostring(client.server.discovered_tools == tools))
    local tools, err = client:list_tools()
    if not tools then
      error(err)
    end
    ngx.say(#tools)
    ngx.say(tostring(client.server.discovered_tools == tools))
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
2
true
false
text 3
-32602 Unknown tool {"name":"echo"}
false
false
text Hello, world!
false
3
true
