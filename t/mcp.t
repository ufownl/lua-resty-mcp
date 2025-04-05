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
