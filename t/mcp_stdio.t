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
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/handshake.lua 2>> error.log"
    }))
    assert(client:initialize())
    client:shutdown()
    ngx.say(client.server.info.name)
    ngx.say(client.server.info.title)
    ngx.say(client.server.info.version)
    ngx.say(client.server.instructions)
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
handshake
MCP Handshake
1.0_alpha
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
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/empty.lua 2>> error.log"
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


=== TEST 3: server has no capability
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/handshake.lua 2>> error.log"
    }))
    assert(client:initialize())
    local _, err = client:list_prompts()
    ngx.say(err)
    local _, err = client:get_prompt("foobar")
    ngx.say(err)
    local _, err = client:list_resources()
    ngx.say(err)
    local _, err = client:list_resource_templates()
    ngx.say(err)
    local _, err = client:read_resource("mock://foobar")
    ngx.say(err)
    local _, err = client:list_tools()
    ngx.say(err)
    local _, err = client:call_tool("foobar")
    ngx.say(err)
    local _, err = client:set_log_level("warning")
    ngx.say(err)
    local _, err = client:prompt_complete("foobar", "foo", "bar")
    ngx.say(err)
    local _, err = client:resource_complete("mock://foobar/{id}", "id", "foo")
    ngx.say(err)
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
MCP Handshake v1.0_alpha has no prompts capability
MCP Handshake v1.0_alpha has no prompts capability
MCP Handshake v1.0_alpha has no resources capability
MCP Handshake v1.0_alpha has no resources capability
MCP Handshake v1.0_alpha has no resources capability
MCP Handshake v1.0_alpha has no tools capability
MCP Handshake v1.0_alpha has no tools capability
MCP Handshake v1.0_alpha has no logging capability
MCP Handshake v1.0_alpha has no completions capability
MCP Handshake v1.0_alpha has no completions capability
--- no_error_log
[error]


=== TEST 4: tools
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.stdio, {
      name = "test_tools",
      title = "MCP Tools",
      version = "1.0_alpha",
      command = "/usr/local/openresty/bin/resty -I lib t/mock/tools.lua 2>> error.log"
    }))
    assert(client:initialize({
      event_handlers = {
        ["tools/list_changed"] = function()
          ngx.say("tools/list_changed")
        end
      }
    }))
    local tools = assert(client:list_tools())
    for i, v in ipairs(tools) do
      ngx.say(v.name)
      ngx.say(v.description)
    end
    ngx.say(tostring(client.server.discovered_tools == tools))
    local res = assert(client:call_tool("client_info"))
    ngx.say(tostring(res.isError))
    ngx.say(res.structuredContent.name)
    ngx.say(res.structuredContent.title)
    ngx.say(res.structuredContent.version)
    local res = assert(client:call_tool("add", {a = 1, b = 2}))
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    local _, err = client:call_tool("echo", {message = "Hello, world!"})
    ngx.say(err)
    local res = assert(client:call_tool("enable_echo"))
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    ngx.say(tostring(client.server.discovered_tools == tools))
    local tools = assert(client:list_tools())
    for i, v in ipairs(tools) do
      ngx.say(v.name)
      ngx.say(v.description)
    end
    ngx.say(tostring(client.server.discovered_tools == tools))
    local res = assert(client:call_tool("echo", {message = "Hello, world!"}))
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    local res = assert(client:call_tool("enable_echo"))
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    ngx.say(tostring(client.server.discovered_tools == tools))
    local res = assert(client:call_tool("disable_echo"))
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    ngx.say(tostring(client.server.discovered_tools == tools))
    local tools = assert(client:list_tools())
    ngx.say(tostring(client.server.discovered_tools == tools))
    for i, v in ipairs(tools) do
      ngx.say(v.name)
      ngx.say(v.description)
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
disable_echo
Disables the echo tool.
client_info
Query the client information.
true
nil
test_tools
MCP Tools
1.0_alpha
nil
text 3
-32602 Unknown tool {"name":"echo"}
tools/list_changed
nil
false
add
Adds two numbers.
enable_echo
Enables the echo tool.
disable_echo
Disables the echo tool.
client_info
Query the client information.
echo
Echoes back the input.
true
nil
text test_tools MCP Tools v1.0_alpha say: Hello, world!
true
text tool (name: echo) had been registered
true
tools/list_changed
nil
false
true
add
Adds two numbers.
enable_echo
Enables the echo tool.
disable_echo
Disables the echo tool.
client_info
Query the client information.
--- no_error_log
[error]


