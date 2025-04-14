use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: resource definition and reading
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local cjson = require("cjson")
    local resource = require("resty.mcp.resource")
    local res = resource.new("mock://foobar", "Foobar", function(uri)
      return {
        {text = "content of "..uri},
        {uri = uri.."/bin", blob = "SGVsbG8sIHdvcmxkIQ==", mimeType = "application/octet-stream"}
      }
    end, "Demo resource definition and reading.", "text/plain", {
      audience = {"user", "assistant"},
      priority = 1
    })
    local schema = res:to_mcp()
    ngx.say(schema.uri)
    ngx.say(schema.name)
    ngx.say(schema.description)
    ngx.say(schema.mimeType)
    ngx.say(cjson.encode(schema.annotations.audience))
    ngx.say(schema.annotations.priority)
    local result, code, message, data = res:read()
    if not result then
      error(string.format("%d %s", code, message))
    end
    for i, v in ipairs(result.contents) do
      ngx.say(v.uri)
      ngx.say(tostring(v.mimeType))
      ngx.say(tostring(v.text))
      ngx.say(tostring(v.blob))
    end
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
mock://foobar
Foobar
Demo resource definition and reading.
text/plain
["user","assistant"]
1
mock://foobar
text/plain
content of mock://foobar
nil
mock://foobar/bin
application/octet-stream
nil
SGVsbG8sIHdvcmxkIQ==
--- no_error_log
[error]


=== TEST 2: simple text resource
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local resource = require("resty.mcp.resource")
    local res = resource.new("mock://simple-text", "SimpleText", function(uri)
      return "content of simple text resource"
    end, "Demo simple text resource.", "text/plain")
    local result, code, message, data = res:read()
    if not result then
      error(string.format("%d %s", code, message))
    end
    for i, v in ipairs(result.contents) do
      ngx.say(v.uri)
      ngx.say(tostring(v.mimeType))
      ngx.say(tostring(v.text))
      ngx.say(tostring(v.blob))
    end
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
mock://simple-text
text/plain
content of simple text resource
nil
--- no_error_log
[error]


=== TEST 3: handle errors return by callback
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local resource = require("resty.mcp.resource")
    local res = resource.new("mock://error", "MockError", function(uri)
      return nil, "mock error"
    end)
    local schema = res:to_mcp()
    ngx.say(schema.uri)
    ngx.say(schema.name)
    ngx.say(tostring(schema.description))
    ngx.say(tostring(schema.mimeType))
    ngx.say(tostring(annotations))
    local _, code, message, data = res:read()
    ngx.say(string.format("%d %s %s", code, message, data.errmsg))
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
mock://error
MockError
nil
nil
nil
-32603 Internal errors mock error
--- no_error_log
[error]
