local mcp = {
  transport = {
    stdio = require("resty.mcp.transport.stdio")
  },
  session = require("resty.mcp.session"),
  protocol = require("resty.mcp.protocol"),
  resource = require("resty.mcp.resource"),
  prompt = require("resty.mcp.prompt")
}

local conn, err = mcp.transport.stdio.new()
if not conn then
  error(err)
end
local sess, err = mcp.session.new(conn)
if not sess then
  error(err)
end

local available_resources = {}
local available_prompts = {}

local prompt = mcp.prompt.new("simple_sampling", function(args)
  local messages =  {
    {role = "user", content = {type = "text", text = "Hey, man!"}}
  }
  local res, err = sess:send_request("create_message", {messages, 128})
  if not res then
    return nil, err
  end
  table.insert(messages, res)
  return messages
end, "Sampling prompt from client without arguments.")
available_prompts[prompt.name] = prompt

sess:initialize({
  initialize = function(params)
    local resource = mcp.resource.new("mock://client_capabilities", "ClientCapabilities", function(uri)
      local contents = {}
      if params.capabilities.roots then
        table.insert(contents, {uri = uri.."/roots", text = "true"})
        if params.capabilities.roots.listChanged then
          table.insert(contents, {uri = uri.."/roots/listChanged", text = "true"})
        end
      end
      if params.capabilities.sampling then
        table.insert(contents, {uri = uri.."/sampling", text = "true"})
      end
      return contents
    end, "Capabilities of client.")
    available_resources[resource.uri] = resource
    return mcp.protocol.result.initialize({
      resources = {listChanged = false},
      prompts = true,
    })
  end,
  ["resources/list"] = function(params)
    local resources = {}
    for k, v in pairs(available_resources) do
      table.insert(resources, v)
    end
    return mcp.protocol.result.list("resources", resources)
  end,
  ["resources/read"] = function(params)
    local resource = available_resources[params.uri]
    if resource then
      return resource:read()
    end
    return nil, -32002, "Resource not found", {uri = params.uri}
  end,
  ["prompts/list"] = function(params)
    local prompts = {}
    for k, v in pairs(available_prompts) do
      table.insert(prompts, v)
    end
    return mcp.protocol.result.list("prompts", prompts)
  end,
  ["prompts/get"] = function(params)
    local prompt = available_prompts[params.name]
    if not prompt then
      return nil, -32602, "Invalid prompt name", {name = params.name}
    end
    return prompt:get(params.arguments)
  end
})
