#!/usr/bin/env lua
--[[
  showcase.lua  —  animated truecolor showcase for lua-nxterm

  Demonstrates:
    • Scrolling HSV rainbow
    • Time-animated plasma field
    • Half-block sphere with rotating light
    • Soft “waving” American flag (subtle)
    • Synchronized output for tear-free frames

  Requires a truecolor terminal.
  Run:  lua examples/showcase.lua
  Exit: Ctrl-C  (or let it run ~30 s)
]]

local nxterm = require('nxterm')
local sc     = nxterm.color
local cur    = nxterm.cursor
local write, flush = io.write, io.flush

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function hsv_to_rgb(h, s, v)
  h = h % 360
  local c = v * s
  local x = c * (1 - math.abs((h / 60) % 2 - 1))
  local m = v - c
  local r, g, b
  if     h <  60 then r,g,b = c, x, 0
  elseif h < 120 then r,g,b = x, c, 0
  elseif h < 180 then r,g,b = 0, c, x
  elseif h < 240 then r,g,b = 0, x, c
  elseif h < 300 then r,g,b = x, 0, c
  else                r,g,b = c, 0, x
  end
  return math.floor((r+m)*255 + 0.5),
         math.floor((g+m)*255 + 0.5),
         math.floor((b+m)*255 + 0.5)
end

local function bg(r, g, b)
  return sc(string.format('bg_r%dg%db%d', r, g, b))
end

local function fg(r, g, b)
  return sc(string.format('r%dg%db%d', r, g, b))
end

local function half(ur, ug, ub, lr, lg, lb)
  return fg(ur, ug, ub) .. bg(lr, lg, lb) .. '▀'
end

local function reset() return sc.reset or sc'' end

local function get_size()
  local sz = nxterm.size()
  if not sz then return 80, 24 end
  return sz[1] or sz.width or 80, sz[2] or sz.height or 24
end

-- crude but portable sleep (seconds, fractional ok on most systems)
local function sleep(sec)
  os.execute(string.format('sleep %.3f', sec))
end

---------------------------------------------------------------------------
-- Animated drawers  (all take a time parameter t in seconds)
---------------------------------------------------------------------------

