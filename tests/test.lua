-- Plain-Lua test suite for lua-nxterm (Lua 5.1-5.4, LuaJIT). Run: lua tests/test.lua
local dir = (arg and arg[0] or ''):match('^(.*)[/\\]tests[/\\][^/\\]*$') or '.'
package.path = dir .. '/?.lua;' .. package.path

local nxterm = require('nxterm')
nxterm.strip = false -- tests must not depend on the caller's NO_COLOR

local E, CSI, OSC, BEL = '\27', '\27[', '\27]', '\7'
local passed, failed = 0, 0
local function eq(name, got, want)
	if got == want then passed = passed + 1
	else
		failed = failed + 1
		local function show(v) return type(v) == 'string' and (v:gsub('\27', '\\27'):gsub('\7', '\\7')) or tostring(v) end
		io.stderr:write(('FAIL %s\n  got:  %s\n  want: %s\n'):format(name, show(got), show(want)))
	end
end
local function errors(name, fn)
	local ok = pcall(fn)
	eq(name .. ' raises', ok, false)
end

local sc = nxterm.color

-- metadata
eq('version', nxterm._VERSION, 'lua-nxterm 0.3.0')
eq('colour alias', nxterm.colour, sc)
eq('clear alias', nxterm.clear, nxterm.erase)

-- basic SGR
eq('fluent single', tostring(sc.red), CSI .. '31m')
eq('fluent chain one sequence', tostring(sc.red.bold.ul), CSI .. '31;1;4m')
eq('fluent call wraps', sc.red.bold('x'), CSI .. '31;1mx' .. CSI .. '0m')
eq('fluent call no args', sc.red.bold(), CSI .. '31;1m')
eq('fluent call number', sc.green(5), CSI .. '32m5' .. CSI .. '0m')
eq('concat right', sc.red .. 'x', CSI .. '31mx')
eq('concat left', 'x' .. sc.red, 'x' .. CSI .. '31m')
eq('index multi-key', tostring(sc['red bold']), CSI .. '31;1m')
eq('unknown key ignored', tostring(sc.nope.red), CSI .. '31m')
eq('builder cached', sc.red.bold, sc.red.bold)
errors('builder read-only', function() sc.red.foo = 1 end)
eq('classic seq', sc'red bold ul', CSI .. '31;1;4m')
eq('classic text', sc('red', 'x'), CSI .. '31mx')
eq('classic wrap', sc('red', 'x', 'reset'), CSI .. '31mx' .. CSI .. '0m')
eq('empty is reset', sc'', CSI .. 'm')
eq('true is reset', sc(true), CSI .. 'm')
eq('nil is reset', sc(), CSI .. 'm')
eq('base tostring', tostring(sc), CSI .. 'm')

-- colours
eq('256 fg', sc'c88', CSI .. '38;5;88m')
eq('256 bg', sc'bg_c88', CSI .. '48;5;88m')
eq('256 ul', sc'ul_c88', CSI .. '58;5;88m')
eq('256 out of range', sc'c256', CSI .. 'm')
eq('grey', sc'g0 g23', CSI .. '38;5;232;38;5;255m')
eq('grey bg/ul', sc'bg_g10 ul_g1', CSI .. '48;5;242;58;5;233m')
eq('grey out of range', sc'g24', CSI .. 'm')
eq('rgb', sc'r200g100b20', CSI .. '38;2;200;100;20m')
eq('rgb bg', sc'bg_r1g2b3', CSI .. '48;2;1;2;3m')
eq('rgb ul', sc'ul_r1g2b3', CSI .. '58;2;1;2;3m')
eq('rgb out of range', sc'r256g0b0', CSI .. 'm')
eq('hex', sc'#BB0066', CSI .. '38;2;187;0;102m')
eq('hex short', sc'#f0c', CSI .. '38;2;255;0;204m')
eq('hex bg/ul', sc'bg_#003366 ul_#ff0', CSI .. '48;2;0;51;102;58;2;255;255;0m')
eq('hex ending in cN (regression)', sc'#00cc33', CSI .. '38;2;0;204;51m')
eq('hex ending in gN-like', sc'#a1c3e9', CSI .. '38;2;161;195;233m')
eq('hex bad length (regression)', sc'#12345', CSI .. 'm')
eq('bare dynamic prefixes ignored (regression)', sc'c g r bg_c ul_r #', CSI .. 'm')
eq('bare c via index (regression)', tostring(sc.c), CSI .. 'm')
eq('styles', sc'bold dim italic strike inverse', CSI .. '1;2;3;9;7m')
eq('ul styles', sc'ul_wavy ul_reset', CSI .. '4:3;59m')
eq('bright', sc'red_b bg_grey', CSI .. '91;100m')

