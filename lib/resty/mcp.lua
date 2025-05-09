return {
  _NAME = "resty.mcp",
  _VERSION = require("resty.mcp.version").module,
  transport = {
    stdio = require("resty.mcp.transport.stdio"),
    streamable_http = require("resty.mcp.transport.streamable_http"),
    websocket = require("resty.mcp.transport.websocket")
  },
  client = require("resty.mcp.client").new,
  server = require("resty.mcp.server").new,
  prompt = require("resty.mcp.prompt").new,
  resource = require("resty.mcp.resource").new,
  resource_template = require("resty.mcp.resource_template").new,
  tool = require("resty.mcp.tool").new
}
