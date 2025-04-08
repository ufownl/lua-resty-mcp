local mcp = {
  version = require("resty.mcp.version"),
  rpc = require("resty.mcp.protocol.rpc")
}

local _M = {
  _NAME = "resty.mcp.protocol",
  _VERSION = mcp.version.module,
  request = {},
  notification = {},
  result = {}
}

function _M.request.initialize(capabilities, name)
  return mcp.rpc.request("initialize", {
    protocolVersion = mcp.version.protocol,
    capabilities = capabilities and {
      roots = capabilities.roots and (type(capabilities.roots) == "table" and capabilities.roots or {listChanged = true}) or nil,
      sampling = capabilities.sampling and {} or nil,
      experimental = capabilities.experimental
    } or {},
    clientInfo = {
      name = name or "lua-resty-mcp",
      version = mcp.version.module
    }
  })
end

function _M.request.list(category, cursor)
  return mcp.rpc.request(category.."/list", {cursor = cursor})
end

function _M.request.get_prompt(name, args)
  return mcp.rpc.request("prompts/get", {name = name, arguments = args})
end

function _M.request.read_resource(uri)
  return mcp.rpc.request("resources/read", {uri = uri})
end

function _M.request.call_tool(name, args)
  return mcp.rpc.request("tools/call", {name = name, arguments = args})
end

function _M.notification.initialized()
  return mcp.rpc.notification("notifications/initialized")
end

function _M.notification.list_changed(category)
  return mcp.rpc.notification(string.format("notifications/%s/list_changed", category))
end

function _M.result.initialize(capabilities, name)
  return {
    protocolVersion = mcp.version.protocol,
    capabilities = capabilities and {
      tools = capabilities.tools and (type(capabilities.tools) == "table" and capabilities.tools or {listChanged = true}) or nil,
      resources = capabilities.resources and (type(capabilities.resources) == "table" and capabilities.resources or {subscribe = true, listChanged = true}) or nil,
      prompts = capabilities.prompts and (type(capabilities.prompts) == "table" and capabilities.prompts or {listChanged = true}) or nil,
      completions = capabilities.completions and {} or nil,
      logging = capabilities.logging and {} or nil,
      experimental = capabilities.experimental
    } or {},
    serverInfo = {
      name = name or "lua-resty-mcp",
      version = mcp.version.module
    }
  }
end

function _M.result.list(field_name, tbl, next_cursor)
  local schemas = {}
  for k, v in pairs(tbl) do
    table.insert(schemas, v:to_mcp())
  end
  return {
    [field_name] = schemas,
    nextCursor = next_cursor
  }
end

function _M.annotations(annos)
  local annotations = {}
  if type(annos.audience) == "table" then
    for i, v in ipairs(annos.audience) do
      if v == "user" or v == "assistant" then
        if annotations.audience then
          table.insert(annotations.audience, v)
        else
          annotations.audience = {v}
        end
      end
    end
  end
  if tonumber(annos.priority) then
    annotations.priority = math.min(math.max(tonumber(annos.priority), 0), 1)
  end
  return annotations
end

function _M.tool_annotations(annos)
  local annotations = {title = type(annos.title) == "string" and annos.title or nil}
  for i, k in ipairs({"readOnlyHint", "destructiveHint", "idempotentHint", "openWorldHint"}) do
    if type(annos[k]) == "boolean" then
      annotations[k] = annos[k]
    end
  end
  return annotations
end

return _M
