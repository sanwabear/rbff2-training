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

get_digit = function(num)
	return string.len(tostring(num))
end

function new_env(scriptfile)
	local env = setmetatable({}, {__index=_G})
	pcall(assert(loadfile(scriptfile, env)))
	return env
end

rbff2wb = function(a, v)
	-- ignore bios address
	if 0x10FCEF <= a and a <= 0x10FEFB then
		return
	end
	memory.writebyte(a, AND(v, 0xFF))
end

local fc = emu.framecount

mem_last_time    = 0 --最終読込フレーム(キャッシュ用)
mem_0x100400     = 0 --Base p1
mem_0x100500     = 0 --Base p2
mem_0x100701     = 0 --場面判定用
mem_0x102557     = 0 --場面判定用
mem_0x107C22     = 0 --場面判定用
mem_0x10FDAF     = 0 --場面判定用
mem_0x10FDB6     = 0 --P1 P2 開始判定用
mem_0x10FD82     = 0 --console 0x00, mvs 0x01
mem_0x1041D2     = 0 --unpause 0x00, pause 0xFF
mem_reg_sts_b    = 0 --REG_STATUS_B
mem_stage        = 0 --ステージ
mem_stage_tz     = 0 --ステージバリエーション(Timezone)
mem_bgm          = 0 --BGM
mem_0x10D4E6     = 0 --潜在発動時の停止時間
mem_0x10B862     = 0 --ガードヒット=FF

local mem_player_addr = {
	{
		act           = 0x100460, --行動ID デバッグディップステータス表示のPと同じ
		stop          = 0x10048D, --ヒットストップ
		tmp_combo     = 0x10B4E0, --コンボテンポラリ
		combo         = 0x10B4E4, --コンボ
		max_combo     = 0x10B4EF, --最大コンボ
		state         = 0x10048E, --状態
		last_dmg      = 0x10048F, --最終ダメージ
		char          = 0x107BA5, --キャラ
		color         = 0x107BAC, --カラー A=0x00 D=0x01
		reg_cnt       = 0x300000, --REG_P1CNT
		pos           = 0x100420, --位置

		attack        = 0x1004B6, --攻撃中のみ変化
		fireball      = 0x1006BF, --飛び道具のID
		fireball_pos  = { 0x100620, 0x10062C, 0x100820, 0x10082C, 0x100A20, 0x100A2C, }, --飛び道具の位置

		life          = 0x10048B, --体力
		pow           = 0x1004BC, --パワー
		max_stun      = 0x10B84E, --最大スタン値
		stun          = 0x10B84E+0x02, --現在スタン値
		stun_timer    = 0x10B854, --スタン値ゼロ化までの残フレーム数

		act_contact   = 0x100401, --通常=2、必殺技中=3 ガードヒット=5 潜在ガード=6

		no_hitstop1   = 0x10048D, --01=on
		no_hitstop2   = 0x1004B5, --01=on
		no_hitstop3   = 0x10048B, --01=on

	},
	{
		act           = 0x100560, --行動ID デバッグディップステータス表示のPと同じ
		stop          = 0x10058D, --ヒットストップ
		tmp_combo     = 0x10B4E1, --コンボテンポラリ
		combo         = 0x10B4E5, --コンボ
		max_combo     = 0x10B4F0, --最大コンボ
		state         = 0x10058E, --状態
		last_dmg      = 0x10058F, --最終ダメージ
		char          = 0x107BA7, --キャラ
		color         = 0x107BAD, --カラー A=0x00 D=0x01
		reg_cnt       = 0x340000, --REG_P2CNT
		pos           = 0x100520, --位置

		attack        = 0x1005B6, --攻撃中のみ変化
		fireball      = 0x1007BF, --飛び道具のID
		fireball_pos  = { 0x100720, 0x10072C, 0x100920, 0x10092C, 0x100B20, 0x100B2C, }, --飛び道具の位置

		life          = 0x10058B, --体力
		pow           = 0x1005BC, --パワー
		max_stun      = 0x10B84E+0x08,--最大スタン値
		stun          = 0x10B84E+0x08+0x02, --現在スタン値
		stun_timer    = 0x10B854+0x08, --スタン値ゼロ化までの残フレーム数

		act_contact   = 0x100501, --通常=2、必殺技中=3 ガードヒット=5 潜在ガード=6

		no_hitstop1   = 0x10058D, --01=on
		no_hitstop2   = 0x1005B5, --01=on
		no_hitstop3   = 0x10058B, --01=on
	}
}

local move_type = {
	unknown         = -1,
	attack          =  0,
	low_attack      =  1,
	provoke         =  2, --挑発
}

local function Set(list)
	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end

