local mcp = require("resty.mcp")

local server = assert(mcp.server(mcp.transport.stdio))

assert(server:register(mcp.resource("mock://static/text", "TextResource", function(uri)
  return {
    {text = "Hello, world!"}
  }
end, {
  title = "Text Resource",
  description = "Static text resource.",
  mime = "text/plain"
})))

assert(server:register(mcp.resource("mock://static/blob", "BlobResource", function(uri)
  return {
    {blob = ngx.encode_base64("Hello, world!")}
  }
end, {
  title = "Blob Resource",
  description = "Static blob resource.",
  mime = "application/octet-stream"
})))

assert(server:register(mcp.resource_template("mock://dynamic/text/{id}", "DynamicText", function(uri, vars)
  if vars.id == "" then
    return false
  end
  return true, {
    {text = string.format("content of dynamic text resource %s, id=%s", uri, vars.id)},
  }
end, {
  title = "Dynamic Text",
  description = "Dynamic text resource.",
  mime = "text/plain"
})))

assert(server:register(mcp.resource_template("mock://dynamic/blob/{id}", "DynamicBlob", function(uri, vars)
  if vars.id == "" then
    return false
  end
  return true, {
    {blob = ngx.encode_base64(string.format("content of dynamic blob resource %s, id=%s", uri, vars.id))},
  }
end, {
  title = "Dynamic Blob",
  description = "Dynamic blob resource.",
  mime = "application/octet-stream"
})))

assert(server:register(mcp.tool("enable_hidden_resource", function(args, ctx)
  local ok, err = ctx.session:register(mcp.resource("mock://static/hidden", "HiddenResource", function(uri)
    return {
      {blob = ngx.encode_base64("content of hidden resource"), mimeType = "application/octet-stream"}
    }
  end, {title = "Hidden Resource", description = "Hidden blob resource."}))
  if not ok then
    return nil, err
  end
  return {}
end, {description = "Enable hidden resource."})))

assert(server:register(mcp.tool("disable_hidden_resource", function(args, ctx)
  local ok, err = ctx.session:unregister_resource("mock://static/hidden")
  if not ok then
    return nil, err
  end
  return {}
end, {description = "Disable hidden resource."})))

assert(server:register(mcp.tool("enable_hidden_template", function(args, ctx)
  local ok, err = ctx.session:register(mcp.resource_template("mock://dynamic/hidden/{id}", "DynamicHidden", function(uri, vars)
    if vars.id == "" then
      return false
    end
    return true, string.format("content of dynamic hidden resource %s, id=%s", uri, vars.id)
  end, {description = "Dynamic hidden resource.", mime = "text/plain"}))
  if not ok then
    return nil, err
  end
  return {}
end)))

assert(server:register(mcp.tool("disable_hidden_template", function(args, ctx)
  local ok, err = ctx.session:unregister_resource_template("mock://dynamic/hidden/{id}")
  if not ok then
    return nil, err
  end
  return {}
end)))

assert(server:register(mcp.tool("touch_resource", function(args, ctx)
  local ok, err = ctx.session:resource_updated(args.uri)
  if not ok then
    return nil, err
  end
  return {}
end, {
  description = "Trigger resource updated notification.",
  input_schema = {
    type = "object",
    properties = {
      uri = {
        type = "string",
        description = "URI of updated resource."
      }
    },
    required = {"uri"}
  }
})))

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
