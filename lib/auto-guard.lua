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

math.randomseed(os.time())

local function Set(list)
	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end

local move_type = {
	unknown = -1,
	attack = 0,
	low_attack = 1,
	provoke = 2, --挑発
}

local guard_config = {
	players = {},

	pos_diff = memory.readwordsigned(0x100420) - memory.readwordsigned(0x100520),
	prev_pos_diff = memory.readwordsigned(0x100420) - memory.readwordsigned(0x100520),

	func_passive_general = nil, -- 行動振り分け用関数
	func_passive_forward = nil, -- 前進行動
	func_passive_forward_disabled = function(player) end,
	func_passive_no_guard = function(player) end,
	func_passive_guard = nil, -- 常にガード
	func_passive_guard1_hit = nil, -- 初回だけガード
	func_passive_hit1_guard = nil, -- 初回だけノーガード
	is_hit_or_guard = nil, -- 状態確認して返す
	random_boolean = function() return math.random(255) % 2 == 0 end, --50％で抽選
	func_passive_random_guard = nil,  -- ランダムでガード
	func_passive_random_hit = nil,  -- ランダムでヒット
	func_passive_random_keep = nil,  -- ランダムガードコア関数
	func_counter_move = nil, -- 任意のコマンド入力
}

guard_config.func_counter_move = function(player)
	local tbl ={}-- joypad.get(tbl)
	local diff = guard_config.pos_diff
	if guard_config.pos_diff == 0 then
		diff = guard_config.prev_pos_diff
	end
	local pos_judge = player.pside * guard_config.pos_diff
	for _, k in pairs(player.counter_move.command[player.counter_move.count]) do
		if k == "Front" then
			if 0 < pos_judge then
				tbl["P" .. player.opponent_num .. " Left"] = true
			elseif 0 > pos_judge then
				tbl["P" .. player.opponent_num .. " Right"] = true
			end
		elseif k == "Back" then
			if 0 < pos_judge then
				tbl["P" .. player.opponent_num .. " Right"] = true
			elseif 0 > pos_judge then
				tbl["P" .. player.opponent_num .. " Left"] = true
			end
		else
			tbl["P" .. player.opponent_num .. " " .. k] = true
		end
	end
	joypad.set(tbl)

	player.counter_move.count = (player.counter_move.count + 1) % #player.counter_move.command
	if player.counter_move.count == 0 then
		player.counter_move.count = #player.counter_move.command
	elseif player.counter_move.count == 1 then
		-- 両プレイヤーの状態が安定するまで待つ
		local await = emu.framecount() + 20
		player.func_passive = function(player)
			if await < emu.framecount()
				and 0 == memory.readbyte(player.guard_addr)
				and 0 == memory.readbyte(player.opponent_guard_addr)
				and 0 == memory.readbyte(0x1004B6)
				and 0 == memory.readbyte(0x1005B6)
			then
				player.func_passive = guard_config.func_passive_general
				player.func_passive_guard = guard_config.func_counter_move
			end
		end
	else
		player.func_passive = guard_config.func_counter_move
	end
end