local low_attacks = { --配列のインデックス=キャラID
	--TERRY
	Set { 0x8, 0x32, 0x37, 0x9, 0x3E, 0x3B, 0x8E, 0x8F, 0x18, 0x1E, },
	--ANDY
	Set { 0x8, 0x32, 0x37, 0x9, 0x3E, 0x3B, 0x8E, 0x8F, 0x18, 0x1E, },
	--JOE
	Set { 0x8, 0x9, 0x36, 0x31, 0x42, 0x27, 0x34, 0x18, 0x1E, },
	--MAI
	Set { 0x8, 0x9, 0x39, 0x3C, 0x18, 0x1E, },
	--GEESE
	Set { 0x8, 0x32, 0x37, 0x9, 0x33, 0x41, 0x39, 0x3A, 0x18, 0x19, 0x1E, },
	--SOKAKU
	Set { 0x8, 0x9, 0x16, 0x34, 0x3D, 0x3B, 0x88, 0x18, 0x76, 0x1E, },
	--BOB
	Set { 0x8, 0x3A, 0x32, 0x35, 0x9, 0x18, 0x7C, 0x7D, 0x76, 0x1E, },
	--HON
	Set { 0x36, 0x8, 0x3B, 0x9, 0x18, 0x43, 0x41, 0x83, 0x1B, 0x1E, },
	--MARRY
	Set { 0x8, 0x9, 0x18, 0x41, 0x37, 0x2E, 0x7C, 0x7D, 0x94, 0x1E, },
	--BASH
	Set { 0x8, 0x9, 0x18, 0x35, 0x37, 0x33, 0x38, 0x1E, },
	--YAMAZAKI
	Set { 0x18, 0x19, 0x8, 0x9, 0x32, 0x7D, 0x75, 0x1E, },
	--CHONSHU
	Set { 0x8, 0x9, 0x18, 0x3C, 0x3B, 0x38, 0x1E, },
	--CHONREI
	Set { 0x8, 0x9, 0x35, 0x37, 0x3A, 0x70, 0x18, 0x1E, },
	--DUCK
	Set { 0x8, 0x9, 0x27, 0x35, 0x3D, 0x3F, 0x18, 0xCA, 0xCB, 0xCC, 0x1E, },
	--KIM
	Set { 0x8, 0x7, 0x9, 0x18, 0x8E, 0x83, 0x1E, },
	--BILLY
	Set { 0x8, 0x9, 0x18, 0x31, 0x3, 0x1E, },
	--CHIN
	Set { 0x8, 0x9, 0x18, 0x3A, 0x36, 0x94, 0x3E, 0x3F, 0x37, 0x40, 0x3, 0x82, 0x88, 0x1E, },
	--TUNG
	Set { 0x8, 0x9, 0x18, 0x1E, },
	--LAURENCE
	Set { 0x8, 0x9, 0x18, 0x33, 0x36, 0x1E, },
	--KRAUSER
	Set { 0x8, 0x9, 0x18, 0x34, 0x1E, },
	--RICK
	Set { 0x8, 0x32, 0x3A, 0x9, 0x18, 0x37, 0xC4, 0x1E, },
	--XIANGFEI
	Set { 0x8, 0x9, 0x48, 0x33, 0x3E, 0x47, 0x18, 0x1E, 0xA0, },
	--ALFRED
	Set { 0x8, 0x9, 0x8E, 0x1E, },
}

local init_stuns = { --配列のインデックス=キャラID
	32, --TERRY
	31, --ANDY
	32, --JOE
	29, --MAI
	33, --GEESE
	32, --SOKAKU
	31, --BOB
	31, --HON-FU
	29, --MARY
	35, --BASH
	38, --YAMAZAKI
	29, --CHONSHU
	29, --CHONREI
	32, --DUCK
	32, --KIM
	32, --BILLY
	31, --CHENG
	31, --TUNG
	35, --LAURENCE
	35, --KRAUSER
	32, --RICK
	29, --XIANGFEI
	32, --ALFRED
}
mem_biostest          = false
old_active            = false
match_active          = false
player_select_active = false
p_space               = 0
prev_p_space          = 0

rbff2player = {}

local bios_test = function(address)
	local ram_value = memory.readbyte(address)
	for _, test_value in ipairs({0x5555, 0xAAAA, AND(0xFFFF, address)}) do
		if ram_value == test_value then
			return true
		end
	end
end

