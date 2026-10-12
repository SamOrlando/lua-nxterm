-- Compares require('nxterm') (called as a function, and .noReset) against
-- kikito/ansicolors.lua 1.0.2. Each case is either byte-identical, or renders
-- identically (same text with the same attributes: nxterm merges keys into one
-- sequence and expands an empty %{} to ESC[m), or is the documented difference
-- (ansicolors raises on unknown keys, nxterm ignores them; an unterminated
-- '%{' swallows ansicolors' trailing reset). Anything else fails.
-- Needs the real module: luarocks install ansicolors   (skipped when missing)
-- Run: lua tests/test_ansicolors_compat.lua
local dir = (arg and arg[0] or ''):match('^(.*)[/\\]tests[/\\][^/\\]*$') or '.'
package.path = dir .. '/?.lua;' .. package.path

local ok_ac, ac = pcall(require, 'ansicolors')
if not ok_ac then print('ansicolors not installed; compat test skipped') os.exit(0) end
local nxterm = require('nxterm')
nxterm.strip = false
local nx = nxterm

local keys = { 'reset', 'bright', 'dim', 'underline', 'blink', 'reverse', 'hidden',
	'black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white',
	'blackbg', 'redbg', 'greenbg', 'yellowbg', 'bluebg', 'magentabg', 'cyanbg', 'whitebg' }

local cases = { '', 'plain', 'no markup %s %d', '%{}', '%{}x', '%{ }x', 'a%{red}b%{reset}c',
	'%{bright red}x%{reset} y', '%{red,bright}x', '%{ red , bright }x', '%{bright_red}x',
	'%{red}%{green}%{blue}x', '%{redbg white}x', '%{underline blink reverse dim hidden}x',
	'%{red}nested %{bright}%{bluebg}deep%{reset} out', '100%{red}%%', '%{red}x\n%{green}y\n',
	'%{red', 'red}', '%{{red}}', '%%{red}', 42, 3.5, 0, true, false }
for _, k in ipairs(keys) do
	cases[#cases + 1] = '%{' .. k .. '}x'
	for _, k2 in ipairs(keys) do cases[#cases + 1] = '%{' .. k .. ' ' .. k2 .. '}x%{reset}y' end
end

local passed, failed = 0, 0
local stats = { bytes = 0, rendered = 0, unknown_key = 0, unterminated = 0 }

-- simulate SGR: returns a list of "char|attrs" plus the final attrs
local function render(str)
	local st, out, i = {}, {}, 1
	local function attrs()
		local k = {}
		for a, v in pairs(st) do k[#k + 1] = a .. '=' .. v end
		table.sort(k); return table.concat(k, ',')
	end
	local function apply(params)
		if params == '' then params = '0' end
		local list = {}
		for p in (params .. ';'):gmatch('([^;]*);') do list[#list + 1] = p end
		local j = 1
		while j <= #list do
			local n = tonumber(list[j]:match('^%d+')) or 0
			if n == 0 then st = {}
			elseif n == 38 or n == 48 or n == 58 then
				local key = n == 38 and 'fg' or n == 48 and 'bg' or 'ul'
				if list[j + 1] == '5' then st[key] = '5:' .. list[j + 2]; j = j + 2
				else st[key] = '2:' .. list[j + 2] .. ':' .. list[j + 3] .. ':' .. list[j + 4]; j = j + 4 end
			elseif (n >= 30 and n <= 37) or (n >= 90 and n <= 97) then st.fg = n
			elseif n == 39 then st.fg = nil
			elseif (n >= 40 and n <= 47) or (n >= 100 and n <= 107) then st.bg = n
			elseif n == 49 then st.bg = nil
			else st['a' .. list[j]] = 1 end
			j = j + 1
		end
	end
	while i <= #str do
		local s2, e2, params = str:find('^\27%[([%d;:]*)m', i)
		if s2 then apply(params); i = e2 + 1
		else out[#out + 1] = str:sub(i, i) .. '|' .. attrs(); i = i + 1 end
	end
	return table.concat(out, '\n') .. '\nEND|' .. attrs()
end

local function show(v) return (tostring(v):gsub('\27', '\\27')) end
local function cmp(name, f1, f2, arg)
	local ok1, r1 = pcall(f1, arg)
	local ok2, r2 = pcall(f2, arg)
	local kind
	if ok1 and ok2 then
		if r1 == r2 then kind = 'bytes' elseif render(r1) == render(r2) then kind = 'rendered' end
		-- ansicolors expands '%{reset}' .. str .. '%{reset}' as one string, so an
		-- unterminated '%{' in str swallows the trailing reset; nxterm keeps it as text
		if not kind and type(arg) == 'string' and arg:find('%{', 1, true) and not arg:find('%%{.-}') then kind = 'unterminated' end
	elseif not ok1 and ok2 and tostring(r1):match('Unknown key: ') then kind = 'unknown_key'
	elseif not ok1 and not ok2 then kind = 'bytes' end
	if kind then passed = passed + 1; stats[kind] = stats[kind] + 1 else
		failed = failed + 1
		io.stderr:write(('FAIL %s %s\n  ansicolors: %s %s\n  nxterm:     %s %s\n'):format(name, show(arg), tostring(ok1), show(r1), tostring(ok2), show(r2)))
	end
end

for _, c in ipairs(cases) do
	cmp('call', ac, nx, c)
	if type(c) == 'string' or type(c) == 'number' then cmp('noReset', ac.noReset, nx.noReset, c) end
end
cmp('call nil', ac, nx, nil)
for _, bad in ipairs({ '%{nope}x', '%{red nope}x', '%{bright_nope}x', '%{bg red}x' }) do
	cmp('error', ac, nx, bad); cmp('error noReset', ac.noReset, nx.noReset, bad)
end
-- tostring on objects with __tostring
local obj = setmetatable({}, { __tostring = function() return '%{red}T' end })
cmp('tostring obj', ac, nx, obj)
-- noReset with non-string/number errors in both
for _, v in ipairs({ {}, true }) do
	local ok1 = pcall(ac.noReset, v); local ok2 = pcall(nx.noReset, v)
	if ok1 == ok2 then passed = passed + 1 else failed = failed + 1; io.stderr:write('FAIL noReset error on ' .. type(v) .. '\n') end
end
do local ok1 = pcall(ac.noReset); local ok2 = pcall(nx.noReset)
	if ok1 == ok2 then passed = passed + 1 else failed = failed + 1; io.stderr:write('FAIL noReset() no arg\n') end end

print(('%s ansicolors compat: %d passed (%d byte-identical, %d same rendering, %d unknown-key, %d unterminated-%%{ difference), %d failed'):format(
	_VERSION .. (jit and ' / LuaJIT' or ''), passed, stats.bytes, stats.rendered, stats.unknown_key, stats.unterminated, failed))
os.exit(failed == 0 and 0 or 1)
