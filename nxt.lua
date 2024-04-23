-- local vars
local format, match, sfind, sub = string.format, string.match, string.find, string.sub
local gmatch, gsub = string.gmatch, string.gsub, string.sub
local insert, concat = table.insert, table.concat
local unpack = unpack or table.unpack
local tonumber = tonumber
local rawget, rawset, getmetatable, setmetatable = rawget, rawset, getmetatable, setmetatable
local pairs, ipairs, type = pairs, ipairs, type
local read, write, flush = io.read, io.write, io.flush

local esc = string.char(27) -- all that is holy
local esc_osc = esc .. ']' -- Operating System Command Sequences (ESC])
local esc_csi = esc .. '[' -- Control Sequence Introducer Commands (ESC[)

-- todo:
-- nxt.strip with multiple levels (color, color 16, 256, etc)
-- tolower keywords? should we make it safe for idiots?
-- chaining? sc.red.bold.ul.ul_c91 ?

local nxt = { -- nxterm vtwtf
	_VERSION	 = 'lua-nxt',
	_DESCRIPTION = 'NXTerminal Handling, Escape Sequences, Curses, colors and stuff...',
	_COPYRIGHT   = 'Copyright (C) Sam Orlando 2024 - MIT is for sellouts.',
	-- options
	strip = nil, -- on option and it will strip all esc seq info from strings passed with keys. (see todo)
	-- constants
	-- char map
	cm = {},
	-- general module functions
	title = function(s) return concat({esc_osc,30,';',(s or ''),'\007'}) end,
	reset = function() return esc .. 'c' end,
	erase = function(n) return concat({esc_csi,n or 2,'J'}) end,
	line = {
		erase = function(n) return concat({esc_csi,n or 2,'K'}) end,
		insert = function(n) return concat({esc_csi,n or 1,'L'}) end,
		delete = function(n) return concat({esc_csi,n or 1,'M'}) end,
	},	
	scroll = {
		up = function(n) return concat({esc_csi,n or 1,'S'}) end,
		down = function(n) return concat({esc_csi,n or 1,'T'}) end,
	},
	shift = { -- todo finish
		right = nil,
		left = nil,
	},
	tab = function(n) return concat({esc_csi,n or 1,'I'}) end,
	backtab = function(n) return concat({esc_csi,n or 1,'Z'}) end,
	char = {
		delete = function(n) return concat({esc_csi,n or 1,'P'}) end,
		erase = function(n) return concat({esc_csi,n or 1,'X'}) end,
		insert = function(n) return concat({esc_csi,n or 1,'@'}) end,
		rep = function(n) return concat({esc_csi,n or 1,'b'}) end, -- repeat and not going to bother; this comment was another excessive 
	},
	mode = { -- need to finish dec mode options and where does the fucking ? go?
		set = function(m, dec) return m and concat({esc_csi,m,'h'}) end,
		reset = function(m, dec) return m and concat({esc_csi,m,'l'}) end,
		restore = function(m, dec) return m and concat({esc_csi,m,'r'}) end,
		save = function(m, dec) return m and concat({esc_csi,m,'s'}) end,
		ansi = function() return esc_csi .. '<' end, --vt100
		gpu = function(s) return esc_csi .. (s and '1' or '2') end, --vt52/100
	},
	tty = {
		sane = function() os.execute('stty sane 2> /dev/null') end,
		raw = function() os.execute('stty raw onlcr -echo 2> /dev/null') end,
		set = function() end,
		get = function() end,
	},
	mouse = { -- sgr
		on = function() return esc_csi .. '?1006h' end,
		off = function() return esc_csi .. '?1006l' end,
	},
}
-- aliases
nxt.clear = nxt.erase


-- CURSOR Sequences and Functions
nxt.cursor = {
	up = function(n) return concat({esc_csi,n or 1,'A'}) end,
	down = function(n) return concat({esc_csi,n or 1,'B'}) end,
	forward = function(n) return concat({esc_csi,n or 1,'C'}) end,
	back = function(n) return concat({esc_csi,n or 1,'D'}) end,
	nl = function(n) return concat({esc_csi,n or 1,'E'}) end,
	pl = function(n) return concat({esc_csi,n or 1,'F'}) end,
	sety = function(n, absolute) return concat({esc_csi,n or 1,(absolute and '`') or 'a'}) end,
	setx = function(n, absolute) return concat({esc_csi,n or 1,(absolute and 'd') or 'e'}) end,
	set = function(x,y) return concat({esc_csi,y or 1,';',x or 1,'H'}) end,
	setlc = function(l,c) return concat({esc_csi,l or 1,';',c or 1,'H'}) end,
	save = function() return esc_csi .. 's' end,
	restore = function() return esc_csi .. 'u' end,
	hide = function() return esc_csi .. '?25l' end,
	show = function() return esc_csi .. '?25h' end,
	style = function(n) return concat({esc_csi,n or 0,'q'}) end,
	get = function()
		write(esc_csi .. '6n')
		flush()
		local c,r,m = read(2),'',0 -- char, return, max
		if c == esc_csi then
			while true do
				c = read(1)
				m = m + 1				
				if c == 'R' then break
				elseif m > 7 then return end -- no larger than xxx;xxx something went wrong
				r = r .. c
			end
		else return end
		local y,x = match(r,'(%d+);(%d+)') -- line,col to x,y
		return x and {x,y}
	end,
	getlc = function()
		local pos = nxt.cursor.get()
		return {pos[2],pos[1]}
	end,
}
nxt.cursor.right = nxt.cursor.forward
nxt.cursor.left = nxt.cursor.back

-- function depended on cursor functions
nxt.mode.size = function()
	local pos = nxt.cursor.get()
	write(nxt.cursor.set(9999,9999))
	flush()
	local size = nxt.cursor.get()
	write(nxt.cursor.set(pos[1],pos[2]))
	flush()
	return size
end

-- SGR 
local key_to_sgr = { -- each key name represents an sgr code (Select Graphic Rendition)
  -- reset
  reset = 0, normal = 0,
  -- styles
  b = 1, bright = 1, bold = 1, --bright should not be used but legacy
  shadow = "1:2", -- mintty
  dim = 2, faint = 2,
  italic = 3, i = 3,
  under = 4, ul = 4,
  ul_single = "4:1", ul_double = "4:2", ul_wavy = "4:3", ul_dot = "4:4", ul_dash = "4:5",
  blink = 5,
  blink_fast = 6, blink_rapid = 6,
  inverse = 7, reverse = 7,
  hide = 8,
  strike = 9,
  ul_double = 21, -- overwrites 4:2
  b_off = 22, bright_off = 22, bold_off = 22, shadow_off = 22,
  italic_off = 23, i_off = 23,
  under_off = 24, ul_off = 24,
  blink_off = 25,
  proportional = 26,
  inverse_off = 27, reverse_off = 27,
  unhide = 28, hide_off = 28,
  strike_off = 29,
  -- foreground colors (standard)
  black = 30,
  red = 31,
  green = 32,
  yellow = 33, brown = 33,
  blue = 34,
  magenta = 35,
  cyan = 36,
  white = 37,
  default = 39, fg_reset = 39, fg_default = 39,
  -- background colors (standard)
  bg_black = 40,
  bg_red = 41,
  bg_green = 42,
  bg_yellow = 43, bg_brown = 43,
  bg_blue = 44,
  bg_magenta = 45,
  bg_cyan = 46,
  bg_white = 47,
  bg_default = 49, bg_reset = 49, bg_off = 49,
  -- extended (mintty, etc, god we need better standards)
  proportional_off = 50,
  frame = 51,
  encircle = 52,
  over = 53, ol = 53,
  frame_off = 54, encircle_off = 54,
  over_off = 55, ol_off = 55,
  under_default = 59, ul_default = 59, ul_reset = 59, under_reset = 59,
  sup = 73, super = 73,
  sub = 74,
  script_off = 75,
  -- foreground colors (bright)
  grey = 90, gray = 90, black_b = 90,
  red_b = 91,
  green_b = 92,
  yellow_b = 93, brown_b = 93,
  blue_b = 94,
  magenta_b = 95,
  cyan_b = 96,
  white_b = 97,
  -- background colors (bright)
  bg_grey = 100, bg_gray = 100, bg_black_b = 100,
  bg_red_b = 101,
  bg_green_b = 102,
  bg_yellow_b = 103, bg_brown_b = 103,
  bg_blue_b = 104,
  bg_magenta_b = 105,
  bg_cyan_b = 106,
  bg_white_b = 107,
}

-- palette color(c69)
local function cc_get(s) -- get color code number from string
    local cc = tonumber(match(s, "c(%d+)"))
    if not cc or cc < 0 or cc > 255 then return end
    return cc
end
key_to_sgr["c"] = function(s)
    local cc = cc_get(s)
    return cc and ('38;5;' .. cc)
end
key_to_sgr["bg_c"] = function(s)
    local cc = cc_get(s)
    return cc and ('48;5;' .. cc)
end
key_to_sgr["ul_c"] = function(s)
    local cc = cc_get(s)
    return cc and ('58;5;' .. gsub(cc, ';', ':'))
end

-- grey/gray codes
local function gc_get(s)
    local i = tonumber(match(s, "g(%d+)"))
    if not i or i < 0 or i > 23 then return end
    return 232 + i
end
key_to_sgr["g"] = function(s)
    local cc = gc_get(s)
    return cc and ("38;5;" .. cc)
end
key_to_sgr["bg_g"] = function(s)
    local cc = gc_get(s)
    return cc and ("48;5;" .. cc)
end
key_to_sgr["ul_g"] = function(s)
    local cc = gc_get(s)
    return cc and ("58;5:" .. gsub(cc, ';', ':'))
end

-- rgb (r100b100g0)
local function extract_rgb(s)
    local r, g, b = match(s, "r(%d+)g(%d+)b(%d+)")
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
	for _,v in ipairs({r,g,b}) do
		if not v or v > 255 or v < 0 then return end
	end
    return r, g, b
end
key_to_sgr["r"] = function(s)
    local r, g, b = extract_rgb(s)
    return r and format("38;2;%d;%d;%d", r, g, b)
end
key_to_sgr["bg_r"] = function(s)
    local r, g, b = extract_rgb(s)
    return r and format("48;2;%d;%d;%d", r, g, b)
end
key_to_sgr["ul_r"] = function(s)
    local r, g, b = extract_rgb(s)
    return r and format("58;2:%d:%d:%d", r, g, b)
end

-- rgb hex (#ffff00)
local function hex_to_rgb(hex)
    local r, g, b = match(hex, "#(%x%x)(%x%x)(%x%x)")
    r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
	for _,v in ipairs({r,g,b}) do
		if not v or v > 255 or v < 0 then return end
	end
    return r, g, b
end
key_to_sgr["#"] = function(s)
    local r, g, b = hex_to_rgb(s)
    return r and format("38;2;%d;%d;%d", r, g, b)
end
key_to_sgr["bg_#"] = function(s)
    local r, g, b = hex_to_rgb(s)

    return r and format("48;2;%d;%d;%d", r, g, b)
end
key_to_sgr["ul_#"] = function(s)
    local r, g, b = hex_to_rgb(s)
    return r and format("58;2:%d:%d:%d", r, g, b)
end

-- break string of key words into a single SGR request string; lets not send an sgr seq for each one...
local function keys_to_sgr(keys)
	if nxt.strip then return '' end
	local tbl,sn,fc = {} -- tbl of, sequence number, first char
	if keys == true then keys = '' end -- post_keys was set to true for a reset ([0]m)
	for v in gmatch(keys or '', '[%w#_]+') do
		fc, sn = sub(v,1,1), key_to_sgr[v] -- sn assignment test if we have a static entry of the key or not
		if sn then insert(tbl, sn)
		else -- no static entry lets find what we got
			if sfind(v, '[cg]%d+$') then
				if fc == 'c' or fc == 'g' then sn = key_to_sgr[fc](v)
				else sn = key_to_sgr[sub(v,1,4)](v) end
			elseif sfind(v, '#%x%x%x%x%x%x$') then
				if fc == '#' then sn = key_to_sgr['#'](v)
				else sn = key_to_sgr[sub(v,1,4)](v) end
			elseif sfind(v, 'r(%d+)g(%d+)b(%d+)$') then
				if fc == 'r' then sn = key_to_sgr['r'](v)
				else sn = key_to_sgr[sub(v,1,4)](v) end
			end
			if sn then insert(tbl, sn) end
		end
	end
	
	return concat({esc_csi,concat(tbl,';'),'m'})
end

local function codes_to_escape(...)
	local tbl = {}
	for _,v in pairs({...}) do
		local r = gsub(v, "(%%{(.-)})",
			function(s) -- if we want to exapnd out of sgr we just need to check another table below and not just one return
				return keys_to_sgr(s)
			end)
		if r then insert(tbl, r) end
	end
	return concat(tbl)
end
nxt.escape_codes = codes_to_escape

local function compile_sgr(keys, str, post_keys)
	return concat({keys_to_sgr(keys), str or '',post_keys and keys_to_sgr(post_keys) or ''})
end

function nxt.sgr() -- a generator that will produce nxt seq sgr codes
	return setmetatable({}, {
		__call = function(self, keys, str, post_keys) return compile_sgr(keys, str, post_keys) end,
		__index = function(self, key) return rawget(self, key) or keys_to_sgr(key) end
		})
end

nxt.color = nxt.sgr() -- lets assign a generator for ease to the nxt table
nxt.colour = nxt.color

local function nxt_format(fstr, ...) -- translate or strip sequences
	fstr = codes_to_escape(fstr)
	local t = {}
	for i,v in ipairs({...}) do
		v = (type(v) == 'string' and codes_to_escape(v)) or v
		t[i] = v
	end
	return format(fstr, unpack(t))
end
nxt.format = nxt_format
function nxt.writef(fstr, ...) write(nxt_format(fstr, unpack({...}) )) end
function nxt.printf(fstr, ...) write(nxt_format(fstr, unpack({...}) )); flush() end
function nxt.print(...) write(codes_to_escape(...) .. '\r\n'); flush() end

return nxt