readmems = function()
	local ec = emu.framecount()
	if mem_last_time == ec then
		return
	end

	mem_0x100400       = memory.readbyte(0x100400)
	mem_0x100500       = memory.readbyte(0x100500)
	mem_0x100701       = memory.readword(0x100701)
	mem_0x102557       = memory.readword(0x102557)
	mem_0x107C22       = memory.readword(0x107C22)
	mem_0x10FDAF       = memory.readbyte(0x10FDAF)
	mem_0x10FDB6       = memory.readword(0x10FDB6)
	mem_0x10FD82       = memory.readbyte(0x10FD82)
	mem_0x1041D2       = memory.readbyte(0x1041D2)
	mem_reg_sts_b      = memory.readbyte(0x380000)
	mem_biostest       = bios_test(0x100400) or bios_test(0x100500)
	mem_stage          = memory.readbyte(0x107BB1)
	mem_stage_tz       = memory.readbyte(0x107BB7)
	mem_bgm            = math.max(memory.readbyte(0x10A8D5), 1)
	mem_0x10D4E6       = memory.readbyte(0x10D4E6)
	mem_0x10B862       = memory.readbyte(0x10B862)
	if p_space ~= 0 then
		prev_p_space     = p_space
	end
	old_active         = match_active

	if not mem_biostest
		and mem_0x100701 >= 0x200
		--and (mem_0x107C22 == 0x3800 or mem_0x107C22 == 0x107C22 or mem_0x107C22 == 0x4400)
		and mem_0x107C22 == 0x4400
		and mem_0x10FDAF == 2
		and mem_0x10FDB6 ~= 0 then
		match_active = true
	else
		match_active = false
	end

	if not mem_biostest
		and not match_active
		and mem_0x100701 < 0x200 and mem_0x100701 >= 0x100
		and (mem_0x107C22 == 0x0000 or mem_0x107C22 == 0x5500)
		and mem_0x10FDAF == 2
		and mem_0x10FDB6 ~= 0
		and mem_0x102557 == 0x60 then
		player_select_active = true
	else
		player_select_active = false
	end

	--players
	for i = 1, 2 do
		local mem_p = mem_player_addr[i]
		rbff2player[i] = rbff2player[i] or {}
		rbff2player[3-i] = rbff2player[3-i] or {}
		local p = rbff2player[i]
		local op = rbff2player[3-i]
		p.act           = memory.readword(mem_p.act)
		p.stop          = memory.readbyte(mem_p.stop)
		p.tmp_combo     = tonumber(tohex(memory.readbyte(mem_p.tmp_combo)))
		p.combo         = p.combo or 0 --tonumber(tohex(memory.readbyte(mem_p.combo)))
		p.max_combo     = p.max_combo or 0 --tonumber(tohex(memory.readbyte(mem_p.max_combo)))
		p.state         = memory.readbyte(mem_p.state)
		p.last_dmg      = p.last_dmg or 0 --memory.readbyte(mem_p.last_dmg)
		p.char          = memory.readbyte(mem_p.char)
		p.reg_cnt       = memory.readbyte(mem_p.reg_cnt)
		p.pos           = memory.readwordsigned(mem_p.pos)

		p.attack        = memory.readbyte(mem_p.attack)
		p.fireball      = memory.readbyte(mem_p.fireball)
		p.fireball_pos  = p.fireball_pos or {}

		p.life          = memory.readbyte(mem_p.life)
		p.pow           = memory.readbyte(mem_p.pow)
		p.init_stun     = init_stuns[p.char]
		p.max_stun      = memory.readbyte(mem_p.max_stun)
		p.stun          = memory.readbyte(mem_p.stun)
		p.stun_timer    = memory.readword(mem_p.stun_timer)

		p.act_frames    = p.act_frames or {}
		p.act_contact   = memory.readbyte(mem_p.act_contact)
		p.hit_skip      = p.hit_skip or 0
		p.act_normal    = false
		if p.act < 0x8 or p.act == 0x1D or p.act == 0x1E
			or (0x20 <= p.act and p.act <= 0x23)
			or (0x2C <= p.act and p.act <= 0x2F)
			or (0x3C <= p.act and p.act <= 0x3F)
			--or (0x2C7 <= p.act and p.act <= 0x2C9) --Q.Standing
			or (0x6C == p.act and p.char == 12) --jin
			or ((0x108 <= p.act and p.act <=  0x10A) and p.char == 9) --marry
			or p.act == 0x40 then
			p.act_normal  = true
		end

		p.no_hitstop1   = memory.readbyte(mem_p.no_hitstop1)
		p.no_hitstop2   = memory.readbyte(mem_p.no_hitstop2)
		p.no_hitstop3   = memory.readbyte(mem_p.no_hitstop3)
		p.no_hitstop    = p.no_hitstop1 == 1 and p.no_hitstop2 == 1 and p.no_hitstop3 == 1


		for i = 1, #mem_p.fireball_pos do
			p.fireball_pos[i] = memory.readwordsigned(mem_p.fireball_pos[i])
		end
		p.last_fireball = p.last_fireball or 0

		p.combo_dmg     = p.combo_dmg or 0
		p.max_dmg       = p.max_dmg or 0
		p.cmb_disp_dmg  = p.cmb_disp_dmg or 0

		--攻撃種類,ガード要否
		p.provoke       = 0x0196 == p.act --挑発中
		p.attacy_type   = move_type.unknown
		op.need_block   = false
		op.need_low_block = false
		if p.attack ~= 0 and 0 < p.char and  p.char < 25 then
			if low_attacks[p.char][p.attack] then
				p.attacy_type = move_type.low_attack --下段攻撃
				op.need_block = true
				op.need_low_block = true
			else
				p.attacy_type = move_type.attack --否下段攻撃
				op.need_block = true
			end
		elseif p.last_fireball ~= 0 and 30 > fc() - p.last_fireball then
			--fireball 最終更新から30フレーム持続
			p.attacy_type = move_type.attack --飛び道具＝否下段攻撃
			op.need_block = true
		end
	end

	p_space = rbff2player[1].pos - rbff2player[2].pos

	for i = 1, 2 do
		local mem_p = mem_player_addr[3-i]
		local p = rbff2player[i]
		local op = rbff2player[3-i]

		--前進とガード方向
		local sp = p_space == 0 and prev_p_space or p_space
		sp = i == 1 and sp or (sp * -1)
		local lt, rt = "P"..i.." Left", "P"..i.." Right"
		p.block_side = 0 < sp and rt or lt
		p.front_side = 0 < sp and lt or rt

		--コンボダメージ更新
		if op.state == 0 then
			p.combo_dmg     = 0
		else
			p.combo         = p.tmp_combo
			p.max_combo     = math.max(p.max_combo, p.combo)
		end
		if op.update_dmg == ec then
			op.last_dmg     = memory.readbyte(mem_p.last_dmg)
			p.combo_dmg     = p.combo_dmg + op.last_dmg
			p.max_dmg       = math.max(p.max_dmg, p.combo_dmg)
			p.max_combo     = math.max(p.max_combo, p.combo)
			p.cmb_disp_dmg  = p.combo_dmg
		end

		--フレーム数
		p.frame_gap = p.frame_gap or 0
		p.last_frame_gap = p.last_frame_gap or 0
		local act_len = #p.act_frames
		if mem_0x10B862 ~= 0 and p.act_contact ~= 0 then
			p.hit_skip = 2
		end
		if p.no_hitstop then
			p.skip_frame = mem_0x10D4E6 ~= 0
		else
			p.skip_frame = p.hit_skip ~= 0 or p.stop ~= 0 or mem_0x10D4E6 ~= 0
		end

		if p.skip_frame then
			--停止フレームはフレーム計算しない
			if p.hit_skip ~= 0 then
				--ヒットストップの減算
				p.hit_skip = p.hit_skip - 1
			end
		else
			if act_len == 0 or p.update_act == ec or p.act_frames[act_len][1] ~= p.act then
				--行動IDの更新があった場合にフレーム情報追加
				if act_len > 20 then
					--バッファ長調整
					table.remove(p.act_frames, 1)
					act_len = #p.act_frames
				end
				--ガード移行できない行動をグレーにする
				local col = p.act_normal and 0xFFFFFFFF or 0xC0C0C0FF
				if p.act_frames[act_len] and p.act_frames[act_len][4]
					and p.state == 0 and not p.act_normal then
					--直前の行動がノーマルの場合は行動開始時の1Fのラグを考慮して開始2とする
					p.act_frames[act_len][2] = p.act_frames[act_len][2] - 1
					table.insert(p.act_frames, {p.act, 2, col, p.act_normal})
				else
					table.insert(p.act_frames, {p.act, 1, col, p.act_normal})
				end
			else
				--道津行動IDが継続している場合はフレーム値加算
				p.act_frames[act_len][2] = p.act_frames[act_len][2] + 1
			end
		end

		--フレーム差
		if not p.skip_frame or not op.skip_frame then
			if p.act_normal and op.act_normal then
				p.frame_gap = 0
			elseif not p.act_normal and not op.act_normal then
				p.frame_gap = 0
			elseif p.act_normal and not op.act_normal then
				p.frame_gap = p.frame_gap + 1
				p.last_frame_gap = p.frame_gap
			elseif not p.act_normal and op.act_normal then
				p.frame_gap = p.frame_gap - 1
				p.last_frame_gap = p.frame_gap
			end
		end
	end

	mem_last_time = ec