-- strip / NO_COLOR
nxterm.strip = true
eq('strip classic', sc'red', '')
eq('strip fluent', tostring(sc.red.bold), '')
eq('strip fluent call', sc.red('x'), 'x')
eq('strip escape_codes', nxterm.escape_codes('%{red}x%{}'), 'x')
eq('strip link', nxterm.link('https://e.x', 'e'), 'e')
eq('strip link url only', nxterm.link('https://e.x'), 'https://e.x')
nxterm.strip = false

-- embedding / formatting
local R = CSI .. '0m'
eq('escape_codes', nxterm.escape_codes('a%{red}b%{}c'), R .. 'a' .. CSI .. '31mb' .. CSI .. 'mc' .. R)
eq('escape_codes multi', nxterm.escape_codes('a', 1, 'b'), R .. 'ab' .. R)
eq('escape_strip', nxterm.escape_strip('a%{red bold}b%{}c', 'd'), 'abcd')
eq('format', nxterm.format('%{green}%s=%d', 'n', 3), R .. CSI .. '32mn=3' .. R)
eq('format arg markers', nxterm.format('%s', '%{red}x'), R .. CSI .. '31mx' .. R)
eq('format percent literal', nxterm.format('%d%%', 5), R .. '5%' .. R)

-- cursor
local cur = nxterm.cursor
eq('up', cur.up(), CSI .. '1A');      eq('up n', cur.up(3), CSI .. '3A')
eq('down', cur.down(2), CSI .. '2B')
eq('forward/right', cur.right(4), CSI .. '4C')
eq('back/left', cur.left(), CSI .. '1D')
eq('nl/pl', cur.next_line(2) .. cur.prev_line(), CSI .. '2E' .. CSI .. '1F')
eq('set x,y', cur.set(10, 5), CSI .. '5;10H')
eq('setlc', cur.setlc(5, 10), CSI .. '5;10H')
eq('setx abs/rel', cur.setx(3, true) .. cur.setx(3), CSI .. '3G' .. CSI .. '3a')
eq('sety abs/rel', cur.sety(3, true) .. cur.sety(3), CSI .. '3d' .. CSI .. '3e')
eq('save/restore', cur.save() .. cur.restore(), CSI .. 's' .. CSI .. 'u')
eq('dec save/restore', cur.dec_save() .. cur.dec_restore(), E .. '7' .. E .. '8')
eq('hide/show', cur.hide() .. cur.show(), CSI .. '?25l' .. CSI .. '?25h')
eq('style', cur.style(5), CSI .. '5q')

-- screen / lines / scroll / chars
eq('reset', nxterm.reset(), E .. 'c')
eq('erase', nxterm.erase(), CSI .. '2J')
eq('line erase', nxterm.line.erase(0), CSI .. '0K')
eq('line insert/delete', nxterm.line.insert(2) .. nxterm.line.delete(), CSI .. '2L' .. CSI .. '1M')
eq('scroll', nxterm.scroll.up(2) .. nxterm.scroll.down(), CSI .. '2S' .. CSI .. '1T')
eq('scroll region', nxterm.scroll.region(2, 20), CSI .. '2;20r')
eq('scroll region reset', nxterm.scroll.region(), CSI .. '1;r')
eq('shift', nxterm.shift.right(2) .. nxterm.shift.left(), CSI .. '2 @' .. CSI .. '1 A')
eq('tab/backtab', nxterm.tab() .. nxterm.backtab(2), CSI .. '1I' .. CSI .. '2Z')
eq('char ops', nxterm.char.insert() .. nxterm.char.delete(2) .. nxterm.char.erase(3) .. nxterm.char.rep(4),
	CSI .. '1@' .. CSI .. '2P' .. CSI .. '3X' .. CSI .. '4b')

-- modes
local m = nxterm.mode
eq('mode set', m.set(4), CSI .. '4h')
eq('mode set private', m.set(7, true), CSI .. '?7h')
eq('mode reset private', m.reset(7, true), CSI .. '?7l')
eq('mode set list', m.set({1049, 2004}, true), CSI .. '?1049;2004h')
eq('mode set nil', m.set(), nil)
eq('alt screen', m.alt_screen(true) .. m.alt_screen(false), CSI .. '?1049h' .. CSI .. '?1049l')
eq('bracketed paste', m.bracketed_paste(true), CSI .. '?2004h')
eq('sync', m.sync(false), CSI .. '?2026l')
eq('focus', m.focus(true), CSI .. '?1004h')
eq('wrap', m.wrap(false), CSI .. '?7l')
eq('ansi (regression)', m.ansi(), E .. '<')
eq('gpu (regression)', m.gpu(true) .. m.gpu(false), E .. '(0' .. E .. '(B')
eq('mode.size alias', m.size, nxterm.size)
eq('mouse', nxterm.mouse.on() .. nxterm.mouse.off(), CSI .. '?1000h' .. CSI .. '?1006h' .. CSI .. '?1000l' .. CSI .. '?1006l')

