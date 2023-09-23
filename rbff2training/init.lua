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
local exports              = {}
local convert_lib          = require("data/button_char")
local convert              = function(str)
	return str and convert_lib(str) or str
end
exports.name               = "rbff2training"
exports.version            = "0.0.1"
exports.description        = "RBFF2 Training"
exports.license            = "MIT License"
exports.author             = { name = "Sanwabear" }

local util                 = require("rbff2training/util")
local data                 = require("rbff2training/data")

-- MAMEのLuaオブジェクトの変数と初期化処理
local man
local machine
local cpu
local pgm
local scr
local ioports
local debugger
local base_path
local setup_emu            = function()
	man = manager
	machine = man.machine
	cpu = machine.devices[":maincpu"]
	-- for k, v in pairs(cpu.state) do util.printf("%s %s", k ,v ) end
	pgm = cpu.spaces["program"]
	scr = machine.screens:at(1)
	ioports = man.machine.ioport.ports
	--[[
	for pname, port in pairs(ioports) do
		for fname, field in pairs(port.fields) do util.printf("%s %s", pname, fname) end
	end
	for p, pk in ipairs(data.joy_k) do
		for _, name in pairs(pk) do
			util.printf("%s %s %s", ":edge:joy:JOY" .. p, name, ioports[":edge:joy:JOY" .. p].fields[name])
		end
	end
	]]
	debugger = machine.debugger
	base_path = function()
		local base = emu.subst_env(man.options.entries.homepath:value():match('([^;]+)')) .. '/plugins/' .. exports.name
		local dir = util.cur_dir()
		return dir .. "/" .. base
	end
	dofile(base_path() .. "/data.lua")
end

local rbff2                = exports

-- キャラと動作データ
local chars                = data.chars
local jump_acts            = data.jump_acts
local wakeup_acts          = data.wakeup_acts
local act_types            = data.act_types
local pre_down_acts        = data.pre_down_acts

-- ヒット効果
local hit_effect_types     = data.hit_effect_types
local hit_effect_nokezoris = data.hit_effect_nokezoris
local hit_effects          = data.hit_effects
local hit_effect_moves     = { 0 }
local hit_effect_move_keys = { "OFF" }

-- ヒット時のシステム内での中間処理による停止アドレス
local hit_system_stops     = {}

-- 判定種類
local box_kinds            = data.box_kinds
local box_types            = data.box_types
local main_box_types       = data.main_box_types
local sway_box_types       = data.sway_box_types
local attack_boxies        = data.attack_boxies
local juggle_boxies        = data.juggle_boxies
local fake_boxies          = data.fake_boxies
local hitstun_boxies       = data.hitstun_boxies
local block_boxies         = data.block_boxies
local parry_boxies         = data.parry_boxies
local hurt_boxies          = data.hurt_boxies
local top_types            = data.top_types
local top_sway_types       = data.top_sway_types
local top_punish_types     = data.top_punish_types
local block_types          = data.block_types
local frame_hurt_types     = {
	invincible = 2 ^ 0,
	gnd_hitstun = 2 ^ 1,
	otg = 2 ^ 2,
	juggle = 2 ^ 3,
	wakeup = 2 ^ 4,
	op_normal = 2 ^ 8,
}
-- ヒット処理の飛び先 家庭用版 0x13120 からのデータテーブル 5種類
local possible_types       = {
	none      = 0,  -- 常に判定しない
	same_line = 2 ^ 0, -- 同一ライン同士なら判定する
	diff_line = 2 ^ 1, -- 異なるライン同士で判定する
	air_onry  = 2 ^ 2, -- 相手が空中にいれば判定する
	unknown   = 2 ^ 3, -- 不明
}
-- 同一ライン、異なるラインの両方で判定する
possible_types.both_line   = possible_types.same_line | possible_types.diff_line
local get_top_type         = function(top, types)
	local type = 0
	for _, t in ipairs(types) do
		if top <= t.top then type = type | t.act_type end
	end
	return type
end
local hitbox_possibles     = {
	normal          = 0x94D2C,  -- 012DBC: 012DC8: 通常状態へのヒット判定処理
	down            = 0x94E0C,  -- 012DE4: 012DF0: ダウン状態へのヒット判定処理
	juggle          = 0x94EEC,  -- 012E0E: 012E1A: 空中追撃可能状態へのヒット判定処理
	standing_block  = 0x950AC,  -- 012EAC: 012EB8: 上段ガード判定処理
	crouching_block = 0x9518C,  -- 012ED8: 012EE4: 屈ガード判定処理
	air_block       = 0x9526C,  -- 012F04: 012F16: 空中ガード判定処理
	sway_standing   = 0x95A4C,  -- 012E60: 012E6C: 対ライン上段の処理
	sway_crouching  = 0x95B2C,  -- 012F3A: 012E90: 対ライン下段の処理
	joudan_atemi    = 0x9534C,  -- 012F30: 012F82: 上段当身投げの処理
	urakumo         = 0x9542C,  -- 012F30: 012F82: 裏雲隠しの処理
	gedan_atemi     = 0x9550C,  -- 012F44: 012F82: 下段当身打ちの処理
	gyakushu        = 0x955EC,  -- 012F4E: 012F82: 必勝逆襲拳の処理
	sadomazo        = 0x956CC,  -- 012F58: 012F82: サドマゾの処理
	phoenix_throw   = 0x9588C,  -- 012F6C: 012F82: フェニックススルーの処理
	baigaeshi       = 0x957AC,  -- 012F62: 012F82: 倍返しの処理
	unknown1        = 0x94FCC,  -- 012E38: 012E44: 不明処理、未使用？
	katsu           = 0x9596C,  -- : 012FB2: 喝消し
	nullify         = function(id) -- : 012F9A: 弾消し
		return (0x20 <= id) and possible_types.same_line or possible_types.none
	end,
}
local frame_attack_types   = {
	fb = 2 ^ 0,          -- 0x 1 0000 0001 弾
	attacking = 2 ^ 1,   -- 0x 2 0000 0010 攻撃動作中
	juggle = 2 ^ 2,      -- 0x 4 0000 0100 空中追撃可能
	fake = 2 ^ 3,        -- 0x 8 0000 1000 攻撃能力なし(判定初期から)
	obsolute = 2 ^ 4,    -- 0x F 0001 0000 攻撃能力なし(動作途中から)
	fullhit = 2 ^ 5,     -- 0x20 0010 0000 全段ヒット状態
	harmless = 2 ^ 6,    -- 0x40 0100 0000 攻撃データIDなし

	attack = 7,          -- attack 7ビット左シフト
	act = 7 + 8,         -- act 15ビット左シフト

	act_count = 7 + 8 + 16, -- act_count 31ビット左シフト 本体の動作区切り用
	fb_effect = 7 + 8 + 16, -- effect 31ビット左シフト 弾の動作区切り用
}
local hitbox_grab_bits     = {
	none          = 0,
	joudan_atemi  = 2 ^ 0,
	urakumo       = 2 ^ 1,
	gedan_atemi   = 2 ^ 2,
	gyakushu      = 2 ^ 3,
	sadomazo      = 2 ^ 4,
	phoenix_throw = 2 ^ 5,
	baigaeshi     = 2 ^ 6,
	katsu         = 2 ^ 7,
	nullify       = 2 ^ 8,
	unknown1      = 2 ^ 8,
}
local hitbox_grab_types    = {
	{ name = "none",          label = "",  value = hitbox_grab_bits.none },
	{ name = "joudan_atemi",  label = "J", value = hitbox_grab_bits.joudan_atemi }, -- 上段当身投げ
	{ name = "urakumo",       label = "U", value = hitbox_grab_bits.urakumo },    -- 裏雲隠し
	{ name = "gedan_atemi",   label = "G", value = hitbox_grab_bits.gedan_atemi }, -- 下段当身打ち
	{ name = "gyakushu",      label = "H", value = hitbox_grab_bits.gyakushu },   -- 必勝逆襲拳
	{ name = "sadomazo",      label = "S", value = hitbox_grab_bits.sadomazo },   -- サドマゾ
	{ name = "phoenix_throw", label = "P", value = hitbox_grab_bits.phoenix_throw }, -- フェニックススルー
	{ name = "baigaeshi",     label = "B", value = hitbox_grab_bits.baigaeshi },  -- 倍返し
	{ name = "katsu",         label = "K", value = hitbox_grab_bits.katsu },      -- 喝消し
	{ name = "nullify",       label = "N", value = hitbox_grab_bits.nullify },    -- 弾消し
	{ name = "unknown1",      label = "?", value = hitbox_grab_bits.unknown1 },   -- 喝消し
}
-- 状態フラグ
local esaka_type_names     = data.esaka_type_names
local get_flag_name        = function(flags, names)
	local flgtxt = ""
	if flags <= 0 then
		return nil
	end
	for j = 32, 1, -1 do
		if flags & 2 ^ (j - 1) ~= 0 then
			flgtxt = string.format("%s%02d %s ", flgtxt, 32 - j, names[j])
		end
	end
	return flgtxt
end
local state_flag_names     = data.state_flag_names
local state_flag_c0        = data.state_flag_c0
local state_flag_c4        = data.state_flag_c4
local state_flag_c8        = data.state_flag_c8
local state_flag_cc        = data.state_flag_cc
local state_flag_d0        = data.state_flag_d0

-- コマンド入力状態
local input_state_types    = data.input_state_types
local input_states         = data.input_states
local input_state_col      = data.input_state_col

local chip_dmg_types       = data.chip_dmg_types
local combo_scale_types    = data.combo_scale_types

-- メニュー用変数
local menu                 = {
	proc = nil,
	draw = nil,

	state = nil,
	prev_state = nil,
	current = nil,
	main = nil,
	training = nil,
	recording = nil,
	replay = nil,
	tra_main = {
		proc = nil,
		draw = nil,
	},
	exit = nil,
	bs_menus = nil,
	rvs_menus = nil,
	bar = nil,
	disp = nil,
	extra = nil,
	color = nil,
	auto = nil,
	update_pos = nil,
	reset_pos = nil,

	stgs = data.stage_list,
	bgms = data.bgm_list,

	labels = {
		fix_scr_tops = { "OFF" },
		chars        = {},
		stgs         = {},
		bgms         = {},
		off_on       = { "OFF", "ON" }
	},
}
menu.labels.chars          = data.char_names
for i = -20, 0xF0 do table.insert(menu.labels.fix_scr_tops, "" .. i) end
for _, stg in ipairs(menu.stgs) do table.insert(menu.labels.stgs, stg.name) end
for _, bgm in ipairs(menu.bgms) do
	local exists = false
	for _, name in pairs(menu.labels.bgms) do
		if name == bgm.name then
			exists, bgm.name_idx = true, #menu.labels.bgms
			break
		end
	end
	if not exists then
		table.insert(menu.labels.bgms, bgm.name)
		bgm.name_idx = #menu.labels.bgms
	end
end

local mem               = {
	last_time          = 0,     -- 最終読込フレーム(キャッシュ用)
	_0x10E043          = 0,     -- 手動でポーズしたときに00以外になる
	stage_base_addr    = 0x100E00,
	close_far_offset   = 0x02AE08, -- 近距離技と遠距離技判断用のデータの開始位置
	close_far_offset_d = 0x02DDAA, -- 対ラインの近距離技と遠距離技判断用のデータの開始位置
	pached             = false, -- Fireflower形式のパッチファイルの読込とメモリへの書込
	w8                 = function(addr, value) pgm:write_u8(addr, value) end,
	wd8                = function(addr, value) pgm:write_direct_u8(addr, value) end,
	w16                = function(addr, value) pgm:write_u16(addr, value) end,
	wd16               = function(addr, value) pgm:write_direct_u16(addr, value) end,
	w32                = function(addr, value) pgm:write_u32(addr, value) end,
	wd32               = function(addr, value) pgm:write_direct_u32(addr, value) end,
	w8i                = function(addr, value) pgm:write_i8(addr, value) end,
	w16i               = function(addr, value) pgm:write_i16(addr, value) end,
	w32i               = function(addr, value) pgm:write_i32(addr, value) end,
	r8                 = function(addr, value) return pgm:read_u8(addr, value) end,
	r16                = function(addr, value) return pgm:read_u16(addr, value) end,
	r32                = function(addr, value) return pgm:read_u32(addr, value) end,
	r8i                = function(addr, value) return pgm:read_i8(addr, value) end,
	r16i               = function(addr, value) return pgm:read_i16(addr, value) end,
	r32i               = function(addr, value) return pgm:read_i32(addr, value) end,
}
local in_match          = false -- 対戦画面のときtrue
local in_player_select  = false -- プレイヤー選択画面のときtrue
local p_space           = 0     -- 1Pと2Pの間隔
local prev_space        = 0     -- 1Pと2Pの間隔(前フレーム)

local screen            = {
	offset_x = 0x20,
	offset_z = 0x24,
	offset_y = 0x28,
	left     = 0,
	top      = 0,
}

local global            = {
	frame_number        = 0,
	lag_frame           = false,
	all_act_normal      = false,
	old_all_act_normal  = false,
	sp_skip_frame       = false,
	fix_scr_top         = 1,

	-- 当たり判定用
	axis_color          = 0xFF797979,
	axis_air_color      = 0xFFCC00CC,
	axis_internal_color = 0xFF00FFFF,
	axis_size           = 12,
	axis_size2          = 5,
	no_alpha            = true, --fill = 0x00, outline = 0xFF for all box types
	throwbox_height     = 200, --default for ground throws
	disp_bg             = true,
	fix_pos             = false,
	no_bars             = false,
	sync_pos_x          = 1,  -- 1: OFF, 2:1Pと同期, 3:2Pと同期

	disp_pos            = true, -- 1P 2P 距離表示
	hide_p_chan         = false, -- Pちゃん表示するときfalse
	hide_effect         = false, -- ヒットマークなど画面表示するときfalse
	hide_shadow         = 2,  -- 1:OFF, 2:ON, 3:ON:双角ステージの反射→影
	disp_frmgap         = 3,  -- フレーム差表示
	disp_input_sts      = 1,  -- コマンド入力状態表示 1:OFF 2:1P 3:2P
	disp_normal_frms    = 2,  -- 通常動作フレーム非表示 1:OFF 2:ON
	pause_hit           = 1,  -- 1:OFF, 2:ON, 3:ON:やられのみ 4:ON:投げやられのみ 5:ON:打撃やられのみ 6:ON:ガードのみ
	pause_hitbox        = 1,  -- 判定発生時にポーズ
	pause               = false,
	replay_stop_on_dmg  = false, -- ダメージでリプレイ中段

	next_stg3           = 0,

	-- リバーサルとブレイクショットの設定
	dummy_bs_cnt        = 1, -- ブレイクショットのカウンタ
	dummy_rvs_cnt       = 1, -- リバーサルのカウンタ

	auto_input          = {
		otg_thw       = false, -- ダウン投げ              2
		otg_atk       = false, -- ダウン攻撃              3
		thw_otg       = false, -- 通常投げの派生技        4
		rave          = 1, -- デッドリーレイブ        5
		desire        = 1, -- アンリミテッドデザイア  6
		drill         = 5, -- ドリル                  7
		pairon        = 1, -- 超白龍                  8
		real_counter  = 1, -- M.リアルカウンター      9
		auto_3ecst    = false, -- M.トリプルエクスタシー 10
		auto_taneuma  = false, -- 炎の種馬               11
		auto_katsu    = false, -- 喝CA                   12
		-- 入力設定                                     13
		esaka_check   = false, -- 詠酒距離チェック       14
		fast_kadenzer = false, -- 必勝！逆襲拳           15
		kara_ca       = false, -- 空振りCA               16
	},

	frzc                = 1,
	frz                 = { 0x1, 0x0 }, -- DIPによる停止操作用の値とカウンタ

	dummy_mode          = 1,
	old_dummy_mode      = 1,
	rec_main            = nil,

	input_accepted      = 0,

	next_block_grace    = 0, -- 1ガードでの持続フレーム数
	pow_mode            = 2, -- POWモード　1:自動回復 2:固定 3:通常動作
	disp_meters         = true,
	repeat_interval     = 0,
	await_neutral       = false,
	replay_fix_pos      = 1,  -- 開始間合い固定 1:OFF 2:位置記憶 3:1Pと2P 4:1P 5:2P
	replay_reset        = 2,  -- 状態リセット   1:OFF 2:1Pと2P 3:1P 4:2P
	mame_debug_wnd      = false, -- MAMEデバッグウィンドウ表示のときtrue
	debug_stop          = 0,  -- カウンタ
	damaged_move        = 1,
	disp_replay         = true, -- レコードリプレイガイド表示
	save_snapshot       = 1,  -- 技画像保存 1:OFF 2:新規 3:上書き
}
mem.rg                  = function(id, mask) return (mask == nil) and cpu.state[id].value or (cpu.state[id].value & mask) end
mem.pc                  = function() return cpu.state["CURPC"].value end
mem.wp_cnt, mem.rp_cnt  = {}, {} -- 負荷確認のための呼び出す回数カウンター
local pc_filter         = function(filter)
	if filter == nil or #filter == 0 then
		return nil
	end
	local accept_pc = util.table_to_set(filter)
	return function(pc) return accept_pc[pc] ~= true end
