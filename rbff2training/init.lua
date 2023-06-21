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
local exports              = {}
local lfs                  = require("lfs")
local convert_lib          = require("data/button_char")
local convert              = function(str)
	return str and convert_lib(str) or str
end
exports.name               = "rbff2training"
exports.version            = "0.0.1"
exports.description        = "RBFF2 Training"
exports.license            = "MIT License"
exports.author             = { name = "Sanwabear" }

local printf               = function(format, ...)
	print(string.format(format, ...))
end
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
	pgm = cpu.spaces["program"]
	scr = machine.screens:at(1)
	ioports = man.machine.ioport.ports
	debugger = machine.debugger
	base_path = function()
		local base = emu.subst_env(man.options.entries.homepath:value():match('([^;]+)')) .. '/plugins/' .. exports.name
		local dir = lfs.currentdir()
		return dir .. "/" .. base
	end
	dofile(base_path() .. "/data.lua")
end

local rbff2                = exports

-- キャラの基本データ
-- 配列のインデックス=キャラID
local chars         = {
	{ min_y = 9,  min_sy = 5, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x3, bs_addr = 0x2E, easy_bs_addr = 0x2E, acts = {}, act1sts = {}, fireballs = {}, name = "テリー・ボガード", },
	{ min_y = 10, min_sy = 4, init_stuns = 31, wakeup_frms = 20, sway_act_counts = 0x2, bs_addr = 0x2A, easy_bs_addr = 0x2A, acts = {}, act1sts = {}, fireballs = {}, name = "アンディ・ボガード", },
	{ min_y = 8,  min_sy = 3, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x4, bs_addr = 0x3A, easy_bs_addr = 0x3A, acts = {}, act1sts = {}, fireballs = {}, name = "東丈", },
	{ min_y = 10, min_sy = 4, init_stuns = 29, wakeup_frms = 17, sway_act_counts = 0x3, bs_addr = 0x22, easy_bs_addr = 0x22, acts = {}, act1sts = {}, fireballs = {}, name = "不知火舞", },
	{ min_y = 8,  min_sy = 1, init_stuns = 33, wakeup_frms = 20, sway_act_counts = 0x3, bs_addr = 0x66, easy_bs_addr = 0x4A, acts = {}, act1sts = {}, fireballs = {}, name = "ギース・ハワード", },
	{ min_y = 2,  min_sy = 5, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x2, bs_addr = 0x46, easy_bs_addr = 0x46, acts = {}, act1sts = {}, fireballs = {}, name = "望月双角", },
	{ min_y = 9,  min_sy = 6, init_stuns = 31, wakeup_frms = 20, sway_act_counts = 0x2, bs_addr = 0x2A, easy_bs_addr = 0x2A, acts = {}, act1sts = {}, fireballs = {}, name = "ボブ・ウィルソン", },
	{ min_y = 10, min_sy = 3, init_stuns = 31, wakeup_frms = 20, sway_act_counts = 0x3, bs_addr = 0x32, easy_bs_addr = 0x32, acts = {}, act1sts = {}, fireballs = {}, name = "ホンフゥ", },
	{ min_y = 9,  min_sy = 7, init_stuns = 29, wakeup_frms = 20, sway_act_counts = 0x3, bs_addr = 0x3E, easy_bs_addr = 0x3E, acts = {}, act1sts = {}, fireballs = {}, name = "ブルー・マリー", },
	{ min_y = 9,  min_sy = 4, init_stuns = 35, wakeup_frms = 20, sway_act_counts = 0x3, bs_addr = 0x2A, easy_bs_addr = 0x2A, acts = {}, act1sts = {}, fireballs = {}, name = "フランコ・バッシュ", },
	{ min_y = 9,  min_sy = 4, init_stuns = 38, wakeup_frms = 20, sway_act_counts = 0x2, bs_addr = 0x56, easy_bs_addr = 0x3A, acts = {}, act1sts = {}, fireballs = {}, name = "山崎竜二", },
	{ min_y = 11, min_sy = 1, init_stuns = 29, wakeup_frms = 20, sway_act_counts = 0xC, bs_addr = 0x3A, easy_bs_addr = 0x3A, acts = {}, act1sts = {}, fireballs = {}, name = "秦崇秀", },
	{ min_y = 11, min_sy = 4, init_stuns = 29, wakeup_frms = 20, sway_act_counts = 0xC, bs_addr = 0x36, easy_bs_addr = 0x36, acts = {}, act1sts = {}, fireballs = {}, name = "秦崇雷", },
	{ min_y = 9,  min_sy = 6, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x2, bs_addr = 0x7A, easy_bs_addr = 0x5E, acts = {}, act1sts = {}, fireballs = {}, name = "ダック・キング", },
	{ min_y = 9,  min_sy = 5, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x4, bs_addr = 0x36, easy_bs_addr = 0x36, acts = {}, act1sts = {}, fireballs = {}, name = "キム・カッファン", },
	{ min_y = 4,  min_sy = 3, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x4, bs_addr = 0x2A, easy_bs_addr = 0x2A, acts = {}, act1sts = {}, fireballs = {}, name = "ビリー・カーン", },
	{ min_y = 9,  min_sy = 6, init_stuns = 31, wakeup_frms = 20, sway_act_counts = 0x2, bs_addr = 0x2E, easy_bs_addr = 0x2E, acts = {}, act1sts = {}, fireballs = {}, name = "チン・シンザン", },
	{ min_y = 11, min_sy = 8, init_stuns = 31, wakeup_frms = 20, sway_act_counts = 0x4, bs_addr = 0x22, easy_bs_addr = 0x22, acts = {}, act1sts = {}, fireballs = {}, name = "タン・フー・ルー", },
	{ min_y = 7,  min_sy = 4, init_stuns = 35, wakeup_frms = 20, sway_act_counts = 0x4, bs_addr = 0x22, easy_bs_addr = 0x22, acts = {}, act1sts = {}, fireballs = {}, name = "ローレンス・ブラッド", },
	{ min_y = 7,  min_sy = 2, init_stuns = 35, wakeup_frms = 20, sway_act_counts = 0x3, bs_addr = 0x52, easy_bs_addr = 0x36, acts = {}, act1sts = {}, fireballs = {}, name = "ヴォルフガング・クラウザー", },
	{ min_y = 9,  min_sy = 5, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x7, bs_addr = 0x26, easy_bs_addr = 0x26, acts = {}, act1sts = {}, fireballs = {}, name = "リック・ストラウド", },
	{ min_y = 9,  min_sy = 5, init_stuns = 29, wakeup_frms = 14, sway_act_counts = 0x3, bs_addr = 0x52, easy_bs_addr = 0x32, acts = {}, act1sts = {}, fireballs = {}, name = "李香緋", },
	{ min_y = 10, min_sy = 4, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x0, bs_addr = 0x2A, easy_bs_addr = 0x2A, acts = {}, act1sts = {}, fireballs = {}, name = "アルフレッド", },
	{ min_y = 0,  min_sy = 0, init_stuns = 0,  wakeup_frms = 0,  sway_act_counts = 0x0, bs_addr = 0x0,  easy_bs_addr = 0x0,  acts = {}, act1sts = {}, fireballs = {}, name = "common", },
}

-- メニュー用変数
local menu          = {
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

	stgs = {
		{ stg1 = 0x01, stg2 = 0x00, stg3 = 0x01, no_background = false, name = "日本 [1] 舞", },
		{ stg1 = 0x01, stg2 = 0x01, stg3 = 0x01, no_background = false, name = "日本 [2] 双角1", },
		{ stg1 = 0x01, stg2 = 0x01, stg3 = 0x0F, no_background = false, name = "日本 [2] 双角2", },
		{ stg1 = 0x01, stg2 = 0x02, stg3 = 0x01, no_background = false, name = "日本 [3] アンディ", },
		{ stg1 = 0x02, stg2 = 0x00, stg3 = 0x01, no_background = false, name = "香港1 [1] チン", },
		{ stg1 = 0x02, stg2 = 0x01, stg3 = 0x01, no_background = false, name = "香港1 [2] 山崎", },
		{ stg1 = 0x03, stg2 = 0x00, stg3 = 0x01, no_background = false, name = "韓国 [1] キム", },
		{ stg1 = 0x03, stg2 = 0x01, stg3 = 0x01, no_background = false, name = "韓国 [2] タン", },
		{ stg1 = 0x04, stg2 = 0x00, stg3 = 0x01, no_background = false, name = "サウスタウン [1] ギース", },
		{ stg1 = 0x04, stg2 = 0x01, stg3 = 0x01, no_background = false, name = "サウスタウン [2] ビリー", },
		{ stg1 = 0x05, stg2 = 0x00, stg3 = 0x01, no_background = false, name = "ドイツ [1] クラウザー", },
		{ stg1 = 0x05, stg2 = 0x01, stg3 = 0x01, no_background = false, name = "ドイツ [2] ローレンス", },
		{ stg1 = 0x06, stg2 = 0x00, stg3 = 0x01, no_background = false, name = "アメリカ1 [1] ダック", },
		{ stg1 = 0x06, stg2 = 0x01, stg3 = 0x01, no_background = false, name = "アメリカ1 [2] マリー", },
		{ stg1 = 0x07, stg2 = 0x00, stg3 = 0x01, no_background = false, name = "アメリカ2 [1] テリー", },
		{ stg1 = 0x07, stg2 = 0x01, stg3 = 0x01, no_background = false, name = "アメリカ2 [2] リック", },
		{ stg1 = 0x07, stg2 = 0x02, stg3 = 0x01, no_background = false, name = "アメリカ2 [3] アルフレッド", },
		{ stg1 = 0x08, stg2 = 0x00, stg3 = 0x01, no_background = false, name = "タイ [1] ボブ", },
		{ stg1 = 0x08, stg2 = 0x01, stg3 = 0x01, no_background = false, name = "タイ [2] フランコ", },
		{ stg1 = 0x08, stg2 = 0x02, stg3 = 0x01, no_background = false, name = "タイ [3] 東", },
		{ stg1 = 0x09, stg2 = 0x00, stg3 = 0x01, no_background = false, name = "香港2 [1] 崇秀", },
		{ stg1 = 0x09, stg2 = 0x01, stg3 = 0x01, no_background = false, name = "香港2 [2] 崇雷", },
		{ stg1 = 0x0A, stg2 = 0x00, stg3 = 0x01, no_background = false, name = "NEW CHALLENGERS[1] 香緋", },
		{ stg1 = 0x0A, stg2 = 0x01, stg3 = 0x01, no_background = false, name = "NEW CHALLENGERS[2] ホンフゥ", },
		{ stg1 = 0x04, stg2 = 0x01, stg3 = 0x01, no_background = true,  name = "背景なし(2ライン)", },
		{ stg1 = 0x07, stg2 = 0x02, stg3 = 0x01, no_background = true,  name = "背景なし(1ライン)", },
	},
	bgms = {
		{ id = 0x00, name = "なし", },
		{ id = 0x01, name = "クリといつまでも", },
		{ id = 0x02, name = "雷波濤外伝", },
		{ id = 0x03, name = "タイ南部に伝わったSPの詩", },
		{ id = 0x04, name = "まいまいきゅーん", },
		{ id = 0x05, name = "ギースにしょうゆとオケヒット", },
		{ id = 0x06, name = "TAKU-HATSU-Rock", },
		{ id = 0x07, name = "蜜の味", },
		{ id = 0x08, name = "ドンチカ!!チ!!チ!!", },
		{ id = 0x09, name = "Blue Mary's BLUES", },
		{ id = 0x0A, name = "GOLI-Rock", },
		{ id = 0x0B, name = "C62 -シロクニ- Ver.2", },
		{ id = 0x0C, name = "パンドラの箱より 第3番「決断」", },
		{ id = 0x0D, name = "パンドラの箱より 第3番「決断」 ", },
		{ id = 0x0E, name = "Duck! Duck! Duck!", },
		{ id = 0x0F, name = "ソウルっす♪", },
		{ id = 0x10, name = "ロンドンマーチ", },
		{ id = 0x11, name = "ハプシュ！フゥゥゥ", },
		{ id = 0x12, name = "中国四千年の歴史とはいかにII", },
		{ id = 0x13, name = "牛とお戯れ", },
		{ id = 0x14, name = "REQUIEM K.626 [Lacrimosa]", },
		{ id = 0x15, name = "Exceed The Limit", },
		{ id = 0x16, name = "雄々盛嬢後援 ～競場詩～", },
		{ id = 0x17, name = "Get The Sky -With Your Dream-", },
		{ id = 0x1C, name = "4 HITs Ⅱ", },
		{ id = 0x1E, name = "Gain a victory", },
		{ id = 0x26, name = "NEOGEO SOUND LOGO", },
	},

	labels = {
		fix_scr_tops = { "OFF" },
		chars        = {},
		stgs         = {},
		bgms         = {},
		off_on       = { "OFF", "ON" }
	},
}
for _, char in ipairs(chars) do
	if char.name ~= "common" then
		table.insert(menu.labels.chars, char.name)
	end
end
for i = -20, 70 do
	table.insert(menu.labels.fix_scr_tops, "1P " .. i)
end
for i = -20, 70 do
	table.insert(menu.labels.fix_scr_tops, "2P " .. i)
end
for _, stg in ipairs(menu.stgs) do
	table.insert(menu.labels.stgs, stg.name)
end
for _, bgm in ipairs(menu.bgms) do
	local exists = false
	for _, name in pairs(menu.labels.bgms) do
		if name == bgm.name then
			exists = true
			bgm.name_idx = #menu.labels.bgms
			break
		end
	end
	if not exists then
		table.insert(menu.labels.bgms, bgm.name)
		bgm.name_idx = #menu.labels.bgms
	end
end

local mem                  = {
	last_time          = 0,        -- 最終読込フレーム(キャッシュ用)
	_0x100701          = 0,        -- 場面判定用
	_0x107C22          = 0,        -- 場面判定用
	old_0x107C2A       = 0,        -- ラグチェック用
	_0x107C2A          = 0,        -- ラグチェック用
	_0x10B862          = 0,        -- ガードヒット=FF
	_0x100F56          = 0,        -- 潜在発動時の停止時間
	_0x10FD82          = 0,        -- console 0x00, mvs 0x01
	_0x10FDAF          = 0,        -- 場面判定用
	_0x10FDB6          = 0,        -- P1 P2 開始判定用
	_0x10E043          = 0,        -- 手動でポーズしたときに00以外になる
	_0x10CDD0          = 0x10CDD0, -- プレイヤー選択のハック用
	biostest           = false,    -- 初期化中のときtrue
	stage_base_addr    = 0x100E00,
	close_far_offset   = 0x02AE08, -- 近距離技と遠距離技判断用のデータの開始位置
	close_far_offset_d = 0x02DDAA, -- 対ラインの近距離技と遠距離技判断用のデータの開始位置
}
local match_active         = false -- 対戦画面のときtrue
local player_select_active = false -- プレイヤー選択画面のときtrue
local p_space              = 0     -- 1Pと2Pの間隔
local prev_p_space         = 0     -- 1Pと2Pの間隔(前フレーム)

local screen               = {
	offset_x = 0x20,
	offset_z = 0x24,
	offset_y = 0x28,
	left     = 0,
	top      = 0,
}

local bios_test            = function()
	for _, addr in ipairs({ 0x100400, 0x100500 }) do
		local ram_value = pgm:read_u8(addr)
		for _, test_value in ipairs({ 0x5555, 0xAAAA, (0xFFFF & addr) }) do
			if ram_value == test_value then
				return true
			end
		end
	end
end

local new_set = function(...)
	local ret = {}
	for _, v in ipairs({ ... }) do
		ret[v] = true
	end
	return ret
end

local table_to_set = function(tbl)
	local ret = {}
	for _, v in ipairs(tbl) do
		ret[v] = true
	end
	return ret
end

local global = {
	frame_number        = 0,
	lag_frame           = false,
	all_act_normal      = false,
	old_all_act_normal  = false,

	-- 当たり判定用
	axis_color          = 0xFF797979,
	axis_air_color      = 0xFFCC00CC,
	axis_internal_color = 0xFF00FFFF,
	axis_size           = 12,
	axis_size2          = 5,
	no_alpha            = true, --fill = 0x00, outline = 0xFF for all box types
	throwbox_height     = 200, --default for ground throws
	no_background       = false,
	no_background_addr  = 0x10DDF0,
	fix_pos             = false,
	fix_pos_bps         = nil,
	no_bars             = false,
	sync_pos_x          = 1,  -- 1: OFF, 2:1Pと同期, 3:2Pと同期

	disp_pos            = true, -- 1P 2P 距離表示
	disp_effect         = true, -- ヒットマークなど画面表示するときtrue
	disp_effect_bps     = nil,
	disp_frmgap         = 3,  -- フレーム差表示
	disp_input_sts      = 1,  -- コマンド入力状態表示 1:OFF 2:1P 3:2P
	disp_normal_frms    = 1,  -- 通常動作フレーム非表示 1:OFF 2:ON
	pause_hit           = 1,  -- 1:OFF, 2:ON, 3:ON:やられのみ 4:ON:投げやられのみ 5:ON:打撃やられのみ 6:ON:ガードのみ
	pause_hitbox        = 1,  -- 判定発生時にポーズ
	pause               = false,
	replay_stop_on_dmg  = false, -- ダメージでリプレイ中段

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
	infinity_life2      = true,
	pow_mode            = 2, -- POWモード　1:自動回復 2:固定 3:通常動作
	disp_gauge          = true,
	repeat_interval     = 0,
	await_neutral       = false,
	replay_fix_pos      = 1,  -- 開始間合い固定 1:OFF 2:位置記憶 3:1Pと2P 4:1P 5:2P
	replay_reset        = 2,  -- 状態リセット   1:OFF 2:1Pと2P 3:1P 4:2P
	mame_debug_wnd      = false, -- MAMEデバッグウィンドウ表示のときtrue
	damaged_move        = 1,
	disp_replay         = true, -- レコードリプレイガイド表示
	save_snapshot       = 1,  -- 技画像保存 1:OFF 2:新規 3:上書き
	-- log
	log                 = {
		poslog  = false, -- 位置ログ
		atklog  = false, -- 攻撃情報ログ
		baselog = false, -- フレーム事の処理アドレスログ
		keylog  = false, -- 入力ログ
		rvslog  = false, -- リバサログ
	},
	new_hook_holder     = function()
		return { bps = {}, wps = {}, on = true, }
	end,

	wp                  = function(wps, rw, addr, len, cond, exec)
		table.insert(wps, cpu.debug:wpset(pgm, rw, addr, len, cond or 1, exec or ""))
	end,
	bp                  = function(bps, addr, cond, exec)
		table.insert(bps, cpu.debug:bpset(addr, cond or 1, exec or ""))
	end,
	set_bps             = function(disable, holder)
		if disable == true and holder.on == true then
			for _, bp in ipairs(holder.bps) do
				cpu.debug:bpdisable(bp)
			end
			holder.on = false
		elseif disable ~= true and holder.on ~= true then
			for _, bp in ipairs(holder.bps) do
				cpu.debug:bpenable(bp)
			end
			holder.on = true
		end
	end,
	set_wps             = function(disable, holder)
		if disable == true and holder.on == true then
			for _, wp in ipairs(holder.wps) do
				cpu.debug:wpdisable(wp)
			end
			holder.on = false
		elseif disable ~= true and holder.on ~= true then
			for _, wp in ipairs(holder.wps) do
				cpu.debug:wpenable(wp)
			end
			holder.on = true
		end
	end,
}
local damaged_moves = {
	0x00000, 0x58C84, 0x58DCC, 0x58DBC, 0x58DDC, 0x58FDE, 0x58DEC, 0x590EA, 0x59D70, 0x59FFA,
	0x5A178, 0x5A410, 0x591DA, 0x592F6, 0x593EE, 0x593DA, 0x59508, 0x59708, 0x596FC, 0x30618,
	0x2FFE8, 0x30130, 0x3051C, 0x307B4, 0x30AC0, 0x5980E, 0x58E52, 0x306DE, 0x595CE, 0x58E08,
	0x30F0E, 0x30D74, 0x30E08, 0x316F8, 0x31794, 0x31986, 0x31826, 0x315E6, 0x324C0, 0x32C42,
	0x331CE, 0x336B8, 0x33CC2, 0x33ED6, 0x58C84, 0x325E8, 0x58C84, 0x341AC, 0x31394, 0x58FC6,
	0x590D6, 0x592DA, 0x593C6, 0x593B2, 0x594E0, 0x596F0, 0x596E4, 0x3060C, 0x30128, 0x30516,
	0x3075C, 0x30A68, 0x58C84, 0x3256A, 0x58D8A, 0x58DA0, 0x58DAE, 0x59090, 0x346E0, 0x3278E,
	0x3294C, 0x332E0, 0x349F2, 0x34CF4, 0x34ACC, 0x31AC6, 0x34E40, 0x31CA8, 0x30612, 0x33AC2,
	0x301FC, 0x301F4, 0x3031A, 0x30312,
}
local hit_effect_types = {
	down = "ダ",           -- ダウン
	extra = "特",          -- 特殊なやられ
	extra_launch = "特浮", -- 特殊な空中追撃可能ダウン
	force_stun = "気",     -- 強制気絶
	fukitobi = "吹",       -- 吹き飛び
	hikikomi = "後",       -- 後ろ向きのけぞり
	hikikomi_launch = "後浮", -- 後ろ向き浮き
	launch = "浮",         -- 空中とダウン追撃可能ダウン
	launch2 = "浮の～浮", -- 浮のけぞり～ダウン
	launch_nokezori = "浮の", -- 浮のけぞり
	nokezori = "の",       -- のけぞり
	nokezori2 = "*の", -- のけぞり 対スウェー時はダウン追撃可能ダウン
	otg_down = "*ダ", -- ダウン追撃可能ダウン
	plane_shift = "送",    -- スウェーライン送り
	plane_shift_down = "送ダ", -- スウェーライン送りダウン
	standup = "立",        -- 強制立のけぞり
}
local hit_effect_nokezoris = new_set(
	hit_effect_types.nokezori,
	hit_effect_types.nokezori2,
	hit_effect_types.standup,
	hit_effect_types.hikikomi,
	hit_effect_types.plane_shift)
local hit_effects = {
	{ hit_effect_types.nokezori,         hit_effect_types.fukitobi },
	{ hit_effect_types.nokezori,         hit_effect_types.fukitobi },
	{ hit_effect_types.nokezori,         hit_effect_types.fukitobi },
	{ hit_effect_types.nokezori,         hit_effect_types.fukitobi },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.standup,          hit_effect_types.fukitobi },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.nokezori,         hit_effect_types.fukitobi },
	{ hit_effect_types.nokezori2,        hit_effect_types.fukitobi },
	{ hit_effect_types.plane_shift,      hit_effect_types.plane_shift_down },
	{ hit_effect_types.plane_shift_down, hit_effect_types.plane_shift_down, hit_effect_types.otg_down },
	{ hit_effect_types.fukitobi,         hit_effect_types.fukitobi },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.nokezori,         hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.nokezori,         hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.nokezori,         hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.fukitobi,         hit_effect_types.fukitobi },
	{ hit_effect_types.down,             hit_effect_types.down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down },
	{ hit_effect_types.down,             hit_effect_types.down },
	{ hit_effect_types.down,             hit_effect_types.down },
	{ hit_effect_types.hikikomi,         hit_effect_types.fukitobi },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.nokezori,         hit_effect_types.down },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.nokezori,         hit_effect_types.down },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.standup,          hit_effect_types.standup },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.extra,            hit_effect_types.extra },
	{ hit_effect_types.extra_launch,     hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.nokezori,         hit_effect_types.fukitobi },
	{ hit_effect_types.force_stun,       hit_effect_types.force_stun,       hit_effect_types.otg_down },
	{ hit_effect_types.nokezori,         hit_effect_types.fukitobi },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.extra,            hit_effect_types.extra },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.nokezori,         hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.nokezori,         hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.nokezori,         hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.nokezori,         hit_effect_types.fukitobi },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.launch_nokezori,  hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.launch_nokezori,  hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.hikikomi_launch,  hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.extra,            hit_effect_types.extra },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.launch2,          hit_effect_types.launch2,          hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down },
	{ hit_effect_types.launch,           hit_effect_types.launch },
	{ hit_effect_types.extra,            hit_effect_types.extra },
	{ hit_effect_types.launch,           hit_effect_types.launch },
	{ hit_effect_types.extra,            hit_effect_types.extra },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
	{ hit_effect_types.down,             hit_effect_types.down,             hit_effect_types.otg_down },
	{ hit_effect_types.launch,           hit_effect_types.launch,           hit_effect_types.otg_down },
}
local damaged_move_keys = {}
for i = 1, #damaged_moves do
	local k = i == 1 and "通常" or string.format("%2s %s", i - 2, hit_effects[i - 1][1])
	table.insert(damaged_move_keys, k)
end

-- DIPスイッチ
local dip_config ={
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
}

-- 行動の種類
local act_types = { free = -1, attack = 0, low_attack = 1, provoke =  2, any = 3, overhead = 4, block = 5, hit = 6, }

local sts_flg_names = {
	[0xC0] = {
		"ジャンプ振向",
		"ダウン",
		"屈途中",
		"奥後退",
		"奥前進",
		"奥振向",
		"屈振向",
		"立振向",
		"スウェーライン上飛び退き～戻り",
		"スウェーライン上ダッシュ～戻り",
		"スウェーライン→メイン",
		"スウェーライン上立",
		"メインライン→スウェーライン移動中",
		"スウェーライン上維持",
		"未確認",
		"未確認",
		"着地",
		"ジャンプ移行",
		"後方小ジャンプ",
		"前方小ジャンプ",
		"垂直小ジャンプ",
		"後方ジャンプ",
		"前方ジャンプ",
		"垂直ジャンプ",
		"ダッシュ",
		"飛び退き",
		"屈前進",
		"立途中",
		"屈",
		"後退",
		"前進",
		"立",
	},
	[0xC4] = {
		"避け攻撃",
		"対スウェーライン下段攻撃",
		"対スウェーライン上段攻撃",
		"対メインライン威力大攻撃",
		"対メインラインB攻撃",
		"対メインラインA攻撃",
		"後方小ジャンプC", -- 27 7FC0000
		"後方小ジャンプB",
		"後方小ジャンプA",
		"前方小ジャンプC",
		"前方小ジャンプB",
		"前方小ジャンプA",
		"垂直小ジャンプC",
		"垂直小ジャンプB",
		"垂直小ジャンプA", -- 19
		"後方ジャンプC", -- 18 1FF00
		"後方ジャンプB",
		"後方ジャンプA",
		"前方ジャンプC",
		"前方ジャンプB",
		"前方ジャンプA",
		"垂直ジャンプC",
		"垂直ジャンプB",
		"垂直ジャンプA", --9
		"C4 24",
		"C4 25",
		"屈C",
		"屈B",
		"屈A",
		"立C",
		"立B",
		"立A",
	},
	[0xC8] = {
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"特殊技",
		"",
		"",
		"特殊技",
		"特殊技",
		"特殊技",
		"特殊技",
		"特殊技",
		"潜在能力",
		"潜在能力",
		"超必殺技",
		"超必殺技",
		"必殺技",
		"必殺技",
		"必殺技",
		"必殺技",
		"必殺技",
		"必殺技",
		"必殺技",
		"必殺技",
		"必殺技",
		"必殺技",
		"必殺技",
		"必殺技",
	},
	[0xCC] = {
		"CA",
		"AかB攻撃",
		"滑り",
		"必殺投げやられ",
		"",
		"空中ガード",
		"屈ガード",
		"立ガード",
		"投げ派生やられ",
		"つかみ投げやられ",
		"投げられ",
		"",
		"ライン送りやられ",
		"ダウン",
		"空中やられ",
		"地上やられ",
		"",
		"気絶",
		"気絶起き上がり",
		"挑発",
		"ブレイクショット",
		"必殺技中",
		"",
		"起き上がり",
		"フェイント",
		"つかみ技",
		"",
		"投げ追撃",
		"",
		"",
		"空中投げ",
		"投げ",
	},
	[0xD0] = {
		"",
		"",
		"",
		"ギガティック投げられ",
		"",
		"追撃投げ中",
		"ガード中、やられ中",
		"攻撃ヒット",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
	},
}
local get_flag_name = function(flags, names)
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
-- !!注意!!後隙が配列の後ろに来るように定義すること
local char_acts_base = {
	-- テリー・ボガード
	{
		{ startup = true,  names = { "スウェー戻り" },                      type = act_types.any,        ids = { 0x36, }, },
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                        type = act_types.attack,     ids = { 0x62, 0x63, 0x64, }, },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                        type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C, }, },
		{ startup = true,  names = { "近立C" },                                 type = act_types.attack,     ids = { 0x43, }, },
		{ startup = true,  names = { "立B" },                                    type = act_types.attack,     ids = { 0x45, }, },
		{ startup = true,  names = { "立C" },                                    type = act_types.attack,     ids = { 0x46, }, },
		{ startup = true,  names = { "屈A" },                                    type = act_types.attack,     ids = { 0x47, }, },
		{ startup = true,  names = { "フェイント パワーゲイザー" },   type = act_types.any,        ids = { 0x113, }, },
		{ startup = true,  names = { "フェイント バーンナックル" },   type = act_types.any,        ids = { 0x112, }, },
		{ startup = true,  names = { "バスタースルー" },                   type = act_types.any,        ids = { 0x6D, 0x6E, }, },
		{ startup = true,  names = { "ワイルドアッパー" },                type = act_types.attack,     ids = { 0x69, }, },
		{ startup = true,  names = { "バックスピンキック" },             type = act_types.attack,     ids = { 0x68, }, },
		{ startup = true,  names = { "チャージキック" },                   type = act_types.overhead,   ids = { 0x6A, }, },
		{ startup = true,  names = { "小バーンナックル" },                type = act_types.attack,     ids = { 0x86, 0x87, }, },
		{ startup = false,  names = { "小バーンナックル" },                type = act_types.any,        ids = { 0x88, }, },
		{ startup = true,  names = { "大バーンナックル" },                type = act_types.attack,     ids = { 0x90, 0x91, }, },
		{ startup = false, names = { "大バーンナックル" },                type = act_types.any,        ids = { 0x92, }, },
		{ startup = true,  names = { "パワーウェイブ" },                   type = act_types.attack,     ids = { 0x9A, 0x9B, 0x9C, },                         firing = true, },
		{ startup = true,  names = { "ラウンドウェイブ" },                type = act_types.low_attack, ids = { 0xA4, 0xA5, },                               firing = true, },
		{ startup = false, names = { "ラウンドウェイブ" },                type = act_types.any,        ids = { 0xA6, }, },
		{ startup = true,  names = { "ファイヤーキック" },                type = act_types.low_attack, ids = { 0xB8, 0xB9, }, },
		{ startup = false, names = { "ファイヤーキック" },                type = act_types.any,        ids = { 0xBC, }, },
		{ startup = true,  names = { "ファイヤーキック ヒット" },      type = act_types.attack,     ids = { 0xBA, 0xBB, }, },
		{ startup = true,  names = { "クラックシュート" },                type = act_types.attack,     ids = { 0xAE, 0xAF, }, },
		{ startup = false, names = { "クラックシュート" },                type = act_types.any,        ids = { 0xB0, }, },
		{ startup = true,  names = { "ライジングタックル" },             type = act_types.attack,     ids = { 0xCC, 0xCD, 0xCE, }, },
		{ startup = false, names = { "ライジングタックル" },             type = act_types.any,        ids = { 0xCF, 0xD0, }, },
		{ startup = true,  names = { "パッシングスウェー" },             type = act_types.attack,     ids = { 0xC2, 0xC3, }, },
		{ startup = false, names = { "パッシングスウェー" },             type = act_types.attack,     ids = { 0xC4, }, },
		{ startup = true,  names = { "パワーゲイザー" },                   type = act_types.attack,     ids = { 0xFE, 0xFF, },                               firing = true, },
		{ startup = false, names = { "パワーゲイザー" },                   type = act_types.attack,     ids = { 0x100, },                                    firing = true, },
		{ startup = true,  names = { "トリプルゲイザー" },                type = act_types.attack,     ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, }, firing = true, },
		{ startup = false, names = { "トリプルゲイザー" },                type = act_types.attack,     ids = { 0x10E, }, },
		{ startup = true,  names = { "CA 立B" },                                 type = act_types.attack,     ids = { 0x241, }, },
		{ startup = true,  names = { "CA 屈B" },                                 type = act_types.low_attack, ids = { 0x242, }, },
		{ startup = true,  names = { "CA 立C" },                                 type = act_types.attack,     ids = { 0x244, }, },
		{ startup = true,  names = { "CA _6C" },                                  type = act_types.attack,     ids = { 0x245, }, },
		{ startup = true,  names = { "CA _3C" },                                  type = act_types.attack,     ids = { 0x246, }, },
		{ startup = true,  names = { "CA 屈C" },                                 type = act_types.low_attack, ids = { 0x247, }, },
		{ startup = true,  names = { "CA 屈C" },                                 type = act_types.low_attack, ids = { 0x247, }, },
		{ startup = true,  names = { "CA 立C" },                                 type = act_types.attack,     ids = { 0x240, }, },
		{ startup = true,  names = { "CA 立C" },                                 type = act_types.attack,     ids = { 0x24C, }, },
		{ startup = true,  names = { "CA 屈C" },                                 type = act_types.attack,     ids = { 0x243, }, },
		{ startup = true,  names = { "パワーチャージ" },                   type = act_types.attack,     ids = { 0x24D, }, },
		{ startup = true,  names = { "CA 対スウェーライン上段攻撃" }, type = act_types.overhead,     ids = { 0x24A, }, },
		{ startup = true,  names = { "CA 対スウェーライン下段攻撃" }, type = act_types.low_attack, ids = { 0x24B, }, },
		{ startup = true,  names = { "パワーダンク" },                      type = act_types.attack,     ids = { 0xE0, }, },
		{ startup = false,  names = { "パワーダンク" },                      type = act_types.overhead,     ids = { 0xE1, }, },
		{ startup = false,  names = { "パワーダンク" },                      type = act_types.attack,     ids = { 0xE2, }, },
		{ startup = true,  names = { "CA 立C" },                                 type = act_types.attack,     ids = { 0x248, }, },
		{ startup = true,  names = { "CA 立C" },                                 type = act_types.attack,     ids = { 0x249, }, },
	},
	-- アンディ・ボガード
	{
		{ startup = true,  names = { "スウェー戻り" },           type = act_types.any,        ids = { 0x36 } },
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },             type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },             type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                      type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                      type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                      type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                         type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント 残影拳" },    type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "フェイント 飛翔拳" },    type = act_types.any,        ids = { 0x113 } },
		{ startup = true,  names = { "フェイント 超裂破弾" }, type = act_types.any,        ids = { 0x114 } },
		{ startup = true,  names = { "内股" },                       type = act_types.attack,     ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "上げ面" },                    type = act_types.attack,     ids = { 0x69 } },
		{ startup = true,  names = { "浴びせ蹴り" },              type = act_types.attack,     ids = { 0x68 } },
		{ startup = true,  names = { "小残影拳" },                 type = act_types.attack,     ids = { 0x86, 0x87, 0x8A } },
		{ startup = false, names = { "小残影拳" },                 type = act_types.any,        ids = { 0x88, 0x89 } },
		{ startup = true,  names = { "大残影拳" },                 type = act_types.attack,     ids = { 0x90, 0x91, 0x94 } },
		{ startup = false, names = { "大残影拳" },                 type = act_types.any,        ids = { 0x92 } },
		{ startup = true,  names = { "疾風裏拳" },                 type = act_types.attack,     ids = { 0x95 } },
		{ startup = false, names = { "大残影拳", "疾風裏拳" }, type = act_types.any,        ids = { 0x93 } },
		{ startup = true,  names = { "飛翔拳" },                    type = act_types.attack,     ids = { 0x9A, 0x9B, 0x9C },        firing = true },
		{ startup = true,  names = { "激飛翔拳" },                 type = act_types.attack,     ids = { 0xA7, 0xA4, 0xA5 },        firing = true },
		{ startup = false, names = { "激飛翔拳" },                 type = act_types.any,        ids = { 0xA6 } },
		{ startup = true,  names = { "昇龍弾" },                    type = act_types.attack,     ids = { 0xAE, 0xAF } },
		{ startup = false, names = { "昇龍弾" },                    type = act_types.any,        ids = { 0xB0, 0xB1 } },
		{ startup = true,  names = { "空破弾" },                    type = act_types.attack,     ids = { 0xB8, 0xB9, 0xBA } },
		{ startup = false, names = { "空破弾" },                    type = act_types.any,        ids = { 0xBB } },
		{ startup = true,  names = { "幻影不知火" },              type = act_types.attack,     ids = { 0xC8, 0xC2 } },
		{ startup = false, names = { "幻影不知火" },              type = act_types.any,        ids = { 0xC3 } },
		{ startup = true,  names = { "幻影不知火 地上攻撃" }, type = act_types.attack,     ids = { 0xC4, 0xC5, 0xC6 } },
		{ startup = false, names = { "幻影不知火 地上攻撃" }, type = act_types.any,        ids = { 0xC7 } },
		{ startup = true,  names = { "超裂破弾" },                 type = act_types.attack,     ids = { 0xFE, 0xFF, 0x100, 0x101 } },
		{ startup = true,  names = { "男打弾" },                    type = act_types.attack,     ids = { 0x108, 0x109, 0x10A },     firing = true },
		{ startup = true,  names = { "男打弾 2段目" },            type = act_types.attack,     ids = { 0x10B },                   firing = true },
		{ startup = true,  names = { "男打弾 3段目" },            type = act_types.attack,     ids = { 0x10C },                   firing = true },
		{ startup = true,  names = { "男打弾 4段目" },            type = act_types.attack,     ids = { 0x10D },                   firing = true },
		{ startup = true,  names = { "男打弾 5段目" },            type = act_types.attack,     ids = { 0x10E, 0x10F },            firing = true },
		{ startup = true,  names = { "CA 立B" },                      type = act_types.attack,     ids = { 0x240 } },
		{ startup = true,  names = { "CA 屈B" },                      type = act_types.low_attack, ids = { 0x241 } },
		{ startup = true,  names = { "CA 立C" },                      type = act_types.attack,     ids = { 0x242 } },
		{ startup = true,  names = { "CA _6C" },                       type = act_types.attack,     ids = { 0x243 } },
		{ startup = true,  names = { "CA _3C" },                       type = act_types.attack,     ids = { 0x245 } },
		{ startup = true,  names = { "CA 屈C" },                      type = act_types.low_attack, ids = { 0x246 } },
		{ startup = true,  names = { "CA 立C" },                      type = act_types.attack,     ids = { 0x244 } },
		{ startup = true,  names = { "浴びせ蹴り 追撃" },       type = act_types.attack,     ids = { 0xF4, 0xF5 } },
		{ startup = false, names = { "浴びせ蹴り 追撃" },       type = act_types.any,        ids = { 0xF6 } },
		{ startup = true,  names = { "上げ面追加 B" },            type = act_types.attack,     ids = { 0x24A, 0x24B } },
		{ startup = false, names = { "上げ面追加 B" },            type = act_types.any,        ids = { 0x24C } },
		{ startup = true,  names = { "上げ面追加 C" },            type = act_types.overhead,   ids = { 0x24D } },
		{ startup = false, names = { "上げ面追加 C" },            type = act_types.any,        ids = { 0x24E } },
		{ startup = true,  names = { "上げ面追加 立C" },         type = act_types.attack,     ids = { 0x247 } },
		{ startup = false, names = { "上げ面追加 立C" },         type = act_types.attack,     ids = { 0x248 } },
	},
	-- 東丈
	{
		{ startup = true,  names = { "スウェー戻り" },                                                   type = act_types.any,        ids = { 0x36 } },
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                                                     type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                                                     type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                                                              type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                                                              type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                                                              type = act_types.attack,     ids = { 0x46, 0xF7 } },
		{ startup = true,  names = { "屈A" },                                                                 type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント スラッシュキック" },                             type = act_types.any,        ids = { 0x113 } },
		{ startup = true,  names = { "フェイント ハリケーンアッパー" },                          type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "ジョースペシャル" },                                             type = act_types.any,        ids = { 0x6D, 0x6E, 0x6F, 0x70, 0x71 } },
		{ startup = true,  names = { "夏のおもひで" },                                                   type = act_types.any,        ids = { 0x24E, 0x24F } },
		{ startup = true,  names = { "膝地獄" },                                                            type = act_types.any,        ids = { 0x81, 0x82, 0x83, 0x84 } },
		{ startup = true,  names = { "スライディング" },                                                type = act_types.low_attack, ids = { 0x68, 0xF4 } },
		{ startup = false,  names = { "スライディング" },                                                type = act_types.any, ids = { 0xF5 } },
		{ startup = true,  names = { "ハイキック" },                                                      type = act_types.attack,     ids = { 0x69 } },
		{ startup = true,  names = { "炎の指先" },                                                         type = act_types.any,        ids = { 0x6A } },
		{ startup = true,  names = { "小スラッシュキック" },                                          type = act_types.attack,     ids = { 0x86, 0x87, 0x88 } },
		{ startup = false, names = { "小スラッシュキック" },                                          type = act_types.any,        ids = { 0x89 } },
		{ startup = true,  names = { "大スラッシュキック" },                                          type = act_types.attack,     ids = { 0x90, 0x91 } },
		{ startup = true,  names = { "大スラッシュキック ヒット" },                                type = act_types.attack,     ids = { 0x92 } },
		{ startup = false, names = { "大スラッシュキック", "大スラッシュキック ヒット" }, type = act_types.any,        ids = { 0x93, 0x94 } },
		{ startup = true,  names = { "黄金のカカト" },                                                   type = act_types.attack,     ids = { 0x9A, 0x9B } },
		{ startup = false, names = { "黄金のカカト" },                                                   type = act_types.any,        ids = { 0x9C } },
		{ startup = true,  names = { "タイガーキック" },                                                type = act_types.attack,     ids = { 0xA4, 0xA5 } },
		{ startup = false, names = { "タイガーキック" },                                                type = act_types.any,        ids = { 0xA6, 0xA7 } },
		{ startup = true,  names = { "爆裂拳", "爆裂拳 持続" },                                        type = act_types.attack,     ids = { 0xAE, 0xB0, 0xB1 } },
		{ startup = true,  names = { "爆裂拳 持続" },                                                     type = act_types.attack,     ids = { 0xAF } },
		{ startup = true,  names = { "爆裂拳 隙" },                                                        type = act_types.any,        ids = { 0xB2 } },
		{ startup = true,  names = { "爆裂フック" },                                                      type = act_types.attack,     ids = { 0xB3, 0xB4 } },
		{ startup = false, names = { "爆裂フック" },                                                      type = act_types.any,        ids = { 0xB5 } },
		{ startup = true,  names = { "爆裂アッパー" },                                                   type = act_types.attack,     ids = { 0xF8, 0xF9, 0xFA } },
		{ startup = false, names = { "爆裂アッパー" },                                                   type = act_types.any,        ids = { 0xFB } },
		{ startup = true,  names = { "ハリケーンアッパー" },                                          type = act_types.attack,     ids = { 0xB9, 0xBA },                                                      firing = true },
		{ startup = false, names = { "ハリケーンアッパー" },                                          type = act_types.any,        ids = { 0xB8 } },
		{ startup = true,  names = { "爆裂ハリケーン" },                                                type = act_types.attack,     ids = { 0xC2, 0xC3, 0xC4, 0xC5 },                                          firing = true },
		{ startup = false, names = { "爆裂ハリケーン" },                                                type = act_types.any,        ids = { 0xC6 } },
		{ startup = true,  names = { "スクリューアッパー" },                                          type = act_types.attack,     ids = { 0xFE, 0xFF },                                                      firing = true },
		{ startup = false, names = { "スクリューアッパー" },                                          type = act_types.any,        ids = { 0x100 } },
		{ startup = true,  names = { "サンダーファイヤー(C)" },                                       type = act_types.attack,     ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x10E, 0x10F, 0x110 } },
		{ startup = false, names = { "サンダーファイヤー(C)" },                                       type = act_types.any,        ids = { 0x111 } },
		{ startup = true,  names = { "サンダーファイヤー(D)" },                                       type = act_types.attack,     ids = { 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA } },
		{ startup = false, names = { "サンダーファイヤー(D)" },                                       type = act_types.any,        ids = { 0xEB } },
		{ startup = true,  names = { "CA 立A" },                                                              type = act_types.attack,     ids = { 0x24B } },
		{ startup = true,  names = { "CA 立B" },                                                              type = act_types.attack,     ids = { 0x42 } },
		{ startup = true,  names = { "CA 立B" },                                                              type = act_types.attack,     ids = { 0x244 } },
		{ startup = true,  names = { "CA 立C" },                                                              type = act_types.attack,     ids = { 0x245 } },
		{ startup = true,  names = { "CA 屈B" },                                                              type = act_types.low_attack, ids = { 0x48 } },
		{ startup = true,  names = { "CA 立A" },                                                              type = act_types.attack,     ids = { 0x24C } },
		{ startup = true,  names = { "CA 立B" },                                                              type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "CA _3C" },                                                               type = act_types.attack,     ids = { 0x246 } },
		{ startup = true,  names = { "CA 立C" },                                                              type = act_types.attack,     ids = { 0x240 } },
		{ startup = true,  names = { "CA _8C" },                                                               type = act_types.overhead,   ids = { 0x251, 0x252 } },
		{ startup = true,  names = { "CA _8C" },                                                               type = act_types.any,        ids = { 0x253 } },
		{ startup = true,  names = { "CA 立C" },                                                              type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "CA _2_3_6+C" },                                                          type = act_types.attack,     ids = { 0x24A } },
	},
	-- 不知火舞
	{
		{ startup = true,  names = { "スウェー戻り" },                      type = act_types.any,        ids = { 0x36 } },
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                        type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                        type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                                 type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                                 type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                                 type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "遠立C" },                                 type = act_types.attack,     ids = { 0xF4 } },
		{ startup = true,  names = { "屈A" },                                    type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント 花蝶扇" },               type = act_types.attack,     ids = { 0x112 } },
		{ startup = true,  names = { "フェイント 花嵐" },                  type = act_types.attack,     ids = { 0x113 } },
		{ startup = true,  names = { "風車崩し・改" },                      type = act_types.attack,     ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "夢桜・改" },                            type = act_types.attack,     ids = { 0x72, 0x73 } },
		{ startup = true,  names = { "跳ね蹴り" },                            type = act_types.attack,     ids = { 0x68 } },
		{ startup = true,  names = { "三角跳び" },                            type = act_types.any,        ids = { 0x69 } },
		{ startup = true,  names = { "龍の舞" },                               type = act_types.attack,     ids = { 0x6A } },
		{ startup = true,  names = { "花蝶扇" },                               type = act_types.attack,     ids = { 0x86, 0x87, 0x88 },        firing = true },
		{ startup = true,  names = { "龍炎舞" },                               type = act_types.attack,     ids = { 0x90, 0x91 },              firing = true },
		{ startup = false, names = { "龍炎舞" },                               type = act_types.any,        ids = { 0x92 } },
		{ startup = true,  names = { "小夜千鳥" },                            type = act_types.attack,     ids = { 0x9A, 0x9B } },
		{ startup = false, names = { "小夜千鳥" },                            type = act_types.any,        ids = { 0x9C } },
		{ startup = true,  names = { "必殺忍蜂" },                            type = act_types.attack,     ids = { 0xA4, 0xA5, 0xA6 } },
		{ startup = false, names = { "必殺忍蜂" },                            type = act_types.any,        ids = { 0xA7 } },
		{ startup = true,  names = { "ムササビの舞" },                      type = act_types.attack,     ids = { 0xAE, 0xAF, 0xB0 } },
		{ startup = false, names = { "ムササビの舞" },                      type = act_types.any,        ids = { 0xB0 } },
		{ startup = true,  names = { "超必殺忍蜂" },                         type = act_types.attack,     ids = { 0xFE, 0xFF, 0x100, 0x101 } },
		{ startup = false, names = { "超必殺忍蜂" },                         type = act_types.any,        ids = { 0x102, 0x103 } },
		{ startup = true,  names = { "花嵐" },                                  type = act_types.attack,     ids = { 0x108 } },
		{ startup = true,  names = { "花嵐 突進" },                           type = act_types.attack,     ids = { 0x109 } },
		{ startup = false, names = { "花嵐 突進" },                           type = act_types.any,        ids = { 0x10F } },
		{ startup = true,  names = { "花嵐 上昇" },                           type = act_types.any,        ids = { 0x10A, 0x10B, 0x10C } },
		{ startup = false, names = { "花嵐 上昇" },                           type = act_types.any,        ids = { 0x10D, 0x10E } },
		{ startup = true,  names = { "CA 立B" },                                 type = act_types.attack,     ids = { 0x42 } },
		{ startup = true,  names = { "CA 立C" },                                 type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "CA 屈B" },                                 type = act_types.low_attack, ids = { 0x242 } },
		{ startup = true,  names = { "CA 屈C" },                                 type = act_types.attack,     ids = { 0x243 } },
		{ startup = true,  names = { "CA _3C" },                                  type = act_types.attack,     ids = { 0x244 } },
		{ startup = true,  names = { "CA 立C" },                                 type = act_types.attack,     ids = { 0x246 } },
		{ startup = true,  names = { "CA 対スウェーライン上段攻撃" }, type = act_types.overhead,     ids = { 0x249 } },
		{ startup = true,  names = { "CA C" },                                    type = act_types.attack,     ids = { 0x24A, 0x24B } },
		{ startup = true,  names = { "CA C" },                                    type = act_types.any,        ids = { 0x24C } },
		{ startup = true,  names = { "CA B" },                                    type = act_types.overhead,   ids = { 0x24D } },
		{ startup = true,  names = { "CA B" },                                    type = act_types.any,        ids = { 0x24E } },
		{ startup = true,  names = { "CA C" },                                    type = act_types.overhead,   ids = { 0x24F } },
		{ startup = true,  names = { "CA C" },                                    type = act_types.any,        ids = { 0x250 } },
		{ startup = true,  names = { "CA 屈C" },                                 type = act_types.attack,     ids = { 0x247 } },
	},
	-- ギース・ハワード
	{
		{ startup = true, names = { "スウェー戻り" },                          type = act_types.any,        ids = { 0x36 } },
		{ startup = true, names = { "近 対メインライン威力大攻撃" },                            type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true, names = { "遠 対メインライン威力大攻撃" },                            type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true, names = { "近立C" },                                     type = act_types.attack,     ids = { 0x43 } },
		{ startup = true, names = { "遠立B" },                                     type = act_types.attack,     ids = { 0x45 } },
		{ startup = true, names = { "遠立C" },                                     type = act_types.attack,     ids = { 0x46 } },
		{ startup = true, names = { "屈A" },                                        type = act_types.attack,     ids = { 0x47 } },
		{ startup = true, names = { "フェイント 烈風拳" },                   type = act_types.any,        ids = { 0x112 } },
		{ startup = true, names = { "フェイント レイジングストーム" }, type = act_types.any,        ids = { 0x113 } },
		{ startup = true, names = { "虎殺投げ" },                                type = act_types.any,        ids = { 0x6D, 0x6E } },
		{ startup = true, names = { "絶命人中打ち" },                          type = act_types.any,        ids = { 0x7C, 0x7D, 0x7E, 0x7F } },
		{ startup = true, names = { "虎殺掌" },                                   type = act_types.any,        ids = { 0x81, 0x82, 0x83, 0x84 } },
		{ startup = true, names = { "昇天明星打ち" },                          type = act_types.attack,     ids = { 0x69 } },
		{ startup = true, names = { "飛燕失脚" },                                type = act_types.overhead,   ids = { 0x68, 0x6B, 0x6C } },
		{ startup = true, names = { "雷光回し蹴り" },                          type = act_types.attack,     ids = { 0x6A } },
		{ startup = true, names = { "烈風拳" },                                   type = act_types.attack,     ids = { 0x86, 0x87 },                firing = true },
		{ startup = false, names = { "烈風拳" },                                   type = act_types.any,        ids = { 0x88 } },
		{ startup = true, names = { "ダブル烈風拳" },                          type = act_types.attack,     ids = { 0x90, 0x91, 0x92 },          firing = true },
		{ startup = true, names = { "屈段当て身打ち" },                       type = act_types.any,        ids = { 0xAE } },
		{ startup = true, names = { "屈段当て身打ちキャッチ" },           type = act_types.attack,     ids = { 0xAF, 0xB0, 0xB1 } },
		{ startup = true, names = { "裏雲隠し" },                                type = act_types.any,        ids = { 0xA4 } },
		{ startup = true, names = { "裏雲隠しキャッチ" },                    type = act_types.any,        ids = { 0xA5, 0xA6, 0xA7 } },
		{ startup = true, names = { "上段当て身投げ" },                       type = act_types.any,        ids = { 0x9A } },
		{ startup = true, names = { "上段当て身投げキャッチ" },           type = act_types.any,        ids = { 0x9B, 0x9C, 0x9D } },
		{ startup = true, names = { "雷鳴豪波投げ" },                          type = act_types.any,        ids = { 0xB8, 0xB9, 0xBA } },
		{ startup = true, names = { "真空投げ" },                                type = act_types.any,        ids = { 0xC2, 0xC3 } },
		{ startup = true, names = { "レイジングストーム" },                 type = act_types.attack,     ids = { 0xFE, 0xFF, 0x100 },         firing = true },
		{ startup = true, names = { "羅生門" },                                   type = act_types.attack,     ids = { 0x108, 0x109, 0x10A, 0x10B } },
		{ startup = true, names = { "デッドリーレイブ" },                    type = act_types.attack,     ids = { 0xE0, 0xE1, 0xE2 } },
		{ startup = true, names = { "デッドリーレイブ2段目" },             type = act_types.attack,     ids = { 0xE3 } },
		{ startup = true, names = { "デッドリーレイブ3段目" },             type = act_types.attack,     ids = { 0xE4 } },
		{ startup = true, names = { "デッドリーレイブ4段目" },             type = act_types.attack,     ids = { 0xE5 } },
		{ startup = true, names = { "デッドリーレイブ5段目" },             type = act_types.attack,     ids = { 0xE6 } },
		{ startup = true, names = { "デッドリーレイブ6段目" },             type = act_types.attack,     ids = { 0xE7 } },
		{ startup = true, names = { "デッドリーレイブ7段目" },             type = act_types.attack,     ids = { 0xE8 } },
		{ startup = true, names = { "デッドリーレイブ8段目" },             type = act_types.attack,     ids = { 0xE9 } },
		{ startup = true, names = { "デッドリーレイブ9段目" },             type = act_types.attack,     ids = { 0xEA } },
		{ startup = true, names = { "デッドリーレイブ10段目" },            type = act_types.attack,     ids = { 0xEB, 0xEC } },
		{ startup = true, names = { "CA 立B" },                                     type = act_types.attack,     ids = { 0x241 } },
		{ startup = true, names = { "CA 屈B" },                                     type = act_types.low_attack, ids = { 0x242 } },
		{ startup = true, names = { "CA 屈C" },                                     type = act_types.low_attack, ids = { 0x243 } },
		{ startup = true, names = { "CA 立C" },                                     type = act_types.attack,     ids = { 0x245 } },
		{ startup = true, names = { "CA 屈C" },                                     type = act_types.low_attack, ids = { 0x247 } },
		{ startup = true, names = { "CA _3C" },                                      type = act_types.attack,     ids = { 0x246 } },
		{ startup = true, names = { "CA 立C" },                                     type = act_types.attack,     ids = { 0x244 } },
		{ startup = true, names = { "CA 屈C" },                                     type = act_types.low_attack, ids = { 0x247 } },
		{ startup = true, names = { "CA 立C" },                                     type = act_types.attack,     ids = { 0x249 } },
		{ startup = true, names = { "CA _8C" },                                      type = act_types.attack,     ids = { 0x24E, 0x24F } },
		{ startup = true, names = { "CA _8C" },                                      type = act_types.any,        ids = { 0x250 } },
		{ startup = true, names = { "CA 立C" },                                     type = act_types.attack,     ids = { 0x24D } },
		{ startup = true, names = { "CA 立C" },                                     type = act_types.attack,     ids = { 0x240 } },
		{ startup = true, names = { "CA 屈C" },                                     type = act_types.attack,     ids = { 0x24B } },
		{ startup = true, names = { "CA 対スウェーライン上段攻撃" },     type = act_types.overhead,     ids = { 0x248 } },
		{ startup = true, names = { "CA 対スウェーライン下段攻撃" },     type = act_types.low_attack, ids = { 0x24A } },
	},
	-- 望月双角,
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },             type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },             type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                      type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                      type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                      type = act_types.attack,     ids = { 0x46, 0x71 } },
		{ startup = true,  names = { "屈A" },                         type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント まきびし" }, type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "フェイント いかづち" }, type = act_types.any,        ids = { 0x113 } },
		{ startup = true,  names = { "無道縛り投げ" },           type = act_types.any,        ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "地獄門" },                    type = act_types.any,        ids = { 0x7C, 0x7D, 0x7E, 0x7F } },
		{ startup = true,  names = { "昇天殺" },                    type = act_types.attack,     ids = { 0x72, 0x73 } },
		{ startup = true,  names = { "雷撃棍" },                    type = act_types.any,        ids = { 0x69, 0x6A, 0x6B } },
		{ startup = true,  names = { "錫杖上段打ち" },           type = act_types.attack,     ids = { 0x68 } },
		{ startup = true,  names = { "野猿狩り" },                 type = act_types.attack,     ids = { 0x86, 0x87, 0x88 },       firing = true },
		{ startup = false, names = { "野猿狩り" },                 type = act_types.any,        ids = { 0x89 } },
		{ startup = true,  names = { "まきびし" },                 type = act_types.low_attack, ids = { 0x90, 0x91, 0x92 },       firing = true },
		{ startup = true,  names = { "憑依弾" },                    type = act_types.attack,     ids = { 0x9A, 0x9B },             firing = true },
		{ startup = false, names = { "憑依弾" },                    type = act_types.any,        ids = { 0x9C, 0x9D } },
		{ startup = true,  names = { "鬼門陣" },                    type = act_types.any,        ids = { 0xA4, 0xA5, 0xA6, 0xA7 } },
		{ startup = true,  names = { "邪棍舞" },                    type = act_types.low_attack, ids = { 0xAE },                   firing = true },
		{ startup = true,  names = { "邪棍舞 持続" },             type = act_types.low_attack, ids = { 0xAF },                   firing = true },
		{ startup = true,  names = { "邪棍舞 隙" },                type = act_types.any,        ids = { 0xB0 },                   firing = true },
		{ startup = true,  names = { "喝" },                          type = act_types.attack,     ids = { 0xB8, 0xB9, 0xBA, 0xBB }, firing = true },
		{ startup = true,  names = { "渦炎陣" },                    type = act_types.overhead,   ids = { 0xC2, 0xC3 } },
		{ startup = false, names = { "渦炎陣" },                    type = act_types.any,        ids = { 0xC4, 0xC5 } },
		{ startup = true,  names = { "いかづち" },                 type = act_types.attack,     ids = { 0xFE, 0xFF, 0x103 },      firing = true },
		{ startup = false, names = { "いかづち" },                 type = act_types.any,        ids = { 0x100, 0x101 } },
		{ startup = true,  names = { "無惨弾" },                    type = act_types.overhead,   ids = { 0x108, 0x109, 0x10A } },
		{ startup = false, names = { "無惨弾" },                    type = act_types.any,        ids = { 0x10B, 0x10C } },
		{ startup = true,  names = { "CA 立C" },                      type = act_types.attack,     ids = { 0x241 } },
		{ startup = true,  names = { "CA 立C" },                      type = act_types.attack,     ids = { 0x240 } },
		{ startup = true,  names = { "CA _6C" },                       type = act_types.attack,     ids = { 0x243 } },
		{ startup = true,  names = { "CA _2_2C" },                     type = act_types.low_attack, ids = { 0x24B },                  firing = true },
		{ startup = true,  names = { "CA 6B" },                        type = act_types.attack,     ids = { 0x247 } },
		{ startup = true,  names = { "CA _6_2_3+A" },                  type = act_types.attack,     ids = { 0x242 } },
		{ startup = true,  names = { "CA 屈C" },                      type = act_types.low_attack, ids = { 0x244 } },
		{ startup = true,  names = { "CA 屈C" },                      type = act_types.low_attack, ids = { 0x24D } },
		{ startup = true,  names = { "CA 立C" },                      type = act_types.attack,     ids = { 0xBC } },
	},
	-- ボブ・ウィルソン
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                            type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                            type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                                     type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                                     type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                                     type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                                        type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント ダンシングバイソン" }, type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "ファルコン" },                             type = act_types.any,        ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "ホーネットアタック" },                 type = act_types.any,        ids = { 0x7C, 0x7D, 0x7E } },
		{ startup = true,  names = { "イーグルキャッチ" },                    type = act_types.any,        ids = { 0x72, 0x73, 0x74 } },
		{ startup = true,  names = { "フライングフィッシュ" },              type = act_types.attack,     ids = { 0x68, 0x77 } },
		{ startup = false, names = { "フライングフィッシュ" },              type = act_types.any,        ids = { 0x78 } },
		{ startup = true,  names = { "イーグルステップ" },                    type = act_types.attack,     ids = { 0x69 } },
		{ startup = true,  names = { "リンクスファング" },                    type = act_types.any,        ids = { 0x6A, 0x7A, 0x7B } },
		{ startup = true,  names = { "エレファントタスク" },                 type = act_types.attack,     ids = { 0x6B } },
		{ startup = true,  names = { "H・ヘッジホック" },                      type = act_types.attack,     ids = { 0x6C } },
		{ startup = true,  names = { "ローリングタートル" },                 type = act_types.attack,     ids = { 0x86, 0x87, 0x88 } },
		{ startup = false, names = { "ローリングタートル" },                 type = act_types.any,        ids = { 0x89 } },
		{ startup = true,  names = { "サイドワインダー" },                    type = act_types.low_attack, ids = { 0x90, 0x91, 0x92 } },
		{ startup = false, names = { "サイドワインダー" },                    type = act_types.any,        ids = { 0x93 } },
		{ startup = true,  names = { "モンキーダンス" },                       type = act_types.attack,     ids = { 0xAE, 0xAF } },
		{ startup = false, names = { "モンキーダンス" },                       type = act_types.any,        ids = { 0xB0, 0xB1 } },
		{ startup = true,  names = { "ワイルドウルフ" },                       type = act_types.overhead,   ids = { 0xA4, 0xA5, 0xA6 } },
		{ startup = true,  names = { "バイソンホーン" },                       type = act_types.low_attack, ids = { 0x9A, 0x9B } },
		{ startup = false, names = { "バイソンホーン" },                       type = act_types.any,        ids = { 0x9D, 0x9C } },
		{ startup = true,  names = { "フロッグハンティング" },              type = act_types.attack,     ids = { 0xB8, 0xB9 } },
		{ startup = false, names = { "フロッグハンティング" },              type = act_types.any,        ids = { 0xBD, 0xBE, 0xBA, 0xBB, 0xBC } },
		{ startup = true,  names = { "デンジャラスウルフ" },                 type = act_types.overhead,   ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, 0x103 } },
		{ startup = false, names = { "デンジャラスウルフ" },                 type = act_types.any,        ids = { 0x104 } },
		{ startup = true,  names = { "ダンシングバイソン" },                 type = act_types.attack,     ids = { 0x108, 0x109, 0x10A, 0x10B } },
		{ startup = false, names = { "ダンシングバイソン" },                 type = act_types.any,        ids = { 0x10C, 0x10D } },
		{ startup = true,  names = { "CA 立B" },                                     type = act_types.attack,     ids = { 0x243 } },
		{ startup = true,  names = { "CA 立C" },                                     type = act_types.attack,     ids = { 0x240 } },
		{ startup = true,  names = { "CA _3C" },                                      type = act_types.attack,     ids = { 0x242 } },
		{ startup = true,  names = { "CA 立C" },                                     type = act_types.attack,     ids = { 0x245 } },
		{ startup = true,  names = { "CA _6C" },                                      type = act_types.attack,     ids = { 0x247 } },
		{ startup = true,  names = { "CA _8C" },                                      type = act_types.overhead,   ids = { 0x24A, 0x24B } },
		{ startup = true,  names = { "CA _8C" },                                      type = act_types.any,        ids = { 0x24C } },
		{ startup = true,  names = { "CA 屈B" },                                     type = act_types.attack,     ids = { 0x249 } },
		{ startup = true,  names = { "CA 屈C" },                                     type = act_types.low_attack, ids = { 0x248 } },
	},
	-- ホンフゥ
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                       type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                       type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                                type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                                type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                                type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                                   type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント 制空烈火棍" },        type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "バックフリップ" },                  type = act_types.any,        ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "経絡乱打" },                           type = act_types.any,        ids = { 0x81, 0x82, 0x83, 0x84 } },
		{ startup = true,  names = { "ハエタタキ" },                        type = act_types.attack,     ids = { 0x69 } },
		{ startup = true,  names = { "踏み込み側蹴り" },                  type = act_types.attack,     ids = { 0x68 } },
		{ startup = true,  names = { "トドメヌンチャク" },               type = act_types.attack,     ids = { 0x6A } },
		{ startup = true,  names = { "九龍の読み" },                        type = act_types.attack,     ids = { 0x86 } },
		{ startup = true,  names = { "九龍の読み反撃" },                  type = act_types.attack,     ids = { 0x87, 0x88, 0x89 } },
		{ startup = true,  names = { "黒龍" },                                 type = act_types.attack,     ids = { 0xD7, 0xD8 } },
		{ startup = false, names = { "黒龍" },                                 type = act_types.any,        ids = { 0xD9, 0xDA } },
		{ startup = true,  names = { "小 制空烈火棍" },                    type = act_types.attack,     ids = { 0x90, 0x91 } },
		{ startup = false, names = { "小 制空烈火棍" },                    type = act_types.any,        ids = { 0x92, 0x93 } },
		{ startup = true,  names = { "大 制空烈火棍" },                    type = act_types.attack,     ids = { 0x9A, 0x9B } },
		{ startup = false, names = { "大 制空烈火棍", "爆発ゴロー" }, type = act_types.any,        ids = { 0x9D, 0x9C } },
		{ startup = true,  names = { "電光石火の天" },                     type = act_types.attack,     ids = { 0xAE, 0xAF, 0xB0 } },
		{ startup = true,  names = { "電光石火の地" },                     type = act_types.low_attack, ids = { 0xA4, 0xA5 } },
		{ startup = false, names = { "電光石火の地" },                     type = act_types.any,        ids = { 0xA6 } },
		{ startup = true,  names = { "電光パチキ" },                        type = act_types.attack,     ids = { 0xA7 } },
		{ startup = false, names = { "電光パチキ" },                        type = act_types.any,        ids = { 0xA8 } },
		{ startup = true,  names = { "炎の種馬" },                           type = act_types.attack,     ids = { 0xB8 } },
		{ startup = true,  names = { "炎の種馬 持続" },                    type = act_types.attack,     ids = { 0xB9, 0xBA, 0xBB } },
		{ startup = true,  names = { "炎の種馬 最終段" },                 type = act_types.attack,     ids = { 0xBC, 0xBD } },
		{ startup = true,  names = { "炎の種馬 失敗" },                    type = act_types.any,        ids = { 0xBE, 0xBF, 0xC0 } },
		{ startup = true,  names = { "必勝！逆襲拳" },                     type = act_types.any,        ids = { 0xC2 } },
		{ startup = true,  names = { "必勝！逆襲拳 1回目" },             type = act_types.any,        ids = { 0xC3, 0xC4, 0xC5 } },
		{ startup = true,  names = { "必勝！逆襲拳 2回目" },             type = act_types.any,        ids = { 0xC6, 0xC7, 0xC8 } },
		{ startup = true,  names = { "必勝！逆襲拳 1段目" },             type = act_types.attack,     ids = { 0xC9, 0xCA, 0xCB } },
		{ startup = true,  names = { "必勝！逆襲拳 2~5段目" },           type = act_types.low_attack, ids = { 0xCC } },
		{ startup = true,  names = { "必勝！逆襲拳 6~7段目" },           type = act_types.overhead,   ids = { 0xCD } },
		{ startup = true,  names = { "必勝！逆襲拳 8~10段目" },          type = act_types.overhead,   ids = { 0xCE } },
		{ startup = true,  names = { "必勝！逆襲拳 11~12段目" },         type = act_types.attack,     ids = { 0xCF, 0xD0 } },
		{ startup = false, names = { "必勝！逆襲拳 11~12段目" },         type = act_types.attack,     ids = { 0xD1 } },
		{ startup = true,  names = { "爆発ゴロー" },                        type = act_types.attack,     ids = { 0xFE, 0xFF, 0x100, 0x101 } },
		{ startup = false, names = { "爆発ゴロー" },                        type = act_types.any,        ids = { 0x102 } },
		{ startup = true,  names = { "よかトンハンマー" },               type = act_types.overhead,   ids = { 0x108, 0x109, 0x10A } },
		{ startup = false, names = { "よかトンハンマー" },               type = act_types.any,        ids = { 0x10B },                   firing = true },
		{ startup = true,  names = { "CA 立B" },                                type = act_types.attack,     ids = { 0x245 } },
		{ startup = true,  names = { "CA 立C" },                                type = act_types.attack,     ids = { 0x240 } },
		{ startup = true,  names = { "CA _3C" },                                 type = act_types.attack,     ids = { 0x242 } },
		{ startup = true,  names = { "CA 屈B" },                                type = act_types.low_attack, ids = { 0x246 } },
		{ startup = true,  names = { "CA 立C" },                                type = act_types.attack,     ids = { 0x247 } },
		{ startup = true,  names = { "CA 立C" },                                type = act_types.attack,     ids = { 0x248 } },
		{ startup = true,  names = { "CA 立C" },                                type = act_types.attack,     ids = { 0x252 } },
		{ startup = true,  names = { "CA 立B" },                                type = act_types.attack,     ids = { 0x24C, 0x24D } },
		{ startup = true,  names = { "CA 立B" },                                type = act_types.any,        ids = { 0x24E } },
		{ startup = true,  names = { "CA 立C" },                                type = act_types.overhead,   ids = { 0x24F } },
		{ startup = true,  names = { "CA 立C" },                                type = act_types.any,        ids = { 0x250 } },
		{ startup = true,  names = { "CA 立C" },                                type = act_types.attack,     ids = { 0x243 } },
		{ startup = true,  names = { "CA 立C" },                                type = act_types.attack,     ids = { 0x244 } },
		{ startup = true,  names = { "CA 屈C" },                                type = act_types.low_attack, ids = { 0x24B } },
		{ startup = true,  names = { "CA _3C " },                                type = act_types.low_attack, ids = { 0x251 } },
	},
	-- ブルー・マリー
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                                                                   type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                                                                   type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                                                                            type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                                                                            type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                                                                            type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                                                                               type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント M.スナッチャー" },                                               type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "ヘッドスロー" },                                                                 type = act_types.any,        ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "アキレスホールド" },                                                           type = act_types.any,        ids = { 0x7C, 0x7E, 0x7F } },
		{ startup = true,  names = { "ヒールフォール" },                                                              type = act_types.overhead,   ids = { 0x69 } },
		{ startup = true,  names = { "ダブルローリング" },                                                           type = act_types.attack,     ids = { 0x68 } },
		{ startup = false, names = { "ダブルローリング" },                                                           type = act_types.low_attack, ids = { 0x6C } },
		{ startup = true,  names = { "レッグプレス" },                                                                 type = act_types.any,        ids = { 0x6A } },
		{ startup = true,  names = { "M.リアルカウンター" },                                                         type = act_types.attack,     ids = { 0xA4, 0xA5 } },
		{ startup = false, names = { "CAジャーマンスープレックス", "M.リアルカウンター" },               type = act_types.any,        ids = { 0xA6 } },
		{ startup = true,  names = { "M.リアルカウンター投げ移行" },                                             type = act_types.any,        ids = { 0xAC } },
		{ startup = false, names = { "ジャーマンスープレックス", "CAジャーマンスープレックス" },     type = act_types.any,        ids = { 0xA7, 0xA8, 0xA9, 0xAA, 0xAB } },
		{ startup = true,  names = { "フェイスロック" },                                                              type = act_types.any,        ids = { 0xE0, 0xE1, 0xE2, 0xE3, 0xE4 } },
		{ startup = true,  names = { "投げっぱなしジャーマンスープレックス" },                             type = act_types.any,        ids = { 0xE5, 0xE6, 0xE7 } },
		{ startup = true,  names = { "ヤングダイブ" },                                                                 type = act_types.overhead,   ids = { 0xEA, 0xEB, 0xEC } },
		{ startup = false, names = { "ヤングダイブ" },                                                                 type = act_types.any,        ids = { 0xED } },
		{ startup = true,  names = { "リバースキック" },                                                              type = act_types.overhead,   ids = { 0xEE } },
		{ startup = false, names = { "リバースキック" },                                                              type = act_types.any,        ids = { 0xEF } },
		{ startup = true,  names = { "M.スパイダー" },                                                                  type = act_types.attack,     ids = { 0x8C, 0x86 } },
		{ startup = true,  names = { "デンジャラススパイダー" },                                                  type = act_types.attack,     ids = { 0xF0 } },
		{ startup = true,  names = { "スピンフォール" },                                                              type = act_types.attack,     ids = { 0xAE, 0xAF } },
		{ startup = false, names = { "スピンフォール" },                                                              type = act_types.attack,     ids = { 0xB0 } },
		{ startup = false, names = { "ダブルスパイダー", "M.スパイダー", "デンジャラススパイダー" }, type = act_types.any,        ids = { 0x87, 0x88, 0x89, 0x8A, 0x8B } },
		{ startup = true,  names = { "M.スナッチャー" },                                                               type = act_types.attack,     ids = { 0x90 } },
		{ startup = false, names = { "M.スナッチャー" },                                                               type = act_types.any,        ids = { 0x91, 0x92 } },
		{ startup = true,  names = { "バーチカルアロー" },                                                           type = act_types.overhead,   ids = { 0xB8, 0xB9 } },
		{ startup = false, names = { "バーチカルアロー" },                                                           type = act_types.any,        ids = { 0xBA, 0xBB } },
		{ startup = false, names = { "ダブルスナッチャー", "M.スナッチャー" },                                type = act_types.any,        ids = { 0x93, 0x94, 0x95, 0x96 } },
		{ startup = true,  names = { "M.クラブクラッチ" },                                                            type = act_types.low_attack, ids = { 0x9A, 0x9B } },
		{ startup = true,  names = { "ストレートスライサー" },                                                     type = act_types.low_attack, ids = { 0xC2, 0xC3 } },
		{ startup = false, names = { "ストレートスライサー", "M.クラブクラッチ" },                          type = act_types.any,        ids = { 0xC4, 0xC5 } },
		{ startup = false, names = { "ダブルクラッチ", "M.クラブクラッチ" },                                   type = act_types.any,        ids = { 0x9D, 0x9E, 0x9F, 0xA0, 0xA1 } },
		{ startup = true,  names = { "M.ダイナマイトスウィング" },                                                type = act_types.any,        ids = { 0xCC, 0xCD, 0xCE, 0xCF, 0xD0, 0xD1 } },
		{ startup = true,  names = { "M.タイフーン" },                                                                  type = act_types.attack,     ids = { 0xFE, 0xFF } },
		{ startup = false, names = { "M.タイフーン" },                                                                  type = act_types.any,        ids = { 0x100, 0x101, 0x102, 0x103, 0x104, 0x105, 0x106, 0x107, 0x116 } },
		{ startup = true,  names = { "M.エスカレーション" },                                                         type = act_types.attack,     ids = { 0x10B } },
		{ startup = true,  names = { "M.トリプルエクスタシー" },                                                   type = act_types.any,        ids = { 0xD6, 0xD8, 0xD7, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF } },
		{ startup = true,  names = { "立ち" },                                                                             type = act_types.free,       ids = { 0x109, 0x10A, 0x108 } },
		{ startup = true,  names = { "CA 立B" },                                                                            type = act_types.attack,     ids = { 0x24C } },
		{ startup = true,  names = { "CA 屈B" },                                                                            type = act_types.low_attack, ids = { 0x251 } },
		{ startup = true,  names = { "CA 立C" },                                                                            type = act_types.attack,     ids = { 0x246 } },
		{ startup = true,  names = { "CA _6C" },                                                                             type = act_types.attack,     ids = { 0x24E, 0x24F } },
		{ startup = true,  names = { "CA _6C" },                                                                             type = act_types.any,        ids = { 0x250 } },
		{ startup = true,  names = { "CA 屈C" },                                                                            type = act_types.low_attack, ids = { 0x247 } },
		{ startup = true,  names = { "CA _3C" },                                                                             type = act_types.attack,     ids = { 0x242 } },
		{ startup = true,  names = { "CA 立C" },                                                                            type = act_types.attack,     ids = { 0x241 } },
		{ startup = true,  names = { "CA 立C" },                                                                            type = act_types.attack,     ids = { 0x240 } },
		{ startup = true,  names = { "CA 立C" },                                                                            type = act_types.attack,     ids = { 0x243, 0x244 } },
		{ startup = true,  names = { "CA 立C" },                                                                            type = act_types.any,        ids = { 0x245 } },
		{ startup = true,  names = { "CA 立C" },                                                                            type = act_types.attack,     ids = { 0x252, 0x253 } },
		{ startup = true,  names = { "CA _3C" },                                                                             type = act_types.attack,     ids = { 0x24D } },
		{ startup = true,  names = { "CA _6C" },                                                                             type = act_types.attack,     ids = { 0x249, 0x24A } },
		{ startup = false,  names = { "CA _6C" },                                                                             type = act_types.any,        ids = { 0x24B } },
	},
	-- フランコ・バッシュ
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                               type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                               type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                                        type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                                        type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                                        type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                                           type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント ガッツダンク" },             type = act_types.any,        ids = { 0x113 } },
		{ startup = true,  names = { "フェイント ハルマゲドンバスター" }, type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "ゴリラッシュ" },                             type = act_types.any,        ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "スマッシュ" },                                type = act_types.attack,     ids = { 0x68 } },
		{ startup = true,  names = { "バッシュトルネード" },                    type = act_types.attack,     ids = { 0x6A } },
		{ startup = true,  names = { "バロムパンチ" },                             type = act_types.low_attack, ids = { 0x69 } },
		{ startup = true,  names = { "ダブルコング" },                             type = act_types.overhead,   ids = { 0x86, 0x87, 0x88 } },
		{ startup = false, names = { "ダブルコング" },                             type = act_types.any,        ids = { 0x89 } },
		{ startup = true,  names = { "ザッパー" },                                   type = act_types.attack,     ids = { 0x90, 0x91, 0x92 },            firing = true },
		{ startup = false, names = { "ザッパー" },                                   type = act_types.any,        ids = { 0x92 },                        firing = true },
		{ startup = true,  names = { "ウェービングブロー" },                    type = act_types.attack,     ids = { 0x9A, 0x9B } },
		{ startup = true,  names = { "ガッツダンク" },                             type = act_types.attack,     ids = { 0xA4, 0xA5, 0xA6, 0xA7 } },
		{ startup = false, names = { "ガッツダンク" },                             type = act_types.any,        ids = { 0xA8, 0xAC } },
		{ startup = true,  names = { "ゴールデンボンバー" },                    type = act_types.attack,     ids = { 0xAD, 0xAE, 0xAF, 0xB0 } },
		{ startup = false, names = { "ゴールデンボンバー" },                    type = act_types.any,        ids = { 0xB1 } },
		{ startup = true,  names = { "ファイナルオメガショット" },           type = act_types.overhead,   ids = { 0xFE, 0xFF, 0x100 },           firing = true },
		{ startup = true,  names = { "メガトンスクリュー" },                    type = act_types.attack,     ids = { 0xF4, 0xF5, 0xF6, 0xF7, 0xFC } },
		{ startup = false, names = { "メガトンスクリュー" },                    type = act_types.any,        ids = { 0xF8 } },
		{ startup = true,  names = { "ハルマゲドンバスター" },                 type = act_types.attack,     ids = { 0x108 } },
		{ startup = false, names = { "ハルマゲドンバスター" },                 type = act_types.any,        ids = { 0x109 } },
		{ startup = true,  names = { "ハルマゲドンバスター ヒット" },       type = act_types.attack,     ids = { 0x10A } },
		{ startup = false, names = { "ハルマゲドンバスター ヒット" },       type = act_types.any,        ids = { 0x10B } },
		{ startup = true,  names = { "CA 立A" },                                        type = act_types.attack,     ids = { 0x248 } },
		{ startup = true,  names = { "CA 立C" },                                        type = act_types.low_attack, ids = { 0x247 } },
		{ startup = true,  names = { "CA 屈B" },                                        type = act_types.low_attack, ids = { 0x242 } },
		{ startup = true,  names = { "CA 立D" },                                        type = act_types.attack,     ids = { 0x240 } },
		{ startup = true,  names = { "CA 立B" },                                        type = act_types.low_attack, ids = { 0x246 } },
		{ startup = true,  names = { "CA 屈C" },                                        type = act_types.low_attack, ids = { 0x249 } },
		{ startup = true,  names = { "CA 立C" },                                        type = act_types.overhead,   ids = { 0x24A, 0x24B } },
		{ startup = true,  names = { "CA 立C" },                                        type = act_types.any,        ids = { 0x24C } },
		{ startup = true,  names = { "CA _3C" },                                         type = act_types.attack,     ids = { 0x24D } },
	},
	-- 山崎竜二
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                type = act_types.low_attack,   ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                type = act_types.low_attack,   ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                         type = act_types.attack,       ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                         type = act_types.attack,       ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                         type = act_types.attack,       ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                            type = act_types.attack,       ids = { 0x47 } },
		{ startup = true,  names = { "フェイント 裁きの匕首" }, type = act_types.any,          ids = { 0x112 } },
		{ startup = true,  names = { "ブン投げ" },                    type = act_types.any,          ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "目ツブシ" },                    type = act_types.attack,       ids = { 0x68, 0x6C },                              firing = true },
		{ startup = true,  names = { "カチ上げ" },                    type = act_types.attack,       ids = { 0x69 } },
		{ startup = true,  names = { "ブッ刺し" },                    type = act_types.overhead,     ids = { 0x6A } },
		{ startup = true,  names = { "昇天" },                          type = act_types.attack,       ids = { 0x6B } },
		{ startup = true,  names = { "蛇使い・上段かまえ" },     type = act_types.any,          ids = { 0x86, 0x87 } },
		{ startup = true,  names = { "蛇使い・上段" },              t033330ype = act_types.attack, ids = { 0x88 } },
		{ startup = true,  names = { "蛇だまし・上段" },           type = act_types.any,          ids = { 0x89 } },
		{ startup = true,  names = { "蛇使い・中段かまえ" },     type = act_types.any,          ids = { 0x90, 0x91 } },
		{ startup = true,  names = { "蛇使い・中段" },              type = act_types.attack,       ids = { 0x92 } },
		{ startup = true,  names = { "蛇だまし・中段" },           type = act_types.any,          ids = { 0x93 } },
		{ startup = true,  names = { "蛇使い・下段かまえ" },     type = act_types.any,          ids = { 0x9A, 0x9B } },
		{ startup = true,  names = { "蛇使い・下段" },              type = act_types.low_attack,   ids = { 0x9C } },
		{ startup = true,  names = { "蛇だまし・下段" },           type = act_types.any,          ids = { 0x9D } },
		{ startup = true,  names = { "大蛇" },                          type = act_types.low_attack,   ids = { 0x94 } },
		{ startup = true,  names = { "サドマゾ" },                    type = act_types.any,          ids = { 0xA4 } },
		{ startup = true,  names = { "サドマゾ攻撃" },              type = act_types.low_attack,   ids = { 0xA5, 0xA6 } },
		{ startup = true,  names = { "裁きの匕首" },                 type = act_types.attack,       ids = { 0xC2, 0xC3 } },
		{ startup = false, names = { "裁きの匕首" },                 type = act_types.any,          ids = { 0xC4 } },
		{ startup = true,  names = { "裁きの匕首 ヒット" },       type = act_types.attack,       ids = { 0xC5 } },
		{ startup = true,  names = { "ヤキ入れ" },                    type = act_types.overhead,     ids = { 0xAE, 0xAF, 0xB0 } },
		{ startup = true,  names = { "ヤキ入れ" },                    type = act_types.any,          ids = { 0xB4 } },
		{ startup = true,  names = { "倍返し" },                       type = act_types.attack,       ids = { 0xB8 } },
		{ startup = true,  names = { "倍返し キャッチ" },          type = act_types.any,          ids = { 0xB9 } },
		{ startup = true,  names = { "倍返し 吸収" },                type = act_types.any,          ids = { 0xBA } },
		{ startup = true,  names = { "倍返し 発射" },                type = act_types.attack,       ids = { 0xBB, 0xBC },                              firing = true },
		{ startup = true,  names = { "爆弾パチキ" },                 type = act_types.any,          ids = { 0xCC, 0xCD, 0xCE, 0xCF } },
		{ startup = true,  names = { "トドメ" },                       type = act_types.any,          ids = { 0xD6, 0xD7 } },
		{ startup = true,  names = { "トドメ ヒット" },             type = act_types.any,          ids = { 0xDA, 0xD8, 0xDB, 0xD9 } },
		{ startup = true,  names = { "ギロチン" },                    type = act_types.attack,       ids = { 0xFE, 0xFF, 0x100 } },
		{ startup = false, names = { "ギロチン" },                    type = act_types.any,          ids = { 0x101 } },
		{ startup = true,  names = { "ギロチンヒット" },           type = act_types.any,          ids = { 0x102, 0x103 } },
		{ startup = true,  names = { "ドリル" },                       type = act_types.any,          ids = { 0x108, 0x109 } },
		{ startup = true,  names = { "ドリル ため Lv.1" },           type = act_types.any,          ids = { 0x10A, 0x10B } },
		{ startup = true,  names = { "ドリル ため Lv.2" },           type = act_types.any,          ids = { 0x10C } },
		{ startup = true,  names = { "ドリル ため Lv.3" },           type = act_types.any,          ids = { 0x10D } },
		{ startup = true,  names = { "ドリル ため Lv.4" },           type = act_types.any,          ids = { 0x10E } },
		{ startup = true,  names = { "ドリル Lv.1" },                  type = act_types.any,          ids = { 0xE0, 0xE1, 0xE2 } },
		{ startup = true,  names = { "ドリル Lv.2" },                  type = act_types.any,          ids = { 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9 } },
		{ startup = true,  names = { "ドリル Lv.3" },                  type = act_types.any,          ids = { 0xEA, 0xEB, 0xEC, 0xF1 } },
		{ startup = true,  names = { "ドリル Lv.4" },                  type = act_types.any,          ids = { 0xED, 0xEE, 0xEF, 0xF0 } },
		{ startup = true,  names = { "ドリル Lv.5" },                  type = act_types.any,          ids = { 0xF2, 0xF3, 0xF4, 0xF5, 0xF6 } },
		{ startup = true,  names = { "ドリル フィニッシュ" },    type = act_types.any,          ids = { 0x10F, 0x110 } },
		{ startup = true,  names = { "CA 立C" },                         type = act_types.attack,       ids = { 0x245 } },
		{ startup = true,  names = { "CA 立C" },                         type = act_types.attack,       ids = { 0x247, 0x248, 0x249 } },
		{ startup = true,  names = { "CA 立C" },                         type = act_types.attack,       ids = { 0x244 } },
		{ startup = true,  names = { "CA 立C" },                         type = act_types.attack,       ids = { 0x24D } },
		{ startup = true,  names = { "CA _3C" },                          type = act_types.attack,       ids = { 0x242 } },
		{ startup = true,  names = { "CA _6C" },                          type = act_types.attack,       ids = { 0x241 } },
	},
	-- 秦崇秀
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                                         type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                                         type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                                                  type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                                                  type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                                                  type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                                                     type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント 海龍照臨" },                             type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "発勁龍" },                                                type = act_types.any,        ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "光輪殺" },                                                type = act_types.overhead,   ids = { 0x68 } },
		{ startup = true,  names = { "帝王神足拳" },                                          type = act_types.attack,     ids = { 0x86, 0x87 } },
		{ startup = true,  names = { "帝王神足拳" },                                          type = act_types.any,        ids = { 0x88 } },
		{ startup = true,  names = { "帝王神足拳 Hit" },                                      type = act_types.any,        ids = { 0x89, 0x8A } },
		{ startup = true,  names = { "小 帝王天眼拳" },                                      type = act_types.attack,     ids = { 0x90, 0x91 },                                    firing = true },
		{ startup = false, names = { "小 帝王天眼拳" },                                      type = act_types.any,        ids = { 0x92 },                                          firing = true },
		{ startup = true,  names = { "大 帝王天眼拳" },                                      type = act_types.attack,     ids = { 0x9A, 0x9B },                                    firing = true },
		{ startup = false, names = { "大 帝王天眼拳" },                                      type = act_types.any,        ids = { 0x9C },                                          firing = true },
		{ startup = true,  names = { "小 帝王天耳拳" },                                      type = act_types.attack,     ids = { 0xA4, 0xA5 } },
		{ startup = false, names = { "小 帝王天耳拳" },                                      type = act_types.any,        ids = { 0xA6, 0xA7 } },
		{ startup = true,  names = { "大 帝王天耳拳" },                                      type = act_types.attack,     ids = { 0xAE, 0xAF } },
		{ startup = false, names = { "大 帝王天耳拳" },                                      type = act_types.any,        ids = { 0xB0, 0xB1 } },
		{ startup = true,  names = { "帝王神眼拳（その場）" },                           type = act_types.any,        ids = { 0xC2, 0xC3 } },
		{ startup = true,  names = { "帝王神眼拳（空中）" },                              type = act_types.any,        ids = { 0xCC, 0xCD } },
		{ startup = true,  names = { "帝王神眼拳（空中攻撃）" },                        type = act_types.attack,     ids = { 0xCE } },
		{ startup = false, names = { "帝王神眼拳（空中攻撃）" },                        type = act_types.any,        ids = { 0xCF } },
		{ startup = true,  names = { "帝王神眼拳（背後）" },                              type = act_types.any,        ids = { 0xD6, 0xD7 } },
		{ startup = true,  names = { "帝王空殺神眼拳" },                                    type = act_types.any,        ids = { 0xE0, 0xE1 } },
		{ startup = true,  names = { "竜灯掌" },                                                type = act_types.attack,     ids = { 0xB8 } },
		{ startup = true,  names = { "竜灯掌 ヒット" },                                      type = act_types.any,        ids = { 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE } },
		{ startup = true,  names = { "竜灯掌・幻殺" },                                       type = act_types.any,        ids = { 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB } },
		{ startup = true,  names = { "帝王漏尽拳" },                                          type = act_types.attack,     ids = { 0xFE, 0xFF },                                    firing = true },
		{ startup = true,  names = { "帝王漏尽拳" },                                          type = act_types.any,        ids = { 0x100 },                                         firing = true },
		{ startup = true,  names = { "帝王漏尽拳 ヒット" },                                type = act_types.any,        ids = { 0x101 },                                         firing = true },
		{ startup = true,  names = { "帝王空殺漏尽拳" },                                    type = act_types.low_attack, ids = { 0xEA, 0xEB, 0xEC },                              firing = true },
		{ startup = true,  names = { "帝王空殺漏尽拳 ヒット" },                          type = act_types.any,        ids = { 0xED },                                          firing = true },
		{ startup = false, names = { "帝王空殺漏尽拳", "帝王空殺漏尽拳 ヒット" }, type = act_types.any,        ids = { 0xEE, 0xEF },                                    firing = true },
		{ startup = true,  names = { "海龍照臨" },                                             type = act_types.attack,     ids = { 0x108, 0x109, 0x109, 0x10A },                    firing = true },
		{ startup = false, names = { "海龍照臨" },                                             type = act_types.any,        ids = { 0x10B },                                         firing = true },
		{ startup = true,  names = { "立ち" },                                                   type = act_types.free,       ids = { 0x6C } },
		{ startup = true,  names = { "CA 立A" },                                                  type = act_types.attack,     ids = { 0x247 } },
		{ startup = true,  names = { "CA 立B" },                                                  type = act_types.attack,     ids = { 0x246 } },
		{ startup = true,  names = { "CA 屈B" },                                                  type = act_types.low_attack, ids = { 0x24B } },
		{ startup = true,  names = { "CA 立C" },                                                  type = act_types.attack,     ids = { 0x240 } },
		{ startup = true,  names = { "CA 屈C" },                                                  type = act_types.low_attack, ids = { 0x24C } },
		{ startup = true,  names = { "CA _6C" },                                                   type = act_types.attack,     ids = { 0x242 } },
		{ startup = true,  names = { "CA _3C" },                                                   type = act_types.attack,     ids = { 0x241 } },
		{ startup = true,  names = { "龍回頭" },                                                type = act_types.low_attack, ids = { 0x248 } },
		{ startup = true,  names = { "CA 立C" },                                                  type = act_types.attack,     ids = { 0x245 } },
		{ startup = true,  names = { "CA 立C" },                                                  type = act_types.attack,     ids = { 0x243 } },
		{ startup = true,  names = { "CA _6_4C" },                                                 type = act_types.attack,     ids = { 0x244 } },
	},
	-- 秦崇雷,
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                type = act_types.attack,   ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                type = act_types.attack,   ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                         type = act_types.attack,   ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                         type = act_types.attack,   ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                         type = act_types.attack,   ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                            type = act_types.attack,   ids = { 0x47 } },
		{ startup = true,  names = { "フェイント 帝王宿命拳" }, type = act_types.any,      ids = { 0x112 } },
		{ startup = true,  names = { "発勁龍" },                       type = act_types.any,      ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "龍脚殺" },                       type = act_types.overhead, ids = { 0x68 } },
		{ startup = true,  names = { "帝王神足拳" },                 type = act_types.attack,   ids = { 0x86, 0x87, 0x89 } },
		{ startup = false, names = { "帝王神足拳" },                 type = act_types.any,      ids = { 0x88 } },
		{ startup = true,  names = { "小 帝王天眼拳" },             type = act_types.attack,   ids = { 0x90, 0x91 },         firing = true },
		{ startup = false, names = { "小 帝王天眼拳" },             type = act_types.any,      ids = { 0x92 },               firing = true },
		{ startup = true,  names = { "大 帝王天眼拳" },             type = act_types.attack,   ids = { 0x9A, 0x9B },         firing = true },
		{ startup = false, names = { "大 帝王天眼拳" },             type = act_types.any,      ids = { 0x9C },               firing = true },
		{ startup = true,  names = { "小 帝王天耳拳" },             type = act_types.attack,   ids = { 0xA4, 0xA5 } },
		{ startup = false, names = { "小 帝王天耳拳" },             type = act_types.any,      ids = { 0xA6, 0xA7 } },
		{ startup = true,  names = { "大 帝王天耳拳" },             type = act_types.attack,   ids = { 0xAE, 0xAF } },
		{ startup = false, names = { "大 帝王天耳拳" },             type = act_types.any,      ids = { 0xB0, 0xB1 } },
		{ startup = true,  names = { "帝王漏尽拳" },                 type = act_types.attack,   ids = { 0xB8, 0xB9 },         firing = true },
		{ startup = false, names = { "帝王漏尽拳" },                 type = act_types.any,      ids = { 0xBC }, },
		{ startup = true,  names = { "帝王漏尽拳 ヒット" },       type = act_types.attack,   ids = { 0xBB, 0xBA }, },
		{ startup = true,  names = { "龍転身（前方）" },           type = act_types.any,      ids = { 0xC2, 0xC3, 0xC4 } },
		{ startup = false, names = { "龍転身（後方）" },           type = act_types.any,      ids = { 0xCC, 0xCD, 0xCE } },
		{ startup = true,  names = { "帝王宿命拳" },                 type = act_types.attack,   ids = { 0xFE, 0xFF },         firing = true },
		{ startup = false, names = { "帝王宿命拳" },                 type = act_types.any,      ids = { 0x100 },              firing = true },
		{ startup = true,  names = { "帝王宿命拳2" },                type = act_types.attack,   ids = { 0x101, 0x102 },       firing = true },
		{ startup = false, names = { "帝王宿命拳2" },                type = act_types.any,      ids = { 0x103 },              firing = true },
		{ startup = true,  names = { "帝王宿命拳3" },                type = act_types.attack,   ids = { 0x104, 0x105 },       firing = true },
		{ startup = false, names = { "帝王宿命拳3" },                type = act_types.any,      ids = { 0x106 },              firing = true },
		{ startup = true,  names = { "帝王宿命拳4" },                type = act_types.attack,   ids = { 0x107, 0x115 },       firing = true },
		{ startup = false, names = { "帝王宿命拳4" },                type = act_types.any,      ids = { 0x116 },              firing = true },
		{ startup = true,  names = { "帝王龍声拳" },                 type = act_types.attack,   ids = { 0x108, 0x109 },       firing = true },
		{ startup = false, names = { "帝王龍声拳" },                 type = act_types.any,      ids = { 0x10A },              firing = true },
		{ startup = true,  names = { "CA _6C" },                          type = act_types.attack,   ids = { 0x243 } },
		{ startup = true,  names = { "CA 立C" },                         type = act_types.attack,   ids = { 0x242 } },
		{ startup = true,  names = { "CA _8C" },                          type = act_types.overhead, ids = { 0x244, 0x245 } },
		{ startup = true,  names = { "CA _8C" },                          type = act_types.any,      ids = { 0x246 } },
		{ startup = true,  names = { "CA _3C" },                          type = act_types.attack,   ids = { 0x240 } },
	},
	-- ダック・キング
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                                                                                       type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                                                                                       type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                                                                                                type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                                                                                                type = act_types.attack,     ids = { 0x45, 0x73, 0x74 } },
		{ startup = true,  names = { "遠立C" },                                                                                                type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                                                                                                   type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント ダックダンス" },                                                                     type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "ローリングネックスルー" },                                                                      type = act_types.attack,     ids = { 0x6D, 0x6E, 0x6F, 0x70, 0x71 } },
		{ startup = true,  names = { "ニードルロー" },                                                                                     type = act_types.low_attack, ids = { 0x68 } },
		{ startup = true,  names = { "ニードルロー" },                                                                                     type = act_types.any,        ids = { 0x72 } },
		{ startup = true,  names = { "マッドスピンハンマー" },                                                                         type = act_types.overhead,   ids = { 0x69 } },
		{ startup = true,  names = { "ショッキングボール" },                                                                            type = act_types.any,        ids = { 0x6A, 0x6B, 0x6C } },
		{ startup = true,  names = { "小ヘッドスピンアタック" },                                                                      type = act_types.attack,     ids = { 0x86, 0x87 } },
		{ startup = false, names = { "小ヘッドスピンアタック" },                                                                      type = act_types.any,        ids = { 0x8A } },
		{ startup = true,  names = { "小ヘッドスピンアタック 接触" },                                                               type = act_types.any,        ids = { 0x88, 0x89 } },
		{ startup = true,  names = { "大ヘッドスピンアタック" },                                                                      type = act_types.attack,     ids = { 0x90, 0x91 } },
		{ startup = false, names = { "大ヘッドスピンアタック" },                                                                      type = act_types.attack,     ids = { 0x94 } },
		{ startup = true,  names = { "大ヘッドスピンアタック 接触" },                                                               type = act_types.any,        ids = { 0x92, 0x93 } },
		{ startup = true,  names = { "オーバーヘッドキック" },                                                                         type = act_types.attack,     ids = { 0x95 } },
		{ startup = false, names = { "オーバーヘッドキック" },                                                                         type = act_types.any,        ids = { 0x96 } },
		{ startup = false, names = { "地上振り向き", "小ヘッドスピンアタック", "大ヘッドスピンアタック" },           type = act_types.any,        ids = { 0x3D } },
		{ startup = true,  names = { "フライングスピンアタック" },                                                                   type = act_types.attack,     ids = { 0x9A, 0x9B } },
		{ startup = true,  names = { "フライングスピンアタック 接触" },                                                            type = act_types.any,        ids = { 0x9C } },
		{ startup = false, names = { "フライングスピンアタック" },                                                                   type = act_types.any,        ids = { 0x9D, 0x9E } },
		{ startup = true,  names = { "ダンシングダイブ" },                                                                               type = act_types.attack,     ids = { 0xA4, 0xA5 } },
		{ startup = false, names = { "ダンシングダイブ" },                                                                               type = act_types.any,        ids = { 0xA6, 0xA7 } },
		{ startup = true,  names = { "リバースダイブ" },                                                                                  type = act_types.attack,     ids = { 0xA8, 0xA9 } },
		{ startup = false, names = { "リバースダイブ" },                                                                                  type = act_types.any,        ids = { 0xAA } },
		{ startup = true,  names = { "ブレイクストーム" },                                                                               type = act_types.attack,     ids = { 0xAE, 0xAF } },
		{ startup = false, names = { "ブレイクストーム" },                                                                               type = act_types.any,        ids = { 0xB0, 0xB1 } },
		{ startup = true,  names = { "ブレイクストーム 2段階目" },                                                                    type = act_types.attack,     ids = { 0xB2, 0xB6 } },
		{ startup = true,  names = { "ブレイクストーム 3段階目" },                                                                    type = act_types.attack,     ids = { 0xB3, 0xB7 } },
		{ startup = false, names = { "ブレイクストーム", "ブレイクストーム 2段階目", "ブレイクストーム 3段階目" }, type = act_types.any,        ids = { 0xB4, 0xB5 } },
		{ startup = true,  names = { "ダックフェイント・地" },                                                                         type = act_types.any,        ids = { 0xC2, 0xC3, 0xC4 } },
		{ startup = true,  names = { "ダックフェイント・空" },                                                                         type = act_types.any,        ids = { 0xB8, 0xB9, 0xBA } },
		{ startup = true,  names = { "クロスヘッドスピン" },                                                                            type = act_types.attack,     ids = { 0xD6, 0xD7 } },
		{ startup = false, names = { "クロスヘッドスピン" },                                                                            type = act_types.any,        ids = { 0xD8, 0xD9 } },
		{ startup = true,  names = { "ダイビングパニッシャー" },                                                                      type = act_types.attack,     ids = { 0xE0, 0xE1, } },
		{ startup = true,  names = { "ダイビングパニッシャー 接触" },                                                               type = act_types.any,        ids = { 0xE2 } },
		{ startup = false, names = { "ダイビングパニッシャー", "ダイビングパニッシャー 接触" },                          type = act_types.any,        ids = { 0xE3 } },
		{ startup = true,  names = { "ローリングパニッシャー" },                                                                      type = act_types.attack,     ids = { 0xE4, 0xE5 } },
		{ startup = true,  names = { "ローリングパニッシャー" },                                                                      type = act_types.any,        ids = { 0xE8 } },
		{ startup = true,  names = { "ローリングパニッシャー 接触" },                                                               type = act_types.any,        ids = { 0xE6, 0xE7 } },
		{ startup = true,  names = { "ダンシングキャリバー" },                                                                         type = act_types.low_attack, ids = { 0xE9 } },
		{ startup = false, names = { "ダンシングキャリバー" },                                                                         type = act_types.attack,     ids = { 0xEA, 0xEB, 0xEC } },
		{ startup = false, names = { "ダンシングキャリバー" },                                                                         type = act_types.any,        ids = { 0xED, 0x115 } },
		{ startup = true,  names = { "ブレイクハリケーン" },                                                                            type = act_types.low_attack, ids = { 0xEE, 0xF1 } },
		{ startup = false, names = { "ブレイクハリケーン" },                                                                            type = act_types.attack,     ids = { 0xEF, 0xF0, 0xF2, 0xF3 } },
		{ startup = false, names = { "ブレイクハリケーン" },                                                                            type = act_types.any,        ids = { 0x116, 0xF4 } },
		{ startup = true,  names = { "ブレイクスパイラル" },                                                                            type = act_types.any,        ids = { 0xFE, 0xFF, 0x100, 0x102 } },
		{ startup = true,  names = { "ブレイクスパイラルブラザー" },                                                                type = act_types.any,        ids = { 0xF8, 0xF9 } },
		{ startup = false, names = { "ブレイクスパイラルブラザー" },                                                                type = act_types.any,        ids = { 0xFA, 0xFB, 0xFC, 0xFD } },
		{ startup = true,  names = { "ダックダンス" },                                                                                     type = act_types.attack,     ids = { 0x108 } },
		{ startup = true,  names = { "ダックダンス Lv.1" },                                                                                type = act_types.any,        ids = { 0x109, 0x10C } },
		{ startup = true,  names = { "ダックダンス Lv.2" },                                                                                type = act_types.any,        ids = { 0x10A, 0x10D } },
		{ startup = true,  names = { "ダックダンス Lv.3" },                                                                                type = act_types.any,        ids = { 0x10B, 0x10E } },
		{ startup = true,  names = { "ダックダンス Lv.4" },                                                                                type = act_types.any,        ids = { 0x10F } },
		{ startup = true,  names = { "スーパーポンピングマシーン" },                                                                type = act_types.low_attack, ids = { 0x77, 0x78 } },
		{ startup = false, names = { "スーパーポンピングマシーン" },                                                                type = act_types.any,        ids = { 0x79 } },
		{ startup = true,  names = { "スーパーポンピングマシーン ヒット" },                                                      type = act_types.any,        ids = { 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F, 0x82, 0x80, 0x81 } },
		{ startup = true,  names = { "CA 立B" },                                                                                                type = act_types.attack,     ids = { 0x24E } },
		{ startup = true,  names = { "CA 立B" },                                                                                                type = act_types.attack,     ids = { 0x240 } },
		{ startup = true,  names = { "CA 屈B" },                                                                                                type = act_types.low_attack, ids = { 0x24F } },
		{ startup = true,  names = { "CA 立C" },                                                                                                type = act_types.attack,     ids = { 0x243 } },
		{ startup = true,  names = { "CA 屈C" },                                                                                                type = act_types.low_attack, ids = { 0x24D } },
		{ startup = true,  names = { "CA _6C" },                                                                                                 type = act_types.attack,     ids = { 0x242 } },
		{ startup = true,  names = { "CA _3C" },                                                                                                 type = act_types.attack,     ids = { 0x244 } },
		{ startup = true,  names = { "CA 屈C" },                                                                                                type = act_types.any,        ids = { 0x24C } },
		{ startup = true,  names = { "CA 屈C" },                                                                                                type = act_types.low_attack, ids = { 0x245 } },
		{ startup = true,  names = { "旧ブレイクストーム" },                                                                            type = act_types.low_attack, ids = { 0x247, 0x248 } },
		{ startup = false, names = { "旧ブレイクストーム" },                                                                            type = act_types.any,        ids = { 0x249, 0x24A } },
	},
	-- キム・カッファン
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },          type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },          type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                   type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                   type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                   type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                      type = act_types.low_attack, ids = { 0x47 } },
		{ startup = true,  names = { "フェイント 鳳凰脚" }, type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "体落とし" },              type = act_types.any,        ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "ネリチャギ" },           type = act_types.overhead,   ids = { 0x68, 0x69 } },
		{ startup = false, names = { "ネリチャギ" },           type = act_types.any,        ids = { 0x6A } },
		{ startup = true,  names = { "飛燕斬" },                 type = act_types.attack,     ids = { 0x86, 0x87 } },
		{ startup = false, names = { "飛燕斬" },                 type = act_types.any,        ids = { 0x88, 0x89 } },
		{ startup = true,  names = { "小 半月斬" },             type = act_types.attack,     ids = { 0x90, 0x91, 0x92 } },
		{ startup = true,  names = { "大 半月斬" },             type = act_types.attack,     ids = { 0x9A, 0x9B, 0x9C } },
		{ startup = true,  names = { "飛翔脚" },                 type = act_types.low_attack, ids = { 0xA4, 0xA5 } },
		{ startup = false, names = { "飛翔脚" },                 type = act_types.any,        ids = { 0xA6 } },
		{ startup = true,  names = { "戒脚" },                    type = act_types.low_attack, ids = { 0xA7, 0xA8 } },
		{ startup = false, names = { "戒脚" },                    type = act_types.any,        ids = { 0xA9 } },
		{ startup = true,  names = { "空砂塵" },                 type = act_types.attack,     ids = { 0xAE, 0xAF } },
		{ startup = false, names = { "空砂塵" },                 type = act_types.any,        ids = { 0xB0, 0xB1 } },
		{ startup = true,  names = { "天昇斬" },                 type = act_types.attack,     ids = { 0xB2 } },
		{ startup = false, names = { "天昇斬" },                 type = act_types.any,        ids = { 0xB3, 0xB4 } },
		{ startup = true,  names = { "覇気脚" },                 type = act_types.low_attack, ids = { 0xB8 } },
		{ startup = true,  names = { "鳳凰天舞脚" },           type = act_types.low_attack, ids = { 0xFE, 0xFF } },
		{ startup = false, names = { "鳳凰天舞脚" },           type = act_types.any,        ids = { 0x100 } },
		{ startup = true,  names = { "鳳凰天舞脚 ヒット" }, type = act_types.any,        ids = { 0x101, 0x102, 0x103, 0x104, 0x105, 0x106, 0x107 } },
		{ startup = true,  names = { "鳳凰脚" },                 type = act_types.attack,     ids = { 0x108, 0x109, 0x10A } },
		{ startup = true,  names = { "鳳凰脚 ヒット" },       type = act_types.any,        ids = { 0x10B, 0x10C, 0x10D, 0x10E, 0x10F, 0x110, 0x115 } },
		{ startup = true,  names = { "CA ネリチャギ" },        type = act_types.overhead,   ids = { 0x24A, 0x24B } },
		{ startup = false, names = { "CA ネリチャギ" },        type = act_types.any,        ids = { 0x24C } },
		{ startup = true,  names = { "CA 立A" },                   type = act_types.attack,     ids = { 0x241 } },
		{ startup = true,  names = { "CA 立B" },                   type = act_types.attack,     ids = { 0x244 } },
		{ startup = true,  names = { "CA 立C" },                   type = act_types.attack,     ids = { 0x246, 0x247 } },
		{ startup = true,  names = { "CA 立C" },                   type = act_types.attack,     ids = { 0x248 } },
		{ startup = true,  names = { "CA 立A" },                   type = act_types.attack,     ids = { 0x240 } },
		{ startup = true,  names = { "CA 立B" },                   type = act_types.attack,     ids = { 0x243 } },
		{ startup = true,  names = { "CA 立B" },                   type = act_types.attack,     ids = { 0x249 } },
		{ startup = true,  names = { "CA 立C" },                   type = act_types.attack,     ids = { 0x242 } },
	},
	-- ビリー・カーン
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                  type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                  type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                           type = act_types.low_attack, ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                           type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                           type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                              type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント 強襲飛翔棍" },   type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "一本釣り投げ" },                type = act_types.any,        ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "地獄落とし" },                   type = act_types.any,        ids = { 0x81, 0x82, 0x83, 0x84 } },
		{ startup = true,  names = { "三節棍中段打ち" },             type = act_types.attack,     ids = { 0x86, 0x87 },                        firing = true },
		{ startup = false, names = { "三節棍中段打ち" },             type = act_types.any,        ids = { 0x88, 0x89 } },
		{ startup = true,  names = { "火炎三節棍中段突き" },       type = act_types.attack,     ids = { 0x90, 0x91, },                       firing = true },
		{ startup = false, names = { "火炎三節棍中段突き" },       type = act_types.any,        ids = { 0x92, 0x93 } },
		{ startup = true,  names = { "燕落とし" },                      type = act_types.attack,     ids = { 0x9A, 0x9B } },
		{ startup = false, names = { "燕落とし" },                      type = act_types.any,        ids = { 0x9C } },
		{ startup = true,  names = { "火龍追撃棍" },                   type = act_types.attack,     ids = { 0xB8, 0xB9 } },
		{ startup = true,  names = { "旋風棍" },                         type = act_types.attack,     ids = { 0xA4 } },
		{ startup = false, names = { "旋風棍" },                         type = act_types.attack,     ids = { 0xA5 } },
		{ startup = false, names = { "旋風棍" },                         type = act_types.any,        ids = { 0xA6 } },
		{ startup = true,  names = { "強襲飛翔棍" },                   type = act_types.attack,     ids = { 0xAE, 0xAF, 0xB0 } },
		{ startup = false, names = { "強襲飛翔棍" },                   type = act_types.any,        ids = { 0xB1 } },
		{ startup = true,  names = { "超火炎旋風棍" },                type = act_types.attack,     ids = { 0xFE, 0xFF, 0x100 },                 firing = true },
		{ startup = true,  names = { "紅蓮殺棍" },                      type = act_types.attack,     ids = { 0xF4, 0xF5, 0xF6 } },
		{ startup = false, names = { "紅蓮殺棍" },                      type = act_types.any,        ids = { 0xF7, 0xF8 } },
		{ startup = true,  names = { "サラマンダーストリーム" }, type = act_types.attack,     ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C }, firing = true },
		{ startup = true,  names = { "立C" },                              type = act_types.attack,     ids = { 0x46, 0x6C } },
		{ startup = true,  names = { "CA 立C" },                           type = act_types.low_attack, ids = { 0x241 } },
		{ startup = true,  names = { "CA 立C" },                           type = act_types.attack,     ids = { 0x248 } },
		{ startup = true,  names = { "CA 立C _6C" },                       type = act_types.attack,     ids = { 0x242 } },
		{ startup = true,  names = { "CA 屈C" },                           type = act_types.attack,     ids = { 0x243 } },
		{ startup = true,  names = { "CA 立C" },                           type = act_types.attack,     ids = { 0x245 } },
		{ startup = true,  names = { "集点連破棍" },                   type = act_types.attack,     ids = { 0x246 } },
	},
	-- チン・シンザン
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                                 type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                                 type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                                          type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                                          type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                                          type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "遠屈A" },                                          type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント 破岩撃" },                        type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "フェイント クッサメ砲" },                  type = act_types.any,        ids = { 0x113 } },
		{ startup = true,  names = { "合気投げ" },                                     type = act_types.any,        ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "頭突殺" },                                        type = act_types.any,        ids = { 0x81, 0x83, 0x84 } },
		{ startup = true,  names = { "発勁裏拳" },                                     type = act_types.attack,     ids = { 0x68 } },
		{ startup = true,  names = { "落撃双拳" },                                     type = act_types.overhead,   ids = { 0x69 } },
		{ startup = true,  names = { "気雷砲（前方）" },                            type = act_types.low_attack, ids = { 0x86, 0x87, 0x88 },   firing = true },
		{ startup = true,  names = { "気雷砲（対空）" },                            type = act_types.low_attack, ids = { 0x90, 0x91, 0x92 },   firing = true },
		{ startup = true,  names = { "小 破岩撃" },                                    type = act_types.low_attack, ids = { 0xA4, 0xA5 } },
		{ startup = false, names = { "小 破岩撃" },                                    type = act_types.any,        ids = { 0xA6 } },
		{ startup = true,  names = { "小 破岩撃 接触" },                             type = act_types.any,        ids = { 0xA7, 0xA8 } },
		{ startup = true,  names = { "大 破岩撃" },                                    type = act_types.low_attack, ids = { 0xAE, 0xAF } },
		{ startup = false, names = { "大 破岩撃" },                                    type = act_types.any,        ids = { 0xB0 } },
		{ startup = true,  names = { "大 破岩撃 接触" },                             type = act_types.any,        ids = { 0xB1, 0xB2 } },
		{ startup = true,  names = { "超太鼓腹打ち" },                               type = act_types.attack,     ids = { 0x9A, 0x9B } },
		{ startup = true,  names = { "満腹滞空" },                                     type = act_types.attack,     ids = { 0x9F, 0xA0 } },
		{ startup = false, names = { "超太鼓腹打ち", "滞空滞空" },               type = act_types.any,        ids = { 0x9C } },
		{ startup = true,  names = { "超太鼓腹打ち 接触", "滞空滞空 接触" }, type = act_types.any,        ids = { 0x9D, 0x9E } },
		{ startup = true,  names = { "軟体オヤジ" },                                  type = act_types.any,        ids = { 0xB8, 0xBA } },
		{ startup = true,  names = { "軟体オヤジ持続" },                            type = act_types.any,        ids = { 0xB9, 0xBA } },
		{ startup = true,  names = { "軟体オヤジ隙" },                               type = act_types.any,        ids = { 0xBB } },
		{ startup = true,  names = { "クッサメ砲" },                                  type = act_types.low_attack, ids = { 0xC2, 0xC3 },         firing = true },
		{ startup = false, names = { "クッサメ砲" },                                  type = act_types.any,        ids = { 0xC4, 0xC5 },         firing = true },
		{ startup = true,  names = { "爆雷砲" },                                        type = act_types.attack,     ids = { 0xFE, 0xFF, 0x100 },  firing = true },
		{ startup = true,  names = { "ホエホエ弾" },                                  type = act_types.low_attack, ids = { 0x108, 0x109, },      firing = true },
		{ startup = false, names = { "ホエホエ弾" },                                  type = act_types.any,        ids = { 0x10A },              firing = true },
		{ startup = true,  names = { "ホエホエ弾 持続" },                           type = act_types.low_attack, ids = { 0x10C, 0x10D },       firing = true },
		{ startup = false, names = { "ホエホエ弾 持続" },                           type = act_types.any,        ids = { 0x114, 0x115 },       firing = true },
		{ startup = true,  names = { "ホエホエ弾 落下攻撃" },                     type = act_types.overhead,   ids = { 0x10E },              firing = true },
		{ startup = true,  names = { "ホエホエ弾 落下攻撃 接触" },              type = act_types.any,        ids = { 0x10F },              firing = true },
		{ startup = true,  names = { "ホエホエ弾 着地1" },                          type = act_types.any,        ids = { 0x10B },              firing = true },
		{ startup = true,  names = { "ホエホエ弾 着地2" },                          type = act_types.any,        ids = { 0x110 },              firing = true },
		{ startup = true,  names = { "ホエホエ弾 着地3" },                          type = act_types.any,        ids = { 0x116 },              firing = true },
		{ startup = true,  names = { "CA 立C" },                                          type = act_types.low_attack, ids = { 0x24A } },
		{ startup = true,  names = { "CA _3C(近)" },                                      type = act_types.attack,     ids = { 0x242 } },
		{ startup = true,  names = { "CA 立C" },                                          type = act_types.attack,     ids = { 0x240 } },
		{ startup = true,  names = { "CA _3C(遠)" },                                      type = act_types.attack,     ids = { 0x249 } },
		{ startup = true,  names = { "CA 立C" },                                          type = act_types.attack,     ids = { 0x241 } },
		{ startup = true,  names = { "CA 屈C" },                                          type = act_types.low_attack, ids = { 0x246 } },
		{ startup = true,  names = { "CA 立C2" },                                         type = act_types.attack,     ids = { 0x24B, 0x24C } },
		{ startup = true,  names = { "CA 立C2" },                                         type = act_types.low_attack, ids = { 0x24D } },
		{ startup = true,  names = { "CA 立C3" },                                         type = act_types.low_attack, ids = { 0x247 } },
		{ startup = true,  names = { "CA _6_6+B" },                                        type = act_types.any,        ids = { 0x248 } },
		{ startup = true,  names = { "CA D" },                                             type = act_types.overhead,   ids = { 0x243 } },
		{ startup = true,  names = { "CA _3C" },                                           type = act_types.any,        ids = { 0x244 } },
		{ startup = true,  names = { "CA _1C" },                                           type = act_types.any,        ids = { 0x245 } },
	},
	-- タン・フー・ルー,
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },             type = act_types.attack,   ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },             type = act_types.attack,   ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                      type = act_types.attack,   ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                      type = act_types.attack,   ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                      type = act_types.attack,   ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                         type = act_types.attack,   ids = { 0x47 } },
		{ startup = true,  names = { "フェイント 旋風剛拳" }, type = act_types.any,      ids = { 0x112 } },
		{ startup = true,  names = { "裂千掌" },                    type = act_types.any,      ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "右降龍" },                    type = act_types.attack,   ids = { 0x68 } },
		{ startup = true,  names = { "衝波" },                       type = act_types.attack,   ids = { 0x86, 0x87 },                firing = true },
		{ startup = false, names = { "衝波" },                       type = act_types.any,      ids = { 0x88 } },
		{ startup = true,  names = { "小 箭疾歩" },                type = act_types.attack,   ids = { 0x90, 0x91 } },
		{ startup = false, names = { "小 箭疾歩" },                type = act_types.any,      ids = { 0x92 } },
		{ startup = true,  names = { "大 箭疾歩" },                type = act_types.attack,   ids = { 0x9A, 0x9B } },
		{ startup = false, names = { "大 箭疾歩" },                type = act_types.any,      ids = { 0x9C } },
		{ startup = true,  names = { "裂千脚" },                    type = act_types.attack,   ids = { 0xAE, 0xAF, 0xB0 } },
		{ startup = false, names = { "裂千脚" },                    type = act_types.any,      ids = { 0xB1, 0xB2 } },
		{ startup = true,  names = { "撃放" },                       type = act_types.attack,   ids = { 0xA4 } },
		{ startup = true,  names = { "撃放 タメ" },                type = act_types.attack,   ids = { 0xA5 } },
		{ startup = true,  names = { "撃放 タメ開放" },          type = act_types.attack,   ids = { 0xA7, 0xA8, 0xA9 } },
		{ startup = true,  names = { "撃放隙" },                    type = act_types.any,      ids = { 0xA6 } },
		{ startup = true,  names = { "旋風剛拳" },                 type = act_types.attack,   ids = { 0xFE, 0xFF, 0x100 } },
		{ startup = false, names = { "旋風剛拳" },                 type = act_types.any,      ids = { 0x101, 0x102 } },
		{ startup = true,  names = { "大撃放" },                    type = act_types.attack,   ids = { 0x108, 0x109, 0x10A, 0x10B } },
		{ startup = false, names = { "大撃放" },                    type = act_types.any,      ids = { 0x10C } },
		{ startup = true,  names = { "CA 立C" },                      type = act_types.overhead, ids = { 0x247, 0x248 } },
		{ startup = true,  names = { "CA 立C" },                      type = act_types.overhead, ids = { 0x249 } },
		{ startup = true,  names = { "挑発2" },                      type = act_types.provoke,  ids = { 0x24A } },
		{ startup = true,  names = { "挑発3" },                      type = act_types.provoke,  ids = { 0x24B } },
	},
	-- ローレンス・ブラッド
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                                                                 type = act_types.attack,   ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                                                                 type = act_types.attack,   ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                                                                          type = act_types.attack,   ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                                                                          type = act_types.attack,   ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                                                                          type = act_types.attack,   ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                                                                             type = act_types.attack,   ids = { 0x47 } },
		{ startup = true,  names = { "マタドールバスター" },                                                      type = act_types.any,      ids = { 0x6D, 0x6E, 0x6F } },
		{ startup = true,  names = { "トルネードキック" },                                                         type = act_types.attack,   ids = { 0x68 } },
		{ startup = true,  names = { "オーレィ" },                                                                     type = act_types.any,      ids = { 0x69 } },
		{ startup = true,  names = { "小ブラッディスピン" },                                                      type = act_types.attack,   ids = { 0x86, 0x87 } },
		{ startup = false, names = { "小ブラッディスピン" },                                                      type = act_types.any,      ids = { 0x88, 0x89 } },
		{ startup = true,  names = { "大ブラッディスピン" },                                                      type = act_types.attack,   ids = { 0x90, 0x91 } },
		{ startup = false, names = { "大ブラッディスピン", "大ブラッディスピン ヒット" },             type = act_types.any,      ids = { 0x93, 0x94 } },
		{ startup = true,  names = { "大ブラッディスピン ヒット" },                                            type = act_types.attack,   ids = { 0x92 } },
		{ startup = false, names = { "地上振り向き", "小ブラッディスピン", "大ブラッディスピン" }, type = act_types.any,      ids = { 0x3D } },
		{ startup = true,  names = { "ブラッディサーベル" },                                                      type = act_types.attack,   ids = { 0x9A, 0x9B },                       firing = true },
		{ startup = false, names = { "ブラッディサーベル" },                                                      type = act_types.any,      ids = { 0x9C } },
		{ startup = true,  names = { "ブラッディカッター" },                                                      type = act_types.attack,   ids = { 0xAE, 0xAF, 0xB0 } },
		{ startup = false, names = { "ブラッディカッター" },                                                      type = act_types.any,      ids = { 0xB2, 0xB1 } },
		{ startup = true,  names = { "ブラッディミキサー" },                                                      type = act_types.attack,   ids = { 0xA4 },                             firing = true },
		{ startup = true,  names = { "ブラッディミキサー持続" },                                                type = act_types.attack,   ids = { 0xA5 },                             firing = true },
		{ startup = true,  names = { "ブラッディミキサー隙" },                                                   type = act_types.any,      ids = { 0xA6 } },
		{ startup = true,  names = { "ブラッディフラッシュ" },                                                   type = act_types.attack,   ids = { 0xFE, 0xFF, 0x100, 0x101 } },
		{ startup = true,  names = { "ブラッディフラッシュ フィニッシュ" },                                type = act_types.attack,   ids = { 0x102 } },
		{ startup = true,  names = { "ブラッディシャドー" },                                                      type = act_types.attack,   ids = { 0x108 } },
		{ startup = true,  names = { "ブラッディシャドー ヒット" },                                            type = act_types.any,      ids = { 0x109, 0x10E, 0x10D, 0x10B, 0x10C } },
		{ startup = true,  names = { "CA 立C" },                                                                          type = act_types.attack,   ids = { 0x245 } },
		{ startup = true,  names = { "CA 立C" },                                                                          type = act_types.attack,   ids = { 0x246 } },
		{ startup = true,  names = { "CA 立D" },                                                                          type = act_types.attack,   ids = { 0x24C } },
		{ startup = true,  names = { "CA 立C" },                                                                          type = act_types.attack,   ids = { 0x248 } },
		{ startup = true,  names = { "CA _6_3_2+C" },                                                                      type = act_types.overhead, ids = { 0x249, 0x24A } },
		{ startup = true,  names = { "CA _6_3_2+C" },                                                                      type = act_types.any,      ids = { 0x24B } },
	},
	-- ヴォルフガング・クラウザー
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                                                                        type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                                                                        type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                                                                                 type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                                                                                 type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                                                                                 type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                                                                                    type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント ブリッツボール" },                                                   type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "フェイント カイザーウェイブ" },                                                type = act_types.any,        ids = { 0x113 } },
		{ startup = true,  names = { "ニースマッシャー" },                                                                type = act_types.any,        ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "デスハンマー" },                                                                      type = act_types.overhead,   ids = { 0x68 } },
		{ startup = true,  names = { "カイザーボディプレス" },                                                          type = act_types.attack,     ids = { 0x69 } },
		{ startup = true,  names = { "着地", "ジャンプ着地(カイザーボディプレス)" },                            type = act_types.any,        ids = { 0x72 } },
		{ startup = true,  names = { "ダイビングエルボー" },                                                             type = act_types.any,        ids = { 0x6A, 0x73, 0x74, 0x75 } },
		{ startup = true,  names = { "ブリッツボール・上段" },                                                          type = act_types.attack,     ids = { 0x86, 0x87, 0x88 },                                           firing = true },
		{ startup = true,  names = { "ブリッツボール・下段" },                                                          type = act_types.low_attack, ids = { 0x90, 0x91, 0x92 },                                           firing = true },
		{ startup = true,  names = { "レッグトマホーク" },                                                                type = act_types.overhead,     ids = { 0x9A, 0x9B } },
		{ startup = false, names = { "レッグトマホーク" },                                                                type = act_types.any,        ids = { 0x9C } },
		{ startup = true,  names = { "デンジャラススルー" },                                                             type = act_types.any,        ids = { 0xAE, 0xAF } },
		{ startup = true,  names = { "グリフォンアッパー" },                                                             type = act_types.attack,     ids = { 0x248 } },
		{ startup = true,  names = { "リフトアップブロー" },                                                             type = act_types.any,        ids = { 0xC2, 0xC3 } },
		{ startup = true,  names = { "フェニックススルー" },                                                             type = act_types.any,        ids = { 0xA4, 0xA5, 0xA6, 0xA7 } },
		{ startup = true,  names = { "カイザークロー" },                                                                   type = act_types.attack,     ids = { 0xB8, 0xB9, 0xBA } },
		{ startup = true,  names = { "カイザーウェイブ" },                                                                type = act_types.attack,     ids = { 0xFE } },
		{ startup = true,  names = { "カイザーウェイブため" },                                                          type = act_types.attack,     ids = { 0xFF } },
		{ startup = true,  names = { "カイザーウェイブ発射" },                                                          type = act_types.attack,     ids = { 0x100, 0x101, 0x102 },                                        firing = true },
		{ startup = false, names = { "ギガティックサイクロン", "アンリミテッドデザイア2", "ジャンプ" }, type = act_types.any,        ids = { 0x108, 0x109, 0x10A, 0x10B, 0xC, 0x10C, 0x10D, 0x10C, 0x10E } },
		{ startup = true,  names = { "アンリミテッドデザイア" },                                                       type = act_types.attack,     ids = { 0xE0, 0xE1, } },
		{ startup = true,  names = { "アンリミテッドデザイア" },                                                       type = act_types.any,        ids = { 0xE2 } },
		{ startup = true,  names = { "アンリミテッドデザイア(2)" },                                                    type = act_types.attack,     ids = { 0xE3 } },
		{ startup = true,  names = { "アンリミテッドデザイア(3)" },                                                    type = act_types.attack,     ids = { 0xE4 } },
		{ startup = true,  names = { "アンリミテッドデザイア(4)" },                                                    type = act_types.attack,     ids = { 0xE5 } },
		{ startup = true,  names = { "アンリミテッドデザイア(5)" },                                                    type = act_types.attack,     ids = { 0xE6 } },
		{ startup = true,  names = { "アンリミテッドデザイア(6)" },                                                    type = act_types.attack,     ids = { 0xE7 } },
		{ startup = true,  names = { "アンリミテッドデザイア(7)" },                                                    type = act_types.attack,     ids = { 0xE8 } },
		{ startup = true,  names = { "アンリミテッドデザイア(8)" },                                                    type = act_types.attack,     ids = { 0xE9 } },
		{ startup = true,  names = { "アンリミテッドデザイア(9)" },                                                    type = act_types.attack,     ids = { 0xEA } },
		{ startup = true,  names = { "アンリミテッドデザイア(10)" },                                                   type = act_types.attack,     ids = { 0xEB } },
		{ startup = true,  names = { "CA 立C" },                                                                                 type = act_types.attack,     ids = { 0x240 } },
		{ startup = true,  names = { "CA 立C" },                                                                                 type = act_types.attack,     ids = { 0x24E } },
		{ startup = true,  names = { "CA 立C" },                                                                                 type = act_types.attack,     ids = { 0x242 } },
		{ startup = true,  names = { "CA 立C" },                                                                                 type = act_types.attack,     ids = { 0x241 } },
		{ startup = true,  names = { "CA 屈C" },                                                                                 type = act_types.low_attack, ids = { 0x244 } },
		{ startup = true,  names = { "CA 立C" },                                                                                 type = act_types.attack,     ids = { 0x243 } },
		{ startup = true,  names = { "CA _2_3_6+C" },                                                                             type = act_types.attack,     ids = { 0x245 } },
		{ startup = true,  names = { "CA _3C" },                                                                                  type = act_types.attack,     ids = { 0x247 } },
	},
	-- リック・ストラウド
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                                       type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                                       type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                                                type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                                                type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                                                type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                                                   type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント シューティングスター" },         type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "ガング・ホー" },                                     type = act_types.any,        ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "チョッピングライト" },                            type = act_types.overhead,   ids = { 0x68, 0x69 } },
		{ startup = true,  names = { "スマッシュソード" },                               type = act_types.attack,     ids = { 0x6A } },
		{ startup = true,  names = { "パニッシャー" },                                     type = act_types.attack,     ids = { 0x6B } },
		{ startup = true,  names = { "小 シューティングスター" },                     type = act_types.attack,     ids = { 0x86, 0x87 } },
		{ startup = false, names = { "小 シューティングスター" },                     type = act_types.any,        ids = { 0x8C } },
		{ startup = true,  names = { "小 シューティングスター ヒット" },           type = act_types.attack,     ids = { 0x88, 0x89, 0x8A } },
		{ startup = false, names = { "小 シューティングスター ヒット" },           type = act_types.any,        ids = { 0x8B } },
		{ startup = true,  names = { "大 シューティングスター" },                     type = act_types.attack,     ids = { 0x90, 0x91, 0x92, 0x93, 0x94 } },
		{ startup = true,  names = { "シューティングスターEX" },                       type = act_types.attack,     ids = { 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8 } },
		{ startup = false, names = { "シューティングスターEX" },                       type = act_types.any,        ids = { 0xC9, 0xCA } },
		{ startup = true,  names = { "地上振り向き", "シューティングスターEX" }, type = act_types.any,        ids = { 0x3D } },
		{ startup = true,  names = { "ブレイジングサンバースト" },                   type = act_types.attack,     ids = { 0xB8, 0xB9 } },
		{ startup = false, names = { "ブレイジングサンバースト" },                   type = act_types.any,        ids = { 0xBA } },
		{ startup = true,  names = { "ヘリオン" },                                           type = act_types.attack,     ids = { 0xAE, 0xAF, 0xB1 } },
		{ startup = false, names = { "ヘリオン" },                                           type = act_types.any,        ids = { 0xB0 } },
		{ startup = true,  names = { "フルムーンフィーバー" },                         type = act_types.any,        ids = { 0xA4 } },
		{ startup = true,  names = { "フルムーンフィーバー 持続" },                  type = act_types.any,        ids = { 0xA5 } },
		{ startup = true,  names = { "フルムーンフィーバー 隙" },                     type = act_types.any,        ids = { 0xA6 } },
		{ startup = true,  names = { "ディバインブラスト" },                            type = act_types.attack,     ids = { 0x9A, 0x9B, 0x9C, 0x9D } },
		{ startup = false, names = { "ディバインブラスト" },                            type = act_types.any,        ids = { 0x9E } },
		{ startup = true,  names = { "フェイクブラスト" },                               type = act_types.any,        ids = { 0x9F } },
		{ startup = true,  names = { "ガイアブレス" },                                     type = act_types.attack,     ids = { 0xFE, 0xFF },                              firing = true },
		{ startup = false, names = { "ガイアブレス" },                                     type = act_types.any,        ids = { 0x100 } },
		{ startup = true,  names = { "ハウリング・ブル" },                               type = act_types.low_attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C },       firing = true },
		{ startup = true,  names = { "CA 立B" },                                                type = act_types.attack,     ids = { 0x240 } },
		{ startup = true,  names = { "CA 立C" },                                                type = act_types.attack,     ids = { 0x243 } },
		{ startup = true,  names = { "CA 立B" },                                                type = act_types.attack,     ids = { 0x241 } },
		{ startup = true,  names = { "CA 立C" },                                                type = act_types.attack,     ids = { 0x24D } },
		{ startup = true,  names = { "CA 立C" },                                                type = act_types.attack,     ids = { 0x244 } },
		{ startup = true,  names = { "CA 立C" },                                                type = act_types.attack,     ids = { 0x246 } },
		{ startup = true,  names = { "CA 立C" },                                                type = act_types.attack,     ids = { 0x253 } },
		{ startup = true,  names = { "CA 立C" },                                                type = act_types.attack,     ids = { 0x251 } },
		{ startup = true,  names = { "CA _3C" },                                                 type = act_types.attack,     ids = { 0x248 } },
		{ startup = true,  names = { "CA 屈B" },                                                type = act_types.low_attack, ids = { 0x242 } },
		{ startup = true,  names = { "CA 屈C" },                                                type = act_types.low_attack, ids = { 0x247 } },
		{ startup = true,  names = { "CA 立C" },                                                type = act_types.attack,     ids = { 0x245 } },
		{ startup = true,  names = { "CA 立B" },                                                type = act_types.attack,     ids = { 0x24C } },
		{ startup = true,  names = { "CA 屈C" },                                                type = act_types.low_attack, ids = { 0x24A } },
		{ startup = true,  names = { "CA C" },                                                   type = act_types.attack,     ids = { 0x24E, 0x24F } },
		{ startup = true,  names = { "CA C" },                                                   type = act_types.any,        ids = { 0x250 } },
		{ startup = true,  names = { "CA _2_2+C" },                                              type = act_types.overhead,   ids = { 0xE6 } },
		{ startup = true,  names = { "CA _2_2+C" },                                              type = act_types.any,        ids = { 0xE7 } },
		{ startup = true,  names = { "CA _3_3+B" },                                              type = act_types.overhead,   ids = { 0xE0, 0xE1 } },
		{ startup = true,  names = { "CA _3_3+B" },                                              type = act_types.any,        ids = { 0xE2 } },
		{ startup = true,  names = { "CA _4C" },                                                 type = act_types.attack,     ids = { 0x249 } },
		{ startup = true,  names = { "CA 立B" },                                                type = act_types.attack,     ids = { 0x24B } },
	},
	-- 李香緋
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                   type = act_types.attack,     ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                   type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                            type = act_types.attack,     ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                            type = act_types.attack,     ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                            type = act_types.attack,     ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                               type = act_types.attack,     ids = { 0x47 } },
		{ startup = true,  names = { "フェイント 天崩山" },          type = act_types.any,        ids = { 0x113 } },
		{ startup = true,  names = { "フェイント 大鉄神" },          type = act_types.any,        ids = { 0x112 } },
		{ startup = true,  names = { "力千後宴" },                       type = act_types.any,        ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "裡門頂肘" },                       type = act_types.attack,     ids = { 0x68, 0x69, 0x6A } },
		{ startup = true,  names = { "後捜腿" },                          type = act_types.low_attack, ids = { 0x6B } },
		{ startup = true,  names = { "小 那夢波" },                      type = act_types.attack,     ids = { 0x86, 0x87, 0x88 },            firing = true },
		{ startup = true,  names = { "大 那夢波" },                      type = act_types.attack,     ids = { 0x90, 0x91, 0x92, 0x93 },      firing = true },
		--[[
		  f = ,  0x9E, 0x9F, 閃里肘皇移動
		  f = ,  0xA2, 閃里肘皇スカり
		  f = ,  0xA1, 0xA7, 閃里肘皇ヒット
		  f = ,  0xAD, 閃里肘皇・心砕把スカり
		  f = ,  0xA3, 0xA4, 0xA5, 0xA6, 閃里肘皇・貫空
		  f = ,  0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 閃里肘皇・心砕把
		]]
		{ startup = true,  names = { "閃里肘皇" },                       type = act_types.attack,     ids = { 0x9E, 0x9F } },
		{ startup = false, names = { "閃里肘皇" },                       type = act_types.any,        ids = { 0xA2 } },
		{ startup = true,  names = { "閃里肘皇 ヒット" },             type = act_types.attack,     ids = { 0xA1, 0xA7 } },
		{ startup = true,  names = { "閃里肘皇・貫空" },              type = act_types.attack,     ids = { 0xA3, 0xA4 } },
		{ startup = false, names = { "閃里肘皇・貫空" },              type = act_types.attack,     ids = { 0xA5, 0xA6 } },
		{ startup = true,  names = { "閃里肘皇・心砕把" },           type = act_types.attack,     ids = { 0xAD } },
		{ startup = true,  names = { "閃里肘皇・心砕把 ヒット" }, type = act_types.attack,     ids = { 0xA8, 0xA9, 0xAA, 0xAB, 0xAC } },
		{ startup = true,  names = { "天崩山" },                          type = act_types.attack,     ids = { 0x9A, 0x9B } },
		{ startup = false, names = { "天崩山" },                          type = act_types.any,        ids = { 0x9C, 0x9D } },
		{ startup = true,  names = { "詠酒・対ジャンプ攻撃" },     type = act_types.attack,     ids = { 0xB8 } },
		{ startup = true,  names = { "詠酒・対立ち攻撃" },           type = act_types.attack,     ids = { 0xAE } },
		{ startup = true,  names = { "詠酒・対しゃがみ攻撃" },     type = act_types.low_attack, ids = { 0xC2 } },
		{ startup = true,  names = { "大鉄神" },                          type = act_types.attack,     ids = { 0xF4, 0xF5 } },
		{ startup = false, names = { "大鉄神" },                          type = act_types.any,        ids = { 0xF6, 0xF7 } },
		{ startup = true,  names = { "超白龍" },                          type = act_types.attack,     ids = { 0xFE, 0xFF } },
		{ startup = false, names = { "超白龍" },                          type = act_types.attack,     ids = { 0x100, 0x101, 0x102, 0x103 } },
		{ startup = true,  names = { "真心牙" },                          type = act_types.attack,     ids = { 0x108, 0x109, 0x10D },         firing = true },
		{ startup = false, names = { "真心牙" },                          type = act_types.any,        ids = { 0x10E, 0x10F, 0x110 } },
		{ startup = true,  names = { "真心牙 ヒット" },                type = act_types.any,        ids = { 0x10A, 0x10B, 0x10C } },
		{ startup = true,  names = { "CA 立A" },                            type = act_types.attack,     ids = { 0x241 } },
		{ startup = true,  names = { "CA 立A" },                            type = act_types.attack,     ids = { 0x242 } },
		{ startup = true,  names = { "CA 立A" },                            type = act_types.attack,     ids = { 0x243 } },
		{ startup = true,  names = { "CA 屈A" },                            type = act_types.attack,     ids = { 0x244 } },
		{ startup = true,  names = { "CA 屈A" },                            type = act_types.attack,     ids = { 0x245 } },
		{ startup = true,  names = { "CA 屈A" },                            type = act_types.attack,     ids = { 0x247 } },
		{ startup = true,  names = { "CA 立C" },                            type = act_types.attack,     ids = { 0x24C } },
		{ startup = true,  names = { "CA 立B" },                            type = act_types.attack,     ids = { 0x24D } },
		{ startup = true,  names = { "CA 立C" },                            type = act_types.attack,     ids = { 0x24A } },
		{ startup = true,  names = { "CA 立A" },                            type = act_types.attack,     ids = { 0x24B } },
		{ startup = true,  names = { "アッチョンブリケ" },           type = act_types.provoke,    ids = { 0x283 } },
		{ startup = true,  names = { "CA 立B" },                            type = act_types.attack,     ids = { 0x246 } },
		{ startup = true,  names = { "CA 屈B" },                            type = act_types.low_attack, ids = { 0x24E } },
		{ startup = true,  names = { "CA 立C" },                            type = act_types.overhead,   ids = { 0x249 } },
		{ startup = true,  names = { "CA _3C" },                             type = act_types.attack,     ids = { 0x250, 0x251 } },
		{ startup = true,  names = { "CA _3C" },                             type = act_types.any,        ids = { 0x252 } },
		{ startup = true,  names = { "CA 屈C" },                            type = act_types.low_attack, ids = { 0x287 } },
		{ startup = true,  names = { "CA _6_6+A" },                          type = act_types.any,        ids = { 0x24F } },
		{ startup = true,  names = { "CA _N_C" },                            type = act_types.any,        ids = { 0x284, 0x285, 0x286 } },
	},
	-- アルフレッド
	{
		{ startup = true,  names = { "近 対メインライン威力大攻撃" },                                  type = act_types.attack,   ids = { 0x62, 0x63, 0x64 } },
		{ startup = true,  names = { "遠 対メインライン威力大攻撃" },                                  type = act_types.attack,   ids = { 0x25A, 0x25B, 0x25C } },
		{ startup = true,  names = { "近立C" },                                           type = act_types.attack,   ids = { 0x43 } },
		{ startup = true,  names = { "遠立B" },                                           type = act_types.attack,   ids = { 0x45 } },
		{ startup = true,  names = { "遠立C" },                                           type = act_types.attack,   ids = { 0x46 } },
		{ startup = true,  names = { "屈A" },                                              type = act_types.attack,   ids = { 0x47 } },
		{ startup = true,  names = { "フェイント クリティカルウィング" },    type = act_types.any,      ids = { 0x112 } },
		{ startup = true,  names = { "フェイント オーグメンターウィング" }, type = act_types.any,      ids = { 0x113 } },
		{ startup = true,  names = { "バスタソニックウィング" },                 type = act_types.any,      ids = { 0x6D, 0x6E } },
		{ startup = true,  names = { "フロントステップキック" },                 type = act_types.attack,   ids = { 0x68 } },
		{ startup = true,  names = { "飛び退きキック" },                             type = act_types.attack,   ids = { 0x78 } },
		{ startup = true,  names = { "フォッカー" },                                   type = act_types.overhead, ids = { 0x69 } },
		{ startup = false, names = { "フォッカー" },                                   type = act_types.any,      ids = { 0x79 } },
		{ startup = true,  names = { "小 クリティカルウィング" },                type = act_types.attack,   ids = { 0x86, 0x87, 0x88 } },
		{ startup = false, names = { "小 クリティカルウィング" },                type = act_types.any,      ids = { 0x89 } },
		{ startup = true,  names = { "大 クリティカルウィング" },                type = act_types.attack,   ids = { 0x90, 0x91, 0x92 } },
		{ startup = false, names = { "大 クリティカルウィング" },                type = act_types.any,      ids = { 0x93 } },
		{ startup = true,  names = { "オーグメンターウィング" },                 type = act_types.attack,   ids = { 0x9A, 0x9B } },
		{ startup = false, names = { "オーグメンターウィング" },                 type = act_types.any,      ids = { 0x9C, 0x9D } },
		{ startup = true,  names = { "ダイバージェンス" },                          type = act_types.attack,   ids = { 0xA4, 0xA5 },                  firing = true },
		{ startup = true,  names = { "メーデーメーデー1" },                         type = act_types.overhead, ids = { 0xB1 } },
		{ startup = true,  names = { "メーデーメーデー1 ヒット" },               type = act_types.overhead, ids = { 0xB2 } },
		{ startup = true,  names = { "メーデーメーデー2" },                         type = act_types.overhead, ids = { 0xB3 } },
		{ startup = true,  names = { "メーデーメーデー?" },                         type = act_types.overhead, ids = { 0xB4 } },
		{ startup = true,  names = { "メーデーメーデー3" },                         type = act_types.overhead, ids = { 0xB5 } },
		{ startup = true,  names = { "メーデーメーデー ヒット隙" },             type = act_types.any,      ids = { 0xB6 } },
		{ startup = true,  names = { "メーデーメーデー ヒット着地" },          type = act_types.any,      ids = { 0xB7 } },
		{ startup = true,  names = { "メーデーメーデー" },                          type = act_types.overhead, ids = { 0xAE, 0xAF } },
		{ startup = true,  names = { "メーデーメーデー 着地" },                   type = act_types.any,      ids = { 0xB0 } },
		{ startup = true,  names = { "S.TOL" },                                             type = act_types.attack,   ids = { 0xB8, 0xB9, 0xBA } },
		{ startup = true,  names = { "S.TOL ヒット" },                                   type = act_types.any,      ids = { 0xBB, 0xBC, 0xBD, 0xBE, 0xBF } },
		{ startup = true,  names = { "ショックストール" },                          type = act_types.attack,   ids = { 0xFE, 0xFF } },
		{ startup = true,  names = { "ショックストール 着地" },                   type = act_types.any,      ids = { 0x100, 0x101 } },
		{ startup = true,  names = { "ショックストール ヒット" },                type = act_types.attack,   ids = { 0x102, 0x103 } },
		{ startup = false, names = { "ショックストール ヒット" },                type = act_types.any,      ids = { 0x104, 0x105 } },
		{ startup = true,  names = { "ショックストール空中 ヒット" },          type = act_types.attack,   ids = { 0xF4, 0xF5 } },
		{ startup = false, names = { "ショックストール空中 ヒット" },          type = act_types.any,      ids = { 0xF6, 0xF7 } },
		{ startup = true,  names = { "ウェーブライダー" },                          type = act_types.attack,   ids = { 0x108, 0x109, 0x10A, 0x10B } },
		{ startup = false, names = { "ウェーブライダー" },                          type = act_types.any,      ids = { 0x10C } },
	},
	{
		-- 共通行動
		{ startup = true, names = { "立ち" },                      type = act_types.free, ids = { 0x1, 0x0, 0x23, 0x22, 0x3C } },
		{ startup = true, names = { "立ち振り向き" },          type = act_types.free, ids = { 0x1D } },
		{ startup = true, names = { "しゃがみ振り向き" },    type = act_types.free, ids = { 0x1E } },
		{ startup = true, names = { "振り向き中" },             type = act_types.free, ids = { 0x3D } },
		{ startup = true, names = { "しゃがみ振り向き中" }, type = act_types.free, ids = { 0x3E } },
		{ startup = true, names = { "しゃがみ" },                type = act_types.free, ids = { 0x4, 0x24, 0x25 } },
		{ startup = true, names = { "しゃがみ途中" },          type = act_types.free, ids = { 0x5 } },
		{ startup = true, names = { "立ち途中" },                type = act_types.free, ids = { 0x6 } },
		{ startup = true, names = { "前歩き" },                   type = act_types.free, ids = { 0x2 } },
		{ startup = true, names = { "後歩き" },                   type = act_types.free, ids = { 0x3 } },
		{ startup = true, names = { "しゃがみ歩き" },          type = act_types.free, ids = { 0x7 } },
		{ startup = true, names = { "立ち" },                      type = act_types.free, ids = { 0x21, 0x40, 0x20, 0x3F } },
		{ startup = true, names = { "前歩き" },                   type = act_types.free, ids = { 0x2D, 0x2C } },
		{ startup = true, names = { "後歩き" },                   type = act_types.free, ids = { 0x2E, 0x2F } },
		{
			startup = false,
			names = { "ジャンプ", "アンリミテッドデザイア", "ギガティックサイクロン" },
			type = act_types.any,
			ids = {
				0xB, 0xC, -- 垂直ジャンプ
				0xD, 0xE, -- 前ジャンプ
				0xF, 0x10, -- 後ジャンプ
				0xB, 0x11, 0x12, -- 垂直小ジャンプ
				0xD, 0x13, 0x14, -- 前小ジャンプ
				0xF, 0x15, 0x16, -- 後小ジャンプ
			}
		},
		{ startup = true, names = { "空中ガード後" },                    type = act_types.free,  ids = { 0x12F } },
		{ startup = true, names = { "ダウン" },                             type = act_types.any,   ids = { 0x18E, 0x192, 0x190 } },
		{ startup = true, names = { "気絶" },                                type = act_types.any,   ids = { 0x194, 0x195 } },
		{ startup = true, names = { "ガード" },                             type = act_types.block, ids = { 0x117, 0x118, 0x119, 0x11A, 0x11B, 0x11C, 0x11D, 0x11E, 0x11F, 0x120, 0x121, 0x122, 0x123, 0x124, 0x125, 0x126, 0x127, 0x128, 0x129, 0x12A, 0x12B, 0x12C, 0x12C, 0x12D, 0x12E, 0x131, 0x132, 0x133, 0x134, 0x135, 0x136, 0x137, 0x139 } },
		{ startup = true, names = { "やられ" },                             type = act_types.hit,   ids = { 0x13F, 0x140, 0x141, 0x142, 0x143, 0x144, 0x145, 0x146, 0x147, 0x148, 0x149, 0x14A, 0x14B, 0x14C, 0x14C, 0x14D, 0x14E, 0x14F, 0x151, 0x1E9, 0x239 } },
		{ startup = true, names = { "ダッシュ" },                          type = act_types.any,   ids = { 0x17, 0x18, 0x19 } },
		{ startup = true, names = { "飛び退き" },                          type = act_types.any,   ids = { 0x1A, 0x1B, 0x1C } },
		{ startup = true, names = { "立スウェー移動" },                 type = act_types.any,   ids = { 0x26, 0x27, 0x28 } },
		{ startup = true, names = { "屈スウェー移動" },                 type = act_types.any,   ids = { 0x29, 0x2A, 0x2B } },
		-- { startup = true, names = {"スウェー戻り",
		{ startup = true, names = { "クイックロール" },                 type = act_types.any,   ids = { 0x39, 0x3A, 0x3B } },
		{ startup = true, names = { "スウェーライン上 ダッシュ" }, type = act_types.any,   ids = { 0x30, 0x31, 0x32 } },
		{ startup = true, names = { "スウェーライン上 飛び退き" }, type = act_types.any,   ids = { 0x33, 0x34, 0x35 } },
		{
			startup = false,
			names = { "スウェー戻り", "ダッシュ", "スウェーライン上 ダッシュ",
				"飛び退き", "スウェーライン上 飛び退き" },
			type = act_types.any,
			ids = { 0x37, 0x38 }
		},
		{
			startup = false,
			names = { "スウェー振り向き移動", "ダッシュ", "スウェーライン上 ダッシュ",
				"飛び退き", "スウェーライン上 飛び退き" },
			type = act_types.any,
			ids = { 0x2BC, 0x2BD }
		},
		{ startup = true, names = { "近 対メインライン上段攻撃" },                     type = act_types.overhead,   ids = { 0x5C, 0x5D, 0x5E } },
		{ startup = true, names = { "近 対メインライン下段攻撃" },                     type = act_types.low_attack, ids = { 0x5F, 0x60, 0x61 } },
		-- { startup = true, names = {"近 対メインライン威力大攻撃",
		{ startup = true, names = { "遠 対メインライン上段攻撃" },                     type = act_types.overhead,   ids = { 0x254, 0x255, 0x256 } },
		{ startup = true, names = { "遠 対メインライン下段攻撃" },                     type = act_types.low_attack, ids = { 0x257, 0x258, 0x259 } },
		{ startup = true, names = { "遠 対メインライン威力大攻撃" },                     type = act_types.attack,     ids = { 0x25A, 0x25B, 0x25C } },
		-- { startup = true, names = { "遠 対メインライン威力大攻撃",
		{ startup = true, names = { "ジャンプ移行" },                   type = act_types.any,        ids = { 0x8 } },
		{ startup = true, names = { "着地", "やられ" },                  type = act_types.any,        ids = { 0x9 } },
		{ startup = true, names = { "グランドスウェー" },             type = act_types.any,        ids = { 0x13C, 0x13D, 0x13E } },
		{ startup = true, names = { "テクニカルライズ" },             type = act_types.any,        ids = { 0x2CA, 0x2C8, 0x2C9 } },
		{ startup = true, names = { "避け攻撃" },                         type = act_types.attack,     ids = { 0x67 } },
		{ startup = true, names = { "近立A" },                              type = act_types.attack,     ids = { 0x41 } },
		{ startup = true, names = { "近立B" },                              type = act_types.attack,     ids = { 0x42 } },
		-- { startup = true, names = {"近立C",
		{ startup = true, names = { "遠立A" },                              type = act_types.attack,     ids = { 0x44 } },
		-- { startup = true, names = {"立B",
		-- { startup = true, names = {"立C",
		{ startup = true, names = { "対スウェーライン上段攻撃" }, type = act_types.overhead,   ids = { 0x65 } },
		-- { startup = true, names = {"屈A",
		{ startup = true, names = { "屈B" },                                 type = act_types.low_attack, ids = { 0x48 } },
		{ startup = true, names = { "屈C" },                                 type = act_types.low_attack, ids = { 0x49 } },
		{ startup = true, names = { "対スウェーライン下段攻撃" }, type = act_types.low_attack, ids = { 0x66 } },
		{ startup = true, names = { "着地", "着地(小攻撃後1)" },      type = act_types.any,        ids = { 0x56 } },
		{ startup = true, names = { "着地", "着地(小攻撃後2)" },      type = act_types.any,        ids = { 0x59 } },
		{ startup = true, names = { "着地", "着地(大攻撃後3)" },      type = act_types.any,        ids = { 0x57 } },
		{ startup = true, names = { "着地", "着地(大攻撃後4)" },      type = act_types.any,        ids = { 0x5A } },
		{ startup = true, names = { "垂直ジャンプA" },                  type = act_types.overhead,   ids = { 0x4A } },
		{ startup = true, names = { "垂直ジャンプB" },                  type = act_types.overhead,   ids = { 0x4B } },
		{ startup = true, names = { "垂直ジャンプC" },                  type = act_types.overhead,   ids = { 0x4C } },
		{ startup = true, names = { "ジャンプ振り向き" },             type = act_types.any,        ids = { 0x1F } },
		{ startup = true, names = { "斜めジャンプA" },                  type = act_types.overhead,   ids = { 0x4D } },
		{ startup = true, names = { "斜めジャンプB" },                  type = act_types.overhead,   ids = { 0x4E } },
		{ startup = true, names = { "斜めジャンプC" },                  type = act_types.overhead,   ids = { 0x4F } },
		{ startup = true, names = { "垂直小ジャンプA" },               type = act_types.overhead,   ids = { 0x50 } },
		{ startup = true, names = { "垂直小ジャンプB" },               type = act_types.overhead,   ids = { 0x51 } },
		{ startup = true, names = { "垂直小ジャンプC" },               type = act_types.overhead,   ids = { 0x52 } },
		{ startup = true, names = { "斜め小ジャンプA" },               type = act_types.overhead,   ids = { 0x53 } },
		{ startup = true, names = { "斜め小ジャンプB" },               type = act_types.overhead,   ids = { 0x54 } },
		{ startup = true, names = { "斜め小ジャンプC" },               type = act_types.overhead,   ids = { 0x55 } },
		{ startup = true, names = { "挑発" },                               type = act_types.provoke,    ids = { 0x196 } },
		{ startup = true, names = { "おきあがり" },                      type = act_types.any,        ids = { 0x193, 0x13B, 0x2C7 } },
	},
}
local char_fireball_base = {
	-- テリー・ボガード
	{
		{ names = { "パワーウェイブ" }, type = act_types.attack, ids = { 0x265, 0x266, 0x26A, }, },
		{ names = { "ラウンドウェイブ" }, type = act_types.low_attack, ids = { 0x260, }, },
		{ names = { "パワーゲイザー" }, type = act_types.attack, ids = { 0x261, }, },
		{ names = { "トリプルゲイザー" }, type = act_types.attack, ids = { 0x267, }, },
	},
	-- アンディ・ボガード
	{
		{ names = { "飛翔拳" }, type = act_types.attack, ids = { 0x262, 0x263, }, },
		{ names = { "激飛翔拳" }, type = act_types.attack, ids = { 0x266, 0x267, }, },
	},
	-- 東丈
	{
		{ names = { "ハリケーンアッパー" }, type = act_types.attack, ids = { 0x266, 0x267, 0x269, }, },
		{ names = { "スクリューアッパー" }, type = act_types.attack, ids = { 0x269, 0x26A, 0x26B, }, },
	},
	-- 不知火舞
	{
		{ names = { "花蝶扇" }, type = act_types.attack, ids = { 0x261, 0x262, 0x263, }, },
		{ names = { "龍炎舞" }, type = act_types.attack, ids = { 0x264, }, },
	},
	-- ギース・ハワード
	{
		{ names = { "烈風拳" }, type = act_types.attack, ids = { 0x261, 0x260, 0x276, }, },
		{ names = { "ダブル烈風拳" }, type = act_types.attack, ids = { 0x262, 0x263, 0x264, 0x265, }, },
		{ names = { "レイジングストーム" }, type = act_types.attack, ids = { 0x269, 0x26B, 0x26A, }, },
	},
	-- 望月双角,
	{
		{ names = { "雷撃棍" }, type = act_types.attack, ids = { 0x260, }, },
		{ names = { "野猿狩り/掴み" }, type = act_types.attack, ids = { 0x277, 0x27C, }, },
		{ names = { "まきびし" }, type = act_types.low_attack, ids = { 0x274, 0x275, }, },
		{ names = { "憑依弾" }, type = act_types.attack, ids = { 0x263, 0x266, }, },
		{ names = { "邪棍舞" }, type = act_types.attack, ids = { 0xF4, 0xF5, }, },
		{ names = { "天破" }, type = act_types.attack, ids = { 0xF6, }, },
		{ names = { "払破" }, type = act_types.low_attack, ids = { 0xF7, }, },
		{ names = { "倒破" }, type = act_types.overhead, ids = { 0xF8, }, },
		{ names = { "降破" }, type = act_types.overhead, ids = { 0xF9, }, },
		{ names = { "突破" }, type = act_types.attack, ids = { 0xFA, }, },
		{ names = { "喝" }, type = act_types.attack, ids = { 0x282, 0x283, }, },
		{ names = { "いかづち" }, type = act_types.attack, ids = { 0x286, 0x287, }, },
	},
	-- ボブ・ウィルソン
	{
	},
	-- ホンフゥ
	{
		{ names = { "よかトンハンマー" }, type = act_types.attack, ids = { 0x26B, }, },
	},
	-- ブルー・マリー
	{
	},
	-- フランコ・バッシュ
	{
		{ names = { "ザッパー" }, type = act_types.attack, ids = { 0x269, }, },
		{ names = { "ファイナルオメガショット" }, type = act_types.attack, ids = { 0x26C, }, },
	},
	-- 山崎竜二
	{
		{ names = { "目ツブシ" }, type = act_types.attack, ids = { 0x261, }, },
		{ names = { "倍返し" }, type = act_types.attack, ids = { 0x262, 0x263, 0x270, 0x26D, }, },
	},
	-- 秦崇秀
	{
		{ names = { "帝王天眼拳" }, type = act_types.attack, ids = { 0x262, 0x263, 0x265, }, },
		{ names = { "海龍照臨" }, type = act_types.attack, ids = { 0x273, 0x274, }, },
		{ names = { "帝王漏尽拳" }, type = act_types.attack, ids = { 0x26C, }, },
		{ names = { "帝王空殺漏尽拳" }, type = act_types.low_attack, ids = { 0x26F, }, },
	},
	-- 秦崇雷,
	{
		{ names = { "帝王漏尽拳" }, type = act_types.attack, ids = { 0x266, }, },
		{ names = { "帝王天眼拳" }, type = act_types.attack, ids = { 0x26E, }, },
		{ names = { "帝王宿命拳" }, type = act_types.attack, ids = { 0x268, 0x273, }, },
		{ names = { "帝王龍声拳" }, type = act_types.attack, ids = { 0x26B, }, },
	},
	-- ダック・キング
	{
	},
	-- キム・カッファン
	{
	},
	-- ビリー・カーン
	{
		{ names = { "三節棍中段打ち" }, type = act_types.attack, ids = { 0x266, }, },
		{ names = { "火炎三節棍中段突き" }, type = act_types.attack, ids = { 0x267, }, },
		{ names = { "旋風棍" }, type = act_types.attack, ids = { 0x269, }, },
		{ names = { "超火炎旋風棍" }, type = act_types.attack, ids = { 0x261, 0x263, 0x262, }, },
		{ names = { "サラマンダーストリーム" }, type = act_types.attack, ids = { 0x27A, 0x278, }, },
	},
	-- チン・シンザン
	{
		{ names = { "気雷砲" }, type = act_types.low_attack, ids = { 0x267, 0x268, 0x26E, }, },
		{ names = { "爆雷砲" }, type = act_types.attack, ids = { 0x287, 0x272, 0x273, }, },
		{ names = { "ホエホエ弾" }, type = act_types.low_attack, ids = { 0x280, 0x281, 0x27E, 0x27F, }, },
		{ names = { "クッサメ砲" }, type = act_types.low_attack, ids = { 0x282, }, },
	},
	-- タン・フー・ルー,
	{
		{ names = { "衝波" }, type = act_types.attack, ids = { 0x265, }, },
	},
	-- ローレンス・ブラッド
	{
		{ names = { "ブラッディサーベル" }, type = act_types.attack, ids = { 0x282, }, },
		{ names = { "ブラッディミキサー" }, type = act_types.attack, ids = { 0x284, }, },
	},
	-- ヴォルフガング・クラウザー
	{
		{ names = { "小 ブリッツボール" }, type = act_types.attack, ids = { 0x263, 0x262, }, },
		{ names = { "大 ブリッツボール" }, type = act_types.low_attack, ids = { 0x263, 0x266 }, },
		{ names = { "カイザーウェイブ1" }, type = act_types.attack, ids = { 0x26E, 0x26F, }, },
		{ names = { "カイザーウェイブ2" }, type = act_types.attack, ids = { 0x282, 0x270, }, },
		{ names = { "カイザーウェイブ3" }, type = act_types.attack, ids = { 0x283, 0x271, }, },
	},
	-- リック・ストラウド
	{
		{ names = { "ガイアブレス" }, type = act_types.attack, ids = { 0x261, }, },
		{ names = { "ハウリング・ブル" }, type = act_types.low_attack, ids = { 0x26A, 0x26B, 0x267, }, },
	},
	-- 李香緋
	{
		{ names = { "小 那夢波" }, type = act_types.attack, ids = { 0x263, }, },
		{ names = { "大 那夢波" }, type = act_types.attack, ids = { 0x268, }, },
		{ names = { "真心牙" }, type = act_types.attack, ids = { 0x270, }, },
	},
	-- アルフレッド
	{
		{ names = { "ダイバージェンス" }, type = act_types.attack, ids = { 0x264, }, },
	},
}
for char, acts_base in pairs(char_acts_base) do
	-- キャラごとのテーブル作成
	local char_data = chars[char]
	for _, acts in pairs(acts_base) do
		acts.name = acts.name or acts.names[1]
		acts.normal_name = acts.name
		acts.slide_name = "滑り " .. acts.name
		acts.bs_name = "BS " .. acts.name
		local temp_names = acts.names
		acts.names = {}
		for _, name in ipairs(temp_names) do
			table.insert(acts.names, name)
			table.insert(acts.names, "滑り " .. name)
			table.insert(acts.names, "BS " .. name)
		end
		for i, id in ipairs(acts.ids) do
			if i == 1 then
				acts.id_1st = id
				if acts.type ~= act_types.block and acts.type ~= act_types.hit and
					acts.name ~= "振り向き中" and acts.name ~= "しゃがみ振り向き中" and 
					acts.startup then
					char_data.act1sts[id] = true
				end
			end
			char_data.acts[id] = acts
		end
	end
end
for char = 1, #chars - 1 do
	for id, acts in pairs(chars[#chars].acts) do
		chars[char].acts[id] = acts
	end
	for id, st1 in pairs(chars[#chars].act1sts) do
		chars[char].act1sts[id] = st1
	end
end
for char, fireballs_base in pairs(char_fireball_base) do
	chars[char].fireballs = {}
	for _, fireball in pairs(fireballs_base) do
		fireball.name = fireball.name or fireball.names[1]
		for _, id in pairs(fireball.ids) do
			chars[char].fireballs[id] = fireball
		end
	end
end
local jump_acts = new_set(0x9, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16)
local wakeup_acts = new_set(0x193, 0x13B)
local input_state_types = {
	step = 1,
	faint = 2,
	charge = 3,
	unknown = 4,
	followup = 5,
	shinsoku = 6,
	todome = 7,
	drill5 = 8,
}
local create_input_states = function()
	local _1236b = "_1|_2|_3|_6|_B"
	local _16a = "_1|_6|_A"
	local _16b = "_1|_6|_B"
	local _16c = "_1|_6|_C"
	local _1chg26bc = "_1|^1|_2||_6|_B+_C"
	local _1chg6b = "_1|^1|_6|_B"
	local _1chg6c = "_1|^1|_6|_C"
	local _21416bc = "_2|_1|_4|_1|_6|_B+_C"
	local _21416c = "_2|_1|_4|_1|_6|_C"
	local _2146bc = "_2|_1|_4|_6|_B+_C"
	local _2146c = "_2|_1|_4|_6|_C"
	local _214a = "_2|_1|_4|_A"
	local _214b = "_2|_1|_4|_B"
	local _214bc = "_2|_1|_4|_B+_C"
	local _214c = "_2|_1|_4|_C"
	local _214d = "_2|_1|_4|_D"
	local _22 = "_2|_N|_2"
	local _22a = "_2|_N|_2|_A"
	local _22b = "_2|_N|_2|_B"
	local _22c = "_2|_N|_2|_C"
	local _22d = "_2|_N|_2|_D"
	local _2369b = "_2|_3|_6|_9|_B"
	local _236a = "_2|_3|_6|_A"
	local _236b = "_2|_3|_6|_B"
	local _236bc = "_2|_3|_6|_B+_C"
	local _236c = "_2|_3|_6|_C"
	local _236d = "_2|_3|_6|_D"
	local _2486a = "_2|_4|_8|_6|_A"
	local _2486bc = "_2|_4|_8|_6|_B+_C"
	local _2486c = "_2|_4|_8|_6|_C"
	local _2684a = "_2|_6|_8|_4|_A"
	local _2684bc = "_2|_6|_8|_4|_B+_C"
	local _2684c = "_2|_6|_8|_4|_C"
	local _2a = "_2|_A"
	local _2ab = "_2||_A+_B"
	local _2ac = "_2|_A+_C"
	local _2b = "_2||_B"
	local _2bc = "_2|_B+_C"
	local _2c = "_2||_C"
	local _2chg7b = "_2|^2|_7|_B"
	local _2chg8a = "_2|^2|_8|_A"
	local _2chg8b = "_2|^2|_8|_B"
	local _2chg8c = "_2|^2|_8|_C"
	local _2chg9b = "_2|^2|_9|_B"
	local _33b = "_3|_N|_3|_B"
	local _33c = "_3|_N|_3|_C"
	local _3b = "_3|_B"
	local _35c = "_3|_N|_C"
	local _412c = "_4|_1|_2|_C"
	local _41236a = "_4|_1|_2|_3|_6|_A"
	local _41236b = "_4|_1|_2|_3|_6|_B"
	local _41236bc = "_4|_1|_2|_3|_6|_B+_C"
	local _41236c = "_4|_1|_2|_3|_6|_C"
	local _421ac = "_4|_2|_1|_A+_C"
	local _4268a = "_4|_2|_6|_8|_A"
	local _4268bc = "_4|_2|_6|_8|_B+_C"
	local _4268c = "_4|_2|_6|_8|_C"
	local _44 = "_4|_N|_4"
	local _466bc = "_4|_6|_N|_6|_B+_C"
	local _46b = "_4|_6|_B"
	local _46c = "_4|_6|_C"
	local _4862a = "_4|_8|_6|_2|_A"
	local _4862bc = "_4|_8|_6|_2|_B+_C"
	local _4862c = "_4|_8|_6|_2|_C"
	local _4ac = "_4|_A+_C"
	local _4chg6a = "_4|^4|_6|_A"
	local _4chg6b = "_4|^4|_6|_B"
	local _4chg6bc = "_4|^4|_6|_B+_C"
	local _4chg6c = "_4|^4|_6|_C"
	local _616ab = "_6|_1|_6|_A+_B"
	local _623a = "_6|_2|_3|_A"
	local _623ab = "_6|_2|_3|_A+_B"
	local _623b = "_6|_2|_3|_B"
	local _623bc = "_6|_2|_3|_B+_C"
	local _623c = "_6|_2|_3|_C"
	local _6248a = "_6|_2|_4|_8|_A"
	local _6248bc = "_6|_2|_4|_8|_B+_C"
	local _6248c = "_6|_2|_4|_8|_C"
	local _632146a = "_6|_3|_2|_1|_4|_6|_A"
	local _63214a = "_6|_3|_2|_1|_4|_A"
	local _63214b = "_6|_3|_2|_1|_4|_B"
	local _63214bc = "_6|_3|_2|_1|_4|_B+_C"
	local _63214c = "_6|_3|_2|_1|_4|_C"
	local _632c = "_6|_3|_2|_C"
	local _64123bc = "_6|_4|_1|_2|_3|_B+_C"
	local _64123c = "_6|_4|_1|_2|_3|_C"
	local _64123d = "_6|_4|_1|_2|_3|_D"
	local _6428c = "_6|_4|_2|_8|_C"
	local _646c = "_6|_4|_6|_C"
	local _64c = "_6|_4|_C"
	local _66 = "_6|_N|_6"
	local _666a = "_6|_N|_6|_N|_6|_A"
	local _66a = "_6|_N|_6|_A"
	local _666c = "_6|_N|_6|_N|_6|_C"
	local _6842a = "_6|_8|_4|_2|_A"
	local _6842bc = "_6|_8|_4|_2|_B+_C"
	local _6842c = "_6|_8|_4|_2|_C"
	local _698b = "_6|_9|_8|_B"
	local _6ac = "_6|_A+_C"
	local _82d = "_8|_2|_D"
	local _8426a = "_8|_4|_2|_6|_A"
	local _8426bc = "_8|_4|_2|_6|_B+_C"
	local _8426c = "_8|_4|_2|_6|_C"
	local _8624a = "_8|_6|_2|_4|_A"
	local _8624bc = "_8|_6|_2|_4|_B+_C"
	local _8624c = "_8|_6|_2|_4|_C"
	local _8c = "_8||_C"
	local _a2 = "_A||_2"
	local _a6 = "_A||_6"
	local _a8 = "_A||_8"
	local _aa = "_A|_A"
	local _aaaa = "_A|_A|_A|_A"
	local _bbb = "_B|_B|_B"
	local _bbbb = "_B|_B|_B|_B"
	local _bbbbbb = "_B|_B|_B|_B|_B|_B"
	local _bbbbbbbb = "_B|_B|_B|_B|_B|_B|_B|_B"
	local _cc = "_C|_C||"
	local _ccc = "_C|_C|_C"
	local _cccc = "_C|_C|_C|_C"
	local _46a = "_4|_6|_A"
	local _412d = "_4|_1|_2|_D"
	local _44b = "_4|_N|_4|_B"
	local _44d = "_4|_N|_4|_D"
	local _abc = "_A+_B+_C"
	local _6b = "_6|_B"
	local _6c = "_6|_C"

	local input_states = {
		{ --テリー・ボガード 11
			{ addr = 0x02, estab = 0x010600, cmd = _214a, name = "小バーンナックル", },
			{ addr = 0x06, estab = 0x020600, cmd = _214c, name = "大バーンナックル", },
			{ addr = 0x0A, estab = 0x030600, cmd = _236a, name = "パワーウェイブ", },
			{ addr = 0x0E, estab = 0x040600, cmd = _236c, name = "ラウンドウェイブ", },
			{ addr = 0x12, estab = 0x050600, cmd = _214b, name = "クラックシュート", },
			{ addr = 0x16, estab = 0x060600, cmd = _236b, name = "ファイヤーキック", },
			{ addr = 0x1A, estab = 0x070600, cmd = _236d, name = "パッシングスウェー", },
			{ addr = 0x1E, estab = 0x0600FF, cmd = _2chg8a, type = input_state_types.charge, name = "ライジングタックル", },
			{ addr = 0x22, estab = 0x100600, cmd = _21416bc, sdm = "a", name = "パワーゲイザー", },
			{ addr = 0x26, estab = 0x120600, cmd = _21416c, sdm = "c", name = "トリプルゲイザー", },
			{ addr = 0x2A, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x2E, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x32, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x36, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x3A, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x3E, estab = 0x460600, cmd = _6ac, type = input_state_types.faint, name = "フェイントバーンナックル", },
			{ addr = 0x42, estab = 0x470600, cmd = _2bc, type = input_state_types.faint, name = "フェイントパワーゲイザー", },
		},
		{ --アンディ・ボガード
			{ addr = 0x02, estab = 0x010600, cmd = _16a, name = "小残影拳", },
			{ addr = 0x06, estab = 0x020600, cmd = _16c, name = "大残影拳 or 疾風裏拳", },
			{ addr = 0x0A, estab = 0x030600, cmd = _214a, name = "飛翔拳", },
			{ addr = 0x0E, estab = 0x040600, cmd = _214c, name = "激飛翔拳", },
			{ addr = 0x12, estab = 0x050600, cmd = _623c, name = "昇龍弾", },
			{ addr = 0x16, estab = 0x060600, cmd = _1236b, name = "空破弾", },
			{ addr = 0x1A, estab = 0x071200, cmd = _214d, name = "幻影不知火", },
			{ addr = 0x1E, estab = 0x100600, cmd = _21416bc, sdm = "a", name = "超裂破弾", },
			{ addr = 0x22, estab = 0x120600, cmd = _21416c, sdm = "c", name = "男打弾", },
			{ addr = 0x26, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x2A, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x2E, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x32, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x36, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x3A, estab = 0x460600, cmd = _6ac, type = input_state_types.faint, name = "フェイント斬影拳", },
			{ addr = 0x3E, estab = 0x470600, cmd = _2ac, type = input_state_types.faint, name = "フェイント飛翔拳", },
			{ addr = 0x42, estab = 0x480600, cmd = _2bc, type = input_state_types.faint, name = "フェイント超裂破弾", },
		},
		{ --東丈
			{ addr = 0x02, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x06, estab = 0x010600, cmd = _16b, name = "小スラッシュキック", },
			{ addr = 0x0A, estab = 0x020600, cmd = _16c, name = "大スラッシュキック", },
			{ addr = 0x0E, estab = 0x030600, cmd = _214b, name = "黄金のカカト", },
			{ addr = 0x12, estab = 0x040600, cmd = _623b, name = "タイガーキック", },
			{ addr = 0x16, estab = 0x050C00, cmd = _aaaa, name = "爆裂拳", },
			{ addr = 0x1A, estab = 0x000CFF, cmd = _236a, name = "爆裂フック", },
			{ addr = 0x1E, estab = 0x000CFE, cmd = _236c, name = "爆裂アッパー", },
			{ addr = 0x22, estab = 0x060600, cmd = _41236a, name = "ハリケーンアッパー", },
			{ addr = 0x26, estab = 0x070600, cmd = _41236c, name = "爆裂ハリケーン", },
			{ addr = 0x2A, estab = 0x100600, cmd = _64123bc, sdm = "a", name = "スクリューアッパー", },
			{ addr = 0x2E, estab = 0x120600, cmd = _64123c, sdm = "c", name = "サンダーファイヤーC", },
			{ addr = 0x32, estab = 0x130600, cmd = _64123d, sdm = "d", name = "サンダーファイヤーD", },
			{ addr = 0x36, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x3A, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x3E, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x42, estab = 0x210600, cmd = _2c, type = input_state_types.faint, name = "炎の指先", },
			{ addr = 0x46, estab = 0x280600, cmd = _236c, name = "CA _2_3_6+_C", },
			{ addr = 0x4A, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x4E, estab = 0x460600, cmd = _2ac, type = input_state_types.faint, name = "フェイントハリケーンアッパー", },
			{ addr = 0x52, estab = 0x470600, cmd = _6ac, type = input_state_types.faint, name = "フェイントスラッシュキック", },
		},
		{ --不知火舞
			{ addr = 0x02, estab = 0x010600, cmd = _236a, name = "花蝶扇", },
			{ addr = 0x06, estab = 0x020600, cmd = _214a, name = "龍炎舞", },
			{ addr = 0x0A, estab = 0x030600, cmd = _214c, name = "小夜千鳥", },
			{ addr = 0x0E, estab = 0x040600, cmd = _41236c, name = "必殺忍蜂", },
			{ addr = 0x12, estab = 0x0600FF, cmd = _2ab, type = input_state_types.faint, name = "ムササビの舞", },
			{ addr = 0x16, estab = 0x100600, cmd = _64123bc, sdm = "a", name = "超必殺忍蜂", },
			{ addr = 0x1A, estab = 0x120600, cmd = _64123c, sdm = "c", name = "花嵐", },
			{ addr = 0x1E, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x22, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x26, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x2A, estab = 0x7800FF, cmd = _ccc, name = "跳ね蹴り", },
			{ addr = 0x2E, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x32, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x36, estab = 0x460600, cmd = _2ac, type = input_state_types.faint, name = "フェイント花蝶扇", },
			{ addr = 0x3A, estab = 0x470600, cmd = _2bc, type = input_state_types.faint, name = "フェイント花嵐", },
		},
		{ --ギース・ハワード
			{ addr = 0x02, estab = 0x210600, cmd = _2c, type = input_state_types.faint, name = "雷鳴豪破投げ", },
			{ addr = 0x06, estab = 0x010600, cmd = _214a, name = "烈風拳", },
			{ addr = 0x0A, estab = 0x0206FF, cmd = _214c, name = "ダブル烈風拳", },
			{ addr = 0x0E, estab = 0x030600, cmd = _41236b, name = "上段当身投げ", },
			{ addr = 0x12, estab = 0x0406FE, cmd = _41236c, name = "裏雲隠し", },
			{ addr = 0x16, estab = 0x050600, cmd = _41236a, name = "下段当身打ち", },
			{ addr = 0x1A, estab = 0x100600, cmd = _64123bc, sdm = "a", name = "レイジングストーム", },
			{ addr = nil, easy_addr = 0x1E, estab = nil, cmd = _22c, sdm = "c", name = "羅生門", },
			{ addr = 0x1E, easy_addr = 0x22, estab = 0x0706FD, cmd = _632146a, sdm = "d", name = "デッドリーレイブ", },
			{ addr = 0x22, easy_addr = 0x26, estab = 0x0706FD, cmd = _8624a, name = "真空投げ_8_6_2_4 or CA 真空投げ", },
			{ addr = 0x26, easy_addr = 0x2A, estab = 0x0706FD, cmd = _6248a, name = "真空投げ_6_2_4_8 or CA 真空投げ", },
			{ addr = 0x2A, easy_addr = 0x2E, estab = 0x0706FD, cmd = _2486a, name = "真空投げ_2_4_8_6 or CA 真空投げ", },
			{ addr = 0x2E, easy_addr = 0x32, estab = 0x0706FD, cmd = _4862a, name = "真空投げ_4_8_6_2 or CA 真空投げ", },
			{ addr = 0x32, easy_addr = 0x36, estab = 0x0706FD, cmd = _8426a, name = "真空投げ_8_4_2_6 or CA 真空投げ", },
			{ addr = 0x36, easy_addr = 0x3A, estab = 0x0706FD, cmd = _4268a, name = "真空投げ_4_2_6_8 or CA 真空投げ", },
			{ addr = 0x3A, easy_addr = 0x3E, estab = 0x0706FD, cmd = _2684a, name = "真空投げ_2_6_8_4 or CA 真空投げ", },
			{ addr = 0x3E, easy_addr = 0x42, estab = 0x0706FD, cmd = _6842a, name = "真空投げ_6_8_4_2 or CA 真空投げ", },
			{ addr = 0x42, estab = 0x120600, cmd = _8624c, sdm = "x", name = "羅生門_8_6_2_4", },
			{ addr = 0x46, estab = 0x120600, cmd = _6248c, sdm = "x", name = "羅生門_6_2_4_8", },
			{ addr = 0x4A, estab = 0x120600, cmd = _2486c, sdm = "x", name = "羅生門_2_4_8_6", },
			{ addr = 0x4E, estab = 0x120600, cmd = _4862c, sdm = "x", name = "羅生門_4_8_6_2", },
			{ addr = 0x52, estab = 0x120600, cmd = _8426c, sdm = "x", name = "羅生門_8_4_2_6", },
			{ addr = 0x56, estab = 0x120600, cmd = _4268c, sdm = "x", name = "羅生門_4_2_6_8", },
			{ addr = 0x5A, estab = 0x120600, cmd = _2684c, sdm = "x", name = "羅生門_2_6_8_4", },
			{ addr = 0x5E, estab = 0x120600, cmd = _6842c, sdm = "x", name = "羅生門_6_8_4_2", },
			{ addr = 0x62, easy_addr = 0x46, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x66, easy_addr = 0x4A, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x6A, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x6E, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x72, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x76, easy_addr = 0x4E, estab = 0x500600, cmd = _632c, name = "絶命人中打ち", },
			{ addr = 0x7A, estab = 0x510600, cmd = _412c, sdm = "x", name = "絶命人中打ち", },
			{ addr = 0x7E, easy_addr = 0x52, estab = 0x460600, cmd = _2ac, type = input_state_types.faint, name = "フェイント烈風拳", },
			{ addr = 0x82, easy_addr = 0x56, estab = 0x470600, cmd = _2bc, type = input_state_types.faint, name = "フェイントレイジングストーム", },
		},
		{ --望月双角
			{ addr = 0x02, estab = 0x010600, cmd = _214a, name = "野猿狩り", },
			{ addr = 0x06, estab = 0x020600, cmd = _236a, name = "まきびし", },
			{ addr = 0x0A, estab = 0x030600, cmd = _646c, name = "憑依弾", },
			{ addr = 0x0E, estab = 0x050CFF, cmd = _aaaa, name = "邪棍舞", },
			{ addr = 0x12, estab = 0x060600, cmd = _63214b, name = "喝", },
			{ addr = 0x16, estab = 0x070600, cmd = _82d, name = "禍炎陣", },
			{ addr = 0x1A, estab = 0x100600, cmd = _64123bc, sdm = "a", name = "いかづち", },
			{ addr = 0x1E, estab = 0x120600, cmd = _64123c, sdm = "c", name = "無残弾", },
			{ addr = 0x22, estab = 0x0406FE, cmd = _8624c, name = "鬼門陣_8_6_2_4 or 喝CAの投げ", },
			{ addr = 0x26, estab = 0x0406FE, cmd = _6248c, name = "鬼門陣_6_2_4_8 or 喝CAの投げ", },
			{ addr = 0x2A, estab = 0x0406FE, cmd = _2486c, name = "鬼門陣_2_4_8_6 or 喝CAの投げ", },
			{ addr = 0x2E, estab = 0x0406FE, cmd = _4862c, name = "鬼門陣_4_8_6_2 or 喝CAの投げ", },
			{ addr = 0x32, estab = 0x0406FE, cmd = _8426c, name = "鬼門陣_8_4_2_6 or 喝CAの投げ", },
			{ addr = 0x36, estab = 0x0406FE, cmd = _4268c, name = "鬼門陣_4_2_6_8 or 喝CAの投げ", },
			{ addr = 0x3A, estab = 0x0406FE, cmd = _2684c, name = "鬼門陣_2_6_8_4 or 喝CAの投げ", },
			{ addr = 0x3E, estab = 0x0406FE, cmd = _6842c, name = "鬼門陣_6_8_4_2 or 喝CAの投げ", },
			{ addr = 0x42, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x46, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "バックダッシュ", },
			{ addr = 0x4A, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x4E, estab = 0x210600, cmd = _2c, type = input_state_types.faint, name = "雷撃棍", },
			{ addr = 0x52, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x56, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x5A, estab = 0x500600, cmd = _632c, name = "地獄門", },
			{ addr = 0x5E, estab = 0x510600, cmd = _412c, name = "地獄門", },
			{ addr = 0x62, estab = 0x280600, cmd = _623a, name = "CA _6_2_3+_A", },
			{ addr = 0x66, estab = 0x290600, cmd = _22c, type = input_state_types.todome, name = "CA _2_2+_C", },
			{ addr = 0x6A, estab = 0x460600, cmd = _2ac, type = input_state_types.faint, name = "フェイントまきびし", },
			{ addr = 0x6E, estab = 0x470600, cmd = _2bc, type = input_state_types.faint, name = "フェイントいかづち", },
		},
		{ --ボブ・ウィルソン
			{ addr = 0x02, estab = 0x010600, cmd = _214b, name = "ローリングタートル", },
			{ addr = 0x06, estab = 0x020600, cmd = _214c, name = "サイドワインダー", },
			{ addr = 0x0A, estab = 0x030600, cmd = _2chg8c, type = input_state_types.charge, name = "バイソンホーン", },
			{ addr = 0x0E, estab = 0x040602, cmd = _4chg6b, type = input_state_types.charge, name = "ワイルドウルフ", },
			{ addr = 0x12, estab = 0x050600, cmd = _623b, name = "モンキーダンス", },
			{ addr = 0x16, estab = 0x0606FE, cmd = _466bc, name = "フロッグハンティング", },
			{ addr = 0x1A, estab = 0x100600, cmd = _64123bc, sdm = "a", name = "デンジャラスウルフ", },
			{ addr = 0x1E, estab = 0x120600, cmd = _64123c, sdm = "c", name = "ダンシングバイソン", },
			{ addr = 0x22, estab = 0x1EFFFF, cmd = _33c, type = input_state_types.followup, name = "ホーネットアタック", },
			{ addr = 0x26, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x2A, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x2E, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x32, estab = 0x237800, cmd = _ccc, name = "フライングフィッシュ", },
			{ addr = 0x36, estab = 0x210600, cmd = _8c, type = input_state_types.faint, name = "リンクスファング", },
			{ addr = 0x3A, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x3E, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x42, estab = 0x0600FF, cmd = _2bc, type = input_state_types.faint, name = "フェイントダンシングバイソン", },
		},
		{ --ホンフゥ
			{ addr = 0x02, estab = 0x010600, cmd = _41236c, name = "九龍の読み/黒龍", },
			{ addr = 0x06, estab = 0x020600, cmd = _623a, name = "小制空烈火棍", },
			{ addr = 0x0A, estab = 0x030600, cmd = _623c, name = "大制空烈火棍", },
			{ addr = 0x0E, estab = 0x040600, cmd = _1chg6b, type = input_state_types.charge, name = "電光石火の地", },
			{ addr = 0x12, estab = 0x000CFE, cmd = _bbb, name = "電光パチキ", },
			{ addr = 0x16, estab = 0x050600, cmd = _214b, name = "電光石火の天", },
			{ addr = 0x1A, estab = 0x060600, cmd = _214a, name = "炎の種馬", },
			{ addr = 0x1E, estab = 0x000CFF, cmd = _aaaa, name = "炎の種馬 連打", },
			{ addr = 0x22, estab = 0x070600, cmd = _214c, name = "必勝！逆襲拳", },
			{ addr = 0x26, estab = 0x100600, cmd = _21416bc, sdm = "a", name = "爆発ゴロー", },
			{ addr = 0x2A, estab = 0x120600, cmd = _21416c, sdm = "c", name = "よかトンハンマー", },
			{ addr = 0x2E, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x32, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x36, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x3A, estab = 0x0600FF, cmd = _2c, type = input_state_types.faint, name = "トドメヌンチャク", },
			{ addr = 0x3E, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x42, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x46, estab = 0x460600, cmd = _4ac, type = input_state_types.faint, name = "フェイント制空烈火棍", },
		},
		{ --ブルー・マリー
			{ addr = 0x02, estab = 0x210600, cmd = _2c, type = input_state_types.faint, name = "M.ダイナマイトスイング", },
			{ addr = 0x06, estab = 0x0106FF, cmd = _236c, name = "M.ｽﾊﾟｲﾀﾞｰ or ｽﾋﾟﾝﾌｫｰﾙ or ﾀﾞﾌﾞﾙｽﾊﾟｲﾀﾞｰ", },
			{ addr = 0x0A, estab = 0x0206FE, cmd = _623b, name = "M.スナッチャー or ダブルスナッチャー", },
			{ addr = 0x0E, estab = 0x0006FD, cmd = _46b, name = "ダブルクラッチ", },
			{ addr = 0x12, estab = 0x0306FD, cmd = _4chg6b, type = input_state_types.charge, name = "M.クラブクラッチ", },
			{ addr = 0x16, estab = 0x040600, cmd = _214a, name = "M.リアルカウンター", },
			{ addr = 0x1A, estab = 0x060600, cmd = _623a, name = "バーチカルアロー", },
			{ addr = 0x1E, estab = 0x070600, cmd = _4chg6a, type = input_state_types.charge, name = "ストレートスライサー", },
			{ addr = 0x22, estab = 0x090600, cmd = _2chg8c, type = input_state_types.charge, name = "ヤングダイブ", },
			{ addr = 0x26, estab = 0x100600, cmd = _64123bc, sdm = "a", name = "M.タイフーン", },
			{ addr = 0x2A, estab = 0x120600, cmd = _64123c, sdm = "c", name = "M.エスカレーション", },
			{ addr = 0x2E, estab = 0x280600, cmd = _33c, type = input_state_types.followup, name = "CA ジャーマンスープレックス", },
			{ addr = 0x32, estab = 0x500600, cmd = _632c, name = "アキレスホールド", },
			{ addr = 0x36, estab = 0x510600, cmd = _412c, name = "アキレスホールド", },
			{ addr = 0x3A, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x3E, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x42, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x46, estab = 0x240600, cmd = _2b, type = input_state_types.faint, name = "レッグプレス", },
			{ addr = 0x4A, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x4E, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x52, estab = 0x460600, cmd = _4ac, type = input_state_types.faint, name = "フェイントM.スナッチャー", },
		},
		{ --フランコ・バッシュ
			{ addr = 0x02, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x06, estab = 0x010600, cmd = _214a, name = "ダブルコング", },
			{ addr = 0x0A, estab = 0x020600, cmd = _236a, name = "ザッパー", },
			{ addr = 0x0E, estab = 0x030600, cmd = _236d, name = "ウエービングブロー", },
			{ addr = 0x12, estab = 0x0600FF, cmd = _2369b, name = "ガッツダンク", },
			{ addr = 0x16, estab = 0x0600FF, cmd = _1chg6c, type = input_state_types.charge, name = "ゴールデンボンバー", },
			{ addr = 0x1A, estab = 0x100600, cmd = _64123bc, name = "ファイナルオメガショット", },
			{ addr = 0x1E, estab = 0x110600, cmd = _63214bc, name = "メガトンスクリュー", },
			{ addr = 0x22, estab = 0x120600, cmd = _64123c, name = "ハルマゲドンバスター", },
			{ addr = 0x26, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x2A, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x2E, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x32, estab = 0x7800FF, cmd = _ccc, name = "スマッシュ", },
			{ addr = 0x36, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x3A, estab = 0x0600FF, cmd = _2bc, type = input_state_types.faint, name = "フェイントハルマゲドンバスター", },
			{ addr = 0x3E, estab = 0x0600FF, cmd = _6ac, type = input_state_types.faint, name = "フェイントガッツダンク", },
		},
		{ --山崎竜二
			{ addr = 0x02, estab = 0x0006FE, cmd = _abc, type = input_state_types.drill5, name = "_A_B_C", }, --TODO
			{ addr = 0x06, estab = 0x0006FF, cmd = _22, type = input_state_types.step, name = "_2_2", },
			{ addr = 0x0A, estab = 0x010600, cmd = _214a, name = "蛇使い・上段 ", },
			{ addr = 0x0E, estab = 0x020600, cmd = _214b, name = "蛇使い・中段", },
			{ addr = 0x12, estab = 0x030600, cmd = _214c, name = "蛇使い・下段", },
			{ addr = 0x16, estab = 0x040600, cmd = _41236b, name = "サドマゾ", },
			{ addr = 0x1A, estab = 0x050600, cmd = _623b, name = "ヤキ入れ", },
			{ addr = 0x1E, estab = 0x060600, cmd = _236c, name = "倍返し", },
			{ addr = 0x22, estab = 0x070600, cmd = _623a, name = "裁きの匕首", },
			{ addr = 0x26, estab = 0x080600, cmd = _6428c, name = "爆弾パチキ", },
			{ addr = 0x2A, estab = 0x090C00, cmd = _22c, type = input_state_types.followup, name = "トドメ", },
			{ addr = 0x2E, estab = 0x100600, cmd = _64123bc, sdm = "a", name = "ギロチン", },
			{ addr = 0x32, estab = 0x120600, cmd = _8624c, sdm = "x", name = "ドリル_8_6_2_4", },
			{ addr = 0x36, estab = 0x120600, cmd = _6248c, sdm = "x", name = "ドリル_6_2_4_8", },
			{ addr = 0x3A, estab = 0x120600, cmd = _2486c, sdm = "x", name = "ドリル_2_4_8_6", },
			{ addr = 0x3E, estab = 0x120600, cmd = _4862c, sdm = "x", name = "ドリル_4_8_6_2", },
			{ addr = 0x42, estab = 0x120600, cmd = _8426c, sdm = "x", name = "ドリル_8_4_2_6", },
			{ addr = 0x46, estab = 0x120600, cmd = _4268c, sdm = "x", name = "ドリル_4_2_6_8", },
			{ addr = 0x4A, estab = 0x120600, cmd = _2684c, sdm = "x", name = "ドリル_2_6_8_4", },
			{ addr = 0x4E, estab = 0x120600, cmd = _6842c, sdm = "x", name = "ドリル_6_8_4_2", },
			{ addr = nil, easy_addr = 0x32, estab = 0x120600, cmd = _22c, sdm = "c", name = "ドリル", },
			{ addr = 0x52, easy_addr = 0x36, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x56, easy_addr = 0x3A, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x5A, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x5E, easy_addr = 0x3E, estab = 0x7800FF, cmd = _ccc, name = "砂かけ", },
			{ addr = 0x62, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x66, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x6A, easy_addr = 0x42, estab = 0x460600, cmd = _6ac, type = input_state_types.faint, name = "フェイント裁きの匕首", },
		},
		{ --秦崇秀
			{ addr = 0x02, estab = 0x010600, cmd = _66a, type = input_state_types.shinsoku, name = "帝王神足拳", },
			{ addr = 0x06, estab = 0x020600, cmd = _236a, name = "小帝王天眼拳", },
			{ addr = 0x0A, estab = 0x030600, cmd = _236c, name = "大帝王天眼拳", },
			{ addr = 0x0E, estab = 0x040600, cmd = _623a, name = "小帝王天耳拳", },
			{ addr = 0x12, estab = 0x050600, cmd = _623c, name = "大帝王天耳拳", },
			{ addr = 0x16, estab = 0x0A0600, cmd = _214b, name = "空中 帝王神眼拳", },
			{ addr = 0x1A, estab = 0x060600, cmd = _236b, name = "竜灯掌", },
			{ addr = 0x1E, estab = 0x070600, cmd = _63214a, name = "帝王神眼拳A", },
			{ addr = 0x22, estab = 0x0806FF, cmd = _63214b, name = "帝王神眼拳B or 竜灯掌・幻殺", },
			{ addr = 0x26, estab = 0x090600, cmd = _63214c, name = "帝王神眼拳C", },
			{ addr = 0x2A, estab = 0x100600, cmd = _64123bc, sdm = "a", name = "帝王漏尽拳", },
			{ addr = 0x2E, estab = 0x0A0600, cmd = _2146bc, sdm = "b", name = "帝王空殺漏尽拳", },
			{ addr = 0x32, estab = 0x120600, cmd = _64123c, sdm = "c", name = "海龍照臨", },
			{ addr = 0x36, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x3A, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x3E, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x42, estab = 0x280600, cmd = _64c, name = "CA _6_4+_C", },
			{ addr = 0x46, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x4A, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x4E, estab = 0x460600, cmd = _2bc, type = input_state_types.faint, name = "フェイント海龍照臨", },
		},
		{ --秦崇雷
			{ addr = 0x02, estab = 0x010600, cmd = _66a, type = input_state_types.shinsoku, name = "帝王神足拳", },
			{ addr = 0x06, estab = 0x0106FF, cmd = _666a, type = input_state_types.shinsoku, name = "真・帝王神足拳", },
			{ addr = 0x0A, estab = 0x020600, cmd = _236a, name = "小帝王天眼拳", },
			{ addr = 0x0E, estab = 0x030600, cmd = _236c, name = "大帝王天眼拳", },
			{ addr = 0x12, estab = 0x040600, cmd = _623a, name = "小帝王天耳拳", },
			{ addr = 0x16, estab = 0x050600, cmd = _623c, name = "大帝王天耳拳", },
			{ addr = 0x1A, estab = 0x060600, cmd = _2146c, name = "帝王漏尽拳", },
			{ addr = 0x1E, estab = 0x070600, cmd = _236b, name = "龍転身（前方）", },
			{ addr = 0x22, estab = 0x080600, cmd = _214b, name = "龍転身（後方）", },
			{ addr = 0x26, estab = 0x100600, cmd = _64123bc, sdm = "a", name = "帝王宿命拳", },
			{ addr = 0x2A, estab = 0x0006FE, cmd = _ccc, name = "_C_C_C" , },
			{ addr = 0x2E, estab = 0x120600, cmd = _64123c, sdm = "c", name = "帝王龍声拳", },
			{ addr = 0x32, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x36, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x3A, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x3E, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x42, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x46, estab = 0x460600, cmd = _2bc, type = input_state_types.faint, name = "フェイント帝王宿命拳", },
		},
		{ --ダック・キング
			-- ROMパッチをあてて通常コマンドでﾌﾞﾚｲｸｽﾊﾟｲﾗﾙﾌﾞﾗｻﾞｰを出せるようにしているため
			-- こちらのほうもコマンド変更4
			{ addr = 0x02, estab = 0x070600, cmd = _35c, type = input_state_types.unknown, name = "_3_N_C", },
			{ addr = 0x06, estab = 0x010600, cmd = _236a, name = "小ヘッドスピンアタック", },
			{ addr = 0x0A, estab = 0x020600, cmd = _236c, name = "大ヘッドスピンアタック", },
			-- オーバーヘッドキックはCCで成立するが、成立時に次のC入力が1回消費される作りのため見ためが他と違う
			{ addr = 0x0E, estab = 0x06FFFF, cmd = _cc, type = input_state_types.unknown, name = "オーバーヘッドキック", },
			{ addr = 0x12, estab = 0x030600, cmd = _214a, name = "フライングスピンアタック", },
			{ addr = 0x16, estab = 0x040600, cmd = _214b, name = "ダンシングダイブ", },
			{ addr = 0x1A, estab = 0x0006FE, cmd = _236b, name = "リバースダイブ", },
			{ addr = 0x1E, estab = 0x050600, cmd = _623b, name = "ブレイクストーム", },
			{ addr = 0x22, estab = 0x0006FD, cmd = _bbbb, name = "ブレイクストーム追加1段階", },
			{ addr = 0x26, estab = 0x0006FC, cmd = _bbbbbb, name = "ブレイクストーム追加2段階", },
			{ addr = 0x2A, estab = 0x0006FB, cmd = _bbbbbbbb, name = "ブレイクストーム追加3段階", },
			{ addr = 0x2E, estab = 0x060600, cmd = _22, type = input_state_types.step, name = "ダックフェイント・空", },
			{ addr = 0x32, estab = 0x080600, cmd = _82d, name = "クロスヘッドスピン", },
			{ addr = 0x36, estab = 0x090600, cmd = _214bc, name = "ﾀﾞｲﾋﾞﾝｸﾞﾊﾟﾆｯｼｬｰ or ﾀﾞﾝｼﾝｸﾞｷｬﾘﾊﾞｰ", },
			{ addr = 0x3A, estab = 0x0A0600, cmd = _236bc, name = "ローリングパニッシャー", },
			{ addr = 0x3E, estab = 0x0C0600, cmd = _623bc, name = "ブレイクハリケーン", },
			{ addr = 0x42, estab = 0x100600, cmd = _8624bc, sdm = "x", name = "ブレイクスパイラル_8_6_2_4", },
			{ addr = 0x46, estab = 0x100600, cmd = _6248bc, sdm = "x", name = "ブレイクスパイラル_6_2_4_8", },
			{ addr = 0x4A, estab = 0x100600, cmd = _2486bc, sdm = "x", name = "ブレイクスパイラル_2_4_8_6", },
			{ addr = 0x4E, estab = 0x100600, cmd = _4862bc, sdm = "x", name = "ブレイクスパイラル_4_8_6_2", },
			{ addr = 0x52, estab = 0x100600, cmd = _8426bc, sdm = "x", name = "ブレイクスパイラル_8_4_2_6", },
			{ addr = 0x56, estab = 0x100600, cmd = _4268bc, sdm = "x", name = "ブレイクスパイラル_4_2_6_8", },
			{ addr = 0x5A, estab = 0x100600, cmd = _2684bc, sdm = "x", name = "ブレイクスパイラル_2_6_8_4", },
			{ addr = 0x5E, estab = 0x100600, cmd = _6842bc, sdm = "x", name = "ブレイクスパイラル_6_8_4_2", },
			{ addr = 0x62, estab = 0x1106FA, cmd = _41236bc, sdm = "x", name = "ﾌﾞﾚｲｸｽﾊﾟｲﾗﾙﾌﾞﾗｻﾞｰ or ｸﾚｲｼﾞｰBR", },
			{ addr = 0x66, estab = 0x130600, cmd = _63214c, sdm = "x", name = "スーパーポンピングマシーン", },
			{ addr = 0x6A, estab = 0x0006F9, cmd = _623c, sdm = "x", name = "_6_2_3+_C", },
			{ addr = 0x6E, estab = 0x120600, cmd = _64123c, sdm = "x", name = "ダックダンス", },
			{ addr = nil, easy_addr = 0x42, estab = nil, cmd = _22c, sdm = "a", name = "ブレイクスパイラル", },
			{ addr = nil, easy_addr = 0x46, estab = 0x1106FA, cmd = _41236bc, name = "ﾌﾞﾚｲｸｽﾊﾟｲﾗﾙﾌﾞﾗｻﾞｰ or ｸﾚｲｼﾞｰBR", },
			{ addr = nil, easy_addr = 0x4A, estab = nil, cmd = _64123c, sdm = "c", name = "ダックダンス", },
			{ addr = nil, easy_addr = 0x4E, estab = nil, cmd = _22d, sdm = "d", name = "スーパーポンピングマシーン", },
			{ addr = 0x72, easy_addr = 0x52, estab = 0x0006F8, cmd = _cccc, name = "ダックダンスC連打", },
			{ addr = 0x76, easy_addr = 0x5A, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x7A, easy_addr = 0x5E, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x7E, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x82, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x86, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x8A, easy_addr = 0x6E, estab = 0x210600, cmd = _2c, type = input_state_types.faint, name = "ショッキングボール", },
			{ addr = 0x8E, easy_addr = 0x72, estab = 0x280600, cmd = _2369b, name = "CA ブレイクストーム", },
			{ addr = 0x92, easy_addr = 0x76, estab = 0x460600, cmd = _2bc, type = input_state_types.faint, name = "フェイントダックダンス", },
		},
		{ --キム・カッファン
			{ addr = 0x02, estab = 0x010600, cmd = _2chg8b, type = input_state_types.charge, name = "飛燕斬", },
			{ addr = 0x06, estab = 0x010601, cmd = _2chg9b, type = input_state_types.charge, name = "飛燕斬", },
			{ addr = 0x0A, estab = 0x010602, cmd = _2chg7b, type = input_state_types.charge, name = "飛燕斬", },
			{ addr = 0x0E, estab = 0x040800, cmd = _2b, type = input_state_types.faint, name = "飛翔脚", },
			{ addr = 0x12, estab = 0x0008FF, cmd = _3b, type = input_state_types.faint, name = "戒脚", },
			{ addr = 0x16, estab = 0x020600, cmd = _214b, name = "小半月斬", },
			{ addr = 0x1A, estab = 0x030600, cmd = _214c, name = "大半月斬", },
			{ addr = 0x1E, estab = 0x050600, cmd = _2chg8a, type = input_state_types.charge, name = "空砂塵", },
			{ addr = 0x22, estab = 0x06FEFF, cmd = _2a, type = input_state_types.faint, name = "天昇斬", },
			{ addr = 0x26, estab = 0x0006FE, cmd = _22b, type = input_state_types.shinsoku, name = "覇気脚", },
			{ addr = 0x2A, estab = 0x100600, cmd = _41236bc, sdm = "a", name = "鳳凰天舞脚", },
			{ addr = 0x2E, estab = 0x120600, cmd = _21416c, sdm = "c", name = "鳳凰脚", },
			{ addr = 0x32, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x36, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x3A, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x3E, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x42, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x46, estab = 0x460600, cmd = _2bc, type = input_state_types.faint, name = "フェイント鳳凰脚", },
		},
		{ --ビリー・カーン
			{ addr = 0x02, estab = 0x010600, cmd = _4chg6a, type = input_state_types.charge, name = "三節棍中段打ち", },
			{ addr = 0x06, estab = 0x0006FF, cmd = _46c, name = "火炎三節棍中段突き", },
			{ addr = 0x0A, estab = 0x030600, cmd = _214a, name = "雀落とし", },
			{ addr = 0x0E, estab = 0x040C00, cmd = _aaaa, name = "旋風棍", },
			{ addr = 0x12, estab = 0x050600, cmd = _1236b, name = "強襲飛翔棍", },
			{ addr = 0x16, estab = 0x060600, cmd = _214b, name = "火龍追撃棍", },
			{ addr = 0x1A, estab = 0x100600, cmd = _64123bc, sdm = "a", name = "超火炎旋風棍", },
			{ addr = 0x1E, estab = 0x110600, cmd = _632c, sdm = "b", name = "紅蓮殺棍", },
			{ addr = 0x22, estab = 0x120600, cmd = _64123c, sdm = "c", name = "サラマンダーストーム", },
			{ addr = 0x26, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x2A, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x2E, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x32, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x36, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x3A, estab = 0x280600, cmd = _236c, name = "CA 集点連破棍", },
			{ addr = 0x3E, estab = 0x460600, cmd = _4ac, type = input_state_types.faint, name = "フェイント強襲飛翔棍", },
		},
		{ --チン・シンザン
			{ addr = 0x02, estab = 0x010600, cmd = _236a, name = "氣雷砲（前方）", },
			{ addr = 0x06, estab = 0x020600, cmd = _623a, name = "氣雷砲（対空）", },
			{ addr = 0x0A, estab = 0x030600, cmd = _2chg8a, type = input_state_types.charge, name = "超太鼓腹打ち", },
			{ addr = 0x0E, estab = 0x0006FF, cmd = _aa, name = "満腹滞空", },
			{ addr = 0x12, estab = 0x040600, cmd = _4chg6b, type = input_state_types.charge, name = "小破岩撃", },
			{ addr = 0x16, estab = 0x050600, cmd = _4chg6c, type = input_state_types.charge, name = "大破岩撃", },
			{ addr = 0x1A, estab = 0x060600, cmd = _214b, name = "軟体オヤジ", },
			{ addr = 0x1E, estab = 0x070600, cmd = _214c, name = "クッサメ砲", },
			{ addr = 0x22, estab = 0x100600, cmd = _1chg26bc, type = input_state_types.charge, sdm = "a", name = "爆雷砲", },
			{ addr = 0x26, estab = 0x120600, cmd = _64123c, sdm = "c", name = "ホエホエ弾", },
			{ addr = 0x2A, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x2E, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x32, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x36, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x3A, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x3E, estab = 0x280600, cmd = _44b, name = "CA _4_4+_B", },
			{ addr = 0x42, estab = 0x460600, cmd = _6ac, type = input_state_types.faint, name = "フェイント破岩撃", },
			{ addr = 0x46, estab = 0x470600, cmd = _2ac, type = input_state_types.faint, name = "フェイントクッサメ砲", },
		},
		{ --タン・フー・ルー,
			{ addr = 0x02, estab = 0x010600, cmd = _236a, name = "衝波", },
			{ addr = 0x06, estab = 0x020600, cmd = _214a, name = "小箭疾歩", },
			{ addr = 0x0A, estab = 0x030600, cmd = _214c, name = "大箭疾歩", },
			{ addr = 0x0E, estab = 0x040600, cmd = _236c, name = "撃放", },
			{ addr = 0x12, estab = 0x050600, cmd = _623b, name = "烈千脚", },
			{ addr = 0x16, estab = 0x100600, cmd = _64123bc, sdm = "a", name = "旋風剛拳", },
			{ addr = 0x1A, estab = 0x120600, cmd = _64123c, sdm = "c", name = "大撃砲", },
			{ addr = 0x1E, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x22, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x26, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x2A, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x2E, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x32, estab = 0x280600, cmd = _6b, type = input_state_types.faint, name = "_6+_B", },
			{ addr = 0x36, estab = 0x290600, cmd = _6c, type = input_state_types.faint, name = "_6+_C", },
			{ addr = 0x3A, estab = 0x460600, cmd = _2bc, type = input_state_types.faint, name = "フェイント旋風剛拳", },
		},
		{ --ローレンス・ブラッド
			{ addr = 0x02, estab = 0x010600, cmd = _63214a, name = "小ブラッディスピン", },
			{ addr = 0x06, estab = 0x020600, cmd = _63214c, name = "大ブラッディスピン", },
			{ addr = 0x0A, estab = 0x030600, cmd = _4chg6c, type = input_state_types.charge, name = "ブラッディサーベル", },
			{ addr = 0x0E, estab = 0x0406FF, cmd = _aaaa, name = "ブラッディミキサー", },
			{ addr = 0x12, estab = 0x050600, cmd = _2chg8c, type = input_state_types.charge, name = "ブラッディカッター", },
			{ addr = 0x16, estab = 0x100600, cmd = _64123bc, sdm = "a", name = "ブラッディフラッシュ", },
			{ addr = 0x1A, estab = 0x120600, cmd = _64123c, sdm = "c", name = "ブラッディシャドー", },
			{ addr = 0x1E, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x22, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x26, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x2A, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x2E, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x32, estab = 0x280600, cmd = _632c, name = "CA _6_3_2_C", },
		},
		{ --ヴォルフガング・クラウザー
			{ addr = 0x02, easy_addr = 0x02, estab = 0x0006FE, cmd = _421ac, name = "アンリミテッドデザイア2 Finish", },
			{ addr = 0x06, estab = 0x010600, cmd = _214a, name = "小ブリッツボール", },
			{ addr = 0x0A, estab = 0x0206FF, cmd = _214c, name = "大ブリッツボール", },
			{ addr = 0x0E, estab = 0x030600, cmd = _236b, name = "レッグトマホーク", },
			{ addr = 0x12, estab = 0x040600, cmd = _41236c, name = "フェニックススルー", },
			{ addr = 0x16, estab = 0x050600, cmd = _41236a, name = "デンジャラススルー", },
			{ addr = 0x1A, estab = 0x0006FD, cmd = _666c, name = "グリフォンアッパー", },
			{ addr = 0x1E, estab = 0x0606FC, cmd = _623c, name = "カイザークロー", },
			{ addr = 0x22, estab = 0x070600, cmd = _63214b, name = "リフトアップブロー", },
			{ addr = 0x26, estab = 0x100600, cmd = _4chg6bc, type = input_state_types.charge, sdm = "a", name = "カイザーウェイブ", },
			{ addr = 0x2A, estab = 0x120600, cmd = _8624c, sdm = "x", name = "ギガティックサイクロン_8_6_2_4", },
			{ addr = 0x2E, estab = 0x120600, cmd = _6248c, sdm = "x", name = "ギガティックサイクロン_6_2_4_8", },
			{ addr = 0x32, estab = 0x120600, cmd = _2486c, sdm = "x", name = "ギガティックサイクロン_2_4_8_6", },
			{ addr = 0x36, estab = 0x120600, cmd = _4862c, sdm = "x", name = "ギガティックサイクロン_4_8_6_2", },
			{ addr = 0x3A, estab = 0x120600, cmd = _8426c, sdm = "x", name = "ギガティックサイクロン_8_4_2_6", },
			{ addr = 0x3E, estab = 0x120600, cmd = _4268c, sdm = "x", name = "ギガティックサイクロン_4_2_6_8", },
			{ addr = 0x42, estab = 0x120600, cmd = _2684c, sdm = "x", name = "ギガティックサイクロン_2_6_8_4", },
			{ addr = 0x46, estab = 0x120600, cmd = _6842c, sdm = "x", name = "ギガティックサイクロン_6_8_4_2", },
			{ addr = nil, easy_addr = 0x2A, estab = nil, cmd = _22c, sdm = "c", name = "ギガティックサイクロン", },
			{ addr = 0x4A, easy_addr = 0x2E, estab = 0x130600, cmd = _632146a, sdm = "d", name = "アンリミテッドデザイア", },
			{ addr = 0x4E, easy_addr = 0x32, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x52, easy_addr = 0x36, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x56, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x5A, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x5E, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x62, easy_addr = 0x46, estab = 0x210600, cmd = _2c, type = input_state_types.faint, name = "ダイビングエルボー", },
			{ addr = 0x66, easy_addr = 0x4A, estab = 0x280600, cmd = _236c, name = "CA _2_3_6_C", },
			{ addr = 0x6A, easy_addr = 0x4E, estab = 0x460600, cmd = _2ac, type = input_state_types.faint, name = "フェイントブリッツボール", },
			{ addr = 0x6E, easy_addr = 0x52, estab = 0x470600, cmd = _2bc, type = input_state_types.faint, name = "フェイントカイザーウェイブ", },
		},
		{ --リック・ストラウド
			{ addr = 0x02, estab = 0x010600, cmd = _236a, name = "小シューティングスター", },
			{ addr = 0x06, estab = 0x0206FF, cmd = _236c, name = "大シューティングスター", },
			{ addr = 0x0A, estab = 0x030600, cmd = _214c, name = "ディバインブラスト", },
			{ addr = 0x0E, estab = 0x040600, cmd = _214b, name = "フルムーンフィーバー", },
			{ addr = 0x12, estab = 0x050600, cmd = _623a, name = "ヘリオン", },
			{ addr = 0x16, estab = 0x060600, cmd = _214a, name = "ブレイジングサンバースト", },
			{ addr = 0x1A, estab = 0x100600, cmd = _64123bc, sdm = "a", name = "ガイアブレス", },
			{ addr = 0x1E, estab = 0x120600, cmd = _64123c, sdm = "c", name = "ハウリング・ブル", },
			{ addr = 0x22, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x26, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x2A, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x2E, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x32, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x36, estab = 0x280600, cmd = _33b, name = "CA _3_3_B", },
			{ addr = 0x3A, estab = 0x290600, cmd = _22c, name = "CA _2_2_C", },
			{ addr = 0x3E, estab = 0x460600, cmd = _6ac, type = input_state_types.faint, name = "フェイントシューティングスター", },
		},
		{ --李香緋
			{ addr = 0x02, estab = 0x070600, cmd = _a8, name = "詠酒・対ジャンプ攻撃", },
			{ addr = 0x06, estab = 0x080600, cmd = _a6, name = "詠酒・対立ち攻撃", },
			{ addr = 0x0A, estab = 0x090600, cmd = _a2, name = "詠酒・対しゃがみ攻撃 ", },
			{ addr = 0x0E, estab = 0x010600, cmd = _236a, name = "小那夢波", },
			{ addr = 0x12, estab = 0x020600, cmd = _236c, name = "大那夢波", },
			{ addr = 0x16, estab = 0x0306FF, cmd = _236b, name = "閃里肘皇 or 閃里肘皇・貫空", },
			{ addr = 0x1A, estab = 0x0006FE, cmd = _214b, name = "閃里肘皇・心砕把", },
			{ addr = 0x1E, estab = 0x060600, cmd = _623b, name = "天崩山", },
			{ addr = 0x22, estab = 0x100600, cmd = _64123bc, sdm = "a", name = "大鉄神", },
			{ addr = 0x26, estab = 0x1106FD, cmd = _616ab, sdm = "b", name = "超白龍 1段目or2段目", },
			{ addr = 0x2A, estab = 0x0006FD, cmd = _623ab, sdm = "x", name = "超白龍 2段目のみ", },
			{ addr = 0x2E, estab = 0x120600, cmd = _8624c, sdm = "x", name = "真心牙_8_6_2_4", },
			{ addr = 0x32, estab = 0x120600, cmd = _6248c, sdm = "x", name = "真心牙_6_2_4_8", },
			{ addr = 0x36, estab = 0x120600, cmd = _2486c, sdm = "x", name = "真心牙_2_4_8_6", },
			{ addr = 0x3A, estab = 0x120600, cmd = _4862c, sdm = "x", name = "真心牙_4_8_6_2", },
			{ addr = 0x3E, estab = 0x120600, cmd = _8426c, sdm = "x", name = "真心牙_8_4_2_6", },
			{ addr = 0x42, estab = 0x120600, cmd = _4268c, sdm = "x", name = "真心牙_4_2_6_8", },
			{ addr = 0x46, estab = 0x120600, cmd = _2684c, sdm = "x", name = "真心牙_2_6_8_4", },
			{ addr = 0x4A, estab = 0x120600, cmd = _6842c, sdm = "x", name = "真心牙_6_8_4_2", },
			{ addr = nil, easy_addr = 0x2A, estab = nil, cmd = _22c, sdm = "c", name = "真心牙", },
			{ addr = 0x4E, easy_addr = 0x2E, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x52, easy_addr = 0x32, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x56, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x5A, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x5E, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x62, easy_addr = 0x36, estab = 0x280600, cmd = _66a, name = "CA _6_6_A", },
			{ addr = 0x66, easy_addr = 0x3A, estab = 0x460600, cmd = _4ac, type = input_state_types.faint, name = "フェイント天崩山", },
			{ addr = 0x6A, easy_addr = 0x3E, estab = 0x470600, cmd = _2bc, type = input_state_types.faint, name = "フェイント大鉄神", },
		},
		{ --アルフレッド
			{ addr = 0x02, estab = 0x010600, cmd = _214a, name = "小クリティカルウィング", },
			{ addr = 0x06, estab = 0x020600, cmd = _214c, name = "大クリティカルウィング", },
			{ addr = 0x0A, estab = 0x030600, cmd = _236a, name = "オーグメンターウィング", },
			{ addr = 0x0E, estab = 0x040600, cmd = _236c, name = "ダイバージェンス", },
			{ addr = 0x12, estab = 0x050600, cmd = _214b, name = "メーデーメーデー", },
			{ addr = 0x16, estab = 0x06FFFF, cmd = _bbb, name = "メーデーメーデー追加", },
			{ addr = 0x1A, estab = 0x060600, cmd = _698b, name = "S.TOL", },
			{ addr = 0x1E, estab = 0x100600, cmd = _41236bc, sdm = "a", name = "ショックストール", },
			{ addr = 0x22, estab = 0x120600, cmd = _64123c, sdm = "c", name = "ウェーブライダー", },
			{ addr = 0x26, estab = 0x1E0600, cmd = _66, type = input_state_types.step, name = "ダッシュ", },
			{ addr = 0x2A, estab = 0x1F0600, cmd = _44, type = input_state_types.step, name = "飛び退き", },
			{ addr = 0x2E, estab = 0x200600, cmd = _46a, name = "_4_6+_A", },
			{ addr = 0x32, estab = 0x000033, cmd = _412d, name = "_4_1_2+_D", },
			{ addr = 0x36, estab = 0x000027, cmd = _44d, type = input_state_types.shinsoku, name = "_4_4+_D", },
			{ addr = 0x3A, estab = 0x460600, cmd = _2ac, type = input_state_types.faint, name = "フェイントクリティカルウィング", },
			{ addr = 0x3E, estab = 0x470600, cmd = _4ac, type = input_state_types.faint, name = "フェイントオーグメンターウィング", },
		},
		{ -- all 調査用
		},
	}
	for ti = 2, 160, 2 do
		table.insert(input_states[#input_states], {
			name = string.format("%x", ti),
			addr = ti,
			cmd = "?",
			type = input_state_types.unknown,
			estab = 0
		})
	end
	local deepcopy
	deepcopy = function(orig)
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
	local sdm_cmd = { ["a"] = _22a, ["b"] = _22b, ["c"] = _22c, ["d"] = _22d }
	local sdm_estab =  { ["a"] = 0x100600, ["b"] = 0x110600, ["c"] = 0x120600, ["d"] = 0x130600 }
	local id_estab = function(tbl)
		tbl.estab = sdm_estab[tbl.sdm] or tbl.estab
		tbl.id = (0xFF0000 & tbl.estab) / 0x10000
		tbl.estab = tbl.estab & 0xFFFF
	end
	local do_remove = function(target, indexies)
		for i = #indexies, 1, -1 do
			table.remove(target, indexies[i])
		end
	end
	-- DEBUG DIP 2-1 ON時の簡易コマンドテーブルの準備としてSDMのフラグからコマンド情報を変更
	local input_easy_states = deepcopy(input_states)
	for _, char_tbl in ipairs(input_easy_states) do
		local removes = {}
		for i, tbl in ipairs(char_tbl) do
			if tbl.sdm == "x" then
				-- 削除
				table.insert(removes, i)
			elseif tbl.sdm ~= nil then
				-- 簡易コマンドへ変更
				tbl.cmd = sdm_cmd[tbl.sdm]
				tbl.type = input_state_types.followup
			end
			tbl.addr = tbl.easy_addr or tbl.addr
			id_estab(tbl)
		end
		do_remove(char_tbl, removes)
	end
	-- 通常コマンドテーブルの準備としてアドレスが未定義にしているものを削除
	for _, char_tbl in ipairs(input_states) do
		local removes = {}
		for i, tbl in ipairs(char_tbl) do
			if tbl.addr == nil then
				-- 削除
				table.insert(removes, i)
			end
			id_estab(tbl)
		end
		do_remove(char_tbl, removes)
	end
	local convert = function(input_tables)
		for _, char_tbl in ipairs(input_tables) do
			for _, tbl in ipairs(char_tbl) do
				-- 左右反転コマンド表示用
				tbl.r_cmd = string.gsub(tbl.cmd, "[134679]", {
					["1"] = "3", ["3"] = "1", ["4"] = "6", ["6"] = "4", ["7"] = "9", ["9"] = "7",
				})
				local r_cmds, cmds = {}, {}
				for c in string.gmatch(convert(tbl.r_cmd), "([^|]*)|?") do
					table.insert(r_cmds, c)
				end
				for c in string.gmatch(convert(tbl.cmd), "([^|]*)|?") do
					table.insert(cmds, c)
				end
				-- コマンドの右向き左向きをあらわすデータ値をキーにしたテーブルを用意
				tbl.lr_cmds = { [0x00] = cmds, [0x80] = r_cmds, }
				tbl.cmds = cmds
				tbl.name = convert(tbl.name)
			end
		end
		return input_tables
	end
	return { normal = convert(input_states), easy = convert(input_easy_states) }
end
local input_states = create_input_states()

-- キー入力2
local cmd_neutral = function(p, next_joy)
	next_joy["P" .. p.control .. " Up"] = false
	next_joy["P" .. p.control .. " Down"] = false
	next_joy[p.block_side] = false
	next_joy[p.front_side] = false
	next_joy["P" .. p.control .. " A"] = false
	next_joy["P" .. p.control .. " B"] = false
	next_joy["P" .. p.control .. " C"] = false
	next_joy["P" .. p.control .. " D"] = false
end
local cmd_base = {
	_5 = cmd_neutral,
	_7 = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Up"] = true
		next_joy[p.block_side] = true
	end,
	_8 = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Up"] = true
	end,
	_9 = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Up"] = true
		next_joy[p.front_side] = true
	end,
	_6 = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.front_side] = true
	end,
	_3 = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.front_side] = true
		next_joy["P" .. p.control .. " Down"] = true
	end,
	_2 = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Down"] = true
	end,
	_1 = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Down"] = true
		next_joy[p.block_side] = true
	end,
	_4 = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.block_side] = true
	end,
	_a = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " A"] = true
	end,
	_b = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " B"] = true
	end,
	_c = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " C"] = true
	end,
	_d = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " D"] = true
	end,
	_ab = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " A"] = true
		next_joy["P" .. p.control .. " B"] = true
	end,
	_bc = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " B"] = true
		next_joy["P" .. p.control .. " C"] = true
	end,
	_6a = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.front_side] = true
		next_joy["P" .. p.control .. " A"] = true
	end,
	_3a = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.front_side] = true
		next_joy["P" .. p.control .. " Down"] = true
		next_joy["P" .. p.control .. " A"] = true
	end,
	_2a = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Down"] = true
		next_joy["P" .. p.control .. " A"] = true
	end,
	_4a = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.block_side] = true
		next_joy["P" .. p.control .. " A"] = true
	end,
	_6b = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.front_side] = true
		next_joy["P" .. p.control .. " B"] = true
	end,
	_3b = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.front_side] = true
		next_joy["P" .. p.control .. " Down"] = true
		next_joy["P" .. p.control .. " B"] = true
	end,
	_2b = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Down"] = true
		next_joy["P" .. p.control .. " B"] = true
	end,
	_4b = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.block_side] = true
		next_joy["P" .. p.control .. " B"] = true
	end,
	_6c = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.front_side] = true
		next_joy["P" .. p.control .. " C"] = true
	end,
	_3c = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.front_side] = true
		next_joy["P" .. p.control .. " Down"] = true
		next_joy["P" .. p.control .. " C"] = true
	end,
	_2c = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Down"] = true
		next_joy["P" .. p.control .. " C"] = true
	end,
	_4c = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.block_side] = true
		next_joy["P" .. p.control .. " C"] = true
	end,
	_8d = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Up"] = true
		next_joy["P" .. p.control .. " D"] = true
	end,
	_2d = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Down"] = true
		next_joy["P" .. p.control .. " D"] = true
	end,
}
local rvs_types = {
	on_wakeup           = 1, -- ダウン起き上がりリバーサル入力
	jump_landing        = 2, -- 着地リバーサル入力（やられの着地）
	knock_back_landing  = 3, -- 着地リバーサル入力（通常ジャンプの着地）
	knock_back_recovery = 4, -- リバーサルじゃない最速入力
	in_knock_back       = 5, -- のけぞり中のデータをみてのけぞり修了の_2F前に入力確定する
	dangerous_through   = 6, -- デンジャラススルー用
	atemi               = 7, -- 当身うち空振りと裏雲隠し用
}
local pre_down_acts = new_set(0x142, 0x145, 0x156, 0x15A, 0x15B, 0x15E, 0x15F, 0x160, 0x162, 0x166, 0x16A, 0x16C, 0x16D, 0x174, 0x175, 0x186, 0x188, 0x189, 0x1E0, 0x1E1, 0x2AE, 0x2BA)
local common_rvs = {
	{ cmd = cmd_base._2a     , bs = false, common = true, name = "[共通] 屈A", },
	{ cmd = cmd_base._a      , bs = false, common = true, name = "[共通] 立A", },
	{ cmd = cmd_base._2b     , bs = false, common = true, name = "[共通] 屈B", },
	{ cmd = cmd_base._b      , bs = false, common = true, name = "[共通] 立B", },
	{ cmd = cmd_base._6c     , bs = false, common = true, name = "[共通] 投げ", throw = true, },
	{ cmd = cmd_base._ab     , bs = false, common = true, name = "[共通] 避け攻撃", },
	{ id = 0x1F, ver = 0x0600, bs = false, common = true, name = "[共通] 飛び退き", },
	{ cmd = cmd_base._2c     , bs = false, common = true, name = "[共通] 屈C", },
	{ cmd = cmd_base._2d     , bs = false, common = true, name = "[共通] 屈D", },
	{ cmd = cmd_base._c      , bs = false, common = true, name = "[共通] 立C", },
	{ cmd = cmd_base._d      , bs = false, common = true, name = "[共通] 立D", },
	{ cmd = cmd_base._8      , bs = false, common = true, name = "[共通] 垂直ジャンプ", jump = true, },
	{ cmd = cmd_base._9      , bs = false, common = true, name = "[共通] 前ジャンプ", jump = true, },
	{ cmd = cmd_base._7      , bs = false, common = true, name = "[共通] 後ジャンプ", jump = true, },
	{ id = 0x1E, ver = 0x0600, bs = false, common = true, name = "[共通] ダッシュ", },
}
-- idはコマンドテーブル上の技ID
-- verは追加入力フラグとして認識される技ID
local char_rvs_list = {
	-- テリー・ボガード
	{
		{ cmd = cmd_base._3a     , bs = false, name = "ワイルドアッパー", },
		{ cmd = cmd_base._6b     , bs = false, name = "バックスピンキック", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "小バーンナックル", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "大バーンナックル", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "パワーウェイブ", },
		{ id = 0x04, ver = 0x0600, bs = true , name = "ランドウェイブ", },
		{ id = 0x05, ver = 0x0600, bs = true , name = "クラックシュート", },
		{ id = 0x06, ver = 0x0600, bs = true , name = "ファイヤーキック", },
		{ id = 0x07, ver = 0x0600, bs = false, name = "パッシングスウェー", },
		{ id = 0x08, ver = 0x0600, bs = false, name = "ライジングタックル", },
		{ id = 0x10, ver = 0x0600, bs = true , name = "パワーゲイザー", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "トリプルゲイザー", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント バーンナックル", },
		{ id = 0x47, ver = 0x0600, bs = false, name = "フェイント パワーゲイザー", },
	},
	-- アンディ・ボガード
	{
		{ cmd = cmd_base._3a     , bs = false, name = "上げ面", },
		{ cmd = cmd_base._6b     , bs = false, name = "浴びせ蹴り", },
		{ id = 0x01, ver = 0x0600, bs = false, name = "小残影拳", },
		{ id = 0x02, ver = 0x06FF, bs = false, name = "大残影拳", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "飛翔拳", },
		{ id = 0x04, ver = 0x0600, bs = true , name = "激飛翔拳", },
		{ id = 0x05, ver = 0x0600, bs = true , name = "昇龍弾", },
		{ id = 0x06, ver = 0x0600, bs = true , name = "空破弾", },
		-- { id = 0x07, ver = 0x1200, bs = false, name = "幻影不知火", },
		{ id = 0x10, ver = 0x0600, bs = false, name = "超裂破弾", },
		{ id = 0x12, ver = 0x0600, bs = true , name = "男打弾", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント 残影拳", },
		{ id = 0x47, ver = 0x0600, bs = false, name = "フェイント 飛翔拳", },
		{ id = 0x48, ver = 0x0600, bs = false, name = "フェイント 超裂破弾", },
	},
	-- 東丈
	{
		{ cmd = cmd_base._3c     , bs = false, name = "膝地獄", },
		{ cmd = cmd_base._3b     , bs = false, name = "上げ面", },
		{ cmd = cmd_base._4b     , bs = false, name = "ハイキック", },
		{ id = 0x01, ver = 0x0600, bs = false, name = "小スラッシュキック", },
		{ id = 0x02, ver = 0x0600, bs = false, name = "大スラッシュキック", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "黄金のカカト", },
		{ id = 0x04, ver = 0x0600, bs = true , name = "タイガーキック", },
		{ id = 0x05, ver = 0x0C00, bs = true , name = "爆裂拳", },
		-- { id = 0x00, ver = 0x0CFF, bs = false, name = "爆裂フック", },
		-- { id = 0x00, ver = 0x0CFE, bs = false, name = "爆裂アッパー", },
		{ id = 0x06, ver = 0x0600, bs = true , name = "ハリケーンアッパー", },
		{ id = 0x07, ver = 0x0600, bs = true , name = "爆裂ハリケーン", },
		{ id = 0x10, ver = 0x0600, bs = false, name = "スクリューアッパー", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "サンダーファイヤー(C)", },
		{ id = 0x13, ver = 0x0600, bs = false, name = "サンダーファイヤー(D)", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント ハリケーンアッパー", },
		{ id = 0x47, ver = 0x0600, bs = false, name = "フェイント スラッシュキック", },
	},
	-- 不知火舞
	{
		{ cmd = cmd_base._4a     , bs = false, name = "龍の舞", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "花蝶扇", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "龍炎舞", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "小夜千鳥", },
		{ id = 0x04, ver = 0x0600, bs = true , name = "必殺忍蜂", },
		-- { id = 0x05, ver = 0x0600, bs = false, name = "ムササビの舞", },
		{ id = 0x10, ver = 0x0600, bs = false, name = "超必殺忍蜂", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "花嵐", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント 花蝶扇", },
		{ id = 0x47, ver = 0x0600, bs = false, name = "フェイント 花嵐", },
	},
	-- ギース・ハワード
	{
		{ cmd = cmd_base._3c     , bs = false, name = "虎殺掌", },
		{ cmd = cmd_base._3a     , bs = false, name = "昇天明星打ち", },
		{ cmd = cmd_base._6a     , bs = false, name = "飛燕失脚", },
		{ cmd = cmd_base._4b     , bs = false, name = "雷光回し蹴り", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "烈風拳", },
		{ id = 0x02, ver = 0x06FF, bs = true , name = "ダブル烈風拳", },
		{ id = 0x03, ver = 0x0600, bs = false, name = "上段当て身投げ", },
		{ id = 0x04, ver = 0x06FE, bs = false, name = "裏雲隠し", },
		{ id = 0x05, ver = 0x0600, bs = false, name = "下段当て身打ち", },
		{ id = 0x06, ver = 0x0600, bs = false, name = "雷鳴豪波投げ", },
		{ id = 0x07, ver = 0x06FD, bs = false, name = "真空投げ", throw = true, },
		{ id = 0x10, ver = 0x0600, bs = false, name = "レイジングストーム", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "羅生門", throw = true, },
		{ id = 0x13, ver = 0x0600, bs = true , name = "デッドリーレイブ", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント 烈風拳", },
		{ id = 0x47, ver = 0x0600, bs = false, name = "フェイント レイジングストーム", },
	},
	-- 望月双角
	{
		{ cmd = cmd_base._3a     , bs = false, name = "錫杖上段打ち", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "野猿狩り", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "まきびし", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "憑依弾", },
		{ id = 0x04, ver = 0x06FE, bs = false, name = "鬼門陣", throw = true, },
		{ id = 0x05, ver = 0x0CFF, bs = false, name = "邪棍舞", },
		{ id = 0x06, ver = 0x0600, bs = true , name = "喝", },
		{ id = 0x07, ver = 0x0600, bs = false, name = "渦炎陣", },
		{ id = 0x10, ver = 0x0600, bs = false, name = "いかづち", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "無惨弾", },
		{ id = 0x21, ver = 0x0600, bs = false, name = "雷撃棍", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント まきびし", },
		{ id = 0x47, ver = 0x0600, bs = false, name = "フェイント いかづち", },
	},
	-- ボブ・ウィルソン
	{
		{ cmd = cmd_base._3a     , bs = false, name = "エレファントタスク", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "ローリングタートル", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "サイドワインダー", },
		{ id = 0x03, ver = 0x0600, bs = false, name = "バイソンホーン", },
		{ id = 0x04, ver = 0x0602, bs = true , name = "ワイルドウルフ", },
		{ id = 0x05, ver = 0x0600, bs = true , name = "モンキーダンス", },
		{ id = 0x06, ver = 0x06FE, bs = false, name = "フロッグハンティング", },
		-- { id = 0x00, ver = 0x1EFF, bs = false, name = "ホーネットアタック", },
		{ id = 0x10, ver = 0x0600, bs = false, name = "デンジャラスウルフ", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "ダンシングバイソン", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント ダンシングバイソン", },
	},
	-- ホンフゥ
	{
		{ cmd = cmd_base._3a     , bs = false, name = "ハエタタキ", },
		{ cmd = cmd_base._6b     , bs = false, name = "踏み込み側蹴り", },
		{ id = 0x01, ver = 0x0600, bs = false, name = "九龍の読み", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "小 制空烈火棍", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "大 制空烈火棍", },
		{ id = 0x04, ver = 0x0600, bs = true , name = "電光石火の地", },
		--{ id = 0x00, ver = 0x0CFE, bs = false, name = "電光パチキ", },
		{ id = 0x05, ver = 0x0600, bs = true , name = "電光石火の天", },
		{ id = 0x06, ver = 0x0600, bs = false, name = "炎の種馬", },
		--{ id = 0x00, ver = 0x0CFF, bs = false, name = "炎の種馬連打", },
		{ id = 0x07, ver = 0x0600, bs = false, name = "必勝！逆襲拳", },
		{ id = 0x10, ver = 0x0600, bs = false, name = "爆発ゴロー", },
		{ id = 0x12, ver = 0x0600, bs = true , name = "よかトンハンマー", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント 制空烈火棍", },
	},
	-- ブルー・マリー
	{
		{ cmd = cmd_base._6b     , bs = false, name = "ヒールフォール", },
		{ cmd = cmd_base._4b     , bs = false, name = "ダブルローリング", },
		{ id = 0x01, ver = 0x06FF, bs = false, name = "M.スパイダー", },
		{ id = 0x02, ver = 0x06FE, bs = true , name = "M.スナッチャー", },
		{ id = 0x03, ver = 0x06FD, bs = false, name = "M.クラブクラッチ", },
		--{ id = 0x00, ver = 0x06FD, bs = false, name = "ダブルクラッチ", },
		{ id = 0x04, ver = 0x0600, bs = false, name = "M.リアルカウンター", },
		{ id = 0x05, ver = 0x0600, bs = true , name = "スピンフォール", },
		{ id = 0x06, ver = 0x0600, bs = true , name = "バーチカルアロー", },
		{ id = 0x07, ver = 0x0600, bs = true , name = "ストレートスライサー", },
		{ id = 0x09, ver = 0x0600, bs = false, name = "ヤングダイブ", },
		{ id = 0x08, ver = 0x06F9, bs = false, name = "M.ダイナマイトスウィング", },
		{ id = 0x10, ver = 0x0600, bs = false, name = "M.タイフーン", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "M.エスカレーション", },
		-- { id = 0x28, ver = 0x0600, bs = false, name = "M.トリプルエクスタシー", },
		-- { id = 0x24, ver = 0x0600, bs = false, name = "レッグプレス", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント M.スナッチャー", },
	},
	-- フランコ・バッシュ
	{
		{ cmd = cmd_base._6b     , bs = false, name = "バッシュトルネード", },
		{ cmd = cmd_base._bc     , bs = false, name = "バロムパンチ", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "ダブルコング", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "ザッパー", },
		{ id = 0x03, ver = 0x0600, bs = false, name = "ウェービングブロー", },
		{ id = 0x04, ver = 0x0600, bs = true , name = "ガッツダンク", },
		{ id = 0x05, ver = 0x0600, bs = true , name = "ゴールデンボンバー", },
		{ id = 0x10, ver = 0x0600, bs = true , name = "ファイナルオメガショット", },
		{ id = 0x11, ver = 0x0600, bs = false, name = "メガトンスクリュー", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "ハルマゲドンバスター", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント ハルマゲドンバスター", },
		{ id = 0x47, ver = 0x0600, bs = false, name = "フェイント ガッツダンク", },
	},
	-- 山崎竜二
	{
		{ cmd = cmd_base._6a     , bs = false, name = "ブッ刺し", },
		{ cmd = cmd_base._3a     , bs = false, name = "昇天", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "蛇使い・上段", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "蛇使い・中段", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "蛇使い・下段", },
		{ id = 0x04, ver = 0x0600, bs = false, name = "サドマゾ", },
		{ id = 0x05, ver = 0x0600, bs = false, name = "ヤキ入れ", },
		{ id = 0x06, ver = 0x0600, bs = false, name = "倍返し", },
		{ id = 0x07, ver = 0x0600, bs = true , name = "裁きの匕首", },
		{ id = 0x08, ver = 0x0600, bs = false, name = "爆弾パチキ", throw = true, },
		{ id = 0x09, ver = 0x0C00, bs = false, name = "トドメ", },
		{ id = 0x10, ver = 0x0600, bs = false, name = "ギロチン", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "ドリル", throw = true, },
		-- { id = 0x00, ver = 0x06FE, bs = false, name = "ドリル Lv.5", },
		-- { id = 0x00, ver = 0x06FF, bs = false, name = "?", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント 裁きの匕首", },
	},
	-- 秦崇秀
	{
		{ cmd = cmd_base._6a     , bs = false, name = "光輪殺", },
		{ id = 0x01, ver = 0x0600, bs = false, name = "帝王神足拳", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "小 帝王天眼拳", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "大 帝王天眼拳", },
		{ id = 0x04, ver = 0x0600, bs = true , name = "小 帝王天耳拳", },
		{ id = 0x05, ver = 0x0600, bs = true , name = "大 帝王天耳拳", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント 海龍照臨", },
		{ id = 0x06, ver = 0x0600, bs = false, name = "竜灯掌", },
		{ id = 0x07, ver = 0x0600, bs = true , name = "帝王神眼拳（その場）", },
		{ id = 0x08, ver = 0x06FF, bs = true , name = "帝王神眼拳（空中）", },
		{ id = 0x09, ver = 0x0600, bs = true , name = "帝王神眼拳（背後）", },
		-- { id = 0x0A, ver = 0x0600, bs = false, name = "帝王空殺神眼拳", },
		{ id = 0x10, ver = 0x0600, bs = true , name = "帝王漏尽拳", },
		-- { id = 0x11, ver = 0x0600, bs = false, name = "帝王空殺漏尽拳", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "海龍照臨", },
	},
	-- 秦崇雷,
	{
		{ cmd = cmd_base._6b     , bs = false, name = "龍殺脚", },
		{ id = 0x01, ver = 0x0600, bs = false, name = "帝王神足拳", },
		{ id = 0x01, ver = 0x06FF, bs = false, name = "真 帝王神足拳", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "小 帝王天眼拳", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "大 帝王天眼拳", },
		{ id = 0x04, ver = 0x0600, bs = true , name = "小 帝王天耳拳", },
		{ id = 0x05, ver = 0x0600, bs = true , name = "大 帝王天耳拳", },
		{ id = 0x06, ver = 0x0600, bs = true , name = "帝王漏尽拳", },
		{ id = 0x07, ver = 0x0600, bs = false, name = "龍転身（前方）", },
		{ id = 0x08, ver = 0x0600, bs = false, name = "龍転身（後方）", },
		{ id = 0x10, ver = 0x06FF, bs = false, name = "帝王宿命拳", },
		--{ id = 0x00, ver = 0x06FE, bs = false, name = "帝王宿命拳(連射)", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "帝王龍声拳", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント 帝王宿命拳", },
	},
	-- ダック・キング
	{
		{ cmd = cmd_base._3b     , bs = false, name = "ニードルロー", },
		{ cmd = cmd_base._4a     , bs = false, name = "マッドスピンハンマー", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "小ヘッドスピンアタック", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "大ヘッドスピンアタック", },
		-- { id = 0x02, ver = 0x06FF, bs = true , name = "大ヘッドスピンアタック", },
		-- { id = 0x00, ver = 0x06FF, bs = false, name = "ヘッドスピンアタック追撃", },
		{ id = 0x03, ver = 0x0600, bs = false, name = "フライングスピンアタック", },
		{ id = 0x04, ver = 0x0600, bs = true , name = "ダンシングダイブ", },
		{ id = 0x00, ver = 0x06FE, bs = false, name = "リバースダイブ", },
		{ id = 0x05, ver = 0x06FE, bs = false, name = "ブレイクストーム", },
		-- { id = 0x00, ver = 0x06FD, bs = false, name = "ブレイクストーム追撃1段階目", },
		-- { id = 0x00, ver = 0x06FC, bs = false, name = "ブレイクストーム追撃2段階目", },
		-- { id = 0x00, ver = 0x06FB, bs = false, name = "ブレイクストーム追撃3段階目", },
		-- { id = 0x06, ver = 0x0600, bs = false, name = "ダックフェイント・空", },
		-- { id = 0x07, ver = 0x0600, bs = false, name = "ダックフェイント・地", },
		{ id = 0x08, ver = 0x0600, bs = false, name = "クロスヘッドスピン", },
		{ id = 0x09, ver = 0x0600, bs = false, name = "ダンシングキャリバー", },
		{ id = 0x0A, ver = 0x0600, bs = false, name = "ローリングパニッシャー", },
		{ id = 0x0C, ver = 0x0600, bs = false, name = "ブレイクハリケーン", },
		{ id = 0x10, ver = 0x0600, bs = false, name = "ブレイクスパイラル", throw = true, },
		--{ id = 0x11, ver = 0x06FA, bs = false, name = "ブレイクスパイラルBR", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "ダックダンス", },
		--{ id = 0x00, ver = 0x06F8, bs = false, name = "ダックダンス継続", },
		{ id = 0x13, ver = 0x0600, bs = false, name = "スーパーポンピングマシーン", },
		-- { id = 0x00, ver = 0x06F9, bs = false, name = "ダイビングパニッシャー?", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント ダックダンス", },
		-- { id = 0x28, ver = 0x0600, bs = false, name = "旧ブレイクストーム", },
	},
	-- キム・カッファン
	{
		{ cmd = cmd_base._6b     , bs = false, name = "ネリチャギ", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "飛燕斬・真上", },
		{ id = 0x01, ver = 0x0601, bs = true , name = "飛燕斬・前方", },
		{ id = 0x01, ver = 0x0602, bs = true , name = "飛燕斬・後方", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "小 半月斬", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "大 半月斬", },
		{ id = 0x04, ver = 0x0800, bs = false, name = "飛翔脚", },
		-- { id = 0x00, ver = 0x08FF, bs = false, name = "戒脚", },
		{ id = 0x05, ver = 0x0600, bs = false, name = "空砂塵", },
		{ id = 0x00, ver = 0x06FE, bs = false, name = "天昇斬", },
		{ id = 0x06, ver = 0x0600, bs = true , name = "覇気脚", },
		-- { id = 0x10, ver = 0x0600, bs = false, name = "鳳凰天舞脚", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "鳳凰脚", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント 鳳凰脚", },
	},
	-- ビリー・カーン
	{
		{ cmd = cmd_base._3c     , bs = false, name = "地獄落とし", },
		{ id = 0x01, ver = 0x0600, bs = false, name = "三節棍中段打ち", },
		-- { id = 0x00, ver = 0x06FF, bs = false, name = "火炎三節棍中段突き", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "雀落とし", },
		{ id = 0x04, ver = 0x0C00, bs = false, name = "旋風棍", },
		{ id = 0x05, ver = 0x0600, bs = true , name = "強襲飛翔棍", },
		{ id = 0x06, ver = 0x0600, bs = true , name = "火龍追撃棍", },
		{ id = 0x10, ver = 0x0600, bs = false, name = "超火炎旋風棍", },
		{ id = 0x11, ver = 0x0600, bs = false, name = "紅蓮殺棍", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "サラマンダーストリーム", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント 強襲飛翔棍", },
	},
	-- チン・シンザン
	{
		{ cmd = cmd_base._6a     , bs = false, name = "落撃双拳", },
		{ cmd = cmd_base._4a     , bs = false, name = "発勁裏拳", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "気雷砲（前方）", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "気雷砲（対空）", },
		{ id = 0x03, ver = 0x0600, bs = false, name = "超太鼓腹打ち", },
		-- { id = 0x00, ver = 0x06FF, bs = false, name = "満腹対空", },
		{ id = 0x04, ver = 0x0600, bs = true , name = "小 破岩撃", },
		{ id = 0x05, ver = 0x0600, bs = true , name = "大 破岩撃", },
		{ id = 0x06, ver = 0x0600, bs = false, name = "軟体オヤジ", },
		{ id = 0x07, ver = 0x0600, bs = false, name = "クッサメ砲", },
		{ id = 0x10, ver = 0x0600, bs = true , name = "爆雷砲", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "ホエホエ弾", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント 破岩撃", },
		{ id = 0x47, ver = 0x0600, bs = false, name = "フェイント クッサメ砲", },
	},
	-- タン・フー・ルー,
	{
		{ cmd = cmd_base._3a     , bs = false, name = "右降龍", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "衝波", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "小 箭疾歩", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "大 箭疾歩", },
		{ id = 0x04, ver = 0x0600, bs = false, name = "撃放", },
		{ id = 0x05, ver = 0x0600, bs = true , name = "裂千脚", },
		{ id = 0x10, ver = 0x0600, bs = false, name = "旋風剛拳", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "大撃放", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント 旋風剛拳", },
	},
	-- ローレンス・ブラッド
	{
		{ cmd = cmd_base._6b     , bs = false, name = "トルネードキック", },
		{ cmd = cmd_base._bc     , bs = false, name = "オーレィ", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "小 ブラッディスピン", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "大 ブラッディスピン", },
		{ id = 0x03, ver = 0x0600, bs = false, name = "ブラッディサーベル", },
		{ id = 0x04, ver = 0x06FF, bs = false, name = "ブラッディミキサー", },
		{ id = 0x05, ver = 0x0600, bs = true , name = "ブラッディカッター", },
		{ id = 0x10, ver = 0x0600, bs = false, name = "ブラッディフラッシュ", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "ブラッディシャドー", },
	},
	-- ヴォルフガング・クラウザー
	{
		{ cmd = cmd_base._6a     , bs = false, name = "デスハンマー", },
		{ id = 0x01, ver = 0x0600, bs = false, name = "ブリッツボール・上段", },
		{ id = 0x02, ver = 0x06FF, bs = false, name = "ブリッツボール・下段", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "レッグトマホーク", },
		{ id = 0x04, ver = 0x0600, bs = false, name = "フェニックススルー", throw = true, },
		{ id = 0x05, ver = 0x0600, bs = false, name = "デンジャラススルー", throw = true, },
		-- { id = 0x00, ver = 0x06FD, bs = false, name = "グリフォンアッパー", },
		{ id = 0x06, ver = 0x06FC, bs = false, name = "カイザークロー", },
		{ id = 0x07, ver = 0x0600, bs = false, name = "リフトアップブロー", },
		{ id = 0x10, ver = 0x0600, bs = true , name = "カイザーウェイブ", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "ギガティックサイクロン", throw = true, },
		{ id = 0x13, ver = 0x0600, bs = false, name = "アンリミテッドデザイア", },
		-- { id = 0x00, ver = 0x06FE, bs = false, name = "アンリミテッドデザイア2", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント ブリッツボール", },
		{ id = 0x47, ver = 0x0600, bs = false, name = "フェイント カイザーウェイブ", },
	},
	-- リック・ストラウド
	{
		{ cmd = cmd_base._6a     , bs = false, name = "チョッピングライト", },
		{ cmd = cmd_base._3a     , bs = false, name = "スマッシュソード", },
		--{ id = 0x28, ver = 0x0600, bs = true , name = "?", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "小 シューティングスター", },
		{ id = 0x02, ver = 0x06FF, bs = false, name = "大 シューティングスター", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "ディバインブラスト", },
		{ id = 0x04, ver = 0x0600, bs = false, name = "フルムーンフィーバー", },
		{ id = 0x05, ver = 0x0600, bs = true , name = "ヘリオン", },
		{ id = 0x06, ver = 0x0600, bs = true , name = "ブレイジングサンバースト", },
		-- { id = 0x09, ver = 0x0600, bs = false, name = "?", },
		{ id = 0x10, ver = 0x0600, bs = false, name = "ガイアブレス", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "ハウリング・ブル", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント シューティングスター", },
	},
	-- 李香緋
	{
		{ cmd = cmd_base._6a     , bs = false, name = "裡門頂肘", },
		{ cmd = cmd_base._4b     , bs = false, name = "後捜腿", },
		--{ id = 0x28, ver = 0x0600, bs = true , name = "?", },
		--{ id = 0x29, ver = 0x0600, bs = true , name = "?", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "小 那夢波", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "大 那夢波", },
		{ id = 0x03, ver = 0x06FF, bs = false, name = "閃里肘皇", },
		{ id = 0x00, ver = 0x06FE, bs = false, name = "閃里肘皇・心砕把", },
		{ id = 0x06, ver = 0x0600, bs = true , name = "天崩山", },
		{ id = 0x07, ver = 0x0600, bs = true , name = "詠酒・対ジャンプ攻撃", },
		{ id = 0x08, ver = 0x0600, bs = true , name = "詠酒・対立ち攻撃", },
		{ id = 0x09, ver = 0x0600, bs = true , name = "詠酒・対しゃがみ攻撃", },
		{ id = 0x10, ver = 0x0600, bs = true , name = "大鉄神", },
		{ id = 0x11, ver = 0x06FD, bs = false, name = "超白龍", },
		-- { id = 0x00, ver = 0x06FD, bs = false, name = "超白龍2", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "真心牙", throw = true, },
		{ id = 0x47, ver = 0x0600, bs = false, name = "フェイント 天崩山", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント 大鉄神", },
	},
	-- アルフレッド
	{
		{ cmd = cmd_base._6b     , bs = false, name = "フロントステップキック", },
		{ cmd = cmd_base._4b     , bs = false, name = "飛び退きキック", },
		{ id = 0x01, ver = 0x0600, bs = true , name = "小 クリティカルウィング", },
		{ id = 0x02, ver = 0x0600, bs = true , name = "大 クリティカルウィング", },
		{ id = 0x03, ver = 0x0600, bs = true , name = "オーグメンターウィング", },
		{ id = 0x04, ver = 0x0600, bs = true , name = "ダイバージェンス", },
		-- { id = 0x05, ver = 0x0600, bs = false, name = "メーデーメーデー", },
		{ id = 0x06, ver = 0x0600, bs = false, name = "S.TOL", },
		--{ id = 0x10, ver = 0x0600, bs = false, name = "ショックストール", },
		{ id = 0x12, ver = 0x0600, bs = false, name = "ウェーブライダー", },
		{ id = 0x46, ver = 0x0600, bs = false, name = "フェイント クリティカルウィング", },
		{ id = 0x47, ver = 0x0600, bs = false, name = "フェイント オーグメンターウィング", },
	},
}
-- ブレイクショット対応技のみ
local char_bs_list = {}
for _, list in pairs(char_rvs_list) do
	for i, cmd in pairs(common_rvs) do
		table.insert(list, i, cmd)
	end
	local bs_list = {}
	for _, cmd in pairs(list) do
		if cmd.bs then
			table.insert(bs_list, cmd)
		end
	end
	table.insert(char_bs_list, bs_list)
end

local get_next_counter          = function(targets, p, excludes)
	local ex, list, len = excludes or {}, {}, 0
	for _, rvs in ipairs(targets) do
		if not ex[rvs] then
			len = len + 1
			table.insert(list, rvs)
		end
	end
	if len == 0 then
		return nil
	elseif len == 1 then
		return list[1]
	else
		return list[math.random(len)]
	end
end

local get_next_rvs              = function(p, excludes)
	local i = p.addr.base == 0x100400 and 1 or 2
	local rvs_menu = menu.rvs_menus[i][p.char]
	if not rvs_menu then
		return nil
	end
	p.dummy_rvs_list = {}
	for j, rvs in pairs(char_rvs_list[p.char]) do
		if rvs_menu.pos.col[j + 1] == 2 then
			table.insert(p.dummy_rvs_list, rvs)
		end
	end

	local ret = get_next_counter(p.dummy_rvs_list, p, excludes)
	--printf("get_next_rvs %x %s %s", p.addr.base, ret == nil and "" or ret.name, #p.dummy_rvs_list)
	return ret
end

local get_next_bs               = function(p, excludes)
	local i = p.addr.base == 0x100400 and 1 or 2
	local bs_menu = menu.bs_menus[i][p.char]
	if not bs_menu then
		return nil
	end
	p.dummy_bs_list = {}
	for j, bs in pairs(char_bs_list[p.char]) do
		if bs_menu.pos.col[j + 1] == 2 then
			table.insert(p.dummy_bs_list, bs)
		end
	end

	local ret = get_next_counter(p.dummy_bs_list, p, excludes)
	return ret
end
-- エミュレータ本体の入力取得
local joyk                      = {
	p1 = {
		dn = "P1 Down",  -- joyk.p1.dn
		lt = "P1 Left",  -- joyk.p1.lt
		rt = "P1 Right", -- joyk.p1.rt
		up = "P1 Up",    -- joyk.p1.up
		a  = "P1 A",     -- joyk.p1.a
		b  = "P1 B",     -- joyk.p1.b
		c  = "P1 C",     -- joyk.p1.c
		d  = "P1 D",     -- joyk.p1.d
		st = "1 Player Start", -- joyk.p1.st
	},
	p2 = {
		dn = "P2 Down",   -- joyk.p2.dn
		lt = "P2 Left",   -- joyk.p2.lt
		rt = "P2 Right",  -- joyk.p2.rt
		up = "P2 Up",     -- joyk.p2.up
		a  = "P2 A",      -- joyk.p2.a
		b  = "P2 B",      -- joyk.p2.b
		c  = "P2 C",      -- joyk.p2.c
		d  = "P2 D",      -- joyk.p2.d
		st = "2 Players Start", -- joyk.p2.st
	},
}
local use_joy                   = {
	{ port = ":edge:joy:JOY1",  field = joyk.p1.a,  frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1",  field = joyk.p1.b,  frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1",  field = joyk.p1.c,  frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1",  field = joyk.p1.d,  frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1",  field = joyk.p1.dn, frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1",  field = joyk.p1.lt, frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1",  field = joyk.p1.rt, frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1",  field = joyk.p1.up, frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joyk.p2.a,  frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joyk.p2.b,  frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joyk.p2.c,  frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joyk.p2.d,  frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joyk.p2.dn, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joyk.p2.lt, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joyk.p2.rt, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2",  field = joyk.p2.up, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:START", field = joyk.p2.st, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:START", field = joyk.p1.st, frame = 0, prev = 0, player = 1, get = 0, },
}
local get_joy_base              = function(prev, exclude_player)
	-- for pname, port in pairs(ioports) do
	-- 	for fname, field in pairs(port.fields) do
	-- 		printf("%s %s", pname, fname)
	-- 	end
	-- end
	local ec = scr:frame_number()
	local joy_port = {}
	local joy_val = {}
	local prev_joy_val = {}
	for _, joy in ipairs(use_joy) do
		local state = 0
		if not joy_port[joy.port] then
			joy_port[joy.port] = ioports[joy.port]:read()
		end
		local field = ioports[joy.port].fields[joy.field]
		state = ((joy_port[joy.port] & field.mask) ~ field.defvalue)
		if joy.get < ec then
			joy.prev = joy.frame
			if state > 0 then
				-- on
				if joy.frame > 0 then
					joy.frame = joy.frame + 1
				else
					joy.frame = 1
				end
			else
				-- off
				if joy.frame < 0 then
					joy.frame = joy.frame - 1
				else
					joy.frame = -1
				end
			end
		end
		joy.get = ec
		if exclude_player ~= joy.player then
			joy_val[joy.field] = joy.frame
			prev_joy_val[joy.field] = joy.prev
		end
	end
	return prev and prev_joy_val or joy_val
end
local get_joy                   = function(exclude_player)
	return get_joy_base(false, exclude_player)
end
local accept_input              = function(btn, joy_val, state_past)
	if 12 < state_past then
		local p1 = btn == "Start" and "1 Player Start" or ("P1 " .. btn)
		local p2 = btn == "Start" and "2 Players Start" or ("P2 " .. btn)
		if btn == "Up" or btn == "Down" or btn == "Right" or btn == "Left" then
			if (0 < joy_val[p1]) or (0 < joy_val[p2]) then
				pgm:write_u32(0x0010D612, 0x00600004)
				pgm:write_u8(0x0010D713, 0x01)
				return true
			end
		else
			if (0 < joy_val[p1] and state_past >= joy_val[p1]) or
				(0 < joy_val[p2] and state_past >= joy_val[p2]) then
				if global.disp_replay then
					pgm:write_u32(0x0010D612, 0x00610004)
					pgm:write_u8(0x0010D713, 0x01)
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
			local st = i == 1 and "1 Player Start" or "2 Players Start"
			if (35 < joy_val[st]) then
				pgm:write_u32(0x0010D612, 0x00610004)
				pgm:write_u8(0x0010D713, 0x01)
				return true
			end
		end
	end
	return false
end
local new_next_joy              = function()
	return {
		[joyk.p1.dn] = false,
		[joyk.p1.a] = false,
		[joyk.p2.dn] = false,
		[joyk.p2.a] = false,
		[joyk.p1.lt] = false,
		[joyk.p1.b] = false,
		[joyk.p2.lt] = false,
		[joyk.p2.b] = false,
		[joyk.p1.rt] = false,
		[joyk.p1.c] = false,
		[joyk.p2.rt] = false,
		[joyk.p2.c] = false,
		[joyk.p1.up] = false,
		[joyk.p1.d] = false,
		[joyk.p2.up] = false,
		[joyk.p2.d] = false,
	}
end
-- 入力の1P、2P反転用のテーブル
local rev_joy                   = {
	[joyk.p1.a] = joyk.p2.a,
	[joyk.p2.a] = joyk.p1.a,
	[joyk.p1.b] = joyk.p2.b,
	[joyk.p2.b] = joyk.p1.b,
	[joyk.p1.c] = joyk.p2.c,
	[joyk.p2.c] = joyk.p1.c,
	[joyk.p1.d] = joyk.p2.d,
	[joyk.p2.d] = joyk.p1.d,
	[joyk.p1.dn] = joyk.p2.dn,
	[joyk.p2.dn] = joyk.p1.dn,
	[joyk.p1.lt] = joyk.p2.lt,
	[joyk.p2.lt] = joyk.p1.lt,
	[joyk.p1.rt] = joyk.p2.rt,
	[joyk.p2.rt] = joyk.p1.rt,
	[joyk.p1.up] = joyk.p2.up,
	[joyk.p2.up] = joyk.p1.up,
}
-- 入力から1P、2Pを判定するテーブル
local joy_pside                 = {
	[joyk.p1.dn] = 1,
	[joyk.p1.a] = 1,
	[joyk.p2.dn] = 2,
	[joyk.p2.a] = 2,
	[joyk.p1.lt] = 1,
	[joyk.p1.b] = 1,
	[joyk.p2.lt] = 2,
	[joyk.p2.b] = 2,
	[joyk.p1.rt] = 1,
	[joyk.p1.c] = 1,
	[joyk.p2.rt] = 2,
	[joyk.p2.c] = 2,
	[joyk.p1.up] = 1,
	[joyk.p1.d] = 1,
	[joyk.p2.up] = 2,
	[joyk.p2.d] = 2,
}
-- 入力の左右反転用のテーブル
local joy_frontback             = {
	[joyk.p1.lt] = joyk.p1.rt,
	[joyk.p2.lt] = joyk.p2.rt,
	[joyk.p1.rt] = joyk.p1.lt,
	[joyk.p2.rt] = joyk.p2.lt,
}
-- MAMEへの入力の無効化
local cls_joy                   = function()
	for _, joy in ipairs(use_joy) do
		ioports[joy.port].fields[joy.field]:set_value(0)
	end
end

-- キー入力
local kprops                    = { "d", "c", "b", "a", "rt", "lt", "dn", "up", "sl", "st", }
local posi_or_pl1               = function(v) return 0 <= v and v + 1 or 1 end
local nega_or_mi1               = function(v) return 0 >= v and v - 1 or -1 end

-- ポーズ
local set_freeze                = function(frz_expected)
	local dswport = ioports[":DSW"]
	local fzfld = dswport.fields["Freeze"]
	local freez = ((dswport:read() & fzfld.mask) ~ fzfld.defvalue) <= 0

	if mem._0x10FD82 ~= 0x00 then
		if freez ~= frz_expected then
			fzfld:set_value(global.frz[global.frzc])
			global.frzc = global.frzc + 1
			if global.frzc > #global.frz then
				global.frzc = 1
			end
		end
	else
		pgm:write_u8(0x1041D2, frz_expected and 0x00 or 0xFF)
	end
end
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
	local a0, a1, d0, d1 = nil, 0x04B746, p.input1, p.cln_btn
	d1 = 0xFFFF & (d1 * 8)
	d0 = d0 + d1
	d1 = p.char_4times
	a1 = a1 + d1
	a0 = pgm:read_u32(a1) + d0
	d1 = pgm:read_u8(a0)
	d1 = 0xFFFF & (d1 * 4)
	a1 = 0x26444
	a1 = a1 + d1
	a0 = pgm:read_u32(a1)
	return a0
end

-- 当たり判定
local type_ck_push              = function(obj, box)
	obj.height = obj.height or box.bottom - box.top --used for height of ground throwbox
end
local type_ck_vuln              = function(obj, box) if not obj.vulnerable then return true end end
local type_ck_gd                = function(obj, box) end
local type_ck_atk               = function(obj, box) if obj.harmless then return true end end
local type_ck_thw               = function(obj, box) if obj.harmless then return true end end
local type_ck_und               = function(obj, box)
	--printf("%x, unk box id: %x", obj.base, box.id) --debug
end
local box_types                 = {
	atemi = "atemi",
	attack = "attack",
	block = "block",
	push = "push",
	throw = "throw",
	unknown = "unkown",
	vuln = "vuln",
}
local box_type_base             = {
	a    = { id = 0x00, enabled = true, type_check = type_ck_atk, type = box_types.attack, sort = 4, color = 0xFF00FF, fill = 0x40, outline = 0xFF, sway = false, name = "攻撃", },
	fa   = { id = 0x00, enabled = false, type_check = type_ck_und, type = box_types.attack, sort = 4, color = 0x00FF00, fill = 0x00, outline = 0xFF, sway = false, name = "攻撃(嘘)", },
	da   = { id = 0x00, enabled = true, type_check = type_ck_und, type = box_types.attack, sort = 4, color = 0xFF00FF, fill = 0x00, outline = 0xFF, sway = false, name = "攻撃(無効)", },
	aa   = { id = 0x00, enabled = true, type_check = type_ck_atk, type = box_types.attack, sort = 4, color = 0xFF0033, fill = 0x40, outline = 0xFF, sway = false, name = "攻撃(空中追撃可)", },
	faa  = { id = 0x00, enabled = false, type_check = type_ck_und, type = box_types.attack, sort = 4, color = 0x00FF33, fill = 0x00, outline = 0xFF, sway = false, name = "攻撃(嘘、空中追撃可)", },
	daa  = { id = 0x00, enabled = true, type_check = type_ck_und, type = box_types.attack, sort = 4, color = 0xFF0033, fill = 0x00, outline = 0xFF, sway = false, name = "攻撃(無効、空中追撃可)", },
	t3   = { id = 0x00, enabled = true, type_check = type_ck_thw, type = box_types.throw, sort = -1, color = 0x8B4513, fill = 0x40, outline = 0xFF, sway = false, name = "未使用", },
	pa   = { id = 0x00, enabled = true, type_check = type_ck_atk, type = box_types.attack, sort = 5, color = 0xFF00FF, fill = 0x40, outline = 0xFF, sway = false, name = "飛び道具", },
	pfa  = { id = 0x00, enabled = true, type_check = type_ck_atk, type = box_types.attack, sort = 5, color = 0x00FF00, fill = 0x00, outline = 0xFF, sway = false, name = "飛び道具(嘘)", },
	pda  = { id = 0x00, enabled = true, type_check = type_ck_atk, type = box_types.attack, sort = 5, color = 0xFF00FF, fill = 0x00, outline = 0xFF, sway = false, name = "飛び道具(無効)", },
	paa  = { id = 0x00, enabled = true, type_check = type_ck_atk, type = box_types.attack, sort = 5, color = 0xFF0033, fill = 0x40, outline = 0xFF, sway = false, name = "飛び道具(空中追撃可)", },
	pfaa = { id = 0x00, enabled = true, type_check = type_ck_atk, type = box_types.attack, sort = 5, color = 0x00FF33, fill = 0x00, outline = 0xFF, sway = false, name = "飛び道具(嘘、空中追撃可)", },
	pdaa = { id = 0x00, enabled = true, type_check = type_ck_atk, type = box_types.attack, sort = 5, color = 0xFF0033, fill = 0x00, outline = 0xFF, sway = false, name = "飛び道具(無効、空中追撃可)", },
	t    = { id = 0x00, enabled = true, type_check = type_ck_thw, type = box_types.throw, sort = 6, color = 0xFFFF00, fill = 0x40, outline = 0xFF, sway = false, name = "投げ", },
	at   = { id = 0x00, enabled = true, type_check = type_ck_thw, type = box_types.throw, sort = 6, color = 0xFFFF00, fill = 0x40, outline = 0xFF, sway = false, name = "必殺技投げ", },
	pt   = { id = 0x00, enabled = true, type_check = type_ck_thw, type = box_types.throw, sort = 6, color = 0xFFFF00, fill = 0x40, outline = 0xFF, sway = false, name = "空中投げ", },
	p    = { id = 0x01, enabled = true, type_check = type_ck_push, type = box_types.push, sort = 1, color = 0xDDDDDD, fill = 0x00, outline = 0xFF, sway = false, name = "押し合い", },
	v1   = { id = 0x02, enabled = true, type_check = type_ck_vuln, type = box_types.vuln, sort = 2, color = 0x0000FF, fill = 0x40, outline = 0xFF, sway = false, name = "食らい1", },
	v2   = { id = 0x03, enabled = true, type_check = type_ck_vuln, type = box_types.vuln, sort = 2, color = 0x0000FF, fill = 0x40, outline = 0xFF, sway = false, name = "食らい2", },
	v3   = { id = 0x04, enabled = true, type_check = type_ck_vuln, type = box_types.vuln, sort = 2, color = 0x00FFFF, fill = 0x80, outline = 0xFF, sway = false, name = "食らい(ダウン追撃のみ可)", },
	v4   = { id = 0x05, enabled = true, type_check = type_ck_vuln, type = box_types.vuln, sort = 2, color = 0x00FFFF, fill = 0x80, outline = 0xFF, sway = false, name = "食らい(空中追撃のみ可)", },
	v5   = { id = 0x06, enabled = true, type_check = type_ck_vuln, type = box_types.vuln, sort = 2, color = 0x606060, fill = 0x40, outline = 0xFF, sway = false, name = "食らい5(未使用?)", },
	v6   = { id = 0x07, enabled = true, type_check = type_ck_vuln, type = box_types.vuln, sort = 2, color = 0x00FFFF, fill = 0x80, outline = 0xFF, sway = false, name = "食らい(対ライン上攻撃)", },
	x1   = { id = 0x08, enabled = true, type_check = type_ck_vuln, type = box_types.vuln, sort = 2, color = 0x00FFFF, fill = 0x80, outline = 0xFF, sway = false, name = "食らい(対ライン下攻撃)", },
	x2   = { id = 0x09, enabled = true, type_check = type_ck_und, type = box_types.unknown, sort = -1, color = 0x00FF00, fill = 0x40, outline = 0xFF, sway = false, name = "用途不明2", },
	x3   = { id = 0x0A, enabled = true, type_check = type_ck_und, type = box_types.unknown, sort = -1, color = 0x00FF00, fill = 0x40, outline = 0xFF, sway = false, name = "用途不明3", },
	x4   = { id = 0x0B, enabled = true, type_check = type_ck_und, type = box_types.unknown, sort = -1, color = 0x00FF00, fill = 0x40, outline = 0xFF, sway = false, name = "用途不明4", },
	x5   = { id = 0x0C, enabled = true, type_check = type_ck_und, type = box_types.unknown, sort = -1, color = 0x00FF00, fill = 0x40, outline = 0xFF, sway = false, name = "用途不明5", },
	x6   = { id = 0x0D, enabled = true, type_check = type_ck_und, type = box_types.unknown, sort = -1, color = 0x00FF00, fill = 0x40, outline = 0xFF, sway = false, name = "用途不明6", },
	x7   = { id = 0x0E, enabled = true, type_check = type_ck_und, type = box_types.unknown, sort = -1, color = 0x00FF00, fill = 0x40, outline = 0xFF, sway = false, name = "用途不明7", },
	x8   = { id = 0x0F, enabled = true, type_check = type_ck_und, type = box_types.unknown, sort = -1, color = 0x00FF00, fill = 0x40, outline = 0xFF, sway = false, name = "用途不明8", },
	x9   = { id = 0x10, enabled = true, type_check = type_ck_und, type = box_types.unknown, sort = -1, color = 0x00FF00, fill = 0x40, outline = 0xFF, sway = false, name = "用途不明9", },
	g1   = { id = 0x11, enabled = true, type_check = type_ck_gd, type = box_types.block, sort = 3, color = 0xC0C0C0, fill = 0x40, outline = 0xFF, sway = false, name = "立ガード", },
	g2   = { id = 0x12, enabled = true, type_check = type_ck_gd, type = box_types.block, sort = 3, color = 0xC0C0C0, fill = 0x40, outline = 0xFF, sway = false, name = "下段ガード", },
	g3   = { id = 0x13, enabled = true, type_check = type_ck_gd, type = box_types.block, sort = 3, color = 0xC0C0C0, fill = 0x40, outline = 0xFF, sway = false, name = "空中ガード", },
	g4   = { id = 0x14, enabled = true, type_check = type_ck_gd, type = box_types.atemi, sort = 3, color = 0xFF7F00, fill = 0x40, outline = 0xFF, sway = false, name = "上段当身投げ", },
	g5   = { id = 0x15, enabled = true, type_check = type_ck_gd, type = box_types.atemi, sort = 3, color = 0xFF7F00, fill = 0x40, outline = 0xFF, sway = false, name = "裏雲隠し", },
	g6   = { id = 0x16, enabled = true, type_check = type_ck_gd, type = box_types.atemi, sort = 3, color = 0xFF7F00, fill = 0x40, outline = 0xFF, sway = false, name = "下段当身打ち", },
	g7   = { id = 0x17, enabled = true, type_check = type_ck_gd, type = box_types.atemi, sort = 3, color = 0xFF7F00, fill = 0x40, outline = 0xFF, sway = false, name = "必勝逆襲拳", },
	g8   = { id = 0x18, enabled = true, type_check = type_ck_gd, type = box_types.atemi, sort = 3, color = 0xFF7F00, fill = 0x40, outline = 0xFF, sway = false, name = "サドマゾ", },
	g9   = { id = 0x19, enabled = true, type_check = type_ck_gd, type = box_types.atemi, sort = 3, color = 0xFF007F, fill = 0x40, outline = 0xFF, sway = false, name = "倍返し", },
	g12  = { id = 0x1A, enabled = true, type_check = type_ck_und, type = box_types.block, sort = -1, color = 0x006400, fill = 0x40, outline = 0xFF, sway = false, name = "ガード?1", },
	g11  = { id = 0x1B, enabled = true, type_check = type_ck_und, type = box_types.block, sort = -1, color = 0x006400, fill = 0x40, outline = 0xFF, sway = false, name = "ガード?2", },
	g10  = { id = 0x1C, enabled = true, type_check = type_ck_gd, type = box_types.atemi, sort = 3, color = 0xFF7F00, fill = 0x40, outline = 0xFF, sway = false, name = "フェニックススルー", },
	g13  = { id = 0x1D, enabled = true, type_check = type_ck_und, type = box_types.block, sort = -1, color = 0x006400, fill = 0x40, outline = 0xFF, sway = false, name = "ガード?4", },
	g14  = { id = 0x1E, enabled = true, type_check = type_ck_gd, type = box_types.block, sort = -1, color = 0x006400, fill = 0x40, outline = 0xFF, sway = false, name = "ガード?5", },
	g15  = { id = 0x1F, enabled = true, type_check = type_ck_und, type = box_types.block, sort = -1, color = 0x006400, fill = 0x40, outline = 0xFF, sway = false, name = "ガード?6", },
	g16  = { id = 0x20, enabled = true, type_check = type_ck_und, type = box_types.block, sort = -1, color = 0x006400, fill = 0x40, outline = 0xFF, sway = false, name = "ガード?7", },
	sv1  = { id = 0x02, enabled = true, type_check = type_ck_vuln, type = box_types.vuln, sort = 2, color = 0x7FFF00, fill = 0x40, outline = 0xFF, sway = true, name = "食らい1(スウェー中)", },
	sv2  = { id = 0x03, enabled = true, type_check = type_ck_vuln, type = box_types.vuln, sort = 2, color = 0x7FFF00, fill = 0x40, outline = 0xFF, sway = true, name = "食らい2(スウェー中)", },
}
local box_types, sway_box_types = {}, {}
for _, boxtype in pairs(box_type_base) do
	if 0 < boxtype.id then
		if boxtype.sway then
			sway_box_types[boxtype.id - 1] = boxtype
		else
			box_types[boxtype.id - 1] = boxtype
		end
	end
	boxtype.fill    = (0xFFFFFFFF & (boxtype.fill << 24)) | boxtype.color
	boxtype.outline = (0xFFFFFFFF & (boxtype.outline << 24)) | boxtype.color
end
local attack_boxies = new_set(
	box_type_base.a, -- 攻撃
	box_type_base.pa, -- 飛び道具
	box_type_base.da, -- 攻撃(無効)
	box_type_base.pda, -- 飛び道具(無効)
	box_type_base.aa, -- 攻撃(空中追撃可)
	box_type_base.paa, -- 飛び道具(空中追撃可)
	box_type_base.daa, -- 攻撃(無効、空中追撃可)
	box_type_base.pdaa, -- 飛び道具(無効、空中追撃可)
	box_type_base.t, -- 通常投げ
	box_type_base.at, -- 空中投げ
	box_type_base.pt) -- 必殺技投げ

-- ボタンの色テーブル
local btn_col = { [convert("_A")] = 0xFFCC0000, [convert("_B")] = 0xFFCC8800, [convert("_C")] = 0xFF3333CC, [convert("_D")] = 0xFF336600, }
local text_col, shadow_col = 0xFFFFFFFF, 0xFF000000

local is_dir = function(name)
	if type(name) ~= "string" then return false end
	local cd = lfs.currentdir()
	local is = lfs.chdir(name) and true or false
	lfs.chdir(cd)
	return is
end
local mkdir = function(path)
	if is_dir(path) then
		return true, nil
	end
	local r, err = lfs.mkdir(path)
	if not r then
		print(err)
	end
	return r, err
end
local is_file = function(name)
	if type(name) ~= "string" then return false end
	local f = io.open(name, "r")
	if f then
		f:close()
		return true
	end
	return false
end

local rom_patch_path = function(filename)
	local base = base_path() .. '/rom-patch/'
	local patch = base .. emu.romname() .. '/' .. filename
	if is_file(patch) then
		return patch
	else
		print(patch .. " NOT found")
	end
	return base .. 'rbff2/' .. filename
end

local ram_patch_path = function(filename)
	local base = base_path() .. '/ram-patch/'
	local patch = base .. emu.romname() .. '/' .. filename
	if is_file(patch) then
		return patch
	end
	return base .. 'rbff2/' .. filename
end

local tohex = function(num)
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

local tohexnum = function(num)
	return tonumber(tohex(num))
end

-- tableで返す
local tobits = function(num)
	-- returns a table of bits, least significant first.
	local t, rest = {}, 0 -- will contain the bits
	while num > 0 do
		rest = math.fmod(num, 2)
		table.insert(t, rest)
		num = (num - rest) / 2
	end
	return t
end

local testbit = function(target, hex)
	local ret = (target & hex) ~= 0
	return ret
end

local get_digit = function(num)
	return string.len(tostring(num))
end

-- 16ビット値を0.999上限の数値に変える
local int16tofloat = function(int16v)
	if int16v and type(int16v) == "number" then
		return int16v / 0x10000
	end
	return 0
end

local draw_rtext = function(x, y, str, fgcol, bgcol)
	if not str then
		return
	end
	if type(str) ~= "string" then
		str = string.format("%s", str)
	end
	local xx = -man.ui:get_string_width(str, scr.xscale * scr.height)
	scr:draw_text(x + xx, y, str, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
	return xx
end

local draw_text_with_shadow = function(x, y, str, fgcol, bgcol)
	if type(str) ~= "string" then
		str = string.format("%s", str)
	end
	scr:draw_text(x + 0.5, y + 0.5, str, shadow_col, bgcol or 0x00000000)
	scr:draw_text(x, y, str, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
	return man.ui:get_string_width(str, scr.xscale * scr.height)
end

local draw_rtext_with_shadow = function(x, y, str, fgcol, bgcol)
	draw_rtext(x + 0.5, y + 0.5, str, shadow_col, bgcol)
	return draw_rtext(x, y, str, fgcol, bgcol)
end

local draw_fmt_rtext = function(x, y, fmt, dec)
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
local draw_cmd = function(p, line, frame, str)
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
local draw_base = function(p, line, frame, addr, act_name, xmov)
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
local bp_offset = {
	[0x012C42] = { ["rbff2k"] = 0x28, ["rbff2h"] = 0x00 },
	[0x012C88] = { ["rbff2k"] = 0x28, ["rbff2h"] = 0x00 },
	[0x012D4C] = { ["rbff2k"] = 0x28, ["rbff2h"] = 0x00 }, --p1 push
	[0x012D92] = { ["rbff2k"] = 0x28, ["rbff2h"] = 0x00 }, --p2 push
	[0x039F2A] = { ["rbff2k"] = 0x0C, ["rbff2h"] = 0x20 }, --special throws
	[0x017300] = { ["rbff2k"] = 0x28, ["rbff2h"] = 0x00 }, --solid shadows
}
local bp_clone = { ["rbff2k"] = -0x104, ["rbff2h"] = 0x20 }
local fix_bp_addr = function(addr)
	local fix1 = bp_clone[emu.romname()] or 0
	local fix2 = bp_offset[addr] and (bp_offset[addr][emu.romname()] or fix1) or fix1
	return addr + fix2
end
local hurt_inv_type = {
	-- 全身無敵
	full    = { type = 0, disp_label = "全身無敵", name = "全身無敵" },
	-- ライン関係の無敵
	main    = { type = 1, disp_label = "メイン攻撃無敵", name = "メインライン攻撃無敵" },
	sway_oh = { type = 1, disp_label = "対メイン上段無敵", name = "対メインライン上段攻撃無敵" },
	sway_lo = { type = 1, disp_label = "対メイン下段無敵", name = "対メインライン下段攻撃無敵" },
	-- やられ判定の高さ
	top32   = { type = 2, value = 32, disp_label = "上半身無敵1", name = "32 避け" },
	top40   = { type = 2, value = 40, disp_label = "上半身無敵2", name = "40 ウェービングブロー,龍転身,ダブルローリング" },
	top48   = { type = 2, value = 48, disp_label = "上半身無敵3", name = "48 ローレンス避け" },
	--[[
	top60 = { type = 2, value = 60, disp_label = "頭部無敵1", name = "60 屈 アンディ,東,舞,ホンフゥ,マリー,山崎,崇秀,崇雷,キム,ビリー,チン,タン"},
	top64 = { type = 2, value = 64, disp_label = "頭部無敵2", name = "64 屈 テリー,ギース,双角,ボブ,ダック,リック,シャンフェイ,アルフレッド"},
	top68 = { type = 2, value = 68, disp_label = "頭部無敵3", name = "68 屈 ローレンス"},
	top76 = { type = 2, value = 76, disp_label = "頭部無敵4", name = "76 屈 フランコ"},
	top80 = { type = 2, value = 80, disp_label = "頭部無敵5", name = "80 屈 クラウザー"},
	]]
	-- 足元無敵
	low40 = { type = 3, value = 40, disp_label = "足元無敵1", name = "対アンディ屈C" },
	low32 = { type = 3, value = 32, disp_label = "足元無敵2", name = "対ギース屈C" },
	low24 = { type = 3, value = 24, disp_label = "足元無敵3", name = "対だいたいの屈B（キムとボブ以外）" },
	-- 特殊やられ
	otg = { type = 4, disp_label = "ダウン追撃", name = "ダウン追撃のみ可能" },
	juggle = { type = 4, disp_label = "空中追撃", name = "空中追撃のみ可能" },
}
hurt_inv_type.values = {
	hurt_inv_type.full, hurt_inv_type.main, hurt_inv_type.sway_oh, hurt_inv_type.sway_lo, hurt_inv_type.top32, hurt_inv_type.top40,
	hurt_inv_type.top48, -- hurt_inv_type.top60, hurt_inv_type.top64, hurt_inv_type.top68, hurt_inv_type.top76, hurt_inv_type.top80,
	hurt_inv_type.low40, hurt_inv_type.low32, hurt_inv_type.low24, hurt_inv_type.otg, hurt_inv_type.juggle
}
-- 投げ無敵
local throw_inv_type = {
	time24 = { value = 24, disp_label = "タイマー24", name = "通常投げ" },
	time20 = { value = 20, disp_label = "タイマー20", name = "M.リアルカウンター投げ" },
	time10 = { value = 10, disp_label = "タイマー10", name = "真空投げ 羅生門 鬼門陣 M.タイフーン M.スパイダー 爆弾パチキ ドリル ブレスパ ブレスパBR リフトアップブロー デンジャラススルー ギガティックサイクロン マジンガ STOL" },
	sway   = { value = 256, disp_label = "スウェー", name = "スウェー" },
	flag1  = { value = 256, disp_label = "フラグ1", name = "無敵フラグ" },
	flag2  = { value = 256, disp_label = "フラグ2", name = "通常投げ無敵フラグ" },
	state  = { value = 256, disp_label = "やられ状態", name = "相互のやられ状態が非通常値" },
	no_gnd = { value = 256, disp_label = "高度", name = "接地状態ではない（地面へのめり込みも投げ不可）" },
}
throw_inv_type.values = {
	throw_inv_type.time24, throw_inv_type.time20, throw_inv_type.time10, throw_inv_type.sway, throw_inv_type.flag1, throw_inv_type.flag2,
	throw_inv_type.state, throw_inv_type.no_gnd
}
hurt_inv_type.get = function(p, real_top, real_bottom, box)
	local ret, top, low = {}, nil, nil
	for _, type in ipairs(hurt_inv_type.values) do
		if type.type == 2 and real_top <= type.value then
			top = type
		end
		if type.type == 3 and real_bottom >= type.value then
			low = type
		end
	end
	if top then
		table.insert(ret, top)
	end
	if low then
		table.insert(ret, low)
	end
	if box.type == box_type_base.v3 then                                                            -- 食らい(ダウン追撃のみ可)
		table.insert(ret, hurt_inv_type.otg)
	elseif box.type == box_type_base.v4 then                                                        -- 食らい(空中追撃のみ可)
		table.insert(ret, hurt_inv_type.juggle)
	elseif box.type == box_type_base.v6 then                                                        -- 食らい(対ライン上攻撃)
		table.insert(ret, hurt_inv_type.sway_oh)
	elseif box.type == box_type_base.x1 then                                                        -- 食らい(対ライン下攻撃)
		table.insert(ret, hurt_inv_type.sway_lo)
	elseif box.type == box_type_base.sv1 or                                                         -- 食らい1(スウェー中)
		box.type == box_type_base.sv2 then                                                          -- 食らい2(スウェー中)
		table.insert(ret, hurt_inv_type.main)
	end
	return #ret == 0 and {} or ret
end
throw_inv_type.get = function(p)
	if p.is_fireball then
		return {}
	end
	local ret = nil
	for _, type in ipairs(throw_inv_type.values) do
		if p.tw_frame >= type.value then
			ret = type
		end
	end
	ret = ret == nil and {} or { ret }
	if p.state ~= 0 or p.op.state ~= 0 then
		table.insert(ret, throw_inv_type.state)
	end
	if p.pos_y ~= 0 then
		table.insert(ret, throw_inv_type.no_gnd)
	end
	if p.sway_status ~= 0x00 then
		table.insert(ret, throw_inv_type.sway)
	end
	if p.tw_muteki ~= 0 then
		table.insert(ret, throw_inv_type.flag1)
	end
	if p.tw_muteki2 ~= 0 then
		table.insert(ret, throw_inv_type.flag2)
	end
	return ret
end
-- 削りダメージ補正
local chip_dmg_types = {
	zero = {
	      -- ゼロ
		name = "0",
		calc = function(pure_dmg)
			return 0
		end,
	},
	rshift4 = {
	         -- 1/16
		name = "1/16",
		calc = function(pure_dmg)
			return math.max(1, 0xFFFF & (pure_dmg >> 4))
		end,
	},
	rshift5 = {
	         -- 1/32
		name = "1/32",
		calc = function(pure_dmg)
			return math.max(1, 0xFFFF & (pure_dmg >> 5))
		end,
	},
}
-- 削りダメージ計算種別 補正処理の分岐先の種類分用意する
local chip_dmg_type_tbl = {
	chip_dmg_types.zero, --  0 ダメージ無し
	chip_dmg_types.zero, --  1 ダメージ無し
	chip_dmg_types.rshift4, --  2 1/16
	chip_dmg_types.rshift4, --  3 1/16
	chip_dmg_types.zero, --  4 ダメージ無し
	chip_dmg_types.zero, --  5 ダメージ無し
	chip_dmg_types.rshift4, --  6 1/16
	chip_dmg_types.rshift5, --  7 1/32
	chip_dmg_types.rshift5, --  8 1/32
	chip_dmg_types.zero, --  9 ダメージ無し
	chip_dmg_types.zero, -- 10 ダメージ無し
	chip_dmg_types.rshift4, -- 11 1/16
	chip_dmg_types.rshift4, -- 12 1/16
	chip_dmg_types.rshift4, -- 13 1/16
	chip_dmg_types.rshift4, -- 14 1/16
	chip_dmg_types.rshift4, -- 15 1/16
	chip_dmg_types.zero, -- 16 ダメージ無し
}
-- 削りダメージ計算種別取得 05B2A4 からの処理
local get_chip_dmg_type = function(id, pgm)
	local a0 = fix_bp_addr(0x95CCC)
	local d0 = 0xF & pgm:read_u8(a0 + id)
	local func = chip_dmg_type_tbl[d0 + 1]
	return func
end
-- ヒット処理の飛び先 家庭用版 0x13120 からのデータテーブル 5種類
local hit_proc_types = {
	none      = nil,     -- 常に判定しない
	same_line = "メイン", -- 同一ライン同士なら判定する
	diff_line = "メイン,スウェー", -- 異なるライン同士でも判定する
	unknown   = "",      -- 不明
	air_onry  = "空中のみ", -- 相手が空中にいれば判定する
}
local hit_sub_procs = {
	[0x01311C] = hit_proc_types.none,   -- 常に判定しない
	[0x012FF0] = hit_proc_types.same_line, -- → 013038 同一ライン同士なら判定する
	[0x012FFE] = hit_proc_types.diff_line, -- → 013054 異なるライン同士でも判定する
	[0x01300A] = hit_proc_types.unknown, -- → 013018 不明
	[0x012FE2] = hit_proc_types.air_onry, -- → 012ff0 → 013038 相手が空中にいれば判定する
}
-- 判定枠のチェック処理種類
local hit_box_proc = function(id, addr)
	-- 家庭用版 012DBC~012F04のデータ取得処理をベースに判定＆属性チェック
	-- 家庭用版 012F30~012F96のデータ取得処理をベースに判定＆属性チェック
	local d2 = id - 0x20
	if d2 >= 0 then
		d2 = pgm:read_u8(addr + d2)
		d2 = 0xFFFF & (d2 + d2)
		d2 = 0xFFFF & (d2 + d2)
		local a0 = pgm:read_u32(0x13120 + d2)
		--printf(" ext attack %x %x %s", id, addr, hit_sub_procs[a0] or "none")
		return hit_sub_procs[a0]
	end
	return hit_proc_types.none
end
local hit_box_procs = {
	normal_hit  = function(id) return hit_box_proc(id, 0x94D2C) end, -- 012DBC: 012DC8: 通常状態へのヒット判定処理
	down_hit    = function(id) return hit_box_proc(id, 0x94E0C) end, -- 012DE4: 012DF0: ダウン状態へのヒット判定処理
	air_hit     = function(id) return hit_box_proc(id, 0x94EEC) end, -- 012E0E: 012E1A: 空中追撃可能状態へのヒット判定処理
	up_block    = function(id) return hit_box_proc(id, 0x950AC) end, -- 012EAC: 012EB8: 上段ガード判定処理
	low_block   = function(id) return hit_box_proc(id, 0x9518C) end, -- 012ED8: 012EE4: 屈段ガード判定処理
	air_block   = function(id) return hit_box_proc(id, 0x9526C) end, -- 012F04: 012F16: 空中ガード判定処理
	sway_up_blk  = function(id) return hit_box_proc(id, 0x95A4C) end, -- 012E60: 012E6C: 対ライン上段の謎処理
	sway_low_blk = function(id) return hit_box_proc(id, 0x95B2C) end, -- 012F3A: 012E90: 対ライン下段の謎処理
	j_atm_nage  = function(id) return hit_box_proc(id, 0x9534C) end, -- 012F30: 012F82: 上段当身投げの処理
	urakumo     = function(id) return hit_box_proc(id, 0x9542C) end, -- 012F30: 012F82: 裏雲隠しの処理
	g_atm_uchi  = function(id) return hit_box_proc(id, 0x9550C) end, -- 012F44: 012F82: 屈段当身打ちの処理
	gyakushu    = function(id) return hit_box_proc(id, 0x955EC) end, -- 012F4E: 012F82: 必勝逆襲拳の処理
	sadomazo    = function(id) return hit_box_proc(id, 0x956CC) end, -- 012F58: 012F82: サドマゾの処理
	phx_tw      = function(id) return hit_box_proc(id, 0x9588C) end, -- 012F6C: 012F82: フェニックススルーの処理
	baigaeshi   = function(id) return hit_box_proc(id, 0x957AC) end, -- 012F62: 012F82: 倍返しの処理
	unknown1    = function(id) return hit_box_proc(id, 0x94FCC) end, -- 012E38: 012E44: 不明処理、未使用？
	katsu       = function(id) return hit_box_proc(id, 0x9596C) end, -- : 012FB2: 喝消し
	nullify     = function(id)                                     -- : 012F9A: 弾消し
		return (0x20 <= id) and hit_proc_types.same_line or hit_proc_types.none
	end,
}
local new_hitbox1 = function(p, id, pos_x, pos_y, top, bottom, left, right, is_fireball)
	local box = { id = id, p = p, }
	box.type = nil
	if (box.id >= #box_types) then
		box.atk = true
		local air = hit_box_procs.air_hit(box.id) ~= nil
		if is_fireball then
			p.has_atk_box = true
			if p.atk_count < 0 then
				p.atk_count = 0
			end
			p.atk_count = p.atk_count + 1
			if air then
				if p.hit.fake_hit then
					box.type = box_type_base.pfaa -- 飛び道具(空中追撃可、嘘)
				elseif p.hit.harmless then
					box.type = box_type_base.pdaa -- 飛び道具(空中追撃可、無効)
				else
					box.type = box_type_base.paa -- 飛び道具(空中追撃可)
				end
			else
				if p.hit.fake_hit then
					box.type = box_type_base.pfa -- 飛び道具(嘘)
				elseif p.hit.harmless then
					box.type = box_type_base.pda -- 飛び道具(無効)
				else
					box.type = box_type_base.pa -- 飛び道具
				end
			end
		else
			if air then
				if p.hit.fake_hit then
					box.type = box_type_base.faa -- 攻撃(嘘)
				elseif p.hit.harmless then
					box.type = box_type_base.daa -- 攻撃(無効、空中追撃可)
				else
					box.type = box_type_base.aa -- 攻撃(空中追撃可)
				end
			else
				if p.hit.fake_hit then
					box.type = box_type_base.fa -- 攻撃(嘘)
				elseif p.hit.harmless then
					box.type = box_type_base.da -- 攻撃(無効)
				else
					box.type = box_type_base.a -- 攻撃(空中追撃可)
				end
			end
		end
	else
		if p.in_sway_line and sway_box_types[box.id] then
			box.type = sway_box_types[box.id]
		else
			box.type = box_types[box.id]
		end
	end
	box.type = box.type or box_type_base.x1

	if box.type.type == "push" then
		if is_fireball then
			-- 飛び道具の押し合い判定は無視する
			return nil
		elseif left == 0 and right == 0 then
			-- 投げ中などに出る前後0の判定は無視する
			return nil
		end
	end

	local orig_posy                = pos_y
	pos_y                          = pos_y - p.hit.pos_z

	top                            = pos_y - (0xFFFF & ((top * p.hit.scale) >> 6))
	bottom                         = pos_y - (0xFFFF & ((bottom * p.hit.scale) >> 6))

	top                            = top & 0xFFFF
	bottom                         = bottom & 0xFFFF
	left                           = 0xFFFF & (pos_x - (0xFFFF & ((left * p.hit.scale) >> 6)) * p.hit.flip_x)
	right                          = 0xFFFF & (pos_x - (0xFFFF & ((right * p.hit.scale) >> 6)) * p.hit.flip_x)

	box.top, box.bottom            = bottom, top
	box.left, box.right            = left, right
	box.asis_top, box.asis_bottom  = bottom, top
	box.asis_left, box.asis_right  = left, right

	if ((box.top <= 0 and box.bottom <= 0) or (box.top >= 224 and box.bottom >= 224) or (box.left <= 0 and box.right <= 0) or (box.left >= 320 and box.right >= 320)) then
		--print("OVERFLOW " .. (key or "")) --debug
		return nil
	end

	-- はみ出し補正
	if p.hit.flip_x == 1 then
		if box.right > 320 and box.right > box.left then
			box.right = 0
			box.over_right = true
		end
	else
		if box.left > 320 and box.left > box.right then
			box.left = 0
			box.over_left = true
		end
	end
	if box.top > box.bottom then
		if box.top > 224 then
			box.top = 224
			box.over_top = true
		end
	else
		if box.bottom > 224 then
			box.bottom = 0
			box.over_bottom = true
		end
	end

	if box.top == box.bottom and box.left == box.right then
		box.visible = false
		return nil
	elseif box.type.type_check(p.hit, box) then
		-- ビリーの旋風棍がヒット、ガードされると判定表示が消えてしまうので飛び道具は状態判断の対象から外す
		-- ここの判断処理を省いても飛び道具が最大ヒットして無効になった時点で判定が消えるので悪影響はない
		if is_fireball then
			box.visible = true
		else
			-- フレーム表示や自動ガードで使うため無効状態の判定を返す
			box.visible = false
			return nil
		end
	else
		box.visible = true
	end

	if box.atk then
		p.attack_id = box.id
	end
	if (box.type == box_type_base.a or box.type == box_type_base.aa) and
		(is_fireball == true or (p.hit.harmless == false and p.hit.obsl_hit == false)) then
		-- 攻撃中のフラグをたてる
		p.attacking = true
	end
	if box.type == box_type_base.da or box.type == box_type_base.daa or box.type == box_type_base.pda or box.type == box_type_base.pdaa then
		p.dmmy_attacking = true
	end
	if box.type == box_type_base.aa or box.type == box_type_base.daa or box.type == box_type_base.paa or box.type == box_type_base.pdaa then
		p.juggling = true
	end
	if box.type == box_type_base.v3 then
		p.can_juggle = true
	end
	if box.type == box_type_base.v4 then
		p.can_otg = true
	end

	box.fb_pos_x, box.fb_pos_y = pos_x, orig_posy
	box.pos_x = p.is_fireball and math.floor(p.parent.pos - screen.left) or pos_x
	box.pos_y = p.is_fireball and math.floor(p.parent.pos_y) or orig_posy

	return box
end
local get_reach = function(p, box, pos_x, pos_y)
	local top_reach    = pos_y - math.min(box.top, box.bottom)
	local bottom_reach = pos_y - math.max(box.top, box.bottom)
	local front_reach, back_reach

	local flip_x = p.hit.flip_x == 1
	-- 野猿狩りだけ左右反対
	if p.is_fireball and (p.act == 0x277 or p.act == 0x27c) and p.parent.char == 0x6 then
		flip_x = not flip_x 
	end
	if flip_x then
		front_reach = math.max(box.left, box.right) - pos_x
		back_reach  = math.min(box.left, box.right) - pos_x
	else
		front_reach = pos_x - math.min(box.left, box.right)
		back_reach  = pos_x - math.max(box.left, box.right)
	end
	local x, y
	if p.is_fireball then
		x, y = p.pos, p.pos_y
	else
		x, y = box.pos_x, box.pos_y
	end
	local asis_top_reach    = y - math.min(box.asis_top, box.asis_bottom)
	local asis_bottom_reach = y - math.max(box.asis_top, box.asis_bottom)
	local asis_front_reach, asis_back_reach
	if flip_x then
		asis_front_reach = math.max(box.asis_left, box.asis_right) - x
		asis_back_reach  = math.min(box.asis_left, box.asis_right) - x
	else
		asis_front_reach = x - math.min(box.asis_left, box.asis_right)
		asis_back_reach  = x - math.max(box.asis_left, box.asis_right)
	end
	local reach_data = {
		front       = math.floor(front_reach), -- キャラ本体座標からの前のリーチ
		back        = math.floor(back_reach), -- キャラ本体座標からの後のリーチ
		top         = math.floor(top_reach) - 24, -- キャラ本体座標からの上のリーチ
		bottom      = math.floor(bottom_reach) - 24, -- キャラ本体座標からの下のリーチ
		asis_front  = math.floor(asis_front_reach),
		asis_back   = math.floor(asis_back_reach),
		asis_top    = math.floor(asis_top_reach) - 24,
		asis_bottom = math.floor(asis_bottom_reach) - 24,
	}
	local fix_pos_y = p.pos_miny > 0 and p.pos_miny or p.pos_y
	reach_data.real_top = reach_data.top + fix_pos_y    -- 実際の上のリーチ
	reach_data.real_bottom = reach_data.bottom + fix_pos_y -- 実際の上のリーチ
	return reach_data
end

local in_range = function(top, bottom, atop, abottom)
	if abottom <= top and top <= atop then
		return true
	elseif abottom <= bottom and bottom <= atop then
		return true
	end
	return false
end
local update_summary = function(p)
	local summary        = p.hit_summary
	-- 判定ができてからのログ情報の作成
	summary.attack       = summary.attack or p.attack                  -- 補正前攻撃力導出元ID
	summary.pure_dmg     = summary.pure_dmg or p.pure_dmg              -- 補正前攻撃力
	summary.pure_st      = summary.pure_st or p.pure_st                -- 気絶値
	summary.pure_st_tm   = summary.pure_st_tm or p.pure_st_tm          -- 気絶タイマー
	summary.chip_dmg     = summary.chip_dmg or p.chip_dmg_type.calc(summary.pure_dmg) -- 削りダメージ
	summary.chip_dmg_nm  = summary.chip_dmg_nm or p.chip_dmg_type.name -- 削りダメージ名
	summary.attack_id    = summary.attack_id or p.attack_id
	summary.effect       = summary.effect or p.effect                  -- ヒット効果
	summary.can_techrise = summary.can_techrise or p.can_techrise      -- 受け身行動可否
	summary.gd_strength  = summary.gd_strength or p.gd_strength        -- 相手のガード持続の種類
	summary.max_hit_nm   = summary.max_hit_nm or p.hit.max_hit_nm      -- p.act_frame中の行動最大ヒット 分子
	summary.max_hit_dn   = summary.max_hit_dn or p.hit.max_hit_dn      -- p.act_frame中の行動最大ヒット 分母
	summary.cancelable   = summary.cancelable or p.cancelable or 0     -- キャンセル可否
	summary.repeatable   = summary.repeatable or p.repeatable or false -- 連キャン可否
	summary.slide_atk    = summary.slide_atk or p.slide_atk            -- ダッシュ滑り攻撃
	summary.bs_atk       = summary.bs_atk or p.bs_atk                  -- ブレイクショット

	summary.hitstun      = summary.hitstun or p.hitstun                -- ヒット硬直
	summary.blockstun    = summary.blockstun or p.blockstun            -- ガード硬直
	summary.hitstop      = summary.hitstop or p.hitstop                -- ヒットストップ
	summary.hitstop_gd   = summary.hitstop_gd or p.hitstop_gd          -- ガード時ヒットストップ
	if p.is_fireball == true then
		summary.prj_rank = summary.prj_rank or p.prj_rank              -- 飛び道具の強さ
	else
		summary.prj_rank = nil                                         -- 飛び道具の強さ
	end
end

local block_types = {
	high = 2 ^ 0,
	high_tung = 2 ^ 1,
	low = 2 ^ 2,
	air = 2 ^ 3,
	sway_high = 2 ^ 4,
	sway_high_tung = 2 ^ 5,
	sway_low = 2 ^ 6,
	sway_pass = 2 ^ 7,
}

local update_box_summary = function(p, box)
	local summary = p.hit_summary
	if box then
		local edge = nil
		if p.is_fireball then
			box.reach = get_reach(p, box, box.pos_x, box.fb_pos_y)
		else
			box.reach = get_reach(p, box, box.pos_x, box.pos_y)
		end
		if box.atk then
			summary.normal_hit   = summary.normal_hit or hit_box_procs.normal_hit(box.id)
			summary.down_hit     = summary.down_hit or hit_box_procs.down_hit(box.id)
			summary.air_hit      = summary.air_hit or hit_box_procs.air_hit(box.id)
			summary.up_block     = summary.up_block or hit_box_procs.up_block(box.id)
			summary.low_block    = summary.low_block or hit_box_procs.low_block(box.id)
			summary.air_block    = summary.air_block or hit_box_procs.air_block(box.id)
			summary.sway_up_blk  = summary.sway_up_blk or hit_box_procs.sway_up_blk(box.id)
			summary.sway_low_blk = summary.sway_low_blk or hit_box_procs.sway_low_blk(box.id)
			summary.j_atm_nage   = summary.j_atm_nage or hit_box_procs.j_atm_nage(box.id)
			summary.urakumo      = summary.urakumo or hit_box_procs.urakumo(box.id)
			summary.g_atm_uchi   = summary.g_atm_uchi or hit_box_procs.g_atm_uchi(box.id)
			summary.gyakushu     = summary.gyakushu or hit_box_procs.gyakushu(box.id)
			summary.sadomazo     = summary.sadomazo or hit_box_procs.sadomazo(box.id)
			summary.phx_tw       = summary.phx_tw or hit_box_procs.phx_tw(box.id)
			summary.baigaeshi    = summary.baigaeshi or hit_box_procs.baigaeshi(box.id)
			summary.unknown1     = summary.unknown1 or hit_box_procs.unknown1(box.id)
			summary.katsu        = summary.katsu or p.is_fireball and 3 <= p.prj_rank and hit_box_procs.katsu(box.id) or nil
			summary.nullify      = summary.nullify or p.is_fireball and hit_box_procs.nullify(box.id) or nil
			summary.bai_catch    = summary.bai_catch or p.bai_catch == true and "v" or nil
			summary.box_addr     = summary.box_addr or pgm:read_u32(pgm:read_u8(0x094C2C + box.id) * 4 + 0x012CB4)
		end

		if attack_boxies[box.type] then
			summary.attacking = true	
		end
		if box.type == box_type_base.a or -- 攻撃
			box.type == box_type_base.pa then -- 飛び道具
			summary.hit = true
			edge = summary.edge.hit
		elseif box.type == box_type_base.da or -- 攻撃(無効)
			box.type == box_type_base.pfa or -- 飛び道具(嘘)
			box.type == box_type_base.pda then -- 飛び道具(無効)
			edge = summary.edge.hit
		elseif box.type == box_type_base.aa or -- 攻撃(空中追撃可)
			box.type == box_type_base.paa then -- 飛び道具(空中追撃可)
			summary.hit = true
			summary.juggle = true
			edge = summary.edge.hit
		elseif box.type == box_type_base.daa or -- 攻撃(無効、空中追撃可)
			box.type == box_type_base.pfaa or -- 飛び道具(嘘、空中追撃可)
			box.type == box_type_base.pdaa then -- 飛び道具(無効、空中追撃可)
			edge = summary.edge.hit
		elseif box.type == box_type_base.t then -- 通常投げ
			summary.n_throw = true
			summary.tw_threshold = p.tw_threshold
			edge = summary.edge.throw
		elseif box.type == box_type_base.at then -- 空中投げ
			summary.air_throw = true
			summary.tw_threshold = p.tw_threshold
			edge = summary.edge.throw
		elseif box.type == box_type_base.pt then -- 必殺技投げ
			summary.sp_throw     = true
			summary.sp_throw_id  = p.sp_throw_id
			summary.tw_threshold = p.tw_threshold
			edge                 = summary.edge.throw
		elseif box.type == box_type_base.v1 or -- 食らい1
			box.type == box_type_base.v2 then -- 食らい2
			summary.hurt = true
			edge = summary.edge.hurt
		elseif box.type == box_type_base.v3 then -- 食らい(ダウン追撃のみ可)
			summary.hurt = true
			edge = summary.edge.hurt
		elseif box.type == box_type_base.v4 then -- 食らい(空中追撃のみ可)
			summary.hurt = true
			edge = summary.edge.hurt
		elseif box.type == box_type_base.v6 then -- 食らい(対ライン上攻撃)
			summary.hurt = true
			edge = summary.edge.hurt
		elseif box.type == box_type_base.x1 then -- 食らい(対ライン下攻撃)
			summary.hurt = true
			edge = summary.edge.hurt
		elseif box.type == box_type_base.sv1 or -- 食らい1(スウェー中)
			box.type == box_type_base.sv2 then -- 食らい2(スウェー中)
			edge = summary.edge.hurt
		elseif box.type == box_type_base.g1 or -- 立ガード
			box.type == box_type_base.g2 or -- 屈段ガード
			box.type == box_type_base.g3 then -- 空中ガード
			summary.block = true
			edge = summary.edge.block
		elseif box.type == box_type_base.g4 or -- 上段当身投げ
			box.type == box_type_base.g5 or -- 裏雲隠し
			box.type == box_type_base.g6 or -- 屈段当身打ち
			box.type == box_type_base.g7 or -- 必勝逆襲拳
			box.type == box_type_base.g8 or -- サドマゾ
			box.type == box_type_base.g9 or -- 倍返し
			box.type == box_type_base.g10 then -- フェニックススルー
			summary.parry = true
			edge = summary.edge.parry
		end
		-- 各判定の最大数値の保存
		if edge then
			edge.front       = math.max(box.reach.front, edge.front or 0)
			edge.back        = math.min(box.reach.back, edge.back or 999)
			edge.top         = math.max(box.reach.top, edge.top or 0)
			edge.bottom      = math.min(box.reach.bottom, edge.bottom or 999)
			-- 実際の上下のリーチを再計算
			edge.real_top    = edge.top + p.pos_y
			edge.real_bottom = edge.bottom + p.pos_y
			-- boxごとに評価
			if edge == summary.edge.hit then
				local real_top, real_bottom = box.reach.real_top, box.reach.real_bottom

				box.info = box.info or {
					punish_away = 0, -- 1:避けつぶし
					-- 2:ウェービングブロー,龍転身,ダブルローリングつぶし
					-- 3:避けつぶし ローレンス用
					-- 4:60 屈 アンディ,東,舞,ホンフゥ,マリー,山崎,崇秀,崇雷,キム,ビリー,チン,タン
					-- 5:64 屈 テリー,ギース,双角,ボブ,ダック,リック,シャンフェイ,アルフレッド
					-- 6:68 屈 ローレンス
					asis_punish_away = 0,
					j_atm_nage = true,
					range_j_atm_nage = true,
					urakumo = true,
					range_urakumo = true,
					g_atm_uchi = true,
					range_g_atm_uchi = true,
					gyakushu = true,
					range_gyakushu = true,
					sadomazo = true,
					range_sadomazo = true,
					baigaeshi = true,
					range_baigaeshi = true,
					phx_tw = true,
					range_phx_tw = true,
				}
				local info = box.info

				local blockbit = 0
				if summary.air_block ~= hit_proc_types.none then
					blockbit = blockbit | block_types.air
				end
				if summary.low_block ~= hit_proc_types.none then
					blockbit = blockbit | block_types.low
				end
				if summary.up_block ~= hit_proc_types.none then
					if real_top <= 36 then
						-- 全キャラ上段ガード不能
					elseif real_top <= 48 then
						blockbit = blockbit | block_types.high_tung
					else
						blockbit = blockbit | block_types.high
					end
				end
				if p.sway_status == 0 and summary.normal_hit == hit_proc_types.diff_line then
					if summary.sway_up_blk == hit_proc_types.diff_line then
						if real_top <= 48 then
							-- 対スウェー全キャラ上段ガード不能
						elseif real_top <= 59 then
							blockbit = blockbit | block_types.sway_high_tung
						else
							blockbit = blockbit | block_types.sway_high
						end
					end
					if summary.sway_low_blk == hit_proc_types.diff_line then
						blockbit = blockbit | block_types.sway_low
					end
				else
					blockbit = blockbit | block_types.sway_pass
				end
				info.blockbit = blockbit
				table.insert(summary.blockbits, blockbit)
				summary.blockbit = summary.blockbit | blockbit

				if real_bottom < 32 then
					info.punish_away = 1 -- 避けつぶし
				elseif real_bottom < 40 then
					info.punish_away = 2 -- ウェービングブロー,龍転身,ダブルローリングつぶし
				elseif real_bottom < 48 then
					info.punish_away = 3 -- 避けつぶし ローレンス用
				elseif real_bottom < 60 then
					info.punish_away = 4 -- 60 屈 アンディ,東,舞,ホンフゥ,マリー,山崎,崇秀,崇雷,キム,ビリー,チン,タン
				elseif real_bottom < 64 then
					info.punish_away = 5 -- 64 屈 テリー,ギース,双角,ボブ,ダック,リック,シャンフェイ,アルフレッド
				elseif real_bottom < 68 then
					info.punish_away = 6 -- 68 屈 ローレンス
				end
				if box.reach.bottom < 32 then
					info.asis_punish_away = 1 -- 避けつぶし
				elseif box.reach.bottom < 40 then
					info.asis_punish_away = 2 -- ウェービングブロー,龍転身,ダブルローリングつぶし
				elseif box.reach.bottom < 48 then
					info.asis_punish_away = 3 -- 避けつぶし ローレンス用
				elseif box.reach.bottom < 60 then
					info.asis_punish_away = 4 -- 60 屈 アンディ,東,舞,ホンフゥ,マリー,山崎,崇秀,崇雷,キム,ビリー,チン,タン
				elseif box.reach.bottom < 64 then
					info.asis_punish_away = 5 -- 64 屈 テリー,ギース,双角,ボブ,ダック,リック,シャンフェイ,アルフレッド
				elseif box.reach.bottom < 68 then
					info.asis_punish_away = 6 -- 68 屈 ローレンス
				end
				-- 76 屈 フランコ
				-- 80 屈 クラウザー

				-- 上段当身投げ
				info.j_atm_nage = summary.j_atm_nage
				info.range_j_atm_nage = summary.j_atm_nage and in_range(real_top, real_bottom, 112, 40)
				-- 裏雲隠し
				info.urakumo = summary.urakumo
				info.range_urakumo = summary.urakumo and in_range(real_top, real_bottom, 104, 40)
				-- 屈段当身打ち
				info.g_atm_uchi = summary.g_atm_uchi
				info.range_g_atm_uchi = summary.g_atm_uchi and in_range(real_top, real_bottom, 44, 0)
				-- 必勝逆襲拳
				info.gyakushu = summary.gyakushu
				info.range_gyakushu = summary.gyakushu and in_range(real_top, real_bottom, 72, 32)
				-- サドマゾ
				info.sadomazo = summary.sadomazo
				info.range_sadomazo = summary.sadomazo and in_range(real_top, real_bottom, 96, 36)
				-- 倍返し
				info.baigaeshi = summary.baigaeshi
				info.range_baigaeshi = summary.baigaeshi and in_range(real_top, real_bottom, 84, 0)
				-- フェニックススルー
				info.phx_tw = summary.phx_tw
				info.range_phx_tw = summary.phx_tw and in_range(real_top, real_bottom, 120, 56)
				-- 喝消し
				info.katsu = summary.katsu
				info.range_katsu = summary.katsu and in_range(real_top, real_bottom, 84, 0)
				-- 弾消し
				info.nullify = summary.nullify
				-- ヒット処理のアドレス
				info.box_addr = summary.box_addr
			elseif edge == summary.edge.hurt then
				summary.hurt_inv = hurt_inv_type.get(p, edge.real_top, edge.real_bottom, box)
			end
		end

		if box.atk then
			local memo = ""
			memo = memo .. " nml=" .. (summary.normal_hit or "-")
			memo = memo .. " dwn=" .. (summary.down_hit or "-")
			memo = memo .. " air=" .. (summary.air_hit or "-")
			memo = memo .. " ugd=" .. (summary.up_block or "-")
			memo = memo .. " lgd=" .. (summary.low_block or "-")
			memo = memo .. " agd=" .. (summary.air_block or "-")
			memo = memo .. " sugd=" .. (summary.sway_up_blk or "-")
			memo = memo .. " slgd=" .. (summary.sway_low_blk or "-")
			memo = memo .. " jatm=" .. (summary.j_atm_nage or "-")
			memo = memo .. " urkm=" .. (summary.urakumo or "-")
			memo = memo .. " gatm=" .. (summary.g_atm_uchi or "-")
			memo = memo .. " gsyu=" .. (summary.gyakushu or "-")
			memo = memo .. " sdmz=" .. (summary.sadomazo or "-")
			memo = memo .. " phx=" .. (summary.phx_tw or "-")
			memo = memo .. " bai=" .. (summary.baigaeshi or "-")
			memo = memo .. " ?1=" .. (summary.unknown1 or "-")
			memo = memo .. " catch=" .. (summary.bai_catch or "-")

			-- ログ用
			box.log_txt = string.format(
				"hit %6x %3x %3x %2s %3s %2x %2x %2x %s %x %2s %4s %4s %4s %2s %2s/%2s %3s %s %2s %2s %2s %2s %2s %2s %2s %2s %2x %3s " .. memo,
				p.addr.base,          -- 1P:100400 2P:100500 1P弾:100600 2P弾:100700 1P弾:100800 2P弾:100900 1P弾:100A00 2P弾:100B00
				p.act,                --
				p.acta,               --
				p.act_count,          --
				p.act_frame,          --
				p.act_contact,        --
				p.attack,             --
				p.hitstop_id,         -- ガード硬直のID
				p.gd_strength,        -- 相手のガード持続の種類
				box.id,               -- 判定のID
				p.hit.harmless and "hm" or "", -- 無害化
				p.hit.fake_hit and "fake" or "", -- 嘘判定
				p.hit.obsl_hit and "obsl" or "", -- 嘘判定
				p.hit.full_hit and "full" or "", -- 最大ヒット
				p.hit.harmless2 and "h2" or "", -- 無害化
				p.hit.max_hit_nm,     -- p.act_frame中の行動最大ヒット 分子
				p.hit.max_hit_dn,     -- p.act_frame中の行動最大ヒット 分母
				p.pure_dmg,           -- 補正前攻撃力 %3s
				p.chip_dmg_type.calc(p.pure_dmg), -- 補正前削りダメージ %s
				p.chip_dmg_type.name, -- 削り補正値 %4s
				p.hitstop,            -- ヒットストップ %2s
				p.hitstop_gd,         -- ガード時ヒットストップ %2s
				p.hitstun,            -- ヒット後硬直F %2s
				p.blockstun,          -- ガード後硬直F %2s
				p.effect,             -- ヒット効果 %2s
				p.pure_st,            -- 気絶値 %2s
				p.pure_st_tm,         -- 気絶タイマー %2s
				p.prj_rank,           -- 飛び道具の強さ
				p.esaka_range         -- 詠酒範囲
			)
		elseif box.type.type_check == type_ck_gd then
			box.log_txt = string.format("block %6x %x", p.addr.base, box.id)
		end
	end
	return box
end

local new_throwbox = function(p, box)
	local height                   = scr.height * scr.yscale
	--print("a", box.opp_id, box.top, box.bottom, p.hit.flip_x)
	p.throwing                     = true
	box.flat_throw                 = box.top == nil
	box.top                        = box.top or box.pos_y - global.throwbox_height
	box.left                       = box.pos_x + (box.left or 0)
	box.right                      = box.pos_x + (box.right or 0)
	box.top                        = box.top and box.pos_y - box.top --air throw
	box.bottom                     = box.bottom and (box.pos_y - box.bottom) or height + screen.top - p.hit.pos_z
	box.type                       = box.type or box_type_base.t
	box.visible                    = true
	--print("b", box.opp_id, box.top, box.bottom, p.hit.flip_x)
	box.asis_top, box.asis_bottom  = box.bottom, box.top
	box.asis_left, box.asis_right  = box.left, box.right
	return box
end

-- 1:右向き -1:左向き
local get_flip_x = function(p)
	local obj_base = p.addr.base
	local flip_x = pgm:read_i16(obj_base + 0x6A) < 0 and 1 or 0
	flip_x = flip_x ~ (pgm:read_u8(obj_base + 0x71) & 1)
	flip_x = flip_x > 0 and 1 or -1
	return flip_x
end

-- 当たり判定用のキャラ情報更新と判定表示用の情報作成
local update_object = function(p)
	local height   = scr.height * scr.yscale

	local obj_base = p.addr.base

	p.hit.pos_x    = p.pos - screen.left
	if p.min_pos then
		p.hit.min_pos_x = p.min_pos - screen.left
	else
		p.hit.min_pos_x = nil
	end
	if p.max_pos then
		p.hit.max_pos_x = p.max_pos - screen.left
	else
		p.hit.max_pos_x = nil
	end
	p.hit.pos_z      = p.pos_z
	p.hit.old_pos_y  = p.hit.pos_y
	p.hit.pos_y      = height - p.pos_y - p.hit.pos_z
	p.hit.pos_y      = screen.top + p.hit.pos_y
	p.hit.on         = pgm:read_u32(obj_base)
	p.hit.flip_x     = get_flip_x(p)
	p.hit.scale      = pgm:read_u8(obj_base + 0x73) + 1
	p.hit.char_id    = pgm:read_u16(obj_base + 0x10)
	p.hit.base       = obj_base

	p.attacking      = false
	p.dmmy_attacking = false
	p.juggling       = false
	p.can_juggle     = false
	p.can_otg        = false
	p.attack_id      = 0
	p.effect         = 0
	p.throwing       = false

	-- ヒットするかどうか
	if p.is_fireball then
		p.hit.harmless = p.obsl_hit or p.full_hit or p.harmless2
		p.hit.fake_hit = p.fake_hit
	else
		p.hit.harmless = p.obsl_hit or p.full_hit
		p.hit.fake_hit = p.fake_hit or p.harmless2
	end
	p.hit.obsl_hit = p.obsl_hit
	p.hit.full_hit = p.full_hit
	p.hit.max_hit_dn = p.max_hit_dn
	p.hit.max_hit_nm = p.max_hit_nm
	p.hit.harmless2 = p.harmless2

	-- 食らい判定かどうか
	p.hit.vulnerable = false
	if p.hit.vulnerable1 == 1 then
		p.hit.vulnerable = true
	elseif p.hit.vulnerable21 == 1 then
		p.hit.vulnerable = p.hit.vulnerable22
	end

	-- 判定データ排他用のテーブル
	for _, box in ipairs(p.buffer) do
		local hitbox = new_hitbox1(p, box.id, box.pos_x, box.pos_y, box.top, box.bottom, box.left, box.right, box.is_fireball)
		if hitbox then
			p.uniq_hitboxes[box.key] = hitbox.type
			update_box_summary(p, hitbox)
			table.insert(p.hitboxes, hitbox)
			-- 攻撃情報ログ
			if global.log.atklog == true and hitbox.log_txt ~= nil then
				print(hitbox.log_txt)
			end
		end
	end

	-- ヒット効果、削り補正、硬直
	-- 一動作で複数の攻撃判定を持っていてもIDの値は同じになる
	-- 058232(家庭用版)からの処理
	-- 1004E9のデータ＝5C83Eでセット 技ID
	-- 1004E9のデータ-0x20 + 0x95C0C のデータがヒット効果の元ネタ D0
	-- D0 = 0x9だったら 1005E4 くらった側E4 OR 0x40の結果をセット （7ビット目に1）
	-- D0 = 0xAだったら 1005E4 くらった側E4 OR 0x40の結果をセット （7ビット目に1）
	-- D0 x 4 + 579da
	-- d0 = fix_bp_addr(0x0579DA + d0 * 4) --0x0579DA から4バイトのデータの並びがヒット効果の処理アドレスになる
	p.effect        = pgm:read_u8(p.attack_id - 0x20 + fix_bp_addr(0x95BEC))
	-- 削りダメージ計算種別取得 05B2A4 からの処理
	p.chip_dmg_type = get_chip_dmg_type(p.attack_id, pgm)
	-- 硬直時間取得 05AF7C(家庭用版)からの処理
	local d2        = 0xF & pgm:read_u8(p.attack_id + fix_bp_addr(0x95CCC))
	p.hitstun       = pgm:read_u8(0x16 + 0x2 + fix_bp_addr(0x5AF7C) + d2) + 1 + 3 -- ヒット硬直
	p.blockstun     = pgm:read_u8(0x1A + 0x2 + fix_bp_addr(0x5AF88) + d2) + 1 + 2 -- ガード硬直

	-- 共通情報
	if (p.is_fireball and p.proc_active) or p.attack_flag then
		update_summary(p)
	end

	-- 空投げ, 必殺投げ
	if p.n_throw and p.n_throw.on == 0x1 then
		table.insert(p.hitboxes, update_box_summary(p, new_throwbox(p, p.n_throw)))
		--print("n throw " .. string.format("%x", p.addr.base) .. " " .. p.n_throw.type.name .. " " .. " " .. p.n_throw.left .. " " .. p.n_throw.right .. " " .. p.n_throw.top .. " " .. p.n_throw.bottom)
	end
	if p.air_throw and p.air_throw.on == 0x1 then
		table.insert(p.hitboxes, update_box_summary(p, new_throwbox(p, p.air_throw)))
	end
	if p.sp_throw and p.sp_throw.on == 0x1 then
		table.insert(p.hitboxes, update_box_summary(p, new_throwbox(p, p.sp_throw)))
	end
end

local dummy_gd_type = {
	none   = 1, -- なし
	auto   = 2, -- オート
	bs     = 3, -- ブレイクショット
	hit1   = 4, -- 1ヒットガード
	block1 = 5, -- 1ガード
	fixed  = 6, -- 常時
	random = 7, -- ランダム
	force  = 8, -- 強制
}
local wakeup_type = {
	none = 1, -- なし
	rvs  = 2, -- リバーサル
	tech = 3, -- テクニカルライズ
	sway = 4, -- グランドスウェー
	atk  = 5, -- 起き上がり攻撃
}
rbff2.startplugin = function()
	-- プレイヤーの状態など
	local players = {}
	for p = 1, 2 do
		local p1 = (p == 1)
		local base = p1 and 0x100400 or 0x100500
		players[p] = {
			base                       = 0x0,
			bases                      = {},

			dummy_act                  = 1,         -- 立ち, しゃがみ, ジャンプ, 小ジャンプ, スウェー待機
			dummy_gd                   = dummy_gd_type.none, -- なし, オート, ブレイクショット, 1ヒットガード, 1ガード, 常時, ランダム, 強制
			dummy_wakeup               = wakeup_type.none, -- なし, リバーサル, テクニカルライズ, グランドスウェー, 起き上がり攻撃

			dummy_bs                   = nil,       -- ランダムで選択されたブレイクショット
			dummy_bs_list              = {},        -- ブレイクショットのコマンドテーブル上の技ID
			dummy_bs_chr               = 0,         -- ブレイクショットの設定をした時のキャラID
			bs_count                   = -1,        -- ブレイクショットの実施カウント

			dummy_rvs                  = nil,       -- ランダムで選択されたリバーサル
			dummy_rvs_list             = {},        -- リバーサルのコマンドテーブル上の技ID
			dummy_rvs_chr              = 0,         -- リバーサルの設定をした時のキャラID
			rvs_count                  = -1,        -- リバーサルの実施カウント
			gd_rvs_enabled             = false,     -- ガードリバーサルの実行可否

			life_rec                   = true,      -- 自動で体力回復させるときtrue
			red                        = 2,         -- 体力設定     	--"最大", "赤", "ゼロ" ...
			max                        = 1,         -- パワー設定       --"最大", "半分", "ゼロ" ...
			disp_hitbox                = 2,         -- 判定表示
			disp_range                 = 2,         -- 間合い表示
			disp_base                  = false,     -- 処理のアドレスを表示するときtrue
			disp_char                  = true,      -- キャラを画面表示するときtrue
			disp_char_bps              = nil,
			disp_dmg                   = true,      -- ダメージ表示するときtrue
			disp_cmd                   = 2,         -- 入力表示 1:OFF 2:ON 3:ログのみ 4:キーディスのみ
			disp_frm                   = 4,         -- フレーム数表示する
			disp_fbfrm                 = true,      -- 弾のフレーム数表示するときtrue
			disp_stun                  = true,      -- 気絶表示
			disp_sts                   = 3,         -- 状態表示 "OFF", "ON", "ON:小表示", "ON:大表示"

			dis_plain_shift            = false,     -- ライン送らない現象

			no_hit                     = 0,         -- Nヒット目に空ぶるカウントのカウンタ
			no_hit_limit               = 0,         -- Nヒット目に空ぶるカウントの上限

			combo                      = 0,         -- 最近のコンボ数
			last_combo                 = 0,
			last_dmg                   = 0,         -- ダメージ
			last_pow                   = 0,         -- コンボ表示用POWゲージ増加量
			tmp_pow                    = 0,         -- コンボ表示用POWゲージ増加量
			tmp_pow_rsv                = 0,         -- コンボ表示用POWゲージ増加量(予約値)
			tmp_pow_atc                = 0,         -- コンボ表示用POWゲージ増加量(予約時の行動)
			tmp_stun                   = 0,
			tmp_st_timer               = 0,
			dmg_scaling                = 1,
			dmg_scl7                   = 0,
			dmg_scl6                   = 0,
			dmg_scl5                   = 0,
			dmg_scl4                   = 0,
			last_pure_dmg              = 0,
			last_stun                  = 0,
			last_st_timer              = 0,
			last_normal_state          = true,
			last_effects               = {},
			life                       = 0, -- いまの体力
			max_combo                  = 0, -- 最大コンボ数
			max_dmg                    = 0,
			max_combo_pow              = 0,
			max_disp_stun              = 0,
			max_st_timer               = 0,
			mv_state                   = 0, -- 動作
			old_combo                  = 0, -- 前フレームのコンボ数
			last_combo_dmg             = 0,
			last_combo_pow             = 0,
			last_dmg_scaling           = 1,
			last_combo_stun            = 0,
			last_combo_st_timer        = 0,
			old_state                  = 0, -- 前フレームのやられ状態
			char                       = 0,
			close_far                  = {
				a = { x1 = 0, x2 = 0 },
				b = { x1 = 0, x2 = 0 },
				c = { x1 = 0, x2 = 0 },
				d = { x1 = 0, x2 = 0 },
			},
			close_far_lma              = {
				["1"] = { x1 = 0, x2 = 0 },
				["2"] = { x1 = 0, x2 = 0 },
				["M"] = { x1 = 0, x2 = 0 },
				["C"] = { x1 = 0, x2 = 0 },
			},
			act                        = 0,
			acta                       = 0,
			atk_count                  = 0,
			attack                     = 0, -- 攻撃中のみ変化
			old_attack                 = 0,
			hitstop_id                 = 0, -- ヒット/ガードしている相手側のattackと同値
			attack_id                  = 0, -- 当たり判定ごとに設定されているID
			effect                     = 0,
			attacking                  = false, -- 攻撃判定発生中の場合true
			dmmy_attacking             = false, -- ヒットしない攻撃判定発生中の場合true（嘘判定のぞく）
			juggling                   = false, -- 空中追撃判定発生中の場合true
			throwing                   = false, -- 投げ判定発生中の場合true
			can_techrise               = false, -- 受け身行動可否
			pow_up                     = 0, -- 状態表示用パワー増加量空振り
			pow_up_hit                 = 0, -- 状態表示用パワー増加量ヒット
			pow_up_gd                  = 0, -- 状態表示用パワー増加量ガード
			pow_revenge                = 0, -- 状態表示用パワー増加量倍返し反射
			pow_absorb                 = 0, -- 状態表示用パワー増加量倍返し吸収
			hitstop                    = 0, -- 攻撃側のガード硬直
			old_pos                    = 0, -- X座標
			old_pos_frc                = 0, -- X座標少数部
			pos                        = 0, -- X座標
			pos_frc                    = 0, -- X座標少数部
			old_posd                   = 0, -- X座標
			posd                       = 0, -- X座標
			poslr                      = "L", -- 右側か左側か
			max_pos                    = 0, -- X座標最大
			min_pos                    = 0, -- X座標最小
			pos_y                      = 0, -- Y座標
			pos_frc_y                  = 0, -- Y座標少数部
			pos_miny                   = 0, -- Y座標の最小値
			old_pos_y                  = 0, -- Y座標
			old_pos_frc_y              = 0, -- Y座標少数部
			old_in_air                 = false,
			in_air                     = false,
			chg_air_state              = 0, -- ジャンプの遷移ポイントかどうか
			force_y_pos                = 1, -- Y座標強制
			pos_z                      = 0, -- Z座標
			old_pos_z                  = 0, -- Z座標
			on_main_line               = 0, -- Z座標メインに移動した瞬間フレーム
			on_sway_line               = 0, -- Z座標スウェイに移動した瞬間フレーム
			in_sway_line               = false, -- Z座標
			sway_status                = 0, --
			side                       = 0, -- 向き
			state                      = 0, -- いまのやられ状態
			flag_c0                    = 0, -- 処理で使われているフラグ群
			old_flag_c0                = 0, -- 処理で使われているフラグ群
			flag_cc                    = 0, -- 処理で使われているフラグ群
			old_flag_cc                = 0, -- 処理で使われているフラグ群
			attack_flag                = false,
			flag_c8                    = 0, -- 処理で使われているフラグ群
			flag_d0                    = 0, -- 処理で使われているフラグ（硬直の判断用）
			old_flag_d0                = 0, -- 処理で使われているフラグ（硬直の判断用）
			tmp_combo                  = 0, -- 一次的なコンボ数
			tmp_combo_dmg              = 0,
			tmp_combo_pow              = 0,
			last_combo_stun_offset     = 0,
			last_combo_st_timer_offset = 0,
			tmp_dmg                    = 0, -- ダメージが入ったフレーム
			color                      = 0, -- カラー A=0x00 D=0x01

			frame_gap                  = 0,
			last_frame_gap             = 0,
			hist_frame_gap             = { 0 },
			act_contact                = 0,
			block1                     = 0, -- ガード時（硬直前後）フレームの判断用
			on_block                   = 0, -- ガード時（硬直前）フレーム
			on_block1                  = 0, -- ガード時（硬直後）フレーム
			hit1                       = 0, -- ヒット時（硬直前後）フレームの判断用
			on_hit                     = 0, -- ヒット時（硬直前）フレーム
			on_hit1                    = 0, -- ヒット時（硬直後）フレーム
			on_punish                  = 0,
			on_wakeup                  = 0,
			on_down                    = 0,
			hit_skip                   = 0,
			old_skip_frame             = false,
			skip_frame                 = false,
			last_blockstun             = 0,
			last_hitstop               = 0,

			knock_back1                = 0, -- のけぞり確認用1(色々)
			knock_back2                = 0, -- のけぞり確認用2(裏雲隠し)
			knock_back3                = 0, -- のけぞり確認用3(フェニックススルー)
			old_knock_back1            = 0, -- のけぞり確認用1(色々)
			old_knock_back2            = 0, -- のけぞり確認用2(裏雲隠し)
			old_knock_back3            = 0, -- のけぞり確認用3(フェニックススルー)
			fake_hit                   = false,
			obsl_hit                   = false, -- 嘘判定チェック用
			full_hit                   = false, -- 判定チェック用1
			harmless2                  = false, -- 判定チェック用2 飛び道具専用
			prj_rank                   = 0, -- 飛び道具の強さ
			esaka_range                = 0, -- 詠酒の間合いチェック用

			key_now                    = {}, -- 個別キー入力フレーム
			key_pre                    = {}, -- 前フレームまでの個別キー入力フレーム
			key_hist                   = {},
			ggkey_hist                 = {},
			key_frames                 = {},
			act_frame                  = 0,
			act_frames                 = {},
			act_frames2                = {},
			act_frames_total           = 0,

			muteki                     = {
				act_frames  = {},
				act_frames2 = {},
			},

			frm_gap                    = {
				act_frames  = {},
				act_frames2 = {},
			},

			reg_pcnt                   = 0, -- キー入力 REG_P1CNT or REG_P2CNT
			reg_st_b                   = 0, -- キー入力 REG_STATUS_B

			update_sts                 = 0,
			update_dmg                 = 0,
			update_act                 = 0,
			random_boolean             = math.random(255) % 2 == 0,

			backstep_killer            = false,
			need_block                 = false,
			need_low_block             = false,

			hitboxes                   = {},
			buffer                     = {},
			uniq_hitboxes              = {}, -- key + boolean
			hitbox_txt                 = "",
			hurtbox_txt                = "",
			chg_hitbox_frm             = 0,
			chg_hurtbox_frm            = 0,
			type_boxes                 = {}, -- key + count
			fireball_bases             = new_set(base + 0x200, base + 0x400, base + 0x600),
			fake_hits                  = p1 and
				{ [base + 0x200] = 0x10DDF5, [base + 0x400] = 0x10DDF7, [base + 0x600] = 0x10DDF9, } or
				{ [base + 0x200] = 0x10DDF6, [base + 0x400] = 0x10DDF8, [base + 0x600] = 0x10DDFA, },
			fireball                   = {},

			bs_hooked                  = 0, -- BSモードのフック処理フレーム数。

			all_summary                = {}, -- 大状態表示のデータ構造
			atk_summary                = {}, -- 大状態表示のデータ構造の一部
			hit_summary                = {}, -- 大状態表示のデータ構造の一部
			old_hit_summary            = {}, -- 大状態表示のデータ構造の一部

			fix_scr_top                = 0xFF, -- screen_topの強制フック用

			hit                        = {
				pos_x        = 0,
				pos_z        = 0,
				pos_y        = 0,
				on           = 0,
				flip_x       = 0,
				scale        = 0,
				char_id      = 0,
				vulnerable   = 0,
				harmless     = false,
				obsl_hit     = false,
				full_hit     = false,
				harmless2    = false,
				vulnerable1  = 0,
				vulnerable21 = 0,
				vulnerable22 = 0, -- 0の時vulnerable=true
			},

			throw                      = {
				x1         = 0,
				x2         = 0,
				half_range = 0,
				full_range = 0,
				in_range   = false,
			},

			n_throw                    = {
				addr = {
					on       = p1 and 0x10CD90 or 0x10CDB0,
					base     = p1 and 0x10CD91 or 0x10CDB1,
					opp_base = p1 and 0x10CD95 or 0x10CDB5,
					opp_id   = p1 and 0x10CD9A or 0x10CDBA,
					char_id  = p1 and 0x10CD9C or 0x10CDBC,
					side     = p1 and 0x10CDA0 or 0x10CDC0,
					range1   = p1 and 0x10CDA1 or 0x10CDC1,
					range2   = p1 and 0x10CDA2 or 0x10CDC2,
					range3   = p1 and 0x10CDA3 or 0x10CDC3,
					range41  = p1 and 0x10CDA4 or 0x10CDC4,
					range42  = p1 and 0x10CDA5 or 0x10CDC5,
					range5   = p1 and 0x10CDA6 or 0x10CDC6,
					id       = p1 and 0x10CDA7 or 0x10CDC7,
					pos_x    = p1 and 0x10CDA8 or 0x10CDC8,
					pos_y    = p1 and 0x100DAA or 0x10CDCA,
				},
			},

			air_throw                  = {
				addr = {
					on       = p1 and 0x10CD00 or 0x10CD20,
					range_x  = p1 and 0x10CD01 or 0x10CD21,
					range_y  = p1 and 0x10CD03 or 0x10CD23,
					base     = p1 and 0x10CD05 or 0x10CD25,
					opp_base = p1 and 0x10CD09 or 0x10CD29,
					opp_id   = p1 and 0x10CD0D or 0x10CD2D,
					side     = p1 and 0x10CD11 or 0x10CD31,
					id       = p1 and 0x10CD12 or 0x10CD32,
					pos_x    = p1 and 0x10CD13 or 0x10CD33,
					pos_y    = p1 and 0x10CD15 or 0x10CD35,
				},
			},

			sp_throw                   = {
				addr = {
					on       = p1 and 0x10CD40 or 0x10CD60,
					front    = p1 and 0x10CD41 or 0x10CD61,
					top      = p1 and 0x10CD43 or 0x10CD63,
					base     = p1 and 0x10CD45 or 0x10CD65,
					opp_base = p1 and 0x10CD49 or 0x10CD69,
					opp_id   = p1 and 0x10CD4D or 0x10CD6D,
					side     = p1 and 0x10CD51 or 0x10CD71,
					bottom   = p1 and 0x10CD52 or 0x10CD72,
					id       = p1 and 0x10CD54 or 0x10CD74,
					pos_x    = p1 and 0x10CD55 or 0x10CD75,
					pos_y    = p1 and 0x10CD57 or 0x10CD77,
				},
			},

			addr                       = {
				base         = base,            -- キャラ状態とかのベースのアドレス
				act          = base + 0x60,     -- 行動ID デバッグディップステータス表示のPと同じ
				acta         = base + 0x62,     -- 行動ID デバッグディップステータス表示のAと同じ
				act_count    = base + 0x66,     -- 現在の行動のカウンタ
				act_boxtype  = base + 0x67,     -- 現在の行動の判定種類
				act_frame    = base + 0x6F,     -- 現在の行動の残フレーム、ゼロになると次の行動へ
				act_contact  = base + 0x01,     -- 通常=2、必殺技中=3 ガードヒット=5 潜在ガード=6
				attack       = base + 0xB6,     -- 攻撃中のみ変化、判定チェック用2 0のときは何もしていない、 詠酒の間合いチェック用
				hitstop_id   = base + 0xEB,     -- 被害中のみ変化
				can_techrise = base + 0x92,     -- 受け身行動可否チェック用
				ophit_base   = base + 0x9E,     -- ヒットさせた相手側のベースアドレス
				char         = p1 and 0x107BA5 or 0x107BA7, -- キャラID
				color        = p1 and 0x107BAC or 0x107BAD, -- カラー A=0x00 D=0x01
				combo        = p1 and 0x10B4E4 or 0x10B4E5, -- コンボ
				combo2       = p1 and 0x10B4E5 or 0x10B4E4, -- 最近のコンボ数のアドレス
				dmg_id       = base + 0xE9,     -- ダメージ算出の技ID(最後にヒット/ガードした技のID)
				tmp_combo2   = p1 and 0x10B4E1 or 0x10B4E0, -- 一次的なコンボ数のアドレス
				max_combo2   = p1 and 0x10B4F0 or 0x10B4EF, -- 最大コンボ数のアドレス
				dmg_scl7     = p1 and 0x10DE50 or 0x10DE51, -- 補正 7/8 の回数
				dmg_scl6     = p1 and 0x10DE52 or 0x10DE53, -- 補正 6/8 の回数
				dmg_scl5     = p1 and 0x10DE54 or 0x10DE55, -- 補正 5/8 の回数
				dmg_scl4     = p1 and 0x10DE56 or 0x10DE57, -- 補正 4/8 の回数
				last_dmg     = base + 0x8F,     -- 最終ダメージ
				tmp_dmg      = p1 and 0x10CA10 or 0x10CA11, -- 最終ダメージの更新フック
				pure_dmg     = p1 and 0x10DDFB or 0x10DDFC, -- 最終ダメージ(補正前)
				tmp_pow      = p1 and 0x10DE59 or 0x10DE58, -- POWゲージ増加量
				tmp_pow_rsv  = p1 and 0x10DE5B or 0x10DE5A, -- POWゲージ増加量(予約値)
				tmp_stun     = p1 and 0x10DDFD or 0x10DDFF, -- 最終気絶値
				tmp_st_timer = p1 and 0x10DDFE or 0x10DE00, -- 最終気絶タイマー
				life         = base + 0x8B,     -- 体力
				max_combo    = p1 and 0x10B4EF or 0x10B4F0, -- 最大コンボ
				max_stun     = p1 and 0x10B84E or 0x10B856, -- 最大気絶値
				corner       = base + 0xB7,     -- 画面端状態 0:端以外 1:画面端 3:端押し付け
				pos          = base + 0x20,     -- X座標
				pos_frc      = base + 0x22,     -- X座標 少数部
				max_pos      = p1 and 0x10DDE6 or 0x10DDE8, -- X座標最大
				min_pos      = p1 and 0x10DDEA or 0x10DDEC, -- X座標最小
				pos_y        = base + 0x28,     -- Y座標
				pos_frc_y    = base + 0x2A,     -- Y座標 少数部
				pos_z        = base + 0x24,     -- Z座標
				sway_status  = base + 0x89,     -- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
				side         = base + 0x58,     -- 向き
				--forward    = base + 0x40, -- 前移動速度 8バイト
				--backward   = 0x0022FAE -- 後退のベースアドレス
				input_side   = base + 0x86,     -- コマンド入力でのキャラ向きチェック用 00:左側 80:右側
				input1       = base + 0x82,     -- キー入力 直近Fの入力
				input2       = base + 0x83,     -- キー入力 1F前の入力
				cln_btn      = base + 0x84,     -- クリアリングされたボタン入力
				state        = base + 0x8E,     -- 状態
				flag_c0      = base + 0xC0,     -- フラグ群
				flag_c4      = base + 0xC4,     -- フラグ群
				flag_c8      = base + 0xC8,     -- フラグ群
				flag_cc      = base + 0xCC,     -- フラグ群 00 00 00 00
				flag_d0      = base + 0xD0,     -- フラグ群
				stop         = base + 0x8D,     -- ヒットストップ
				knock_back1  = base + 0x69,     -- のけぞり確認用1(色々)
				knock_back2  = base + 0x16,     -- のけぞり確認用2(裏雲隠し)
				knock_back3  = base + 0x7E,     -- のけぞり確認用3(フェニックススルー)
				sp_throw_id  = base + 0xA3,     -- 投げ必殺のID
				sp_throw_act = base + 0xA4,     -- 投げ必殺の持続残F
				additional   = base + 0xA5,     -- 追加入力成立時のデータ
				prj_rank     = base + 0xB5,     -- 飛び道具の強さ
				input_offset = p1 and 0x0394C4 or 0x0394C8, -- コマンド入力状態のオフセットアドレス
				no_hit       = p1 and 0x10DDF2 or 0x10DDF1, -- ヒットしないフック
				-- range        = 0x1004E2 or 0x1005E2 -- 距離 0近距離 1中距離 2遠距離
				cancelable   = base + 0xAF,     -- キャンセル可否 00不可 C0可 D0可 正確ではない
				repeatable   = base + 0x6A,     -- 連キャン可否用
				box_base1    = base + 0x76,     -- 判定の開始アドレス1、判定データはバンク切替されている場合あり
				box_base2    = base + 0x7A,     -- 判定の開始アドレス2、判定データはバンク切替されている場合あり
				kaiser_wave  = base + 0xFB,     -- カイザーウェイブのレベル
				hurt_state   = base + 0xE4,     -- やられ状態

				-- キャラ毎の必殺技の番号 0x1004B8
				-- 技の内部の進行度 0x1004F7

				stun         = p1 and 0x10B850 or 0x10B858, -- 現在気絶値
				stun_timer   = p1 and 0x10B854 or 0x10B85C, -- 気絶値ゼロ化までの残フレーム数
				tmp_combo    = p1 and 0x10B4E0 or 0x10B4E1, -- コンボテンポラリ
				-- bs_id        = base + 0xB9, -- BSの技ID
				pow          = base + 0xBC,     -- パワーアドレス
				reg_pcnt     = p1 and 0x300000 or 0x340000, -- キー入力 REG_P1CNT or REG_P2CNT アドレス
				reg_st_b     = 0x380000,        -- キー入力 REG_STATUS_B アドレス
				control1     = base + 0x12,     -- Human 1 or 2, CPU 3
				control2     = base + 0x13,     -- Human 1 or 2, CPU 3

				select_hook  = p1 and 0x10CDD1 or 0x10CDD5, -- プレイヤーセレクト画面のフック処理用アドレス
				bs_hook1     = p1 and 0x10DDDA or 0x10DDDE, -- BSモードのフック処理用アドレス。技のID。
				bs_hook2     = p1 and 0x10DDDB or 0x10DDDF, -- BSモードのフック処理用アドレス。技のバリエーション。
				bs_hook3     = p1 and 0x10DDDD or 0x10DDE1, -- BSモードのフック処理用アドレス。技発動。

				tw_threshold = p1 and 0x10DDE2 or 0x10DDE3, -- 投げ可能かどうかのフレーム判定のしきい値
				tw_frame     = base + 0x90,     -- 投げ可能かどうかのフレーム経過
				tw_accepted  = p1 and 0x10DDE4 or 0x10DDE5, -- 投げ確定時のフレーム経過
				tw_muteki    = base + 0xF6,     -- 投げ無敵の残フレーム数

				-- フックできないかわり用
				state2       = p1 and 0x10CA0E or 0x10CA0F, -- 状態
				act2         = p1 and 0x10CA12 or 0x10CA14, -- 行動ID デバッグディップステータス表示のPと同じ

				-- フックできないかわり用-当たり判定
				vulnerable1  = p1 and 0x10CB30 or 0x10CB31,
				vulnerable21 = p1 and 0x10CB32 or 0x10CB33,
				vulnerable22 = p1 and 0x10CB34 or 0x10CB35, -- 0の時vulnerable=true

				-- ヒットするかどうか
				fake_hit     = p1 and 0x10DDF3 or 0x10DDF4, -- 出だしから嘘判定のフック
				obsl_hit     = base + 0x6A,     -- 嘘判定チェック用 3ビット目が立っていると嘘判定
				full_hit     = base + 0xAA,     -- 判定チェック用1 0じゃないとき全段攻撃ヒット/ガード
				max_hit_nm   = base + 0xAB,     -- 同一技行動での最大ヒット数 分子

				-- スクショ用
				fix_scr_top  = p1 and 0x10DE5C or 0x10DE5D, -- screen_topの強制フック用

				force_block  = p1 and 0x10DE5E or 0x10DE5F, -- 強制ガード用
			},
		}

		for i = 1, #kprops do
			players[p].key_now[kprops[i]] = 0
			players[p].key_pre[kprops[i]] = 0
		end
		for i = 1, 16 do
			players[p].key_hist[i] = ""
			players[p].key_frames[i] = 0
			players[p].act_frames[i] = { 0, 0 }
			players[p].bases[i] = { count = 0, addr = 0x0, act_data = nil, name = "", pos1 = 0, pos2 = 0, xmov = 0, }
		end
	end
	players[1].op = players[2]
	players[2].op = players[1]
	-- 飛び道具領域の作成
	for _, p in ipairs(players) do
		for base, _ in pairs(p.fireball_bases) do
			p.fireball[base] = {
				addr = {
					base        = base, -- キャラ状態とかのベースのアドレス
					char        = base + 0x10, -- 技のキャラID
					act         = base + 0x60, -- 技のID デバッグのP
					acta        = base + 0x62, -- 技のID デバッグのA
					actb        = base + 0x64, -- 技のID?
					act_count   = base + 0x66, -- 現在の行動のカウンタ
					act_boxtype = base + 0x67, -- 現在の行動の判定種類
					act_frame   = base + 0x6F, -- 現在の行動の残フレーム、ゼロになると次の行動へ
					act_contact = base + 0x01, -- 通常=2、必殺技中=3 ガードヒット=5 潜在ガード=6
					dmg_id      = base + 0xE9, -- 最後にヒット/ガードしたダメージ算出の技ID
					pos         = base + 0x20, -- X座標
					pos_y       = base + 0x28, -- Y座標
					pos_z       = base + 0x24, -- Z座標
					attack      = base + 0xBF, -- デバッグのNO
					hitstop_id  = base + 0xBE, -- ヒット硬直用ID、受け身行動可否チェック用、倍返しチェック2
					fake_hit    = p.fake_hits[base], -- ヒットするかどうか
					obsl_hit    = base + 0x6A, -- 嘘判定チェック用 3ビット目が立っていると嘘判定
					full_hit    = base + 0xAA, -- 判定チェック用1 0じゃないとき全段攻撃ヒット/ガード
					harmless2   = base + 0xE7, -- 判定チェック用2 0じゃないときヒット/ガード
					max_hit_nm  = base + 0xAB, -- 同一技行動での最大ヒット数 分子
					prj_rank    = base + 0xB5, -- 飛び道具の強さ
					side        = base + 0x58, -- 向き
					box_base1   = base + 0x76,
					box_base2   = base + 0x7A,
					bai_chk1    = base + 0x8A, -- 倍返しチェック1
				},
			}
		end
	end

	-- Fireflower形式のパッチファイルの読込とメモリへの書込
	local pached = false
	local ffptn = "%s*(%w+):%s+(%w+)%s+(%w+)%s*[\r\n]*"
	local fixaddr = function(saddr, offset)
		local addr = tonumber(saddr, 16) + offset
		if (addr % 2 == 0) then
			return addr + 1
		else
			return addr - 1
		end
	end
	local apply_patch = function(s_patch, offset, force)
		if force ~= true then
			for saddr, v1, v2 in string.gmatch(s_patch, ffptn) do
				local before = pgm:read_u8(fixaddr(saddr, offset))
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
	local apply_patch_file = function(patch, force)
		local ret = false
		if pgm then
			local path = rom_patch_path(patch)
			print(path .. " patch " .. (force and "force" or ""))
			local f = io.open(path, "r")
			if f then
				for line in f:lines() do
					ret = apply_patch(line, 0x000000, force)
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

	-- 場面変更
	local apply_1p2p_active = function()
		pgm:write_direct_u8(0x100024, 0x03) -- 1P or 2P
		pgm:write_direct_u8(0x100027, 0x03) -- 1P or 2P
	end

	local apply_vs_mode = function(continue)
		apply_1p2p_active()
		if not continue then
			pgm:write_direct_u8(0x107BB5, 0x01) -- vs 1st CPU mode
		end
	end

	local goto_player_select = function()
		dofile(ram_patch_path("player-select.lua"))
		apply_vs_mode(false)
	end

	local restart_fight = function(param)
		param                = param or {}
		local stg1           = param.next_stage.stg1 or menu.stgs[1].stg1
		local stg2           = param.next_stage.stg2 or menu.stgs[1].stg2
		local stg3           = param.next_stage.stg3 or menu.stgs[1].stg3
		global.no_background = (param.next_stage or menu.stgs[1]).no_background
		local p1             = param.next_p1 or 1
		local p2             = param.next_p2 or 21
		local p1col          = param.next_p1col or 0x00
		local p2col          = param.next_p2col or 0x01
		local bgm            = param.next_bgm or 21

		dofile(ram_patch_path("vs-restart.lua"))
		apply_vs_mode(true)

		local p = players

		pgm:write_u8(0x107BB1, stg1)
		pgm:write_u8(0x107BB7, stg2)
		pgm:write_u8(0x107BB9, stg3) -- フックさせて無理やり実現するために0xD0を足す（0xD1～0xD5にする）
		pgm:write_u8(p[1].addr.char, p1)
		pgm:write_u8(p[1].addr.color, p1col)
		pgm:write_u8(p[2].addr.char, p2)
		if p1 == p2 then
			p2col = p1col == 0x00 and 0x01 or 0x00
		end
		pgm:write_u8(p[2].addr.color, p2col)
		pgm:write_u8(0x10A8D5, bgm) --BGM

		-- メニュー用にキャラの番号だけ差し替える
		players[1].char = p1
		players[2].char = p2
	end
	--

	-- ブレイクポイント発動時のデバッグ画面表示と停止をさせない
	local debug_stop = 0
	local auto_recovery_debug = function()
		if debugger then
			if debugger.execution_state ~= "run" then
				debug_stop = debug_stop + 1
			end
			if 3 > debug_stop then
				debugger.execution_state = "run"
				debug_stop = 0
			end
		end
	end

	-- 対スウェーライン攻撃の近距離間合い
	-- 地上通常技の近距離間合い
	-- char 0=テリー
	local cache_close_far_pos = {}
	local get_close_far_pos = function(char)
		if cache_close_far_pos[char] then
			return cache_close_far_pos[char]
		end
		local org_char                = char
		char                          = char - 1
		local abc_offset              = mem.close_far_offset + (char * 4)
		-- 家庭用02DD02からの処理
		local d_offset                = mem.close_far_offset_d + (char * 2)
		local ret                     = {
			a = { x1 = 0, x2 = pgm:read_u8(abc_offset) },
			b = { x1 = 0, x2 = pgm:read_u8(abc_offset + 1) },
			c = { x1 = 0, x2 = pgm:read_u8(abc_offset + 2) },
			d = { x1 = 0, x2 = pgm:read_u16(d_offset) },
		}
		cache_close_far_pos[org_char] = ret
		return ret
	end

	local get_lmo_range_internal = function(ret, name, d0, d1, incl_last)
		local decd1 = int16tofloat(d1)
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

	local cache_close_far_pos_lmo = {}
	local get_close_far_pos_line_move_attack = function(char, logging)
		if cache_close_far_pos_lmo[char] then
			return cache_close_far_pos_lmo[char]
		end

		-- 家庭用2EC72,2EDEE,2E1FEからの処理
		local offset = 0x2EE06
		local d1 = 0x2A000 -- 整数部上部4バイト、少数部下部4バイト
		local decd1 = int16tofloat(d1)
		local ret = {}
		-- 0:近A 1:遠A 2:近B 3:遠B 4:近C 5:遠C
		for i, act_name in ipairs({ "近A", "遠A", "近B", "遠B", "近C", "遠C" }) do
			local d0 = pgm:read_u8(pgm:read_u32(offset + (i - 1) * 4) + char * 6)
			-- データが近距離、遠距離の2種類しかないのと実質的に意味があるのが近距離のものなので最初のデータだけ返す
			if i == 1 then
				get_lmo_range_internal(ret, "", d0, d1, true)
				ret["近"] = { x1 = 0, x2 = 72 } -- 近距離攻撃になる距離

				if char == 6 then
					-- 渦炎陣
					get_lmo_range_internal(ret, "必", 24, 0x40000)
				elseif char == 14 then
					-- クロスヘッドスピン
					get_lmo_range_internal(ret, "必", 24, 0x80000)
				end
			end
			if logging then
				printf("%s %s %x %s %x %s", chars[char].name, act_name, d0, d0, d1, decd1)
			end
		end
		cache_close_far_pos_lmo[char] = ret
		return ret
	end

	local load_or_set_bps = function(hook_holder, p, enabled, addr, cond, exec)
		if hook_holder ~= nil then
			global.set_bps(enabled ~= true, hook_holder)
		else
			hook_holder = global.new_hook_holder()
			global.bp(hook_holder.bps, addr, cond, exec)
			global.set_bps(enabled ~= true, hook_holder)
		end
		return hook_holder
	end

	-- 詠酒の距離チェックを飛ばす
	local set_skip_esaka_check = function(p, enabled)
		p.skip_esaka_check = load_or_set_bps(p.skip_esaka_check, p, enabled,
			0x0236F2, string.format("(A4)==$%x", p.addr.base), "PC=2374C;g")
	end

	-- 自動 炎の種馬
	-- bp 04094A,1,{PC=040964;g}
	local set_auto_taneuma = function(p, enabled)
		p.auto_taneuma = load_or_set_bps(p.auto_taneuma, p, enabled,
			fix_bp_addr(0x04092A), string.format("(A4)==$%x", p.addr.base), string.format("PC=%x;g", fix_bp_addr(0x040944)))
	end

	-- 必勝！逆襲拳1発キャッチカデンツァ
	-- bp 0409A6,1,{maincpu.pb@(f7+(A4))=7;D0=7;g}
	local set_fast_kadenzer = function(p, enabled)
		p.fast_kadenze = load_or_set_bps(p.fast_kadenze, p, enabled,
			fix_bp_addr(0x040986), string.format("(A4)==$%x", p.addr.base), "maincpu.pb@(f7+(A4))=7;D0=7;g")
	end

	-- 自動喝CA
	-- bp 03F94C,1,{PC=03F952;g}
	-- bp 03F986,1,{PC=3F988;g}
	local set_auto_katsu = function(p, enabled)
		p.auto_katsu1 = load_or_set_bps(p.auto_katsu1, p, enabled,
			fix_bp_addr(0x03F92C), string.format("(A4)==$%x", p.addr.base), string.format("PC=%x;g", fix_bp_addr(0x03F932)))
		p.auto_katsu2 = load_or_set_bps(p.auto_katsu2, p, enabled,
			fix_bp_addr(0x03F966), string.format("(A4)==$%x", p.addr.base), string.format("PC=%x;g", fix_bp_addr(0x03F968)))
	end

	-- 空振りCAできる
	-- bp 02FA5E,1,{PC=02FA6A;g}
	local set_kara_ca = function(p, enabled)
		p.kara_ca = load_or_set_bps(p.kara_ca, p, enabled,
			fix_bp_addr(0x02FA1E), string.format("(A4)==$%x", p.addr.base), string.format("PC=%x;g", fix_bp_addr(0x02FA4A)))
	end

	local new_empty_table = function(len)
		local tmp_table = {}
		for i = 1, len do
			table.insert(tmp_table, nil)
		end
		return tmp_table
	end

	local new_filled_table = function(...)
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

	--  自動デッドリー
	local set_auto_deadly = function(p, count)
		p.auto_deadly = p.auto_deadly or new_empty_table(11)
		--  自動デッドリー最後
		p.auto_deadly[11] = load_or_set_bps(p.auto_deadly[11], p, count == 10,
			fix_bp_addr(0x03DBC4), string.format("(A4)==$%x", p.addr.base), string.format("PC=%x;g", fix_bp_addr(0x03DBE2)))
		--  自動デッドリー途中
		local check_count = count - 1
		for i = 1, 10 do
			p.auto_deadly[i] = load_or_set_bps(p.auto_deadly[i], p, i == check_count,
				fix_bp_addr(0x03DCE8), string.format("(A4)==$%x&&D1<%x", p.addr.base, i), string.format("PC=%x;g", fix_bp_addr(0x03DD16)))
		end
	end

	-- 自動マリートリプルエクスタシー
	local set_auto_3ecst = function(p, enabled)
		p.auto_3ecst = load_or_set_bps(p.auto_3ecst, p, enabled,
			fix_bp_addr(0x041CE0), string.format("(A4)==$%x", p.addr.base), string.format("PC=%x;g", fix_bp_addr(0x041CFC)))
	end

	-- ドリルLVセット
	local set_auto_drill = function(p, count)
		p.auto_drill = p.auto_drill or new_empty_table(5)
		local check_count = count - 1
		for i = 1, 5 do
			p.auto_drill[i] = load_or_set_bps(p.auto_drill[i], p, i == check_count,
				fix_bp_addr(0x042C10), string.format("(A4)==$%x", p.addr.base), string.format("D7=%x;g", i))
		end
	end

	-- 自動アンリミ
	local set_auto_unlimit = function(p, count)
		p.auto_unlimit = p.auto_unlimit or new_empty_table(11)
		-- 自動アンリミサイクロン
		p.auto_unlimit[11] = load_or_set_bps(p.auto_unlimit[11], p, count == 11,
			fix_bp_addr(0x049966), string.format("(A4)==$%x", p.addr.base), string.format("PC=%x;g", fix_bp_addr(0x4998A)))
		-- 自動アンリミ途中
		local check_count = count == 11 and 9 or (count - 1)
		for i = 1, 10 do
			p.auto_unlimit[i] = load_or_set_bps(p.auto_unlimit[i], p, i == check_count,
				fix_bp_addr(0x049B1C), string.format("(A4)==$%x&&D1<%x", p.addr.base, i), string.format("PC=%x;g", fix_bp_addr(0x049B4E)))
		end
	end

	-- 当たり判定と投げ判定用のブレイクポイントとウォッチポイントのセット
	local set_wps = function(reset)
		if global.wps then
			global.set_wps(reset, global.wps)
		else
			global.wps = global.new_hook_holder()
			local wps = global.wps.wps
			global.wp(wps, "w", 0x1006BF, 1, "wpdata!=0", "maincpu.pb@10CA00=1;g")
			global.wp(wps, "w", 0x1007BF, 1, "wpdata!=0", "maincpu.pb@10CA01=1;g")
			global.wp(wps, "w", 0x100620, 1, "wpdata!=0", "maincpu.pb@10CA02=1;g")
			global.wp(wps, "w", 0x10062C, 1, "wpdata!=0", "maincpu.pb@10CA03=1;g")
			global.wp(wps, "w", 0x100820, 1, "wpdata!=0", "maincpu.pb@10CA04=1;g")
			global.wp(wps, "w", 0x10082C, 1, "wpdata!=0", "maincpu.pb@10CA05=1;g")
			global.wp(wps, "w", 0x100A20, 1, "wpdata!=0", "maincpu.pb@10CA06=1;g")
			global.wp(wps, "w", 0x100A2C, 1, "wpdata!=0", "maincpu.pb@10CA07=1;g")
			global.wp(wps, "w", 0x100720, 1, "wpdata!=0", "maincpu.pb@10CA08=1;g")
			global.wp(wps, "w", 0x10072C, 1, "wpdata!=0", "maincpu.pb@10CA09=1;g")
			global.wp(wps, "w", 0x100920, 1, "wpdata!=0", "maincpu.pb@10CA0A=1;g")
			global.wp(wps, "w", 0x10092C, 1, "wpdata!=0", "maincpu.pb@10CA0B=1;g")
			global.wp(wps, "w", 0x100B20, 1, "wpdata!=0", "maincpu.pb@10CA0C=1;g")
			global.wp(wps, "w", 0x100B2C, 1, "wpdata!=0", "maincpu.pb@10CA0D=1;g")
			global.wp(wps, "w", 0x10048E, 1, "wpdata!=0", "maincpu.pb@10CA0E=maincpu.pb@10048E;g")
			global.wp(wps, "w", 0x10058E, 1, "wpdata!=0", "maincpu.pb@10CA0F=maincpu.pb@10058E;g")
			global.wp(wps, "w", 0x10048F, 1, "1", "maincpu.pb@10CA10=wpdata;g")
			global.wp(wps, "w", 0x10058F, 1, "1", "maincpu.pb@10CA11=wpdata;g")
			global.wp(wps, "w", 0x100460, 1, "wpdata!=0", "maincpu.pw@10CA12=wpdata;g")
			global.wp(wps, "w", 0x100560, 1, "wpdata!=0", "maincpu.pw@10CA14=wpdata;g")

			-- X軸のMAXとMIN
			global.wp(wps, "w", 0x100420, 2, "wpdata>maincpu.pw@10DDE6", "maincpu.pw@10DDE6=wpdata;g")
			global.wp(wps, "w", 0x100420, 2, "wpdata<maincpu.pw@10DDEA", "maincpu.pw@10DDEA=wpdata;g")
			global.wp(wps, "w", 0x100520, 2, "wpdata>maincpu.pw@10DDE8", "maincpu.pw@10DDE8=wpdata;g")
			global.wp(wps, "w", 0x100520, 2, "wpdata<maincpu.pw@10DDEC", "maincpu.pw@10DDEC=wpdata;g")

			-- コマンド入力状態の記憶場所 A1
			-- bp 39488,{(A4)==100400},{printf "PC=%X A4=%X A1=%X",PC,(A4),(A1);g}

			-- タメ状態の調査用
			-- global.wp(wps, "w", 0x10B548, 160, "wpdata!=FF&&wpdata>0&&maincpu.pb@(wpaddr)==0", "printf \"pos=%X addr=%X wpdata=%X\", (wpaddr - $10B548),wpaddr,wpdata;g")

			-- 必殺技追加入力の調査用
			-- wp 1004A5,1,r,wpdata!=FF,{printf "PC=%X data=%X",PC,wpdata;g} -- 追加入力チェックまたは技処理内での消去
			-- wp 1004A5,1,w,wpdata==0,{printf "PC=%X data=%X CLS",PC,wpdata;g} -- 更新 追加技入力時
			-- wp 1004A5,1,w,wpdata!=maincpu.pb@(wpaddr),{printf "PC=%X data=%X W",PC,wpdata;g} -- 消去（毎フレーム）

			--[[
			-- コマンド成立の確認用
			for i, p in ipairs(players) do
				global.wp(wps, "w", p.addr.base + 0xA4, 2, "wpdata>0",
					"printf \"wpdata=%X CH=%X CH4=%D PC=%X PREF_ADDR=%X A4=%X A6=%X D1=%X\",wpdata,maincpu.pw@((A4)+10),maincpu.pw@((A4)+10),PC,PREF_ADDR,(A4),(A6),(D1);g")
			end
			]]
			--[[
			-- 投げ持続フレームの解除の確認用
			for i, p in ipairs(players) do
				global.wp(wps, "w", p.addr.base + 0xA4, 2, "wpdata==0&&maincpu.pb@" ..  string.format("%x", p.addr.base) .. ">0",
					"printf \"wpdata=%X CH=%X CH4=%D PC=%X PREF_ADDR=%X A4=%X A6=%X D1=%X\",wpdata,maincpu.pw@((A4)+10),maincpu.pw@((A4)+10),PC,PREF_ADDR,(A4),(A6),(D1);g")
			end
			]]
		end
	end

	local set_bps = function(reset)
		if global.bps then
			global.set_bps(reset, global.bps)
		else
			global.bps = global.new_hook_holder()
			local bps = global.bps

			if global.infinity_life2 then
				--bp 05B480,{(maincpu.pw@107C22>0)&&($100400<=((A3)&$FFFFFF))&&(((A3)&$FFFFFF)<=$100500)},{PC=5B48E;g}
				global.bp(bps, fix_bp_addr(0x05B460), "1", string.format("PC=%x;g", fix_bp_addr(0x05B46E)))
				global.bp(bps, fix_bp_addr(0x05B466), "1", string.format("PC=%x;g", fix_bp_addr(0x05B46E)))
			end

			-- wp CB23E,16,r,{A4==100400},{printf "A4=%X PC=%X A6=%X D1=%X data=%X",A4,PC,A6,D1,wpdata;g}

			-- リバーサルとBSモードのフック
			local bp_cond = "(maincpu.pw@107C22>0)&&((($1E> maincpu.pb@10DDDA)&&(maincpu.pb@10DDDD==$1)&&($100400==((A4)&$FFFFFF)))||(($1E> maincpu.pb@10DDDE)&&(maincpu.pb@10DDE1==$1)&&($100500==((A4)&$FFFFFF))))"
			local bp_cnd2 = "(maincpu.pw@107C22>0)&&((($1E<=maincpu.pb@10DDDA)&&(maincpu.pb@10DDDD==$1)&&($100400==((A4)&$FFFFFF)))||(($1E<=maincpu.pb@10DDDE)&&(maincpu.pb@10DDE1==$1)&&($100500==((A4)&$FFFFFF))))"
			-- ダッシュとか用
			-- BPモードON 未入力で技発動するように
			global.bp(bps, fix_bp_addr(0x039512), "((A6)==CB242)&&" .. bp_cnd2, "D1=0;g")
			-- 技入力データの読み込み
			global.bp(bps, fix_bp_addr(0x03957E), "((A6)==CB244)&&" .. bp_cnd2,
				"temp1=$10DDDA+((((A4)&$FFFFFF)-$100400)/$40);D1=(maincpu.pb@(temp1));A6=((A6)+1);maincpu.pb@((A4)+$D6)=D1;maincpu.pb@((A4)+$D7)=maincpu.pb@(temp1+1);PC=((PC)+$20);g")
			-- 必殺技用
			-- BPモードON 未入力で技発動するように
			global.bp(bps, fix_bp_addr(0x039512), "((A6)==CB242)&&" .. bp_cond, "D1=0;g")
			-- 技入力データの読み込み
			-- bp 03957E,{((A6)==CB244)&&((A4)==100400)&&(maincpu.pb@10048E==2)},{D1=1;g}
			-- bp 03957E,{((A6)==CB244)&&((A4)==100500)&&(maincpu.pb@10058E==2)},{D1=1;g}
			-- 0395B2: 1941 00A3                move.b  D1, ($a3,A4) -- 確定した技データ
			-- 0395B6: 195E 00A4                move.b  (A6)+, ($a4,A4) -- 技データ読込 だいたい06
			-- 0395BA: 195E 00A5                move.b  (A6)+, ($a5,A4) -- 技データ読込 だいたい00、飛燕斬01、02、03
			global.bp(bps, fix_bp_addr(0x03957E), "((A6)==CB244)&&" .. bp_cond,
				"temp1=$10DDDA+((((A4)&$FFFFFF)-$100400)/$40);D1=(maincpu.pb@(temp1));A6=((A6)+2);maincpu.pb@((A4)+$A3)=D1;maincpu.pb@((A4)+$A4)=maincpu.pb@(temp1+1);maincpu.pb@((A4)+$A5)=maincpu.pb@(temp1+2);PC=((PC)+$20);g")

			-- ステージ設定用。メニューでFを設定した場合にのみ動作させる
			-- ラウンド数を1に初期化→スキップ
			global.bp(bps, 0x0F368, "maincpu.pw@((A5)-$448)==$F", "PC=F36E;g")
			-- ラウンド2以上の場合の初期化処理→無条件で実施
			global.bp(bps, 0x22AD8, "maincpu.pw@((A5)-$448)==$F", "PC=22AF4;g")
			-- キャラ読込 ラウンド1の時だけ読み込む→無条件で実施
			global.bp(bps, 0x22D32, "maincpu.pw@((A5)-$448)==$F", "PC=22D3E;g")
			-- ラウンド2以上の時の処理→データロード直後の状態なので不要。スキップしないとBGMが変わらない
			global.bp(bps, 0x0F6AC, "maincpu.pw@((A5)-$448)==$F", "PC=F6B6;g")
			-- ラウンド1じゃないときの処理 →スキップ
			global.bp(bps, 0x1E39A, "maincpu.pw@((A5)-$448)==$F", "PC=1E3A4;g")
			-- ラウンド1の時だけ読み込む →無条件で実施。データを1ラウンド目の値に戻す
			global.bp(bps, 0x17694, "maincpu.pw@((A5)-$448)==$F", "maincpu.pw@((A5)-$448)=1;PC=176A0;g")

			-- 当たり判定用
			-- 喰らい判定フラグ用
			global.bp(bps, fix_bp_addr(0x5C2DA),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CB30+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=$01;g")

			-- 喰らい判定用
			global.bp(bps, fix_bp_addr(0x5C2E6),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CB32+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=$01;maincpu.pb@(temp1+$2)=(maincpu.pb@(((A4)+$B1)&$FFFFFF));g")

			--判定追加1 攻撃判定
			global.bp(bps, fix_bp_addr(0x012C42),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100F00)",
				--"printf \"PC=%X A4=%X A2=%X D0=%X CT=%X\",PC,A4,A2,D0,($1DC000+((maincpu.pb@10CB40)*$10));"..
				"temp0=($1DC000+((maincpu.pb@10CB40)*$10));maincpu.pb@(temp0)=1;maincpu.pb@(temp0+1)=maincpu.pb@(A2);maincpu.pb@(temp0+2)=maincpu.pb@((A2)+$1);maincpu.pb@(temp0+3)=maincpu.pb@((A2)+$2);maincpu.pb@(temp0+4)=maincpu.pb@((A2)+$3);maincpu.pb@(temp0+5)=maincpu.pb@((A2)+$4);maincpu.pd@(temp0+6)=((A4)&$FFFFFFFF);maincpu.pb@(temp0+$A)=$FF;maincpu.pd@(temp0+$B)=maincpu.pd@((A2)+$5);maincpu.pw@(temp0+$C)=maincpu.pw@(((A4)&$FFFFFF)+$20);maincpu.pw@(temp0+$E)=maincpu.pw@(((A4)&$FFFFFF)+$28);maincpu.pb@10CB40=((maincpu.pb@10CB40)+1);g")

			--[[
			判定データ調査用
			bp 0x012C42,1,{printf "0x012C42 %X %X A3=%X A4=%X A1=%X A2=%X 476=%X 47A=%X 576=%X 57A=%X",maincpu.pw@100460,maincpu.pw@10046E,A3,A4,A1,A2,maincpu.pd@100476,maincpu.pd@10047A,maincpu.pd@100576,maincpu.pd@10057A;g}
			bp 0x012C88,1,{printf "0x012C88 %X %X A3=%X A4=%X A1=%X A2=%X 476=%X 47A=%X 576=%X 57A=%X",maincpu.pw@100460,maincpu.pw@10046E,A3,A4,A1,A2,maincpu.pd@100476,maincpu.pd@10047A,maincpu.pd@100576,maincpu.pd@10057A;g}
			]]
			--判定追加2 攻撃判定
			global.bp(bps, fix_bp_addr(0x012C88),
				"(maincpu.pw@107C22>0)&&($100400<=((A3)&$FFFFFF))&&(((A3)&$FFFFFF)<=$100F00)",
				--"printf \"PC=%X A3=%X A1=%X D0=%X CT=%X\",PC,A3,A1,D0,($1DC000+((maincpu.pb@10CB40)*$10));"..
				"temp0=($1DC000+((maincpu.pb@10CB40)*$10));maincpu.pb@(temp0)=1;maincpu.pb@(temp0+1)=maincpu.pb@(A1);maincpu.pb@(temp0+2)=maincpu.pb@((A1)+$1);maincpu.pb@(temp0+3)=maincpu.pb@((A1)+$2);maincpu.pb@(temp0+4)=maincpu.pb@((A1)+$3);maincpu.pb@(temp0+5)=maincpu.pb@((A1)+$4);maincpu.pd@(temp0+6)=((A3)&$FFFFFFFF);maincpu.pb@(temp0+$A)=$01;maincpu.pd@(temp0+$B)=maincpu.pd@((A1)+$5);maincpu.pw@(temp0+$C)=maincpu.pw@(((A3)&$FFFFFF)+$20);maincpu.pw@(temp0+$E)=maincpu.pw@(((A3)&$FFFFFF)+$28);maincpu.pb@10CB40=((maincpu.pb@10CB40)+1);g")

			--判定追加3 1P押し合い判定
			global.bp(bps, fix_bp_addr(0x012D4C),
				"(maincpu.pw@107C22>0)&&($100400==((A4)&$FFFFFF))",
				--"printf \"PC=%X A4=%X A2=%X D0=%X CT=%X\",PC,A4,A2,D0,($1DC000+((maincpu.pb@10CB40)*$10));"..
				"temp0=($1DC000+((maincpu.pb@10CB40)*$10));maincpu.pb@(temp0)=1;maincpu.pb@(temp0+1)=maincpu.pb@(A2);maincpu.pb@(temp0+2)=maincpu.pb@((A2)+$1);maincpu.pb@(temp0+3)=maincpu.pb@((A2)+$2);maincpu.pb@(temp0+4)=maincpu.pb@((A2)+$3);maincpu.pb@(temp0+5)=maincpu.pb@((A2)+$4);maincpu.pd@(temp0+6)=((A4)&$FFFFFFFF);maincpu.pb@(temp0+$A)=$FF;maincpu.pw@(temp0+$C)=maincpu.pw@(((A4)&$FFFFFF)+$20);maincpu.pw@(temp0+$E)=maincpu.pw@(((A4)&$FFFFFF)+$28);maincpu.pb@10CB40=((maincpu.pb@10CB40)+1);g")

			--判定追加4 2P押し合い判定
			global.bp(bps, fix_bp_addr(0x012D92),
				"(maincpu.pw@107C22>0)&&($100500<=((A3)&$FFFFFF))",
				--"printf \"PC=%X A3=%X A1=%X D0=%X CT=%X\",PC,A3,A1,D0,($1DC000+((maincpu.pb@10CB40)*$10));"..
				"temp0=($1DC000+((maincpu.pb@10CB40)*$10));maincpu.pb@(temp0)=1;maincpu.pb@(temp0+1)=maincpu.pb@(A1);maincpu.pb@(temp0+2)=maincpu.pb@((A1)+$1);maincpu.pb@(temp0+3)=maincpu.pb@((A1)+$2);maincpu.pb@(temp0+4)=maincpu.pb@((A1)+$3);maincpu.pb@(temp0+5)=maincpu.pb@((A1)+$4);maincpu.pd@(temp0+6)=((A3)&$FFFFFFFF);maincpu.pb@(temp0+$A)=$FF;maincpu.pw@(temp0+$C)=maincpu.pw@(((A3)&$FFFFFF)+$20);maincpu.pw@(temp0+$E)=maincpu.pw@(((A3)&$FFFFFF)+$28);maincpu.pb@10CB40=((maincpu.pb@10CB40)+1);g")

			-- 地上通常投げ
			global.bp(bps, fix_bp_addr(0x05D782),
				"(maincpu.pw@107C22>0)&&((((D7)&$FFFF)!=0x65))&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CD90+((((A4)&$FFFFFF)-$100400)/$8);maincpu.pb@(temp1)=$1;maincpu.pd@(temp1+$1)=((A4)&$FFFFFF);maincpu.pd@(temp1+$5)=maincpu.pd@(((A4)&$FFFFFF)+$96);maincpu.pw@(temp1+$A)=maincpu.pw@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$10);maincpu.pw@(temp1+$C)=maincpu.pw@(((A4)&$FFFFFF)+$10);maincpu.pb@(temp1+$10)=maincpu.pb@(((A4)&$FFFFFF)+$96+$58);maincpu.pb@(temp1+$11)=maincpu.pb@(((A4)&$FFFFFF)+$58);maincpu.pb@(temp1+$12)=maincpu.pb@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$58);maincpu.pb@(temp1+$13)=maincpu.pb@(maincpu.pd@((PC)+$2));maincpu.pb@(temp1+$14)=maincpu.pb@((maincpu.pd@((PC)+$02))+((maincpu.pw@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$10))<<3)+$3);maincpu.pb@(temp1+$15)=maincpu.pb@((maincpu.pd@((PC)+$02))+((maincpu.pw@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$10))<<3)+$4);maincpu.pb@(temp1+$16)=maincpu.pb@((maincpu.pd@((PC)+$2))+((maincpu.pw@(((A4)&$FFFFFF)+$10))<<3)+$3);maincpu.pb@(temp1+$17)=maincpu.pb@((PC)+$D2+(maincpu.pw@((A4)&$FFFFFF)+$10)*4+((((D7)&$FFFF)-$60)&$7));maincpu.pw@(temp1+$18)=maincpu.pw@(($FFFFFF&(A4))+$20);maincpu.pw@(temp1+$1A)=maincpu.pw@(($FFFFFF&(A4))+$28);g")

			-- 空中投げ
			global.bp(bps, fix_bp_addr(0x060428),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CD00+((((A4)&$FFFFFF)-$100400)/$8);maincpu.pb@(temp1)=$1;maincpu.pw@(temp1+$1)=maincpu.pw@(A0);maincpu.pw@(temp1+$3)=maincpu.pw@((A0)+$2);maincpu.pd@(temp1+$5)=$FFFFFF&(A4);maincpu.pd@(temp1+$9)=maincpu.pd@(($FFFFFF&(A4))+$96);maincpu.pw@(temp1+$D)=maincpu.pw@(maincpu.pd@(($FFFFFF&(A4))+$96)+$10);maincpu.pd@(temp1+$11)=maincpu.rb@(($FFFFFF&(A4))+$58);maincpu.pw@(temp1+$13)=maincpu.pw@(($FFFFFF&(A4))+$20);maincpu.pw@(temp1+$15)=maincpu.pw@(($FFFFFF&(A4))+$28);g")

			-- 必殺投げ
			global.bp(bps, fix_bp_addr(0x039F2A),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CD40+((((A4)&$FFFFFF)-$100400)/$8);maincpu.pb@(temp1)=$1;maincpu.pw@(temp1+$1)=maincpu.pw@(A0);maincpu.pw@(temp1+$3)=maincpu.pw@((A0)+$2);maincpu.pd@(temp1+$5)=$FFFFFF&(A4);maincpu.pd@(temp1+$9)=maincpu.pd@(($FFFFFF&(A4))+$96);maincpu.pw@(temp1+$D)=maincpu.pw@(maincpu.pd@(($FFFFFF&(A4))+$96)+$10);maincpu.pd@(temp1+$11)=maincpu.rb@(($FFFFFF&(A4))+$58);maincpu.pw@(temp1+$12)=maincpu.pw@(A0+$4);maincpu.pw@(temp1+$15)=maincpu.pw@(($FFFFFF&(A4))+$20);maincpu.pw@(temp1+$17)=maincpu.pw@(($FFFFFF&(A4))+$28);g")
			-- プレイヤー選択時のカーソル操作表示用データのオフセット
			-- PC=11EE2のときのA4レジスタのアドレスがプレイヤー選択のアイコンの参照場所
			-- データの領域を未使用の別メモリ領域に退避して1P操作で2Pカーソル移動ができるようにする
			-- maincpu.pw@((A4)+$60)=$00F8を付けたすとカーソルをCPUにできる
			global.bp(bps, 0x11EE2,
				"(maincpu.pw@((A4)+2)==2D98||maincpu.pw@((A4)+2)==33B8)&&maincpu.pw@100701==10B&&maincpu.pb@10FDAF==2&&maincpu.pw@10FDB6!=0&&maincpu.pb@100026==2",
				"maincpu.pb@10CDD0=($FF&((maincpu.pb@10CDD0)+1));maincpu.pd@10CDD1=((A4)+$13);g")
			global.bp(bps, 0x11EE2,
				"(maincpu.pw@((A4)+2)==2D98||maincpu.pw@((A4)+2)==33B8)&&maincpu.pw@100701==10B&&maincpu.pb@10FDAF==2&&maincpu.pw@10FDB6!=0&&maincpu.pb@100026==1",
				"maincpu.pb@10CDD0=($FF&((maincpu.pb@10CDD0)+1));maincpu.pd@10CDD5=((A4)+$13);g")

			-- プレイヤー選択時に1Pか2Pの選択ボタン押したときに対戦モードに移行する
			-- PC=  C5D0 読取反映先=?? スタートボタンの読取してるけど関係なし
			-- PC= 12376 読取反映先=D0 スタートボタンの読取してるけど関係なし
			-- PC=C096A8 読取反映先=D1 スタートボタンの読取してるけど関係なし
			-- PC=C1B954 読取反映先=D2 スタートボタンの読取してるとこ
			global.bp(bps, 0xC1B95A,
				"(maincpu.pb@100024==1&&maincpu.pw@100701==10B&&maincpu.pb@10FDAF==2&&maincpu.pw@10FDB6!=0)&&((((maincpu.pb@300000)&$10)==0)||(((maincpu.pb@300000)&$80)==0))",
				"D2=($FF^$04);g")
			global.bp(bps, 0xC1B95A,
				"(maincpu.pb@100024==2&&maincpu.pw@100701==10B&&maincpu.pb@10FDAF==2&&maincpu.pw@10FDB6!=0)&&((((maincpu.pb@340000)&$10)==0)||(((maincpu.pb@340000)&$80)==0))",
				"D2=($FF^$01);g")

			-- 影表示
			--{base = 0x017300, ["rbff2k"] = 0x28, ["rbff2h"] = 0x0, no_background = true,
			--			func = function() memory.pgm:write_u8(gr("a4") + 0x82, 0) end},
			--solid shadows 01
			--no    shadows FF
			global.bp(bps, 0x017300, "maincpu.pw@107C22>0&&maincpu.pb@10DDF0==FF", "maincpu.pb@((A4)+$82)=$FF;g")

			-- 潜在ぜったい投げるマン
			--table.insert(bps, cpu.debug:global.bp(fix_bp_addr(0x039F8C), "1",
			--	"maincpu.pb@((A3)+$90)=$19;g"))
			-- 投げ可能判定用フレーム
			global.bp(bps, fix_bp_addr(0x039F90), "maincpu.pw@107C22>0",
				"temp1=$10DDE2+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=D7;g")
			-- 投げ確定時の判定用フレーム
			global.bp(bps, fix_bp_addr(0x039F96), "maincpu.pw@107C22>0",
				"temp1=$10DDE4+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=maincpu.pb@((A3)+$90);g")

			-- 判定の接触判定が無視される
			-- bp 13118,1,{PC=1311C;g}

			-- 攻撃のヒットをむりやりガードに変更する
			-- $10DE5E $10DE5Fにフラグたっているかをチェックする
			global.bp(bps, fix_bp_addr(0x0580D4),
				"maincpu.pw@107C22>0&&((maincpu.pb@10DDF1>0&&(A4)==100500&&maincpu.pb@10DE5F==1&&(maincpu.pb@10058E==0||maincpu.pb@10058E==2))||(maincpu.pb@10DDF1>0&&(A4)==100400&&maincpu.pb@10DE5E==1&&(maincpu.pb@10048E==0||maincpu.pb@10048E==2)))",
				"PC=" .. string.format("%x", fix_bp_addr(0x0580EA)) .. ";g")
			--[[
			global.bp(bps, fix_bp_addr(0x012FD0),
				"maincpu.pw@107C22>0&&((maincpu.pb@10DDF1>0&&(A4)==100500)||(maincpu.pb@10DDF1>0&&(A4)==100400))",
				"temp1=$10DDF1+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=0;PC=" .. string.format("%x", fix_bp_addr(0x012FDA)) .. ";g")
			]]

			-- N段目で強制空ぶりさせるフック
			global.bp(bps, fix_bp_addr(0x0130F8),
				"maincpu.pw@107C22>0&&((D7)<$FFFF)&&((maincpu.pb@10DDF1!=$FF&&(A4)==100500&&maincpu.pb@10DDF1<=maincpu.pb@10B4E0)||(maincpu.pb@10DDF2!=$FF&&(A4)==100400&&maincpu.pb@10DDF2<=maincpu.pb@10B4E1))",
				"maincpu.pb@(temp1)=0;PC=" .. string.format("%x", fix_bp_addr(0x012FDA)) .. ";g")
			--[[ 空振りフック時の状態確認用
			global.bp(bps, fix_bp_addr(0x0130F8),
				"maincpu.pw@107C22>0&&((D7)<$FFFF)&&((A4)==100500||(A4)==100400)",
				"printf \"A4=%X 1=%X 2=%X E0=%X E1=%X\",(A4),maincpu.pb@10DDF1,maincpu.pb@10DDF2,maincpu.pb@10B4E0,maincpu.pb@10B4E1;g")
			]]

			-- ヒット後ではなく技の出だしから嘘判定であることの判定用フック
			global.bp(bps, fix_bp_addr(0x011DFE),
				"maincpu.pw@107C22>0",
				"temp1=$10DDF3+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=(D5);g")


			--[[ 家庭用 補正前のダメージ出力
			bp 05B1B2,1,{printf "%d",maincpu.pb@(A4+$8f);g}
			bp 05B1D0,1,{printf "%d",maincpu.pb@(A4+$8f);g}
			bp 05B13A,1,{printf "%d",maincpu.pb@(A4+$8f);g}
			bp 05B15A,1,{printf "%d",maincpu.pb@(A4+$8f);g}

			05B11A MVS
			05B13A MVS
			]]
			-- 補正前ダメージ取得用フック
			global.bp(bps, fix_bp_addr(0x05B11A),
				"maincpu.pw@107C22>0",
				"temp1=$10DDFB+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=maincpu.pb@((A4)+$8F);g")
			global.bp(bps, fix_bp_addr(0x05B13A),
				"maincpu.pw@107C22>0",
				"temp1=$10DDFB+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=maincpu.pb@((A4)+$8F);g")

			-- 気絶値と気絶値タイマー取得用フック
			global.bp(bps, fix_bp_addr(0x05C1E0),
				"maincpu.pw@107C22>0",
				"temp1=$10DDFD+((((A4)&$FFFFFF)-$100400)/$80);maincpu.pb@(temp1)=(D0);maincpu.pb@(temp1+$1)=(D1);g")

			--ダメージ補正 7/8
			global.bp(bps, fix_bp_addr(0x5B1E0),
				"maincpu.pw@107C22>0",
				"temp1=$10DE50+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=maincpu.pb@(temp1)+1;g")
			--ダメージ補正 6/8
			global.bp(bps, fix_bp_addr(0x5B1F6),
				"maincpu.pw@107C22>0",
				"temp1=$10DE52+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=maincpu.pb@(temp1)+1;g")
			--ダメージ補正 5/8
			global.bp(bps, fix_bp_addr(0x5B20C),
				"maincpu.pw@107C22>0",
				"temp1=$10DE54+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=maincpu.pb@(temp1)+1;g")
			--ダメージ補正 4/8
			global.bp(bps, fix_bp_addr(0x5B224),
				"maincpu.pw@107C22>0",
				"temp1=$10DE56+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=maincpu.pb@(temp1)+1;g")

			-- POWゲージ増加量取得用フック 通常技
			-- 中間のチェックをスキップして算出処理へ飛ぶ
			global.bp(bps, fix_bp_addr(0x03BEDA),
				"maincpu.pw@107C22>0",
				string.format("PC=%x;g", fix_bp_addr(0x03BEEC)))
			-- 中間チェックに抵触するパターンは値採取後にRTSへ移動する
			global.bp(bps, fix_bp_addr(0x05B3AC),
				"maincpu.pw@107C22>0&&(maincpu.pb@((A3)+$BF)!=$0||maincpu.pb@((A3)+$BC)==$3C)",
				"temp1=$10DE58+((((A3)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=(maincpu.pb@(temp1)+(D0));" .. string.format("PC=%x", fix_bp_addr(0x05B34E)) .. ";g")
			-- 中間チェックに抵触しないパターン
			global.bp(bps, fix_bp_addr(0x05B3AC),
				"maincpu.pw@107C22>0&&maincpu.pb@((A3)+$BF)==$0&&maincpu.pb@((A3)+$BC)!=$3C",
				"temp1=$10DE58+((((A3)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=(maincpu.pb@(temp1)+(D0));g")

			-- POWゲージ増加量取得用フック 必殺技
			-- 中間のチェックをスキップして算出処理へ飛ぶ
			global.bp(bps, fix_bp_addr(0x05B34C),
				"maincpu.pw@107C22>0",
				string.format("PC=%x;g", fix_bp_addr(0x05B35E)))
			-- 中間チェックに抵触するパターンは値採取後にRTSへ移動する
			global.bp(bps, fix_bp_addr(0x03C144),
				"maincpu.pw@107C22>0&&maincpu.pb@((A4)+$BF)!=$0",
				"temp1=$10DE5A+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=(maincpu.pb@(temp1)+(D0));" .. string.format("PC=%x", fix_bp_addr(0x03C13A)) .. ";g")
			-- 中間チェックに抵触しないパターン
			global.bp(bps, fix_bp_addr(0x03C144),
				"maincpu.pw@107C22>0&&maincpu.pb@((A4)+$BF)==$0",
				"temp1=$10DE5A+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=(maincpu.pb@(temp1)+(D0));g")

			-- POWゲージ増加量取得用フック 倍返しとか
			-- 中間のチェック以前に値がD0に入っているのでそれを採取する
			global.bp(bps, fix_bp_addr(0x03BF04),
				"maincpu.pw@107C22>0",
				"temp1=$10DE5A+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=(maincpu.pb@(temp1)+(D0));g")

			--[[ ドリル簡易入力
			デバッグDIP4-4参照箇所の以下まとめて。
			bp 042BF8,1,{PC=042BFA;g}
			bp 042C1A,1,{PC=042C1C;g}
			bp 04343A,1,{PC=04343C;g}
			bp 0434AA,1,{PC=434b6;g}
			]]

			-- 空振りCAできる
			-- bp 02FA5E,1,{PC=02FA6A;g}
			-- ↓のテーブルを全部00にするのでも可
			-- 02FA72: 0000 0000
			-- 02FA76: 0000 0000
			-- 02FA7A: FFFF FFFF
			-- 02FA7E: 00FF FF00
			-- 02FA82: FFFF

			-- bp 3B5CE,1,{maincpu.pb@1007B5=0;g} -- 2P 飛び道具の強さ0に

			-- bp 39db0,1,{PC=39db4;g} -- 必殺投げの高度チェックを無視

			--[[ ライン移動攻撃の移動量のしきい値 調査用
			table.insert(bps, cpu.debug:bpset(0x029768,
				"1",
				"printf \"CH=%D D0=%X D1=%X PREF_ADDR=%X\",maincpu.pw@((A4)+10), D0,D1,PREF_ADDR;g"))
			]]

			--[[ 投げ無敵調査用
			for _, addr in ipairs({
				0x00039DAE, -- 投げチェック処理
				0x00039D52, -- 爆弾パチキ ドリル M.カウンター投げ M.タイフーン 真心牙 S.TOL 鬼門陣
				0x0003A0D4, -- 真空投げ
				0x0003A0E6, -- 羅生門
				0x0003A266, -- ブレイクスパイラル
				0x0003A426, -- リフトアップブロー
				0x0003A438, -- デンジャラススルー
				0x0003A44A, -- ギガティックサイクロン
				0x00039F36, -- 投げ成立
				0x00039DFA, -- 無敵Fチェック
			}) do
				global.bp(bps, addr, "1", "printf \"A4=%X CH=%D PC=%X PREF_ADDR=%X A0=%X D7=%X\",(A4),maincpu.pw@((A4)+10),PC,PREF_ADDR,(A0),(D7);g"))
			end
			]]

			-- bp 058946,1,{PC=5895A;g} -- BS出ない
			-- bp 039782,1,{PC=039788;g} -- BS表示でない
		end
	end

	local set_bps_rg = function(reset)
		if global.bps_rg then
			global.set_bps(reset, global.bps_rg)
		else
			global.bps_rg = global.new_hook_holder()
			local bps_rg = global.bps_rg.bps

			local cond1, cond2
			if emu.romname() ~= "rbff2" then
				-- この処理をそのまま有効にすると通常時でも食らい判定が見えるようになるが、MVS版ビリーの本来は攻撃判定無しの垂直ジャンプ攻撃がヒットしてしまう
				-- ビリーの判定が出ない(maincpu.pb@((A0)+$B6)==0)な垂直小ジャンプAと垂直小ジャンプBと斜め小ジャンプBときはこのワークアラウンドが動作しないようにする
				cond1 = table.concat({
					"(maincpu.pw@107C22>0)",
					"(maincpu.pb@((A0)+$B6)==0)",
					"(maincpu.pw@((A0)+$60)!=$50)",
					"(maincpu.pw@((A0)+$60)!=$51)",
					"(maincpu.pw@((A0)+$60)!=$54)",
				}, "&&")
			else
				cond1 = "(maincpu.pw@107C22>0)"
			end
			cond2 = cond1 .. "&&(maincpu.pb@((A3)+$B6)==0)"
			-- 投げの時だけやられ判定表示（ジョー用）
			local cond3 = "(maincpu.pw@107C22>0)&&((maincpu.pb@($AA+(A3))|D0)!=0)"
			global.bp(bps_rg, fix_bp_addr(0x5C2E2), cond3, "PC=((PC)+$C);g")
			-- 投げのときだけやられ判定表示（主にボブ用）
			local cond4 = "(maincpu.pw@107C22>0)&&(maincpu.pb@($7A+(A3))==0)"
			global.bp(bps_rg, 0x12BB0, cond4, "PC=((PC)+$E);g")

			--check vuln at all times *** setregister for m68000.pc is broken *** --bp 05C2E8, 1, {PC=((PC)+$6);g}
			global.bp(bps_rg, fix_bp_addr(0x5C2E8), cond2, "PC=((PC)+$6);g")
			--この条件で動作させると攻撃判定がでてしまってヒットしてしまうのでダメ
			--[[
			local cond2 = "(maincpu.pw@107C22>0)&&(maincpu.pb@((A0)+$B6)==0)&&((maincpu.pw@((A0)+$60)==$50)||(maincpu.pw@((A0)+$60)==$51)||(maincpu.pw@((A0)+$60)==$54))"
			global.bp(bps_rg, fix_bp_addr(0x5C2E8), cond2, "maincpu.pb@((A3)+$B6)=1;g")
			]]
			--check vuln at all times *** hackish workaround *** --bp 05C2E8, 1, {A3=((A3)-$B5);g}
			global.bp(bps_rg, fix_bp_addr(0x5C2E8), cond1, "A3=((A3)-$B5);g")
			--*** fix for hackish workaround *** --bp 05C2EE, 1, {A3=((A3)+$B5);g}
			global.bp(bps_rg, fix_bp_addr(0x5C2EE), cond1, "A3=((A3)+$B5);g")
			-- 無理やり条件スキップしたので当たり処理に入らないようにする
			global.bp(bps_rg, fix_bp_addr(0x5C2F6), "(maincpu.pb@((A3)+$B6)==0)||((maincpu.pb@($AA+(A3))|D0)!=0)", "PC=((PC)+$8);g")
		end
	end

	local hook_reset = nil
	local set_hook = function(reset)
		if reset == true then
			if hook_reset == true then
				return
			end
		else
			if hook_reset == false then
				return
			end
		end
		hook_reset = reset == true
		set_wps(hook_reset)
		set_bps(hook_reset)
		set_bps_rg(hook_reset)
	end

	-- 誤動作防止のためフックで使用する領域を初期化する
	local cls_hook = function()
		-- 各種当たり判定のフック
		-- 0x10CB40 当たり判定の発生個数
		-- 0x1DC000 から 0x10 間隔で当たり判定をbpsetのフックで記録する
		for addr = 0x1DC000, 0x1DC000 + pgm:read_u8(0x10CB40) * 0x11 do
			pgm:write_u8(addr, 0xFF)
		end
		pgm:write_u8(0x10CB40, 0x00)

		for i, p in ipairs(players) do
			pgm:write_u8(p.addr.state2, 0x00) -- ステータス更新フック
			pgm:write_u16(p.addr.act2, 0x00) -- 技ID更新フック

			pgm:write_u8(p.addr.vulnerable1, 0xFF) -- 食らい判定のフック
			pgm:write_u8(p.addr.vulnerable21, 0xFF) -- 食らい判定のフック
			pgm:write_u8(p.addr.vulnerable22, 0xFF) -- 食らい判定のフック

			pgm:write_u8(p.n_throw.addr.on, 0xFF) -- 投げのフック
			pgm:write_u8(p.air_throw.addr.on, 0xFF) -- 空中投げのフック
			pgm:write_u8(p.sp_throw.addr.on, 0xFF) -- 必殺投げのフック
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
	local research_cmd = function()
		local make_cmd    = function(joykp, ...)
			local joy = new_next_joy()
			if ... then
				for _, k in ipairs({ ... }) do
					joy[joykp[k]] = true
				end
			end
			return joy
		end
		local _1          = function(joykp) return make_cmd(joykp, "lt", "dn") end
		local _1a         = function(joykp) return make_cmd(joykp, "lt", "dn", "a") end
		local _1b         = function(joykp) return make_cmd(joykp, "lt", "dn", "b") end
		local _1ab        = function(joykp) return make_cmd(joykp, "lt", "dn", "a", "b") end
		local _1c         = function(joykp) return make_cmd(joykp, "lt", "dn", "c") end
		local _1ac        = function(joykp) return make_cmd(joykp, "lt", "dn", "a", "c") end
		local _1bc        = function(joykp) return make_cmd(joykp, "lt", "dn", "b", "c") end
		local _1abc       = function(joykp) return make_cmd(joykp, "lt", "dn", "a", "b", "c") end
		local _1d         = function(joykp) return make_cmd(joykp, "lt", "dn", "d") end
		local _1ad        = function(joykp) return make_cmd(joykp, "lt", "dn", "a", "d") end
		local _1bd        = function(joykp) return make_cmd(joykp, "lt", "dn", "b", "d") end
		local _1abd       = function(joykp) return make_cmd(joykp, "lt", "dn", "a", "b", "d") end
		local _1cd        = function(joykp) return make_cmd(joykp, "lt", "dn", "c", "d") end
		local _1acd       = function(joykp) return make_cmd(joykp, "lt", "dn", "a", "c", "d") end
		local _1bcd       = function(joykp) return make_cmd(joykp, "lt", "dn", "b", "c", "d") end
		local _1abcd      = function(joykp) return make_cmd(joykp, "lt", "dn", "a", "b", "c", "d") end
		local _2          = function(joykp) return make_cmd(joykp, "dn") end
		local _2a         = function(joykp) return make_cmd(joykp, "dn", "a") end
		local _2b         = function(joykp) return make_cmd(joykp, "dn", "b") end
		local _2ab        = function(joykp) return make_cmd(joykp, "dn", "a", "b") end
		local _2c         = function(joykp) return make_cmd(joykp, "dn", "c") end
		local _2ac        = function(joykp) return make_cmd(joykp, "dn", "a", "c") end
		local _2bc        = function(joykp) return make_cmd(joykp, "dn", "b", "c") end
		local _2abc       = function(joykp) return make_cmd(joykp, "dn", "a", "b", "c") end
		local _2d         = function(joykp) return make_cmd(joykp, "dn", "d") end
		local _2ad        = function(joykp) return make_cmd(joykp, "dn", "a", "d") end
		local _2bd        = function(joykp) return make_cmd(joykp, "dn", "b", "d") end
		local _2abd       = function(joykp) return make_cmd(joykp, "dn", "a", "b", "d") end
		local _2cd        = function(joykp) return make_cmd(joykp, "dn", "c", "d") end
		local _2acd       = function(joykp) return make_cmd(joykp, "dn", "a", "c", "d") end
		local _2bcd       = function(joykp) return make_cmd(joykp, "dn", "b", "c", "d") end
		local _2abcd      = function(joykp) return make_cmd(joykp, "dn", "a", "b", "c", "d") end
		local _3          = function(joykp) return make_cmd(joykp, "rt", "dn") end
		local _3a         = function(joykp) return make_cmd(joykp, "rt", "dn", "a") end
		local _3b         = function(joykp) return make_cmd(joykp, "rt", "dn", "b") end
		local _3ab        = function(joykp) return make_cmd(joykp, "rt", "dn", "a", "b") end
		local _3c         = function(joykp) return make_cmd(joykp, "rt", "dn", "c") end
		local _3ac        = function(joykp) return make_cmd(joykp, "rt", "dn", "a", "c") end
		local _3bc        = function(joykp) return make_cmd(joykp, "rt", "dn", "b", "c") end
		local _3abc       = function(joykp) return make_cmd(joykp, "rt", "dn", "a", "b", "c") end
		local _3d         = function(joykp) return make_cmd(joykp, "rt", "dn", "d") end
		local _3ad        = function(joykp) return make_cmd(joykp, "rt", "dn", "a", "d") end
		local _3bd        = function(joykp) return make_cmd(joykp, "rt", "dn", "b", "d") end
		local _3abd       = function(joykp) return make_cmd(joykp, "rt", "dn", "a", "b", "d") end
		local _3cd        = function(joykp) return make_cmd(joykp, "rt", "dn", "c", "d") end
		local _3acd       = function(joykp) return make_cmd(joykp, "rt", "dn", "a", "c", "d") end
		local _3bcd       = function(joykp) return make_cmd(joykp, "rt", "dn", "b", "c", "d") end
		local _3abcd      = function(joykp) return make_cmd(joykp, "rt", "dn", "a", "b", "c", "d") end
		local _4          = function(joykp) return make_cmd(joykp, "lt") end
		local _4a         = function(joykp) return make_cmd(joykp, "lt", "a") end
		local _4b         = function(joykp) return make_cmd(joykp, "lt", "b") end
		local _4ab        = function(joykp) return make_cmd(joykp, "lt", "a", "b") end
		local _4c         = function(joykp) return make_cmd(joykp, "lt", "c") end
		local _4ac        = function(joykp) return make_cmd(joykp, "lt", "a", "c") end
		local _4bc        = function(joykp) return make_cmd(joykp, "lt", "b", "c") end
		local _4abc       = function(joykp) return make_cmd(joykp, "lt", "a", "b", "c") end
		local _4d         = function(joykp) return make_cmd(joykp, "lt", "d") end
		local _4ad        = function(joykp) return make_cmd(joykp, "lt", "a", "d") end
		local _4bd        = function(joykp) return make_cmd(joykp, "lt", "b", "d") end
		local _4abd       = function(joykp) return make_cmd(joykp, "lt", "a", "b", "d") end
		local _4cd        = function(joykp) return make_cmd(joykp, "lt", "c", "d") end
		local _4acd       = function(joykp) return make_cmd(joykp, "lt", "a", "c", "d") end
		local _4bcd       = function(joykp) return make_cmd(joykp, "lt", "b", "c", "d") end
		local _4abcd      = function(joykp) return make_cmd(joykp, "lt", "a", "b", "c", "d") end
		local _5          = function(joykp) return make_cmd(joykp) end
		local _5a         = function(joykp) return make_cmd(joykp, "a") end
		local _5b         = function(joykp) return make_cmd(joykp, "b") end
		local _5ab        = function(joykp) return make_cmd(joykp, "a", "b") end
		local _5c         = function(joykp) return make_cmd(joykp, "c") end
		local _5ac        = function(joykp) return make_cmd(joykp, "a", "c") end
		local _5bc        = function(joykp) return make_cmd(joykp, "b", "c") end
		local _5abc       = function(joykp) return make_cmd(joykp, "a", "b", "c") end
		local _5d         = function(joykp) return make_cmd(joykp, "d") end
		local _5ad        = function(joykp) return make_cmd(joykp, "a", "d") end
		local _5bd        = function(joykp) return make_cmd(joykp, "b", "d") end
		local _5abd       = function(joykp) return make_cmd(joykp, "a", "b", "d") end
		local _5cd        = function(joykp) return make_cmd(joykp, "c", "d") end
		local _5acd       = function(joykp) return make_cmd(joykp, "a", "c", "d") end
		local _5bcd       = function(joykp) return make_cmd(joykp, "b", "c", "d") end
		local _5abcd      = function(joykp) return make_cmd(joykp, "a", "b", "c", "d") end
		local _a          = _5a
		local _b          = _5b
		local _ab         = _5ab
		local _c          = _5c
		local _ac         = _5ac
		local _bc         = _5bc
		local _abc        = _5abc
		local _d          = _5d
		local _ad         = _5ad
		local _bd         = _5bd
		local _abd        = _5abd
		local _cd         = _5cd
		local _acd        = _5acd
		local _bcd        = _5bcd
		local _abcd       = _5abcd
		local _6          = function(joykp) return make_cmd(joykp, "rt") end
		local _6a         = function(joykp) return make_cmd(joykp, "rt", "a") end
		local _6b         = function(joykp) return make_cmd(joykp, "rt", "b") end
		local _6ab        = function(joykp) return make_cmd(joykp, "rt", "a", "b") end
		local _6c         = function(joykp) return make_cmd(joykp, "rt", "c") end
		local _6ac        = function(joykp) return make_cmd(joykp, "rt", "a", "c") end
		local _6bc        = function(joykp) return make_cmd(joykp, "rt", "b", "c") end
		local _6abc       = function(joykp) return make_cmd(joykp, "rt", "a", "b", "c") end
		local _6d         = function(joykp) return make_cmd(joykp, "rt", "d") end
		local _6ad        = function(joykp) return make_cmd(joykp, "rt", "a", "d") end
		local _6bd        = function(joykp) return make_cmd(joykp, "rt", "b", "d") end
		local _6abd       = function(joykp) return make_cmd(joykp, "rt", "a", "b", "d") end
		local _6cd        = function(joykp) return make_cmd(joykp, "rt", "c", "d") end
		local _6acd       = function(joykp) return make_cmd(joykp, "rt", "a", "c", "d") end
		local _6bcd       = function(joykp) return make_cmd(joykp, "rt", "b", "c", "d") end
		local _6abcd      = function(joykp) return make_cmd(joykp, "rt", "a", "b", "c", "d") end
		local _7          = function(joykp) return make_cmd(joykp, "lt", "up") end
		local _7a         = function(joykp) return make_cmd(joykp, "lt", "up", "a") end
		local _7b         = function(joykp) return make_cmd(joykp, "lt", "up", "b") end
		local _7ab        = function(joykp) return make_cmd(joykp, "lt", "up", "a", "b") end
		local _7c         = function(joykp) return make_cmd(joykp, "lt", "up", "c") end
		local _7ac        = function(joykp) return make_cmd(joykp, "lt", "up", "a", "c") end
		local _7bc        = function(joykp) return make_cmd(joykp, "lt", "up", "b", "c") end
		local _7abc       = function(joykp) return make_cmd(joykp, "lt", "up", "a", "b", "c") end
		local _7d         = function(joykp) return make_cmd(joykp, "lt", "up", "d") end
		local _7ad        = function(joykp) return make_cmd(joykp, "lt", "up", "a", "d") end
		local _7bd        = function(joykp) return make_cmd(joykp, "lt", "up", "b", "d") end
		local _7abd       = function(joykp) return make_cmd(joykp, "lt", "up", "a", "b", "d") end
		local _7cd        = function(joykp) return make_cmd(joykp, "lt", "up", "c", "d") end
		local _7acd       = function(joykp) return make_cmd(joykp, "lt", "up", "a", "c", "d") end
		local _7bcd       = function(joykp) return make_cmd(joykp, "lt", "up", "b", "c", "d") end
		local _7abcd      = function(joykp) return make_cmd(joykp, "lt", "up", "a", "b", "c", "d") end
		local _8          = function(joykp) return make_cmd(joykp, "up") end
		local _8a         = function(joykp) return make_cmd(joykp, "up", "a") end
		local _8b         = function(joykp) return make_cmd(joykp, "up", "b") end
		local _8ab        = function(joykp) return make_cmd(joykp, "up", "a", "b") end
		local _8c         = function(joykp) return make_cmd(joykp, "up", "c") end
		local _8ac        = function(joykp) return make_cmd(joykp, "up", "a", "c") end
		local _8bc        = function(joykp) return make_cmd(joykp, "up", "b", "c") end
		local _8abc       = function(joykp) return make_cmd(joykp, "up", "a", "b", "c") end
		local _8d         = function(joykp) return make_cmd(joykp, "up", "d") end
		local _8ad        = function(joykp) return make_cmd(joykp, "up", "a", "d") end
		local _8bd        = function(joykp) return make_cmd(joykp, "up", "b", "d") end
		local _8abd       = function(joykp) return make_cmd(joykp, "up", "a", "b", "d") end
		local _8cd        = function(joykp) return make_cmd(joykp, "up", "c", "d") end
		local _8acd       = function(joykp) return make_cmd(joykp, "up", "a", "c", "d") end
		local _8bcd       = function(joykp) return make_cmd(joykp, "up", "b", "c", "d") end
		local _8abcd      = function(joykp) return make_cmd(joykp, "up", "a", "b", "c", "d") end
		local _9          = function(joykp) return make_cmd(joykp, "rt", "up") end
		local _9a         = function(joykp) return make_cmd(joykp, "rt", "up", "a") end
		local _9b         = function(joykp) return make_cmd(joykp, "rt", "up", "b") end
		local _9ab        = function(joykp) return make_cmd(joykp, "rt", "up", "a", "b") end
		local _9c         = function(joykp) return make_cmd(joykp, "rt", "up", "c") end
		local _9ac        = function(joykp) return make_cmd(joykp, "rt", "up", "a", "c") end
		local _9bc        = function(joykp) return make_cmd(joykp, "rt", "up", "b", "c") end
		local _9abc       = function(joykp) return make_cmd(joykp, "rt", "up", "a", "b", "c") end
		local _9d         = function(joykp) return make_cmd(joykp, "rt", "up", "d") end
		local _9ad        = function(joykp) return make_cmd(joykp, "rt", "up", "a", "d") end
		local _9bd        = function(joykp) return make_cmd(joykp, "rt", "up", "b", "d") end
		local _9abd       = function(joykp) return make_cmd(joykp, "rt", "up", "a", "b", "d") end
		local _9cd        = function(joykp) return make_cmd(joykp, "rt", "up", "c", "d") end
		local _9acd       = function(joykp) return make_cmd(joykp, "rt", "up", "a", "c", "d") end
		local _9bcd       = function(joykp) return make_cmd(joykp, "rt", "up", "b", "c", "d") end
		local _9abcd      = function(joykp) return make_cmd(joykp, "rt", "up", "a", "b", "c", "d") end
		local extract_cmd = function(joyk, cmd_ary)
			if not cmd_ary then
				return {}
			end
			local ret, prev = {}, _5(joyk)
			for _, cmd in ipairs(cmd_ary) do
				local typename = type(cmd)
				if typename == "number" and cmd > 1 then -- 繰り返し回数1は前のコマンドが含まれるので2以上からカウント
					for i = 2, cmd do
						table.insert(ret, prev)
					end
				elseif typename == "function" then
					prev = cmd(joyk)
					table.insert(ret, prev)
				end
			end
			return ret
		end
		local merge_cmd   = function(cmd_ary1, cmd_ary2)
			local keys1, keys2 = extract_cmd(joyk.p1, cmd_ary1), extract_cmd(joyk.p2, cmd_ary2)
			local ret, max = {}, math.max(#keys1, #keys2)
			for i = 1, max do
				local joy = new_next_joy()
				for _, key in ipairs({ keys1[i] or {}, keys2[i] or {} }) do
					for k, v in pairs(key) do
						if v then
							joy[k] = v
						end
					end
				end
				table.insert(ret, joy)
			end
			return ret
		end
		local rec1        = {}
		local rec2        = {}
		local rec3        = {}
		local rec4        = {}
		local rec5        = {}
		local rec6        = {}
		local rec7        = {}
		local rec8        = {}
		--[[
		rec1 = merge_cmd( -- ボブ対クラウザー100% ラグがでると落ちる
			{
				_4, 4, _5, 4, _4, 6, _7, 17, _5, 8, _5a, 7, _5c, 12, _4, 30, _5c, 3, _5, 5, _5c, 5, _5, 47, _5a, 5, _5b, 5, _5, 25, _1c, 5, _5, 20, _2bc, 4, _5, 2, _2, 5, _3, 5, _6, 5, _5b, 5, _4, 2,
				_5, 64, _2, 5, _3, 5, _6, 5, _5b, 5,
				_5, 64, _2, 5, _3, 5, _6, 6, _5b, 5, _4, 2,
				_5, 64, _2, 5, _3, 5, _6, 5, _5b, 5,
				_5, 64, _2, 5, _3, 5, _6, 5, _5b, 5,
				_5, 53, _4, 16, _5, 2, _6, 5, _3, 5, _2, 5, _1, 5, _5c, 5, _5, 180, _8c, 2, _5, 1,
			},
			{ _5, }
		)
		]]
		--[[
		rec1 = merge_cmd( -- 対ビリー 自動ガード+リバサ立A向けの炎の種馬相打ちコンボ
			{ _4, 11, _2a, 7, _2, 1, _3, 2, _6, 7, _6a, 2, _5, 38, _1a, 15, _5, 7, _6ac, 3, _5, 13, _1a, 6, _5, 16, _5c, 7, _5, 12, _5c, 5, _5, 12, _4, 3, _2, 3, _1c, 3, _5, 76, _4, 15, _5, 16, _2, 3, _5c, 2, _5, 1, },
			{ _5, }
		)
		rec1 = merge_cmd( -- 対アンディ 自動ガード+リバサ立A向けの炎の種馬相打ちコンボ
			{ _4, 11, _2a, 4, _2, 1, _3, 2, _6, 7, _6a, 2, _5, 40, _2a, 6, _2c, 5, _5, 5, _6ac, 3, _5, 28, _1a, 6, _5, 16, _5c, 7, _5, 20, _5c, 5, _5, 23, _4, 6, _2, 4, _1c, 3, _5, 68, _5b, 3, _5, 4, _5b, 4, _5, 33, _2, 3, _5c, 2, _5, 1, },
			{ _5, }
		)
		rec1 = merge_cmd( -- 対ギース 自動ガード+リバサ下A向けの炎の種馬相打ちコンボ
			{ _4, 11, _2a, 4, _2, 1, _3, 2, _6, 7, _6a, 2, _5, 38, _2b, 6, _2c, 5, _5, 9, _6ac, 3, _5, 28, _1a, 6, _5, 16, _5c, 7, _5, 15, _5c, 5, _5, 15, _4, 6, _2, 4, _1c, 3, _5, 76, _4, 15, _5, 16, _2, 3, _5c, 2, _5, 1, },
			{ _5, }
		)
		]]
		--[[
		rec1 = merge_cmd(  -- ガード解除直前のNのあと2とNの繰り返しでガード硬直延長,をさらに投げる
			{ _8, _5, 46, _6, 15, _5, 13, _4, _1, 5, _2, 2, _3, 4, _6, 6, _4c, 4, _c, 102, _5, 36, _c, 12, _5, _c, 11, _5, },
			{ _5, }
		)
		]]

		--[[
		rec1 = merge_cmd(  -- ガード解除直前のNのあと2とNの繰り返しでガード硬直延長,をさらに投げる
			{ _8, _5, 46, _1, 20, _2, 27, _5, 6, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1,
			_5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1,},
			{ _8, _5, 46, _2b, _5, 12, _2b, _5, 50, _4, _5, _4, _5, _7, 6, _7d, _5, 15, _c, _5, }
		)
		rec1 = merge_cmd(  -- ガード解除直前のNのあと2とNの繰り返しでガード硬直延長,をさらに投げる
			{ _8, _5, 46, _1, 20, _2, 27, _5, 6, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1,
			_5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1,},
			{ _8, _5, 46, _2b, _5, 12, _2b, _5, 50, _4, _5, _4, _5, _7, 6, _7d, _5, 41, _c, _5, }
		)
		]]
		-- 真神足拳調査
		--[[
		rec8 = merge_cmd( --神足拳 ギリギリ遅らせ入力
			{ _8, _5, 46, _6, 17, _5, 17, _6, _5, 6, _a, _5, 2, _6, _5, },
			{ }
		)
		]]

		--[[
		rec1 = merge_cmd(  -- ガード解除直前のNでガード硬直延長
			{ _8, _5, 46, _1, 20, _2, 27, _5, },
			{ _8, _5, 46, _2b, _5, 12, _2b, _5, }
		)
		rec1 = merge_cmd(  -- ガード解除直前のNのあと2とNの繰り返しでガード硬直延長,をさらに投げる
			{ _8, _5, 46, _1, 20, _2, 27, _5, 6, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1,
			_5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1,},
			{ _8, _5, 46, _2b, _5, 12, _2b, _5, 42, _4, 20, _4c, _5, }
		)

		-- LINNさんネタの確認 ... リバサバクステキャンセルサイクロンで重ね飛燕失脚の迎撃
		rec1 = merge_cmd( -- バクステ回避
			{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
			{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, })
		rec2 = merge_cmd( -- サイクロン成立
			{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
			{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 2, _5c, })
		rec3 = merge_cmd( -- サイクロン成立
			{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
			{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 3, _5c, })
		rec4 = merge_cmd( -- サイクロン成立
			{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
			{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 4, _c, })
		rec5 = merge_cmd( -- サイクロン成立
			{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
			{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 5, _c, })
		rec3 = merge_cmd( -- サイクロン不成立
			{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
			{ _8, _5, 46, _2, 15, _2 , _5, 111, _8, _4, _2, _6, _5, _4, _5, _4, _5, 6, _c, })
		rec4 = merge_cmd( -- サイクロン不成立
			{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
			{ _8, _5, 46, _2, 15, _2 , _5, 110, _8, _4, _2, _6, _5, _4, _5, _4, _5, 7, _c, })
		rec1 = merge_cmd( -- リバサバクステキャンセルアンリミ
			{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
			{ _8, _5, 46, _2, 15, _2 , _5, 110, _6, _3, _2, _1, _4, _6, _5, _4, _5, _4, _5, 5, _a, })
		rec1 = merge_cmd( -- リバササイクロンが飛燕失脚を投げられない状態でCがでて喰らう
			{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, }, -- 通常投げ→飛燕失脚重ね
			{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 1, _c, })
		rec2 = merge_cmd( -- リバササイクロンが飛燕失脚を投げられない状態でバクステがでる
			{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, }, -- 通常投げ→飛燕失脚重ね
			{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 2, _c, })
		rec3 = merge_cmd( -- リバサバクステキャンセルサイクロン
			{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, }, -- 通常投げ→飛燕失脚重ね
			{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 3, _c, })
		rec4 = merge_cmd( -- リバサバクステキャンセルサイクロン
			{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, }, -- 通常投げ→飛燕失脚重ね
			{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 4, _c, })
		rec5 = merge_cmd( -- リバサバクステキャンセルサイクロン
			{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, }, -- 通常投げ→飛燕失脚重ね
			{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 5, _c, })
		rec1 = merge_cmd( -- ガー不飛燕失脚 リバサバクステキャンセルサイクロン
			{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, }, -- 通常投げ→飛燕失脚重ね
			{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 6, _5c, })
		rec2 = merge_cmd( -- ガー不ジャンプB リバサバクステキャンセルレイブ
			{ _8, _5, 46, _2a, _5, 5, _2c, _5, 15, _6, _5, _4, _1, _2, _3, _bc, _5, 155, _9, _5, 29, _b, _1, 81, _5, },
			{ _8, _5, 46, _2, 15, _2 , _5, 191, _4, _1, _2, _3, _6, _4, _5, _6, _5, _6, _5, 4, _a, })
		rec2 = merge_cmd( -- ガー不ジャンプB リバサバクステキャンセルレイブ
			{ _8, _5, 46, _2a, _5, 5, _2c, _5, 15, _6, _5, _4, _1, _2, _3, _bc, _5, 155, _9, _5, 29, _b, _1, 81, _1, 289, _6, _5, _4, _1, _2, _3, _5, _4, _5, _4, _5, 3, _bc, _5, 178, _4, 23, _5, 26, _cd, _5, 51, _2, _1, _4, _5, _4, _5, _4, 3, _c, _5, 40, _cd, _5 },
			{ _8, _5, 46, _2, 15, _2 , _5, 191, _4, _1, _2, _3, _6, _4, _5, _6, _5, _6, _5, 4, _a, _5, 340, _4a, _5, 270, _6, _2, _3, _6, _c, _5, 76, _cd, _5  })
		rec3 = merge_cmd( -- ガー不ジャンプB リバサバクステキャンセル真空投げ
			{ _8, _5, 46, _2a, _5, 5, _2c, _5, 15, _6, _5, _4, _1, _2, _3, _bc, _5, 155, _9, _5, 29, _b, _1, 81, _5, },
			{ _8, _5, 46, _2, 15, _2 , _5, 191, _2, _4, _8, _6, _2, _4, _5, _6, _5, _6, _5, 4, _5a, })
		]]
		return { rec1, rec2, rec3, rec4, rec5, rec6, rec7, rec8 }
	end
	for i, preset_cmd in ipairs(research_cmd()) do
		local store = recording.slot[i].store
		for _, joy in ipairs(preset_cmd) do
			table.insert(store, { joy = joy, pos = { 1, -1 } })
		end
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
			p.init_stun = p.char_data.init_stuns

			do_recover(p, op, true)

			p.last_pure_dmg       = 0
			p.last_dmg            = 0
			p.last_dmg_scaling    = 0
			p.last_combo_dmg      = 0
			p.last_dmg            = 0
			p.last_combo          = 0
			p.last_combo_stun     = 0
			p.last_stun           = 0
			p.last_combo_st_timer = 0
			p.last_st_timer       = 0
			p.last_combo_pow      = 0
			p.last_pow            = 0
			p.tmp_combo           = 0
			p.tmp_dmg             = 0
			p.tmp_pow             = 0
			p.tmp_pow_rsv         = 0
			p.tmp_pow_atc         = 0
			p.tmp_stun            = 0
			p.tmp_st_timer        = 0
			p.tmp_pow             = 0
			p.tmp_combo_pow       = 0
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
		local fixpos     = { pgm:read_i16(players[1].addr.pos), pgm:read_i16(players[2].addr.pos) }
		local fixsway    = { pgm:read_u8(players[1].addr.sway_status), pgm:read_u8(players[2].addr.sway_status) }
		local fixscr     = {
			x = pgm:read_u16(mem.stage_base_addr + screen.offset_x),
			y = pgm:read_u16(mem.stage_base_addr + screen.offset_y),
			z = pgm:read_u16(mem.stage_base_addr + screen.offset_z),
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
			if k ~= "1 Player Start" and k ~= "2 Players Start" and f > 0 then
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
					if recording.fixpos == nil then
						rec_fixpos()
					end
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
			if k ~= "1 Player Start" and k ~= "2 Players Start" and recording.active_slot.side == joy_pside[rev_joy[k]] then
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
		if #recording.active_slot.store > 0 and (accept_input("Start", joy_val, state_past) or force_start_play == true) then
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
					pgm:write_u8(p.addr.sway_status, 0x00) --fixpos.fixsway[i])
					--pgm:write_u32(p.addr.base, 0x000261A0) -- 素立ち処理
					pgm:write_u32(p.addr.base, 0x00058D5A) -- やられからの復帰処理

					pgm:write_u8(p.addr.base + 0xC0, 0x80)
					pgm:write_u8(p.addr.base + 0xC2, 0x00)
					pgm:write_u8(p.addr.base + 0xFC, 0x00)
					pgm:write_u8(p.addr.base + 0xFD, 0x00)

					pgm:write_u8(p.addr.base + 0x61, 0x01)
					pgm:write_u8(p.addr.base + 0x63, 0x02)
					pgm:write_u8(p.addr.base + 0x65, 0x02)

					pgm:write_i16(p.addr.pos_y, 0x00)
					pgm:write_i16(p.addr.pos_z, 0x18)

					pgm:write_u32(p.addr.base + 0x28, 0x00)
					pgm:write_u32(p.addr.base + 0x48, 0x00)
					pgm:write_u32(p.addr.base + 0xDA, 0x00)
					pgm:write_u32(p.addr.base + 0xDE, 0x00)
					pgm:write_u32(p.addr.base + 0x34, 0x00)
					pgm:write_u32(p.addr.base + 0x38, 0x00)
					pgm:write_u32(p.addr.base + 0x3C, 0x00)
					pgm:write_u32(p.addr.base + 0x4C, 0x00)
					pgm:write_u32(p.addr.base + 0x50, 0x00)
					pgm:write_u32(p.addr.base + 0x44, 0x00)

					pgm:write_u16(p.addr.base + 0x60, 0x01)
					pgm:write_u16(p.addr.base + 0x64, 0xFFFF)
					pgm:write_u8(p.addr.base + 0x66, 0x00)
					pgm:write_u16(p.addr.base + 0x6E, 0x00)
					pgm:write_u8(p.addr.base + 0x6A, 0x00)
					pgm:write_u8(p.addr.base + 0x7E, 0x00)
					pgm:write_u8(p.addr.base + 0xB0, 0x00)
					pgm:write_u8(p.addr.base + 0xB1, 0x00)

					do_recover(p, op, true)

					p.last_blockstun = 0
					p.last_frame_gap = 0
				end
			end

			local fixpos = recording.fixpos
			if fixpos then
				-- 開始間合い固定 1:OFF 2:位置記憶 3:1Pと2P 4:1P 5:2P
				if fixpos.fixpos then
					for i, p in ipairs(players) do
						if global.replay_fix_pos == 3 or (global.replay_fix_pos == 4 and i == 3) or (global.replay_fix_pos == 5 and i == 4) then
							pgm:write_i16(p.addr.pos, fixpos.fixpos[i])
						end
					end
				end
				if fixpos.fixscr and global.replay_fix_pos and global.replay_fix_pos ~= 1 then
					pgm:write_u16(mem.stage_base_addr + screen.offset_x, fixpos.fixscr.x)
					pgm:write_u16(mem.stage_base_addr + screen.offset_x + 0x30, fixpos.fixscr.x)
					pgm:write_u16(mem.stage_base_addr + screen.offset_x + 0x2C, fixpos.fixscr.x)
					pgm:write_u16(mem.stage_base_addr + screen.offset_x + 0x34, fixpos.fixscr.x)
					pgm:write_u16(mem.stage_base_addr + screen.offset_y, fixpos.fixscr.y)
					pgm:write_u16(mem.stage_base_addr + screen.offset_z, fixpos.fixscr.z)
				end
			end
			players[1].input_side = pgm:read_u8(players[1].addr.input_side)
			players[2].input_side = pgm:read_u8(players[2].addr.input_side)
			players[1].disp_side  = get_flip_x(players[1])
			players[2].disp_side  = get_flip_x(players[2])

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

		if accept_input("Start", joy_val, state_past) then
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
		elseif pgm:read_u8(players[recording.player].addr.state) == 1 then
			if global.replay_stop_on_dmg then
				stop = true
			end
		end
		if not stop and store then
			-- 入力再生
			local pos = { players[1].input_side, players[2].input_side }
			--local pos = { players[1].disp_side, players[2].disp_side }
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

		if accept_input("Start", joy_val, state_past) then
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

			for _, fb in ipairs(p.fireball) do
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

			for _, fb in ipairs(p.fireball) do
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
					local disp_name = frame_group[1].disp_name or frame_group[1].name
					draw_text_with_shadow(x + 12, txty + y, disp_name, 0xFFC0C0C0)
				end
			end
			-- グループのフレーム数を末尾から描画
			for k = #frame_group, 1, -1 do
				local frame = frame_group[k]
				local x2 = x1 - frame.count
				local on_fb, on_prefb, on_ar, on_gd = false, false, false, false
				if x2 < xmin then
					if x2 + x1 < xmin and not main_frame then
						break
					end
					x2 = xmin
				else
					on_fb = frame.chg_fireball_state == true
					on_prefb = frame.chg_prefireball_state == true
					on_ar = frame.chg_air_state == 1
					on_gd = frame.chg_air_state == -1
				end

				if (frame.col + frame.line) > 0 then
					local evx = math.min(x1, x2)
					if on_fb then
						scr:draw_text(evx - 1.5, txty + y - 1, "●")
					elseif on_prefb then
						-- 飛び道具の処理発生ポイント(発生保障や完全消失の候補)
						scr:draw_text(evx - 2.0, txty + y - 1, "◆")
					end
					if on_ar then
						scr:draw_text(evx - 3, txty + y, "▲")
					elseif on_gd then
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
		if dip_config.infinity_life then
			pgm:write_u8(p.addr.life, max_life)
			pgm:write_u8(p.addr.max_stun, p.init_stun) -- 最大気絶値
			pgm:write_u8(p.addr.init_stun, p.init_stun) -- 最大気絶値
		elseif p.life_rec then
			-- 回復判定して回復
			if force or ((math.max(p.update_dmg, op.update_dmg) + 180) <= global.frame_number and p.state == 0) then
				-- やられ状態から戻ったときに回復させる
				pgm:write_u8(p.addr.life, max_life) -- 体力
				pgm:write_u8(p.addr.stun, 0)    -- 気絶値
				pgm:write_u8(p.addr.max_stun, p.init_stun) -- 最大気絶値
				pgm:write_u8(p.addr.init_stun, p.init_stun) -- 最大気絶値
				pgm:write_u16(p.addr.stun_timer, 0) -- 気絶値タイマー
			elseif max_life < p.life then
				-- 最大値の方が少ない場合は強制で減らす
				pgm:write_u8(p.addr.life, max_life)
			end
		end

		-- パワーゲージ回復
		-- 0x3C, 0x1E, 0x00
		local pow     = { 0x3C, 0x1E, 0x00 }
		local max_pow = pow[p.max] or (p.max - #pow) -- パワーMAXにするかどうか
		-- POWモード　1:自動回復 2:固定 3:通常動作
		if global.pow_mode == 2 then
			pgm:write_u8(p.addr.pow, max_pow)
		elseif global.pow_mode == 1 and p.pow == 0 then
			pgm:write_u8(p.addr.pow, max_pow)
		elseif global.pow_mode ~= 3 and max_pow < p.pow then
			-- 最大値の方が少ない場合は強制で減らす
			pgm:write_u8(p.addr.pow, max_pow)
		end
	end

	-- 1Pと2Pの通常投げ間合い取得
	-- 0x05D78Cからの実装
	local get_n_throw = function(p, op, height)
		-- 相手が向き合いか背向けかで押し合い幅を解決して反映
		local op_edge = 0xFFFF & (op.proc_pos - ((p.side == op.side) and op.push_back or op.push_front))
		-- 自身の押し合い判定を反映
		local p_edge = 0xFFFF & (p.pos - p.push_front)

		local a = 0xFFFF & math.abs(op.proc_pos - op_edge)
		local tw_center = p_edge - screen.left
		if 0 > p.side then
			tw_center = tw_center - a
		else
			tw_center = tw_center + a
		end

		-- 投げ間合いセット
		p.throw            = {
			x1 = tw_center - p.tw_half_range,
			x2 = tw_center + p.tw_half_range,
			half_range = p.tw_half_range,
			full_range = p.tw_half_range + p.tw_half_range,
			in_range = false,
		}
		local op_pos       = op.proc_pos - screen.left
		p.throw.in_range   = p.throw.x1 <= op_pos and op_pos <= p.throw.x2

		-- フックした情報の取得
		p.n_throw.left     = nil
		p.n_throw.right    = nil
		p.n_throw.top      = nil
		p.n_throw.bottom   = nil
		p.n_throw.on       = pgm:read_u8(p.n_throw.addr.on)
		p.n_throw.base     = pgm:read_u32(p.n_throw.addr.base)
		p.n_throw.opp_base = pgm:read_u32(p.n_throw.addr.opp_base)
		p.n_throw.opp_id   = pgm:read_u16(p.n_throw.addr.opp_id)
		p.n_throw.char_id  = pgm:read_u16(p.n_throw.addr.char_id)
		p.n_throw.side     = p.side
		p.n_throw.range1   = pgm:read_u8(p.n_throw.addr.range1)
		p.n_throw.range2   = pgm:read_u8(p.n_throw.addr.range2)
		p.n_throw.range3   = pgm:read_i8(p.n_throw.addr.range3)
		p.n_throw.range41  = pgm:read_i8(p.n_throw.addr.range41)
		p.n_throw.range42  = pgm:read_i8(p.n_throw.addr.range42)
		p.n_throw.range5   = pgm:read_i8(p.n_throw.addr.range5)
		p.n_throw.id       = pgm:read_i8(p.n_throw.addr.id)
		p.n_throw.pos_x    = p.pos - screen.left
		p.n_throw.pos_y    = height - p.pos_y - screen.top
		local range        = (p.n_throw.range1 == p.n_throw.range2 and math.abs(p.n_throw.range42 * 4)) or math.abs(p.n_throw.range41 * 4)
		range              = range + p.n_throw.range5 * -4
		range              = range + p.throw.half_range
		p.n_throw.range    = range
		p.n_throw.right    = p.n_throw.range * p.side
		p.n_throw.left     = (p.n_throw.range - p.throw.full_range) * p.side
		p.n_throw.type     = box_type_base.t
		p.n_throw.on       = p.addr.base == p.n_throw.base and p.n_throw.on or 0xFF
	end
	-- 空中投げ間合い取得
	-- 0x05FDCA,0x060426からの実装
	-- TODO アドレスの補正
	local can_air_throwable_bases = new_set(0x02C9D4, 0x02BF20, 0x02C132, 0x02C338, 0x02C552)
	local get_air_throw = function(p, op, height)
		-- 投げ間合いセット
		p.air_throw           = p.air_throw or {}
		-- 参考表示の枠なので簡易的なチェックにする
		p.air_throw.can_throw = p.in_air == true and op.in_air == true and
			can_air_throwable_bases[p.base] == true and pgm:read_u8(0x05FDE0 + p.char) ~= 0
		p.air_throw.x1        = p.side < 0 and -pgm:read_u16(0x060566) or 0
		p.air_throw.x2        = p.side < 0 and 0 or pgm:read_u16(0x060566)
		p.air_throw.y1        = pgm:read_u16(0x060568)
		p.air_throw.y2        = -p.air_throw.y1
		local op_pos          = op.proc_pos - p.proc_pos
		local op_pos_y        = op.old_pos_y - p.old_pos_y
		-- フックした情報の取得
		p.air_throw.in_range  = p.air_throw.x1 <= op_pos and
			op_pos <= p.air_throw.x2 and
			p.air_throw.y1 >= op_pos_y and
			op_pos_y >= p.air_throw.y2
		p.air_throw.on        = pgm:read_u8(p.air_throw.addr.on)
		p.air_throw.range_x   = pgm:read_i16(p.air_throw.addr.range_x)
		p.air_throw.range_y   = pgm:read_i16(p.air_throw.addr.range_y)
		p.air_throw.left      = 0
		p.air_throw.right     = p.air_throw.range_x * p.side
		p.air_throw.base      = pgm:read_u32(p.air_throw.addr.base)
		p.air_throw.opp_base  = pgm:read_u32(p.air_throw.addr.opp_base)
		p.air_throw.opp_id    = pgm:read_u16(p.air_throw.addr.opp_id)
		p.air_throw.pos_x     = p.pos - screen.left
		p.air_throw.pos_y     = screen.top + height - p.old_pos_y - p.old_pos_z
		p.air_throw.side      = p.side
		p.air_throw.top       = p.air_throw.range_y
		p.air_throw.bottom    = -p.air_throw.range_y
		p.air_throw.type      = box_type_base.at
		p.air_throw.on        = p.addr.base == p.air_throw.base and p.air_throw.on or 0xFF
	end
	-- 必殺投げ間合い取得
	local get_sp_throw = function(p, op, height)
		-- フックした情報の取得
		p.sp_throw.left     = nil
		p.sp_throw.right    = nil
		p.sp_throw.top      = nil
		p.sp_throw.bottom   = nil
		p.sp_throw.on       = pgm:read_u8(p.sp_throw.addr.on)
		p.sp_throw.front    = pgm:read_i16(p.sp_throw.addr.front)
		p.sp_throw.top      = -pgm:read_i16(p.sp_throw.addr.top)
		p.sp_throw.base     = pgm:read_u32(p.sp_throw.addr.base)
		p.sp_throw.opp_base = pgm:read_u32(p.sp_throw.addr.opp_base)
		p.sp_throw.opp_id   = pgm:read_u16(p.sp_throw.addr.opp_id)
		p.sp_throw.side     = p.side
		p.sp_throw.bottom   = pgm:read_i16(p.sp_throw.addr.bottom)
		p.sp_throw.pos_x    = p.pos - screen.left
		p.sp_throw.pos_y    = screen.top + height - p.old_pos_y - p.old_pos_z
		p.sp_throw.right    = p.sp_throw.front * p.side
		p.sp_throw.type     = box_type_base.pt
		p.sp_throw.on       = p.addr.base == p.sp_throw.base and p.sp_throw.on or 0xFF
		if p.sp_throw.top == 0 then
			p.sp_throw.top    = nil
			p.sp_throw.bottom = nil
		end
	end
	-- 0:攻撃無し 1:ガード継続小 2:ガード継続大
	local get_gd_strength = function(p)
		-- 飛び道具は無視
		if p.addr.base ~= 0x100400 and p.addr.base ~= 0x100500 then
			return 1
		end
		local char_id     = pgm:read_u16(p.addr.base + 0x10)
		local char_4times = 0xFFFF & (char_id + char_id)
		char_4times       = 0xFFFF & (char_4times + char_4times)
		-- 家庭用0271FCからの処理
		local cond1       = pgm:read_u8(p.addr.base + 0xA2) -- ガード判断用 0のときは何もしていない
		local cond2       = pgm:read_u8(p.addr.base + 0xB6) -- ガード判断用 0のときは何もしていない
		local ret         = 0
		if cond1 ~= 0 then
			ret = 1
		elseif cond2 ~= 0 then
			local b2 = 0x80 == (0x80 & pgm:read_u8(pgm:read_u32(0x8C9E2 + char_4times) + cond2))
			ret = b2 and 2 or 1
		end
		return ret
	end
	local summary_rows, summary_sort_key = {
		"動作",
		"動作C0",
		"動作C4",
		"動作C8",
		"動作CC",
		"動作D0",
		"投げ無敵",
		"方向(動作/入力)",
		"ブレイクショット",
		"押し合い範囲",
		"攻撃対象",
		"攻撃/気絶",
		"硬直 当/防(BS)",
		"攻撃範囲 最大",
		"やられ範囲 最大",
		"キャッチ範囲",
		"投げ間合い",
		"ヒット数",
		"POW(基/当/防)",
		"詠酒間合い",
		"キャンセル",
		"キャンセル補足",
		"滑り攻撃補足",
		"効果(地/空)",
		"1 ガード方向",
		"1 接触判定",
		"1 攻撃高さ",
		"2 ガード方向",
		"2 接触判定",
		"2 攻撃高さ",
		"3 ガード方向",
		"3 接触判定",
		"3 攻撃高さ",
		"1 攻撃範囲",
		"2 攻撃範囲",
		"3 攻撃範囲",
		"1 やられ範囲",
		"2 やられ範囲",
		"3 やられ範囲",
	}, {}
	for i, k in ipairs(summary_rows) do
		summary_sort_key[k .. ":"] = i
	end
	local sort_summary = function(summary)
		table.sort(summary, function(row1, row2)
			local k1 = summary_sort_key[row1[1]] or 100
			local k2 = summary_sort_key[row2[1]] or 100
			return (k1 < k2)
		end)
		return summary
	end
	local faint_cancels = {
		{ { name = "フ", f = 18 }, },                  -- テリー
		{ { name = "フ", f = 18 }, },                  -- アンディ
		{ { name = "フ", f = 18 }, },                  -- 東
		{ { name = "フ", f = 18 }, },                  -- 舞
		{ { name = "フ", f = 19 }, },                  -- ギース
		{ { name = "フ", f = 18 }, },                  -- 双角
		{ { name = "フ", f = 19 }, },                  -- ボブ
		{ { name = "フ", f = 16 }, },                  -- ホンフゥ
		{ { name = "フ", f = 41 }, },                  -- マリー
		{ { name = "フ", f = 15 }, },                  -- フランコ
		{ { name = "フ", f = 18 }, { name = "中蛇", f = 9, } }, -- 山崎
		{ { name = "フ", f = 57 }, { name = "真眼", f = 47, } }, -- 崇秀
		{ { name = "フ", f = 27 }, { name = "龍転", f = 25, } }, -- 崇雷
		{ { name = "フ", f = 47 }, },                  -- ダック
		{ { name = "フ", f = 19 }, { name = "覇気", f = 28, } }, -- キム
		{ { name = "フ", f = 42 }, },                  -- ビリー
		{ { name = "フ", f = 23 }, { name = "軟体", f = 20, } }, -- チン
		{ { name = "フ", f = 19 }, },                  -- タン
		{},                                             -- ローレンス
		{ { name = "フ", f = 17 }, },                  -- クラウザー
		{ { name = "フ", f = 18 }, },                  -- リック
		{ { name = "フ", f = 22 }, },                  -- シャンフェイ
		{ { name = "フ", f = 13 }, },                  -- アルフレッド
	}
	local check_edge = function(edge)
		if edge.front and edge.top and edge.bottom and edge.back then
			return true
		end
		return false
	end
	local add_frame_to_summary = function(summary)
		for _, row in ipairs(summary) do
			row[3] = global.frame_number
		end
		return summary
	end
	local make_throw_summary = function(p, summary)
		local range_label
		if summary.n_throw == true then
			range_label = string.format("地/%sF/前%s/後%s",
				summary.tw_threshold,
				summary.edge.throw.front,
				summary.edge.throw.back)
		elseif summary.air_throw == true then
			range_label = string.format("空/前%s/上%s(%s)/下%s(%s)/後%s",
				summary.edge.throw.front,
				summary.edge.throw.top + p.pos_y,
				summary.edge.throw.top,
				summary.edge.throw.bottom + p.pos_y,
				summary.edge.throw.bottom,
				summary.edge.throw.back)
		elseif summary.sp_throw == true then
			--[[
				p.act
					M.スパイダー 86
					M.スナッチャー 91
					ジャーマンスープレックス A6
					フェイスロック  A6
					投げっぱなしジャーマン A6
					デンジャラススパイダー F0
					ダブルスパイダー AF B0
					ダブルスナッチャー B9 BA
					ダブルクラッチ  C4 9D
					M.ダイナマイトスウィング
					M.タイフーン FF 100

				summary.sp_throw_id
					05 デンジャラ
					07 リフトアップ
					12 Gサイクロン
					08 爆弾パチキ
					12 ドリル
					11 ブレスパBR
					10 ブレスパ
					12 まじんが
					04 きもんじｎ
					07 真空投げ
					12 羅生門
					06 雷鳴ごうは
					08 ダイナマイトスイング
			]]
			local air, inf, otg = false, false, false
			if p.char == 0x05 then       --ギース・ハワード
				otg = summary.sp_throw_id == 0x06
			elseif p.char == 0x06 then   --望月双角,
			elseif p.char == 0x09 then   --ブルー・マリー
				air = p.act == 0x91 or   -- M.スナッチャー
					p.act == 0xB9 or p.act == 0xBA -- ダブルスナッチャー
				inf = p.act == 0xC4 or p.act == 0x9D -- ダブルクラッチ
				otg = summary.sp_throw_id == 0x08
			elseif p.char == 0x0B then   --山崎竜二
			elseif p.char == 0x0E then   --ダック・キング
				air = summary.sp_throw_id == 0x11
			elseif p.char == 0x14 then   --ヴォルフガング・クラウザー
			elseif p.char == 0x16 then   --李香緋
			end
			if air == true then
				range_label = string.format("空/%sF/前%s/上%s(%s)/下%s(%s)/後%s",
					summary.tw_threshold,
					summary.edge.throw.front,
					summary.edge.throw.top + p.pos_y,
					summary.edge.throw.top,
					summary.edge.throw.bottom + p.pos_y,
					summary.edge.throw.bottom,
					summary.edge.throw.back)
			elseif inf == true then
				range_label = string.format("地/%sF/前%s/上∞/下∞/後%s",
					summary.tw_threshold,
					summary.edge.throw.front,
					summary.edge.throw.back)
			elseif otg == true then
				range_label = string.format("追撃/前%s/後%s",
					summary.tw_threshold,
					summary.edge.throw.front,
					summary.edge.throw.back)
			else
				range_label = string.format("地/%sF/前%s/後%s",
					summary.tw_threshold,
					summary.edge.throw.front,
					summary.edge.throw.back)
			end
		end
		local throw_summary = {
			{ "投げ間合い:", range_label },
		}
		return add_frame_to_summary(throw_summary)
	end
	local make_parry_summary = function(p, summary)
		local range_label = string.format("前%s/上%s/下%s/後%s",
			summary.edge.parry.front,
			summary.edge.parry.top + p.pos_y,
			summary.edge.parry.bottom + p.pos_y,
			summary.edge.parry.back)
		local parry_summary = {
			{ "キャッチ範囲:", range_label },
		}
		return add_frame_to_summary(parry_summary)
	end
	local make_atk_summary = function(p, summary)
		-- 詠酒間合い
		local esaka_label = (p.esaka_range > 0) and p.esaka_range or "-"
		-- ブレイクショット
		local bs_label = "-"
		if p.bs_atk == true then
			bs_label = "〇"
		end
		-- キャンセル可否
		local cancel_label, cancel_advs_label, cancel_advs = "連×/必×", "", {}
		if p.flag_c8 == 0 and p.cancelable and p.cancelable ~= 0 then
			if faint_cancels[p.char] and p.attack_id then
				for _, fc in ipairs(faint_cancels[p.char]) do
					local p1  = 1 + p.hitstop + fc.f
					local p2h = p.hitstop + p.hitstun
					local p2g = p.hitstop_gd + p.blockstun
					table.insert(cancel_advs, string.format(fc.name .. ":当%sF/防%sF", p2h - p1, p2g - p1))
				end
			end
			cancel_label = string.format("%s", p.repeatable and "連〇/必〇" or "連×/必〇")
			if #cancel_advs > 0 then
				cancel_advs_label = table.concat(cancel_advs, ",")
			end
		end
		local slide_label = p.slide_atk and "滑(CA×)/" or ""
		local atk_summary = {
			{ "詠酒間合い:",          esaka_label },
			{ "ブレイクショット:", bs_label },
			{ "キャンセル:",          slide_label .. cancel_label .. string.format("%02x", p.cancelable) },
			{ "キャンセル補足:",    cancel_advs_label },
			{ "滑り攻撃補足:",       p.dash_act_info }
		}
		return add_frame_to_summary(atk_summary)
	end
	local make_atkact_summary = function(p, summary, fbno)
		fbno = fbno or 0
		local prefix = fbno == 0 and "" or ("弾" .. fbno)
		local atkact_summary = {}
		if p.fake_hit == false and (p.attack_id > 0 or p.is_fireball == true) then
			for _, box in ipairs(p.hitboxes) do
				if box.atk and box.info then
					local info = box.info

					-- 避け攻撃つぶし
					local punish_away_label, asis_punish_away_label
					if summary.normal_hit == hit_proc_types.same_line or
						summary.normal_hit == hit_proc_types.diff_line then
						punish_away_label = "上方"
						asis_punish_away_label = "上方"
						if info.punish_away == 1 then
							punish_away_label = "〇避け攻撃"
						elseif info.punish_away == 2 then
							punish_away_label = "〇避け攻撃ロ1"
						elseif info.punish_away == 3 then
							punish_away_label = "〇避け攻撃ロ2"
						elseif info.punish_away == 4 then
							punish_away_label = "〇屈1"
						elseif info.punish_away == 5 then
							punish_away_label = "〇屈2"
						elseif info.punish_away == 6 then
							punish_away_label = "〇屈3"
						end
						if info.asis_punish_away == 1 then
							asis_punish_away_label = "〇避け攻撃"
						elseif info.asis_punish_away == 2 then
							asis_punish_away_label = "〇避け攻撃ロ1"
						elseif info.asis_punish_away == 3 then
							asis_punish_away_label = "〇避け攻撃ロ2"
						elseif info.asis_punish_away == 4 then
							asis_punish_away_label = "〇屈1"
						elseif info.asis_punish_away == 5 then
							asis_punish_away_label = "〇屈2"
						elseif info.asis_punish_away == 6 then
							asis_punish_away_label = "〇屈3"
						end
					end

					local blocks, sway_blocks = {}, {}
					if testbit(info.blockbit, block_types.high) then
						table.insert(blocks, "立")
					end
					if testbit(info.blockbit, block_types.high_tung) then
						table.insert(blocks, "立(タンのみ)")
					end
					if testbit(info.blockbit, block_types.low) then
						table.insert(blocks, "屈")
					end
					if testbit(info.blockbit, block_types.air) then
						table.insert(blocks, "空")
					end
					if testbit(info.blockbit, block_types.sway_high) then
						table.insert(sway_blocks, "立")
					end
					if testbit(info.blockbit, block_types.sway_high_tung) then
						table.insert(sway_blocks, "立(タンのみ)")
					end
					if testbit(info.blockbit, block_types.sway_low) then
						table.insert(sway_blocks, "屈")
					end

					local parry = {}
					table.insert(parry, info.range_j_atm_nage and "上" or info.j_atm_nage and "(上)" or nil) -- 上段当て身投げ可能
					table.insert(parry, info.range_urakumo and "裏" or info.urakumo and "(裏)" or nil) -- 裏雲隠し可能
					table.insert(parry, info.range_g_atm_uchi and "下" or info.g_atm_uchi and "(下)" or nil) -- 屈段当て身打ち可能
					table.insert(parry, info.range_gyakushu and "逆" or info.gyakushu and "(逆)" or nil) -- 逆襲拳可能
					table.insert(parry, info.range_sadomazo and "サ" or info.sadomazo and "(サ)" or nil) -- サドマゾ可能
					table.insert(parry, info.range_phx_tw and "フ" or info.phx_tw and "(フ)" or nil) -- フェニックススルー可能
					table.insert(parry, info.range_baigaeshi and "倍" or info.baigaeshi and "(倍)" or nil) -- 倍返し可能
					table.insert(parry, info.range_katsu and "喝消し" or info.katsu and "(喝消し)" or nil) -- 喝を相殺可能
					table.insert(parry, info.nullify and "弾消し" or nil)                -- 弾を相殺可能
					table.insert(summary.boxes, {
						punish_away_label = punish_away_label,
						asis_punish_away_label = asis_punish_away_label,
						block_label = #blocks == 0 and "ガード不能" or table.concat(blocks, ","),
						sway_block_label = #sway_blocks == 0 and "-" or table.concat(sway_blocks, ","),
						parry_label = #parry == 0 and "不可" or string.gsub(table.concat(parry, ","), "%),%(", ","),
						reach_label = string.format("前%s/上%s(%s)/下%s(%s)/後%s",
							box.reach.front,
							box.reach.top + p.pos_y,
							box.reach.top,
							box.reach.bottom + p.pos_y,
							box.reach.bottom,
							box.reach.back)
					})
					box.type_count = #summary.boxes
				end
			end
			-- 攻撃範囲
			local reach_label
			if summary.edge.hit.front then
				reach_label = string.format("前%s/上%s/下%s/後%s",
					summary.edge.hit.front,
					summary.edge.hit.top + p.pos_y,
					summary.edge.hit.bottom + p.pos_y,
					summary.edge.hit.back)
			else
				reach_label = "-"
			end
			-- ヒット効果
			local effect_label = "-"
			if p.effect then
				local e = p.effect + 1
				effect_label = string.format("%s:%s/%s", p.effect, hit_effects[e][1], hit_effects[e][2])
				if hit_effects[e][3] then
					effect_label = effect_label .. " " .. hit_effects[e][3]
				end
				if summary.can_techrise == false then
					effect_label = effect_label .. " 受身不可"
				end
			end
			-- 追撃能力
			local followups = {}
			if summary.down_hit then
				table.insert(followups, "ダウン追撃")
			end
			if summary.air_hit then
				table.insert(followups, "空中追撃")
			end
			local followup_label = #followups == 0 and "" or (table.concat(followups, ","))
			-- 弾強度
			local prj_rank_label = ""
			if p.is_fireball then
				prj_rank_label = string.format("弾強度:%s%s", summary.prj_rank, (p.fake_hit == true and p.full_hit == false) and "(被相殺)" or "")
			end

			for box_no, box in ipairs(summary.boxes) do
				table.insert(atkact_summary, { box_no .. " ガード方向:", string.format("メイン:%s/スウェー:%s", box.block_label, box.sway_block_label) })
				table.insert(atkact_summary, { box_no .. " 接触判定:", box.parry_label })
				local label = box.punish_away_label
				if box.punish_away_label ~= box.asis_punish_away_label then
					label = label .. "(" .. box.asis_punish_away_label .. ")"
				end
				table.insert(atkact_summary, { box_no .. " 攻撃高さ:", label })
				table.insert(atkact_summary, { box_no .. " 攻撃範囲:", box.reach_label })
			end
			table.insert(atkact_summary, { "攻撃対象:", summary.normal_hit or summary.down_hit or summary.air_hit or "-" })
			table.insert(atkact_summary, { "攻撃範囲 最大:", reach_label })
			table.insert(atkact_summary, { prefix .. "効果(地/空):", effect_label .. " " .. followup_label })
			table.insert(atkact_summary, { prefix .. "硬直 当/防(BS):",
				p.hitstun and
				string.format(prefix .. "%sF(%sF)/%sF(%sF)",
					p.hitstun and p.hitstun or "-",
					summary.hitstop,
					p.blockstun,
					summary.hitstop_gd) or
				"-"
			})
			table.insert(atkact_summary, { prefix .. "ヒット数:", string.format("%s/%s %s", summary.max_hit_nm, summary.max_hit_dn, prj_rank_label) })

			return add_frame_to_summary(atkact_summary)
		end
		return nil
	end
	local make_dmg_summary = function(p, summary, fbno)
		fbno = fbno or 0
		local prefix = fbno == 0 and "" or ("弾" .. fbno)
		local atkact_summary = {}
		-- local chip_type = string.format(" %s %s", summary.chip_dmg_nm, summary.attack_id)
		table.insert(atkact_summary, { prefix .. "攻撃/気絶:", string.format("%s(%s)/%s(%sF) %02x",
			summary.pure_dmg,
			summary.chip_dmg and (summary.chip_dmg > 0 and summary.chip_dmg or 0) or 0,
			summary.pure_st,
			summary.pure_st_tm,
			summary.attack) })
		return add_frame_to_summary(atkact_summary)
	end
	local make_pow_summary = function(p, summary)
		local atkact_summary = {}
		-- パワーゲージ
		local pow_label = string.format("%s/%s/%s  返/吸:%s/%s", p.pow_up or 0, p.pow_up_hit or 0, p.pow_up_gd or 0, p.pow_revenge or 0, p.pow_absorb or 0)
		table.insert(atkact_summary, { "POW(基/当/防):", pow_label })
		return add_frame_to_summary(atkact_summary)
	end
	local make_hurt_summary = function(p, summary)
		local hurt_labels = {}
		local has_hurt = check_edge(summary.edge.hurt)
		if not (has_hurt == true and (summary.hurt == true or p.hit.vulnerable == true)) then
			summary.hurt_inv = { hurt_inv_type.full }
		end
		-- やられ判定無敵
		for _, inv in ipairs(summary.hurt_inv) do
			table.insert(hurt_labels, inv.disp_label)
		end
		local hurt_label = table.concat(hurt_labels, ",")

		local throw_invincibles = {}
		-- 投げ無敵
		for _, inv in ipairs(summary.throw_inv) do
			table.insert(throw_invincibles, inv.disp_label)
		end
		local throw_label = table.concat(throw_invincibles, ",")
		local reach_label = ""
		if has_hurt == true then
			reach_label = string.format("前%s/上%s/下%s/後%s",
				summary.edge.hurt.front,
				summary.edge.hurt.top + p.pos_y,
				summary.edge.hurt.bottom + p.pos_y,
				summary.edge.hurt.back)
		end
		local normal, otg, juggle, high, low, highg, lowg, airg = 0, 0, 0, 0, 0, 0, 0, 0
		local push_label = "なし"
		summary.hurt_boxes = summary.hurt_boxes or {}
		for _, box in ipairs(p.hitboxes) do
			if not box.atk then
				local type_label = nil
				if box.type == box_type_base.p then
					push_label = string.format("前%s/上%s(%s)/下%s(%s)/後%s",
						box.reach.front,
						box.reach.top + p.pos_y,
						box.reach.top,
						box.reach.bottom + p.pos_y,
						box.reach.bottom,
						box.reach.back)
				elseif box.type == box_type_base.v1 or box.type == box_type_base.v2 then
					normal = normal + 1
					type_label = normal .. " やられ範囲:"
				elseif box.type == box_type_base.v3 then
					otg = otg + 1
					type_label = otg .. " ダウン追撃:"
				elseif box.type == box_type_base.v4 then
					juggle = juggle + 1
					type_label = juggle .. " 空中追撃:"
				elseif box.type == box_type_base.v6 then
					high = high + 1
					type_label = high .. " 対ライン上攻撃:"
				elseif box.type == box_type_base.x1 then
					low = low + 1
					type_label = low .. " 対ライン下攻撃:"
				elseif box.type == box_type_base.g1 then
					highg = highg + 1
					type_label = highg .. " 上段ガード:"
				elseif box.type == box_type_base.g2 then
					lowg = lowg + 1
					type_label = lowg .. " 下段ガード:"
				elseif box.type == box_type_base.g3 then
					airg = airg + 1
					type_label = airg .. " 空中ガード:"
				end

				if type_label then
					table.insert(summary.hurt_boxes, {
						type_label  = type_label,
						reach_label = string.format("前%s/上%s(%s)/下%s(%s)/後%s ",
							box.reach.front,
							box.reach.top + p.pos_y,
							box.reach.top,
							box.reach.bottom + p.pos_y,
							box.reach.bottom,
							box.reach.back)
					})
					box.type_count = #summary.hurt_boxes
				end
			end
		end

		local sides_label -- 00:左側 80:右側
		sides_label = (p.internal_side == 0x0) and "右" or "左"
		sides_label = sides_label .. ((p.input_side == 0x0) and "/右" or "/左")
		-- 見た目と入力方向が違う状態
		sides_label = sides_label .. ((p.internal_side == p.input_side) and "" or "＊")

		local hurt_sumamry = {
			{ "投げ無敵:",           throw_label },
			{ "方向(動作/入力):",  sides_label },
			{ "押し合い範囲:",     push_label },
			{ "やられ範囲 最大:", reach_label .. hurt_label },
		}
		for _, box in ipairs(summary.hurt_boxes) do
			table.insert(hurt_sumamry, { box.type_label, box.reach_label })
		end

		-- 移動距離 進力とみなす値 慣性とみなす値
		if p.diff_pos_total > 0 or p.thrust > 0 or p.inertia > 0 then
			table.insert(hurt_sumamry, { "動作:", string.format("M %0.03f T %0.03f I %0.03f", p.diff_pos_total, p.thrust, p.inertia) })
		end

		-- フラグによる状態の表示
		if p.flag_c0 > 0 then
			table.insert(hurt_sumamry, { "動作C0:", get_flag_name(p.flag_c0, sts_flg_names[0xC0]) })
		end
		if p.flag_c4 > 0 then
			table.insert(hurt_sumamry, { "動作C4:", get_flag_name(p.flag_c4, sts_flg_names[0xC4]) })
		end
		if p.flag_c8 > 0 then
			table.insert(hurt_sumamry, { "動作C8:", get_flag_name(p.flag_c8, sts_flg_names[0xC8]) })
		end
		if p.flag_cc > 0 then
			table.insert(hurt_sumamry, { "動作CC:", get_flag_name(p.flag_cc, sts_flg_names[0xCC]) })
		end
		if p.flag_d0 > 0 then
			table.insert(hurt_sumamry, { "動作D0:", get_flag_name(p.flag_d0, sts_flg_names[0xD0]) })
		end

		return add_frame_to_summary(hurt_sumamry)
	end

	local new_box_summary = function(p)
		local throw_inv = throw_inv_type.get(p)
		local ret = {
			hit           = false, -- 攻撃判定あり
			otg           = false, -- ダウン追撃判定あり
			juggle        = false, -- 空中追撃判定あり
			hurt          = false, -- くらい判定あり（＝打撃無敵ではない)
			throw         = false, -- 投げ判定あり
			block         = false, -- ガード判定あり
			blockbits     = {},
			blockbit      = 0,
			parry         = false, -- 当て身キャッチ判定あり
			boxes         = {}, -- 攻撃判定ごとの情報
			edge          = {
				-- 判定の最大範囲
				hit   = {},
				hurt  = {},
				block = {},
				parry = {},
				throw = {},
			},
			hurt_inv      = {}, -- やられ判定無敵
			throw_inv     = throw_inv, -- 投げ無敵
			throw_inv_set = table_to_set(throw_inv),
		}
		return ret
	end

	local force_y_pos = { "OFF", 0 }
	for i = 1, 256 do
		table.insert(force_y_pos, i)
	end
	for i = -1, -256, -1 do
		table.insert(force_y_pos, i)
	end

	-- 判定データの取得
	local debug_box = function(p, pgm)
		-- do_debug_box(p, pgm)
	end
	local do_debug_box = function(p, pgm)
		-- メモリのコピー処理を再現できないかぎり無理
		-- 家庭用004A76からの処理、必要かどうか不明
		if pgm:read_u16(0x107EC6) ~= p.act_boxtype then
		end
		local d0 = p.side ~ pgm:read_u8(p.addr.base + 0x6A)
		print("frame=%s %x %s x=%s y=%s,%s %x %x",
			global.frame_number, p.addr.base, (0 < d0) and ">" or "<",
			p.pos, p.pos_y, p.pos_z, p.act_boxtype, pgm:read_u16(0x107EC6))
		for d2 = 1, pgm:read_u8(p.addr.box_base2) do
			local a2 = p.box_base2 + 5 * (d2 - 1)
			-- 004A9Eからの処理
			-- local d5 = 0xFFFF & ((0xFF & ((pgm:read_u8(a2) & 0x1F) - 0x20)) * 256)
			local d5 = pgm:read_u8(a2) & 0x1F
			local y1, y2 = pgm:read_u8(a2 + 0x1), pgm:read_u8(a2 + 0x2)
			local x1, x2 = pgm:read_u8(a2 + 0x3), pgm:read_u8(a2 + 0x4)
			printf("  %s addr=%x data=%02x%02x%02x%02x%02x type=%03x y1=%s y2=%s x1=%s x2=%s",
				d2, a2, d5, y1, y2, x1, x2, d5, y1, y2, x1, x2)
		end
	end

	-- 投げ間合いで使う立ち状態の押し合い判定
	-- 家庭用0x05D78Cからの処理
	local get_push_range = function(p, fix)
		local d5 = pgm:read_u8(fix + fix_bp_addr(0x05C99C) + p.char_8times)
		if fix == 0x3 then
			d5 = 0xFF00 + d5
			if 0 > p.side then -- 位置がマイナスなら
				d5 = 0x10000 - d5 -- NEG
			end
		end
		d5 = 0xFFFF & (d5 + d5) -- 2倍値に
		d5 = 0xFFFF & (d5 + d5) -- さらに2倍値に
		return d5
	end

	local frame_event_types = {
		reset = 0,
		split = 1,
		inactive = 2,
		active = 3,
	}
	local frame_attack_types = {
		attacking = 2 ^ 0, -- 0x1
		fake = 2 ^ 1, -- 0x10
		juggling = 2 ^ 3, -- 0x100
		harmless = 2 ^ 4, -- 0x1000
		x05 = 2 ^ 5, -- attack用 5 ~ 8
		x06 = 2 ^ 6, --
		x07 = 2 ^ 7, --
		x08 = 2 ^ 8, --
		x09 = 2 ^ 9, -- act_count用 9 ~ 16
		x17 = 2 ^ 17, -- 技データ用 17 ~ 32
	}
	local on_frame_func = {
		gd_str_txt = { "小", "大" },
	}
	local frame_infos = {}
	on_frame_func.break_info = function(info, event_type)
		-- ブレイク
		if info.last_event == frame_event_types.inactive and #info.actives == 0 then
			info.startup = info.count
		elseif info.last_event == frame_event_types.active then
			table.insert(info.actives, { count = info.count, attackbit = info.attackbit })
			table.insert(info.summaries, info.summary)
		elseif info.last_event == frame_event_types.inactive then
			if event_type == frame_event_types.active or event_type == frame_event_types.split then
				table.insert(info.actives, { count = -info.count, attackbit = info.attackbit })
			else
				info.recovery = info.count
			end
		end
		info.count = 0
	end
	on_frame_func.insert_tbl = function(pow, tbl, val)
		table.insert(tbl, pow == 1 and string.format("%s", val) or string.format("%sx%s", val, pow))
	end
	on_frame_func.build_txt1 = function(ctx, max, count, curr)
		ctx = ctx or { prev = nil, pow = 0, tbl = {} }
		if ctx.prev ~= curr then
			if ctx.prev then
				on_frame_func.insert_tbl(ctx.pow, ctx.tbl, ctx.prev)
			end
			ctx.prev = curr
			ctx.pow = 1
		elseif ctx.prev == curr then
			ctx.pow = ctx.pow + 1
		end
		if count == max then
			on_frame_func.insert_tbl(ctx.pow, ctx.tbl, ctx.prev)
		end
		return ctx
	end
	on_frame_func.build_txt2 = function(ctx, max, count, curr)
		ctx = ctx or { tbl = {} }
		table.insert(ctx.tbl, curr)
		return ctx
	end
	on_frame_func.dmg_txt = function(chip_dmg, pure_dmg)
		if chip_dmg == 0 then
			return string.format("%s", pure_dmg)
		end
		return string.format("%s(%s)", pure_dmg, chip_dmg)
	end
	on_frame_func.stun_txt = function(pure_st, pure_st_tm)
		if pure_st_tm == 0 then
			if pure_st == 0 then
				return "-"
			end
			return string.format("%s", pure_st)
		end
		return string.format("%s/%s", pure_st, pure_st_tm)
	end
	on_frame_func.effect_txt = function(effect, gd_strength, hitstun, blockstun)
		local e = effect + 1
		local e1, e2 = hit_effects[e][1], hit_effects[e][2]
		if e1 == e2 then
			return string.format("%s(-/%s)", e1, blockstun)
		elseif hit_effect_nokezoris[e1] then
			return string.format("%s(%s/%s)/%s", e1, hitstun, blockstun, e2)
		end
		return string.format("%s(-/%s)/%s", e1, blockstun, e2)
	end
	on_frame_func.block_txt = function(air_hit, blockbit)
		local lo = testbit(blockbit, block_types.low)
		local hi = testbit(blockbit, block_types.high)
		local hitg = testbit(blockbit, block_types.high_tung)
		local blocktxt = ""
		if lo then
			if hi == false and hitg == false then
				blocktxt = "下"
			else
				if hitg then
					blocktxt = "上*"
				end
				if hi then
					blocktxt = blocktxt .. "上"
				end
			end
		else
			if hi == false and hitg == false then
				blocktxt = "不"
			else
				if hitg then
					blocktxt = "中*"
				end
				if hi then
					blocktxt = blocktxt .. "中"
				end
			end
		end
		if testbit(blockbit, block_types.air) then
			blocktxt = blocktxt .. "空"
		end
		if air_hit == hit_proc_types.same_line then
			blocktxt = "拾" .. blocktxt
		end
		return blocktxt
	end
	on_frame_func.sway_block_txt = function(blockbit)
		if testbit(blockbit, block_types.sway_pass) then
			return "-"
		end
		local lo = testbit(blockbit, block_types.sway_low)
		local hi = testbit(blockbit, block_types.sway_high)
		local hitg = testbit(blockbit, block_types.sway_high_tung)
		local blocktxt = ""
		if lo then
			if hi == false and hitg == false then
				blocktxt = "下"
			else
				if hitg then
					blocktxt = "上*"
				end
				if hi then
					blocktxt = blocktxt .. "上"
				end
			end
		else
			if hi == false and hitg == false then
				blocktxt = "不"
			else
				if hitg then
					blocktxt = "中*"
				end
				if hi then
					blocktxt = blocktxt .. "中"
				end
			end
		end
		return blocktxt
	end
	local on_frame_event = function(p, fb, event_type, attackbit)
		local func = on_frame_func
		if event_type == frame_event_types.reset then
			local info = frame_infos[p]
			if info then
				func.break_info(info, event_type)
				local text
				local takeoff_and_main = math.min(info.startup, math.min(info.takeoff, info.stay_main))
				local land_and_main = math.min(info.landing, info.return_main)
				if takeoff_and_main == info.startup or takeoff_and_main == 0 then
					text = string.format("%s", info.startup)
				else
					local startup = info.startup - takeoff_and_main
					if #info.actives == 0 and info.recovery == 0 and land_and_main > 0 then
						startup = startup - land_and_main
						text = string.format("%s+%s+%s", takeoff_and_main, startup, land_and_main)
					else
						text = string.format("%s+%s", takeoff_and_main, startup)
					end
				end
				if #info.actives > 0 then
					text = text .. "/"
					local delim = ""
					for _, active in ipairs(info.actives) do
						if nil == active then
							delim = ""
						elseif 0 > active.count then
							-- マイナス値はinactive扱いでカッコで表現
							text = string.format("%s(%s)", text, -active.count)
							delim = ""
						elseif testbit(active.attackbit, frame_attack_types.fake) then
							-- 嘘判定は{}で表現
							text = string.format("%s{%s}", text, active.count)
							delim = ""
						else
							-- 通常の攻撃判定とフルヒットなどの判定無効状態は合わせて表示
							text = string.format("%s%s%s", text, delim, active.count)
							delim = ","
						end
					end
				end
				if info.recovery > 0 then
					land_and_main = math.min(info.recovery, land_and_main)
					if land_and_main == info.recovery or land_and_main == 0 then
						text = string.format("%s/%s", text, info.recovery)
					else
						text = string.format("%s/%s+%s", text, info.recovery - land_and_main, land_and_main)
					end
				end
				text = string.format("%3s|%s", info.total, text)
				local invs = {}
				for k, v in pairs({ ["打"] = info.hurt_inv, ["通"] = info.throw_inv2, ["投"] = info.throw_inv1 }) do
					if v > 0 then
						table.insert(invs, string.format("%s%s", k, v))
					end
				end
				text = string.format("%s|%s", text, #invs > 0 and table.concat(invs, "") or "-")

				if #info.summaries > 0 then
					local max, contexts = #info.summaries, {}
					local build_txt = #info.summaries > 1 and func.build_txt1 or func.build_txt2
					local texts = { text }
					for i, s in ipairs(info.summaries) do
						for j, sv in ipairs(s.attacking ~= true and new_filled_table(7, "-") or {
							s.hitstop_gd,
							func.dmg_txt(s.chip_dmg, s.pure_dmg),
							func.stun_txt(s.pure_st, s.pure_st_tm),
							func.effect_txt(s.effect, s.gd_strength, s.hitstun, s.blockstun),
							func.block_txt(s.air_hit, s.blockbit),
							func.sway_block_txt(s.blockbit),
							s.prj_rank and s.prj_rank or "-",
						}) do
							contexts[j] = build_txt(contexts[j], max, i, sv)
							if max == i then
								table.insert(texts, table.concat(contexts[j].tbl, ","))
							end
						end
					end
					text = table.concat(texts, "|")
					-- 末尾の-を取り除く
					while true do
						local a1, _ = string.find(text, "%|%-x%d+$")
						if a1 == nil then
							a1, _ = string.find(text, "%|%-$")
						end
						if a1 == nil then
							break
						end
						text = string.sub(text, 1, a1 - 1)
					end
				end
				p.last_frame_info_txt = text
			end
			frame_infos[p] = nil
			return
		elseif event_type == frame_event_types.split then
			local info = frame_infos[p]
			if info then
				func.break_info(info, event_type)
			end
			return
		end
		-- ブレイク条件をくっつける
		local break_key = attackbit and p.hit_summary.blockbit and
			string.format("%x %x", attackbit, p.hit_summary.blockbit) or nil
		local summary = fb and fb.hit_summary or p.hit_summary
		local info = frame_infos[p] or {
			last_event = event_type, -- 攻撃かどうか
			count = 0,      -- バッファ
			hurt_inv = 0,   -- 打撃無敵
			has_hurt = false,
			throw_inv1 = 0, -- 投げ無敵
			can_throw1 = false,
			throw_inv2 = 0, -- 投げ無敵
			can_throw2 = false,
			takeoff = 0,    -- 地上バッファ
			jumped = false,
			stay_main = 0,  -- メインラインバッファ
			planed = false,
			landing = 0,    -- 着地硬直バッファ
			return_main = 0, -- メインライン硬直バッファ
			break_key = break_key, -- ブレイク条件
			attackbit = attackbit,
			summary = summary,
			total = 0,
			startup = 0,
			actives = {},
			summaries = {},
			recovery = 0,
		}
		frame_infos[p] = info
		if info.last_event ~= event_type then
			func.break_info(info, event_type)
			info.last_event = event_type
			info.break_key = break_key
			info.attackbit = attackbit
			info.count = 1
		elseif info.break_key ~= break_key then
			if info.last_event == frame_event_types.active then
				table.insert(info.actives, { count = info.count, attackbit = info.attackbit })
				table.insert(info.summaries, info.summary)
			elseif info.last_event == frame_event_types.inactive then
				if #info.actives == 0 then
					info.startup = info.count
					table.insert(info.actives, nil)
				else
					table.insert(info.actives, { count = -info.count, attackbit = info.attackbit })
				end
			end
			info.break_key = break_key
			info.attackbit = attackbit
			info.last_event = event_type
			info.count = 1
		else
			info.count = info.count + 1
		end
		info.total = info.total + 1
		if p.in_air then
			info.jumped = true
			info.landing = 0
		else
			if info.jumped == false then
				info.takeoff = info.takeoff + 1
			else
				info.landing = info.landing + 1
			end
		end
		if p.in_sway_line then
			info.planed = true
			info.return_main = 0
		else
			if info.planed == false then
				info.stay_main = info.stay_main + 1
			end
			info.return_main = info.return_main + 1
		end
		info.summary = summary
		if info.has_hurt == false then
			local has_hurt = true
			for _, inv in ipairs(summary.hurt_inv) do
				if inv == hurt_inv_type.full then -- 全身無敵
					info.hurt_inv = info.hurt_inv + 1
					has_hurt = false
					break
				end
			end
			info.has_hurt = has_hurt
		end
		local throwable = p.sway_status == 0x00 and p.tw_muteki == 0 and p.pos_y == 0
		local n_throwable = p.throwable and p.tw_muteki2 == 0
		if info.can_throw1 == false then
			info.can_throw1 = throwable
			if info.can_throw1 == false then
				info.throw_inv1 = info.throw_inv1 + 1
			end
		end
		if info.can_throw2 == false then
			info.can_throw2 = n_throwable
			if info.can_throw2 == false then
				info.throw_inv2 = info.throw_inv2 + 1
			end
		end
	end
	local proc_nonact_frame = function(p)
		if p.skip_frame then
			-- なにもしない
		else
			on_frame_event(p, nil, frame_event_types.reset)
		end
	end
	local proc_act_frame = function(p)
		local op = p.op

		-- 飛び道具
		local chg_fireball_state, chg_prefireball_state, active_fb = false, false, nil
		local attackbit = 0
		for _, fb in pairs(p.fireball) do
			if fb.has_atk_box == true then
				if fb.atk_count == 1 and fb.act_data_fired.name == p.act_data.name then
					chg_fireball_state = true
				end
				attackbit = frame_attack_types.attacking
				if fb.fake_hit == true then
					attackbit = attackbit | frame_attack_types.fake
				elseif fb.obsl_hit == true or fb.full_hit == true or fb.harmless2 == true then
					attackbit = attackbit | frame_attack_types.harmless
				end
				if fb.juggling then
					attackbit = attackbit | frame_attack_types.juggling
				end
				--[[ 飛び道具は判定の遷移ごとに細分化しない
				if fb.max_hit_dn > 1 or fb.max_hit_dn == 0 then
					attackbit = attackbit | fb.act * frame_attack_types.x17 | fb.act_count * frame_attack_types.x09
				end ]]
				attackbit = attackbit | (p.attack * frame_attack_types.x05)
				active_fb = fb
				break
			end
		end
		if chg_fireball_state ~= true then
			for _, fb in pairs(p.fireball) do
				if fb.proc_active == true and fb.alive ~= true then
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

		--ガード移行できない行動は色替えする
		local col, line = 0xAAF0E68C, 0xDDF0E68C
		local multi = p.act * frame_attack_types.x17
		if p.max_hit_dn > 1 or p.max_hit_dn == 0 then
			multi = multi | p.act_count * frame_attack_types.x09
		end
		if p.skip_frame then
			col, line = 0xAA888888, 0xDD888888
		elseif p.attacking then
			attackbit = frame_attack_types.attacking
			if p.juggling then
				attackbit = attackbit | frame_attack_types.juggling
				col, line = 0xAAFF4500, 0xDDFF4500
			else
				col, line = 0xAAFF00FF, 0xDDFF00FF
			end
			attackbit = attackbit | multi
		elseif p.dmmy_attacking then
			attackbit = attackbit | frame_attack_types.attacking
			attackbit = attackbit | frame_attack_types.harmless
			if p.juggling then
				attackbit = attackbit | frame_attack_types.juggling
				col, line = 0x00000000, 0xDDFF4500
			else
				col, line = 0x00000000, 0xDDFF00FF
			end
			attackbit = attackbit | multi
		elseif p.throwing then
			attackbit = frame_attack_types.attacking
			col, line = 0xAAD2691E, 0xDDD2691E
		elseif p.act_1st ~= true and p.old_repeatable == true and (p.repeatable == true or p.act_frame > 0) then
			-- 1F前の状態とあわせて判定する
			col, line = 0xAAD2691E, 0xDDD2691E
		elseif p.can_juggle or p.can_otg then
			if op.act_normal ~= true then
				col, line = 0x99CCA500, 0x99CCA500
			else
				col, line = 0xAAFFA500, 0xDDFFA500
			end
		elseif p.act_normal then
			col, line = 0x44FFFFFF, 0xDDFFFFFF
		end

		-- 3 "ON:判定の形毎", 4 "ON:攻撃判定の形毎", 5 "ON:くらい判定の形毎",
		local reach_memo = ""
		if p.disp_frm == 3 then
			reach_memo = p.hitbox_txt .. "&" .. p.hurtbox_txt
		elseif p.disp_frm == 4 then
			reach_memo = p.hitbox_txt
		elseif p.disp_frm == 5 then
			reach_memo = p.hurtbox_txt
		end

		local act_count  = p.act_count or 0
		local max_hit_dn = p.attacking and p.hit.max_hit_dn or 0

		-- 行動が変わったかのフラグ
		local frame      = p.act_frames[#p.act_frames]
		local concrete_name, chg_act_name, disp_name
		if frame ~= nil then
			if p.act_data.names then
				chg_act_name = true
				for _, name in pairs(p.act_data.names) do
					if frame.name == name then
						chg_act_name = false
						concrete_name = frame.name
						disp_name = frame.disp_name
						--p.act_1st = false
					end
				end
				if chg_act_name then
					concrete_name = p.act_data.name or p.act_data.names[1]
					disp_name = convert(p.act_data.disp_name or concrete_name)
				end
			elseif frame.name ~= p.act_data.name then
				concrete_name = p.act_data.name
				disp_name = convert(p.act_data.disp_name or concrete_name)
				chg_act_name = true
			else
				concrete_name = frame.name
				disp_name = frame.disp_name
				chg_act_name = false
			end
		else
			concrete_name = p.act_data.name
			disp_name = convert(p.act_data.disp_name or concrete_name)
			chg_act_name = true
		end
		local is_change_any = function(expecteds, old, current)
			for _, expected in ipairs(expecteds) do
				if old ~= expected and current == expected then
					return true
				end
			end
			return false
		end
		if chg_act_name ~= true then
			-- ダッシュの加速、減速、最終モーション
			-- スウェーのダッシュの区切り
			chg_act_name = is_change_any({ 0x18, 0x19, 0x32, 0x34, 0x35, 0x80 }, p.old_act, p.act)
			chg_act_name = chg_act_name or (p.act == 0x19 and p.base == fix_bp_addr(0x26152))
		end
		if chg_act_name ~= true then
			-- スウェーの切り替え
			chg_act_name = is_change_any({ 0x00, 0x80, 0x32, 0x34, 0x35, 0x80 }, p.old_sway_status, p.sway_status)
		end
		local chg_any_state = #p.act_frames == 0 or	p.chg_air_state ~= 0 or p.act_1st
		chg_any_state = chg_any_state or (frame and frame.col ~= col) or false
		chg_any_state = chg_any_state or (frame and frame.reach_memo ~= reach_memo) or false
		chg_any_state = chg_any_state or (max_hit_dn > 1) and (frame and (frame.act_count ~= act_count) or false)
		if chg_act_name or
			chg_fireball_state or
			chg_prefireball_state or
			chg_any_state then
			--行動IDの更新があった場合にフレーム情報追加
			frame = {
				act = p.act,
				count = 1,
				col = col,
				name = concrete_name,
				disp_name = disp_name,
				line = line,
				chg_fireball_state = chg_fireball_state,
				chg_prefireball_state = chg_prefireball_state,
				chg_air_state = p.chg_air_state,
				act_1st = p.act_1st,
				reach_memo = reach_memo,
				act_count = act_count,
				max_hit_dn = max_hit_dn,
			}
			table.insert(p.act_frames, frame)
			if 180 < #p.act_frames then
				--バッファ長調整
				table.remove(p.act_frames, 1)
			end
		else
			--同一行動IDが継続している場合はフレーム値加算
			if frame then
				frame.count = frame.count + 1
			end
		end
		-- 技名でグループ化したフレームデータの配列をマージ生成する
		p.act_frames2 = frame_groups(frame, p.act_frames2 or {})
		-- 表示可能範囲（最大で横画面幅）以上は加算しない
		p.act_frames_total = (332 < p.act_frames_total) and 332 or (p.act_frames_total + 1)

		if p.skip_frame then
			-- なにもしない
		elseif (p.flag_d0 & 0x2200000 > 0) or p.act_normal then
			-- やられと通常状態
			on_frame_event(p, active_fb, frame_event_types.reset)
		else
			if p.act_1st then
				on_frame_event(p, active_fb, frame_event_types.reset)
			end
			if p.attacking or p.dmmy_attacking or p.throwing or attackbit > 0 then
				on_frame_event(p, active_fb, frame_event_types.active, attackbit)
			else
				on_frame_event(p, active_fb, frame_event_types.inactive, attackbit)
			end
		end
		-- 後の処理用に最終フレームを保持
		return frame, chg_act_name
	end

	local proc_muteki_frame = function(p, chg_act_name)
		local last_frame = p.act_frames[#p.act_frames]

		-- 無敵表示
		local col, line = 0x00000000, 0x00000000
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
		--printf("top %s, hi %s, lo %s", screen_top, vul_hi, vul_lo)

		local frame = p.muteki.act_frames[#p.muteki.act_frames]
		if frame == nil or chg_act_name or frame.col ~= col or p.state ~= p.old_state or p.act_1st then
			--行動IDの更新があった場合にフレーム情報追加
			frame = {
				act = p.act,
				count = 1,
				col = col,
				name = last_frame.name,
				disp_name = last_frame.disp_name,
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
				disp_name = last_frame.disp_name,
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

	local proc_fb_frame = function(p)
		local last_frame = p.act_frames[#p.act_frames]
		local fb_upd_groups = {}

		-- 飛び道具2
		for fb_base, fb in pairs(p.fireball) do
			local frame = fb.act_frames[#fb.act_frames]
			local reset, new_name = false, fb.act_data_fired.name
			if p.act_data.firing then
				if p.act_1st then
					reset = true
				elseif not frame or frame.name ~= fb.act_data_fired.name then
					reset = true
				end
			elseif fb.act == 0 and (not frame or frame.name ~= "") then
				reset = true
				new_name = ""
			end
			local col, line, act
			if p.skip_frame then
				col, line, act = 0x00000000, 0x00000000, 0
			elseif fb.has_atk_box == true then
				if fb.fake_hit == true then
					col, line, act = 0xAA00FF33, 0xDD00FF33, 2
				elseif fb.obsl_hit == true or fb.full_hit == true or fb.harmless2 == true then
					if fb.juggling then
						col, line, act = 0x00000000, 0xDDFF4500, 1
					else
						col, line, act = 0x00000000, 0xDDFF1493, 0
					end
				else
					if fb.juggling then
						col, line, act = 0xAAFF4500, 0xDDFF4500, 1
					else
						col, line, act = 0xAAFF00FF, 0xDDFF00FF, 1
					end
				end
			else
				col, line, act = 0x00000000, 0x00000000, 0
			end

			-- 3 "ON:判定の形毎", 4 "ON:攻撃判定の形毎", 5 "ON:くらい判定の形毎",
			local reach_memo = ""
			if fb.disp_frm == 3 then
				reach_memo = fb.hitbox_txt .. "&" .. fb.hurtbox_txt
			elseif p.disp_frm == 4 then
				reach_memo = fb.hitbox_txt
			elseif p.disp_frm == 5 then
				reach_memo = fb.hurtbox_txt
			end
			local act_count  = fb.actb
			local max_hit_dn = fb.hit.max_hit_dn

			if #fb.act_frames == 0 or (frame == nil) or frame.col ~= col or reset or frame.reach_memo ~= reach_memo or (max_hit_dn > 1 and frame.act_count ~= act_count) then
				-- 軽量化のため攻撃の有無だけで記録を残す
				frame = {
					act        = act,
					count      = 1,
					col        = col,
					name       = new_name,
					line       = line,
					act_1st    = reset,
					reach_memo = reach_memo,
					act_count  = act_count,
					max_hit_dn = max_hit_dn,
				}
				-- 関数の使いまわすためact_framesは配列にするが明細を表示ないので1個しかもたなくていい
				fb.act_frames[1] = frame
			else
				-- 同一行動IDが継続している場合はフレーム値加算
				frame.count = frame.count + 1
			end
			-- 技名でグループ化したフレームデータの配列をマージ生成する
			fb.act_frames2, fb_upd_groups[fb_base] = frame_groups(frame, fb.act_frames2 or {})
		end

		-- メインフレーム表示からの描画開始位置を記憶させる
		for fb_base, fb_upd_group in pairs(fb_upd_groups) do
			if fb_upd_group and last_frame then
				last_frame.fireball = last_frame.fireball or {}
				last_frame.fireball[fb_base] = last_frame.fireball[fb_upd_group] or {}
				local last_fb_frame = last_frame.fireball[fb_base]
				table.insert(last_fb_frame, p.fireball[fb_base].act_frames2[# p.fireball[fb_base].act_frames2])
				last_fb_frame[#last_fb_frame].parent_count = last_frame.last_total
			end
		end
	end

	-- トレモのメイン処理
	menu.tra_main.proc = function()
		-- 画面表示
		if global.no_background or global.disp_gauge == false then
			if pgm:read_u8(0x107BB9) == 0x01 or pgm:read_u8(0x107BB9) == 0x0F then
				local match = pgm:read_u8(0x107C22)
				if match == 0x38 then --HUD
					pgm:write_u8(0x107C22, 0x33)
				end
				if match ~= 0 then --BG layers
					if global.no_background then
						pgm:write_u8(0x107762, 0x00)
					end
					pgm:write_u8(0x107765, 0x01)
				end
			end
			if global.no_background then
				--pgm:write_u16(0x401FFE, 0x8F8F)
				pgm:write_u16(0x401FFE, 0x5ABB)
				pgm:write_u8(global.no_background_addr, 0xFF)
			end
		else
			pgm:write_u8(global.no_background_addr, 0x00)
		end

		-- 強制位置補正
		local p1, p2 = players[1], players[2]
		global.fix_pos = false
		if p1.fix_scr_top == 0xFF then
			pgm:write_u8(p1.addr.fix_scr_top, 0xFF)
		else
			pgm:write_i8(p1.addr.fix_scr_top, p1.fix_scr_top - 1)
			global.fix_pos = true
		end
		if p2.fix_scr_top == 0xFF then
			pgm:write_u8(p2.addr.fix_scr_top, 0xFF)
		else
			pgm:write_i8(p2.addr.fix_scr_top, p2.fix_scr_top - 92)
			global.fix_pos = true
		end

		local cond = "maincpu.pw@107C22>0"
		local pc = "PC=$4112;g"

		for i, p in ipairs(players) do
			if p.disp_char_bps then
				global.set_bps(p.disp_char, p.disp_char_bps)
			elseif p.disp_char == false then
				p.disp_char_bps = global.new_hook_holder()
				local bps = p.disp_char_bps.bps
				local cond3 = cond .. "&&(A3)==$100400"
				if i == 1 then
					-- bp 40AE,{(A4)==100400||(A4)==100600||(A4)==100800||(A4)==100A00},{PC=4112;g} -- 2Pだけ消す
					cond3 = cond3 .. "&&((A4)==$100400||(A4)==$100600||(A4)==$100800||(A4)==$100A00)"
				else
					-- bp 40AE,{(A4)==100500||(A4)==100700||(A4)==100900||(A4)==100B00},{PC=4112;g} -- 1Pだけ消す
					cond3 = cond3 .. "&&((A4)==$100500||(A4)==$100700||(A4)==$100900||(A4)==$100B00)"
				end
				global.bp(bps, 0x0040AE, cond3, pc)
			end
		end

		if global.disp_effect_bps then
			global.set_bps(global.disp_effect, global.disp_effect_bps)
		elseif global.disp_effect == false then
			global.disp_effect_bps = global.new_hook_holder()
			local bps = global.disp_effect_bps.bps
			--pc = "printf \"A3=%X A4=%X PREF=%X\",A3,A4,PREF_ADDR;PC=$4112;g"
			global.bp(bps, 0x03BCC2, cond, "PC=$3BCC8;g")
			-- ファイヤーキックの砂煙だけ抑止する
			local cond2 = cond .. "&&maincpu.pw@((A3)+$10)==$1&&maincpu.pw@((A3)+$60)==$B8"
			global.bp(bps, 0x03BB1E, cond2, "PC=$3BC00;g")
			global.bp(bps, 0x0357B0, cond, "PC=$35756;g")
			global.bp(bps, 0x015A82, cond, pc)    -- rts 015A88
			global.bp(bps, 0x015AAC, cond, pc)    -- rts 015AB2
			global.bp(bps, 0x015AD8, cond, pc)    -- rts 015ADE
			global.bp(bps, 0x0173B2, cond, pc)    -- rts 0173B8 影
			global.bp(bps, 0x017750, cond, pc)    -- rts 017756
			global.bp(bps, 0x02559E, cond, pc)    -- rts 0255FA
			global.bp(bps, 0x0256FA, cond, pc)    -- rts 025700
			global.bp(bps, 0x036172, cond, pc)    -- rts 036178
			global.bp(bps, 0x03577C, cond2, pc)   -- rts 035782 技エフェクト
			global.bp(bps, 0x03BB60, cond2, pc)   -- rts 03BB66 技エフェクト
			global.bp(bps, 0x060BDA, cond, pc)    -- rts 060BE0 ヒットマーク
			global.bp(bps, 0x060F2C, cond, pc)    -- rts 060F32 ヒットマーク
			global.bp(bps, 0x061150, cond, "PC=$061156;g") -- rts 061156 ヒットマーク、パワーウェイブの一部
			global.bp(bps, 0x0610E0, cond, pc)    -- rts 0610E6

			-- コンボ表示抑制＝ヒット数を2以上にしない
			-- bp 0252E8,1,{D7=0;PC=0252EA;g}
			global.bp(bps, 0x0252E8, "1", "D7=0;PC=0252EA;g")
			-- bp 039782,1,{PC=039788;g} -- BS表示でない
			global.bp(bps, 0x039782, "1", "PC=039788;g")
			-- bp 03C604,1,{PC=03C60A;g} -- 潜在表示でない
			global.bp(bps, 0x03C604, "1", "PC=03C60A;g")
			-- bp 039850,1,{PC=039856;g} -- リバサ表示でない
			global.bp(bps, 0x039850, "1", "PC=039856;g")
			-- いろんな割り込み文字が出ない、開幕にONにしておくと進まない
			-- bp 2378,1,{PC=2376;g}
			-- global.bp(bps, 0x002378, "1", "PC=002376;g")
		end

		if global.fix_pos_bps then
			global.set_bps(global.fix_pos ~= true, global.fix_pos_bps)
		elseif global.fix_pos then
			global.fix_pos_bps = global.new_hook_holder()
			-- bp 0040AE,1,{PC=$4112;g} -- 描画全部無視
			local bps = global.fix_pos_bps.bps
			-- 画面表示高さを1Pか2Pの高いほうにあわせる
			-- bp 013B6E,1,{D0=((maincpu.pw@100428)-(D0)+4);g}
			-- bp 013B6E,1,{D0=((maincpu.pw@100428)-(D0)-24);g}
			-- bp 013BBA,1,{D0=(maincpu.pw@100428);g}
			-- bp 013AF0,1,{PC=13B28;g} -- 潜在演出無視
			-- bp 013AF0,1,{PC=13B76;g} -- 潜在演出強制（上に制限が付く）
			global.bp(bps, 0x013B6E, cond .. "&&(maincpu.pb@10DE5C)!=0xFF", "D0=((maincpu.pw@100428)-(maincpu.pb@10DE5C)+#40);g")
			global.bp(bps, 0x013B6E, cond .. "&&(maincpu.pb@10DE5D)!=0xFF", "D0=((maincpu.pw@100428)-(maincpu.pb@10DE5D)+#40);g")
			global.bp(bps, 0x013BBA, cond .. "&&(maincpu.pb@10DE5C)!=0xFF", "D0=((maincpu.pw@100428)-(maincpu.pb@10DE5C)+#40);g")
			global.bp(bps, 0x013BBA, cond .. "&&(maincpu.pb@10DE5D)!=0xFF", "D0=((maincpu.pw@100428)-(maincpu.pb@10DE5D)+#40);g")
			global.bp(bps, 0x013AF0, cond, "PC=$13B28;g")
		end

		-- メイン処理
		if not match_active then
			return
		end
		-- ポーズ中は状態を更新しない
		if mem._0x10E043 ~= 0 then
			return
		end

		if menu.reset_pos then
			menu.update_pos()
		end

		local next_joy = new_next_joy()

		local ec = scr:frame_number()
		local state_past = ec - global.input_accepted
		local height = scr.height * scr.yscale
		local width = scr.width * scr.xscale
		local joy_val = get_joy()

		global.frame_number = global.frame_number + 1

		-- ポーズ解除状態
		set_freeze((not match_active) or true)

		-- スタートボタン（リプレイモード中のみスタートボタンおしっぱでメニュー表示へ切り替え
		if (global.dummy_mode == 6 and is_start_a(joy_val, state_past)) or
			(global.dummy_mode ~= 6 and accept_input("Start", joy_val, state_past)) then
			-- メニュー表示状態へ切り替え
			global.input_accepted = ec
			menu.state = menu
			cls_joy()
			return
		end

		screen.left     = pgm:read_i16(mem.stage_base_addr + screen.offset_x) + (320 - width) / 2 --FBA removes the side margins for some games
		screen.top      = pgm:read_i16(mem.stage_base_addr + screen.offset_y)

		-- プレイヤーと飛び道具のベースアドレスをキー、オブジェクトを値にするバッファ
		local temp_hits = {}

		-- ラグ発生時は処理をしないで戻る
		if global.lag_frame == true then
			return
		end

		-- 1Pと2Pの状態読取
		for i, p in ipairs(players) do
			local op          = players[3 - i]
			p.op              = op
			p.base            = pgm:read_u32(p.addr.base)
			p.char            = pgm:read_u8(p.addr.char)
			p.char_data       = chars[p.char]
			p.char_4times     = 0xFFFF & (p.char + p.char)
			p.char_4times     = 0xFFFF & (p.char_4times + p.char_4times)
			p.char_8times     = 0xFFFF & (p.char << 3)
			p.close_far       = get_close_far_pos(p.char)
			p.close_far_lma   = get_close_far_pos_line_move_attack(p.char)
			p.life            = pgm:read_u8(p.addr.life) -- 今の体力
			p.old_state       = p.state          -- 前フレームの状態保存
			p.state           = pgm:read_u8(p.addr.state) -- 今の状態
			p.old_flag_c0     = p.flag_c0
			p.old_flag_cc     = p.flag_cc
			p.old_flag_d0     = p.flag_d0
			p.flag_c0         = pgm:read_u32(p.addr.flag_c0)
			p.flag_c4         = pgm:read_u32(p.addr.flag_c4)
			p.flag_c8         = pgm:read_u32(p.addr.flag_c8)
			p.flag_cc         = pgm:read_u32(p.addr.flag_cc)
			p.flag_d0         = pgm:read_u8(p.addr.flag_d0)
			p.box_base1       = pgm:read_u32(p.addr.box_base1)
			p.box_base2       = pgm:read_u32(p.addr.box_base2)
			p.old_kaiser_wave = p.kaiser_wave          -- 前フレームのカイザーウェイブのレベル
			p.kaiser_wave     = pgm:read_u8(p.addr.kaiser_wave) -- カイザーウェイブのレベル
			p.hurt_state      = pgm:read_u8(p.addr.hurt_state)
			p.slide_atk       = testbit(p.flag_cc, 0x4) -- ダッシュ滑り攻撃
			-- ブレイクショット
			if testbit(p.flag_cc, 0x200000) == true and
				(testbit(p.old_flag_cc, 0x100000) == true or p.bs_atk == true) then
				p.bs_atk = true
			else
				p.bs_atk = false
			end
			--[[
				       1 CA技
				       2 小技
					   4 ダッシュ専用攻撃 滑り攻撃
					  20 空中ガード
				      40 斜め後ろ
				      80 後ろ
				     100 投げ派生
				     200 つかまれ
				     400 なげられ
				    2000 ダウンまで
				    6000 吹き飛びダウン
				    8000 やられ
				   80000 挑発
				  100000 ブレイクショット
				  200000 必殺技
				  800000 ダウン
				 1000000 フェイント技
				 2000000 つかみ技
				40000000 空中投げ
				80000000 投げ技
			]]
			p.attack_flag     = testbit(p.flag_cc,
				2 ^ 31 | --		"CA",
				2 ^ 30  | --"AかB攻撃",
				2 ^ 11  | --"ブレイクショット",
				2 ^ 10  | --"必殺技中",
				2 ^ 6  | --"つかみ技",
				2 ^ 4  | --"投げ追撃",
				2 ^ 1  | --"空中投げ",
				2 ^ 0 --"投げ",
			) or (p.flag_c8 > 0) or (p.flag_c4 > 0)
			p.state_bits      = tobits(p.flag_c0)
			p.old_blkstn_bits = p.blkstn_bits
			p.blkstn_bits     = tobits(p.flag_d0)
			p.pos_miny        = 0
			if testbit(p.flag_c4, 0x1FF00) then
				p.pos_miny = p.char_data.min_y
			elseif testbit(p.flag_c4, 0x7FC0000) then
				p.pos_miny = p.char_data.min_sy
			end
			p.last_normal_state = p.normal_state
			p.normal_state      = p.state == 0                    -- 素立ち
			p.combo             = tohexnum(pgm:read_u8(p.addr.combo2)) -- 最近のコンボ数
			p.tmp_combo         = tohexnum(pgm:read_u8(p.addr.tmp_combo2)) -- 一次的なコンボ数
			p.max_combo         = tohexnum(pgm:read_u8(p.addr.max_combo2)) -- 最大コンボ数
			p.tmp_dmg           = pgm:read_u8(p.addr.tmp_dmg)     -- ダメージ
			p.old_attack        = p.attack
			p.attack            = pgm:read_u8(p.addr.attack)
			p.dmg_id            = pgm:read_u8(p.addr.dmg_id) -- 最後にヒット/ガードした技ID
			-- キャンセル可否家庭用2AD90からの処理の断片
			if p.attack < 0x70 then
				p.cancelable = pgm:read_u8(pgm:read_u32(p.char_4times + 0x850D8) + p.attack)
			else
				p.cancelable = pgm:read_u8(p.addr.cancelable)
			end
			p.old_repeatable = p.repeatable
			p.repeatable     = (p.cancelable & 0xD0 == 0xD0) and (pgm:read_u8(p.addr.repeatable) & 0x4 == 0x4)
			p.pure_dmg       = pgm:read_u8(p.addr.pure_dmg) -- ダメージ(フック処理)
			p.chip_dmg_type  = chip_dmg_types.zero
			p.tmp_pow        = pgm:read_u8(p.addr.tmp_pow) -- POWゲージ増加量
			p.tmp_pow_rsv    = pgm:read_u8(p.addr.tmp_pow_rsv) -- POWゲージ増加量(予約値)
			if p.tmp_pow_rsv > 0 then
				p.tmp_pow_atc = p.attack              -- POWゲージ増加量(予約時の行動)
			end

			p.tmp_stun     = pgm:read_u8(p.addr.tmp_stun) -- 気絶値
			p.tmp_st_timer = pgm:read_u8(p.addr.tmp_st_timer) -- 気絶タイマー
			pgm:write_u8(p.addr.tmp_dmg, 0)
			pgm:write_u8(p.addr.pure_dmg, 0)
			pgm:write_u8(p.addr.tmp_pow, 0)
			pgm:write_u8(p.addr.tmp_pow_rsv, 0)
			pgm:write_u8(p.addr.tmp_stun, 0)
			pgm:write_u8(p.addr.tmp_st_timer, 0)
			p.tw_threshold   = pgm:read_u8(p.addr.tw_threshold)
			p.tw_accepted    = pgm:read_u8(p.addr.tw_accepted)
			p.tw_frame       = pgm:read_u8(p.addr.tw_frame)
			p.old_tw_muteki  = p.tw_muteki or 0
			p.tw_muteki      = pgm:read_u8(p.addr.tw_muteki)
			-- 通常投げ無敵判断 その2(HOME 039FC6から03A000の処理を再現して投げ無敵の値を求める)
			p.old_tw_muteki2 = p.tw_muteki2 or 0
			p.tw_muteki2     = 0
			if 0x70 <= p.attack then
				p.tw_muteki2 = pgm:read_u8(pgm:read_u32(p.char_4times + 0x89692) + p.attack - 0x70)
			end
			p.throwable       = p.state == 0 and op.state == 0 and p.tw_frame > 24 and p.sway_status == 0x00 and p.tw_muteki == 0 -- 投げ可能ベース
			p.n_throwable     = p.throwable and p.tw_muteki2 == 0                                                        -- 通常投げ可能
			p.sp_throw_id     = pgm:read_u8(p.addr.sp_throw_id)                                                          -- 投げ必殺のID
			p.sp_throw_act    = pgm:read_u8(p.addr.sp_throw_act)                                                         -- 投げ必殺の持続残F
			p.additional      = pgm:read_u8(p.addr.additional)

			p.old_act         = p.act or 0x00
			p.act             = pgm:read_u16(p.addr.act)
			p.acta            = pgm:read_u16(p.addr.acta)
			p.old_act_count   = p.act_count
			p.act_count       = pgm:read_u8(p.addr.act_count)
			-- 家庭用004A6Aからの処理
			p.act_boxtype     = 0xFFFF & (pgm:read_u8(p.addr.act_boxtype) & 0xC0 * 4)
			p.old_act_frame   = p.act_frame
			p.act_frame       = pgm:read_u8(p.addr.act_frame)
			p.provoke         = 0x0196 == p.act --挑発中
			p.stop            = pgm:read_u8(p.addr.stop)
			p.gd_strength     = get_gd_strength(p)
			p.old_knock_back1 = p.knock_back1
			p.old_knock_back2 = p.knock_back2
			p.old_knock_back3 = p.knock_back3
			p.knock_back1     = pgm:read_u8(p.addr.knock_back1)
			p.knock_back2     = pgm:read_u8(p.addr.knock_back2)
			p.knock_back3     = pgm:read_u8(p.addr.knock_back3)
			p.hitstop_id      = pgm:read_u8(p.addr.hitstop_id)
			p.attack_id       = 0
			p.old_attacking   = p.attacking
			p.attacking       = false
			p.dmmy_attacking  = false
			p.juggling        = false
			p.can_juggle      = false
			p.can_otg         = false
			p.old_throwing    = p.throwing
			p.throwing        = false
			p.can_techrise    = 2 > pgm:read_u8(0x88A12 + p.attack)
			p.pow_up_hit      = 0
			p.pow_up_gd       = 0
			p.pow_up          = 0
			p.pow_revenge     = 0
			p.pow_absorb      = 0
			p.esaka_range     = 0
			p.hitstop         = 0
			p.hitstop_gd      = 0
			p.pure_dmg        = 0
			p.pure_st         = 0
			p.pure_st_tm      = 0
			p.chip_dmg_type   = chip_dmg_types.zero
			p.fake_hit        = (pgm:read_u8(p.addr.fake_hit) & 0xB) == 0
			p.obsl_hit        = (pgm:read_u8(p.addr.obsl_hit) & 0xB) == 0
			p.full_hit        = pgm:read_u8(p.addr.full_hit) > 0
			p.harmless2       = pgm:read_u8(p.addr.attack) == 0
			p.prj_rank        = pgm:read_u8(p.addr.prj_rank)
			p.old_posd        = p.posd
			p.posd            = pgm:read_i32(p.addr.pos)
			p.poslr           = p.posd == op.posd and "=" or p.posd < op.posd and "L" or "R"
			p.old_pos         = p.pos
			p.old_pos_frc     = p.pos_frc
			p.pos             = pgm:read_i16(p.addr.pos)
			p.pos_frc         = pgm:read_u16(p.addr.pos_frc)
			p.thrust          = pgm:read_i16(p.addr.base + 0x34) + int16tofloat(pgm:read_u16(p.addr.base + 0x36))
			p.inertia         = pgm:read_i16(p.addr.base + 0xDA) + int16tofloat(pgm:read_u16(p.addr.base + 0xDC))
			p.pos_total       = p.pos + int16tofloat(p.pos_frc)
			p.old_pos_total   = p.old_pos + int16tofloat(p.old_pos_frc)
			p.diff_pos_total  = p.pos_total - p.old_pos_total
			p.max_pos         = pgm:read_i16(p.addr.max_pos)
			if p.max_pos == 0 or p.max_pos == p.pos then
				p.max_pos = nil
			end
			pgm:write_i16(p.addr.max_pos, 0)
			p.min_pos = pgm:read_i16(p.addr.min_pos)
			if p.min_pos == 1000 or p.min_pos == p.pos then
				p.min_pos = nil
			end
			pgm:write_i16(p.addr.min_pos, 1000)
			p.proc_pos      = p.max_pos or p.min_pos or p.pos -- 内部の補正前のX座標
			p.old_pos_y     = p.pos_y
			p.old_pos_frc_y = p.pos_frc_y
			p.old_in_air    = p.in_air
			p.pos_y         = pgm:read_i16(p.addr.pos_y)
			p.pos_frc_y     = int16tofloat(pgm:read_u16(p.addr.pos_frc_y))
			p.in_air        = 0 < p.pos_y or 0 < p.pos_frc_y

			-- ジャンプの遷移ポイントかどうか
			if p.old_in_air ~= true and p.in_air == true then
				p.chg_air_state = 1
			elseif p.old_in_air == true and p.in_air ~= true then
				p.chg_air_state = -1
			else
				p.chg_air_state = 0
			end
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
			p.old_pos_z       = p.pos_z
			p.pos_z           = pgm:read_i16(p.addr.pos_z)
			p.on_sway_line    = (40 == p.pos_z and 40 > p.old_pos_z) and global.frame_number or p.on_sway_line
			p.on_main_line    = (24 == p.pos_z and 24 < p.old_pos_z) and global.frame_number or p.on_main_line
			p.old_sway_status = p.sway_status
			p.sway_status     = pgm:read_u8(p.addr.sway_status) -- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
			if p.sway_status == 0x00 then
				p.in_sway_line = false
			else
				p.in_sway_line = true
			end
			p.internal_side = pgm:read_u8(p.addr.side)
			p.side          = pgm:read_i8(p.addr.side) < 0 and -1 or 1
			p.corner        = pgm:read_u8(p.addr.corner)               -- 画面端状態 0:端以外 1:画面端 3:端押し付け
			p.input_side    = pgm:read_u8(p.addr.input_side)           -- コマンド入力でのキャラ向きチェック用 00:左側 80:右側
			p.disp_side     = get_flip_x(players[1])
			p.push_front    = get_push_range(p, 0x3)                   -- 正面
			p.push_back     = get_push_range(p, 0x4)                   -- 背後
			p.tw_half_range = pgm:read_u8(fix_bp_addr(0x5D854) + p.char_4times) -- 投げ間合い半数
			p.input1        = pgm:read_u8(p.addr.input1)
			p.input2        = pgm:read_u8(p.addr.input2)
			p.cln_btn       = pgm:read_u8(p.addr.cln_btn)
			-- 滑り属性の攻撃か慣性残しの立ち攻撃か
			if p.slide_atk == true or (p.old_act == 0x19 and p.inertia > 0 and testbit(p.flag_c0, 0x32)) then
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

			p.life        = pgm:read_u8(p.addr.life)
			p.pow         = pgm:read_u8(p.addr.pow)
			p.init_stun   = p.char_data.init_stuns
			p.max_stun    = pgm:read_u8(p.addr.max_stun)
			p.stun        = pgm:read_u8(p.addr.stun)
			p.stun_timer  = pgm:read_u16(p.addr.stun_timer)
			p.act_contact = pgm:read_u8(p.addr.act_contact)
			p.ophit_base  = pgm:read_u32(p.addr.ophit_base)
			p.ophit       = nil
			if p.ophit_base == 0x100400 or p.ophit_base == 0x100500 then
				p.ophit = op
			else
				p.ophit = op.fireball[p.ophit_base]
			end

			-- ライン送らない状態のデータ書き込み
			if p.dis_plain_shift then
				pgm:write_u8(p.addr.hurt_state, p.hurt_state | 0x40)
			end
		end

		-- 1Pと2Pの状態読取 ゲージ
		for _, p in ipairs(players) do
			local op         = p.op

			local hit_attack = p.attack

			if hit_attack ~= 0 and op.hitstop_id ~= 0 and op.flag_c0 > 0 and op.flag_cc > 0 then
				hit_attack = op.hitstop_id
			end

			if hit_attack ~= 0 then
				p.hitstop    = 0x7F & pgm:read_u8(pgm:read_u32(fix_bp_addr(0x83C38) + p.char_4times) + hit_attack)
				p.hitstop    = p.hitstop == 0 and 2 or p.hitstop + 1 -- システムで消費される分を加算
				p.hitstop_gd = math.max(2, p.hitstop - 1) -- ガード時の補正

				-- 補正前ダメージ量取得 家庭用 05B118 からの処理
				p.pure_dmg   = pgm:read_u8(pgm:read_u32(p.char_4times + fix_bp_addr(0x813F0)) + hit_attack)
				-- 気絶値と気絶タイマー取得 05C1CA からの処理
				p.pure_st    = pgm:read_u8(pgm:read_u32(p.char_4times + fix_bp_addr(0x85CCA)) + hit_attack)
				p.pure_st_tm = pgm:read_u8(pgm:read_u32(p.char_4times + fix_bp_addr(0x85D2A)) + hit_attack)

				if 0x58 > hit_attack then
					-- 家庭用 0236F0 からの処理
					local d1 = pgm:read_u8(p.addr.attack)
					local d0 = pgm:read_u16(pgm:read_u32(p.char_4times + 0x23750) + ((d1 + d1) & 0xFFFF)) & 0x1FFF
					if d0 ~= 0 then
						p.esaka_range = d0
					end

					-- 家庭用 05B37E からの処理
					if 0x27 <= hit_attack then -- CA技、特殊技かどうかのチェック
						p.pow_up_hit = pgm:read_u8((0xFF & (hit_attack - 0x27)) + pgm:read_u32(0x8C18C + p.char_4times))
					else        -- 通常技 ビリーとチョンシュか、それ以外でアドレスが違う
						local a0 = (0xC ~= p.char and 0x10 ~= p.char) and 0x8C24C or 0x8C274
						p.pow_up_hit = pgm:read_u8(a0 + hit_attack)
					end
					-- ガード時増加量 d0の右1ビットシフト=1/2
					p.pow_up_gd = 0xFF & (p.pow_up_hit >> 1)
				end

				-- 必殺技のパワー増加 家庭用 03C140 からの処理
				-- 03BEF6: 4A2C 00BF                tst.b   ($bf,A4) beqのときのみ
				-- 03BF00: 082C 0004 00CD           btst    #$4, ($cd,A4) beqのときのみ
				-- base+A3の値は技発動時の処理中にしか採取できないのでこの処理は機能しない
				-- local d0, a0 = pgm:read_u8(p.addr.base + 0xA3), 0
				local spid = ((pgm:read_u8(p.addr.base + 0xCD) & 0x20) == 0x20) and pgm:read_u8(p.addr.base + 0xB8) or 0 -- 0xB8=技コマンド成立時の技のID
				if spid > 0 then
					p.pow_up = pgm:read_u8(pgm:read_u32(0x8C1EC + p.char_4times) + spid - 1)
				end

				-- トドメ=ヒットで+7、雷撃棍=発生で+5、倍返し=返しで+7、吸収で+20、蛇使い は個別に設定が必要
				local yama_pows = new_set(0x06, 0x70, 0x71, 0x75, 0x76, 0x77, 0x7C, 0x7D)
				if p.char == 0x6 and p.attack == 0x28 then
					p.pow_up_hit = 0
					p.pow_up_gd  = 0
					p.pow_up     = 5
				elseif p.char == 0xB and yama_pows[p.attack] then
					p.pow_up_hit = 0
					p.pow_up_gd  = 0
					p.pow_up     = 5
				elseif p.char == 0xB and p.attack == 0x8E then
					p.pow_up_hit  = 0
					p.pow_up_gd   = 0
					p.pow_up      = 0
					p.pow_revenge = 7
					p.pow_absorb  = 20
				elseif p.char == 0xB and p.attack == 0xA0 then
					p.pow_up_hit = 7
					p.pow_up_gd  = 0
					p.pow_up     = 0
				elseif p.char == 0xB and p.attack == 0x82 then
					p.pow_revenge = 6 -- サドマゾ
				elseif p.char == 0x14 and p.attack == 0x82 then
					p.pow_revenge = 6 -- フェニックススルー
				elseif p.char == 0x8 and p.attack == 0x94 then
					p.pow_revenge = 6 -- 逆襲
				elseif p.char == 0x5 and p.attack == 0x82 then
					p.pow_revenge = 6 -- 当身投げ
				elseif p.char == 0x5 and p.attack == 0x7c then
					p.pow_revenge = 6 -- 当身投げ
				elseif p.char == 0x5 and p.attack == 0x88 then
					p.pow_revenge = 6 -- 当身投げ
				end
			end

			p.max_hit_dn    = p.attack > 0 and pgm:read_u8(pgm:read_u32(fix_bp_addr(0x827B8) + p.char_4times) + p.attack) or 0
			p.max_hit_nm    = pgm:read_u8(p.addr.max_hit_nm)
			p.last_dmg      = p.last_dmg or 0
			p.last_pow      = p.last_pow or 0
			p.last_pure_dmg = p.last_pure_dmg or 0
			p.last_stun     = p.last_stun or 0
			p.last_st_timer = p.last_st_timer or 0
			p.last_effects  = p.last_effects or {}
			p.dmg_scl7      = pgm:read_u8(p.addr.dmg_scl7)
			p.dmg_scl6      = pgm:read_u8(p.addr.dmg_scl6)
			p.dmg_scl5      = pgm:read_u8(p.addr.dmg_scl5)
			p.dmg_scl4      = pgm:read_u8(p.addr.dmg_scl4)
			pgm:write_u8(p.addr.dmg_scl7, 0)
			pgm:write_u8(p.addr.dmg_scl6, 0)
			pgm:write_u8(p.addr.dmg_scl5, 0)
			pgm:write_u8(p.addr.dmg_scl4, 0)
			p.dmg_scaling = 1
			if p.dmg_scl7 > 0 then
				p.dmg_scaling = p.dmg_scaling * (0.875 ^ p.dmg_scl7)
			end
			if p.dmg_scl6 > 0 then
				p.dmg_scaling = p.dmg_scaling * (0.75 ^ p.dmg_scl6)
			end
			if p.dmg_scl5 > 0 then
				p.dmg_scaling = p.dmg_scaling * (0.625 ^ p.dmg_scl5)
			end
			if p.dmg_scl4 > 0 then
				p.dmg_scaling = p.dmg_scaling * (0.5 ^ p.dmg_scl4)
			end
		end

		-- 1Pと2Pの状態読取 入力
		global.old_all_act_normal = global.all_act_normal
		global.all_act_normal = true
		for _, p in ipairs(players) do
			local op           = p.op

			p.input_offset     = pgm:read_u32(p.addr.input_offset)
			p.old_input_states = p.input_states or {}
			p.input_states     = {}
			local debug        = false
			local states       = dip_config.easy_super and input_states.easy or input_states.normal
			states             = debug and states[#states] or states[p.char]
			for ti, tbl in ipairs(states) do
				local old = p.old_input_states[ti]
				local addr = tbl.addr + p.input_offset
				local on = pgm:read_u8(addr - 1)
				local on_prev = on
				local chg_remain = pgm:read_u8(addr)
				local max = (old and old.on_prev == on_prev) and old.max or chg_remain
				local input_estab = old and old.input_estab or false
				local charging = false

				-- コマンド種類ごとの表示用の補正
				local reset = false
				local force_reset = false
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
						if 0 < tbl.id  and tbl.id < 0x1E  then
							local id_estab = pgm:read_u8(0xB8 + p.addr.base)
							local cmd_estab = pgm:read_u8(0xA5 + p.addr.base)
							local exp_extab = tbl.estab & 0x00FF
							reset = cmd_estab == exp_extab and id_estab == tbl.id or input_estab
						else
							--local id_estab = pgm:read_u8(0xD6 + p.addr.base)
							--reset = id_estab == tbl.id or input_estab
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
			p.last_blockstun = p.last_blockstun or 0
			p.last_hitstop   = p.last_hitstop or 0
			p.on_hit         = p.on_hit or 0
			p.on_block       = p.on_block or 0
			p.hit_skip       = p.hit_skip or 0
			p.on_punish      = p.on_punish or 0

			if mem._0x10B862 ~= 0 and p.act_contact ~= 0 then
				if p.state == 2 then
					-- ガードへの遷移フレームを記録
					p.on_block = global.frame_number
					p.on_punish = -1
				elseif p.state == 1 or p.state == 3 then
					-- ヒットへの遷移フレームを記録
					p.on_hit = global.frame_number
					if p.act_normal ~= true and p.old_state == 0 then
						-- 確定反撃フレームを記録
						p.on_punish = global.frame_number
					elseif p.old_state == 0 or p.old_state == 2 then
						p.on_punish = -1
					end
				else
					if p.act_normal ~= true and (p.on_punish + 60) >= global.frame_number then
						p.on_punish = -1
					end
				end
				if pgm:read_u8(p.addr.base + 0xAB) > 0 or p.ophit then
					p.hit_skip = 2
				end
			end
			if p.state == 0 and p.act_normal ~= true and mem._0x10B862 ~= 0 and op.act_contact ~= 0 then
				p.on_punish = -1
			end

			-- 起き上がりフレーム
			if wakeup_acts[p.old_act] ~= true and wakeup_acts[p.act] == true then
				p.on_wakeup = global.frame_number
			end
			-- ダウンフレーム
			if (p.old_flag_c0 & 0x2 == 0x0) and (p.flag_c0 & 0x2 == 0x2) then
				p.on_down = global.frame_number
			end
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
			else
				p.act_data = {
					name = (p.state == 1 or p.state == 3) and "やられ" or tohex(p.act),
					type = act_types.any,
				}
				p.act_1st  = false
			end
			if p.act_data.name == "やられ" then
				p.act_1st = false
			elseif p.act_data.name ~= "ダウン" and (p.state == 1 or p.state == 3) then
				p.act_data = {
					name = "やられ",
					type = act_types.any,
				}
				p.act_1st  = false
			end
			-- カイザーウェイブのレベルアップ
			if p.char == 0x14 and p.old_kaiser_wave ~= p.kaiser_wave then
				p.act_1st = true
			end
			p.old_act_normal = p.act_normal
			-- ガード移行可否
			p.act_normal = nil
			if p.state == 2 or
				(p.flag_cc & 0xFFFFFF3F) ~= 0 or
				(p.flag_c0 & 0x03FFD723) ~= 0 or
				(pgm:read_u8(p.addr.base + 0xB6) | p.flag_c4 | p.flag_c8) ~= 0 then
				p.act_normal = false
			else
				p.act_normal = true -- 移動中など
				p.act_normal = p.act_data.type == act_types.free or p.act_data.type == act_types.block
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
			for _, fb in pairs(p.fireball) do
				fb.parent         = p
				fb.is_fireball    = true
				fb.act            = pgm:read_u16(fb.addr.act)
				fb.acta           = pgm:read_u16(fb.addr.acta)
				fb.actb           = pgm:read_u16(fb.addr.actb)
				fb.act_count      = pgm:read_u8(fb.addr.act_count) -- 現在の行動のカウンタ
				-- 家庭用004A6Aからの処理
				fb.act_boxtype    = 0xFFFF & (pgm:read_u8(fb.addr.act_boxtype) & 0xC0 * 4)
				fb.act_frame      = pgm:read_u8(fb.addr.act_frame) -- 現在の行動の残フレーム、ゼロになると次の行動へ
				fb.act_contact    = pgm:read_u8(fb.addr.act_contact) -- 通常=2、必殺技中=3 ガードヒット=5 潜在ガード=6
				fb.pos            = pgm:read_i16(fb.addr.pos)
				fb.pos_y          = pgm:read_i16(fb.addr.pos_y)
				fb.pos_miny       = 0
				fb.pos_z          = pgm:read_i16(fb.addr.pos_z)
				fb.gd_strength    = get_gd_strength(fb)
				fb.asm            = pgm:read_u16(pgm:read_u32(fb.addr.base))
				fb.old_proc_act   = fb.proc_active
				fb.proc_active    = (fb.asm ~= 0x4E75 and fb.asm ~= 0x197C)
				fb.attack         = pgm:read_u16(pgm:read_u32(fb.addr.attack)) -- 攻撃中のみ変化
				fb.hitstop_id     = pgm:read_u16(fb.addr.hitstop_id)
				fb.attack_id      = 0
				fb.old_attacking  = p.attacking
				fb.attacking      = false
				fb.dmmy_attacking = false
				fb.juggling       = false
				if fb.hitstop_id == 0 then
					fb.hitstop    = 0
					fb.hitstop_gd = 0
					fb.pure_dmg   = 0
					fb.chip_dmg_type = chip_dmg_types.zero
					fb.pure_st    = 0
					fb.pure_st_tm = 0
				else
					-- ヒットストップ取得 家庭用 061656 からの処理
					fb.hitstop    = pgm:read_u8(fb.hitstop_id + fix_bp_addr(0x884F2))
					fb.hitstop    = fb.hitstop == 0 and 2 or fb.hitstop + 1 -- システムで消費される分を加算
					fb.hitstop_gd = math.max(2, fb.hitstop - 1) -- ガード時の補正
					-- 補正前ダメージ量取得 家庭用 05B146 からの処理
					fb.pure_dmg   = pgm:read_u8(fb.hitstop_id + fix_bp_addr(0x88472))
					-- 気絶値と気絶タイマー取得 家庭用 05C1B0 からの処理
					fb.pure_st    = pgm:read_u8(fb.hitstop_id + fix_bp_addr(0x886F2))
					fb.pure_st_tm = pgm:read_u8(fb.hitstop_id + fix_bp_addr(0x88772))
				end
				-- 受け身行動可否 家庭用 05A9B8 からの処理
				fb.can_techrise   = 2 > pgm:read_u8(0x8E2C0 + pgm:read_u8(fb.addr.hitstop_id))
				fb.fake_hit       = (pgm:read_u8(fb.addr.fake_hit) & 0xB) == 0
				fb.obsl_hit       = (pgm:read_u8(fb.addr.obsl_hit) & 0xB) == 0 -- 嘘判定チェック用
				fb.full_hit       = pgm:read_u8(fb.addr.full_hit) > 0 -- 判定チェック用1
				fb.harmless2      = pgm:read_u8(fb.addr.harmless2) > 0 -- 判定チェック用2 飛び道具専用
				fb.prj_rank       = pgm:read_u8(fb.addr.prj_rank)  -- 飛び道具の強さ
				fb.side           = pgm:read_u8(fb.addr.side)
				fb.box_base1      = pgm:read_u32(fb.addr.box_base1)
				fb.box_base2      = pgm:read_u32(fb.addr.box_base2)
				--倍返しチェック 家庭用05C8CEからの処理
				fb.bai_chk1       = pgm:read_u8(fb.addr.bai_chk1)
				fb.bai_chk2       = pgm:read_u8(0x8E940 + (0xFFFF & (pgm:read_u16(fb.addr.hitstop_id) + fb.hitstop_id)))
				fb.bai_catch      = 0x2 >= fb.bai_chk1 and fb.bai_chk2 == 0x01
				fb.max_hit_dn     = pgm:read_u8(fix_bp_addr(0x885F2) + fb.hitstop_id) -- 同一技行動での最大ヒット数 分母
				fb.max_hit_nm     = pgm:read_u8(fb.addr.max_hit_nm)       -- 同一技行動での最大ヒット数 分子
				fb.hitboxes       = {}
				fb.buffer         = {}
				fb.uniq_hitboxes  = {}       -- key + boolean
				fb.hit_summary    = fb.hit_summary or {} -- 大状態表示のデータ構造の一部
				fb.hit            = fb.hit or {
					pos_x      = 0,
					pos_z      = 0,
					pos_y      = 0,
					on         = 0,
					flip_x     = 0,
					scale      = 0,
					char_id    = 0,
					vulnerable = 0,
					harmless   = false,
					fake_hit   = false,
					obsl_hit   = false,
					full_hit   = false,
					harmless2  = false,
					max_hit_dn = 0,
					max_hit_nm = 0,
				}
				fb.type_boxes     = {}
				fb.act_data_fired = p.act_data -- 発射したタイミングの行動ID

				fb.act_frames     = fb.act_frames or {}
				fb.act_frames2    = fb.act_frames2 or {}

				-- 当たり判定の構築
				fb.has_atk_box    = false
				if fb.proc_active == true then --0x4E75 is rts instruction
					fb.alive                = true
					temp_hits[fb.addr.base] = fb
					fb.atk_count            = fb.atk_count or 0
				else
					fb.alive      = false
					fb.atk_count  = 0
					fb.hitstop    = 0
					fb.pure_dmg   = 0
					fb.pure_st    = 0
					fb.pure_st_tm = 0
				end
				global.all_act_normal = global.all_act_normal and (fb.alive == false)

				fb.hit_summary = new_box_summary(fb)
				if fb.alive then
					debug_box(fb, pgm)
				end
			end

			-- 値更新のフック確認
			p.update_sts = (pgm:read_u8(p.addr.state2) ~= 0) and global.frame_number or p.update_sts
			p.update_dmg = (p.tmp_dmg ~= 0) and global.frame_number or p.update_dmg
			p.act2       = pgm:read_u16(p.addr.act2)
			p.update_act = (p.act2 ~= 0) and global.frame_number or p.update_act
			p.act_1st    = p.update_act == global.frame_number and p.act_1st == true
			if p.act_1st == true then
				p.atk_count = 1
				p.startup = p.atk_count
				p.active = 0
				p.recovery = 0
			else
				p.atk_count = p.atk_count + 1
				p.startup = p.startup or 0
				p.active = p.active or 0
				p.recovery = p.recovery or 0
			end

			-- 硬直フレーム設定
			p.last_blockstun   = p.last_blockstun or 0

			-- 当たり判定のフック確認
			p.hit.vulnerable1  = pgm:read_u8(p.addr.vulnerable1)
			p.hit.vulnerable21 = pgm:read_u8(p.addr.vulnerable21)
			p.hit.vulnerable22 = pgm:read_u8(p.addr.vulnerable22) == 0 --0の時vulnerable=true

			-- リーチ
			p.hit_summary      = new_box_summary(p)
			debug_box(p, pgm)

			-- 投げ判定取得
			get_n_throw(p, op, height)

			-- 空中投げ判定取得
			get_air_throw(p, op, height)

			-- 必殺投げ判定取得
			get_sp_throw(p, op, height)

			-- 当たり判定の構築用バッファのリフレッシュ
			p.hitboxes             = {}
			p.buffer               = {}
			p.uniq_hitboxes        = {} -- key + boolean
			p.type_boxes           = {}
			temp_hits[p.addr.base] = p

			--攻撃種類,ガード要否
			if global.frame_number <= p.update_sts and p.state ~= p.old_state then
				p.random_boolean = math.random(255) % 2 == 0
			end
			op.need_block     = false
			op.need_low_block = false
			op.need_ovh_block = false
			if p.act ~= 0 and 0 < p.char and p.char < 25 then
				op.need_block     = (p.act_data.type == act_types.low_attack) or (p.act_data.type == act_types.attack) or (p.act_data.type == act_types.overhead)
				op.need_low_block = p.act_data.type == act_types.low_attack
				op.need_ovh_block = p.act_data.type == act_types.overhead
			end
			for _, fb in pairs(p.fireball) do
				-- 飛び道具の状態チェック
				if fb.act ~= nil and fb.act > 0 and fb.act ~= 0xC then
					local act_type = act_types.attack
					if p.char_data.fireballs[fb.act] then
						-- 双角だけ中段と下段の飛び道具がある
						act_type = p.char_data.fireballs[fb.act].type
						fb.char_fireball = p.char_data.fireballs[fb.act]
					end
					op.need_block     = op.need_block or (act_type == act_types.low_attack) or (act_type == act_types.attack) or (act_type == act_types.overhead)
					op.need_low_block = op.need_low_block or (act_type == act_types.low_attack)
					op.need_ovh_block = op.need_ovh_block or (act_type == act_types.overhead)
					-- printf("%x %x %x %s", fb.act, fb.acta, fb.actb, act_type) -- debug
				end
			end
		end

		-- キャラと飛び道具の当たり判定取得
		for addr = 0x1DC000, 0x1DC000 + pgm:read_u8(0x10CB40) * 0x10, 0x10 do
			local box = {
				on     = pgm:read_u8(addr),
				id     = pgm:read_u8(addr + 0x1),
				top    = pgm:read_i8(addr + 0x2),
				bottom = pgm:read_i8(addr + 0x3),
				left   = pgm:read_i8(addr + 0x4),
				right  = pgm:read_i8(addr + 0x5),
				base   = pgm:read_u32(addr + 0x6),
				pos_x  = pgm:read_i16(addr + 0xC) - screen.left,
				pos_y  = height - pgm:read_i16(addr + 0xE) + screen.top,
			}
			if box.on ~= 0xFF and temp_hits[box.base] then
				box.is_fireball = temp_hits[box.base].is_fireball == true
				local p = temp_hits[box.base]
				local base = ((p.addr.base - 0x100400) / 0x100)
				box.key = string.format("%x %x %s %s %s %s", base, box.id, box.top, box.bottom, box.left, box.right)
				if p.uniq_hitboxes[box.key] == nil then
					p.uniq_hitboxes[box.key] = true
					table.insert(p.buffer, box)
				end
			end
		end

		-- キャラと飛び道具への当たり判定の反映
		for _, p in pairs(temp_hits) do
			-- update_objectはキャラの位置情報と当たり判定の情報を読み込んだ後で実行すること
			update_object(p)

			-- 飛び道具の有効無効確定
			if p.is_fireball == true then
				p.alive = #p.hitboxes > 0
			end

			local hitbox_keys = {}
			local hurtbox_keys = {}
			for k, boxtype in pairs(p.uniq_hitboxes) do
				if boxtype == true then
				elseif boxtype.type == "attack" or boxtype.type == "throw" or boxtype.type == "atemi" then
					table.insert(hitbox_keys, k)
				else
					table.insert(hurtbox_keys, k)
				end
			end
			table.sort(hitbox_keys)
			table.sort(hurtbox_keys)
			local hitbox_txt = string.format("%s %s %s ", p.attack_id, p.hit.fake_hit, p.alive) .. table.concat(hitbox_keys, "&")
			local hurtbox_txt = table.concat(hurtbox_keys, "&")
			if p.hitbox_txt ~= hitbox_txt then
				p.chg_hitbox_frm = global.frame_number
			end
			if p.hurtbox_txt ~= hurtbox_txt then
				p.chg_hurtbox_frm = global.frame_number
			end
			p.hitbox_txt = hitbox_txt
			p.hurtbox_txt = hurtbox_txt
		end

		-- キャラの状態表示のためのサマリ情報の構築
		for _, p in ipairs(players) do
			-- くらい判定等の常時更新するサマリ情報
			p.hurt_summary = make_hurt_summary(p, p.hit_summary)

			-- 攻撃判定のサマリ情報
			if check_edge(p.hit_summary.edge.throw) then
				p.throw_summary = make_throw_summary(p, p.hit_summary)
			else
				p.throw_summary = p.old_throw_summary or {}
			end
			p.old_throw_summary = p.throw_summary

			if check_edge(p.hit_summary.edge.parry) then
				p.parry_summary = make_parry_summary(p, p.hit_summary)
			else
				p.parry_summary = p.old_parry_summary or {}
			end
			p.old_parry_summary = p.parry_summary

			p.dmg_summary = p.dmg_summary or {}
			if p.hit_summary.pure_dmg ~= nil and (p.attack_id > 0 or (p.hit_summary.pure_dmg or 0) > 0) then
				p.dmg_summary = make_dmg_summary(p, p.hit_summary) or p.dmg_summary
			end

			p.pow_summary = p.pow_summary or {}
			if p.attack > 0 then
				p.pow_summary = make_pow_summary(p, p.hit_summary) or p.pow_summary
			end

			-- 攻撃モーション単位で変わるサマリ情報
			local summary_p_atk = p.attack > 0 and string.format("%x %s %s %s", p.attack, p.slide_atk, p.bs_atk, p.hitbox_txt) or ""
			p.atk_summary = p.atk_summary or {}
			-- 攻撃モーション単位で変わるサマリ情報 本体
			p.atkact_summary = make_atkact_summary(p, p.hit_summary) or p.atkact_summary
			if (p.attack_flag and p.attack > 0 and p.summary_p_atk ~= summary_p_atk) or
				(p.attack_id > 0 and p.summary_p_atkid ~= p.attack_id) then
				p.atk_summary = make_atk_summary(p, p.hit_summary)
				p.summary_p_atk = summary_p_atk
				p.summary_p_atkid = p.attack_id
			end
			-- 攻撃モーション単位で変わるサマリ情報 弾
			for _, fb in pairs(p.fireball) do
				if fb.alive then
					fb.dmg_summary = make_dmg_summary(fb, fb.hit_summary) or fb.dmg_summary
					p.dmg_summary = fb.dmg_summary

					fb.atkact_summary = make_atkact_summary(fb, fb.hit_summary) or fb.atkact_summary
					-- 表示情報を弾の情報で上書き
					p.atkact_summary = fb.atkact_summary
					-- 情報を残すために弾中の動作のIDも残す
					p.summary_p_atk = p.attack > 0 and p.attack or summary_p_atk
				end
			end

			-- サマリ情報を結合する
			local all_summary = {}
			for _, summary in ipairs({
				p.hurt_summary,
				p.dmg_summary,
				p.pow_summary,
				p.atkact_summary,
				p.atk_summary,
				p.throw_summary,
				p.parry_summary }) do
				for _, row in ipairs(summary) do
					table.insert(all_summary, row)
				end
			end
			p.all_summary = sort_summary(all_summary)
		end

		-- フレーム表示などの前処理1
		for _, p in ipairs(players) do
			local op         = p.op

			--フレーム数
			p.frame_gap      = p.frame_gap or 0
			p.last_frame_gap = p.last_frame_gap or 0
			if mem._0x10B862 ~= 0 and p.act_contact ~= 0 then
				local hitstun, blockstun = 0, 0
				if p.ophit and p.ophit.hitboxes then
					for _, box in pairs(p.ophit.hitboxes) do
						if box.type.type == "attack" then
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
					p.last_hitstop   = on_block and p.ophit.hitstop_gd or p.ophit.hitstop
				end
			elseif op.char == 20 and op.act == 0x00AF and op.act_count == 0x00 and op.act_frame == 0x09 then
				-- デンジャラススルー専用
				p.last_blockstun = p.stop + 2
				p.last_hitstop = p.stop
			elseif op.char == 5 and op.act == 0x00A7 and op.act_count == 0x00 and op.act_frame == 0x06 then
				-- 裏雲隠し専用
				p.last_blockstun = p.knock_back2 + 3
				p.last_hitstop = 0
			end
		end

		-- フレーム表示などの前処理2
		for _, p in ipairs(players) do
			--停止演出のチェック
			p.old_skip_frame = p.skip_frame
			if global.no_background then
				p.skip_frame = p.hit_skip ~= 0 or p.stop ~= 0
			else
				-- 停止演出のチェックで背景なしチートの影響箇所をチェックするので背景なしONときは停止演出のチェックを飛ばす
				p.skip_frame = p.hit_skip ~= 0 or p.stop ~= 0 or
					(mem._0x100F56 == 0xFFFFFFFF or mem._0x100F56 == 0x0000FFFF)
			end

			if p.hit_skip ~= 0 or mem._0x100F56 ~= 0 then
				--停止フレームはフレーム計算しない
				if p.hit_skip ~= 0 then
					--ヒットストップの減算
					p.hit_skip = p.hit_skip - 1
				end
			end

			-- ヒットフレームの判断
			if p.state ~= 1 and p.state ~= 3 then
				p.hit1 = 0
			elseif p.on_hit == global.frame_number then
				p.hit1 = 1 -- 1ヒット確定
			end
			-- 停止時間なしのヒットガードのためelseifで繋げない
			if (p.hit1 == 1 and p.skip_frame == false) or ((p.state == 1 or p.state == 3) and p.old_skip_frame == true and p.skip_frame == false) then
				p.hit1 = 2 -- ヒット後のヒットストップ解除フレームの記録
				p.on_hit1 = global.frame_number
			end

			-- ガードフレームの判断
			if p.state ~= 2 then
				p.block1 = 0
			elseif p.on_block == global.frame_number then
				p.block1 = 1 -- 1ガード確定
			end
			-- 停止時間なしのヒットガードのためelseifで繋げない
			if (p.block1 == 1 and p.skip_frame == false) or (p.state == 2 and p.old_skip_frame == true and p.skip_frame == false) then
				p.block1 = 2 -- ガード後のヒットストップ解除フレームの記録
				p.on_block1 = global.frame_number
			end
		end

		-- ログ表示
		if global.log.baselog or global.log.keylog or global.log.poslog then
			local p1, p2 = players[1], players[2]
			local log1, log2 = string.format("P1 %s ", p1.act_data.name, string.format("P2 %s ", p2.act_data.name))

			-- ベースアドレスログ
			if global.log.baselog then
				local b1 = p1.bases[#players[1].bases]
				local b2 = p2.bases[#players[2].bases]
				log1 = string.format("%s addr %3s %8x %0.03f ", log1, 999 < b1.count and "LOT" or b1.count, b1.addr, b1.xmov)
				log2 = string.format("%s addr %3s %8x %0.03f ", log2, 999 < b2.count and "LOT" or b2.count, b2.addr, b2.xmov)
			end

			-- 入力ログ
			if global.log.keylog then
				log1 = string.format("%s key %s ", log1, p1.key_hist[#p1.key_hist])
				log2 = string.format("%s key %s ", log2, p2.key_hist[#p2.key_hist])
			end

			-- 位置ログ
			if global.log.poslog then
				log1 = string.format("%s pos %4d.%05d %4d.%05d %2s %3s", log1, p1.pos, p1.pos_frc, p1.pos_y, p1.pos_frc_y, p1.act_count, p1.act_frame)
				log2 = string.format("%s pos %4d.%05d %4d.%05d %2s %3s", log2, p2.pos, p2.pos_frc, p2.pos_y, p2.pos_frc_y, p2.act_count, p2.act_frame)
			end

			print(log1, log2)
		end

		-- フック処理のデータ反映
		for _, p in ipairs(players) do
			-- リバーサルのランダム選択
			p.dummy_rvs = nil
			if p.dummy_bs_chr == p.char then
				if (p.dummy_wakeup == wakeup_type.tech or p.dummy_wakeup == wakeup_type.sway or p.dummy_wakeup == wakeup_type.rvs) and #p.dummy_rvs_list > 0 then
					p.dummy_rvs = get_next_rvs(p)
				end
			end
			-- ブレイクショットのランダム選択
			p.dummy_bs = nil
			if p.dummy_rvs_chr == p.char then
				if p.dummy_gd == dummy_gd_type.bs and #p.dummy_bs_list > 0 then
					if p.state == 2 and p.skip_frame then
						p.dummy_bs = get_next_bs(p)
					end
				end
			end
			-- BSモード用技ID更新フック用の値更新
			if p.bs_hooked + 2 < global.frame_number then
				pgm:write_u8(p.addr.bs_hook3, 0xFF) -- 初期化
			end
			p.write_bs_hook = function(bs_hook)
				if bs_hook and bs_hook.id then
					pgm:write_u8(p.addr.bs_hook1, bs_hook.id or 0x00)
					pgm:write_u16(p.addr.bs_hook2, bs_hook.ver or 0x0600)
					pgm:write_u8(p.addr.bs_hook3, 0x01)
					p.bs_hooked = global.frame_number
					--printf("bshook %s %x %x %x", global.frame_number, p.act, bs_hook.id or 0x20, bs_hook.ver or 0x0600)
				else
					pgm:write_u8(p.addr.bs_hook1, 0x00)
					pgm:write_u16(p.addr.bs_hook2, 0x0600)
					pgm:write_u8(p.addr.bs_hook3, 0xFF)
					-- printf("bshook %s %x %x %x", global.frame_number, 0x20, 0x0600))
				end
			end
		end

		-- キャラ間の距離
		p_space         = players[1].pos - players[2].pos

		-- プレイヤー操作事前設定（それぞれCPUか人力か入れ替えか）
		-- キー入力の取得（1P、2Pの操作を入れ替えていたりする場合もあるのでモード判定と一緒に処理する）
		local reg_p1cnt = pgm:read_u8(players[1].addr.reg_pcnt)
		local reg_p2cnt = pgm:read_u8(players[2].addr.reg_pcnt)
		local reg_st_b  = pgm:read_u8(players[1].addr.reg_st_b)
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
			pgm:write_u8(p.addr.control1, p.control) -- Human 1 or 2, CPU 3
			pgm:write_u8(p.addr.control2, p.control) -- Human 1 or 2, CPU 3

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
					for _, fb in pairs(p.fireball) do
						fb.act_frames = {}
						fb.act_frames2 = {}
					end
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
		else
			for _, p in ipairs(players) do
				proc_nonact_frame(p)
			end
		end

		-- フレーム経過による硬直差の減少
		for _, p in ipairs(players) do
			if p.last_hitstop > 0 then
				p.last_hitstop = p.last_hitstop - 1
			elseif p.last_blockstun > 0 then
				p.last_blockstun = p.last_blockstun - 1
			end
		end

		-- キーディス用の処理
		for i, p in ipairs(players) do
			local p1      = i == 1
			local op      = p.op

			-- 入力表示用の情報構築
			local key_now = p.key_now
			key_now.d     = (p.reg_pcnt & 0x80) == 0x00 and posi_or_pl1(key_now.d) or nega_or_mi1(key_now.d)           -- Button D
			key_now.c     = (p.reg_pcnt & 0x40) == 0x00 and posi_or_pl1(key_now.c) or nega_or_mi1(key_now.c)           -- Button C
			key_now.b     = (p.reg_pcnt & 0x20) == 0x00 and posi_or_pl1(key_now.b) or nega_or_mi1(key_now.b)           -- Button B
			key_now.a     = (p.reg_pcnt & 0x10) == 0x00 and posi_or_pl1(key_now.a) or nega_or_mi1(key_now.a)           -- Button A
			key_now.rt    = (p.reg_pcnt & 0x08) == 0x00 and posi_or_pl1(key_now.rt) or nega_or_mi1(key_now.rt)         -- Right
			key_now.lt    = (p.reg_pcnt & 0x04) == 0x00 and posi_or_pl1(key_now.lt) or nega_or_mi1(key_now.lt)         -- Left
			key_now.dn    = (p.reg_pcnt & 0x02) == 0x00 and posi_or_pl1(key_now.dn) or nega_or_mi1(key_now.dn)         -- Down
			key_now.up    = (p.reg_pcnt & 0x01) == 0x00 and posi_or_pl1(key_now.up) or nega_or_mi1(key_now.up)         -- Up
			key_now.sl    = (p.reg_st_b & (p1 and 0x02 or 0x08)) == 0x00 and posi_or_pl1(key_now.sl) or nega_or_mi1(key_now.sl) -- Select
			key_now.st    = (p.reg_st_b & (p1 and 0x01 or 0x04)) == 0x00 and posi_or_pl1(key_now.st) or nega_or_mi1(key_now.st) -- Start
			local lever, lever_no
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
			local btn_a, btn_b, btn_c, btn_d = false, false, false, false
			if (p.reg_pcnt & 0x10) == 0x00 then
				lever = lever .. "_A"
				btn_a = true
			end
			if (p.reg_pcnt & 0x20) == 0x00 then
				lever = lever .. "_B"
				btn_b = true
			end
			if (p.reg_pcnt & 0x40) == 0x00 then
				lever = lever .. "_C"
				btn_c = true
			end
			if (p.reg_pcnt & 0x80) == 0x00 then
				lever = lever .. "_D"
				btn_d = true
			end
			-- GG風キーディスの更新
			table.insert(p.ggkey_hist, { l = lever_no, a = btn_a, b = btn_b, c = btn_c, d = btn_d, })
			while 60 < #p.ggkey_hist do
				--バッファ長調整
				table.remove(p.ggkey_hist, 1)
			end
			-- キーログの更新
			if p.key_hist[#p.key_hist] ~= lever then
				for k = 2, #p.key_hist do
					p.key_hist[k - 1] = p.key_hist[k]
					p.key_frames[k - 1] = p.key_frames[k]
				end
				if 16 ~= #p.key_hist then
					p.key_hist[#p.key_hist + 1] = lever
					p.key_frames[#p.key_frames + 1] = 1
				else
					p.key_hist[#p.key_hist] = lever
					p.key_frames[#p.key_frames] = 1
				end
			else
				local frmcount = p.key_frames[#p.key_frames]
				--フレーム数が多すぎる場合は加算をやめる
				p.key_frames[#p.key_frames] = (999 < frmcount) and 1000 or (frmcount + 1)
			end

			-- コンボ数とコンボダメージの処理
			if p.normal_state == true then
				p.tmp_combo_dmg = 0
				p.last_combo_stun_offset = p.stun
				p.last_combo_st_timer_offset = p.stun_timer
			end
			if p.tmp_pow_rsv > 0 then
				p.tmp_pow = p.tmp_pow + p.tmp_pow_rsv
			end
			if p.tmp_pow > 0 then
				p.last_pow = p.tmp_pow
				-- TODO: 大バーン→クラックシュートみたいな繋ぎのときにちゃんと加算されない
				if p.last_normal_state == true and p.normal_state == true then
					p.tmp_combo_pow = p.tmp_pow
				elseif p.last_normal_state == true and p.normal_state == false then
					p.tmp_combo_pow = p.tmp_pow
				elseif p.tmp_combo == 1 then
					p.tmp_combo_pow = p.tmp_pow
				else
					p.tmp_combo_pow = p.tmp_combo_pow + p.tmp_pow
				end
				p.last_combo_pow = p.tmp_combo_pow
				p.max_combo_pow = math.max(p.max_combo_pow, p.tmp_combo_pow)
			end
			if p.pure_dmg > 0 then -- ヒットしなくても算出しているのでp.tmp_dmgでチェックしない
				p.last_pure_dmg = p.pure_dmg
			end
			if p.tmp_dmg ~= 0x00 then
				p.last_dmg = p.tmp_dmg
				p.tmp_combo_dmg = p.tmp_combo_dmg + p.tmp_dmg
				p.last_combo = p.tmp_combo
				p.last_combo_dmg = p.tmp_combo_dmg
				p.last_dmg_scaling = p.dmg_scaling
				p.max_dmg = math.max(p.max_dmg, p.tmp_combo_dmg)
				p.last_stun = p.tmp_stun
				p.last_st_timer = p.tmp_st_timer
				p.last_combo_stun = p.stun - p.last_combo_stun_offset
				p.last_combo_st_timer = math.max(0, p.stun_timer - p.last_combo_st_timer_offset)
				p.max_disp_stun = math.max(p.max_disp_stun, p.last_combo_stun)
				p.max_st_timer = math.max(p.max_st_timer, p.last_combo_st_timer)
				p.init_stun = p.char_data.init_stuns
			end

			do_recover(p, op)
		end

		-- プレイヤー操作
		for i, p in ipairs(players) do
			local op = p.op
			if p.control == 1 or p.control == 2 then
				--前進とガード方向
				local sp = p_space == 0 and prev_p_space or p_space
				sp = i == 1 and sp or (sp * -1)
				local lt, rt = "P" .. p.control .. " Left", "P" .. p.control .. " Right"
				p.block_side = 0 < sp and rt or lt
				p.front_side = 0 < sp and lt or rt

				-- レコード中、リプレイ中は行動しないためのフラグ
				local accept_control = true
				if global.dummy_mode == 5 then
					accept_control = false
				elseif global.dummy_mode == 6 then
					if global.rec_main == rec_play and recording.player == p.control then
						accept_control = false
					end
				end

				-- 立ち, しゃがみ, ジャンプ, 小ジャンプ, スウェー待機
				-- { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" },
				-- レコード中、リプレイ中は行動しない
				if accept_control then
					if p.dummy_act == 1 then
					elseif p.dummy_act == 2 and p.sway_status == 0x00 then
						next_joy["P" .. p.control .. " Down"] = true
					elseif p.dummy_act == 3 and p.sway_status == 0x00 then
						next_joy["P" .. p.control .. " Up"] = true
					elseif p.dummy_act == 4 and p.sway_status == 0x00 and p.state_bits[18] ~= 1 then
						-- 地上のジャンプ移行モーション以外だったら上入力
						next_joy["P" .. p.control .. " Up"] = true
					elseif p.dummy_act == 5 then
						if p.in_sway_line ~= true and p.state == 0 and op.in_sway_line ~= true and op.act ~= 0x65 and op.act ~= 0x66 then
							if joy_val["P" .. p.control .. " D"] < 0 then
								next_joy["P" .. p.control .. " D"] = true
							end
							next_joy["P" .. p.control .. " Down"] = true
						elseif p.in_sway_line == true then
							next_joy["P" .. p.control .. " Up"] = true
						end
					end
				end

				-- なし, オート, 1ヒットガード, 1ガード, 常時, ランダム, 強制
				if p.dummy_gd == dummy_gd_type.force then
					pgm:write_u8(p.addr.force_block, 0x01)
				else
					pgm:write_u8(p.addr.force_block, 0x00)
				end
				-- リプレイ中は自動ガードしない
				if (p.need_block or p.need_low_block or p.need_ovh_block) and accept_control then
					if jump_acts[p.act] then
						next_joy["P" .. p.control .. " Up"] = false
					end
					if p.dummy_gd == dummy_gd_type.fixed then
						-- 常時（ガード方向はダミーモードに従う）
						next_joy[p.block_side] = true
						p.backstep_killer = true
					elseif p.dummy_gd == dummy_gd_type.auto or     -- オート
						p.dummy_gd == dummy_gd_type.bs or          -- ブレイクショット
						(p.dummy_gd == dummy_gd_type.random and p.random_boolean) or -- ランダム
						(p.dummy_gd == dummy_gd_type.hit1 and p.next_block) or -- 1ヒットガード
						(p.dummy_gd == dummy_gd_type.block1)       -- 1ガード
					then
						-- 中段から優先
						if p.need_ovh_block then
							next_joy["P" .. p.control .. " Down"] = false
							p.backstep_killer = true
						elseif p.need_low_block then
							next_joy["P" .. p.control .. " Up"] = false
							next_joy["P" .. p.control .. " Down"] = true
							p.backstep_killer = false
						else
							p.backstep_killer = true
						end
						if p.dummy_gd == dummy_gd_type.block1 and p.next_block ~= true then
							-- 1ガードの時は連続ガードの上下段のみ対応させる
							next_joy[p.block_side] = false
							p.backstep_killer = false
						else
							next_joy[p.block_side] = true
						end
					end
				else
					if p.backstep_killer then
						-- コマンド入力状態を無効にしてバクステ暴発を防ぐ
						local bs_addr = dip_config.easy_super and p.char_data.easy_bs_addr or p.char_data.bs_addr
						pgm:write_u8(p.input_offset + bs_addr, 0x00)
						p.backstep_killer = false
					end
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
				if p.fwd_prov and op.provoke then
					next_joy[p.front_side] = true
				end

				local input_bs = function()
					p.write_bs_hook(p.dummy_bs)
				end
				local input_rvs = function(rvs_type, p, logtxt)
					if global.log.rvslog and logtxt then
						print(logtxt)
					end
					if p.dummy_rvs.throw then
						if p.act == 0x9 and p.act_frame > 1 then -- 着地硬直は投げでないのでスルー
							return
						end
						if op.in_air then
							return
						end
						if op.sway_status ~= 0x00 then -- 全投げ無敵
							return
						end
						if p.dummy_rvs.cmd then -- 通常投げ
							if not p.n_throwable or not p.throw.in_range then
								--return
							end
						end
					elseif p.dummy_rvs.jump then
						if p.state == 0 and p.old_state == 0 and (p.flag_c0 | p.old_flag_c0) & 0x10000 == 0x10000 then
							-- 連続通常ジャンプを繰り返さない
							return
						end
					end
					if p.dummy_rvs.cmd then
						if rvs_types.knock_back_recovery ~= rvs_type then
							if (((p.flag_c0 | p.old_flag_c0) & 0x2 == 0x2) or pre_down_acts[p.act]) and p.dummy_rvs.cmd == cmd_base._2d then
								-- no act
							else
								p.dummy_rvs.cmd(p, next_joy)
							end
						end
					else
						p.write_bs_hook(p.dummy_rvs)
					end
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
				-- print(p.state, p.knock_back1, p.knock_back2, p.knock_back3, p.stop, rvs_types.in_knock_back, p.last_blockstun, string.format("%x", p.act), p.act_count, p.act_frame)
				-- ヒットストップ中は無視
				if not p.skip_frame then
					-- なし, リバーサル, テクニカルライズ, グランドスウェー, 起き上がり攻撃
					if (p.dummy_wakeup == wakeup_type.tech or p.dummy_wakeup == wakeup_type.sway or p.dummy_wakeup == wakeup_type.rvs) and p.dummy_rvs then
						-- ダウン起き上がりリバーサル入力
						if wakeup_acts[p.act] and (p.char_data.wakeup_frms - 3) <= (global.frame_number - p.on_wakeup) then
							input_rvs(rvs_types.on_wakeup, p, string.format("ダウン起き上がりリバーサル入力1 %s %s",
								p.char_data.wakeup_frms, (global.frame_number - p.on_wakeup)))
						end
						-- 着地リバーサル入力（やられの着地）
						if 1 < p.pos_y_down and p.old_pos_y > p.pos_y and p.in_air ~= true then
							input_rvs(rvs_types.knock_back_landing, p, "着地リバーサル入力（やられの着地）")
						end
						-- 着地リバーサル入力（通常ジャンプの着地）
						if p.act == 0x9 and (p.act_frame == 2 or p.act_frame == 0) then
							input_rvs(rvs_types.jump_landing, p, "着地リバーサル入力（通常ジャンプの着地）")
						end
						-- リバーサルじゃない最速入力
						if p.state == 0 and p.act_data.name ~= "やられ" and p.old_act_data.name == "やられ" and p.knock_back1 == 0 then
							input_rvs(rvs_types.knock_back_recovery, p, "リバーサルじゃない最速入力")
						end
						-- のけぞりのリバーサル入力
						if (p.state == 1 or (p.state == 2 and p.gd_rvs_enabled)) and p.stop == 0 then
							-- のけぞり中のデータをみてのけぞり終了の2F前に入力確定する
							-- 奥ラインへ送った場合だけ無視する（p.act ~= 0x14A）
							if p.knock_back3 == 0x80 and p.knock_back1 == 0 and p.act ~= 0x14A then
								input_rvs(rvs_types.in_knock_back, p, "のけぞり中のデータをみてのけぞり終了の2F前に入力確定する1")
							elseif p.old_knock_back1 > 0 and p.knock_back1 == 0 then
								input_rvs(rvs_types.in_knock_back, p, "のけぞり中のデータをみてのけぞり終了の2F前に入力確定する2")
							end
							-- デンジャラススルー用
							if p.knock_back3 == 0x0 and p.stop < 3 and p.base == 0x34538 then
								input_rvs(rvs_types.dangerous_through, p, "デンジャラススルー用")
							end
						elseif p.state == 3 and p.stop == 0 and p.knock_back2 <= 1 then
							-- 当身うち空振りと裏雲隠し用
							input_rvs(rvs_types.atemi, p, "当身うち空振りと裏雲隠し用")
						end
						-- 奥ラインへ送ったあとのリバサ
						if p.act == 0x14A and (p.act_count == 4 or p.act_count == 5) and p.old_act_frame == 0 and p.act_frame == 0 and p.tw_frame == 0 then
							input_rvs(rvs_types.in_knock_back, p, string.format("奥ラインへ送ったあとのリバサ %x %x %x %s", p.act, p.act_count, p.act_frame, p.tw_frame))
						end
						-- テクニカルライズのリバサ
						if p.act == 0x2C9 and p.act_count == 2 and p.act_frame == 0 and p.tw_frame == 0 then
							input_rvs(rvs_types.in_knock_back, p, string.format("テクニカルライズのリバサ1 %x %x %x %s", p.act, p.act_count, p.act_frame, p.tw_frame))
						end
						if p.act == 0x2C9 and p.act_count == 0 and p.act_frame == 2 and p.tw_frame == 0 then
							input_rvs(rvs_types.in_knock_back, p, string.format("テクニカルライズのリバサ2 %x %x %x %s", p.act, p.act_count, p.act_frame, p.tw_frame))
						end
						-- グランドスウェー
						local sway_act_frame = 0
						if p.char_data.sway_act_counts ~= 0 then
							sway_act_frame = 1
						end
						if p.act == 0x13E and p.act_count == p.char_data.sway_act_counts and p.act_frame == sway_act_frame then
							input_rvs(rvs_types.in_knock_back, p, string.format("グランドスウェーのあとのリバサ %x %x %x %s", p.act, p.act_count, p.act_frame, p.tw_frame))
						end
					end
					if p.dummy_wakeup == wakeup_type.tech and p.on_down == global.frame_number then
						-- テクニカルライズ入力
						cmd_base._2d(p, next_joy)
					elseif p.dummy_wakeup == wakeup_type.sway and p.on_down == global.frame_number then
						-- グランドスウェー入力
						cmd_base._8d(p, next_joy)
					elseif p.dummy_wakeup == wakeup_type.atk and p.on_down == global.frame_number and (p.char == 0x04 or p.char == 0x07 or p.char == 0x0A or p.char == 0x0B) then
						-- 起き上がり攻撃入力
						-- 舞、ボブ、フランコ、山崎のみなのでキャラをチェックする
						p.write_bs_hook({ id = 0x23, ver = 0x7800, bs = false, name = "起き上がり攻撃", })
					end
				end

				-- 自動ダウン追撃
				if op.act == 0x190 or op.act == 0x192 or op.act == 0x18E or op.act == 0x13B then
					-- 自動ダウン投げ
					-- TODO 間合い管理
					if global.auto_input.otg_thw then
						if p.char == 5 then
							-- ギース
							p.write_bs_hook({ id = 0x06, ver = 0x0600, bs = false, name = "雷鳴豪波投げ", })
						elseif p.char == 9 then
							-- マリー
							p.write_bs_hook({ id = 0x08, ver = 0x06F9, bs = false, name = "M.ダイナマイトスウィング", })
						end
					end
					-- 自動ダウン攻撃
					-- TODO 間合い管理
					if global.auto_input.otg_atk then
						if p.char == 9 then
							-- マリー
							p.write_bs_hook({ id = 0x24, ver = 0x0600, bs = false, name = "レッグプレス", })
						elseif p.char == 11 then
							-- 山崎
							p.write_bs_hook({ id = 0x09, ver = 0x0C00, bs = false, name = "トドメ", })
						elseif p.char == 3 or p.char == 6 or p.char == 7 or p.char == 8 or p.char == 14 or p.char == 20 then
							-- ジョー、双角、ボブ、ホンフゥ、ダック、クラウザー
							-- TODO ホンフゥはタイミングがわるいと全然あたらない
							p.write_bs_hook({ id = 0x21, ver = 0x0600, bs = false, name = "ダウン攻撃", })
						end
					end
				end

				-- 自動投げ追撃
				if global.auto_input.thw_otg then
					if p.char == 7 then
						-- ボブ
						if p.act == 0x6D and p.act_count == 5 and p.act_frame == 0 then
							p.write_bs_hook({ id = 0x00, ver = 0x1EFF, bs = false, name = "ホーネットアタック", })
						end
					elseif p.char == 3 then
						-- ジョー
						if p.act == 0x70 and p.act_count == 0 and p.act_frame == 11 then
							cmd_base._2c(p, next_joy)
						end
					elseif p.char == 5 then
						-- ギース
						if p.act == 0x6D and p.act_count == 0 and p.act_frame == 0 then
							p.write_bs_hook({ id = 0x50, ver = 0x0600, bs = false, name = "絶命人中打ち", })
						end
					elseif p.char == 6 then
						-- 双角
						if p.act == 0x6D and p.act_count == 0 and p.act_frame == 0 then
							p.write_bs_hook({ id = 0x50, ver = 0x0600, bs = false, name = "地獄門", })
						end
					elseif p.char == 9 then
						-- マリー
						if p.act == 0x6D and p.act_count == 0 and p.act_frame == 0 then
							p.write_bs_hook({ id = 0x50, ver = 0x0600, bs = false, name = "アキレスホールド", })
						end
					elseif p.char == 22 then
						if p.act == 0xA1 and p.act_count == 6 and p.act_frame >= 0 then
							p.write_bs_hook({ id = 0x03, ver = 0x06FF, bs = false, name = "閃里肘皇", })
						end
					end
				end
				-- 自動超白龍
				if 1 < global.auto_input.pairon and p.char == 22 then
					if p.act == 0x43 and p.act_count >= 0 and p.act_count <= 3 and p.act_frame >= 0 and 2 == global.auto_input.pairon then
						p.write_bs_hook({ id = 0x11, ver = 0x06FD, bs = false, name = "超白龍", })
					elseif p.act == 0x43 and p.act_count == 3 and p.act_count <= 3 and p.act_frame >= 0 and 3 == global.auto_input.pairon then
						p.write_bs_hook({ id = 0x11, ver = 0x06FD, bs = false, name = "超白龍", })
					elseif p.act == 0x9F and p.act_count == 2 and p.act_frame >= 0 then
						--p.write_bs_hook({ id = 0x00, ver = 0x06FE, bs = false, name = "閃里肘皇・心砕把", })
					end
					--p.write_bs_hook({ id = 0x00, ver = 0x06FD, bs = false, name = "超白龍2", })
				end
				-- 自動M.リアルカウンター
				if 1 < global.auto_input.real_counter and p.char == 9 then
					if p.act == 0xA5 and p.act_count == 0 then
						local real_tw = global.auto_input.real_counter == 5 and math.random(2, 4) or global.auto_input.real_counter
						if 2 == real_tw then
							cmd_base._a(p, next_joy)
						elseif 3 == real_tw then
							cmd_base._b(p, next_joy)
						elseif 4 == real_tw then
							cmd_base._c(p, next_joy)
						end
					end
				end

				-- ブレイクショット
				if p.dummy_gd == dummy_gd_type.bs and p.on_block == global.frame_number then
					p.bs_count = (p.bs_count < 1) and 1 or p.bs_count + 1
					if global.dummy_bs_cnt <= p.bs_count and p.dummy_bs then
						input_bs()
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

		-- ヒットしない処理のデータ更新
		for _, p in ipairs(players) do
			pgm:write_u8(p.addr.no_hit, p.no_hit_limit == 0 and 0xFF or (p.no_hit_limit - 1))
		end

		-- Y座標強制
		for _, p in ipairs(players) do
			if p.force_y_pos > 1 then
				pgm:write_i16(p.addr.pos_y, force_y_pos[p.force_y_pos])
			end
		end
		-- X座標同期とY座標をだいぶ下に
		if global.sync_pos_x ~= 1 then
			local from = global.sync_pos_x - 1
			local to   = 3 - from
			pgm:write_i16(players[to].addr.pos, players[from].pos)
			pgm:write_i16(players[to].addr.pos_y, players[from].pos_y - 124)
		end

		-- 強制ポーズ処理
		global.pause = false
		for _, p in ipairs(players) do
			-- 判定が出たらポーズさせる
			for _, box in ipairs(p.hitboxes) do
				if (box.type.type == "throw" and global.pause_hitbox == 2) or
					((box.type.type == "attack" or box.type.type == "atemi") and global.pause_hitbox == 3) then
					global.pause = true
					break
				end
			end
			for _, fb in pairs(p.fireball) do
				for _, box in ipairs(fb.hitboxes) do
					if (box.type.type == "throw" and global.pause_hitbox == 2) or
						(box.type.type == "attack" and global.pause_hitbox == 3) then
						global.pause = true
						break
					end
				end
			end

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

	local draw_summary = function(i, summary)
		if summary == nil or #summary == 0 then
			return summary
		end
		local x, y = i == 1 and 162 or 2, 2
		scr:draw_box(x - 2, y - 2, x + 158, y + 2 + 7 * #summary, 0x80404040, 0x80404040)
		for _, row in ipairs(summary) do
			local k, v, frame = row[1], row[2], row[3] or 0
			local col = global.frame_number == frame and 0xFF00FFFF or 0xFFFFFFFF
			scr:draw_text(x, y, k, col)
			if v then
				if type(v) == "number" then
					scr:draw_text(x + 47, y, v .. "", col)
				else
					scr:draw_text(x + 47, y, v, col)
				end
			end
			y = y + 7
		end
	end

	local draw_hitbox = function(left, top, right, bottom, outline, fill, over_left, over_top, over_right, over_bottom)
		if outline and 0 < outline then
			if over_left ~= true then
				scr:draw_box(left, top, left + 1, bottom, 0, outline)
			end
			if over_top ~= true then
				scr:draw_box(left, top, right, top + 1, 0, outline)
			end
			if over_right ~= true then
				scr:draw_box(right + 1, top, right, bottom, 0, outline)
			end
			if over_bottom ~= true then
				scr:draw_box(left, bottom + 1, right, bottom, 0, outline)
			end
		end
		if fill and 0 < fill then
			scr:draw_box(left, top, right, bottom, outline, fill)
		end
	end
	local draw_vline = function(x1, y1, y2, color)
		scr:draw_box(x1, y1, x1 + 1, y2 + 1, 0, color)
	end
	local draw_hline = function(x1, x2, y1, color)
		scr:draw_box(x1, y1, x2 + 1, y1 + 1, 0, color)
	end
	local draw_axis = function(i, p, x, col)
		if x then
			local axis = p.disp_hitbox == 2 and global.axis_size or global.axis_size2
			draw_vline(x, p.hit.pos_y - axis, p.hit.pos_y + axis, col)
			draw_hline(x - axis, x + axis, p.hit.pos_y, col)
			if p.disp_hitbox == 2 then
				draw_text_with_shadow(x - 1.5, p.hit.pos_y + axis, string.format("%d", i), col)
			end
		end
	end
	local draw_esaka = function(i, x, col)
		if x and 0 <= x then
			local y1, y2 = 0, 200 + global.axis_size
			draw_vline(x, y1, y2, col)
			draw_text_with_shadow(x - 2.5, y2, string.format("え%d", i), col)
		end
	end
	local draw_close_far = function(i, p, btn, x1, x2)
		local op = p.op
		if x1 and x2 then
			local diff = math.abs(p.pos - op.pos)
			local in_range = x1 <= diff and diff <= x2
			x1 = p.hit.pos_x + x1 * p.side
			x2 = p.hit.pos_x + x2 * p.side
			-- 間合い
			local color = in_range and 0xFFFFFF00 or 0xFFBBBBBB
			draw_hline(x2 - 2, x2 + 2, p.hit.pos_y, color)
			draw_vline(x2, p.hit.pos_y - 2, p.hit.pos_y + 2, color)
			if in_range then
				draw_text_with_shadow(x2 - 2.5, p.hit.pos_y + 4, string.format("%s%d", btn, i), color)
			end
		end
	end

	local table_add_all = function(t1, t2, pre_add)
		for _, r in ipairs(t2) do
			if pre_add then
				pre_add(r)
			end
			table.insert(t1, r)
		end
	end

	menu.tra_main.draw = function()
		-- メイン処理
		if match_active then
			-- 判定表示（キャラ、飛び道具）
			local hitboxes = {}
			for _, p in ipairs(players) do
				if p.disp_hitbox > 1 then
					local callback = nil
					if p.disp_hitbox == 3 then
						callback = function(box)
							box.type_count = nil
						end
					end
					table_add_all(hitboxes, p.hitboxes, callback)
					for _, fb in pairs(p.fireball) do
						if fb.hitboxes == nil then
							-- ラウンド開始直後のラグ扱いフレームでエラーが出るのでスキップする
							return
						end
						table_add_all(hitboxes, fb.hitboxes, callback)
					end
				end
			end
			table.sort(hitboxes, function(box1, box2)
				return (box1.type.sort < box2.type.sort)
			end)
			for _, box in ipairs(hitboxes) do
				if box.flat_throw then
					if box.visible == true and box.type.enabled == true then
						if global.no_background ~= true then
							draw_hitbox(box.left, box.top - 8, box.right, box.bottom + 8, box.type.fill, box.type.fill)
						end
						draw_hline(box.left, box.right, box.bottom, box.type.outline)
						draw_vline(box.left, box.top - 8, box.bottom + 8, box.type.outline)
						draw_vline(box.right, box.top - 8, box.bottom + 8, box.type.outline)
					end
				else
					if box.visible == true and box.type.enabled == true then
						-- 背景なしの場合は判定の塗りつぶしをやめる
						if global.no_background then
							draw_hitbox(box.left, box.top, box.right, box.bottom, box.type.outline, 0,
								box.over_left, box.over_top, box.over_right, box.over_bottom)
						else
							draw_hitbox(box.left, box.top, box.right, box.bottom, box.type.outline, box.type.fill,
								box.over_left, box.over_top, box.over_right, box.over_bottom)
						end
						if box.type_count then
							local x1, x2 = math.min(box.left, box.right), math.max(box.left, box.right)
							local y1, y2 = math.min(box.top, box.bottom), math.max(box.top, box.bottom)
							local x = math.floor((x2 - x1) / 2) + x1 - 2
							local y = math.floor((y2 - y1) / 2) + y1 - 4
							scr:draw_text(x + 0.5, y + 0.5, box.type_count .. "", shadow_col)
							scr:draw_text(x, y, box.type_count .. "", box.type.outline)
						end
					end
				end
			end

			-- 座標表示
			for i, p in ipairs(players) do
				if p.in_air ~= true and p.sway_status == 0x00 then
					-- 通常投げ間合い
					if p.disp_range == 2 or p.disp_range == 3 then
						local color = p.throw.in_range and 0xFFFFFF00 or 0xFFBBBBBB
						draw_hline(p.throw.x1, p.throw.x2, p.hit.pos_y, color)
						draw_vline(p.throw.x1, p.hit.pos_y - 4, p.hit.pos_y + 4, color)
						draw_vline(p.throw.x2, p.hit.pos_y - 4, p.hit.pos_y + 4, color)
						if p.throw.in_range then
							draw_text_with_shadow(p.throw.x1 + 2.5, p.hit.pos_y + 4, string.format("投%d", i), color)
						end
					end

					-- 地上通常技の遠近判断距離
					if p.disp_range == 2 or p.disp_range == 4 then
						for btn, range in pairs(p.close_far) do
							draw_close_far(i, p, string.upper(btn), range.x1, range.x2)
						end
					end
				elseif p.sway_status == 0x80 then
					-- ライン移動技の遠近判断距離
					if p.disp_range == 2 or p.disp_range == 4 then
						for btn, range in pairs(p.close_far_lma) do
							draw_close_far(i, p, string.upper(btn), range.x1, range.x2)
						end
					end
				elseif p.air_throw.can_throw == true or p.air_throw.on == 0x1 then
					-- 通常投げ間合い
					if p.disp_range == 2 or p.disp_range == 3 then
						local color = p.air_throw.in_range and 0xFFFFFF00 or 0xFFBBBBBB
						draw_hitbox(
							p.air_throw.x1 + p.hit.pos_x,
							p.air_throw.y1 + p.hit.old_pos_y,
							p.air_throw.x2 + p.hit.pos_x,
							p.air_throw.y2 + p.hit.old_pos_y,
							color,
							0,
							false, false, false, false)
						if p.air_throw.in_range then
							draw_text_with_shadow(p.air_throw.x1 + 2.5, 0, string.format("投%d", i), color)
						end
					end
				end

				-- 詠酒範囲
				if p.disp_range == 2 or p.disp_range == 5 then
					if p.esaka_range > 0 then
						draw_esaka(i, p.hit.pos_x + p.esaka_range, global.axis_internal_color)
						draw_esaka(i, p.hit.pos_x - p.esaka_range, global.axis_internal_color)
					end
				end

				-- 中心座標
				if p.disp_hitbox > 1 then
					draw_axis(i, p, p.hit.pos_x, p.in_air == true and global.axis_air_color or global.axis_color)
					if p.disp_hitbox == 2 then
						draw_axis(i, p, p.hit.max_pos_x, global.axis_internal_color)
						draw_axis(i, p, p.hit.min_pos_x, global.axis_internal_color)
					end
				end
			end

			-- スクショ保存
			for _, p in ipairs(players) do
				local chg_y = p.chg_air_state ~= 0
				local chg_act = p.old_act_normal ~= p.act_normal
				local chg_hit = p.chg_hitbox_frm == global.frame_number
				local chg_hurt = p.chg_hurtbox_frm == global.frame_number
				local chg_sway = p.on_sway_line == global.frame_number or p.on_main_line == global.frame_number
				local chg_actc = p.atk_count ~= 1 and (p.old_act_count ~= p.act_count)
				for _, fb in pairs(p.fireball) do
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
					mkdir(dir_name)
					dir_name = dir_name .. "/" .. p.char_data.names2
					mkdir(dir_name)
					if p.slide_atk then
						sub_name = "_SLIDE_"
					elseif p.bs_atk then
						sub_name = "_BS_"
					end
					name = string.format("%s%s%04x_%s_%03d", p.char_data.names2, sub_name, p.act_data.id_1st or 0, name, p.atk_count)
					dir_name = dir_name .. string.format("/%04x", p.act_data.id_1st or 0)
					mkdir(dir_name)

					-- ファイル名を設定してMAMEのスクショ機能で画像保存
					local filename, dowrite = dir_name .. "/" .. name .. ".png", false
					if is_file(filename) then
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
					for k = 1, #p.key_hist do
						draw_cmd(i, k, p.key_frames[k], p.key_hist[k])
					end
					draw_cmd(i, #p.key_hist + 1, 0, "")
				end
			end

			-- ベースアドレス表示
			for i, p in ipairs(players) do
				for k = 1, #p.bases do
					if p.disp_base then
						draw_base(i, k, p.bases[k].count, p.bases[k].addr, p.bases[k].name, p.bases[k].xmov)
					end
				end
			end
			-- ダメージとコンボ表示
			for i, p in ipairs(players) do
				local p1 = i == 1
				local op = p.op

				-- コンボ表示などの四角枠
				if p.disp_dmg then
					if p1 then
						scr:draw_box(184 + 40, 40, 274 + 40, 84, 0x80404040, 0x80404040)
					else
						scr:draw_box(45 - 40, 40, 134 - 40, 84, 0x80404040, 0x80404040)
					end

					-- コンボ表示
					scr:draw_text(p1 and 228 or 9, 41, "補正:")
					scr:draw_text(p1 and 228 or 9, 48, "ダメージ:")
					scr:draw_text(p1 and 228 or 9, 55, "コンボ:")
					scr:draw_text(p1 and 228 or 9, 62, "気絶値:")
					scr:draw_text(p1 and 228 or 9, 69, "気絶値持続:")
					scr:draw_text(p1 and 228 or 9, 76, "POW:")
					draw_rtext(p1 and 296 or 77, 41, string.format("%s>%s(%s%%)", p.last_pure_dmg, op.last_dmg, (op.last_dmg_scaling - 1) * 100))
					draw_rtext(p1 and 296 or 77, 48, string.format("%s(+%s)", op.last_combo_dmg, op.last_dmg))
					draw_rtext(p1 and 296 or 77, 55, op.last_combo)
					draw_rtext(p1 and 296 or 77, 62, string.format("%s(+%s)", op.last_combo_stun, op.last_stun))
					draw_rtext(p1 and 296 or 77, 69, string.format("%s(+%s)", op.last_combo_st_timer, op.last_st_timer))
					draw_rtext(p1 and 296 or 77, 76, string.format("%s(+%s)", op.last_combo_pow, op.last_pow))
					scr:draw_text(p1 and 301 or 82, 41, "最大")
					draw_rtext(p1 and 311 or 92, 48, op.max_dmg)
					draw_rtext(p1 and 311 or 92, 55, op.max_combo)
					draw_rtext(p1 and 311 or 92, 62, op.max_disp_stun)
					draw_rtext(p1 and 311 or 92, 69, op.max_st_timer)
					draw_rtext(p1 and 311 or 92, 76, op.max_combo_pow)
				end

				-- 状態 小表示
				if p.disp_sts == 2 or p.disp_sts == 3 then
					scr:draw_box(p1 and 2 or 277, 0, p1 and 40 or 316, 36, 0x80404040, 0x80404040)

					scr:draw_text(p1 and 4 or 278, 1, string.format("%s", p.state))
					draw_rtext(p1 and 16 or 290, 1, string.format("%02s", p.tw_threshold))
					draw_rtext(p1 and 28 or 302, 1, string.format("%03s", p.tw_accepted))
					draw_rtext(p1 and 40 or 314, 1, string.format("%03s", p.tw_frame))

					local diff_pos_y = p.pos_y + p.pos_frc_y - p.old_pos_y - p.old_pos_frc_y
					draw_rtext(p1 and 16 or 290, 7, string.format("%0.03f", diff_pos_y))
					draw_rtext(p1 and 40 or 314, 7, string.format("%0.03f", p.pos_y + p.pos_frc_y))

					draw_rtext(p1 and 16 or 290, 13, string.format("%02x", p.attack))
					draw_rtext(p1 and 28 or 302, 13, string.format("%02x", p.attack_id))
					draw_rtext(p1 and 40 or 314, 13, string.format("%02x", p.hitstop_id))

					draw_rtext(p1 and 16 or 290, 19, string.format("%04x", p.act))
					draw_rtext(p1 and 28 or 302, 19, string.format("%02x", p.act_count))
					draw_rtext(p1 and 40 or 314, 19, string.format("%02x", p.act_frame))

					draw_rtext(p1 and 16 or 290, 25, string.format("%02x", p.hurt_state))
					draw_rtext(p1 and 28 or 302, 25, string.format("%02x", p.sway_status))
					draw_rtext(p1 and 40 or 314, 25, string.format("%02x", p.additional))

					--[[
						p.tw_frame のしきい値。しきい値より大きければ投げ処理継続可能。
						0  空投げ M.スナッチャー0
						10 真空投げ 羅生門 鬼門陣 M.タイフーン M.スパイダー 爆弾パチキ ドリル ブレスパ ブレスパBR リフトアップブロー デンジャラススルー ギガティックサイクロン マジンガ STOL
						20 M.リアルカウンター投げ
						24 通常投げ しんさいは
					]]
					if not p.hit.vulnerable or not p.n_throwable or not p.throwable then
						local throw_txt = p.throwable and "" or "投"
						if p.tw_frame <= 10 then
							throw_txt = throw_txt .. "<"
						end
						if p.tw_frame <= 20 then
							throw_txt = throw_txt .. "<"
						end
						scr:draw_text(p1 and 1 or 275, 31, "無敵")
						scr:draw_text(p1 and 15 or 289, 31, p.hit.vulnerable and "" or "打")
						scr:draw_text(p1 and 24 or 298, 31, p.n_throwable and "" or "通")
						scr:draw_text(p1 and 30 or 304, 31, p.throwable and "" or throw_txt)
					end
				end

				-- コマンド入力状態表示
				if global.disp_input_sts - 1 == i then
					local col_orange = 0xFFFF8800
					local col_orange2 = 0xC0FF8800
					local col_red = 0xFFFF0000
					local col_green = 0xC07FFF00
					local col_green2 = 0xFF7FFF00
					local col_yellow = 0xC0FFFF00
					local col_yellow2 = 0xFFFFFF00
					local col_white = 0xC0FFFFFF
					for ti, input_state in ipairs(p.input_states) do
						local x = 147
						local y = 25 + ti * 5
						local x1, x2, y2 = x + 15, x - 8, y + 4
						draw_text_with_shadow(x1, y - 2, input_state.tbl.name,
							input_state.input_estab == true and col_orange2 or col_white)
						if input_state.on > 0 and input_state.chg_remain > 0 then
							local col, col2
							if input_state.charging == true then
								col, col2 = col_green, col_green2
							else
								col, col2 = col_yellow, col_yellow2
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
										input_state.input_estab == true and col_orange or
										input_state.on > ci and col_red or
										(ci == 1 and input_state.on >= ci) and col_red or nil))
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
				if p.dummy_gd == dummy_gd_type.bs and global.no_background ~= true then
					if p1 then
						scr:draw_box(106, 40, 150, 50, 0x80404040, 0x80404040)
					else
						scr:draw_box(169, 40, 213, 50, 0x80404040, 0x80404040)
					end
					scr:draw_text(p1 and 115 or 180, 41, "回ガードでB.S.")
					draw_rtext(p1 and 115 or 180, 41, global.dummy_bs_cnt - math.max(p.bs_count, 0))
				end

				-- ガードリバーサル状態表示
				if p.dummy_wakeup == wakeup_type.rvs and global.no_background ~= true then
					if p1 then
						scr:draw_box(106, 50, 150, 60, 0x80404040, 0x80404040)
					else
						scr:draw_box(169, 50, 213, 60, 0x80404040, 0x80404040)
					end
					scr:draw_text(p1 and 115 or 180, 51, "回ガードでG.R.")
					local count = 0
					if p.gd_rvs_enabled and global.dummy_rvs_cnt > 1 then
						count = 0
					else
						count = global.dummy_rvs_cnt - math.max(p.rvs_count, 0)
					end
					draw_rtext(p1 and 115 or 180, 51, count)
				end

				-- 気絶表示
				if p.disp_stun then
					scr:draw_box(p1 and (138 - p.max_stun) or 180, 29, p1 and 140 or (182 + p.max_stun), 34, 0, 0xDDC0C0C0) -- 枠
					scr:draw_box(p1 and (139 - p.max_stun) or 181, 30, p1 and 139 or (181 + p.max_stun), 33, 0, 0xDD000000) -- 黒背景
					scr:draw_box(p1 and (139 - p.stun) or 181, 30, p1 and 139 or (181 + p.stun), 33, 0, 0xDDFF0000) -- 気絶値
					draw_rtext_with_shadow(p1 and 135 or 190, 28, p.stun)

					scr:draw_box(p1 and (138 - 90) or 180, 35, p1 and 140 or (182 + 90), 40, 0, 0xDDC0C0C0)      -- 枠
					scr:draw_box(p1 and (139 - 90) or 181, 36, p1 and 139 or (181 + 90), 39, 0, 0xDD000000)      -- 黒背景
					scr:draw_box(p1 and (139 - p.stun_timer) or 181, 36, p1 and 139 or (181 + p.stun_timer), 39, 0, 0xDDFFFF00) -- 気絶値
					draw_rtext_with_shadow(p1 and 135 or 190, 34, p.stun_timer)
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
						for base, _ in pairs(p.fireball_bases) do
							local fb = p.fireball[base]
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
					draw_text_with_shadow(30, p1 and 52 or 58, p.last_frame_info_txt or "")
					if p.on_punish > 0 and p.on_punish <= global.frame_number then
						if p1 then
							draw_rtext_with_shadow(155, 46, "PUNISH", col2(p.on_punish))
						else
							draw_text_with_shadow(170, 46, "PUNISH", col2(p.on_punish))
						end
					end
				end
			end

			for i, p in ipairs(players) do
				if p.disp_sts == 2 or p.disp_sts == 4 then
					draw_summary(i, p.all_summary)
				end
			end

			-- キャラ間の距離表示
			local abs_space = math.abs(p_space)
			if global.disp_pos then
				local y = 216 -- math.floor(get_digit(abs_space)/2)
				draw_rtext_with_shadow(167, y, abs_space)

				-- キャラの向き
				for i, p in ipairs(players) do
					local p1     = i == 1
					local side   = p.side == 1 and "(>)" or "(<)" -- 内部の向き 1:右向き -1:左向き
					local i_side = p.input_side == 0x00 and "[>]" or "[<]" -- コマンド入力でのキャラ向きチェック用 00:左側 80:右側 -- p.poslr
					if p1 then
						local flip_x = p.disp_side == 1 and ">" or "<" -- 判定の向き 1:右向き -1:左向き
						draw_rtext_with_shadow(150, y, string.format("%s%s%s", flip_x, side, i_side))
					else
						local flip_x = p.disp_side == 1 and "<" or ">" -- 判定の向き 1:左向き -1:右向き
						draw_text_with_shadow(170, y, string.format("%s%s%s", i_side, side, flip_x))
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

		-- ログ
		local log = ""
		for _, p in ipairs(players) do
			log = log .. string.format(
				"%6x %1s %1s %s %4x %4x %4x ",
				p.addr.base,
				p.char,
				p.state,
				p.act_contact,
				p.act,
				p.acta,
				p.attack
			--,	p.act_count, p.act_frame
			)
			for _, box in ipairs(p.hitboxes) do
				local atk, air = " ", " "

				if box.type == box_type_base.a then
					atk, air = "A", " "
				elseif box.type == box_type_base.da then
					atk, air = "A", " "
				elseif box.type == box_type_base.aa then
					atk, air = "A", "A"
				elseif box.type == box_type_base.daa then
					atk, air = "A", "A"
				end
				log = log .. string.format("%2x %1s %1s ", box.id or 0xFF, atk, air)

				local tw, range = " ", " "
				if box.type == box_type_base.t then
					tw, range = "NT", string.format("%sx%s", math.abs(box.left - box.right), math.abs(box.top - box.bottom))
				elseif box.type == box_type_base.at then
					tw, range = "AT", string.format("%sx%s", math.abs(box.left - box.right), math.abs(box.top - box.bottom))
				elseif box.type == box_type_base.pt then
					tw, range = "PT", string.format("%sx%s", math.abs(box.left - box.right), math.abs(box.top - box.bottom))
				else
					tw, range = "", ""
				end
				log = log .. string.format("%2x %1s %1s ", box.id or 0xFF, tw, range)
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
			local tmp_chr = pgm:read_u8(p.addr.char)

			-- ブレイクショット
			if not p.dummy_bs_chr or p.dummy_bs_chr ~= tmp_chr then
				p.char = tmp_chr
				p.dummy_bs_chr = p.char
				p.dummy_bs_list = {}
				p.dummy_bs = get_next_bs(p)
			end

			-- リバーサル
			if not p.dummy_rvs_chr or p.dummy_rvs_chr ~= tmp_chr then
				p.char = tmp_chr
				p.dummy_rvs_chr = tmp_chr
				p.dummy_rvs_list = {}
				p.dummy_rvs = get_next_rvs(p)
			end

			p.char_data      = chars[p.char]
			p.gd_rvs_enabled = false
			p.rvs_count      = -1
		end
	end
	local menu_to_main = function(cancel, do_init)
		local col               = menu.training.pos.col
		local row               = menu.training.pos.row
		local p                 = players

		global.dummy_mode       = col[1]  -- ダミーモード
		-- レコード・リプレイ設定
		p[1].dummy_act          = col[3]  -- 1P アクション
		p[2].dummy_act          = col[4]  -- 2P アクション
		p[1].dummy_gd           = col[5]  -- 1P ガード
		p[2].dummy_gd           = col[6]  -- 2P ガード
		global.next_block_grace = col[7] - 1 -- 1ガード持続フレーム数
		global.dummy_bs_cnt     = col[8]  -- ブレイクショット設定
		p[1].dummy_wakeup       = col[9]  -- 1P やられ時行動
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
				p.next_block = false
				p.next_block_ec = 75 -- カウンター初期化
			elseif p.dummy_gd == dummy_gd_type.block1 then
				p.next_block = true
				p.next_block_ec = 75 -- カウンター初期化
			end
			p.bs_count = -1 -- BSガードカウンター初期化
			p.rvs_count = -1 -- リバサカウンター初期化
			p.block1 = 0
			p.dummy_rvs_chr = p.char
			p.dummy_rvs = get_next_rvs(p)
			p.dummy_bs_chr = p.char
			p.dummy_bs = get_next_bs(p)
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
			menu.replay.pos.col[14] = global.replay_fix_pos        -- 開始間合い固定
			menu.replay.pos.col[15] = global.replay_reset          -- 状態リセット
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
				if not cancel and row == (8 + i) and (p.dummy_wakeup == wakeup_type.tech or p.dummy_wakeup == wakeup_type.sway or p.dummy_wakeup == wakeup_type.rvs) then
					menu.current = menu.rvs_menus[i][p.char]
					return
				end
			end
		end

		menu.current = menu.main
	end
	local menu_to_main_cancel = function()
		menu_to_main(true, false)
	end
	local life_range = { "最大", "赤", "ゼロ", }
	for i = 1, 0xC0 do
		table.insert(life_range, i)
	end
	local pow_range = { "最大", "半分", "ゼロ", }
	for i = 1, 0x3C do
		table.insert(pow_range, i)
	end
	local bar_menu_to_main         = function(cancel)
		local col                = menu.bar.pos.col
		local p                  = players
		--  タイトルラベル
		p[1].red                 = col[2] -- 1P 体力ゲージ量
		p[2].red                 = col[3] -- 2P 体力ゲージ量
		p[1].max                 = col[4] -- 1P POWゲージ量
		p[2].max                 = col[5] -- 2P POWゲージ量
		dip_config.infinity_life = col[6] == 2 -- 体力ゲージモード
		global.pow_mode          = col[7] -- POWゲージモード

		menu.current                 = menu.main
	end
	local bar_menu_to_main_cancel  = function()
		bar_menu_to_main(true)
	end
	local disp_menu_to_main        = function(cancel)
		local col             = menu.disp.pos.col
		local p               = players
		--  タイトルラベル
		p[1].disp_hitbox        = col[2]   -- 1P 判定表示
		p[2].disp_hitbox        = col[3]   -- 2P 判定表示
		p[1].disp_range         = col[4]   -- 1P 間合い表示
		p[2].disp_range         = col[5]   -- 2P 間合い表示
		p[1].disp_stun          = col[6] == 2 -- 1P 気絶ゲージ表示
		p[2].disp_stun          = col[7] == 2 -- 2P 気絶ゲージ表示
		p[1].disp_dmg           = col[8] == 2 -- 1P ダメージ表示
		p[2].disp_dmg           = col[9] == 2 -- 2P ダメージ表示
		p[1].disp_cmd           = col[10]  -- 1P 入力表示
		p[2].disp_cmd           = col[11]  -- 2P 入力表示
		global.disp_input_sts   = col[12]  -- コマンド入力状態表示
		global.disp_normal_frms = col[13]  -- 通常動作フレーム非表示
		global.disp_frmgap      = col[14]  -- フレーム差表示
		p[1].disp_frm           = col[15]  -- 1P フレーム数表示
		p[2].disp_frm           = col[16]  -- 2P フレーム数表示
		p[1].disp_fbfrm         = col[17] == 2 -- 1P 弾フレーム数表示
		p[2].disp_fbfrm         = col[18] == 2 -- 2P 弾フレーム数表示
		p[1].disp_sts           = col[19]  -- 1P 状態表示
		p[2].disp_sts           = col[20]  -- 2P 状態表示
		p[1].disp_base          = col[21] == 2 -- 1P 処理アドレス表示
		p[2].disp_base          = col[22] == 2 -- 2P 処理アドレス表示
		global.disp_pos         = col[23] == 2 -- 1P 2P 距離表示
		p[1].disp_char          = col[24] == 2 -- 1P キャラ表示
		p[2].disp_char          = col[25] == 2 -- 2P キャラ表示
		global.disp_effect      = col[26] == 2 -- エフェクト表示
		menu.current            = menu.main
	end
	local disp_menu_to_main_cancel = function()
		disp_menu_to_main(true)
	end
	local ex_menu_to_main          = function(cancel)
		local col             = menu.extra.pos.col
		local p               = players
		-- タイトルラベル
		dip_config.easy_super = col[2] == 2               -- 簡易超必
		dip_config.semiauto_p = col[3] == 2               -- 半自動潜在能力
		p[1].dis_plain_shift  = col[4] == 2 or col[4] == 3 -- ライン送らない現象
		p[2].dis_plain_shift  = col[4] == 2 or col[4] == 4 -- ライン送らない現象
		global.pause_hit      = col[5]                    -- ヒット時にポーズ
		global.pause_hitbox   = col[6]                    -- 判定発生時にポーズ
		global.save_snapshot  = col[7]                    -- 技画像保存
		global.mame_debug_wnd = col[8] == 2               -- MAMEデバッグウィンドウ
		global.damaged_move   = col[9]                    -- ヒット効果確認用
		global.log.poslog     = col[10] == 2              -- 位置ログ
		global.log.atklog     = col[11] == 2              -- 攻撃情報ログ
		global.log.baselog    = col[12] == 2              -- 処理アドレスログ
		global.log.keylog     = col[13] == 2              -- 入力ログ
		global.log.rvslog     = col[14] == 2              -- リバサログ

		local dmove           = damaged_moves[global.damaged_move]
		if dmove and dmove > 0 then
			for i = 0x0579BA, 0x057B02, 4 do
				pgm:write_direct_u32(fix_bp_addr(i), dmove == 0 and 0 or fix_bp_addr(dmove))
			end
		else
			local ii = 2
			for i = 0x0579BA, 0x057B02, 4 do
				local dmove = damaged_moves[ii]
				pgm:write_direct_u32(fix_bp_addr(i), dmove == 0 and 0 or fix_bp_addr(dmove))
				ii = ii + 1
			end
		end

		menu.current = menu.main
	end
	local ex_menu_to_main_cancel   = function()
		ex_menu_to_main(true)
	end
	local auto_menu_to_main        = function(cancel)
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
		global.auto_input.esaka_check   = col[14] == 2 -- 詠酒距離チェック
		global.auto_input.fast_kadenzer = col[15] == 2 -- 必勝！逆襲拳
		global.auto_input.kara_ca       = col[16] == 2 -- 空振りCA

		for _, p in ipairs(players) do
			set_auto_deadly(p, global.auto_input.rave)
			set_auto_unlimit(p, global.auto_input.desire)
			set_auto_drill(p, global.auto_input.drill)
			set_skip_esaka_check(p, global.auto_input.esaka_check)
			set_auto_taneuma(p, global.auto_input.auto_taneuma)
			set_fast_kadenzer(p, global.auto_input.fast_kadenzer)
			set_auto_katsu(p, global.auto_input.auto_katsu)
			set_kara_ca(p, global.auto_input.kara_ca)
			set_auto_3ecst(p, global.auto_input.auto_3ecst)
		end
		menu.current = menu.main
	end
	local auto_menu_to_main_cancel = function()
		auto_menu_to_main(true)
	end
	local box_type_col_list        = {
		box_type_base.a, box_type_base.fa, box_type_base.da, box_type_base.aa, box_type_base.faa, box_type_base.daa,
		box_type_base.pa, box_type_base.pfa, box_type_base.pda, box_type_base.paa, box_type_base.pfaa, box_type_base.pdaa,
		box_type_base.t3, box_type_base.t, box_type_base.at, box_type_base.pt,
		box_type_base.p, box_type_base.v1, box_type_base.sv1, box_type_base.v2, box_type_base.sv2, box_type_base.v3,
		box_type_base.v4, box_type_base.v5, box_type_base.v6, box_type_base.x1, box_type_base.x2, box_type_base.x3,
		box_type_base.x4, box_type_base.x5, box_type_base.x6, box_type_base.x7, box_type_base.x8, box_type_base.x9,
		box_type_base.g1, box_type_base.g2, box_type_base.g3, box_type_base.g4, box_type_base.g5, box_type_base.g6,
		box_type_base.g7, box_type_base.g8, box_type_base.g9, box_type_base.g10, box_type_base.g11, box_type_base.g12,
		box_type_base.g13, box_type_base.g14, box_type_base.g15, box_type_base.g16, }
	local col_menu_to_main         = function(cancel)
		local col = menu.color.pos.col

		for i = 2, #col do
			box_type_col_list[i - 1].enabled = col[i] == 2
		end

		menu.current = menu.main
	end
	local col_menu_to_main_cancel  = function()
		col_menu_to_main(true)
	end
	local menu_rec_to_tra          = function() menu.current = menu.training end
	local exit_menu_to_rec         = function(slot_no)
		local ec              = scr:frame_number()
		global.dummy_mode     = 5
		global.rec_main       = rec_await_no_input
		global.input_accepted = ec
		-- 選択したプレイヤー側の反対側の操作をいじる
		recording.temp_player = (pgm:read_u8(players[1].addr.reg_pcnt) ~= 0xFF) and 2 or 1
		recording.last_slot   = slot_no
		recording.active_slot = recording.slot[slot_no]
		menu.current              = menu.main
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
		recording.temp_player = (pgm:read_u8(players[1].addr.reg_pcnt) ~= 0xFF) and 2 or 1
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
		col[2] = p[1].disp_hitbox      -- 判定表示
		col[3] = p[2].disp_hitbox      -- 判定表示
		col[4] = p[1].disp_range       -- 間合い表示
		col[5] = p[2].disp_range       -- 間合い表示
		col[6] = p[1].disp_stun and 2 or 1 -- 1P 気絶ゲージ表示
		col[7] = p[2].disp_stun and 2 or 1 -- 2P 気絶ゲージ表示
		col[8] = p[1].disp_dmg and 2 or 1 -- 1P ダメージ表示
		col[9] = p[2].disp_dmg and 2 or 1 -- 2P ダメージ表示
		col[10] = p[1].disp_cmd        -- 1P 入力表示
		col[11] = p[2].disp_cmd        -- 2P 入力表示
		col[12] = g.disp_input_sts     -- コマンド入力状態表示
		col[13] = g.disp_normal_frms   -- 通常動作フレーム非表示
		col[14] = g.disp_frmgap        -- フレーム差表示
		col[15] = p[1].disp_frm        -- 1P フレーム数表示
		col[16] = p[2].disp_frm        -- 2P フレーム数表示
		col[17] = p[1].disp_fbfrm and 2 or 1 -- 1P 弾フレーム数表示
		col[18] = p[2].disp_fbfrm and 2 or 1 -- 2P 弾フレーム数表示
		col[19] = p[1].disp_sts        -- 1P 状態表示
		col[20] = p[2].disp_sts        -- 2P 状態表示
		col[21] = p[1].disp_base and 2 or 1 -- 1P 処理アドレス表示
		col[22] = p[2].disp_base and 2 or 1 -- 2P 処理アドレス表示
		col[23] = g.disp_pos and 2 or 1 -- 1P 2P 距離表示
		col[24] = p[1].disp_char and 2 or 1 -- 1P キャラ表示
		col[25] = p[2].disp_char and 2 or 1 -- 2P キャラ表示
		col[26] = g.disp_effect and 2 or 1 -- エフェクト表示
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
		col[10] = g.log.poslog and 2 or 1 -- 位置ログ
		col[11] = g.log.atklog and 2 or 1 -- 攻撃情報ログ
		col[12] = g.log.baselog and 2 or 1 -- 処理アドレスログ
		col[13] = g.log.keylog and 2 or 1 -- 入力ログ
		col[14] = g.log.rvslog and 2 or 1 -- リバサログ
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
		col[14] = global.auto_input.esaka_check and 2 or 1 -- 詠酒距離チェック
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
		cls_hook()
		goto_player_select()
		cls_joy()
		cls_ps()
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
		cls_hook()
		global.disp_gauge = menu.main.pos.col[15] == 2 -- 体力,POWゲージ表示
		restart_fight({
			next_p1    = menu.main.pos.col[9],   -- 1P セレクト
			next_p2    = menu.main.pos.col[10],  -- 2P セレクト
			next_p1col = menu.main.pos.col[11] - 1, -- 1P カラー
			next_p2col = menu.main.pos.col[12] - 1, -- 2P カラー
			next_stage = menu.stgs[menu.main.pos.col[13]], -- ステージセレクト
			next_bgm   = menu.bgms[menu.main.pos.col[14]].id, -- BGMセレクト
		})
		local fix_scr_top = menu.main.pos.col[16]
		if fix_scr_top == 1 then
			players[1].fix_scr_top = 0xFF
			players[2].fix_scr_top = 0xFF
		elseif fix_scr_top <= 91 then
			players[1].fix_scr_top = fix_scr_top
			players[2].fix_scr_top = 0xFF
		else
			players[1].fix_scr_top = 0xFF
			players[2].fix_scr_top = fix_scr_top
		end
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
	local is_label_line            = function(str)
		return str:find('^' .. "  +") ~= nil
	end
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
			{ "1P セレクト",            menu.labels.chars },
			{ "2P セレクト",            menu.labels.chars },
			{ "1P カラー",              { "A", "D" } },
			{ "2P カラー",              { "A", "D" } },
			{ "ステージセレクト",       menu.labels.stgs },
			{ "BGMセレクト",            menu.labels.bgms },
			{ "体力,POWゲージ表示",     menu.labels.off_on, },
			{ "背景なし時位置補正",     menu.labels.fix_scr_tops, },
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
				1, -- 背景なし時位置補正     16
				0, -- リスタート             18
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
			menu_restart_fight, -- 背景なし時位置補正
			menu_restart_fight, -- リスタート
		},
		on_b = new_filled_table(18, menu.exit),
	}
	menu.current                       = menu.main -- デフォルト設定
	menu.update_pos                = function()
		-- メニューの更新
		menu.main.pos.col[9] = math.min(math.max(pgm:read_u8(0x107BA5), 1), #menu.labels.chars)
		menu.main.pos.col[10] = math.min(math.max(pgm:read_u8(0x107BA7), 1), #menu.labels.chars)
		menu.main.pos.col[11] = math.min(math.max(pgm:read_u8(0x107BAC) + 1, 1), 2)
		menu.main.pos.col[12] = math.min(math.max(pgm:read_u8(0x107BAD) + 1, 1), 2)

		menu.reset_pos = false

		local stg1 = pgm:read_u8(0x107BB1)
		local stg2 = pgm:read_u8(0x107BB7)
		local stg3 = pgm:read_u8(0x107BB9) == 1 and 0x01 or 0x0F
		menu.main.pos.col[13] = 1
		for i, data in ipairs(menu.stgs) do
			if data.stg1 == stg1 and data.stg2 == stg2 and data.stg3 == stg3 and global.no_background == data.no_background then
				menu.main.pos.col[13] = i
				break
			end
		end

		local bgmid, found = pgm:read_u8(0x10A8D5), false
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

		menu.main.pos.col[15] = global.disp_gauge and 2 or 1 -- 体力,POWゲージ表示

		if players[1].fix_scr_top ~= 0xFF then
			menu.main.pos.col[16] = players[1].fix_scr_top
		elseif players[2].fix_scr_top ~= 0xFF then
			menu.main.pos.col[16] = players[2].fix_scr_top
		else
			menu.main.pos.col[16] = 1
		end

		setup_char_manu()
	end
	-- ブレイクショットメニュー
	menu.bs_menus, menu.rvs_menus            = {}, {}
	local bs_blocks, rvs_blocks    = {}, {}
	for i = 1, 60 do
		table.insert(bs_blocks, string.format("%s回ガード後に発動", i))
		table.insert(rvs_blocks, string.format("%s回ガード後に発動", i))
	end
	local menu_bs_to_tra_menu = function()
		menu_to_tra()
	end
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
		for _, a_bs_menu in ipairs(cur_prvs) do
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
		for _, bs_list in pairs(char_bs_list) do
			local list, on_ab, col = {}, {}, {}
			table.insert(list, { "     ONにしたスロットからランダムで発動されます。" })
			table.insert(on_ab, menu_bs_to_tra_menu)
			table.insert(col, 0)
			for _, bs in pairs(bs_list) do
				table.insert(list, { bs.name, menu.labels.off_on, common = bs.common == true, row = #list, })
				table.insert(on_ab, menu_bs_to_tra_menu)
				table.insert(col, 1)
			end

			local a_bs_menu = {
				list = list,
				pos = {
					-- メニュー内の選択位置
					offset = 1,
					row = 2,
					col = col,
				},
				on_a = on_ab,
				on_b = on_ab,
			}
			table.insert(pbs, a_bs_menu)
		end
		for _, rvs_list in pairs(char_rvs_list) do
			local list, on_ab, col = {}, {}, {}
			table.insert(list, { "     ONにしたスロットからランダムで発動されます。" })
			table.insert(on_ab, menu_rvs_to_tra_menu)
			table.insert(col, 0)
			for _, bs in pairs(rvs_list) do
				table.insert(list, { bs.name, menu.labels.off_on, common = bs.common == true, row = #list, })
				table.insert(on_ab, menu_rvs_to_tra_menu)
				table.insert(col, 1)
			end

			local a_rvs_menu = {
				list = list,
				pos = {
					-- メニュー内の選択位置
					offset = 1,
					row = 2,
					col = col,
				},
				on_a = on_ab,
				on_b = on_ab,
			}
			table.insert(prvs, a_rvs_menu)
		end
	end
	local gd_frms = {}
	for i = 1, 61 do
		table.insert(gd_frms, string.format("%sF後にガード解除", (i - 1)))
	end
	local no_hit_row = { "OFF", }
	for i = 1, 99 do
		table.insert(no_hit_row, string.format("%s段目で空振り", i))
	end
	menu.training = {
		list = {
			{ "ダミーモード",           { "プレイヤー vs プレイヤー", "プレイヤー vs CPU", "CPU vs プレイヤー", "1P&2P入れ替え", "レコード", "リプレイ" }, },
			{ "                         ダミー設定" },
			{ "1P アクション",          { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" }, },
			{ "2P アクション",          { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" }, },
			{ "1P ガード",              { "なし", "オート", "ブレイクショット（Aで選択画面へ）", "1ヒットガード", "1ガード", "常時", "ランダム", "強制" }, },
			{ "2P ガード",              { "なし", "オート", "ブレイクショット（Aで選択画面へ）", "1ヒットガード", "1ガード", "常時", "ランダム", "強制" }, },
			{ "1ガード持続フレーム数",  gd_frms, },
			{ "ブレイクショット設定",   bs_blocks },
			{ "1P やられ時行動",        { "なし", "リバーサル（Aで選択画面へ）", "テクニカルライズ（Aで選択画面へ）", "グランドスウェー（Aで選択画面へ）", "起き上がり攻撃", }, },
			{ "2P やられ時行動",        { "なし", "リバーサル（Aで選択画面へ）", "テクニカルライズ（Aで選択画面へ）", "グランドスウェー（Aで選択画面へ）", "起き上がり攻撃", }, },
			{ "ガードリバーサル設定",   bs_blocks },
			{ "1P 強制空振り",          no_hit_row, },
			{ "2P 強制空振り",          no_hit_row, },
			{ "1P 挑発で前進",          menu.labels.off_on, },
			{ "2P 挑発で前進",          menu.labels.off_on, },
			{ "1P Y座標強制",           force_y_pos, },
			{ "2P Y座標強制",           force_y_pos, },
			{ "画面下に移動",           { "OFF", "2Pを下に移動", "1Pを下に移動", }, },
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
		on_a = new_filled_table(18, menu_to_main),
		on_b = new_filled_table(18, menu_to_main_cancel),
	}

	menu.bar = {
		list = {
			{ "                         ゲージ設定" },
			{ "1P 体力ゲージ量",         life_range, }, -- "最大", "赤", "ゼロ" ...
			{ "2P 体力ゲージ量",         life_range, }, -- "最大", "赤", "ゼロ" ...
			{ "1P POWゲージ量",          pow_range, }, -- "最大", "半分", "ゼロ" ...
			{ "2P POWゲージ量",          pow_range, }, -- "最大", "半分", "ゼロ" ...
			{ "体力ゲージモード",        { "自動回復", "固定" }, },
			{ "POWゲージモード",         { "自動回復", "固定", "通常動作" }, },
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
		on_a = new_filled_table(7, bar_menu_to_main),
		on_b = new_filled_table(7, bar_menu_to_main_cancel),
	}

	menu.disp = {
		list = {
			{ "                          表示設定" },
			{ "1P 判定表示",             { "OFF", "ON", "ON:P番号なし", }, },
			{ "2P 判定表示",             { "OFF", "ON", "ON:P番号なし", }, },
			{ "1P 間合い表示",           { "OFF", "ON", "ON:投げ", "ON:遠近攻撃", "ON:詠酒", }, },
			{ "2P 間合い表示",           { "OFF", "ON", "ON:投げ", "ON:遠近攻撃", "ON:詠酒", }, },
			{ "1P 気絶ゲージ表示",       menu.labels.off_on, },
			{ "2P 気絶ゲージ表示",       menu.labels.off_on, },
			{ "1P ダメージ表示",         menu.labels.off_on, },
			{ "2P ダメージ表示",         menu.labels.off_on, },
			{ "1P 入力表示",             { "OFF", "ON", "ログのみ", "キーディスのみ", }, },
			{ "2P 入力表示",             { "OFF", "ON", "ログのみ", "キーディスのみ", }, },
			{ "コマンド入力状態表示",    { "OFF", "1P", "2P", }, },
			{ "通常動作フレーム非表示",  menu.labels.off_on, },
			{ "フレーム差表示",          { "OFF", "数値とグラフ", "数値" }, },
			{ "1P フレーム数表示",       { "OFF", "ON", "ON:判定の形毎", "ON:攻撃判定の形毎", "ON:くらい判定の形毎", }, },
			{ "2P フレーム数表示",       { "OFF", "ON", "ON:判定の形毎", "ON:攻撃判定の形毎", "ON:くらい判定の形毎", }, },
			{ "1P 弾フレーム数表示",     menu.labels.off_on, },
			{ "2P 弾フレーム数表示",     menu.labels.off_on, },
			{ "1P 状態表示",             { "OFF", "ON", "ON:小表示", "ON:大表示" }, },
			{ "2P 状態表示",             { "OFF", "ON", "ON:小表示", "ON:大表示" }, },
			{ "1P 処理アドレス表示",     menu.labels.off_on, },
			{ "2P 処理アドレス表示",     menu.labels.off_on, },
			{ "1P 2P 距離表示",          menu.labels.off_on, },
			{ "1P キャラ表示",           menu.labels.off_on, },
			{ "2P キャラ表示",           menu.labels.off_on, },
			{ "エフェクト表示",          menu.labels.off_on, },
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
				1, -- 通常動作フレーム非表示 13
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
				2, -- エフェクト表示         26
			},
		},
		on_a = new_filled_table(26, disp_menu_to_main),
		on_b = new_filled_table(26, disp_menu_to_main_cancel),
	}
	menu.extra = {
		list = {
			{ "                          特殊設定" },
			{ "簡易超必",               menu.labels.off_on, },
			{ "半自動潜在能力",         menu.labels.off_on, },
			{ "ライン送らない現象",     { "OFF", "ON", "ON:1Pのみ", "ON:2Pのみ" }, },
			{ "ヒット時にポーズ",       { "OFF", "ON", "ON:やられのみ", "ON:投げやられのみ", "ON:打撃やられのみ", "ON:ガードのみ", }, },
			{ "判定発生時にポーズ",     { "OFF", "投げ", "攻撃", "変化時", }, },
			{ "技画像保存",             { "OFF", "ON:新規", "ON:上書き", }, },
			{ "MAMEデバッグウィンドウ", menu.labels.off_on, },
			{ "ヒット効果確認用",       damaged_move_keys },
			{ "位置ログ",               menu.labels.off_on, },
			{ "攻撃情報ログ",           menu.labels.off_on, },
			{ "処理アドレスログ",       menu.labels.off_on, },
			{ "入力ログ",               menu.labels.off_on, },
			{ "リバサログ",             menu.labels.off_on, },
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
				1, -- 位置ログ               10
				1, -- 攻撃情報ログ           11
				1, -- 処理アドレスログ       12
				1, -- 入力ログ               13
				1, -- リバサログ             14
			},
		},
		on_a = new_filled_table(14, ex_menu_to_main),
		on_b = new_filled_table(14, ex_menu_to_main_cancel),
	}

	menu.auto = {
		list = {
			{ "                        自動入力設定" },
			{ "ダウン投げ"            , menu.labels.off_on, },
			{ "ダウン攻撃"            , menu.labels.off_on, },
			{ "通常投げの派生技"      , menu.labels.off_on, },
			{ "デッドリーレイブ"      , { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, },
			{ "アンリミテッドデザイア", { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, "ギガティックサイクロン" }, },
			{ "ドリル"                , { 1, 2, 3, 4, 5 }, },
			{ "超白龍"                , { "OFF", "C攻撃-判定発生前", "C攻撃-判定発生後" }, },
			{ "M.リアルカウンター"    , { "OFF", "ジャーマン", "フェイスロック", "投げっぱなしジャーマン", "ランダム", }, },
			{ "M.トリプルエクスタシー", menu.labels.off_on, },
			{ "炎の種馬"              , menu.labels.off_on, },
			{ "喝CA"                  , menu.labels.off_on, },
			{ "                          入力設定" },
			{ "詠酒距離チェック"      , menu.labels.off_on, },
			{ "必勝！逆襲拳"          , menu.labels.off_on, },
			{ "空振りCA"              , menu.labels.off_on, },
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
		on_a = new_filled_table(16, auto_menu_to_main),
		on_b = new_filled_table(16, auto_menu_to_main_cancel),
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
	table.insert(menu.color.on_b, col_menu_to_main_cancel)
	for _, box in pairs(box_type_col_list) do
		table.insert(menu.color.list, { box.name, menu.labels.off_on, { fill = box.fill, outline = box.outline } })
		table.insert(menu.color.pos.col, box.enabled and 2 or 1)
		table.insert(menu.color.on_a, col_menu_to_main)
		table.insert(menu.color.on_b, col_menu_to_main_cancel)
	end

	menu.recording = {
		list = {
			{ "            選択したスロットに記憶されます。" },
			{ "スロット1",              { "Aでレコード開始", }, },
			{ "スロット2",              { "Aでレコード開始", }, },
			{ "スロット3",              { "Aでレコード開始", }, },
			{ "スロット4",              { "Aでレコード開始", }, },
			{ "スロット5",              { "Aでレコード開始", }, },
			{ "スロット6",              { "Aでレコード開始", }, },
			{ "スロット7",              { "Aでレコード開始", }, },
			{ "スロット8",              { "Aでレコード開始", }, },
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
		on_b = new_filled_table(1, menu_rec_to_tra, 8, menu_to_tra),
	}
	local play_interval = {}
	for i = 1, 301 do
		table.insert(play_interval, i - 1)
	end
	menu.replay = {
		list = {
			{ "     ONにしたスロットからランダムでリプレイされます。" },
			{ "スロット1",              menu.labels.off_on, },
			{ "スロット2",              menu.labels.off_on, },
			{ "スロット3",              menu.labels.off_on, },
			{ "スロット4",              menu.labels.off_on, },
			{ "スロット5",              menu.labels.off_on, },
			{ "スロット6",              menu.labels.off_on, },
			{ "スロット7",              menu.labels.off_on, },
			{ "スロット8",              menu.labels.off_on, },
			{ "                        リプレイ設定" },
			{ "繰り返し",               menu.labels.off_on, },
			{ "繰り返し間隔",           play_interval, },
			{ "繰り返し開始条件",       { "なし", "両キャラがニュートラル", }, },
			{ "開始間合い固定",         { "OFF", "Aでレコード開始", "1Pと2P", "1P", "2P", }, },
			{ "状態リセット",           { "OFF", "1Pと2P", "1P", "2P", }, },
			{ "ガイド表示",             menu.labels.off_on, },
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
		on_a = new_filled_table(17, exit_menu_to_play),
		-- TODO キャンセル時にも間合い固定の設定とかが変わるように
		on_b = new_filled_table(17, exit_menu_to_play_cancel),
	}
	init_auto_menu_config()
	init_disp_menu_config()
	init_ex_menu_config()
	init_bar_menu_config()
	init_menu_config()
	init_restart_fight()
	menu_to_main(true)

	menu.proc = function()
		-- メニュー表示中はDIPかポーズでフリーズさせる
		set_freeze(false)
	end
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

		if not match_active or player_select_active then
			return
		end

		-- 初回のメニュー表示時は状態更新
		if menu.prev_state ~= menu and menu.state == menu then
			menu.update_pos()
		end
		-- 前フレームのメニューを更新
		menu.prev_state = menu.state

		local joy_val = get_joy()

		if accept_input("Start", joy_val, state_past) then
			-- Menu ON/OFF
			global.input_accepted = ec
		elseif accept_input("A", joy_val, state_past) then
			-- サブメニューへの遷移（あれば）
			menu.current.on_a[menu.current.pos.row]()
			global.input_accepted = ec
		elseif accept_input("B", joy_val, state_past) then
			-- メニューから戻る
			menu.current.on_b[menu.current.pos.row]()
			global.input_accepted = ec
		elseif accept_input("Up", joy_val, state_past) then
			-- カーソル上移動
			menu_cur_updown(-1)
		elseif accept_input("Down", joy_val, state_past) then
			-- カーソル下移動
			menu_cur_updown(1)
		elseif accept_input("Left", joy_val, state_past) then
			-- カーソル左移動
			menu_cur_lr(-1, true)
		elseif accept_input("Right", joy_val, state_past) then
			-- カーソル右移動
			menu_cur_lr(1, true)
		elseif accept_input("C", joy_val, state_past) then
			-- カーソル左10移動
			menu_cur_lr(-10, false)
		elseif accept_input("D", joy_val, state_past) then
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
	end

	local bufuf = {}
	local active_mem_0x100701 = {}
	for i = 0x022E, 0x0615 do
		active_mem_0x100701[i] = true
	end

	menu.state = menu.tra_main -- menu or tra_main
	local main_or_menu = function()
		if not cpu then
			return
		end

		-- フレーム更新しているかチェック更新
		local ec = scr:frame_number()
		if mem.last_time == ec then
			return
		end
		mem.last_time = ec

		-- メモリ値の読込と更新
		mem._0x100701 = pgm:read_u16(0x100701) -- 22e 22f 対戦中
		mem._0x107C22 = pgm:read_u16(0x107C22) -- 対戦中4400
		mem._0x10B862 = pgm:read_u8(0x10B862) -- 対戦中00
		mem._0x100F56 = pgm:read_u32(0x100F56) --100F56 100F58
		mem._0x10FD82 = pgm:read_u8(0x10FD82)
		mem._0x10FDAF = pgm:read_u8(0x10FDAF)
		mem._0x10FDB6 = pgm:read_u16(0x10FDB6)
		mem.biostest  = bios_test()
		mem._0x10E043 = pgm:read_u8(0x10E043)
		mem.old_0x107C2A = mem._0x107C2A
		mem._0x107C2A = pgm:read_u16(0x107C2A)
		global.lag_frame = mem.old_0x107C2A == mem._0x107C2A
		if mem._0x107C2A >= 0x176E then
			pgm:write_u16(0x107C2A, 0) -- リセット
		end
		prev_p_space  = (p_space ~= 0) and p_space or prev_p_space

		-- 対戦中かどうかの判定
		if not mem.biostest
			and active_mem_0x100701[mem._0x100701] ~= nil
			and mem._0x107C22 == 0x4400
			and mem._0x10FDAF == 2
			and (mem._0x10FDB6 == 0x0100 or mem._0x10FDB6 == 0x0101) then
			match_active = true
		else
			match_active = false
		end
		-- プレイヤーセレクト中かどうかの判定
		if not mem.biostest
			and mem._0x100701 == 0x10B
			and (mem._0x107C22 == 0x0000 or mem._0x107C22 == 0x5500)
			and mem._0x10FDAF == 2
			and mem._0x10FDB6 ~= 0
			and mem._0x10E043 == 0 then
			pgm:write_u32(mem._0x100F56, 0x00000000)
			player_select_active = true
		else
			player_select_active = false -- 状態リセット
			pgm:write_u8(mem._0x10CDD0, 0x00)
			pgm:write_u32(players[1].addr.select_hook)
			pgm:write_u32(players[2].addr.select_hook)
		end

		-- ROM部分のメモリエリアへパッチあて
		if mem.biostest then
			pached = false -- 状態リセット
		elseif not pached then
			pached = apply_patch_file("char1-p1.pat", true)

			-- キャラ選択の時間減らす処理をNOPにする
			pgm:write_direct_u16(0x63336, 0x4E71)
			pgm:write_direct_u16(0x63338, 0x4E71)
			--時間の値にアイコン用のオフセット値を足しこむ処理で空表示にする 0632DA: 0640 00EE                addi.w  #$ee, D0
			pgm:write_direct_u16(0x632DC, 0x0DD7)

			-- 0632D0: 004B -- キャラ選択の時間の内部タイマー初期値1 デフォは4B=75フレーム
			-- 063332: 004B -- キャラ選択の時間の内部タイマー初期値2 デフォは4B=75フレーム

			-- 0xCB240から16バイト実質効いていない旧避け攻撃ぽいコマンドデータ
			-- ここを1発BS用のリバーサルとBSモードの入れ物に使う
			-- BSモードONの時は CB241 を 00 にして未入力で技データを読み込ませる
			-- 技データ希望の技IDを設定していれば技が出る
			pgm:write_direct_u16(0xCB240, 0xF020) -- F0 は入力データ起点    20 はあり得ない入力
			pgm:write_direct_u16(0xCB242, 0xFF01) -- FF は技データへの繋ぎ  00 は技データ（なにもしない）
			pgm:write_direct_u16(0xCB244, 0x0600) -- 追加技データ

			--[[ 判定の色 座標の色で確認
			maincpu.rw@500C=100F  -- 青色
			maincpu.rw@500C=102D  -- 暗い青色
			maincpu.rw@500C=20F0  -- 緑色
			maincpu.rw@500C=30FF  -- 水色
			maincpu.rw@500C=4F00  -- 赤色
			maincpu.rw@500C=5F0F  -- ドピンク
			maincpu.rw@500C=6F70  -- オレンジに近い色
			maincpu.rw@500C=6FF0  -- 黄色
			maincpu.rw@500C=7F77  -- 薄い朱色
			maincpu.rw@500C=7FFF  -- 白色
			]]

			--[[
			-- スタートボタンで判定表示
			maincpu.rd@0047B0=08390000;maincpu.rd@0047B4=00380000;maincpu.rd@0047B8=670001C8;maincpu.rd@0047BC=4E714E71;maincpu.rd@0047C0=4E714E71
			-- スタートボタンで判定色付けチェックへジャンプ
			maincpu.rd@004F52=08390000;maincpu.rd@004F56=00380000;maincpu.rw@004F5A=6702
			-- 判定色のメモリがゼロなら色付け処理へジャンプ
			maincpu.rd@004F5E=41F90040;maincpu.rd@004F62=1c023210;maincpu.rd@004F66=67024E75
			-- 判定色付けのメモリ範囲の不足修正
			maincpu.rw@004F74=7216
			-- 判定色付け用のメモリ領域の初期化を修正
			maincpu.rd@0110C4=0000500A
			]]

			--[[ 没案
			-- スタートボタンで無敵表示
			maincpu.rd@05BCAC=08390000;
			maincpu.rd@05BCB0=00380000;
			maincpu.rd@05BCB4=67000004;
			maincpu.rd@05BCB8=4E7549ED;
			maincpu.rd@05BCBC=84004E71;
			maincpu.rd@05BCC0=4E714E71;

			maincpu.rd@05BCD8=4E714E71;
			maincpu.rd@05BCDC=4E714E71;

			-- デバッグの飛び道具のID表示の代わりに投げ無敵フレームを表示
			maincpu.rd@05BCAC=08390000;
			maincpu.rd@05BCB0=00380000;
			maincpu.rd@05BCB4=67000004;
			maincpu.rd@05BCB8=4E7549ED;
			maincpu.rd@05BCBC=84004E71;
			maincpu.rd@05BCC0=4E714E71;
			maincpu.rd@05BCC4=363C7107;
			maincpu.rd@05BCC8=610000E6;

			maincpu.rd@05BCD8=4E714E71;
			maincpu.rd@05BCDC=4E714E71;
			maincpu.rd@05BCE0=363C72A7;
			maincpu.rd@05BCE4=610000CA;

			maincpu.rd@05BDB0=1E2C0090;
			maincpu.rd@05BDB4=4E714E71;maincpu.rw@05BDB8=4E71;
			-- 24Fよりおおきいかどうかがわかるようにしたい

			-- 無敵表示位置
			maincpu.rw@05BCC6=7065
			maincpu.rw@05BCE2=7445
			maincpu.rw@05BCCE=7066
			maincpu.rw@05BCEA=7446
			-- 無敵表示を-M-表記に
			maincpu.rw@05BEEC=0002
			maincpu.rd@05BF2D=2D4D2DFF
			-- ダメージ表示位置
			maincpu.rw@05B446=7065
			maincpu.rw@05B45C=7445
			-- ダメージ表示を白色
			maincpu.rw@05BDC0=2F00
			maincpu.rw@05B44A=2F00
			maincpu.rw@05B460=2F00
			]]

			-- 乱入されても常にキャラ選択できる
			-- MVS                    家庭用
			-- maincpu.rb@062E7C=00   maincpu.rb@062E9D=00

			--[[ 空振りCAできる
			オリジナル
			maincpu.rd@02FA72=00000000
			maincpu.rd@02FA76=00000000
			maincpu.rd@02FA7A=FFFFFFFF
			maincpu.rd@02FA7E=00FFFF00
			maincpu.rw@02FA82=FFFF

			パッチ（00をFFにするとヒット時限定になる）
			maincpu.rd@02FA72=00000000
			maincpu.rd@02FA76=00000000
			maincpu.rd@02FA7A=00000000
			maincpu.rd@02FA7E=00000000
			maincpu.rw@02FA82=0000
			]]

			--[[ 連キャン、必キャン可否テーブルに連キャンデータを設定する
			for i = 0x085138, 0x08591F do
				pgm:write_direct_u8(i, 0xD0)
			end
			]]

			--[[ 常にCPUレベルMAX
			MVS                          家庭用
			maincpu.rd@0500E8=303C0007   maincpu.rd@050108=303C0007
			maincpu.rd@050118=3E3C0007   maincpu.rd@050138=3E3C0007
			maincpu.rd@050150=303C0007   maincpu.rd@050170=303C0007
			maincpu.rd@0501A8=303C0007   maincpu.rd@0501C8=303C0007
			maincpu.rd@0501CE=303C0007   maincpu.rd@0501EE=303C0007
			]]
			pgm:write_direct_u32(fix_bp_addr(0x0500E8), 0x303C0007)
			pgm:write_direct_u32(fix_bp_addr(0x050118), 0x3E3C0007)
			pgm:write_direct_u32(fix_bp_addr(0x050150), 0x303C0007)
			pgm:write_direct_u32(fix_bp_addr(0x0501A8), 0x303C0007)
			pgm:write_direct_u32(fix_bp_addr(0x0501CE), 0x303C0007)

			-- 対戦の双角ステージをビリーステージに変更する MVSと家庭用共通
			pgm:write_direct_u16(0xF290, 0x0004)

			-- 簡易超必ONのときにダックのブレイクスパイラルブラザー（BRも）が出るようにする
			pgm:write_direct_u16(0x0CACC8, 0xC37C)

			-- クレジット消費をNOPにする
			pgm:write_direct_u32(0x00D238, 0x4E714E71)
			pgm:write_direct_u32(0x00D270, 0x4E714E71)

			-- 家庭用の初期クレジット9
			pgm:write_direct_u16(0x00DD54, 0x0009)
			pgm:write_direct_u16(0x00DD5A, 0x0009)
			pgm:write_direct_u16(0x00DF70, 0x0009)
			pgm:write_direct_u16(0x00DF76, 0x0009)

			-- 家庭用のクレジット表示をスキップ bp 00C734,1,{PC=c7c8;g}
			-- CREDITをCREDITSにする判定をスキップ bp C742,1,{PC=C748;g}
			-- CREDIT表示のルーチンを即RTS
			pgm:write_direct_u16(0x00C700, 0x4E75)

			-- 自動アンリミのバグ修正
			pgm:write_direct_u8(fix_bp_addr(0x049951), 0x2)
			pgm:write_direct_u8(fix_bp_addr(0x049947), 0x9)

			-- 逆襲拳、サドマゾの初段で相手の状態変更しない（相手が投げられなくなる事象が解消する）
			-- pgm:write_direct_u8(0x57F43, 0x00)

			--[[ WIP
			-- https://www.neo-geo.com/forums/index.php?threads/universe-bios-released-good-news-for-mvs-owners.41967/page-7
			-- pgm:write_direct_u8 (10E003, 0x0C)       -- Auto SDM combo (RB2) 0x56D98A
			-- pgm:write_direct_u32(1004D5, 0x46A70500) -- 1P Crazy Yamazaki Return (now he can throw projectile "anytime" with some other bug) 0x55FE5C
			-- pgm:write_direct_u16(1004BF, 0x3CC1)     -- 1P Level 2 Blue Mary 0x55FE46
			-- cheat offset NGX 45F987 = MAME 0
			]]
		end

		-- 強制的に家庭用モードに変更
		if not mem.biostest then
			pgm:write_direct_u16(0x10FE32, 0x0000)
		end

		-- デバッグDIP
		local dip1, dip2, dip3, dip4 = 0x00, 0x00, 0x00, 0x00
		if match_active and dip_config.show_hitbox then
			--dip1 = dip1 | 0x40    --cheat "DIP= 1-7 色々な判定表示"
			dip1 = dip1 | 0x80 --cheat "DIP= 1-8 当たり判定表示"
		end
		if match_active and dip_config.infinity_life then
			dip1 = dip1 | 0x02 --cheat "DIP= 1-2 Infinite Energy"
		end
		if match_active and dip_config.easy_super then
			dip2 = dip2 | 0x01 --Cheat "DIP 2-1 Eeasy Super"
		end
		if match_active and dip_config.semiauto_p then
			dip4 = dip4 | 0x08 -- DIP4-4
		end
		if dip_config.infinity_time then
			dip2 = dip2 | 0x10  --cheat "DIP= 2-5 Disable Time Over"
			-- 家庭用オプションの時間無限大設定
			pgm:write_u8(0x10E024, 0x03) -- 1:45 2:60 3:90 4:infinity
			pgm:write_u8(0x107C28, 0xAA) --cheat "Infinite Time"
		else
			pgm:write_u8(0x107C28, dip_config.fix_time)
		end
		if dip_config.stage_select then
			dip1 = dip1 | 0x04 --cheat "DIP= 1-3 Stage Select Mode"
		end
		if player_select_active and dip_config.alfred then
			dip2 = dip2 | 0x80 --cheat "DIP= 2-8 Alfred Code (B+C >A)"
		end
		if match_active and dip_config.watch_states then
			dip2 = dip2 | 0x20 --cheat "DIP= 2-6 Watch States"
		end
		if match_active and dip_config.cpu_cant_move then
			dip3 = dip3 | 0x01 --cheat "DIP= 3-1 CPU Can't Move"
		end
		--dip3 = dip3 | 0x10    --cheat "DIP= 3-5 移動速度変更"

		pgm:write_u8(0x10E000, dip1)
		pgm:write_u8(0x10E001, dip2)
		pgm:write_u8(0x10E002, dip3)
		pgm:write_u8(0x10E003, dip4)

		-- CPUレベル MAX（ロムハックのほうが楽）
		-- maincpu.pw@10E792=0007
		-- maincpu.pw@10E796=0008
		-- pgm:write_u16(0x10E792, 0x0007)
		-- pgm:write_u16(0x10E796, 0x0007)

		if match_active then
			-- 1Pと2Pの操作の設定
			for i, p in ipairs(players) do
				pgm:write_u8(p.addr.control1, i) -- Human 1 or 2, CPU 3
				pgm:write_u8(p.addr.control2, i) -- Human 1 or 2, CPU 3
			end
		end
		if player_select_active then
			if pgm:read_u8(mem._0x10CDD0) > 12 then
				local addr1 = 0xFFFFFF & pgm:read_u32(players[1].addr.select_hook)
				local addr2 = 0xFFFFFF & pgm:read_u32(players[2].addr.select_hook)
				if addr1 > 0 then
					pgm:write_u8(addr1, 2)
				end
				if addr2 > 0 then
					pgm:write_u8(addr2, 1)
				end
			end
		end

		-- 更新フックの仕込み、フックにはデバッガ必須
		set_hook()

		-- メニュー初期化前に処理されないようにする
		menu.state.proc()

		-- メニュー切替のタイミングでフック用に記録した値が状態変更後に謝って読みこまれないように常に初期化する
		cls_hook()
	end

	emu.register_pause(function()
		menu.state.draw()
	end)

	emu.register_resume(function()
		global.pause = false
	end)

	emu.register_frame_done(function()
		if machine then
			if machine.paused == false then
				menu.state.draw()
				--collectgarbage("collect")

				if global.pause then
					emu.pause()
				end
			end
		end
	end)

	emu.register_periodic(function()
		if machine then
			if machine.paused == false then
				main_or_menu()
			end
			if global.mame_debug_wnd == false then
				auto_recovery_debug()
			end
		end
	end)
end

return exports
