local _M = {
  _NAME = "t.mock",
  _VERSION = "1.0"
}

function _M.handshake(mcp, server)
  server:run({
    capabilities = {
      prompts = false,
      resources = false,
      tools = false,
      completions = false,
      logging = false
    },
    instructions = "Hello, MCP!"
  })
end

function _M.tools(mcp, server)
  assert(server:register(mcp.tool("add", function(args)
    return args.a + args.b
  end, {
    title = "Add Tool",
    description = "Adds two numbers.",
    input_schema = {
      type = "object",
      properties = {
        a = {type = "number"},
        b = {type = "number"}
      },
      required = {"a", "b"}
    }
  })))

  assert(server:register(mcp.tool("enable_echo", function(args, ctx)
    local ok, err = ctx.session:register(mcp.tool("echo", function(args)
      return string.format("%s %s v%s say: %s", ctx.session.client.info.name, ctx.session.client.info.title, ctx.session.client.info.version, args.message)
    end, {
      title = "Echo Tool",
      description = "Echoes back the input.",
      input_schema = {
        type = "object",
        properties = {
          message = {
            type = "string",
            description = "Message to echo."
          }
        },
        required = {"message"}
      }
    }))
    if not ok then
      return nil, err
    end
    return {}
  end, {title = "Enable Echo", description = "Enables the echo tool."})))

  assert(server:register(mcp.tool("disable_echo", function(args, ctx)
    local ok, err = ctx.session:unregister_tool("echo")
    if not ok then
      return nil, err
    end
    return {}
  end, {title = "Disable Echo", description = "Disables the echo tool."})))

  assert(server:register(mcp.tool("client_info", function(args, ctx)
    return ctx.session.client.info
  end, {
    title = "Client Info",
    description = "Query the client information.",
    output_schema = {
      type = "object",
      properties = {
        name = {type = "string"},
        title = {type = "string"},
        version = {type = "string"}
      },
      required = {"name", "version"}
    }
  })))

  server:run({
    capabilities = {
      prompts = false,
      resources = false,
      completions = false,
      logging = false
    },
    pagination = {
      tools = 1
    }
  })
end

function _M.prompts(mcp, server)
  assert(server:register(mcp.prompt("simple_prompt", function(args)
    return "This is a simple prompt without arguments."
  end, {
    title = "Simple Prompt",
    description = "A prompt without arguments."
  })))

  assert(server:register(mcp.prompt("complex_prompt", function(args)
    return {
      {role = "user", content = {type = "text", text = string.format("This is a complex prompt with arguments: temperature=%s, style=%s", args.temperature, tostring(args.style))}},
      {role = "assistant", content = {type = "text", text = string.format("Assistant reply: temperature=%s, style=%s", args.temperature, tostring(args.style))}}
    }
  end, {
    title = "Complex Prompt",
    description = "A prompt with arguments.",
    arguments = {
      temperature = {title = "Temperature", description = "Temperature setting.", required = true},
      style = {title = "Style", description = "Output style."}
    }
  })))

  assert(server:register(mcp.tool("enable_mock_error", function(args, ctx)
    local ok, err = ctx.session:register(mcp.prompt("mock_error", function(args)
      return nil, "mock error"
    end, {
      title = "Mock Error",
      description = "Mock error message."
    }))
    if not ok then
      return nil, err
    end
    return {}
  end, {description = "Enable mock error prompt."})))

  assert(server:register(mcp.tool("disable_mock_error", function(args, ctx)
    local ok, err = ctx.session:unregister_prompt("mock_error")
    if not ok then
      return nil, err
    end
    return {}
  end)))

  server:run({
    capabilities = {
      resources = false,
      completions = false,
      logging = false
    },
    pagination = {
      prompts = 1
    }
  })
end

function _M.resources(mcp, server)
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
    end, {
      title = "Dynamic Hidden",
      description = "Dynamic hidden resource.",
      mime = "text/plain"
    }))
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
end

function _M.roots(mcp, server)
  assert(server:register(mcp.resource("mock://client_capabilities", "ClientCapabilities", function(uri, ctx)
    local contents = {}
    if ctx.session.client.capabilities.roots then
      table.insert(contents, {uri = uri.."/roots", text = "true"})
      if ctx.session.client.capabilities.roots.listChanged then
        table.insert(contents, {uri = uri.."/roots/listChanged", text = "true"})
      end
    end
    if ctx.session.client.capabilities.sampling then
      table.insert(contents, {uri = uri.."/sampling", text = "true"})
    end
    if ctx.session.client.capabilities.elicitation then
      table.insert(contents, {uri = uri.."/elicitation", text = "true"})
    end
    return contents
  end, {description = "Capabilities of client."})))

  assert(server:register(mcp.resource("mock://discovered_roots", "DiscoveredRoots", function(uri, ctx)
    local roots, err = ctx.session:list_roots()
    if not roots then
      return nil, err
    end
    local contents = {}
    for i, v in ipairs(roots) do
      table.insert(contents, {uri = v.uri, text = v.name or ""})
    end
    return contents
  end, {description = "Discovered roots from client."})))

  server:run({
    capabilities = {
      prompts = false,
      tools = false,
      completions = false,
      logging = false
    },
    event_handlers = {
      ["roots/list_changed"] = function(params, ctx)
        assert(ctx.session:resource_updated("mock://discovered_roots"))
      end
    }
  })
