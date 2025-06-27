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
    local pt = prompt.new("foobar", function(args)
      local text = ""
      if args.a then
        text = text..string.format("a=%s\n", args.a)
      end
      text = text..string.format("b=%s", args.b)
      if args.c then
        text = text..string.format("\nc=%s", args.c)
      end
      return text
    end, {
      title = "Foobar",
      description = "Demo prompt definition and getting.",
      arguments = {
        a = {
          title = "AAA",
          description = "First argument?"
        },
        b = {
          description = "Second argument?",
          required = true
        },
        c = {}
      }
    })
    local decl = pt:to_mcp()
    ngx.say(decl.name)
    ngx.say(decl.title)
    ngx.say(decl.description)
    for i, v in ipairs(decl.arguments) do
      ngx.say(v.name)
      ngx.say(tostring(v.title))
      ngx.say(tostring(v.description))
      ngx.say(tostring(v.required))
    end
    local result, code, message, data = pt:get({a = "foo", b = "bar", c = "foobar"})
    if not result then
      error(string.format("%d %s", code, message))
    end
    ngx.say(result.description)
    for i, v in ipairs(result.messages) do
      ngx.say(v.role)
      ngx.say(v.content.type)
      ngx.say(v.content.text)
    end
    local result, code, message, data = pt:get({b = "bar", c = "foobar"})
    if not result then
      error(string.format("%d %s", code, message))
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
Foobar
Demo prompt definition and getting.
b
nil
Second argument?
true
a
AAA
First argument?
nil
c
nil
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
--- no_error_log
[error]


=== TEST 2: multi-turns prompt definition and getting
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local prompt = require("resty.mcp.prompt")
    local pt = prompt.new("foobar", function(args)
      local n = tonumber(args.n) or 1
      local messages = {}
      for i = 1, n do
        table.insert(messages, {
          role = i % 2 == 0 and "assistant" or "user",
          content = {
            type = "text",
            text = "Turn: "..i
          }
        })
      end
      return messages
    end, {
      description = "Demo multi-turns prompt.",
      arguments = {
        n = {required = true}
      }
    })
    local result, code, message, data = pt:get({n = "3"})
    if not result then
      error(string.format("%d %s", code, message))
    end
    ngx.say(result.description)
    for i, v in ipairs(result.messages) do
      ngx.say(v.role)
      ngx.say(v.content.type)
      ngx.say(v.content.text)
    end
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
Demo multi-turns prompt.
user
text
Turn: 1
assistant
text
Turn: 2
user
text
Turn: 3
--- no_error_log
[error]


=== TEST 3: handle errors return by callback
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local prompt = require("resty.mcp.prompt")
    local pt = prompt.new("foobar", function(args)
      return nil, "mock error"
    end, {description = "Demo handling errors return by callback."})
    local _, code, message, data = pt:get()
    ngx.say(string.format("%d %s %s", code, message, data.errmsg))
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
-32603 Internal errors mock error
--- no_error_log
[error]
