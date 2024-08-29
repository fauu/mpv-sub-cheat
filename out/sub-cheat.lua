local script_name = "mpv-sub-cheat"
local script_options_prefix = "sub-cheat"
local cheat_lines_capacity = 3
local ass_line_break = "\\N"
local dot_separator_pattern = "[^%.]+"
local options = {enabled = "no", ["margin-bottom"] = 9, lifetime = 8, ["ass-filter"] = "move.fr.kf.fad.k", style = "\\an2\\fs38\\bord1.5\\shad1\\be2\\1c&HFFFFFF&", ["style-1"] = "\\3c&H333333&\\4c&H333333&\\1a&H77&", ["style-2"] = "\\bord1.5\\3c&H993366&\\4c&H000000&\\1a&H00&", ["style-3"] = "\\3c&H1166CC&"}
local enabled_3f = false
local activated_3f = false
local cheat_sid = nil
local cheat_ass_overlay = nil
local cheat_lines = {}
local cheat_lines_expire_timers = {}
local subs_we_revealed_primary_3f = false
local function state_clear()
  cheat_sid = nil
  cheat_ass_overlay = nil
  cheat_lines = {}
  cheat_lines_expire_timers = {}
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
  local prefix
  if (sub_track == 2) then
    prefix = "secondary-"
  else
    prefix = ""
  end
  return (prefix .. property_base)
end
local function cheat_sub_property(property_base)
  return sub_track_property(cheat_sid, property_base)
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
local function append_ass_line_break(s)
  return (s .. ass_line_break)
end
local function cheat_text_showing_3f()
  return (cheat_ass_overlay and not cheat_ass_overlay.hidden)
end
local function cheat_text_empty_3f()
  return (not cheat_ass_overlay or (cheat_ass_overlay.data == ""))
end
local function make_cheat_ass_overlay_data()
  local num_lines = #cheat_lines
  if (num_lines == 0) then
    return ""
  else
    local lines_with_nl
    local function _4_(_241)
      return append_ass_line_break(_241.text)
    end
    lines_with_nl = map(_4_, cheat_lines)
    local padded_lines = array_pad_left(lines_with_nl, cheat_lines_capacity, "")
    local margin = string.rep(ass_line_break, options["margin-bottom"])
    return string.format("{%s%s}%s{%s}%s{%s}%s%s", options.style, options["style-1"], padded_lines[1], options["style-2"], padded_lines[2], options["style-3"], padded_lines[3], margin)
  end
end
local function cheat_text_show()
  cheat_ass_overlay["data"] = make_cheat_ass_overlay_data()
  cheat_ass_overlay["hidden"] = false
  cheat_ass_overlay:update()
  return cheat_ass_overlay
end
local function cheat_text_hide()
  cheat_ass_overlay["hidden"] = true
  cheat_ass_overlay:update()
  return cheat_ass_overlay
end
local function subs_reveal()
  cheat_text_show()
  if ((cheat_sid == 2) and (mp.get_property("sub-visibility") == "no")) then
    mp.set_property("sub-visibility", "yes")
    subs_we_revealed_primary_3f = true
    return nil
  else
    return nil
  end
end
local function subs_hide()
  cheat_text_hide()
  if subs_we_revealed_primary_3f then
    mp.set_property("sub-visibility", "no")
    subs_we_revealed_primary_3f = false
    return nil
  else
    return nil
  end
end
local function cheat_lines_expire_timers_remove(timer)
  for i = 1, #cheat_lines_expire_timers do
    local i_timer = cheat_lines_expire_timers[i]
    if (i_timer == timer) then
      table.remove(cheat_lines_expire_timers, i)
      break
    else
    end
  end
  return nil
end
local function cheat_lines_expire(timer, target_hash)
  cheat_lines_expire_timers_remove(timer)
  for i = 1, #cheat_lines do
    local i_hash = cheat_lines[i].hash
    if (i_hash == target_hash) then
      table.remove(cheat_lines, i)
      if (cheat_text_showing_3f and not cheat_text_empty_3f) then
        cheat_text_show()
      else
      end
      break
    else
    end
  end
  return nil
