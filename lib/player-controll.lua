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
	red  = 0xFF0000FF,
	green  = 0x00FF00FF,
	yellow = 0xFFFF00FF,
	gray2  = 0x80C0C0FF,
	gray3  = 0x80A0A0FF,
}

local fix_player_select = {
	on_start_frame = 0,
	on_select_frame = 0,
	on_start1 = nil,
	on_start2 = nil,
	force_vs_mode = nil,
	apply_vs_mode = function(continue)
		memory.writebyte(0x100024, 0x03) -- 1P & 2P Active
		memory.writebyte(0x100027, 0x03) -- 1P & 2P Active
		if not continue then
			memory.writebyte(0x107BB5, 0x01) -- vs 1st CPU mode
		end
	end,
	copy_joypad = function(fromp, top)
		local tbl = joypad.get()
		local tbl2 = {}
		for _, v in pairs({" Down", " Left", " Right", " Up"}) do
			tbl2["P"..top..v] = tbl["P"..fromp..v]
		end
		joypad.set(tbl2)
	end,
	copy_buttons = function(fromp, top)
		local tbl = joypad.get()
		local tbl2 = {}
		for _, v in pairs({" Button A", " Button D"}) do
			tbl2["P"..top..v] = tbl["P"..fromp..v]
		end
		joypad.set(tbl2)
	end,
}
fix_player_select.on_start_frame = 0
fix_player_select.on_start1 = function(addr, value)
	if value ~= 0x03 then
		fix_player_select.on_start_frame = emu.framecount()
	end
end
fix_player_select.on_start2 = function(addr, value)
	if value == 0xFF then
		fix_player_select.on_select_frame = emu.framecount()
	elseif value ~= 0x00 then
		fix_player_select.on_select_frame = emu.framecount()
	end
end
memory.registerwrite(0x107BA5, fix_player_select.on_start2)
memory.registerwrite(0x107BA7, fix_player_select.on_start2)
memory.registerwrite(0x107BB5, fix_player_select.on_start1)

local controll_config = {
	p1 = 0x01, -- Disable 0, Human 1 or 2, CPU 3
	p2 = 0x02, -- Disable 0, Human 1 or 2, CPU 3
	apply_player_controll = nil,
	change = nil,
}
controll_config.apply_player_controll = function()
	memory.writebyte(0x100412, controll_config.p1)-- Human 1 or 2, CPU 3
	memory.writebyte(0x100413, controll_config.p1)-- Human 1 or 2, CPU 3
	memory.writebyte(0x100512, controll_config.p2) -- Human 1 or 2, CPU 3
	memory.writebyte(0x100513, controll_config.p2) -- Human 1 or 2, CPU 3
end

-- for record and replay
local replay = {
	draw_recording_status = nil,
	draw_playing_status = nil,
	record = nil,
	replay = nil,
	max_fc = 60 * 60,
	slot = nil,
	slots = {},
	active_slot = 0,
	replay_repeat = true,
	on_damage_stop = true,
	position_mode = 0,

	state = 1,
	state_last_frame = emu.framecount(),
	text = {
		[1] = { "PRESS 1P START TO BEGIN RECORDING 2P", "PRESS 2P START TO BEGIN RECORDING 1P", },
		[12] = { "START RECORDING 2P WITH ANY 1P INPUT", "PRESS START TO EXIT", },
		[22] = { "START RECORDING 1P WITH ANY 1P INPUT", "PRESS START TO EXIT", },
		[3] = { ">>> RECORDING... <<<", "PRESS START TO EXIT", },
		[4] = { "RECORDING BUFFER IS FULL! ", "PRESS START TO EXIT", },

		[-1] = { "NO RECORD DATA", },
		[-2] = { "PRESS 1P START TO RE-PLAY THE 2P", "PRESS 2P START TO RE-PLAY THE 1P", },
		[-3] = { ">>> RE-PLAYING... >>>", "PRESS START TO EXIT", },
		[-4] = { ">>> RE-PLAYING... >>>", "PRESS START TO EXIT", },
		[-5] = { ">>> RE-PLAYING... >>>", "PRESS START TO EXIT", },
	},
	text_color = {
		[1] = c.yellow,
		[12] = c.yellow,
		[22] = c.yellow,
		[3] = c.red,
		[4] = c.red,

		[-1] = c.red,
		[-2] = c.yellow,
		[-3] = c.green,
		[-4] = c.green,
		[-5] = c.green,
	},

	reset_fc = 0,
	start_fc = 0,
	start = false,
	in_record_or_replay = false,
	pos_fix_fc = -15,

	new_data = function()
		return {
			rec_controll = 1,
			rec_start_pos_diff = 0,
			rec_p1_pos = 0,
			rec_p2_pos = 0,
			rec_p1_pow = 0,
			rec_p2_pow = 0,
			rec_on_p1_side = false,
			rec_fc = 0,
			rec_buff_max_fc = 0,
			rec_buff = {},
			rec_side = {},
		}
	end,
}
local set_slot = function(slot)
	if replay.active_slot ~= slot then
		replay.slots[slot] = replay.slots[slot] or replay.new_data()
		replay.active_slot = slot
	end
