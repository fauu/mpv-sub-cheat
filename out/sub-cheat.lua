local script_options_prefix = "sub-cheat"
local options = {["margin-bottom"] = 9, lifetime = 8, ["ass-filter"] = "move.fr.kf.fad.k", style = "\\an2\\fs36\\bord1.5\\shad1\\be2\\1c&HFFFFFF&", ["style-1"] = "\\3c&H333333&\\4c&H333333&\\1a&H77&", ["style-2"] = "\\bord1.5\\3c&H663399&\\4c&H000000&\\1a&H00&", ["style-3"] = "\\3c&H663300&"}
local fallback_sid = nil
local fallback_ass_overlay = nil
local fallback_lines = {}
local fallback_lines_expire_timers = {}
local subs_we_revealed_primary_3f = false
local function state_clear()
  fallback_sid = nil
  fallback_ass_overlay = nil
  fallback_lines = {}
  fallback_lines_expire_timers = {}
  subs_we_revealed_primary_3f = true
  return nil
end
local function string_and_non_empty_3f(s)
  return ((s ~= nil) and (s ~= ""))
end
local function array_pad_left(arr, up_to, padding_value)
  local result = (arr or {})
  local n = #result
  for i = (n + 1), up_to do
    table.insert(result, 1, padding_value)
  end
  return result
end
local function map(f, arr)
  local tbl_21_auto = {}
  local i_22_auto = 0
  for _, v in ipairs(arr) do
    local val_23_auto = f(v)
    if (nil ~= val_23_auto) then
      i_22_auto = (i_22_auto + 1)
      tbl_21_auto[i_22_auto] = val_23_auto
    else
    end
  end
  return tbl_21_auto
end
local function sub_track_property(sub_track, property_base)
  local _2_
  if (sub_track == 2) then
    _2_ = "secondary-"
  else
    _2_ = ""
  end
  return (_2_ .. property_base)
end
local function has_special_ass_code_3f(s)
  local found = false
  for _, code in ipairs(options["ass-filter"]) do
    if found then break end
    if s:find(code) then
      found = true
    else
    end
  end
  return found
end
local function fallback_text_showing_3f()
  return (fallback_ass_overlay and not fallback_ass_overlay.hidden)
end
local function fallback_text_empty_3f()
  return (not fallback_ass_overlay or (fallback_ass_overlay.data == ""))
end
local function fallback_text_show()
  local num_lines = #fallback_lines
  local data
  if (num_lines == 0) then
    data = ""
  else
    local lines_with_nl
    local function _5_(_241)
      return (_241.text .. "\\N")
    end
    lines_with_nl = map(_5_, fallback_lines)
    local padded_lines = array_pad_left(lines_with_nl, 3, "")
    local margin = string.rep("\\N", options["margin-bottom"])
    local data_2a = string.format("{%s%s}%s{%s}%s{%s}%s%s", options.style, options["style-1"], padded_lines[1], options["style-2"], padded_lines[2], options["style-3"], padded_lines[3], margin)
    data = data_2a
  end
  fallback_ass_overlay["data"] = data
  fallback_ass_overlay["hidden"] = false
  fallback_ass_overlay:update()
  return fallback_ass_overlay
end
local function fallback_text_hide()
  fallback_ass_overlay["hidden"] = true
  fallback_ass_overlay:update()
  return fallback_ass_overlay
end
local function subs_reveal()
  fallback_text_show()
  if ((fallback_sid == 2) and (mp.get_property("sub-visibility") == "no")) then
    mp.set_property("sub-visibility", "yes")
    subs_we_revealed_primary_3f = true
    return nil
  else
    return nil
  end
end
local function subs_hide()
  fallback_text_hide()
  if subs_we_revealed_primary_3f then
    mp.set_property("sub-visibility", "no")
    subs_we_revealed_primary_3f = false
    return nil
  else
    return nil
  end
end
local function fallback_lines_expire_timers_remove(timer)
  for i = 1, #fallback_lines_expire_timers do
    local i_timer = fallback_lines_expire_timers[i]
    if (i_timer == timer) then
      table.remove(fallback_lines_expire_timers, i)
      break
    else
    end
  end
  return nil
