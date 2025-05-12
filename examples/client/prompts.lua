local mcp = require("resty.mcp")
local cjson = require("cjson")

local client = assert(mcp.client(mcp.transport.stdio, {
  command = {"npx", "-y", "@modelcontextprotocol/server-everything"}
}))
assert(client:initialize())
print(ngx.localtime(), " initialized")
print("serverInfo: ", cjson.encode(client.server))

local prompts = assert(client:list_prompts())
print("prompts: ", cjson.encode(prompts))

local prompt = assert(client:get_prompt("simple_prompt"))
print("simple prompt: ", cjson.encode(prompt))

local prompt = assert(client:get_prompt("complex_prompt", {temperature = "0.4", style = "json"}))
print("complex prompt: ", cjson.encode(prompt))

local _, err = client:get_prompt("foobar")
print("invalid prompt: ", err)

client:shutdown()
print(ngx.localtime(), " shutdown")
