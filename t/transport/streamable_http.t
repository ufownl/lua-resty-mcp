use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: server
--- http_config
lua_package_path 'lib/?.lua;;';
lua_shared_dict mcp_message_bus 64m;
--- config
location = /t {
  content_by_lua_block {
    local cjson = require("cjson")
    local message_bus = require("resty.mcp.transport.streamable_http.message_bus.builtin").new()
    local streamable_http = require("resty.mcp.transport.streamable_http")
    local session_id = message_bus:new_session()
    local conn = streamable_http.server({session_id = session_id})
    ngx.thread.spawn(function()
      local data, err = conn:recv()
      if not data then
        error(err)
      end
      ngx.say(data)
      local ok, err = conn:send({method = "hello"})
      if not ok then
        error(err)
      end
      local ok, err = conn:send({method = "progress_1"}, {related_request = 1})
      if not ok then
        error(err)
      end
      local ok, err = conn:send({
        {method = "progress_2"},
        {method = "request_related_2"},
      }, {related_request = 2})
      if not ok then
        error(err)
      end
      local ok, err = conn:send({
        {id = 1, result = "foo"},
        {method = "test"},
        {id = 2, result = "bar"}
      })
      if not ok then
        error(err)
      end
    end)
    local ok, err = message_bus:push_smsg(session_id, "Hello, Streamable HTTP!")
    if not ok then
      error(err)
    end
    local n = 5
    while n > 0 do
      local msgs, err = message_bus:pop_cmsgs(session_id, {"get", "1", "2"})
      if not msgs then
        error(err)
      end
      for i, msg in ipairs(msgs) do
        local dm = cjson.decode(msg.data)
        if #dm > 0 then
          ngx.say("batch:")
          for j, v in ipairs(dm) do
            ngx.say(string.format("  id=%s, method=%s, result=%s", tostring(v.id), tostring(v.method), tostring(v.result)))
          end
        else
          ngx.say(string.format("id=%s, method=%s, result=%s", tostring(dm.id), tostring(dm.method), tostring(dm.result)))
        end
      end
      n = n - #msgs
    end
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
Hello, Streamable HTTP!
id=nil, method=hello, result=nil
id=nil, method=test, result=nil
id=nil, method=progress_1, result=nil
id=1, method=nil, result=foo
batch:
  id=nil, method=progress_2, result=nil
  id=nil, method=request_related_2, result=nil
id=2, method=nil, result=bar
--- no_error_log
[error]