end
mem.wp8                 = function(addr, cb, filter)
	local accept_pc = pc_filter(filter)
	local name = string.format("wp8_%x_%s", addr, #global.holder.taps)
	if addr % 2 == 0 then
		table.insert(global.holder.taps, pgm:install_write_tap(addr, addr + 1, name,
			function(offset, data, mask)
				mem.wp_cnt[addr] = (mem.wp_cnt[addr] or 0) + 1
				if accept_pc and accept_pc(mem.pc()) then return data end
				local ret = {}
				if mask > 0xFF then
					cb((data & mask) >> 8, ret)
					if ret.value then
						--util.printf("1 %x %x %x %x", data, mask, ret.value, (ret.value << 8) & mask)
						return (ret.value << 8) & mask
					end
				elseif offset == (addr + 1) then
					cb(data & mask, ret)
					if ret.value then
						--util.printf("2 %x %x %x %x", data, mask, ret.value, ret.value & mask)
						return ret.value & mask
					end
				end
				return data
			end))
	else
		table.insert(global.holder.taps, pgm:install_write_tap(addr - 1, addr, name,
			function(offset, data, mask)
				mem.wp_cnt[addr] = (mem.wp_cnt[addr] or 0) + 1
				if accept_pc and accept_pc(mem.pc()) then return data end
				local ret = {}
				if mask == 0xFF or mask == 0xFFFF then
					cb(0xFF & data, ret)
					if ret.value then
						if mask == 0xFFFF then
							--util.printf("3 %x %x %x %x", data, mask, ret.value, (ret.value & 0xFF) | (0xFF00 & data))
							return (ret.value & 0xFF) | (0xFF00 & data)
						else
							--util.printf("4 %x %x %x %x", data, mask, ret.value, (ret.value & 0xFF) | (0xFF00 & data))
							return (ret.value & 0xFF) | (0xFF00 & data)
						end
					end
				end
				return data
			end))
	end
	cb(mem.r8(addr), {})
end
mem.wp16                = function(addr, cb, filter)
	local accept_pc = pc_filter(filter)
	local name = string.format("wp16_%x_%s", addr, #global.holder.taps)
	table.insert(global.holder.taps, pgm:install_write_tap(addr, addr + 1, name,
		function(offset, data, mask)
			local ret = {}
			mem.wp_cnt[addr] = (mem.wp_cnt[addr] or 0) + 1
			if accept_pc and accept_pc(mem.pc()) then return data end
			if mask == 0xFFFF then
				cb(data & mask, ret)
				--util.printf("wp16 %x %x %x %x",addr, data, mask, ret.value or 0)
				return ret.value or data
			end
			local data2, mask2, mask3, data3
			local prev = mem.r32(addr)
			if mask == 0xFF00 or mask == 0xFF then mask2 = mask << 16 end
			mask3 = 0xFFFF ~ mask2
			data2 = data & mask
			data3 = (prev & mask3) | data2
			cb(data3, ret)
			--util.printf("wp16 %x %x %x %x",addr, data, mask, ret.value or 0)
			return ret.value or data
		end))
	cb(mem.r16(addr), {})
	--printf("register wp %s %x", name, addr)
end
mem.wp32                = function(addr, cb, filter)
	local accept_pc = pc_filter(filter)
	local num = #global.holder.taps
	local name = string.format("wp32_%x_%s", addr, num)
	table.insert(global.holder.taps, pgm:install_write_tap(addr, addr + 3, name,
		function(offset, data, mask)
			mem.wp_cnt[addr] = (mem.wp_cnt[addr] or 0) + 1
			if accept_pc and accept_pc(mem.pc()) then return data end
			local ret = {}
			--util.printf("wp32-1 %x %x %x %x %x", addr, offset, data, data, mask, ret.value or 0)
			local prev = mem.r32(addr)
			local data2, mask2, mask3, data3
			if offset == addr then
				mask2 = mask << 16
				data2 = (data << 16) & mask2
			else
				mask2 = 0x0000FFFF & mask
				data2 = data & mask2
			end
			mask3 = 0xFFFFFFFF ~ mask2
			data3 = (prev & mask3) | data2
			cb(data3, ret)
			if ret.value then ret.value = addr == offset and (ret.value >> 0x10) or (ret.value & 0xFFFF) end
			--util.printf("wp32-3 %x %x %x %x %x %x", addr, offset, data, data3, mask, ret.value or 0)
			return ret.value or data
		end))
	cb(mem.r32(addr), {})
end
mem.rp8                 = function(addr, cb, filter)
	local accept_pc = pc_filter(filter)
	local name = string.format("rp8_%x_%s", addr, #global.holder.taps)
	if addr % 2 == 0 then
		table.insert(global.holder.taps, pgm:install_read_tap(addr, addr + 1, name,
			function(offset, data, mask)
				mem.wp_cnt[addr] = (mem.wp_cnt[addr] or 0) + 1
				if accept_pc and accept_pc(mem.pc()) then return data end
				local ret = {}
				if mask > 0xFF then
					cb((data & mask) >> 8, ret)
					if ret.value then
						--util.printf("1 %x %x %x %x", data, mask, ret.value, (ret.value << 8) & mask)
						return (ret.value << 8) & mask
					end
				elseif offset == (addr + 1) then
					cb(data & mask, ret)
					if ret.value then
						--util.printf("2 %x %x %x %x", data, mask, ret.value, ret.value & mask)
						return ret.value & mask
					end
				end
				return data
			end))
	else
		table.insert(global.holder.taps, pgm:install_read_tap(addr - 1, addr, name,
			function(offset, data, mask)
				mem.wp_cnt[addr] = (mem.wp_cnt[addr] or 0) + 1
				if accept_pc and accept_pc(mem.pc()) then return data end
				local ret = {}
				if mask == 0xFF or mask == 0xFFFF then
					cb(0xFF & data, ret)
					if ret.value then
						if mask == 0xFFFF then
							--util.printf("3 %x %x %x %x", data, mask, ret.value, (ret.value & 0xFF) | (0xFF00 & data))
							return (ret.value & 0xFF) | (0xFF00 & data)
						else
							--util.printf("4 %x %x %x %x", data, mask, ret.value, (ret.value & 0xFF) | (0xFF00 & data))
							return (ret.value & 0xFF) | (0xFF00 & data)
						end
					end
				end
				return data
			end))
	end
	cb(mem.r8(addr), {})
end
mem.rp16                = function(addr, cb, filter)
	local accept_pc = pc_filter(filter)
	local num = #global.holder.taps
	local name = string.format("rp16_%x_%s", addr, num)
	table.insert(global.holder.taps, pgm:install_read_tap(addr, addr + 1, name,
		function(offset, data, mask)
			mem.rp_cnt[addr] = (mem.rp_cnt[addr] or 0) + 1
			if accept_pc and accept_pc(mem.pc()) then return data end
			local ret = {}
			if offset == addr then cb(data, ret) end
			return ret.value or data
		end))
	cb(mem.r16(addr), {})
end
mem.rp32                = function(addr, cb, filter)
	local accept_pc = pc_filter(filter)
	local num = #global.holder.taps
	local name = string.format("rp32_%x_%s", addr, num)
	table.insert(global.holder.taps, pgm:install_read_tap(addr, addr + 3, name,
		function(offset, data, mask)
			mem.rp_cnt[addr] = (mem.rp_cnt[addr] or 0) + 1
			if accept_pc and accept_pc(mem.pc()) then return data end
			if offset == addr then cb(mem.r32(addr)) end
			return data
		end))
	cb(mem.r32(addr))
end

-- DIPスイッチ
local dip_config                = {
	show_range    = false,
	show_hitbox   = false,
	infinity_life = false,
	easy_super    = false,
	semiauto_p    = false,
	infinity_time = true,
	fix_time      = 0x99,
	stage_select  = false,
	alfred        = false,
	watch_states  = false,
	cpu_cant_move = false,
	other_speed   = false,
}
-- デバッグDIPのセット
local set_dip_config            = function()
	local dip1, dip2, dip3, dip4 = 0x00, 0x00, 0x00, 0x00                   -- デバッグDIP
	dip1 = dip1 | (in_match and dip_config.show_range and 0x40 or 0)        --cheat "DIP= 1-7 色々な判定表示"
	dip1 = dip1 | (in_match and dip_config.show_hitbox and 0x80 or 0)       --cheat "DIP= 1-8 当たり判定表示"
	dip1 = dip1 | (in_match and dip_config.infinity_life and 0x02 or 0)     --cheat "DIP= 1-2 Infinite Energy"
	dip2 = dip2 | (in_match and dip_config.easy_super and 0x01 or 0)        --Cheat "DIP 2-1 Eeasy Super"
	dip4 = dip4 | (in_match and dip_config.semiauto_p and 0x08 or 0)        -- DIP4-4
	dip2 = dip2 | (dip_config.infinity_time and 0x18 or 0)                  -- 2-4 PAUSEを消す + cheat "DIP= 2-5 Disable Time Over"
	mem.w8(0x10E024, dip_config.infinity_time and 0x03 or 0x02)             -- 家庭用オプション 1:45 2:60 3:90 4:infinity
	mem.w8(0x107C28, dip_config.infinity_time and 0xAA or dip_config.fix_time) --cheat "Infinite Time"
	dip1 = dip1 | (dip_config.stage_select and 0x04 or 0)                   --cheat "DIP= 1-3 Stage Select Mode"
	dip2 = dip2 | (in_player_select and dip_config.alfred and 0x80 or 0)    --cheat "DIP= 2-8 Alfred Code (B+C >A)"
	dip2 = dip2 | (in_match and dip_config.watch_states and 0x20 or 0)      --cheat "DIP= 2-6 Watch States"
	dip3 = dip3 | (in_match and dip_config.cpu_cant_move and 0x01 or 0)     --cheat "DIP= 3-1 CPU Can't Move"
	dip3 = dip3 | (in_match and dip_config.other_speed and 0x10 or 0)       --cheat "DIP= 3-5 移動速度変更"
	for i, dip in ipairs({ dip1, dip2, dip3, dip4 }) do mem.w8(0x10E000 + i - 1, dip) end
end

-- キー入力
local joy_k                     = data.joy_k
local rev_joy                   = data.rev_joy
local joy_frontback             = data.joy_frontback
local joy_pside                 = data.joy_pside
local joy_neutrala              = data.joy_neutrala
local joy_neutralp              = data.joy_neutralp
local joy_ezmap                 = data.joy_ezmap
local kprops                    = data.kprops
local cmd_funcs                 = data.cmd_funcs

local rvs_types                 = data.rvs_types
local hook_cmd_types            = data.hook_cmd_types

local get_next_xs               = function(p, list, cur_menu)
	local sub_menu, ons = cur_menu[p.num][p.char], {}
	if sub_menu == nil or list == nil then return nil end
	for j, s in pairs(list) do if sub_menu.pos.col[j + 1] == 2 then table.insert(ons, s) end end
	return #ons > 0 and ons[math.random(#ons)] or nil
end
local get_next_rvs              = function(p) return get_next_xs(p, p.char_data and p.char_data.rvs or nil, menu.rvs_menus) end
local get_next_bs               = function(p) return get_next_xs(p, p.char_data and p.char_data.bs or nil, menu.bs_menus) end

local use_joy                   = {
	{ port = ":edge:joy:JOY1",  field = joy_k[1].a,  frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1",  field = joy_k[1].b,  frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1",  field = joy_k[1].c,  frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1",  field = joy_k[1].d,  frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1",  field = joy_k[1].dn, frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1",  field = joy_k[1].lt, frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1",  field = joy_k[1].rt, frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1",  field = joy_k[1].up, frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joy_k[2].a,  frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joy_k[2].b,  frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joy_k[2].c,  frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joy_k[2].d,  frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joy_k[2].dn, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joy_k[2].lt, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joy_k[2].rt, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joy_k[2].up, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:START", field = joy_k[2].st, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:START", field = joy_k[1].st, frame = 0, prev = 0, player = 1, get = 0, },
}
local get_joy                   = function(exclude_player, prev)
	local frame_number, joy_port, joy_val, prev_joy_val = scr:frame_number(), {}, {}, {}
	for _, joy in ipairs(use_joy) do
		joy_port[joy.port] = joy_port[joy.port] or ioports[joy.port]:read()
		local field = ioports[joy.port].fields[joy.field]
		local state = ((joy_port[joy.port] & field.mask) ~ field.defvalue)
		if joy.get < frame_number then
			joy.prev = joy.frame
			if state > 0 then
				joy.frame = joy.frame <= 0 and 1 or (joy.frame + 1) -- on
			else
				joy.frame = joy.frame >= 0 and -1 or (joy.frame - 1) -- off
			end
		end
		joy.get = frame_number
		if exclude_player ~= joy.player then
			joy_val[joy.field], prev_joy_val[joy.field] = joy.frame, joy.prev
		end
	end
	return prev and prev_joy_val or joy_val
end

local play_cursor_sound         = function()
	mem.w32(0x10D612, 0x600004)
	mem.w8(0x10D713, 0x1)
end

local accept_input              = function(btn, joy_val, state_past)
	if 12 < state_past then
		local p1, p2 = joy_k[1][btn], joy_k[2][btn]
		if btn == "Up" or btn == "Down" or btn == "Right" or btn == "Left" then
			if (0 < joy_val[p1]) or (0 < joy_val[p2]) then
				play_cursor_sound()
				return true
			end
		else
			if (0 < joy_val[p1] and state_past >= joy_val[p1]) or
				(0 < joy_val[p2] and state_past >= joy_val[p2]) then
				if global.disp_replay then
					play_cursor_sound()
				end
				return true
			end
		end
	end
	return false
end
local is_start_a                = function(joy_val, state_past)
	if 12 < state_past then
		for i = 1, 2 do
			if (35 < joy_val[joy_k[i].st]) then
				play_cursor_sound()
				return true
			end
		end
	end
	return false
end
local new_next_joy              = function() return util.deepcopy(joy_neutrala) end
-- MAMEへの入力の無効化
local cls_joy                   = function()
	for _, joy in ipairs(use_joy) do ioports[joy.port].fields[joy.field]:set_value(0) end
end

-- キー入力
local posi_or_pl1               = function(v) return 0 <= v and v + 1 or 1 end
local nega_or_mi1               = function(v) return 0 >= v and v - 1 or -1 end

-- ポーズ
local set_freeze                = function(freeze) mem.w8(0x1041D2, freeze and 0x00 or 0xFF) end

local new_ggkey_set             = function(p1)
	local xoffset, yoffset = p1 and 50 or 245, 200
	local pt0, pt2, ptS, ptP, ptP1, ptP2, ptP3, ptP4 = 0, 1, math.sin(1), 9, 8.4, 8.7, 9.3, 9.6
	local oct_vt = {
		{ x = pt0,  y = pt2,  no = 1, op = 5, dg1 = 4, dg2 = 6, }, -- 1:レバー2
		{ x = ptS,  y = ptS,  no = 2, op = 6, dg1 = 5, dg2 = 7, }, -- 2:レバー3
		{ x = pt2,  y = pt0,  no = 3, op = 7, dg1 = 6, dg2 = 8, }, -- 3:レバー6
		{ x = ptS,  y = -ptS, no = 4, op = 8, dg1 = 1, dg2 = 7, }, -- 4:レバー9
		{ x = pt0,  y = -pt2, no = 5, op = 1, dg1 = 2, dg2 = 8, }, -- 5:レバー8
		{ x = -ptS, y = -ptS, no = 6, op = 2, dg1 = 1, dg2 = 3, }, -- 6:レバー7
		{ x = -pt2, y = pt0,  no = 7, op = 3, dg1 = 2, dg2 = 4, }, -- 7:レバー4
		{ x = -ptS, y = ptS,  no = 8, op = 4, dg1 = 3, dg2 = 5, }, -- 8:レバー1
		{ x = pt0,  y = pt0,  no = 9, op = 9, dg1 = 9, dg2 = 9, }, -- 9:レバー5
	}
	for _, xy in ipairs(oct_vt) do
		xy.x1, xy.y1 = xy.x * ptP1 + xoffset, xy.y * ptP1 + yoffset
		xy.x2, xy.y2 = xy.x * ptP2 + xoffset, xy.y * ptP2 + yoffset
		xy.x3, xy.y3 = xy.x * ptP3 + xoffset, xy.y * ptP3 + yoffset
		xy.x4, xy.y4 = xy.x * ptP3 + xoffset, xy.y * ptP4 + yoffset
		xy.x, xy.y   = xy.x * ptP + xoffset, xy.y * ptP + yoffset -- 座標の中心
		xy.xt, xy.yt = xy.x - 2.5, xy.y - 3                 -- レバーの丸表示用
	end
	local key_xy = {
		oct_vt[8], -- 8:レバー1
		oct_vt[1], -- 1:レバー2
		oct_vt[2], -- 2:レバー3
		oct_vt[7], -- 7:レバー4
		oct_vt[9], -- 9:レバー5
		oct_vt[3], -- 3:レバー6
		oct_vt[6], -- 6:レバー7
		oct_vt[5], -- 5:レバー8
		oct_vt[4], -- 4:レバー9
	}
	return { xoffset = xoffset, yoffset = yoffset, oct_vt = oct_vt, key_xy = key_xy, }
end
local ggkey_set                 = {
	new_ggkey_set(true),
	new_ggkey_set(false)
}

local slide_btn                 = { [0] = "-", [1] = "A", [2] = "B", [3] = "C", [4] = "D", [5] = "AB", [6] = "BC", [7] = "CD", }
local slide_rev                 = { [0] = "N", [1] = "↑", [2] = "↓", [3] = "→", [4] = "↗", [5] = "↘", [6] = "←", [7] = "↖", [8] = "↙", }
-- ダッシュ中の行動アドレス 家庭用0x02B024からの処理
local get_dash_act_addr         = function(p, pgm)
	--[[
	02B024: 43F9 0004 B746           lea     $4b746.l, A1                          ; A1 = 4b746
	02B02A: 297C 0000 0004 00CC      move.l  #$4, ($cc,A4)                         ; 動作フラグセット 0000 0004 滑り攻撃
	02B032: 6100 B63A                bsr     $2666e                                ; 方向キーセット D0=方向 100*83=入力 100*82=入力1F前
	02B036: 7200                     moveq   #$0, D1                               ; D1 = 0
	02B038: 122C 0084                move.b  ($84,A4), D1                          ; D1 = 100*84 クリアリング後のボタン入力
	02B03C: E748                     lsl.w   #3, D0                                ; 3ビットシフト D0 *= 8
	02B03E: D041                     add.w   D1, D0                                ; D0 = D0 + D1
	02B040: 322C 0010                move.w  ($10,A4), D1                          ; D1 = キャラID
	02B044: D241                     add.w   D1, D1                                ; D1 = D1 + D1
	02B046: D241                     add.w   D1, D1                                ; D1 = D1 + D1
	02B048: D3C1                     adda.l  D1, A1                                ; A1 = A1 + D1
	02B04A: 2051                     movea.l (A1), A0                              ; A0 = A1のデータ
	02B04C: D1C0                     adda.l  D0, A0                                ; A0 = A0 + D0
	02B04E: 7200                     moveq   #$0, D1                               ; D1 = 0
	02B050: 1210                     move.b  (A0), D1                              ; D1 = A0のデータ1バイト
	02B052: D241                     add.w   D1, D1                                ; D1 = D1 + D1
	02B054: D241                     add.w   D1, D1                                ; D1 = D1 + D1
	02B056: 43FA B3EC                lea     (-$4c14,PC) ; ($26444), A1            ; A1 = 26444 ダッシュ攻撃の最終的なテーブル
	02B05A: D3C1                     adda.l  D1, A1                                ; A1 = A1 + D1
	02B05C: 2051                     movea.l (A1), A0                              ; A0 = A1のデータ
	02B05E: 4ED0                     jmp     (A0)                                  ; A0へジャンプ
	]]
	local d1 = mem.r8(mem.r32(0x04B746 + p.char4) + p.input1 + (0xFFFF & (p.cln_btn * 8)))
	return mem.r32(0x26444 + 0xFFFF & (d1 * 4))
end

-- ボタンの色テーブル
local btn_col                   = { [convert("_A")] = 0xFFCC0000, [convert("_B")] = 0xFFCC8800, [convert("_C")] = 0xFF3333CC, [convert("_D")] = 0xFF336600, }
local text_col, shadow_col      = 0xFFFFFFFF, 0xFF000000

local rom_patch_path            = function(filename)
	local base = base_path() .. '/patch/rom/'
	local patch = base .. emu.romname() .. '/' .. filename
	if util.is_file(patch) then
		return patch
	else
		print(patch .. " NOT found")
	end
	return base .. 'rbff2/' .. filename
end

local ram_patch_path            = function(filename)
	local base = base_path() .. '/patch/ram/'
	local patch = base .. emu.romname() .. '/' .. filename
	if util.is_file(patch) then
		return patch
	end
	return base .. 'rbff2/' .. filename
end

local get_string_width          = function(str)
	return man.ui:get_string_width(str) * scr.width
end

local get_line_height          = function(lines)
	return man.ui.line_height * scr.height * (lines or 1)
end

local draw_rtext                = function(x, y, str, fgcol, bgcol)
	if not str then
		return
	end
	if type(str) ~= "string" then
		str = string.format("%s", str)
	end
	local w = get_string_width(str)
	scr:draw_text(x - w, y, str, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
	return w
end

local draw_ctext                = function(x, y, str, fgcol, bgcol)
	if not str then
		return
	end
	if type(str) ~= "string" then
		str = string.format("%s", str)
	end
	local w = get_string_width(str) / 2
	scr:draw_text(x - w, y, str, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
	return w
end

local draw_text_with_shadow     = function(x, y, str, fgcol, bgcol)
	if type(str) ~= "string" then
		str = string.format("%s", str)
	end
	scr:draw_text(x + 0.5, y + 0.5, str, shadow_col, bgcol or 0x00000000)
	scr:draw_text(x, y, str, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
	return get_string_width(str)
end

local draw_rtext_with_shadow    = function(x, y, str, fgcol, bgcol)
	draw_rtext(x + 0.5, y + 0.5, str, shadow_col, bgcol)
	return draw_rtext(x, y, str, fgcol, bgcol)
end

local draw_ctext_with_shadow    = function(x, y, str, fgcol, bgcol)
	draw_ctext(x + 0.5, y + 0.5, str, shadow_col, bgcol)
	return draw_ctext(x, y, str, fgcol, bgcol)
end

local draw_fmt_rtext            = function(x, y, fmt, dec)
	return draw_rtext_with_shadow(x, y, string.format(fmt, dec))
end
-- コマンド文字列表示
local draw_cmd_text_with_shadow = function(x, y, str, fgcol, bgcol)
	-- 変換しつつUnicodeの文字配列に落とし込む
	local cstr, xx = convert(str), x
	for c in string.gmatch(cstr, "([%z\1-\127\194-\244][\128-\191]*)") do
		-- 文字の影
		scr:draw_text(xx + 0.5, y + 0.5, c, 0xFF000000)
		if btn_col[c] then
			-- ABCDボタンの場合は黒の●を表示した後ABCDを書いて文字の部分を黒く見えるようにする
			scr:draw_text(xx, y, convert("_("), text_col)
			scr:draw_text(xx, y, c, fgcol or btn_col[c])
		else
			scr:draw_text(xx, y, c, fgcol or text_col)
		end
		xx = xx + 5 -- フォントの大きさ問わず5pxずつ表示する
	end
end
-- コマンド入力表示
local draw_cmd                  = function(p, line, frame, str)
	local p1 = p == 1
	local xx = p1 and 12 or 294 -- 1Pと2Pで左右に表示し分ける
	local yy = (line + 10 - 1) * 8 -- +8はオフセット位置

	if 0 < frame then
		local cframe = 999 < frame and "LOT" or frame
		draw_rtext_with_shadow(p1 and 10 or 292, yy, cframe, text_col)
	end
	local col = 0xFAFFFFFF
	if p1 then
		for i = 1, 50 do
			scr:draw_line(i, yy, i + 1, yy, col)
			col = col - 0x05000000
		end
	else
		for i = 320, 270, -1 do
			scr:draw_line(i, yy, i - 1, yy, col)
			col = col - 0x05000000
		end
	end
	draw_cmd_text_with_shadow(xx, yy, str)
end
-- 処理アドレス表示
local draw_base                 = function(p, line, frame, addr, act_name, xmov)
	local p1 = p == 1
	local xx = p1 and 60 or 195 -- 1Pと2Pで左右に表示し分ける
	local yy = (line + 10 - 1) * 8 -- +8はオフセット位置

	local cframe
	if 0 < frame then
		cframe = 999 < frame and "LOT" or frame
	else
		cframe = "0"
	end
	local sline = string.format("%3s %8x %0.03f %s", cframe, addr, xmov, act_name)
	scr:draw_text(xx + 0.5, yy + 0.5, sline, 0xFF000000) -- 文字の影
	scr:draw_text(xx, yy, sline, text_col)
end

-- 当たり判定のオフセット
local addr_offset               = {
	[0x012C42] = { ["rbff2k"] = 0x28, ["rbff2h"] = 0x00 },
	[0x012C88] = { ["rbff2k"] = 0x28, ["rbff2h"] = 0x00 },
	[0x012D4C] = { ["rbff2k"] = 0x28, ["rbff2h"] = 0x00 }, --p1 push
	[0x012D92] = { ["rbff2k"] = 0x28, ["rbff2h"] = 0x00 }, --p2 push
	[0x039F2A] = { ["rbff2k"] = 0x0C, ["rbff2h"] = 0x20 }, --special throws
	[0x017300] = { ["rbff2k"] = 0x28, ["rbff2h"] = 0x00 }, --solid shadows
}
local addr_clone                = { ["rbff2k"] = -0x104, ["rbff2h"] = 0x20 }
local fix_addr                  = function(addr)
	local fix1 = addr_clone[emu.romname()] or 0
	local fix2 = addr_offset[addr] and (addr_offset[addr][emu.romname()] or fix1) or fix1
	return addr + fix2
end
local hurt_inv_type             = {
	-- 全身無敵
	full    = { type = 0, min_label = "全身", disp_label = "全身無敵", name = "全身無敵" },
	-- ライン関係の無敵
	main    = { type = 1, min_label = "メイン", disp_label = "メイン攻撃無敵", name = "メインライン攻撃無敵" },
	sway_oh = { type = 1, min_label = "対上", disp_label = "対メイン上段無敵", name = "対メインライン上段攻撃無敵" },
	sway_lo = { type = 1, min_label = "対下", disp_label = "対メイン下段無敵", name = "対メインライン下段攻撃無敵" },
	-- やられ判定の高さ
	top32   = { type = 2, value = 32, min_label = "膝上", disp_label = "上半身無敵1", name = "32 避け" },
	top40   = { type = 2, value = 40, min_label = "膝上", disp_label = "上半身無敵2", name = "40 ウェービングブロー,龍転身,ダブルローリング" },
	top48   = { type = 2, value = 48, min_label = "膝上", disp_label = "上半身無敵3", name = "48 ローレンス避け" },
	--[[
	top60 = { type = 2, value = 60, min_label = "上部", disp_label = "頭部無敵1", name = "60 屈 アンディ,東,舞,ホンフゥ,マリー,山崎,崇秀,崇雷,キム,ビリー,チン,タン"},
	top64 = { type = 2, value = 64, min_label = "上部", disp_label = "頭部無敵2", name = "64 屈 テリー,ギース,双角,ボブ,ダック,リック,シャンフェイ,アルフレッド"},
	top68 = { type = 2, value = 68, min_label = "上部", disp_label = "頭部無敵3", name = "68 屈 ローレンス"},
	top76 = { type = 2, value = 76, min_label = "上部", disp_label = "頭部無敵4", name = "76 屈 フランコ"},
	top80 = { type = 2, value = 80, min_label = "上部", disp_label = "頭部無敵5", name = "80 屈 クラウザー"},
	]]
	-- 足元無敵
	low40 = { type = 3, value = 40, min_label = "足元", disp_label = "足元無敵1", name = "対アンディ屈C" },
	low32 = { type = 3, value = 32, min_label = "足元", disp_label = "足元無敵2", name = "対ギース屈C" },
	low24 = { type = 3, value = 24, min_label = "足元", disp_label = "足元無敵3", name = "対だいたいの屈B（キムとボブ以外）" },
	-- 特殊やられ
	otg = { type = 4, min_label = "追撃可", disp_label = "ダウン追撃", name = "ダウン追撃のみ可能" },
	juggle = { type = 4, min_label = "追撃可", disp_label = "空中追撃", name = "空中追撃のみ可能" },
}
hurt_inv_type.values            = {
	hurt_inv_type.full, hurt_inv_type.main, hurt_inv_type.sway_oh, hurt_inv_type.sway_lo, hurt_inv_type.top32, hurt_inv_type.top40,
	hurt_inv_type.top48, -- hurt_inv_type.top60, hurt_inv_type.top64, hurt_inv_type.top68, hurt_inv_type.top76, hurt_inv_type.top80,
	hurt_inv_type.low40, hurt_inv_type.low32, hurt_inv_type.low24, hurt_inv_type.otg, hurt_inv_type.juggle
}
-- 投げ無敵
local throw_inv_type            = {
	time24 = { value = 24, disp_label = "タイマー24", name = "通常投げ" },
	time20 = { value = 20, disp_label = "タイマー20", name = "M.リアルカウンター投げ" },
	time10 = { value = 10, disp_label = "タイマー10", name = "真空投げ 羅生門 鬼門陣 M.タイフーン M.スパイダー 爆弾パチキ ドリル ブレスパ ブレスパBR リフトアップブロー デンジャラススルー ギガティックサイクロン マジンガ STOL" },
	sway   = { value = 256, disp_label = "スウェー", name = "スウェー" },
	flag1  = { value = 256, disp_label = "フラグ1", name = "無敵フラグ" },
	flag2  = { value = 256, disp_label = "フラグ2", name = "通常投げ無敵フラグ" },
	state  = { value = 256, disp_label = "やられ状態", name = "相互のやられ状態が非通常値" },
	no_gnd = { value = 256, disp_label = "高度", name = "接地状態ではない（地面へのめり込みも投げ不可）" },
}
throw_inv_type.values           = {
	throw_inv_type.time24, throw_inv_type.time20, throw_inv_type.time10, throw_inv_type.sway, throw_inv_type.flag1, throw_inv_type.flag2,
	throw_inv_type.state, throw_inv_type.no_gnd
}
hurt_inv_type.get               = function(p, real_top, real_bottom, box)
	local ret, top, low = {}, nil, nil
	for _, type in ipairs(hurt_inv_type.values) do
		if type.type == 2 and real_top <= type.value then top = type end
		if type.type == 3 and real_bottom >= type.value then low = type end
	end
	if top then table.insert(ret, top) end
	if low then table.insert(ret, low) end
	if box.type == box_types.down_otg then  -- 食らい(ダウン追撃のみ可)
		table.insert(ret, hurt_inv_type.otg)
	elseif box.type == box_types.launch then -- 食らい(空中追撃のみ可)
		table.insert(ret, hurt_inv_type.juggle)
	elseif box.type == box_types.hurt3 then -- 食らい(対ライン上攻撃)
		table.insert(ret, hurt_inv_type.sway_oh)
	elseif box.type == box_types.hurt4 then -- 食らい(対ライン下攻撃)
		table.insert(ret, hurt_inv_type.sway_lo)
	elseif box.type == box_types.sway_hurt1 or -- 食らい1(スウェー中)
		box.type == box_types.sway_hurt2 then -- 食らい2(スウェー中)
		table.insert(ret, hurt_inv_type.main)
	end
	return #ret == 0 and {} or ret
end
throw_inv_type.get              = function(p)
	if p.is_fireball then return {} end
	local ret = nil
	for _, type in ipairs(throw_inv_type.values) do if p.throw_timer >= type.value then ret = type end end
	ret = ret == nil and {} or { ret }
	if p.state ~= 0 or p.op.state ~= 0 then table.insert(ret, throw_inv_type.state) end
	if p.pos_y ~= 0 then table.insert(ret, throw_inv_type.no_gnd) end
	if p.sway_status ~= 0x00 then table.insert(ret, throw_inv_type.sway) end
	if p.invincible ~= 0 then table.insert(ret, throw_inv_type.flag1) end
	if p.tw_muteki2 ~= 0 then table.insert(ret, throw_inv_type.flag2) end
	return ret
end

local sort_ab                   = function(v1, v2)
	if v1 <= v2 then return v2, v1 end
	return v1, v2
end

local sort_ba                   = function(v1, v2)
	if v1 <= v2 then return v1, v2 end
	return v2, v1
end

local fix_box_scale             = function(p, src, dest)
	--local prev = string.format("%x id=%02x top=%s bottom=%s left=%s right=%s", p.addr.base, src.id, src.top, src.bottom, src.left, src.right)
	dest = dest or util.deepcopy(src) -- 計算元のboxを汚さないようにディープコピーしてから処理する

	-- 全座標について p.box_scale / 0x1000 の整数値に計算しなおす
	dest.top, dest.bottom = util.int16((src.top * p.box_scale) >> 6), util.int16((src.bottom * p.box_scale) >> 6)
	dest.left, dest.right = util.int16((src.left * p.box_scale) >> 6), util.int16((src.right * p.box_scale) >> 6)
	--util.printf("%s ->a top=%s bottom=%s left=%s right=%s", prev, dest.reach.top, dest.reach.bottom, dest.reach.left, dest.reach.right)

	if dest.type.kind == box_kinds.attack then
		-- 攻撃位置から解決した属性を付与する
		local real_top = math.tointeger(math.max(dest.top, dest.bottom) + screen.top - p.pos_z - p.y)
		local real_bottom = math.tointeger(math.min(dest.top, dest.bottom) + screen.top - p.pos_z - p.y)
		dest.blockable = {
			real_top = real_top,
			real_bottom = real_bottom,
			main = util.testbit(dest.reach.possible, possible_types.same_line) and dest.reach.blockable | get_top_type(real_top, top_types) or 0,
			sway = util.testbit(dest.reach.possible, possible_types.diff_line) and dest.reach.blockable | get_top_type(real_top, top_sway_types) or 0,
			punish = util.testbit(dest.reach.possible, possible_types.same_line) and get_top_type(real_bottom, top_punish_types) or 0
		}
	end

	-- キャラの座標と合算して画面上への表示位置に座標を変換する
	dest.left, dest.right = p.x - dest.left * p.flip_x, p.x - dest.right * p.flip_x
	dest.bottom, dest.top = p.y - dest.bottom, p.y - dest.top
	--util.printf("%s ->b x=%s y=%s top=%s bottom=%s left=%s right=%s", prev, p.x, p.y, dest.top, dest.bottom, dest.left, dest.right)
	return dest
end

-- ROM部分のメモリエリアへパッチあて
local load_rom_patch            = function()
	if mem.pached then return end

	mem.pached = mem.pached or util.apply_patch_file(pgm, rom_patch_path("char1-p1.pat"), true)

	--[[
	010668: 0C6C FFEF 0022           cmpi.w  #-$11, ($22,A4)                     ; THE CHALLENGER表示のチェック。
	01066E: 6704                     beq     $10674                              ; braにしてチェックを飛ばすとすぐにキャラ選択にいく
	010670: 4E75                     rts                                         ; bp 01066E,1,{PC=00F05E;g} にすると乱入の割り込みからラウンド開始前へ
	010672: 4E71                     nop                                         ; 4EF9 0000 F05E
	]]

	mem.wd16(0x1F3BC, 0x4E75) -- 1Pのスコア表示をすぐ抜ける
	mem.wd16(0x1F550, 0x4E75) -- 2Pのスコア表示をすぐ抜ける

	mem.wd8(0x25DB3, 0x1)     -- H POWERの表示バグを修正する 無駄な3段表示から2段表示へ

	mem.wd32(0xD238, 0x4E714E71) -- 家庭用モードでのクレジット消費をNOPにする

	mem.wd8(0x62E9D, 0x00)    -- 乱入されても常にキャラ選択できる

	-- 対CPU1体目でボスキャラも選択できるようにする サンキューヒマニトさん
	mem.wd8(0x633EE, 0x60)     -- CPUのキャラテーブルをプレイヤーと同じにする
	mem.wd8(0x63440, 0x60)     -- CPUの座標テーブルをプレイヤーと同じにする
	mem.wd32(0x62FF4, 0x4E714E71) -- PLのカーソル座標修正をNOPにする
	mem.wd32(0x62FF8, 0x4E714E71) -- PLのカーソル座標修正をNOPにする

	mem.wd8(0x62EA6, 0x60)     -- CPU選択時にアイコンを減らすのを無効化
	mem.wd32(0x63004, 0x4E714E71) -- PLのカーソル座標修正をNOPにする

	-- キャラ選択の時間減らす処理をNOPにする
	mem.wd16(0x63336, 0x4E71)
	mem.wd16(0x63338, 0x4E71)

	--時間の値にアイコン用のオフセット値を改変して空表示にする
	-- 0632D0: 004B -- キャラ選択の時間の内部タイマー初期値1 デフォは4B=75フレーム
	-- 063332: 004B -- キャラ選択の時間の内部タイマー初期値2 デフォは4B=75フレーム
	mem.wd16(0x632DC, 0x0DD7)

	-- 常にCPUレベルMAX
	mem.wd32(fix_addr(0x0500E8), 0x303C0007)
	mem.wd32(fix_addr(0x050118), 0x3E3C0007)
	mem.wd32(fix_addr(0x050150), 0x303C0007)
	mem.wd32(fix_addr(0x0501A8), 0x303C0007)
	mem.wd32(fix_addr(0x0501CE), 0x303C0007)

	-- 対戦の双角ステージをビリーステージに変更する（MVSと家庭用共通）
	mem.wd16(0xF290, 0x0004)

	-- 簡易超必ONのときにダックのブレイクスパイラルブラザー（BRも）が出るようにする
	mem.wd16(0x0CACC8, 0xC37C)

	-- クレジット消費をNOPにする
	mem.wd32(0x00D238, 0x4E714E71)
	mem.wd32(0x00D270, 0x4E714E71)

	-- 家庭用の初期クレジット9
	mem.wd16(0x00DD54, 0x0009)
	mem.wd16(0x00DD5A, 0x0009)
	mem.wd16(0x00DF70, 0x0009)
	mem.wd16(0x00DF76, 0x0009)

	-- 家庭用のクレジット表示をスキップ bp 00C734,1,{PC=c7c8;g}
	-- CREDITをCREDITSにする判定をスキップ bp C742,1,{PC=C748;g}
	-- CREDIT表示のルーチンを即RTS
	mem.wd16(0x00C700, 0x4E75)

	-- デバッグDIPによる自動アンリミのバグ修正
	mem.wd8(fix_addr(0x049951), 0x2)
	mem.wd8(fix_addr(0x049947), 0x9)

	--[[ 未適用ハック
	-- 空振りCAできる。
	-- 逆にFFにしても個別にCA派生を判定している処理があるため単純に全不可にはできない。
	-- オリジナル（家庭用）
	-- maincpu.rd@02FA72=00000000
	-- maincpu.rd@02FA76=00000000
	-- maincpu.rd@02FA7A=FFFFFFFF
	-- maincpu.rd@02FA7E=00FFFF00
	-- maincpu.rw@02FA82=FFFF
	パッチ（00をFFにするとヒット時限定になる）
	for i = 0x02FA72, 0x02FA82 do mem.wd8(i, 0x00) end
	
	-- 連キャン、必キャン可否テーブルに連キャンデータを設定する。C0が必、D0で連。
	for i = 0x085138, 0x08591F do mem.wd8(i, 0xD0) end

	-- 逆襲拳、サドマゾの初段で相手の状態変更しない（相手が投げられなくなる事象が解消する）
	-- mem.wd8(0x57F43, 0x00)
	
	-- よそで見つけたチート
	-- https://www.neo-geo.com/forums/index.php?threads/universe-bios-released-good-news-for-mvs-owners.41967/page-7
	mem.wd8 (10E003, 0x0C)       -- Auto SDM combo (RB2) 0x56D98A
	mem.wd32(1004D5, 0x46A70500) -- 1P Crazy Yamazaki Return (now he can throw projectile "anytime" with some other bug) 0x55FE5C
	mem.wd16(1004BF, 0x3CC1)     -- 1P Level 2 Blue Mary 0x55FE46
	-- cheat offset NGX 45F987 = MAME 0

	-- RAM改変によるCPUレベル MAX（ロムハックのほうが楽）
	-- mem.w16(0x10E792, 0x0007) -- maincpu.pw@10E792=0007
	-- mem.w16(0x10E796, 0x0007) -- maincpu.pw@10E796=0008
	]]
end

-- ヒット効果アドレステーブルの取得
local load_hit_effects = function()
	for i, _ in ipairs(hit_effects) do
		table.insert(hit_effect_moves, mem.r32(0x579DA + (i - 1) * 4))
		table.insert(hit_effect_move_keys, string.format("%2s %s %x", i, table.concat(hit_effects[i], " "), hit_effect_moves[#hit_effect_moves]))
	end
end

local load_hit_system_stops = function()
	if hit_system_stops["a"] then return end
	for addr = 0x57C54, 0x57CC0, 4 do hit_system_stops[mem.r32(addr)] = true end
	hit_system_stops["a"] = true
end

-- キャラの基本アドレスの取得
local load_proc_base            = function()
	if chars[1].proc_base then return end
	for char = 1, #chars - 1 do
		local char4 = char << 2
		chars[char].proc_base = {
			cancelable    = mem.r32(char4 + 0x850D8),
			forced_down   = 0x88A12,
			hitstop       = mem.r32(char4 + fix_addr(0x83C38)),
			damege        = mem.r32(char4 + fix_addr(0x813F0)),
			stun          = mem.r32(char4 + fix_addr(0x85CCA)),
			stun_timer    = mem.r32(char4 + fix_addr(0x85D2A)),
			max_hit       = mem.r32(char4 + fix_addr(0x827B8)),
			esaka         = mem.r32(char4 + 0x23750),
			pow_up        = ((0xC == char) and 0x8C274 or (0x10 == char) and 0x8C29C or 0x8C24C),
			pow_up_ext    = mem.r32(0x8C18C + char4),
			effect        = -0x20 + fix_addr(0x95BEC),
			chip_damage   = fix_addr(0x95CCC),
			hitstun1      = fix_addr(0x95CCC),
			hitstun2      = 0x16 + 0x2 + fix_addr(0x5AF7C),
			blockstun     = 0x1A + 0x2 + fix_addr(0x5AF88),
			bs_pow        = mem.r32(char4 + 0x85920),
			bs_invincible = mem.r32(char4 + 0x85920) + 0x1,
			sp_invincible = mem.r32(char4 + 0x8DE62),
		}
	end
end

-- 接触判定の取得
local load_push_box             = function()
	if chars[1].push_box then return end
	-- キャラデータの押し合い判定を作成
	-- キャラごとの4種類の判定データをロードする
	for char = 1, #chars - 1 do
		chars[char].push_box_mask = mem.r32(0x5C728 + (char << 2))
		chars[char].push_box = {}
		for _, addr in ipairs({ 0x5C9BC, 0x5CA7C, 0x5CB3C, 0x5CBFC }) do
			local a2 = addr + (char << 3)
			local y1, y2, x1, x2 = mem.r8i(a2 + 0x1), mem.r8i(a2 + 0x2), mem.r8i(a2 + 0x3), mem.r8i(a2 + 0x4)
			chars[char].push_box[addr] = {
				addr = addr,
				id = 0,
				type = box_types.push,
				front = x1,
				back = x2,
				left = math.min(x1, x2),
				right = math.max(x1, x2),
				top = math.min(y1, y2),
				bottom = math.max(y1, y2),
			}
			-- printf("char=%s addr=%x type=000 x1=%s x2=%s y1=%s y2=%s", char, a2, x1, x2, y1, y2)
		end
	end
end

local get_push_box              = function(p)
	-- 家庭用 05C6D0 からの処理
	local push_box = chars[p.char].push_box
	if p.char == 0x5 and util.testbit(p.flag_c8, state_flag_c8._15) then
		return push_box[0x5C9BC]
	else
		if util.testbit(p.flag_c0, state_flag_c0._01) ~= true and p.pos_y ~= 0 then
			if (p.flag_c8 & p.char_data.push_box_mask) ~= 0 then
				return push_box[0x5CB3C]
			elseif p.flag_c8 & 0xFFFF0000 == 0 then
				return push_box[0x5CB3C]
			else
				return push_box[0x5CBFC]
			end
		end
		return push_box[(p.flag_c0 & 0x14000046 ~= 0) and 0x5CA7C or 0x5C9BC]
	end
end

local fix_throw_box_pos         = function(box)
	box.left, box.right = box.x - box.left * box.flip_x, box.x - box.right * box.flip_x
	box.bottom, box.top = box.y - box.bottom, box.y - box.top
	return box
end

-- 通常投げ間合い
-- 家庭用0x05D78Cからの処理
local get_normal_throw_box      = function(p)
	-- 相手が向き合いか背向けかで押し合い幅を解決して反映
	local push_box, op_push_box = chars[p.char].push_box[0x5C9BC], chars[p.op.char].push_box[0x5C9BC]
	local op_edge = (p.internal_side == p.op.internal_side) and op_push_box.back or op_push_box.front
	local center = util.int16(((push_box.front - math.abs(op_edge)) * p.box_scale) >> 6)
	local range = mem.r8(fix_addr(0x5D854) + p.char4)
	return fix_throw_box_pos({
		id = 0x100, -- dummy
		type = box_types.normal_throw,
		left = center - range,
		right = center + range,
		top = -0x05, -- 地上投げの範囲をわかりやすくする
		bottom = 0x05,
		x = p.pos - screen.left,
		y = screen.top - p.pos_y - p.pos_z,
		threshold = mem.r8(0x3A66C), -- 投げのしきい値 039FA4からの処理
		flip_x = p.internal_side, -- 向き補正値
	})
end

-- 必殺投げ間合い
local get_special_throw_box     = function(p, id)
	local a0 = 0x3A542 + (0xFFFF & (id << 3))
	local top, bottom = mem.r16(a0 + 2), mem.r16(a0 + 4)
	if id == 0xA then
		top, bottom = 0x1FFF, 0x1FFF -- ダブルクラッチは上下無制限
	elseif top + bottom == 0 then
		top, bottom = 0x05, 0x05 -- 地上投げの範囲をわかりやすくする
	end
	return fix_throw_box_pos({
		id = id,
		type = box_types.special_throw,
		left = -mem.r16(a0),
		right = 0x0,
		top = top,
		bottom = -bottom,
		x = p.pos - screen.left,
		y = screen.top - p.pos_y - p.pos_z,
		threshold = mem.r8(0x3A66C + (0xFF & id)), -- 投げのしきい値 039FA4からの処理
		flip_x = p.internal_side,            -- 向き補正値
	})
end

-- 空中投げ間合い
-- MEMO: 0x060566(家庭用)のデータを読まずにハードコードにしている
local get_air_throw_box         = function(p)
	return fix_throw_box_pos({
		id = 0x200, -- dummy
		type = box_types.air_throw,
		left = -0x30,
		right = 0x0,
		top = -0x20,
		bottom = 0x20,
		x = p.pos - screen.left,
		y = screen.top - p.pos_y - p.pos_z,
		threshold = 0,      -- 投げのしきい値
		flip_x = p.internal_side, -- 向き補正値
	})
end

local get_throwbox              = function(p, id)
	if id == 0x100 then
		return get_normal_throw_box(p)
	elseif id == 0x200 then
		return get_air_throw_box(p)
	end
	return get_special_throw_box(p, id)
end

local draw_hitbox               = function(box)
	--util.printf("%s  %s", box.type.kind, box.type.enabled)
	if box.type.enabled ~= true then return end
	-- 背景なしの場合は判定の塗りつぶしをやめる
	local outline, fill = box.type.outline, global.disp_bg and box.type.fill or 0
	local x1, x2 = sort_ab(box.left, box.right)
	local y1, y2 = sort_ab(box.top, box.bottom)
	scr:draw_box(x1, y1, x1 - 1, y2, 0, outline)
	scr:draw_box(x2, y1, x2 + 1, y2, 0, outline)
	scr:draw_box(x1, y1, x2, y1 - 1, 0, outline)
	scr:draw_box(x1, y2, x2, y2 + 1, outline, outline)
	scr:draw_box(x1, y1, x2, y2, outline, fill)
	--util.printf("%s  x1=%s x2=%s y1=%s y2=%s",  box.type.kind, x1, x2, y1, y2)
end

local draw_range                = function(range)
	local label, flip_x, x, y, col = range.label, range.flip_x, range.x, range.y, range.within and 0xFFFFFF00 or 0xFFBBBBBB
	local size = range.within == nil and global.axis_size or global.axis_size2 -- 範囲判定がないものは単純な座標とみなす
	scr:draw_box(x, y - size, x + flip_x, y + size, 0, col)
	scr:draw_box(x - size + flip_x, y, x + size + flip_x, y - 1, 0, col)
	draw_ctext_with_shadow(x, y, label or "", col)
end

-- 0:攻撃無し 1:ガード継続小 2:ガード継続大
local get_gd_strength           = function(p, data)
	if p.is_fireball then return 1 end -- 飛び道具は無視
	-- 家庭用0271FCからの処理
	local cond2 = mem.r8(data)      -- ガード判断用 0のときは何もしていない
	if mem.r8(p.addr.base + 0xA2) ~= 0 then
		return 1
	elseif cond2 ~= 0 then
		local b2 = 0x80 == (0x80 & mem.r8(mem.r32(0x8C9E2 + p.char4) + cond2))
		return b2 and 2 or 1
	end
	return 0
end

-- 判定枠のチェック処理種類
local hitbox_possible_map       = {
	[0x01311C] = possible_types.none,   -- 常に判定しない
	[0x012FF0] = possible_types.same_line, -- → 013038 同一ライン同士なら判定する
	[0x012FFE] = possible_types.both_line, -- → 013054 異なるライン同士でも判定する
	[0x01300A] = possible_types.unknown, -- → 013018 不明
	[0x012FE2] = possible_types.air_onry, -- → 012ff0 → 013038 相手が空中にいれば判定する
}
local get_hitbox_possibles      = function(id)
	local possibles = {}
	for k, addr_or_func in pairs(hitbox_possibles) do
		local ret = possible_types.none
		if type(addr_or_func) == "number" then
			-- 家庭用版 012DBC~012F04,012F30~012F96のデータ取得処理をベースに判定＆属性チェック
			local d2 = 0xFF & (id - 0x20)
			if d2 >= 0 then ret = hitbox_possible_map[mem.r32(0x13120 + (mem.r8(addr_or_func + d2) << 2))] end
		else
			ret = addr_or_func(id)
		end
		if possible_types.none ~= ret then possibles[k] = ret end
	end
	return possibles
end

local box_with_bit_types        = {
	-- 優先順で並べる
	{ box_type = box_types.fake_juggle_fb,     attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.fake | frame_attack_types.juggle },
	{ box_type = box_types.fake_fireball,      attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.fake },
	{ box_type = box_types.fake_juggle,        attackbit = frame_attack_types.attacking | frame_attack_types.fake | frame_attack_types.juggle },
	{ box_type = box_types.fake_attack,        attackbit = frame_attack_types.attacking | frame_attack_types.fake },

	{ box_type = box_types.harmless_juggle_fb, attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.fullhit | frame_attack_types.juggle },
	{ box_type = box_types.harmless_juggle_fb, attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.obsolute | frame_attack_types.juggle },
	{ box_type = box_types.harmless_juggle_fb, attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.harmless | frame_attack_types.juggle },
	{ box_type = box_types.juggle_fireball,    attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.juggle },
	{ box_type = box_types.harmless_fireball,  attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.fullhit },
	{ box_type = box_types.harmless_fireball,  attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.obsolute },
	{ box_type = box_types.harmless_fireball,  attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.harmless },
	{ box_type = box_types.fireball,           attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.attacking },
	{ box_type = box_types.harmless_juggle,    attackbit = frame_attack_types.attacking | frame_attack_types.fullhit | frame_attack_types.juggle },
	{ box_type = box_types.harmless_juggle,    attackbit = frame_attack_types.attacking | frame_attack_types.harmless | frame_attack_types.juggle },
	{ box_type = box_types.harmless_juggle,    attackbit = frame_attack_types.attacking | frame_attack_types.obsolute | frame_attack_types.juggle },
	{ box_type = box_types.juggle,             attackbit = frame_attack_types.attacking | frame_attack_types.juggle },
	{ box_type = box_types.harmless_attack,    attackbit = frame_attack_types.attacking | frame_attack_types.fullhit },
	{ box_type = box_types.harmless_attack,    attackbit = frame_attack_types.attacking | frame_attack_types.obsolute },
	{ box_type = box_types.harmless_attack,    attackbit = frame_attack_types.attacking | frame_attack_types.harmless },
	{ box_type = box_types.attack,             attackbit = frame_attack_types.attacking },
}
local fix_box_type              = function(p, box)
	local type = p.in_sway_line and box.sway_type or box.type
	if type ~= box_types.attack then return type end
	-- TODO 多段技の状態
	p.max_hit_dn = p.max_hit_dn or 0
	if p.max_hit_dn > 1 or p.max_hit_dn == 0 or (p.char == 0x4 and p.attack == 0x16) then
	end
	-- TODO つかみ技はダメージ加算タイミングがわかるようにする
	if util.testbit(p.flag_cc, state_flag_cc.grabbing) and p.op.last_damage_scaled ~= 0xFF then
	end
	for _, item in ipairs(box_with_bit_types) do
		if util.testbit(p.attackbit & 0x7F, item.attackbit, true) then return item.box_type end
	end
	return box_with_bit_types[#box_with_bit_types].box_type
end

-- 遠近間合い取得
local load_close_far            = function() 
	if chars[1].close_far then return end
	-- 地上通常技の近距離間合い 家庭用02DD02からの処理
	for org_char = 1, #chars - 1 do
		local char                = org_char - 1
		local abc_offset          = mem.close_far_offset + (char * 4)
		local d_offset            = mem.close_far_offset_d + (char * 2)
		-- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
		chars[org_char].close_far = {
			[0x00] = {
				A = { x1 = 0, x2 = mem.r8(abc_offset) },
				B = { x1 = 0, x2 = mem.r8(abc_offset + 1) },
				C = { x1 = 0, x2 = mem.r8(abc_offset + 2) },
				D = { x1 = 0, x2 = mem.r16(d_offset) },
			},
			[0x01] = {},
			[0x82] = {},
		}
	end

	-- 対スウェーライン攻撃の近距離間合い
	local get_lmo_range_internal = function(ret, name, d0, d1, incl_last)
		local decd1 = util.int16tofloat(d1)
		local intd1 = math.floor(decd1)
		local x1, x2 = 0, 0
		for d = 1, intd1 do
			x2 = d * d0
			ret[name .. d - 1] = { x1 = x1, x2 = x2 - 1 }
			x1 = x2
		end
		if incl_last then
			ret[name .. intd1] = { x1 = x1, x2 = math.floor(d0 * decd1) } -- 1Fあたりの最大移動量になる距離
		end
		return ret
	end
	-- 家庭用2EC72,2EDEE,2E1FEからの処理
	for org_char = 1, #chars - 1 do
		local ret = {}
		-- データが近距離、遠距離の2種類しかないのと実質的に意味があるのが近距離のものなので最初のデータだけ返す
		-- 0x0:近A 0x1:遠A 0x2:近B 0x3:遠B 0x4:近C 0x5:遠C
		get_lmo_range_internal(ret, "", mem.r8(mem.r32(0x2EE06 + 0x0 * 4) + org_char * 6), 0x2A000, true)
		ret["近"] = { x1 = 0, x2 = 72 } -- 近距離の対メインライン攻撃になる距離
		if org_char == 6 then
			get_lmo_range_internal(ret, "必", 24, 0x40000) -- 渦炎陣
		elseif org_char == 14 then
			get_lmo_range_internal(ret, "必", 24, 0x80000) -- クロスヘッドスピン
		end
		-- printf("%s %s %x %s %x %s", chars[char].name, act_name, d0, d0, d1, decd1)
		chars[org_char].close_far[0x80] = ret
	end
end
local reset_memory_tap = function(enabled)
	if not global.holder then return end
	if enabled ~= true and global.holder.on == true then
		for _, tap in ipairs(global.holder.taps) do tap:remove() end
		global.holder.on = false
	elseif enabled == true and global.holder.on ~= true then
		for _, tap in ipairs(global.holder.taps) do tap:reinstall() end
		global.holder.on = true
	end
end
local load_memory_tap           = function(wps) -- tapの仕込み
	if global.holder then
		reset_memory_tap(true)
		return
	end
	global.holder = { on = true, taps = {} }
	for _, p in ipairs(wps) do
		for _, k in ipairs({ "wp8", "wp16", "wp32", "rp8", "rp16", "rp32", }) do
			for any, cb in pairs(p[k] or {}) do
				local addr = type(any) == "number" and any or any.addr
				local filter = type(any) == "number" and {} or not any.filter and {} or type(any.filter) == "table" and any.filter or type(any.filter) == "number" and { any.filter }
				---@diagnostic disable-next-line: redundant-parameter
				mem[k](addr > 0xFF and addr or ((p.addr and p.addr.base) + addr), cb, filter)
			end
		end
	end
end

local apply_attack_infos        = function(p, id, base_addr)
	--[[ ヒット効果、削り補正、硬直
	一動作で複数の攻撃判定を持っていてもIDの値は同じになる
	058232(家庭用版)からの処理
	1004E9のデータ＝5C83Eでセット 技ID
	1004E9のデータ-0x20 + 0x95C0C のデータがヒット効果の元ネタ D0
	D0 = 0x9だったら 1005E4 くらった側E4 OR 0x40の結果をセット （7ビット目に1）
	D0 = 0xAだったら 1005E4 くらった側E4 OR 0x40の結果をセット （7ビット目に1）
	D0 x 4 + 579da
	d0 = fix_addr(0x0579DA + d0 * 4) --0x0579DA から4バイトのデータの並びがヒット効果の処理アドレスになる
	]]
	p.effect        = mem.r8(id + base_addr.effect)
	-- 削りダメージ計算種別取得 05B2A4 からの処理
	p.chip_dmg_type = data.chip_dmg_type_tbl[(0xF & mem.r8(base_addr.chip_damage + id)) + 1]
	p.chip_dmg      = p.chip_dmg_type.calc(p.pure_dmg)
	-- 硬直時間取得 05AF7C(家庭用版)からの処理
	local d2        = 0xF & mem.r8(id + base_addr.hitstun1)
	p.hitstun       = mem.r8(base_addr.hitstun2 + d2) + 1 + 3 -- ヒット硬直
	p.blockstun     = mem.r8(base_addr.blockstun + d2) + 1 + 2 -- ガード硬直
end

local dummy_gd_type             = {
	none   = 1, -- なし
	auto   = 2, -- オート
	bs     = 3, -- ブレイクショット
	hit1   = 4, -- 1ヒットガード
	block1 = 5, -- 1ガード
	fixed  = 6, -- 常時
	random = 7, -- ランダム
	force  = 8, -- 強制
}
local wakeup_type               = {
	none = 1, -- なし
	rvs  = 2, -- リバーサル
	tech = 3, -- テクニカルライズ
	sway = 4, -- グランドスウェー
	atk  = 5, -- 起き上がり攻撃
}
local rvs_wake_types            = util.new_set(wakeup_type.tech, wakeup_type.sway, wakeup_type.rvs)
rbff2.startplugin               = function()
	local players, all_wps, all_objects, all_fireballs, hitboxies, ranges = {}, {}, {}, {}, {}, {}
	local hitboxies_order = function(b1, b2) return (b1.id < b2.id) end
	local ranges_order = function(r1, r2) return (r1.within and 1 or -1) < (r2.within and 1 or -1) end
	local find = function(sources, resolver) -- sourcesの要素をresolverを通して得た結果で最初の非nilの値を返す
		sources = sources or {}
		local i, ii, p, a = 1, nil, nil, nil
		return function()
			while i <= #sources and p == nil do
				i, ii, p, a = i + 1, i, resolver(sources[i]), sources[i]
				if p then return ii, a, p end -- インデックス, sources要素, convert結果
			end
		end
	end
	local get_object_by_addr = function(addr, default) return all_objects[addr] or default end             -- ベースアドレスからオブジェクト解決
	local get_object_by_reg = function(reg, default) return all_objects[mem.rg(reg, 0xFFFFFF)] or default end -- レジストリからオブジェクト解決
	local now = function() return global.frame_number + 1 end
	for i = 1, 2 do                                                                                        -- プレイヤーの状態など
		local p1 = (i == 1)
		local base = p1 and 0x100400 or 0x100500
		players[i] = {
			num               = i,
			base              = 0x0,
			bases             = {},

			dummy_act         = 1,                    -- 立ち, しゃがみ, ジャンプ, 小ジャンプ, スウェー待機
			dummy_gd          = dummy_gd_type.none,   -- なし, オート, ブレイクショット, 1ヒットガード, 1ガード, 常時, ランダム, 強制
			dummy_wakeup      = wakeup_type.none,     -- なし, リバーサル, テクニカルライズ, グランドスウェー, 起き上がり攻撃

			dummy_bs          = nil,                  -- ランダムで選択されたブレイクショット
			dummy_bs_list     = {},                   -- ブレイクショットのコマンドテーブル上の技ID
			dummy_bs_chr      = 0,                    -- ブレイクショットの設定をした時のキャラID
			bs_count          = -1,                   -- ブレイクショットの実施カウント

			dummy_rvs         = nil,                  -- ランダムで選択されたリバーサル
			dummy_rvs_list    = {},                   -- リバーサルのコマンドテーブル上の技ID
			dummy_rvs_chr     = 0,                    -- リバーサルの設定をした時のキャラID
			rvs_count         = -1,                   -- リバーサルの実施カウント
			gd_rvs_enabled    = false,                -- ガードリバーサルの実行可否

			life_rec          = true,                 -- 自動で体力回復させるときtrue
			red               = 2,                    -- 体力設定     	--"最大", "赤", "ゼロ" ...
			max               = 1,                    -- パワー設定       --"最大", "半分", "ゼロ" ...
			disp_hitbox       = true,                 -- 判定表示
			disp_range        = true,                 -- 間合い表示
			disp_base         = false,                -- 処理のアドレスを表示するときtrue
			hide_char         = false,                -- キャラを画面表示しないときtrue
			hide_phantasm     = false,                -- 残像を画面表示しないときtrue
			disp_dmg          = true,                 -- ダメージ表示するときtrue
			disp_cmd          = 2,                    -- 入力表示 1:OFF 2:ON 3:ログのみ 4:キーディスのみ
			disp_frm          = 4,                    -- フレーム数表示する
			disp_fbfrm        = true,                 -- 弾のフレーム数表示するときtrue
			disp_stun         = true,                 -- 気絶表示
			disp_sts          = 3,                    -- 状態表示 "OFF", "ON", "ON:小表示", "ON:大表示"

			dis_plain_shift   = false,                -- ライン送らない現象

			no_hit            = 0,                    -- Nヒット目に空ぶるカウントのカウンタ
			no_hit_limit      = 0,                    -- Nヒット目に空ぶるカウントの上限

			last_normal_state = true,
			last_effects      = {},
			life              = 0,   -- いまの体力
			mv_state          = 0,   -- 動作
			old_state         = 0,   -- 前フレームのやられ状態
			char              = 0,
			close_far         = {},
			act               = 0,
			acta              = 0,
			atk_count         = 0,
			attack            = 0,       -- 攻撃中のみ変化
			old_attack        = 0,
			attack_id         = 0,       -- 当たり判定ごとに設定されているID
			effect            = 0,
			attacking         = false,   -- 攻撃判定発生中の場合true
			dmmy_attacking    = false,   -- ヒットしない攻撃判定発生中の場合true（嘘判定のぞく）
			juggle            = false,   -- 空中追撃判定発生中の場合true
			forced_down       = false,   -- 受け身行動可否
			pow_up            = 0,       -- 状態表示用パワー増加量空振り
			pow_up_hit        = 0,       -- 状態表示用パワー増加量ヒット
			pow_up_gd         = 0,       -- 状態表示用パワー増加量ガード
			pow_revenge       = 0,       -- 状態表示用パワー増加量倍返し反射
			pow_absorb        = 0,       -- 状態表示用パワー増加量倍返し吸収
			hitstop           = 0,       -- 攻撃側のガード硬直
			old_pos           = 0,       -- X座標
			old_pos_frc       = 0,       -- X座標少数部
			pos               = 0,       -- X座標
			pos_frc           = 0,       -- X座標少数部
			old_posd          = 0,       -- X座標
			posd              = 0,       -- X座標
			poslr             = "L",     -- 右側か左側か
			max_pos           = 0,       -- X座標最大
			min_pos           = 0,       -- X座標最小
			pos_y             = 0,       -- Y座標
			pos_frc_y         = 0,       -- Y座標少数部
			pos_miny          = 0,       -- Y座標の最小値
			old_pos_y         = 0,       -- Y座標
			old_pos_frc_y     = 0,       -- Y座標少数部
			old_in_air        = false,
			in_air            = false,
			chg_air_state     = 0,       -- ジャンプの遷移ポイントかどうか
			force_y_pos       = 1,       -- Y座標強制
			pos_z             = 0,       -- Z座標
			old_pos_z         = 0,       -- Z座標
			on_main_line      = 0,       -- Z座標メインに移動した瞬間フレーム
			on_sway_line      = 0,       -- Z座標スウェイに移動した瞬間フレーム
			in_sway_line      = false,   -- Z座標
			sway_status       = 0,       --
			side              = 0,       -- 向き
			state             = 0,       -- いまのやられ状態
			flag_c0           = 0,       -- 処理で使われているフラグ群
			old_flag_c0       = 0,       -- 処理で使われているフラグ群
			flag_cc           = 0,       -- 処理で使われているフラグ群
			old_flag_cc       = 0,       -- 処理で使われているフラグ群
			attack_flag       = false,
			flag_c8           = 0,       -- 処理で使われているフラグ群
			flag_d0           = 0,       -- 処理で使われているフラグ（硬直の判断用）
			old_flag_d0       = 0,       -- 処理で使われているフラグ（硬直の判断用）
			color             = 0,       -- カラー A=0x00 D=0x01

			frame_gap         = 0,
			last_frame_gap    = 0,
			hist_frame_gap    = { 0 },
			block1            = 0,   -- ガード時（硬直前後）フレームの判断用
			on_block          = 0,   -- ガード時（硬直前）フレーム
			on_block1         = 0,   -- ガード時（硬直後）フレーム
			hit1              = 0,   -- ヒット時（硬直前後）フレームの判断用
			on_hit            = 0,   -- ヒット時（硬直前）フレーム
			on_hit1           = 0,   -- ヒット時（硬直後）フレーム
			on_punish         = 0,
			on_wakeup         = 0,
			on_down           = 0,
			hit_skip          = 0,
			old_skip_frame    = false,
			skip_frame        = false,

			knock_back1       = 0,    -- のけぞり確認用1(色々)
			knock_back2       = 0,    -- のけぞり確認用2(裏雲隠し)
			knock_back3       = 0,    -- のけぞり確認用3(フェニックススルー)
			konck_back4       = 0,    -- のけぞり確認用4(色々,リバサ表示判断用)

			old_knock_back1   = 0,    -- のけぞり確認用1(色々)
			fireball_rank     = 0,    -- 飛び道具の強さ
			esaka_range       = 0,    -- 詠酒の間合いチェック用

			key_now           = {},   -- 個別キー入力フレーム
			key_pre           = {},   -- 前フレームまでの個別キー入力フレーム
			key_hist          = {},
			ggkey_hist        = {},
			key_frames        = {},
			act_frame         = 0,
			act_frames        = {},
			act_frames2       = {},
			act_frames_total  = 0,

			throw_boxies      = {},

			muteki            = {
				act_frames  = {},
				act_frames2 = {},
			},

			frm_gap           = {
				act_frames  = {},
				act_frames2 = {},
			},

			frame_info        = {
				text = { "", "" },
				attack = {
					buff = nil,
					txt = { "", "" }
				},
				hurt = {
					buff = nil,
					txt = { "", "" }
				},
			},

			reg_pcnt          = 0,   -- キー入力 REG_P1CNT or REG_P2CNT
			reg_st_b          = 0,   -- キー入力 REG_STATUS_B

			update_state      = 0,
			update_act        = 0,
			random_boolean    = math.random(255) % 2 == 0,

			backstep_killer   = false,

			boxies            = {},
			hitbox_txt        = "",
			hurtbox_txt       = "",
			chg_hitbox_frm    = 0,
			chg_hurtbox_frm   = 0,
			fireballs         = {},

			addr              = {
				base        = base,            -- キャラ状態とかのベースのアドレス
				control     = base + 0x12,     -- Human 1 or 2, CPU 3
				pos         = base + 0x20,     -- X座標
				pos_y       = base + 0x28,     -- Y座標
				sway_status = base + 0x89,     -- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
				input_side  = base + 0x86,     -- コマンド入力でのキャラ向きチェック用 00:左側 80:右側
				life        = base + 0x8B,     -- 体力
				pow         = base + 0xBC,     -- パワーアドレス
				hurt_state  = base + 0xE4,     -- やられ状態 ライン送らない状態用
				stun_limit  = p1 and 0x10B84E or 0x10B856, -- 最大気絶値
				no_hit      = p1 and 0x10DDF2 or 0x10DDF1, -- ヒットしないフック
				char        = p1 and 0x107BA5 or 0x107BA7, -- キャラID
				color       = p1 and 0x107BAC or 0x107BAD, -- カラー A=0x00 D=0x01
				stun        = p1 and 0x10B850 or 0x10B858, -- 現在気絶値
				stun_timer  = p1 and 0x10B854 or 0x10B85C, -- 気絶値ゼロ化までの残フレーム数
				reg_pcnt    = p1 and 0x300000 or 0x340000, -- キー入力 REG_P1CNT or REG_P2CNT アドレス
				reg_st_b    = 0x380000,        -- キー入力 REG_STATUS_B アドレス
			},
		}
		local p = players[i]
		for k = 1, #kprops do
			p.key_now[kprops[k]], p.key_pre[kprops[k]] = 0, 0
		end
		for k = 1, 16 do
			p.key_hist[k], p.key_frames[k], p.act_frames[k] = "", 0, { 0, 0 }
			p.bases[k] = { count = 0, addr = 0x0, act_data = nil, name = "", pos1 = 0, pos2 = 0, xmov = 0, }
		end
		local update_tmp_combo = function(data)
			if data == 1 then    -- 一次的なコンボ数が1リセットしたタイミングでコンボ用の情報もリセットする
				p.last_combo             = 1 -- 2以上でのみ0x10B4E4か0x10B4E5が更新されるのでここで1リセットする
				p.last_stun              = 0
				p.last_st_timer          = 0
				p.combo_update           = global.frame_number + 1
				p.combo_damage           = 0
				p.combo_start_stun       = p.stun
				p.combo_start_stun_timer = p.stun_timer
				p.combo_stun             = 0
				p.combo_stun_timer       = 0
				p.combo_pow              = p.hurt_attack == p.op.attack and p.op.pow_up or 0
			elseif data > 1 then
				p.combo_update = global.frame_number + 1
			end
		end
		p.wp8 = {
			[0x16] = function(data) p.knock_back2 = data end, -- のけぞり確認用2(裏雲隠し)
			[0x69] = function(data) p.knock_back1 = data end, -- のけぞり確認用1(色々)
			[0x7E] = function(data) p.knock_back3 = data end, -- のけぞり確認用3(フェニックススルー)
			[{ addr = 0x82, filter = { 0x2668C, 0x2AD24, 0x2AD2C } }] = function(data, ret)
				local pc = mem.pc()
				if pc == 0x2668C then p.input1, p.flag_fin = data, false end
				if pc == 0x2AD24 or pc == 0x2AD2C then p.flag_fin = util.testbit(data, 0x80) end -- キー入力 直近Fの入力, 動作の最終F
			end,
			[0x83] = function(data) p.input2 = data end,                             -- キー入力 1F前の入力
			[0x84] = function(data) p.cln_btn = data end,                            -- クリアリングされたボタン入力
			[0x86] = function(data) p.input_side = util.int8(data) < 0 and -1 or 1 end, -- コマンド入力でのキャラ向きチェック用 00:左側 80:右側
			[0x88] = function(data) p.in_bs = data ~= 0 end,                         -- BS動作中
			[0x89] = function(data) p.sway_status, p.in_sway_line = data, data ~= 0x00 end, -- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
			[0x8B] = function(data, ret)
				-- 残体力がゼロだと次の削りガードが失敗するため常に1残すようにもする
				p.life, p.update_dmg, ret.value = data, now(), math.max(data, 1) -- 体力
			end,
			[0x8E] = function(data)
				local changed = p.state ~= data
				p.change_state = changed and now() or p.change_state -- 状態の変更フレームを記録
				p.on_block = data == 2 and now() or p.on_block -- ガードへの遷移フレームを記録
				p.on_hit = data == 1 or data == 3 and now() or p.on_hit -- ヒットへの遷移フレームを記録
				p.random_boolean = p.state == data and p.random_boolean or (math.random(255) % 2 == 0)
				p.state, p.update_state = data, now()       -- 今の状態と状態更新フレームを記録
				if data == 2 then
					update_tmp_combo(changed and 1 or 2)    -- 連続ガード用のコンボ状態リセット
					p.last_combo = changed and 1 or p.last_combo + 1
				end
			end,
			[{ addr = 0x8F, filter = { 0x5B134, 0x5B154 } }] = function(data)
				p.last_damage, p.last_damage_scaled = data, data -- 補正前攻撃力
			end,
			[0x90] = function(data) p.throw_timer = data end, -- 投げ可能かどうかのフレーム経過
			[{ addr = 0xA9, filter = { 0x23284, 0x232B0 } }] = function(data)
				p.on_vulnerable = now()              -- 判定無敵ではない, 判定無敵ではない+無敵タイマーONではない
			end,
			-- [0x92] = function(data) end, -- 弾ヒット?
			[0xA2] = function(data) p.shooting = data == 0 end, -- 弾発射時に値が入る ガード判断用
			[0xA3] = function(data)                    -- A3:成立した必殺技コマンドID A4:必殺技コマンドの持続残F
				if data == 0 then
					p.on_sp_clear = now()
				elseif data ~= 0 then
					p.on_sp_established, p.last_sp = now(), data
					local sp2, proc_base           = (p.last_sp - 1) * 2, p.char_data.proc_base
					p.bs_pow, p.bs_invincible      = mem.r8(proc_base.bs_pow + sp2) & 0x7F, mem.r8(proc_base.bs_invincible + sp2)
					p.bs_invincible                = p.bs_invincible == 0xFF and 0 or p.bs_invincible
					p.sp_invincible                = mem.r8(proc_base.sp_invincible + p.last_sp - 1)
				end
			end,
			[0xA5] = function(data) p.additional = data end, -- 追加入力成立時のデータ
			[0xAF] = function(data) p.cancelable_data = data end, -- キャンセル可否 00:不可 C0:可 D0:可 正確ではないかも
			[0xB6] = function(data)
				-- 攻撃中のみ変化、判定チェック用2 0のときは何もしていない、 詠酒の間合いチェック用など
				p.attackbit = util.hex_set(p.attackbit, frame_attack_types.harmless, data ~= 0)
				if data == 0 then return end
				if p.attack ~= data then
					p.cancelable      = false
					p.cancelable_data = 0
					p.repeatable      = false
					p.forced_down     = false
					p.hitstop         = 0
					p.blockstop       = 0
					p.pure_dmg        = 0
					p.pure_st         = 0
					p.pure_st_tm      = 0
					p.max_hit_dn      = 0
					p.esaka_range     = 0
					p.pow_up_hit      = 0
					p.pow_up_gd       = 0
					p.effect          = 0
					p.chip_dmg_type   = chip_dmg_types.zero
					p.chip_dmg        = 0
					p.hitstun         = 0
					p.blockstun       = 0
					p.pow_revenge     = 0
					p.pow_absorb      = 0
					p.pow_up_hit      = 0
					p.pow_revenge     = 0
					p.pow_up          = 0x58 > data and 0 or p.pow_up
					p.pow_up_direct   = 0x58 > data and 0 or p.pow_up_direct
				end
				-- util.printf("attack %x", data)
				p.attack         = data
				p.attackbit      = util.hex_reset(p.attackbit, 0xFFFFFFFF << frame_attack_types.attack, p.attack << frame_attack_types.attack)
				local base_addr  = p.char_data.proc_base
				-- キャンセル可否家庭用2AD90からの処理の断片
				local cancelable = ((data < 0x70) and mem.r8(data + base_addr.cancelable) or p.cancelable_data) & 0xD0 == 0xD0
				p.cancelable     = cancelable
				p.repeatable     = cancelable and p.repeatable
				p.forced_down    = 2 <= mem.r8(data + base_addr.forced_down) -- テクニカルライズ可否 家庭用 05A9BA からの処理
				-- ヒットストップ 家庭用 攻撃側:05AE2A やられ側:05AE50 からの処理 OK
				p.hitstop        = math.max(2, (0x7F & mem.r8(data + base_addr.hitstop)) - 1)
				p.blockstop      = math.max(2, p.hitstop - 1) -- ガード時の補正
				p.pure_dmg       = mem.r8(data + base_addr.damege) -- 補正前ダメージ  家庭用 05B118 からの処理
				p.pure_st        = mem.r8(data + base_addr.stun) -- 気絶値 05C1CA からの処理
				p.pure_st_tm     = mem.r8(data + base_addr.stun_timer) -- 気絶タイマー 05C1CA からの処理
				p.max_hit_dn     = data > 0 and mem.r8(data + base_addr.max_hit) or 0
				if 0x58 > data then
					-- 詠酒距離 家庭用 0236F0 からの処理
					local esaka = mem.r16(base_addr.esaka + ((data + data) & 0xFFFF))
					p.esaka, p.esaka_type = esaka & 0x1FFF, esaka_type_names[esaka & 0xE000] or ""
					if 0x27 <= data then                                   -- 家庭用 05B37E からの処理
						p.pow_up_hit = mem.r8((0xFF & (data - 0x27)) + base_addr.pow_up_ext) -- CA技、特殊技
					else
						p.pow_up_hit = mem.r8(base_addr.pow_up + data)     -- ビリー、チョンシュ、その他の通常技
					end
					p.pow_up_gd = 0xFF & (p.pow_up_hit >> 1)               -- ガード時増加量 d0の右1ビットシフト=1/2
				end
				apply_attack_infos(p, data, base_addr)
				if p.char_data.pow and p.char_data.pow[data] then
					p.pow_revenge = p.char_data.pow[data].pow_revenge or p.pow_revenge
					p.pow_absorb = p.char_data.pow[data].pow_absorb or p.pow_absorb
					p.pow_up_hit = p.char_data.pow[data].pow_up_hit or p.pow_up_hit
				end
				-- util.printf("%x dmg %x %s %s %s %s %s", p.addr.base, data, p.pure_dmg, p.pure_st, p.pure_st_tm, p.pow_up_hit, p.pow_up_gd)
			end,
			-- [0xB7] = function(data) p.corner = data end, -- 画面端状態 0:端以外 1:画面端 3:端押し付け
			[0xB8] = function(data)
				p.spid, p.sp_flag = data, mem.r32(0x3AAAC + (data << 2)) -- 技コマンド成立時の技のID, 0xC8へ設定するデータ(03AA8Aからの処理)
			end,
			[{ addr = 0xB9, filter = { 0x58930, 0x58948 } }] = function(data)
				if data == 0 and mem.pc() == 0x58930 then p.on_bs_clear = now() end            -- BSフラグのクリア
				if data ~= 0 and mem.pc() == 0x58948 then p.on_bs_established, p.last_bs = now(), data end -- BSフラグ設定
			end,
			[0xD0] = function(data) p.flag_d0 = data end,                                      -- フラグ群
			[0xE4] = function(data) p.hurt_state = data end,                                   -- やられ状態
			[0xE8] = function(data, ret)
				if data < 0x10 and p.dummy_gd == dummy_gd_type.force then ret.value = 0x10 end -- 0x10以上でガード
			end,
			[0xEC] = function(data) p.push_invincible = data end,                              -- 押し合い判定の透過状態
			[0xEE] = function(data)
				p.in_hitstop_value = data
				--p.in_hitstop = data ~= 0 and (0x7F & data) == data
				p.in_hitstun = util.testbit(data, 0x80)
			end,
			[0xF6] = function(data) p.invincible = data end, -- 打撃と投げの無敵の残フレーム数
			-- [0xF7] = function(data) end -- 技の内部の進行度
			[{ addr = 0xFB, filter = { 0x49418, 0x49428 } }] = function(data)
				p.kaiserwave = p.kaiserwave or {} -- カイザーウェイブのレベルアップ
				local pc = mem.pc()
				if (p.kaiserwave[pc] == nil) or p.kaiserwave[pc] + 1 < global.frame_number then
					p.update_act = now()
				end
				p.kaiserwave[pc] = now()
			end,
			[p1 and 0x10B4E1 or 0x10B4E0] = update_tmp_combo,
			[p1 and 0x10B4E5 or 0x10B4E4] = function(data) p.last_combo = data end, -- 最近のコンボ数
			[p1 and 0x10B4E7 or 0x10B4E8] = function(data) p.konck_back4 = data end, -- 1ならやられ中
			--[p1 and 0x10B4F0 or 0x10B4EF] = function(data) p.max_combo = data end, -- 最大コンボ数
			[p1 and 0x10B84E or 0x10B856] = function(data) p.stun_limit = data end, -- 最大気絶値
			[p1 and 0x10B850 or 0x10B858] = function(data) p.stun = data end, -- 現在気絶値
			[p1 and 0x1041B0 or 0x1041B4] = function(data, ret)
				if p.bs_hook and p.bs_hook.cmd_type then
					-- util.printf("bs_hook cmd %x", p.bs_hook.cmd_type)
					-- フックの処理量軽減のためまとめてキー入力を記録する
					mem.w8(p1 and 0x1041AE or 0x1041B2, p.bs_hook.cmd_type) -- 押しっぱずっと有効
					mem.w8(p1 and 0x1041AF or 0x1041B3, p.bs_hook.cmd_type) -- 押しっぱ有効が5Fのみ
					ret.value = p.bs_hook.cmd_type           -- 押しっぱ有効が1Fのみ
				end
			end,
		}
		local special_throws = {
			[0x39E56] = function() return mem.rg("D0", 0xFF) end, -- 汎用
			[0x45ADC] = function() return 0x14 end,      -- ブレイクスパイラルBR
		}
		local special_throw_addrs = util.get_hash_key(special_throws)
		local add_throw_box = function(p, box) p.throw_boxies[box.id] = box end
		local extra_throw_callback = function(data)
			if in_match then
				local pc = mem.pc()
				local id = special_throws[pc]
				if id then add_throw_box(p.op, get_special_throw_box(p.op, id())) end -- 必殺投げ
				if pc == 0x06042A then add_throw_box(p, get_air_throw_box(p)) end -- 空中投げ
			end
		end
		local drill_counts = { 0x07, 0x09, 0x0B, 0x0C, 0x3C, } -- { 0x00, 0x01, 0x02, 0x03, 0x04, }
		p.rp8 = {
			[{ addr = 0x12, filter = { 0x3DCF8, 0x49B2C } }] = function(data, ret)
				local check_count = 0
				if p.char == 0x5 then check_count = global.auto_input.rave == 10 and 9 or (global.auto_input.rave - 1) end
				if p.char == 0x14 then check_count = global.auto_input.desire == 11 and 9 or (global.auto_input.desire - 1) end
				if mem.rg("D1", 0xFF) < check_count then ret.value = 0x3 end -- 自動デッドリー、自動アンリミ1
			end,
			[{ addr = 0x28, filter = util.table_add_all(special_throw_addrs, { 0x6042A }) }] = extra_throw_callback,
			[{ addr = 0x8A, filter = { 0x5A9A2, 0x5AB34 } }] = function(data)
				local pc = mem.pc()
				if p.dummy_wakeup == wakeup_type.sway and pc == 0x5A9A2 then
					mem.w8(mem.rg("A0", 0xFFFFFF) + (data & 0x1) * 2, 2) -- 起き上がり動作の入力を更新
				elseif p.dummy_wakeup == wakeup_type.tech and pc == 0x5AB34 then
					mem.w8(mem.rg("A0", 0xFFFFFF) + (data & 0x1) * 2, 1) -- 起き上がり動作の入力を更新
				end
			end,
			[{ addr = 0x8E, filter = 0x39F8A }] = function(data)
				if in_match then add_throw_box(p.op, get_normal_throw_box(p.op)) end -- 通常投げ
			end,
			[{ addr = 0x8F, filter = 0x5B41E }] = function(data, ret)
				-- 残体力を攻撃力が上回ると気絶値が加算がされずにフックが失敗するので、残体力より大きい値を返さないようにもする
				p.last_damage_scaled, ret.value = data, math.min(p.life, data)
				p.combo_damage = (p.combo_damage or 0) + p.last_damage_scaled -- 確定した補正後の攻撃力をコンボダメージに加算
				p.max_combo_damage = math.max(p.max_combo_damage or 0, p.combo_damage)
			end,
			[{ addr = 0x90, filter = 0x39FB0 }] = function(data)
				local timer, threshold = data, mem.rg("D7", 0xFF) -- 投げ成否判断時の相手のタイマーと投げしきい値
				p.op.throwing = { timer = timer, threshold = threshold, established = threshold < timer, }
			end,
			[{ addr = 0x94, filter = 0x42BFE }] = function(data, ret)
				if global.auto_input.drill > 0 then ret.value = drill_counts[global.auto_input.drill] end -- 自動ドリル
			end,
			[{ addr = 0xA5, filter = { 0x3DBE6, 0x49988, 0x42C26 } }] = function(data, ret)
				if p.char == 0x5 and global.auto_input.rave == 10 then ret.value = 0xFF end -- 自動デッドリー
				if p.char == 0x14 and global.auto_input.desire == 11 then ret.value = 0xFE end -- 自動アンリミ2
				if p.char == 0xB and global.auto_input.drill == 5 then ret.value = 0xFE end -- 自動ドリルLv.5
			end,
			[{ addr = 0xB9, filter = { 0x396B4, 0x39756 } }] = function(data) p.on_bs_check = now() end, -- BSの技IDチェック
			[{ addr = 0xBF, filter = { 0x3BEF6, 0x3BF24, 0x5B346, 0x5B368 } }] = function(data)
				if data ~= 0 then -- 増加量を確認するためなのでBSチェックは省く
					local pc, pow_up = mem.pc(), 0
					if pc == 0x3BEF6 then
						local a3 = mem.r8(base + 0xA3) -- 必殺技発生時のパワー増加 家庭用 03C140 からの処理
						p.pow_up = a3 ~= 0 and mem.r8(mem.r32(0x8C1EC + p.char4) + a3 - 1) or 0
						pow_up   = p.pow_up
					elseif pc == 0x3BF24 then
						p.pow_up_direct = mem.rg("D0", 0xFF) -- パワー直接増加 家庭用 03BF24 からの処理
						pow_up = p.pow_up_direct
					elseif pc == 0x5B346 then
						pow_up = 1 -- 被ガード時のパワー増加
					elseif pc == 0x5B368 then
						pow_up = (p.flag_cc & 0xE0 == 0) and p.pow_up_hit or p.pow_up_gd or 0
					end
					p.last_pow_up, p.op.combo_pow = pow_up, (p.op.combo_pow or 0) + pow_up
					--util.printf("%x %x data=%s last_pow_up=%s combo_pow=%s", base, pc, data, p.last_pow_up, p.op.combo_pow)
				end
			end,
			[{ addr = 0xCD, filter = special_throw_addrs }] = extra_throw_callback,
			[{ addr = 0xD6, filter = 0x5A7B4 }] = function(data, ret)
				if p.dummy_wakeup == wakeup_type.atk and p.char_data.wakeup then ret.value = 0x23 end -- 成立コマンド値を返す
			end,
		}
		p.wp16 = {
			[0x34] = function(data) p.thrust = data end,
			[0x36] = function(data) p.thrust_frc = util.int16tofloat(data) end,
			[0x92] = function(data) p.anyhit_id = data end,
			[0x9E] = function(data) p.ophit_base = data end, -- ヒットさせた相手側のベースアドレス
			[0xDA] = function(data) p.inertia = data end,
			[0xDC] = function(data) p.inertia_frc = util.int16tofloat(data) end,
			[0xE6] = function(data) p.on_hit_any = now() + 1 end, -- 0xE6か0xE7 打撃か当身でフラグが立つ
			[p1 and 0x10B854 or 0x10B85C] = function(data) p.stun_timer = data end, -- 気絶値ゼロ化までの残フレーム数
		}
		local nohit = function(data, ret)
			if p.no_hit_limit > 0 and p.last_combo >= p.no_hit_limit then ret.value = 0x311C end --  0x0001311Cの後半を返す
		end
		p.rp16 = {
			[0x13124 + 0x2] = nohit, -- 0x13124の後半読み出しハック
			[0x13128 + 0x2] = nohit, -- 0x13128の後半読み出しハック 0x1311Cを返す
			[0x1312C + 0x2] = nohit, -- 0x1312Cの後半読み出しハック 0x1311Cを返す
			[0x13130 + 0x2] = nohit, -- 0x13130の後半読み出しハック 0x1311Cを返す
		}
		p.wp32 = {
			[{ addr = 0x00, filter = { 0x58268, 0x582AA } }] = function(data, ret)
				if global.damaged_move > 1 then ret.value = hit_effect_moves[global.damaged_move] end
			end,
			-- [0x0C] = function(data) p.reserve_proc = data end,               -- 予約中の処理アドレス
			[0xC0] = function(data) p.flag_c0 = data end,                    -- フラグ群
			[0xC4] = function(data) p.flag_c4 = data end,                    -- フラグ群
			[0xC8] = function(data) p.flag_c8 = data end,                    -- フラグ群
			[0xCC] = function(data) p.flag_cc = data end,                    -- フラグ群
			[p1 and 0x0394C4 or 0x0394C8] = function(data) p.input_offset = data end, -- コマンド入力状態のオフセットアドレス
		}
		all_objects[p.addr.base] = p
	end
	players[1].op, players[2].op = players[2], players[1]
	for _, parent in ipairs(players) do -- 飛び道具領域の作成
		for fb_base = 1, 3 do
			local base = fb_base * 0x200 + parent.addr.base
			local p = {
				is_fireball = true,
				parent      = parent,
				addr        = {
					base = base, -- キャラ状態とかのベースのアドレス
				}
			}
			p.wp8 = {
				[0xB5] = function(data) p.fireball_rank = data end,
				[0xE7] = function(data)
					p.attackbit = util.hex_set(p.attackbit, frame_attack_types.fullhit, data == 0)
				end,
				[0x8A] = function(data) p.grabbable1 = 0x2 >= data end,
				[0xA3] = function(data) p.shooting = data == 0 end, -- 攻撃中に値が入る ガード判断用
			}
			p.wp16 = {
				[0x64] = function(data) p.actb = data end,
				[0xBE] = function(data)
					if data == 0 or p.proc_active ~= true then
						return
					end
					if p.attack ~= data then
						p.forced_down   = false
						p.hitstop       = 0
						p.blockstop     = 0
						p.pure_dmg      = 0
						p.pure_st       = 0
						p.pure_st_tm    = 0
						p.max_hit_dn    = 0
						p.effect        = 0
						p.chip_dmg_type = chip_dmg_types.zero
						p.chip_dmg      = 0
						p.hitstun       = 0
						p.blockstun     = 0
					end
					p.addr.proc_base = p.addr.proc_base or { -- TODO 初期化処理を移動させたい
						forced_down = 0x8E2C0,
						hitstop     = fix_addr(0x884F2),
						damege      = fix_addr(0x88472),
						stun        = fix_addr(0x886F2),
						stun_timer  = fix_addr(0x88772),
						max_hit     = fix_addr(0x885F2),
						baigaeshi   = 0x8E940,
						effect      = -0x20 + fix_addr(0x95BEC),
						chip_damage = fix_addr(0x95CCC),
						hitstun1    = fix_addr(0x95CCC),
						hitstun2    = 0x16 + 0x2 + fix_addr(0x5AF7C),
						blockstun   = 0x1A + 0x2 + fix_addr(0x5AF88),
					}
					local base_addr  = p.addr.proc_base
					p.attack         = data
					p.forced_down    = 2 <= mem.r8(data + base_addr.forced_down)       -- テクニカルライズ可否 家庭用 05A9D6 からの処理
					p.hitstop        = math.max(2, mem.r8(data + base_addr.hitstop) - 1) -- ヒットストップ 家庭用 弾やられ側:05AE50 からの処理 OK
					p.blockstop      = math.max(2, p.hitstop - 1)                      -- ガード時の補正
					p.pure_dmg       = mem.r8(data + base_addr.damege)                 -- 補正前ダメージ 家庭用 05B146 からの処理
					p.pure_st        = mem.r8(data + base_addr.stun)                   -- 気絶値 家庭用 05C1B0 からの処理
					p.pure_st_tm     = mem.r8(data + base_addr.stun_timer)             -- 気絶タイマー 家庭用 05C1B0 からの処理
					p.max_hit_dn     = mem.r8(data + base_addr.max_hit)                -- 最大ヒット数 家庭用 061356 からの処理 OK
					p.grabbable2     = mem.r8((0xFFFF & (data + data)) + base_addr.baigaeshi) == 0x01 -- 倍返し可否
					apply_attack_infos(p, data, base_addr)
					p.attackbit = util.hex_reset(p.attackbit, 0xFF << frame_attack_types.fb_effect, p.effect << frame_attack_types.fb_effect)
					-- util.printf("%x %s %s  hitstun %s %s", data, p.hitstop, p.blockstop, p.hitstun, p.blockstun)
				end,
			}
			p.wp32 = {
				[0x00] = function(data)
					p.asm         = mem.r16(data)
					p.proc_active = p.asm ~= 0x4E75 and p.asm ~= 0x197C
					if not p.proc_active then p.boxies, p.grabbable, p.attack_id, p.attackbit = {}, 0, 0, 0 end
				end,
			}
			parent.fireballs[base], all_objects[base], all_fireballs[base] = p, p, p
		end
	end
	local change_player_input = function()
		if in_player_select ~= true then return end
		local a4, sel              = mem.rg("A4", 0xFFFFFF), mem.r8(0x100026)
		local p_num, op_num, p_sel = mem.r8(a4 + 0x12), 0, {}
		op_num, p_sel[p_num]       = 3 - p_num, a4 + 0x13
		if sel == op_num and p_sel[op_num] then mem.w8(p_sel[p_num], op_num) end -- プレイヤー選択時に1P2P操作を入れ替え
	end
	local common_p = {                                                -- プレイヤー別ではない共通のフック
		wp8 = {
			[{ addr = 0x107EC6, filter = 0x11DE8 }] = change_player_input,
			[0x107C22] = function(data, ret)
				if global.disp_meters ~= true and data == 0x38 then -- ゲージのFIX非表示
					ret.value = 0x0
					mem.w8(0x10E024, 0x3)                   -- 3にしないと0x107C2Aのカウントが進まなくなる
				end
				if global.disp_bg ~= true and mem.r8(0x107C22) > 0 then -- 背景消し
					mem.w8(0x107762, 0x00)
					mem.w16(0x401FFE, 0x5ABB)               -- 背景色
				end
			end,
			[0x10B862] = function(data) mem._0x10B862 = data end, -- 押し合い判定で使用
		},
		wp16 = {
			[mem.stage_base_addr + screen.offset_x] = function(data) screen.left = data + (320 - scr.width * scr.xscale) / 2 end,
			[mem.stage_base_addr + screen.offset_y] = function(data) screen.top = data + scr.height * scr.yscale end,
			[{ addr = 0x107BB8, filter = 0xF368 }] = function(data, ret)
				if global.next_stg3 == 2 then ret.value = 2 end -- 双角ステージの雨バリエーション指定用
			end,
			[0x107C2A] = function(data, ret)
				global.lag_frame, global.last_frame = global.last_frame == data, data
				if data >= 0x176E then ret.value = 0 end -- 0x176Eで止まるのでリセットしてループさせる
			end,
		},
		wp32 = {
			[0x100F56] = function(data) global.sp_skip_frame = data ~= 0 end,
		},
		rp8 = {
			[{ addr = 0x107EC6, filter = 0x11DC4 }] = function(data)
				if in_player_select ~= true then return end
				if data == mem.rg("D0", 0xFF) then change_player_input(data) end
			end,
			[{ addr = 0x107765, filter = { 0x40EE, 004114, 0x413A } }] = function(_, ret)
				local pc = mem.pc()
				local a = mem.rg("A4", 0xFFFFFF)
				local b = mem.r32(a + 0x8A)
				local c = mem.r16(a + 0xA) + 0x100000
				local d = mem.r16(c + 0xA) + 0x100000
				local e = (mem.r32(a + 0x18) << 32) + mem.r32(a + 0x1C)
				local p_bases = { a, b, c, d, } -- ベースアドレス候補
				if data.p_chan[e] then ret.value = 0 end
				for i, addr, p in find(p_bases, get_object_by_addr) do
					--util.printf("%s %s %6x", global.frame_number, i, addr)
					if i == 1 and p.hide_char then
						ret.value = 4
					elseif i == 2 and p.hide_phantasm then
						ret.value = 4
					elseif i >= 3 and p.hide_effect then
						ret.value = 4
					end
					return
				end
				if global.hide_effect then
					ret.value = 4
					return
				end
				--util.printf("%6x %8x %8x %8x | %8x %16x %s", a, b, c, d, pc, e, data.get_obj_name(e))
			end,
			[{ addr = 0x107C1F, filter = 0x39456 }] = function(data)
				local p = get_object_by_reg("A4", {})
				if p.bs_hook then
					if p.bs_hook.ver then
						-- util.printf("bs_hook1 %x %x", p.bs_hook.id, p.bs_hook.ver)
						mem.w8(p.addr.base + 0xA3, p.bs_hook.id)
						mem.w16(p.addr.base + 0xA4, p.bs_hook.ver)
					else
						-- util.printf("bs_hook2 %x %x", p.bs_hook.id, p.bs_hook.f)
						mem.w8(p.addr.base + 0xD6, p.bs_hook.id)
						mem.w8(p.addr.base + 0xD7, p.bs_hook.f)
					end
				end
			end,
		},
		rp16 = {
			[{ addr = 0x107BB8, filter = {
				0xF6AC,                                                       -- BGMロード鳴らしたいので  --[[ 0x1589Eと0x158BCは雨発動用にそのままとする ]]
				0x17694,                                                      -- 必要な事前処理ぽいので
				0x1E39A,                                                      -- FIXの表示をしたいので
				0x22AD8,                                                      -- データロードぽいので
				0x22D32,                                                      -- 必要な事前処理ぽいので
			} }] = function(data, ret) ret.value = 1 end,                     -- 双角ステージの雨バリエーション時でも1ラウンド相当の前処理を行う
			[{ addr = 0x107BB0, filter = { 0x1728E, 0x172DE } }] = function(data, ret) -- 影消し=2, 双角ステージの反射→影化=0
				if global.hide_shadow ~= 2 then ret.value = (global.hide_shadow == 1) and 2 or 0 end
			end,
			[mem.stage_base_addr + 0x46] = function(data, ret) if global.fix_scr_top > 1 then ret.value = data + global.fix_scr_top - 20 end end,
			[mem.stage_base_addr + 0xA4] = function(data, ret) if global.fix_scr_top > 1 then ret.value = data + global.fix_scr_top - 20 end end,
		},
		rp32 = {
			[{ addr = 0x5B1DE, filter = 0x5B1B6 }] = function(data) get_object_by_reg("A4", {}).last_damage_scaling1 = 1 end,
			[{ addr = 0x5B1E2, filter = 0x5B1B6 }] = function(data) get_object_by_reg("A4", {}).last_damage_scaling1 = 7 / 8 end,
			[{ addr = 0x5B1E6, filter = 0x5B1B6 }] = function(data) get_object_by_reg("A4", {}).last_damage_scaling1 = 3 / 4 end,
			[{ addr = 0x5B1EA, filter = 0x5B1B6 }] = function(data) get_object_by_reg("A4", {}).last_damage_scaling1 = 3 / 4 end,
			[0x5B1EE] = function(data) get_object_by_reg("A4", {}).last_damage_scaling2 = 1 end,
			[0x5B1F2] = function(data) get_object_by_reg("A4", {}).last_damage_scaling2 = 1 end,
			[0x5B1F6] = function(data) get_object_by_reg("A4", {}).last_damage_scaling2 = 7 / 8 end,
			[0x5B1FA] = function(data) get_object_by_reg("A4", {}).last_damage_scaling2 = 3 / 4 end,
		}
	}
	table.insert(all_wps, common_p)
	for base, p in pairs(all_objects) do
		-- 判定表示前の座標がらみの関数
		p.x, p.y, p.flip_x = 0, 0, 0
		p.calc_range_x = function(range_x) return p.x + range_x * p.flip_x end -- 自身の範囲の座標計算
		-- 自身が指定の範囲内かどうかの関数
		p.within = function(x1, x2) return (x1 <= p.op.x and p.op.x <= x2) or (x1 >= p.op.x and p.op.x >= x2) end

		p.wp8 = util.hash_add_all(p.wp8, {
			[0x10] = function(data)
				p.char, p.char4, p.char8 = data, (data << 2), (data << 3)
				p.char_data = p.is_fireball and chars[#chars] or chars[data]      -- 弾はダミーを設定する
			end,
			[0x58] = function(data) p.internal_side = util.int8(data) < 0 and -1 or 1 end, -- 向き 00:左側 80:右側
			[0x66] = function(data)
				p.act_count = data                                                -- 現在の行動のカウンタ
				if p.is_fireball ~= true then
					local hits, shifts = p.max_hit_dn or 0, frame_attack_types.act_count
					if hits > 1 or hits == 0 or (p.char == 0x4 and p.attack == 0x16) then
						-- 連続ヒットできるものはカウントで区別できるようにする
						p.attackbit = util.hex_reset(p.attackbit, 0xFF << shifts, p.act_count << shifts)
					elseif util.testbit(p.flag_cc, state_flag_cc.grabbing) and p.op.last_damage_scaled ~= 0xFF then
						p.attackbit = util.hex_reset(p.attackbit, 0xFF << shifts, p.op.last_damage_scaled << shifts)
					end
				end
			end,
			[0x67] = function(data) p.act_boxtype = 0xFFFF & (data & 0xC0 * 4) end, -- 現在の行動の判定種類
			[0x6A] = function(data)
				p.repeatable = (data & 0x4) == 0x4                         -- 連打キャンセル判定
				p.flip_x1 = ((data & 0x80) == 0) and 0 or 1                -- 判定の反転
				local clear = (data & 0xFB) ~= 0
				if mem.pc() == fix_addr(0x011DFE) then
					p.attackbit = util.hex_set(p.attackbit, frame_attack_types.fake, clear) -- 判定無効化
				else
					p.attackbit = util.hex_set(p.attackbit, frame_attack_types.obsolute, clear) -- 判定有効化
				end
			end,
			[0x6F] = function(data) p.act_frame = data end, -- 動作パターンの残フレーム
			[0x71] = function(data) p.flip_x2 = (data & 1) end, -- 判定の反転
			[0x73] = function(data) p.box_scale = data + 1 end, -- 判定の拡大率
			[0x7A] = function(data)                    -- 攻撃判定とやられ判定
				--util.printf("box %x %x %x", p.addr.base, mem.pc(), data)
				p.boxies, p.grabbable = {}, 0
				if data > 0 then
					p.attackbit = util.hex_reset(p.attackbit, 0x1F, p.attackbit & frame_attack_types.fake)
					p.attackbit = util.hex_set(p.attackbit, p.is_fireball and frame_attack_types.fb or 0)
					local a2base = mem.r32(base + 0x7A)
					for a2 = a2base, a2base + (data - 1) * 5, 5 do -- 家庭用 004A9E からの処理
						local id = mem.r8(a2)
						local top, bottom = sort_ba(mem.r8i(a2 + 0x1), mem.r8i(a2 + 0x2))
						local left, right = sort_ba(mem.r8i(a2 + 0x3), mem.r8i(a2 + 0x4))
						local type = main_box_types[id] or (id < 0x20) and box_types.unknown or box_types.attack
						p.attack_id = type == box_types.attack and id or p.attack_id
						local reach, possibles
						if type == box_types.attack then
							possibles = get_hitbox_possibles(p.attack_id)
							p.attackbit = util.hex_set(p.attackbit, frame_attack_types.attacking)
							p.attackbit = util.hex_set(p.attackbit, possibles.juggle and frame_attack_types.juggle or 0)
							local possible = util.hex_set(util.hex_set(possibles.normal, possibles.sway_standing), possibles.sway_crouching)
							local blockable = act_types.unblockable -- ガード属性 -- 不能
							if possibles.crouching_block and possibles.standing_block then
								blockable = act_types.attack -- 上段
							elseif possibles.crouching_block then
								blockable = act_types.low_attack -- 下段
							elseif possibles.standing_block then
								blockable = act_types.overhead -- 中段
							end
							reach = { blockable = blockable, possible = possible, }
							for _, t in ipairs(hitbox_grab_types) do p.grabbable = p.grabbable | (possibles[t.name] and t.value or 0) end
						end
						table.insert(p.boxies, {
							no = #p.boxies + 1,
							id = id,
							type = type,
							left = left,
							right = right,
							top = top,
							bottom = bottom,
							sway_type = sway_box_types[id] or type,
							possibles = possibles or {},
							reach = reach or {}, -- 判定のリーチとその属性
						})
						-- util.printf("p=%x %x %x %x %s addr=%x id=%02x l=%s r=%s t=%s b=%s", p.addr.base, data, base, p.box_addr, 0, a2, id, x1, x2, y1, y2)
					end
				end
			end,
			[0x8D] = function(data)
				p.hitstop_remain, p.in_hitstop = data, (data > 0 or (p.hitstop_remain and p.hitstop_remain > 0)) and now() or p.in_hitstop -- 0になるタイミングも含める
			end,
			[0xAA] = function(data)
				p.attackbit = util.hex_set(p.attackbit, frame_attack_types.fullhit, data == 0) -- 全段攻撃ヒット/ガード
			end,
			[0xAB] = function(data) p.max_hit_nm = data end,                      -- 同一技行動での最大ヒット数 分子
			[0xB1] = function(data) p.hurt_invincible = data > 0 end,             -- やられ判定無視の全身無敵
			[0xE9] = function(data) p.dmg_id = data end,                          -- 最後にヒット/ガードした技ID
			[0xEB] = function(data) p.hurt_attack = data end,                      -- やられ中のみ変化
		})
		p.wp16 = util.hash_add_all(p.wp16, {
			[0x20] = function(data) p.pos, p.max_pos, p.min_pos = data, math.max(p.max_pos or 0, data), math.min(p.min_pos or 1000, data) end,
			[0x22] = function(data) p.pos_frc = util.int16tofloat(data) end, -- X座標(小数部)
			[0x24] = function(data)
				p.pos_z, p.on_sway_line,p.on_main_line = data, 40 == data and now() or p.on_sway_line, 24 == data and now() or p.on_main_line -- Z座標
			end,
			[0x28] = function(data) p.pos_y = util.int16(data) end,                                       -- Y座標
			[0x2A] = function(data) p.pos_frc_y = util.int16tofloat(data) end,                            -- Y座標(小数部)
			[{ addr = 0x5E, filter = 0x011E10 }] = function(data) p.box_addr = mem.rg("A0", 0xFFFFFFFF) - 0x2 end, -- 判定のアドレス
			[0x60] = function(data)
				p.act, p.update_act = data, now()                                       -- 行動ID デバッグディップステータス表示のPと同じ
				p.attackbit = util.hex_reset(p.attackbit, 0xFFFFFF << frame_attack_types.act, p.act << frame_attack_types.act)
				if p.parent then
					if p.parent.char_data then p.act_data = p.parent.char_data.fireballs[data] end
				elseif p.char_data then
					p.act_data = p.char_data.acts[data]
				end
			end,
			[0x62] = function(data) p.acta = data end, -- 行動ID デバッグディップステータス表示のAと同じ
		})
		table.insert(all_wps, p)
	end

	-- 場面変更
	local apply_1p2p_active = function()
		if in_match then
			mem.wd8(0x100024, 0x03)
			mem.wd8(0x100027, 0x03)
		end
	end

	local goto_player_select = function()
		-- プログラム改変
		mem.wd32(0x10668, 0xC6CFFEF) -- 元の乱入処理
		mem.wd32(0x1066C, 0x226704) -- 元の乱入処理
		mem.wd8(0x1066E, 0x60)  -- 乱入時にTHE CHALLENGER表示をさせない

		mem.w8(0x1041D3, 1)     -- 乱入フラグON
		mem.wd8(0x107BB5, 0x01)
		mem.w32(0x107BA6, 0x00010001) -- CPU戦の進行数をリセット
		mem.w32(0x100024, 0x00000000)
		mem.w16(0x10FDB6, 0x0101)
	end

	local restart_fight = function(param)
		param              = param or {}
		global.next_stg3   = param.next_stage.stg3 or mem.r16(0x107BB8)
		local p1, p2       = param.next_p1 or 1, param.next_p2 or 21
		local p1col, p2col = param.next_p1col or 0x00, param.next_p2col or 0x01

		-- プログラム改変
		mem.wd32(0x10668, 0x4EF90000) -- FIGHT表示から対戦開始(F05E)へ飛ばす
		mem.wd32(0x1066C, 0xF33A4E71) -- FIGHT表示から対戦開始

		mem.w8(0x1041D3, 1)     -- 乱入フラグで割り込み
		mem.w8(0x107C1F, 0)     -- キャラデータの読み込み無視フラグをOFF
		mem.w32(0x107BA6, 0x00010001) -- CPU戦の進行数をリセット
		mem.wd8(0x100024, 0x03)
		mem.wd8(0x100027, 0x03)
		mem.w16(0x10FDB6, 0x0101)

		mem.w16(0x1041D6, 0x0003) -- 対戦モード3
		mem.w8(0x107BB1, param.next_stage.stg1 or mem.r8(0x107BB1))
		mem.w8(0x107BB7, param.next_stage.stg2 or mem.r8(0x107BB7))
		mem.w16(0x107BB8, global.next_stg3) -- ステージのバリエーション
		mem.w8(players[1].addr.char, p1)
		mem.w8(players[1].addr.color, p1col)
		mem.w8(players[2].addr.char, p2)
		if p1 == p2 then p2col = p1col == 0x00 and 0x01 or 0x00 end
		mem.w8(players[2].addr.color, p2col)
		mem.w16(0x10A8D4, param.next_bgm or 21) -- 対戦モード3 BGM

		-- メニュー用にキャラの番号だけ差し替える
		players[1].char, players[2].char = p1, p2
	end

	-- ブレイクポイント発動時のデバッグ画面表示と停止をさせない
	local auto_recovery_debug = function()
		if not global.mame_debug_wnd and debugger and debugger.execution_state ~= "run" then
			debugger.execution_state = "run"
		end
	end

	-- レコード＆リプレイ
	local recording = {
		state           = 0, -- 0=レコーディング待ち, 1=レコーディング, 2=リプレイ待ち 3=リプレイ開始
		cleanup         = false,
		player          = nil,
		temp_player     = nil,
		play_count      = 1,

		last_slot       = nil,
		active_slot     = nil,
		slot            = {}, -- スロット
		live_slots      = {}, -- ONにされたスロット

		fixpos          = nil,
		do_repeat       = false,
		repeat_interval = 0,
	}
	for i = 1, 8 do
		recording.slot[i] = {
			side  = 1, -- レコーディング対象のプレイヤー番号 1=1P, 2=2P
			store = {}, -- 入力保存先
			name  = "スロット" .. i,
		}
	end

	-- 調査用自動再生スロットの準備
	for i, preset_cmd in ipairs(data.research_cmd) do
		for _, joy in ipairs(preset_cmd) do table.insert(recording.slot[i].store, { joy = joy, pos = { 1, -1 } }) end
	end
	recording.player = 1
	recording.active_slot = recording.slot[1]
	recording.active_slot.side = 1

	-- メニュー用変数
	local rec_await_no_input
	local rec_await_1st_input
	local rec_await_play
	local rec_input
	local rec_play
	local rec_repeat_play
	local rec_play_interval
	local rec_fixpos
	local do_recover
	local menu_to_tra
	local menu_to_bar
	local menu_to_disp
	local menu_to_ex
	local menu_to_col
	local menu_to_auto

	-- 状態クリア
	local cls_ps = function()
		for _, p in ipairs(players) do
			local op = p.op
			p.input_states = {}
			p.char_data = chars[p.char]

			do_recover(p, op, true)

			p.combo_update = 0
			p.combo_damage = 0
			p.combo_start_stun = 0
			p.combo_start_stun_timer = 0
			p.combo_stun = 0
			p.combo_stun_timer = 0
			p.combo_pow = 0
			p.last_damage = 0
			p.last_damage_scaled = 0
			p.last_combo = 0
			p.last_stun = 0
			p.last_stun_timer = 0
			p.last_pow_up = 0
			p.max_combo_damage = 0
			p.max_combo = 0
			p.max_combo_stun = 0
			p.max_combo_stun_timer = 0
			p.max_combo_pow = 0
		end
	end

	local frame_to_time = function(frame_number)
		local min = math.floor(frame_number / 3600)
		local sec = math.floor((frame_number % 3600) / 60)
		local frame = math.floor((frame_number % 3600) % 60)
		return string.format("%02d:%02d:%02d", min, sec, frame)
	end
	-- リプレイ開始位置記憶
	rec_fixpos = function()
		local pos        = { players[1].input_side, players[2].input_side }
		local fixpos     = { mem.r16i(players[1].addr.pos), mem.r16i(players[2].addr.pos) }
		local fixsway    = { mem.r8(players[1].addr.sway_status), mem.r8(players[2].addr.sway_status) }
		local fixscr     = {
			x = mem.r16(mem.stage_base_addr + screen.offset_x),
			y = mem.r16(mem.stage_base_addr + screen.offset_y),
			z = mem.r16(mem.stage_base_addr + screen.offset_z),
		}
		recording.fixpos = { pos = pos, fixpos = fixpos, fixscr = fixscr, fixsway = fixsway, }
	end
	-- 初回入力まち
	-- 未入力状態を待ちける→入力開始まで待ち受ける
	rec_await_no_input = function(to_joy)
		local joy_val = get_joy()

		local no_input = true
		for k, f in pairs(joy_val) do
			if f > 0 then
				no_input = false
				break
			end
		end
		if no_input then
			-- 状態変更
			global.rec_main = rec_await_1st_input
			print(global.frame_number .. " rec_await_no_input -> rec_await_1st_input")
		end
	end
	rec_await_1st_input = function(to_joy)
		local joy_val = get_joy(recording.temp_player)

		local next_val = nil
		local pos = { players[1].input_side, players[2].input_side }
		for k, f in pairs(joy_val) do
			if k ~= joy_k[1].st and k ~= joy_k[2].st and f > 0 then
				if not next_val then
					next_val = new_next_joy()
					recording.player = recording.temp_player
					recording.active_slot.cleanup = false
					recording.active_slot.side = joy_pside[rev_joy[k]] -- レコーディング対象のプレイヤー番号 1=1P, 2=2P
					recording.active_slot.store = {}    -- 入力保存先
					table.insert(recording.active_slot.store, { joy = next_val, pos = pos })
					table.insert(recording.active_slot.store, { joy = new_next_joy(), pos = pos })

					-- 状態変更
					-- 初回のみ開始記憶
					if recording.fixpos == nil then rec_fixpos() end
					global.rec_main = rec_input
					print(global.frame_number .. " rec_await_1st_input -> rec_input")
				end
				-- レコード中は1Pと2P入力が入れ替わっているので反転させて記憶する
				next_val[rev_joy[k]] = f > 0
			end
		end
	end
	-- 入力中
	rec_input = function(to_joy)
		local joy_val = get_joy(recording.player)

		-- 入力保存
		local next_val = new_next_joy()
		local pos = { players[1].input_side, players[2].input_side }
		for k, f in pairs(joy_val) do
			if k ~= joy_k[1].st and k ~= joy_k[2].st and recording.active_slot.side == joy_pside[rev_joy[k]] then
				-- レコード中は1Pと2P入力が入れ替わっているので反転させて記憶する
				next_val[rev_joy[k]] = f > 0
			end
		end
		table.remove(recording.active_slot.store)
		table.insert(recording.active_slot.store, { joy = next_val, pos = pos })
		table.insert(recording.active_slot.store, { joy = new_next_joy(), pos = pos })
	end
	-- リプレイまち
	rec_await_play = function(to_joy)
		local force_start_play = global.rec_force_start_play
		global.rec_force_start_play = false -- 初期化
		local ec = scr:frame_number()
		local state_past = ec - global.input_accepted

		local tmp_slots = {}
		for j, slot in ipairs(recording.slot) do
			-- 冗長な未入力を省く
			if not slot.cleanup then
				for i = #slot.store, 1, -1 do
					local empty = true
					for k, v in pairs(slot.store[i].joy) do
						if v then
							empty = false
							break
						end
					end
					if empty then
						slot.store[i] = nil
					else
						break
					end
				end
				slot.cleanup = true
			end
			-- コマンド登録があってメニューONになっているスロットを一時保存
			if #slot.store > 0 and recording.live_slots[j] == true then
				table.insert(tmp_slots, slot)
			end
		end

		-- ランダムで1つ選定
		if #tmp_slots > 0 then
			recording.active_slot = tmp_slots[math.random(#tmp_slots)]
		else
			recording.active_slot = { store = {}, name = "空" }
		end

		local joy_val = get_joy()
		if #recording.active_slot.store > 0 and (accept_input("st", joy_val, state_past) or force_start_play == true) then
			recording.force_start_play = false
			-- 状態変更
			recording.play_count = 1
			global.rec_main = rec_play
			global.input_accepted = ec

			-- メインラインでニュートラル状態にする
			for i, p in ipairs(players) do
				local op = p.op

				-- 状態リセット   1:OFF 2:1Pと2P 3:1P 4:2P
				if global.replay_reset == 2 or (global.replay_reset == 3 and i == 3) or (global.replay_reset == 4 and i == 4) then
					local resets = {
						[mem.w16i] = {
							[0x28] = 0x00,
							[0x24] = 0x18,
						},
						[mem.w16] = {
							[0x60] = 0x01,
							[0x64] = 0xFFFF,
							[0x6E] = 0x00,
						},
						[mem.w32] = {
							[p.addr.base] = 0x58D5A, -- やられからの復帰処理  0x261A0: 素立ち処理
							[0x28] = 0x00,
							[0x34] = 0x00,
							[0x38] = 0x00,
							[0x3C] = 0x00,
							[0x44] = 0x00,
							[0x48] = 0x00,
							[0x4C] = 0x00,
							[0x50] = 0x00,
							[0xDA] = 0x00,
							[0xDE] = 0x00,
						},
						[mem.w8] = {
							[0x61] = 0x01,
							[0x63] = 0x02,
							[0x65] = 0x02,
							[0x66] = 0x00,
							[0x6A] = 0x00,
							[0x7E] = 0x00,
							[0xB0] = 0x00,
							[0xB1] = 0x00,
							[0xC0] = 0x80,
							[0xC2] = 0x00,
							[0xFC] = 0x00,
							[0xFD] = 0x00,
							[0x89] = 0x00,
						},
					}
					for fnc, tbl in pairs(resets) do for addr, value in pairs(tbl) do fnc(addr, value) end end
					do_recover(p, op, true)
					p.last_frame_gap = 0
				end
			end

			local fixpos = recording.fixpos
			if fixpos then
				-- 開始間合い固定 1:OFF 2:位置記憶 3:1Pと2P 4:1P 5:2P
				if fixpos.fixpos then
					for i, p in ipairs(players) do
						if global.replay_fix_pos == 3 or (global.replay_fix_pos == 4 and i == 3) or (global.replay_fix_pos == 5 and i == 4) then
							mem.w16i(p.addr.pos, fixpos.fixpos[i])
						end
					end
				end
				if fixpos.fixscr and global.replay_fix_pos and global.replay_fix_pos ~= 1 then
					mem.w16(mem.stage_base_addr + screen.offset_x, fixpos.fixscr.x)
					mem.w16(mem.stage_base_addr + screen.offset_x + 0x30, fixpos.fixscr.x)
					mem.w16(mem.stage_base_addr + screen.offset_x + 0x2C, fixpos.fixscr.x)
					mem.w16(mem.stage_base_addr + screen.offset_x + 0x34, fixpos.fixscr.x)
					mem.w16(mem.stage_base_addr + screen.offset_y, fixpos.fixscr.y)
					mem.w16(mem.stage_base_addr + screen.offset_z, fixpos.fixscr.z)
				end
			end
			players[1].input_side = mem.r8(players[1].addr.input_side)
			players[2].input_side = mem.r8(players[2].addr.input_side)

			-- 入力リセット
			local next_joy        = new_next_joy()
			for _, joy in ipairs(use_joy) do
				to_joy[joy.field] = next_joy[joy.field] or false
			end
			return
		end
	end
	-- 繰り返しリプレイ待ち
	rec_repeat_play = function(to_joy)
		-- 繰り返し前の行動が完了するまで待つ
		local p = players[3 - recording.player]
		local op = players[recording.player]

		local p_ok = true
		if global.await_neutral == true then
			p_ok = p.act_normal or (not p.act_normal and p.update_act == global.frame_number and recording.last_act ~= p.act)
		end
		if p_ok then
			if recording.last_pos_y == 0 or (recording.last_pos_y > 0 and p.pos_y == 0) then
				-- リプレイ側が通常状態まで待つ
				if op.act_normal and op.state == 0 then
					-- 状態変更
					global.rec_main = rec_await_play
					global.rec_force_start_play = true -- 一時的な強制初期化フラグをON
					print(global.frame_number .. " rec_repeat_play -> rec_await_play(force)")
					return
				end
			end
		end
	end
	-- リプレイ中
	rec_play = function(to_joy)
		local ec = scr:frame_number()
		local state_past = ec - global.input_accepted

		local joy_val = get_joy()

		if accept_input("st", joy_val, state_past) then
			-- 状態変更
			global.rec_main = rec_await_play
			global.input_accepted = ec
			print(global.frame_number .. " rec_play -> rec_await_play")
			return
		end

		local stop = false
		local store = recording.active_slot.store[recording.play_count]
		if store == nil then
			stop = true
		elseif players[recording.player].state == 1 then
			if global.replay_stop_on_dmg then
				stop = true
			end
		end
		if not stop and store then
			-- 入力再生
			local pos = { players[1].input_side, players[2].input_side }
			for _, joy in ipairs(use_joy) do
				local k = joy.field
				-- 入力時と向きが変わっている場合は左右反転させて反映する
				local opside = 3 - recording.active_slot.side
				if recording.active_slot.side == joy_pside[k] then
					if joy_frontback[k] and joy_pside[k] then
						local now_side = pos[joy_pside[k]]
						local next_side = store.pos[joy_pside[k]]
						if now_side ~= next_side then
							k = joy_frontback[k]
						end
					end
				elseif opside == joy_pside[k] then
					if joy_frontback[k] and joy_pside[k] then
						local now_side = pos[joy_pside[k]]
						local next_side = store.pos[joy_pside[k]]
						if now_side ~= next_side then
							k = joy_frontback[k]
						end
					end
				end
				to_joy[k] = store.joy[joy.field] or to_joy[k]
			end
			recording.play_count = recording.play_count + 1

			-- 繰り返し判定
			if 0 < #recording.active_slot.store and #recording.active_slot.store < recording.play_count then
				stop = true
			end
		end

		if stop then
			global.repeat_interval = recording.repeat_interval
			-- 状態変更
			global.rec_main = rec_play_interval
			print(global.frame_number .. " rec_play -> rec_play_interval")
		end
	end
	--

	-- リプレイまでの待ち時間
	rec_play_interval = function(to_joy)
		local ec = scr:frame_number()
		local state_past = ec - global.input_accepted

		local joy_val = get_joy()

		if accept_input("st", joy_val, state_past) then
			-- 状態変更
			global.rec_main = rec_await_play
			global.input_accepted = ec
			print(global.frame_number .. " rec_play_interval -> rec_await_play")
			return
		end

		global.repeat_interval = math.max(0, global.repeat_interval - 1)

		local stop = global.repeat_interval == 0

		if stop then
			if recording.do_repeat then
				-- 状態変更
				-- 繰り返し前の行動を覚えておいて、行動が完了するまで待機できるようにする
				recording.last_act = players[3 - recording.player].act
				recording.last_pos_y = players[3 - recording.player].pos_y
				global.rec_main = rec_repeat_play
				print(global.frame_number .. " rec_play_interval -> rec_repeat_play")
				return
			else
				-- 状態変更
				global.rec_main = rec_await_play
				print(global.frame_number .. " rec_play_interval -> rec_await_play")
				return
			end
		end
	end
	--

	-- 1Pと2Pともにフレーム数が多すぎる場合は加算をやめる
	-- グラフの描画最大範囲（画面の横幅）までにとどめる
	local fix_max_framecount = function()
		local min_count = 332
		for _, p in ipairs(players) do
			local frame1 = p.act_frames[#p.act_frames]
			if frame1.count <= 332 then
				return
			else
				min_count = math.min(min_count, frame1.count)
			end

			frame1 = p.muteki.act_frames[#p.muteki.act_frames]
			if frame1.count <= 332 then
				return
			else
				min_count = math.min(min_count, frame1.count)
			end

			frame1 = p.frm_gap.act_frames[#p.frm_gap.act_frames]
			if frame1.count <= 332 then
				return
			else
				min_count = math.min(min_count, frame1.count)
			end

			for _, fb in ipairs(p.fireballs) do
				local frame1 = fb.act_frames[#fb.act_frames]
				if frame1.count <= 332 then
					return
				else
					min_count = math.min(min_count, frame1.count)
				end
			end
		end

		local fix = min_count - 332
		for _, p in ipairs(players) do
			local frame1 = p.act_frames[#p.act_frames]
			frame1.count = frame1.count - fix

			frame1 = p.muteki.act_frames[#p.muteki.act_frames]
			frame1.count = frame1.count - fix

			frame1 = p.frm_gap.act_frames[#p.frm_gap.act_frames]
			frame1.count = frame1.count - fix

			for _, fb in ipairs(p.fireballs) do
				local frame1 = fb.act_frames[#fb.act_frames]
				frame1.count = frame1.count - fix
			end
		end
	end

	-- 技名でグループ化したフレームデータの配列をマージ生成する
	local frame_groups = function(frame, frames2)
		local upd = false
		if #frames2 == 0 then
			table.insert(frames2, {})
		end
		if frame.count and frame.act then
			local frame_group = frames2[#frames2] or {}
			local prev_frame  = frame_group ~= nil and frame_group[#frame_group] or nil
			local prev_name   = prev_frame ~= nil and prev_frame.name or nil
			if prev_name ~= frame.name or (frame.act_1st and frame.count == 1) then
				upd = true
				frame_group = {} -- ブレイクしたので新規にグループ作成
				table.insert(frames2, frame_group)
				table.insert(frame_group, frame)
				if 180 < #frames2 then
					--バッファ長調整 TODO
					table.remove(frames2, 1)
				end
				-- グループの先頭はフレーム合計ゼロ開始
				frame.last_total = 0
			else
				-- 同じグループ
				if prev_frame == frame then
					-- 変更なし
				elseif prev_frame then
					table.insert(frame_group, frame)
					-- 直前までのフレーム合計加算して保存
					frame.last_total = prev_frame.last_total + prev_frame.count
				end
			end
		end
		return frames2, upd
	end
	-- グラフでフレームデータを表示する
	local dodraw = function(x1, y, frame_group, main_frame, height, xmin, xmax, show_name, show_count, x, scr, txty, draw_if_overflow)
		local grp_len = #frame_group
		local overflow = 0
		if 0 < grp_len then
			-- 最終フレームに記録された全フレーム数を記憶
			local pre_x = (frame_group[grp_len].last_total or 0) + frame_group[grp_len].count + x
			if pre_x > xmax then
				x1 = xmax
				overflow = pre_x - xmax
			else
				x1 = pre_x
			end
			-- グループの名称を描画
			if show_name and main_frame then
				if (frame_group[1].col + frame_group[1].line) > 0 then
					draw_text_with_shadow(x + 12, txty + y, frame_group[1].name, 0xFFC0C0C0)
				end
			end
			-- グループのフレーム数を末尾から描画
			for k = #frame_group, 1, -1 do
				local frame = frame_group[k]
				local x2 = x1 - frame.count
				local on_fireball, on_prefb, on_air, on_ground = false, false, false, false
				if x2 < xmin then
					if x2 + x1 < xmin and not main_frame then
						break
					end
					x2 = xmin
				else
					on_fireball = frame.on_fireball
					on_prefb = frame.on_prefb
					on_air = frame.on_air
					on_ground = frame.on_ground
				end

				if (frame.col + frame.line) > 0 then
					local evx = math.min(x1, x2)
					if on_fireball then
						scr:draw_text(evx - 1.5, txty + y - 1, "●")
					elseif on_prefb then
						-- 飛び道具の処理発生ポイント(発生保障や完全消失の候補)
						scr:draw_text(evx - 2.0, txty + y - 1, "◆")
					end
					if on_air then
						scr:draw_text(evx - 3, txty + y, "▲")
					elseif on_ground then
						scr:draw_text(evx - 3, txty + y, "▼")
					end
					scr:draw_box(x1, y, x2, y + height, frame.line, frame.col)
					if show_count then
						local count_txt = 300 < frame.count and "LOT" or ("" .. frame.count)
						if frame.count > 5 then
							draw_text_with_shadow(x2 + 1, txty + y, count_txt)
						elseif 3 > frame.count then
							draw_text_with_shadow(x2 - 1, txty + y, count_txt)
						else
							draw_text_with_shadow(x2, txty + y, count_txt)
						end
					end
				end
				if x2 <= x then
					break
				end
				x1 = x2
			end
		end
		return overflow
	end
	local draw_frames = function(frames2, xmax, show_name, show_count, x, y, height, span, disp_fbfrm)
		if #frames2 == 0 then
			return
		end
		span = span or height
		local txty = math.max(-2, height - 8)

		-- 縦に描画
		local x1 = xmax
		if #frames2 < 7 then
			y = y + (7 - #frames2) * span
		end
		for j = #frames2 - math.min(#frames2 - 1, 6), #frames2 do
			local frame_group = frames2[j]
			local overflow = dodraw(x1, y + span, frame_group, true, height, x, xmax, show_name, show_count, x, scr, txty)

			for _, frame in ipairs(frame_group) do
				if frame.fireball and disp_fbfrm == true then
					for _, fb in pairs(frame.fireball) do
						for _, sub_group in ipairs(fb) do
							dodraw(x1, y + 0 + span, sub_group, false, height, x, xmax, show_name, show_count, x + sub_group.parent_count - overflow, scr, txty - 1)
						end
					end
				end
				if frame.frm_gap then
					for _, sub_group in ipairs(frame.frm_gap) do
						dodraw(x1, y + 6 + span, sub_group, false, height - 3, x, xmax, show_name, show_count, x, scr, txty - 1)
					end
				end
				if frame.muteki then
					for _, sub_group in ipairs(frame.muteki) do
						dodraw(x1, y + 11 + span, sub_group, false, height - 3, x, xmax, show_name, show_count, x, scr, txty - 1)
					end
				end
			end
			y = y + span
		end
	end
	local draw_frame_groups = function(frames2, act_frames_total, x, y, height, show_count)
		if #frames2 == 0 then
			return
		end

		-- 横に描画
		local xmin = x --30
		local xa, xb, xmax = 325 - xmin, act_frames_total + xmin, 0
		-- 左寄せで開始
		if xa < xb then
			xmax = xa
		else
			xmax = (act_frames_total + xmin) % (325 - xmin)
		end
		-- 右寄せで開始
		-- xmax = math.min(325 - xmin, act_frames_total + xmin)
		local x1 = xmax
		local loopend = false
		for j = #frames2, 1, -1 do
			local frame_group = frames2[j]
			local first = true
			for k = #frame_group, 1, -1 do
				local frame = frame_group[k]
				local x2 = math.max(xmin, x1 - frame.count)
				loopend = x2 <= xmin
				if (frame.col + frame.line) > 0 then -- 速度かせぎのためカラー無しはスキップする
					scr:draw_box(x1, y, x2, y + height, frame.line, frame.col)
					if show_count == true and first == true then
						first = false
						local txty = math.max(-2, height - 8)
						local count_txt = 300 < frame.count and "LOT" or ("" .. frame.count)
						if frame.count > 5 then
							draw_text_with_shadow(x2 + 1, txty + y, count_txt)
						elseif 3 > frame.count then
							draw_text_with_shadow(x2 - 1, txty + y, count_txt)
						else
							draw_text_with_shadow(x2, txty + y, count_txt)
						end
					end
				end
				if loopend then break end
				x1 = x2
			end
			if loopend then break end
		end
	end

	do_recover = function(p, op, force)
		-- 体力と気絶値とMAX気絶値回復
		local life = { 0xC0, 0x60, 0x00 }
		local max_life = life[p.red] or (p.red - #life) -- 赤体力にするかどうか
		local init_stuns = p.char_data and p.char_data.init_stuns or 0
		if dip_config.infinity_life then
			mem.w8(p.addr.life, max_life)
			mem.w8(p.addr.stun_limit, init_stuns) -- 最大気絶値
			mem.w8(p.addr.init_stun, init_stuns) -- 最大気絶値
		elseif p.life_rec then
			if force or (p.addr.life ~= max_life and 180 < math.min(p.throw_timer, op.throw_timer)) then
				mem.w8(p.addr.life, max_life) -- やられ状態から戻ったときに回復させる
				mem.w8(p.addr.stun, 0)    -- 気絶値
				mem.w8(p.addr.stun_limit, init_stuns) -- 最大気絶値
				mem.w8(p.addr.init_stun, init_stuns) -- 最大気絶値
				mem.w16(p.addr.stun_timer, 0) -- 気絶値タイマー
			elseif max_life < p.life then
				mem.w8(p.addr.life, max_life) -- 最大値の方が少ない場合は強制で減らす
			end
		end

		-- パワーゲージ回復
		-- 0x3C, 0x1E, 0x00
		local pow     = { 0x3C, 0x1E, 0x00 }
		local max_pow = pow[p.max] or (p.max - #pow) -- パワーMAXにするかどうか
		-- POWモード　1:自動回復 2:固定 3:通常動作
		if global.pow_mode == 2 then
			mem.w8(p.addr.pow, max_pow)
		elseif global.pow_mode == 1 and p.pow == 0 then
			mem.w8(p.addr.pow, max_pow)
		elseif global.pow_mode ~= 3 and max_pow < p.pow then
			-- 最大値の方が少ない場合は強制で減らす
			mem.w8(p.addr.pow, max_pow)
		end
	end

	local force_y_pos = { "OFF", 0 }
	for i = 1, 256 do table.insert(force_y_pos, i) end
	for i = -1, -256, -1 do table.insert(force_y_pos, i) end

	local proc_act_frame = function(parent)
		local op, chg_act_name = parent.op, nil

		-- 飛び道具
		local chg_fireball_state, chg_prefireball_state, active_fb = false, false, nil
		local attackbit = 0
		for _, p in pairs(parent.fireballs) do
			local base = ((p.addr.base - 0x100400) / 0x100)
			if p.proc_active == true and #p.boxies > 0 then
				if p.atk_count == 1 and p.act_data_fired.name == parent.act_data.name then
					chg_fireball_state = true
				end
				attackbit = frame_attack_types.attacking
				attackbit = attackbit | parent.attackbit
				if p.juggle then
					attackbit = attackbit | frame_attack_types.juggle
				end
				attackbit = attackbit | (p.hurt_attack << frame_attack_types.attack)
				attackbit = attackbit | base << frame_attack_types.fb
				if p.max_hit_dn > 1 or p.max_hit_dn == 0 then
					attackbit = attackbit | p.act_count << frame_attack_types.fb_effect
					if util.testbit(p.act_data.type, act_types.rec_in_detail) then
						attackbit = attackbit | p.act << frame_attack_types.fb_act
					end
				else
					attackbit = attackbit | (p.effect << frame_attack_types.fb_effect)
				end
				active_fb = p
				break
			end
		end
		if chg_fireball_state ~= true then
			for _, fb in pairs(parent.fireballs) do
				if fb.proc_active == true and #fb.boxies == 0 then
					fb.atk_count = fb.atk_count - 1
					if fb.atk_count == -1 then
						chg_prefireball_state = true
						break
					end
				end
				if fb.old_proc_act == true and fb.proc_active ~= true then
					chg_prefireball_state = true
					break
				end
			end
		end
		parent.on_fireball = chg_fireball_state == true
		parent.on_prefb = chg_prefireball_state == true

		--ガード移行できない行動は色替えする
		local col, line = 0xAAF0E68C, 0xDDF0E68C
		if parent.on_bs_established == global.frame_number then
			col, line = 0xAA0022FF, 0xDD0022FF
		elseif parent.on_bs_clear == global.frame_number then
			col, line = 0xAA00FF22, 0xDD00FF22
		elseif parent.in_hitstop == global.frame_number or parent.on_hit_any == global.frame_number then
			col, line = 0xAA444444, 0xDD444444
		elseif parent.on_bs_check == global.frame_number then
			col, line = 0xAAFF0022, 0xDDFF0022
		elseif parent.hitbox_types and #parent.hitbox_types > 0 then
			-- 判定タイプをソートする
			table.sort(parent.hitbox_types, function(t1, t2) return t1.sort > t2.sort end)
			if parent.hitbox_types[1].sort < 3 and parent.repeatable then
				-- やられ判定より連キャン状態を優先表示する
				col, line = 0xAAD2691E, 0xDDD2691E
			else
				col = parent.hitbox_types[1].color
				col, line = util.hex_set(col, 0xAA000000), util.hex_set(col, 0xDD000000)
			end
		end

		-- TODO 3 "ON:判定の形毎", 4 "ON:攻撃判定の形毎", 5 "ON:くらい判定の形毎",
		local masked_attackbit = parent.attackbit
		if parent.disp_frm == 3 then
			masked_attackbit = masked_attackbit
		elseif parent.disp_frm == 4 then
			masked_attackbit = masked_attackbit
		elseif parent.disp_frm == 5 then
			masked_attackbit = masked_attackbit
		end

		local frame = parent.act_frames[#parent.act_frames]
		local name  = frame and frame.name or parent.act_data.name
		name        = (frame and parent.act_data.name_set and parent.act_data.name_set[name] ~= true) and parent.act_data.name or name

		if frame == nil or frame.attackbit ~= masked_attackbit or frame.col ~= col then
			--行動IDの更新があった場合にフレーム情報追加
			frame = {
				act = parent.act,
				count = 1,
				col = col,
				name = name,
				line = line,
				on_fireball = parent.on_fireball,
				on_prefb = parent.on_prefb,
				on_air = parent.on_air,
				on_ground = parent.on_ground,
				act_1st = parent.act_1st,

				attackbit = masked_attackbit,
			}
			table.insert(parent.act_frames, frame)
			if 180 < #parent.act_frames then
				--バッファ長調整
				table.remove(parent.act_frames, 1)
			end
		else
			--同一行動IDが継続している場合はフレーム値加算
			if frame then
				frame.count = frame.count + 1
			end
		end
		-- 技名でグループ化したフレームデータの配列をマージ生成する
		parent.act_frames2 = frame_groups(frame, parent.act_frames2 or {})
		-- 表示可能範囲（最大で横画面幅）以上は加算しない
		parent.act_frames_total = (332 < parent.act_frames_total) and 332 or (parent.act_frames_total + 1)

		-- 後の処理用に最終フレームを保持
		return frame, chg_act_name
	end

	local proc_muteki_frame = function(p, chg_act_name)
		local last_frame = p.act_frames[#p.act_frames]

		-- 無敵表示
		local col, line = 0x00000000, 0x00000000
		--[[
		for _, hurt_inv in ipairs(p.hit_summary.hurt_inv) do
			if 0x400 > p.flag_cc then
				if hurt_inv.type == 0 then -- 全身無敵
					col, line = 0xAAB0E0E6, 0xDDAFEEEE
					break
				elseif hurt_inv.type == 1 then -- スウェー上
					col, line = 0xAAFFA500, 0xDDAFEEEE
					break
				elseif hurt_inv.type == 2 then -- 上半身無敵（地上）
					col, line = 0xAA32CD32, 0xDDAFEEEE
					break
				elseif hurt_inv.type == 3 then -- 足元無敵（地上）
					col, line = 0xAA9400D3, 0xDDAFEEEE
					break
				elseif hurt_inv.type == 0 then -- ダウンor空中追撃のみ可能
					col, line = 0xAAB0E0E6, 0xDDAFEEEE
					break
				end
			else
				if hurt_inv.type == 0 then -- 全身無敵
					col, line = 0xAAB0E0E6, 0xDDAFEEEE
					break
				elseif hurt_inv.type == 1 then -- スウェー上
					col, line = 0xAAFFA500, 0xDDAFEEEE
					break
				end
			end
		end
		]]
		--printf("top %s, hi %s, lo %s", screen_top, vul_hi, vul_lo)

		local frame = p.muteki.act_frames[#p.muteki.act_frames]
		if frame == nil or chg_act_name or frame.col ~= col or p.state ~= p.old_state or p.act_1st then
			--行動IDの更新があった場合にフレーム情報追加
			frame = {
				act = p.act,
				count = 1,
				col = col,
				name = last_frame.name,
				line = line,
				act_1st = p.act_1st,
			}
			table.insert(p.muteki.act_frames, frame)
			if 180 < #p.muteki.act_frames then
				--バッファ長調整
				table.remove(p.muteki.act_frames, 1)
			end
		else
			--同一行動IDが継続している場合はフレーム値加算
			frame.count = frame.count + 1
		end
		-- 技名でグループ化したフレームデータの配列をマージ生成する
		local upd_group
		p.muteki.act_frames2, upd_group = frame_groups(frame, p.muteki.act_frames2 or {})
		-- メインフレーム表示からの描画開始位置を記憶させる
		if upd_group and last_frame then
			last_frame.muteki = last_frame.muteki or {}
			table.insert(last_frame.muteki, p.muteki.act_frames2[#p.muteki.act_frames2])
		end

		return frame
	end

	local proc_frame_gap = function(p, chg_act_name)
		local op = p.op
		local last_frame = p.act_frames[#p.act_frames]

		-- フレーム差
		-- フレーム差のバッファ
		local old_last_frame_gap = p.last_frame_gap
		local save_frame_gap = function()
			local upd = false
			if old_last_frame_gap > 0 and old_last_frame_gap > p.last_frame_gap then
				upd = true
			elseif old_last_frame_gap < 0 and old_last_frame_gap < p.last_frame_gap then
				upd = true
			elseif old_last_frame_gap ~= 0 and p.last_frame_gap == 0 then
				upd = true
			end
			if upd then
				table.insert(p.hist_frame_gap, old_last_frame_gap)
				if 10 < #p.hist_frame_gap then
					--バッファ長調整
					table.remove(p.hist_frame_gap, 1)
				end
			end
		end
		-- フレーム差の更新
		local col, line = 0x00000000, 0x00000000
		if p.act_normal == op.act_normal then
			if p.act_normal ~= op.act_normal then
				p.last_frame_gap = 0
			end
			p.frame_gap = 0
		elseif p.act_normal then
			-- 直前が行動中ならリセットする
			if not p.old_act_normal then
				p.frame_gap = 0
			end
			p.frame_gap = p.frame_gap + 1
			p.last_frame_gap = p.frame_gap
			col, line = 0xAA0000FF, 0xDD0000FF
		elseif not p.act_normal then
			-- 直前が行動中ならリセットする
			if not op.old_act_normal then
				p.frame_gap = 0
			end
			p.frame_gap = p.frame_gap - 1
			p.last_frame_gap = p.frame_gap
			col, line = 0xAAFF6347, 0xDDFF6347
		end
		save_frame_gap()

		local frame = p.frm_gap.act_frames[#p.frm_gap.act_frames]
		if frame == nil or chg_act_name or (frame.col ~= col and (p.frame_gap == 0 or p.frame_gap == -1 or p.frame_gap == 1)) or p.act_1st then
			--行動IDの更新があった場合にフレーム情報追加
			frame = {
				act = p.act,
				count = 1,
				col = col,
				name = last_frame.name,
				line = line,
				act_1st = p.act_1st,
			}
			table.insert(p.frm_gap.act_frames, frame)
			if 180 < #p.frm_gap.act_frames then
				--バッファ長調整
				table.remove(p.frm_gap.act_frames, 1)
			end
		else
			--同一行動IDが継続している場合はフレーム値加算
			frame.count = frame.count + 1
		end
		-- 技名でグループ化したフレームデータの配列をマージ生成する
		local upd_group
		p.frm_gap.act_frames2, upd_group = frame_groups(frame, p.frm_gap.act_frames2 or {})
		-- メインフレーム表示からの描画開始位置を記憶させる
		if upd_group and last_frame then
			last_frame.frm_gap = last_frame.frm_gap or {}
			table.insert(last_frame.frm_gap, p.frm_gap.act_frames2[#p.frm_gap.act_frames2])
		end
	end

	local proc_fb_frame = function(parent)
		local last_frame = parent.act_frames[#parent.act_frames]
		local fb_upd_groups = {}

		-- 飛び道具2
		for fb_base, p in pairs(parent.fireballs) do
			local col, line, act = 0, 0, 0
			if p.in_hitstop == global.frame_number or p.on_hit_any == global.frame_number then
				col, line = 0xAA444444, 0xDD444444
			elseif p.hitbox_types and #p.hitbox_types > 0 then
				-- 判定タイプをソートする
				table.sort(p.hitbox_types, function(t1, t2) return t1.sort > t2.sort end)
				if p.hitbox_types[1].sort < 3 and p.repeatable then
					-- やられ判定より連キャン状態を優先表示する
					col, line = 0xAAD2691E, 0xDDD2691E
				else
					col = p.hitbox_types[1].color
					col, line = util.hex_set(col, 0xAA000000), util.hex_set(col, 0xDD000000)
				end
			end

			-- 3 "ON:判定の形毎", 4 "ON:攻撃判定の形毎", 5 "ON:くらい判定の形毎",
			local masked_attackbit = p.attackbit
			if p.disp_frm == 3 then
				masked_attackbit = masked_attackbit
			elseif p.disp_frm == 4 then
				masked_attackbit = masked_attackbit
			elseif p.disp_frm == 5 then
				masked_attackbit = masked_attackbit
			end

			local frame = p.act_frames[#p.act_frames]
			local name  = frame and frame.name or p.act_data_fired.name
			name        = (frame and p.act_data_fired.name_set and p.act_data_fired.name_set[name] ~= true) and p.act_data_fired.name or name

			if frame == nil or frame.attackbit ~= masked_attackbit then
				-- 軽量化のため攻撃の有無だけで記録を残す
				frame = {
					act       = act,
					count     = 1,
					col       = col,
					name      = name,
					line      = line,
					-- act_1st    = reset,

					attackbit = masked_attackbit,
				}
				-- 関数の使いまわすためact_framesは配列にするが明細を表示ないので1個しかもたなくていい
				p.act_frames[1] = frame
			else
				-- 同一行動IDが継続している場合はフレーム値加算
				frame.count = frame.count + 1
			end
			-- 技名でグループ化したフレームデータの配列をマージ生成する
			p.act_frames2, fb_upd_groups[fb_base] = frame_groups(frame, p.act_frames2 or {})
		end

		-- メインフレーム表示からの描画開始位置を記憶させる
		for fb_base, fb_upd_group in pairs(fb_upd_groups) do
			if fb_upd_group and last_frame then
				last_frame.fireball = last_frame.fireball or {}
				last_frame.fireball[fb_base] = last_frame.fireball[fb_upd_group] or {}
				local last_fb_frame = last_frame.fireball[fb_base]
				table.insert(last_fb_frame, parent.fireballs[fb_base].act_frames2[# parent.fireballs[fb_base].act_frames2])
				last_fb_frame[#last_fb_frame].parent_count = last_frame.last_total
			end
		end
	end

	local input_rvs = function(rvs_type, p, logtxt)
		if global.rvslog and logtxt then emu.print_info(logtxt) end
		if util.testbit(p.dummy_rvs.hook_type, hook_cmd_types.throw) then
			if p.act == 0x9 and p.act_frame > 1 then return end -- 着地硬直は投げでないのでスルー
			if p.op.in_air then return end
			if p.op.sway_status ~= 0x00 then return end -- 全投げ無敵
		elseif util.testbit(p.dummy_rvs.hook_type, hook_cmd_types.jump) then
			if p.state == 0 and p.old_state == 0 and (p.flag_c0 | p.old_flag_c0) & 0x10000 == 0x10000 then
				return -- 連続通常ジャンプを繰り返さない
			end
		end
		p.bs_hook = p.dummy_rvs.id and p.dummy_rvs or nil
		if p.dummy_rvs.cmd_type then
			if rvs_types.knock_back_recovery ~= rvs_type then
				if (((p.flag_c0 | p.old_flag_c0) & 0x2 == 0x2) or pre_down_acts[p.act]) and p.dummy_rvs.cmd_type == data.cmd_types._2d then
					-- no act
				else
					p.bs_hook = p.dummy_rvs
				end
			end
		end
	end

	-- トレモのメイン処理
	menu.tra_main.proc = function()
		if not in_match or mem._0x10E043 ~= 0 then return end -- ポーズ中は状態を更新しない
		if menu.reset_pos then menu.update_pos() end
		global.frame_number = global.frame_number + 1
		local next_joy, joy_val, state_past = new_next_joy(), get_joy(), scr:frame_number() - global.input_accepted
		set_freeze((not in_match) or true) -- ポーズ解除状態

		-- スタートボタン（リプレイモード中のみスタートボタンおしっぱでメニュー表示へ切り替え
		if (global.dummy_mode == 6 and is_start_a(joy_val, state_past)) or
			(global.dummy_mode ~= 6 and accept_input("st", joy_val, state_past)) then
			-- メニュー表示状態へ切り替え
			global.input_accepted, menu.state = global.frame_number, menu
			cls_joy()
			return
		end

		if global.lag_frame == true then return end -- ラグ発生時は処理をしないで戻る

		-- 1Pと2Pの状態読取
		for i, p in ipairs(players) do
			local op      = players[3 - i]
			p.op          = op
			p.base        = mem.r32(p.addr.base)
			p.char        = mem.r8(p.addr.char)
			p.char_data   = chars[p.char]
			p.char4       = 0xFFFF & (p.char << 2)
			p.char8       = 0xFFFF & (p.char << 3)
			p.old_state   = p.state -- 前フレームの状態保存
			p.old_flag_c0 = p.flag_c0
			p.old_flag_cc = p.flag_cc
			p.slide_atk   = util.testbit(p.flag_cc, state_flag_cc._02) -- ダッシュ滑り攻撃
			-- ブレイクショット
			p.bs_atk      = util.testbit(p.flag_cc, state_flag_cc._21) and (util.testbit(p.old_flag_cc, state_flag_cc._20) or p.bs_atk)
			-- やられ状態
			if p.flag_fin or util.testbit(p.flag_c0, state_flag_c0._16) then
				-- 最終フレームか着地フレームの場合は前フレームのを踏襲する
				p.in_hitstun = p.in_hitstun
			elseif p.flag_c8 == 0 and p.hurt_state then
				p.in_hitstun = p.hurt_state > 0 or
					util.testbit(p.flag_cc, state_flag_cc.hitstun) or
					util.testbit(p.flag_d0, state_flag_d0._06) or -- ガード中、やられ中
					util.testbit(p.flag_c0, state_flag_c0._01) -- ダウン
			else
				p.in_hitstun = false
			end
			--[[
			p.attack_flag     = util.testbit(p.flag_cc, state_flag_cc.attacking) or (p.flag_c8 > 0) or (p.flag_c4 > 0)
			p.spid            = util.testbit(p.flag_cc, state_flag_cc._21) and mem.r8(p.addr.base + 0xB8) or 0
			p.pos_miny        = 0
			]]
			if util.testbit(p.flag_c4, state_flag_c4.hop) then
				p.pos_miny = p.char_data.min_sy
			elseif util.testbit(p.flag_c4, state_flag_c4.jump) then
				p.pos_miny = p.char_data.min_y
			end
			p.last_normal_state = p.normal_state
			p.normal_state      = p.state == 0 -- 素立ち
			p.old_attack        = p.attack
			p.old_repeatable    = p.repeatable
			p.old_pure_dmg      = p.pure_dmg
			p.old_invincible    = p.invincible or 0
			-- 通常投げ無敵判断 その2(HOME 039FC6から03A000の処理を再現して投げ無敵の値を求める)
			p.old_tw_muteki2    = p.tw_muteki2 or 0
			p.throwable         = p.state == 0 and op.state == 0 and p.throw_timer > 24 and p.sway_status == 0x00 and p.invincible == 0 -- 投げ可能ベース
			p.n_throwable       = p.throwable and p.tw_muteki2 == 0                                                            -- 通常投げ可能
			p.old_act           = p.act or 0x00
			p.old_act_count     = p.act_count
			p.old_act_frame     = p.act_frame
			p.gd_strength       = get_gd_strength(p)
			p.old_knock_back1   = p.knock_back1
			p.dmmy_attacking    = false
			p.juggle            = false
			p.can_juggle        = false
			p.can_otg           = false
			p.old_anyhit_id     = p.anyhit_id
			p.old_posd          = p.posd
			p.posd              = p.pos + p.pos_frc
			p.poslr             = p.posd == op.posd and "=" or p.posd < op.posd and "L" or "R"
			p.old_pos           = p.pos
			p.old_pos_frc       = p.pos_frc
			p.thrust            = p.thrust + p.thrust_frc
			p.inertia           = p.inertia + p.inertia_frc
			p.pos_total         = p.pos + p.pos_frc
			p.old_pos_total     = p.old_pos + util.int16tofloat(p.old_pos_frc)
			p.diff_pos_total    = p.pos_total - p.old_pos_total
			p.old_pos_y         = p.pos_y
			p.old_pos_frc_y     = p.pos_frc_y
			p.old_in_air        = p.in_air
			p.in_air            = 0 < p.pos_y or 0 < p.pos_frc_y

			-- ジャンプの遷移ポイントかどうか
			if p.old_in_air ~= true and p.in_air == true then
				p.chg_air_state = 1
			elseif p.old_in_air == true and p.in_air ~= true then
				p.chg_air_state = -1
			else
				p.chg_air_state = 0
			end
			p.on_air = p.chg_air_state == 1
			p.on_ground = p.chg_air_state == -1
			if p.in_air then
				p.pos_y_peek = math.max(p.pos_y_peek or 0, p.pos_y)
			else
				p.pos_y_peek = 0
			end
			if p.pos_y < p.old_pos_y or (p.pos_y == p.old_pos_y and p.pos_frc_y < p.old_pos_frc_y) then
				p.pos_y_down = p.pos_y_down and (p.pos_y_down + 1) or 1
			else
				p.pos_y_down = 0
			end
			p.old_pos_z = p.pos_z
			p.old_sway_status = p.sway_status
			-- 滑り属性の攻撃か慣性残しの立ち攻撃か
			if p.slide_atk == true or (p.old_act == 0x19 and p.inertia > 0 and util.testbit(p.flag_c0, 0x32)) then
				p.dash_act_addr = get_dash_act_addr(p, pgm)
				p.dash_act_info = string.format("%s %s+%s %x",
					p.slide_atk == true and "滑り属性" or "慣性残し",
					slide_rev[p.input1] or p.input1,
					slide_btn[p.cln_btn] or p.cln_btn,
					p.dash_act_addr or 0)
			else
				p.dash_act_addr = p.dash_act_addr or 0
				p.dash_act_info = p.dash_act_info or ""
			end

			p.ophit = nil
			if p.ophit_base == 0x100400 or p.ophit_base == 0x100500 then
				p.ophit = op
			else
				p.ophit = op.fireballs[p.ophit_base]
			end

			-- ライン送らない状態のデータ書き込み
			if p.dis_plain_shift then
				mem.w8(p.addr.hurt_state, p.hurt_state | 0x40)
			end
		end

		-- 1Pと2Pの状態読取 ゲージ
		for _, p in ipairs(players) do
			p.last_pow      = p.last_pow or 0
			p.last_pure_dmg = p.last_pure_dmg or 0
			p.last_stun     = p.last_stun or 0
			p.last_st_timer = p.last_st_timer or 0
			p.last_effects  = p.last_effects or {}
		end

		-- 1Pと2Pの状態読取 入力
		global.old_all_act_normal = global.all_act_normal
		global.all_act_normal = true
		for _, p in ipairs(players) do
			p.old_input_states = p.input_states or {}
			p.input_states     = {}
			local debug        = false -- 調査時のみtrue
			local states       = dip_config.easy_super and input_states.easy or input_states.normal
			states             = debug and states[#states] or states[p.char]
			for ti, tbl in ipairs(states) do
				local old = p.old_input_states[ti]
				local addr = tbl.addr + p.input_offset
				local on, chg_remain = mem.r8(addr - 1), mem.r8(addr)
				local on_prev = on
				local max = (old and old.on_prev == on_prev) and old.max or chg_remain
				local input_estab = old and old.input_estab or false
				local charging, reset, force_reset = false, false, false

				-- コマンド種類ごとの表示用の補正
				if tbl.type == input_state_types.drill5 then
					force_reset = on > 1 or chg_remain > 0 or max > 0
					chg_remain, on, max = 0, 0, 0
				elseif tbl.type == input_state_types.step then
					on = math.max(on - 2, 0)
					if old then
						reset = old.on == 2 and old.chg_remain > 0
					end
				elseif tbl.type == input_state_types.faint then
					on = math.max(on - 2, 0)
					if old then
						reset = old.on == 1 and old.chg_remain > 0
						if on == 0 and chg_remain > 0 then
							force_reset = true
						end
					end
				elseif tbl.type == input_state_types.charge then
					if on == 1 and chg_remain == 0 then
						on = 3
					elseif on > 1 then
						on = on + 1
					end
					charging = on == 1
					if old then
						reset = old.on == #tbl.cmds and old.chg_remain > 0
					end
				elseif tbl.type == input_state_types.followup then
					on = math.max(on - 1, 0)
					on = (on == 1) and 0 or on
					if old then
						reset = old.on == #tbl.cmds and old.chg_remain > 0
						if on == 0 and chg_remain > 0 then
							force_reset = true
						end
					end
				elseif tbl.type == input_state_types.shinsoku then
					on = (on <= 2) and 0 or (on - 1)
					if old then
						reset = old.on == #tbl.cmds and old.chg_remain > 0
						if on == 0 and chg_remain > 0 then
							force_reset = true
						end
					end
				elseif tbl.type == input_state_types.todome then
					on = math.max(on - 1, 0)
					on = (on <= 1) and 0 or (on - 1)
					if old then
						reset = old.on > 0 and old.chg_remain > 0
						if on == 0 and chg_remain > 0 then
							force_reset = true
						end
					end
				elseif tbl.type == input_state_types.unknown then
					if old then
						reset = old.on > 0 and old.chg_remain > 0
					end
				else
					if old then
						reset = old.on == #tbl.cmds and old.chg_remain > 0
					end
				end
				if old then
					if p.char ~= old.char or on == 1 then
						input_estab = false
					else
						if 0 < tbl.id and tbl.id < 0x1E then
							reset = p.additional == tbl.exp_extab and p.spid == tbl.id or input_estab
						end
						if chg_remain == 0 and on == 0 and reset then
							input_estab = true
						end
					end
					if force_reset then
						input_estab = false
					end
				end
				local tmp = {
					char = p.char,
					chg_remain = chg_remain, -- 次の入力の受付猶予F
					on = on,
					on_prev = on_prev, -- 加工前の入力のすすみの数値
					tbl = tbl,
					debug = debug,
					input_estab = input_estab,
					charging = charging,
					max = max,
				}
				table.insert(p.input_states, tmp)
			end

			--フレーム数
			p.frame_gap      = p.frame_gap or 0
			p.last_frame_gap = p.last_frame_gap or 0
			p.on_hit         = p.on_hit or 0
			p.on_block       = p.on_block or 0
			p.hit_skip       = p.hit_skip or 0
			p.on_punish      = p.on_punish or 0

			if mem._0x10B862 ~= 0 then
				if p.state == 2 then
					p.on_punish = -1
				elseif p.state == 1 or p.state == 3 then
					if p.act_normal ~= true and p.old_state == 0 then
						-- 確定反撃フレームを記録
						p.on_punish = global.frame_number
					elseif p.old_state == 0 or p.old_state == 2 then
						p.on_punish = -1
					end
				else
					if p.act_normal ~= true and (p.on_punish + 60) >= global.frame_number then p.on_punish = -1 end
				end
				if mem.r8(p.addr.base + 0xAB) > 0 or p.ophit then p.hit_skip = 2 end
			end
			if p.state == 0 and p.act_normal ~= true and mem._0x10B862 ~= 0 then p.on_punish = -1 end

			-- 起き上がりフレーム
			if wakeup_acts[p.old_act] ~= true and wakeup_acts[p.act] == true then p.on_wakeup = global.frame_number end
			-- フレーム表示用処理
			p.act_frames          = p.act_frames or {}
			p.act_frames2         = p.act_frames2 or {}
			p.act_frames_total    = p.act_frames_total or 0
			p.muteki.act_frames   = p.muteki.act_frames or {}
			p.muteki.act_frames2  = p.muteki.act_frames2 or {}
			p.frm_gap.act_frames  = p.frm_gap.act_frames or {}
			p.frm_gap.act_frames2 = p.frm_gap.act_frames2 or {}

			p.old_act_data        = p.act_data or { name = "", type = act_types.any, }
			if p.char_data.acts and p.char_data.acts[p.act] then
				p.act_data = p.char_data.acts[p.act]
				p.act_1st  = p.char_data.act1sts[p.act] or false
				-- 技動作は滑りかBSかを付与する
				if p.slide_atk then
					p.act_data.name = p.act_data.slide_name
				elseif p.bs_atk then
					p.act_data.name = p.act_data.bs_name
				else
					p.act_data.name = p.act_data.normal_name
				end
				-- CAのときのみ開始動作として評価する
				if util.testbit(p.act_data.type, act_types.startup_if_ca) then
					p.act_1st = util.testbit(p.flag_cc, state_flag_cc._00)
				end
			else
				p.act_data = {
					name = (p.state == 1 or p.state == 3) and "やられ" or util.tohex(p.act),
					type = act_types.preserve | act_types.any,
				}
				p.act_1st  = false
			end
			if p.act_data.name == "やられ" then
				p.act_1st = false
			elseif p.act_data.name ~= "ダウン" and (p.state == 1 or p.state == 3) then
				p.act_data = {
					name = "やられ",
					type = act_types.preserve | act_types.any,
				}
				p.act_1st  = false
			end
			p.old_act_normal = p.act_normal
			-- ガード移行可否
			p.act_normal = nil
			if p.state == 2 or
				(p.flag_cc & 0xFFFFFF3F) ~= 0 or
				(p.flag_c0 & 0x03FFD723) ~= 0 or
				(mem.r8(p.addr.base + 0xB6) | p.flag_c4 | p.flag_c8) ~= 0 then
				p.act_normal = false
			else
				p.act_normal = true -- 移動中など
				p.act_normal = util.testbit(p.act_data.type, act_types.free | act_types.block)
			end
			global.all_act_normal = global.all_act_normal and p.act_normal

			-- アドレス保存
			if not p.bases[#p.bases] or p.bases[#p.bases].addr ~= p.base then
				table.insert(p.bases, {
					addr     = p.base,
					count    = 1,
					act_data = p.act_data,
					name     = p.act_data.name,
					pos1     = p.pos_total,
					pos2     = p.pos_total,
					xmov     = 0,
				})
			else
				local base = p.bases[#p.bases]
				base.count = base.count + 1
				base.pos2  = p.pos_total
				base.xmov  = base.pos2 - base.pos1
			end
			if 16 < #p.bases then
				--バッファ長調整
				table.remove(p.bases, 1)
			end

			-- 飛び道具の状態読取
			for _, fb in pairs(p.fireballs) do
				fb.old_act        = fb.act
				fb.gd_strength    = get_gd_strength(fb)
				fb.old_proc_act   = fb.proc_active
				fb.type_boxes     = {}
				fb.act_data_fired = p.act_data -- 発射したタイミングの行動ID
				fb.act_frames     = fb.act_frames or {}
				fb.act_frames2    = fb.act_frames2 or {}
				if fb.proc_active == true then --0x4E75 is rts instruction
					fb.atk_count = fb.atk_count or 0
					if p.char_data.fb1sts[fb.act] then
						p.act_data = chars[p.char].fireballs[fb.act]
						fb.act_data_fired = p.act_data -- 発射したタイミングの行動ID
						if fb.old_act ~= fb.act then
							p.act_1st = true
							p.update_act = global.frame_number
						end
					end
				end
				global.all_act_normal = global.all_act_normal and (fb.proc_active == false)
			end
			p.act_1st = p.update_act == global.frame_number and p.act_1st == true
			p.atk_count = p.act_1st == true and 1 or (p.atk_count + 1)
		end

		-- キャラと飛び道具への当たり判定の反映
		hitboxies, ranges = {}, {}                     -- ソート前の判定のバッファ
		for _, p in pairs(all_objects) do
			if p.char_data and (p.is_fireball ~= true or p.proc_active) then
				-- 判定表示前の座標補正
				p.x, p.y, p.flip_x = p.pos - screen.left, screen.top - p.pos_y - p.pos_z, (p.flip_x1 ~ p.flip_x2) > 0 and 1 or -1
				p.vulnerable = (p.invincible and p.invincible > 0) or p.hurt_invincible or p.on_vulnerable ~= global.frame_number
				p.grabbable = p.grabbable | (p.grabbable1 and p.grabbable2 and hitbox_grab_bits.baigaeshi or 0)
				p.hitboxies, p.ranges, p.hitbox_types = {}, {}, {} -- 座標補正後データ格納のためバッファのクリア

				-- 当たりとやられ判定判定
				for _, box in ipairs(p.boxies) do
					local type = fix_box_type(p, box) -- 属性はヒット状況などで変わるので都度解決する
					if not (hurt_boxies[type] and p.vulnerable) then
						local fixbox = fix_box_scale(p, box)
						fixbox.type = type
						table.insert(p.hitboxies, fixbox)
						table.insert(p.hitbox_types, type)
					end
				end

				-- 押し合い判定（本体のみ）
				if p.push_invincible and p.push_invincible == 0 and mem._0x10B862 == 0 then
					local box = fix_box_scale(p, get_push_box(p))
					table.insert(p.hitboxies, box)
					table.insert(p.hitbox_types, box.type)
				end

				if p.is_fireball ~= true then
					-- 投げ判定
					local last_throw_ids = {}
					for _, box in pairs(p.throw_boxies) do
						table.insert(p.hitboxies, box)
						table.insert(p.hitbox_types, box.type)
						table.insert(last_throw_ids, { char = p.char, id = box.id })
					end
					if 0 < #last_throw_ids then
						p.throw_boxies, p.last_throw_ids = {}, last_throw_ids
					elseif p.last_throw_ids then
						for _, item in ipairs(p.last_throw_ids) do
							if item.char == p.char then
								local box = get_throwbox(p, item.id)
								box.type = box_types.push
								table.insert(p.hitboxies, box)
							end
						end
					end

					-- 詠酒を発動される範囲
					if p.esaka and p.esaka > 0 then
						-- 内側に太線を引きたいのでflipを反転する
						p.esaka_range = p.calc_range_x(p.esaka)
						table.insert(p.ranges, { label = string.format("E%sP%s", p.num, p.esaka_type), x = p.esaka_range, y = p.y, flip_x = -p.flip_x, within = p.within(p.x, p.esaka_range) })
					end

					-- 座標
					table.insert(p.ranges, { label = string.format("%sP", p.num), x = p.x, y = p.y, flip_x = p.input_side })

					-- 地上通常技かライン移動技の遠近判断距離
					if p.pos_y + p.pos_frc_y == 0 then
						for label, close_far in pairs(p.char_data.close_far[p.sway_status]) do
							local x1, x2 = close_far.x1 == 0 and p.x or p.calc_range_x(close_far.x1), p.calc_range_x(close_far.x2)
							-- 内側に太線を引きたいのでflipを反転する
							table.insert(p.ranges, { label = label, x = x2, y = p.y, flip_x = -p.flip_x, within = p.within(x1, x2) })
						end
					end
				end

				-- 全体バッファに保存する
				if p.disp_hitbox or (p.parent and p.parent.disp_hitbox) then hitboxies = util.table_add_all(hitboxies, p.hitboxies) end
				if p.disp_range or (p.parent and p.parent.disp_range) then ranges = util.table_add_all(ranges, p.ranges) end
			end
		end
		table.sort(hitboxies, hitboxies_order)
		table.sort(ranges, ranges_order)

		-- フレーム表示などの前処理1
		for _, p in ipairs(players) do
			local op         = p.op

			--フレーム数
			p.frame_gap      = p.frame_gap or 0
			p.last_frame_gap = p.last_frame_gap or 0
			if mem._0x10B862 ~= 0 then
				local hitstun, blockstun = 0, 0
				if p.ophit and p.ophit.hitboxies then
					for _, box in pairs(p.ophit.hitboxies) do
						if box.type.kind == box_kinds.attack then
							hitstun, blockstun = box.hitstun, box.blockstun
							break
						end
					end
				end
				local on_hit = p.on_hit == global.frame_number
				local on_block = p.on_block == global.frame_number
				if p.ophit and (on_block or on_hit) then
					-- ガード時硬直, ヒット時硬直
					p.last_blockstun = on_block and blockstun or hitstun
				end
			elseif op.char == 20 and op.act == 0x00AF and op.act_count == 0x00 and op.act_frame == 0x09 then
				-- デンジャラススルー専用
				p.last_blockstun = p.hitstop_remain + 2
			elseif op.char == 5 and op.act == 0x00A7 and op.act_count == 0x00 and op.act_frame == 0x06 then
				-- 裏雲隠し専用
				p.last_blockstun = p.knock_back2 + 3
			end
		end

		-- フレーム表示などの前処理2
		for _, p in ipairs(players) do
			-- 起き上がりと投げやられ演出の停止はフレーム差の計算に邪魔なので停止扱いしない
			local stop = p.hitstop_remain ~= 0 and util.testbit(p.flag_cc,
				state_flag_cc._03 |                  -- 必殺投げやられ
				state_flag_cc._08 |                  -- 投げ派生やられ
				state_flag_cc._09 |                  -- つかみ投げやられ
				state_flag_cc._10 |                  -- 投げられ
				state_flag_cc._27 |                  -- 投げ追撃
				state_flag_cc._30 |                  -- 空中投げ
				state_flag_cc._31 |                  -- 投げ
				state_flag_cc._23                    -- 起き上がり
			) ~= true
			if util.testbit(p.flag_c0, state_flag_c0._01) and -- ダウン
				util.testbit(p.flag_cc, state_flag_cc._13) -- ダウン
			then
				stop = false
			end

			p.old_skip_frame = p.skip_frame                 --停止演出のチェック
			p.skip_frame = p.hit_skip ~= 0 or stop or global.sp_skip_frame
			if p.hit_skip ~= 0 or global.sp_skip_frame then -- 停止フレームはフレーム計算しない
				if p.hit_skip ~= 0 then p.hit_skip = p.hit_skip - 1 end --ヒットストップの減算
			end

			-- ヒットフレームの判断
			if p.state ~= 1 and p.state ~= 3 then
				p.hit1 = 0
			elseif p.on_hit == global.frame_number then
				p.hit1 = 1 -- 1ヒット確定
			end
			-- 停止時間なしのヒットガードのためelseifで繋げない
			if (p.hit1 == 1 and p.skip_frame == false) or
				((p.state == 1 or p.state == 3) and p.old_skip_frame == true and p.skip_frame == false) then
				p.hit1 = 2 -- ヒット後のヒットストップ解除フレームの記録
				p.on_hit1 = global.frame_number
			end

			if p.state ~= 2 then
				p.block1 = 0 -- ガードフレームの判断
			elseif p.on_block == global.frame_number then
				p.block1 = 1 -- 1ガード確定
			end

			-- 停止時間なしのヒットガードのためelseifで繋げない
			if (p.block1 == 1 and p.skip_frame == false) or
				(p.state == 2 and p.old_skip_frame == true and p.skip_frame == false) then
				p.block1 = 2 -- ガード後のヒットストップ解除フレームの記録
				p.on_block1 = global.frame_number
			end
		end

		-- キャラ間の距離
		prev_space, p_space = (p_space ~= 0) and p_space or prev_space, players[1].pos - players[2].pos

		-- プレイヤー操作事前設定（それぞれCPUか人力か入れ替えか）
		-- キー入力の取得（1P、2Pの操作を入れ替えていたりする場合もあるのでモード判定と一緒に処理する）
		local reg_p1cnt     = mem.r8(players[1].addr.reg_pcnt)
		local reg_p2cnt     = mem.r8(players[2].addr.reg_pcnt)
		local reg_st_b      = mem.r8(players[1].addr.reg_st_b)
		for i, p in ipairs(players) do
			-- プレイヤー vs プレイヤー, プレイヤー vs CPU, CPU vs プレイヤー, 1P&2P入れ替え, レコード, 同じ位置でリプレイ, その場でリプレイ
			if global.dummy_mode == 2 then
				p.control = i == 1 and i or 3
			elseif global.dummy_mode == 3 then
				p.control = i == 1 and 3 or i
			elseif global.dummy_mode == 4 or global.dummy_mode == 5 then
				p.control = 3 - i
			else
				p.control = i
			end
			mem.w16(p.addr.control, 0x0101 * p.control) -- Human 1 or 2, CPU 3

			-- キー入力
			if p.control == 1 then
				p.reg_pcnt = reg_p1cnt
				p.reg_st_b = reg_st_b
			elseif p.control == 2 then
				p.reg_pcnt = reg_p2cnt
				p.reg_st_b = reg_st_b
			else
				p.reg_pcnt = 0xFF
				p.reg_st_b = 0xFF
			end
		end
		apply_1p2p_active()

		-- 全キャラ特別な動作でない場合はフレーム記録しない
		if global.disp_normal_frms == 1 or (global.disp_normal_frms == 2 and global.all_act_normal == false) then
			-- キャラ、弾ともに通常動作状態ならリセットする
			if global.disp_normal_frms == 2 and global.old_all_act_normal == true then
				for _, p in ipairs(players) do
					p.act_frames_total = 0
					p.act_frames = {}
					p.act_frames2 = {}
					p.frm_gap.act_frames = {}
					p.frm_gap.act_frames2 = {}
					p.hist_frame_gap = {}
					p.muteki.act_frames = {}
					p.muteki.act_frames2 = {}
					for _, fb in pairs(p.fireballs) do
						fb.act_frames = {}
						fb.act_frames2 = {}
					end
					p.frame_gap      = 0
					p.last_frame_gap = 0
				end
			end

			-- フレームデータの構築処理
			for _, p in ipairs(players) do
				local _, chg_act_name = proc_act_frame(p)
				proc_muteki_frame(p, chg_act_name)
				proc_frame_gap(p, chg_act_name)
				proc_fb_frame(p)
			end

			--1Pと2Pともにフレーム数が多すぎる場合は加算をやめる
			fix_max_framecount()
		end

		-- キーディス用の処理
		for i, p in ipairs(players) do
			local p1                         = i == 1
			local op                         = p.op
			local key_now                    = p.key_now
			local lever, lever_no
			local btn_a, btn_b, btn_c, btn_d = false, false, false, false

			-- 入力表示用の情報構築
			key_now.d                        = (p.reg_pcnt & 0x80) == 0x00 and posi_or_pl1(key_now.d) or nega_or_mi1(key_now.d)           -- Button D
			key_now.c                        = (p.reg_pcnt & 0x40) == 0x00 and posi_or_pl1(key_now.c) or nega_or_mi1(key_now.c)           -- Button C
			key_now.b                        = (p.reg_pcnt & 0x20) == 0x00 and posi_or_pl1(key_now.b) or nega_or_mi1(key_now.b)           -- Button B
			key_now.a                        = (p.reg_pcnt & 0x10) == 0x00 and posi_or_pl1(key_now.a) or nega_or_mi1(key_now.a)           -- Button A
			key_now.rt                       = (p.reg_pcnt & 0x08) == 0x00 and posi_or_pl1(key_now.rt) or nega_or_mi1(key_now.rt)         -- Right
			key_now.lt                       = (p.reg_pcnt & 0x04) == 0x00 and posi_or_pl1(key_now.lt) or nega_or_mi1(key_now.lt)         -- Left
			key_now.dn                       = (p.reg_pcnt & 0x02) == 0x00 and posi_or_pl1(key_now.dn) or nega_or_mi1(key_now.dn)         -- Down
			key_now.up                       = (p.reg_pcnt & 0x01) == 0x00 and posi_or_pl1(key_now.up) or nega_or_mi1(key_now.up)         -- Up
			key_now.sl                       = (p.reg_st_b & (p1 and 0x02 or 0x08)) == 0x00 and posi_or_pl1(key_now.sl) or nega_or_mi1(key_now.sl) -- Select
			key_now.st                       = (p.reg_st_b & (p1 and 0x01 or 0x04)) == 0x00 and posi_or_pl1(key_now.st) or nega_or_mi1(key_now.st) -- Start
			if (p.reg_pcnt & 0x05) == 0x00 then
				lever, lever_no = "_7", 7
			elseif (p.reg_pcnt & 0x09) == 0x00 then
				lever, lever_no = "_9", 9
			elseif (p.reg_pcnt & 0x06) == 0x00 then
				lever, lever_no = "_1", 1
			elseif (p.reg_pcnt & 0x0A) == 0x00 then
				lever, lever_no = "_3", 3
			elseif (p.reg_pcnt & 0x01) == 0x00 then
				lever, lever_no = "_8", 8
			elseif (p.reg_pcnt & 0x02) == 0x00 then
				lever, lever_no = "_2", 2
			elseif (p.reg_pcnt & 0x04) == 0x00 then
				lever, lever_no = "_4", 4
			elseif (p.reg_pcnt & 0x08) == 0x00 then
				lever, lever_no = "_6", 6
			else
				lever, lever_no = "_N", 5
			end
			if (p.reg_pcnt & 0x10) == 0x00 then lever, btn_a = lever .. "_A", true end
			if (p.reg_pcnt & 0x20) == 0x00 then lever, btn_b = lever .. "_B", true end
			if (p.reg_pcnt & 0x40) == 0x00 then lever, btn_c = lever .. "_C", true end
			if (p.reg_pcnt & 0x80) == 0x00 then lever, btn_d = lever .. "_D", true end
			-- GG風キーディスの更新
			table.insert(p.ggkey_hist, { l = lever_no, a = btn_a, b = btn_b, c = btn_c, d = btn_d, })
			while 60 < #p.ggkey_hist do table.remove(p.ggkey_hist, 1) end --バッファ長調整
			-- キーログの更新
			if p.key_hist[#p.key_hist] ~= lever then
				for k = 2, #p.key_hist do
					p.key_hist[k - 1], p.key_frames[k - 1] = p.key_hist[k], p.key_frames[k]
				end
				if 16 ~= #p.key_hist then
					p.key_hist[#p.key_hist + 1], p.key_frames[#p.key_frames + 1] = lever, 1
				else
					p.key_hist[#p.key_hist], p.key_frames[#p.key_frames] = lever, 1
				end
			else
				local frmcount = p.key_frames[#p.key_frames]
				--フレーム数が多すぎる場合は加算をやめる
				p.key_frames[#p.key_frames] = (999 < frmcount) and 1000 or (frmcount + 1)
			end

			do_recover(p, op)
		end

		-- プレイヤー操作
		for i, p in ipairs(players) do
			local op = p.op
			if p.control == 1 or p.control == 2 then
				--前進とガード方向
				local sp = p_space == 0 and prev_space or p_space
				sp = i == 1 and sp or (sp * -1)
				local front_back = {
					[data.cmd_types.front] = 0 < sp and data.cmd_types._4 or data.cmd_types._6,
					[data.cmd_types.back] = 0 < sp and data.cmd_types._6 or data.cmd_types._4,
				}
				local check_cmd_hook = function()
					p.bs_hook = (p.bs_hook and p.bs_hook.cmd_type) and p.bs_hook or { cmd_type = data.cmd_types._5 }
				end
				local add_cmd_hook = function(input)
					check_cmd_hook()
					input = front_back[input] or input
					p.bs_hook.cmd_type = p.bs_hook.cmd_type & data.cmd_masks[input]
					p.bs_hook.cmd_type = p.bs_hook.cmd_type | input
				end
				local clear_cmd_hook = function(mask)
					check_cmd_hook()
					mask = 0xFF ~ (front_back[mask] or mask)
					p.bs_hook.cmd_type = p.bs_hook.cmd_type & mask
				end
				local reset_cmd_hook = function(input)
					check_cmd_hook()
					input = front_back[input] or input
					p.bs_hook = { cmd_type = input }
				end
				local is_block_cmd_hook = function()
					return p.bs_hook and p.bs_hook.cmd_type and
						util.testbit(p.bs_hook.cmd_type, front_back[data.cmd_types.back]) and
						util.testbit(p.bs_hook.cmd_type, data.cmd_types._2) ~= true
				end
				local reset_sp_hook = function(hook) p.bs_hook = hook end
				reset_sp_hook()

				-- レコード中、リプレイ中は行動しないためのフラグ
				local in_rec_replay = true
				if global.dummy_mode == 5 then
					in_rec_replay = false
				elseif global.dummy_mode == 6 then
					if global.rec_main == rec_play and recording.player == p.control then
						in_rec_replay = false
					end
				end

				-- 立ち, しゃがみ, ジャンプ, 小ジャンプ, スウェー待機
				-- { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" },
				-- レコード中、リプレイ中は行動しない
				if in_rec_replay then
					if p.sway_status == 0x00 then
						if p.dummy_act == 2 then
							reset_cmd_hook(data.cmd_types._2) -- しゃがみ
						elseif p.dummy_act == 3 then
							reset_cmd_hook(data.cmd_types._8) -- ジャンプ
						elseif p.dummy_act == 4 and not util.testbit(p.flag_c0, state_flag_c0._17, true) then
							reset_cmd_hook(data.cmd_types._8) -- 地上のジャンプ移行モーション以外だったら上入力
						elseif p.dummy_act == 5 and op.sway_status == 0x00 and p.state == 0 then
							reset_cmd_hook(data.cmd_types._2d) -- スウェー待機(スウェー移動)
						end
					elseif p.dummy_act == 5 and p.in_sway_line then
						reset_cmd_hook(data.cmd_types._8) -- スウェー待機
					end
				end

				local act_type = op.act_data.type
				for _, fb in pairs(op.fireballs) do
					if fb.proc_active and fb.act_data then act_type = act_type | fb.act_data.type end
				end
				-- リプレイ中は自動ガードしない
				if util.testbit(act_type, act_types.attack) and in_rec_replay then
					if jump_acts[p.act] then
						clear_cmd_hook(data.cmd_types._8)
					end
					if p.dummy_gd == dummy_gd_type.fixed then
						-- 常時（ガード方向はダミーモードに従う）
						add_cmd_hook(data.cmd_types.back)
					elseif p.dummy_gd == dummy_gd_type.auto or     -- オート
						p.dummy_gd == dummy_gd_type.bs or          -- ブレイクショット
						(p.dummy_gd == dummy_gd_type.random and p.random_boolean) or -- ランダム
						(p.dummy_gd == dummy_gd_type.hit1 and p.next_block) or -- 1ヒットガード
						(p.dummy_gd == dummy_gd_type.block1)       -- 1ガード
					then
						-- 中段から優先
						if util.testbit(act_type, act_types.overhead, true) then
							clear_cmd_hook(data.cmd_types._2)
						elseif util.testbit(act_type, act_types.low_attack, true) then
							add_cmd_hook(data.cmd_types._2)
						end
						if p.dummy_gd == dummy_gd_type.block1 and p.next_block ~= true then
							-- 1ガードの時は連続ガードの上下段のみ対応させる
							clear_cmd_hook(data.cmd_types.back)
						else
							add_cmd_hook(data.cmd_types.back)
						end
					end
					p.backstep_killer = is_block_cmd_hook()
				elseif p.backstep_killer then
					-- コマンド入力状態を無効にしてバクステ暴発を防ぐ
					local bs_addr = dip_config.easy_super and p.char_data.easy_bs_addr or p.char_data.bs_addr
					mem.w8(p.input_offset + bs_addr, 0x00)
					p.backstep_killer = false
				end

				-- 次のガード要否を判断する
				if p.dummy_gd == dummy_gd_type.hit1 then
					-- 1ヒットガードのときは次ガードすべきかどうかの状態を切り替える
					if global.frame_number == p.on_hit then
						p.next_block = true -- ヒット時はガードに切り替え
						p.next_block_ec = 75 -- カウンター初期化
					elseif global.frame_number == p.on_block then
						p.next_block = false
					end
					if p.next_block == false then
						-- カウンター消費しきったらヒットするように切り替える
						p.next_block_ec = p.next_block_ec and (p.next_block_ec - 1) or 0
						if p.next_block_ec == 0 then
							p.next_block = false
						end
					end
				elseif p.dummy_gd == dummy_gd_type.block1 then
					if p.block1 == 0 and p.next_block_ec == 75 then
						p.next_block = true
					elseif p.block1 == 1 then
						p.next_block = true
						p.next_block_ec = 75 -- カウンター初期化
					elseif p.block1 == 2 and global.frame_number <= (p.on_block1 + global.next_block_grace) then
						p.next_block = true
					else
						-- カウンター消費しきったらガードするように切り替える
						p.next_block_ec = p.next_block_ec and (p.next_block_ec - 1) or 0
						if p.next_block_ec == 0 then
							p.next_block = true
							p.next_block_ec = 75 -- カウンター初期化
							p.block1 = 0
						elseif global.frame_number == p.on_block then
							p.next_block_ec = 75 -- カウンター初期化
							p.next_block = false
						else
							p.next_block = false
						end
					end
					if global.frame_number == p.on_hit then
						-- ヒット時はガードに切り替え
						p.next_block = true
						p.next_block_ec = 75 -- カウンター初期化
						p.block1 = 0
					end
				end

				--挑発中は前進
				if p.fwd_prov and util.testbit(op.act_data.type, act_types.provoke) then
					add_cmd_hook(data.cmd_types.front)
				end

				-- ガードリバーサル
				if global.dummy_rvs_cnt == 1 then
					p.gd_rvs_enabled = true
				elseif p.gd_rvs_enabled ~= true and p.dummy_wakeup == wakeup_type.rvs and p.dummy_rvs and p.on_block == global.frame_number then
					p.rvs_count = (p.rvs_count < 1) and 1 or p.rvs_count + 1
					if global.dummy_rvs_cnt <= p.rvs_count and p.dummy_rvs then
						p.gd_rvs_enabled = true
						p.rvs_count = -1
					end
				elseif p.gd_rvs_enabled and p.state ~= 2 then
					-- ガード状態が解除されたらリバサ解除
					p.gd_rvs_enabled = false
				end

				-- TODO: ライン送られのリバーサルを修正する。猶予1F
				-- print(p.state, p.knock_back1, p.knock_back2, p.knock_back3, p.hitstop_remain, rvs_types.in_knock_back, p.last_blockstun, string.format("%x", p.act), p.act_count, p.act_frame)
				-- ヒットストップ中は無視
				if not p.skip_frame then
					-- なし, リバーサル, テクニカルライズ, グランドスウェー, 起き上がり攻撃
					if rvs_wake_types[p.dummy_wakeup] and p.dummy_rvs then
						-- ダウン起き上がりリバーサル入力
						if wakeup_acts[p.act] and (p.char_data.wakeup_frms - 3) <= (global.frame_number - p.on_wakeup) then
							input_rvs(rvs_types.on_wakeup, p, string.format("[Reversal] wakeup %s %s",
								p.char_data.wakeup_frms, (global.frame_number - p.on_wakeup)))
						end
						-- 着地リバーサル入力（やられの着地）
						if 1 < p.pos_y_down and p.old_pos_y > p.pos_y and p.in_air ~= true then
							input_rvs(rvs_types.knock_back_landing, p, "[Reversal] blown landing")
						end
						-- 着地リバーサル入力（通常ジャンプの着地）
						if p.act == 0x9 and (p.act_frame == 2 or p.act_frame == 0) then
							input_rvs(rvs_types.jump_landing, p, "[Reversal] jump landing")
						end
						-- リバーサルじゃない最速入力
						if p.state == 0 and p.act_data.name ~= "やられ" and p.old_act_data.name == "やられ" and p.knock_back1 == 0 then
							input_rvs(rvs_types.knock_back_recovery, p, "[Reversal] blockstun 1")
						end
						-- のけぞりのリバーサル入力
						if (p.state == 1 or (p.state == 2 and p.gd_rvs_enabled)) and p.hitstop_remain == 0 then
							-- のけぞり中のデータをみてのけぞり終了の2F前に入力確定する
							-- 奥ラインへ送った場合だけ無視する（p.act ~= 0x14A）
							if p.knock_back3 == 0x80 and p.knock_back1 == 0 and p.act ~= 0x14A then
								-- のけぞり中のデータをみてのけぞり終了の2F前に入力確定する1
								input_rvs(rvs_types.in_knock_back, p, "[Reversal] blockstun 2")
							elseif p.old_knock_back1 > 0 and p.knock_back1 == 0 then
								-- のけぞり中のデータをみてのけぞり終了の2F前に入力確定する2
								input_rvs(rvs_types.in_knock_back, p, "[Reversal] blockstun 3")
							end
							-- デンジャラススルー用
							if p.knock_back3 == 0x0 and p.hitstop_remain < 3 and p.base == 0x34538 then
								input_rvs(rvs_types.dangerous_through, p, "[Reversal] blockstun 4")
							end
						elseif p.state == 3 and p.hitstop_remain == 0 and p.knock_back2 <= 1 then
							-- 当身うち空振りと裏雲隠し用
							input_rvs(rvs_types.atemi, p, "[Reversal] blockstun 5")
						end
						-- 奥ラインへ送ったあとのリバサ
						if p.act == 0x14A and (p.act_count == 4 or p.act_count == 5) and p.old_act_frame == 0 and p.act_frame == 0 and p.throw_timer == 0 then
							input_rvs(rvs_types.in_knock_back, p, string.format("[Reversal] plane shift %x %x %x %s", p.act, p.act_count, p.act_frame, p.throw_timer))
						end
						-- テクニカルライズのリバサ
						if p.act == 0x2C9 and p.act_count == 2 and p.act_frame == 0 and p.throw_timer == 0 then
							input_rvs(rvs_types.in_knock_back, p, string.format("[Reversal] tech-rise1 %x %x %x %s", p.act, p.act_count, p.act_frame, p.throw_timer))
						end
						if p.act == 0x2C9 and p.act_count == 0 and p.act_frame == 2 and p.throw_timer == 0 then
							input_rvs(rvs_types.in_knock_back, p, string.format("[Reversal] tech-rise2 %x %x %x %s", p.act, p.act_count, p.act_frame, p.throw_timer))
						end
						-- グランドスウェー
						local sway_act_frame = 0
						if p.char_data.sway_act_counts ~= 0 then
							sway_act_frame = 1
						end
						if p.act == 0x13E and p.act_count == p.char_data.sway_act_counts and p.act_frame == sway_act_frame then
							input_rvs(rvs_types.in_knock_back, p, string.format("[Reversal] ground sway %x %x %x %s", p.act, p.act_count, p.act_frame, p.throw_timer))
						end
					end
				end

				-- 自動ダウン追撃
				if op.act == 0x190 or op.act == 0x192 or op.act == 0x18E or op.act == 0x13B then
					if global.auto_input.otg_thw and p.char_data.otg_throw then
						reset_sp_hook(p.char_data.otg_throw) -- 自動ダウン投げ
					end
					if global.auto_input.otg_atk and p.char_data.otg_stomp then
						reset_sp_hook(p.char_data.otg_stomp) -- 自動ダウン攻撃
					end
				end

				-- 自動投げ追撃
				if global.auto_input.thw_otg then
					if p.char == 3 and p.act == 0x70 then
						reset_cmd_hook(data.cmd_types._2c) -- ジョー
					elseif p.act == 0x6D and p.char_data.add_throw then
						reset_sp_hook(p.char_data.add_throw) -- ボブ、ギース、双角、マリー
					elseif p.char == 22 and p.act == 0x9F and p.act_count == 2 and p.act_frame >= 0 and p.char_data.add_throw then
						reset_sp_hook(p.char_data.add_throw) -- 閃里肘皇・心砕把
					end
				end

				-- 自動超白龍
				if 1 < global.auto_input.pairon and p.char == 22 then
					if p.act == 0x43 and p.act_count >= 0 and p.act_count <= 3 and p.act_frame >= 0 and 2 == global.auto_input.pairon then
						reset_sp_hook(data.rvs_bs_list[p.char][28]) -- 超白龍
					elseif p.act == 0x43 and p.act_count == 3 and p.act_count <= 3 and p.act_frame >= 0 and 3 == global.auto_input.pairon then
						reset_sp_hook(data.rvs_bs_list[p.char][28]) -- 超白龍
					elseif p.act == 0xA1 and p.act_count == 6 and p.act_frame >= 0 then
						reset_sp_hook(data.rvs_bs_list[p.char][21]) -- 閃里肘皇・貫空
					end
					if p.act == 0xFE then
						reset_sp_hook(data.rvs_bs_list[p.char][29]) -- 超白龍2
					end
				end

				-- ブレイクショット
				if p.dummy_gd == dummy_gd_type.bs and p.on_block == global.frame_number then
					p.bs_count = (p.bs_count < 1) and 1 or p.bs_count + 1
					if global.dummy_bs_cnt <= p.bs_count and p.dummy_bs then
						reset_sp_hook(p.dummy_bs)
						p.bs_count = -1
					end
				end
			end
		end

		-- レコード＆リプレイ
		if global.dummy_mode == 5 or global.dummy_mode == 6 then
			local prev_rec_main, called = nil, {}
			repeat
				prev_rec_main = global.rec_main
				called[prev_rec_main or "NOT DEFINED"] = true
				global.rec_main(next_joy)
			until global.rec_main == prev_rec_main or called[global.rec_main] == true
		end

		-- ジョイスティック入力の反映
		for _, joy in ipairs(use_joy) do
			if next_joy[joy.field] ~= nil then
				ioports[joy.port].fields[joy.field]:set_value(next_joy[joy.field] and 1 or 0)
			end
		end

		-- Y座標強制
		for _, p in ipairs(players) do
			if p.force_y_pos > 1 then
				mem.w16i(p.addr.pos_y, force_y_pos[p.force_y_pos])
			end
		end
		-- X座標同期とY座標をだいぶ下に
		if global.sync_pos_x ~= 1 then
			local from = global.sync_pos_x - 1
			local to   = 3 - from
			mem.w16i(players[to].addr.pos, players[from].pos)
			mem.w16i(players[to].addr.pos_y, players[from].pos_y - 124)
		end

		-- 強制ポーズ処理
		global.pause = false
		-- 判定が出たらポーズさせる
		for _, box in ipairs(hitboxies) do
			if (box.type.kind == box_kinds.throw and global.pause_hitbox == 2) or
				((box.type.kind == box_kinds.attack or box.type.kind == box_kinds.parry) and global.pause_hitbox == 3) then
				global.pause = true
				break
			end
		end
		for _, p in ipairs(players) do
			-- ヒット時にポーズさせる
			if p.state ~= 0 and p.state ~= p.old_state and global.pause_hit > 0 then
				-- 1:OFF, 2:ON, 3:ON:やられのみ 4:ON:投げやられのみ 5:ON:打撃やられのみ 6:ON:ガードのみ
				if global.pause_hit == 2 or
					(global.pause_hit == 6 and p.state == 2) or
					(global.pause_hit == 5 and p.state == 1) or
					(global.pause_hit == 4 and p.state == 3) or
					(global.pause_hit == 3 and p.state ~= 2) then
					global.pause = true
				end
			end
		end
	end

	menu.tra_main.draw = function()
		-- メイン処理
		if in_match then
			-- 順番に判定表示（キャラ、飛び道具）
			for _, range in ipairs(ranges) do draw_range(range) end -- 座標と範囲
			for _, box in ipairs(hitboxies) do draw_hitbox(box) end -- 各種判定

			-- スクショ保存
			for _, p in ipairs(players) do
				local chg_y = p.chg_air_state ~= 0
				local chg_act = p.old_act_normal ~= p.act_normal
				local chg_hit = p.chg_hitbox_frm == global.frame_number
				local chg_hurt = p.chg_hurtbox_frm == global.frame_number
				local chg_sway = p.on_sway_line == global.frame_number or p.on_main_line == global.frame_number
				for _, fb in pairs(p.fireballs) do
					if fb.chg_hitbox_frm == global.frame_number then
						chg_hit = true
					end
					if fb.chg_hurtbox_frm == global.frame_number then
						chg_hurt = true
					end
				end
				local chg_hitbox = p.act_normal ~= true and (p.atk_count == 1 or chg_act or chg_y or chg_hit or chg_hurt or chg_sway)

				-- 判定が変わったらポーズさせる
				if chg_hitbox and global.pause_hitbox == 4 then
					global.pause = true
				end

				-- 画像保存 1:OFF 2:1P動作 3:2P動作
				if (chg_hitbox or p.state ~= 0) and global.save_snapshot > 1 then
					-- 画像保存先のディレクトリ作成
					local frame_group = p.act_frames2[#p.act_frames2]
					local name, sub_name, dir_name = frame_group[#frame_group].name, "_", base_path() .. "/capture"
					util.mkdir(dir_name)
					dir_name = dir_name .. "/" .. p.char_data.names2
					util.mkdir(dir_name)
					if p.slide_atk then sub_name = "_SLIDE_" elseif p.bs_atk then sub_name = "_BS_" end
					name = string.format("%s%s%04x_%s_%03d", p.char_data.names2, sub_name, p.act_data.id_1st or 0, name, p.atk_count)
					dir_name = dir_name .. string.format("/%04x", p.act_data.id_1st or 0)
					util.mkdir(dir_name)

					-- ファイル名を設定してMAMEのスクショ機能で画像保存
					local filename, dowrite = dir_name .. "/" .. name .. ".png", false
					if util.is_file(filename) then
						if global.save_snapshot == 3 then
							dowrite = true
							os.remove(filename)
						end
					else
						dowrite = true
					end
					if dowrite then
						scr:snapshot(filename)
						print("save " .. filename)
					end
				end
			end

			-- コマンド入力表示
			for i, p in ipairs(players) do
				-- コマンド入力表示 1:OFF 2:ON 3:ログのみ 4:キーディスのみ
				if p.disp_cmd == 2 or p.disp_cmd == 3 then
					for k = 1, #p.key_hist do draw_cmd(i, k, p.key_frames[k], p.key_hist[k]) end
					draw_cmd(i, #p.key_hist + 1, 0, "")
				end
			end

			-- ベースアドレス表示
			for i, p in ipairs(players) do
				for k = 1, #p.bases do
					local bk = p.bases[k]
					if p.disp_base then draw_base(i, k, bk.count, bk.addr, bk.name, bk.xmov) end
				end
			end
			-- ダメージとコンボ表示
			for i, p in ipairs(players) do
				local p1, op, combo_label1, combo_label2, combo_label3, sts_label = i == 1, p.op, {}, {}, {}, {}
				for _, xp in util.sorted_pairs(util.hash_add_all({ [p.addr.base] = p }, p.fireballs)) do
					if xp.num or xp.proc_active then
						table.insert(sts_label, string.format("Damage %3s/%1s  Stun %2s/%2s Fra.", xp.pure_dmg or 0, xp.chip_dmg or 0, xp.pure_st or 0, xp.pure_st_tm or 0))
						table.insert(sts_label, string.format("HitStop %2s/%2s HitStun %2s/%2s", xp.hitstop or 0, xp.blockstop or 0, xp.hitstun or 0, xp.blockstun or 0))
						table.insert(sts_label, string.format("%2s", data.hit_effect_name(xp.effect)))
						local grabl = ""
						for _, t in ipairs(hitbox_grab_types) do grabl = grabl .. (util.testbit(xp.grabbable, t.value, true) and t.label or "- ") end
						table.insert(sts_label, string.format("Grab %-s", grabl))
						if xp.num then
							table.insert(sts_label, string.format("Pow. %2s/%2s/%2s Rev.%2s Abs.%2s",
								p.pow_up_direct == 0 and p.pow_up or p.pow_up_direct or 0, p.pow_up_hit or 0, p.pow_up_gd or 0, p.pow_revenge or 0, p.pow_absorb or 0))
							table.insert(sts_label, string.format("Inv.%2s  BS-Pow.%2s BS-Inv.%2s", xp.sp_invincible or 0, xp.bs_pow or 0, xp.bs_invincible or 0))
							table.insert(sts_label, string.format("%s/%s Hit  Esaka %s %s", xp.max_hit_nm or 0, xp.max_hit_dn or 0, xp.esaka or 0, p.esaka_type or ""))
							table.insert(sts_label, string.format("Cancel %-2s/%-2s Teching %s", xp.repeatable and "Ch" or "", xp.cancelable and "Sp" or "",
								xp.forced_down or xp.in_bs and "No" or "Yes"))
						elseif xp.proc_active then
							table.insert(sts_label, string.format("%s/%s Hit  Fireball-Lv. %s", xp.max_hit_nm or 0, xp.max_hit_dn or 0, xp.fireball_rank or 0))
						end
						for _, _, blockable in find(xp.hitboxies, function(box) return box.blockable end) do
							table.insert(sts_label, string.format("Box Top %3s Bottom %3s", blockable.real_top, blockable.real_bottom))
							table.insert(sts_label, string.format("Main %-5s  Sway %-5s", data.top_type_name(blockable.main), data.top_type_name(blockable.sway)))
							table.insert(sts_label, string.format("Punish %-9s", data.top_punish_name(blockable.punish)))
						end
					end
				end
				local last_damage_scaling = 100.00
				if op.last_damage_scaling1 and op.last_damage_scaling2 then
					last_damage_scaling = (op.last_damage_scaling1 * op.last_damage_scaling2) * 100
				end
				if op.combo_update == global.frame_number then
					local stun, timer                       = math.max(op.stun - op.combo_start_stun), math.max(op.stun_timer - op.combo_start_stun_timer, 0)
					op.combo_stun, op.last_stun             = stun, math.max(stun - op.combo_stun, 0)
					op.combo_stun_timer, op.last_stun_timer = timer, math.max(timer - op.combo_stun_timer, 0)
					op.max_combo                            = math.max(op.max_combo or 0, op.last_combo)
					op.max_combo_pow                        = math.max(op.max_combo_pow or 0, op.combo_pow)
					op.max_combo_stun                       = math.max(op.max_combo_stun or 0, op.combo_stun)
					op.max_combo_stun_timer                 = math.max(op.max_combo_stun_timer or 0, op.combo_stun_timer)
				end
				table.insert(combo_label2, string.format("%3s>%3s(%6s%%)", op.last_damage, op.last_damage_scaled, last_damage_scaling))
				table.insert(combo_label2, string.format("%3s(+%3s)", op.combo_damage or 0, op.last_damage_scaled))
				table.insert(combo_label2, string.format("%3s", op.last_combo))
				table.insert(combo_label2, string.format("%3s(+%3s)", op.combo_stun or 0, op.last_stun))
				table.insert(combo_label2, string.format("%3s(+%3s)", op.combo_stun_timer or 0, op.last_stun_timer or 0))
				table.insert(combo_label2, string.format("%3s(+%3s)", op.combo_pow or 0, p.last_pow_up or 0))
				table.insert(combo_label3, "")
				table.insert(combo_label3, string.format("%3s", op.max_combo_damage or 0))
				table.insert(combo_label3, string.format("%3s", op.max_combo or 0))
				table.insert(combo_label3, string.format("%3s", op.max_combo_stun or 0))
				table.insert(combo_label3, string.format("%3s", op.max_combo_stun_timer or 0))
				table.insert(combo_label3, string.format("%3s", op.max_combo_pow or 0))
				if p.disp_dmg then
					util.table_add_all(combo_label1, { -- コンボ表示
						"Scaling",
						"Damage",
						"Combo",
						"Stun",
						"Timer",
						"Power",
					})
				end
				if p.disp_sts == 2 or p.disp_sts == 4 then util.table_add_all(combo_label1, sts_label) end
				if #combo_label1 > 0 then
					local box_bottom = get_line_height(#combo_label1)
					scr:draw_box(p1 and 224 or 0, 40, p1 and 320 or 96, 40 + box_bottom, 0x80404040, 0x80404040) -- 四角枠
					scr:draw_text(p1 and 224 + 4 or 4, 40, table.concat(combo_label1, "\n"))
					if p.disp_dmg then scr:draw_text(p1 and 224 + 36 or 36, 40, table.concat(combo_label2, "\n")) end
					if p.disp_dmg then scr:draw_text(p1 and 224 + 68 or 68, 40, table.concat(combo_label3, "\n")) end
				end

				-- 状態 小表示
				if p.disp_sts == 2 or p.disp_sts == 3 then
					local state_label = {}
					table.insert(state_label, string.format("%s %02d %03d %03d",
						p.state, p.throwing and p.throwing.threshold or 0, p.throwing and p.throwing.timer or 0, p.throw_timer))
					local diff_pos_y = p.pos_y + p.pos_frc_y - p.old_pos_y - p.old_pos_frc_y
					table.insert(state_label, string.format("%0.03f %0.03f", diff_pos_y, p.pos_y + p.pos_frc_y))
					table.insert(state_label, string.format("%02x %02x %02x", p.spid, p.attack, p.attack_id))
					table.insert(state_label, string.format("%03x %02x %02x", p.act, p.act_count, p.act_frame))
					table.insert(state_label, string.format("%02x %02x %02x", p.hurt_state, p.sway_status, p.additional))
					local box_bottom = get_line_height(#state_label)
					scr:draw_box(p1 and 0 or 277, 0, p1 and 40 or 316, box_bottom, 0x80404040, 0x80404040)
					scr:draw_text(p1 and 4 or 278, 0, table.concat(state_label, "\n"))
				end

				-- コマンド入力状態表示
				if global.disp_input_sts - 1 == i then
					for ti, input_state in ipairs(p.input_states) do
						local x, y = 147, 25 + ti * 5
						local x1, x2, y2 = x + 15, x - 8, y + 4
						draw_text_with_shadow(x1, y - 2, input_state.tbl.name,
							input_state.input_estab == true and input_state_col.orange2 or input_state_col.white)
						if input_state.on > 0 and input_state.chg_remain > 0 then
							local col, col2
							if input_state.charging == true then
								col, col2 = input_state_col.green, input_state_col.green2
							else
								col, col2 = input_state_col.yellow, input_state_col.yellow2
							end
							scr:draw_box(x2 + input_state.max * 2, y, x2, y2, col2, 0)
							scr:draw_box(x2 + input_state.chg_remain * 2, y, x2, y2, 0, col)
						end
						local cmdx = x - 50
						y = y - 2
						for ci, c in ipairs(input_state.tbl.lr_cmds[p.input_side]) do
							if c ~= "" then
								cmdx = cmdx + math.max(5.5,
									draw_text_with_shadow(cmdx, y, c,
										input_state.input_estab == true and input_state_col.orange or
										input_state.on > ci and input_state_col.red or
										(ci == 1 and input_state.on >= ci) and input_state_col.red or nil))
							end
						end
						draw_rtext_with_shadow(x + 1, y, input_state.chg_remain)
						draw_text_with_shadow(x + 4, y, "/")
						draw_text_with_shadow(x + 7, y, input_state.max)
						if input_state.debug then
							draw_rtext_with_shadow(x + 25, y, input_state.on)
							draw_rtext_with_shadow(x + 40, y, input_state.on_prev)
						end
					end
				end

				-- BS状態表示
				-- ガードリバーサル状態表示
				if global.disp_bg then
					local bs_label = {}
					if p.dummy_gd == dummy_gd_type.bs and global.dummy_bs_cnt > 1 then 
						table.insert(bs_label, string.format("%02d回ガードでBS", global.dummy_bs_cnt - math.max(p.bs_count, 0)))
					end
					if p.dummy_wakeup == wakeup_type.rvs and global.dummy_rvs_cnt > 1 then
						table.insert(bs_label, string.format("%02d回ガードでRev.", 
							p.gd_rvs_enabled and global.dummy_rvs_cnt > 1 and 0 or (global.dummy_rvs_cnt - math.max(p.rvs_count, 0))))
					end
					if #bs_label > 0 then
						scr:draw_box(p1 and 110 or 173, 40, p1 and 150 or 213, 40 + get_line_height(#bs_label), 0x80404040, 0x80404040)
						scr:draw_text(p1 and 110 or 173, 40, table.concat(bs_label, "\n"))
					end
				end

				-- 気絶表示
				if p.disp_stun then
					draw_text_with_shadow(p1 and 112 or 184, 19.7, string.format("%3s/%3s", p.life, 0xC0))
					scr:draw_box(p1 and (138 - p.stun_limit) or 180, 29, p1 and 140 or (182 + p.stun_limit), 34, 0, 0xDDC0C0C0) -- 枠
					scr:draw_box(p1 and (139 - p.stun_limit) or 181, 30, p1 and 139 or (181 + p.stun_limit), 33, 0, 0xDD000000) -- 黒背景
					scr:draw_box(p1 and (139 - p.stun) or 181, 30, p1 and 139 or (181 + p.stun), 33, 0, 0xDDFF0000) -- 気絶値
					draw_text_with_shadow(p1 and 112 or 184, 28, string.format("%3s/%3s", p.stun, p.stun_limit))
					scr:draw_box(p1 and (138 - 90) or 180, 35, p1 and 140 or (182 + 90), 40, 0, 0xDDC0C0C0)      -- 枠
					scr:draw_box(p1 and (139 - 90) or 181, 36, p1 and 139 or (181 + 90), 39, 0, 0xDD000000)      -- 黒背景
					scr:draw_box(p1 and (139 - p.stun_timer) or 181, 36, p1 and 139 or (181 + p.stun_timer), 39, 0, 0xDDFFFF00) -- 気絶値
					draw_text_with_shadow(p1 and 112 or 184, 34, string.format("%3s", p.stun_timer))
				end
			end

			-- コマンド入力とダメージとコンボ表示
			for i, p in ipairs(players) do
				local p1 = i == 1

				--行動IDとフレーム数表示
				if global.disp_frmgap > 1 or p.disp_frm > 1 then
					if global.disp_frmgap == 2 then
						draw_frame_groups(p.act_frames2, p.act_frames_total, 30, p1 and 64 or 72, 8, true)
						local j = 0
						for _, fb in pairs(p.fireballs) do
							if fb.act_frames2 ~= nil and p.disp_fbfrm == true then
								draw_frame_groups(fb.act_frames2, p.act_frames_total, 30, p1 and 64 or 70, 8, true)
							end
							j = j + 1
						end
						draw_frame_groups(p.muteki.act_frames2, p.act_frames_total, 30, p1 and 68 or 76, 3, true)
						-- draw_frame_groups(p.frm_gap.act_frames2, p.act_frames_total, 30, p1 and 65 or 73, 3, true)
					end
					if p.disp_frm > 1 then
						draw_frames(p.act_frames2, p1 and 160 or 285, true, true, p1 and 40 or 165, 63, 8, 16, p.disp_fbfrm)
					end
				end
				--フレーム差表示
				if global.disp_frmgap > 1 then
					local col = function(gap)
						if gap == 0 then
							return 0xFFFFFFFF
						elseif gap > 0 then
							return 0xFF00FFFF
						else
							return 0xFFFF0000
						end
					end
					local col2 = function(frame_number)
						if (frame_number + 10) <= global.frame_number then
							return 0xFFFFFFFF
						else
							return 0xFF00FFFF
						end
					end
					draw_rtext_with_shadow(p1 and 155 or 170, 40, p.last_frame_gap, col(p.last_frame_gap))

					-- 確定反撃の表示
					if p.on_punish > 0 and p.on_punish <= global.frame_number then
						if p1 then
							draw_rtext_with_shadow(155, 46, "確定反撃", col2(p.on_punish))
						else
							draw_text_with_shadow(170, 46, "確定反撃", col2(p.on_punish))
						end
					end
				end
			end

			-- キャラ間の距離表示
			local abs_space = math.abs(p_space)
			if global.disp_pos then
				local y = 216
				draw_ctext_with_shadow(scr.width / 2, y, abs_space)

				-- キャラの向き
				for i, p in ipairs(players) do
					local p1     = i == 1
					local side   = p.internal_side == 1 and "(>)" or "(<)" -- 内部の向き 1:右向き -1:左向き
					local i_side = p.input_side == 1 and "[>]" or "[<]" -- コマンド入力でのキャラ向き
					if p1 then
						draw_rtext_with_shadow(150, y, string.format("%s%s%s", p.flip_x, side, i_side))
					else
						draw_text_with_shadow(170, y, string.format("%s%s%s", i_side, side, p.flip_x))
					end
					if p.old_pos_y ~= p.pos_y or p.last_posy_txt == nil then
						p.last_posy_txt = string.format("%3s>%3s", p.old_pos_y or 0, p.pos_y)
					end
					draw_rtext_with_shadow(p1 and 110 or 230, y, p.last_posy_txt)
				end
			end

			-- GG風コマンド入力表示
			for i, p in ipairs(players) do
				local p1 = i == 1
				-- コマンド入力表示 1:OFF 2:ON 3:ログのみ 4:キーディスのみ
				if p.disp_cmd == 2 or p.disp_cmd == 4 then
					local xoffset, yoffset = ggkey_set[i].xoffset, ggkey_set[i].yoffset
					local oct_vt = ggkey_set[i].oct_vt
					local key_xy = ggkey_set[i].key_xy
					local tracks, max_track = {}, 6 -- 軌跡をつくる 軌跡は6個まで
					scr:draw_box(xoffset - 13, yoffset - 13, xoffset + 35, yoffset + 13, 0x80404040, 0x80404040)
					for ni = 1, 8 do -- 八角形描画
						local prev = ni > 1 and ni - 1 or 8
						local xy1, xy2 = oct_vt[ni], oct_vt[prev]
						scr:draw_line(xy1.x, xy1.y, xy2.x, xy2.y, 0xDDCCCCCC)
						scr:draw_line(xy1.x1, xy1.y1, xy2.x1, xy2.y1, 0xDDCCCCCC)
						scr:draw_line(xy1.x2, xy1.y2, xy2.x2, xy2.y2, 0xDDCCCCCC)
						scr:draw_line(xy1.x3, xy1.y3, xy2.x3, xy2.y3, 0xDDCCCCCC)
						scr:draw_line(xy1.x4, xy1.y4, xy2.x4, xy2.y4, 0xDDCCCCCC)
					end
					for j = #p.ggkey_hist, 2, -1 do -- 軌跡採取
						local k = j - 1
						local xy1, xy2 = key_xy[p.ggkey_hist[j].l], key_xy[p.ggkey_hist[k].l]
						if xy1.x ~= xy2.x or xy1.y ~= xy2.y then
							table.insert(tracks, 1, { xy1 = xy1, xy2 = xy2, })
							if #tracks >= max_track then
								break
							end
						end
					end
					local fixj = max_track - #tracks   -- 軌跡の上限補正用
					for j, track in ipairs(tracks) do
						local col = 0xFF0000FF + 0x002A0000 * (fixj + j) -- 青→ピンクのグラデーション
						local xy1, xy2 = track.xy1, track.xy2
						if xy1.x == xy2.x then
							scr:draw_box(xy1.x - 0.6, xy1.y, xy2.x + 0.6, xy2.y, col, col)
						elseif xy1.y == xy2.y then
							scr:draw_box(xy1.x, xy1.y - 0.6, xy2.x, xy2.y + 0.6, col, col)
						elseif xy1.op == xy2.no or xy1.dg1 == xy2.no or xy1.dg2 == xy2.no or xy1.no == 9 or xy2.no == 9 then
							for k = -0.6, 0.6, 0.3 do
								scr:draw_line(xy1.x + k, xy1.y + k, xy2.x + k, xy2.y + k, col)
							end
						else
							scr:draw_line(xy1.x, xy1.y, xy2.x, xy2.y, col)
							scr:draw_line(xy1.x1, xy1.y1, xy2.x1, xy2.y1, col)
							scr:draw_line(xy1.x2, xy1.y2, xy2.x2, xy2.y2, col)
							scr:draw_line(xy1.x3, xy1.y3, xy2.x3, xy2.y3, col)
							scr:draw_line(xy1.x4, xy1.y4, xy2.x4, xy2.y4, col)
						end
					end

					local ggkey = p.ggkey_hist[#p.ggkey_hist]
					if ggkey then -- ボタン描画
						local xy = key_xy[ggkey.l]
						scr:draw_text(xy.xt, xy.yt, convert("_("), 0xFFCC0000)
						scr:draw_text(xy.xt, xy.yt, convert("_)"))
						local xx, yy, btn = key_xy[5].x + 11, key_xy[5].y, convert("_A")
						if ggkey.a then
							scr:draw_text(xx, yy, convert("_("))
							scr:draw_text(xx, yy, btn, btn_col[btn])
						else
							scr:draw_text(xx, yy, convert("_("), 0xDDCCCCCC)
							scr:draw_text(xx, yy, btn, 0xDD444444)
						end
						xx, yy, btn = xx + 5, yy - 3, convert("_B")
						if ggkey.b then
							scr:draw_text(xx, yy, convert("_("))
							scr:draw_text(xx, yy, btn, btn_col[btn])
						else
							scr:draw_text(xx, yy, convert("_("), 0xDDCCCCCC)
							scr:draw_text(xx, yy, btn, 0xDD444444)
						end
						xx, yy, btn = xx + 5, yoffset - 3, convert("_C")
						if ggkey.c then
							scr:draw_text(xx, yy, convert("_("))
							scr:draw_text(xx, yy, btn, btn_col[btn])
						else
							scr:draw_text(xx, yy, convert("_("), 0xDDCCCCCC)
							scr:draw_text(xx, yy, btn, 0xDD444444)
						end
						xx, yy, btn = xx + 5, yy + 1, convert("_D")
						if ggkey.d then
							scr:draw_text(xx, yy, convert("_("))
							scr:draw_text(xx, yy, btn, btn_col[btn])
						else
							scr:draw_text(xx, yy, convert("_("), 0xDDCCCCCC)
							scr:draw_text(xx, yy, btn, 0xDD444444)
						end
					end
				end
			end

			-- レコーディング状態表示
			if global.disp_replay and (global.dummy_mode == 5 or global.dummy_mode == 6) then
				scr:draw_box(260 - 25, 208 - 8, 320 - 5, 224, 0xBB404040, 0xBB404040)
				if global.rec_main == rec_await_1st_input then
					-- 初回入力まち
					scr:draw_text(265, 204, "● REC " .. #recording.active_slot.name, 0xFFFF1133)
					scr:draw_text(290, 212, frame_to_time(3600), 0xFFFF1133)
				elseif global.rec_main == rec_await_1st_input then
					scr:draw_text(265, 204, "● REC " .. #recording.active_slot.name, 0xFFFF1133)
					scr:draw_text(290, 212, frame_to_time(3600), 0xFFFF1133)
				elseif global.rec_main == rec_input then
					-- 入力中
					scr:draw_text(265, 204, "● REC " .. #recording.active_slot.name, 0xFFFF1133)
					scr:draw_text(265, 212, frame_to_time(3601 - #recording.active_slot.store), 0xFFFF1133)
				elseif global.rec_main == rec_repeat_play then
					-- 自動リプレイまち
					scr:draw_text(265 - 15, 204, "■ リプレイ中", 0xFFFFFFFF)
					scr:draw_text(265 - 15, 212, "スタートおしっぱでメニュー", 0xFFFFFFFF)
				elseif global.rec_main == rec_play then
					-- リプレイ中
					scr:draw_text(265 - 15, 204, "■ リプレイ中", 0xFFFFFFFF)
					scr:draw_text(265 - 15, 212, "スタートおしっぱでメニュー", 0xFFFFFFFF)
				elseif global.rec_main == rec_play_interval then
					-- リプレイまち
					scr:draw_text(265 - 15, 204, "■ リプレイ中", 0xFFFFFFFF)
					scr:draw_text(265 - 15, 212, "スタートおしっぱでメニュー", 0xFFFFFFFF)
				elseif global.rec_main == rec_await_play then
					-- リプレイまち
					scr:draw_text(265 - 15, 204, "■ スタートでリプレイ", 0xFFFFFFFF)
					scr:draw_text(265 - 15, 212, "スタートおしっぱでメニュー", 0xFFFFFFFF)
				elseif global.rec_main == rec_fixpos then
					-- 開始位置記憶中
					scr:draw_text(265, 204, "● 位置REC " .. #recording.active_slot.name, 0xFFFF1133)
					scr:draw_text(265 - 15, 212, "スタートでメニュー", 0xFFFF1133)
				elseif global.rec_main == rec_await_1st_input then
				end
			end
		end
	end

	emu.register_start(function()
		setup_emu()
		math.randomseed(os.time())
	end)

	emu.register_stop(function() end)

	emu.register_menu(function(index, event) return false end, {}, "RB2 Training")

	emu.register_frame(function() end)
	-- メニュー表示
	local menu_max_row = 13
	local menu_nop = function() end
	local setup_char_manu = function()
		-- キャラにあわせたメニュー設定
		for _, p in ipairs(players) do
			local tmp_chr = mem.r8(p.addr.char)

			-- ブレイクショット
			if not p.dummy_bs_chr or p.dummy_bs_chr ~= tmp_chr then
				p.char, p.char_data, p.dummy_bs_chr = tmp_chr, chars[tmp_chr], tmp_chr
				p.dummy_bs = get_next_bs(p)
			end

			-- リバーサル
			if not p.dummy_rvs_chr or p.dummy_rvs_chr ~= tmp_chr then
				p.char, p.char_data, p.dummy_rvs_chr = tmp_chr, chars[tmp_chr], tmp_chr
				p.dummy_rvs = get_next_rvs(p)
			end

			p.gd_rvs_enabled = false
			p.rvs_count      = -1
		end
	end
	local menu_to_main = function(cancel, do_init)
		local col               = menu.training.pos.col
		local row               = menu.training.pos.row
		local p                 = players

		global.dummy_mode       = col[1] -- ダミーモード
		-- レコード・リプレイ設定
		p[1].dummy_act          = col[3] -- 1P アクション
		p[2].dummy_act          = col[4] -- 2P アクション
		p[1].dummy_gd           = col[5] -- 1P ガード
		p[2].dummy_gd           = col[6] -- 2P ガード
		global.next_block_grace = col[7] - 1 -- 1ガード持続フレーム数
		global.dummy_bs_cnt     = col[8] -- ブレイクショット設定
		p[1].dummy_wakeup       = col[9] -- 1P やられ時行動
		p[2].dummy_wakeup       = col[10] -- 2P やられ時行動
		global.dummy_rvs_cnt    = col[11] -- ガードリバーサル設定
		p[2].no_hit_limit       = col[12] - 1 -- 1P 強制空振り
		p[1].no_hit_limit       = col[13] - 1 -- 2P 強制空振り
		p[1].fwd_prov           = col[14] == 2 -- 1P 挑発で前進
		p[2].fwd_prov           = col[15] == 2 -- 2P 挑発で前進
		p[1].force_y_pos        = col[16] -- 1P Y座標強制
		p[2].force_y_pos        = col[17] -- 2P Y座標強制
		global.sync_pos_x       = col[18] -- X座標同期
		for _, p in ipairs(players) do
			if p.dummy_gd == dummy_gd_type.hit1 then
				p.next_block, p.next_block_ec = false, 75 -- カウンター初期化 false
			elseif p.dummy_gd == dummy_gd_type.block1 then
				p.next_block, p.next_block_ec = true, 75 -- カウンター初期化 true
			end
			p.block1 = 0
			p.rvs_count, p.dummy_rvs_chr, p.dummy_rvs = -1, p.char, get_next_rvs(p) -- リバサガードカウンター初期化、キャラとBSセット
			p.bs_count, p.dummy_bs_chr, p.dummy_bs = -1, p.char, get_next_bs(p) -- BSガードカウンター初期化、キャラとBSセット
		end

		global.old_dummy_mode = global.dummy_mode

		if global.dummy_mode == 5 then
			-- レコード
			-- 設定でレコーディングに入らずに抜けたとき用にモードを1に戻しておく
			global.dummy_mode = 1
			if not cancel and row == 1 then
				menu.current = menu.recording
				return
			end
		elseif global.dummy_mode == 6 then
			-- リプレイ
			-- 設定でリプレイに入らずに抜けたとき用にモードを1に戻しておく
			global.dummy_mode = 1
			menu.replay.pos.col[11] = recording.do_repeat and 2 or 1 -- 繰り返し
			menu.replay.pos.col[12] = recording.repeat_interval + 1 -- 繰り返し間隔
			menu.replay.pos.col[13] = global.await_neutral and 2 or 1 -- 繰り返し開始条件
			menu.replay.pos.col[14] = global.replay_fix_pos       -- 開始間合い固定
			menu.replay.pos.col[15] = global.replay_reset         -- 状態リセット
			menu.replay.pos.col[16] = global.disp_replay and 2 or 1 -- ガイド表示
			menu.replay.pos.col[17] = global.replay_stop_on_dmg and 2 or 1 -- ダメージでリプレイ中止
			if not cancel and row == 1 then
				menu.current = menu.replay
				return
			end
		end
		-- プレイヤー選択しなおしなどで初期化したいときはサブメニュー遷移しない
		if do_init ~= true then
			-- 設定後にメニュー遷移
			for i, p in ipairs(players) do
				-- ブレイクショット ガードのメニュー設定
				if not cancel and row == (4 + i) and p.dummy_gd == dummy_gd_type.bs then
					menu.current = menu.bs_menus[i][p.char]
					return
				end
				-- リバーサル やられ時行動のメニュー設定
				if not cancel and row == (8 + i) and rvs_wake_types[p.dummy_wakeup] then
					menu.current = menu.rvs_menus[i][p.char]
					return
				end
			end
		end

		menu.current = menu.main
	end
	local menu_to_main_cancel = function() menu_to_main(true, false) end
	local life_range,  pow_range = { "最大", "赤", "ゼロ", },  { "最大", "半分", "ゼロ", }
	for i = 1, 0xC0 do table.insert(life_range, i) end
	for i = 1, 0x3C do table.insert(pow_range, i) end
	local bar_menu_to_main         = function()
		local col                = menu.bar.pos.col
		local p                  = players
		--  タイトルラベル
		p[1].red                 = col[2] -- 1P 体力ゲージ量
		p[2].red                 = col[3] -- 2P 体力ゲージ量
		p[1].max                 = col[4] -- 1P POWゲージ量
		p[2].max                 = col[5] -- 2P POWゲージ量
		dip_config.infinity_life = col[6] == 2 -- 体力ゲージモード
		global.pow_mode          = col[7] -- POWゲージモード

		menu.current             = menu.main
	end
	local disp_menu_to_main        = function()
		local col               = menu.disp.pos.col
		local p                 = players
		--  タイトルラベル
		p[1].disp_hitbox        = col[2] == 2 -- 1P 判定表示
		p[2].disp_hitbox        = col[3] == 2 -- 2P 判定表示
		p[1].disp_range         = col[4] == 2 -- 1P 間合い表示
		p[2].disp_range         = col[5] == 2 -- 2P 間合い表示
		p[1].disp_stun          = col[6] == 2 -- 1P 気絶ゲージ表示
		p[2].disp_stun          = col[7] == 2 -- 2P 気絶ゲージ表示
		p[1].disp_dmg           = col[8] == 2 -- 1P ダメージ表示
		p[2].disp_dmg           = col[9] == 2 -- 2P ダメージ表示
		p[1].disp_cmd           = col[10] -- 1P 入力表示
		p[2].disp_cmd           = col[11] -- 2P 入力表示
		global.disp_input_sts   = col[12] -- コマンド入力状態表示
		global.disp_normal_frms = col[13] -- 通常動作フレーム非表示
		global.disp_frmgap      = col[14] -- フレーム差表示
		p[1].disp_frm           = col[15] -- 1P フレーム数表示
		p[2].disp_frm           = col[16] -- 2P フレーム数表示
		p[1].disp_fbfrm         = col[17] == 2 -- 1P 弾フレーム数表示
		p[2].disp_fbfrm         = col[18] == 2 -- 2P 弾フレーム数表示
		p[1].disp_sts           = col[19] -- 1P 状態表示
		p[2].disp_sts           = col[20] -- 2P 状態表示
		p[1].disp_base          = col[21] == 2 -- 1P 処理アドレス表示
		p[2].disp_base          = col[22] == 2 -- 2P 処理アドレス表示
		global.disp_pos         = col[23] == 2 -- 1P 2P 距離表示
		p[1].hide_char          = col[24] == 1 -- 1P キャラ表示
		p[2].hide_char          = col[25] == 1 -- 2P キャラ表示
		p[1].hide_phantasm      = col[26] == 1 -- 1P 残像表示
		p[2].hide_phantasm      = col[27] == 1 -- 2P 残像表示
		p[1].hide_effect        = col[28] == 1 -- 1P エフェクト表示
		p[2].hide_effect        = col[29] == 1 -- 2P エフェクト表示
		global.hide_p_chan      = col[30] == 1 -- Pちゃん表示
		global.hide_effect      = col[31] == 1 -- エフェクト表示
		menu.current            = menu.main
	end
	local ex_menu_to_main          = function()
		local col             = menu.extra.pos.col
		local p               = players
		-- タイトルラベル
		dip_config.easy_super = col[2] == 2          -- 簡易超必
		dip_config.semiauto_p = col[3] == 2          -- 半自動潜在能力
		p[1].dis_plain_shift  = col[4] == 2 or col[4] == 3 -- ライン送らない現象
		p[2].dis_plain_shift  = col[4] == 2 or col[4] == 4 -- ライン送らない現象
		global.pause_hit      = col[5]               -- ヒット時にポーズ
		global.pause_hitbox   = col[6]               -- 判定発生時にポーズ
		global.save_snapshot  = col[7]               -- 技画像保存
		global.mame_debug_wnd = col[8] == 2          -- MAMEデバッグウィンドウ
		global.damaged_move   = col[9]               -- ヒット効果確認用
		global.all_bs         = col[10] == 2         -- 全必殺技BS

		if global.all_bs then
			-- 全必殺技BS可能
			for addr = 0x85980, 0x85CE8, 2 do mem.wd16(addr, 0x007F|0x8000) end -- 0パワー消費 無敵7Fフレーム
			mem.wd32(0x39F24, 0x4E714E71) -- 6600 0014 nop化
		else
			local addr = 0x85980
			for _, b16 in ipairs(data.bs_data) do
				mem.wd16(addr, b16)
				addr = addr + 2
			end
			mem.wd32(0x39F24, 0x66000014)
		end

		menu.current = menu.main
	end
	local auto_menu_to_main        = function()
		local col                       = menu.auto.pos.col
		-- 自動入力設定
		global.auto_input.otg_thw       = col[2] == 2 -- ダウン投げ
		global.auto_input.otg_atk       = col[3] == 2 -- ダウン攻撃
		global.auto_input.thw_otg       = col[4] == 2 -- 通常投げの派生技
		global.auto_input.rave          = col[5] -- デッドリーレイブ
		global.auto_input.desire        = col[6] -- アンリミテッドデザイア
		global.auto_input.drill         = col[7] -- ドリル
		global.auto_input.pairon        = col[8] -- 超白龍
		global.auto_input.real_counter  = col[9] -- M.リアルカウンター
		global.auto_input.auto_3ecst    = col[10] == 2 -- M.トリプルエクスタシー
		global.auto_input.auto_taneuma  = col[11] == 2 -- 炎の種馬
		global.auto_input.auto_katsu    = col[12] == 2 -- 喝CA
		-- 入力設定
		global.auto_input.esaka_check   = col[14] -- 詠酒チェック
		global.auto_input.fast_kadenzer = col[15] == 2 -- 必勝！逆襲拳
		global.auto_input.kara_ca       = col[16] == 2 -- 空振りCA
		--"ジャーマン", "フェイスロック", "投げっぱなしジャーマン"
		if global.auto_input.real_counter > 1 then
			mem.wd16(0x413EE, 0x1C3C) -- ボタン読み込みをボタンデータ設定に変更
			mem.wd16(0x413F0, 0x10 * (2 ^ (global.auto_input.real_counter - 2)))
			mem.wd16(0x413F2, 0x4E71)
		else
			mem.wd32(0x413EE, 0x4EB90002)
			mem.wd16(0x413F2, 0x6396)
		end
		-- 詠酒の条件チェックを飛ばす
		mem.wd32(0x23748, global.auto_input.esaka_check == 2 and 0x4E714E71 or 0x6E00FC6A) -- 技種類と距離チェック飛ばす
		mem.wd32(0x236FC, global.auto_input.esaka_check == 3 and 0x604E4E71 or 0x6400FCB6) -- 距離チェックNOP
		-- 自動 炎の種馬
		mem.wd16(0x4094A, global.auto_input.auto_taneuma and 0x6018 or 0x6704) -- 連打チェックを飛ばす
		-- 必勝！逆襲拳1発キャッチカデンツァ
		mem.wd16(0x4098C, global.auto_input.fast_kadenzer and 0x7003 or 0x5210) -- カウンターに3を直接設定する
		-- 自動喝CA
		mem.wd8(0x3F94C, global.auto_input.auto_katsu and 0x60 or 0x67) -- 入力チェックを飛ばす
		mem.wd16(0x3F986, global.auto_input.auto_katsu and 0x4E71 or 0x6628) -- 入力チェックをNOPに
		-- 空振りCAできる
		mem.wd8(0x2FA5E, global.auto_input.kara_ca and 0x60 or 0x67) -- テーブルチェックを飛ばす
		-- 自動マリートリプルエクスタシー
		mem.wd8(0x41D00, global.auto_input.auto_3ecst and 0x60 or 0x66) -- デバッグDIPチェックを飛ばす
		menu.current = menu.main
	end
	local col_menu_to_main         = function()
		local col = menu.color.pos.col
		--util.printf("col_menu_to_main %s %s", #col, #data.box_type_list)
		for i = 2, #col do data.box_type_list[i - 1].enabled = col[i] == 2 end
		menu.current = menu.main
	end
	local menu_rec_to_tra          = function() menu.current = menu.training end
	local exit_menu_to_rec         = function(slot_no)
		local ec              = scr:frame_number()
		global.dummy_mode     = 5
		global.rec_main       = rec_await_no_input
		global.input_accepted = ec
		-- 選択したプレイヤー側の反対側の操作をいじる
		recording.temp_player = (mem.r8(players[1].addr.reg_pcnt) ~= 0xFF) and 2 or 1
		recording.last_slot   = slot_no
		recording.active_slot = recording.slot[slot_no]
		menu.current          = menu.main
		menu.exit()
	end
	local exit_menu_to_play_common = function()
		local col = menu.replay.pos.col
		recording.live_slots = recording.live_slots or {}
		for i = 1, #recording.slot do
			recording.live_slots[i] = (col[i + 1] == 2)
		end
		recording.do_repeat       = col[11] == 2 -- 繰り返し
		recording.repeat_interval = col[12] - 1 -- 繰り返し間隔
		global.await_neutral      = col[13] == 2 -- 繰り返し開始条件
		global.replay_fix_pos     = col[14] -- 開始間合い固定
		global.replay_reset       = col[15] -- 状態リセット
		global.disp_replay        = col[16] == 2 -- ガイド表示
		global.replay_stop_on_dmg = col[17] == 2 -- ダメージでリプレイ中止
		global.repeat_interval    = recording.repeat_interval
	end
	local exit_menu_to_rec_pos     = function()
		local ec = scr:frame_number()
		global.dummy_mode = 5 -- レコードモードにする
		global.rec_main = rec_fixpos
		global.input_accepted = ec
		-- 選択したプレイヤー側の反対側の操作をいじる
		recording.temp_player = (mem.r8(players[1].addr.reg_pcnt) ~= 0xFF) and 2 or 1
		exit_menu_to_play_common()
		menu.current = menu.main
		menu.exit()
	end
	local exit_menu_to_play        = function()
		local col = menu.replay.pos.col

		if menu.replay.pos.row == 14 and col[14] == 2 then -- 開始間合い固定 / 記憶
			exit_menu_to_rec_pos()
			return
		end

		local ec = scr:frame_number()
		global.dummy_mode = 6 -- リプレイモードにする
		global.rec_main = rec_await_play
		global.input_accepted = ec
		exit_menu_to_play_common()
		menu.current = menu.main
		menu.exit()
	end
	local exit_menu_to_play_cancel = function()
		local ec = scr:frame_number()
		global.dummy_mode = 6 -- リプレイモードにする
		global.rec_main = rec_await_play
		global.input_accepted = ec
		exit_menu_to_play_common()
		menu_to_tra()
	end
	local init_menu_config         = function()
		local col = menu.training.pos.col
		local p = players
		local g = global
		col[1] = g.dummy_mode        -- ダミーモード
		-- -- レコード・リプレイ設定
		col[3] = p[1].dummy_act      -- 1P アクション
		col[4] = p[2].dummy_act      -- 2P アクション
		col[5] = p[1].dummy_gd       -- 1P ガード
		col[6] = p[2].dummy_gd       -- 2P ガード
		col[7] = g.next_block_grace + 1 -- 1ガード持続フレーム数
		col[8] = g.dummy_bs_cnt      -- ブレイクショット設定
		col[9] = p[1].dummy_wakeup   -- 1P やられ時行動
		col[10] = p[2].dummy_wakeup  -- 2P やられ時行動
		col[11] = g.dummy_rvs_cnt    -- ガードリバーサル設定
		col[12] = p[2].no_hit_limit + 1 -- 1P 強制空振り
		col[13] = p[1].no_hit_limit + 1 -- 2P 強制空振り
		col[14] = p[1].fwd_prov and 2 or 1 -- 1P 挑発で前進
		col[15] = p[2].fwd_prov and 2 or 1 -- 2P 挑発で前進
		col[16] = p[1].force_y_pos   -- 1P Y座標強制
		col[17] = p[2].force_y_pos   -- 2P Y座標強制
		g.sync_pos_x = col[18]       -- X座標同期
	end
	local init_bar_menu_config     = function()
		local col = menu.bar.pos.col
		local p = players
		local g = global
		--   1                                                        1
		col[2] = p[1].red                      -- 1P 体力ゲージ量
		col[3] = p[2].red                      -- 2P 体力ゲージ量
		col[4] = p[1].max                      -- 1P POWゲージ量
		col[5] = p[2].max                      -- 2P POWゲージ量
		col[6] = dip_config.infinity_life and 2 or 1 -- 体力ゲージモード
		col[7] = g.pow_mode                    -- POWゲージモード
	end
	local init_disp_menu_config    = function()
		local col = menu.disp.pos.col
		local p = players
		local g = global
		-- タイトルラベル
		col[2] = p[1].disp_hitbox and 2 or 1 -- 判定表示
		col[3] = p[2].disp_hitbox and 2 or 1 -- 判定表示
		col[4] = p[1].disp_range and 2 or 1 -- 間合い表示
		col[5] = p[2].disp_range and 2 or 1 -- 間合い表示
		col[6] = p[1].disp_stun and 2 or 1 -- 1P 気絶ゲージ表示
		col[7] = p[2].disp_stun and 2 or 1 -- 2P 気絶ゲージ表示
		col[8] = p[1].disp_dmg and 2 or 1 -- 1P ダメージ表示
		col[9] = p[2].disp_dmg and 2 or 1 -- 2P ダメージ表示
		col[10] = p[1].disp_cmd           -- 1P 入力表示
		col[11] = p[2].disp_cmd           -- 2P 入力表示
		col[12] = g.disp_input_sts        -- コマンド入力状態表示
		col[13] = g.disp_normal_frms      -- 通常動作フレーム非表示
		col[14] = g.disp_frmgap           -- フレーム差表示
		col[15] = p[1].disp_frm           -- 1P フレーム数表示
		col[16] = p[2].disp_frm           -- 2P フレーム数表示
		col[17] = p[1].disp_fbfrm and 2 or 1 -- 1P 弾フレーム数表示
		col[18] = p[2].disp_fbfrm and 2 or 1 -- 2P 弾フレーム数表示
		col[19] = p[1].disp_sts           -- 1P 状態表示
		col[20] = p[2].disp_sts           -- 2P 状態表示
		col[21] = p[1].disp_base and 2 or 1 -- 1P 処理アドレス表示
		col[22] = p[2].disp_base and 2 or 1 -- 2P 処理アドレス表示
		col[23] = g.disp_pos and 2 or 1   -- 1P 2P 距離表示
		col[24] = p[1].hide_char and 1 or 2 -- 1P キャラ表示
		col[25] = p[2].hide_char and 1 or 2 -- 2P キャラ表示
		col[26] = p[1].hide_phantasm and 1 or 2 -- 1P 残像表示
		col[27] = p[2].hide_phantasm and 1 or 2 -- 2P 残像表示
		col[28] = p[1].hide_effect and 1 or 2 -- 1P エフェクト表示
		col[29] = p[2].hide_effect and 1 or 2 -- 2P エフェクト表示
		col[30] = g.hide_p_chan and 1 or 2 -- Pちゃん表示
		col[31] = g.hide_effect and 1 or 2 -- エフェクト表示
	end
	local init_ex_menu_config      = function()
		local col = menu.extra.pos.col
		local p = players
		local g = global
		-- タイトルラベル
		col[2] = dip_config.easy_super and 2 or 1 -- 簡易超必
		col[3] = dip_config.semiauto_p and 2 or 1 -- 半自動潜在能力
		col[4] = 1                          -- ライン送らない現象
		if p[1].dis_plain_shift and p[2].dis_plain_shift then
			col[4] = 2
		elseif p[1].dis_plain_shift then
			col[4] = 3
		elseif p[2].dis_plain_shift then
			col[4] = 4
		end
		col[5] = g.pause_hit           -- ヒット時にポーズ
		col[6] = g.pause_hitbox        -- 判定発生時にポーズ
		col[7] = g.save_snapshot       -- 技画像保存
		col[8] = g.mame_debug_wnd and 2 or 1 -- MAMEデバッグウィンドウ
		col[9] = g.damaged_move        -- ヒット効果確認用
	end
	local init_auto_menu_config    = function()
		local col = menu.auto.pos.col
		local g = global
		-- -- 自動入力設定
		col[2] = g.auto_input.otg_thw and 2 or 1       -- ダウン投げ
		col[3] = g.auto_input.otg_atk and 2 or 1       -- ダウン攻撃
		col[4] = g.auto_input.thw_otg and 2 or 1       -- 通常投げの派生技
		col[5] = g.auto_input.rave                     -- デッドリーレイブ
		col[6] = g.auto_input.desire                   -- アンリミテッドデザイア
		col[7] = g.auto_input.drill                    -- ドリル
		col[8] = g.auto_input.pairon                   -- 超白龍
		col[9] = g.auto_input.real_counter             -- M.リアルカウンター
		col[10] = g.auto_input.auto_3ecst and 2 or 1   -- M.トリプルエクスタシー
		col[11] = global.auto_input.auto_taneuma and 2 or 1 -- 炎の種馬
		col[12] = global.auto_input.auto_katsu and 2 or 1 -- 喝CA
		-- -- 入力設定
		col[14] = global.auto_input.esaka_check        -- 詠酒距離チェック
		col[15] = global.auto_input.fast_kadenzer and 2 or 1 -- 必勝！逆襲拳
		col[16] = global.auto_input.kara_ca and 2 or 1 -- 空振りCA
	end
	local init_restart_fight       = function()
	end
	menu_to_tra                    = function() menu.current = menu.training end
	menu_to_bar                    = function() menu.current = menu.bar end
	menu_to_disp                   = function() menu.current = menu.disp end
	menu_to_ex                     = function() menu.current = menu.extra end
	menu_to_auto                   = function() menu.current = menu.auto end
	menu_to_col                    = function() menu.current = menu.color end
	menu.exit                      = function()
		-- Bボタンでトレーニングモードへ切り替え
		menu.state = menu.tra_main
		cls_joy()
		cls_ps()
	end
	local menu_player_select       = function()
		--main_menu.pos.row = 1
		cls_ps()
		goto_player_select()
		--cls_joy()
		--cls_ps()
		-- 初期化
		menu_to_main(false, true)
		-- メニューを抜ける
		menu.state = menu.tra_main
		menu.prev_state = nil
		menu.reset_pos = true
		-- レコード＆リプレイ用の初期化
		if global.old_dummy_mode == 5 then
			-- レコード
			exit_menu_to_rec(recording.last_slot or 1)
		elseif global.old_dummy_mode == 6 then
			-- リプレイ
			exit_menu_to_play()
		end
	end
	local menu_restart_fight       = function()
		--main_menu.pos.row = 1
		global.disp_meters = menu.main.pos.col[15] == 2 -- 体力,POWゲージ表示
		global.disp_bg = menu.main.pos.col[16] == 2  -- 背景表示
		global.hide_shadow = menu.main.pos.col[17]   -- 影表示
		restart_fight({
			next_p1    = menu.main.pos.col[9],       -- 1P セレクト
			next_p2    = menu.main.pos.col[10],      -- 2P セレクト
			next_p1col = menu.main.pos.col[11] - 1,  -- 1P カラー
			next_p2col = menu.main.pos.col[12] - 1,  -- 2P カラー
			next_stage = menu.stgs[menu.main.pos.col[13]], -- ステージセレクト
			next_bgm   = menu.bgms[menu.main.pos.col[14]].id, -- BGMセレクト
		})
		global.fix_scr_top = menu.main.pos.col[18]
		if global.fix_scr_top == 1 then -- 1:OFF
			-- 演出のためのカメラワークテーブルを戻す
			for addr = 0x13C60, 0x13CBF, 4 do mem.wd32(addr, 0x00000000) end
			mem.wd32(0x13C6C, 0x00030000)
			mem.wd32(0x13C70, 0x000A0000)
			mem.wd32(0x13C7C, 0x000A0000)
			mem.wd32(0x13C80, 0x000A0000)
			mem.wd32(0x13C84, 0x00010000)
			mem.wd32(0x13C88, 0x00020000)
			mem.wd32(0x13C98, 0x00300000)
			mem.wd32(0x13C9C, 0x00020000)
			mem.wd32(0x13CA0, 0x00040000)
			mem.wd32(0x13CBC, 0x00020000)
		else
			-- 演出のためのカメラワークテーブルをすべてFにしてキャラを追従可能にする
			for addr = 0x13C60, 0x13CBF, 4 do mem.wd32(addr, 0xFFFFFFFF) end
		end
		-- 画面の上限設定を飛ばす
		mem.wd8(0x13AF0, global.fix_scr_top == 1 and 0x67 or 0x60) -- 013AF0: 6700 0036 beq $13b28
		mem.wd8(0x13B9A, global.fix_scr_top == 1 and 0x6A or 0x60) -- 013B9A: 6A04      bpl $13ba0

		cls_joy()
		cls_ps()
		-- 初期化
		menu_to_main(false, true)
		-- メニューを抜ける
		menu.state = menu.tra_main
		menu.reset_pos = true
		-- レコード＆リプレイ用の初期化
		if global.old_dummy_mode == 5 then
			-- レコード
			exit_menu_to_rec(recording.last_slot or 1)
		elseif global.old_dummy_mode == 6 then
			-- リプレイ
			exit_menu_to_play()
		end
	end
	-- 半角スペースで始まっているメニューはラベル行とみなす
	local is_label_line            = function(str) return str:find('^' .. "  +") ~= nil end
	menu.main                      = {
		list = {
			{ "ダミー設定" },
			{ "ゲージ設定" },
			{ "表示設定" },
			{ "特殊設定" },
			{ "自動入力設定" },
			{ "判定個別設定" },
			{ "プレイヤーセレクト画面" },
			{ "                          クイックセレクト" },
			{ "1P セレクト", menu.labels.chars },
			{ "2P セレクト", menu.labels.chars },
			{ "1P カラー", { "A", "D" } },
			{ "2P カラー", { "A", "D" } },
			{ "ステージセレクト", menu.labels.stgs },
			{ "BGMセレクト", menu.labels.bgms },
			{ "体力,POWゲージ表示", menu.labels.off_on, },
			{ "背景表示", menu.labels.off_on, },
			{ "影表示", { "OFF", "ON", "ON:反射→影", } },
			{ "位置補正", menu.labels.fix_scr_tops, },
			{ "リスタート" },
		},
		pos = {
			-- メニュー内の選択位置
			offset = 1,
			row = 1,
			col = {
				0, -- ダミー設定              1
				0, -- ゲージ設定              2
				0, -- 表示設定                3
				0, -- 特殊設定                4
				0, -- 自動入力設定            5
				0, -- 判定個別設定            6
				0, -- プレイヤーセレクト画面  7
				0, -- クイックセレクト        8
				1, -- 1P セレクト             9
				1, -- 2P セレクト            10
				1, -- 1P カラー              11
				1, -- 2P カラー              12
				1, -- ステージセレクト       13
				1, -- BGMセレクト            14
				1, -- 体力,POWゲージ表示     15
				2, -- 背景表示               16
				2, -- 影表示                 17
				1, -- 背景なし時位置補正     18
				0, -- リスタート             19
			},
		},
		on_a = {
			menu_to_tra, -- ダミー設定
			menu_to_bar, -- ゲージ設定
			menu_to_disp, -- 表示設定
			menu_to_ex, -- 特殊設定
			menu_to_auto, -- 自動入力設定
			menu_to_col, -- 判定個別設定
			menu_player_select, -- プレイヤーセレクト画面
			menu_nop,  -- クイックセレクト
			menu_restart_fight, -- 1P セレクト
			menu_restart_fight, -- 2P セレクト
			menu_restart_fight, -- 1P カラー
			menu_restart_fight, -- 2P カラー
			menu_restart_fight, -- ステージセレクト
			menu_restart_fight, -- BGMセレクト
			menu_restart_fight, -- 体力,POWゲージ表示
			menu_restart_fight, -- 背景表示
			menu_restart_fight, -- 影表示
			menu_restart_fight, -- 背景なし時位置補正
			menu_restart_fight, -- リスタート
		},
		on_b = util.new_filled_table(19, menu.exit),
	}
	menu.current                   = menu.main  -- デフォルト設定
	menu.update_pos                = function()
		-- メニューの更新
		menu.main.pos.col[9] = math.min(math.max(mem.r8(0x107BA5), 1), #menu.labels.chars)
		menu.main.pos.col[10] = math.min(math.max(mem.r8(0x107BA7), 1), #menu.labels.chars)
		menu.main.pos.col[11] = math.min(math.max(mem.r8(0x107BAC) + 1, 1), 2)
		menu.main.pos.col[12] = math.min(math.max(mem.r8(0x107BAD) + 1, 1), 2)

		menu.reset_pos = false

		local stg1 = mem.r8(0x107BB1)
		local stg2 = mem.r8(0x107BB7)
		local stg3 = mem.r8(0x107BB8)
		menu.main.pos.col[13] = 1
		for i, data in ipairs(menu.stgs) do
			if data.stg1 == stg1 and data.stg2 == stg2 and data.stg3 == stg3 and global.disp_bg == data.disp_bg then
				menu.main.pos.col[13] = i
				break
			end
		end

		local bgmid, found = mem.r8(0x10A8D5), false
		for _, bgm in ipairs(menu.bgms) do
			if bgmid == bgm.id then
				menu.main.pos.col[14] = bgm.name_idx
				found = true
				break
			end
		end
		if not found then
			menu.main.pos.col[14] = 1
		end

		menu.main.pos.col[15] = global.disp_meters and 2 or 1 -- 体力,POWゲージ表示
		menu.main.pos.col[16] = global.disp_bg and 2 or 1 -- 背景表示
		menu.main.pos.col[17] = global.hide_shadow      -- 影表示
		menu.main.pos.col[18] = global.fix_scr_top

		setup_char_manu()
	end
	-- ブレイクショットメニュー
	menu.bs_menus, menu.rvs_menus  = {}, {}
	local bs_blocks, rvs_blocks    = {}, {}
	for i = 1, 60 do
		table.insert(bs_blocks, string.format("%s回ガード後に発動", i))
		table.insert(rvs_blocks, string.format("%s回ガード後に発動", i))
	end
	local menu_bs_to_tra_menu = function() menu_to_tra() end
	local menu_rvs_to_tra_menu = function()
		local cur_prvs = nil
		for i, prvs in ipairs(menu.rvs_menus) do
			for _, a_bs_menu in ipairs(prvs) do
				if menu.current == a_bs_menu then
					cur_prvs = prvs
					break
				end
			end
			if cur_prvs then
				break
			end
		end
		-- 共通行動の設定を全キャラにコピー反映
		for _, a_bs_menu in ipairs(cur_prvs or {}) do
			if menu.current ~= a_bs_menu then
				for _, rvs in ipairs(a_bs_menu.list) do
					if rvs.common then
						a_bs_menu.pos.col[rvs.row] = menu.current.pos.col[rvs.row]
					end
				end
			end
		end
		menu_to_tra()
	end
	for i = 1, 2 do
		local pbs, prvs = {}, {}
		table.insert(menu.bs_menus, pbs)
		table.insert(menu.rvs_menus, prvs)
		for _, bs_list in pairs(data.char_bs_list) do
			local list, on_ab, col = {}, {}, {}
			table.insert(list, { "     ONにしたスロットからランダムで発動されます。" })
			table.insert(on_ab, menu_bs_to_tra_menu)
			table.insert(col, 0)
			for _, bs in pairs(bs_list) do
				local name = bs.name
				if util.testbit(bs.hook_type, hook_cmd_types.ex_breakshot, true) then bs.name = "*" .. bs.name end
				table.insert(list, { name, menu.labels.off_on, common = bs.common == true, row = #list, })
				table.insert(on_ab, menu_bs_to_tra_menu)
				table.insert(col, 1)
			end
			table.insert(pbs, { list = list, pos = { offset = 1, row = 2, col = col, }, on_a = on_ab, on_b = on_ab, })
		end
		for _, rvs_list in pairs(data.char_rvs_list) do
			local list, on_ab, col = {}, {}, {}
			table.insert(list, { "     ONにしたスロットからランダムで発動されます。" })
			table.insert(on_ab, menu_rvs_to_tra_menu)
			table.insert(col, 0)
			for _, bs in pairs(rvs_list) do
				table.insert(list, { bs.name, menu.labels.off_on, common = bs.common == true, row = #list, })
				table.insert(on_ab, menu_rvs_to_tra_menu)
				table.insert(col, 1)
			end
			table.insert(prvs, { list = list, pos = { offset = 1, row = 2, col = col, }, on_a = on_ab, on_b = on_ab, })
		end
	end
	local gd_frms = {}
	for i = 1, 61 do table.insert(gd_frms, string.format("%sF後にガード解除", (i - 1))) end
	local no_hit_row = { "OFF", }
	for i = 1, 99 do table.insert(no_hit_row, string.format("%s段目で空振り", i)) end
	menu.training = {
		list = {
			{ "ダミーモード", { "プレイヤー vs プレイヤー", "プレイヤー vs CPU", "CPU vs プレイヤー", "1P&2P入れ替え", "レコード", "リプレイ" }, },
			{ "                         ダミー設定" },
			{ "1P アクション", { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" }, },
			{ "2P アクション", { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" }, },
			{ "1P ガード", { "なし", "オート", "ブレイクショット（Aで選択画面へ）", "1ヒットガード", "1ガード", "常時", "ランダム", "強制" }, },
			{ "2P ガード", { "なし", "オート", "ブレイクショット（Aで選択画面へ）", "1ヒットガード", "1ガード", "常時", "ランダム", "強制" }, },
			{ "1ガード持続フレーム数", gd_frms, },
			{ "ブレイクショット設定", bs_blocks },
			{ "1P やられ時行動", { "なし", "リバーサル（Aで選択画面へ）", "テクニカルライズ（Aで選択画面へ）", "グランドスウェー（Aで選択画面へ）", "起き上がり攻撃", }, },
			{ "2P やられ時行動", { "なし", "リバーサル（Aで選択画面へ）", "テクニカルライズ（Aで選択画面へ）", "グランドスウェー（Aで選択画面へ）", "起き上がり攻撃", }, },
			{ "ガードリバーサル設定", bs_blocks },
			{ "1P 強制空振り", no_hit_row, },
			{ "2P 強制空振り", no_hit_row, },
			{ "1P 挑発で前進", menu.labels.off_on, },
			{ "2P 挑発で前進", menu.labels.off_on, },
			{ "1P Y座標強制", force_y_pos, },
			{ "2P Y座標強制", force_y_pos, },
			{ "画面下に移動", { "OFF", "2Pを下に移動", "1Pを下に移動", }, },
		},
		pos = { -- メニュー内の選択位置
			offset = 1,
			row = 1,
			col = {
				1, -- ダミーモード            1
				0, -- レコード・リプレイ設定  2
				1, -- 1P アクション           3
				1, -- 2P アクション           4
				1, -- 1P ガード               5
				1, -- 2P ガード               6
				1, -- 1ガード持続フレーム数   7
				1, -- ブレイクショット設定    8
				1, -- 1P やられ時行動         9
				1, -- 2P やられ時行動        10
				1, -- ガードリバーサル設定   11
				1, -- 1P 強制空振り          12
				1, -- 2P 強制空振り          13
				1, -- 1P 挑発で前進          14
				1, -- 2P 挑発で前進          15
				1, -- 1P Y座標強制           16
				1, -- 2P Y座標強制           17
				1, -- X座標同期              18
			},
		},
		on_a = util.new_filled_table(18, menu_to_main),
		on_b = util.new_filled_table(18, menu_to_main_cancel),
	}

	menu.bar = {
		list = {
			{ "                         ゲージ設定" },
			{ "1P 体力ゲージ量", life_range, }, -- "最大", "赤", "ゼロ" ...
			{ "2P 体力ゲージ量", life_range, }, -- "最大", "赤", "ゼロ" ...
			{ "1P POWゲージ量", pow_range, }, -- "最大", "半分", "ゼロ" ...
			{ "2P POWゲージ量", pow_range, }, -- "最大", "半分", "ゼロ" ...
			{ "体力ゲージモード", { "自動回復", "固定" }, },
			{ "POWゲージモード", { "自動回復", "固定", "通常動作" }, },
		},
		pos = {
			-- メニュー内の選択位置
			offset = 1,
			row = 2,
			col = {
				0, -- －ゲージ設定－          1
				2, -- 1P 体力ゲージ量         2
				2, -- 2P 体力ゲージ量         3
				2, -- 1P POWゲージ量          4
				2, -- 2P POWゲージ量          5
				2, -- 体力ゲージモード        6
				2, -- POWゲージモード         7
			},
		},
		on_a = util.new_filled_table(7, bar_menu_to_main),
		on_b = util.new_filled_table(7, bar_menu_to_main),
	}

	menu.disp = {
		list = {
			{ "                          表示設定" },
			{ "1P 判定表示", { "OFF", "ON", }, },
			{ "2P 判定表示", { "OFF", "ON", }, },
			{ "1P 間合い表示", { "OFF", "ON", }, },
			{ "2P 間合い表示", { "OFF", "ON", }, },
			{ "1P 気絶ゲージ表示", menu.labels.off_on, },
			{ "2P 気絶ゲージ表示", menu.labels.off_on, },
			{ "1P ダメージ表示", menu.labels.off_on, },
			{ "2P ダメージ表示", menu.labels.off_on, },
			{ "1P 入力表示", { "OFF", "ON", "ログのみ", "キーディスのみ", }, },
			{ "2P 入力表示", { "OFF", "ON", "ログのみ", "キーディスのみ", }, },
			{ "コマンド入力状態表示", { "OFF", "1P", "2P", }, },
			{ "通常動作フレーム非表示", menu.labels.off_on, },
			{ "フレーム差表示", { "OFF", "数値とグラフ", "数値" }, },
			{ "1P フレーム数表示", { "OFF", "ON", "ON:判定の形毎", "ON:攻撃判定の形毎", "ON:くらい判定の形毎", }, },
			{ "2P フレーム数表示", { "OFF", "ON", "ON:判定の形毎", "ON:攻撃判定の形毎", "ON:くらい判定の形毎", }, },
			{ "1P 弾フレーム数表示", menu.labels.off_on, },
			{ "2P 弾フレーム数表示", menu.labels.off_on, },
			{ "1P 状態表示", { "OFF", "ON", "ON:小表示", "ON:大表示" }, },
			{ "2P 状態表示", { "OFF", "ON", "ON:小表示", "ON:大表示" }, },
			{ "1P 処理アドレス表示", menu.labels.off_on, },
			{ "2P 処理アドレス表示", menu.labels.off_on, },
			{ "1P 2P 距離表示", menu.labels.off_on, },
			{ "1P キャラ表示", menu.labels.off_on, },
			{ "2P キャラ表示", menu.labels.off_on, },
			{ "1P 残像表示", menu.labels.off_on, },
			{ "2P 残像表示", menu.labels.off_on, },
			{ "1P エフェクト表示", menu.labels.off_on, },
			{ "2P エフェクト表示", menu.labels.off_on, },
			{ "Pちゃん表示", menu.labels.off_on, },
			{ "エフェクト表示", menu.labels.off_on, },
		},
		pos = {
			-- メニュー内の選択位置
			offset = 1,
			row = 2,
			col = {
				0, -- －表示設定－            1
				2, -- 1P 判定表示             2
				2, -- 2P 判定表示             3
				2, -- 1P 間合い表示           4
				2, -- 2P 間合い表示           5
				2, -- 1P 気絶ゲージ表示       6
				2, -- 2P 気絶ゲージ表示       7
				1, -- 1P ダメージ表示         8
				1, -- 2P ダメージ表示         9
				1, -- 1P 入力表示            10
				1, -- 2P 入力表示            11
				1, -- コマンド入力状態表示   12
				2, -- 通常動作フレーム非表示 13
				3, -- フレーム差表示         14
				4, -- 1P フレーム数表示      15
				4, -- 2P フレーム数表示      16
				2, -- 1P 弾フレーム数表示    17
				2, -- 1P 弾フレーム数表示    18
				1, -- 1P 状態表示            19
				1, -- 2P 状態表示            20
				1, -- 1P 処理アドレス表示    21
				1, -- 2P 処理アドレス表示    22
				1, -- 1P 2P 距離表示         23
				2, -- 1P キャラ表示          24
				2, -- 2P キャラ表示          25
				2, -- 1P 残像表示            26
				2, -- 2P 残像表示            27
				2, -- 1P エフェクト表示      28
				2, -- 2P エフェクト表示      29
				2, -- Pちゃん表示            30
				2, -- エフェクト表示         31
			},
		},
		on_a = util.new_filled_table(31, disp_menu_to_main),
		on_b = util.new_filled_table(31, disp_menu_to_main),
	}
	menu.extra = {
		list = {
			{ "                          特殊設定" },
			{ "簡易超必", menu.labels.off_on, },
			{ "半自動潜在能力", menu.labels.off_on, },
			{ "ライン送らない現象", { "OFF", "ON", "ON:1Pのみ", "ON:2Pのみ" }, },
			{ "ヒット時にポーズ", { "OFF", "ON", "ON:やられのみ", "ON:投げやられのみ", "ON:打撃やられのみ", "ON:ガードのみ", }, },
			{ "判定発生時にポーズ", { "OFF", "投げ", "攻撃", "変化時", }, },
			{ "技画像保存", { "OFF", "ON:新規", "ON:上書き", }, },
			{ "MAMEデバッグウィンドウ", menu.labels.off_on, },
			{ "ヒット効果確認用", hit_effect_move_keys },
			{ "全必殺技BS", menu.labels.off_on, }
		},
		pos = {
			-- メニュー内の選択位置
			offset = 1,
			row = 2,
			col = {
				0, -- －特殊設定－            1
				1, -- 簡易超必                2
				1, -- 半自動潜在能力          3
				1, -- ライン送らない現象      4
				1, -- ヒット時にポーズ        5
				1, -- 判定発生時にポーズ      6
				1, -- 技画像保存              7
				1, -- MAMEデバッグウィンドウ  8
				1, -- ヒット効果確認用        9
				1, -- 全必殺技BS             10
			},
		},
		on_a = util.new_filled_table(10, ex_menu_to_main),
		on_b = util.new_filled_table(10, ex_menu_to_main),
	}

	menu.auto = {
		list = {
			{ "                        自動入力設定" },
			{ "ダウン投げ", menu.labels.off_on, },
			{ "ダウン攻撃", menu.labels.off_on, },
			{ "通常投げの派生技", menu.labels.off_on, },
			{ "デッドリーレイブ", { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, },
			{ "アンリミテッドデザイア", { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, "ギガティックサイクロン" }, },
			{ "ドリル", { 1, 2, 3, 4, 5 }, },
			{ "超白龍", { "OFF", "C攻撃-判定発生前", "C攻撃-判定発生後" }, },
			{ "M.リアルカウンター", { "OFF", "ジャーマン", "フェイスロック", "投げっぱなしジャーマン", }, },
			{ "M.トリプルエクスタシー", menu.labels.off_on, },
			{ "炎の種馬", menu.labels.off_on, },
			{ "喝CA", menu.labels.off_on, },
			{ "                          入力設定" },
			{ "詠酒チェック", { "OFF", "詠酒距離チェックなし", "いつでも詠酒" }, },
			{ "必勝！逆襲拳", menu.labels.off_on, },
			{ "空振りCA", menu.labels.off_on, },
		},
		pos = {
			-- メニュー内の選択位置
			offset = 1,
			row = 2,
			col = {
				0, -- 自動入力設定            1
				1, -- ダウン投げ              2
				1, -- ダウン攻撃              3
				1, -- 通常投げの派生技        4
				1, -- デッドリーレイブ        5
				1, -- アンリミテッドデザイア  6
				1, -- ドリル                  7
				1, -- 超白龍                  8
				1, -- M.リアルカウンター      9
				1, -- M.トリプルエクスタシー 10
				1, -- 炎の種馬               11
				1, -- 喝CA                   12
				0, -- 入力設定               13
				1, -- 詠酒距離チェック       14
				1, -- 必勝！逆襲拳           15
				1, -- 空振りCA               16
			},
		},
		on_a = util.new_filled_table(16, auto_menu_to_main),
		on_b = util.new_filled_table(16, auto_menu_to_main),
	}

	menu.color = {
		list = {},
		pos = {
			-- メニュー内の選択位置
			offset = 1,
			row = 2,
			col = {},
		},
		on_a = {},
		on_b = {},
	}
	table.insert(menu.color.list, { "                          判定個別設定" })
	table.insert(menu.color.pos.col, 0)
	table.insert(menu.color.on_a, col_menu_to_main)
	table.insert(menu.color.on_b, col_menu_to_main)
	for _, box in pairs(data.box_type_list) do -- TODO 修正する
		table.insert(menu.color.list, { box.name, menu.labels.off_on, { fill = box.fill, outline = box.outline } })
		table.insert(menu.color.pos.col, box.enabled and 2 or 1)
		table.insert(menu.color.on_a, col_menu_to_main)
		table.insert(menu.color.on_b, col_menu_to_main)
	end

	menu.recording = {
		list = {
			{ "            選択したスロットに記憶されます。" },
			{ "スロット1", { "Aでレコード開始", }, },
			{ "スロット2", { "Aでレコード開始", }, },
			{ "スロット3", { "Aでレコード開始", }, },
			{ "スロット4", { "Aでレコード開始", }, },
			{ "スロット5", { "Aでレコード開始", }, },
			{ "スロット6", { "Aでレコード開始", }, },
			{ "スロット7", { "Aでレコード開始", }, },
			{ "スロット8", { "Aでレコード開始", }, },
		},
		pos = {
			-- メニュー内の選択位置
			offset = 1,
			row = 2,
			col = {
				0, -- 説明               1
				1, -- スロット1          2
				1, -- スロット2          3
				1, -- スロット3          4
				1, -- スロット4          5
				1, -- スロット5          6
				1, -- スロット6          7
				1, -- スロット7          8
				1, -- スロット8          9
			},
		},
		on_a = {
			menu_rec_to_tra,           -- 説明
			function() exit_menu_to_rec(1) end, -- スロット1
			function() exit_menu_to_rec(2) end, -- スロット2
			function() exit_menu_to_rec(3) end, -- スロット3
			function() exit_menu_to_rec(4) end, -- スロット4
			function() exit_menu_to_rec(5) end, -- スロット5
			function() exit_menu_to_rec(6) end, -- スロット6
			function() exit_menu_to_rec(7) end, -- スロット7
			function() exit_menu_to_rec(8) end, -- スロット8
		},
		on_b = util.new_filled_table(1, menu_rec_to_tra, 8, menu_to_tra),
	}
	local play_interval = {}
	for i = 1, 301 do table.insert(play_interval, i - 1) end
	menu.replay = {
		list = {
			{ "     ONにしたスロットからランダムでリプレイされます。" },
			{ "スロット1", menu.labels.off_on, },
			{ "スロット2", menu.labels.off_on, },
			{ "スロット3", menu.labels.off_on, },
			{ "スロット4", menu.labels.off_on, },
			{ "スロット5", menu.labels.off_on, },
			{ "スロット6", menu.labels.off_on, },
			{ "スロット7", menu.labels.off_on, },
			{ "スロット8", menu.labels.off_on, },
			{ "                        リプレイ設定" },
			{ "繰り返し", menu.labels.off_on, },
			{ "繰り返し間隔", play_interval, },
			{ "繰り返し開始条件", { "なし", "両キャラがニュートラル", }, },
			{ "開始間合い固定", { "OFF", "Aでレコード開始", "1Pと2P", "1P", "2P", }, },
			{ "状態リセット", { "OFF", "1Pと2P", "1P", "2P", }, },
			{ "ガイド表示", menu.labels.off_on, },
			{ "ダメージでリプレイ中止", menu.labels.off_on, },
		},
		pos = {
			-- メニュー内の選択位置
			offset = 1,
			row = 2,
			col = {
				0,         -- 説明               1
				2,         -- スロット1          2
				2,         -- スロット2          3
				2,         -- スロット3          4
				2,         -- スロット4          5
				2,         -- スロット5          6
				2,         -- スロット6          7
				2,         -- スロット7          8
				2,         -- スロット8          9
				0,         -- リプレイ設定      10
				1,         -- 繰り返し          11
				1,         -- 繰り返し間隔      12
				1,         -- 繰り返し開始条件  13
				global.replay_fix_pos, -- 開始間合い固定    14
				global.replay_reset, -- 状態リセット      15
				2,         -- ガイド表示        16
				2,         -- ダメージでリプレイ中止 17
			},
		},
		on_a = util.new_filled_table(17, exit_menu_to_play),
		-- TODO キャンセル時にも間合い固定の設定とかが変わるように
		on_b = util.new_filled_table(17, exit_menu_to_play_cancel),
	}
	init_auto_menu_config()
	init_disp_menu_config()
	init_ex_menu_config()
	init_bar_menu_config()
	init_menu_config()
	init_restart_fight()
	menu_to_main(true)

	menu.proc = function() set_freeze(false) end -- メニュー表示中はDIPかポーズでフリーズさせる
	local menu_cur_updown = function(add_val)
		local temp_row = menu.current.pos.row
		while true do
			temp_row = (temp_row + add_val) % #menu.current.list
			if temp_row < 1 then
				temp_row = #menu.current.list
			elseif temp_row > #menu.current.list then
				temp_row = 1
			end
			-- printf("row %s/%s", temp_row, #menu_cur.list)
			-- ラベルだけ行の場合はスキップ
			if not is_label_line(menu.current.list[temp_row][1]) then
				menu.current.pos.row = temp_row
				break
			end
		end
		if not (menu.current.pos.offset < menu.current.pos.row and menu.current.pos.row < menu.current.pos.offset + menu_max_row) then
			menu.current.pos.offset = math.max(1, menu.current.pos.row - menu_max_row)
		end
		global.input_accepted = scr:frame_number()
	end
	local menu_cur_lr = function(add_val, loop)
		-- カーソル右移動
		local cols = menu.current.list[menu.current.pos.row][2]
		if cols then
			local col_pos = menu.current.pos.col
			local temp_col = col_pos[menu.current.pos.row]
			if loop then
				temp_col = temp_col and ((temp_col + add_val) % #cols) or 1
			else
				temp_col = temp_col and temp_col + add_val or 1
			end
			if temp_col < 1 then
				temp_col = loop and #cols or 1
			elseif temp_col > #cols then
				temp_col = loop and 1 or #cols
			end
			col_pos[menu.current.pos.row] = temp_col
			-- printf("row %s/%s", temp_col, #cols)
		end
		global.input_accepted = scr:frame_number()
	end
	menu.draw = function()
		local ec = scr:frame_number()
		local state_past = ec - global.input_accepted
		local width = scr.width * scr.xscale
		local height = scr.height * scr.yscale
		if not in_match or in_player_select then return end
		if menu.prev_state ~= menu and menu.state == menu then menu.update_pos() end -- 初回のメニュー表示時は状態更新
		menu.prev_state = menu.state -- 前フレームのメニューを更新

		local joy_val = get_joy()
		if accept_input("st", joy_val, state_past) then
			-- Menu ON/OFF
			global.input_accepted = ec
		elseif accept_input("a", joy_val, state_past) then
			-- サブメニューへの遷移（あれば）
			menu.current.on_a[menu.current.pos.row]()
			global.input_accepted = ec
		elseif accept_input("b", joy_val, state_past) then
			-- メニューから戻る
			menu.current.on_b[menu.current.pos.row]()
			global.input_accepted = ec
		elseif accept_input("up", joy_val, state_past) then
			-- カーソル上移動
			menu_cur_updown(-1)
		elseif accept_input("dn", joy_val, state_past) then
			-- カーソル下移動
			menu_cur_updown(1)
		elseif accept_input("lt", joy_val, state_past) then
			-- カーソル左移動
			menu_cur_lr(-1, true)
		elseif accept_input("rt", joy_val, state_past) then
			-- カーソル右移動
			menu_cur_lr(1, true)
		elseif accept_input("c", joy_val, state_past) then
			-- カーソル左10移動
			menu_cur_lr(-10, false)
		elseif accept_input("d", joy_val, state_past) then
			-- カーソル右10移動
			menu_cur_lr(10, false)
		end

		-- メニュー表示本体
		scr:draw_box(0, 0, width, height, 0xC0000000, 0xC0000000)
		local row_num, menu_max = 1, math.min(menu.current.pos.offset + menu_max_row, #menu.current.list)
		for i = menu.current.pos.offset, menu_max do
			local row = menu.current.list[i]
			local y = 48 + 10 * row_num
			local c1, c2, c3, c4, c5
			-- 選択行とそうでない行の色分け判断
			if i == menu.current.pos.row then
				c1, c2, c3, c4, c5 = 0xFFDD2200, 0xFF662200, 0xFFFFFF00, 0xCC000000, 0xAAFFFFFF
				-- アクティブメニュー項目のビカビカ処理
				local deep = math.modf((scr:frame_number() / 5) % 20) + 1
				c1 = c1 - (0x00110000 * math.abs(deep - 10))
			else
				c1, c2, c3, c4, c5 = 0xFFC0C0C0, 0xFFB0B0B0, 0xFF000000, 0x00000000, 0xFF000000
			end
			if is_label_line(row[1]) then
				-- ラベルだけ行
				scr:draw_text(96, y + 1, row[1], 0xFFFFFFFF)
			else
				-- 通常行 ラベル部分
				scr:draw_box(90, y + 0.5, 230, y + 8.5, c2, c1)
				if i == menu.current.pos.row then
					scr:draw_line(90, y + 0.5, 230, y + 0.5, 0xFFDD2200)
					scr:draw_line(90, y + 0.5, 90, y + 8.5, 0xFFDD2200)
				else
					scr:draw_box(90, y + 7.0, 230, y + 8.5, 0xFFB8B8B8, 0xFFB8B8B8)
					scr:draw_box(90, y + 8.0, 230, y + 8.5, 0xFFA8A8A8, 0xFFA8A8A8)
				end
				scr:draw_text(96.5, y + 1.5, row[1], c4)
				scr:draw_text(96, y + 1, row[1], c3)
				if row[2] then
					-- 通常行 オプション部分
					local col_pos_num = menu.current.pos.col[i] or 1
					if col_pos_num > 0 then
						scr:draw_text(165.5, y + 1.5, string.format("%s", row[2][col_pos_num]), c4)
						scr:draw_text(165, y + 1, string.format("%s", row[2][col_pos_num]), c3)
						-- オプション部分の左右移動可否の表示
						if i == menu.current.pos.row then
							scr:draw_text(160, y + 1, "◀", col_pos_num == 1 and c5 or c3)
							scr:draw_text(223, y + 1, "▶", col_pos_num == #row[2] and c5 or c3)
						end
					end
				end
				if row[3] and row[3].outline then
					scr:draw_box(200, y + 2, 218, y + 7, row[3].outline, row[3].outline)
				end
			end

			row_num = row_num + 1
		end

		local p1, p2 = players[1], players[2]
		p1.max_pos = 0
		p1.min_pos = 1000
		p2.max_pos = 0
		p2.min_pos = 1000
	end

	local active_mem_0x100701 = {}
	for i = 0x022E, 0x0615 do active_mem_0x100701[i] = true end

	menu.state = menu.tra_main -- menu or tra_main

	emu.register_pause(function() menu.state.draw() end)

	emu.register_resume(function() global.pause = false end)

	emu.register_frame_done(function()
		if not machine then return end
		if machine.paused == false then
			menu.state.draw()
			--collectgarbage("collect")
			if global.pause then emu.pause() end
		end
	end)

	local bios_test = function()
		local ram_value1, ram_value2  = mem.r16(players[1].addr.base), mem.r16(players[2].addr.base)
		for _, test_value in ipairs({0x5555, 0xAAAA, 0xFFFF & players[1].addr.base, 0xFFFF & players[2].addr.base}) do
			if ram_value1 == test_value then
				return true
			elseif ram_value2 == test_value then
				return true
			end
		end
		return false
	end

	emu.register_periodic(function()
		auto_recovery_debug()
		if not machine then return end
		if machine.paused then return end
		local ec = scr:frame_number() -- フレーム更新しているか
		if mem.last_time == ec then return end
		mem.last_time   = ec

		-- メモリ値の読込と更新
		local _0x100701 = mem.r16(0x100701) -- 22e 22f 対戦中
		local _0x107C22 = mem.r8(0x107C22) -- 対戦中44
		local _0x10FDAF = mem.r8(0x10FDAF)
		local _0x10FDB6 = mem.r16(0x10FDB6)
		mem._0x10E043   = mem.r8(0x10E043)
		if bios_test() then
			in_match, in_player_select, mem.pached = false, false, false -- 状態リセット
			reset_memory_tap(false)
		else
			-- プレイヤーセレクト中かどうかの判定
			in_player_select = _0x100701 == 0x10B and (_0x107C22 == 0 or _0x107C22 == 0x55) and _0x10FDAF == 2 and _0x10FDB6 ~= 0 and mem._0x10E043 == 0
			-- 対戦中かどうかの判定
			in_match = active_mem_0x100701[_0x100701] ~= nil and _0x107C22 == 0x44 and _0x10FDAF == 2 and _0x10FDB6 ~= 0
			if in_match then
				mem.w16(0x10FDB6, 0x0101) -- 操作の設定
				for i, p in ipairs(players) do mem.w16(p.addr.control, i * 0x0101) end
			end
			load_rom_patch()  -- ROM部分のメモリエリアへパッチあて
			mem.wd16(0x10FE32, 0x0000) -- 強制的に家庭用モードに変更
			set_dip_config()  -- デバッグDIPのセット
			load_hit_effects() -- ヒット効果アドレステーブルの取得
			load_hit_system_stops() -- ヒット時のシステム内での中間処理による停止アドレス取得
			load_proc_base()  -- キャラの基本アドレスの取得
			load_push_box()   -- 接触判定の取得
			load_close_far()  -- 遠近間合い取得
			load_memory_tap(all_wps) -- tapの仕込み
			menu.state.proc() -- メニュー初期化前に処理されないようにする
		end
	end)
end

return exports
