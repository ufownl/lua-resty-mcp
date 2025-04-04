return {
  _NAME = "resty.mcp",
  _VERSION = require("resty.mcp.version").module,
  transport = {
    stdio = require("resty.mcp.transport.stdio")
  },
  client = require("resty.mcp.client").new
}