end

function _M.sampling(mcp, server)
  assert(server:register(mcp.resource("mock://client_capabilities", "ClientCapabilities", function(uri, ctx)
    local contents = {}
    if ctx.session.client.capabilities.roots then
      table.insert(contents, {uri = uri.."/roots", text = "true"})
      if ctx.session.client.capabilities.roots.listChanged then
        table.insert(contents, {uri = uri.."/roots/listChanged", text = "true"})
      end
    end
    if ctx.session.client.capabilities.sampling then
      table.insert(contents, {uri = uri.."/sampling", text = "true"})
    end
    if ctx.session.client.capabilities.elicitation then
      table.insert(contents, {uri = uri.."/elicitation", text = "true"})
    end
    return contents
  end, {description = "Capabilities of client."})))

  assert(server:register(mcp.prompt("simple_sampling", function(args, ctx)
    local messages =  {
      {role = "user", content = {type = "text", text = "Hey, man!"}}
    }
    local res, err = ctx.session:create_message(messages, 128)
    if not res then
      return nil, err
    end
    table.insert(messages, res)
    return messages
  end, {description = "Sampling prompt from client without arguments."})))

  server:run({
    capabilities = {
      tools = false,
      completions = false,
      logging = false
    }
  })
end

function _M.progress(mcp, server)
  assert(server:register(mcp.prompt("echo", function(args, ctx)
    for i, v in ipairs({0.25, 0.5, 1}) do
      local ok, err = ctx.push_progress(v, 1, "prompt")
      if not ok then
        return
      end
    end
    return "Please process this message: "..args.message
  end, {
    description = "Create an echo prompt",
    arguments = {
      message = {required = true}
    }
  })))

  assert(server:register(mcp.resource("echo://static", "echo static", function(uri, ctx)
    for i, v in ipairs({0.25, 0.5, 1}) do
      local ok, err = ctx.push_progress(v, 1, "resource")
      if not ok then
        return
      end
    end
    return "Resource echo: static"
  end, {description = "Echo a static message as a resource", mime = "text/plain"})))

  assert(server:register(mcp.resource_template("echo://{message}", "echo", function(uri, vars, ctx)
    for i, v in ipairs({0.25, 0.5, 1}) do
      local ok, err = ctx.push_progress(v, 1, "resource_template")
      if not ok then
        return
      end
    end
    return true, "Resource echo: "..ngx.unescape_uri(vars.message)
  end, {description = "Echo a message as a resource", mime = "text/plain"})))

  assert(server:register(mcp.tool("echo", function(args, ctx)
    for i, v in ipairs({0.25, 0.5, 1}) do
      local ok, err = ctx.push_progress(v, 1, "tool")
      if not ok then
        return
      end
    end
    return "Tool echo: "..args.message
  end, {
    description = "Echo a message as a tool",
    input_schema = {
      type = "object",
      properties = {
        message = {type = "string"}
      },
      required = {"message"}
    }
  })))

  assert(server:register(mcp.prompt("simple_sampling", function(args, ctx)
    local messages =  {
      {role = "user", content = {type = "text", text = "Hey, man!"}}
    }
    local res, err = ctx.session:create_message(messages, 128, nil, 180, function(progress, total, message)
      table.insert(messages, {
        role = "assistant",
        content = {
          type = "text",
          text = string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message))
        }
      })
      return true
    end)
    if not res then
      return nil, err
    end
    table.insert(messages, res)
    return messages
  end, {description = "Sampling prompt from client without arguments."})))

  assert(server:register(mcp.prompt("cancel_sampling", function(args, ctx)
    local messages =  {
      {role = "user", content = {type = "text", text = "Hey, man!"}}
    }
    local res, err = ctx.session:create_message(messages, 128, nil, 180, function(progress, total, message)
      table.insert(messages, {
        role = "assistant",
        content = {
          type = "text",
          text = string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message))
        }
      })
      return nil, "test cancellation"
    end)
    if not res then
      return nil, err
    end
    table.insert(messages, res)
    return messages
  end, {description = "Sampling prompt from client without arguments."})))

  server:run()
end