end
local function cheat_lines_add(sub_text)
  local sub_text_2a = sub_text:gsub("\n", ass_line_break)
  local time = mp.get_property("time-pos/full")
  local first_char = sub_text_2a:sub(1, 1)
  local poor_hash = (time .. #sub_text_2a .. first_char)
  table.insert(cheat_lines, {hash = poor_hash, text = sub_text_2a})
  if (#cheat_lines > cheat_lines_capacity) then
    table.remove(cheat_lines, 1)
  else
  end
  local timer
  local function _12_()
    return cheat_lines_expire(timer, poor_hash)
  end
  timer = mp.add_timeout(options.lifetime, _12_)
  return table.insert(cheat_lines_expire_timers, timer)
end
local function cheat_lines_clear()
  cheat_lines = {}
  return nil
end
local function handle_cheat_sub_text(_, sub_text)
  if string_and_non_empty_3f(sub_text) then
    cheat_lines_add(sub_text)
    if cheat_text_showing_3f() then
      return subs_reveal()
    else
      return nil
    end
  else
    return nil
  end
end
local function handle_seeking()
  if cheat_text_showing_3f() then
    cheat_text_hide()
  else
  end
  cheat_lines_clear()
  if cheat_ass_overlay then
    return cheat_ass_overlay:update()
  else
    return nil
  end
end
local function handle_pause(_, paused_3f)
  if cheat_ass_overlay then
    if paused_3f then
      subs_reveal()
    else
      subs_hide()
    end
  else
  end
  for _0, timer in ipairs(cheat_lines_expire_timers) do
    if paused_3f then
      timer:stop()
    else
      timer:resume()
    end
  end
  return nil
end
local function activate()
  mp.observe_property("seeking", "bool", handle_seeking)
  mp.observe_property("pause", "bool", handle_pause)
  do
    local sid_secondary = mp.get_property("current-tracks/sub2/id")
    if sid_secondary then
      cheat_sid = 2
    else
      cheat_sid = 1
    end
  end
  mp.set_property_bool(cheat_sub_property("sub-visibility"), false)
  do
    cheat_ass_overlay = mp.create_osd_overlay("ass-events")
    cheat_ass_overlay["hidden"] = true
  end
  mp.observe_property(cheat_sub_property("sub-text"), "string", handle_cheat_sub_text)
  activated_3f = true
  return nil
end
local function deactivate()
  mp.unobserve_property(handle_seeking)
  mp.unobserve_property(handle_pause)
  mp.unobserve_property(handle_cheat_sub_text)
  mp.set_property(cheat_sub_property("sub-visibility"), "yes")
  activated_3f = false
  return nil
end
local function handle_sub_track(_, sid_primary)
  state_clear()
  if sid_primary then
    if (enabled_3f and not activated_3f) then
      return activate()
    else
      return nil
    end
  else
    deactivate()
    if enabled_3f then
      return mp.osd_message((script_name .. ": No subtitle tracks selected"))
    else
      return nil
    end
  end
end
local function enable()
  mp.observe_property("current-tracks/sub/id", "number", handle_sub_track)
  enabled_3f = true
  return nil
end
local function disable()
  mp.unobserve_property(handle_sub_track)
  if activated_3f then
    deactivate()
  else
  end
  enabled_3f = false
  return nil
end
local function handle_sub_cheat_toggle_enabled_pressed()
  if enabled_3f then
    disable()
  else
    enable()
  end
  local state
  if enabled_3f then
    state = "ON"
  else
    state = "OFF"
  end
  local msg = (script_name .. " " .. state)
  return mp.osd_message(msg, 5)
end
local function handle_subs_peek_key_event(event_info)
  if activated_3f then
    local _27_ = event_info.event
    if (_27_ == "down") then
      return subs_reveal()
    elseif (_27_ == "up") then
      return subs_hide()
    else
      return nil
    end
  else
    return nil
  end
end
do
  local opt = require("mp.options")
  opt.read_options(options, script_options_prefix)
end
local _30_
do
  local tbl_21_auto = {}
  local i_22_auto = 0
  for identifier in options["ass-filter"]:gmatch(dot_separator_pattern) do
    local val_23_auto = ("\\" .. identifier)
    if (nil ~= val_23_auto) then
      i_22_auto = (i_22_auto + 1)
      tbl_21_auto[i_22_auto] = val_23_auto
    else
    end
  end
  _30_ = tbl_21_auto
end
options["ass-filter"] = _30_
mp.add_key_binding(nil, "sub-cheat-toggle-enabled", handle_sub_cheat_toggle_enabled_pressed)
mp.add_key_binding(nil, "sub-cheat-peek", handle_subs_peek_key_event, {complex = true})
if (options.enabled == "yes") then
  enable()
else
end
return nil