end
readmems()

--register hook
for i = 1, 2 do
	local mem_p = mem_player_addr[i]
	local p = rbff2player[i]
	--飛び道具射出の更新フック
	memory.registerwrite(mem_p.fireball, function() p.last_fireball = fc() end)
	--飛び座標の更新フック
	for i = 1, #mem_p.fireball_pos do
		memory.registerwrite(mem_p.fireball_pos[i], function() p.last_fireball = fc() end)
	end
	--ステータス更新フック
	memory.registerwrite(mem_p.state, function() p.update_sts = fc() end)
	--ダメージ更新フック
	memory.registerwrite(mem_p.last_dmg, function() p.update_dmg = fc() end)

	--技ID更新
	memory.registerwrite(mem_p.act, function() p.update_act = fc() end)
end

--key input
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
local rb2key_last_time = 0

--       REG_P1CNT, REG_P2CNT, REG_STATUS_B
--return 0x300000 , 0x340000 , 0x380000,    rb2key, rb2key_pre
rb2key.capture_keys = function()
	local p1 = rbff2player[1]
	local p2 = rbff2player[2]
	if rb2key_last_time == emu.framecount() then
		return p1.reg_cnt, p2.reg_cnt, mem_reg_sts_b, rb2key_now, rb2key_pre
	end

	readmems()

	for i = 1, kprops_len do
		local k = kprops[i]
		rb2key_pre[k] = rb2key_now[k]
	end

	local kio = p1.reg_cnt
	rb2key_now.d1  = AND(kio, 0x80) == 0x00 and posi_or_pl1(rb2key_now.d1 ) or nega_or_mi1(rb2key_now.d1 ) --P1 Button D
	rb2key_now.c1  = AND(kio, 0x40) == 0x00 and posi_or_pl1(rb2key_now.c1 ) or nega_or_mi1(rb2key_now.c1 ) --P1 Button C
	rb2key_now.b1  = AND(kio, 0x20) == 0x00 and posi_or_pl1(rb2key_now.b1 ) or nega_or_mi1(rb2key_now.b1 ) --P1 Button B
	rb2key_now.a1  = AND(kio, 0x10) == 0x00 and posi_or_pl1(rb2key_now.a1 ) or nega_or_mi1(rb2key_now.a1 ) --P1 Button A
	rb2key_now.rt1 = AND(kio, 0x08) == 0x00 and posi_or_pl1(rb2key_now.rt1) or nega_or_mi1(rb2key_now.rt1) --P1 Right
	rb2key_now.lt1 = AND(kio, 0x04) == 0x00 and posi_or_pl1(rb2key_now.lt1) or nega_or_mi1(rb2key_now.lt1) --P1 Left
	rb2key_now.dn1 = AND(kio, 0x02) == 0x00 and posi_or_pl1(rb2key_now.dn1) or nega_or_mi1(rb2key_now.dn1) --P1 Down
	rb2key_now.up1 = AND(kio, 0x01) == 0x00 and posi_or_pl1(rb2key_now.up1) or nega_or_mi1(rb2key_now.up1) --P1 Up

	kio = p2.reg_cnt
	rb2key_now.d2  = AND(kio, 0x80) == 0x00 and posi_or_pl1(rb2key_now.d2 ) or nega_or_mi1(rb2key_now.d2 ) --P2 Button D
	rb2key_now.c2  = AND(kio, 0x40) == 0x00 and posi_or_pl1(rb2key_now.c2 ) or nega_or_mi1(rb2key_now.c2 ) --P2 Button C
	rb2key_now.b2  = AND(kio, 0x20) == 0x00 and posi_or_pl1(rb2key_now.b2 ) or nega_or_mi1(rb2key_now.b2 ) --P2 Button B
	rb2key_now.a2  = AND(kio, 0x10) == 0x00 and posi_or_pl1(rb2key_now.a2 ) or nega_or_mi1(rb2key_now.a2 ) --P2 Button A
	rb2key_now.rt2 = AND(kio, 0x08) == 0x00 and posi_or_pl1(rb2key_now.rt2) or nega_or_mi1(rb2key_now.rt2) --P2 Right
	rb2key_now.lt2 = AND(kio, 0x04) == 0x00 and posi_or_pl1(rb2key_now.lt2) or nega_or_mi1(rb2key_now.lt2) --P2 Left
	rb2key_now.dn2 = AND(kio, 0x02) == 0x00 and posi_or_pl1(rb2key_now.dn2) or nega_or_mi1(rb2key_now.dn2) --P2 Down
	rb2key_now.up2 = AND(kio, 0x01) == 0x00 and posi_or_pl1(rb2key_now.up2) or nega_or_mi1(rb2key_now.up2) --P2 Up
	kio = mem_reg_sts_b
	rb2key_now.sl2 = AND(kio, 0x08) == 0x00 and posi_or_pl1(rb2key_now.sl2) or nega_or_mi1(rb2key_now.sl2) --Select P2
	rb2key_now.st2 = AND(kio, 0x04) == 0x00 and posi_or_pl1(rb2key_now.st2) or nega_or_mi1(rb2key_now.st2) --Start P2
	rb2key_now.sl1 = AND(kio, 0x02) == 0x00 and posi_or_pl1(rb2key_now.sl1) or nega_or_mi1(rb2key_now.sl1) --Select P1
	rb2key_now.st1 = AND(kio, 0x01) == 0x00 and posi_or_pl1(rb2key_now.st1) or nega_or_mi1(rb2key_now.st1) --Start P1

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
	rb2key_last_time = emu.framecount()

	return p1.reg_cnt, p2.reg_cnt, mem_reg_sts_b, rb2key_now, rb2key_pre