end
set_slot(1)

-- replay end
replay.init_replay_state = function(mode)
	replay.state = mode == 1 and 1 or mode == 2 and -1 or 0
	replay.state_last_frame = emu.framecount()
	replay.slots[replay.active_slot] = replay.slots[replay.active_slot] or replay.new_data()
end

-- cetering text
local draw_text = function(y, text, color)
	local w = emu.screenwidth() / 2
	local w2 = 2 * string.len(text)
	gui.text(w - w2, y, text, color)
end

-- counter for flashing replay status display
local draw_cnt = 1
-- replay status text array counter
local text_cnt = 1

-- display status text
local draw_status = function(state)
	local text = replay.text[replay.state]
	local text_color = replay.text_color[replay.state]
	if draw_cnt < 90 then
		if text_cnt <= #text then
			draw_text(76, text[text_cnt], text_color)
		elseif text_cnt <= #text then
			text_cnt = 1
			draw_text(76, text[text_cnt], text_color)
		end
	elseif draw_cnt < 100 then
	elseif draw_cnt >= 100 then
		text_cnt = text_cnt < #text and text_cnt + 1 or 1
		draw_cnt = 1
	end
	draw_cnt = draw_cnt + 1
end

replay.draw_recording_status = function()
	draw_status()
end

replay.draw_playing_status = function()
	draw_status()
