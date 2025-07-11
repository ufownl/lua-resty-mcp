# lua-resty-mcp

**[Model Context Protocol (MCP)](https://modelcontextprotocol.io/)** SDK implemented in Lua for [OpenResty](https://openresty.org/).

## Status

Production ready.

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
  * [server:replace\_\*](#serverreplace_)
  * [server:list\_roots](#serverlist_roots)
  * [server:create\_message](#servercreate_message)
  * [server:elicit](#serverelicit)
  * [server:log](#serverlog)
  * [server:ping](#serverping)
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
  * [client:prompt\_complete](#clientprompt_complete)
  * [client:resource\_complete](#clientresource_complete)
  * [client:set\_log\_level](#clientset_log_level)
  * [client:ping](#clientping)
* [Known Issues](#known-issues)
  * [Cancel request on server that uses stdio transport](#cancel-request-on-server-that-uses-stdio-transport)
* [License](#license)

## Features

- [x] Transports
  - [x] stdio
  - [x] Streamable HTTP
  - [x] WebSocket *(non-specification)*
- [x] Protocols
  - [x] Lifecycle
  - [x] Prompts
  - [x] Resources
  - [x] Tools
  - [x] Roots
  - [x] Sampling
  - [x] Elicitation
  - [x] Utilities
    - [x] Pagination
    - [x] Progress
    - [x] Cancellation
    - [x] Completion
    - [x] Logging
    - [x] Ping

## Quickstart

A simple server demonstrating prompts, resources, tools:

```lua
-- Import lua-resty-mcp module
local mcp = require("resty.mcp")

-- Create an MCP server session with stdio transport
local server = assert(mcp.server(mcp.transport.stdio, {}))

-- Register a prompt
assert(server:register(mcp.prompt("echo", function(args)
  return "Please process this message: "..args.message
end, {
  description = "Create an echo prompt",
  arguments = {
    message = {required = true}
  }
})))

-- Register a resource template
assert(server:register(mcp.resource_template("echo://{message}", "echo", function(uri, vars)
  return true, "Resource echo: "..ngx.unescape_uri(vars.message)
end, {description = "Echo a message as a resource", mime = "text/plain"})))

-- Register a tool
assert(server:register(mcp.tool("echo", function(args)
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

-- Launch the server session
server:run()
```

## Server APIs

### mcp.server

`syntax: server, err = mcp.server(transport[, options])`

Create an MCP server session with the specific transport (currently only `mcp.transport.stdio` is available here) and options.

A successful call returns an MCP server session. Otherwise, it returns `nil` and a string describing the error.

Available transports:

* `mcp.transport.stdio`
* `mcp.transport.websocket`

Available options:

```lua
{
  -- Common options
  name = "lua-resty-mcp",  -- Name of this session (optional)
  title = "lua-resty-mcp",  -- Title of this session (optional)
  version = "1.0",  -- Version of this session (optional)

  -- Options for WebSocket connections (optional)
  websocket_opts = {
    ...
  },

  -- You can also put your other options here and access them via `options` field of the session instance
}
```

> [!NOTE]
> 1. The optional field `title` is intended for UI and end-user contexts — optimized to be human-readable and easily understood, even by those unfamiliar with domain-specific terminology. If not provided, the name should be used for display;
> 2. Available options for WebSocket connections can be viewed [here](https://github.com/openresty/lua-resty-websocket/tree/master?tab=readme-ov-file#new);
> 3. WebSocket transport for the server should only be used in `content_by_lua*` directives.

A simple echo demo server configuration that uses WebSocket transport:

```lua
worker_processes auto;

events {
}

http {
  server {
    listen 80;

    location = /mcp {
      content_by_lua_block {
        local mcp = require("resty.mcp")
        local server = assert(mcp.server(mcp.transport.websocket))
        assert(server:register(mcp.tool("echo", function(args)
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
        server:run()
      }
    }
  }
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
  assert(server:register(mcp.tool("echo", function(args)
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
  server:run()
end
```

The optional 2nd argument of this method `options`, should be a dict-like Lua table that contains the configuration options of the endpoint and server session. It includes the following optional fields:

```lua
{
  -- Configure the message bus of this endpoint
  message_bus = {
    -- Type of the message bus, available types: "builtin", "redis"
    -- It's implemented using the shared memory zone of OpenResty
    type = "builtin",

    mark_ttl = 10,  -- TTL of the session mark (seconds)
    cache_ttl = 90,  -- TTL of the cached messages (seconds)

    -- Options for "builtin" message bus
    shm_zone = "mcp_message_bus",  -- name of the shared memory zone
    spin_opts = {
      -- Spin waiting arguments for "builtin" message bus
      step = 0.001,
      ratio = 2,
      max_step = 0.5
    },

    -- Options for "redis" message bus
    redis = {
      host = "127.0.0.1",  -- Host of the Redis server
      port = 6379,  -- Port of the Redis server
      password = "foobared",  -- Password of the Redis server
      db = 0,  -- Index of the Redis logical database
      -- Options for Redis connections
      options = {
        ...
      }
    },
    -- The maximum number of events that can be cached for replay
    event_capacity = 1024
  },

  -- Whether to enable the resumability and redelivery mechanism
  enable_resumability = false,

  -- Longest standby in seconds, default: 600
  -- If no request is received from the client for longer than this duration, the session will be terminated
  -- If long inactivity is desired, please send a ping request periodically to avoid the auto-termination
  longest_standby = 600,

  -- Read timeout threshold, in seconds, default: 10
  -- Best to be much smaller than longest_standby, and NOT exceed it
  read_timeout = 10,

  -- Common options are the same as `mcp.server` API
  ...
}
```

> [!NOTE]
> Available options for Redis connections can be viewed [here](https://github.com/openresty/lua-resty-redis?tab=readme-ov-file#connect).

> [!TIP]
> 1. It is recommended to use different shared memory zones or Redis logical databases for different endpoints;
> 2. Hard-coding the Redis password is not secure, it is recommended to pass it through environment variables.

A simple echo demo server configuration that uses Streamable HTTP transport:

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
          assert(server:register(mcp.tool("echo", function(args)
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
    completions = {},
    logging = {},
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

`syntax: component = mcp.prompt(name, callback[, options])`

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

The 3rd argument of this method `options`, should be a dict-like Lua table that contains the optional options of this prompt, and it could be defined as follows:

```lua
{
  title = "Prompt Title",
  description = "Description of this prompt.",
  arguments = {
    arg_name = {
      title = "Argument Title",
      description = "What is this argument.",
      required = true
    },
    ...
  },
  completions = {
    arg_name = function(value, prev_args)
      -- Query the suggested values based on `value`
      -- If `prev_args` is set, it will contain the previously resolved variables passed from the client
      return values, total, has_more  -- All of these are optional
    end,
    ...
  }
}
```

#### mcp.resource

`syntax: component = mcp.resource(uri, name, callback[, options])`

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

The 4th argument of this method `options`, should be a dict-like Lua table that contains the optional options of this resource, and it could be defined as follows:

```lua
{
  title = "Resource Title",
  description = "Description of this resource.",
  mime = "text/plain",  -- MIME type of this resource
  annotations = {
    -- Describes who the intended customer of this object or data is
    audience = {"user", "assistant"},

    -- Describes how important this data is for operating the server
    -- The value will be clipped to the range [0, 1]
    priority = 0.42,

    -- The moment the resource was last modified, as an ISO 8601 formatted string
    last_modified = "2025-06-18T08:00:00Z"
  },
  size = 1024  -- Size of this resource
}
```

#### mcp.resource\_template

`syntax: component = mcp.resource_template(pattern, name, callback[, options])`

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

The 4th argument of this method `options`, should be a dict-like Lua table that contains the optional options of this resource template, and it could be defined as follows:

```lua
{
  title = "Resource Template Title",
  description = "Description of this resource template.",
  mime = "text/plain",  -- MIME type of this resource template
  annotations = {
    -- Describes who the intended customer of this object or data is
    audience = {"user", "assistant"},

    -- Describes how important this data is for operating the server
    -- The value will be clipped to the range [0, 1]
    priority = 0.42,

    -- The moment the resource was last modified, as an ISO 8601 formatted string
    last_modified = "2025-06-18T08:00:00Z"
  },
  completions = {
    var_name = function(value, prev_vars)
      -- Query the suggested values based on `value`
      -- If `prev_vars` is set, it will contain the previously resolved variables passed from the client
      return values, total, has_more  -- All of these are optional
    end,
    ...
  }
}
```

#### mcp.tool

`syntax: component = mcp.tool(name, callback[, options])`

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
    } or {
      -- structured-error that conform to the output schema
      ...
    }
  end
  return "result of this tool calling" or {
    {type = "text", text = "result of this tool calling"},
    {type = "image", data = "...", mimeType = "image/jpeg"},
    ...
  } or {
    -- structured-content that conform to the output schema
    ...
  }
end
```

The 3rd argument of this method `options`, should be a dict-like Lua table that contains the optional options of this tool, and it could be defined as follows:

```lua
{
  title = "Tool Title",
  description = "Description of this tool.",

  -- A JSONSchema-like Lua table that declares the input constraints of this tool
  input_schema = {
    type = "object",
    properties = {
      ...
    },
    required = {...}
  },

  -- A JSONSchema-like Lua table that declares the structure of the tool's output returned in `structuredContent` field
  output_schema = {
    type = "object",
    properties = {
      ...
    },
    required = {...}
  },

  annotations = {
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
}
```

> [!NOTE]
> All of the properties in `annotations` field are **hints**. They are not guaranteed to provide a faithful description of tool behavior (including descriptive properties like `title`).

> [!IMPORTANT]
> 1. When you need to call server methods from callbacks (event handlers and context component callbacks), you **MUST** call them via the `ctx.session` field instead of via the server instance outside of the callback using closure upvalues. Because `ctx.session` is a wrapper of the server instance that contains the context required by the backend components, calling the server methods via the server instance outside of the callback will result in undefined behavior.
> 2. The fields in `ctx` argument of callbacks (event handlers and context component callbacks) are **ONLY** available **before** the callback returns; accessing them after the callback returns results in undefined behavior.

### server:unregister\_\*

`syntax: ok, err = server:unregister_prompt(name)`

`syntax: ok, err = server:unregister_resource(uri)`

`syntax: ok, err = server:unregister_resource_template(pattern)`

`syntax: ok, err = server:unregister_tool(name)`

Unregister the corresponding component.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

### server:resource\_updated

`syntax: ok, err = server:resource_updated(uri)`

Trigger the resource updated event.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

### server:replace\_\*

`syntax: ok, err = server:replace_prompts(prompts)`

`syntax: ok, err = server:replace_resources(resources, templates)`

`syntax: ok, err = server:replace_tools(tools)`

Replace the corresponding components.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

### server:list\_roots

`syntax: roots, err, rpc_err = server:list_roots([timeout])`

Request a list of root URIs from the client.

A successful call returns an array-like Lua table that contains the roots. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

The returned `roots` may have the following structure:

```lua
{
  {uri = "file:///path/to/project", name = "Project"},
  {uri = "file:///path/to/foobar"},
  ...
}
```

### server:create\_message

`syntax: res, err, rpc_err = server:create_message(messages, max_tokens[, options[, timeout[, progress_cb]]])`

Request to sample an LLM via the client.

A successful call returns a dict-like Lua table that contains the sampled message from the client. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

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

### server:elicit

`syntax: res, err, rpc_err = server:elicit(message, schema[, timeout[, progress_cb]])`

Elicit additional information from the user via the client.

A successful call returns a dict-like Lua table that contains the result of the elicitation. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

The 2nd argument of this method `schema`, defines the structure of the expected response from the user using a restricted subset of JSON Schema. Only top-level properties are allowed, without nesting.

The result of the elicitation may have the following structure:

```lua
{
  action = "accept",
  content = {
    text = "Hello, world!",
    seed = 42
  }
}
```

### server:log

`syntax: ok, err = server:log(level, data[, logger])`

Send a log message to the client.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

Available log levels: `"debug"`, `"info"`, `"notice"`, `"warning"`, `"error"`, `"critical"`, `"alert"`, `"emergency"`.

The 2nd argument `data` could be any JSON serializable type, and the optional `logger` should be the name of the logger issuing this message.

### server:ping

`syntax: ok, err, rpc_err = server:ping([timeout])`

Send a `ping` request to the client.

A successful call returns a conditional true value. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

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
assert(client:initialize({
  roots = {
    {path = "/path/to/project", name = "Project"}  -- Expose a directory named `Project` to server
  },
  sampling_callback = function(params)
    -- Sampling callback
    return "Mock sampling text."
  end
}))

-- Discover available prompts
local prompts = assert(client:list_prompts())

-- Get a specific prompt
local res = assert(client:get_prompt("complex_prompt", {temperature = "0.4", style = "json"}))

-- Discover available resources
local resources = assert(client:list_resources())

-- Read a specific resource
local res = assert(client:read_resource("test://static/resource/1"))

-- Subscribe to a specific resource
assert(client:subscribe_resource("test://static/resource/42", function(uri)
  -- Resource updated callback
end))

-- Unsubscribe from a specific resource
assert(client:unsubscribe_resource("test://static/resource/42"))

-- Discover available tools
local tools = assert(client:list_tools())

-- Call a specific tool
local res = assert(client:call_tool("echo", {message = "Hello, world!"}))

-- Shutdown this client session
client:shutdown()
```

## Client APIs

### mcp.client

`syntax: client, err = mcp.client(transport, options)`

Create an MCP client session with the specific transport and options.

A successful call returns an MCP client session. Otherwise, it returns `nil` and a string describing the error.

Available transports:

* `mcp.transport.stdio`
* `mcp.transport.streamable_http`
* `mcp.transport.websocket`

Available options:

```lua
{
  -- Common options
  name = "lua-resty-mcp",  -- Name of this session (optional)
  title = "lua-resty-mcp",  -- Title of this session (optional)
  version = "1.0",  -- Version of this session (optional)

  -- Options for stdio transport

  -- Command and arguments for starting server (required)
  command = "npx -y @modelcontextprotocol/server-everything" or {"npx", "-y", "@modelcontextprotocol/server-everything"},

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

  -- Options for WebSocket transport

  -- URL of the WebSocket MCP endpoint (required)
  endpoint_url = "ws://127.0.0.1/mcp",

  -- Options for WebSocket connections
  websocket_opts = {
    ...
  },

  -- You can also put your other options here and access them via `options` field of the session instance
}
```

> [!NOTE]
> 1. The optional field `title` is intended for UI and end-user contexts — optimized to be human-readable and easily understood, even by those unfamiliar with domain-specific terminology. If not provided, the name should be used for display;
> 2. Available options for HTTP connections can be viewed [here](https://github.com/ledgetech/lua-resty-http?tab=readme-ov-file#connect). Note that `scheme`, `host`, and `port` will be parsed according to `endpoint_url` automatically, so setting them in `http_opts` will be ignored;
> 3. Available options for WebSocket connections can be viewed [here](https://github.com/openresty/lua-resty-websocket/tree/master?tab=readme-ov-file#clientnew), it combines the available options for `client:new` and `client:connect` methods. Note that the subprotocol will always be set to `"mcp"`, so setting `protocols` in `websocket_opts` will be ignored.

### client:initialize

`syntax: ok, err, rpc_err = client:initialize([options[, timeout]])`

Initialize the client session.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

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
      return nil, "an error occured"
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

  -- This callback will be called when MCP server requests elicitation
  elicitation_callback = function(params, ctx)
    local current_session = ctx.session
    -- Interact with the current session or other services
    local ok, err = ctx.push_progress(0.1, 1, "elicitation")
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
    if user_declined then
      return
    end
    return {
      -- Content that conform to `params.requestedSchema`
      ...
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
    end,
    message = function(params, ctx)
      -- Will be called when a log message notification is received (optional)
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

`syntax: prompts, err, rpc_err = client:list_prompts([timeout])`

List the available prompts of the MCP server.

A successful call returns an array-like Lua table that contains the prompts. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

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

`syntax: res, err, rpc_err = client:get_prompt(name, args[, timeout[, progress_cb]])`

Get a specific prompt from the MCP server.

A successful call returns a dict-like Lua table that contains the content of the prompt. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

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

`syntax: resources, err, rpc_err = client:list_resources([timeout])`

List the available resources of the MCP server.

A successful call returns an array-like Lua table that contains the resources. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

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

`syntax: templates, err, rpc_err = client:list_resource_templates([timeout])`

List the available resource templates of the MCP server.

A successful call returns an array-like Lua table that contains the resource templates. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

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

`syntax: res, err, rpc_err = client:read_resource(uri[, timeout[, progress_cb]])`

Read a specific resource from the MCP server.

A successful call returns a dict-like Lua table that contains the content of the resource. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

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

`syntax: ok, err, rpc_err = client:subscribe_resource(uri, callback[, timeout])`

Subscribe to a specific resource of the MCP server.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

`callback` will be called when the MCP server triggers `notifications/resources/updated`, and it could be defined as follows:

```lua
function updated_callback(uri, ctx)
  local current_session = ctx.session
  -- Interact with the current session or other services
  -- Read this resource from the MCP server to get the latest content
end
```

### client:unsubscribe\_resource

`syntax: ok, err, rpc_err = client:unsubscribe_resource(uri[, timeout])`

Unsubscribe from a subscribed resource of the MCP server.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

### client:list\_tools

`syntax: tools, err, rpc_err = client:list_tools([timeout])`

List the available tools of the MCP server.

A successful call returns an array-like Lua table that contains the tools. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

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

`syntax: res, err, rpc_err = client:call_tool(name, args[, timeout[, progress_cb]])`

Call a specific tool in the MCP server.

A successful call returns a dict-like Lua table that contains the result of the tool call. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

The 4th argument of this method `progress_cb`, is the callback to receive the progress of this request. It could be defined as follows:

```lua
function progress_cb(progress, total, message)
  -- If you want to cancel this request, return a conditional false value and an optional string describing the reason
  -- Otherwise, return `true` to continue with the request
end
```

The result of the tool calling may have the following structures:

```lua
-- Without structured content
{
  content = {
    {
      type = "text",
      text = "Current weather in New York:\nTemperature: 72°F\nConditions: Partly cloudy"
    },
    ...
  },
  isError = false
}
```

```lua
-- With structured content
{
  content = {
    {
      "type": "text",
      "text": "{\"temperature\": 22.5, \"conditions\": \"Partly cloudy\", \"humidity\": 65}"
    }
  },
  structuredContent = {
    temperature = 22.5,
    conditions = "Partly cloudy",
    humidity = 65
  },
  isError = false
}
```

### client:prompt\_complete

`syntax: res, err, rpc_err = client:prompt_complete(name, arg_name, arg_value[, prev_args])`

Request to complete an argument of a prompt.

A successful call returns a dict-like Lua table that contains the result of the argument completion. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

The result of the argument completion may have the following structure:

```lua
{
  completion = {
    -- Returned suggested values of this argument (max 100 items)
    values = {...},

    -- Number of total suggested values of this argument (optional)
    total = 123,

    -- Indicates whether there are more suggested values (optional)
    hasMore = true
  }
}
```

### client:resource\_complete

`syntax: res, err, rpc_err = client:resource_complete(uri, arg_name, arg_value[, prev_args])`

Request to complete an argument of a resource template.

A successful call returns a dict-like Lua table that contains the result of the argument completion. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

The 1st argument `uri` should be the URI pattern of the resource template, and the structure of the result is the same as in [client:prompt\_complete](#clientprompt_complete).

### client:set\_log\_level

`syntax: res, err, rpc_err = client:set_log_level(level[, timeout])`

Configure the minimum log level.

A successful call returns a conditional true value. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

Available log levels: `"debug"`, `"info"`, `"notice"`, `"warning"`, `"error"`, `"critical"`, `"alert"`, `"emergency"`.

### client:ping

`syntax: ok, err, rpc_err = client:ping([timeout])`

Send a `ping` request to the server.

A successful call returns a conditional true value. Otherwise, it returns `nil` and a string describing the error, along with an additional RPC error object if the error originated from the peer responding to the RPC request.

## Known Issues

### Cancel request on server that uses stdio transport

It is currently not possible to cancel requests on servers that use stdio transport. This is because the server module of the stdio transport is implemented using the Lua I/O library, and the APIs in it are all blocking. Therefore, it is not possible to yield the execution of the current request handler and handle the cancellation notification.

## License

BSD-3-Clause license. See [LICENSE](https://github.com/ufownl/lua-resty-mcp/blob/main/LICENSE) for details.
