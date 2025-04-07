use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== Level 1
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local ctx = {
      var = "value",
      hello = "Hello World!"
    }
    local function test_case(case)
      local utils = require("resty.mcp.utils")
      local t, err = utils.uri_template(case)
      if not t then
        error(err)
      end
      ngx.say(t:expand(ctx))
    end
    test_case("{var}")
    test_case("{hello}")
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
value
Hello%20World%21


=== Level 2
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local ctx = {
      var = "value",
      hello = "Hello World!",
      path = "/foo/bar"
    }
    local function test_case(case)
      local utils = require("resty.mcp.utils")
      local t, err = utils.uri_template(case)
      if not t then
        error(err)
      end
      ngx.say(t:expand(ctx))
    end
    test_case("{+var}")
    test_case("{+hello}")
    test_case("{+path}/here")
    test_case("here?ref={+path}")
    test_case("X{#var}")
    test_case("X{#hello}")
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
value
Hello%20World!
/foo/bar/here
here?ref=/foo/bar
X#value
X#Hello%20World!


=== Level 3
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local ctx = {
      var = "value",
      hello = "Hello World!",
      empty = "",
      path = "/foo/bar",
      x = "1024",
      y = "768"
    }
    local function test_case(case)
      local utils = require("resty.mcp.utils")
      local t, err = utils.uri_template(case)
      if not t then
        error(err)
      end
      ngx.say(t:expand(ctx))
    end
    test_case("map?{x,y}")
    test_case("{x,hello,y}")
    test_case("{+x,hello,y}")
    test_case("{+path,x}/here")
    test_case("{#x,hello,y}")
    test_case("{#path,x}/here")
    test_case("X{.var}")
    test_case("X{.x,y}")
    test_case("{/var}")
    test_case("{/var,x}/here")
    test_case("{;x,y}")
    test_case("{;x,y,empty}")
    test_case("{?x,y}")
    test_case("{?x,y,empty}")
    test_case("?fixed=yes{&x}")
    test_case("{&x,y,empty}")
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
map?1024,768
1024,Hello%20World%21,768
1024,Hello%20World!,768
/foo/bar,1024/here
#1024,Hello%20World!,768
#/foo/bar,1024/here
X.value
X.1024.768
/value
/value/1024/here
;x=1024;y=768
;x=1024;y=768;empty
?x=1024&y=768
?x=1024&y=768&empty=
?fixed=yes&x=1024
&x=1024&y=768&empty=


=== Level 4
--- http_config
lua_package_path 'lib/?.lua;;';
--- config
location = /t {
  content_by_lua_block {
    local ctx = {
      var = "value",
      hello = "Hello World!",
      path = "/foo/bar",
      list = {"red", "green", "blue"},
      keys = {semi = ";", dot = ".", comma = ","}
    }
    local function test_case(case, reorder, prefix)
      local utils = require("resty.mcp.utils")
      local t, err = utils.uri_template(case)
      if not t then
        error(err)
      end
      local out = t:expand(ctx)
      if reorder then
        local prefix = #out
        local sep
        for i, v in ipairs(reorder) do
          local from, to = string.find(out, v, 1, true)
          if not from then
            error("dismatch")
          end
          if from < prefix then
            prefix = from
          end
          if to < #out then
            sep = string.sub(out, to + 1, to + 1)
          end
        end
        local reordered_out = string.sub(out, 1, prefix - 1)..table.concat(reorder, sep)
        if #reordered_out ~= #out then
          error("dismatch")
        end
        ngx.say(reordered_out)
      else
        ngx.say(out)
      end
    end
    test_case("{var:3}")
    test_case("{var:30}")
    test_case("{list}")
    test_case("{list*}")
    test_case("{keys}", {"semi,%3B", "dot,.", "comma,%2C"})
    test_case("{keys*}", {"semi=%3B", "dot=.", "comma=%2C"})
    test_case("{+path:6}/here")
    test_case("{+list}")
    test_case("{+list*}")
    test_case("{+keys}", {"semi,;", "dot,.", "comma,,"})
    test_case("{+keys*}", {"semi=;", "dot=.", "comma=,"})
    test_case("{#path:6}/here")
    test_case("{#list}")
    test_case("{#list*}")
    test_case("{#keys}", {"semi,;", "dot,.", "comma,,"})
    test_case("{#keys*}", {"semi=;", "dot=.", "comma=,"})
    test_case("X{.var:3}")
    test_case("X{.list}")
    test_case("X{.list*}")
    test_case("X{.keys}", {"semi,%3B", "dot,.", "comma,%2C"})
    test_case("X{.keys*}", {"semi=%3B", "dot=.", "comma=%2C"})
    test_case("{/var:1,var}")
    test_case("{/list}")
    test_case("{/list*}")
    test_case("{/list*,path:4}")
    test_case("{/keys}", {"semi,%3B", "dot,.", "comma,%2C"})
    test_case("{/keys*}", {"semi=%3B", "dot=.", "comma=%2C"})
    test_case("{;hello:5}")
    test_case("{;list}")
    test_case("{;list*}")
    test_case("{;keys}", {"semi,%3B", "dot,.", "comma,%2C"})
    test_case("{;keys*}", {"semi=%3B", "dot=.", "comma=%2C"})
    test_case("{?var:3}")
    test_case("{?list}")
    test_case("{?list*}")
    test_case("{?keys}", {"semi,%3B", "dot,.", "comma,%2C"})
    test_case("{?keys*}", {"semi=%3B", "dot=.", "comma=%2C"})
    test_case("{&var:3}")
    test_case("{&list}")
    test_case("{&list*}")
    test_case("{&keys}", {"semi,%3B", "dot,.", "comma,%2C"})
    test_case("{&keys*}", {"semi=%3B", "dot=.", "comma=%2C"})
  }
}
--- request
GET /t
--- error_code: 200
--- response_body
val
value
red,green,blue
red,green,blue
semi,%3B,dot,.,comma,%2C
semi=%3B,dot=.,comma=%2C
/foo/b/here
red,green,blue
red,green,blue
semi,;,dot,.,comma,,
semi=;,dot=.,comma=,
#/foo/b/here
#red,green,blue
#red,green,blue
#semi,;,dot,.,comma,,
#semi=;,dot=.,comma=,
X.val
X.red,green,blue
X.red.green.blue
X.semi,%3B,dot,.,comma,%2C
X.semi=%3B.dot=..comma=%2C
/v/value
/red,green,blue
/red/green/blue
/red/green/blue/%2Ffoo
/semi,%3B,dot,.,comma,%2C
/semi=%3B/dot=./comma=%2C
;hello=Hello
;list=red,green,blue
;list=red;list=green;list=blue
;keys=semi,%3B,dot,.,comma,%2C
;semi=%3B;dot=.;comma=%2C
?var=val
?list=red,green,blue
?list=red&list=green&list=blue
?keys=semi,%3B,dot,.,comma,%2C
?semi=%3B&dot=.&comma=%2C
&var=val
&list=red,green,blue
&list=red&list=green&list=blue
&keys=semi,%3B,dot,.,comma,%2C
&semi=%3B&dot=.&comma=%2C