-- OSC
eq('title', nxterm.title('hi'), OSC .. '0;hi' .. BEL)
eq('cwd', nxterm.cwd('/tmp'), OSC .. '7;file:///tmp' .. BEL)
eq('link', nxterm.link('https://e.x', 'e'), OSC .. '8;;https://e.x' .. BEL .. 'e' .. OSC .. '8;;' .. BEL)
eq('progress', nxterm.progress(1, 40), OSC .. '9;4;1;40' .. BEL)
eq('progress hide', nxterm.progress(0), OSC .. '9;4;0' .. BEL)
eq('bell', nxterm.bell(), BEL)


-- ansicolors compatibility (expected bytes taken from kikito/ansicolors.lua 1.0.2)
do
	local ac = nxterm.ansicolors
	eq('ac call', ac('%{red}hello'), CSI .. '0m' .. CSI .. '31mhello' .. CSI .. '0m')
	eq('ac one seq per key', ac('%{bright red}x'), CSI .. '0m' .. CSI .. '1m' .. CSI .. '31mx' .. CSI .. '0m')
	eq('ac underscore split', ac('%{bright_red}x'), CSI .. '0m' .. CSI .. '1m' .. CSI .. '31mx' .. CSI .. '0m')
	eq('ac comma list', ac('%{red,bright}x'), CSI .. '0m' .. CSI .. '31m' .. CSI .. '1mx' .. CSI .. '0m')
	eq('ac empty braces', ac('%{}x'), CSI .. '0mx' .. CSI .. '0m')
	eq('ac plain', ac('plain'), CSI .. '0mplain' .. CSI .. '0m')
	eq('ac nil', ac(nil), CSI .. '0m' .. CSI .. '0m')
	eq('ac number', ac(42), CSI .. '0m42' .. CSI .. '0m')
	eq('ac boolean', ac(true), CSI .. '0mtrue' .. CSI .. '0m')
	eq('ac tostring obj', ac(setmetatable({}, { __tostring = function() return '%{blue}o' end })),
		CSI .. '0m' .. CSI .. '34mo' .. CSI .. '0m')
	eq('ac hidden + bg', ac('%{hidden redbg whitebg}x'), CSI .. '0m' .. CSI .. '8m' .. CSI .. '41m' .. CSI .. '47mx' .. CSI .. '0m')
	eq('ac noReset', ac.noReset('%{red}hello'), CSI .. '31mhello')
	eq('ac noReset plain', ac.noReset('plain'), 'plain')
	eq('ac noReset empty braces', ac.noReset('%{}'), '')
	eq('ac noReset number', ac.noReset(7), '7')
	eq('ac nxterm keys accepted', ac.noReset('%{bg_red c88 #ff0000}x'), CSI .. '41m' .. CSI .. '38;5;88m' .. CSI .. '38;2;255;0;0mx')
	local ok, err = pcall(ac, '%{red nope}x')
	eq('ac unknown key raises', ok, false); eq('ac unknown key message', err, 'Unknown key: nope')
	ok, err = pcall(ac.noReset, '%{bg red}x')
	eq('ac unknown part raises', ok, false); eq('ac unknown part message', err, 'Unknown key: bg')
	errors('ac noReset nil', function() return ac.noReset(nil) end)
	errors('ac noReset table', function() return ac.noReset({}) end)
	-- the rest of nxterm stays lenient
	eq('lenient escape_codes', nxterm.escape_codes('%{nope}x'), (CSI .. '0m') .. CSI .. 'mx' .. (CSI .. '0m'))
	nxterm.strip = true
	eq('ac strip', ac('%{red}x'), 'x'); eq('ac noReset strip', ac.noReset('%{red}x'), 'x')
	nxterm.strip = false
	-- aliases (kikito + hoelzro names) on the regular API
	eq('alias hidden', sc'hidden', CSI .. '8m')
	eq('alias kikito bg', sc'blackbg redbg greenbg yellowbg bluebg magentabg cyanbg whitebg', CSI .. '40;41;42;43;44;45;46;47m')
	eq('alias hoelzro', sc'clear underscore onblack onred ongreen onyellow onblue onmagenta oncyan onwhite',
		CSI .. '0;4;40;41;42;43;44;45;46;47m')
	-- hoelzro/ansicolors call forms
	eq('hoelzro concat', sc.red .. 'x' .. sc.reset, CSI .. '31mx' .. CSI .. '0m')
	eq('hoelzro call', sc.red('x'), CSI .. '31mx' .. CSI .. '0m')
	eq('hoelzro tostring', tostring(sc.onblue), CSI .. '44m')
end

-- sgr() constructor returns the shared base builder
eq('sgr()', tostring(nxterm.sgr().blue), CSI .. '34m')

print(('%s: %d passed, %d failed'):format(_VERSION .. (jit and (' / ' .. jit.version) or ''), passed, failed))
os.exit(failed == 0 and 0 or 1)