=== TEST 5: prompts
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/prompts.lua 2>> error.log"
    }))
    assert(client:initialize({
      event_handlers = {
        ["prompts/list_changed"] = function()
          ngx.say("prompts/list_changed")
        end
      }
    }))
    local prompts = assert(client:list_prompts())
    for i, v in ipairs(prompts) do
      ngx.say(v.name)
      ngx.say(v.title)
      ngx.say(v.description)
    end
    ngx.say(tostring(client.server.discovered_prompts == prompts))
    local res = assert(client:get_prompt("simple_prompt"))
    ngx.say(res.description)
    for i, v in ipairs(res.messages) do
      ngx.say(string.format("%s %s %s", v.role, v.content.type, v.content.text))
    end
    local res = assert(client:get_prompt("complex_prompt", {
      temperature = "0.4",
      style = "json"
    }))
    ngx.say(res.description)
    for i, v in ipairs(res.messages) do
      ngx.say(string.format("%s %s %s", v.role, v.content.type, v.content.text))
    end
    local _, err = client:get_prompt("mock_error")
    ngx.say(err)
    local res = assert(client:call_tool("enable_mock_error"))
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    ngx.say(tostring(client.server.discovered_prompts == prompts))
    local prompts = assert(client:list_prompts())
    for i, v in ipairs(prompts) do
      ngx.say(v.name)
      ngx.say(v.title)
      ngx.say(v.description)
    end
    ngx.say(tostring(client.server.discovered_prompts == prompts))
    local _, err = client:get_prompt("mock_error")
    ngx.say(err)
    local res = assert(client:call_tool("enable_mock_error"))
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    ngx.say(tostring(client.server.discovered_prompts == prompts))
    local res = assert(client:call_tool("disable_mock_error"))
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    ngx.say(tostring(client.server.discovered_prompts == prompts))
    local prompts = assert(client:list_prompts())
    ngx.say(tostring(client.server.discovered_prompts == prompts))
    for i, v in ipairs(prompts) do
      ngx.say(v.name)
      ngx.say(v.title)
      ngx.say(v.description)
    end
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
simple_prompt
Simple Prompt
A prompt without arguments.
complex_prompt
Complex Prompt
A prompt with arguments.
true
A prompt without arguments.
user text This is a simple prompt without arguments.
A prompt with arguments.
user text This is a complex prompt with arguments: temperature=0.4, style=json
assistant text Assistant reply: temperature=0.4, style=json
-32602 Invalid prompt name {"name":"mock_error"}
prompts/list_changed
nil
false
simple_prompt
Simple Prompt
A prompt without arguments.
complex_prompt
Complex Prompt
A prompt with arguments.
mock_error
Mock Error
Mock error message.
true
-32603 Internal errors {"errmsg":"mock error"}
true
text prompt (name: mock_error) had been registered
true
prompts/list_changed
nil
false
true
simple_prompt
Simple Prompt
A prompt without arguments.
complex_prompt
Complex Prompt
A prompt with arguments.
--- no_error_log
[error]


