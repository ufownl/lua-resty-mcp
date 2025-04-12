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
