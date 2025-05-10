local _M = {
  _NAME = "f1-calendar-mcp.utils",
  _VERSION = "1.0"
}

function _M.iso_date(date)
  local m, err = ngx.re.match(date, "^(?<year>[0-9]+)-(?<month>[0-9]+)-(?<day>[0-9]+)T(?<hour>[0-9]+):(?<minute>[0-9]+):(?<second>[0-9]+(\\.[0-9]+)?)(?<offset_sign>[Z+-])((?<offset_hour>[0-9]+)(:(?<offset_minute>[0-9]+))?)?$", "o")
  if not m then
    if err then
      ngx.log(ngx.ERR, "regex error: ", err)
    end
    return
  end
  local timestamp = os.time({
    year = tonumber(m.year),
    month = tonumber(m.month),
    day = tonumber(m.day),
    hour = tonumber(m.hour),
    min = tonumber(m.minute)
  }) + tonumber(m.second) - os.time({
    year = 1970,
    month = 1,
    day = 1,
    hour = 0
  })
  local offset = 0
  if m.offset_sign ~= "Z" then
    if tonumber(m.offset_hour) then
      offset = offset + tonumber(m.offset_hour) * 3600
    end
    if tonumber(m.offset_minute) then
      offset = offset + tonumber(m.offset_minute) * 60
    end
    if m.offset_sign == "+" then
      offset = -offset
    end
  end
  return timestamp + offset
end

return _M