end
-- [レコーディング処理]
-- スタート待機状態：
--  state = 1
--  1Pと2Pを操作して任意の位置へ移動
--  1Pか2Pスタートボタンで開始待ちへ
--
-- 開始待ち中：
--  state = 12 (1P), state = 22 (2P)
--  スタートした反対Pを操作可能に
--  操作開始時点からレコーディングへ
--  レコーディングへ遷移するタイミングでレコーディングバッファクリア
--
-- レコーディング：
--  state = 3
--  バッファフルでバッファフル状態へ
--  60秒経過かスタートボタンかメニュー遷移でスタート待機状態へ
--
-- レコーディング(バッファフル)：
--  state = 4
--  60秒経過かスタートボタンかメニュー遷移で終了
--  終了後はスタート待機状態へ
--
replay.record = function()
	local cur_slot = replay.slots[replay.active_slot]
	local kio1, kio2, kio3, key, pre_key = rb2key.capture_keys()
	local ec = emu.framecount()
	local state_past = ec - replay.state_last_frame

	if replay.state == 1
		and 15 < state_past
		and 0 < key.st1 and state_past >= key.st1 then
		replay.state = 12
		replay.state_last_frame = ec
		replay.in_record_or_replay = false
		replay.slots[replay.active_slot] = replay.slots[replay.active_slot] or replay.new_data()
		cur_slot.rec_fc = 0
		player_controll.config_player_controll(0, 1)
		cur_slot.rec_controll = 2
		return
	elseif replay.state == 1
		and 15 < state_past
		and 0 < key.st2 and state_past >= key.st2 then
		replay.state = 22
		replay.state_last_frame = ec
		replay.in_record_or_replay = false
		replay.slots[replay.active_slot] = replay.slots[replay.active_slot] or replay.new_data()
		cur_slot.rec_fc = 0
		player_controll.config_player_controll(2, 0)
		cur_slot.rec_controll = 1
		return
	elseif replay.state == 12
		and 15 < state_past
		and kio1 ~= 0xFF then
		replay.state = 3
		replay.state_last_frame = ec

		cur_slot.rec_start_pos_diff = cur_slot.rec_p1_pos - cur_slot.rec_p2_pos
		cur_slot.rec_fc = 1
		cur_slot.rec_buff = { kio1 }
		cur_slot.rec_side = { 0 > cur_slot.rec_start_pos_diff }
		cur_slot.rec_p1_pos = memory.readwordsigned(0x100420)
		cur_slot.rec_p2_pos = memory.readwordsigned(0x100520)
		cur_slot.rec_p1_pow = memory.readbyte(0x1004BC)
		cur_slot.rec_p2_pow = memory.readbyte(0x1005BC)

		return
	elseif replay.state == 22
		and 15 < state_past
		and kio2 ~= 0xFF then
		replay.state = 3
		replay.state_last_frame = ec

		cur_slot.rec_start_pos_diff = cur_slot.rec_p1_pos - cur_slot.rec_p2_pos
		cur_slot.rec_fc = 1
		cur_slot.rec_buff = { kio2 }
		cur_slot.rec_side = { 0 > cur_slot.rec_start_pos_diff }
		cur_slot.rec_p1_pos = memory.readwordsigned(0x100420)
		cur_slot.rec_p2_pos = memory.readwordsigned(0x100520)
		cur_slot.rec_p1_pow = memory.readbyte(0x1004BC)
		cur_slot.rec_p2_pow = memory.readbyte(0x1005BC)

		return
	elseif (replay.state == 12 or replay.state == 22 or replay.state == 3 or replay.state == 4)
		and 15 < state_past
		and ((0 < key.st1 and state_past >= key.st1)
		or (0 < key.st2 and state_past >= key.st2)) then
		replay.state = 1
		replay.state_last_frame = ec
		return
	elseif replay.state == 3 and replay.max_fc <= state_past then
		replay.state = 4
		replay.state_last_frame = ec
	end

	if replay.state == 1 then
	elseif replay.state == 12 then
	elseif replay.state == 22 then
	elseif replay.state == 3 and slow.phase() == 0 then
		local slow_buttons = slow.buttons() --スロー中のボタンフィルタ用
		local kiox = cur_slot.rec_controll == 2 and kio1 or kio2
		kiox = bit.bor(kiox, slow_buttons["P"..cur_slot.rec_controll.." Button A"] == false and 0x10 or 0x00)
		kiox = bit.bor(kiox, slow_buttons["P"..cur_slot.rec_controll.." Button B"] == false and 0x10 or 0x00)
		kiox = bit.bor(kiox, slow_buttons["P"..cur_slot.rec_controll.." Button C"] == false and 0x10 or 0x00)
		kiox = bit.bor(kiox, slow_buttons["P"..cur_slot.rec_controll.." Button D"] == false and 0x10 or 0x00)

		cur_slot.rec_fc = cur_slot.rec_fc + 1
		cur_slot.rec_buff_max_fc = cur_slot.rec_fc
		cur_slot.rec_buff[cur_slot.rec_fc] = kiox
		cur_slot.rec_side[cur_slot.rec_fc] = 0 > memory.readwordsigned(0x100420) - memory.readwordsigned(0x100520)
	elseif replay.state == 3 and slow.phase() ~= 0 then
	elseif replay.state == 4 then
	else
		replay.state = 1
		replay.state_last_frame = 0
		return
	end
end

