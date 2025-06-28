use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: resource template definition and reading
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local cjson = require("cjson")
    local template = require("resty.mcp.resource_template")
    local res = template.new("mock://foobar/{id}", "Foobar", function(uri, vars)
      if vars.id == "" then
        ngx.say("invalid id")
        return false
      end
      return true, {
        {text = string.format("content of %s, id=%s", uri, vars.id)},
        {uri = uri.."/bin", blob = "SGVsbG8sIHdvcmxkIQ==", mimeType = "application/octet-stream"}
      }
    end, {
      title = "Foobar Resource Template",
      description = "Demo resource template definition and reading.",
      mime = "text/plain",
      annotations = {
        audience = {"user", "assistant"},
        priority = 1,
        last_modified = "2025-06-18T08:00:00Z"
      }
    })
    local decl = res:to_mcp()
    ngx.say(decl.uriTemplate)
    ngx.say(decl.name)
    ngx.say(decl.title)
    ngx.say(decl.description)
    ngx.say(decl.mimeType)
    ngx.say(cjson.encode(decl.annotations.audience))
    ngx.say(decl.annotations.priority)
    ngx.say(decl.annotations.lastModified)
    for i = 1, 2 do
      local result, code, message, data = res:read("mock://foobar/"..i)
      if not result then
        error(string.format("%d %s", code, message))
      end
      for j, v in ipairs(result.contents) do
        ngx.say(v.uri)
        ngx.say(tostring(v.mimeType))
        ngx.say(tostring(v.text))
        ngx.say(tostring(v.blob))
      end
    end
    local _, code, message, data = res:read("mock://foobar/")
    ngx.say(string.format("%d %s %s", code, message, data.uri))
    local _, code, message, data = res:read("mock://hello")
    ngx.say(string.format("%d %s %s", code, message, data.uri))
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
mock://foobar/{id}
Foobar
Foobar Resource Template
Demo resource template definition and reading.
text/plain
["user","assistant"]
1
2025-06-18T08:00:00Z
mock://foobar/1
text/plain
content of mock://foobar/1, id=1
nil
mock://foobar/1/bin
application/octet-stream
nil
SGVsbG8sIHdvcmxkIQ==
mock://foobar/2
text/plain
content of mock://foobar/2, id=2
nil
mock://foobar/2/bin
application/octet-stream
nil
SGVsbG8sIHdvcmxkIQ==
invalid id
-32002 Resource not found mock://foobar/
-32002 Resource not found mock://hello
--- no_error_log
[error]


=== TEST 2: simple text resource
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local template = require("resty.mcp.resource_template")
    local res = template.new("mock://simple-text/{what}", "SimpleText", function(uri, vars)
      return true, "content of simple text resource: "..vars.what
    end, {description = "Demo simple text resource template.", mime = "text/plain"})
    local result, code, message, data = res:read("mock://simple-text/foobar")
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
mock://simple-text/foobar
text/plain
content of simple text resource: foobar
nil
--- no_error_log
[error]


=== TEST 3: handle errors return by callback
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local template = require("resty.mcp.resource_template")
    local res = template.new("mock://error{?message}", "MockError", function(uri, vars)
      return true, nil, ngx.unescape_uri(vars.message)
    end)
    local decl = res:to_mcp()
    ngx.say(decl.uriTemplate)
    ngx.say(decl.name)
    ngx.say(tostring(decl.description))
    ngx.say(tostring(decl.mimeType))
    ngx.say(tostring(annotations))
    local _, code, message, data = res:read("mock://error?"..ngx.encode_args({message = "mock error"}))
    ngx.say(string.format("%d %s %s", code, message, data.errmsg))
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
mock://error{?message}
MockError
nil
nil
nil
-32603 Internal errors mock error
--- no_error_log
[error]
