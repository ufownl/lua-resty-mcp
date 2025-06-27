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
    end, {
      title = "Foobar Resource",
      description = "Demo resource definition and reading.",
      mime = "text/plain",
      annotations = {
        audience = {"user", "assistant"},
        priority = 1,
        last_modified = "2025-06-18T08:00:00Z"
      },
      size = 1024
    })
    local decl = res:to_mcp()
    ngx.say(decl.uri)
    ngx.say(decl.name)
    ngx.say(decl.title)
    ngx.say(decl.description)
    ngx.say(decl.mimeType)
    ngx.say(cjson.encode(decl.annotations.audience))
    ngx.say(decl.annotations.priority)
    ngx.say(decl.annotations.lastModified)
    ngx.say(decl.size)
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
Foobar Resource
Demo resource definition and reading.
text/plain
["user","assistant"]
1
2025-06-18T08:00:00Z
1024
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
    end, {description = "Demo simple text resource.", mime = "text/plain"})
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
    local decl = res:to_mcp()
    ngx.say(decl.uri)
    ngx.say(decl.name)
    ngx.say(tostring(decl.description))
    ngx.say(tostring(decl.mimeType))
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
