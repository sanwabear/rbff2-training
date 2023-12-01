--MIT License
--
--Copyright (c) 2019- @ym2601 (https://github.com/sanwabear)
--
--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:
--
--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.
--
--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--SOFTWARE.
local lfs        = require("lfs")
local _convert   = require("data/button_char")

local ut         = {}

ut.convert       = function(str)
	return str and _convert(str) or str
end

ut.cur_dir       = lfs.currentdir

local is_dir     = function(name)
	if type(name) ~= "string" then return false end
	local cd = lfs.currentdir()
	local is = lfs.chdir(name) and true or false
	lfs.chdir(cd)
	return is
end
ut.is_dir        = is_dir

ut.mkdir         = function(path)
	if is_dir(path) then
		return true, nil
	end
	local r, err = lfs.mkdir(path)
	if not r then
		print(err)
	end
	return r, err
end

ut.is_file       = function(name)
	if type(name) ~= "string" then return false end
	local f = io.open(name, "r")
	if f then
		f:close()
		return true
	end
	return false
end

local tohex      = function(num)
	local hexstr = '0123456789abcdef'
	local s = ''
	while num > 0 do
		local mod = math.fmod(num, 16)
		s = string.sub(hexstr, mod + 1, mod + 1) .. s
		num = math.floor(num / 16)
	end
	if s == '' then s = '0' end
	return s
end
ut.tohex         = tohex

ut.tohexnum      = function(num) return tonumber(tohex(num)) end

-- tableで返す
ut.tobits        = function(num)
	-- returns a table of bits, least significant first.
	local t, rest = {}, 0 -- will contain the bits
	while num > 0 do
		rest = math.fmod(num, 2)
		table.insert(t, rest)
		num = (num - rest) / 2
	end
	return t
end

local bin_lookup = {
	[" "] = "0000",
	["0"] = "0000",
	["1"] = "0001",
	["2"] = "0010",
	["3"] = "0011",
	["4"] = "0100",
	["5"] = "0101",
	["6"] = "0110",
	["7"] = "0111",
	["8"] = "1000",
	["9"] = "1001",
	["A"] = "1010",
	["B"] = "1011",
	["C"] = "1100",
	["D"] = "1101",
	["E"] = "1110",
	["F"] = "1111",
	["a"] = "1010",
	["b"] = "1011",
	["c"] = "1100",
	["d"] = "1101",
	["e"] = "1110",
	["f"] = "1111",
}
ut.hextobitstr   = function(hex, delim)
	local ln, str = hex:len(), "" -- get length of string
	delim = delim or ""
	for i = 1, ln do             -- loop through each hex character
		local index = hex:sub(i, i) -- each character in order
		str = str .. bin_lookup[index] -- lookup a table
		str = str .. delim       -- add a space
	end
	return str
end
ut.tobitstr      = function(value, delim)
	local hex = string.format("%X", value) -- convert number to HEX
	return ut.hextobitstr(hex, delim)
end

ut.frame_to_time = function(frame_number)
	local min = math.floor(frame_number / 3600)
	local sec = math.floor((frame_number % 3600) / 60)
	local frame = math.floor((frame_number % 3600) % 60)
	return string.format("%02d:%02d:%02d", min, sec, frame)
end

ut.get_digit        = function(num) return string.len(tostring(num)) end

-- 16ビット値を0.999上限の数値に変える
ut.int16tofloat     = function(int16v)
	if int16v and type(int16v) == "number" then
		return int16v / 0x10000
	end
	return 0
end

ut.printf           = function(format, ...) print(string.format(format, ...)) end

ut.int8             = function(pos)
	if 127 < pos or pos < -128 then
		-- (pos + 2 ^ 15) % 2 ^ 16 - 2 ^ 15
		return (pos + 128) % 256 - 128
	end
	return pos
end

ut.int16            = function(pos)
	if 32767 < pos or pos < -32768 then
		-- (pos + 2 ^ 15) % 2 ^ 16 - 2 ^ 15
		return (pos + 32768) % 65536 - 32768
	end
	return pos
end

local deepcopy
deepcopy            = function(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end
ut.deepcopy         = deepcopy

ut.table_sort       = function(tbl, order)
	table.sort(tbl, order)
	return tbl
end

ut.table_add        = function(tbl, item, limit)
	table.insert(tbl, item)
	if limit then
		while limit < #tbl do table.remove(tbl, 1) end -- FIFO
	end
	return item
end

ut.table_add_all    = function(t1, t2, pre_add)
	t1 = t1 or {}
	for _, r in ipairs(t2 or {}) do
		if pre_add then
			pre_add(r)
		end
		table.insert(t1, r)
	end
	return t1
end

ut.table_add_conv_all    = function(t1, t2, conv)
	t1 = t1 or {}
	for _, r in ipairs(t2 or {}) do
		table.insert(t1, conv(r))
	end
	return t1
end

ut.hash_add_all     = function(t1, t2, pre_add)
	t1 = t1 or {}
	for k, v in pairs(t2 or {}) do
		if pre_add then
			pre_add(k, v)
		end
		t1[k] = v
	end
	return t1
end

ut.sorted_pairs     = function(tbl, order_func)
	local a = {}
	for n in pairs(tbl) do a[#a + 1] = n end
	table.sort(a, order_func)
	local i = 0
	return function()
		i = i + 1
		return a[i], tbl[a[i]]
	end
end

ut.get_hash_key     = function(tbl)
	local ret = {}
	for k, _ in pairs(tbl) do
		table.insert(ret, k)
	end
	return ret
end

ut.new_set          = function(...)
	local ret = {}
	for _, v in ipairs({ ... }) do
		ret[v] = true
	end
	return ret
end

ut.new_set_false    = function(...)
	local ret = {}
	for _, v in ipairs({ ... }) do
		ret[v] = false
	end
	return ret
end

ut.new_tbl_0        = function(...)
	local ret = {}
	for _, v in ipairs({ ... }) do
		ret[v] = 0
	end
	return ret
end

ut.table_to_set     = function(tbl)
	local ret = {}
	for _, v in ipairs(tbl or {}) do
		ret[v] = true
	end
	return ret
end

ut.new_empty_table  = function(len)
	local tmp_table = {}
	for i = 1, len do
		table.insert(tmp_table, nil)
	end
	return tmp_table
end

ut.new_filled_table = function(...)
	local tmp_table = {}
	local a = { ... }
	for j = 1, #a, 2 do
		local len = a[j]
		local fill = a[j + 1]
		for i = 1, len do
			table.insert(tmp_table, fill)
		end
	end
	return tmp_table
end

ut.tstb             = function(target, hex, strict)
	if strict then
		return ((target or 0) & hex) == hex
	else
		return ((target or 0) & hex) ~= 0
	end
end

ut.hex_set          = function(target, hex, clear)
	local ret = (target or 0) | (hex or 0)
	if clear then ret = ret - (hex or 0) end
	return ret
end

ut.hex_clear        = function(target, hex)
	return ut.hex_set(target, hex, true)
end

ut.hex_reset        = function(target, clr_mask, hex)
	local ret = ut.hex_clear(target, clr_mask)
	ret = ut.hex_set(ret, hex)
	return ret
end

local ffptn         = "%s*(%w+):%s+(%w+)%s+(%w+)%s*[\r\n]*"

local fixaddr       = function(saddr, offset)
	local addr = tonumber(saddr, 16) + offset
	if (addr % 2 == 0) then
		return addr + 1
	else
		return addr - 1
	end
end

local apply_patch   = function(pgm, s_patch, offset, force)
	if force ~= true then
		for saddr, v1, v2 in string.gmatch(s_patch, ffptn) do
			local before = pgm:read_direct_u8(fixaddr(saddr, offset))
			if before ~= tonumber(v1, 16) then
				if before == tonumber(v2, 16) then
					-- already patched
				else
					print("patch failure in 0x" .. saddr)
					return false
				end
			end
		end
	end
	for saddr, v1, v2 in string.gmatch(s_patch, ffptn) do
		pgm:write_direct_u8(fixaddr(saddr, offset), tonumber(v2, 16))
	end
	return true
end

ut.apply_patch_file = function(pgm, path, force)
	local ret = false
	if pgm then
		print(path .. " patch " .. (force and "force" or ""))
		local f = io.open(path, "r")
		if f then
			for line in f:lines() do
				ret = apply_patch(pgm, line, 0x000000, force)
				if not ret then
					print("patch failure in [" .. line .. "]")
				end
			end
			f:close()
		end
	end
	print(ret and "patch finish" or "patch NOT finish")
	return ret
end

ut.get_polygon      = function(x, y, sides, rad_odd, rad_even, rotation)
	local ret, angle = {}, (math.pi * 2) / sides
	rotation = math.rad(-((rotation or 0) % 360)) + (angle / 2)
	for i = 0, sides, 1 do
		local a = angle * i + rotation
		local rad = (i % 2 == 0) and rad_even or rad_odd
		table.insert(ret, { x = math.sin(a) * rad + x, y = math.cos(a) * rad + y })
	end
	return ret
end
--[[
	local py, sides, rad = 200, 8, (360 / 8) * 1.5
	for _, px in ipairs({50, 245}) do
		for ni = 9, 10.2, 0.3 do
			local poly, p1, p2 = ut.get_polygon(px, py, sides, ni, ni + 1.3, rad)
			for i = 1, #poly - 1 do
				p1, p2 = poly[i], poly[i + 1]
				scr:draw_line(p1.x, p1.y, p2.x, p2.y, 0xDDCCCCCC)
			end
		end
	end
]]

ut.ifind = function(sources, resolver) -- sourcesの要素をresolverを通して得た結果で最初の非nilの値を返す
	sources = sources or {}
	local i, ii, p, a = 1, nil, nil, nil
	return function()
		while i <= #sources and p == nil do
			i, ii, p, a = i + 1, i, resolver(sources[i]), sources[i]
			if p == false then p = nil end
			if p then return ii, a, p end -- インデックス, sources要素, convert結果
		end
	end
end

ut.ifind_all = function(sources, resolver) -- sourcesの要素をresolverを通して得た結果で非nilの値を返す
	sources = sources or {}
	local i, ii, p, a = 1, nil, nil, nil
	return function()
		while i <= #sources do
			i, ii, p, a = i + 1, i, resolver(sources[i]), sources[i]
			if p == false then p = nil end
			if p then return ii, a, p end -- インデックス, sources要素, convert結果
		end
	end
end

ut.find_all = function(sources, resolver) -- sourcesの要素をresolverを通して得た結果で非nilの値を返す
	local i, col, ret = 1, {}, nil
	for k, v in pairs(sources) do
		local v2 = resolver(k, v)
		if v2 == false then v2 = nil end
		if v2 then table.insert(col, { k, v, v2 }) end
	end
	return function()
		while i <= #col do
			i, ret = i + 1, col[i]
			return ret[1], ret[2], ret[3]
		end
	end
end

ut.sort_ab                              = function(v1, v2)
	if v1 <= v2 then return v2, v1 end
	return v1, v2
end

ut.sort_ba                              = function(v1, v2)
	if v1 <= v2 then return v1, v2 end
	return v2, v1
end

print("util loaded")
return ut
