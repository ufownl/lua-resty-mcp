use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: tool definition and calling
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local tool = require("resty.mcp.tool")
    local fn = tool.new("add", function(args)
      local r = args.a + args.b
      return {
        {type = "text", text = args.format and string.format(args.format, r) or tostring(r)}
      }
    end, "Adds two numbers.", {
      a = {
        type = "number",
        required = true
      },
      b = {
        type = "number",
        required = true
      },
      format = {
        type = "string",
        description = "Result format string."
      }
    }, {
      title = "Mock Tool Annotations",
      readOnlyHint = false,
      destructiveHint = true,
      idempotentHint = false,
      openWorldHint = true
    })
    local schema = fn:to_mcp()
    ngx.say(schema.name)
    ngx.say(schema.description)
    table.sort(schema.inputSchema.required)
    for i, v in ipairs(schema.inputSchema.required) do
      ngx.say(string.format("%d %s", i, v))
    end
    local props = {}
    for k, v in pairs(schema.inputSchema.properties) do
      table.insert(props, k.." "..v.type..(v.description and " "..v.description or ""))
    end
    table.sort(props)
    for i, v in ipairs(props) do
      ngx.say(v)
    end
    ngx.say(schema.annotations.title)
    ngx.say(tostring(schema.annotations.readOnlyHint))
    ngx.say(tostring(schema.annotations.destructiveHint))
    ngx.say(tostring(schema.annotations.idempotentHint))
    ngx.say(tostring(schema.annotations.openWorldHint))
    local result, code, message, data = fn({a = 1, b = 2})
    if not result then
      error(string.format("%d %s", code, message))
    end
    ngx.say(tostring(result.isError))
    for i, v in ipairs(result.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    local result, code, message, data = fn({a = 1, b = 2, format = "result=%d"})
    if not result then
      error(string.format("%d %s", code, message))
    end
    ngx.say(tostring(result.isError))
    for i, v in ipairs(result.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    local _, code, message, data = fn({a = 1, b = 2, format = 1})
    ngx.say(string.format("%d %s %s %s %s", code, message, data.argument, data.expected, data.actual))
    local _, code, message, data = fn({b = 2})
    ngx.say(string.format("%d %s %s %s %s", code, message, data.argument, data.expected, tostring(data.required)))
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
add
Adds two numbers.
1 a
2 b
a number
b number
format string Result format string.
Mock Tool Annotations
false
true
false
true
false
text 3
false
text result=3
-32602 Invalid arguments format string number
-32602 Missing required arguments a number true
--- no_error_log
[error]


=== TEST 2: handle tool execution errors
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local tool = require("resty.mcp.tool")
    local fn = tool.new("div", function(args)
      if args.b == 0 then
        return {
          {type = "text", text = "ERROR: divisor cannot be 0!"}
        }, true
      end
      return {
        {type = "text", text = tostring(args.a / args.b)}
      }
    end, "Calculate `a` divided by `b`.", {
      a = {
        type = "number",
        required = true
      },
      b = {
        type = "number",
        required = true
      }
    })
    local result, code, message, data = fn({a = 1, b = 2})
    if not result then
      error(string.format("%d %s", code, message))
    end
    ngx.say(tostring(result.isError))
    for i, v in ipairs(result.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
    local result, code, message, data = fn({a = 1, b = 0})
    if not result then
      error(string.format("%d %s", code, message))
    end
    ngx.say(tostring(result.isError))
    for i, v in ipairs(result.content) do
      ngx.say(string.format("%s %s", v.type, v.text))
    end
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
false
text 0.5
true
text ERROR: divisor cannot be 0!
--- no_error_log
[error]
