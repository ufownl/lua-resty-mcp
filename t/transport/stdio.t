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
    local conn, err = stdio.new({command = "resty -I lib t/transport/tee.lua"})
    if not conn then
      error("conn "..err)
    end
    local ok, err = conn:send("Hello, world!")
    if not ok then
      error("send "..err)
    end
    local data, err = conn:recv()
    if not data then
      error("recv "..err)
    end
    ngx.say(data)
    conn:close()
    local ok, err = conn:send(data)
    ngx.say(tostring(ok))
    ngx.say(err)
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
Hello, world!
nil
closed
--- no_error_log
[error]