end
local function fallback_lines_expire(timer, target_hash)
  fallback_lines_expire_timers_remove(timer)
  for i = 1, #fallback_lines do
    local i_hash = fallback_lines[i].hash
    if (i_hash == target_hash) then
      table.remove(fallback_lines, i)
      if (fallback_text_showing_3f and not fallback_text_empty_3f) then
        fallback_text_show()
      else
      end
      break
    else
    end
  end
  return nil
end
local function fallback_lines_add(sub_text)
  local time = mp.get_property("time-pos/full")
  local first_char = sub_text:sub(1, 1)
  local poor_hash = (time .. #sub_text .. first_char)
  table.insert(fallback_lines, {hash = poor_hash, text = sub_text})
  if (#fallback_lines > 3) then
    table.remove(fallback_lines, 1)
  else
  end
  local timer
  local function _13_()
    return fallback_lines_expire(timer, poor_hash)
  end
  timer = mp.add_timeout(options.lifetime, _13_)
  return table.insert(fallback_lines_expire_timers, timer)
end
local function fallback_lines_clear()
  fallback_lines = {}
  return nil
end
local function handle_subs_reveal_key_event(event_info)
  local _14_ = event_info.event
  if (_14_ == "down") then
    return subs_reveal()
  elseif (_14_ == "up") then
    return subs_hide()
  else
    return nil
  end
end
local function handle_fallback_sub_text(_, sub_text)
  if string_and_non_empty_3f(sub_text) then
    local ass = mp.get_property(sub_track_property(fallback_sid, "sub-text-ass"))
    if (not ass or not has_special_ass_code_3f(ass)) then
      fallback_lines_add(sub_text:gsub("\n", "\\N"))
      if fallback_text_showing_3f() then
        return subs_reveal()
      else
        return nil
      end
    else
      return nil
    end
  else
    return nil
  end
end
local function handle_seeking()
  if fallback_text_showing_3f() then
    fallback_text_hide()
  else
  end
  fallback_lines_clear()
  if fallback_ass_overlay then
    return fallback_ass_overlay:update()
  else
    return nil
  end
end
local function handle_pause(_, paused_3f)
  if fallback_ass_overlay then
    if paused_3f then
      fallback_text_show()
    else
      fallback_text_hide()
    end
  else
  end
  for _0, timer in ipairs(fallback_lines_expire_timers) do
    if paused_3f then
      timer:stop()
    else
      timer:resume()
    end
  end
  return nil
end
local function activate()
  do
    local sid_secondary = mp.get_property("current-tracks/sub2/id")
    if sid_secondary then
      fallback_sid = 2
    else
      fallback_sid = 1
    end
  end
  mp.set_property_bool(sub_track_property(fallback_sid, "sub-visibility"), false)
  do
    fallback_ass_overlay = mp.create_osd_overlay("ass-events")
    fallback_ass_overlay["hidden"] = true
  end
  return mp.observe_property(sub_track_property(fallback_sid, "sub-text"), "string", handle_fallback_sub_text)
end
local function handle_sub_track_change(_, sid_primary)
  state_clear()
  if sid_primary then
    return activate()
  else
    return nil
  end
end
require("mp.options").read_options(options, script_options_prefix)
local _26_
do
  local tbl_21_auto = {}
  local i_22_auto = 0
  for identifier in options["ass-filter"]:gmatch("[^%.]+") do
    local val_23_auto = ("\\" .. identifier)
    if (nil ~= val_23_auto) then
      i_22_auto = (i_22_auto + 1)
      tbl_21_auto[i_22_auto] = val_23_auto
    else
    end
  end
  _26_ = tbl_21_auto
end
options["ass-filter"] = _26_
mp.observe_property("current-tracks/sub/id", "number", handle_sub_track_change)
mp.observe_property("seeking", "bool", handle_seeking)
mp.observe_property("pause", "bool", handle_pause)
mp.add_key_binding(nil, "peek-cheat-subs", handle_subs_reveal_key_event, {complex = true})
return nil