=== TEST 6: resources
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/resources.lua 2>> error.log"
    }))
    assert(client:initialize({
      event_handlers = {
        ["resources/list_changed"] = function()
          ngx.say("resources/list_changed")
        end
      }
    }))
    local resources = assert(client:list_resources())
    for i, v in ipairs(resources) do
      ngx.say(v.uri)
      ngx.say(v.name)
      ngx.say(v.title)
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
    local res = assert(client:call_tool("enable_hidden_resource"))
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    local res = assert(client:read_resource("mock://static/hidden"))
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(tostring(v.mimeType))
      ngx.say(tostring(v.text))
      ngx.say(v.blob and ngx.decode_base64(v.blob) or "nil")
    end
    ngx.say(tostring(client.server.discovered_resources == resources))
    local resources = assert(client:list_resources())
    for i, v in ipairs(resources) do
      ngx.say(v.uri)
      ngx.say(v.name)
      ngx.say(v.title)
      ngx.say(tostring(v.description))
      ngx.say(tostring(v.mimeType))
    end
    ngx.say(tostring(client.server.discovered_resources == resources))
    local templates = assert(client:list_resource_templates())
    ngx.say(tostring(client.server.discovered_resource_templates == templates))
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
    local res, err = client:read_resource("mock://dynamic/hidden/foobar")
    ngx.say(err)
    local res = assert(client:call_tool("enable_hidden_template"))
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    local res = assert(client:read_resource("mock://dynamic/hidden/foobar"))
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(tostring(v.mimeType))
      ngx.say(tostring(v.text))
      ngx.say(v.blob and ngx.decode_base64(v.blob) or "nil")
    end
    ngx.say(tostring(client.server.discovered_resource_templates == templates))
    local templates = assert(client:list_resource_templates())
    ngx.say(tostring(client.server.discovered_resource_templates == templates))
    for i, v in ipairs(templates) do
      ngx.say(v.uriTemplate)
      ngx.say(v.name)
      ngx.say(tostring(v.description))
      ngx.say(tostring(v.mimeType))
    end
    local res = assert(client:call_tool("touch_resource", {uri = "mock://static/text"}))
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
      local res = assert(client:call_tool("touch_resource", {uri = uri}))
      ngx.say(tostring(res.isError))
      for j, v in ipairs(res.content) do
        ngx.say(string.format("%s %s", v.type, v.text))
      end
    end
    assert(client:unsubscribe_resource(uris[1]))
    for i, uri in ipairs(uris) do
      local res = assert(client:call_tool("touch_resource", {uri = uri}))
      ngx.say(tostring(res.isError))
      for j, v in ipairs(res.content) do
        ngx.say(string.format("%s %s", v.type, v.text))
      end
    end
    ngx.say(tostring(client.server.discovered_resource_templates == templates))
    local res = assert(client:call_tool("disable_hidden_template"))
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    ngx.say(tostring(client.server.discovered_resource_templates == templates))
    local templates = assert(client:list_resource_templates())
    ngx.say(tostring(client.server.discovered_resource_templates == templates))
    for i, v in ipairs(templates) do
      ngx.say(v.uriTemplate)
      ngx.say(v.name)
      ngx.say(tostring(v.description))
      ngx.say(tostring(v.mimeType))
    end
    local resources = assert(client:list_resources())
    ngx.say(tostring(client.server.discovered_resources == resources))
    local res = assert(client:call_tool("disable_hidden_resource"))
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    ngx.say(tostring(client.server.discovered_resources == resources))
    local resources = assert(client:list_resources())
    ngx.say(tostring(client.server.discovered_resources == resources))
    for i, v in ipairs(resources) do
      ngx.say(v.uri)
      ngx.say(v.name)
      ngx.say(v.title)
      ngx.say(tostring(v.description))
      ngx.say(tostring(v.mimeType))
    end
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
mock://static/text
TextResource
Text Resource
Static text resource.
text/plain
mock://static/blob
BlobResource
Blob Resource
Static blob resource.
application/octet-stream
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
resources/list_changed
nil
mock://static/hidden
application/octet-stream
nil
content of hidden resource
false
mock://static/text
TextResource
Text Resource
Static text resource.
text/plain
mock://static/blob
BlobResource
Blob Resource
Static blob resource.
application/octet-stream
mock://static/hidden
HiddenResource
Hidden Resource
Hidden blob resource.
nil
true
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
-32002 Resource not found {"uri":"mock:\/\/dynamic\/hidden\/foobar"}
resources/list_changed
nil
mock://dynamic/hidden/foobar
text/plain
content of dynamic hidden resource mock://dynamic/hidden/foobar, id=foobar
nil
false
true
mock://dynamic/text/{id}
DynamicText
Dynamic text resource.
text/plain
mock://dynamic/blob/{id}
DynamicBlob
Dynamic blob resource.
application/octet-stream
mock://dynamic/hidden/{id}
DynamicHidden
Dynamic hidden resource.
text/plain
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
true
resources/list_changed
nil
false
true
mock://dynamic/text/{id}
DynamicText
Dynamic text resource.
text/plain
mock://dynamic/blob/{id}
DynamicBlob
Dynamic blob resource.
application/octet-stream
true
resources/list_changed
nil
false
true
mock://static/text
TextResource
Text Resource
Static text resource.
text/plain
mock://static/blob
BlobResource
Blob Resource
Static blob resource.
application/octet-stream
--- no_error_log
[error]