local low_attacks = {
	-- TERRY
	Set { 0x8, 0x32, 0x37, 0x9, 0x3E, 0x3B, 0x8E, 0x8F, 0x18, 0x1E, },
	-- ANDY
	Set { 0x8, 0x32, 0x37, 0x9, 0x3E, 0x3B, 0x8E, 0x8F, 0x18, 0x1E, },
	-- JOE
	Set { 0x8, 0x9, 0x36, 0x31, 0x42, 0x27, 0x34, 0x18, 0x1E, },
	-- MAI
	Set { 0x8, 0x9, 0x39, 0x3C, 0x18, 0x1E, },
	-- GEESE
	Set { 0x8, 0x32, 0x37, 0x9, 0x33, 0x41, 0x39, 0x3A, 0x18, 0x19, 0x1E, },
	-- SOKAKU
	Set { 0x8, 0x9, 0x16, 0x34, 0x3D, 0x3B, 0x88, 0x18, 0x76, 0x1E, },
	-- BOB
	Set { 0x8, 0x3A, 0x32, 0x35, 0x9, 0x18, 0x7C, 0x7D, 0x76, 0x1E, },
	-- HON
	Set { 0x36, 0x8, 0x3B, 0x9, 0x18, 0x43, 0x41, 0x83, 0x1B, 0x1E, },
	-- MARRY
	Set { 0x8, 0x9, 0x18, 0x41, 0x37, 0x2E, 0x7C, 0x7D, 0x94, 0x1E, },
	-- BASH
	Set { 0x8, 0x9, 0x18, 0x35, 0x37, 0x33, 0x38, 0x1E, },
	-- YAMAZAKI
	Set { 0x18, 0x19, 0x8, 0x9, 0x32, 0x7D, 0x75, 0x1E, },
	-- CHONSHU
	Set { 0x8, 0x9, 0x18, 0x3C, 0x3B, 0x38, 0x1E, },
	-- CHONREI
	Set { 0x8, 0x9, 0x35, 0x37, 0x3A, 0x70, 0x18, 0x1E, },
	-- DUCK
	Set { 0x8, 0x9, 0x27, 0x35, 0x3D, 0x3F, 0x18, 0xCA, 0xCB, 0xCC, 0x1E, },
	-- KIM
	Set { 0x8, 0x7, 0x9, 0x18, 0x8E, 0x83, 0x1E, },
	-- BILLY
	Set { 0x8, 0x9, 0x18, 0x31, 0x3, 0x1E, },
	-- CHIN
	Set { 0x8, 0x9, 0x18, 0x3A, 0x36, 0x94, 0x3E, 0x3F, 0x37, 0x40, 0x3, 0x82, 0x88, 0x1E, },
	-- TUNG
	Set { 0x8, 0x9, 0x18, 0x1E, },
	-- LAURENCE
	Set { 0x8, 0x9, 0x18, 0x33, 0x36, 0x1E, },
	-- KRAUSER
	Set { 0x8, 0x9, 0x18, 0x34, 0x1E, },
	-- RICK
	Set { 0x8, 0x32, 0x3A, 0x9, 0x18, 0x37, 0xC4, 0x1E, },
	-- XIANGFEI
	Set { 0x8, 0x9, 0x48, 0x33, 0x3E, 0x47, 0x18, 0x1E, 0xA0, },
	-- ALFRED
	Set {0x8, 0x9, 0x8E, 0x1E, },
}

local attacks = {}

local apply_guard = nil

apply_guard = function(pos_judge, player)
	local prev_left, prev_right = player.left, player.right
	if 0 < pos_judge then
		player.left = false
		player.right = true
	elseif 0 > pos_judge then
		player.left = true
		player.right = false
	else
		apply_guard(player.prev_pos_judge, player)
	end
	player.prev_pos_judge = pos_judge
end

guard_config.func_passive_general = function(player)
	local move = player.get_attack_type()
	if move == move_type.attack or move == move_type.low_attack then
		player.func_passive_guard(player)
		player.back_step_kill = false
	elseif move == move_type.provoke then
		player.func_passive_forward(player)
		player.back_step_kill = true
	else
		-- バックステップ防止のため一瞬下に入力する
		if not player.back_step_kill then
			local _, _, _, _, pre_key = rb2key.capture_keys()
			if 0 < pre_key["lt"..player.opponent_num]
			or 0 < pre_key["rt"..player.opponent_num] then
				joypad.set({["P" .. player.opponent_num .. " Down"] = true })
			end
			player.back_step_kill = true
		end
	end
end

guard_config.func_passive_forward = function(player)
	local tbl ={}-- joypad.get(tbl)

	local pos_judge = player.pside * guard_config.pos_diff
	if math.abs(pos_judge) > 90 then
		if 90 < pos_judge then
			tbl["P" .. player.opponent_num .. " Left"] = true
		elseif 90 > pos_judge then
			tbl["P" .. player.opponent_num .. " Right"] = true
		end
	end

	joypad.set(tbl)
end

guard_config.func_passive_guard = function(player)
	local tbl ={}-- joypad.get(tbl)

	local pos_judge = player.pside * guard_config.pos_diff
	if 0 == pos_judge then
		if player.left == false and player.right == false then
			--print("!!") --軸一致
			apply_guard(pos_judge, player)
		end
	else
		apply_guard(pos_judge, player)
	end
	tbl["P" .. player.opponent_num .. " Left"] = player.left
	tbl["P" .. player.opponent_num .. " Right"] = player.right
	tbl["P" .. player.opponent_num .. " Down"] = player.get_attack_type() == move_type.low_attack

	joypad.set(tbl)
end

guard_config.is_hit_or_guard = function(expected, -- 1 is hit, 2 is guard
	player)
	return player.guard_or_hit == emu.framecount() and expected == memory.readbyte(player.guard_addr)
end

guard_config.func_passive_guard1_hit = function(player)
	guard_config.func_passive_guard(player)
	if guard_config.is_hit_or_guard(2, player) then
		local await = emu.framecount() + 90 -- 90フレームだけガード
		player.func_passive_guard = function(player)
			if await < emu.framecount() then
				player.func_passive_guard = guard_config.func_passive_guard1_hit
				return guard_config.func_passive_guard(player)
			end
			return guard_config.func_passive_no_guard(player)
		end
	end
end