-- [リプレイモード]
-- バッファなし状態：
--  state = -1
--  レコーディングバッファが空の場合は警告表示してなにもしない
--
-- スタート待機状態：
--  state = -2
--  1Pスタートか2Pスタートでレコーディングの再生開始前処理シーケンスへ移動
--
-- 再生開始前処理シーケンス状態：
--  state = -3
--  スタートボタンでスタート待機状態へ
--  位置補正が完了したら再生状態へ
--
-- 再生状態：
--  state = -4
--  スタートボタンでスタート待機状態へ
--  レコーディングバッファを全再生か60秒経過かメニュー遷移で再生後処理シーケンスへ
--  設定でヒット時に中断する場合は被ダメージなどのキャラ状態変更で再生後処理シーケンスへ
--
-- 再生後処理シーケンス状態：
--  state = -5
--  スタートボタンでスタート待機状態へ
--  設定を確認して再実行する場合は再生開始前処理シーケンスへ
--  1回で終わりであればスタート待機状態へ
--
replay.replay = function()
	local cur_slot = replay.slots[replay.active_slot]
	local kio1, kio2, _, key, pre_key = rb2key.capture_keys()
	local ec = emu.framecount()
	local state_past = ec - replay.state_last_frame

	if cur_slot.rec_buff_max_fc == 0 then
		replay.state = -1
		return
	elseif replay.state == -1 then
		replay.state = -2
	end

	if (replay.state == -2)
		and 15 < state_past
		and ((0 < key.st1 and state_past >= key.st1)
		or (0 < key.st2 and state_past >= key.st2)) then
		replay.state = -3
		replay.state_last_frame = ec
		return
	elseif replay.state == -3 and replay.position_mode == 1
		and (
		(cur_slot.rec_controll == 2 and memory.readbyte(0x10058E) == 0 and memory.readbyte(0x10054A) == 0)
		or
		(cur_slot.rec_controll == 1 and memory.readbyte(0x10048E) == 0 and memory.readbyte(0x10044A) == 0)
		) then
		if cur_slot.rec_p1_pos == memory.readwordsigned(0x100420)
			and cur_slot.rec_p2_pos == memory.readwordsigned(0x100520) then
			replay.state = -4
			replay.state_last_frame = ec
			cur_slot.rec_fc = 0
			memory.writebyte(0x1004BC, cur_slot.rec_p1_pow)
			memory.writebyte(0x1004BC, cur_slot.rec_p2_pow)
			memory.writebyte(0x10B84E + 0x02, 0)
			memory.writebyte(0x10B84E + 0x08 + 0x02, 0)
			memory.writebyte(0x10B84E + 0x06, 0)
			memory.writebyte(0x10B84E + 0x08 + 0x06, 0)
		else
			memory.writeword(0x100420, cur_slot.rec_p1_pos )
			memory.writeword(0x100520, cur_slot.rec_p2_pos)
		end
		return
	elseif replay.state == -3 and replay.position_mode == 2
		and (
		(cur_slot.rec_controll == 2 and memory.readbyte(0x10058E) == 0 and memory.readbyte(0x10054A) == 0)
		or
		(cur_slot.rec_controll == 1 and memory.readbyte(0x10048E) == 0 and memory.readbyte(0x10044A) == 0)
		) then
		-- enemy in relative position
		local offset_addr, retl_addr = 0x100420, 0x100520
		if cur_slot.rec_controll == 1 then
			offset_addr, retl_addr = 0x100520, 0x100420
		end
		local offset_pos = memory.readwordsigned(offset_addr)
		local retl_pos = offset_pos
		if 0 > offset_pos - memory.readwordsigned(retl_addr) then
			retl_pos = retl_pos + math.abs(cur_slot.rec_start_pos_diff)
		else
			retl_pos = retl_pos - math.abs(cur_slot.rec_start_pos_diff)
		end
		if 604 < retl_pos then
			offset_pos = offset_pos - (retl_pos - 604)
			retl_pos = 604
		elseif 36 > retl_pos then
			offset_pos = offset_pos + (36 - retl_pos)
			retl_pos = 36
		end
		if memory.readwordsigned(offset_addr) == offset_pos
			and memory.readwordsigned(retl_addr) == retl_pos then
			replay.state = -4
			replay.state_last_frame = ec
			cur_slot.rec_fc = 0
			memory.writebyte(0x1004BC, cur_slot.rec_p1_pow)
			memory.writebyte(0x1004BC, cur_slot.rec_p2_pow)
			memory.writebyte(0x10B84E + 0x02, 0)
			memory.writebyte(0x10B84E + 0x08 + 0x02, 0)
			memory.writebyte(0x10B84E + 0x06, 0)
			memory.writebyte(0x10B84E + 0x08 + 0x06, 0)
		else
			memory.writeword(offset_addr, offset_pos)
			memory.writeword(retl_addr, retl_pos)
		end
		return
	elseif replay.state == -3 and replay.position_mode == 0
		and (
		(cur_slot.rec_controll == 2 and memory.readbyte(0x10058E) == 0 and memory.readbyte(0x10054A) == 0)
		or
		(cur_slot.rec_controll == 1 and memory.readbyte(0x10048E) == 0 and memory.readbyte(0x10044A) == 0)
		) then
		replay.state = -4
		replay.state_last_frame = ec
		cur_slot.rec_fc = 0
		memory.writebyte(0x1004BC, cur_slot.rec_p1_pow)
		memory.writebyte(0x1004BC, cur_slot.rec_p2_pow)
		memory.writebyte(0x10B84E + 0x02, 0)
		memory.writebyte(0x10B84E + 0x08 + 0x02, 0)
		memory.writebyte(0x10B84E + 0x06, 0)
		memory.writebyte(0x10B84E + 0x08 + 0x06, 0)
		return
	elseif replay.state == -4 and cur_slot.rec_fc >= cur_slot.rec_buff_max_fc then
		replay.state = -5
		replay.state_last_frame = ec
		return
	elseif replay.state == -5 and replay.replay_repeat then
		replay.state = -3
		replay.state_last_frame = ec
		return
	elseif replay.state == -5 and not replay.replay_repeat then
		replay.state = -1
		replay.state_last_frame = ec
		return
	elseif (replay.state == -3 or replay.state == -4 or replay.state == -5)
		and replay.on_damage_stop
		and (
		(cur_slot.rec_controll == 2 and memory.readbyte(0x10058E) ~= 0)
		or
		(cur_slot.rec_controll == 1 and memory.readbyte(0x10048E) ~= 0)
		) then
		replay.state = -1
		replay.state_last_frame = ec
		return
	elseif (replay.state == -3 or replay.state == -4 or replay.state == -5)
		and 15 < state_past
		and ((0 < key.st1 and state_past >= key.st1)
		or (0 < key.st2 and state_past >= key.st2)) then
		replay.state = -1
		replay.state_last_frame = ec
		return
	end

	if replay.state == -1 then
	elseif replay.state == -2 then
	elseif replay.state == -3 then
	elseif replay.state == -4 and slow.phase() == 0 then
		local p1_in_p1_side = 0 > memory.readwordsigned(0x100420) - memory.readwordsigned(0x100520)
		--memory.writebyte(cur_slot.rec_controll == 1 and 0x1004CD or 0x1005CD, 0x5F) --cheat Motion blur
		cur_slot.rec_fc = cur_slot.rec_fc < cur_slot.rec_buff_max_fc and cur_slot.rec_fc + 1 or 1
		local input = bit.bxor(cur_slot.rec_buff[cur_slot.rec_fc], 0xFF)
		local rec_on_p1_side = cur_slot.rec_side[cur_slot.rec_fc]
		local tbl = {
			["P"..cur_slot.rec_controll.." Button D"] = bit.band(input, 0x80) == 0x80,
			["P"..cur_slot.rec_controll.." Button C"] = bit.band(input, 0x40) == 0x40,
			["P"..cur_slot.rec_controll.." Button B"] = bit.band(input, 0x20) == 0x20,
			["P"..cur_slot.rec_controll.." Button A"] = bit.band(input, 0x10) == 0x10,
			["P"..cur_slot.rec_controll.." Right"   ] = bit.band(input, 0x08) == 0x08,
			["P"..cur_slot.rec_controll.." Left"    ] = bit.band(input, 0x04) == 0x04,
			["P"..cur_slot.rec_controll.." Down"    ] = bit.band(input, 0x02) == 0x02,
			["P"..cur_slot.rec_controll.." Up"      ] = bit.band(input, 0x01) == 0x01,
		}
		if p1_in_p1_side ~= rec_on_p1_side then
			tbl["P"..cur_slot.rec_controll.." Right"   ] = bit.band(input, 0x04) == 0x04
			tbl["P"..cur_slot.rec_controll.." Left"    ] = bit.band(input, 0x08) == 0x08
		end
		joypad.set(tbl)
	elseif replay.state == -4 and slow.phase() ~= 0 then

	elseif replay.state == -5 then
	else
		replay.state = 1
		replay.state_last_frame = ec
		return
	end