=== TEST 7: roots
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/roots.lua 2>> error.log"
    }))
    assert(client:initialize({
      roots = {
        {path = "/path/to/foo/bar", name = "Foobar"},
        {path = "/path/to/hello/world"}
      }
    }))
    local res = assert(client:read_resource("mock://client_capabilities"))
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(v.text)
    end
    local res = assert(client:read_resource("mock://discovered_roots"))
    ngx.say(#res.contents)
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(v.text)
    end
    local sema = assert(require("ngx.semaphore").new())
    local ok, err = client:subscribe_resource("mock://discovered_roots", function(uri, ctx)
      local res = assert(ctx.session:read_resource("mock://discovered_roots"))
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
    assert(client:expose_roots())
    assert(sema:wait(5))
    assert(client:expose_roots({
      {path = "/path/to/foo/bar"},
      {path = "/path/to/hello/world", name = "Hello, world!"}
    }))
    assert(sema:wait(5))
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
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/sampling.lua 2>> error.log"
    }))
    assert(client:initialize({
      sampling_callback = function(params)
        return "Hey there! What's up?"
      end
    }))
    local res = assert(client:read_resource("mock://client_capabilities"))
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(v.text)
    end
    local res = assert(client:get_prompt("simple_sampling"))
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
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/sampling.lua 2>> error.log"
    }))
    assert(client:initialize({
      sampling_callback = function(params)
        return {
          content = {
            type = "image",
            data = "SGV5LCBtYW4h",
            mimeType = "image/jpeg"
          },
          model = "mock"
        }
      end
    }))
    local res = assert(client:read_resource("mock://client_capabilities"))
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(v.text)
    end
    local res = assert(client:get_prompt("simple_sampling"))
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


=== TEST 10: progress
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/progress.lua 2>> error.log"
    }))
    assert(client:initialize({
      sampling_callback = function(params, ctx)
        for i, v in ipairs({0.25, 0.5, 1}) do
          assert(ctx.push_progress(v, 1, "sampling"))
        end
        return "Hey there! What's up?"
      end
    }))
    local res = assert(client:get_prompt("echo", {message = "Hello, MCP!"}, 180, function(progress, total, message)
      ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
      return true
    end))
    ngx.say(res.description)
    for i, v in ipairs(res.messages) do
      ngx.say(string.format("%s %s %s", v.role, v.content.type, v.content.text))
    end
    local res = assert(client:read_resource("echo://static", 180, function(progress, total, message)
      ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
      return true
    end))
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(tostring(v.mimeType))
      ngx.say(tostring(v.text))
    end
    local res = assert(client:read_resource("echo://foobar", 180, function(progress, total, message)
      ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
      return true
    end))
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(tostring(v.mimeType))
      ngx.say(tostring(v.text))
    end
    local res = assert(client:call_tool("echo", {message = "Hello, MCP!"}, 180, function(progress, total, message)
      ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
      return true
    end))
    ngx.say(tostring(res.isError))
    for i, v in ipairs(res.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    local res = assert(client:get_prompt("simple_sampling"))
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
progress=0.25, total=1, message=prompt
progress=0.5, total=1, message=prompt
progress=1, total=1, message=prompt
Create an echo prompt
user text Please process this message: Hello, MCP!
progress=0.25, total=1, message=resource
progress=0.5, total=1, message=resource
progress=1, total=1, message=resource
echo://static
text/plain
Resource echo: static
progress=0.25, total=1, message=resource_template
progress=0.5, total=1, message=resource_template
progress=1, total=1, message=resource_template
echo://foobar
text/plain
Resource echo: foobar
progress=0.25, total=1, message=tool
progress=0.5, total=1, message=tool
progress=1, total=1, message=tool
nil
text Tool echo: Hello, MCP!
Sampling prompt from client without arguments.
user text Hey, man! nil nil
assistant text progress=0.25, total=1, message=sampling nil nil
assistant text progress=0.5, total=1, message=sampling nil nil
assistant text progress=1, total=1, message=sampling nil nil
assistant text Hey there! What's up? nil unknown
--- no_error_log
[error]


=== TEST 11: cancellation
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/progress.lua 2>> error.log"
    }))
    assert(client:initialize({
      sampling_callback = function(params, ctx)
        for i, v in ipairs({0.25, 0.5, 1}) do
          local ok, err = ctx.push_progress(v, 1, "sampling")
          if not ok then
            return
          end
        end
        return "Hey there! What's up?"
      end
    }))
    local res, err = client:get_prompt("echo", {message = "Hello, MCP!"}, 180, function(progress, total, message)
      ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
      return nil, "test cancellation"
    end)
    ngx.say(tostring(err))
    local res, err = client:read_resource("echo://static", 180, function(progress, total, message)
      ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
      return nil, "test cancellation"
    end)
    ngx.say(tostring(err))
    local res, err = client:read_resource("echo://foobar", 180, function(progress, total, message)
      ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
      return nil, "test cancellation"
    end)
    ngx.say(tostring(err))
    local res, err = client:call_tool("echo", {message = "Hello, MCP!"}, 180, function(progress, total, message)
      ngx.say(string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message)))
      return nil, "test cancellation"
    end)
    ngx.say(tostring(err))
    local res, err = client:get_prompt("cancel_sampling")
    ngx.say(tostring(err))
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
progress=0.25, total=1, message=prompt
-1 Request cancelled {"reason":"test cancellation"}
progress=0.25, total=1, message=resource
-1 Request cancelled {"reason":"test cancellation"}
progress=0.25, total=1, message=resource_template
-1 Request cancelled {"reason":"test cancellation"}
progress=0.25, total=1, message=tool
-1 Request cancelled {"reason":"test cancellation"}
-32603 Internal errors {"errmsg":"-1 Request cancelled {\"reason\":\"test cancellation\"}"}
--- no_error_log
[error]


