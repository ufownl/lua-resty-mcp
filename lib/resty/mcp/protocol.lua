local mcp = {
  version = require("resty.mcp.version"),
  rpc = require("resty.mcp.protocol.rpc"),
  validator = require("resty.mcp.protocol.validator")
}

local _M = {
  _NAME = "resty.mcp.protocol",
  _VERSION = mcp.version.module,
  request = {},
  notification = {},
  result = {}
}

local cjson = require("cjson.safe")

function _M.request.initialize(capabilities, name, version)
  return {
    msg = mcp.rpc.request("initialize", {
      protocolVersion = mcp.version.protocol,
      capabilities = capabilities and {
        roots = capabilities.roots and (type(capabilities.roots) == "table" and capabilities.roots or {listChanged = true}) or nil,
        sampling = capabilities.sampling and {} or nil,
        experimental = capabilities.experimental
      } or {},
      clientInfo = {
        name = name or "lua-resty-mcp",
        version = version or mcp.version.module
      }
    }),
    validator = mcp.validator.InitializeResult
  }
end

local list_result_validator = {
  prompts = mcp.validator.ListPromptsResult,
  resources = mcp.validator.ListResourcesResult,
  ["resources/templates"] = mcp.validator.ListResourceTemplatesResult,
  tools = mcp.validator.ListToolsResult,
  roots = mcp.validator.ListRootsResult
}

function _M.request.list(category, cursor)
  return {
    msg = mcp.rpc.request(category.."/list", {cursor = cursor}),
    validator = list_result_validator[category]
  }
end

function _M.request.get_prompt(name, args)
  return {
    msg = mcp.rpc.request("prompts/get", {name = name, arguments = args}),
    validator = mcp.validator.GetPromptResult
  }
end

function _M.request.read_resource(uri)
  return {
    msg = mcp.rpc.request("resources/read", {uri = uri}),
    validator = mcp.validator.ReadResourceResult
  }
end

function _M.request.subscribe_resource(uri)
  return {
    msg = mcp.rpc.request("resources/subscribe", {uri = uri}),
    validator = function(res)
      return true
    end
  }
end

function _M.request.unsubscribe_resource(uri)
  return {
    msg = mcp.rpc.request("resources/unsubscribe", {uri = uri}),
    validator = function(res)
      return true
    end
  }
end

function _M.request.call_tool(name, args)
  return {
    msg = mcp.rpc.request("tools/call", {name = name, arguments = args}),
    validator = mcp.validator.CallToolResult
  }
end

function _M.request.set_log_level(level)
  return {
    msg = mcp.rpc.request("logging/setLevel", {level = level}),
    validator = function(res)
      return true
    end
  }
end

function _M.request.create_message(messages, max_tokens, options)
  return {
    msg = mcp.rpc.request("sampling/createMessage", {
      messages = messages,
      maxTokens = tonumber(max_tokens),
      modelPreferences = options and options.modelPreferences,
      systemPrompt = options and tostring(options.systemPrompt),
      includeContext = options and tostring(options.includeContext),
      temperature = options and tonumber(options.temperature),
      stopSequences = options and options.stopSequences,
      metadata = options and options.metadata
    }),
    validator = mcp.validator.CreateMessageResult
  }
end

function _M.notification.initialized()
  return mcp.rpc.notification("notifications/initialized")
end

function _M.notification.list_changed(category)
  return mcp.rpc.notification(string.format("notifications/%s/list_changed", category))
end

function _M.notification.resource_updated(uri)
  return mcp.rpc.notification("notifications/resources/updated", {uri = uri})
end

function _M.notification.progress(progress_token, progress, total, message)
  return mcp.rpc.notification("notifications/progress", {
    progressToken = progress_token,
    progress = progress,
    total = total,
    message = message
  })
end

function _M.notification.cancelled(rid, reason)
  return mcp.rpc.notification("notifications/cancelled", {
    requestId = rid,
    reason = reason
  })
end

function _M.notification.message(level, data, logger)
  return mcp.rpc.notification("notifications/message", {
    level = level,
    data = data,
    logger = logger
  })
end

function _M.result.initialize(capabilities, name, version, instructions)
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
      version = version or mcp.version.module
    },
    instructions = instructions
  }
end

function _M.result.list(field_name, tbl, next_cursor)
  local schemas = {}
  for k, v in pairs(tbl) do
    table.insert(schemas, v:to_mcp())
  end
  return {
    [field_name] = setmetatable(schemas, cjson.array_mt),
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