function _M.cancellation(mcp, server)
  local utils = require("resty.mcp.utils")

  assert(server:register(mcp.prompt("echo", function(args, ctx)
    assert(ctx.push_progress(0.25, 1, "prompt"))
    local ok, err = utils.spin_until(function()
      return ctx.cancelled()
    end, 1)
    if ok then
      return
    end
    error(err)
    return "Please process this message: "..args.message
  end, {
    description = "Create an echo prompt",
    arguments = {
      message = {required = true}
    }
  })))

  assert(server:register(mcp.resource("echo://static", "echo static", function(uri, ctx)
    assert(ctx.push_progress(0.25, 1, "resource"))
    local ok, err = utils.spin_until(function()
      return ctx.cancelled()
    end, 1)
    if ok then
      return
    end
    error(err)
    return "Resource echo: static"
  end, {description = "Echo a static message as a resource", mime = "text/plain"})))

  assert(server:register(mcp.resource_template("echo://{message}", "echo", function(uri, vars, ctx)
    assert(ctx.push_progress(0.25, 1, "resource_template"))
    local ok, err = utils.spin_until(function()
      return ctx.cancelled()
    end, 1)
    if ok then
      return
    end
    error(err)
    return true, "Resource echo: "..ngx.unescape_uri(vars.message)
  end, {description = "Echo a message as a resource", mime = "text/plain"})))

  assert(server:register(mcp.tool("echo", function(args, ctx)
    assert(ctx.push_progress(0.25, 1, "tool"))
    local ok, err = utils.spin_until(function()
      return ctx.cancelled()
    end, 1)
    if ok then
      return
    end
    error(err)
    return "Tool echo: "..args.message
  end, {
    description = "Echo a message as a tool",
    input_schema = {
      type = "object",
      properties = {
        message = {type = "string"}
      },
      required = {"message"}
    }
  })))

  assert(server:register(mcp.prompt("simple_sampling", function(args, ctx)
    local messages =  {
      {role = "user", content = {type = "text", text = "Hey, man!"}}
    }
    local res, err = ctx.session:create_message(messages, 128, nil, 180, function(progress, total, message)
      table.insert(messages, {
        role = "assistant",
        content = {
          type = "text",
          text = string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message))
        }
      })
      return true
    end)
    if not res then
      return nil, err
    end
    table.insert(messages, res)
    return messages
  end, {description = "Sampling prompt from client without arguments."})))

  assert(server:register(mcp.prompt("cancel_sampling", function(args, ctx)
    local messages =  {
      {role = "user", content = {type = "text", text = "Hey, man!"}}
    }
    local res, err = ctx.session:create_message(messages, 128, nil, 180, function(progress, total, message)
      table.insert(messages, {
        role = "assistant",
        content = {
          type = "text",
          text = string.format("progress=%s, total=%s, message=%s", tostring(progress), tostring(total), tostring(message))
        }
      })
      return nil, "test cancellation"
    end)
    if not res then
      return nil, err
    end
    table.insert(messages, res)
    return messages
  end, {description = "Sampling prompt from client without arguments."})))

  server:run()
end

function _M.batch_replace(mcp, server)
  assert(server:register(mcp.tool("batch_prompts", function(args, ctx)
    local ok, err = ctx.session:replace_prompts({
      mcp.prompt("batch_prompt_1", function(args, ctx)
        return "content of batch_prompt_1"
      end),
      mcp.prompt("batch_prompt_2", function(args, ctx)
        return "content of batch_prompt_2"
      end)
    })
    if not ok then
      return nil, err
    end
    return {}
  end)))

  assert(server:register(mcp.tool("batch_resources", function(args, ctx)
    local ok, err = ctx.session:replace_resources({
      mcp.resource("mock://batch/static_1", "static_1", function(uri, ctx)
        return "batch_static_1"
      end),
      mcp.resource("mock://batch/static_2", "static_2", function(uri, ctx)
        return "batch_static_2"
      end)
    }, {
      mcp.resource_template("mock://batch/dynamic_1/{id}", "dynamic_1", function(uri, vars, ctx)
        if vars.id == "" then
          return false
        end
        return true, "batch_dynamic_1: "..vars.id
      end),
      mcp.resource_template("mock://batch/dynamic_2/{id}", "dynamic_2", function(uri, vars, ctx)
        if vars.id == "" then
          return false
        end
        return true, "batch_dynamic_2: "..vars.id
      end)
    })
    if not ok then
      return nil, err
    end
    return {}
  end)))

  assert(server:register(mcp.tool("batch_tools", function(args, ctx)
    local ok, err = ctx.session:replace_tools({
      mcp.tool("batch_tool_1", function(args, ctx)
        return "result of batch_tool_1"
      end),
      mcp.tool("batch_tool_2", function(args, ctx)
        return "result of batch_tool_2"
      end)
    })
    if not ok then
      return nil, err
    end
    return {}
  end)))

  server:run()
