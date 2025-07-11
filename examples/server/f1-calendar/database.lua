local _M = {
  _NAME = "f1-calendar.database",
  _VERSION = "1.0"
}

local cjson = require("cjson.safe")
local http = require("resty.http")
local ngx_semaphore = require("ngx.semaphore")

local function get_config()
  local httpc, err = http.new()
  if not httpc then
    return nil, err
  end
  httpc:set_proxy_options({
    http_proxy = os.getenv("http_proxy"),
    https_proxy = os.getenv("https_proxy")
  })
  local res, err = httpc:request_uri("https://raw.githubusercontent.com/sportstimes/f1/refs/heads/main/_db/f1/config.json")
  if not res then
    return nil, err
  end
  if res.status ~= ngx.HTTP_OK then
    return nil, "get config failed"
  end
  local cfg, err = cjson.decode(res.body)
  if not cfg then
    return nil, err
  end
  return cfg
end

local function get_schedule(year)
  local httpc, err = http.new()
  if not httpc then
    return nil, err
  end
  httpc:set_proxy_options({
    http_proxy = os.getenv("http_proxy"),
    https_proxy = os.getenv("https_proxy")
  })
  local res, err = httpc:request_uri(string.format("https://raw.githubusercontent.com/sportstimes/f1/refs/heads/main/_db/f1/%u.json", year))
  if not res then
    return nil, err
  end
  if res.status ~= ngx.HTTP_OK then
    return nil, string.format("get schedule of %u failed", year)
  end
  local sch, err = cjson.decode(res.body)
  if not sch then
    return nil, err
  end
  return sch
end

local function get_data()
  local cfg, err = get_config()
  if not cfg then
    return nil, err
  end
  local schedules = {}
  for i, v in ipairs(cfg.availableYears) do
    local sch, err = get_schedule(v)
    if not sch then
      return nil, err
    end
    schedules[v] = sch
  end
  return {
    config = cfg,
    schedules = schedules
  }
end

local cache_storage = {sema = assert(ngx_semaphore.new())}

function _M.query(timeout)
  repeat
    if cache_storage.data then
      if type(cache_storage.data) == "number" then
        cache_storage.data = cache_storage.data + 1
        local ok, err = cache_storage.sema:wait(tonumber(timeout) or 30)
        if not ok then
          cache_storage.data = cache_storage.data - 1
          return nil, err
        end
      end
    else
      cache_storage.data = 0
      local data, err = get_data()
      local n = cache_storage.data
      cache_storage.data = data
      if n > 0 then
        cache_storage.sema:post(n)
      end
      if err then
        return nil, err
      end
    end
  until cache_storage.data
  return cache_storage.data
end

return _M
