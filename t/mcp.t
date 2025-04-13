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
      command = "/usr/local/openresty/bin/resty -I lib t/mock/handshake.lua 2>> error.log"
    })
    if not client then
      error(err)
    end
    local ok, err = client:initialize()
    if not ok then
      error(err)
    end
    client:shutdown()
    ngx.say(client.server.instructions)
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
Hello, MCP!
--- no_error_log
[error]


=== TEST 2: handshake error
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/empty.lua 2>> error.log"
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
--- no_error_log
[error]


=== TEST 3: server has no capability
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/handshake.lua 2>> error.log"
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
--- no_error_log
[error]


=== TEST 4: tools
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/tools.lua 2>> error.log"
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
    for i, v in ipairs(tools) do
      ngx.say(v.name)
      ngx.say(v.description)
    end
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
    local ok, err = client:wait_background_tasks()
    if not ok then
      error(err)
    end
    ngx.say(tostring(client.server.discovered_tools == tools))
    local tools, err = client:list_tools()
    if not tools then
      error(err)
    end
    for i, v in ipairs(tools) do
      ngx.say(v.name)
      ngx.say(v.description)
    end
    ngx.say(tostring(client.server.discovered_tools == tools))
    local res, err = client:call_tool("echo", {message = "Hello, world!"})
    if not res then
      error(err)
    end
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    local res, err = client:call_tool("enable_echo")
    if not res then
      error(err)
    end
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
add
Adds two numbers.
enable_echo
Enables the echo tool.
true
nil
text 3
-32602 Unknown tool {"name":"echo"}
nil
false
add
Adds two numbers.
enable_echo
Enables the echo tool.
echo
Echoes back the input.
true
nil
text Hello, world!
true
text tool (name: echo) had been registered
--- no_error_log
[error]


=== TEST 5: prompts
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/prompts.lua 2>> error.log"
    })
    if not client then
      error(err)
    end
    local ok, err = client:initialize()
    if not ok then
      error(err)
    end
    local prompts, err = client:list_prompts()
    if not prompts then
      error(err)
    end
    for i, v in ipairs(prompts) do
      ngx.say(v.name)
      ngx.say(v.description)
    end
    ngx.say(tostring(client.server.discovered_prompts == prompts))
    local res, err = client:get_prompt("simple_prompt")
    if not res then
      error(err)
    end
    ngx.say(res.description)
    for i, v in ipairs(res.messages) do
      ngx.say(string.format("%s %s %s", v.role, v.content.type, v.content.text))
    end
    local res, err = client:get_prompt("complex_prompt", {
      temperature = "0.4",
      style = "json"
    })
    if not res then
      error(err)
    end
    ngx.say(res.description)
    for i, v in ipairs(res.messages) do
      ngx.say(string.format("%s %s %s", v.role, v.content.type, v.content.text))
    end
    local _, err = client:get_prompt("mock_error")
    ngx.say(err)
    local res, err = client:call_tool("enable_mock_error")
    if not res then
      error(err)
    end
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    local ok, err = client:wait_background_tasks()
    if not ok then
      error(err)
    end
    ngx.say(tostring(client.server.discovered_prompts == prompts))
    local prompts, err = client:list_prompts()
    if not prompts then
      error(err)
    end
    for i, v in ipairs(prompts) do
      ngx.say(v.name)
      ngx.say(v.description)
    end
    ngx.say(tostring(client.server.discovered_prompts == prompts))
    local _, err = client:get_prompt("mock_error")
    ngx.say(err)
    local res, err = client:call_tool("enable_mock_error")
    if not res then
      error(err)
    end
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
simple_prompt
A prompt without arguments.
complex_prompt
A prompt with arguments.
true
A prompt without arguments.
user text This is a simple prompt without arguments.
A prompt with arguments.
user text This is a complex prompt with arguments: temperature=0.4, style=json
assistant text Assistant reply: temperature=0.4, style=json
-32602 Invalid prompt name {"name":"mock_error"}
nil
false
simple_prompt
A prompt without arguments.
complex_prompt
A prompt with arguments.
mock_error
Mock error message.
true
-32603 Internal errors {"errmsg":"mock error"}
true
text prompt (name: mock_error) had been registered
--- no_error_log
[error]


