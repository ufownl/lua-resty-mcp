use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: request with no params
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local rpc = require("resty.mcp.protocol.rpc")
    local req, rid, _ = rpc.request("foobar")
    local resp = rpc.handle(req, {
      foobar = function(params)
        return tostring(params)
      end
    })
    rpc.handle(resp, {}, function(id, result, errobj)
      ngx.say("rid: "..tostring(id == rid))
      ngx.say("result: "..result)
      ngx.say("error: "..tostring(errobj))
    end)
    local resp = rpc.handle(req, {})
    rpc.handle(resp, {}, function(id, result, errobj)
      ngx.say("rid: "..tostring(id == rid))
      ngx.say("result: "..tostring(result))
      ngx.say("code: "..errobj.code)
      ngx.say("message: "..errobj.message)
    end)
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
rid: true
result: nil
error: nil
rid: true
result: nil
code: -32601
message: Method not found


=== TEST 2: request with params
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local cjson = require("cjson")
    local rpc = require("resty.mcp.protocol.rpc")
    local req, rid, _ = rpc.request("foobar", {
      foo = 1
    })
    local resp = rpc.handle(req, {
      foobar = function(params)
        return cjson.encode(params)
      end
    })
    rpc.handle(resp, {}, function(id, result, errobj)
      ngx.say("rid: "..tostring(id == rid))
      ngx.say("result: "..result)
      ngx.say("error: "..tostring(errobj))
    end)
    local resp = rpc.handle(req, {})
    rpc.handle(resp, {}, function(id, result, errobj)
      ngx.say("rid: "..tostring(id == rid))
      ngx.say("result: "..tostring(result))
      ngx.say("code: "..errobj.code)
      ngx.say("message: "..errobj.message)
    end)
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
rid: true
result: {"foo":1}
error: nil
rid: true
result: nil
code: -32601
message: Method not found


=== TEST 3: notification with no params
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local rpc = require("resty.mcp.protocol.rpc")
    local ntf, _ = rpc.notification("foobar")
    local resp = rpc.handle(ntf, {
      foobar = function(params)
        ngx.say("notification: "..tostring(params))
      end
    })
    ngx.say("response: "..tostring(resp))
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
notification: nil
response: nil


=== TEST 4: notification with no params
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local cjson = require("cjson")
    local rpc = require("resty.mcp.protocol.rpc")
    local ntf, _ = rpc.notification("foobar", {
      foo = 1
    })
    local resp = rpc.handle(ntf, {
      foobar = function(params)
        ngx.say("notification: "..cjson.encode(params))
      end
    })
    ngx.say("response: "..tostring(resp))
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
notification: {"foo":1}
response: nil


=== TEST 5: batch messages
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local cjson = require("cjson")
    local rpc = require("resty.mcp.protocol.rpc")
    local req1, rid1, _ = rpc.request("foobar", {
      foo = 1
    })
    local ntf, _ = rpc.notification("foobar", {
      foo = 2
    })
    local req2, rid2, _ = rpc.request("foobar", {
      foo = 3
    })
    local resp = rpc.handle(rpc.batch({req1, ntf, req2}), {
      foobar = function(params)
        local res = cjson.encode(params)
        ngx.say("call foobar: "..res)
        return res
      end
    })
    rpc.handle(resp, {}, function(id, result, errobj)
      for i, v in ipairs({rid1, rid2}) do
        ngx.say("rid"..i..": "..tostring(id == v))
      end
      ngx.say("result: "..result)
      ngx.say("error: "..tostring(errobj))
    end)
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
call foobar: {"foo":1}
call foobar: {"foo":2}
call foobar: {"foo":3}
rid1: true
rid2: false
result: {"foo":1}
error: nil
rid1: false
rid2: true
result: {"foo":3}
error: nil


=== TEST 6: handle errors
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local cjson = require("cjson")
    local rpc = require("resty.mcp.protocol.rpc")
    local resp = rpc.handle('{"foo"', {})
    rpc.handle(resp, {}, function(id, result, errobj)
      ngx.say("rid: "..tostring(id == cjson.null))
      ngx.say("result: "..tostring(result))
      ngx.say("code: "..errobj.code)
      ngx.say("message: "..errobj.message)
    end)
    local resp = rpc.handle('123', {})
    rpc.handle(resp, {}, function(id, result, errobj)
      ngx.say("rid: "..tostring(id == cjson.null))
      ngx.say("result: "..tostring(result))
      ngx.say("code: "..errobj.code)
      ngx.say("message: "..errobj.message)
    end)
    local resp = rpc.handle('[1]', {})
    rpc.handle(resp, {}, function(id, result, errobj)
      ngx.say("rid: "..tostring(id == cjson.null))
      ngx.say("result: "..tostring(result))
      ngx.say("code: "..errobj.code)
      ngx.say("message: "..errobj.message)
    end)
    local resp = rpc.handle('[1,2]', {})
    rpc.handle(resp, {}, function(id, result, errobj)
      ngx.say("rid: "..tostring(id == cjson.null))
      ngx.say("result: "..tostring(result))
      ngx.say("code: "..errobj.code)
      ngx.say("message: "..errobj.message)
    end)
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
rid: true
result: nil
code: -32700
message: Parse error
rid: true
result: nil
code: -32600
message: Invalid Request
rid: true
result: nil
code: -32600
message: Invalid Request
rid: true
result: nil
code: -32600
message: Invalid Request
rid: true
result: nil
code: -32600
message: Invalid Request