end
rb2key.capture_keys()

--メッシュの四角描画
gui_boxb = function(x1, y1, x2, y2, color1, color2, initb)
	local stepx = x1 < x2 and 1 or -1
	local stepy = y1 < y2 and 1 or -1
	for x = x1, x2, stepx do
		for y = y1, y2, stepy do
			initb = not initb
			if initb then
				gui.drawpixel(x, y, color2 or 0xCCCCFFFF)
			end
		end
	end
end

--外枠つきのメッシュの四角描画
gui_boxc = function(x1, y1, x2, y2, color1, color2, initb)
	gui.box(x1, y1, x2, y2, color1, color2)
	gui_boxb(x1, y1, x2, y2, color1, color2, initb)
end

--slow
rb2slow = {}

local slow_modes = {
	off       = 0,
	slow      = 1,
	step_a    = 2,
	step_b    = 3,
}

local slow_phases = {
	run       = 0, --動作フェーズ
	pre_run   = 1, --調査直前のポーズ解除フェーズ
	post_run  = 2, --動作後の初期フェーズ
	freez     = 3, --特別な処理がない待ちフェーズ
	tmp_run   = 4, --ステップ実行中の一時的な継続動作フェーズ
}

local slow_pause = {
	pause     = 0xFF,
	unpause   = 0x00,
}

