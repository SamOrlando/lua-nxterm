-- local vars
local nxtui = {
	_VERSION	 = 'lua-nxtui',
	_DESCRIPTION = 'NXTerminal User Interface Stuff <stuff: shapes and dialogs>',
	_COPYRIGHT   = 'Copyright (C) Sam Orlando 2024 - MIT is for sellouts.',
}

-- https://github.com/sindresorhus/cli-spinners/blob/main/spinners.json
-- https://github.com/Absolpega/lua-askpass/blob/main/askpass.lua

local format, match, sub, rep, lower = string.format, string.match, string.sub, string.rep, string.lower
local gmatch, gsub = string.gmatch, string.gsub, string.sub
local insert, concat = table.insert, table.concat
local unpack = unpack or table.unpack
local tonumber = tonumber
local rawget, rawset, getmetatable, setmetatable = rawget, rawset, getmetatable, setmetatable
local pairs, ipairs, type = pairs, ipairs, type
local read, write, flush = io.read, io.write, io.flush

local nxterm = require('nxterm')
local sc, cf, cc = nxterm.color, nxterm.format, nxterm.cursor -- screen control, colored format, cursor control

local bool_false = {["0"] = true, ["false"] = true, ["f"] = true, ["no"] = true, ["n"] = true, ["off"] = true, ["disable"] = true, ["disabled"] = true}
local function tobool(b)
	if b == nil then return false end
	local tst = type(b)
	if tst == 'boolean' then return b
	elseif tst == 'number' then
		return b ~= 0
	elseif tst == 'string' then
		return not bool_false[lower(tst)]
	end
	return true -- function, table, userdata just return true for exists
end

nxtui.meta = {} -- meta tables for all types
nxtui.meta.shared = {
	methods = {
		pos = function(self, x, y)
			if y then
				self.x = tonumber(x) or 1
				self.y = tonumber(y) or 1
			else return {self.x, self.y} end
		end,
		layer = function(self, l)
			if l then self.z = tonumber(l) or 1
			else return self.z end
		end,
		color = function(self, k, v)
			if v then
				local ct = self.style.color or {}
				ct[k] = v
			else return self.style.color[k] end
		end,
		seen = function(self, b)
			if b ~= nil then self.draw = tobool(b)
			else return self.draw end
		end,
		width = function(self, w)
			if w then self.w = tonumber(w) or 1 else return self.w end
		end,
		height = function(self, h)
			if h then self.h = tonumber(h) or 1 else return self.h end
		end,
		size = function(self, w, h)
			if h then
				self.w = tonumber(w) or 1
				self.h = tonumber(h) or 1
			else return {self.w, self.h} end
		end,
		border = function(self, n)
			if b then self.style.border = tonumber(n) or 0 else return self.style.border end
		end,
		bold = function(self, b)
			if b then self.style.bold = tobool(b) else return self.style.bold end
		end,
		italic = function(self, b)
			if b then self.style.italic = tobool(b) else return self.style.italic end
		end,
	},
}
local shared_metamethods = nxtui.meta.shared.methods

local shared_set_defaults = function(t)
	t = t or {} -- table root
	t.style = t.style or {} -- styles (color, bold, border, frame, etc)
	t.draw = t.draw ~= nil and t.draw or false -- draw flag boolean
	t.x = t.x or 1 -- x
	t.y = t.y or 1 -- y
	t.z = t.z or 1 -- z or (layer)
	return t
end

nxtui.meta.panel = {
	methods = {
		__index = function(self, key) return rawget(self, key) or rawget(getmetatable(self), methods)[key] or shared_metamethods[key] end,
		__newindex = function(self, key, v) print('new index attempt in panel key: ' .. key) end,
		__call = function(self, ...) end,
	},
}

-- see shared default section
nxtui.panel = function(opt)	return setmetatable(shared_set_defaults(opt), nxtui.meta.panel) end