=== TEST 12: batch replacement APIs
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/batch_replace.lua 2>> error.log"
    }))
    assert(client:initialize({
      event_handlers = {
        ["prompts/list_changed"] = function()
          ngx.say("prompts/list_changed")
        end,
        ["resources/list_changed"] = function()
          ngx.say("resources/list_changed")
        end,
        ["tools/list_changed"] = function()
          ngx.say("tools/list_changed")
        end
      }
    }))
    local prompts = assert(client:list_prompts())
    ngx.say(#prompts)
    local res = assert(client:call_tool("batch_prompts"))
    ngx.say(tostring(res.isError))
    local prompts = assert(client:list_prompts())
    for i, v in ipairs(prompts) do
      ngx.say(v.name)
      local res = assert(client:get_prompt(v.name))
      ngx.say(res.messages[1].content.text)
    end
    local resources = assert(client:list_resources())
    ngx.say(#resources)
    local templates = assert(client:list_resource_templates())
    ngx.say(#templates)
    local res = assert(client:call_tool("batch_resources"))
    ngx.say(tostring(res.isError))
    local resources = assert(client:list_resources())
    for i, v in ipairs(resources) do
      ngx.say(v.uri)
      local res = assert(client:read_resource(v.uri))
      ngx.say(res.contents[1].text)
    end
    local templates = assert(client:list_resource_templates())
    for i, v in ipairs(templates) do
      ngx.say(v.uriTemplate)
      local res = assert(client:read_resource(string.format("mock://batch/dynamic_%d/foobar", i)))
      ngx.say(res.contents[1].text)
    end
    local tools = assert(client:list_tools())
    for i, v in ipairs(tools) do
      ngx.say(v.name)
    end
    local res = assert(client:call_tool("batch_tools"))
    ngx.say(tostring(res.isError))
    local tools = assert(client:list_tools())
    for i, v in ipairs(tools) do
      ngx.say(v.name)
      local res = assert(client:call_tool(v.name))
      ngx.say(res.content[1].text)
    end
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
0
prompts/list_changed
nil
batch_prompt_1
content of batch_prompt_1
batch_prompt_2
content of batch_prompt_2
0
0
resources/list_changed
nil
mock://batch/static_1
batch_static_1
mock://batch/static_2
batch_static_2
mock://batch/dynamic_1/{id}
batch_dynamic_1: foobar
mock://batch/dynamic_2/{id}
batch_dynamic_2: foobar
batch_prompts
batch_resources
batch_tools
tools/list_changed
nil
batch_tool_1
result of batch_tool_1
batch_tool_2
result of batch_tool_2
--- no_error_log
[error]


=== TEST 13: logging
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/logging.lua 2>> error.log"
    }))
    assert(client:initialize({
      event_handlers = {
        message = function(params)
          ngx.say(string.format("[%s] %s %s", params.level, params.data, tostring(params.logger)))
        end
      }
    }))
    local res = assert(client:call_tool("log_echo", {level = "error", data = "Foobar"}))
    ngx.say(tostring(res.isError))
    assert(client:set_log_level("warning"))
    local res = assert(client:call_tool("log_echo", {level = "error", data = "Foobar"}))
    ngx.say(tostring(res.isError))
    local res = assert(client:call_tool("log_echo", {level = "warning", data = "Hello, MCP!", logger = "mock"}))
    ngx.say(tostring(res.isError))
    local res = assert(client:call_tool("log_echo", {level = "notice", data = "Hello, MCP!", logger = "mock"}))
    ngx.say(tostring(res.isError))
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
nil
[error] Foobar nil
nil
[warning] Hello, MCP! mock
nil
nil
--- no_error_log
[error]