local function draw_rainbow(ox, oy, width, rows, t)
  local phase = t * 40          -- scroll speed
  for row = 0, rows - 1 do
    local line = {}
    for col = 0, width - 1 do
      local hue = ((col / width) * 360 + phase) % 360
      local sat = 0.85 + 0.15 * math.sin(row * 0.5 + t)
      local val = 0.70 + 0.30 * math.cos(col * 0.04 + t * 1.5)
      local r, g, b = hsv_to_rgb(hue, sat, val)
      line[#line + 1] = bg(r, g, b) .. ' '
    end
    write(cur.setlc(oy + row, ox) .. table.concat(line) .. reset())
  end
end

local function draw_plasma(ox, oy, w, h, t)
  for y = 0, h - 1 do
    local line = {}
    for x = 0, w - 1 do
      local v = math.sin(x * 0.13 + t * 1.7)
            + math.sin(y * 0.17 + t * 1.3)
            + math.sin((x + y) * 0.09 + t * 0.9)
            + math.sin(math.sqrt(x*x + y*y) * 0.11 - t * 2.1)
      v = (v + 4) / 8
      local r, g, b = hsv_to_rgb(v * 280 + t * 30, 0.9, 0.5 + 0.45 * v)
      line[#line + 1] = bg(r, g, b) .. ' '
    end
    write(cur.setlc(oy + y, ox) .. table.concat(line) .. reset())
  end
end

local function draw_sphere(ox, oy, diam, t)
  local radius = diam / 2
  local cx, cy = radius, radius
  -- rotating light direction
  local lx = math.cos(t * 1.4)
  local ly = math.sin(t * 1.1) * 0.7

  for cell_y = 0, math.floor(diam / 2) - 1 do
    local line = {}
    for cell_x = 0, diam - 1 do
      local function pixel(px, py)
        local dx = px - cx + 0.5
        local dy = py - cy + 0.5
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > radius then
          return 12, 12, 22
        end
        local nx = dx / radius
        local ny = dy / radius
        local light = math.max(0.05, 0.55 - 0.5 * (nx * lx + ny * ly))
        -- slight pulse
        light = light * (0.85 + 0.15 * math.sin(t * 3 + dist * 0.3))
        local r = math.floor(30  + light * 200)
        local g = math.floor(70  + light * 160)
        local b = math.floor(150 + light * 100)
        return r, g, b
      end
      local ur, ug, ub = pixel(cell_x, cell_y * 2)
      local lr, lg, lb = pixel(cell_x, cell_y * 2 + 1)
      line[#line + 1] = half(ur, ug, ub, lr, lg, lb)
    end
    write(cur.setlc(oy + cell_y, ox) .. table.concat(line) .. reset())
  end
end

-- Subtle wave on the flag (horizontal shear of stripes + brightness)
local function draw_flag(ox, oy, flag_w, flag_h, t)
  flag_w = math.max(flag_w, 36)
  flag_h = math.max(flag_h, 12)

  local stripe_h = flag_h / 13
  local canton_h = math.floor(7 * stripe_h + 0.5)
  local canton_w = math.floor(flag_w * 0.4 + 0.5)

  local reds   = {{185,25,40}, {200,16,46}, {215,45,60}}
  local whites = {{225,225,225}, {240,240,240}, {255,255,255}}
  local blues  = {{8,22,70}, {18,38,105}, {28,52,135}}

  for y = 0, flag_h - 1 do
    local row = {}
    local stripe_idx = math.floor(y / stripe_h)
    local is_red = (stripe_idx % 2 == 0)
    local shade = (y % 3) + 1

    -- gentle vertical wave offset (visual “flutter”)
    local wave = math.sin(y * 0.35 + t * 2.5) * 1.8

    for x = 0, flag_w - 1 do
      local r, g, b
      local sx = x + wave          -- sample with slight horizontal shift

      if y < canton_h and sx < canton_w then
        local bx = blues[shade]
        local tt = math.max(0, math.min(1, sx / canton_w))
        r = math.floor(bx[1] * (0.8 + 0.35 * tt))
        g = math.floor(bx[2] * (0.8 + 0.35 * tt))
        b = math.floor(bx[3] * (0.85 + 0.25 * tt))
        -- stars
        local star_rows = 9
        local sy = math.floor(y / (canton_h / star_rows))
        local sxx = math.floor((sx - 2) / (canton_w / 11))
        local stars_in_row = (sy % 2 == 0) and 6 or 5
        local offset = (sy % 2 == 0) and 0 or 1
        if sy >= 0 and sy < star_rows
           and sxx >= offset and sxx < offset + stars_in_row * 2
           and sxx % 2 == offset % 2 then
          r, g, b = 255, 255, 255
        end
      else
        if is_red then
          local rx = reds[shade]
          local tt = x / flag_w
          -- brightness modulation from the wave
          local pulse = 1 + 0.08 * math.sin(x * 0.2 + t * 3)
          r = math.min(255, math.floor((rx[1] + tt * 20) * pulse))
          g = math.min(255, math.floor((rx[2] + tt * 8)  * pulse))
          b = math.min(255, math.floor((rx[3] + tt * 8)  * pulse))
        else
          local wx = whites[shade]
          r, g, b = wx[1], wx[2], wx[3]
        end
      end
      row[#row + 1] = bg(r, g, b) .. ' '
    end
    write(cur.setlc(oy + y, ox) .. table.concat(row) .. reset())
  end
end

---------------------------------------------------------------------------
-- Main animation loop
---------------------------------------------------------------------------

local function main()
  local cols, rows = get_size()
  local usable_w = math.max(60, cols - 1)
  local usable_h = math.max(22, rows - 1)

  write(nxterm.mode.alt_screen(true))
  write(nxterm.mode.sync(true))
  write(cur.hide())
  write(nxterm.erase())
  write(nxterm.title('nxterm · animated patterns'))
  flush()

  -- layout constants (computed once)
  local rain_rows = 3
  local flag_h = math.min(14, math.floor(usable_h * 0.38))
  local flag_w = math.floor(flag_h * 1.9)
  if flag_w > usable_w * 0.48 then
    flag_w = math.floor(usable_w * 0.48)
    flag_h = math.floor(flag_w / 1.9)
  end
  local flag_y   = rain_rows + 3
  local sphere_d = math.min(flag_h * 2 - 1, usable_w - flag_w - 6)
  local sphere_x = flag_w + 5
  local sphere_y = flag_y
  local plasma_h = math.max(5, rows - (flag_y + flag_h + 3))
  local plasma_y = rows - plasma_h - 1

  local t0 = os.clock()
  local frame = 0
  local max_frames = 600          -- ~30 s at ~20 fps

  while frame < max_frames do
    local t = os.clock() - t0
    frame = frame + 1

    write(nxterm.mode.sync(true))   -- begin synchronized update

    -- header
    write(cur.setlc(1, 1)
        .. sc('bg_#0f0f1e white bold')
        .. string.format('  nxterm animated demo  ·  t=%.1fs  frame=%d  ·  Ctrl-C to quit', t, frame)
        .. string.rep(' ', math.max(0, usable_w - 70))
        .. reset())

    -- rainbow (scrolling)
    draw_rainbow(1, 2, usable_w, rain_rows, t)

    -- labels
    write(cur.setlc(flag_y - 1, 2) .. sc.dim('flag + wave') .. reset())
    write(cur.setlc(sphere_y - 1, sphere_x) .. sc.dim('half-block sphere') .. reset())

    -- main elements
    draw_flag(2, flag_y, flag_w, flag_h, t)
    draw_sphere(sphere_x, sphere_y, sphere_d, t)

    -- plasma
    write(cur.setlc(plasma_y - 1, 2) .. sc.dim('plasma') .. reset())
    draw_plasma(1, plasma_y, usable_w, plasma_h, t)

    write(nxterm.mode.sync(false))  -- end synchronized update → single paint
    flush()

    sleep(0.045)                    -- ~22 fps target
  end

  -- clean exit
  write(nxterm.mode.sync(false))
  write(nxterm.mode.alt_screen(false))
  write(cur.show())
  write(nxterm.erase() .. cur.setlc(1, 1))
  flush()
end

-- graceful Ctrl-C
local ok, err = pcall(main)
if not ok then
  write(nxterm.mode.sync(false))
  write(nxterm.mode.alt_screen(false))
  write(cur.show())
  write(nxterm.erase() .. cur.setlc(1, 1))
  flush()
  if not tostring(err):match('interrupted') then
    io.stderr:write(tostring(err) .. '\n')
  end
end

