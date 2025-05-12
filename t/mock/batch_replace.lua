local mcp = require("resty.mcp")

local server = assert(mcp.server(mcp.transport.stdio))

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
