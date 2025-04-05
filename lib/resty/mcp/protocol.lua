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

function _M.request.initialize(name, roots, sampling, experimental)
  return mcp.rpc.request("initialize", {
    protocolVersion = mcp.version.protocol,
    capabilities = {
      roots = roots and (type(roots) == "table" and roots or {listChanged = true}) or nil,
      sampling = sampling and {} or nil,
      experimental = experimental
    },
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

function _M.result.initialize(name, tools, resources, prompts, completions, logging, experimental)
  return {
    protocolVersion = mcp.version.protocol,
    capabilities = {
      tools = tools and (type(tools) == "table" and tools or {listChanged = true}) or nil,
      resources = resources and (type(resources) == "table" and resources or {subscribe = true, listChanged = true}) or nil,
      prompts = prompts and (type(prompts) == "table" and prompts or {listChanged = true}) or nil,
      completions = completions and {} or nil,
      logging = logging and {} or nil,
      experimental = experimental
    },
    serverInfo = {
      name = name or "lua-resty-mcp",
      version = mcp.version.module
    }
  }
end

return _M