guard_config.func_passive_hit1_guard = function(player)
	if guard_config.is_hit_or_guard(1, player) then
		local await = emu.framecount() + 90
		player.func_passive_guard = function(player)
			if await < emu.framecount() then
				player.func_passive_guard = guard_config.func_passive_hit1_guard
				return guard_config.func_passive_no_guard(player)
			end
			return guard_config.func_passive_guard(player)
		end
	end
end

guard_config.func_passive_random_guard = function(player)
	guard_config.func_passive_guard(player)
	if guard_config.is_hit_or_guard(2, player) then
		player.func_passive_guard = guard_config.func_passive_random_keep(2)
	end
end

guard_config.func_passive_random_hit = function(player)
	if guard_config.is_hit_or_guard(1, player) then
		player.func_passive_guard = guard_config.func_passive_random_keep(1)
	end
end

guard_config.func_passive_random_keep = function(expected, -- 1 is hit, 2 is guard
	player)
	return function(player) -- カリー化しておく
		if expected == 2 then
			guard_config.func_passive_guard(player)
	end
	if guard_config.is_hit_or_guard(0, player) then
		if guard_config.random_boolean() then
			player.func_passive_guard = guard_config.func_passive_random_hit
		else
			player.func_passive_guard = guard_config.func_passive_random_guard
		end
	end
	end
end

for pside = -1, 1, 2 do
	-- バッグDIP ステータス表示のP
	-- 0x100460 下1桁表示
	-- 0x100461
	--
	-- バッグDIP ステータス表示のA
	-- 0x100462 下1桁表示
	-- 0x100463
	-- か
	-- 0x100464 下1桁表示
	-- 0x100465
	local p_addr = 0x100560
	local attack_addr = 0x1005B6
	local fireball_addr = 0x1007BF
	local fireball_pos_addrs = { 0x100720, 0x10072C, 0x100920, 0x10092C, 0x100B20, 0x100B2C }
	local opponent_guard_addr = 0x10058E
	local opponent_char_addr = 0x100511
	local guard_addr = 0x10048E
	local opponent_num = 1
	if pside == -1 then
		attack_addr = 0x1004B6
		fireball_addr = 0x1006BF
		fireball_pos_addrs = { 0x100620, 0x10062C, 0x100820, 0x10082C, 0x100A20, 0x100A2C }
		p_addr = 0x100460
		opponent_guard_addr = 0x10048E
		opponent_char_addr = 0x100411
		guard_addr = 0x10058E
		opponent_num = 2
	end

	local player = {
		pside = pside,
		left = false,
		right = false,
		down = false,
		enable_auto_guard = true,
		enable_low_guard = false,

		counter_move = {
			count = 0,
			command = { },
		},
		set_counter_move = nil,

		func_passive_guard = guard_config.func_passive_guard,
		func_passive_forward = guard_config.func_passive_forward,
		func_passive = guard_config.func_passive_general,

		guard_or_hit = 0, --framecount
		shot_fireball = 0, --framecount

		opponent_num = opponent_num,
		opponent_guard_addr = opponent_guard_addr,
		addr = attack_addr,
		guard_addr = guard_addr,
		prev_pos_judge = pside,
		get_attack_type = nil,
		last_fireball_frame = 0,
	}
	memory.registerwrite(fireball_addr, function() player.last_fireball_frame = emu.framecount() end)
	for i = 1, #fireball_pos_addrs do
		memory.registerwrite(fireball_pos_addrs[i], function() player.last_fireball_frame = emu.framecount() end)
	end

	player.get_attack_type = function()
		local player = guard_config.players[pside]
		local state =  memory.readbyte(opponent_guard_addr)
		if state == 0 then
			local attack = memory.readbyte(attack_addr)
			if attack ~= 0 then
				if player.enable_low_guard
					or (player.enable_auto_guard and low_attacks[memory.readbyte(opponent_char_addr)][attack]) then
					return move_type.low_attack
				end
				return move_type.attack
					--elseif player.shot_fireball <= emu.framecount() and 0 < memory.readbyte(fireball_addr) then
					--	return move_type.attack
			elseif 0x0196 == memory.readword(p_addr) then
				return move_type.provoke
			end
		end
		-- fireball 最終更新から30フレーム持続
		if player.last_fireball_frame ~= 0 and 30 > emu.framecount() - player.last_fireball_frame then
			return move_type.attack
		end
		return move_type.unknown
	end

	memory.registerwrite(guard_addr, function() player.guard_or_hit = emu.framecount() end)
	memory.registerwrite(fireball_addr, function() player.shot_fireball = emu.framecount() end)

	player.set_counter_move = function(command)
		guard_config.players[pside].counter_move.count = 1
		guard_config.players[pside].counter_move.command = command
	end

	guard_config.players[pside] = player
