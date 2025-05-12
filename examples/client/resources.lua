local mcp = require("resty.mcp")
local cjson = require("cjson")

local client = assert(mcp.client(mcp.transport.stdio, {
  command = {"npx", "-y", "@modelcontextprotocol/server-everything"}
}))
assert(client:initialize({
  sampling_callback = function(params)
    return "Mock sampling message!"
  end
}))
print(ngx.localtime(), " initialized")
print("serverInfo: ", cjson.encode(client.server))

local resources = assert(client:list_resources())
print("resources: ", cjson.encode(resources))

local resource_templates = assert(client:list_resource_templates())
print("resource templates: ", cjson.encode(resource_templates))

local resource = assert(client:read_resource("test://static/resource/1"))
print("resource text: ", cjson.encode(resource))

local resource= assert(client:read_resource("test://static/resource/2"))
print("resource blob: ", cjson.encode(resource))

local _, err = client:read_resource("foobar")
print("invalid resource: ", err)

local count = 0
assert(client:subscribe_resource("test://static/resource/42", function(uri)
  print(string.format("%s updated!", uri))
  count = count + 1
  if count >= 3 then
    local ok, err = client:unsubscribe_resource("test://static/resource/42")
    if not ok then
      error(err)
    end
  end
end))

print("sleep 30 seconds")
ngx.sleep(30)
client:shutdown()
print(ngx.localtime(), " shutdown")
