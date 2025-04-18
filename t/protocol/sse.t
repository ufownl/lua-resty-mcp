use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: SSE parser
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local sse_parser = require("resty.mcp.protocol.sse.parser")
    local parser = sse_parser.new(function(event, data, id, retry)
      ngx.say(string.format("event: %s, id: %s, retry: %s", event, tostring(id), tostring(retry)))
      ngx.say(data)
    end)
    local stream = {
      "data: YHOO",
      "data: +2",
      "data: 10",
      ""
    }
    for i, v in ipairs(stream) do
      parser(v)
    end
    local stream = {
      ": test stream",
      "",
      "data: first event",
      "id: 1",
      "",
      "data:second event",
      "id",
      "",
      "data:  third event",
      ""
    }
    for i, v in ipairs(stream) do
      parser(v)
      ngx.say("last event: "..tostring(parser.last_event))
    end
    local stream = {
      "data",
      "",
      "data",
      "data",
      "",
      "data: foobar"
    }
    for i, v in ipairs(stream) do
      parser(v)
    end
    local stream = {
      "event: hello",
      "data: Hello, world!",
      "id: 1",
      "retry: 123",
      "",
      "event: foobar",
      "data: foo",
      "data: bar",
      "id: 23\0",
      "retry: abc",
      ""
    }
    for i, v in ipairs(stream) do
      parser(v)
    end
    ngx.say("last event: "..parser.last_event)
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
event: message, id: nil, retry: nil
YHOO
+2
10
last event: nil
last event: nil
last event: nil
last event: 1
event: message, id: 1, retry: nil
first event
last event: 1
last event: 1
last event: nil
event: message, id: nil, retry: nil
second event
last event: nil
last event: nil
event: message, id: nil, retry: nil
 third event
last event: nil
event: message, id: nil, retry: nil

event: message, id: nil, retry: nil


event: hello, id: 1, retry: 123
foobar
Hello, world!
event: foobar, id: nil, retry: nil
foo
bar
last event: 1
--- no_error_log
[error]
