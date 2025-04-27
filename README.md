# lua-resty-mcp

**[Model Context Protocol (MCP)](https://modelcontextprotocol.io/)** SDK implemented in Lua for [OpenResty](https://openresty.org/).

## Status

In development.

## Table of Contents

* [Features](#features)
* [Quickstart](#quickstart)
* [Server APIs](#server-apis)
  * [mcp.server](#mcpserver)
  * [mcp.transport.streamable\_http.endpoint](#mcptransportstreamable_httpendpoint)
  * [server:run](#serverrun)
  * [server:register](#serverregister)
  * [server:unregister\_\*](#serverunregister_)
  * [server:resource\_updated](#serverresource_updated)
  * [server:list\_roots](#serverlist_roots)
  * [server:create\_messages](#servercreate_message)
  * [server:wait\_background\_tasks](#serverwait_background_tasks)
  * [server:shutdown](#servershutdown)
* [Writing MCP Clients](#writing-mcp-clients)
* [Client APIs](#client-apis)
  * [mcp.client](#mcpclient)
  * [client:initialize](#clientinitialize)
  * [client:wait\_background\_tasks](#clientwait_background_tasks)
  * [client:shutdown](#clientshutdown)
  * [client:expose\_roots](#clientexpose_roots)
  * [client:list\_prompts](#clientlist_prompts)
  * [client:get\_prompt](#clientget_prompt)
  * [client:list\_resources](#clientlist_resources)
  * [client:list\_resource\_templates](#clientlist_resource_templates)
  * [client:read\_resource](#clientread_resource)
  * [client:subscribe\_resource](#clientsubscribe_resource)
  * [client:unsubscribe\_resource](#clientunsubscribe_resource)
  * [client:list\_tools](#clientlist_tools)
  * [client:call\_tool](#clientcall_tool)
* [Known Issues](#known-issues)
  * [Cancel request on server that uses stdio transport](#cancel-request-on-server-that-uses-stdio-transport)
* [License](#license)

## Features

- [x] Transports
  - [x] stdio
  - [x] Streamable HTTP
- [ ] Protocols
  - [x] Lifecycle
  - [x] Prompts
  - [x] Resources
  - [x] Tools
  - [x] Roots
  - [x] Sampling
  - [ ] Utilities
    - [x] Pagination
    - [x] Progress
    - [x] Cancellation
    - [ ] Ping
    - [ ] Logging
    - [ ] Completion

## Quickstart

A simple server demonstrating prompts, resources, tools:

```lua
-- Import lua-resty-mcp module
local mcp = require("resty.mcp")

-- Create an MCP server session with stdio transport
local server, err = mcp.server(mcp.transport.stdio, {})
if not server then
  error(err)
end

-- Register a prompt
local ok, err = server:register(mcp.prompt("echo", function(args)
  return "Please process this message: "..args.message
end, "Create an echo prompt", {message = {required = true}}))
if not ok then
  error(err)
end

-- Register a resource template
local ok, err = server:register(mcp.resource_template("echo://{message}", "echo", function(uri, vars)
  return true, "Resource echo: "..ngx.unescape_uri(vars.message)
end, "Echo a message as a resource", "text/plain"))
if not ok then
  error(err)
end

-- Register a tool
local ok, err = server:register(mcp.tool("echo", function(args)
  return "Tool echo: "..args.message
end, "Echo a message as a tool", {
  type = "object",
  properties = {
    message = {type = "string"}
  },
  required = {"message"}
}))
if not ok then
  error(err)
end

-- Launch the server session
server:run()
```

## Server APIs

### mcp.server

`syntax: server, err = mcp.server(transport[, options])`

Create an MCP server session with the specific transport (currently only `mcp.transport.stdio` is available here) and options.

A successful call returns an MCP server session. Otherwise, it returns `nil` and a string describing the error.

Available options:

```lua
{
  -- Common options
  name = "lua-resty-mcp",  -- Name of this session (optional)
  version = "1.0",  -- Version of this session (optional)

  -- You can also put your other options here and access them via `options` field of the session instance
}
```

### mcp.transport.streamable\_http.endpoint

`syntax: mcp.transport.streamable_http.endpoint(custom_fn[, options])`

Create an MCP Streamable HTTP endpoint.

> [!NOTE]
> This method should only be called from `content_by_lua*` directives.

The 1st argument of this method `custom_fn`, will be called when the clients initiate the initialization phase; the reference to `resty.mcp` module and the instance of the server session will be passed into this callback. You should configure the contexts for the server and launch the server session in this callback. It could be defined as follows:

```lua
function custom_fn(mcp, server)
  local ok, err = server:register(mcp.tool("echo", function(args)
    return "Tool echo: "..args.message
  end, "Echo a message as a tool", {
    type = "object",
    properties = {
      message = {type = "string"}
    },
    required = {"message"}
  }))
  if not ok then
    error(err)
  end
  server:run()
end
```

The optional 2nd argument of this method `options`, should be a dict-like Lua table that contains the configuration options of the endpoint and server session. It includes the following optional fields:

```lua
{
  -- Configure the message bus of this endpoint
  message_bus = {
    -- Type of the message bus, currently only "builtin" is available
    -- It's implemented using the shared memory zone of OpenResty
    type = "builtin",

    -- Options for "builtin" message bus
    shm_zone = "mcp_message_bus",  -- name of the shared memory zone
    mark_ttl = 10,  -- TTL of the session mark (seconds)
    cache_ttl = 90,  -- TTL of the cached events (seconds)

    -- Options for spin waiting
    step = 0.001,
    ratio = 2,
    max_step = 0.5
  },

  -- Whether to enable the resumability and redelivery mechanism
  enable_resumability = false,

  -- Other options are the same as `mcp.server` API
  ...
}
```

> [!TIP]
> It is recommended to use different shared memory zones for different endpoints.

A simple echo demo server configuration:

```lua
worker_processes auto;

events {
}

http {
  lua_shared_dict mcp_message_bus 64m;

  server {
    listen 80;

    location = /mcp {
      content_by_lua_block {
        require("resty.mcp").transport.streamable_http.endpoint(function(mcp, server)
          local ok, err = server:register(mcp.tool("echo", function(args)
            return "Tool echo: "..args.message
          end, "Echo a message as a tool", {
            type = "object",
            properties = {
              message = {type = "string"}
            },
            required = {"message"}
          }))
          if not ok then
            error(err)
          end
          server:run()
        end)
      }
    }
  }
}
```

> [!IMPORTANT]
> Endpoint callbacks use a different request context than outside the callback, so **DO NOT** access variables outside the callback through upvalues of the closure, which will result in undefined behavior.

### server:run

`syntax: server:run([options])`

Launch the server session.

Available options:

```lua
{
  -- Configure server capabilities, which are enabled by default
  -- Explicitly set the field to `false` to disable the corresponding capability
  -- (optional)
  capabilities = {
    prompts = {
      listChanged = true
    },
    resources = {
      subscribe = true,
      listChanged = true
    },
    tools = {
      listChanged = true
    }
  },

  -- Configure the page size of the corresponding list, 0 disables pagination
  -- The default value for these fields is 0
  -- (optional)
  pagination = {
    prompts = 0,
    resources = 0,
    tools = 0
  },

  -- Instructions describing how to use the server and its features (optional)
  instructions = "Hello, MCP!",

  -- Configure the event handlers of the server session (optional)
  event_handlers = {
    initialized = function(params, ctx)
      -- Will be called after `initialized` notification (optional)
      local current_session = ctx.session
      -- Interact with the current session or other services
    end,
    ["roots/list_changed"] = function(params, ctx)
      -- Will be called after `roots/list_changed` notification (optional)
      local current_session = ctx.session
      -- Interact with the current session or other services
    end,
    ["resources/subscribe"] = function(params, ctx)
      -- Will be called after successfully subscribing to a resource (optional)
      local current_session = ctx.session
      -- Interact with the current session or other services
    end,
    ["resources/unsubscribe"] = function(params, ctx)
      -- Will be called after successfully unsubscribing to a resource (optional)
      local current_session = ctx.session
      -- Interact with the current session or other services
    end
  }
}
```

> [!NOTE]
> Before launching a server session, maybe you should register some context components.

### server:register

`syntax: ok, err = server:register(component)`

Register a context component to the server session.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

Available context components:

* [mcp.prompt](#mcpprompt)
* [mcp.resource](#mcpresource)
* [mcp.resource\_template](#mcpresource_template)
* [mcp.tool](#mcptool)

#### mcp.prompt

`syntax: component = mcp.prompt(name, callback[, desc[, args]])

Create a prompt or prompt template.

`callback` will be called when a client requests to get this prompt, and it could be defined as follows:

```lua
function callback(args, ctx)
  local meta_field = ctx._meta  -- `_meta` field of current request
  local current_session = ctx.session
  -- Interact with the current session or other services
  local ok, err = ctx.push_progress(0.1, 1, "getting prompt")
  -- The 3 arguments stand for "progress", "total", and "message"
  -- "progress" is required and the other 2 are optional
  if not ok then
    if err == "cancelled" then
      -- Or you can also use `ctx.cancelled()` to check whether the current request is cancelled
      return
    end
    error(err)
  end
  -- Continue interacting with the current session or other services
  if error_occurred then
    return nil, "an error occured"
  end
  return "content of this prompt" or {
    {role = "user", content = {type = "text", text = "text content"}},
    {role = "assistant", content = {type = "image", data = "...", mimeType = "image/jpeg"}},
    ...
  }
end
```

The 4th argument of this method `args`, is used to declare the expected arguments that will be passed into `callback`. It should be a table and could be defined as follows:

```lua
{
  arg_name = {
    description = "What is this argument.",
    required = true
  },
  ...
}
```

#### mcp.resource

`syntax: component = mcp.resource(uri, name, callback[, desc[, mime[, annos[, size]]]])`

Create a resource.

`callback` will be called when a client requests to read this resource, and it could be defined as follows:

```lua
function callback(uri, ctx)
  local meta_field = ctx._meta  -- `_meta` field of current request
  local current_session = ctx.session
  -- Interact with the current session or other services
  local ok, err = ctx.push_progress(0.1, 1, "reading resource")
  -- The 3 arguments stand for "progress", "total", and "message"
  -- "progress" is required and the other 2 are optional
  if not ok then
    if err == "cancelled" then
      -- Or you can also use `ctx.cancelled()` to check whether the current request is cancelled
      return
    end
    error(err)
  end
  -- Continue interacting with the current session or other services
  if error_occurred then
    return nil, "an error occured"
  end
  return "content of this resource" or {
    {text = "content of "..uri},
    {uri = uri.."/bin", blob = "SGVsbG8sIHdvcmxkIQ==", mimeType = "application/octet-stream"},
    ...
  }
end
```

The 6th argument of this method `annos`, is optional annotations for the client. It should be a table and could be defined as follows:

```lua
{
  -- Describes who the intended customer of this object or data is
  audience = {"user", "assistant"},

  -- Describes how important this data is for operating the server
  -- The value will be clipped to the range [0, 1]
  priority = 0.42
}
```

#### mcp.resource\_template

`syntax: component = mcp.resource_template(pattern, name, callback[, desc[, mime[, annos]]])`

Create a resource template.

`callback` will be called when a client requests to read a resource that matches this template, and it could be defined as follows:

```lua
function callback(uri, vars, ctx)
  -- `vars` is a table that holds variables extracted from the URI according to the template pattern
  local meta_field = ctx._meta  -- `_meta` field of current request
  local current_session = ctx.session
  -- Interact with the current session or other services
  local ok, err = ctx.push_progress(0.1, 1, "reading resource")
  -- The 3 arguments stand for "progress", "total", and "message"
  -- "progress" is required and the other 2 are optional
  if not ok then
    if err == "cancelled" then
      -- Or you can also use `ctx.cancelled()` to check whether the current request is cancelled
      return
    end
    error(err)
  end
  -- Continue interacting with the current session or other services
  if resource_not_found then
    return false
  end
  if error_occurred then
    return true, nil, "an error occured"
  end
  return true, "content of this resource" or {
    {text = string.format("content of %s, foo=%s", uri, vars.foo)},
    {uri = uri.."/bin", blob = "SGVsbG8sIHdvcmxkIQ==", mimeType = "application/octet-stream"},
    ...
  }
end
```

The argument `annos` is the same as in `mcp.resource`.

#### mcp.tool

`syntax: component = mcp.tool(name, callback[, desc[, input_schema[, annos]]])`

Create a tool.

`callback` will be called when a client requests to call this tool, and it could be defined as follows:

```lua
function callback(args, ctx)
  local meta_field = ctx._meta  -- `_meta` field of current request
  local current_session = ctx.session
  -- Interact with the current session or other services
  local ok, err = ctx.push_progress(0.1, 1, "calling tool")
  -- The 3 arguments stand for "progress", "total", and "message"
  -- "progress" is required and the other 2 are optional
  if not ok then
    if err == "cancelled" then
      -- Or you can also use `ctx.cancelled()` to check whether the current request is cancelled
      return
    end
    error(err)
  end
  -- Continue interacting with the current session or other services
  if error_occurred then
    return nil, "an error occured" or {
      -- multi-content error information
      {type = "text", text = "an error occured"},
      {type = "audio", data = "...", mimeType = "audio/mpeg"},
      ...
    }
  end
  return "result of this tool calling" or {
    {type = "text", text = "result of this tool calling"},
    {type = "image", data = "...", mimeType = "image/jpeg"},
    ...
  }
end
```

The 4th argument `input_schema`, is a JSON Schema object defining the expected arguments for the tool.

The 5th argument `annos`, is optional additional tool information. It should be a table and could be defined as follows:

```lua
{
  -- A human-readable title for the tool
  title = "Foobar",
  
  -- If true, the tool does not modify its environment
  -- Default: false
  readOnlyHint = false,

  -- If true, the tool may perform destructive updates to its environment
  -- If false, the tool performs only additive updates
  -- This property is meaningful only when `readOnlyHint == false`
  -- Default: true
  destructiveHint = true,

  -- If true, calling the tool repeatedly with the same arguments will have no additional effect on the its environment
  -- This property is meaningful only when `readOnlyHint == false`
  -- Default: false
  idempotentHint = false,

  -- If true, this tool may interact with an "open world" of external entities
  -- If false, the tool's domain of interaction is closed
  -- Default: true
  openWorldHint = true
}
```

> [!NOTE]
> All of the above properties are **hints**. They are not guaranteed to provide a faithful description of tool behavior (including descriptive properties like `title`).

> [!IMPORTANT]
> 1. When you need to call server methods from callbacks (event handlers and context component callbacks), you **MUST** call them via the `ctx.session` field instead of via the server instance outside of the callback using closure upvalues. Because `ctx.session` is a wrapper of the server instance that contains the context required by the backend components, calling the server methods via the server instance outside of the callback will result in undefined behavior.
> 2. The fields in `ctx` argument of callbacks (event handlers and context component callbacks) are **ONLY** available **before** the callback returns; accessing them after the callback returns results in undefined behavior.

### server:unregister\_\*

`syntax: ok, err = unregister_prompt(name)`

`syntax: ok, err = unregister_resource(uri)`

`syntax: ok, err = unregister_resource_template(pattern)`

`syntax: ok, err = unregister_tool(name)`

Unregister the corresponding component.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

### server:resource\_updated

`syntax: ok, err = server:resource_updated(uri)`

Trigger the resource updated event.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

### server:list\_roots

`syntax: roots, err = server:list_roots([timeout])`

Request a list of root URIs from the client.

A successful call returns an array-like Lua table that contains the roots. Otherwise, it returns `nil` and a string describing the error.

The returned `roots` may have the following structure:

```lua
{
  {uri = "file:///path/to/project", name = "Project"},
  {uri = "file:///path/to/foobar"},
  ...
}
```

### server:create\_message

`syntax: res, err = server:create_message(messages, max_tokens[, options[, timeout[, progress_cb]]])`

Request to sample an LLM via the client.

A successful call returns a dict-like Lua table that contains the sampled message from the client. Otherwise, it returns `nil` and a string describing the error.

The 1st argument of this method `messages`, should be an array-like Lua table that contains a list of structured conversation messages. It could be defined as follows:

```lua
{
  {
    role = "user" or "assistant",
    content = {type = "text", text = "text message"}
  },
  {
    role = "user" or "assistant",
    content = {type = "image" or "audio", data = "...", mimeType = "..."}
  },
  ...
}
```

The 3rd argument of this method `options`, should be a dict-like Lua table that contains the additional sampling options. It includes the following optional fields:

```lua
{
  -- Preferences for which model to select
  modelPreferences = {
    -- Hints to use for model selection
    hints = {
      {name = "gemma"},
      {name = "llama"},
      ...
    },

    -- How much to prioritize cost when selecting a model
    -- 0 means cost, 1 means cost is the most important factor
    costPriority = 0.5,

    -- How much to prioritize sampling speed (latency) when selecting a model
    -- 0 means speed is not important, 1 means speed is the most important factor
    speedPriority = 0.5,

    -- How much to prioritize intelligence and capabilities when selecting a model
    -- 0 means intelligence is not important, 1 means intelligence is the most important factor
    intelligencePriority = 0.5
  },

  -- System prompt you wants to use for sampling
  systemPrompt = "You are a helpful assistant."

  -- A request to include context from one or more MCP servers (including the caller), to be attached to the prompt
  includeContext = "none" or "thisServer" or "allServers",

  temperature = 0.4,
  stopSequences = {"foo", "bar", ...},
  metadata = {...}
}
```

> [!NOTE]
> All of the above properties are **hints**.

The 5th argument of this method `progress_cb`, is the callback to receive the progress of this request. It could be defined as follows:

```lua
function progress_cb(progress, total, message)
  -- If you want to cancel this request, return a conditional false value and an optional string describing the reason
  -- Otherwise, return `true` to continue with the request
end
```

The returned message of this method is similar to the list elements passed in the `messages` argument, but has an additional `model` field containing the name of the model that generated the message, and an optional `stopReason` field containing the reason why sampling stopped, if known.

### server:wait\_background\_tasks

`syntax: ok, err = server:wait_background_tasks([timeout])`

Wait on the background tasks of the server session.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

### server:shutdown

`syntax: server:shutdown()`

Shutdown the server session.

## Writing MCP Clients

The following code demonstrates how to use the high-level client APIs to interact with an MCP server:

```lua
-- Import lua-resty-mcp module
local mcp = require("resty.mcp")

-- Create an MCP client session with stdio transport
local client, err = mcp.client(mcp.transport.stdio, {
  command = {"npx", "-y", "@modelcontextprotocol/server-everything"}
})

-- Initialize this session with roots (optional) and sampling callback (optional)
local ok, err = client:initialize({
  roots = {
    {path = "/path/to/project", name = "Project"}  -- Expose a directory named `Project` to server
  },
  sampling_callback = function(params)
    -- Sampling callback
    return "Mock sampling text."
  end
})

-- Discover available prompts
local prompts, err = client:list_prompts()

-- Get a specific prompt
local res, err = client:get_prompt("complex_prompt", {temperature = "0.4", style = "json"})

-- Discover available resources
local resources, err = client:list_resources()

-- Read a specific resource
local res, err = client:read_resource("test://static/resource/1")

-- Subscribe to a specific resource
local ok, err = client:subscribe_resource("test://static/resource/42", function(uri)
  -- Resource updated callback
end)

-- Unsubscribe from a specific resource
local ok, err = client:unsubscribe_resource("test://static/resource/42")

-- Discover available tools
local tools, err = client:list_tools()

-- Call a specific tool
local res, err = client:call_tool("echo", {message = "Hello, world!"})

-- Shutdown this client session
client:shutdown()
```

## Client APIs

### mcp.client

`syntax: client, err = mcp.client(transport, options)`

Create an MCP client session with the specific transport (`mcp.transport.stdio` or `mcp.transport.streamable_http`) and options.

A successful call returns an MCP client session. Otherwise, it returns `nil` and a string describing the error.

Available options:

```lua
{
  -- Common options
  name = "lua-resty-mcp",  -- Name of this session (optional)
  version = "1.0",  -- Version of this session (optional)

  -- Options for stdio transport

  -- Command and arguments for starting server (required)
  command = "ngx -y @modelcontextprotocol/server-everything" or {"npx", "-y", "@modelcontextprotocol/server-everything"},

  -- Options for pipe connected to server (optional)
  pipe_opts = {
    -- Buffer size used by reading operations, in bytes
    -- Default: 4096
    buffer_size = 4096,

    -- Environment variables for server
    environ = {"PATH=/tmp/bin", "CWD=/tmp/work"},

    -- Write timeout threshold, in milliseconds
    -- Default: 10000, 0 for never timeout
    write_timeout = 10000,

    -- STDOUT read timeout threshold, in milliseconds
    -- Default: 10000, 0 for never timeout
    stdout_read_timeout = 10000,

    -- Wait timeout threshold, in milliseconds
    -- Default: 10000, 0 for never timeout
    wait_timeout = 10000
  },

  -- Options for Streamable HTTP transport

  -- URL of the MCP endpoint (required)
  endpoint_url = "http://127.0.0.1/mcp",

  -- Content of the HTTP Authorization header (optional)
  endpoint_auth = "Bearer TOKEN",

  -- Read timeout threshold, in seconds
  -- Default: 10
  read_timeout = 10,

  -- Whether to enable the standalone GET SSE stream
  -- Default: false
  enable_get_sse = false,

  -- Options for HTTP connections
  http_opts = {
    ...
  },

  -- Options for spin waiting
  spin_opts = {
    step = 0.001,
    ratio = 2,
    max_step = 0.5
  },

  -- You can also put your other options here and access them via `options` field of the session instance
}
```

> [!NOTE]
> Available options for HTTP connections can be viewed [here](https://github.com/ledgetech/lua-resty-http?tab=readme-ov-file#connect). Note that `scheme`, `host`, and `port` will be parsed according to `endpoint_url` automatically, so setting them in `http_opts` will be ignored.

### client:initialize

`syntax: ok, err = client:initialize([options[, timeout]])`

Initialize the client session.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

Available options:

```lua
{
  -- List of directories that will be exposed to the server
  roots = {
    {path = "/path/to/first", name = "First Directory"},
    {path = "/path/to/second"},
    ...
  },

  -- This callback will be called when the MCP server requests sampling LLM
  sampling_callback = function(params, ctx)
    local current_session = ctx.session
    -- Interact with the current session or other services
    local ok, err = ctx.push_progress(0.1, 1, "sampling")
    -- The 3 arguments stand for "progress", "total", and "message"
    -- "progress" is required and the other 2 are optional
    if not ok then
      if err == "cancelled" then
        -- Or you can also use `ctx.cancelled()` to check whether the current request is cancelled
        return
      end
      error(err)
    end
    -- Continue interacting with the current session or other services
    if error_occurred then
      return nil, -1, "an error occured", opt_extra_err_info
    end
    return "Mock sampling text." or {
      role = "assistant",
      content = {
        type = "text",
        text = "Mock sampling text."
      },
      model = "gemma3-4b",
      stopReason = "endTurn"
    }
  end,

  event_handlers = {
    ["prompts/list_changed"] = function(params, ctx)
      -- Will be called after `prompts/list_changed` notification (optional)
      local current_session = ctx.session
      -- Interact with the current session or other services
    end,
    ["resources/list_changed"] = function(params, ctx)
      -- Will be called after `resources/list_changed` notification (optional)
      local current_session = ctx.session
      -- Interact with the current session or other services
    end,
    ["tools/list_changed"] = function(params, ctx)
      -- Will be called after `tools/list_changed` notification (optional)
      local current_session = ctx.session
      -- Interact with the current session or other services
    end
  }
}
```

The sampling callback's argument `params` may have the following structure:

```lua
{
  messages = {
    {
      role = "user",
      content = {type = "text", text = "What is the capital of France?"}
    },
    ...
  },
  modelPreferences = {
    hints = {
      {name = "claude-3-sonnet"},
      ...
    },
    intelligencePriority = 0.8,
    speedPriority = 0.5
  },
  systemPrompt = "You are a helpful assistant.",
  maxTokens = 100
}
```

### client:wait\_background\_tasks

`syntax: ok, err = client:wait_background_tasks([timeout])`

Wait on the background tasks of the client session.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

### client:shutdown

`syntax: client:shutdown()`

Shutdown the client session.

### client:expose\_roots

`syntax: ok, err = client:expose_roots(roots)`

Expose a new set of directories to the server.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

The argument `roots` is the same as in `client:initialize`, pass `nil` or `{}` to expose no directories to the server.

> [!NOTE]
> Calling this method will trigger `notifications/roots/list_changed`.

### client:list\_prompts

`syntax: prompts, err = client:list_prompts([timeout])`

List the available prompts of the MCP server.

A successful call returns an array-like Lua table that contains the prompts. Otherwise, it returns `nil` and a string describing the error.

The returned `prompts` may have the following structure:

```lua
{
  {
    name = "code_review",
    description = "Asks the LLM to analyze code quality and suggest improvements",
    arguments = {
      {
        name = "code",
        description = "The code to review",
        required = true
      },
      ...
    }
  },
  ...
}
```

### client:get\_prompt

`syntax: res, err = client:get_prompt(name, args[, timeout[, progress_cb]])`

Get a specific prompt from the MCP server.

A successful call returns a dict-like Lua table that contains the content of the prompt. Otherwise, it returns `nil` and a string describing the error.

The 4th argument of this method `progress_cb`, is the callback to receive the progress of this request. It could be defined as follows:

```lua
function progress_cb(progress, total, message)
  -- If you want to cancel this request, return a conditional false value and an optional string describing the reason
  -- Otherwise, return `true` to continue with the request
end
```

The content of the prompt may have the following structure:

```lua
{
  description = "Code review prompt",
  messages = {
    {
      role = "user",
      content = {
        type = "text",
        text = "Please review this Python code:\ndef hello():\n    print('world')"
      }
    },
    ...
  }
}
```

### client:list\_resources

`syntax: resources, err = client:list_resources([timeout])`

List the available resources of the MCP server.

A successful call returns an array-like Lua table that contains the resources. Otherwise, it returns `nil` and a string describing the error.

The returned `resources` may have the following structure:

```lua
{
  {
    uri = "file:///project/src/main.rs",
    name = "main.rs",
    description = "Primary application entry point",
    mimeType = "text/x-rust"
  },
  ...
}
```

### client:list\_resource\_templates

`syntax: templates, err = client:list_resource_templates([timeout])`

List the available resource templates of the MCP server.

A successful call returns an array-like Lua table that contains the resource templates. Otherwise, it returns `nil` and a string describing the error.

The returned `templates` may have the following structure:

```lua
{
  {
    uriTemplate = "file://{+path}",
    name = "Project Files",
    description = "Access files in the project directory",
    mimeType = "application/octet-stream"
  },
  ...
}
```

### client:read\_resource

`syntax: res, err = client:read_resource(uri[, timeout[, progress_cb]])`

Read a specific resource from the MCP server.

A successful call returns a dict-like Lua table that contains the content of the resource. Otherwise, it returns `nil` and a string describing the error.

The 3rd argument of this method `progress_cb`, is the callback to receive the progress of this request. It could be defined as follows:

```lua
function progress_cb(progress, total, message)
  -- If you want to cancel this request, return a conditional false value and an optional string describing the reason
  -- Otherwise, return `true` to continue with the request
end
```

The content of the resource may have the following structure:

```lua
{
  contents = {
    {
      uri = "file:///project/src/main.rs",
      mimeType = "text/x-rust",
      text = "fn main() {\n    println!(\"Hello world!\");\n}"
    },
    ...
  }
}
```

### client:subscribe\_resource

`syntax: ok, err = client:subscribe_resource(uri, callback[, timeout])`

Subscribe to a specific resource of the MCP server.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

`callback` will be called when the MCP server triggers `notifications/resources/updated`, and it could be defined as follows:

```lua
function updated_callback(uri, ctx)
  local current_session = ctx.session
  -- Interact with the current session or other services
  -- Read this resource from the MCP server to get the latest content
end
```

### client:unsubscribe\_resource

`syntax: ok, err = client:unsubscribe_resource(uri[, timeout])`

Unsubscribe from a subscribed resource of the MCP server.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

### client:list\_tools

`syntax: tools, err = client:list_tools([timeout])`

List the available tools of the MCP server.

A successful call returns an array-like Lua table that contains the tools. Otherwise, it returns `nil` and a string describing the error.

The returned `tools` may have the following structure:

```lua
{
  {
    name = "get_weather",
    description = "Get current weather information for a location",
    inputSchema = {
      type = "object",
      properties = {
        location = {
          type = "string",
          description = "City name or zip code"
        }
      },
      required = {"location"}
    }
  },
  ...
}
```

### client:call\_tool

`syntax: res, err = client:call_tool(name, args[, timeout[, progress_cb]])`

Call a specific tool in the MCP server.

A successful call returns a dict-like Lua table that contains the result of the tool call. Otherwise, it returns `nil` and a string describing the error.

The 4th argument of this method `progress_cb`, is the callback to receive the progress of this request. It could be defined as follows:

```lua
function progress_cb(progress, total, message)
  -- If you want to cancel this request, return a conditional false value and an optional string describing the reason
  -- Otherwise, return `true` to continue with the request
end
```

The result of the tool calling may have the following structure:

```lua
{
  jsonrpc = "2.0",
  id = 2,
  result = {
    content = {
      {
        type = "text",
        text = "Current weather in New York:\nTemperature: 72°F\nConditions: Partly cloudy"
      },
      ...
    },
    isError = false
  }
}
```

## Known Issues

### Cancel request on server that uses stdio transport

It is currently not possible to cancel requests on servers that use stdio transport. This is because the server module of the stdio transport is implemented using the Lua I/O library, and the APIs in it are all blocking. Therefore, it is not possible to yield the execution of the current request handler and handle the cancellation notification.

## License

BSD-3-Clause license. See [LICENSE](https://github.com/ufownl/lua-resty-mcp/blob/main/LICENSE) for details.
