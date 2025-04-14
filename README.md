# lua-resty-mcp

**[Model Context Protocol (MCP)](https://modelcontextprotocol.io/)** SDK implemented in Lua for [OpenResty](https://openresty.org/).

## Status

In development.

## Features

- [ ] Transports
  - [x] stdio
  - [ ] Streamable HTTP
- [ ] Protocols
  - [x] Lifecycle
  - [x] Prompts
  - [x] Resources
  - [x] Tools
  - [x] Roots
  - [x] Sampling
  - [ ] Utilities
    - [x] Pagination
    - [ ] Ping
    - [ ] Logging
    - [ ] Progress
    - [ ] Completion
    - [ ] Cancellation

## Quickstart

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
  {path = "/path/to/project", name = "Project"}  -- Expose a directory named `Project` to server
}, function(params)
  -- Sampling callback
  return "Mock sampling text."
end)

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

Create an MCP client session with the specific transport (currently only `mcp.transport.stdio` is available) and options.

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
    buffer_size = 4096,  -- Buffer size used by reading operations, in bytes (default: 4096)
    environ = {"PATH=/tmp/bin", "CWD=/tmp/work"},  -- Environment variables for server
    write_timeout = 10000,  -- Write timeout threshold, in milliseconds (default: 10000, 0 for never timeout)
    stdout_read_timeout = 10000,  -- STDOUT read timeout threshold, in milliseconds (default: 10000, 0 for never timeout)
    wait_timeout = 10000,  -- Wait timeout threshold, in milliseconds (default: 10000, 0 for never timeout)
  }

  -- You can also put your other options here and access them via `options` field of the session instance
}
```

### client:initialize

`syntax: ok, err = client:initialize(roots, sampling_callback)`

Initialize the client session.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

Both arguments are optional; `roots` is a list of directories that will be exposed to the server. Its structure is as follows:

```lua
{
  {path = "/path/to/first", name = "First Directory"},
  {path = "/path/to/second"},
  ...
}
```

`sampling_callback` will be called when the MCP server requests sampling LLM, and it could be defined as follows:

```lua
function sampling_callback(params)
  return "Mock sampling text." or {
    role = "assistant",
    content = {
      type = "text",
      text = "Mock sampling text."
    },
    model = "gemma3-4b",
    stopReason = "endTurn"
  }
end
```

The callback's argument `params` may have the following structure:

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

`syntax: prompts, err = client:list_prompts()`

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

`syntax: res, err = client:get_prompt(name, args)`

Get a specific prompt from the MCP server.

A successful call returns a dict-like Lua table that contains the content of the prompt. Otherwise, it returns `nil` and a string describing the error.

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

`syntax: resources, err = client:list_resources()`

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

`syntax: templates, err = client:list_resource_templates()`

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

`syntax: res, err = client:read_resource(uri)`

Read a specific resource from the MCP server.

A successful call returns a dict-like Lua table that contains the content of the resource. Otherwise, it returns `nil` and a string describing the error.

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

`syntax: ok, err = client:subscribe_resource(uri, callback)`

Subscribe to a specific resource of the MCP server.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

`callback` will be called when the MCP server triggers `notifications/resources/updated`, and it could be defined as follows:

```lua
function updated_callback(uri)
  -- Read this resource from the MCP server to get the latest content
end
```

### client:unsubscribe\_resource

`syntax: ok, err = client:unsubscribe_resource(uri)`

Unsubscribe from a subscribed resource of the MCP server.

A successful call returns `true`. Otherwise, it returns `nil` and a string describing the error.

### client:list\_tools

`syntax: tools, err = client:list_tools()`

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

`syntax: res, err = client:call_tool(name, args)`

Call a specific tool in the MCP server.

A successful call returns a dict-like Lua table that contains the result of the tool call. Otherwise, it returns `nil` and a string describing the error.

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

## Server APIs

TODO

## License

BSD-3-Clause license. See [LICENSE](https://github.com/ufownl/lua-resty-mcp/blob/main/LICENSE) for details.
