local mcp = {
  version = require("resty.mcp.version")
}

local _M = {
  _NAME = "resty.mcp.utils.uri_template",
  _VERSION = mcp.version.module
}

local ngx_escape_uri = ngx.escape_uri
local ngx_re_gsub = ngx.re.gsub
local ngx_re_find = ngx.re.find
local ngx_re_match = ngx.re.match

local function encode_unreserved(raw)
  local out, n, err = ngx_re_gsub(ngx_escape_uri(raw, 2), "[!'()*]", function(m)
    return string.format("%%%02X", string.byte(m[0]))
  end, "o")
  if not out then
    error(err)
  end
  return out
end

local function encode_reserved(raw)
  local out = ""
  while true do
    local from, to, err = ngx_re_find(raw, "%[0-9A-Fa-f]{2}", "o")
    if err then
      error(err)
    end
    local part = from and string.sub(raw, 1, from - 1) or raw
    local s, n, err = ngx_re_gsub(ngx_escape_uri(part, 0), "%([35][bBdDfF])", function(m)
      local ch = string.upper(m[1])
      if ch == "3F" then
        return "?"
      elseif ch == "5B" then
        return "["
      elseif ch == "5D" then
        return "]"
      else
        return m[0]
      end
    end, "o")
    if not s then
      error(err)
    end
    out = out..s
    if not to then
      break
    end
    out = out..string.sub(raw, from, to)
    if to >= #raw then
      break
    end
    raw = string.sub(raw, to + 1)
  end
  return out
end

local function encode_value(op, val, key)
  local fn = (op == "+" or op == "#") and encode_reserved or encode_unreserved
  return key and encode_unreserved(key).."="..fn(val) or fn(val)
end

local function key_operator(op)
  return op == ";" or op == "&" or op == "?"
end

local function get_values(ctx, op, key, mod)
  local val = ctx[key]
  local typ = type(val)
  local res = {}
  if val == "" then
    if op == ";" then
      table.insert(res, encode_unreserved(key))
    elseif op == "?" or op == "&" then
      table.insert(res, encode_unreserved(key).."=")
    else
      table.insert(res, "")
    end
  elseif typ ~= "nil" then
    if typ == "string" or typ == "number" or typ == "boolean" then
      table.insert(res, encode_value(op, tonumber(mod) and string.sub(tostring(val), 1, math.floor(mod)) or tostring(val), key_operator(op) and key))
    elseif typ == "table" then
      if mod == "*" then
        if #val > 0 then
          for i, v in ipairs(val) do
            if type(v) ~= "nil" then
              table.insert(res, encode_value(op, tostring(v), key_operator(op) and key))
            end
          end
        else
          for k, v in pairs(val) do
            if type(v) ~= "nil" then
              table.insert(res, encode_value(op, tostring(v), k))
            end
          end
        end
      else
        local t = {}
        if #val > 0 then
          for i, v in ipairs(val) do
            if type(v) ~= "nil" then
              table.insert(t, encode_value(op, tostring(v)))
            end
          end
        else
          for k, v in pairs(val) do
            if type(v) ~= "nil" then
              table.insert(t, encode_unreserved(k))
              table.insert(t, encode_value(op, tostring(v)))
            end
          end
        end
        if key_operator(op) then
          table.insert(res, encode_unreserved(key).."="..table.concat(t, ","))
        elseif #t > 0 then
          table.insert(res, table.concat(t, ","))
        end
      end
    else
      error("unsupported value type: "..typ)
    end
  end
  return res
end

local function get_regex(op, key, mod)
  local pattern = "\\S"..(tonumber(mod) and string.format("{%d,%d}", 0, mod * 3) or "*")
  if op == ";" then
    if mod == "*" then
      return string.format("(?:%s=?)?(%s)", encode_unreserved(key), pattern)
    else
      return encode_unreserved(key)..string.format("(?:=(%s))?", pattern)
    end
  elseif op == "?" or op == "&" then
    if mod == "*" then
      return string.format("(?:%s=)?(%s)", encode_unreserved(key), pattern)
    else
      return encode_unreserved(key)..string.format("=(%s)", pattern)
    end
  else
    return string.format("(%s)", pattern)
  end
end

local available_operators = {
  ["+"] = true,
  ["#"] = true,
  ["."] = true,
  ["/"] = true,
  [";"] = true,
  ["?"] = true,
  ["&"] = true,
}

local function parse_operator(exp)
  local op = string.sub(exp, 1, 1)
  if available_operators[op] then
    return op, string.sub(exp, 2)
  else
    return nil, exp
  end
end

local function escape_regex(raw, ctx)
  if ctx then
    return raw
  end
  local out, n, err = ngx_re_gsub(raw, "[\\$\\(\\)\\[\\]\\.\\?\\+\\*]", function(m)
    return "\\"..m[0]
  end, "o")
  if err then
    error(err)
  end
  return out
end

local function expand_impl(pattern, ctx)
  local vars = {}
  local out, n, err = ngx_re_gsub(pattern, "{([^{}]+)}|([^{}]+)", function(m)
    if m[1] then
      local op, exp = parse_operator(m[1])
      local vals = {}
      local function parse_variable(var)
        local m, err = ngx_re_match(var, "([^:\\*]*)(?::(\\d+)|(\\*))?", "o")
        if m then
          if ctx then
            for i, v in ipairs(get_values(ctx, op, m[1], m[2] or m[3])) do
              table.insert(vals, v)
            end
          else
            table.insert(vals, get_regex(op, m[1], m[2] or m[3]))
          end
          table.insert(vars, m[1])
        elseif err then
          error(err)
        end
      end
      local prev = 1
      while true do
        local curr = string.find(exp, ",", prev, true)
        if not curr then
          parse_variable(string.sub(exp, prev))
          break
        end
        parse_variable(string.sub(exp, prev, curr - 1))
        prev = curr + 1
      end
      if #vals == 0 then
        return ""
      end
      if op and op ~= "+" then
        local sep = op
        if op == "?" then
          sep = "&"
        elseif op == "#" then
          sep = ","
        end
        return escape_regex(op, ctx)..table.concat(vals, escape_regex(sep, ctx))
      else
        return table.concat(vals, ",")
      end
    else
      return escape_regex(encode_reserved(m[2]), ctx)
    end
  end, "o")
  if not out then
    error(err)
  end
  return ctx and out or "^"..out.."$", vars
end

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

function _MT.__index.expand(self, ctx)
  if not ctx then
    error("context MUST be set")
  end
  local out, vars = expand_impl(self.pattern, ctx)
  return out
end

function _MT.__index.test(self, uri)
  local from, to, err = ngx_re_find(uri, self.match_regex, "o")
  if err then
    error(err)
  end
  return from == 1 and to == #uri
end

-- Known issue: parse unpacked list variables following a key operator (`;?&`).
function _MT.__index.match(self, uri)
  local m, err = ngx_re_match(uri, self.match_regex, "o")
  if err then
    error(err)
  end
  if not m then
    return nil, "mismatch"
  end
  local res = {}
  for i, v in ipairs(self.variables) do
    if m[i] and (not res[v] or #m[i] > #res[v]) then
      res[v] = m[i]
    end
  end
  return res
end

function _M.new(pattern)
  local regex, vars = expand_impl(pattern)
  if #vars == 0 then
    return nil, "invalid uri template pattern"
  end
  return setmetatable({
    pattern = pattern,
    match_regex = regex,
    variables = vars
  }, _MT)
end

function _M.check(v)
  return type(v) == "table" and v._NAME == _M._NAME and v or nil
end

return _M
