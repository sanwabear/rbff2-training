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

local max = 0
local count = 0
local pause = 0xFF
local unpause = 0x00
local phase = 0 -- 0 = active, 1 = pre-pause, 2 = pause
local no_buttons = {}
local buttons = {
	["P1 Button A"] = false,
	["P1 Button B"] = false,
	["P1 Button C"] = false,
	["P1 Button D"] = false,
	["P2 Button A"] = false,
	["P2 Button B"] = false,
	["P2 Button C"] = false,
	["P2 Button D"] = false,
}

local _, _, _, ks, _ = rb2key.capture_keys()
local kbak = {
	a1 = ks.a1, b1 = ks.b1, c1 = ks.c1, d1 = ks.d1,
	a2 = ks.a2, b2 = ks.b2, c2 = ks.c2, d2 = ks.d2,
}

local do_pause = function(v)
	memory.writebyte(0x104191, v)
	memory.writebyte(0x1041D2, v)
end

-- おしっぱで攻撃ボタンが認識されるようにする
local checkkey = function()
	local _, _, _, ks, _ = rb2key.capture_keys()
	local x = max - 1
	--	print("a1-1", kbak.a1)
	kbak.a1 = x <= kbak.a1 + ks.a1 and x or ks.a1
	kbak.b1 = x <= kbak.b1 + ks.b1 and x or ks.b1
	kbak.c1 = x <= kbak.c1 + ks.c1 and x or ks.c1
	kbak.d1 = x <= kbak.d1 + ks.d1 and x or ks.d1
	kbak.a2 = x <= kbak.a2 + ks.a2 and x or ks.a2
	kbak.b2 = x <= kbak.b2 + ks.b2 and x or ks.b2
	kbak.c2 = x <= kbak.c2 + ks.c2 and x or ks.c2
	kbak.d2 = x <= kbak.d2 + ks.d2 and x or ks.d2
	--	print("a1-2", kbak.a1, x <= kbak.a1)
end
local update_buttons = function()
	buttons["P1 Button A"] = 1 <= kbak.a1
	buttons["P1 Button B"] = 1 <= kbak.b1
	buttons["P1 Button C"] = 1 <= kbak.c1
	buttons["P1 Button D"] = 1 <= kbak.d1
	buttons["P2 Button A"] = 1 <= kbak.a2
	buttons["P2 Button B"] = 1 <= kbak.b2
	buttons["P2 Button C"] = 1 <= kbak.c2
	buttons["P2 Button D"] = 1 <= kbak.d2
end
local unsetkey = function()
	local x = max - 1
	--print("unset", x <= kbak.a1)
	joypad.set({
		["P1 Button A"] = x <= kbak.a1,
		["P1 Button B"] = x <= kbak.b1,
		["P1 Button C"] = x <= kbak.c1,
		["P1 Button D"] = x <= kbak.d1,
		["P2 Button A"] = x <= kbak.a2,
		["P2 Button B"] = x <= kbak.b2,
		["P2 Button C"] = x <= kbak.c2,
		["P2 Button D"] = x <= kbak.d2,
	})
	checkkey()
end
local setkey = function()
	joypad.set(buttons)
end

slow = {}
slow.apply_slow = function()
	if max == 0 then
		return
	end

	-- スロー中にセレクトで抜ける（メニュー操作などできるように）
	local _, _, _, ks, _ = rb2key.capture_keys()
	if 0 < ks.sl then
		do_pause(unpause)
		return
	end

	count = count + 1
	if count == max then
		unsetkey()
		phase = 1
		do_pause(pause)
	elseif count > max then
		update_buttons()
		setkey()
		count = 0
		phase = 0
		do_pause(unpause)
	else
		checkkey()
		phase = 2
		do_pause(pause)
	end
end
slow.config_slow = function(newmax)
	count = 0
	max = newmax
	local _, _, _, ks, _ = rb2key.capture_keys()
	local kbak = {
		a1 = 0, b1 = 0, c1 = 0, d1 = 0,
		a2 = 0, b2 = 0, c2 = 0, c2 = 0,
	}
end

slow.phase = function()
	if max == 0 then
		return 0
	end
	return phase
end

slow.buttons = function()
	if max == 0 then
		return no_buttons
	end
	return buttons
end

slow.term = function()
	do_pause(unpause)
end