end

auto_guard = {}

auto_guard.update_guard = function()
	guard_config.pos_diff = memory.readwordsigned(0x100420) - memory.readwordsigned(0x100520)
	if guard_config.pos_diff ~= 0 then
		guard_config.prev_pos_diff = guard_config.pos_diff
	end
	for pside, player in pairs(guard_config.players) do
		player.func_passive(player)
	end
end

auto_guard.draw_guard_status = function()
	gui.text(160-8, 217, guard_config.pos_diff, 0xFFFFFFFF)
end

---public config
-- pside is -1=1P, 1=2P

-- 挑発を受けた時の前進行動
auto_guard.config_forward        = function(enabled)
	for pside = -1, 1, 2 do
		guard_config.players[pside].func_passive_forward = 
			enabled and guard_config.func_passive_forward or guard_config.func_passive_forward_disabled
	end
end

-- ノーガード
auto_guard.config_no_guard       = function(pside)
	guard_config.players[pside].func_passive = guard_config.func_passive_general
	guard_config.players[pside].func_passive_guard = guard_config.func_passive_no_guard
end

-- 自動ガード 実験的
auto_guard.config_auto_guard     = function(pside)
	guard_config.players[pside].func_passive = guard_config.func_passive_general
	guard_config.players[pside].func_passive_guard = guard_config.func_passive_guard
	guard_config.players[pside].enable_auto_guard = true
	guard_config.players[pside].enable_low_guard = false
end

-- 立ちガード
auto_guard.config_standing_guard = function(pside)
	guard_config.players[pside].func_passive = guard_config.func_passive_general
	guard_config.players[pside].func_passive_guard = guard_config.func_passive_guard
	guard_config.players[pside].enable_auto_guard = false
	guard_config.players[pside].enable_low_guard = false
end

-- しゃがみガード
auto_guard.config_crouching_guard = function(pside)
	guard_config.players[pside].func_passive = guard_config.func_passive_general
	guard_config.players[pside].func_passive_guard = guard_config.func_passive_guard
	guard_config.players[pside].enable_auto_guard = false
	guard_config.players[pside].enable_low_guard = true
end

-- 初回だけノーガード
auto_guard.config_1hit_guard     = function(pside)
	guard_config.players[pside].func_passive = guard_config.func_passive_general
	guard_config.players[pside].func_passive_guard = guard_config.func_passive_hit1_guard
end

-- ランダムガード
auto_guard.config_random_guard   = function(pside)
	guard_config.players[pside].func_passive = guard_config.func_passive_general
	guard_config.players[pside].func_passive_guard = guard_config.func_passive_random_keep(0)
end

-- スウェー
local sway = {
	{ "Button D" },
}
auto_guard.config_sway           = function(pside)
	guard_config.players[pside].func_passive = guard_config.func_passive_general
	guard_config.players[pside].set_counter_move(sway)
	guard_config.players[pside].func_passive_guard = guard_config.func_counter_move
end

-- 避け攻撃
local attack_avoider = {
	{ "Button A", "Button B" },
}
auto_guard.config_attack_avoider = function(pside)
	guard_config.players[pside].func_passive = guard_config.func_passive_general
	guard_config.players[pside].set_counter_move(attack_avoider)
	guard_config.players[pside].func_passive_guard = guard_config.func_counter_move
end

-- 詠酒・対立ち攻撃
local esaka_anti_stand = {
	{ "Button A" },
	{ "Button A" },
	{ "Button A" , "Front" },
}
auto_guard.config_esaka_anti_stand = function(pside)
	guard_config.players[pside].func_passive = guard_config.func_passive_general
	guard_config.players[pside].set_counter_move(esaka_anti_stand)
	guard_config.players[pside].func_passive_guard = guard_config.func_counter_move
end

-- 詠酒・対しゃがみ攻撃
local esaka_anti_crouch = {
	{ "Button A" },
	{ "Button A" },
	{ "Button A" , "Down" },
}
auto_guard.config_esaka_anti_crouch = function(pside)
	guard_config.players[pside].func_passive = guard_config.func_passive_general
	guard_config.players[pside].set_counter_move(esaka_anti_crouch)
	guard_config.players[pside].func_passive_guard = guard_config.func_counter_move
end

-- 詠酒・対ジャンプ攻撃
local esaka_anti_air = {
	{ "Button A" },
	{ "Button A" },
	{ "Button A" , "Up" },
}
auto_guard.config_esaka_anti_air = function(pside)
	guard_config.players[pside].func_passive = guard_config.func_passive_general
	guard_config.players[pside].set_counter_move(esaka_anti_air)
	guard_config.players[pside].func_passive_guard = guard_config.func_counter_move
end