=== TEST 6: resources
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/resources.lua 2>> error.log"
    })
    if not client then
      error(err)
    end
    local ok, err = client:initialize()
    if not ok then
      error(err)
    end
    local resources, err = client:list_resources()
    if not resources then
      error(err)
    end
    for i, v in ipairs(resources) do
      ngx.say(v.uri)
      ngx.say(v.name)
      ngx.say(tostring(v.description))
      ngx.say(tostring(v.mimeType))
    end
    ngx.say(tostring(client.server.discovered_resources == resources))
    for i, uri in ipairs({"mock://static/text", "mock://static/blob", "mock://static/hidden"}) do
      local res, err = client:read_resource(uri)
      if res then
        for j, v in ipairs(res.contents) do
          ngx.say(v.uri)
          ngx.say(tostring(v.mimeType))
          ngx.say(tostring(v.text))
          ngx.say(v.blob and ngx.decode_base64(v.blob) or "nil")
        end
      else
        ngx.say(err)
      end
    end
    local res, err = client:call_tool("enable_hidden_resource")
    if not res then
      error(err)
    end
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    local res, err = client:read_resource("mock://static/hidden")
    if not res then
      error(err)
    end
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(tostring(v.mimeType))
      ngx.say(tostring(v.text))
      ngx.say(v.blob and ngx.decode_base64(v.blob) or "nil")
    end
    local ok, err = client:wait_background_tasks()
    if not ok then
      error(err)
    end
    ngx.say(tostring(client.server.discovered_resources == resources))
    local resources, err = client:list_resources()
    if not resources then
      error(err)
    end
    for i, v in ipairs(resources) do
      ngx.say(v.uri)
      ngx.say(v.name)
      ngx.say(tostring(v.description))
      ngx.say(tostring(v.mimeType))
    end
    ngx.say(tostring(client.server.discovered_resources == resources))
    local templates, err = client:list_resource_templates()
    if not templates then
      error(err)
    end
    for i, v in ipairs(templates) do
      ngx.say(v.uriTemplate)
      ngx.say(v.name)
      ngx.say(tostring(v.description))
      ngx.say(tostring(v.mimeType))
    end
    for i, uri in ipairs({"mock://dynamic/text/abc", "mock://dynamic/blob/123", "mock://dynamic/blob/"}) do
      local res, err = client:read_resource(uri)
      if res then
        for j, v in ipairs(res.contents) do
          ngx.say(v.uri)
          ngx.say(tostring(v.mimeType))
          ngx.say(tostring(v.text))
          ngx.say(v.blob and ngx.decode_base64(v.blob) or "nil")
        end
      else
        ngx.say(err)
      end
    end
    local res, err = client:call_tool("touch_resource", {uri = "mock://static/text"})
    if not res then
      error(err)
    end
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    local uris = {"mock://static/text", "mock://dynamic/text/123", "mock://unknown"}
    for i, v in ipairs(uris) do
      local ok, err = client:subscribe_resource(v, function(uri)
        ngx.say(string.format("sub %d: %s", i, uri))
      end)
      if not ok then
        ngx.say(err)
      end
    end
    for i, uri in ipairs(uris) do
      local res, err = client:call_tool("touch_resource", {uri = uri})
      if not res then
        error(err)
      end
      ngx.say(tostring(res.isError))
      for i, v in ipairs(res.content) do
        ngx.say(string.format("%s %s", v.type, v.text))
      end
    end
    local ok, err = client:unsubscribe_resource(uris[1])
    if not ok then
      error(err)
    end
    for i, uri in ipairs(uris) do
      local res, err = client:call_tool("touch_resource", {uri = uri})
      if not res then
        error(err)
      end
      ngx.say(tostring(res.isError))
      for i, v in ipairs(res.content) do
        ngx.say(string.format("%s %s", v.type, v.text))
      end
    end
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
mock://static/blob
BlobResource
Static blob resource.
application/octet-stream
mock://static/text
TextResource
Static text resource.
text/plain
true
mock://static/text
text/plain
Hello, world!
nil
mock://static/blob
application/octet-stream
nil
Hello, world!
-32002 Resource not found {"uri":"mock:\/\/static\/hidden"}
nil
mock://static/hidden
application/octet-stream
nil
content of hidden resource
false
mock://static/blob
BlobResource
Static blob resource.
application/octet-stream
mock://static/hidden
HiddenResource
Hidden blob resource.
nil
mock://static/text
TextResource
Static text resource.
text/plain
true
mock://dynamic/text/{id}
DynamicText
Dynamic text resource.
text/plain
mock://dynamic/blob/{id}
DynamicBlob
Dynamic blob resource.
application/octet-stream
mock://dynamic/text/abc
text/plain
content of dynamic text resource mock://dynamic/text/abc, id=abc
nil
mock://dynamic/blob/123
application/octet-stream
nil
content of dynamic blob resource mock://dynamic/blob/123, id=123
-32002 Resource not found {"uri":"mock:\/\/dynamic\/blob\/"}
nil
-32002 Resource not found {"uri":"mock:\/\/unknown"}
sub 1: mock://static/text
nil
sub 2: mock://dynamic/text/123
nil
nil
nil
sub 2: mock://dynamic/text/123
nil
nil
--- no_error_log
[error]


