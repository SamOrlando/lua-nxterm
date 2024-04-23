-- local vars
local format, match, sfind, sub = string.format, string.match, string.find, string.sub
local gmatch, gsub = string.gmatch, string.gsub, string.sub
local insert, concat = table.insert, table.concat
local unpack = unpack or table.unpack
local tonumber = tonumber
local rawget, rawset, getmetatable, setmetatable = rawget, rawset, getmetatable, setmetatable
local pairs, ipairs, type = pairs, ipairs, type
local read, write, flush = io.read, io.write, io.flush
local nxt = require('nxt')

--input
--text
--label
--edit
--window
--rect
--button (fancy rect)
--menu
--list
--tree

return nxt