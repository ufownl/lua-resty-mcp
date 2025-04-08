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
      command = "resty -I lib t/mock/handshake.lua"
    })
    if not client then
      error(err)
    end
    local ok, err = client:initialize()
    if not ok then
      error(err)
    end
    client:shutdown()
    ngx.say("Hello, MCP!")
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
Hello, MCP!


=== TEST 2: handshake error
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "resty -I lib t/mock/empty.lua"
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


=== TEST 3: server has no capability
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "resty -I lib t/mock/handshake.lua"
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


=== TEST 4: tools
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "resty -I lib t/mock/tools.lua"
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
false
text 3
-32602 Unknown tool {"name":"echo"}
false
false
add
Adds two numbers.
echo
Echoes back the input.
enable_echo
Enables the echo tool.
true
false
text Hello, world!
true
text Echo tool has been enabled!


=== TEST 5: prompts
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "resty -I lib t/mock/prompts.lua"
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
    client:shutdown()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
complex_prompt
A prompt with arguments.
simple_prompt
A prompt without arguments.
true
A prompt without arguments.
user text This is a simple prompt without arguments.
A prompt with arguments.
user text This is a complex prompt with arguments: temperature=0.4, style=json
assistant text Assistant reply: temperature=0.4, style=json
-32602 Invalid prompt name {"name":"mock_error"}
false
false
complex_prompt
A prompt with arguments.
mock_error
Mock error message.
simple_prompt
A prompt without arguments.
true
-32603 Internal errors {"errmsg":"mock error"}


=== TEST 6: resources
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local client, err = mcp.client(mcp.transport.stdio, {
      command = "resty -I lib t/mock/resources.lua"
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
false
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