local do_pause = function(v)
	if mem_0x10FD82 ~= 0x00 then
		if v == slow_pause.unpause then
			joypad.set({ ["Dip 1"] = AND(joypad.get()["Dip 1"] or 0x00, 0x7F) })
		else
			joypad.set({ ["Dip 1"] = OR (joypad.get()["Dip 1"] or 0x00, 0x80) })
		end
	else
		memory.writebyte(0x104191, v)
		memory.writebyte(0x1041D2, v)
	end
end

local slow_mode        = slow_modes.off
local slow_interval    = 3 --min=3
local slow_count       = 0
local slow_phase       = slow_phases.run
local slow_step_frame  = 0
local slow_run_frame   = 0
local slow_joybuff  = {}
local slow_joybuff2 = {}
local slow_joyprev  = {}
local slow_init = function()
	slow_mode        = slow_modes.off
	slow_interval    = 3 --min=3
	slow_count       = 0
	slow_phase       = slow_phases.run
	slow_step_frame  = 0
	slow_run_frame   = 0
	for i = 1, 2 do
		for _, v in pairs({"A", "B", "C", "D"}) do
			local k  = "P"..i.." Button "..v
			slow_joybuff[k] = false
			slow_joyprev[k] = false
		end
	end
end
slow_init()

fc = function()
	if slow_mode == slow_modes.off then
		return emu.framecount()
	else
		return slow_run_frame
	end
end

local next_slow_phase = function()
	local ct = (slow_count + 1) % slow_interval
	if ct == 0 then
		return ct, slow_phases.run
	elseif ct == 1 then
		return ct, slow_phases.post_run
	elseif ct == slow_interval - 1 then
		return ct, slow_phases.pre_run
	else
		return ct, slow_phases.freez
	end
end

local next_step_phase = function()
	local _, _, _, ck, _ = rb2key.capture_keys()
	local ec  = emu.framecount()
	local state_past = ec - slow_step_frame

	if slow_phase == slow_phases.freez then
		if 60 < ck.st then
			return slow_phases.tmp_run
		elseif 15 < state_past and 0 < ck.st and state_past >= ck.st then
			slow_step_frame = ec
			return slow_phases.pre_run
		end
	elseif slow_phase == slow_phases.run then
		if 60 < ck.st then
			--スタートおしっぱで一時的な継続動作フェーズへ移行する
			return slow_phases.tmp_run
		end
		return slow_phases.post_run
	elseif slow_phase == slow_phases.post_run then
		return slow_phases.freez
	elseif slow_phase == slow_phases.pre_run then
		return slow_phases.run
	elseif slow_phase == slow_phases.tmp_run then
		if 15 < ck.st and slow_mode == slow_modes.step_b then
			--スタートが離されるまで継続する
			return slow_phases.tmp_run
		end
	end
	return slow_phases.freez
end

local input_joybuff = function()
	local tbl = joypad.get()
	for k, v in pairs(slow_joybuff) do
		--前回ONでフラッシュされた場合は途中1フレでも離した場合、次回はOFFでフラッシュする...AND
		--前回OFFでフラッシュされた場合は途中1フレでも押した場合、次回はONでフラッシュする...OR
		if slow_joyprev[k] then
			slow_joybuff[k] = tbl[k] and slow_joybuff[k]
		else
			slow_joybuff[k] = tbl[k] or  slow_joybuff[k]
		end
		--前回ONの場合でOFFに切り替わった時点で、次回ON前に1FだけOFFにする...前回ONとのAND
		slow_joybuff2[k] = slow_joybuff2[k] and slow_joybuff[k]
	end
end

local unset_joybuff = function()
	input_joybuff() --フラッシュ前の最終バッファ更新
	local tbl = {}
	for k, v in pairs(slow_joybuff) do
		tbl[k]          = slow_joybuff2[k]
	end
	joypad.set(tbl)
end

local flush_joybuff = function()
	input_joybuff() --フラッシュ前の最終バッファ更新
	local tbl = {}
	for k, v in pairs(slow_joybuff) do
		slow_joyprev[k]  = slow_joybuff[k] --バッファコピー
		slow_joybuff2[k] = slow_joybuff[k]
		tbl[k]           = slow_joybuff[k]
	end
	joypad.set(tbl)
end

rb2slow.apply_slow = function()
	readmems()
	if not match_active then
		local tbl = joypad.get()
		for k, v in pairs(slow_joybuff) do
			slow_joyprev[k]  = tbl[k] --バッファコピー
			slow_joybuff2[k] = tbl[k]
		end
		return
	end

	if slow_mode == slow_modes.off then
		slow_count = 0
		slow_phase = slow_phases.run
		slow_run_frame = emu.framecount()
		return
	elseif slow_mode == slow_modes.slow then
		slow_count, slow_phase = next_slow_phase()
	else
		slow_phase = next_step_phase()
	end

	if slow_phase == slow_phases.pre_run then
		--ポーズ継続
		do_pause(slow_pause.pause)
		--入力バッファフラッシュ
		unset_joybuff()
		slow_run_frame = emu.framecount() + 1
	elseif slow_phase == slow_phases.run then
		--ポーズ解除
		do_pause(slow_pause.unpause)
		--入力バッファフラッシュ
		flush_joybuff()
		slow_run_frame = emu.framecount() + 1
	elseif slow_phase == slow_phases.tmp_run then
		--制御なしで継続動作
		do_pause(slow_pause.unpause)
		slow_run_frame = emu.framecount()
	else
		--ポーズ継続
		do_pause(slow_pause.pause)
		--入力バッファ開始
		input_joybuff()
	end
