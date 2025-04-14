local mcp = require("resty.mcp")

local server, err = mcp.server(mcp.transport.stdio)
if not server then
  error(err)
end

local ok, err = server:register(mcp.resource("mock://static/text", "TextResource", function(uri)
  return {
    {text = "Hello, world!"}
  }
end, "Static text resource.", "text/plain"))
if not ok then
  error(err)
end

local ok, err = server:register(mcp.resource("mock://static/blob", "BlobResource", function(uri)
  return {
    {blob = ngx.encode_base64("Hello, world!")}
  }
end, "Static blob resource.", "application/octet-stream"))
if not ok then
  error(err)
end

local ok, err = server:register(mcp.resource_template("mock://dynamic/text/{id}", "DynamicText", function(uri, vars)
  if vars.id == "" then
    return false
  end
  return true, {
    {text = string.format("content of dynamic text resource %s, id=%s", uri, vars.id)},
  }
end, "Dynamic text resource.", "text/plain"))
if not ok then
  error(err)
end

local ok, err = server:register(mcp.resource_template("mock://dynamic/blob/{id}", "DynamicBlob", function(uri, vars)
  if vars.id == "" then
    return false
  end
  return true, {
    {blob = ngx.encode_base64(string.format("content of dynamic blob resource %s, id=%s", uri, vars.id))},
  }
end, "Dynamic blob resource.", "application/octet-stream"))
if not ok then
  error(err)
end

local ok, err = server:register(mcp.tool("enable_hidden_resource", function(args, ctx)
  local ok, err = ctx.session:register(mcp.resource("mock://static/hidden", "HiddenResource", function(uri)
    return {
      {blob = ngx.encode_base64("content of hidden resource"), mimeType = "application/octet-stream"}
    }
  end, "Hidden blob resource."))
  if not ok then
    return nil, err
  end
  return {}
end, "Enable hidden resource."))
if not ok then
  error(err)
end

local ok, err = server:register(mcp.tool("touch_resource", function(args, ctx)
  local ok, err = ctx.session:resource_updated(args.uri)
  if not ok then
    return nil, err
  end
  return {}
end, "Trigger resource updated notification.", {
  type = "object",
  properties = {
    uri = {
      type = "string",
      description = "URI of updated resource."
    }
  },
  required = {"uri"}
}))

server:run({
  capabilities = {
    prompts = false,
    completions = false,
    logging = false
  },
  pagination = {
    resources = 1
  }
})
