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
      return args.format and string.format(args.format, r) or r
    end, {
      title = "Add Tool",
      description = "Adds two numbers.",
      input_schema = {
        type = "object",
        properties = {
          a = {type = "number"},
          b = {type = "number"},
          format = {
            type = "string",
            description = "Result format string."
          }
        },
        required = {"a", "b"}
      },
      annotations = {
        title = "Mock Tool Annotations",
        readOnlyHint = false,
        destructiveHint = true,
        idempotentHint = false,
        openWorldHint = true
      }
    })
    local decl = fn:to_mcp()
    ngx.say(decl.name)
    ngx.say(decl.title)
    ngx.say(decl.description)
    table.sort(decl.inputSchema.required)
    for i, v in ipairs(decl.inputSchema.required) do
      ngx.say(string.format("%d %s", i, v))
    end
    local props = {}
    for k, v in pairs(decl.inputSchema.properties) do
      table.insert(props, k.." "..v.type..(v.description and " "..v.description or ""))
    end
    table.sort(props)
    for i, v in ipairs(props) do
      ngx.say(v)
    end
    ngx.say(decl.annotations.title)
    ngx.say(tostring(decl.annotations.readOnlyHint))
    ngx.say(tostring(decl.annotations.destructiveHint))
    ngx.say(tostring(decl.annotations.idempotentHint))
    ngx.say(tostring(decl.annotations.openWorldHint))
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
    ngx.say(string.format("%d %s", code, message))
    local _, code, message, data = fn({b = 2})
    ngx.say(string.format("%d %s", code, message))
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
add
Add Tool
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
nil
text 3
nil
text result=3
-32602 Invalid arguments
-32602 Invalid arguments
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
        return nil, "ERROR: divisor cannot be 0!"
      end
      return args.a / args.b
    end, {
      description = "Calculate `a` divided by `b`.",
      input_schema = {
        type = "object",
        properties = {
          a = {type = "number"},
          b = {type = "number"}
        },
        required = {"a", "b"}
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
nil
text 0.5
true
text ERROR: divisor cannot be 0!
--- no_error_log
[error]


=== TEST 3: multi-content tool definition and calling
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local tool = require("resty.mcp.tool")
    local fn = tool.new("multi_content", function(args)
      local result = {
        {type = "text", text = "text content"},
        {type = "image", data = ngx.encode_base64("image content"), mimeType = "image/png"},
        {type = "audio", data = ngx.encode_base64("audio content"), mimeType = "audio/mpeg"},
        {type = "resource", resource = {uri = "mock://multi-content/resource/text", text = "text resource content"}},
        {type = "resource", resource = {uri = "mock://multi-content/resource/blob", blob = ngx.encode_base64("blob resource content"), mimeType = "application/octet-stream"}}
      }
      if args.is_error then
        return nil, result
      end
      return result
    end, {
      description = "Return multi-content.",
      input_schema = {
        type = "object",
        properties = {
          is_error = {type = "boolean"}
        }
      }
    })
    local result, code, message, data = fn({})
    if not result then
      error(string.format("%d %s", code, message))
    end
    ngx.say(tostring(result.isError))
    for i, v in ipairs(result.content) do
      ngx.say(v.type)
      if v.type == "text" then
        ngx.say(v.text)
        ngx.say(tostring(v.mimeType))
      elseif v.type == "resource" then
        ngx.say(v.resource.uri)
        ngx.say(v.resource.text or v.resource.blob and ngx.decode_base64(v.resource.blob))
        ngx.say(tostring(v.resource.mimeType))
      else
        ngx.say(ngx.decode_base64(v.data))
        ngx.say(tostring(v.mimeType))
      end
    end
    local result, code, message, data = fn({is_error = true})
    if not result then
      error(string.format("%d %s", code, message))
    end
    ngx.say(tostring(result.isError))
    for i, v in ipairs(result.content) do
      ngx.say(v.type)
      if v.type == "text" then
        ngx.say(v.text)
        ngx.say(tostring(v.mimeType))
      elseif v.type == "resource" then
        ngx.say(v.resource.uri)
        ngx.say(v.resource.text or v.resource.blob and ngx.decode_base64(v.resource.blob))
        ngx.say(tostring(v.resource.mimeType))
      else
        ngx.say(ngx.decode_base64(v.data))
        ngx.say(tostring(v.mimeType))
      end
    end
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
nil
text
text content
nil
image
image content
image/png
audio
audio content
audio/mpeg
resource
mock://multi-content/resource/text
text resource content
nil
resource
mock://multi-content/resource/blob
blob resource content
application/octet-stream
true
text
text content
nil
image
image content
image/png
audio
audio content
audio/mpeg
resource
mock://multi-content/resource/text
text resource content
nil
resource
mock://multi-content/resource/blob
blob resource content
application/octet-stream
--- no_error_log
[error]


=== TEST 4: structured-content tool definition and calling
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local cjson = require("cjson")
    local tool = require("resty.mcp.tool")
    local fn = tool.new("structured_content", function(args)
      return args
    end, {
      description = "Return structured-content.",
      output_schema = {
        type = "object",
        properties = {
          foo = {type = "string"},
          bar = {type = "integer"}
        },
        required = {"foo"}
      }
    })
    local ok, _ = pcall(fn, {})
    ngx.say(ok)
    local ok, _ = pcall(fn, {foo = 1})
    ngx.say(ok)
    local ok, _ = pcall(fn, {foo = "Hello, world!", bar = "Foobar"})
    ngx.say(ok)
    local res = fn({foo = "Hello, world!", bar = 0})
    ngx.say(res.structuredContent.foo)
    ngx.say(res.structuredContent.bar)
    ngx.say(#res.content)
    ngx.say(res.content[1].type)
    local content = cjson.decode(res.content[1].text)
    ngx.say(content.foo)
    ngx.say(content.bar)
    local fn = tool.new("unstructured_content", function(args)
      return args
    end, {description = "Return unstructured-content."})
    local ok, _ = pcall(fn, {foo = "Hello, world!", bar = 0})
    ngx.say(ok)
    local res = fn({})
    ngx.say(res.structuredContent)
    ngx.say(#res.content)
    local fn = tool.new("another_structured_content", function(args)
      return args
    end, {
      description = "Return structured-content.",
      output_schema = {type = "object"}
    })
    local res = fn({})
    ngx.say(type(res.structuredContent))
    ngx.say(#res.content)
    ngx.say(res.content[1].type)
    ngx.say(res.content[1].text)
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
false
false
false
Hello, world!
0
1
text
Hello, world!
0
false
nil
0
table
1
text
{}
--- no_error_log
[error]
