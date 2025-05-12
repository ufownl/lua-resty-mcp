use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: stdio echo
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local stdio = require("resty.mcp.transport.stdio")
    local conn = assert(stdio.client({command = "/usr/local/openresty/bin/resty -I lib t/transport/tee.lua 2>> error.log"}))
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
closed
nil
closed
--- no_error_log
[error]
