local mcp = {
  transport = {
    stdio = require("resty.mcp.transport.stdio")
  },
  session = require("resty.mcp.session"),
  protocol = require("resty.mcp.protocol"),
  resource = require("resty.mcp.resource")
}

local conn, err = mcp.transport.stdio.server()
if not conn then
  error(err)
end
local sess, err = mcp.session.new(conn)
if not sess then
  error(err)
end

local available_resources = {}
local subscribed_resources = {}

local function set_discovered_roots(roots)
  local resource = mcp.resource.new("mock://discovered_roots", "DiscoveredRoots", function(uri)
    local contents = {}
    for i, v in ipairs(roots) do
      table.insert(contents, {uri = v.uri, text = v.name or ""})
    end
    return contents
  end, "Discovered roots from client.")
  available_resources[resource.uri] = resource
end

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
    return mcp.protocol.result.initialize({resources = {subscribe = true, listChanged = false}})
  end,
  ["notifications/initialized"] = function(params)
    local res, err = sess:send_request("list", {"roots"})
    if not res then
      error(err)
    end
    set_discovered_roots(res.roots)
  end,
  ["notifications/roots/list_changed"] = function(params)
    local res, err = sess:send_request("list", {"roots"})
    if not res then
      error(err)
    end
    set_discovered_roots(res.roots)
    local uri = "mock://discovered_roots"
    if subscribed_resources[uri] then
      local ok, err = sess:send_notification("resource_updated", {uri})
      if not ok then
        error(err)
      end
    end
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
  ["resources/subscribe"] = function(params)
    if subscribed_resources[params.uri] then
      return {}
    end
    local resource = available_resources[params.uri]
    if resource then
      subscribed_resources[params.uri] = true
      return {}
    end
    return nil, -32002, "Resource not found", {uri = params.uri}
  end,
  ["resources/unsubscribe"] = function(params)
    subscribed_resources[params.uri] = nil
    return {}
  end
})
