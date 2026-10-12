--- lua-nxterm: terminal escape sequences, cursor control and SGR colours.
-- https://github.com/SamOrlando/lua-nxterm  (MIT, Copyright (c) 2024-2026 Sam Orlando)

-- local vars
local read, write, flush = io.read, io.write, io.flush
local tonumber, tostring = tonumber, tostring
local rawget, setmetatable = rawget, setmetatable
local pairs, ipairs, type, select = pairs, ipairs, type, select
local unpack = unpack or table.unpack
local insert, concat = table.insert, table.concat
local format, match, find, sub = string.format, string.match, string.find, string.sub
local gmatch, gsub = string.gmatch, string.gsub
local char = string.char

local esc = char(27) -- all that is holy
local esc_osc = esc .. ']' -- Operating System Command Sequences (ESC])
local esc_csi = esc .. '[' -- Control Sequence Introducer Commands (ESC[)
local bel = char(7)

-- Respect NO_COLOR (https://no-color.org/) unless explicitly overridden
local no_color = os.getenv("NO_COLOR") ~= nil

local nxterm = { -- nxterm vtwtf
	_VERSION     = 'lua-nxterm 0.3.0',
	_DESCRIPTION = 'NXTerminal Handling, Escape Sequences, Cursor, colors and stuff...',
	_COPYRIGHT   = 'Copyright (C) Sam Orlando 2024-2026 - MIT',
	-- options
	strip = no_color, -- when true, all SGR / style sequences become empty strings
	-- constants
	-- char map (reserved for future glyph / box-drawing helpers)
	cm = {},
	-- general module functions
	title = function(s)
		-- OSC 0 is the widely supported "icon name + window title"
		return concat{esc_osc, '0;', (s or ''), bel}
	end,
	reset = function() return esc .. 'c' end,
	erase = function(n) return concat{esc_csi, n or 2, 'J'} end,
	line = {
		erase  = function(n) return concat{esc_csi, n or 2, 'K'} end,
		insert = function(n) return concat{esc_csi, n or 1, 'L'} end,
		delete = function(n) return concat{esc_csi, n or 1, 'M'} end,
	},
	scroll = {
		up   = function(n) return concat{esc_csi, n or 1, 'S'} end,
		down = function(n) return concat{esc_csi, n or 1, 'T'} end,
		region = function(top, bottom) return concat{esc_csi, top or 1, ';', bottom or '', 'r'} end,
	},
	-- column shift (DEC / xterm)
	shift = {
		right = function(n) return concat{esc_csi, n or 1, ' @'} end, -- ICH-like / shift
		left  = function(n) return concat{esc_csi, n or 1, ' A'} end,
	},
	tab     = function(n) return concat{esc_csi, n or 1, 'I'} end,
	backtab = function(n) return concat{esc_csi, n or 1, 'Z'} end,
	char = {
		delete = function(n) return concat{esc_csi, n or 1, 'P'} end,
		erase  = function(n) return concat{esc_csi, n or 1, 'X'} end,
		insert = function(n) return concat{esc_csi, n or 1, '@'} end,
		rep    = function(n) return concat{esc_csi, n or 1, 'b'} end, -- repeat
	},
	mode = {
		-- m = mode number(s), private = true for DEC private modes (the '?')
		set   = function(m, private)
			if not m then return end
			if type(m) == 'table' then m = concat(m, ';') end
			return concat{esc_csi, private and '?' or '', m, 'h'}
		end,
		reset = function(m, private)
			if not m then return end
			if type(m) == 'table' then m = concat(m, ';') end
			return concat{esc_csi, private and '?' or '', m, 'l'}
		end,
		-- Note: final 'r' is scroll region (see scroll.region), not mode restore.
		-- DEC private mode save/restore is not exposed here to avoid that clash.
		ansi = function() return esc .. '<' end, -- VT52: enter ANSI (VT100) mode (ESC <)
		-- DEC special graphics (line drawing) charset in G0: on → ESC ( 0, off → ESC ( B (US-ASCII)
		gpu  = function(on) return esc .. (on and '(0' or '(B') end,
		alt_screen      = function(on) return on and esc_csi..'?1049h' or esc_csi..'?1049l' end,
		bracketed_paste = function(on) return on and esc_csi..'?2004h' or esc_csi..'?2004l' end,
		sync  = function(on) return on and esc_csi..'?2026h' or esc_csi..'?2026l' end,
		focus = function(on) return on and esc_csi..'?1004h' or esc_csi..'?1004l' end,
		wrap  = function(on) return on and esc_csi..'?7h'  or esc_csi..'?7l'  end,
	},
	tty = {
		sane = function() os.execute('stty sane 2>/dev/null') end,
		raw  = function() os.execute('stty raw onlcr -echo 2>/dev/null') end,
		set  = function() end, -- reserved
		get  = function() end, -- reserved
	},
	mouse = { -- normal tracking (?1000) + SGR reporting (?1006)
		on  = function() return esc_csi..'?1000h'..esc_csi..'?1006h' end,
		off = function() return esc_csi..'?1000l'..esc_csi..'?1006l' end,
	},
	cwd = function(path) return concat{esc_osc, '7;file://', path or '', bel} end,
	progress = function(state, pct)
		-- state: 0=hide, 1=normal, 2=error, 3=indeterminate, 4=paused
		if state == 0 or state == 3 then return concat{esc_osc, '9;4;', state, bel} end
		return concat{esc_osc, '9;4;', state, ';', pct or 0, bel}
	end,
	bell = function() return bel end,
}
-- aliases
nxterm.clear = nxterm.erase

-- hyperlink support (OSC 8) - widely supported in modern terminals
-- fix to be text(url) output if stripped
nxterm.link = function(url, text)
	if nxterm.strip then return text or url or '' end
	url = url or ''
	text = text or url
	return concat{esc_osc, '8;;', url, bel, text, esc_osc, '8;;', bel}
end


nxterm.cursor = { -- CURSOR Sequences and Functions
	up      = function(n) return concat{esc_csi, n or 1, 'A'} end,
	down    = function(n) return concat{esc_csi, n or 1, 'B'} end,
	forward = function(n) return concat{esc_csi, n or 1, 'C'} end,
	back    = function(n) return concat{esc_csi, n or 1, 'D'} end,
	nl      = function(n) return concat{esc_csi, n or 1, 'E'} end,
	pl      = function(n) return concat{esc_csi, n or 1, 'F'} end,
	-- absolute / relative column (x) and row (y)
	setx = function(n, absolute) return concat{esc_csi, n or 1, (absolute and 'G') or 'a'} end, -- CHA / HPR
	sety = function(n, absolute) return concat{esc_csi, n or 1, (absolute and 'd') or 'e'} end, -- VPA / VPR
	-- set(col, row)  -- note: first argument is column (x), second is row (y)
	set   = function(x, y) return concat{esc_csi, y or 1, ';', x or 1, 'H'} end,
	-- setlc(line, col) -- standard row;col order
	setlc = function(l, c) return concat{esc_csi, l or 1, ';', c or 1, 'H'} end,
	save     = function() return esc_csi .. 's' end,
	dec_save = function() return esc .. '7' end,
	restore  = function() return esc_csi .. 'u' end,
	dec_restore = function() return esc .. '8' end,
	hide     = function() return esc_csi .. '?25l' end,
	show     = function() return esc_csi .. '?25h' end,
	style    = function(n) return concat{esc_csi, n or 0, 'q'} end, -- DECSCUSR
	get = function()
		write(esc_csi .. '6n')
		flush()
		local c = read(2)
		if c ~= esc_csi then return end
		local r, m = '', 0
		while true do
			c = read(1)
			if not c then return end -- EOF / not a terminal
			if c == 'R' then break end
			m = m + 1
			if m > 16 then return end -- safety
			r = r .. c
		end
		local row, col = match(r, '(%d+);(%d+)')
		if not row then return end
		-- returns {col, row} (x, y)
		return {tonumber(col), tonumber(row)}
	end,
	getlc = function()
		local pos = nxterm.cursor.get()
		if not pos then return end
		return {pos[2], pos[1]} -- {row, col}
	end,
}
local cursor = nxterm.cursor
cursor.right      = cursor.forward
cursor.left       = cursor.back
cursor.next_line  = cursor.nl
cursor.prev_line  = cursor.pl

-- Prefer stty size (fast, no cursor movement). Fall back to the classic cursor probe.
function nxterm.size()
	local f = io.popen('stty size 2>/dev/null')
	if f then
		local s = f:read('*a')
		f:close()
		local rows, cols = match(s or '', '(%d+)%s+(%d+)')
		if rows then
			return {tonumber(cols), tonumber(rows)} -- {width, height} matching original cursor probe
		end
	end
	-- fallback
	local pos = cursor.get()
	if not pos then return end
	write(cursor.set(9999, 9999)); flush()
	local size = cursor.get()
	write(cursor.set(pos[1], pos[2])); flush()
	return size
end
nxterm.mode.size = nxterm.size -- keep old name working

---------------------------------------------------------------------------
-- SGR (Select Graphic Rendition)
---------------------------------------------------------------------------
local key_to_sgr = {
	-- reset
	reset = 0, rf = 0, normal = 0,
	-- styles
	b = 1, bright = 1, bold = 1,
	shadow = '1:2', -- mintty
	dim = 2, faint = 2,
	italic = 3, i = 3,
	under = 4, ul = 4, underline = 4,
	ul_single = '4:1', ul_double = '4:2', ul_wavy = '4:3', ul_dot = '4:4', ul_dash = '4:5',
	blink = 5, blink_slow = 5,
	blink_fast = 6, blink_rapid = 6, rapid_blink = 6,
	inverse = 7, reverse = 7,
	hide = 8,
	strike = 9,
	fraktur = 20,
	-- note: classic double-underline is also 21; we keep the modern 4:2 form above
	b_off = 22, bright_off = 22, bold_off = 22, shadow_off = 22,
	italic_off = 23, i_off = 23, fraktur_off = 23,
	under_off = 24, ul_off = 24, underline_off = 24,
	blink_off = 25,
	proportional = 26,
	inverse_off = 27, reverse_off = 27,
	unhide = 28, hide_off = 28,
	strike_off = 29,
	-- foreground (standard)
	black = 30, red = 31, green = 32, yellow = 33, brown = 33,
	blue = 34, magenta = 35, cyan = 36, white = 37,
	default = 39, fg_reset = 39, fg_default = 39,
	-- background (standard)
	bg_black = 40, bg_red = 41, bg_green = 42, bg_yellow = 43, bg_brown = 43,
	bg_blue = 44, bg_magenta = 45, bg_cyan = 46, bg_white = 47,
	bg_default = 49, bg_reset = 49, bg_off = 49,
	-- ansicolors compatibility aliases
	-- kikito/ansicolors.lua: hidden, <color>bg
	hidden = 8,
	blackbg = 40, redbg = 41, greenbg = 42, yellowbg = 43,
	bluebg = 44, magentabg = 45, cyanbg = 46, whitebg = 47,
	-- hoelzro/ansicolors: clear, underscore, on<color>
	clear = 0, underscore = 4,
	onblack = 40, onred = 41, ongreen = 42, onyellow = 43,
	onblue = 44, onmagenta = 45, oncyan = 46, onwhite = 47,
	-- extended
	proportional_off = 50,
	frame = 51, encircle = 52,
	over = 53, ol = 53,
	frame_off = 54, encircle_off = 54,
	over_off = 55, ol_off = 55,
	under_default = 59, ul_default = 59, ul_reset = 59, under_reset = 59,
	sup = 73, super = 73,
	sub = 74,
	script_off = 75,
	-- bright foreground
	grey = 90, gray = 90, black_b = 90,
	red_b = 91, green_b = 92, yellow_b = 93, brown_b = 93,
	blue_b = 94, magenta_b = 95, cyan_b = 96, white_b = 97,
	-- bright background
	bg_grey = 100, bg_gray = 100, bg_black_b = 100,
	bg_red_b = 101, bg_green_b = 102, bg_yellow_b = 103, bg_brown_b = 103,
	bg_blue_b = 104, bg_magenta_b = 105, bg_cyan_b = 106, bg_white_b = 107,
}

-- 256-color palette helpers
local function cc_get(s)
	local cc = tonumber(match(s, 'c(%d+)$'))
	if not cc or cc < 0 or cc > 255 then return end
	return cc
end
key_to_sgr.c = function(s)
	local cc = cc_get(s)
	return cc and ('38;5;' .. cc)
end
key_to_sgr.bg_c = function(s)
	local cc = cc_get(s)
	return cc and ('48;5;' .. cc)
end
key_to_sgr.ul_c = function(s)
	local cc = cc_get(s)
	return cc and ('58;5;' .. cc)
end

-- greyscale (g0 .. g23 → 232 .. 255)
local function gc_get(s)
	local i = tonumber(match(s, 'g(%d+)$'))
	if not i or i < 0 or i > 23 then return end
	return 232 + i
end
key_to_sgr.g = function(s)
	local cc = gc_get(s)
	return cc and ('38;5;' .. cc)
end
key_to_sgr.bg_g = function(s)
	local cc = gc_get(s)
	return cc and ('48;5;' .. cc)
end
key_to_sgr.ul_g = function(s)
	local cc = gc_get(s)
	return cc and ('58;5;' .. cc)
end

-- truecolor r100g50b0
local function extract_rgb(s)
	local r, g, b = match(s, 'r(%d+)g(%d+)b(%d+)$')
	r, g, b = tonumber(r), tonumber(g), tonumber(b)
	if not (r and g and b) then return end
	if r < 0 or r > 255 or g < 0 or g > 255 or b < 0 or b > 255 then return end
	return r, g, b
end
key_to_sgr.r = function(s)
	local r, g, b = extract_rgb(s)
	return r and format('38;2;%d;%d;%d', r, g, b)
end
key_to_sgr.bg_r = function(s)
	local r, g, b = extract_rgb(s)
	return r and format('48;2;%d;%d;%d', r, g, b)
end
key_to_sgr.ul_r = function(s)
	local r, g, b = extract_rgb(s)
	return r and format('58;2;%d;%d;%d', r, g, b)
end

-- hex #rrggbb or short #rgb
local function hex_to_rgb(hex)
	local r, g, b
	r, g, b = match(hex, '#(%x%x)(%x%x)(%x%x)$')
	if r then
		r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
	else
		-- short form #rgb → #rrggbb
		r, g, b = match(hex, '#(%x)(%x)(%x)$')
		if not r then return end
		r = tonumber(r .. r, 16)
		g = tonumber(g .. g, 16)
		b = tonumber(b .. b, 16)
	end
	if not (r and g and b) or r > 255 or g > 255 or b > 255 then return end
	return r, g, b
end
key_to_sgr['#'] = function(s)
	local r, g, b = hex_to_rgb(s)
	return r and format('38;2;%d;%d;%d', r, g, b)
end
key_to_sgr['bg_#'] = function(s)
	local r, g, b = hex_to_rgb(s)
	return r and format('48;2;%d;%d;%d', r, g, b)
end
key_to_sgr['ul_#'] = function(s)
	local r, g, b = hex_to_rgb(s)
	return r and format('58;2;%d;%d;%d', r, g, b)
end

-- Resolve key tokens to a list of SGR parameter fragments (no CSI wrapper).
-- e.g. "red bold" → {"31","1"}   "c88" → {"38;5;88"}   "" → {}
-- Unknown or out-of-range tokens are ignored. Results are memoised per key string.
local prefixes = { [''] = true, bg_ = true, ul_ = true }
local function resolve_token(v)
	local sn = key_to_sgr[v]
	if sn ~= nil and type(sn) ~= 'function' then return sn end
	-- dynamic forms: [bg_|ul_](cN | gN | #hex | rNgNbN)
	local pre, body = match(v, '^(%a%a_)(.+)$')
	if not (pre and prefixes[pre]) then pre, body = '', v end
	local kind
	if match(body, '^#%x+$') then kind = '#'
	elseif match(body, '^c%d+$') then kind = 'c'
	elseif match(body, '^g%d+$') then kind = 'g'
	elseif match(body, '^r%d+g%d+b%d+$') then kind = 'r'
	end
	local fn = kind and key_to_sgr[pre .. kind]
	return fn and fn(body) or nil
end

local params_cache = setmetatable({}, { __mode = 'k' })
local function keys_to_sgr_params(keys)
	if keys == true then keys = '' end -- historical: true → reset
	keys = keys or ''
	local tbl = params_cache[keys]
	if tbl then return tbl end
	tbl = {}
	for v in gmatch(keys, '[%w#_]+') do
		local sn = resolve_token(v)
		if sn then tbl[#tbl + 1] = tostring(sn) end
	end
	if type(keys) == 'string' then params_cache[keys] = tbl end
	return tbl
end

-- Convert a whitespace (or any non [%w#_]) separated list of keys into a single SGR sequence.
-- Empty key list still emits ESC[m (equivalent to reset / SGR 0).
local function keys_to_sgr(keys)
	if nxterm.strip then return '' end
	local tbl = keys_to_sgr_params(keys)
	return concat{esc_csi, concat(tbl, ';'), 'm'}
end

function nxterm.escape_codes(...)
	local n = select('#', ...)
	local tbl = {keys_to_sgr('reset')}
	for i = 1, n do
		local v = select(i, ...)
		if type(v) == 'string' then
			insert(tbl, (gsub(v, '%%{(.-)}', keys_to_sgr)))
		end
	end
	insert(tbl, keys_to_sgr('reset'))
	return concat(tbl)
end
local codes_to_escape = nxterm.escape_codes

function nxterm.escape_strip(...)
	local n = select('#', ...)
	local tbl = {}
	for i = 1, n do
		local v = select(i, ...)
		if type(v) == 'string' then
			insert(tbl, (gsub(v, '%%{(.-)}', '')))
		end
	end
	return concat(tbl)
end

local function compile_sgr(keys, str, post_keys)
	return concat{
		keys_to_sgr(keys),
		str or '',
		post_keys and keys_to_sgr(post_keys) or ''
	}
end

---------------------------------------------------------------------------
-- Fluent / chainable SGR builder
-- Accumulates raw SGR parameters so chaining emits ONE sequence:
--   sc.red.bold  →  ESC[31;1m   (not ESC[31mESC[1m)
--
--   color.red.bold("hello")          → styled + auto-reset
--   tostring(color.red.bold)         → just the sequence
--   color.red.bold .. "text"         → works via __concat
--   color("red bold") / color'red bold ul'  → classic key form (returns sequence)
--   color("red bold", "text", true)  → classic wrap form
---------------------------------------------------------------------------
local sgr_objects = {} -- params string → shared immutable builder object
local make_sgr

local function make_sgr_mt(params)
	-- params = semicolon-joined SGR parameter string, e.g. "31;1;4"
	local function emit()
		if nxterm.strip then return '' end
		return concat{esc_csi, params, 'm'}
	end
	return {
		__index = function(_, key)
			if type(key) ~= 'string' then return nil end
			local add = keys_to_sgr_params(key)
			if #add == 0 then return make_sgr(params) end
			local joined = concat(add, ';')
			return make_sgr(params == '' and joined or (params .. ';' .. joined))
		end,
		__call = function(_, a, b, c)
			if params == '' then
				-- Base object: classic form
				--   sc("red bold")          → sequence only
				--   sc("red bold", "text")  → sequence + text
				--   sc("red bold", "text", "reset") → full wrap
				return compile_sgr(a, b, c)
			end
			-- Fluent chain already has styles accumulated
			--   sc.red.bold("text")     → styles + text + reset
			--   sc.red.bold()           → just the accumulated sequence
			if a == nil then return emit() end
			return emit() .. tostring(a) .. keys_to_sgr('reset')
		end,
		__tostring = emit,
		__concat = function(a, b)
			return tostring(a) .. tostring(b)
		end,
		__newindex = function() error('nxterm: colour builder objects are read-only', 2) end,
	}
end

make_sgr = function(params)
	params = params or ''
	local o = sgr_objects[params]
	if not o then
		o = setmetatable({}, make_sgr_mt(params))
		sgr_objects[params] = o
	end
	return o
end

function nxterm.sgr()
	return make_sgr('')
end

nxterm.color  = nxterm.sgr()
nxterm.colour = nxterm.color

---------------------------------------------------------------------------
-- ansicolors drop-in (kikito/ansicolors.lua, LuaRocks "ansicolors" 1.0.2)
--   local colors = require('nxterm').ansicolors
--   colors('%{red}hello')          → ESC[0m ESC[31m hello ESC[0m
--   colors.noReset('%{red}hello')  → ESC[31m hello
-- Byte-for-byte compatible with ansicolors: one ESC[<n>m per key, strict
-- (unknown keys raise "Unknown key: <word>"). nxterm keys (bg_red, c88,
-- #ff8800, r1g2b3, ...) are accepted too. Honours nxterm.strip / NO_COLOR.
---------------------------------------------------------------------------
local function ac_escape_keys(keys)
	if nxterm.strip then return '' end
	local buf = {}
	for word in gmatch(keys, '[%w#_]+') do
		local sn = resolve_token(word)
		if sn ~= nil then
			buf[#buf + 1] = concat{esc_csi, sn, 'm'}
		else
			-- ansicolors splits on non-alphanumerics: bright_red = bright + red
			for part in gmatch(word, '%w+') do
				local p = resolve_token(part)
				if p == nil then error('Unknown key: ' .. part, 0) end
				buf[#buf + 1] = concat{esc_csi, p, 'm'}
			end
		end
	end
	return concat(buf)
end

local function ac_replace_codes(str)
	local t = type(str)
	if t ~= 'string' and t ~= 'number' then
		error("bad argument #1 to 'noReset' (string expected, got " .. (t == 'nil' and 'no value' or t) .. ")", 2)
	end
	return (gsub(str, '%%{(.-)}', ac_escape_keys))
end

nxterm.ansicolors = setmetatable({ noReset = ac_replace_codes }, {
	__call = function(_, str)
		str = tostring(str or '')
		return ac_replace_codes('%{reset}' .. str .. '%{reset}')
	end,
})

function nxterm.format(fstr, ...)
	fstr = codes_to_escape(fstr)
	local n = select('#', ...)
	local t = {}
	for i = 1, n do
		local v = select(i, ...)
		-- expand %{} markers in string arguments without the reset brackets,
		-- so an argument does not cancel the style set by the format string
		t[i] = (type(v) == 'string') and (gsub(v, '%%{(.-)}', keys_to_sgr)) or v
	end
	return format(fstr, unpack(t))
end
local nxt_format = nxterm.format

function nxterm.writef(fstr, ...)
	write(nxt_format(fstr, ...))
end
function nxterm.printf(fstr, ...)
	write(nxt_format(fstr, ...) .. '\r\n')
	flush()
end
function nxterm.print(...)
	write(codes_to_escape(...) .. '\r\n')
	flush()
end

return nxterm