end

rb2slow.init = slow_init

rb2slow.term = function()
	do_pause(slow_pause.unpause)
end

rb2slow.config_mode_step_a = function()
	slow_init()
	slow_mode = slow_modes.step_a
end

rb2slow.config_mode_step_b = function()
	slow_init()
	slow_mode = slow_modes.step_b
end

rb2slow.config_mode_slow = function(interval)
	slow_init()
	slow_mode = slow_modes.slow
	slow_interval = interval
end

rb2slow.config_mode_off = function()
	slow_init()
	slow_mode = slow_modes.off
end

--emu.registerafter(rb2slow.apply_slow)
--emu.registerexit(rb2slow.term)
--emu.registerstart(rb2slow.init)
local apply_block = function()
	readmems()
	if not match_active then
		return
	end

	local prev = joypad.get()

	local tbl = {}
	for i = 1, 2 do
		local p = rbff2player[i]
		if p.need_block then
			tbl[p.block_side] = true
			if p.need_low_block then
				tbl["P"..i.." Down"] = true
			end
		end
	end

	joypad.set(tbl)
end

--emu.registerafter(apply_block)

rbff2mon = {}

--stun
local getpixel = function(x, y)
	local r, g, b = gui.readpixel(x, y)
	return bit.lshift(r, 16) + bit.lshift(g, 8) + b
end
local readbuff = function(x1, y1, x2, y2, c)
	for x = x1, x2 do
		for y = y1, y2 do
			local px = getpixel(x, y)
			if px == 0xFFFFFF then
				gui.drawpixel(x, y, c or 0xA4A4A4FF)
			elseif px == 0x000000 then
				gui.drawpixel(x, y, 0xCFCFCFFF)
			else
				gui.drawpixel(x, y, 0xFFFFFFFF)
			end
		end
	end
end
local readbuff_all = function(x1, y1, x2, y2)
	readbuff(x1, y1, x2, y2, 0xFF8400FF)
	readbuff(320-x2, y1, 320-x1, y2, 0x6BADD6FF)
end
local box_both = function(x1, y1, x2, y2, c1)
	gui.box(x1, y1, x2, y2, c1)
	gui.box(320-x2, y1, 320-x1, y2, c1)
end
local drawline_both = function(x1, y1, x2, y2, c1)
	gui.drawline(x1, y1, x2, y2, c1)
	gui.drawline(320-x2, y1, 320-x1, y2, c1)
end
local drawpixel_both = function(x1, y1, c1)
	gui.drawpixel(x1, y1, c1)
	gui.drawpixel(320-x1, y1, c1)
end
rbff2mon.draw_stuns = function()
	--オーバーレイ
	box_both(46, 28, 144, 32, 0xFFFFFFFF)
	for x = 145, 175 do
		for y = 29, 32 do
			local px = getpixel(x, y)
			if px ~= 0x002163 and px ~= 0x6BADD6 	and px ~= 0x9CCEE7 and px ~= 0xFFFFFF
				and px ~= 0xFF8400 and px ~= 0xFF0000 and px ~= 0xFF6B00 and px ~= 0xFFFF00
				and px ~= 0xFFC642 and px ~= 0xFF9400 and px ~= 0x0029D6 and px ~= 0x5284FF
				and px ~= 0x9CCEFF then
				gui.drawpixel(x, y, 0xFFFFFFFF)
			end
		end
	end

	readbuff_all(47, 32, 140, 39)
	drawline_both(46, 29, 46, 32, 0x848484FF)
	drawline_both(47, 33, 47, 37, 0x848484FF)
	drawpixel_both(48, 38, 0x848484FF)
	drawline_both(49, 39, 140, 39, 0x848484FF)

	--1P スタンゲージ
	gui.box(139 - rbff2player[1].max_stun, 29, 139, 30, 0x000000FF) --黒背景
	if rbff2player[1].stun > 0 then
		local x = 139-rbff2player[1].stun
		gui.drawline(x, 29, 139, 29, 0xFF0000FF)
		gui.drawline(x, 30, 139, 30, 0xBB0000FF)
	end

	--2P スタンゲージ
	gui.box(320 - (139 - rbff2player[2].max_stun), 29, 320-139, 30, 0x000000FF) --黒背景
	if rbff2player[2].stun > 0 then
		local x = 320-(139-rbff2player[2].stun)
		gui.drawline(x, 29, 181, 29, 0xFF0000FF)
		gui.drawline(x, 30, 181, 30, 0xBB0000FF)
	end

	--COUNT"T"のスキマ埋め
	gui.drawbox (172, 36, 173, 38, 0xFFFFFFFF)
	gui.drawline(172, 39, 173, 39, 0x848484FF)
	gui.drawbox (178, 36, 179, 38, 0xFFFFFFFF)
	gui.drawline(178, 39, 179, 39, 0x848484FF)

	--スタンゲージ
	--スタンリセットタイマーゲージ
	if rbff2player[1].stun_timer > 0 then
		local x = 139-rbff2player[1].stun_timer
		gui.drawline(x, 32, 139, 32, 0x0000FFFF)
		gui.drawline(x, 33, 139, 33, 0x0000BBFF)
		gui.drawline(x, 33, 139, 34, 0xC6C6BDFF)
	end
	--スタンリセットタイマーゲージ
	if rbff2player[2].stun_timer > 0 then
		local x = 320-(139-rbff2player[2].stun_timer)
		gui.drawline(x, 32, 181, 32, 0x0000FFFF)
		gui.drawline(x, 33, 181, 33, 0x0000BBFF)
		gui.drawline(x, 34, 181, 34, 0xC6C6BDFF)
	end
