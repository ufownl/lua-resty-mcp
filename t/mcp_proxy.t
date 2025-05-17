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
      server:run()
    end, {
      proxy = {
        transport = "stdio",
        command = "/usr/local/openresty/bin/resty -I lib t/mock/handshake.lua 2>> error.log"
      }
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
    client:shutdown()
    ngx.say(client.server.info.name)
    ngx.say(client.server.info.version)
    ngx.say(client.server.instructions)
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
MCP Handshake
1.0_alpha
Hello, MCP!
--- no_error_log
[error]


=== TEST 2: handshake error
--- http_config
lua_package_path 'lib/?.lua;;';
lua_shared_dict mcp_message_bus 64m;
--- config
location = /mcp {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    mcp.transport.streamable_http.endpoint(function(mcp, server)
      server:run()
    end, {
      proxy = {
        transport = "stdio",
        command = "/usr/local/openresty/bin/resty -I lib t/mock/empty.lua 2>> error.log"
      }
    })
  }
}

location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.streamable_http, {
      endpoint_url = "http://127.0.0.1:1984/mcp"
    }))
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
--- no_error_log
[error]