=== TEST 14: ping
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/ping.lua 2>> error.log"
    }))
    assert(client:initialize())
    assert(client:ping())
    local res = assert(client:call_tool("ping"))
    ngx.say(tostring(res.isError))
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
nil
--- no_error_log
[error]


=== TEST 15: completion
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/completion.lua 2>> error.log"
    }))
    assert(client:initialize())
    local res = assert(client:prompt_complete("simple_prompt", "foo", "bar"))
    ngx.say(#res.completion.values)
    ngx.say(tostring(res.completion.total))
    ngx.say(tostring(res.completion.hasMore))
    local res = assert(client:prompt_complete("complex_prompt", "temperature", "0"))
    ngx.say(#res.completion.values)
    ngx.say(tostring(res.completion.total))
    ngx.say(tostring(res.completion.hasMore))
    local res = assert(client:prompt_complete("complex_prompt", "style", ""))
    ngx.say(#res.completion.values)
    ngx.say(tostring(res.completion.total))
    ngx.say(tostring(res.completion.hasMore))
    local res = assert(client:prompt_complete("complex_prompt", "style", "a"))
    ngx.say(#res.completion.values)
    ngx.say(tostring(res.completion.total))
    ngx.say(tostring(res.completion.hasMore))
    local res = assert(client:resource_complete("mock://no_completion/text/{id}", "id", ""))
    ngx.say(#res.completion.values)
    ngx.say(tostring(res.completion.total))
    ngx.say(tostring(res.completion.hasMore))
    local res = assert(client:resource_complete("mock://dynamic/text/{id}", "id", ""))
    ngx.say(#res.completion.values)
    ngx.say(tostring(res.completion.total))
    ngx.say(tostring(res.completion.hasMore))
    local res = assert(client:resource_complete("mock://dynamic/text/{id}", "id", "a"))
    ngx.say(#res.completion.values)
    ngx.say(tostring(res.completion.total))
    ngx.say(tostring(res.completion.hasMore))
    local res = assert(client:prompt_complete("complex_prompt", "style", "", {style = "foobar"}))
    ngx.say(#res.completion.values)
    ngx.say(res.completion.values[1])
    ngx.say(tostring(res.completion.total))
    ngx.say(tostring(res.completion.hasMore))
    local res = assert(client:resource_complete("mock://dynamic/text/{id}", "id", "", {id = "foobar"}))
    ngx.say(#res.completion.values)
    ngx.say(res.completion.values[1])
    ngx.say(tostring(res.completion.total))
    ngx.say(tostring(res.completion.hasMore))
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
0
nil
nil
0
nil
nil
100
102
true
2
2
false
0
nil
nil
100
nil
true
2
nil
nil
1
foobar
nil
nil
1
foobar
nil
nil
--- no_error_log
[error]


=== TEST 16: elicitation
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client = assert(mcp.client(mcp.transport.stdio, {
      command = "/usr/local/openresty/bin/resty -I lib t/mock/elicitation.lua 2>> error.log"
    }))
    local round = 0
    assert(client:initialize({
      elicitation_callback = function(params)
        round = round + 1
        if round == 1 then
          return {text = "Hello, world!", seed = 42}
        elseif round == 2 then
          return {text = "Hello, world!"}
        end
      end
    }))
    local res = assert(client:read_resource("mock://client_capabilities"))
    for i, v in ipairs(res.contents) do
      ngx.say(v.uri)
      ngx.say(v.text)
    end
    local res = assert(client:call_tool("simple_elicit"))
    ngx.say(res.structuredContent.action)
    ngx.say(res.structuredContent.content.text)
    ngx.say(res.structuredContent.content.seed)
    local res = assert(client:call_tool("simple_elicit"))
    ngx.say(res.structuredContent.action)
    local res = assert(client:call_tool("simple_elicit"))
    ngx.say(res.structuredContent.action)
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
mock://client_capabilities/elicitation
true
accept
Hello, world!
42
cancel
decline
--- no_error_log
[error]
