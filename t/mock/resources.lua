local mcp = {
  transport = {
    stdio = require("resty.mcp.transport.stdio")
  },
  session = require("resty.mcp.session"),
  protocol = require("resty.mcp.protocol"),
  resource = require("resty.mcp.resource"),
  resource_template = require("resty.mcp.resource_template"),
  tool = require("resty.mcp.tool")
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

local resource = mcp.resource.new("mock://static/text", "TextResource", function(uri)
  return {
    {text = "Hello, world!"}
  }
end, "Static text resource.", "text/plain")
available_resources[resource.uri] = resource

local resource = mcp.resource.new("mock://static/blob", "BlobResource", function(uri)
  return {
    {blob = ngx.encode_base64("Hello, world!")}
  }
end, "Static blob resource.", "application/octet-stream")
available_resources[resource.uri] = resource

local enable_hidden_resource = mcp.tool.new("enable_hidden_resource", function(args)
  if available_resources.hidden_resource then
    return {
      {type = "text", text = "Hidden resource has been enabled!"}
    }, true
  end
  local resource = mcp.resource.new("mock://static/hidden", "HiddenResource", function(uri)
    return {
      {blob = ngx.encode_base64("content of hidden resource"), mimeType = "application/octet-stream"}
    }
  end, "Hidden blob resource.")
  available_resources[resource.uri] = resource
  local ok, err = sess:send_notification("list_changed", {"resources"})
  if not ok then
    return {
      {type = "text", text = err}
    }, true
  end
  return {}
end, "Enable hidden resource.")

local available_templates = {
  mcp.resource_template.new("mock://dynamic/text/{id}", "DynamicText", function(uri, vars)
    if vars.id == "" then
      return false
    end
    return true, {
      {text = string.format("content of dynamic text resource %s, id=%s", uri, vars.id)},
    }
  end, "Dynamic text resource.", "text/plain"),
  mcp.resource_template.new("mock://dynamic/blob/{id}", "DynamicBlob", function(uri, vars)
    if vars.id == "" then
      return false
    end
    return true, {
      {blob = ngx.encode_base64(string.format("content of dynamic blob resource %s, id=%s", uri, vars.id))},
    }
  end, "Dynamic blob resource.", "application/octet-stream")
}

sess:initialize({
  initialize = function(params)
    return mcp.protocol.result.initialize({
      resources = true,
      tools = {listChanged = false}
    })
  end,
  ["resources/list"] = function(params)
    local resources = {}
    for k, v in pairs(available_resources) do
      table.insert(resources, v)
    end
    table.sort(resources, function(a, b)
      return a.uri < b.uri
    end)
    local idx = tonumber(params.cursor) or 1
    return mcp.protocol.result.list("resources", {resources[idx]}, idx < #resources and tostring(idx + 1) or nil)
  end,
  ["resources/templates/list"] = function(params)
    local idx = tonumber(params.cursor) or 1
    return mcp.protocol.result.list("resourceTemplates", {available_templates[idx]}, idx < #available_templates and tostring(idx + 1) or nil)
  end,
  ["resources/read"] = function(params)
    local resource = available_resources[params.uri]
    if resource then
      return resource:read()
    end
    for i, template in ipairs(available_templates) do
      local result, code, message, data = template:read(params.uri)
      if result then
        return result
      end
      if code ~= -32002 then
        return nil, code, message, data
      end
    end
    return nil, -32002, "Resource not found", {uri = params.uri}
  end,
  ["tools/list"] = function(params)
    return mcp.protocol.result.list("tools", {enable_hidden_resource})
  end,
  ["tools/call"] = function(params)
    if params.name ~= "enable_hidden_resource" then
      return nil, -32602, "Unknown tool", {name = params.name}
    end
    return enable_hidden_resource(params.arguments)
  end
})
