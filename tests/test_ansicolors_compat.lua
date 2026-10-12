-- Byte-for-byte comparison of nxterm.ansicolors against kikito/ansicolors.lua.
-- Needs the real module: luarocks install ansicolors   (skipped when missing)
-- Run: lua tests/test_ansicolors_compat.lua
local dir = (arg and arg[0] or ''):match('^(.*)[/\\]tests[/\\][^/\\]*$') or '.'
package.path = dir .. '/?.lua;' .. package.path

local ok_ac, ac = pcall(require, 'ansicolors')
if not ok_ac then print('ansicolors not installed; compat test skipped') os.exit(0) end
local nxterm = require('nxterm')
nxterm.strip = false
local nx = nxterm.ansicolors

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
local function show(v) return (tostring(v):gsub('\27', '\\27')) end
local function cmp(name, f1, f2, arg)
	local ok1, r1 = pcall(f1, arg)
	local ok2, r2 = pcall(f2, arg)
	local same
	if ok1 and ok2 then same = (r1 == r2)
	elseif not ok1 and not ok2 then
		-- compare the message text after the "file:line: " prefix ansicolors adds
		local m1 = tostring(r1):match('(Unknown key: .*)$')
		same = (m1 == nil) or (m1 == tostring(r2):match('(Unknown key: .*)$'))
	else same = false end
	if same then passed = passed + 1 else
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

print(('%s ansicolors compat: %d passed, %d failed'):format(_VERSION .. (jit and ' / LuaJIT' or ''), passed, failed))
os.exit(failed == 0 and 0 or 1)