local dct = { -- draw char table
	{'┌','┐','└','┘','─','│','├','┤','┴','┬'},
	{'╔','╗','╚','╝','═','║','╠','╣','╩','╦'},
	{'╒','╕','╘','╛','═','│','╞','╡','╧','╤'},
	{'╓','╖','╙','╜','─','║','╟','╢','╨','╥'},
}
nxtui.draw = {
	rect = function(w, h, x, y, ss) -- width, height, x, y, style set
		if w < 2 or h < 2 then return end
		x, y, ss = x or 1, y or 1, ss or 1
		local o = concat{ cc.set(x,y), dct[ss][1], rep(dct[ss][5], w-2),dct[ss][2], cc.set(x,y+1) } -- top frame
		for i = 1, h - 2, 1 do o = o .. concat{ dct[ss][6], cc.forward(w-2), dct[ss][6], cc.set(x,y+1+i) } end -- hollow lines
		o = o .. concat{ cc.set(x,y+h-1), dct[ss][3], rep(dct[ss][5], w-2), dct[ss][4] } -- bottom frame
		write(o) -- write it
		flush() -- calculated
	end,
	hline = function(w, x, y, ss)
		if w < 1 then return end
		x, y, ss = x or 1, y or 1, ss or 1
		local o = cc.set(x,y) .. rep(dct[ss][5], w)
		write(o); flush()
	end,
	vline = function(h, x, y, ss)
		if h < 1 then return end
		x, y, ss = x or 1, y or 1, ss or 1
		-- finish me
		local o = cc.set(x,y) .. rep(dct[ss][5], h)
		write(o); flush()
	end,
}

local function table_as_cstring(t, indent, deep, indent_str, map)
	if deep == 0 then return else deep = deep or 10 end
	indent, indent_str = indent or 0, indent_str or '   '
	local output, indentation, tt, address = {}, rep(indent_str, indent + 1) -- tt and address are local nil
	if type(t) == "table" then
		if indent == 0 then	insert(output, cf('%{b ul c14}%s %{b_off ul_off c8}= %{c6}{', tostring(t))) end
		for k, v in pairs(t) do
			tt = type(v)
			address = match(tostring(t), "table: (0x%x+)")
			map = map or {[address]=0,origin=address}
			if tt == "table" then
				address = match(tostring(v), "table: (0x%x+)")
				if map[address] then
					map[address] = map[address] + 1
					if map.origin == address then insert(output, cf('%s%{c14}%s %{c8}= %s%{c6}{%{c7}...%{c6}} %{c8}c:%{c7}%d %{c11}!%{c7}self%{c8}:origin%{c11}!%{}', indentation, tostring(k), address, map[address]))
					else insert(output, cf('%s%{c14}%s %{c8}= %s%{c6}{%{c7}...%{c6}} %{c8}c:%{c7}%d%{}', indentation, tostring(k), address, map[address])) end
				else
					map[address] = 1
					local s = table_as_cstring(v, indent + 1, deep - 1, indent_str, map) -- we have to do local s due to table.concat? and secondary return value
					if s == '' then
						s = nil
						map[address] = nil -- remove because its easier to print empty then an address
					end -- table was empty
					insert(output, cf('%s%{c14}%s %{c8}= %s%{c6}{%s', indentation, tostring(k), s and address or '', s and '' or '}'))
					if s then
						insert(output, s)
						insert(output, indentation .. sc.c6 .. "}")
					end
				end
			elseif tt == "function" then insert(output, cf('%s%{c15}%s %{c8}= %s%{c1}()',indentation, tostring(k), match(tostring(v), "function: (0x%x+)")))
			elseif tt == "number" then insert(output, cf('%s%{c15}%s %{c8}= %{c2}%s',indentation, tostring(k), tostring(v)))
			elseif tt == "boolean" then insert(output, cf('%s%{c15}%s %{c8}= %{c12}%s',indentation, tostring(k), tostring(v)))
			elseif tt == "string" then insert(output, cf('%s%{c15}%s %{c8}= \'%{c7}%s%{c8}\'',indentation, tostring(k), tostring(v)))
			else insert(output, cf('%s%{c15}%s %{c8}= %{c7}%s',indentation, tostring(k), tostring(v))) end
		end
		if indent == 0 then insert(output, sc('c6','}')) end
	else insert(output, sc('c7', tostring(t))) end
	return concat(output,'\r\n')
end

function nxtui.print_table(...)
	local output = table_as_cstring(unpack{...}) .. sc('reset','\r\n')
	write(output); flush()
end
return nxtui