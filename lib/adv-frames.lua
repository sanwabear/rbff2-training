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
require("rbff2-global")

local c = { --colors
	red    = 0xFF0000FF,
	cyan   = 0x00FFFFFF,
	white  = 0xFFFFFFFF,
}

local frames = {
	p          = { 0x100460, 0x100560 }, -- 行動ID デバッグディップのPと同じ
	hitstop    = { 0x10048D, 0x10058D }, -- ヒットストップ
	combo      = { 0x10B4E0, 0x10B4E1 }, -- コンボ
	state      = { 0x10058E, 0x10048E }, -- 状態
	chr        = { 0x107BA5, 0x107BA7 }, -- キャラ
	skip_upd   = { 0, 0, },
	skip_count = { 0, 0, },
	next_frame = { 0, 0, },
	act        = { 0, 0, }, -- 行動ID デバッグディップのPと同じ
	no_guard   = { 0, 0, 0, }, -- ガード不能フレーム数 1p, 2p
	last       = { 0, 0, 0, 0, }, -- 1p, 2p 1p有利不利, 2p有利不利
	first      = { 0, 0, }, -- 初回ヒットまでのラグ1p, 2p
	first_flg  = { true, true, }, -- 初回ヒットまでのラグ1p, 2p
}

for i = 1, #frames.combo do
	memory.registerwrite(frames.combo[i], function()
		frames.skip_upd[i] = emu.framecount()
	end)
	memory.registerwrite(frames.state[i], function()
		frames.skip_upd[i] = emu.framecount()
	end)
end

adv_frames = {
	enabled = true,
	show_action = true,
}

local gui_text = function(left, x, y, text, color)
	local s = tostring(text)
	if left then
		if color then
			gui.text(x + 16 - #s * 4, y, s, color)
		else
			gui.text(x + 16 - #s * 4, y, s)
		end
	else
		if color then
			gui.text(x - #s * 4, y, s, color)
		else
			gui.text(x - #s * 4, y, s)
		end
	end
end

adv_frames.draw_frames = function()
	if not adv_frames then
		return
	end

	gui_text(true , 160-72, 203, frames.last[1])
	gui_text(false, 160+72, 203, frames.last[2])
	gui_text(true , 160-72, 210, frames.first[1])
	gui_text(false, 160+72, 210, frames.first[2])
	if adv_frames.show_action then
		gui_text(true , 160-43, 203, tohex(frames.act[1]))
		gui_text(false, 160+43, 203, tohex(frames.act[2]))
	end
	gui_text(true , 160-72, 217, frames.last[3], 0 > frames.last[3] and c.red or c.cyan)
	gui_text(false, 160+72, 217, frames.last[4], 0 > frames.last[4] and c.red or c.cyan)
end

adv_frames.update_frames = function()
	if not adv_frames then
		return
	end

	local skip = false
	for i = 1, #frames.p do
		if emu.framecount() == frames.skip_upd[i]
			and memory.readbyte(frames.state[i]) ~= 0 then

			-- 本判定処理の1Fとあわせてヒットストップぶんの2F削減する
			frames.skip_count[i] = frames.skip_count[i] + 2

			-- 初回のヒット/ガードまでのフレーム数を記憶する
			if frames.first_flg[i] == true and memory.readbyte(frames.state[i]) ~= 0 then
				frames.first[i] = frames.last[i]
				frames.first_flg[i] = false
			end
		end

		-- ヒットストップ判定と削減
		skip = skip or frames.skip_count[i] > 0
		frames.skip_count[i] = math.max(0, frames.skip_count[i] - 1)
	end

	if not skip and memory.readbyte(0x10D4EA) == 0 and slow.phase() == 0 then
		local nostop = false
		for i = 1, #frames.p do
			if memory.readbyte(frames.hitstop[i]) == 0x00 then
				nostop = true
				local act = memory.readword(frames.p[i])
				local chr = memory.readbyte(frames.chr[i])
				frames.act[i] = act
				if act < 0x8 or act == 0x1D or act == 0x1E
					or (0x20 <= act and act <= 0x23)
					or (0x2C <= act and act <= 0x2F)
					or (0x3C <= act and act <= 0x3F)
					or (0x6C == act and chr == 12) --jin
					or ((0x108 <= act and act <=  0x10A) and chr == 9) --marry
					or act == 0x40 then
					frames.no_guard[i] = 0
					frames.first_flg[i] = true
				else
					frames.no_guard[i] = frames.no_guard[i] + 1
					frames.last[i] = frames.no_guard[i] + 1 --行動発生までの1Fを加算する
				end
			end
		end
		local p1pos = frames.no_guard[1] == 0 and frames.no_guard[2] > 0
		local p2pos = frames.no_guard[1] > 0 and frames.no_guard[2] == 0
		if nostop and (p1pos or p2pos) then
			frames.no_guard[3] = frames.no_guard[3] + 1
			frames.last[3] = frames.no_guard[3] * (p1pos and 1 or -1)
			frames.last[4] = -frames.last[3]
		else
			frames.no_guard[3] = 0
			frames.no_guard[4] = 0
		end
	end
end

adv_frames.config_draw = function(flg)
	adv_frames.enabled = flg
end
