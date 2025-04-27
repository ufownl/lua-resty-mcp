local mcp = require("resty.mcp")
local cjson = require("cjson")

local client, err = mcp.client(mcp.transport.stdio, {
  command = {"npx", "-y", "@modelcontextprotocol/server-everything"}
})
if not client then
  error(err)
end
local ok, err = client:initialize({
  sampling_callback = function(params)
    return "Mock sampling message!"
  end
})
if not ok then
  error(err)
end
print(ngx.localtime(), " initialized")
print("serverInfo: ", cjson.encode(client.server))

local resources, err = client:list_resources()
if not resources then
  error(err)
end
print("resources: ", cjson.encode(resources))

local resource_templates, err = client:list_resource_templates()
if not resource_templates then
  error(err)
end
print("resource templates: ", cjson.encode(resource_templates))

local resource, err = client:read_resource("test://static/resource/1")
if not resource then
  error(err)
end
print("resource text: ", cjson.encode(resource))

local resource, err = client:read_resource("test://static/resource/2")
if not resource then
  error(err)
end
print("resource blob: ", cjson.encode(resource))

local _, err = client:read_resource("foobar")
print("invalid resource: ", err)

local count = 0
local ok, err = client:subscribe_resource("test://static/resource/42", function(uri)
  print(string.format("%s updated!", uri))
  count = count + 1
  if count >= 3 then
    local ok, err = client:unsubscribe_resource("test://static/resource/42")
    if not ok then
      error(err)
    end
  end
end)
if not ok then
  error(err)
end

print("sleep 30 seconds")
ngx.sleep(30)
client:shutdown()
print(ngx.localtime(), " shutdown")
