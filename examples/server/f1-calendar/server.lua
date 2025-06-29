local _M = {
  _NAME = "f1-calendar.server",
  _VERSION = "1.0"
}

function _M.declare(mcp, server)
  local data, err = require("f1-calendar.database").query()
  if not data then
    return nil, err
  end

  local function iso_date(date)
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

  local session_names = {
    fp1 = "FP1",
    fp2 = "FP2",
    fp3 = "FP3",
    qualifying = "Qualifying",
    sprintQualifying = "Sprint Qualifying",
    sprint = "Sprint",
    gp = "GP"
  }

  local function race_schedule(race)
    local sessions
    if race.sessions.sprint then
      if race.sessions.sprintQualifying then
        sessions = {"fp1", "sprintQualifying", "sprint", "qualifying", "gp"}
      else
        sessions = {"fp1", "qualifying", "fp2", "sprint", "gp"}
      end
    else
      sessions = {"fp1", "fp2", "fp3", "qualifying", "gp"}
    end
    local resp = "**Schedule:**\n\n"
    for i, s in ipairs(sessions) do
      local sdt = iso_date(race.sessions[s])
      local edt = sdt + data.config.sessionLengths[s] * 60
      resp = resp..string.format("- **%s:** from %s to %s\n", session_names[s], os.date("%c", sdt), os.date("%c", edt))
    end
    return resp
  end

  assert(server:register(mcp.tool("upcoming_or_ungoing_race", function(args, ctx)
    local schedule = data.schedules[data.config.calendarOutputYear]
    if not schedule then
      return nil, "No schedule found for this year's Formula One World Championship."
    end
    local race
    local now = ngx.now()
    for i = #schedule.races, 1, -1 do
      local dt = iso_date(schedule.races[i].sessions.gp) + data.config.sessionLengths.gp * 60
      if now > dt then
        race = schedule.races[i + 1]
        break
      end
    end
    if not race then
      return "All Formula One races this year have concluded."
    end
    local resp = string.format("The current date and time is %s. ", os.date("%c", now))
    local name = string.find(race.name, "Grand Prix", 1, true) and race.name or race.name.." Grand Prix"
    local fp1_ts = iso_date(race.sessions.fp1)
    if now < fp1_ts then
      resp = resp..string.format("The %s will start in ", name)
      local dur = fp1_ts - now
      if dur > 24 * 3600 then
        local dt = os.date("*t", math.floor(now))
        local today = math.floor(now) - dt.hour * 3600 - dt.min * 60 - dt.sec
        local fp1_dt = os.date("*t", math.floor(fp1_ts))
        local fp1_day = math.floor(fp1_ts) - fp1_dt.hour * 3600 - fp1_dt.min * 60 - fp1_dt.sec
        local days = (fp1_day - today) / (24 * 3600)
        resp = resp..string.format("%u %s ", days, days > 1 and "days" or "day")
      else
        local hours = math.floor(dur % (24 * 3600) / 3600)
        if hours > 0 then
          resp = resp..string.format("%u %s ", hours, hours > 1 and "hours" or "hour")
        else
          local minutes = math.floor(dur % 3600 / 60)
          resp = resp..string.format("%u %s ", minutes, minutes > 1 and "minutes" or "minute")
        end
      end
    else
      resp = resp..string.format("The %s is being held ", name)
    end
    resp = resp..string.format("at %s (lon %f, lat %f).\n\n", race.location, race.longitude, race.latitude)
    return resp..race_schedule(race)
  end, {description = "Get detailed information and the race schedule about the upcoming or ongoing Formula One Grand Prix. The race schedule includes the start and end times of each session."})))

  assert(server:register(mcp.tool("race_calendar", function(args, ctx)
    local year = args.year or data.config.calendarOutputYear
    local schedule = data.schedules[year]
    if not schedule then
      return nil, string.format("No schedule found for the %u Formula One World Championship.", year)
    end
    local now = ngx.now()
    local resp = string.format("## Race calendar of the %u Formula One World Championship\n\nThe %u Formula One World Championship has %u rounds.\n\n", year, year, #schedule.races)
    for i, r in ipairs(schedule.races) do
      local name = string.find(r.name, "Grand Prix", 1, true) and r.name or r.name.." Grand Prix"
      local fp1_sdt = iso_date(r.sessions.fp1)
      local gp_edt = iso_date(r.sessions.gp) + data.config.sessionLengths.gp * 60
      resp = resp..string.format("### Round %u: %s\n\nThe %s ", r.round, name, name)
      if now < fp1_sdt then
        resp = resp.."will be "
      elseif now < gp_edt then
        resp = resp.."is being "
      else
        resp = resp.."was "
      end
      resp = resp..string.format("held at %s (lon %f, lat %f). \n\n", r.location, r.longitude, r.latitude)
      resp = resp..string.format("%s\n", race_schedule(r))
    end
    return resp
  end, {
    description = "Get the race calendar of the Formula One World Championship for this year or a specific season. You can get information such as how many rounds there are in a year, the location, and the schedule of each Grand Prix in the race calendar. The schedule includes detailed information about each session, such as the session name, start and end times, etc.",
    input_schema = {
      type = "object",
      properties = {
        year = {
          type = "integer",
          description = string.format("Specify the year in four-digit format, available years are %s. Alternatively, you can omit this argument to get the race calendar for this year.", table.concat(data.config.availableYears, ", ")),
          minimum = data.config.availableYears[1],
          maximum = data.config.availableYears[-1],
        }
      }
    }
  })))

  return true
end

return _M
