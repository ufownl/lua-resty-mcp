use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: prompt definition and getting
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local prompt = require("resty.mcp.prompt")
    local pt = prompt.new("foobar", "Demo prompt definition and getting.", {
      a = {
        description = "First argument?"
      },
      b = {
        description = "Second argument?",
        required = true
      },
      c = {}
    }, function(args)
      local text = ""
      if args.a then
        text = text..string.format("a=%s\n", args.a)
      end
      text = text..string.format("b=%s", args.b)
      if args.c then
        text = text..string.format("\nc=%s", args.c)
      end
      return {
        {role = "user", content = {type = "text", text = text}}
      }
    end)
    local schema = pt:to_mcp()
    ngx.say(schema.name)
    ngx.say(schema.description)
    for i, v in ipairs(schema.arguments) do
      ngx.say(v.name)
      ngx.say(tostring(v.description))
      ngx.say(tostring(v.required))
    end
    local result, code, message, data = pt:get({a = "foo", b = "bar", c = "foobar"})
    if not result then
      error(string.format("%d %s %s", code, message))
    end
    ngx.say(result.description)
    for i, v in ipairs(result.messages) do
      ngx.say(v.role)
      ngx.say(v.content.type)
      ngx.say(v.content.text)
    end
    local result, code, message, data = pt:get({b = "bar", c = "foobar"})
    if not result then
      error(string.format("%d %s %s", code, message))
    end
    ngx.say(result.description)
    for i, v in ipairs(result.messages) do
      ngx.say(v.role)
      ngx.say(v.content.type)
      ngx.say(v.content.text)
    end
    local _, code, message, data = pt:get({b = 1, c = "foobar"})
    ngx.say(string.format("%d %s %s %s %s", code, message, data.argument, data.expected, data.actual))
    local _, code, message, data = pt:get({c = "foobar"})
    ngx.say(string.format("%d %s %s %s %s", code, message, data.argument, data.expected, tostring(data.required)))
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
foobar
Demo prompt definition and getting.
b
Second argument?
true
a
First argument?
nil
c
nil
nil
Demo prompt definition and getting.
user
text
a=foo
b=bar
c=foobar
Demo prompt definition and getting.
user
text
b=bar
c=foobar
-32602 Invalid arguments b string number
-32602 Missing required arguments b string true


=== TEST 2: handle errors return by callback
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local prompt = require("resty.mcp.prompt")
    local pt = prompt.new("foobar", "Demo handling errors return by callback.", nil, function(args)
      return nil, "mock error"
    end)
    local _, code, message, data = pt:get()
    ngx.say(string.format("%d %s %s", code, message, data.errmsg))
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
-32603 Internal errors mock error
