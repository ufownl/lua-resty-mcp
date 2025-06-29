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
    require("t.case").handshake(mcp, client)
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
    require("t.case").handshake_error(mcp, client)
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
    require("t.case").no_capability(mcp, client)
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
    require("t.case").tools(mcp, client)
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
add
Add Tool
Adds two numbers.
enable_echo
Enable Echo
Enables the echo tool.
disable_echo
Disable Echo
Disables the echo tool.
client_info
Client Info
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
Add Tool
Adds two numbers.
enable_echo
Enable Echo
Enables the echo tool.
disable_echo
Disable Echo
Disables the echo tool.
client_info
Client Info
Query the client information.
echo
Echo Tool
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
Add Tool
Adds two numbers.
enable_echo
Enable Echo
Enables the echo tool.
disable_echo
Disable Echo
Disables the echo tool.
client_info
Client Info
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
    require("t.case").prompts(mcp, client)
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
    require("t.case").resources(mcp, client)
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
Dynamic Text
Dynamic text resource.
text/plain
mock://dynamic/blob/{id}
DynamicBlob
Dynamic Blob
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
Dynamic Text
Dynamic text resource.
text/plain
mock://dynamic/blob/{id}
DynamicBlob
Dynamic Blob
Dynamic blob resource.
application/octet-stream
mock://dynamic/hidden/{id}
DynamicHidden
Dynamic Hidden
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
Dynamic Text
Dynamic text resource.
text/plain
mock://dynamic/blob/{id}
DynamicBlob
Dynamic Blob
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
    require("t.case").roots(mcp, client)
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
    require("t.case").sampling_string(mcp, client)
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
    require("t.case").sampling_struct(mcp, client)
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
    require("t.case").progress(mcp, client)
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
    require("t.case").cancellation(mcp, client)
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
true
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
    require("t.case").batch_replace(mcp, client)
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
    require("t.case").logging(mcp, client)
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
    require("t.case").ping(mcp, client)
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
    require("t.case").completion(mcp, client)
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
    require("t.case").elicitation(mcp, client)
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
