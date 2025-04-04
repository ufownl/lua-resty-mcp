local mcp = require("resty.mcp")
local cjson = require("cjson")

local client, err = mcp.client(mcp.transport.stdio, {
  command = {"npx", "-y", "@modelcontextprotocol/server-everything"}
})
if not client then
  error(err)
end
local ok, err = client:initialize()
if not ok then
  error(err)
end
print(ngx.localtime(), " initialized")
print("serverInfo: ", cjson.encode(client.server))

local prompts, err = client:list_prompts()
if not prompts then
  error(err)
end
print("prompts: ", cjson.encode(prompts))

local prompt, err = client:get_prompt("simple_prompt")
if not prompt then
  error(err)
end
print("simple prompt: ", cjson.encode(prompt))

local prompt, err = client:get_prompt("complex_prompt", {temperature = "0.4", style = "json"})
if not prompt then
  error(err)
end
print("complex prompt: ", cjson.encode(prompt))

local _, err = client:get_prompt("foobar")
print("invalid prompt: ", err)

client:shutdown()
print(ngx.localtime(), " shutdown")