end

player_controll = {}

player_controll.apply_player_controll = function()
	controll_config.apply_player_controll()
	if controll_config.mode == 1 then
		replay.record()
	elseif controll_config.mode == 2 then
		player_controll.config_player_controll(1, 2)
		replay.replay()
	elseif controll_config.mode == 3 then
		player_controll.config_player_controll(1, 3)
	elseif controll_config.mode == 4 then
		player_controll.config_player_controll(3, 1)
	elseif controll_config.mode == 5 then
		player_controll.config_player_controll(3, 3)
	else
		player_controll.config_player_controll(1, 2)
	end
end

player_controll.config_mode_record = function()
	controll_config.mode = 1
	replay.init_replay_state(1)
end

player_controll.config_mode_replay = function()
	controll_config.mode = 2
	replay.init_replay_state(2)
end

player_controll.config_mode_off = function()
	controll_config.mode = 0
	replay.init_replay_state(0)
end

player_controll.config_mode_cpu = function(pside)
	controll_config.mode = pside == 1 and 3 or pside == 2 and 4 or 5
	replay.init_replay_state(0)
end

player_controll.config_player_controll = function(p1, p2)
	controll_config.p1 = p1
	controll_config.p2 = p2
	controll_config.apply_player_controll()
end

player_controll.config_player_slot = set_slot