end

function _M.logging(mcp, server)
  assert(server:register(mcp.tool("log_echo", function(args, ctx)
    local ok, err = ctx.session:log(args.level, args.data, args.logger)
    if not ok then
      return nil, err
    end
    return {}
  end, {
    description = "Echo a message as log.",
    input_schema = {
      type = "object",
      properties = {
        level = {type = "string"},
        data = {type = "string"},
        logger = {type = "string"}
      },
      required = {"level", "data"}
    }
  })))

  server:run({
    capabilities = {
      prompts = false,
      resources = false,
      completions = false
    }
  })
end

function _M.ping(mcp, server)
  assert(server:register(mcp.tool("ping", function(args, ctx)
    local ok, err = ctx.session:ping()
    if not ok then
      return nil, err
    end
    return {}
  end, {description = "Send a ping request."})))

  server:run({
    capabilities = {
      logging = false,
      prompts = false,
      resources = false,
      completions = false
    }
  })
end

function _M.completion(mcp, server)
  assert(server:register(mcp.prompt("simple_prompt", function(args)
    return "This is a simple prompt without arguments."
  end, {description = "A prompt without arguments."})))

  assert(server:register(mcp.prompt("complex_prompt", function(args)
    return {
      {role = "user", content = {type = "text", text = string.format("This is a complex prompt with arguments: temperature=%s, style=%s", args.temperature, tostring(args.style))}},
      {role = "assistant", content = {type = "text", text = string.format("Assistant reply: temperature=%s, style=%s", args.temperature, tostring(args.style))}}
    }
  end, {
    description = "A prompt with arguments.",
    arguments = {
      temperature = {description = "Temperature setting.", required = true},
      style = {description = "Output style."}
    },
    completions = {
      style = function(value, prev_args)
        if prev_args and prev_args.style then
          return {prev_args.style}
        end
        local available_values = {"a01", "a02"}
        for i = 0, 99 do
          table.insert(available_values, string.format("b%02d", i))
        end
        local values = {}
        for i, v in ipairs(available_values) do
          if string.find(v, value, 1, true) then
            table.insert(values, v)
          end
        end
        return values, #values
      end
    }
  })))

  assert(server:register(mcp.resource_template("mock://no_completion/text/{id}", "NoCompletion", function(uri, vars)
    if vars.id == "" then
      return false
    end
    return true, {
      {text = string.format("content of no_completion text resource %s, id=%s", uri, vars.id)},
    }
  end, {description = "No completion text resource.", mime = "text/plain"})))

  assert(server:register(mcp.resource_template("mock://dynamic/text/{id}", "DynamicText", function(uri, vars)
    if vars.id == "" then
      return false
    end
    return true, {
      {text = string.format("content of dynamic text resource %s, id=%s", uri, vars.id)},
    }
  end, {
    desciption = "Dynamic text resource.",
    mime = "text/plain",
    completions = {
      id = function(value, prev_args)
        if prev_args and prev_args.id then
          return {prev_args.id}
        end
        local available_values = {"a01", "a02"}
        for i = 0, 99 do
          table.insert(available_values, string.format("b%02d", i))
        end
        local values = {}
        for i, v in ipairs(available_values) do
          if string.find(v, value, 1, true) then
            table.insert(values, v)
          end
        end
        return values, nil, #values > 2
      end
    }
  })))

  server:run({
    capabilities = {
      logging = false,
      tools = false
    }
  })
end

function _M.elicitation(mcp, server)
  assert(server:register(mcp.resource("mock://client_capabilities", "ClientCapabilities", function(uri, ctx)
    local contents = {}
    if ctx.session.client.capabilities.roots then
      table.insert(contents, {uri = uri.."/roots", text = "true"})
      if ctx.session.client.capabilities.roots.listChanged then
        table.insert(contents, {uri = uri.."/roots/listChanged", text = "true"})
      end
    end
    if ctx.session.client.capabilities.sampling then
      table.insert(contents, {uri = uri.."/sampling", text = "true"})
    end
    if ctx.session.client.capabilities.elicitation then
      table.insert(contents, {uri = uri.."/elicitation", text = "true"})
    end
    return contents
  end, {description = "Capabilities of client."})))

  assert(server:register(mcp.tool("simple_elicit", function(args, ctx)
    local res, err = ctx.session:elicit("Hello, world!", {
      type = "object",
      properties = {
        text = {type = "string"},
        seed = {type = "integer"}
      },
      required = {"text", "seed"}
    })
    if not res then
      return nil, err
    end
    return res
  end, {
    description = "Elicit from client without arguments.",
    output_schema = {type = "object"}
  })))

  server:run({
    capabilities = {
      prompts = false,
      completions = false,
      logging = false
    }
  })
end

return _M
