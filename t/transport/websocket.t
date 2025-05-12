use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: websocket echo
--- http_config
lua_package_path 'lib/?.lua;;';
lua_socket_log_errors off;
--- config
location = /ws_tee {
  content_by_lua_block {
    local cjson = require("cjson")
    local websocket = require("resty.mcp.transport.websocket")
    local conn = assert(websocket.server())
    while true do
      local data, err = conn:recv()
      if data then
        assert(conn:send(cjson.decode(data)))
      elseif err ~= "timeout" then
        break
      end
    end
    conn:close()
  }
}

location = /t {
  content_by_lua_block {
    local websocket = require("resty.mcp.transport.websocket")
    local conn = assert(websocket.client({endpoint_url = "ws://127.0.0.1:1984/ws_tee"}))
    assert(conn:send({"Hello, world!"}))
    local data = assert(conn:recv())
    ngx.say(data)
    conn:close()
    local ok, err = conn:send({"Hello, world!"})
    ngx.say(tostring(ok))
    ngx.say(err)
    local ok, err = conn:recv()
    ngx.say(tostring(ok))
    ngx.say(err)
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
["Hello, world!"]
nil
already closed
nil
failed to receive the first 2 bytes: closed
--- no_error_log
[error]
