use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: tools management
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local server, err = mcp.server(mcp.transport.stdio, {})
    ngx.say(tostring(server.available_tools))
    local function print_stats()
      for i, tool in ipairs(server.available_tools.list) do
        ngx.say(tool.name)
        local result, code, message, data = tool()
        if not result then
          error(string.format("%d %s", code, message))
        end
        for j, v in ipairs(result.content) do
          ngx.say(string.format("%s %s", v.type, v.text))
        end
      end
    end
    for i, v in ipairs({"foo", "bar", "hello"}) do
      local ok, err = server:register(mcp.tool(v, function(args)
        return {
          {type = "text", text = v}
        }
      end))
      if not ok then
        error(err)
      end
    end
    print_stats()
    local ok, err = server:register(mcp.tool("bar", function(args)
      return {
        {type = "text", text = "new bar"}
      }
    end))
    ngx.say(err)
    print_stats()
    local ok, err = server:unregister_tool("bar")
    if not ok then
      error(err)
    end
    print_stats()
    local ok, err = server:unregister_tool("bar")
    ngx.say(err)
    print_stats()
    local ok, err = server:register(mcp.tool("bar", function(args)
      return {
        {type = "text", text = "new bar"}
      }
    end))
    if not ok then
      error(err)
    end
    print_stats()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
nil
foo
text foo
bar
text bar
hello
text hello
tool (name: bar) had been registered
foo
text foo
bar
text bar
hello
text hello
foo
text foo
hello
text hello
tool (name: bar) is not registered
foo
text foo
hello
text hello
foo
text foo
hello
text hello
bar
text new bar
--- no_error_log
[error]


=== TEST 2: prompts management
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local server, err = mcp.server(mcp.transport.stdio, {})
    ngx.say(tostring(server.available_prompts))
    local function print_stats()
      for i, prompt in ipairs(server.available_prompts.list) do
        ngx.say(prompt.name)
        local result, code, message, data = prompt:get()
        if not result then
          error(string.format("%d %s", code, message))
        end
        for j, v in ipairs(result.messages) do
          ngx.say(string.format("%s %s %s", v.role, v.content.type, v.content.text))
        end
      end
    end
    for i, v in ipairs({"foo", "bar", "hello"}) do
      local ok, err = server:register(mcp.prompt(v, function(args)
        return {
          {role = "user", content = {type = "text", text = v}}
        }
      end))
      if not ok then
        error(err)
      end
    end
    print_stats()
    local ok, err = server:register(mcp.prompt("bar", function(args)
      return {
        {role = "assistant", content = {type = "text", text = "new bar"}}
      }
    end))
    ngx.say(err)
    print_stats()
    local ok, err = server:unregister_prompt("bar")
    if not ok then
      error(err)
    end
    print_stats()
    local ok, err = server:unregister_prompt("bar")
    ngx.say(err)
    print_stats()
    local ok, err = server:register(mcp.prompt("bar", function(args)
      return {
        {role = "assistant", content = {type = "text", text = "new bar"}}
      }
    end))
    if not ok then
      error(err)
    end
    print_stats()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
nil
foo
user text foo
bar
user text bar
hello
user text hello
prompt (name: bar) had been registered
foo
user text foo
bar
user text bar
hello
user text hello
foo
user text foo
hello
user text hello
prompt (name: bar) is not registered
foo
user text foo
hello
user text hello
foo
user text foo
hello
user text hello
bar
assistant text new bar
--- no_error_log
[error]


=== TEST 3: resources management
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local mcp = require("resty.mcp")
    local server, err = mcp.server(mcp.transport.stdio, {})
    ngx.say(tostring(server.available_resources))
    ngx.say(tostring(server.available_resource_templates))
    local function print_stats()
      for i, resource in ipairs(server.available_resources.list) do
        ngx.say(resource.uri)
        ngx.say(resource.name)
        local result, code, message, data = resource:read()
        if not result then
          error(string.format("%d %s", code, message))
        end
        for j, v in ipairs(result.contents) do
          ngx.say(string.format("%s %s %s", v.uri, tostring(v.mimeType), v.text))
        end
      end
      for i, resource_template in ipairs(server.available_resource_templates) do
        ngx.say(resource_template.uri_template.pattern)
        ngx.say(resource_template.name)
      end
    end
    for i, v in ipairs({"foo", "bar", "hello"}) do
      local ok, err = server:register(mcp.resource("static://"..v, v, function(uri)
        return {
          {text = "content of "..uri}
        }
      end))
      if not ok then
        error(err)
      end
      local ok, err = server:register(mcp.resource_template(string.format("dynamic://%s/{x}", v), v, function(uri, vars)
        return true, {
          {text = "dynamic content of "..uri}
        }
      end))
      if not ok then
        error(err)
      end
    end
    print_stats()
    local ok, err = server:register(mcp.resource("static://bar", "NewBar", function(uri)
      return {
        {text = "new content of "..uri, mimeType = "text/plain"}
      }
    end))
    ngx.say(err)
    local ok, err = server:register(mcp.resource_template("dynamic://bar/{x}", "NewBarTemplate", function(uri, vars)
      return true, {
        {text = "new dynamic content of "..uri}
      }
    end))
    ngx.say(err)
    print_stats()
    local ok, err = server:unregister_resource("static://bar")
    if not ok then
      error(err)
    end
    local ok, err = server:unregister_resource_template("dynamic://bar/{x}")
    if not ok then
      error(err)
    end
    print_stats()
    local ok, err = server:unregister_resource("static://bar")
    ngx.say(err)
    local ok, err = server:unregister_resource_template("dynamic://bar/{x}")
    ngx.say(err)
    print_stats()
    local ok, err = server:register(mcp.resource("static://bar", "NewBar", function(uri)
      return {
        {text = "new content of "..uri, mimeType = "text/plain"}
      }
    end))
    if not ok then
      error(err)
    end
    local ok, err = server:register(mcp.resource_template("dynamic://bar/{x}", "NewBarTemplate", function(uri, vars)
      return true, {
        {text = "new dynamic content of "..uri}
      }
    end))
    if not ok then
      error(err)
    end
    print_stats()
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
nil
nil
static://foo
foo
static://foo nil content of static://foo
static://bar
bar
static://bar nil content of static://bar
static://hello
hello
static://hello nil content of static://hello
dynamic://foo/{x}
foo
dynamic://bar/{x}
bar
dynamic://hello/{x}
hello
resource (uri: static://bar) had been registered
resource template (pattern: dynamic://bar/{x}) had been registered
static://foo
foo
static://foo nil content of static://foo
static://bar
bar
static://bar nil content of static://bar
static://hello
hello
static://hello nil content of static://hello
dynamic://foo/{x}
foo
dynamic://bar/{x}
bar
dynamic://hello/{x}
hello
static://foo
foo
static://foo nil content of static://foo
static://hello
hello
static://hello nil content of static://hello
dynamic://foo/{x}
foo
dynamic://hello/{x}
hello
resource (uri: static://bar) is not registered
resource template (pattern: dynamic://bar/{x}) is not registered
static://foo
foo
static://foo nil content of static://foo
static://hello
hello
static://hello nil content of static://hello
dynamic://foo/{x}
foo
dynamic://hello/{x}
hello
static://foo
foo
static://foo nil content of static://foo
static://hello
hello
static://hello nil content of static://hello
static://bar
NewBar
static://bar text/plain new content of static://bar
dynamic://foo/{x}
foo
dynamic://hello/{x}
hello
dynamic://bar/{x}
NewBarTemplate
--- no_error_log
[error]