player_controll.draw_playing_status = function()
	if controll_config.mode == 1 then
		replay.draw_recording_status()
	elseif controll_config.mode == 2 then
		replay.draw_playing_status()
	end
end

player_controll.config_replay_repeat = function(flg)
	replay.replay_repeat = flg
end

player_controll.config_replay_on_damage_stop = function(flg)
	replay.on_damage_stop = flg
end

player_controll.config_replay_position_fixed    = function()
	replay.position_mode = 1
end

player_controll.config_replay_position_relative = function()
	replay.position_mode = 2
end

player_controll.config_replay_position_off      = function()
	replay.position_mode = 0
end

player_controll.init_replay_state = replay.init_replay_state

player_controll.each_replay_slots = function(callback)
	for i = 1, #replay.slots do
		if replay.slots[i] then
			pcall(function() callback(i, replay.slots[i]) end)
		end
	end
end

player_controll.hack_player_select = function()
	local kio1, kio2, kio3, key, pre_key = rb2key.capture_keys()
	local ec = emu.framecount()
	local state_past = ec - fix_player_select.on_select_frame

	-- stop the PLAYER SELECT timer
	for i = 0, 0xA00, 0x100 do
		memory.writebyte(0x1020B2 + i, 0x0A)
	end

	local p1 = memory.readbyte(0x107BA5)
	local p2 = memory.readbyte(0x107BA7)
	if fix_player_select.on_start_frame == ec or fix_player_select.on_select_frame == ec then
		if p1 == 0xFF or p2 == 0xFF then
			fix_player_select.apply_vs_mode()
		end
	elseif fix_player_select.on_start_frame < ec and 8 < state_past then
		-- copy joypad for enemy's cursor
		if p1 ~= 0xFF and p2 == 0xFF then
			if 0 < key.up or 0 < key.dn or 0 < key.lt or 0 < key.rt then
				fix_player_select.copy_joypad(1, 2)
			end
			if (0 < key.a and state_past > key.a) or (0 < key.d and state_past > key.d) then
				fix_player_select.copy_buttons(1, 2)
			end
		elseif p1 == 0xFF and p2 ~= 0xFF then
			if 0 < key.up or 0 < key.dn or 0 < key.lt or 0 < key.rt then
				fix_player_select.copy_joypad(2, 1)
			end
			if (0 < key.a and state_past > key.a) or (0 < key.d and state_past > key.d) then
				fix_player_select.copy_buttons(2, 1)
			end
		end
	end
end

player_controll.apply_vs_mode = fix_player_select.apply_vs_mode