=== TEST 7: roots
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/roots.lua 2>> error.log"
    })
    if not client then
      error(err)
    end
    local ok, err = client:initialize({
      {path = "/path/to/foo/bar", name = "Foobar"},
      {path = "/path/to/hello/world"}
    })
    if not ok then
      error(err)
    end
    local res, err = client:read_resource("mock://client_capabilities")
    if not res then
      error(err)
    end
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(v.text)
    end
    local res, err = client:read_resource("mock://discovered_roots")
    if not res then
      error(err)
    end
    ngx.say(#res.contents)
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(v.text)
    end
    local sema, err = require("ngx.semaphore").new()
    if not sema then
      error(err)
    end
    local ok, err = client:subscribe_resource("mock://discovered_roots", function(uri)
      local res, err = client:read_resource("mock://discovered_roots")
      if not res then
        error(err)
      end
      ngx.say(#res.contents)
      for i, v in ipairs(res.contents) do
        ngx.say(v.uri)
        ngx.say(v.text)
      end
      sema:post()
    end)
    if not ok then
      ngx.say(err)
    end
    local ok, err = client:expose_roots()
    if not ok then
      error(err)
    end
    local ok, err = sema:wait(5)
    if not ok then
      error(err)
    end
    local ok, err = client:expose_roots({
      {path = "/path/to/foo/bar"},
      {path = "/path/to/hello/world", name = "Hello, world!"}
    })
    if not ok then
      error(err)
    end
    local ok, err = sema:wait(5)
    if not ok then
      error(err)
    end
    ngx.say("END")
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
mock://client_capabilities/roots
true
mock://client_capabilities/roots/listChanged
true
2
file:///path/to/foo/bar
Foobar
file:///path/to/hello/world

0
2
file:///path/to/foo/bar

file:///path/to/hello/world
Hello, world!
END
--- no_error_log
[error]


=== TEST 8: sampling (simple string)
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/sampling.lua 2>> error.log"
    })
    if not client then
      error(err)
    end
    local ok, err = client:initialize(nil, function(params)
      return "Hey there! What's up?"
    end)
    if not ok then
      error(err)
    end
    local res, err = client:read_resource("mock://client_capabilities")
    if not res then
      error(err)
    end
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(v.text)
    end
    local res, err = client:get_prompt("simple_sampling")
    if not res then
      error(err)
    end
    ngx.say(res.description)
    for i, v in ipairs(res.messages) do
      ngx.say(string.format("%s %s %s %s", v.role, v.content.type, v.content.text, tostring(v.model)))
    end
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
mock://client_capabilities/roots
true
mock://client_capabilities/roots/listChanged
true
mock://client_capabilities/sampling
true
Sampling prompt from client without arguments.
user text Hey, man! nil
assistant text Hey there! What's up? unknown
--- no_error_log
[error]


=== TEST 9: sampling (result structure)
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/sampling.lua 2>> error.log"
    })
    if not client then
      error(err)
    end
    local ok, err = client:initialize(nil, function(params)
      return {
        content = {
          type = "image",
          data = "SGV5LCBtYW4h",
          mimeType = "image/jpeg"
        },
        model = "mock"
      }
    end)
    if not ok then
      error(err)
    end
    local res, err = client:read_resource("mock://client_capabilities")
    if not res then
      error(err)
    end
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(v.text)
    end
    local res, err = client:get_prompt("simple_sampling")
    if not res then
      error(err)
    end
    ngx.say(res.description)
    for i, v in ipairs(res.messages) do
      ngx.say(string.format("%s %s %s %s %s", v.role, v.content.type, v.content.text or v.content.data, tostring(v.content.mimeType), tostring(v.model)))
    end
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
mock://client_capabilities/roots
true
mock://client_capabilities/roots/listChanged
true
mock://client_capabilities/sampling
true
Sampling prompt from client without arguments.
user text Hey, man! nil nil
assistant image SGV5LCBtYW4h image/jpeg mock
--- no_error_log
[error]
