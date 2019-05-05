--MIT License
--
--Copyright (c) 2019 @ym2601 (https://github.com/sanwabear)
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
function tohex(num)
	local hexstr = '0123456789ABCDEF'
	local s = ''
	while num > 0 do
		local mod = math.fmod(num, 16)
		s = string.sub(hexstr, mod+1, mod+1) .. s
		num = math.floor(num / 16)
	end
	if s == '' then s = '0' end
	return s
end

function new_env(scriptfile)
	local env = setmetatable({}, {__index=_G})
	pcall(assert(loadfile(scriptfile, env)))
	return env
end

rb2key = {}
local rb2key_now = {}
local rb2key_pre = {}
local kprops = {
	"d1", "c1", "b1", "a1", "rt1", "lt1", "dn1", "up1", "sl1", "st1",
	"d2", "c2", "b2", "a2", "rt2", "lt2", "dn2", "up2", "sl2", "st2",
	"d", "c", "b", "a", "rt", "lt", "dn", "up", "sl", "st",
}
local kprops_len = #kprops
for i = 1, kprops_len do
	rb2key_now[kprops[i]] = -emu.framecount()
	rb2key_pre[kprops[i]] = -emu.framecount()
end
local posi_or_pl1 = function(v)
	return 0 <= v and v + 1 or 1
end
local nega_or_mi1 = function(v)
	return 0 >= v and v - 1 or -1
end
local last_time = 0
local kio1, kio2, kio3 = 0xFF, 0xFF, 0xFF

bios_test = function(address)
	local ram_value = memory.readbyte(address)
	for _, test_value in ipairs({0x5555, 0xAAAA, bit.band(0xFFFF, address)}) do
		if ram_value == test_value then
			return true
		end
	end
end


--        REG_P1CNT, REG_P2CNT, REG_STATUS_B
-- return 0x300000 , 0x340000 , 0x380000,    rb2key, rb2key_pre
rb2key.capture_keys = function()
	if last_time == emu.framecount() then
		return kio1, kio2, kio3, rb2key_now, rb2key_pre
	end

	for i = 1, kprops_len do
		local k = kprops[i]
		rb2key_pre[k] = rb2key_now[k]
	end
	local kio = memory.readbyte(0x300000)
	rb2key_now.d1  = bit.band(kio, 0x80) == 0x00 and posi_or_pl1(rb2key_now.d1 ) or nega_or_mi1(rb2key_now.d1 ) -- P1 Button D
	rb2key_now.c1  = bit.band(kio, 0x40) == 0x00 and posi_or_pl1(rb2key_now.c1 ) or nega_or_mi1(rb2key_now.c1 ) -- P1 Button C
	rb2key_now.b1  = bit.band(kio, 0x20) == 0x00 and posi_or_pl1(rb2key_now.b1 ) or nega_or_mi1(rb2key_now.b1 ) -- P1 Button B
	rb2key_now.a1  = bit.band(kio, 0x10) == 0x00 and posi_or_pl1(rb2key_now.a1 ) or nega_or_mi1(rb2key_now.a1 ) -- P1 Button A
	rb2key_now.rt1 = bit.band(kio, 0x08) == 0x00 and posi_or_pl1(rb2key_now.rt1) or nega_or_mi1(rb2key_now.rt1) -- P1 Right
	rb2key_now.lt1 = bit.band(kio, 0x04) == 0x00 and posi_or_pl1(rb2key_now.lt1) or nega_or_mi1(rb2key_now.lt1) -- P1 Left
	rb2key_now.dn1 = bit.band(kio, 0x02) == 0x00 and posi_or_pl1(rb2key_now.dn1) or nega_or_mi1(rb2key_now.dn1) -- P1 Down
	rb2key_now.up1 = bit.band(kio, 0x01) == 0x00 and posi_or_pl1(rb2key_now.up1) or nega_or_mi1(rb2key_now.up1) -- P1 Up
	kio1 = kio
	kio = memory.readbyte(0x340000)
	rb2key_now.d2  = bit.band(kio, 0x80) == 0x00 and posi_or_pl1(rb2key_now.d2 ) or nega_or_mi1(rb2key_now.d2 ) -- P2 Button D
	rb2key_now.c2  = bit.band(kio, 0x40) == 0x00 and posi_or_pl1(rb2key_now.c2 ) or nega_or_mi1(rb2key_now.c2 ) -- P2 Button C
	rb2key_now.b2  = bit.band(kio, 0x20) == 0x00 and posi_or_pl1(rb2key_now.b2 ) or nega_or_mi1(rb2key_now.b2 ) -- P2 Button B
	rb2key_now.a2  = bit.band(kio, 0x10) == 0x00 and posi_or_pl1(rb2key_now.a2 ) or nega_or_mi1(rb2key_now.a2 ) -- P2 Button A
	rb2key_now.rt2 = bit.band(kio, 0x08) == 0x00 and posi_or_pl1(rb2key_now.rt2) or nega_or_mi1(rb2key_now.rt2) -- P2 Right
	rb2key_now.lt2 = bit.band(kio, 0x04) == 0x00 and posi_or_pl1(rb2key_now.lt2) or nega_or_mi1(rb2key_now.lt2) -- P2 Left
	rb2key_now.dn2 = bit.band(kio, 0x02) == 0x00 and posi_or_pl1(rb2key_now.dn2) or nega_or_mi1(rb2key_now.dn2) -- P2 Down
	rb2key_now.up2 = bit.band(kio, 0x01) == 0x00 and posi_or_pl1(rb2key_now.up2) or nega_or_mi1(rb2key_now.up2) -- P2 Up
	kio2 = kio
	kio = memory.readbyte(0x380000)
	rb2key_now.sl2 = bit.band(kio, 0x08) == 0x00 and posi_or_pl1(rb2key_now.sl2) or nega_or_mi1(rb2key_now.sl2) -- Select P2
	rb2key_now.st2 = bit.band(kio, 0x04) == 0x00 and posi_or_pl1(rb2key_now.st2) or nega_or_mi1(rb2key_now.st2) -- Start P2
	rb2key_now.sl1 = bit.band(kio, 0x02) == 0x00 and posi_or_pl1(rb2key_now.sl1) or nega_or_mi1(rb2key_now.sl1) -- Select P1
	rb2key_now.st1 = bit.band(kio, 0x01) == 0x00 and posi_or_pl1(rb2key_now.st1) or nega_or_mi1(rb2key_now.st1) -- Start P1

	rb2key_now.d  = math.max(rb2key_now.d1 , rb2key_now.d2 )
	rb2key_now.c  = math.max(rb2key_now.c1 , rb2key_now.c2 )
	rb2key_now.b  = math.max(rb2key_now.b1 , rb2key_now.b2 )
	rb2key_now.a  = math.max(rb2key_now.a1 , rb2key_now.a2 )
	rb2key_now.rt = math.max(rb2key_now.rt1, rb2key_now.rt2)
	rb2key_now.lt = math.max(rb2key_now.lt1, rb2key_now.lt2)
	rb2key_now.dn = math.max(rb2key_now.dn1, rb2key_now.dn2)
	rb2key_now.up = math.max(rb2key_now.up1, rb2key_now.up2)
	rb2key_now.sl = math.max(rb2key_now.sl1, rb2key_now.sl2)
	rb2key_now.st = math.max(rb2key_now.st1, rb2key_now.st2)
	kio3 = kio
	last_time = emu.framecount()

	return kio1, kio2, kio3, rb2key_now, rb2key_pre
end

-- メッシュシュだけ
gui_boxb = function(x1, y1, x2, y2, color1, color2, initb)
	local stepx = x1 < x2 and 1 or -1
	local stepy = y1 < y2 and 1 or -1
	for x = x1, x2, stepx do
		for y = y1, y2, stepy do
			initb = not initb
			if initb then
				gui.drawpixel(x, y, color2)
			end
		end
	end
end

-- 外枠つきのメッシュ
gui_boxc = function(x1, y1, x2, y2, color1, color2, initb)
	gui.box(x1, y1, x2, y2, color1, color2)
	gui_boxb(x1, y1, x2, y2, color1, color2, initb)
end