end

local gui_rtext = function(x, y, text, c)
	local t = tostring(text)
	gui.text(x + (4-#t)*4 ,y, text, c or 0xFFFFFFFF)
end

rbff2mon.draw_combos = function()
	gui_boxb(45, 40, 134, 62, 0x848484FF, 0x848484FF)
	gui.text( 49, 41, "-2P-", 0x00FFFFFF)
	gui.text( 49, 48, "DAMAGE", 0x00FFFFFF)
	gui.text( 49, 55, "COMBO", 0x00FFFFFF)
	gui_rtext( 77, 48, rbff2player[1].last_dmg, 0x00FFFFFF) --last single damage
	gui.text( 97, 41, "LAST", 0x00FFFFFF)
	gui_rtext( 97, 48, rbff2player[2].cmb_disp_dmg, 0x00FFFFFF) --last combo damage
	gui_rtext( 97, 55, rbff2player[2].combo, 0x00FFFFFF) --last combo count
	gui.text(117, 41, "BEST", 0x00FFFFFF)
	gui_rtext(117, 48, rbff2player[2].max_dmg, 0x00FFFFFF) --max combo damage
	gui_rtext(117, 55, rbff2player[2].max_combo, 0x00FFFFFF) --max combo count

	gui_boxb(184, 40, 274, 62, 0x848484FF, 0x848484FF)
	gui.text(188, 41, "-1P-", 0x00FFFFFF)
	gui.text(188, 48, "DAMAGE", 0x00FFFFFF)
	gui.text(188, 55, "COMBO", 0x00FFFFFF)
	gui_rtext(216, 48, rbff2player[2].last_dmg, 0x00FFFFFF) --last single damage
	gui.text(236, 41, "LAST", 0x00FFFFFF)
	gui_rtext(236, 48, rbff2player[1].cmb_disp_dmg, 0x00FFFFFF) --last combo damage
	gui_rtext(236, 55, rbff2player[1].combo, 0x00FFFFFF) --last combo count
	gui.text(256, 41, "BEST", 0x00FFFFFF)
	gui_rtext(256, 48, rbff2player[1].max_dmg, 0x00FFFFFF) --max combo damage
	gui_rtext(256, 55, rbff2player[1].max_combo, 0x00FFFFFF) --max combo count
end

gui.register(function()
	readmems()
	if not match_active then
		gui.clearuncommitted()
		return
	end
	gui.clearuncommitted()
	rbff2mon.draw_stuns()
	rbff2mon.draw_combos()

	--距離
	gui.text(160, 217 - math.floor(get_digit(p_space)/2), p_space)

	--行動IDとフレーム数
	for i = 1, 2 do
		local p = rbff2player[i]
		local len = #p.act_frames
		local j = 1
		local xoffset = i == 1 and 45 or 236
		for i = len, 1, -1 do
			local y = 56 + i*6
			local c = p.act_frames[j][3]
			gui_rtext(xoffset   , y, tohex(p.act_frames[j][1]), c)
			gui_rtext(xoffset+24, y, p.act_frames[j][2], c)
			--gui_rtext(xoffset+30, y, p.act_frames[j][4], c)
			j = j + 1
		end

		--フレーム差
		gui.text(xoffset+32, 210, p.last_frame_gap)

	end

end)

emu.registerafter(function()
	readmems()
	memory.writebyte(0x10048B, 0x60)
	memory.writebyte(0x10058B, 0x60)
	--memory.writebyte(0x1004BF, 0x80) --pow inifinity
	memory.writebyte(0x1004BC, 0x3C)
	--memory.writebyte(0x1005BF, 0x80) --pow inifinity
	memory.writebyte(0x1005BC, 0x3C)
	memory.writebyte(0x10E000, 0x02)
	memory.writebyte(0x10E001, 0x10)
	memory.writebyte(0x10E002, 0x01)
	memory.writebyte(0x107C28, 0xAA)

	local wb = memory.writebyte

	--	memory.writebyte(0x10048D, 0x01) --no hitstop
	--	memory.writebyte(0x1004B5, 0x01) --no hitstop
	--	memory.writebyte(0x10048B, 0x01) --no hitstop
	--	memory.writebyte(0x10058D, 0x01) --no hitstop
	--	memory.writebyte(0x1005B5, 0x01) --no hitstop
	--	memory.writebyte(0x10058B, 0x01) --no hitstop
end)

emu.registerstart(function()
	memory.writebyte(0x10D4E6, 0x00) --workaround
end)
