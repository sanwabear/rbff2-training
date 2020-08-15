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

local exports = {}
local sqlite3 = require('lsqlite3')
require('lfs')

exports.name = "rbff2training"
exports.version = "0.0.1"
exports.description = "RBFF2 Training"
exports.license = "MIT License"
exports.author = { name = "Sanwabear" }

local rbff2 = exports

function rbff2.startplugin()
	local main_or_menu_state, prev_main_or_menu_state
	local menu_cur, main_menu, tra_menu, rec_menu, play_menu, menu, tra_main, menu_exit, bs_menus

	local menu_move_fc = 0

	local mem_last_time         = 0      -- 最終読込フレーム(キャッシュ用)
	local mem_0x100400          = 0      -- 1P用のRAMスペースの先頭
	local mem_0x100500          = 0      -- 2P用のRAMスペースの先頭
	local mem_0x100701          = 0      -- 場面判定用
	local mem_0x102557          = 0      -- 場面判定用
	local mem_0x1041D2          = 0      -- unpause 0x00, pause 0xFF
	local mem_0x107C22          = 0      -- 場面判定用
	local mem_0x10B862          = 0      -- ガードヒット=FF
	local mem_0x10D4EA          = 0      -- 潜在発動時の停止時間
	local mem_0x10FD82          = 0      -- console 0x00, mvs 0x01
	local mem_0x10FDAF          = 0      -- 場面判定用
	local mem_0x10FDB6          = 0      -- P1 P2 開始判定用
	local mem_0x10E043          = 0      -- 手動でポーズしたときに00以外になる
	local mem_bgm               = 0      -- BGM
	local mem_reg_sts_b         = 0      -- REG_STATUS_B
	local mem_stage             = 0      -- ステージ
	local mem_stage_tz          = 0      -- ステージバリエーション(Timezone)
	local mem_biostest          = false  -- 初期化中のときtrue
	local old_active            = false  -- 対戦画面のときtrue(前フレーム)
	local match_active          = false  -- 対戦画面のときtrue
	local player_select_active  = false  -- プレイヤー選択画面のときtrue
	local player_select_hacked  = 0        -- プレイヤー選択のハック用 
	local mem_0x10CDD0          = 0x10CDD0 -- プレイヤー選択のハック用 
	local p_space               = 0      -- 1Pと2Pの間隔
	local prev_p_space          = 0      -- 1Pと2Pの間隔(前フレーム)
	local stage_base_addr       = 0x100E00
	local offset_pos_x          = 0x20
	local offset_pos_z          = 0x24
	local offset_pos_y          = 0x28
	local screen_left           = 0
	local screen_top            = 0
	local bios_test             = function()
		local cpu = manager:machine().devices[":maincpu"]
		local pgm = cpu.spaces["program"]
		local ram_value = pgm:read_u8(addr)
		for _, addr in ipairs({0x100400, 0x100500}) do
			for _, test_value in ipairs({0x5555, 0xAAAA, bit32.band(0xFFFF, addr)}) do
				if ram_value == test_value then
					return true
				end
			end
		end
	end

	local global = {
		frame_number    = 0,

		-- 当たり判定用
		axis_color      = 0xFFFFFFFF,
		axis_size       = 12,
		no_alpha        = true, --fill = 0x00, outline = 0xFF for all box types
		throwbox_height = 200, --default for ground throws
		no_background   = false,

		disp_stun       = true, -- スタン表示
		disp_pos        = true, -- 1P 2P 距離表示
		disp_hitbox     = true, -- 判定表示
		disp_frmgap     = true, -- フレーム差表示
		pause_hit       = false, -- ヒット時にポーズ
		pausethrow      = false, -- 投げ判定表示時にポーズ

		frzc            = 1, 
		frz             = {0x1, 0x0},  -- DIPによる停止操作用の値とカウンタ

		dummy_mode      = 1,
		rec_main        = nil,

		input_accepted  = 0,

		next_block_grace = 0, -- 1ガードでの持続フレーム数
		infinity_life2   = true,
		repeat_interval = 0,
		await_neutral   = false,
		replay_fix_pos  = false,
	}

	-- DIPスイッチ
	local dip_config ={
		show_hitbox   = false,
		infinity_life = false,
		easy_super    = false,
		infinity_time = true,
		fix_time      = 0x99,
		stage_select  = false,
		alfred        = false,
		watch_states  = false,
		cpu_cant_move = false,
	}

	-- 最大スタン値の初期値
	-- 配列のインデックス=キャラID
	local init_stuns =  {
		32 --[[ TERRY ]] ,31 --[[ ANDY ]] ,32 --[[ JOE ]], 29 --[[ MAI ]], 33 --[[ GEESE ]], 32 --[[ SOKAKU ]],
		31 --[[ BOB ]] ,31 --[[ HON-FU ]] ,29 --[[ MARY ]] ,35 --[[ BASH ]] ,38 --[[ YAMAZAKI ]] ,29 --[[ CHONSHU ]],
		29 --[[ CHONREI ]] ,32 --[[ DUCK ]] ,32 --[[ KIM ]] ,32 --[[ BILLY ]] ,31 --[[ CHENG ]] ,31 --[[ TUNG ]],
		35 --[[ LAURENCE ]] ,35 --[[ KRAUSER ]] ,32 --[[ RICK ]] ,29 --[[ XIANGFEI ]] ,32 --[[ ALFRED ]]
	}

	-- 行動の種類
	local act_types = { free = -1, attack = 0, low_attack = 1, provoke =  2, any = 3, overhead = 4 }

	local char_names = { "テリー・ボガード", "アンディ・ボガード", "東丈", "不知火舞", "ギース・ハワード", "望月双角",
		"ボブ・ウィルソン", "ホンフゥ", "ブルー・マリー", "フランコ・バッシュ", "山崎竜二", "秦崇秀", "秦崇雷",
		"ダック・キング", "キム・カッファン", "ビリー・カーン", "チン・シンザン", "タン・フー・ルー",
		"ローレンス・ブラッド", "ヴォルフガング・クラウザー", "リック・ストラウド", "李香緋", "アルフレッド",
	}
	local bgms = {
		{ id = 0x01, name = "クリといつまでも"              , }, --テリー・ボガード
		{ id = 0x02, name = "雷波濤外伝"                    , }, --アンディ・ボガード
		{ id = 0x03, name = "タイ南部に伝わったSPの詩"      , }, --東丈
		{ id = 0x04, name = "まいまいきゅーん"              , }, --不知火舞
		{ id = 0x05, name = "ギースにしょうゆとオケヒット"  , }, --ギース・ハワード
		{ id = 0x06, name = "TAKU-HATSU-Rock"               , }, --望月双角,
		{ id = 0x07, name = "蜜の味"                        , }, --ボブ・ウィルソン
		{ id = 0x08, name = "ドンチカ!!チ!!チ!!"            , }, --ホンフゥ
		{ id = 0x09, name = "Blue Mary's BLUES"             , }, --ブルー・マリー
		{ id = 0x0A, name = "GOLI-Rock"                     , }, --フランコ・バッシュ
		{ id = 0x0B, name = "C62 -シロクニ- Ver.2"          , }, --山崎竜二
		{ id = 0x0C, name = "パンドラの箱より 第3番「決断」", }, --秦崇秀
		{ id = 0x0D, name = "パンドラの箱より 第3番「決断」", }, --秦崇雷,
		{ id = 0x0E, name = "Duck! Duck! Duck!"             , }, --ダック・キング
		{ id = 0x0F, name = "ソウルっす♪"                  , }, --キム・カッファン
		{ id = 0x10, name = "ロンドンマーチ"                , }, --ビリー・カーン
		{ id = 0x11, name = "ハプシュ！フゥゥゥ"            , }, --チン・シンザン
		{ id = 0x12, name = "中国四千年の歴史とはいかにII"  , }, --タン・フー・ルー,
		{ id = 0x13, name = "牛とお戯れ"                    , }, --ローレンス・ブラッド
		{ id = 0x14, name = "REQUIEM K.626 [Lacrimosa]"     , }, --ヴォルフガング・クラウザー
		{ id = 0x15, name = "Exceed The Limit"              , }, --リック・ストラウド
		{ id = 0x16, name = "雄々盛嬢後援 ～競場詩～"       , }, --李香緋
		{ id = 0x17, name = "Get The Sky -With Your Dream-" , }, --アルフレッド
		{ id = 0x00, name = "なし"                          , }, -- なし
		{ id = 0x1C, name = "4 HITs Ⅱ"                     , }, -- キャラクターセレクト
		{ id = 0x1E, name = "Gain a victory"                , }, -- 勝利デモ
		{ id = 0x26, name = "NEOGEO SOUND LOGO"             , }, -- ネオジオデモ
	}
	local bgm_names = {}
	for i, bgm in ipairs(bgms) do
		local exists = false
		for _, name in pairs(bgm_names) do
			if name == bgm.name then
				exists = true
				bgm.name_idx = #bgm_names
				break
			end
		end
		if not exists then 
			table.insert(bgm_names, bgm.name)
			bgm.name_idx = #bgm_names
		end
	end
	local stgs = {
		{ stg1 = 0x01, stg2 = 0x00, stg3 = 0x01, name = "日本 [1]"          , }, -- 不知火舞
		{ stg1 = 0x01, stg2 = 0x01, stg3 = 0x01, name = "日本 [2]"          , }, -- 望月双角,
		{ stg1 = 0x01, stg2 = 0x01, stg3 = 0x0F, name = "日本 [2] 雨"       , }, -- 望月双角,
		{ stg1 = 0x01, stg2 = 0x02, stg3 = 0x01, name = "日本 [3]"          , }, -- アンディ・ボガード
		{ stg1 = 0x02, stg2 = 0x00, stg3 = 0x01, name = "香港1 [1]"         , }, -- チン・シンザン
		{ stg1 = 0x02, stg2 = 0x01, stg3 = 0x01, name = "香港1 [2]"         , }, -- 山崎竜二
		{ stg1 = 0x03, stg2 = 0x00, stg3 = 0x01, name = "韓国 [1]"          , }, -- キム・カッファン
		{ stg1 = 0x03, stg2 = 0x01, stg3 = 0x01, name = "韓国 [2]"          , }, -- タン・フー・ルー,
		{ stg1 = 0x04, stg2 = 0x00, stg3 = 0x01, name = "サウスタウン [1]"  , }, -- ギース・ハワード
		{ stg1 = 0x04, stg2 = 0x01, stg3 = 0x01, name = "サウスタウン [2]"  , }, -- ビリー・カーン
		{ stg1 = 0x05, stg2 = 0x00, stg3 = 0x01, name = "ドイツ [1]"        , }, -- ヴォルフガング・クラウザー
		{ stg1 = 0x05, stg2 = 0x01, stg3 = 0x01, name = "ドイツ [2]"        , }, -- ローレンス・ブラッド
		{ stg1 = 0x06, stg2 = 0x00, stg3 = 0x01, name = "アメリカ1 [1]"     , }, -- ダック・キング
		{ stg1 = 0x06, stg2 = 0x01, stg3 = 0x01, name = "アメリカ1 [2]"     , }, -- ブルー・マリー
		{ stg1 = 0x07, stg2 = 0x00, stg3 = 0x01, name = "アメリカ2 [1]"     , }, -- テリー・ボガード
		{ stg1 = 0x07, stg2 = 0x01, stg3 = 0x01, name = "アメリカ2 [2]"     , }, -- リック・ストラウド
		{ stg1 = 0x07, stg2 = 0x02, stg3 = 0x01, name = "アメリカ2 [2]"     , }, -- アルフレッド
		{ stg1 = 0x08, stg2 = 0x00, stg3 = 0x01, name = "タイ [1]"          , }, -- ボブ・ウィルソン
		{ stg1 = 0x08, stg2 = 0x01, stg3 = 0x01, name = "タイ [2]"          , }, -- フランコ・バッシュ
		{ stg1 = 0x08, stg2 = 0x02, stg3 = 0x01, name = "タイ [3]"          , }, -- 東丈
		{ stg1 = 0x09, stg2 = 0x00, stg3 = 0x01, name = "香港2 [1]"         , }, -- 秦崇秀
		{ stg1 = 0x09, stg2 = 0x01, stg3 = 0x01, name = "香港2 [2]"         , }, -- 秦崇雷,
		{ stg1 = 0x0A, stg2 = 0x00, stg3 = 0x01, name = "NEW CHALLENGERS[1]", }, -- 李香緋
		{ stg1 = 0x0A, stg2 = 0x01, stg3 = 0x01, name = "NEW CHALLENGERS[2]", }, -- ホンフゥ
	}
	local names = {}
	for i, stg in ipairs(stgs) do
		table.insert(names, stg.name)
	end

	local char_acts_base = {
		-- テリー・ボガード
		{
			{ disp_name = "フェイント", name = "フェイント パワーゲイザー", type = act_types.any, ids = { 0x113, }, },
			{ disp_name = "フェイント", name = "フェイント バーンナックル", type = act_types.any, ids = { 0x112, }, },
			{ name = "バスタースルー", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "ワイルドアッパー", type = act_types.attack, ids = { 0x69, }, },
			{ name = "バックスピンキック", type = act_types.attack, ids = { 0x68, }, },
			{ name = "チャージキック", type = act_types.overhead, ids = { 0x6A, }, },
			{ disp_name = "バーンナックル", name = "小バーンナックル", type = act_types.attack, ids = { 0x86, 0x87, 0x88, }, },
			{ disp_name = "バーンナックル", name = "大バーンナックル", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
			{ name = "パワーウェイブ", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
			{ name = "ランドウェイブ", type = act_types.low_attack, ids = { 0xA4, 0xA5, 0xA6, }, },
			{ name = "ファイヤーキック", type = act_types.low_attack, ids = { 0xB8, 0xB9, 0xBC, 0xBA, 0xBB, }, },
			{ name = "クラックシュート", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, }, },
			{ name = "ライジングタックル", type = act_types.attack, ids = { 0xCC, 0xCD, 0xCE, 0xCF, 0xD0, }, },
			{ name = "パッシングスウェー", type = act_types.attack, ids = { 0xC2, 0xC3, 0xC4, }, },
			{ name = "パワーゲイザー", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, }, },
			{ name = "トリプルゲイザー", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x10E, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x241, }, },
			{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x242, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x244, }, },
			{ disp_name = "CA _6C", name = "CA 5C(3段目)", type = act_types.attack, ids = { 0x245, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x246, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目or3段目)", type = act_types.low_attack, ids = { 0x247, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x240, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)", type = act_types.attack, ids = { 0x243, }, },
			{ disp_name = "パワーチャージ", name = "CA パワーチャージ", type = act_types.attack, ids = { 0x24D, }, },
			{ disp_name = "CA 立D", name = "CA 立D(2段目)", type = act_types.attack, ids = { 0x24A, }, },
			{ disp_name = "CA 下D", name = "CA 下D(2段目)", type = act_types.low_attack, ids = { 0x24B, }, },
			{ disp_name = "パワーダンク", name = "CA パワーダンク", type = act_types.attack, ids = { 0xE0, 0xE1, 0xE2, }, },
			{ disp_name = "CA 立C", name = "CA 近立C(2段目)", type = act_types.attack, ids = { 0x248, }, },
			{ disp_name = "CA 立C", name = "CA 近立C(3段目)", type = act_types.attack, ids = { 0x249, }, },
		},
		-- アンディ・ボガード
		{
			{ disp_name = "フェイント", name = "フェイント 残影拳", type = act_types.any, ids = { 0x112, }, },
			{ disp_name = "フェイント", name = "フェイント 飛翔拳", type = act_types.any, ids = { 0x113, }, },
			{ disp_name = "フェイント", name = "フェイント 超裂破弾", type = act_types.any, ids = { 0x114, }, },
			{ name = "内股", type = act_types.attack, ids = { 0x6D, 0x6E, }, },
			{ name = "上げ面", type = act_types.attack, ids = { 0x69, }, },
			{ name = "浴びせ蹴り", type = act_types.attack, ids = { 0x68, }, },
			{ name = "小残影拳", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, 0x8A, }, },
			{ name = "大残影拳/疾風裏拳", type = act_types.attack, ids = { 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, }, },
			{ name = "飛翔拳", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
			{ name = "激飛翔拳", type = act_types.attack, ids = { 0xA7, 0xA4, 0xA5, 0xA6, }, },
			{ name = "昇龍弾", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, }, },
			{ name = "空破弾", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, 0xBB, }, },
			{ name = "幻影不知火", type = act_types.attack, ids = { 0xC8, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, }, },
			{ name = "超裂破弾", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, }, },
			{ name = "男打弾", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10E, 0x10F, 0x10B, 0x10C, 0x10D, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x240, }, },
			{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x241, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x242, }, },
			{ disp_name = "CA _6C", name = "CA 6C(3段目)", type = act_types.attack, ids = { 0x243, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x245, }, },
			{ disp_name = "CA 下C", name = "CA 下C(3段目)", type = act_types.low_attack, ids = { 0x246, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x244, }, },
			{ disp_name = "浴びせ蹴り 追撃", name = "CA 浴びせ蹴り追撃", type = act_types.attack, ids = { 0xF4, 0xF5, 0xF6, }, },
			{ disp_name = "上げ面追加 B", name = "CA 上げ面追加B(2段目)", type = act_types.attack, ids = { 0x24A, 0x24B, 0x24C, }, },
			{ disp_name = "上げ面追加 C", name = "CA 上げ面追加C(3段目)", type = act_types.overhead, ids = { 0x24D, 0x24E, }, },
			{ disp_name = "上げ面追加 立C", name = "CA 上げ面追加近C(2段目)", type = act_types.attack, ids = { 0x247, }, },
			{ disp_name = "上げ面追加 立C", name = "CA 上げ面追加近C(3段目)", type = act_types.attack, ids = { 0x248, }, },
			{ disp_name = "上げ面追加 下C", name = "CA 上げ面追加下C(2段目)", type = act_types.attack, ids = { 0x246, }, },
		},
		-- 東丈
		{
			{ disp_name = "フェイント", name = "フェイント スラッシュキック", type = act_types.any, ids = { 0x113, }, },
			{ disp_name = "フェイント", name = "フェイント ハリケーンアッパー", type = act_types.any, ids = { 0x112, }, },
			{ name = "ジョースペシャル", type = act_types.any, ids = { 0x6D, 0x6E, 0x6F, 0x70, 0x71, }, },
			{ name = "膝地獄", type = act_types.any, ids = { 0x81, 0x82, 0x83, 0x84, }, },
			{ name = "スライディング", type = act_types.low_attack, ids = { 0x68, 0xF4, 0xF5, }, },
			{ name = "ハイキック", type = act_types.attack, ids = { 0x69, }, },
			{ name = "炎の指先", type = act_types.attack, ids = { 0x6A, }, },
			{ disp_name = "スラッシュキック", name = "小スラッシュキック", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, }, },
			{ disp_name = "スラッシュキック", name = "大スラッシュキック", type = act_types.attack, ids = { 0x90, 0x91, 0x92, 0x93, 0x94, }, },
			{ name = "黄金のカカト", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
			{ name = "タイガーキック", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, }, },
			{ name = "爆裂拳", type = act_types.attack, ids = { 0xAE, 0xB0, 0xB1, 0xB2, 0xAF, }, },
			{ name = "爆裂フック", type = act_types.attack, ids = { 0xB3, 0xB4, 0xB5, }, },
			{ name = "爆裂アッパー", type = act_types.attack, ids = { 0xF8, 0xF9, 0xFA, 0xFB, }, },
			{ name = "ハリケーンアッパー", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, }, },
			{ name = "爆裂ハリケーン", type = act_types.attack, ids = { 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, }, },
			{ name = "スクリューアッパー", type = act_types.attack, ids = { 0xFE, 0xFF, }, },
			{ disp_name = "サンダーファイヤー", name = "サンダーファイヤー(C)", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x10E, 0x10F, 0x110, 0x111, }, },
			{ disp_name = "サンダーファイヤー", name = "サンダーファイヤー(D)", type = act_types.attack, ids = { 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, }, },
			{ disp_name = "CA 立A", name = "CA 立A(2段目)", type = act_types.attack, ids = { 0x24B, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x42, }, },
			{ disp_name = "CA 立B", name = "CA 遠立B(2段目)", type = act_types.attack, ids = { 0x244, }, },
			{ disp_name = "CA 立C", name = "CA 遠立C(3段目)", type = act_types.attack, ids = { 0x255, }, },
			{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x48, }, },
			{ disp_name = "CA 立A", name = "CA 立A(3段目)", type = act_types.attack, ids = { 0x24C, }, },
			{ disp_name = "CA 立B", name = "CA 立B(3段目)", type = act_types.attack, ids = { 0x45, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x25, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x246, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x240, }, },
			{ disp_name = "CA _8C", name = "CA 8C(3段目)", type = act_types.overhead, ids = { 0x251, 0x252, 0x253, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x46, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x24B, }, },
			{ disp_name = "CA 236C", name = "CA 236C(3段目)", type = act_types.attack, ids = { 0x24A, }, },
		},
		-- 不知火舞
		{
			{ disp_name = "フェイント", name = "フェイント 花蝶扇", type = act_types.attack, ids = { 0x112, }, },
			{ disp_name = "フェイント", name = "フェイント 花嵐", type = act_types.attack, ids = { 0x113, }, },
			{ name = "風車崩し・改", type = act_types.attack, ids = { 0x6D, 0x6E, }, },
			{ name = "夢桜・改", type = act_types.attack, ids = { 0x72, 0x73, }, },
			{ name = "跳ね蹴り", type = act_types.attack, ids = { 0x68, }, },
			{ name = "三角跳び", type = act_types.attack, ids = { 0x69, }, },
			{ name = "龍の舞", type = act_types.attack, ids = { 0x6A, }, },
			{ name = "花蝶扇", type = act_types.attack, ids = { 0x86, 0x87, 0x88, }, },
			{ name = "龍炎舞", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
			{ name = "小夜千鳥", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
			{ name = "必殺忍蜂", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, }, },
			{ name = "ムササビの舞", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, }, },
			{ name = "超必殺忍蜂", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, 0x103, }, },
			{ name = "花嵐", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x10E, 0x10F, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x42, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x43, }, },
			{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x242, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)下Aルート", type = act_types.attack, ids = { 0x243, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x244, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x246, }, },
			{ disp_name = "龍の舞追撃 立D", name = "龍の舞追撃立D", type = act_types.attack, ids = { 0x249, }, },
			{ disp_name = "龍の舞追撃 下D", name = "龍の舞追撃下D", type = act_types.attack, ids = { 0x66, }, },
			{ disp_name = "CA C", name = "CA C(4段目)", type = act_types.attack, ids = { 0x24A, 0x24B, 0x24C, }, },
			{ disp_name = "CA B", name = "CA B(5段目)", type = act_types.overhead, ids = { 0x24D, 0x24E, }, },
			{ disp_name = "CA C", name = "CA C(5段目)", type = act_types.overhead, ids = { 0x24F, 0x250, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)下Bルート", type = act_types.attack, ids = { 0x247, }, },
		},
		-- ギース・ハワード
		{
			{ disp_name = "フェイント", name = "フェイント 烈風拳", type = act_types.any, ids = { 0x112, }, },
			{ disp_name = "フェイント", name = "フェイント レイジングストーム", type = act_types.any, ids = { 0x113, }, },
			{ name = "虎殺投げ", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "絶命人中打ち", type = act_types.any, ids = { 0x7C, 0x7D, 0x7E, 0x7F, }, },
			{ name = "虎殺掌", type = act_types.any, ids = { 0x81, 0x82, 0x83, 0x84, }, },
			{ name = "昇天明星打ち", type = act_types.attack, ids = { 0x69, }, },
			{ name = "飛燕失脚", type = act_types.overhead, ids = { 0x68, 0x6B, 0x6C, }, },
			{ name = "雷光回し蹴り", type = act_types.attack, ids = { 0x6A, }, },
			{ name = "烈風拳", type = act_types.attack, ids = { 0x86, 0x87, 0x88, }, },
			{ name = "ダブル烈風拳", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
			{ name = "下段当て身打ち", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, }, },
			{ name = "裏雲隠し", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, }, },
			{ name = "上段当て身投げ", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D, }, },
			{ name = "雷鳴豪波投げ", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, }, },
			{ name = "真空投げ", type = act_types.attack, ids = { 0xC2, 0xC3, }, },
			{ name = "レイジングストーム", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, }, },
			{ name = "羅生門", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, }, },
			{ name = "デッドリーレイブ", type = act_types.attack, ids = { 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x241, }, },
			{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x242, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x245, }, },
			{ disp_name = "CA 下C", name = "CA 下C(3段目)", type = act_types.low_attack, ids = { 0x247, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x246, }, },
			{ disp_name = "CA 立C", name = "CA 近C(2段目)", type = act_types.attack, ids = { 0x244, }, },
			{ disp_name = "真空投げ", name = "CA 真空投げ(3段目)", type = act_types.attack, ids = { 0x22, 0x23, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)昇天明星打ちルート", type = act_types.low_attack, ids = { 0x247, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)昇天明星打ちルート", type = act_types.attack, ids = { 0x249, }, },
			{ disp_name = "CA _8C", name = "CA 8C(3段目)昇天明星打ちルート", type = act_types.attack, ids = { 0x24E, 0x24F, 0x250, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)近立Bルート", type = act_types.attack, ids = { 0x24D, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)下Aルート", type = act_types.attack, ids = { 0x240, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)下Aルート", type = act_types.attack, ids = { 0x24B, }, },
			{ disp_name = "CA 立D", name = "CA 立D(2段目)", type = act_types.attack, ids = { 0x248, }, },
			{ disp_name = "CA 下D", name = "CA 下D(2段目)", type = act_types.low_attack, ids = { 0x24A, }, },
			{ disp_name = "スゥエーC", name = "近スゥエーC", type = act_types.low_attack, ids = { 0x62, 0x63, 0x64, }, },
			{ disp_name = "スゥエーC", name = "スゥエーC", type = act_types.low_attack, ids = { 0x25A, 0x25B, 0x25C, }, },
		},
		-- 望月双角,
		{
			{ disp_name = "フェイント", name = "フェイント まきびし", type = act_types.any, ids = { 0x112, }, },
			{ disp_name = "フェイント", name = "フェイント いかづち", type = act_types.any, ids = { 0x113, }, },
			{ name = "無道縛り投げ", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "地獄門", type = act_types.any, ids = { 0x7C, 0x7D, 0x7E, 0x7F, }, },
			{ name = "昇天殺", type = act_types.attack, ids = { 0x72, 0x73, }, },
			{ name = "雷撃棍", type = act_types.attack, ids = { 0x69, 0x6A, 0x6B, }, },
			{ name = "錫杖上段打ち", type = act_types.attack, ids = { 0x68, }, },
			{ name = "野猿狩り", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, }, },
			{ name = "まきびし", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
			{ name = "憑依弾", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D, }, },
			{ name = "鬼門陣", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, }, },
			{ name = "邪棍舞", type = act_types.low_attack, ids = { 0xAE, 0xAF, 0xB0, }, },
			{ name = "喝", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, 0xBB, }, },
			{ name = "渦炎陣", type = act_types.attack, ids = { 0xC2, 0xC3, 0xC4, 0xC5, }, },
			{ name = "いかづち", type = act_types.attack, ids = { 0xFE, 0xFF, 0x103, 0x100, 0x101, }, },
			{ name = "無惨弾", type = act_types.overhead, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x241, }, },
			{ disp_name = "CA 立C", name = "CA 近立C(2段目)", type = act_types.attack, ids = { 0x240, }, },
			{ disp_name = "CA _6C", name = "CA 6C(2段目)", type = act_types.attack, ids = { 0x243, }, },
			{ disp_name = "CA _2_2C", name = "CA 雷撃棍(3段目)", type = act_types.attack, ids = { 0x24B, }, },
			{ disp_name = "CA 6B", name = "CA 6B(2段目)", type = act_types.attack, ids = { 0x247, }, },
			{ disp_name = "CA _6_2_3A", name = "CA 623A(3段目)", type = act_types.attack, ids = { 0x242, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)立Aルート", type = act_types.low_attack, ids = { 0x244, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)下Aルート", type = act_types.low_attack, ids = { 0x24D, }, },
			{ disp_name = "CA 立C", name = "CA C(2段目)喝ルート", type = act_types.attack, ids = { 0xBC, }, },
		},
		-- ボブ・ウィルソン
		{
			{ disp_name = "フェイント", name = "フェイント ダンシングバイソン", type = act_types.any, ids = { 0x112, }, },
			{ name = "ファルコン", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "ホーネットアタック", type = act_types.any, ids = { 0x7C, 0x7D, 0x7E, }, },
			{ name = "イーグルキャッチ", type = act_types.any, ids = { 0x72, 0x73, 0x74, }, },
			{ name = "フライングフィッシュ", type = act_types.attack, ids = { 0x68, 0x77, 0x78, }, },
			{ name = "イーグルステップ", type = act_types.attack, ids = { 0x69, }, },
			{ name = "レッグプレス", type = act_types.attack, ids = { 0x6A, 0x7A, 0x7B, }, },
			{ name = "エレファントタスク", type = act_types.attack, ids = { 0x6B, }, },
			{ name = "H・ヘッジホック", type = act_types.attack, ids = { 0x6C, }, },
			{ name = "ローリングタートル", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, }, },
			{ name = "サイドワインダー", type = act_types.low_attack, ids = { 0x90, 0x91, 0x92, 0x93, }, },
			{ name = "モンキーダンス", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, }, },
			{ name = "ワイルドウルフ", type = act_types.overhead, ids = { 0xA4, 0xA5, 0xA6, }, },
			{ name = "バイソンホーン", type = act_types.low_attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D, }, },
			{ name = "フロッグハンティング", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBD, 0xBE, 0xBA, 0xBB, 0xBC, }, },
			{ name = "デンジャラスウルフ", type = act_types.overhead, ids = { 0xFF, 0x100, 0x101, 0x102, 0x103, 0x104, }, },
			{ name = "ダンシングバイソン", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x243, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x240, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x242, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x245, }, },
			{ disp_name = "CA _6C", name = "CA 6C(3段目)", type = act_types.attack, ids = { 0x247, }, },
			{ disp_name = "CA _8C", name = "CA 8C(3段目)", type = act_types.overhead, ids = { 0x24A, 0x24B, 0x24C, }, },
		},
		-- ホンフゥ
		{
			{ disp_name = "フェイント", name = "フェイント 制空烈火棍", type = act_types.any, ids = { 0x112, }, },
			{ name = "バックフリップ", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "経絡乱打", type = act_types.any, ids = { 0x81, 0x82, 0x83, 0x84, }, },
			{ name = "ハエタタキ", type = act_types.attack, ids = { 0x69, }, },
			{ name = "踏み込み側蹴り", type = act_types.attack, ids = { 0x68, }, },
			{ name = "トドメヌンチャク", type = act_types.attack, ids = { 0x6A, }, },
			{ name = "九龍の読み", type = act_types.attack, ids = { 0x86, 0x86, 0x87, 0x88, 0x89, }, },
			{ name = "黒龍", type = act_types.attack, ids = { 0xD7, 0xD8, 0xD9, 0xDA, }, },
			{ disp_name = "制空烈火棍", name = "小 制空烈火棍", type = act_types.attack, ids = { 0x90, 0x91, 0x92, 0x93, }, },
			{ disp_name = "制空烈火棍", name = "大 制空烈火棍", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D, }, },
			{ name = "電光石火の天", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, }, },
			{ name = "電光石火の地", type = act_types.low_attack, ids = { 0xA4, 0xA5, 0xA6, }, },
			{ name = "電光パチキ", type = act_types.attack, ids = { 0xA8, }, },
			{ name = "炎の種馬", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0, }, },
			{ name = "必勝！逆襲拳", type = act_types.attack, ids = { 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB, 0xCC, 0xCD, 0xCE, 0xD0, 0xD1, }, },
			{ name = "爆発ゴロー", type = act_types.attack, ids = { 0xFF, 0x101, 0x9C, 0x102, }, },
			{ name = "よかトンハンマー", type = act_types.overhead, ids = { 0x108, 0x109, 0x10A, 0x10B, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x245, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x240, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x242, }, },
			{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x246, }, },
			{ disp_name = "CA 立C", name = "CA 近立C(2段目)近立Aルート", type = act_types.attack, ids = { 0x247, }, },
			{ disp_name = "CA 立C", name = "CA 近立C(3段目)近立Aルート", type = act_types.attack, ids = { 0x248, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)立Aルート", type = act_types.attack, ids = { 0x252, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目) 立Bルート", type = act_types.attack, ids = { 0x24C, 0x24D, 0x24E, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目) 立Bルート", type = act_types.overhead, ids = { 0x24F, 0x250, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)3Aルート", type = act_types.attack, ids = { 0x243, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)3Aルート", type = act_types.attack, ids = { 0x244, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)3Aルート", type = act_types.low_attack, ids = { 0x24B, }, },
			{ disp_name = "CA _3C ", name = "CA 3C(2段目)6Bルート", type = act_types.low_attack, ids = { 0x251, }, },
		},
		-- ブルー・マリー
		{
			{ disp_name = "フェイント", name = "フェイント M.スナッチャー", type = act_types.any, ids = { 0x112, }, },
			{ name = "ヘッドスロー", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "アキレスホールド", type = act_types.any, ids = { 0x7C, 0x7E, 0x7F, }, },
			{ name = "ヒールフォール", type = act_types.overhead, ids = { 0x69, }, },
			{ name = "ダブルローリング", type = act_types.low_attack, ids = { 0x68, 0x6C, }, },
			{ name = "レッグプレス", type = act_types.attack, ids = { 0x6A, }, },
			{ name = "M.リアルカウンター", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xAC, }, },
			{ disp_name = "M.リアルカウンター", name = "M.リアルカウンターA投げ", type = act_types.attack, ids = { 0xAC, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, }, },
			{ disp_name = "M.リアルカウンター", name = "M.リアルカウンターB投げ", type = act_types.attack, ids = { 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, }, },
			{ disp_name = "M.リアルカウンター", name = "M.リアルカウンターC投げ", type = act_types.attack, ids = { 0xE5, 0xE6, 0xE7, }, },
			{ name = "M.スパイダー", type = act_types.attack, ids = { 0x8C, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x8B, }, },
			{ name = "M.スナッチャー", type = act_types.attack, ids = { 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, }, },
			{ name = "M.クラブクラッチ", type = act_types.low_attack, ids = { 0x9A, 0x9B, 0xC4, 0xC5, 0x9D, 0x9E, 0x9F, 0xA0, 0xA1, }, },
			{ name = "ヤングダイブ", type = act_types.overhead, ids = { 0xEA, 0xEB, 0xEC, 0xED, }, },
			{ name = "デンジャラススパイダー", type = act_types.attack, ids = { 0xF0, 0x87, 0x88, 0x89, 0x8A, 0x8B, }, },
			{ name = "リバースキック", type = act_types.overhead, ids = { 0xEE, 0xEF, }, },
			{ name = "スピンフォール", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, }, },
			{ disp_name = "スパイダー", name = "M.スパイダー/ダブルスパイダー 投げ", type = act_types.attack, ids = { 0x88, 0x89, 0x8A, 0x8B, }, },
			{ name = "バーチカルアロー", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, 0xBB, }, },
			--{ disp_name = "スナッチャー", name = "M.スナッチャー/ダブルスナッチャー 投げ", type = act_types.attack, ids = { 0x93, 0x94, 0x95, 0x96, }, },
			{ name = "ストレートスライサー", type = act_types.low_attack, ids = { 0xC2, 0xC3, 0xC4, 0xC5, }, },
			--{ disp_name = "クラッチ", name = "M.クラブクラッチ/ダブルクラッチ 投げ", type = act_types.attack, ids = { 0x9D, 0x9E, 0x9F, 0xA0, 0xA1, }, },
			{ name = "M.ダイナマイトスウィング", type = act_types.attack, ids = { 0xCC, 0xCD, 0xCE, 0xCF, 0xD0, 0xD1, }, },
			{ name = "M.タイフーン", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, 0x103, 0x104, 0x105, 0x106, 0x107, 0x116, }, },
			{ name = "M.エスカレーション", type = act_types.attack, ids = { 0x10B, }, },
			{ name = "M.トリプルエクスタシー", type = act_types.attack, ids = { 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF, }, },
			{ name = "立ち", type = act_types.free, ids = { 0x109, 0x10A, 0x108, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x24C, }, },
			{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x251, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x246, }, },
			{ disp_name = "CA _6C", name = "CA 6C(3段目)", type = act_types.attack, ids = { 0x250, }, },
			{ disp_name = "CA 下C", name = "CA 下C(3段目)", type = act_types.low_attack, ids = { 0x247, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x242, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)下Aルート", type = act_types.attack, ids = { 0x241, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)立Aルート", type = act_types.attack, ids = { 0x240, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)立Cルート", type = act_types.attack, ids = { 0x243, 0x244, 0x245, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)立Cルート", type = act_types.attack, ids = { 0x252, 0x253, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x24D, }, },
			{ disp_name = "CA _6C", name = "CA 6C(2段目)避け攻撃ルート", type = act_types.attack, ids = { 0x249, 0x24A, 0x24B, }, },
		},
		-- フランコ・バッシュ
		{
			{ disp_name = "フェイント", name = "フェイント ガッツダンク", type = act_types.any, ids = { 0x113, }, },
			{ disp_name = "フェイント", name = "フェイント ハルマゲドンバスター", type = act_types.any, ids = { 0x112, }, },
			{ name = "ゴリラッシュ", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "スマッシュ", type = act_types.attack, ids = { 0x68, }, },
			{ name = "バッシュトルネード", type = act_types.attack, ids = { 0x6A, }, },
			{ name = "バロムパンチ", type = act_types.attack, ids = { 0x69, }, },
			{ name = "ダブルコング", type = act_types.overhead, ids = { 0x86, 0x87, 0x88, 0x89, }, },
			{ name = "ザッパー", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
			{ name = "ウェービングブロー", type = act_types.attack, ids = { 0x9A, 0x9B, }, },
			{ name = "ガッツダンク", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xAC, }, },
			{ name = "ゴールデンボンバー", type = act_types.attack, ids = { 0xAD, 0xAE, 0xAF, 0xB0, 0xB1, }, },
			{ name = "ファイナルオメガショット", type = act_types.overhead, ids = { 0xFE, 0xFF, 0x100, }, },
			{ name = "メガトンスクリュー", type = act_types.attack, ids = { 0xF4, 0xF5, 0xF6, 0xF7, 0xFC, 0xF8, }, },
			{ name = "ハルマゲドンバスター", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, }, },
			{ disp_name = "CA 立A", name = "CA 立A(3段目)", type = act_types.attack, ids = { 0x248, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x247, }, },
			{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x242, }, },
			{ disp_name = "CA 立D", name = "CA 立D(2段目)", type = act_types.attack, ids = { 0x240, }, },
			{ disp_name = "CA 立B", name = "CA 立B(3段目)", type = act_types.low_attack, ids = { 0x246, }, },
			{ disp_name = "CA 下C", name = "CA 下C(3段目)", type = act_types.low_attack, ids = { 0x249, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x24D, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.overhead, ids = { 0x24C, }, },
		},
		-- 山崎竜二
		{
			{ disp_name = "フェイント", name = "フェイント 裁きの匕首", type = act_types.any, ids = { 0x112, }, },
			{ name = "ブン投げ", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "目ツブシ", type = act_types.attack, ids = { 0x68, 0x6C, }, },
			{ name = "カチ上げ", type = act_types.attack, ids = { 0x69, }, },
			{ name = "ブッ刺し", type = act_types.overhead, ids = { 0x6A, }, },
			{ name = "昇天", type = act_types.attack, ids = { 0x6B, }, },
			{ disp_name = "蛇使い", name = "蛇使い・上段/蛇だまし", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, }, },
			{ disp_name = "蛇使い", name = "蛇使い・中段/蛇だまし", type = act_types.attack, ids = { 0x90, 0x91, 0x92, 0x93, }, },
			{ disp_name = "蛇使い", name = "蛇使い・下段/蛇だまし", type = act_types.low_attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D, }, },
			{ name = "大蛇", type = act_types.low_attack, ids = { 0x94, }, },
			{ name = "サドマゾ", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, }, },
			{ name = "裁きの匕首", type = act_types.attack, ids = { 0xC2, 0xC3, 0xC4, 0xC5, }, },
			{ name = "ヤキ入れ", type = act_types.overhead, ids = { 0xAE, 0xAF, 0xB0, 0xB4, }, },
			{ name = "倍返し", type = act_types.attack, ids = { 0xB8, 0xBA, 0xB9, 0xBB, 0xBC, }, },
			{ name = "爆弾パチキ", type = act_types.attack, ids = { 0xCC, 0xCD, 0xCE, 0xCF, }, },
			{ name = "トドメ", type = act_types.attack, ids = { 0xD6, 0xDA, 0xD8, 0xDB, 0xD9, }, },
			{ name = "ギロチン", type = act_types.attack, ids = { 0xFF, 0x100, 0x101, 0x102, 0x103, }, },
			{ name = "ドリル", type = act_types.attack, ids = { 0x101, 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x10E, 0x10F, 0x110, 0xE0, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEF, 0xF0, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)3Aルート", type = act_types.attack, ids = { 0x245, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)3Aルート", type = act_types.attack, ids = { 0x247, 0x248, 0x249, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x244, }, },
			{ disp_name = "CA _3C", name = "CA 3C(2段目)", type = act_types.attack, ids = { 0x242, }, },
			{ disp_name = "CA _6C", name = "CA 6C(2段目)", type = act_types.attack, ids = { 0x241, }, },
			{ disp_name = "スゥエーC", name = "近スゥエーC", type = act_types.low_attack, ids = { 0x62, 0x63, 0x64, }, },
			{ disp_name = "スゥエーC", name = "スゥエーC", type = act_types.low_attack, ids = { 0x25A, 0x25B, 0x25C, }, },
		},
		-- 秦崇秀
		{
			{ disp_name = "フェイント", name = "フェイント 海龍照臨", type = act_types.any, ids = { 0x112, }, },
			{ name = "発勁龍", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "光輪殺", type = act_types.overhead, ids = { 0x68, }, },
			{ name = "帝王神足拳", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, 0x8A, }, },
			{ disp_name = "帝王天眼拳", name = "小 帝王天眼拳", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
			{ disp_name = "帝王天眼拳", name = "大 帝王天眼拳", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
			{ disp_name = "帝王天耳拳", name = "小 帝王天耳拳", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, }, },
			{ disp_name = "帝王天耳拳", name = "大 帝王天耳拳", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, }, },
			{ disp_name = "帝王神眼拳", name = "帝王神眼拳（その場）", type = act_types.attack, ids = { 0xC2, 0xC3, }, },
			{ disp_name = "帝王神眼拳", name = "帝王神眼拳（空中）", type = act_types.attack, ids = { 0xCC, 0xCD, 0xCF, }, },
			{ disp_name = "帝王神眼拳", name = "帝王神眼拳（背後）", type = act_types.attack, ids = { 0xD6, 0xD7, }, },
			{ name = "帝王空殺神眼拳", type = act_types.attack, ids = { 0xE0, 0xE1, }, },
			{ name = "竜灯掌", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, }, },
			{ name = "竜灯掌・幻殺", type = act_types.attack, ids = { 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, }, },
			{ name = "帝王漏尽拳", type = act_types.attack, ids = { 0xFE, 0xFF, 0x101, 0x100, }, },
			{ name = "帝王空殺漏尽拳", type = act_types.attack, ids = { 0xEA, 0xEB, 0xEC, 0xEE, 0xEF, 0xED, }, },
			{ name = "海龍照臨", type = act_types.attack, ids = { 0x108, 0x109, 0x109, 0x10A, 0x10B, }, },
			{ name = "立ち", type = act_types.free, ids = { 0x6C, }, },
			{ disp_name = "CA 立A", name = "CA 立A(2段目)", type = act_types.attack, ids = { 0x247, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x246, }, },
			{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x24B, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x240, }, },
			{ disp_name = "CA 下C", name = "CA 下C(3段目)", type = act_types.low_attack, ids = { 0x24C, }, },
			{ disp_name = "CA _6C", name = "CA 6C(3段目)", type = act_types.attack, ids = { 0x242, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x241, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)", type = act_types.low_attack, ids = { 0x248, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)Cルート", type = act_types.attack, ids = { 0x245, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)Cルート", type = act_types.attack, ids = { 0x243, }, },
			{ disp_name = "CA 立C", name = "CA 立C(4段目)Cルート", type = act_types.attack, ids = { 0x244, }, },
		},
		-- 秦崇雷,
		{
			{ disp_name = "フェイント", name = "フェイント 帝王宿命拳", type = act_types.any, ids = { 0x112, }, },
			{ name = "発勁龍", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "龍脚殺", type = act_types.overhead, ids = { 0x68, }, },
			{ name = "帝王神足拳", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, }, },
			{ disp_name = "帝王天眼拳", name = "大 帝王天眼拳", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
			{ disp_name = "帝王天眼拳", name = "小 帝王天眼拳", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
			{ disp_name = "帝王天耳拳", name = "小 帝王天耳拳", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, }, },
			{ disp_name = "帝王天耳拳", name = "大 帝王天耳拳", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, }, },
			{ name = "帝王漏尽拳", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBB, 0xBA, 0xBC, }, },
			{ disp_name = "龍転身", name = "龍転身（前方）", type = act_types.any, ids = { 0xC2, 0xC3, 0xC4, }, },
			{ disp_name = "龍転身", name = "龍転身（後方）", type = act_types.any, ids = { 0xCC, 0xCD, 0xCE, }, },
			{ name = "帝王宿命拳", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, }, },
			{ name = "帝王宿命拳", type = act_types.attack, ids = { 0x101, 0x102, 0x104, 0x105, 0x107, 0x115, 0x116, 0x103, 0x106, }, },
			{ name = "帝王龍声拳", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x243, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)立Bルート", type = act_types.attack, ids = { 0x242, }, },
			{ disp_name = "CA _8C", name = "CA 8C(3段目)立Bルート", type = act_types.overhead, ids = { 0x244, 0x245, 0x246, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)立Bルート", type = act_types.attack, ids = { 0x240, }, },
		},
		-- ダック・キング
		{
			{ disp_name = "フェイント", name = "フェイント ダックダンス", type = act_types.any, ids = { 0x112, }, },
			{ name = "ローリングネックスルー", type = act_types.attack, ids = { 0x6D, 0x6E, 0x6F, 0x70, 0x71, }, },
			{ name = "ニードルロー", type = act_types.low_attack, ids = { 0x68, }, },
			{ name = "マッドスピンハンマー", type = act_types.overhead, ids = { 0x69, }, },
			{ name = "ショッキングボール", type = act_types.attack, ids = { 0x6A, 0x6B, 0x6C, }, },
			{ disp_name = "ヘッドスピンアタック", name = "小ヘッドスピンアタック", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, 0x8A, }, },
			{ disp_name = "ヘッドスピンアタック", name = "大ヘッドスピンアタック", type = act_types.attack, ids = { 0x90, 0x91, 0x92, 0x93, 0x95, 0x96, 0x94, }, },
			{ disp_name = "着地", name = "ヘッドスピンアタック着地", type = act_types.any, ids = { 0x3D, }, },
			{ name = "フライングスピンアタック", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0x9E, }, },
			{ name = "ダンシングダイブ", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, }, },
			{ name = "ブレイクストーム", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, 0xB2, 0xB6, 0xB4, 0xB5, 0xB3, 0xB7, }, },
			{ name = "ダックフェイント・地", type = act_types.any, ids = { 0xC2, 0xC3, 0xC4, }, },
			{ name = "ダックフェイント・空", type = act_types.any, ids = { 0xB8, 0xB9, 0xBA, }, },
			{ name = "ダイビングパニッシャー", type = act_types.attack, ids = { 0xE0, 0xE1, 0xE2, 0xE3, }, },
			{ name = "ローリングパニッシャー", type = act_types.attack, ids = { 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, }, },
			{ name = "ダンシングキャリバー", type = act_types.attack, ids = { 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0x115, }, },
			{ name = "ブレイクハリケーン", type = act_types.attack, ids = { 0xEE, 0xEF, 0xF0, 0xF1, 0xF2, 0xF3, 0x116, 0xF4, }, },
			{ name = "ブレイクスパイラル", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x102, }, },
			{ disp_name = "ブレイクスパイラルBR", name = "ブレイクスパイラルBR/クレイジーBR", type = act_types.attack, ids = { 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, }, },
			{ name = "ダックダンス", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x10E, 0x10F, }, },
			{ name = "スーパーポンピングマシーン", type = act_types.low_attack, ids = { 0x77, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7F, 0x82, 0x80, 0x81, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x24E, }, },
			{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x24F, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x243, }, },
			{ disp_name = "CA 下C", name = "CA 下C(3段目)", type = act_types.low_attack, ids = { 0x24D, }, },
			{ disp_name = "CA _6C", name = "CA 6C(3段目)", type = act_types.attack, ids = { 0x242, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x244, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)", type = act_types.attack, ids = { 0x24C, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)下Cルート", type = act_types.low_attack, ids = { 0x245, }, },
			{ disp_name = "旧ブレイクストーム", name = "CA ブレイクストーム", type = act_types.attack, ids = { 0x247, 0x248, 0x249, 0x24A, }, },
			{ name = "立B", type = act_types.overhead, ids = { 0x45, 0x72, 0x73, 0x74, }, },
		},
		-- キム・カッファン
		{
			{ disp_name = "フェイント", name = "フェイント 鳳凰脚", type = act_types.any, ids = { 0x112, }, },
			{ name = "体落とし", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "ネリチャギ", type = act_types.overhead, ids = { 0x68, 0x69, 0x6A, }, },
			{ name = "飛燕斬", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, }, },
			{ disp_name = "半月斬", name = "小 半月斬", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
			{ disp_name = "半月斬", name = "大 半月斬", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
			{ name = "飛翔脚", type = act_types.low_attack, ids = { 0xA4, 0xA6, 0xA5, 0xA7, 0xA8, 0xA9, }, },
			{ disp_name = "空砂塵", name = "空砂塵/天昇斬", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, 0xB2, 0xB3, 0xB4, }, },
			{ name = "覇気脚", type = act_types.low_attack, ids = { 0xB8, }, },
			{ name = "鳳凰天舞脚", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, 0x103, 0x104, 0x105, 0x106, 0x107, }, },
			{ name = "鳳凰脚", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x10E, 0x10F, 0x110, 0x115, }, },
			{ name = "CA ネリチャギ", type = act_types.overhead, ids = { 0x24B, 0x24A, 0x24C, }, },
			{ disp_name = "CA 立A", name = "CA 立A(2段目)立Cルート", type = act_types.attack, ids = { 0x241, }, },
			{ disp_name = "CA 立B", name = "CA 立B(3段目)立Cルート", type = act_types.attack, ids = { 0x244, }, },
			{ disp_name = "CA 立C", name = "CA 立C(4段目)立Cルート", type = act_types.attack, ids = { 0x246, 0x247, 0x248, }, },
			{ disp_name = "CA 立A", name = "CA 立A(2段目)", type = act_types.attack, ids = { 0x240, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x243, }, },
			{ disp_name = "CA 立B", name = "CA 立B(3段目)", type = act_types.attack, ids = { 0x249, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x242, }, },
			{ name = "下A", type = act_types.low_attack, ids = { 0x47, }, },
		},
		-- ビリー・カーン
		{
			{ disp_name = "フェイント", name = "フェイント 強襲飛翔棍", type = act_types.any, ids = { 0x112, }, },
			{ name = "一本釣り投げ", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "地獄落とし", type = act_types.any, ids = { 0x81, 0x82, 0x83, 0x84, }, },
			{ disp_name = "三節棍中段打ち", name = "三節棍中段打ち/火炎三節棍中段打ち", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, 0x90, 0x91, 0x92, 0x93, }, },
			{ name = "燕落とし", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
			{ name = "火龍追撃棍", type = act_types.attack, ids = { 0xB8, 0xB9, }, },
			{ name = "旋風棍", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, }, },
			{ name = "強襲飛翔棍", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, }, },
			{ name = "超火炎旋風棍", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, }, },
			{ name = "紅蓮殺棍", type = act_types.attack, ids = { 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, }, },
			{ name = "サラマンダーストリーム", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.low_attack, ids = { 0x241, }, },
			{ disp_name = "CA _6C", name = "CA 6C(2段目)", type = act_types.attack, ids = { 0x248, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)", type = act_types.attack, ids = { 0x243, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)下Cルート", type = act_types.attack, ids = { 0x245, }, },
			{ disp_name = "集点連破棍", name = "CA 236C(2段目)下Cルート", type = act_types.attack, ids = { 0x246, }, },
		},
		-- チン・シンザン
		{
			{ disp_name = "フェイント", name = "フェイント 破岩撃", type = act_types.any, ids = { 0x112, }, },
			{ disp_name = "フェイント", name = "フェイント クッサメ砲", type = act_types.any, ids = { 0x113, }, },
			{ name = "合気投げ", type = act_types.attack, ids = { 0x6D, 0x6E, }, },
			{ name = "頭突殺", type = act_types.attack, ids = { 0x81, 0x83, 0x84, }, },
			{ name = "発勁裏拳", type = act_types.attack, ids = { 0x68, }, },
			{ name = "落撃双拳", type = act_types.overhead, ids = { 0x69, }, },
			{ disp_name = "気雷砲", name = "気雷砲（前方）", type = act_types.attack, ids = { 0x86, 0x87, 0x88, }, },
			{ disp_name = "気雷砲", name = "気雷砲（対空）", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
			{ name = "破岩撃", type = act_types.low_attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xAE, 0xAF, 0xB0, 0xB1, 0xB2, }, },
			{ name = "超太鼓腹打ち/満腹対空", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0xA0, 0x9F, 0x9C, }, },
			{ name = "軟体オヤジ", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, 0xBB, }, },
			{ name = "クッサメ砲", type = act_types.attack, ids = { 0xC2, 0xC3, 0xC4, 0xC5, }, },
			{ name = "爆雷砲", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, }, },
			{ name = "ホエホエ弾", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x114, 0x115, 0x116, 0x10E, 0x110, 0x10F, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)近立Aルート", type = act_types.low_attack, ids = { 0x24A, }, },
			{ disp_name = "CA _3C", name = "CA 3C(2段目)近立Aルート", type = act_types.attack, ids = { 0x242, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)立Aルート", type = act_types.attack, ids = { 0x240, }, },
			{ disp_name = "CA _3C", name = "CA 3C(2段目)立Aルート", type = act_types.attack, ids = { 0x249, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)立Cルート", type = act_types.attack, ids = { 0x241, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)ライン攻撃ルート", type = act_types.attack, ids = { 0x246, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)ライン攻撃ルート", type = act_types.attack, ids = { 0x24B, 0x24C, 0x24D, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)ライン攻撃ルート", type = act_types.low_attack, ids = { 0x247, }, },
			{ disp_name = "CA _6_6B", name = "CA 66B(3段目)ライン攻撃ルート", type = act_types.any, ids = { 0x248, }, },
			{ disp_name = "CA D", name = "CA D(2段目)", type = act_types.overhead, ids = { 0x243, }, },
			{ disp_name = "CA _3C", name = "CA 3C(2段目)6Aルート", type = act_types.any, ids = { 0x244, }, },
			{ disp_name = "CA _1C", name = "CA 1C(2段目)6Aルート", type = act_types.any, ids = { 0x245, }, },
		},
		-- タン・フー・ルー,
		{
			{ disp_name = "フェイント", name = "フェイント 旋風剛拳", type = act_types.any, ids = { 0x112, }, },
			{ name = "裂千掌", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "右降龍", type = act_types.attack, ids = { 0x68, }, },
			{ name = "衝波", type = act_types.attack, ids = { 0x86, 0x87, 0x88, }, },
			{ disp_name = "箭疾歩", name = "小 箭疾歩", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
			{ disp_name = "箭疾歩", name = "大 箭疾歩", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
			{ name = "裂千脚", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, 0xB2, }, },
			{ name = "撃放", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, }, },
			{ name = "旋風剛拳", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, }, },
			{ name = "大撃放", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)避け攻撃ルート", type = act_types.overhead, ids = { 0x247, 0x248, 0x249, }, },
			{ name = "挑発", type = act_types.provoke, ids = { 0x24A, 0x24B, }, },
		},
		-- ローレンス・ブラッド
		{
			{ name = "マタドールバスター", type = act_types.any, ids = { 0x6D, 0x6E, 0x6F, }, },
			{ name = "トルネードキック", type = act_types.attack, ids = { 0x68, }, },
			{ name = "オーレィ", type = act_types.any, ids = { 0x69, }, },
			{ disp_name = "ブラッディスピン", name = "小 ブラッディスピン", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, }, },
			{ disp_name = "ブラッディスピン", name = "大 ブラッディスピン", type = act_types.attack, ids = { 0x90, 0x91, 0x93, 0x94, 0x92, }, },
			{ name = "ブラッディスピン隙", type = act_types.attack, ids = { 0x3D, }, },
			{ name = "ブラッディサーベル", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
			{ name = "ブラッディカッター", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, 0xB2, }, },
			{ name = "ブラッディミキサー", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, }, },
			{ name = "ブラッディフラッシュ", type = act_types.attack, ids = { 0xFF, 0x100, 0x101, 0x102, }, },
			{ name = "ブラッディシャドー", type = act_types.attack, ids = { 0x108, 0x109, 0x10E, 0x10D, 0x10B, 0x10C, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x245, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x246, }, },
			{ disp_name = "CA 立D", name = "CA 立D(2段目)", type = act_types.attack, ids = { 0x24C, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)オーレィ", type = act_types.attack, ids = { 0x248, }, },
			{ disp_name = "CA _6_3_2C", name = "CA 632C(3段目)オーレィ", type = act_types.overhead, ids = { 0x249, 0x24A, 0x24B, }, },
		},
		-- ヴォルフガング・クラウザー
		{
			{ disp_name = "フェイント", name = "フェイント ブリッツボール", type = act_types.any, ids = { 0x112, }, },
			{ disp_name = "フェイント", name = "フェイント カイザーウェイブ", type = act_types.any, ids = { 0x113, }, },
			{ name = "ニースマッシャー", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "デスハンマー", type = act_types.overhead, ids = { 0x68, }, },
			{ name = "カイザーボディプレス", type = act_types.attack, ids = { 0x69, 0x72, }, },
			{ name = "ダイビングエルボー", type = act_types.attack, ids = { 0x73, 0x74, 0x75, }, },
			{ disp_name = "ブリッツボール", name = "ブリッツボール・上段", type = act_types.attack, ids = { 0x86, 0x87, 0x88, }, },
			{ disp_name = "ブリッツボール", name = "ブリッツボール・下段", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
			{ name = "レッグトマホーク", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
			{ name = "デンジャラススルー", type = act_types.attack, ids = { 0xAE, 0xAF, }, },
			{ name = "グリフォンアッパー", type = act_types.attack, ids = { 0x248, }, },
			{ name = "リフトアップブロー", type = act_types.attack, ids = { 0xC2, 0xC3, }, },
			{ name = "フェニックススルー", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, }, },
			{ name = "カイザークロー", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, }, },
			{ name = "カイザーウェイブ", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, }, },
			{ name = "ギガティックサイクロン", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0xC, 0x10C, 0x10D, 0x10C, 0x10E, }, },
			{ name = "アンリミテッドデザイア", type = act_types.attack, ids = { 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)近立Aルート", type = act_types.attack, ids = { 0x240, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)立Aルート", type = act_types.attack, ids = { 0x24E, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)立Bルート", type = act_types.attack, ids = { 0x242, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)下Aルート", type = act_types.attack, ids = { 0x241, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)", type = act_types.low_attack, ids = { 0x244, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)近立Cルート", type = act_types.attack, ids = { 0x243, }, },
			{ disp_name = "CA _2_3_6C", name = "CA 236C(2段目)近立Cルート", type = act_types.attack, ids = { 0x245, }, },
			{ disp_name = "CA _3C", name = "CA 3C(2段目)近立Cルート", type = act_types.attack, ids = { 0x247, }, },
		},
		-- リック・ストラウド
		{
			{ disp_name = "フェイント", name = "フェイント シューティングスター", type = act_types.any, ids = { 0x112, }, },
			{ name = "ガング・ホー", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "チョッピングライト", type = act_types.overhead, ids = { 0x68, 0x69, }, },
			{ name = "スマッシュソード", type = act_types.attack, ids = { 0x6A, }, },
			{ name = "パニッシャー", type = act_types.attack, ids = { 0x6B, }, },
			{ disp_name = "シューティングスター", name = "小 シューティングスター", type = act_types.attack, ids = { 0x86, 0x87, 0x8C, 0x88, 0x89, 0x8A, 0x8B, }, },
			{ disp_name = "シューティングスター", name = "大 シューティングスター", type = act_types.attack, ids = { 0x90, 0x91, 0x92, 0x93, 0x94, }, },
			{ name = "シューティングスターEX", type = act_types.attack, ids = { 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0x3D, }, },
			{ name = "ブレイジングサンバースト", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, }, },
			{ name = "ヘリオン", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB1, 0xB0, }, },
			{ name = "フルムーンフィーバー", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, }, },
			{ name = "ディバインブラスト/フェイクブラスト", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0x9F, }, },
			{ name = "ガイアブレス", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, }, },
			{ name = "ハウリング・ブル", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)近立Aルート", type = act_types.attack, ids = { 0x240, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)近立A Cルート", type = act_types.attack, ids = { 0x243, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)近立Aルート", type = act_types.attack, ids = { 0x24D, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)立A Bルート", type = act_types.attack, ids = { 0x241, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)立Aルート", type = act_types.attack, ids = { 0x244, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)立Aルート", type = act_types.attack, ids = { 0x246, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)近立Bルート", type = act_types.attack, ids = { 0x253, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)近立Bルート 遠Bルート", type = act_types.attack, ids = { 0x251, }, },
			{ disp_name = "CA 3C(", name = "CA 3C(3段目)近立Bルート", type = act_types.attack, ids = { 0x248, }, },
			{ disp_name = "CA 下B", name = "CA 下B(2段目)近立Bルート 下Aルート", type = act_types.attack, ids = { 0x242, }, },
			{ disp_name = "CA 下C", name = "CA 下C(3段目)近立Bルート 下Aルート", type = act_types.low_attack, ids = { 0x247, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)下Aルート", type = act_types.attack, ids = { 0x245, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)下Bルート", type = act_types.attack, ids = { 0x24C, }, },
			{ disp_name = "CA 下C", name = "CA 下C(2段目)下Bルート", type = act_types.low_attack, ids = { 0x24A, }, },
			{ disp_name = "CA C", name = "CA C(3段目)遠立Bルート", type = act_types.attack, ids = { 0x24E, 0x24F, 0x250, }, },
			{ disp_name = "CA _2_2C", name = "CA 22C(3段目)遠立Bルート", type = act_types.overhead, ids = { 0xE6, 0xE7, }, },
			{ disp_name = "CA _3_3B", name = "CA 33B(2段目)", type = act_types.overhead, ids = { 0xE0, 0xE1, }, },
			{ disp_name = "CA _4C", name = "CA 4C(2段目)", type = act_types.attack, ids = { 0x249, }, },
		},
		-- 李香緋
		{
			{ disp_name = "フェイント", name = "フェイント 天崩山", type = act_types.any, ids = { 0x113, }, },
			{ disp_name = "フェイント", name = "フェイント 大鉄神", type = act_types.any, ids = { 0x112, }, },
			{ name = "力千後宴", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "裡門頂肘", type = act_types.attack, ids = { 0x68, 0x69, 0x6A, }, },
			{ name = "後捜腿", type = act_types.attack, ids = { 0x6B, }, },
			{ disp_name = "那夢波", name = "小 那夢波", type = act_types.attack, ids = { 0x86, 0x87, 0x88, }, },
			{ disp_name = "那夢波", name = "大 那夢波", type = act_types.attack, ids = { 0x90, 0x91, 0x92, 0x93, }, },
			{ disp_name = "閃里肘皇", name = "閃里肘皇/貫空/心砕把", type = act_types.attack, ids = { 0x9E, 0x9F, 0xA2, 0xA1, 0xA7, 0xAD, 0xA3, 0xA4, 0xA5, 0xA6, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC, }, },
			{ name = "天崩山", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D, }, },
			{ disp_name = "詠酒", name = "詠酒・対ジャンプ攻撃", type = act_types.attack, ids = { 0xB8, }, },
			{ disp_name = "詠酒", name = "詠酒・対立ち攻撃", type = act_types.attack, ids = { 0xAE, }, },
			{ disp_name = "詠酒", name = "詠酒・対しゃがみ攻撃", type = act_types.attack, ids = { 0xC2, }, },
			{ name = "大鉄神", type = act_types.attack, ids = { 0xF4, 0xF5, 0xF6, 0xF7, }, },
			{ name = "超白龍", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, 0x103, }, },
			{ name = "真心牙", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x10E, 0x10F, 0x110, }, },
			{ disp_name = "CA 立A", name = "CA 立A(2段目)", type = act_types.attack, ids = { 0x241, }, },
			{ disp_name = "CA 立A", name = "CA 立A(3段目)", type = act_types.attack, ids = { 0x242, }, },
			{ disp_name = "CA 立A", name = "CA 立A(4段目)", type = act_types.attack, ids = { 0x243, }, },
			{ disp_name = "CA 下A", name = "CA 下A(2段目)", type = act_types.attack, ids = { 0x244, }, },
			{ disp_name = "CA 下A", name = "CA 下A(3段目)", type = act_types.attack, ids = { 0x245, }, },
			{ disp_name = "CA 下A", name = "CA 下A(4段目)", type = act_types.attack, ids = { 0x246, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目、4段目)", type = act_types.attack, ids = { 0x24C, }, },
			{ disp_name = "CA 立B", name = "CA 立B(4段目)", type = act_types.attack, ids = { 0x24D, }, },
			{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x24A, }, },
			{ disp_name = "CA 立A", name = "CA 立A(3段目)Cのあと", type = act_types.attack, ids = { 0x24B, }, },
			{ disp_name = "CA 立C", name = "CA 立C(4段目)CAのあと", type = act_types.attack, ids = { 0x24C, }, },
			{ disp_name = "挑発", name = "アッチョンブリケ", type = act_types.provoke, ids = { 0x283, }, },
			{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x246, }, },
			{ disp_name = "CA 下B", name = "CA 下B(2段目)下Bルート", type = act_types.low_attack, ids = { 0x24E, }, },
			{ disp_name = "CA 立C", name = "CA 立C(3段目)Bルート", type = act_types.overhead, ids = { 0x249, }, },
			{ disp_name = "CA _3C", name = "CA 3C(3段目)Bルート", type = act_types.provoke, ids = { 0x250, 0x251, 0x252, }, },
			{ disp_name = "CA 下C", name = "CA 下C(3段目)Bルート", type = act_types.low_attack, ids = { 0x287, }, },
			{ disp_name = "CA _6_6A", name = "CA 66A", type = act_types.attack, ids = { 0x24F, }, },
		},
		-- アルフレッド
		{
			{ disp_name = "フェイント", name = "フェイント クリティカルウィング", type = act_types.any, ids = { 0x112, }, },
			{ disp_name = "フェイント", name = "フェイント オーグメンターウィング", type = act_types.any, ids = { 0x113, }, },
			{ name = "バスタソニックウィング", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "フロントステップキック", type = act_types.attack, ids = { 0x68, }, },
			{ name = "バックステップキック", type = act_types.attack, ids = { 0x78, }, },
			{ name = "フォッカー", type = act_types.attack, ids = { 0x69, }, },
			{ disp_name = "クリティカルウィング", name = "小 クリティカルウィング", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, }, },
			{ disp_name = "クリティカルウィング", name = "大 クリティカルウィング", type = act_types.attack, ids = { 0x90, 0x91, 0x92, 0x93, }, },
			{ name = "オーグメンターウィング", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D, }, },
			{ name = "ダイバージェンス", type = act_types.attack, ids = { 0xA4, 0xA5, }, },
			{ name = "メーデーメーデー", type = act_types.attack, ids = { 0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xAE, 0xAF, 0xB0, 0xB1, }, },
			{ name = "S.TOL", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, }, },
			{ name = "ショックストール", type = act_types.attack, ids = { 0x100, 0x101, 0x102, 0x103, 0x104, 0x105, 0xFE, 0xFF, 0x100, 0xF4, 0xF5, 0xF6, 0xF7, }, },
			{ name = "ウェーブライダー", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, }, },
		},
		{
			-- 共通行動
			{ name = "立ち", type = act_types.free, ids = { 0x1, 0x0, 0x23, 0x22, }, },
			{ name = "立ち振り向き", type = act_types.free, ids = { 0x1D, }, },
			{ name = "しゃがみ振り向き", type = act_types.free, ids = { 0x1E, }, },
			{ name = "振り向き中", type = act_types.free, ids = { 0x3D, }, },
			{ name = "しゃがみ振り向き中", type = act_types.free, ids = { 0x3E, }, },
			{ name = "しゃがみ", type = act_types.free, ids = { 0x4, 0x24, 0x25, }, },
			{ name = "しゃがみ途中", type = act_types.free, ids = { 0x5, }, },
			{ name = "立ち途中", type = act_types.free, ids = { 0x6, }, },
			{ name = "前歩き", type = act_types.free, ids = { 0x2, }, },
			{ name = "後歩き", type = act_types.free, ids = { 0x3, }, },
			{ name = "ダッシュ", type = act_types.any, ids = { 0x17, 0x18, 0x19, }, },
			{ name = "バックステップ", type = act_types.any, ids = { 0x1A, 0x1B, 0x1C, }, },
			{ name = "しゃがみ歩き", type = act_types.free, ids = { 0x7, }, },
			{ name = "スゥエー移動", type = act_types.any, ids = { 0x26, 0x27, 0x28, }, },
			{ name = "スゥエー戻り", type = act_types.any, ids = { 0x36, 0x37, 0x38, }, },
			{ name = "クイックロール", type = act_types.any, ids = { 0x39, 0x3A, 0x3B, }, },
			{ disp_name = "立ち", name = "スゥエーライン上 立ち", type = act_types.free, ids = { 0x21, 0x40, 0x20, 0x3F, }, },
			{ disp_name = "前歩き", name = "スゥエーライン上 前歩き", type = act_types.free, ids = { 0x2D, 0x2C, }, },
			{ disp_name = "後歩き", name = "スゥエーライン上 後歩き", type = act_types.free, ids = { 0x2E, 0x2F, }, },
			{ disp_name = "ダッシュ", name = "スゥエーライン上 ダッシュ", type = act_types.any, ids = { 0x30, 0x31, 0x32, }, },
			{ disp_name = "バックステップ", name = "スゥエーライン上 バックステップ", type = act_types.any, ids = { 0x33, 0x34, 0x35, }, },
			{ disp_name = "スゥエーA", name = "近スゥエーA", type = act_types.overhead, ids = { 0x5C, 0x5D, 0x5E, }, },
			{ disp_name = "スゥエーB", name = "近スゥエーB", type = act_types.low_attack, ids = { 0x5F, 0x60, 0x61, }, },
			{ disp_name = "スゥエーC", name = "近スゥエーC", type = act_types.attack, ids = { 0x62, 0x63, 0x64, }, },
			{ disp_name = "スゥエーA", name = "スゥエーA", type = act_types.overhead, ids = { 0x254, 0x255, 0x256, }, },
			{ disp_name = "スゥエーB", name = "スゥエーB", type = act_types.low_attack, ids = { 0x257, 0x258, 0x259, }, },
			{ disp_name = "スゥエーC", name = "スゥエーC", type = act_types.attack, ids = { 0x25A, 0x25B, 0x25C, }, },
			{ name = "ジャンプ移行", type = act_types.any, ids = { 0x8, 0xB, }, },
			{ disp_name = "着地", name = "ジャンプ着地", type = act_types.any, ids = { 0x9, }, },
			{ disp_name = "ジャンプ", name = "垂直ジャンプ", type = act_types.any, ids = { 0xB, 0xC, }, },
			{ disp_name = "ジャンプ", name = "前ジャンプ", type = act_types.any, ids = { 0xD, 0xE, }, },
			{ disp_name = "ジャンプ", name = "後ジャンプ", type = act_types.any, ids = { 0xF, 0x10, }, },
			{ disp_name = "小ジャンプ", name = "垂直小ジャンプ", type = act_types.any, ids = { 0xB, 0x11, 0x12, }, },
			{ disp_name = "小ジャンプ", name = "前小ジャンプ", type = act_types.any, ids = { 0xD, 0x13, 0x14, }, },
			{ disp_name = "小ジャンプ", name = "後小ジャンプ", type = act_types.any, ids = { 0xF, 0x15, 0x16, }, },
			{ name = "テクニカルライズ", type = act_types.any, ids = { 0x13C, 0x13D, 0x13E, }, },
			{ name = "グランドスゥエー", type = act_types.any, ids = { 0x2CA, 0x2C8, 0x2C9, }, },
			{ name = "避け攻撃", type = act_types.attack, ids = { 0x67, }, },
			{ name = "近立A", type = act_types.attack, ids = { 0x41, }, },
			{ name = "近立B", type = act_types.attack, ids = { 0x42, }, },
			{ name = "近立C", type = act_types.attack, ids = { 0x43, }, },
			{ name = "立A", type = act_types.attack, ids = { 0x44, }, },
			{ name = "立B", type = act_types.attack, ids = { 0x45, }, },
			{ name = "立C", type = act_types.attack, ids = { 0x46, }, },
			{ disp_name = "対スゥエーライン攻撃", name = "対スゥエーライン攻撃(上)", type = act_types.attack, ids = { 0x65, }, },
			{ name = "下A", type = act_types.attack, ids = { 0x47, }, },
			{ name = "下B", type = act_types.low_attack, ids = { 0x48, }, },
			{ name = "下C", type = act_types.low_attack, ids = { 0x49, }, },
			{ disp_name = "対スゥエーライン攻撃", name = "対スゥエーライン攻撃(下)", type = act_types.low_attack, ids = { 0x66, }, },
			{ disp_name = "着地", name = "ジャンプ着地(小攻撃後)", type = act_types.attack, ids = { 0x56, 0x59, }, },
			{ disp_name = "着地", name = "ジャンプ着地(大攻撃後)", type = act_types.attack, ids = { 0x57, 0x5A, }, },
			{ disp_name = "ジャンプA", name = "垂直ジャンプA", type = act_types.attack, ids = { 0x4A, }, },
			{ disp_name = "ジャンプB", name = "垂直ジャンプB", type = act_types.attack, ids = { 0x4B, }, },
			{ disp_name = "ジャンプC", name = "垂直ジャンプC", type = act_types.attack, ids = { 0x4C, }, },
			{ name = "ジャンプ振り向き", type = act_types.attack, ids = { 0x1F, }, },
			{ name = "ジャンプA", type = act_types.overhead, ids = { 0x4D, }, },
			{ name = "ジャンプB", type = act_types.overhead, ids = { 0x4E, }, },
			{ name = "ジャンプC", type = act_types.overhead, ids = { 0x4F, }, },
			{ disp_name = "小ジャンプA", name = "垂直小ジャンプA", type = act_types.overhead, ids = { 0x50, }, },
			{ disp_name = "小ジャンプB", name = "垂直小ジャンプB", type = act_types.overhead, ids = { 0x51, }, },
			{ disp_name = "小ジャンプC", name = "垂直小ジャンプC", type = act_types.overhead, ids = { 0x52, }, },
			{ name = "小ジャンプA", type = act_types.overhead, ids = { 0x53, }, },
			{ name = "小ジャンプB", type = act_types.overhead, ids = { 0x54, }, },
			{ name = "小ジャンプC", type = act_types.overhead, ids = { 0x55, }, },
			{ name = "挑発", type = act_types.provoke, ids = { 0x196, }, },
			{ name = "投げ", type = act_types.any, ids = { 0x6D, 0x6E, }, },
			{ name = "ダウン", type = act_types.any, ids = { 0x192, }, },
			{ disp_name = "おきあがり", name = "ダウンおきあがり", type = act_types.any, ids = { 0x193, 0x13B, }, },
			{ name = "気絶", type = act_types.any, ids = { 0x194, 0x195, }, },
			{ name = "ガード", type = act_types.any, ids = { 0x117, 0x118, 0x119, 0x11A, 0x11B, 0x11C, 0x11D, 0x11E, 0x11F, 0x120, 0x121, 0x122, 0x123, 0x124, 0x125, 0x126, 0x127, 0x128, 0x129, 0x12A, 0x12C, 0x12D, 0x131, 0x132, 0x133, 0x134, 0x135, 0x136, 0x137, 0x139, }, },
			{ name = "やられ", type = act_types.any, ids = { 0x13F, 0x140, 0x141, 0x142, 0x143, 0x144, 0x145, 0x146, 0x147, 0x148, 0x149, 0x14A, 0x14B, 0x14C, 0x14C, 0x14D, 0x14E, 0x14F, }, },
		},
	}
	local char_fireball_base = {
		-- テリー・ボガード
		{
			{ name = "パワーウェイブ", type = act_types.attack, ids = { 0x265, 0x266, 0x26A, }, },
			{ name = "ラウンドウェイブ", type = act_types.low_attack, ids = { 0x260, }, },
			{ name = "パワーゲイザー", type = act_types.attack, ids = { 0x261, }, },
			{ name = "トリプルゲイザー", type = act_types.attack, ids = { 0x267, }, },
		},
		-- アンディ・ボガード
		{
			{ name = "飛翔拳", type = act_types.attack, ids = { 0x262, 0x263, }, },
			{ name = "激飛翔拳", type = act_types.attack, ids = { 0x266, 0x267, }, },
		},
		-- 東丈
		{
			{ name = "ハリケーンアッパー", type = act_types.attack, ids = { 0x267, 0x269, }, },
			{ name = "スクリューアッパー", type = act_types.attack, ids = { 0x269, 0x26A, 0x26B, }, },
		},
		-- 不知火舞
		{
			{ name = "花蝶扇", type = act_types.attack, ids = { 0x261, 0x262, 0x263, }, },
			{ name = "龍炎舞", type = act_types.attack, ids = { 0x264, }, },
		},
		-- ギース・ハワード
		{
			{ name = "烈風拳", type = act_types.attack, ids = { 0x261, 0x260, 0x276, }, },
			{ name = "ダブル烈風拳", type = act_types.attack, ids = { 0x262, 0x263, 0x264, 0x265, }, },
			{ name = "レイジングストーム", type = act_types.attack, ids = { 0x269, 0x26B, 0x26A, }, },
		},
		-- 望月双角,
		{
			{ name = "雷撃棍", type = act_types.attack, ids = { 0x260, }, },
			{ name = "野猿狩り/掴み", type = act_types.attack, ids = { 0x277, 0x27C, }, },
			{ name = "まきびし", type = act_types.low_attack, ids = { 0x274, 0x275, }, },
			{ name = "憑依弾", type = act_types.attack, ids = { 0x263, 0x266, }, },
			{ name = "邪棍舞", type = act_types.low_attack, ids = { 0xF4, 0xF5, }, },
			{ name = "突破", type = act_types.attack, ids = { 0xFA, }, },
			{ name = "降破", type = act_types.overhead, ids = { 0xF9, }, },
			{ name = "倒破", type = act_types.low_attack, ids = { 0xF7, }, },
			{ name = "払破", type = act_types.attack, ids = { 0xF8, }, },
			{ name = "天破", type = act_types.attack, ids = { 0xF6, }, },
			{ name = "喝", type = act_types.attack, ids = { 0x282, 0x283, }, },
			{ name = "いかづち", type = act_types.attack, ids = { 0x286, 0x287, }, },
		},
		-- ボブ・ウィルソン
		{
		},
		-- ホンフゥ
		{
			{ name = "よかトンハンマー", type = act_types.attack, ids = { 0x26B, }, },
		},
		-- ブルー・マリー
		{
		},
		-- フランコ・バッシュ
		{
			{ name = "ザッパー", type = act_types.attack, ids = { 0x269, }, },
			{ name = "ファイナルオメガショット", type = act_types.attack, ids = { 0x26C, }, },
		},
		-- 山崎竜二
		{
			{ name = "目ツブシ", type = act_types.attack, ids = { 0x261, }, },
			{ name = "倍返し", type = act_types.attack, ids = { 0x262, 0x263, 0x270, 0x26D, }, },
		},
		-- 秦崇秀
		{
			{ name = "帝王天眼拳", type = act_types.attack, ids = { 0x262, 0x263, 0x265, }, },
			{ name = "海龍照臨", type = act_types.attack, ids = { 0x273, 0x274, }, },
			{ name = "帝王漏尽拳", type = act_types.attack, ids = { 0x26C, }, },
			{ name = "帝王空殺漏尽拳", type = act_types.attack, ids = { 0x26F, }, },
		},
		-- 秦崇雷,
		{
			{ name = "帝王漏尽拳", type = act_types.attack, ids = { 0x266, }, },
			{ name = "帝王天眼拳", type = act_types.attack, ids = { 0x26E, }, },
			{ name = "帝王宿命拳", type = act_types.attack, ids = { 0x268, 0x273, }, },
			{ name = "帝王龍声拳", type = act_types.attack, ids = { 0x26B, }, },
		},
		-- ダック・キング
		{
		},
		-- キム・カッファン
		{
		},
		-- ビリー・カーン
		{
			{ name = "三節棍中段打ち", type = act_types.attack, ids = { 0x266, }, },
			{ name = "火炎三節棍中段打ち", type = act_types.attack, ids = { 0x267, }, },
			{ name = "旋風棍", type = act_types.attack, ids = { 0x269, }, },
			{ name = "超火炎旋風棍", type = act_types.attack, ids = { 0x261, 0x263, 0x262, }, },
			{ name = "サラマンダーストリーム", type = act_types.attack, ids = { 0x27A, 0x278, }, },
		},
		-- チン・シンザン
		{
			{ name = "気雷砲", type = act_types.attack, ids = { 0x267, 0x268, 0x26E, }, },
			{ name = "爆雷砲", type = act_types.attack, ids = { 0x287, 0x272, 0x273, }, },
			{ name = "ホエホエ弾", type = act_types.attack, ids = { 0x280, 0x281, 0x27E, 0x27F, }, },
			{ name = "クッサメ砲", type = act_types.attack, ids = { 0x282, }, },
		},
		-- タン・フー・ルー,
		{
			{ name = "衝波", type = act_types.attack, ids = { 0x265, }, },
		},
		-- ローレンス・ブラッド
		{
			{ name = "ブラッディサーベル", type = act_types.attack, ids = { 0x282, }, },
			{ name = "ブラッディミキサー", type = act_types.attack, ids = { 0x284, }, },
		},
		-- ヴォルフガング・クラウザー
		{
			{ name = "小 ブリッツボール", type = act_types.attack, ids = { 0x263, 0x262, }, },
			{ name = "大 ブリッツボール", type = act_types.attack, ids = { 0x266, }, },
			{ name = "カイザーウェイブ1", type = act_types.attack, ids = { 0x26E, 0x26F, }, },
			{ name = "カイザーウェイブ2", type = act_types.attack, ids = { 0x282, 0x270, }, },
			{ name = "カイザーウェイブ3", type = act_types.attack, ids = { 0x283, 0x271, }, },
		},
		-- リック・ストラウド
		{
			{ name = "ガイアブレス", type = act_types.attack, ids = { 0x261, }, },
			{ name = "ハウリング・ブル", type = act_types.attack, ids = { 0x26A, 0x26B, 0x267, }, },
		},
		-- 李香緋
		{
			{ name = "那夢波", type = act_types.attack, ids = { 0x263, }, },
			{ name = "那夢波", type = act_types.attack, ids = { 0x268, }, },
			{ name = "真心牙", type = act_types.attack, ids = { 0x270, }, },
		},
		-- アルフレッド
		{
			{ name = "ダイバージェンス", type = act_types.attack, ids = { 0x264, }, },
		},
	}
	local char_acts, char_1st_acts = {}, {}
	for char, acts_base in pairs(char_acts_base) do
		char_acts[char], char_1st_acts[char] = {}, {}
		for i, acts in pairs(acts_base) do
			for i, id in ipairs(acts.ids) do
				char_1st_acts[char][id] = i == 1
				char_acts[char][id] = acts
			end
		end
	end
	local char_fireballs = { }
	for char, fireballs_base in pairs(char_fireball_base) do
		char_fireballs [char] = {}
		for _, fireball in pairs(fireballs_base) do
			local label = fireball.name
			local type  = fireball.name
			for _, id in pairs(fireball.ids) do
				char_fireballs[char][id] = fireball
			end
		end
	end
	-- コマンドテーブル上の技ID
	-- ブレイクショット対応技のみ
	local char_bs_list = {
		-- テリー・ボガード
		{
			{ id = 0x01, name = "小 バーンナックル", }, 
			{ id = 0x02, name = "大 バーンナックル", }, 
			{ id = 0x03, name = "パワーウェイブ", }, 
			{ id = 0x04, name = "ラウンドウェイブ", }, 
			{ id = 0x05, name = "クラックシュート", }, 
			{ id = 0x06, name = "ファイヤーキック", }, 
			{ id = 0x10, name = "パワーゲイザー", }, 
		},
		-- アンディ・ボガード
		{
			{ id = 0x03, name = "飛翔拳", }, 
			{ id = 0x04, name = "激 飛翔拳", }, 
			{ id = 0x05, name = "昇龍弾", }, 
			{ id = 0x06, name = "空破弾", }, 
			{ id = 0x12, name = "男打弾", }, 
		},
		-- 東丈
		{
			{ id = 0x06, name = "ハリケーンアッパー", }, 
			{ id = 0x07, name = "爆裂ハリケーン", }, 
			{ id = 0x04, name = "タイガーキック", }, 
			{ id = 0x03, name = "黄金のカカト", }, 
			{ id = 0x05, name = "爆裂拳", }, 
		},
		-- 不知火舞
		{
			{ id = 0x02, name = "龍炎舞", }, 
			{ id = 0x04, name = "必殺忍蜂", }, 
			{ id = 0x01, name = "花蝶扇", }, 
			{ id = 0x03, name = "小夜千鳥", }, 
		},
		-- ギース・ハワード
		{
			{ id = 0x01, name = "烈風拳", }, 
			{ id = 0x02, name = "ダブル烈風拳", }, 
			{ id = 0x13, name = "デッドリーレイブ", }, 
		},
		-- 望月双角,
		{
			{ id = 0x01, name = "まきびし", }, 
			{ id = 0x02, name = "野猿狩り", }, 
			{ id = 0x03, name = "憑依弾", }, 
			{ id = 0x06, name = "喝", }, 
		},
		-- ボブ・ウィルソン
		{
			{ id = 0x01, name = "ローリングタートル", }, 
			{ id = 0x04, name = "ワイルドウルフ", }, 
			{ id = 0x02, name = "サイドワインダー", }, 
			{ id = 0x05, name = "モンキーダンス", }, 
		},
		-- ホンフゥ
		{
			{ id = 0x02, name = "小 制空烈火棍", }, 
			{ id = 0x03, name = "大 制空烈火棍", }, 
			{ id = 0x05, name = "電光石火の天", }, 
			{ id = 0x04, name = "電光石火の地", }, 
			{ id = 0x12, name = "よかトンハンマー", }, 
		},
		-- ブルー・マリー
		{
			{ id = 0x02, name = "M.スナッチャー", }, 
			{ id = 0x05, name = "スピンフォール", }, 
			{ id = 0x06, name = "バーチカルアロー", }, 
			{ id = 0x07, name = "ストレートスライサー", }, 
		},
		-- フランコ・バッシュ
		{
			{ id = 0x01 , name = "ダブルコング", }, 
			{ id = 0x02, name = "ザッパー", }, 
			{ id = 0x05, name = "ゴールデンボンバー", }, 
			{ id = 0x04, name = "ガッツダンク", }, 
			{ id = 0x10, name = "ファイナルオメガショット", }, 
		},
		-- 山崎竜二
		{
			{ id = 0x01, name = "蛇使い・上段", }, 
			{ id = 0x02, name = "蛇使い・中段", }, 
			{ id = 0x03, name = "蛇使い・下段", }, 
			{ id = 0x07, name = "裁きの匕首", }, 
		},
		-- 秦崇秀
		{
			{ id = 0x02, name = "小 帝王天眼拳", }, 
			{ id = 0x03, name = "大 帝王天眼拳", }, 
			{ id = 0x04, name = "小 帝王天耳拳", }, 
			{ id = 0x05, name = "大 帝王天耳拳", }, 
			{ id = 0x07, name = "帝王神眼拳・その場", }, 
			{ id = 0x08, name = "帝王神眼拳・頭上", }, 
			{ id = 0x09, name = "帝王神眼拳・背後", }, 
			{ id = 0x10, name = "帝王漏尽拳", }, 
		},
		-- 秦崇雷,
		{
			{ id = 0x02, name = "小 帝王天眼拳", }, 
			{ id = 0x03, name = "大 帝王天眼拳", }, 
			{ id = 0x04, name = "小 帝王天耳拳", }, 
			{ id = 0x05, name = "大 帝王天耳拳", }, 
			{ id = 0x06, name = "帝王漏尽拳", }, 
		},
		-- ダック・キング
		{
			{ id = 0x01, name = "小 ヘッドスピンアタック", }, 
			{ id = 0x02, name = "大 ヘッドスピンアタック", }, 
			{ id = 0x04, name = "ダンシングダイブ", }, 
		},
		-- キム・カッファン
		{
			{ id = 0x02, name = "小 半月斬", }, 
			{ id = 0x03, name = "大 半月斬", }, 
			{ id = 0x01, ver = 0x02, name = "飛燕斬・後方", }, 
			{ id = 0x01, name = "飛燕斬・真上", }, 
			{ id = 0x01, ver = 0x01, name = "飛燕斬・前方", }, 
			{ id = 0x06, name = "覇気脚", }, 
		},
		-- ビリー・カーン
		{
			{ id = 0x03, name = "雀落とし", }, 
			{ id = 0x05, name = "強襲飛翔棍", }, 
			{ id = 0x06, name = "火龍追撃棍", }, 
		},
		-- チン・シンザン
		{
			{ id = 0x01, name = "氣雷砲（前方）", }, 
			{ id = 0x02, name = "氣雷砲（対空）", }, 
			{ id = 0x04, name = "小 破岩激", }, 
			{ id = 0x05, name = "大 破岩激", }, 
			{ id = 0x10, name = "爆雷砲", }, 
		},
		-- タン・フー・ルー,
		{
			{ id = 0x02, name = "小 箭疾歩", }, 
			{ id = 0x03, name = "大 箭疾歩", }, 
			{ id = 0x01, name = "衝波", }, 
			{ id = 0x05, name = "烈千脚", }, 
		},
		-- ローレンス・ブラッド
		{
			{ id = 0x01, name = "小 ブラッディスピン", }, 
			{ id = 0x02, name = "大 ブラッディスピン", }, 
			{ id = 0x05, name = "ブラッディカッター", }, 
		},
		-- ヴォルフガング・クラウザー
		{
			{ id = 0x03, name = "レッグトマホーク", }, 
			{ id = 0x10, name = "カイザーウェーブ", }, 
		},
		-- リック・ストラウド
		{
			{ id = 0x06, name = "ブレイジングサンバースト", }, 
			{ id = 0x01, name = "小 シューティングスター", }, 
			{ id = 0x03, name = "ディバインブラスト", }, 
			{ id = 0x05, name = "ヘリオン", }, 
		},
		-- 李香緋
		{
			{ id = 0x01, name = "小 那夢波", }, 
			{ id = 0x02, name = "大 那夢波", }, 
			{ id = 0x06, name = "天崩山", }, 
			{ id = 0x07, name = "詠酒・対空中攻撃", }, 
			{ id = 0x08, name = "詠酒・対立ち攻撃", }, 
			{ id = 0x09, name = "詠酒・対しゃがみ攻撃", }, 
			{ id = 0x10, name = "大鉄神", }, 
		},
		-- アルフレッド
		{
			{ id = 0x01, name = "小 クリティカルウィング", }, 
			{ id = 0x02, name = "大 クリティカルウィング", }, 
			{ id = 0x03, name = "オーグメンターウィング", }, 
			{ id = 0x04, name = "ダイバージェンス", }, 
		},
	}

	-- エミュレータ本体の入力取得
	local use_joy = {
		{ port = ":edge:joy:JOY1" , field = "P1 Button 1"    , frame = 0, prev = 0, player = 1, get = 0, },
		{ port = ":edge:joy:JOY1" , field = "P1 Button 2"    , frame = 0, prev = 0, player = 1, get = 0, },
		{ port = ":edge:joy:JOY1" , field = "P1 Button 3"    , frame = 0, prev = 0, player = 1, get = 0, },
		{ port = ":edge:joy:JOY1" , field = "P1 Button 4"    , frame = 0, prev = 0, player = 1, get = 0, },
		{ port = ":edge:joy:JOY1" , field = "P1 Down"        , frame = 0, prev = 0, player = 1, get = 0, },
		{ port = ":edge:joy:JOY1" , field = "P1 Left"        , frame = 0, prev = 0, player = 1, get = 0, },
		{ port = ":edge:joy:JOY1" , field = "P1 Right"       , frame = 0, prev = 0, player = 1, get = 0, },
		{ port = ":edge:joy:JOY1" , field = "P1 Up"          , frame = 0, prev = 0, player = 1, get = 0, },
		{ port = ":edge:joy:JOY2" , field = "P2 Button 1"    , frame = 0, prev = 0, player = 2, get = 0, },
		{ port = ":edge:joy:JOY2" , field = "P2 Button 2"    , frame = 0, prev = 0, player = 2, get = 0, },
		{ port = ":edge:joy:JOY2" , field = "P2 Button 3"    , frame = 0, prev = 0, player = 2, get = 0, },
		{ port = ":edge:joy:JOY2" , field = "P2 Button 4"    , frame = 0, prev = 0, player = 2, get = 0, },
		{ port = ":edge:joy:JOY2" , field = "P2 Down"        , frame = 0, prev = 0, player = 2, get = 0, },
		{ port = ":edge:joy:JOY2" , field = "P2 Left"        , frame = 0, prev = 0, player = 2, get = 0, },
		{ port = ":edge:joy:JOY2" , field = "P2 Right"       , frame = 0, prev = 0, player = 2, get = 0, },
		{ port = ":edge:joy:JOY2" , field = "P2 Up"          , frame = 0, prev = 0, player = 2, get = 0, },
		{ port = ":edge:joy:START", field = "2 Players Start", frame = 0, prev = 0, player = 2, get = 0, },
		{ port = ":edge:joy:START", field = "1 Player Start" , frame = 0, prev = 0, player = 1, get = 0, },
	}
	local get_joy = function(exclude_player)
		local scr = manager:machine().screens[":screen"]
		local ec = scr:frame_number()
		local joy_port = {}
		local joy_val = {}
		for _, joy in ipairs(use_joy) do
			local state = 0
			if exclude_player ~= joy.player then
				if not joy_port[joy.port] then
					joy_port[joy.port] = manager:machine():ioport().ports[joy.port]:read()
				end
				local field = manager:machine():ioport().ports[joy.port].fields[joy.field]
				state = ((joy_port[joy.port] & field.mask) ~ field.defvalue)
			elseif exclude_player ~= nil then
				--print("ignore " .. joy.player)
			end
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
			joy_val[joy.field] = joy.frame
		end
		return joy_val
	end
	local accept_input = function(btn, joy_val, state_past)
		if 12 < state_past then
			local p1 = btn == "Start" and "1 Player Start" or ("P1 " .. btn)
			local p2 = btn == "Start" and "2 Players Start" or ("P2 " .. btn)
			local pgm = manager:machine().devices[":maincpu"].spaces["program"]
			if btn == "Up" or btn == "Down" or btn == "Right" or btn == "Left" then
				if (0 < joy_val[p1]) or (0 < joy_val[p2]) then
					pgm:write_u32(0x0010D612, 0x00600004)
					pgm:write_u8(0x0010D713, 0x01)
					return true
				end
			else
				if (0 < joy_val[p1] and state_past >= joy_val[p1]) or 
				   (0 < joy_val[p2] and state_past >= joy_val[p2]) then
					pgm:write_u32(0x0010D612, 0x00610004)
					pgm:write_u8(0x0010D713, 0x01)
					return true
				end
			end
		end
		return false
	end
	local is_start_a = function(joy_val, state_past)
		if 12 < state_past then
			for i = 1, 2 do
				local st = i == 1 and "1 Player Start" or "2 Players Start"
				local pgm = manager:machine().devices[":maincpu"].spaces["program"]
				if (35 < joy_val[st]) then
					pgm:write_u32(0x0010D612, 0x00610004)
					pgm:write_u8(0x0010D713, 0x01)
					return true
				end
			end
		end
		return false
	end
	local new_next_joy = function()
		return {
			["P1 Down" ] = false, ["P1 Button 1"] = false, ["P2 Down" ] = false, ["P2 Button 1"] = false,
			["P1 Left" ] = false, ["P1 Button 2"] = false, ["P2 Left" ] = false, ["P2 Button 2"] = false,
			["P1 Right"] = false, ["P1 Button 3"] = false, ["P2 Right"] = false, ["P2 Button 3"] = false,
			["P1 Up"   ] = false, ["P1 Button 4"] = false, ["P2 Up"   ] = false, ["P2 Button 4"] = false,
		}
	end
	-- 入力の1P、2P反転用のテーブル
	local rev_joy = {
		["P1 Button 1"] = "P2 Button 1", ["P2 Button 1"] = "P1 Button 1",
		["P1 Button 2"] = "P2 Button 2", ["P2 Button 2"] = "P1 Button 2",
		["P1 Button 3"] = "P2 Button 3", ["P2 Button 3"] = "P1 Button 3",
		["P1 Button 4"] = "P2 Button 4", ["P2 Button 4"] = "P1 Button 4",
		["P1 Down"    ] = "P2 Down"    , ["P2 Down"    ] = "P1 Down"    ,
		["P1 Left"    ] = "P2 Left"    , ["P2 Left"    ] = "P1 Left"    ,
		["P1 Right"   ] = "P2 Right"   , ["P2 Right"   ] = "P1 Right"   ,
		["P1 Up"      ] = "P2 Up"      , ["P2 Up"      ] = "P1 Up"      ,
	}
	-- 入力から1P、2Pを判定するテーブル
	local joy_pside = {
		["P1 Down" ] = 1, ["P1 Button 1"] = 1, ["P2 Down" ] = 2, ["P2 Button 1"] = 2,
		["P1 Left" ] = 1, ["P1 Button 2"] = 1, ["P2 Left" ] = 2, ["P2 Button 2"] = 2,
		["P1 Right"] = 1, ["P1 Button 3"] = 1, ["P2 Right"] = 2, ["P2 Button 3"] = 2,
		["P1 Up"   ] = 1, ["P1 Button 4"] = 1, ["P2 Up"   ] = 2, ["P2 Button 4"] = 2,
	}
	-- 入力の左右反転用のテーブル
	local joy_frontback = {
		["P1 Left" ] = "P1 Right", ["P2 Left" ] = "P2 Right",
		["P1 Right"] = "P1 Left" , ["P2 Right"] = "P2 Left" ,
	}
	-- MAMEへの入力の無効化
	local cls_joy = function()
		for _, joy in ipairs(use_joy) do
			manager:machine():ioport().ports[joy.port].fields[joy.field]:set_value(0)
		end
	end

	-- キー入力
	local kprops = { "d", "c", "b", "a", "rt", "lt", "dn", "up", "sl", "st", }
 	local posi_or_pl1 = function(v) return 0 <= v and v + 1 or 1 end
	local nega_or_mi1 = function(v) return 0 >= v and v - 1 or -1 end

	-- ポーズ
	local set_freeze = function(frz_expected)
		local dswport = manager:machine():ioport().ports[":DSW"]
		local fzfld = dswport.fields["Freeze"]
		local freez = ((dswport:read() & fzfld.mask) ~ fzfld.defvalue) <= 0

		if mem_0x10FD82 ~= 0x00 then
			if freez ~= frz_expected then
				fzfld:set_value(global.frz[global.frzc])
				global.frzc = global.frzc +1
				if global.frzc > #global.frz then
					global.frzc = 1
				end
			end
		else
			local pgm = manager:machine().devices[":maincpu"].spaces["program"]
			pgm:write_u8(0x1041D2, frz_expected and 0x00 or 0xFF)
		end
	end

	-- 当たり判定
	local buffer     = {} -- 当たり判定のバッファ
	local type_ck_push = function(obj, box)
		obj.height = obj.height or box.bottom - box.top --used for height of ground throwbox
	end
	local type_ck_vuln = function(obj, box) if not obj.vulnerable then return true end end
	local type_ck_gd   = function(obj, box) end
	local type_ck_atk  = function(obj, box) if obj.harmless then return true end end
	local type_ck_thw  = function(obj, box) if obj.harmless then return true end end
	local type_ck_und  = function(obj, box)
		--print(string.format("%x, unk box id: %x", obj.base, box.id)) --debug
	end
	local box_type_base = {
		a   = { id = 0x00, name = "攻撃",               enabled = true, type_check = type_ck_atk,  type = "attack", color = 0xFF00FF, fill = 0x40, outline = 0xFF },
		t3  = { id = 0x00, name = "未使用",             enabled = true, type_check = type_ck_thw,  type = "throw",  color = 0x8B4513, fill = 0x40, outline = 0xFF },
		pa  = { id = 0x00, name = "飛び道具(未使用?)",  enabled = true, type_check = type_ck_und,  type = "attack", color = 0xFF00FF, fill = 0x40, outline = 0xFF },
		t   = { id = 0x00, name = "投げ",               enabled = true, type_check = type_ck_thw,  type = "throw",  color = 0xFFFF00, fill = 0x40, outline = 0xFF },
		at  = { id = 0x00, name = "必殺技投げ",         enabled = true, type_check = type_ck_thw,  type = "throw",  color = 0xFFFF00, fill = 0x40, outline = 0xFF },
		pt  = { id = 0x00, name = "空中投げ",           enabled = true, type_check = type_ck_thw,  type = "throw",  color = 0xFFFF00, fill = 0x40, outline = 0xFF },
		p   = { id = 0x01, name = "押し合い",           enabled = true, type_check = type_ck_push, type = "push",   color = 0xDDDDDD, fill = 0x00, outline = 0xFF },
		v1  = { id = 0x02, name = "食らい1",            enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x0000FF, fill = 0x40, outline = 0xFF },
		v2  = { id = 0x03, name = "食らい2",            enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x0000FF, fill = 0x40, outline = 0xFF },
		v3  = { id = 0x04, name = "食らい(ダウン追撃のみ可)", enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x00FFFF, fill = 0x80, outline = 0xFF },
		v4  = { id = 0x05, name = "食らい(空中追撃のみ可)", enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x00FFFF, fill = 0x80, outline = 0xFF },
		v5  = { id = 0x06, name = "食らい5(未使用?)",   enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x606060, fill = 0x40, outline = 0xFF },
		v6  = { id = 0x07, name = "食らい(対ライン上攻撃)", enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x00FFFF, fill = 0x80, outline = 0xFF },
		x1  = { id = 0x08, name = "食らい(対ライン下攻撃)", enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x00FFFF, fill = 0x80, outline = 0xFF },
		x2  = { id = 0x09, name = "用途不明2",          enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
		x3  = { id = 0x0A, name = "用途不明3",          enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
		x4  = { id = 0x0B, name = "用途不明4",          enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
		x5  = { id = 0x0C, name = "用途不明5",          enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
		x6  = { id = 0x0D, name = "用途不明6",          enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
		x7  = { id = 0x0E, name = "用途不明7",          enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
		x8  = { id = 0x0F, name = "用途不明8",          enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
		x9  = { id = 0x10, name = "用途不明9",          enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
		g1  = { id = 0x11, name = "立ガード",           enabled = true, type_check = type_ck_gd,   type = "guard",  color = 0xC0C0C0, fill = 0x40, outline = 0xFF },--rbff2 stand-guard
		g2  = { id = 0x12, name = "下段ガード",         enabled = true, type_check = type_ck_gd,   type = "guard",  color = 0xC0C0C0, fill = 0x40, outline = 0xFF },--rbff2 counch-guard
		g3  = { id = 0x13, name = "空中ガード",         enabled = true, type_check = type_ck_gd,   type = "guard",  color = 0xC0C0C0, fill = 0x40, outline = 0xFF },--rbff2 air-guard
		g4  = { id = 0x14, name = "上段当身投げ",       enabled = true, type_check = type_ck_gd,   type = "atemi",  color = 0xFF7F00, fill = 0x40, outline = 0xFF },--rbff2 j.atemi-nage
		g5  = { id = 0x15, name = "中段当身投げ",       enabled = true, type_check = type_ck_gd,   type = "atemi",  color = 0xFF7F00, fill = 0x40, outline = 0xFF },--rbff2 c.atemi-nage
		g6  = { id = 0x16, name = "下段当身投げ",       enabled = true, type_check = type_ck_gd,   type = "atemi",  color = 0xFF7F00, fill = 0x40, outline = 0xFF },--rbff2 g.ateminage
		g7  = { id = 0x17, name = "必勝逆襲脚",         enabled = true, type_check = type_ck_gd,   type = "atemi",  color = 0xFF7F00, fill = 0x40, outline = 0xFF },--rbff2 h.gyakushu-kyaku
		g8  = { id = 0x18, name = "サドマゾ",           enabled = true, type_check = type_ck_gd,   type = "atemi",  color = 0xFF7F00, fill = 0x40, outline = 0xFF },--rbff2 sadomazo
		g9  = { id = 0x19, name = "倍返し",             enabled = true, type_check = type_ck_gd,   type = "guard",  color = 0xFF007F, fill = 0x40, outline = 0xFF },--rbff2 bai-gaeshi
		g10 = { id = 0x1A, name = "ガード?1",           enabled = true, type_check = type_ck_und,  type = "guard",  color = 0x006400, fill = 0x40, outline = 0xFF },
		g11 = { id = 0x1B, name = "ガード?2",           enabled = true, type_check = type_ck_und,  type = "guard",  color = 0x006400, fill = 0x40, outline = 0xFF },--?
		g12 = { id = 0x1C, name = "ガード?3",           enabled = true, type_check = type_ck_und,  type = "guard",  color = 0x006400, fill = 0x40, outline = 0xFF },--rbff2 p.throw?
		g13 = { id = 0x1D, name = "ガード?4",           enabled = true, type_check = type_ck_und,  type = "guard",  color = 0x006400, fill = 0x40, outline = 0xFF },--?
		g14 = { id = 0x1E, name = "フェニックススルー", enabled = true, type_check = type_ck_gd,   type = "guard",  color = 0xFF7F00, fill = 0x40, outline = 0xFF },--?
		g15 = { id = 0x1F, name = "ガード?6",           enabled = true, type_check = type_ck_und,  type = "guard",  color = 0x006400, fill = 0x40, outline = 0xFF },--?
		g16 = { id = 0x20, name = "ガード?7",           enabled = true, type_check = type_ck_und,  type = "guard",  color = 0x006400, fill = 0x40, outline = 0xFF },--?
		sv1  = { id = 0x02, name = "食らい1(スウェー中)", enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x7FFF00, fill = 0x40, outline = 0xFF, sway = true },
		sv2  = { id = 0x03, name = "食らい2(スウェー中)", enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x7FFF00, fill = 0x40, outline = 0xFF, sway = true, },
	}
	local box_types, sway_box_types = {}, {}
	for _, box in pairs(box_type_base) do
		if 0 < box.id then
			if box.sway then
				sway_box_types[box.id] = box
			else
				box_types[box.id] = box
			end
		end
		box.fill    = bit32.lshift(box.fill   , 24) + box.color
		box.outline = bit32.lshift(box.outline, 24) + box.color
	end

	-- ボタンの色テーブル
	local convert = require("data/button_char")
	local btn_col = { [convert("_A")] = 0xFFCC0000, [convert("_B")] = 0xFFCC8800, [convert("_C")] = 0xFF3333CC, [convert("_D")] = 0xFF336600, }
	local text_col, shadow_col = 0xFFFFFFFF, 0xFF000000

	function exists(name)
		if type(name)~="string" then return false end
		return os.rename(name,name) and true or false
	end

	function is_file(name)
		if type(name)~="string" then return false end
		if not exists(name) then return false end
		local f = io.open(name,"r")
		if f then
			f:close()
			return true
		end
		return false
	end

	local base_path = function()
		return lfs.env_replace(manager:machine():options().entries.homepath:value():match('([^;]+)')) .. '/plugins/' .. exports.name
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
			s = string.sub(hexstr, mod+1, mod+1) .. s
			num = math.floor(num / 16)
		end
		if s == '' then s = '0' end
		return s
	end

	local tohexnum = function(num)
		return tonumber(tohex(num))
	end

	local get_digit = function(num)
		return string.len(tostring(num))
	end

	local function draw_rtext(x, y, str, fgcol, bgcol)
		if not str then
			return
		end
		if type(str)~="number" then
			str = "" .. str
		end
		local scr = manager:machine().screens[":screen"]
		local scale = scr:xscale() * scr:width()
		local xx = x
		for c in string.gmatch(str, "([%z\1-\127\194-\244][\128-\191]*)") do
			xx = xx - manager:ui():get_string_width(c, scale)
		end
		for c in string.gmatch(str, "([%z\1-\127\194-\244][\128-\191]*)") do
			scr:draw_text(xx, y, c, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
			xx = xx + manager:ui():get_string_width(c, scale)
		end
	end

	-- コマンド入力表示
	local function draw_cmd(p, line, frame, str)
		local scr = manager:machine().screens[":screen"]
		local cstr = convert(str)
		local width = scr:width() * scr:xscale()

		local p1 = p == 1
		local xx = p1 and 15 or 300   -- 1Pと2Pで左右に表示し分ける
		local yy = (line + 8 - 1) * 8 -- +8はオフセット位置

		if 0 < frame then
			if 999 < frame then
				draw_rtext(p1 and 10.5 or 295.5, yy + 0.5, "LOT", shadow_col)
				draw_rtext(p1 and 10   or 295  ,       yy, "LOT", text_col)
			else
				draw_rtext(p1 and 10.5 or 295.5, yy + 0.5, frame, shadow_col)
				draw_rtext(p1 and 10   or 295  ,       yy, frame, text_col)
			end
		end
		local col = 0xFAFFFFFF
		if p1 then
			for i = 1, 50 do
				scr:draw_line(i, yy, i+1, yy, col)
				col = col - 0x05000000
			end
		else
			for i = 320, 270, -1 do
				scr:draw_line(i, yy, i-1, yy, col)
				col = col - 0x05000000
			end
		end
		-- 変換しつつUnicodeの文字配列に落とし込む
		for c in string.gmatch(cstr, "([%z\1-\127\194-\244][\128-\191]*)") do
			-- 文字の影
			scr:draw_text(xx + 0.5, yy + 0.5, c, 0xFF000000)
			if btn_col[c] then
				-- ABCDボタンの場合は黒の●を表示した後ABCDを書いて文字の部分を黒く見えるようにする
				scr:draw_text(xx, yy, convert("_("), text_col)
				scr:draw_text(xx, yy, c, btn_col[c])
			else
				scr:draw_text(xx, yy, c, text_col)
			end
			xx = xx + 5 -- フォントの大きさ問わず5pxずつ表示する
		end
	end

	-- 当たり判定表示
	local new_hitbox = function(p, id, top, bottom, left, right, attack_only, is_fireball, key)
		local box = {id = id}
		local a = "攻撃判定"
		box.type = nil
		if box.id + 1 > #box_types then
			box.type = box_type_base.a
			--print(string.format("attack id %x", box.id))
		else
			box.type = box_types[box.id + 1]
			if p.on_sway_line and sway_box_types[box.id + 1] then
				box.type = sway_box_types[box.id + 1] 
			end
		end
		box.type = box.type or box_type_base.x1
		--[[ この判定が意味がないので無効化
		if (attack_only and box.type ~= box_type_base.a) or (not attack_only and box.type == box_type_base.a) then
			return nil
		end
		]]
		if box.type == box_type_base.a then
			-- 攻撃中のフラグをたてる
			p.attacking = true
		end

		box.top    = p.hit.pos_y - bit32.arshift(top    * p.hit.scale * 4, 8)
		box.bottom = p.hit.pos_y - bit32.arshift(bottom * p.hit.scale * 4, 8)
		box.left   = p.hit.pos_x - bit32.arshift(left   * p.hit.scale * 4, 8) * p.hit.flip_x
		box.right  = p.hit.pos_x - bit32.arshift(right  * p.hit.scale * 4, 8) * p.hit.flip_x

		box.top    = (0 > box.top    or 0xFFFF < box.top   ) and bit32.band(0xFFFF, box.top   ) or box.top
		box.bottom = (0 > box.bottom or 0xFFFF < box.bottom) and bit32.band(0xFFFF, box.bottom) or box.bottom
		box.left   = (0 > box.left   or 0xFFFF < box.left  ) and bit32.band(0xFFFF, box.left  ) or box.left
		box.right  = (0 > box.right  or 0xFFFF < box.right ) and bit32.band(0xFFFF, box.right ) or box.right

		if ((box.top <= 0 and box.bottom <=0) or (box.top >= 224 and box.bottom >=224) or (box.left <= 0 and box.right <= 0) or (box.left >= 320 and box.right >= 320)) then
			--print("OVERFLOW " .. (key or "")) --debug
			return nil
		end

		-- はみ出し補正
		if  p.hit.flip_x == 1 then
			if box.right > 320 and box.right > box.left then
				box.right = 0
			end
		else
			if box.left > 320 and box.left > box.right then
				box.left = 0
			end
		end
		if box.top > box.bottom then
			if box.top > (224-screen_top) then
				box.top = screen_top
			end
		end

		if box.top == box.bottom and box.left == box.right then
			box.visible = false
			--print("FLAT " .. (key or "")) --debug
			return nil
		elseif box.type.type_check(p.hit, box) then
			-- ビリーの旋風棍がヒット、ガードされると判定表示が消えてしまうので飛び道具は状態判断の対象から外す
			-- ここの判断処理を省いても飛び道具が最大ヒットして無効になった時点で判定が消えるので悪影響はない
			if is_fireball then
				box.visible = true
				return box
			end
			-- フレーム表示や自動ガードで使うため無効状態の判定を返す
			box.visible = false
			--print("IGNORE " .. (key or "")) --debug
			return nil
		else
			box.visible = true
			--print("LIVE " .. (key or "")) --debug
			return box
		end
	end

	local new_throwbox = function(p, box)
		local scr = manager:machine().screens[":screen"]
		local height = scr:height() * scr:yscale()
		p.throwing = true
		box.flat_throw = box.top == nil
		box.top    = box.top or p.hit.pos_y - global.throwbox_height
		box.left   = p.hit.pos_x + (box.left or 0)
		box.right  = p.hit.pos_x + (box.right or 0)
		box.top    = box.top and p.hit.pos_y - box.top --air throw
		box.bottom = box.bottom and (p.hit.pos_y - box.bottom) or height + screen_top - p.hit.pos_z
		box.type   = box.type or box_type_base.t
		box.visible = true
		return box
	end

	-- 当たり判定用のキャラ情報更新と判定表示用の情報作成
	local update_object = function(p, ec)
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		local scr = manager:machine().screens[":screen"]
		local height = scr:height() * scr:yscale()

		local obj_base = p.addr.base

		p.hit.pos_x   = p.pos - screen_left
		p.hit.pos_z   = p.pos_z
		p.hit.pos_y   = height - p.pos_y - p.hit.pos_z
		p.hit.pos_y   = screen_top + p.hit.pos_y
		p.hit.on      = pgm:read_u32(obj_base)

		p.hit.flip_x  = pgm:read_i16(obj_base + 0x6A) < 0 and 1 or 0
		p.hit.flip_x  = bit32.bxor(p.hit.flip_x, bit32.band(pgm:read_u8(obj_base + 0x71), 1))
		p.hit.flip_x  = p.hit.flip_x > 0 and 1 or -1
		p.hit.scale   = pgm:read_u8(obj_base + 0x73) + 1
		p.hit.char_id = pgm:read_u16(obj_base + 0x10)
		p.hit.base    = obj_base

		p.attacking   = false
		p.throwing    = false

		-- ヒットするかどうか
		p.hit.harmless   = bit32.btest(3, pgm:read_u8(obj_base + 0x6A)) == 0 or pgm:read_u8(obj_base + 0xAA) > 0 or
			(p.hit.projectile and pgm:read_u8(obj_base + 0xE7) > 0) or
			(not p.hit.projectile and pgm:read_u8(obj_base + 0xB6) == 0)

		-- 食らい判定かどうか
		p.hit.vulnerable = false
		if p.hit.vulnerable1 == 1 then
			p.hit.vulnerable = true
		elseif p.hit.vulnerable21 == 1 then
			p.hit.vulnerable = p.hit.vulnerable22
		end
		for _, box in ipairs(p.buffer) do
			local hitbox = new_hitbox(p, box.id, box.top, box.bottom, box.left, box.right, box.attack_only, box.is_fireball, box.key)
			if hitbox then
				table.insert(p.hitboxes, hitbox)
			end
		end

		-- 空投げ, 必殺投げ
		if p.n_throw and p.n_throw.on == 0x1 then
			table.insert(p.hitboxes, new_throwbox(p, p.n_throw))
			--print("n throw " .. string.format("%x", p.addr.base) .. " " .. p.n_throw.type.name .. " " .. " " .. p.n_throw.left .. " " .. p.n_throw.right .. " " .. p.n_throw.top .. " " .. p.n_throw.bottom)
		end
		if p.air_throw and p.air_throw.on == 0x1 then
			table.insert(p.hitboxes, new_throwbox(p, p.air_throw))
		end
		if p.sp_throw and p.sp_throw.on == 0x1 then
			table.insert(p.hitboxes, new_throwbox(p, p.sp_throw))
		end
	end

	-- プレイヤーの状態など
	local players = {}
	for p = 1, 2 do
		p1 = (p == 1)
		players[p] = {
			dummy_act        = 1,           -- 立ち, しゃがみ, ジャンプ, 小ジャンプ, スウェー待機
			dummy_gd         = 1,           -- なし, オート, 1ヒットガード, 1ガード, 常時, ランダム
			dummy_bs         = false,       -- ブレイクショットモードのときtrue
			dummy_bs_list    = {},          -- ブレイクショットのコマンドテーブル上の技ID
			dummy_bs_cnt     = 1,           -- ブレイクショットのコマンドテーブル上の技のバリエーション（基本は0、飛燕斬用）
			dummy_bs_chr     = 0,           -- ブレイクショットの設定をした時のキャラID
			dummy_down       = 1,           -- なし, テクニカルライズ, グランドスウェー, 起き上がり攻撃 
			bs_count         = -1,          -- ブレイクショットの実施カウント

			life_rec         = true,        -- 自動で体力回復させるときtrue
			red              = true,        -- 赤体力にするときtrue
			max              = true,        -- パワーMAXにするときtrue
			disp_dmg         = true,        -- ダメージ表示するときtrue
			disp_cmd         = true,        -- 入力表示するときtrue
			disp_frm         = true,        -- フレーム数表示するときtrue

			combo            = 0,           -- 最近のコンボ数
			tmp_combo_dmg    = 0,
			last_combo       = 0,
			last_dmg         = 0,           -- ダメージ
			last_state       = true,
			life             = 0,           -- いまの体力
			max_combo        = 0,           -- 最大コンボ数
			max_dmg          = 0,
			mv_state         = 0,           -- 動作
			old_combo        = 0,           -- 前フレームのコンボ数
			last_combo_dmg   = 0,
			old_state        = 0,           -- 前フレームのやられ状態
			attack           = 0,           -- 攻撃中のみ変化
			pos              = 0,           -- X位置
			pos_y            = 0,           -- Y位置
			old_pos_y        = 0,           -- Y位置
			pos_z            = 0,           -- Z位置
			side             = 0,           -- 向き
			state            = 0,           -- いまのやられ状態
			tmp_combo        = 0,           -- 一次的なコンボ数
			tmp_dmg          = 0,           -- ダメージが入ったフレーム
			color            = 0,           -- カラー A=0x00 D=0x01

			key_now          = {},          -- 前フレームまでの個別キー入力フレーム
			key_pre          = {},          -- 個別キー入力フレーム
			key_hist         = {},
			key_frames       = {},
			act_frames       = {},
			act_frames2      = {},
			act_frames_total = 0,

			muteki           = {
				act_frames   = {},
				act_frames2  = {},
			},

			frm_gap           = {
				act_frames   = {},
				act_frames2  = {},
			},

			reg_pcnt         = 0,           -- キー入力 REG_P1CNT or REG_P2CNT
			reg_st_b         = 0,           -- キー入力 REG_STATUS_B

			update_sts       = 0,
			update_dmg       = 0,
			update_act       = 0,
			random_boolean   = math.random(255) % 2 == 0,

			backstep_killer  = false,
			need_block       = false,
			need_low_block   = false,
			attacking        = false,
			throwing         = false,

			hitboxes         = {},
			buffer           = {},
			fireball_bases   = p1 and { [0x100600] = true, [0x100800] = true, [0x100A00] = true, } or
				                      { [0x100700] = true, [0x100900] = true, [0x100B00] = true, },
			fireball         = {},

			hit              = {
				pos_x        = 0,
				pos_z        = 0,
				pos_y        = 0,
				on           = 0,
				flip_x       = 0,
				scale        = 0,
				char_id      = 0,
				vulnerable   = 0,
				harmless     = 0,
				vulnerable1  = 0,
				vulnerable21 = 0,
				vulnerable22 = 0,           -- 0の時vulnerable=true
			},

			n_throw        = {
				on           = 0,
				right        = 0,
				base         = 0,
				opp_base     = 0,
				opp_id       = 0,
				char_id      = 0,
				side         = 0,
				range1       = 0,
				range2       = 0,
				range3       = 0,
				range41      = 0,
				range42      = 0,
				range5       = 0,
				range6       = 0,
				addr         = {
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
					range6   = p1 and 0x10CDA7 or 0x10CDC7,
				},
			},

			air_throw        = {
				on           = 0,
				range_x      = 0,
				range_y      = 0,
				base         = 0,
				opp_base     = 0,
				opp_id       = 0,
				side         = 0,
				addr         = {
					on       = p1 and 0x10CD00 or 0x10CD20,
					range_x  = p1 and 0x10CD01 or 0x10CD21,
					range_y  = p1 and 0x10CD03 or 0x10CD23,
					base     = p1 and 0x10CD05 or 0x10CD25,
					opp_base = p1 and 0x10CD09 or 0x10CD29,
					opp_id   = p1 and 0x10CD0D or 0x10CD2D,
					side     = p1 and 0x10CD11 or 0x10CD31,
				},
			},

			sp_throw         = {
				on           = 0,
				front        = 0,
				top          = 0,
				base         = 0,
				opp_base     = 0,
				opp_id       = 0,
				side         = 0,
				bottom       = 0,
				addr         = {
					on       = p1 and 0x10CD40 or 0x10CD60,
					front    = p1 and 0x10CD41 or 0x10CD61,
					top      = p1 and 0x10CD43 or 0x10CD63,
					base     = p1 and 0x10CD45 or 0x10CD65,
					opp_base = p1 and 0x10CD49 or 0x10CD69,
					opp_id   = p1 and 0x10CD4D or 0x10CD6D,
					side     = p1 and 0x10CD51 or 0x10CD71,
					bottom   = p1 and 0x10CD52 or 0x10CD72,
				},
			},

			addr           = {
				base         = p1 and 0x100400 or 0x100500, -- キャラ状態とかのベースのアドレス
				act          = p1 and 0x100460 or 0x100560, -- 行動ID デバッグディップステータス表示のPと同じ
				act_contact  = p1 and 0x100401 or 0x100501, -- 通常=2、必殺技中=3 ガードヒット=5 潜在ガード=6
				attack       = p1 and 0x1004B6 or 0x1005B6, -- 攻撃中のみ変化
				char         = p1 and 0x107BA5 or 0x107BA7, -- キャラ
				color        = p1 and 0x107BAC or 0x107BAD, -- カラー A=0x00 D=0x01
				combo        = p1 and 0x10B4E4 or 0x10B4E5, -- コンボ
				combo2       = p1 and 0x10B4E5 or 0x10B4E4, -- 最近のコンボ数のアドレス
				tmp_combo2   = p1 and 0x10B4E1 or 0x10B4E0, -- 一次的なコンボ数のアドレス
				max_combo2   = p1 and 0x10B4F0 or 0x10B4EF, -- 最大コンボ数のアドレス
				last_dmg     = p1 and 0x10048F or 0x10058F, -- 最終ダメージ
				life         = p1 and 0x10048B or 0x10058B, -- 体力
				max_combo    = p1 and 0x10B4EF or 0x10B4F0, -- 最大コンボ
				max_stun     = p1 and 0x10B84E or 0x10B856, -- 最大スタン値
				pos          = p1 and 0x100420 or 0x100520, -- X位置
				pos_y        = p1 and 0x100428 or 0x100528, -- Y位置
 				pos_z        = p1 and 0x100424 or 0x100524, -- Z位置
 				side         = p1 and 0x100458 or 0x100558, -- 向き
				pow          = p1 and 0x1004BC or 0x1005BC, -- パワー
				state        = p1 and 0x10048E or 0x10058E, -- 状態
				stop         = p1 and 0x10048D or 0x10058D, -- ヒットストップ
				stun         = p1 and 0x10B850 or 0x10B858, -- 現在スタン値
 				stun_timer   = p1 and 0x10B854 or 0x10B85C, -- スタン値ゼロ化までの残フレーム数
 				tmp_combo    = p1 and 0x10B4E0 or 0x10B4E1, -- コンボテンポラリ
				pow          = p1 and 0x1004BC or 0x1005BC, -- パワーアドレス
				reg_pcnt     = p1 and 0x300000 or 0x340000, -- キー入力 REG_P1CNT or REG_P2CNT アドレス
				reg_st_b     = 0x380000,                    -- キー入力 REG_STATUS_B アドレス
				control1     = p1 and 0x100412 or 0x100512, -- Human 1 or 2, CPU 3
				control2     = p1 and 0x100413 or 0x100513, -- Human 1 or 2, CPU 3
				select_hook  = p1 and 0x10CDD1 or 0x10CDD5, -- プレイヤーセレクト画面のフック処理用アドレス
				bs_hook1     = p1 and 0x10DDDA or 0x10DDDC, -- BSモードのフック処理用アドレス。技のID。
				bs_hook2     = p1 and 0x10DDDB or 0x10DDDD, -- BSモードのフック処理用アドレス。技のバリエーション。

				-- フックできない変わり用
				state2       = p1 and 0x10CA0E or 0x10CA0F, -- 状態
				act2         = p1 and 0x10CA12 or 0x10CA13, -- 行動ID デバッグディップステータス表示のPと同じ

				-- フックできない変わり用-当たり判定
				vulnerable1  = p1 and 0x10CB30 or 0x10CB31,
				vulnerable21 = p1 and 0x10CB32 or 0x10CB33,
				vulnerable22 = p1 and 0x10CB34 or 0x10CB35, --0の時vulnerable=true
			},
		}

		for i = 1, #kprops do
			players[p].key_now[kprops[i]] = 0
			players[p].key_pre[kprops[i]] = 0
		end
		for i = 1, 18 do
			players[p].key_hist[i] = ""
			players[p].key_frames[i] = 0
			players[p].act_frames[i] = {0,0}
		end
	end
	-- 飛び道具領域の作成
	for i, p in ipairs(players) do
		for base, _ in pairs(p.fireball_bases) do
			p.fireball[base] = {
				is_fireball    = true,
				act            = 0,
				pos            = 0, -- X位置
				pos_y          = 0, -- Y位置
				pos_z          = 0, -- Z位置
				hitboxes       = {},
				hit            = {
					pos_x      = 0,
					pos_z      = 0,
					pos_y      = 0,
					on         = 0,
					flip_x     = 0,
					scale      = 0,
					char_id    = 0,
					vulnerable = 0,
					harmless   = 0,
				},
				addr           = {
					base       = base, -- キャラ状態とかのベースのアドレス
					act        = base + 0x60, -- 技のID
					pos        = base + 0x20, -- X位置
					pos_y      = base + 0x28, -- Y位置
	 				pos_z      = base + 0x24, -- Z位置
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
	local apply_patch = function(pgm, s_patch, offset, force)
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
	local apply_patch_file = function(pgm, patch, force)
		local ret = false
		if pgm then
			local path = rom_patch_path(patch)
			print(path .. " patch " .. (force and "force" or ""))
			local f = io.open(path, "r")
			for line in f:lines() do
				ret = apply_patch(pgm, line, 0x000000, force)
				if not ret then
					print("patch failure in [" .. line .. "]")
				end
			end
			f:close()
		end
		print(ret and "patch finish" or "patch NOT finish")
		return ret
	end

	-- 場面変更
	local apply_1p2p_active = function()
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		pgm:write_direct_u8(0x100024, 0x03) -- 1P or 2P
		pgm:write_direct_u8(0x100027, 0x03) -- 1P or 2P
	end

	local apply_vs_mode = function(continue)
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		apply_1p2p_active()
		if not continue then
			pgm:write_direct_u8(0x107BB5, 0x01) -- vs 1st CPU mode
		end
	end

	local goto_player_select = function()
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		dofile(ram_patch_path("player-select.lua"))
		apply_vs_mode(false)
	end

	local restart_fight = function(param)
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		param = param or {}
		local stg1  = param.next_stage.stg1 or stgs[1].stg1
		local stg2  = param.next_stage.stg2 or stgs[1].stg2
		local stg3  = param.next_stage.stg3 or stgs[1].stg3
		local p1    = param.next_p1    or 1
		local p2    = param.next_p2    or 21
		local p1col = param.next_p1col or 0x00
		local p2col = param.next_p2col or 0x01
		local bgm   = param.next_bgm   or 21

		dofile(ram_patch_path("vs-restart.lua"))
		apply_vs_mode(true)

		local p = players

		pgm:write_u8(0x107BB1, stg1)
		pgm:write_u8(0x107BB7, stg2)
		pgm:write_u8(0x107BB9, stg3) -- フックさせて無理やり実現するために0xD0を足す（0xD1～0xD5にする）
		pgm:write_u8(p[1].addr.char , p1)
		pgm:write_u8(p[1].addr.color, p1col)
		pgm:write_u8(p[2].addr.char , p2)
		if p1 == p2 then
			pgm:write_u8(p[2].addr.color, p1col == 0x00 and 0x01 or 0x00)
		else
			pgm:write_u8(p[2].addr.color, p2col)
		end
		pgm:write_u8(0x10A8D5, bgm) --BGM
	end
	--

	-- ブレイクポイント発動時のデバッグ画面表示と停止をさせない
	local debug_stop = 0
	local auto_recovery_debug = function()
		if manager:machine():debugger() then
			if manager:machine():debugger().execution_state ~= "run" then
				debug_stop = debug_stop + 1
			end
			if 3 > debug_stop then
				manager:machine():debugger().execution_state = "run"
				debug_stop = 0
			end
		end
	end
	--

	-- 当たり判定のオフセット
	local bp_offset = {
		[0x012C42] = { ["rbff2k"] =   0x28, ["rbff2h"] = 0x0  },
		[0x012C88] = { ["rbff2k"] =   0x28, ["rbff2h"] = 0x0  },
		[0x012D4C] = { ["rbff2k"] =   0x28, ["rbff2h"] = 0x0  }, --p1 push 
		[0x012D92] = { ["rbff2k"] =   0x28, ["rbff2h"] = 0x0  }, --p2 push
		[0x039F2A] = { ["rbff2k"] =   0xC , ["rbff2h"] = 0x20 }, --special throws
		[0x017300] = { ["rbff2k"] =   0x28, ["rbff2h"] = 0x0  }, --solid shadows
	}
	local bp_clone = { ["rbff2k"] = -0x104, ["rbff2h"] = 0x20 }
	local fix_bp_addr = function(addr)
		local fix1 = bp_clone[emu.romname()] or 0
		local fix2 = bp_offset[addr] and (bp_offset[addr][emu.romname()] or fix1) or fix1
		return addr + fix2
	end

	-- 当たり判定と投げ判定用のブレイクポイントとウォッチポイントのセット
	local wps = {}
	local set_wps = function(reset)
		local cpu = manager:machine().devices[":maincpu"]
		local pgm = cpu.spaces["program"]
		if reset then
			for i, idx in ipairs(wps) do
				cpu:debug():bpclr(idx)
			end
			wps = {}
			return
		end

		if #wps == 0 then
			--debug:wpset(space, type, addr, len, [opt] cond, [opt] act)
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x1006BF, 1, "wpdata!=0", "maincpu.pb@10CA00=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x1007BF, 1, "wpdata!=0", "maincpu.pb@10CA01=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x100620, 1, "wpdata!=0", "maincpu.pb@10CA02=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x10062C, 1, "wpdata!=0", "maincpu.pb@10CA03=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x100820, 1, "wpdata!=0", "maincpu.pb@10CA04=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x10082C, 1, "wpdata!=0", "maincpu.pb@10CA05=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x100A20, 1, "wpdata!=0", "maincpu.pb@10CA06=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x100A2C, 1, "wpdata!=0", "maincpu.pb@10CA07=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x100720, 1, "wpdata!=0", "maincpu.pb@10CA08=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x10072C, 1, "wpdata!=0", "maincpu.pb@10CA09=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x100920, 1, "wpdata!=0", "maincpu.pb@10CA0A=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x10092C, 1, "wpdata!=0", "maincpu.pb@10CA0B=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x100B20, 1, "wpdata!=0", "maincpu.pb@10CA0C=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x100B2C, 1, "wpdata!=0", "maincpu.pb@10CA0D=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x10048E, 1, "wpdata!=0", "maincpu.pb@10CA0E=maincpu.pb@10048E;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x10058E, 1, "wpdata!=0", "maincpu.pb@10CA0F=maincpu.pb@10058E;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x10048F, 1, "wpdata!=0", "maincpu.pb@10CA10=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x10058F, 1, "wpdata!=0", "maincpu.pb@10CA11=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x100460, 1, "wpdata!=0", "maincpu.pb@10CA12=1;g"))
			table.insert(wps, cpu:debug():wpset(pgm, "w", 0x100560, 1, "wpdata!=0", "maincpu.pb@10CA13=1;g"))
		end
	end

	local bps = {}
	local set_bps = function(reset)
		local cpu = manager:machine().devices[":maincpu"]
		if reset then
			for i, idx in ipairs(bps) do
				cpu:debug():wpclr(idx)
			end
			bps = {}
			return
		end

		if #bps == 0 then
			if global.infinity_life2 then
				--bp 05B480,{(maincpu.pw@107C22>0)&&($100400<=((A3)&$FFFFFF))&&(((A3)&$FFFFFF)<=$100500)},{PC=5B48E;g}
				table.insert(bps, cpu:debug():bpset(fix_bp_addr(0x05B460),
					"(maincpu.pw@107C22>0)&&($100400<=((A3)&$FFFFFF))&&(((A3)&$FFFFFF)<=$100500)", 
					string.format("PC=%x;g", fix_bp_addr(0x05B46E))))
			end

			-- BSモードのフック
			-- bp 03957E,{((A6)==CB244)&&((A4)==100400)&&(maincpu.pb@10048E==2)},{D1=1;g}
			-- bp 03957E,{((A6)==CB244)&&((A4)==100500)&&(maincpu.pb@10058E==2)},{D1=1;g}
			-- 0395B2: 1941 00A3                move.b  D1, ($a3,A4) -- 確定した技データ
			-- 0395B6: 195E 00A4                move.b  (A6)+, ($a4,A4) -- 技データ読込 だいたい06
			-- 0395BA: 195E 00A5                move.b  (A6)+, ($a5,A4) -- 技データ読込 だいたい00、飛燕斬01、02、03
			table.insert(bps, cpu:debug():bpset(fix_bp_addr(0x03957E),
				"(maincpu.pw@107C22>0)&&((A6)==CB244)&&((maincpu.pb@10048E==2&&($100400==((A4)&$FFFFFF)))||(maincpu.pb@10058E==2&&($100500==((A4)&$FFFFFF))))",
				"temp1=$10DDDA+((((A4)&$FFFFFF)-$100400)/$80);D1=(maincpu.pb@(temp1));A6=((A6)+2);maincpu.pb@((A4)+$A3)=D1;maincpu.pb@((A4)+$A4)=06;maincpu.pb@((A4)+$A5)=maincpu.pb@(temp1+1);PC=((PC)+$20);g"))

			-- ステージ設定用。メニューでFを設定した場合にのみ動作させる
			-- ラウンド数を1に初期化→スキップ
			table.insert(bps, cpu:debug():bpset(0x0F368, "maincpu.pw@((A5)-$448)==$F", "PC=F36E;g"))
			-- ラウンド2以上の場合の初期化処理→無条件で実施
			table.insert(bps, cpu:debug():bpset(0x22AD8, "maincpu.pw@((A5)-$448)==$F", "PC=22AF4;g"))
			-- キャラ読込 ラウンド1の時だけ読み込む→無条件で実施
			table.insert(bps, cpu:debug():bpset(0x22D32, "maincpu.pw@((A5)-$448)==$F", "PC=22D3E;g"))
			-- ラウンド2以上の時の処理→データロード直後の状態なので不要。スキップしないとBGMが変わらない
			table.insert(bps, cpu:debug():bpset(0x0F6AC, "maincpu.pw@((A5)-$448)==$F", "PC=F6B6;g"))
			-- ラウンド1じゃないときの処理 →スキップ
			table.insert(bps, cpu:debug():bpset(0x1E39A, "maincpu.pw@((A5)-$448)==$F", "PC=1E3A4;g"))
			-- ラウンド1の時だけ読み込む →無条件で実施。データを1ラウンド目の値に戻す
			table.insert(bps, cpu:debug():bpset(0x17694, "maincpu.pw@((A5)-$448)==$F", "maincpu.pw@((A5)-$448)=1;PC=176A0;g"))

			-- 当たり判定用
			table.insert(bps, cpu:debug():bpset(fix_bp_addr(0x5C2DA),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CB30+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=$01;g"))

			--くらい2
			table.insert(bps, cpu:debug():bpset(fix_bp_addr(0x5C2E6),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CB32+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=$01;maincpu.pb@(temp1+$2)=(maincpu.pb@(((A4)+$B1)&$FFFFFF));g"))

			--判定追加1
			table.insert(bps, cpu:debug():bpset(fix_bp_addr(0x012C42),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100F00)",
				"temp0=($10CB41+((maincpu.pb@10CB40)*$10));maincpu.pb@(temp0)=1;maincpu.pb@(temp0+1)=maincpu.pb@(A2);maincpu.pb@(temp0+2)=maincpu.pb@((A2)+$1);maincpu.pb@(temp0+3)=maincpu.pb@((A2)+$2);maincpu.pb@(temp0+4)=maincpu.pb@((A2)+$3);maincpu.pb@(temp0+5)=maincpu.pb@((A2)+$4);maincpu.pd@(temp0+6)=((A4)&$FFFFFFFF);maincpu.pb@(temp0+$A)=$FF;temp0=temp0+$10;maincpu.pb@10CB40=((maincpu.pb@10CB40)+1);g"))

			--判定追加2
			table.insert(bps, cpu:debug():bpset(fix_bp_addr(0x012C88),
				"(maincpu.pw@107C22>0)&&($100400<=((A3)&$FFFFFF))&&(((A3)&$FFFFFF)<=$100F00)",
				"temp0=($10CB41+((maincpu.pb@10CB40)*$10));maincpu.pb@(temp0)=1;maincpu.pb@(temp0+1)=maincpu.pb@(A1);maincpu.pb@(temp0+2)=maincpu.pb@((A1)+$1);maincpu.pb@(temp0+3)=maincpu.pb@((A1)+$2);maincpu.pb@(temp0+4)=maincpu.pb@((A1)+$3);maincpu.pb@(temp0+5)=maincpu.pb@((A1)+$4);maincpu.pd@(temp0+6)=((A3)&$FFFFFFFF);maincpu.pb@(temp0+$A)=$01;temp0=temp0+$10;maincpu.pb@10CB40=((maincpu.pb@10CB40)+1);g"))

			--判定追加3
			table.insert(bps, cpu:debug():bpset(fix_bp_addr(0x012D4C),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100F00)",
				"temp0=($10CB41+((maincpu.pb@10CB40)*$10));maincpu.pb@(temp0)=1;maincpu.pb@(temp0+1)=maincpu.pb@(A2);maincpu.pb@(temp0+2)=maincpu.pb@((A2)+$1);maincpu.pb@(temp0+3)=maincpu.pb@((A2)+$2);maincpu.pb@(temp0+4)=maincpu.pb@((A2)+$3);maincpu.pb@(temp0+5)=maincpu.pb@((A2)+$4);maincpu.pd@(temp0+6)=((A4)&$FFFFFFFF);maincpu.pb@(temp0+$A)=$FF;temp0=temp0+$10;maincpu.pb@10CB40=((maincpu.pb@10CB40)+1);g"))

			--判定追加4
			table.insert(bps, cpu:debug():bpset(fix_bp_addr(0x012D92),
				"(maincpu.pw@107C22>0)&&($100400<=((A3)&$FFFFFF))&&(((A3)&$FFFFFF)<=$100F00)",
				"temp0=($10CB41+((maincpu.pb@10CB40)*$10));maincpu.pb@(temp0)=1;maincpu.pb@(temp0+1)=maincpu.pb@(A1);maincpu.pb@(temp0+2)=maincpu.pb@((A1)+$1);maincpu.pb@(temp0+3)=maincpu.pb@((A1)+$2);maincpu.pb@(temp0+4)=maincpu.pb@((A1)+$3);maincpu.pb@(temp0+5)=maincpu.pb@((A1)+$4);maincpu.pd@(temp0+6)=((A3)&$FFFFFFFF);maincpu.pb@(temp0+$A)=$FF;temp0=temp0+$10;maincpu.pb@10CB40=((maincpu.pb@10CB40)+1);g"))

			--ground throws
			table.insert(bps, cpu:debug():bpset(fix_bp_addr(0x05D782),
				"(maincpu.pw@107C22>0)&&((((D7)&$FFFF)==0x65))&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CD90+((((A4)&$FFFFFF)-$100400)/$8);maincpu.pb@(temp1)=$1;maincpu.pd@(temp1+$1)=((A4)&$FFFFFF);maincpu.pd@(temp1+$5)=maincpu.pd@(((A4)&$FFFFFF)+$96);maincpu.pw@(temp1+$A)=maincpu.pw@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$10);maincpu.pw@(temp1+$C)=maincpu.pw@(((A4)&$FFFFFF)+$10);maincpu.pb@(temp1+$10)=maincpu.pb@(((A4)&$FFFFFF)+$96+$58);maincpu.pb@(temp1+$11)=maincpu.pb@(((A4)&$FFFFFF)+$58);maincpu.pb@(temp1+$12)=maincpu.pb@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$58);maincpu.pb@(temp1+$13)=maincpu.pb@(maincpu.pd@((PC)+$2));maincpu.pb@(temp1+$14)=maincpu.pb@((maincpu.pd@((PC)+$02))+((maincpu.pw@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$10))<<3)+$3);maincpu.pb@(temp1+$15)=maincpu.pb@((maincpu.pd@((PC)+$02))+((maincpu.pw@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$10))<<3)+$4);maincpu.pb@(temp1+$16)=maincpu.pb@((maincpu.pd@((PC)+$2))+((maincpu.pw@(((A4)&$FFFFFF)+$10))<<3)+$3);maincpu.pb@(temp1+$17)=maincpu.pb@((PC)+$D2+(maincpu.pw@((A4)&$FFFFFF)+$10)*4+$3);g"))
			table.insert(bps, cpu:debug():bpset(fix_bp_addr(0x05D782),
				"(maincpu.pw@107C22>0)&&((((D7)&$FFFF)!=0x65))&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CD90+((((A4)&$FFFFFF)-$100400)/$8);maincpu.pb@(temp1)=$1;maincpu.pd@(temp1+$1)=((A4)&$FFFFFF);maincpu.pd@(temp1+$5)=maincpu.pd@(((A4)&$FFFFFF)+$96);maincpu.pw@(temp1+$A)=maincpu.pw@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$10);maincpu.pw@(temp1+$C)=maincpu.pw@(((A4)&$FFFFFF)+$10);maincpu.pb@(temp1+$10)=maincpu.pb@(((A4)&$FFFFFF)+$96+$58);maincpu.pb@(temp1+$11)=maincpu.pb@(((A4)&$FFFFFF)+$58);maincpu.pb@(temp1+$12)=maincpu.pb@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$58);maincpu.pb@(temp1+$13)=maincpu.pb@(maincpu.pd@((PC)+$2));maincpu.pb@(temp1+$14)=maincpu.pb@((maincpu.pd@((PC)+$02))+((maincpu.pw@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$10))<<3)+$3);maincpu.pb@(temp1+$15)=maincpu.pb@((maincpu.pd@((PC)+$02))+((maincpu.pw@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$10))<<3)+$4);maincpu.pb@(temp1+$16)=maincpu.pb@((maincpu.pd@((PC)+$2))+((maincpu.pw@(((A4)&$FFFFFF)+$10))<<3)+$3);maincpu.pb@(temp1+$17)=maincpu.pb@((PC)+$D2+(maincpu.pw@((A4)&$FFFFFF)+$10)*4+((((D7)&$FFFF)-$60)&$7));g"))

			-- 空中投げ
			table.insert(bps, cpu:debug():bpset(fix_bp_addr(0x060428),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CD00+((((A4)&$FFFFFF)-$100400)/$8);maincpu.pb@(temp1)=$1;maincpu.pw@(temp1+$1)=maincpu.pw@(A0);maincpu.pw@(temp1+$3)=maincpu.pw@((A0)+$2);maincpu.pd@(temp1+$5)=$FFFFFF&(A4);maincpu.pd@(temp1+$9)=maincpu.pd@(($FFFFFF&(A4))+$96);maincpu.pw@(temp1+$D)=maincpu.pw@(maincpu.pd@(($FFFFFF&(A4))+$96)+$10);maincpu.pd@(temp1+$11)=maincpu.rb@(($FFFFFF&(A4))+$58);g"))

			-- 必殺投げ
			table.insert(bps, cpu:debug():bpset(fix_bp_addr(0x039F2A),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CD40+((((A4)&$FFFFFF)-$100400)/$8);maincpu.pb@(temp1)=$1;maincpu.pw@(temp1+$1)=maincpu.pw@(A0);maincpu.pw@(temp1+$3)=maincpu.pw@((A0)+$2);maincpu.pd@(temp1+$5)=$FFFFFF&(A4);maincpu.pd@(temp1+$9)=maincpu.pd@(($FFFFFF&(A4))+$96);maincpu.pw@(temp1+$D)=maincpu.pw@(maincpu.pd@(($FFFFFF&(A4))+$96)+$10);maincpu.pd@(temp1+$11)=maincpu.rb@(($FFFFFF&(A4))+$58);maincpu.pw@(temp1+$12)=maincpu.pw@(A0+$4);g"))

			-- プレイヤー選択時のカーソル操作表示用データのオフセット
			-- PC=11EE2のときのA4レジスタのアドレスがプレイヤー選択のアイコンの参照場所
			-- データの領域を未使用の別メモリ領域に退避して1P操作で2Pカーソル移動ができるようにする
			-- maincpu.pw@((A4)+$60)=$00F8を付けたすとカーソルをCPUにできる
			table.insert(bps, cpu:debug():bpset(0x11EE2, --アドレス修正不要
				"(maincpu.pw@((A4)+2)==2D98||maincpu.pw@((A4)+2)==33B8)&&maincpu.pw@100701==10B&&maincpu.pb@10FDAF==2&&maincpu.pw@10FDB6!=0&&maincpu.pb@100026==2",
				"maincpu.pb@10CDD0=($FF&((maincpu.pb@10CDD0)+1));maincpu.pd@10CDD1=((A4)+$13);g"))
			table.insert(bps, cpu:debug():bpset(0x11EE2, --アドレス修正不要
				"(maincpu.pw@((A4)+2)==2D98||maincpu.pw@((A4)+2)==33B8)&&maincpu.pw@100701==10B&&maincpu.pb@10FDAF==2&&maincpu.pw@10FDB6!=0&&maincpu.pb@100026==1",
				"maincpu.pb@10CDD0=($FF&((maincpu.pb@10CDD0)+1));maincpu.pd@10CDD5=((A4)+$13);g"))

			-- プレイヤー選択時に1Pか2Pの選択ボタン押したときに対戦モードに移行する
			-- PC=  C5D0 読取反映先=?? スタートボタンの読取してるけど関係なし
			-- PC= 12376 読取反映先=D0 スタートボタンの読取してるけど関係なし
			-- PC=C096A8 読取反映先=D1 スタートボタンの読取してるけど関係なし
			-- PC=C1B954 読取反映先=D2 スタートボタンの読取してるとこ 
			table.insert(bps, cpu:debug():bpset(0xC1B95A,
				"(maincpu.pb@100024==1&&maincpu.pw@100701==10B&&maincpu.pb@10FDAF==2&&maincpu.pw@10FDB6!=0)&&((((maincpu.pb@300000)&$10)==0)||(((maincpu.pb@300000)&$80)==0))",
				"D2=($FF^$04);g"))
			table.insert(bps, cpu:debug():bpset(0xC1B95A,
				"(maincpu.pb@100024==2&&maincpu.pw@100701==10B&&maincpu.pb@10FDAF==2&&maincpu.pw@10FDB6!=0)&&((((maincpu.pb@340000)&$10)==0)||(((maincpu.pb@340000)&$80)==0))",
				"D2=($FF^$01);g"))

			-- 影表示
			--{base = 0x017300, ["rbff2k"] = 0x28, ["rbff2h"] = 0x0, no_background = true,
			--			func = function() memory.pgm:write_u8(gr("a4") + 0x82, 0) end},
			if global.no_background then
				--solid shadows 01
				--no    shadows FF
				table.insert(bps, cpu:debug():bpset(fix_bp_addr(0x017300), "maincpu.pw@107C22>0", "maincpu.pb@((A4)+$82)=$FF;g"))
			end
		end
	end

	local bps_rg = {}
	local set_bps_rg = function(reset)
		local cpu = manager:machine().devices[":maincpu"]
		if reset then
			for i, idx in ipairs(bps_rg) do
				cpu:debug():bpclr(idx)
			end
			bps_rg = {}
			return
		end
		if #bps_rg == 0 then
			-- この処理をそのまま有効にすると通常時でも食らい判定が見えるようになるが、MVS版ビリーの本来は攻撃判定無しの垂直ジャンプ攻撃がヒットしてしまう
			-- ビリーの判定が出ない(maincpu.pb@((A0)+$B6)==0)な垂直小ジャンプAと垂直小ジャンプBと斜め小ジャンプBときはこのワークアラウンドが動作しないようにする
			local cond1 = "(maincpu.pw@107C22>0)&&(maincpu.pb@((A0)+$B6)==0)&&(maincpu.pw@((A0)+$60)!=$50)&&(maincpu.pw@((A0)+$60)!=$51)&&(maincpu.pw@((A0)+$60)!=$54)"
			--check vuln at all times *** setregister for m68000.pc is broken *** --bp 05C2E8, 1, {PC=((PC)+$6);g}
			table.insert(bps_rg, cpu:debug():bpset(fix_bp_addr(0x5C2E8), cond1.."&&(maincpu.pb@((A3)+$B6)==0)", "PC=((PC)+$6);g"))
			--この条件で動作させると攻撃判定がでてしまってヒットしてしまうのでダメ
			--[[
			local cond2 = "(maincpu.pw@107C22>0)&&(maincpu.pb@((A0)+$B6)==0)&&((maincpu.pw@((A0)+$60)==$50)||(maincpu.pw@((A0)+$60)==$51)||(maincpu.pw@((A0)+$60)==$54))"
			table.insert(bps_rg, cpu:debug():bpset(fix_bp_addr(0x5C2E8), cond2, "maincpu.pb@((A3)+$B6)=1;g"))
			]]
			--check vuln at all times *** hackish workaround *** --bp 05C2E8, 1, {A3=((A3)-$B5);g}
			table.insert(bps_rg, cpu:debug():bpset(fix_bp_addr(0x5C2E8), cond1, "A3=((A3)-$B5);g"))
			--*** fix for hackish workaround *** --bp 05C2EE, 1, {A3=((A3)+$B5);g}
			table.insert(bps_rg, cpu:debug():bpset(fix_bp_addr(0x5C2EE), cond1, "A3=((A3)+$B5);g"))
		end
	end

	local set_hook = function(reset)
		set_wps(reset)
		set_bps(reset)
		set_bps_rg(reset)
	end

	-- 誤動作防止のためフックで使用する領域を初期化する
	local cls_hook = function()
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]

		-- 各種当たり判定のフック
		-- 0x10CB40 当たり判定の発生個数
		-- 0x10CB41 から 0x10 間隔で当たり判定をbpsetのフックで記録する
		for addr = 0x10CB41, 0x10CB41 + pgm:read_u8(0x10CB40) * 0x10, 0x10 do
			pgm:write_u8(addr, 0xFF)
		end
		pgm:write_u8(0x10CB40, 0x00)

		for i, p in ipairs(players) do
			pgm:write_u8(p.addr.state2, 0x00)               -- ステータス更新フック
			pgm:write_u8(p.addr.act2, 0x00)                 -- 技ID更新フック

			pgm:write_u8(p.addr.vulnerable1 , 0xFF)         -- 食らい判定のフック
			pgm:write_u8(p.addr.vulnerable21, 0xFF)         -- 食らい判定のフック
			pgm:write_u8(p.addr.vulnerable22, 0xFF)         -- 食らい判定のフック

			pgm:write_u8(p.n_throw.addr.on, 0xFF)           -- 投げのフック
			pgm:write_u8(p.air_throw.addr.on, 0xFF)         -- 空中投げのフック
			pgm:write_u8(p.sp_throw.addr.on, 0xFF)          -- 必殺投げのフック
		end
	end

	-- レコード＆リプレイ
	local recording = {
		state        = 0, -- 0=レコーディング待ち, 1=レコーディング, 2=リプレイ待ち 3=リプレイ開始
		cleanup      = false,
		player       = nil,
		temp_player  = nil,
		play_count   = 1,

		active_slot  = nil,
		slot         = {}, -- スロット
		live_slots   = {}, -- ONにされたスロット

		fixpos       = nil,
		do_repeat    = false,
		repeat_interval = 0,
	}
	for i = 1, 5 do
		recording.slot[i] = {
			side  = 1, -- レコーディング対象のプレイヤー番号 1=1P, 2=2P
			store = {}, -- 入力保存先
			name = "スロット" .. i,
		}
	end
	local rec_await_no_input, rec_await_1st_input, rec_await_play, rec_input, rec_play, rec_repeat_play, rec_play_interval, menu_to_tra, rec_fixpos
	local get_pos = function(i)
		local p = players[i]
		local obj_base = p.addr.base
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		local flip_x = pgm:read_i16(obj_base + 0x6A) < 0 and 1 or 0
		flip_x = bit32.bxor(flip_x, bit32.band(pgm:read_u8(obj_base + 0x71), 1))
		flip_x = flip_x > 0 and 1 or -1
		return flip_x
	end
	local frame_to_time = function(frame_number)
		local min = math.floor(frame_number / 3600)
		local sec = math.floor((frame_number % 3600) / 60)
		local frame = math.floor((frame_number % 3600) % 60)
		return string.format("%02d:%02d:%02d", min, sec, frame)
	end
	-- リプレイ開始位置記憶
	rec_fixpos = function()
		local scr = manager:machine().screens[":screen"]
		local ec = scr:frame_number()

		local pos = { get_pos(1), get_pos(2) }
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		local fixpos = { pgm:read_i16(players[1].addr.pos), pgm:read_i16(players[2].addr.pos) }
		local fixscr = {
			x = pgm:read_u16(stage_base_addr + offset_pos_x),
			y = pgm:read_u16(stage_base_addr + offset_pos_y),
			z = pgm:read_u16(stage_base_addr + offset_pos_z),
		}
		recording.fixpos = { pos = pos, fixpos = fixpos, fixscr = fixscr }
	end
	-- 初回入力まち
	-- 未入力状態を待ちける→入力開始まで待ち受ける
	rec_await_no_input = function()
		local scr = manager:machine().screens[":screen"]
		local ec = scr:frame_number()

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
		end
	end
	rec_await_1st_input = function()
		local scr = manager:machine().screens[":screen"]
		local ec = scr:frame_number()

		local joy_val = get_joy(recording.temp_player)

		local next_val = nil
		local pos = { get_pos(1), get_pos(2) }
		for k, f in pairs(joy_val) do
			if k ~= "1 Player Start" and k ~= "2 Players Start" and f > 0 then
				if not next_val then
					next_val = new_next_joy()
					recording.player = recording.temp_player
					recording.cleanup = false
					recording.active_slot.side = joy_pside[rev_joy[k]] -- レコーディング対象のプレイヤー番号 1=1P, 2=2P
					recording.active_slot.store = {} -- 入力保存先
					table.insert(recording.active_slot.store, { joy = next_val      , pos = pos })
					table.insert(recording.active_slot.store, { joy = new_next_joy(), pos = pos })

					-- 状態変更
					global.rec_main = rec_input
				end
				-- レコード中は1Pと2P入力が入れ替わっているので反転させて記憶する
				next_val[rev_joy[k]] = f > 0
			end
		end
	end
	-- 入力中
	rec_input = function()
		local scr = manager:machine().screens[":screen"]
		local ec = scr:frame_number()

		local joy_val = get_joy(recording.player)

		-- 入力保存
		local next_val = new_next_joy()
		local pos = { get_pos(1), get_pos(2) }
		for k, f in pairs(joy_val) do
			if k ~= "1 Player Start" and k ~= "2 Players Start" and recording.active_slot.side == joy_pside[rev_joy[k]] then
				-- レコード中は1Pと2P入力が入れ替わっているので反転させて記憶する
				next_val[rev_joy[k]] = f > 0
			end
		end
		table.remove(recording.active_slot.store)
		table.insert(recording.active_slot.store, { joy = next_val      , pos = pos })
		table.insert(recording.active_slot.store, { joy = new_next_joy(), pos = pos })
	end
	-- リプレイまち
	rec_await_play = function(force_start_play)
		local scr = manager:machine().screens[":screen"]
		local ec = scr:frame_number()
		local state_past = ec - global.input_accepted

		local empty = true
		for i = 1, #recording.slot do
			if #recording.slot[i].store > 0 then
				empty = false
			end
		end

		if not empty and #recording.live_slots > 0 then
			while true do
				local random_i = math.random(#recording.live_slots)
				local slot_no = recording.live_slots[random_i]
				recording.active_slot = recording.slot[slot_no]
				if #recording.slot[slot_no].store > 0 then
					break
				end
			end
		else
			recording.active_slot = { store = {}, name = "空" }
		end

		-- 冗長な未入力を省く
		if not recording.cleanup then
			for i = #recording.active_slot.store, 1, -1 do
				local empty = true
				for k, v in pairs(recording.active_slot.store[i].joy) do
					if v then
						empty = false
						break
					end
				end
				if empty then
					recording.active_slot.store[i] = nil
				else
					break
				end
			end
			recording.cleanup = true
		end

		local joy_val = get_joy()
		if #recording.active_slot.store > 0 and (accept_input("Start", joy_val, state_past) or force_start_play == true) then
			recording.force_start_play = false
			-- 状態変更
			recording.play_count = 1
			global.rec_main = rec_play
			global.input_accepted = ec
			if global.replay_fix_pos then
				local fixpos = recording.fixpos
				if fixpos then
					local pgm = manager:machine().devices[":maincpu"].spaces["program"]
					if fixpos.fixpos then
						pgm:write_i16(players[1].addr.pos, fixpos.fixpos[1])
						pgm:write_i16(players[2].addr.pos, fixpos.fixpos[2])
					end
					if fixpos.fixscr then
						pgm:write_u16(stage_base_addr + offset_pos_x, fixpos.fixscr.x)
						pgm:write_u16(stage_base_addr + offset_pos_x + 0x30, fixpos.fixscr.x)
						pgm:write_u16(stage_base_addr + offset_pos_x + 0x2C, fixpos.fixscr.x)
						pgm:write_u16(stage_base_addr + offset_pos_x + 0x34, fixpos.fixscr.x)
						pgm:write_u16(stage_base_addr + offset_pos_y, fixpos.fixscr.y)
						pgm:write_u16(stage_base_addr + offset_pos_z, fixpos.fixscr.z)
					end
				end
			end
			return
		end
	end
	-- 繰り返しリプレイ待ち
	rec_repeat_play= function()
		local scr = manager:machine().screens[":screen"]
		local ec = scr:frame_number()

		local joy_val = get_joy()

		local no_input = true
		for k, f in pairs(joy_val) do
			if f > 0 then
				no_input = false
				break
			end
		end

		-- 繰り返し前の行動が完了するまで待つ
		local p = players[3-recording.player]
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
					rec_await_play(true)
				end
			end
		end
	end
	-- リプレイ中
	rec_play = function(to_joy)
		local scr = manager:machine().screens[":screen"]
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		local ec = scr:frame_number()
		local state_past = ec - global.input_accepted

		local joy_val = get_joy()

		if accept_input("Start", joy_val, state_past) then
			-- 状態変更
			global.rec_main = rec_await_play
			global.input_accepted = ec
			return 
		end

		local stop = false
		local store = recording.active_slot.store[recording.play_count]
		if store == nil or pgm:read_u8(players[recording.player].addr.state) == 1 then
			stop = true
		else
			-- 入力再生
			local pos = { get_pos(1), get_pos(2) }
			for _, joy in ipairs(use_joy) do
				local k = joy.field
				-- 入力時と向きが変わっている場合は左右反転させて反映する
				if recording.active_slot.side == joy_pside[k] then
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
		end
	end
	--

	-- リプレイまでの待ち時間
	rec_play_interval = function(to_joy)
		local scr = manager:machine().screens[":screen"]
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		local ec = scr:frame_number()
		local state_past = ec - global.input_accepted

		local joy_val = get_joy()

		if accept_input("Start", joy_val, state_past) then
			-- 状態変更
			global.rec_main = rec_await_play
			global.input_accepted = ec
			return 
		end

		global.repeat_interval = math.max(0, global.repeat_interval - 1)

		local stop = global.repeat_interval == 0

		if stop then
			if recording.do_repeat then
				-- 状態変更
				-- 繰り返し前の行動を覚えておいて、行動が完了するまで待機できるようにする
				recording.last_act = players[3-recording.player].act
				recording.last_pos_y = players[3-recording.player].pos_y
				global.rec_main = rec_repeat_play
			else
				-- 状態変更
				global.rec_main = rec_await_play
			end
		end
	end
	--

	-- 1Pと2Pともにフレーム数が多すぎる場合は加算をやめる
	-- グラフの描画最大範囲（画面の横幅）までにとどめる
	local fix_max_framecount = function()
		local min_count = 332
		for i, p in ipairs(players) do
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

			for j, fb in ipairs(p.fireball) do
				local frame1 = fb.act_frames[#fb.act_frames]
				if frame1.count <= 332 then
					return
				else
					min_count = math.min(min_count, frame1.count)
				end
			end
		end

		local fix = min_count - 332
		for i, p in ipairs(players) do
			local frame1 = p.act_frames[#p.act_frames]
			frame1.count = frame1.count - fix

			frame1 = p.muteki.act_frames[#p.muteki.act_frames]
			frame1.count = frame1.count - fix

			frame1 = p.frm_gap.act_frames[#p.frm_gap.act_frames]
			frame1.count = frame1.count - fix

			for j, fb in ipairs(p.fireball) do
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
				else
					table.insert(frame_group, frame)
					-- 直前までのフレーム合計加算して保存
					frame.last_total = prev_frame.last_total + prev_frame.count
				end
			end
		end
		return frames2, upd
	end
	-- グラフでフレームデータを表示する
	local dodraw = function(x1, y, frame_group, main_frame, height, xmax, show_name, show_count, x, scr, txty)
		local grp_len = #frame_group
		if 0 < grp_len then
			-- 最終フレームに記録された全フレーム数を記憶
			x1 = math.min((frame_group[grp_len].last_total or 0) + frame_group[grp_len].count + x, xmax)
			-- グループの名称を描画
			if show_name and main_frame then
				if (frame_group[1].col + frame_group[1].line) > 0 then
					local disp_name = frame_group[1].disp_name or frame_group[1].name
					scr:draw_text(x+12.5, txty+y+ 0.5, disp_name, shadow_col)
					scr:draw_text(x+12  , txty+y     , disp_name, 0xFFC0C0C0)
				end
			end
			-- グループのフレーム数を末尾から描画
			for k = #frame_group, 1, -1 do
				local frame = frame_group[k]
				local x2 = x1 - frame.count
				local on_fb, on_ar, on_gd = false, false, false
				if x2 < x then
					x2 = x
				else
					on_fb = frame.chg_fireball_state == true
					on_ar = frame.chg_air_state == 1
					on_gd = frame.chg_air_state == -1
				end

				if (frame.col + frame.line) > 0 then
					local evx = math.min(x1, x2)
					if on_fb then
						scr:draw_text(evx-1.5, txty+y-1, "●")
					end
					if on_ar then
						scr:draw_text(evx-3, txty+y, "▲")
					elseif on_gd then
						scr:draw_text(evx-3, txty+y, "▼")
					end
					scr:draw_box(x1, y, x2, y+height, frame.col, frame.line)
					if show_count then
						local count_txt = 300 < frame.count and "LOT" or (""..frame.count)
						if frame.count > 5 then
							scr:draw_text(x2+1.5, txty+y+0.5, count_txt, shadow_col)
							scr:draw_text(x2+1  , txty+y    , count_txt)
						elseif 3 > frame.count then
							scr:draw_text(x2-0.5, txty+y+0.5, count_txt, shadow_col)
							scr:draw_text(x2-1  , txty+y    , count_txt)
						else
							scr:draw_text(x2    , txty+y+0.5, count_txt, shadow_col)
							scr:draw_text(x2    , txty+y    , count_txt)
						end
					end
				end
				if x2 <= x then
					break
				end
				x1 = x2
			end
		end
	end
	local draw_frames = function(frames2, xmax, show_name, show_count, x, y, height, span)
		if #frames2 == 0 then
			return
		end
		local scr = manager:machine().screens[":screen"]
		span = span or height
		local txty = math.max(-2, height-8)

		-- 縦に描画
		local x1 = xmax
		if #frames2 < 7 then
			y = y + (7 - #frames2) * span
		end
		for j = #frames2 - math.min(#frames2 - 1, 6), #frames2 do
			local frame_group = frames2[j]
			dodraw(x1, y + span, frame_group, true, height, xmax, show_name, show_count, x, scr, txty)
			for _, frame in ipairs(frame_group) do
				if frame.frm_gap then
					for _, sub_group in ipairs(frame.frm_gap) do
						dodraw(x1, y + 6 + span, sub_group, false, height-3, xmax, show_name, show_count, x, scr, txty-1)
					end
				end
				if frame.muteki then
					for _, sub_group in ipairs(frame.muteki) do
						dodraw(x1, y + 11 + span, sub_group, false, height-3, xmax, show_name, show_count, x, scr, txty-1)
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
		local scr = manager:machine().screens[":screen"]

		-- 横に描画
		local xmin = x --30
		local xmax = math.min(325 - xmin, act_frames_total + xmin)
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
					scr:draw_box (x1, y, x2, y+height, frame.col, frame.line)
					if show_count == true and first == true then
						first = false
						local txty = math.max(-2, height-8)
						local count_txt = 300 < frame.count and "LOT" or (""..frame.count)
						if frame.count > 5 then
							scr:draw_text(x2+1.5, txty+y+0.5, count_txt, shadow_col)
							scr:draw_text(x2+1  , txty+y    , count_txt)
						elseif 3 > frame.count then
							scr:draw_text(x2-0.5, txty+y+0.5, count_txt, shadow_col)
							scr:draw_text(x2-1  , txty+y    , count_txt)
						else
							scr:draw_text(x2    , txty+y+0.5, count_txt, shadow_col)
							scr:draw_text(x2    , txty+y    , count_txt)
						end
					end
				end
				if loopend then break end
				x1 = x2
			end
			if loopend then break end
		end
	end

	-- トレモのメイン処理
	tra_main = {}
	tra_main.proc = function()
		-- メイン処理
		if not match_active then
			return
		end
		-- ポーズ中は状態を更新しない
		if mem_0x10E043 ~= 0 then
			return
		end

		local next_joy = new_next_joy()

		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		local scr = manager:machine().screens[":screen"]
		local ec = scr:frame_number()
		local state_past = ec - global.input_accepted
		local width = scr:width() * scr:xscale()
		local joy_val = get_joy()

		global.frame_number = global.frame_number + 1

		-- ポーズ解除状態
		set_freeze((not match_active) or true)

		-- スタートボタン（リプレイモード中のみスタートボタンおしっぱでメニュー表示へ切り替え
		if (global.dummy_mode == 6 and is_start_a(joy_val, state_past)) or
		   (global.dummy_mode ~= 6 and accept_input("Start", joy_val, state_past)) then
			-- メニュー表示状態へ切り替え
			global.input_accepted = ec
			main_or_menu_state = menu
			menu_move_fc = ec
			cls_joy()
			return
		end

		screen_left = pgm:read_i16(stage_base_addr + offset_pos_x) + (320 - width) / 2 --FBA removes the side margins for some games
		screen_top  = pgm:read_i16(stage_base_addr + offset_pos_y)

		-- プレイヤーと飛び道具のベースアドレスをキー、オブジェクトを値にするバッファ
		local temp_hits = {}

		-- 1Pと2Pの状態読取
		for i, p in ipairs(players) do
			local op         = players[3-i]
			local p1         = i == 1

			p.life           = pgm:read_u8(p.addr.life)                 -- 今の体力
			p.old_state      = p.state                                  -- 前フレームの状態保存
			p.state          = pgm:read_u8(p.addr.state)                -- 今の状態
			p.combo          = tohexnum(pgm:read_u8(p.addr.combo2))     -- 最近のコンボ数
			p.tmp_combo      = tohexnum(pgm:read_u8(p.addr.tmp_combo2)) -- 一次的なコンボ数
			p.max_combo      = tohexnum(pgm:read_u8(p.addr.max_combo2)) -- 最大コンボ数
			p.tmp_dmg        = pgm:read_u8(p.addr.last_dmg)  -- ダメージ
			pgm:write_u8(p.addr.last_dmg, 0x00)              -- つぎの更新チェックのためにゼロにする(フックが出来なかったのでワークアラウンド)

			p.old_act        = p.act or 0x00
			p.act            = pgm:read_u16(p.addr.act)
			p.provoke        = 0x0196 == p.act --挑発中
			p.stop           = pgm:read_u8(p.addr.stop)
			p.last_dmg       = p.last_dmg or 0 --pgm:read_u8(p.addr.last_dmg)
			p.char           = pgm:read_u8(p.addr.char)
			p.pos            = pgm:read_i16(p.addr.pos)
			p.old_pos_y      = p.pos_y
			p.pos_y          = pgm:read_i16(p.addr.pos_y)
			p.pos_z          = pgm:read_i16(p.addr.pos_z)
			p.on_sway_line   = 24 < p.pos_z
			p.side           = pgm:read_i8(p.addr.side) < 0 and -1 or 1

			p.attack         = pgm:read_u8(p.addr.attack)

			p.life           = pgm:read_u8(p.addr.life)
			p.pow            = pgm:read_u8(p.addr.pow)
			p.init_stun      = init_stuns[p.char]
			p.max_stun       = pgm:read_u8(p.addr.max_stun)
			p.stun           = pgm:read_u8(p.addr.stun)
			p.stun_timer     = pgm:read_u16(p.addr.stun_timer)

			-- フレーム表示用処理
			p.act_frames     = p.act_frames  or {}
			p.act_frames2    = p.act_frames2 or {}
			p.act_frames_total = p.act_frames_total or 0

			p.muteki.act_frames    = p.muteki.act_frames   or {}
			p.muteki.act_frames2   = p.muteki.act_frames2  or {}
			p.frm_gap.act_frames   = p.frm_gap.act_frames  or {}
			p.frm_gap.act_frames2  = p.frm_gap.act_frames2 or {}

			p.act_contact    = pgm:read_u8(p.addr.act_contact)
			p.on_guard       = p.on_guard or 0
			p.hit_skip       = p.hit_skip or 0
			p.old_act_data   = p.act_data or { name = "", type = act_types.any, }
			if char_acts[p.char] and char_acts[p.char][p.act] then
				p.act_data   = char_acts[p.char][p.act]
				p.act_1st    = char_1st_acts[p.char][p.act] or false
			elseif char_acts[#char_acts] and char_acts[#char_acts][p.act] then
				p.act_data   = char_acts[#char_acts][p.act]
				p.act_1st    = char_1st_acts[#char_acts][p.act] or false
			else
				p.act_data   = {
					name     = (p.state == 1 or p.state == 3) and "やられ" or tohex(p.act), 
					type     = act_types.any,
				}
				p.act_1st    = false
			end
			p.old_act_normal = p.act_normal
			p.act_normal     = p.act_data.type == act_types.free

			-- 飛び道具の状態読取
			for _, fb in pairs(p.fireball) do
				fb.act            = pgm:read_u16(fb.addr.act)
				fb.pos            = pgm:read_i16(fb.addr.pos)
				fb.pos_y          = pgm:read_i16(fb.addr.pos_y)
				fb.pos_z          = pgm:read_i16(fb.addr.pos_z)
				fb.hit.projectile = true
				fb.hitboxes       = {}
				fb.buffer         = {}
				fb.act_data_fired = p.act_data -- 発射したタイミングの行動ID

				fb.act_frames     = fb.act_frames  or {}
				fb.act_frames2    = fb.act_frames2 or {}

				-- 当たり判定の構築
				if pgm:read_u16(pgm:read_u32(fb.addr.base)) ~= 0x4E75 then --0x4E75 is rts instruction
					temp_hits[fb.addr.base] = fb
					fb.count = (fb.count or 0) +1
					fb.atk_count = fb.atk_count or 0
				else
					fb.count = 0
					fb.atk_count = 0
				end
			end

			-- 値更新のフック確認
			p.update_sts = (pgm:read_u8(p.addr.state2) ~= 0) and global.frame_number or p.update_sts
			p.update_dmg = (p.tmp_dmg ~= 0) and global.frame_number or p.update_dmg
			p.update_act = (pgm:read_u8(p.addr.act2) ~= 0) and global.frame_number or p.update_act
			p.act_1st    = p.update_act == global.frame_number and p.act_1st == true

			-- 当たり判定のフック確認
			p.hit.vulnerable1  = pgm:read_u8(p.addr.vulnerable1)
			p.hit.vulnerable21 = pgm:read_u8(p.addr.vulnerable21)
			p.hit.vulnerable22 = pgm:read_u8(p.addr.vulnerable22) == 0 --0の時vulnerable=true

			-- 投げ判定取得
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
			p.n_throw.range6   = pgm:read_i8(p.n_throw.addr.range6)
			local range = (p.n_throw.range1 == p.n_throw.range2 and math.abs(p.n_throw.range42*4)) or math.abs(p.n_throw.range41*4)
			range = range + p.n_throw.range5 * -4
			range = range + p.n_throw.range6
			p.n_throw.range    = range
			p.n_throw.right    = p.n_throw.range * p.side
			p.n_throw.type     = box_type_base.t
			p.n_throw.on = p.addr.base == p.n_throw.base and p.n_throw.on or 0

			-- 空中投げ判定取得
			p.air_throw.left     = nil
			p.air_throw.right    = nil
			p.air_throw.on       = pgm:read_u8(p.air_throw.addr.on)
			p.air_throw.range_x  = pgm:read_i16(p.air_throw.addr.range_x)
			p.air_throw.range_y  = pgm:read_i16(p.air_throw.addr.range_y)
			p.air_throw.base     = pgm:read_u32(p.air_throw.addr.base)
			p.air_throw.opp_base = pgm:read_u32(p.air_throw.addr.opp_base)
			p.air_throw.opp_id   = pgm:read_u16(p.air_throw.addr.opp_id)
			p.air_throw.side     = p.side
			p.air_throw.right    = p.air_throw.range_x * p.hit.flip_x
			p.air_throw.top      = -p.air_throw.range_y
			p.air_throw.bottom   =  p.air_throw.range_y
			p.air_throw.type     = box_type_base.at
			p.air_throw.on = p.addr.base == p.air_throw.base and p.air_throw.on or 0

			-- 必殺投げ判定取得
			p.sp_throw.left      = nil
			p.sp_throw.right     = nil
			p.sp_throw.top       = nil
			p.sp_throw.bottom    = nil
			p.sp_throw.on        = pgm:read_u8(p.sp_throw.addr.on)
			p.sp_throw.front     = pgm:read_i16(p.sp_throw.addr.front)
			p.sp_throw.top       = pgm:read_i16(p.sp_throw.addr.top)
			p.sp_throw.base      = pgm:read_u32(p.sp_throw.addr.base)
			p.sp_throw.opp_base  = pgm:read_u32(p.sp_throw.addr.opp_base)
			p.sp_throw.opp_id    = pgm:read_u16(p.sp_throw.addr.opp_id)
			p.sp_throw.side      = p.side
			p.sp_throw.bottom    = pgm:read_i16(p.sp_throw.addr.bottom)
			p.sp_throw.right     = p.sp_throw.front * p.hit.flip_x
			p.sp_throw.type      = box_type_base.pt
			p.sp_throw.on = p.addr.base == p.sp_throw.base and p.sp_throw.on or 0
			if p.sp_throw.top == 0 then
				p.sp_throw.top    = nil
				p.sp_throw.bottom = nil
			end

			-- 当たり判定の構築用バッファのリフレッシュ
			p.hitboxes, p.buffer = {}, {}
			temp_hits[p.addr.base] = p

			--攻撃種類,ガード要否
			if p.update_sts and p.state ~= p.old_state then
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
					if char_fireballs[p.char][fb.act] then
						-- 双角だけ中段と下段の飛び道具がある
						act_type = char_fireballs[p.char][fb.act].type
					end
					op.need_block     = op.need_block or (act_type == act_types.low_attack) or (act_type == act_types.attack) or (act_type == act_types.overhead)
					op.need_low_block = op.need_low_block or (act_type == act_types.low_attack)
					op.need_ovh_block = op.need_ovh_block or (act_type == act_types.overhead)
					--print(string.format("%x %s", fb.act, act_type)) -- debug
				end
			end
		end

		-- 判定データ排他用のテーブル
		local uniq_hitboxes = {}

		-- キャラと飛び道具の当たり判定取得
		for addr = 0x10CB41, 0x10CB41 + pgm:read_u8(0x10CB40) * 0x10, 0x10 do
			local box = {
				on          = pgm:read_u8(addr),
				id          = pgm:read_u8(addr+1),
				top         = pgm:read_i8(addr+2),
				bottom      = pgm:read_i8(addr+3),
				left        = pgm:read_i8(addr+4),
				right       = pgm:read_i8(addr+5),
				base        = pgm:read_u32(addr+6),
				attack_only = (pgm:read_u8(addr+0xA) == 1),
			}
			if box.on ~= 0xFF and temp_hits[box.base] then
				box.key = string.format("%x %x id:%x x1:%x x2:%x y1:%x y2:%x", global.frame_number, box.base, box.id, box.top, box.bottom, box.left, box.right)
				if not uniq_hitboxes[box.key] then
					uniq_hitboxes[box.key] = true
					box.is_fireball = temp_hits[box.base].is_fireball == true
					table.insert(temp_hits[box.base].buffer, box)
				else
					--print("DROP " .. box.key) --debug
				end
			else
				--print("DROP " .. box.key) --debug
			end
		end
		uniq_hitboxes = {}
		for _, p in pairs(temp_hits) do
			-- キャラと飛び道具への当たり判定の反映
			-- update_objectはキャラの位置情報と当たり判定の情報を読み込んだ後で実行すること
			update_object(p, global.frame_number)
		end

		-- キャラ間の距離
		p_space = players[1].pos - players[2].pos

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
				p.control = 3-i
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

		for i, p in ipairs(players) do
			local op = players[3-i]

			--フレーム数
			p.frame_gap      = p.frame_gap or 0
			p.last_frame_gap = p.last_frame_gap or 0
			if mem_0x10B862 ~= 0 and p.act_contact ~= 0 then
				if p.state == 2 then
					p.on_guard = global.frame_number
				end
				p.hit_skip = 2
			end

			--停止演出のチェック
			p.skip_frame = p.hit_skip ~= 0 or p.stop ~= 0 or mem_0x10D4EA ~= 0

			if p.skip_frame then
				--停止フレームはフレーム計算しない
				if p.hit_skip ~= 0 then
					--ヒットストップの減算
					p.hit_skip = p.hit_skip - 1
				end
			end

			-- ジャンプの遷移ポイントかどうか
			local chg_air_state = 0
			if 0 == p.old_pos_y and 0 < p.pos_y then
				chg_air_state = 1
			elseif (0 < p.old_pos_y) and 0 == p.pos_y then
				chg_air_state = -1
			end

			-- 飛び道具
			local chg_fireball_state = false
			for _, fb in pairs(p.fireball) do
				local atk = false -- 攻撃判定 発生中
				for _, box in pairs(fb.hitboxes) do
					if box.visible then
						atk = true
						fb.atk_count = (fb.atk_count or 0) + 1 -- 攻撃判定発生のカウント
						if fb.atk_count == 1 and fb.act_data_fired.name == p.act_data.name then
							chg_fireball_state = true
						end
						break
					end
				end

				local frame = fb.act_frames[#fb.act_frames]
				if #fb.act_frames == 0 or (frame == nil) or frame.atk ~= atk then
					local col, line
					if atk then
						col, line = 0xAAFF1493, 0xDDFF1493
					else
						col, line = 0x00000000, 0x00000000
					end
					-- 軽量化のため攻撃の有無だけで記録を残す
					frame = { act = atk and 1 or 0, count = 1, col = col, name = atk and "A" or "", atk = atk, line = line, }
					-- 関数の使いまわすためact_framesは配列にするが明細を表示ないので1個しかもたなくていい
					fb.act_frames[1] = frame
				else
					-- 同一行動IDが継続している場合はフレーム値加算
					frame.count = frame.count + 1
				end
				-- 技名でグループ化したフレームデータの配列をマージ生成する
				fb.act_frames2, _ = frame_groups(frame, fb.act_frames2 or {})
			end

			--ガード移行できない行動は色替えする
			local col, line = 0xAAF0E68C, 0xDDF0E68C
			if p.skip_frame or p.hit_skip ~= 0 then
				col, line = 0xAA888888, 0xDD888888
			elseif p.attacking then
				col, line = 0xAAFF1493, 0xDDFF1493
			elseif p.throwing then
				col, line = 0xAAD2691E, 0xDDD2691E
			elseif p.act_normal then
				col, line = 0x44FFFFFF, 0xDDFFFFFF
			end

			-- 行動が変わったかのフラグ
			local frame = p.act_frames[#p.act_frames]
			local prev_last_frame = frame
			local chg_act_name = (p.old_act_data.name ~= p.act_data.name)
			local disp_name = convert(p.act_data.disp_name or p.act_data.name)
			if #p.act_frames == 0 or chg_act_name or frame.col ~= col or chg_air_state ~= 0 or chg_fireball_state == true or p.act_1st then
				--行動IDの更新があった場合にフレーム情報追加
				frame = {
					act = p.act,
					count = 1,
					col = col,
					name = p.act_data.name,
					disp_name = disp_name,
					line = line,
					chg_fireball_state = chg_fireball_state,
					chg_air_state = chg_air_state,
					act_1st = p.act_1st,
				}
				table.insert(p.act_frames , frame)
				if 180 < #p.act_frames then
					--バッファ長調整
					table.remove(p.act_frames, 1)
				end
			else
				--同一行動IDが継続している場合はフレーム値加算
				frame.count = frame.count + 1
			end
			-- 技名でグループ化したフレームデータの配列をマージ生成する
			p.act_frames2, _ = frame_groups(frame, p.act_frames2 or {})
			-- 表示可能範囲（最大で横画面幅）以上は加算しない
			p.act_frames_total = (332 < p.act_frames_total) and 332 or (p.act_frames_total + 1)
			-- 後の処理用に最終フレームを保持
			local last_frame = frame

			-- 無敵表示
			local muteki = 0 -- 無敵
			local vul_hi, vul_lo = 240, 0
			for _, box in pairs(p.hitboxes) do
				if box.type.type == "vuln" then
					muteki = 3
					if box.top < box.bottom then
						vul_hi = math.min(vul_hi, box.top-screen_top)
						vul_lo = math.max(vul_lo, box.bottom-screen_top)
					else
						vul_hi = math.min(vul_hi, box.bottom-screen_top)
						vul_lo = math.max(vul_lo, box.top-screen_top)
					end
				end
			end
			if p.on_sway_line then
				-- スウェー上
				muteki, col, line = 4, 0xAAFFA500, 0xDDAFEEEE
			elseif muteki == 0 then
				-- 全身無敵
				muteki, col, line = 0, 0xAAB0E0E6, 0xDDAFEEEE
			elseif 152 <= vul_hi and p.pos_y <= 0 then -- 152 ローレンス避け 156 兄龍転身 168 その他避け
				-- 上半身無敵（地上）
				muteki, col, line = 1, 0xAA32CD32, 0xDDAFEEEE
			elseif vul_lo <= 172 and p.pos_y <= 0 then -- 160 164 168 172 ダブルローリング サイドワインダー
				-- 足元無敵（地上）
				muteki, col, line = 2, 0xAA9400D3, 0xDDAFEEEE
			else
				muteki, col, line = 3, 0x00000000, 0x00000000
			end
			--print(string.format("top %s, hi %s, lo %s", screen_top, vul_hi, vul_lo))

			frame = p.muteki.act_frames[#p.muteki.act_frames]
			if frame == nil or chg_act_name or frame.col ~= col or p.state ~= p.old_state or p.act_1st then
				--行動IDの更新があった場合にフレーム情報追加
				frame = {
					act = p.act,
					count = 1,
					col = col,
					name = p.act_data.name,
					disp_name = disp_name,
					line = line,
					act_1st = p.act_1st,
				}
				table.insert(p.muteki.act_frames , frame)
				if 180 < #p.muteki.act_frames then
					--バッファ長調整
					table.remove(p.muteki.act_frames, 1)
				end
			else
				--同一行動IDが継続している場合はフレーム値加算
				frame.count = frame.count + 1
			end
			-- 技名でグループ化したフレームデータの配列をマージ生成する
			local upd_group = false
			p.muteki.act_frames2, upd_group = frame_groups(frame, p.muteki.act_frames2 or {})
			-- メインフレーム表示からの描画開始位置を記憶させる
			if upd_group then
				last_frame.muteki = last_frame.muteki or {}
				table.insert(last_frame.muteki, p.muteki.act_frames2[#p.muteki.act_frames2])
			end

			--フレーム差
			if p.act_normal and op.act_normal then
				p.frame_gap = 0
				col, line = 0x00000000, 0x00000000
			elseif not p.act_normal and not op.act_normal then
				if p.state == 0 and op.state == 1 then
					p.frame_gap = p.frame_gap + 1
					p.last_frame_gap = p.frame_gap
					col, line = 0xAA0000FF, 0xDD0000FF
				elseif p.state == 1 and op.state == 0 then
					p.frame_gap = p.frame_gap - 1
					p.last_frame_gap = p.frame_gap
					col, line = 0xAAFF6347, 0xDDFF6347
				else
					p.frame_gap = 0
					col, line = 0x00000000, 0x00000000
				end
			elseif p.act_normal and not op.act_normal then
				-- 直前が行動中ならリセットする
				if not p.old_act_normal then
					p.frame_gap = 0
				end
				p.frame_gap = p.frame_gap + 1
				p.last_frame_gap = p.frame_gap
				col, line = 0xAA0000FF, 0xDD0000FF
			elseif not p.act_normal and op.act_normal then
				-- 直前が行動中ならリセットする
				if not op.old_act_normal then
					p.frame_gap = 0
				end
				p.frame_gap = p.frame_gap - 1
				p.last_frame_gap = p.frame_gap
				col, line = 0xAAFF6347, 0xDDFF6347
			end

			frame = p.frm_gap.act_frames[#p.frm_gap.act_frames]
			if frame == nil or chg_act_name or (frame.col ~= col and (p.frame_gap == 0 or p.frame_gap == -1 or p.frame_gap == 1)) or p.act_1st then
				--行動IDの更新があった場合にフレーム情報追加
				frame = {
					act = p.act,
					count = 1,
					col = col,
					name = p.act_data.name,
					disp_name = disp_name,
					line = line,
					act_1st = p.act_1st,
				}
				table.insert(p.frm_gap.act_frames , frame)
				if 180 < #p.frm_gap.act_frames then
					--バッファ長調整
					table.remove(p.frm_gap.act_frames, 1)
				end
			else
				--同一行動IDが継続している場合はフレーム値加算
				frame.count = frame.count + 1
			end
			-- 技名でグループ化したフレームデータの配列をマージ生成する
			p.frm_gap.act_frames2, upd_group = frame_groups(frame, p.frm_gap.act_frames2 or {})
			-- メインフレーム表示からの描画開始位置を記憶させる
			if upd_group then
				last_frame.frm_gap = last_frame.frm_gap or {}
				table.insert(last_frame.frm_gap, p.frm_gap.act_frames2[#p.frm_gap.act_frames2])
			end

			--[[ debug
			-- 技IDの確認用
			if i == 1 and p.old_act ~= p.act and p.act then
				print(string.format("%x %x", p.char, p.act))
			end
			]]
		end
		--1Pと2Pともにフレーム数が多すぎる場合は加算をやめる
		fix_max_framecount()

		for i, p in ipairs(players) do
			local p1 = i == 1

			-- 入力表示用の情報構築
			local key_now = p.key_now
			key_now.d  = bit32.band(p.reg_pcnt, 0x80) == 0x00 and posi_or_pl1(key_now.d ) or nega_or_mi1(key_now.d ) -- Button D
			key_now.c  = bit32.band(p.reg_pcnt, 0x40) == 0x00 and posi_or_pl1(key_now.c ) or nega_or_mi1(key_now.c ) -- Button C
			key_now.b  = bit32.band(p.reg_pcnt, 0x20) == 0x00 and posi_or_pl1(key_now.b ) or nega_or_mi1(key_now.b ) -- Button B
			key_now.a  = bit32.band(p.reg_pcnt, 0x10) == 0x00 and posi_or_pl1(key_now.a ) or nega_or_mi1(key_now.a ) -- Button A
			key_now.rt = bit32.band(p.reg_pcnt, 0x08) == 0x00 and posi_or_pl1(key_now.rt) or nega_or_mi1(key_now.rt) -- Right
			key_now.lt = bit32.band(p.reg_pcnt, 0x04) == 0x00 and posi_or_pl1(key_now.lt) or nega_or_mi1(key_now.lt) -- Left
			key_now.dn = bit32.band(p.reg_pcnt, 0x02) == 0x00 and posi_or_pl1(key_now.dn) or nega_or_mi1(key_now.dn) -- Down
			key_now.up = bit32.band(p.reg_pcnt, 0x01) == 0x00 and posi_or_pl1(key_now.up) or nega_or_mi1(key_now.up) -- Up
			key_now.sl = bit32.band(p.reg_st_b, p1 and 0x02 or 0x08) == 0x00 and posi_or_pl1(key_now.sl) or nega_or_mi1(key_now.sl) -- Select
			key_now.st = bit32.band(p.reg_st_b, p1 and 0x01 or 0x04) == 0x00 and posi_or_pl1(key_now.st) or nega_or_mi1(key_now.st) -- Start
			local lever
			if bit32.band(p.reg_pcnt, 0x01 + 0x04) == 0x00 then
				lever = "_7"
			elseif bit32.band(p.reg_pcnt, 0x01 + 0x08) == 0x00 then
				lever = "_9"
			elseif bit32.band(p.reg_pcnt, 0x02 + 0x04) == 0x00 then
				lever = "_1"
			elseif bit32.band(p.reg_pcnt, 0x02 + 0x08) == 0x00 then
				lever = "_3"
			elseif bit32.band(p.reg_pcnt, 0x01) == 0x00 then
				lever = "_8"
			elseif bit32.band(p.reg_pcnt, 0x02) == 0x00 then
				lever = "_2"
			elseif bit32.band(p.reg_pcnt, 0x04) == 0x00 then
				lever = "_4"
			elseif bit32.band(p.reg_pcnt, 0x08) == 0x00 then
				lever = "_6"
			else
				lever = "_N"
			end
			if bit32.band(p.reg_pcnt, 0x10) == 0x00 then
				lever = lever .. "_A"
			end
			if bit32.band(p.reg_pcnt, 0x20) == 0x00 then
				lever = lever .. "_B"
			end
			if bit32.band(p.reg_pcnt, 0x40) == 0x00 then
				lever = lever .. "_C"
			end
			if bit32.band(p.reg_pcnt, 0x80) == 0x00 then
				lever = lever .. "_D"
			end
			if p.key_hist[#p.key_hist] ~= lever then
				for k = 2, #p.key_hist do
					p.key_hist[k - 1] = p.key_hist[k]
					p.key_frames[k - 1] = p.key_frames[k]
				end
				if 18 ~= #p.key_hist then
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
			local state = p.state ~= 0 -- 素立ちじゃない
			if state == false then
				p.tmp_combo_dmg = 0
			end
			if p.tmp_dmg ~= 0x00 then
				p.last_dmg = p.tmp_dmg
				p.tmp_combo_dmg = p.tmp_combo_dmg + p.tmp_dmg
				p.last_combo = p.tmp_combo
				p.last_combo_dmg = p.tmp_combo_dmg
				if p.max_dmg < p.tmp_combo_dmg then
					p.max_dmg = p.tmp_combo_dmg
				end
			end
			p.last_state = state

			-- 体力とスタン値とMAXスタン値回復
			if p.life_rec then
				local max_life = p.red and 0x60 or 0xC0 -- 赤体力にするかどうか

				-- 回復判定して回復
				if p.old_state ~= p.state and max_life ~= p.life then
					-- やられ状態から戻ったときに回復させる
					pgm:write_u8(p.addr.life, max_life)         -- 体力
					pgm:write_u8(p.addr.stun, p.addr.init_stun) -- スタン値
				elseif max_life < p.life then
					-- 最大値の方が少ない場合は強制で減らす
					pgm:write_u8(p.addr.life, max_life)
				end
			end

			-- パワーゲージ回復
			local max_pow  = p.max and 0x3C or 0x00 -- パワーMAXにするかどうか
			if max_pow ~= 0 then
				pgm:write_u8(p.addr.pow, max_pow)
			end
		end

		-- プレイヤー操作
		for i, p in ipairs(players) do
			local op   = players[3-i]
			if p.control == 1 or p.control == 2 then
				--前進とガード方向
				local sp = p_space == 0 and prev_p_space or p_space
				sp = i == 1 and sp or (sp * -1)
				local lt, rt = "P".. p.control .." Left", "P" .. p.control .. " Right"
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
				-- レコード中、リプレイ中は行動しない
				if accept_control then
					if     p.dummy_act == 1 then
					elseif p.dummy_act == 2 then
						next_joy["P" .. p.control .. " Down"] = true
					elseif p.dummy_act == 3 then
						next_joy["P" .. p.control .. " Up"] = true
					elseif p.dummy_act == 4 then
						-- 地上のジャンプ移行モーション以外だったら上入力
						if p.act < 8 then
							next_joy["P" .. p.control .. " Up"] = true
						end
					elseif p.dummy_act == 5 then
						if not p.on_sway_line then
							if joy_val["P" .. p.control .. " Button 4"] < 0 then
								next_joy["P" .. p.control .. " Button 4"] = true
							end
						else
							next_joy["P" .. p.control .. " Up"] = true
						end
					end
				end

				-- なし, オート, 1ヒットガード, 1ガード, 常時, ランダム
				-- リプレイ中は自動ガードしない
				if (p.need_block or p.need_low_block or p.need_ovh_block) and accept_control then
					local jumps = {0x9,
						0x0B, 0x0C,
						0x0D, 0x0E,
						0x0F, 0x10,
						0x0B, 0x11, 0x12,
						0x0D, 0x13, 0x14,
						0x0F, 0x15, 0x16,
					}
					for _, jump in pairs(jumps) do
						if jump == p.act then
							next_joy["P" .. p.control .. " Up"] = false
							break
						end
					end
					if p.dummy_gd == 5 then
						-- 常時（ガード方向はダミーモードに従う）
						next_joy[p.block_side] = true
						p.backstep_killer = true
					elseif p.dummy_gd == 2 or -- オート
						(p.dummy_gd == 6 and p.random_boolean) or -- ランダム
						(p.dummy_gd == 3 and p.next_block) or -- 1ヒットガード
						(p.dummy_gd == 4) -- 1ガード
						-- 1ガードのときは連続ガードは成立させたいので上下の切り替えは実施する
					then
						if p.dummy_gd == 4 then
							if p.next_block then
								next_joy[p.block_side] = true
							else
								p.next_block_grace = p.next_block_grace and (p.next_block_grace - 1) or global.next_block_grace
								-- 1ガードのガード解除
								if 0 <= p.next_block_grace then
									next_joy[p.block_side] = true
									next_joy[p.front_side] = false
								else
									next_joy[p.block_side] = false
									next_joy[p.front_side] = true
								end
							end
						else
							next_joy[p.block_side] = true
						end
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
					end
				else
					if p.backstep_killer then
 						next_joy["P" .. p.control .. " Down"] = true
						p.backstep_killer = false
					end
				end
				if p.update_sts and p.state ~= p.old_state and p.dummy_gd == 3 then
					-- 1ヒットガードのときは次ガードすべきかどうかの状態を切り替える
					-- ヒット時はガードに切り替え
					if p.state == 1 then
						p.next_block = true
					end
					-- カウンター初期化
					p.next_block_ec = 75
				elseif p.update_sts and p.state ~= p.old_state and p.dummy_gd == 4 then
					-- 1ガードのときは次ガードすべきかどうかの状態を切り替える
					if p.state == 2 then
						if p.skip_frame or p.hit_skip ~= 0 then
							p.next_block = false
						end
					elseif p.state == 1 then
						p.next_block = true
					end
					-- カウンター初期化
					p.next_block_ec = 75
					p.next_block_grace = global.next_block_grace

					--print((p.next_block and "G" or "-") .. " " .. p.next_block_ec .. " " .. p.state .. " " .. op.old_state)

				else
					-- 状態更新なしでカウンター消費しきったらヒットするように切り替える
					if p.next_block_ec and p.next_block_ec > 0 then
						p.next_block_ec = p.next_block_ec - 1
					else
						p.next_block_ec = 0
					end
					if p.next_block_ec == 0 then
						if p.dummy_gd == 4 then
							p.next_block = true
						elseif p.dummy_gd == 3 then
							p.next_block = false
						end
					end
				end

				--挑発中は前進
				if p.fwd_prov and op.provoke then
					next_joy[p.front_side] = true
				end

				-- なし, テクニカルライズ, グランドスウェー, 起き上がり攻撃
				if p.state ~= 0 then
					if p.act == 0x192 or p.act == 0x18E then
						local btn_val = function(btn)
							if 0 < joy_val[btn] then
								return false
							else
								return true
							end
						end
						if     p.dummy_down == 1 then
						elseif p.dummy_down == 2 then
							local dn = "P" .. p.control .. " Down"
							local d  = "P" .. p.control .. " Button 4"
							next_joy[dn] = btn_val(dn)
							next_joy[d]  = btn_val(d)
						elseif p.dummy_down == 3 then
							local up = "P" .. p.control .. " Up"
							local d  = "P" .. p.control .. " Button 4"
							next_joy[up] = btn_val(up)
							next_joy[d]  = btn_val(d)
						elseif p.dummy_down == 4 then
							-- 舞、ボブ、フランコ、山崎
							if p.char == 0x04 or p.char == 0x07 or p.char == 0x0A or p.char == 0x0B then
								local c  = "P" .. p.control .. " Button 3"
								next_joy[c]  = btn_val(c)
							end
						end
					end
				end

				-- ブレイクショット
				if p.dummy_bs_chr ~= p.char then
					p.dummy_bs = false
					p.dummy_bs_list = {}
					p.dummy_bs_cnt = 0
				end
				if p.dummy_bs == true and p.on_guard == global.frame_number then
					pgm:write_u8(p.addr.bs_hook1, 0x20)             -- BSモード用技ID更新フック
					pgm:write_u8(p.addr.bs_hook2, 0x00)             -- BSモード用技ID更新フック
					local bs_list = p.dummy_bs_list
					if #bs_list > 0 then
						local bs = bs_list[math.random(#bs_list)]
						local id = bs.id or 0x20
						local ver = bs.ver or 0x00
						pgm:write_u8(p.addr.bs_hook1, id)
						pgm:write_u8(p.addr.bs_hook2, ver)
					end

					if p.bs_count < 1 then
						p.bs_count = 1
					else
						p.bs_count = p.bs_count + 1
					end
					if p.dummy_bs_cnt <= p.bs_count then
						local bs_list = p.dummy_bs_list
						if #bs_list > 0 then
							next_joy["P" .. p.control .. " Up"] = false
							next_joy["P" .. p.control .. " Down"] = false
							next_joy[p.block_side] = false
							next_joy[p.front_side] = false
							next_joy["P" .. p.control .. " Button 1"] = true
							next_joy["P" .. p.control .. " Button 2"] = false
							next_joy["P" .. p.control .. " Button 3"] = false
							next_joy["P" .. p.control .. " Button 4"] = false
						end
						p.bs_count = -1
					end
				end
			end
		end

		-- レコード＆リプレイ
		if global.dummy_mode == 5 or global.dummy_mode == 6 then
			global.rec_main(next_joy)
		end

		-- ジョイスティック入力の反映
		for _, joy in ipairs(use_joy) do
			if next_joy[joy.field] ~= nil then
				manager:machine():ioport().ports[joy.port].fields[joy.field]:set_value(next_joy[joy.field] and 1 or 0)
			end
		end
	end

	tra_main.draw = function()
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		local scr = manager:machine().screens[":screen"]
		local ec = scr:frame_number()
		local state_past = ec - global.input_accepted
		local width = scr:width() * scr:xscale()
		local joy_val = get_joy()

		-- メイン処理
		if match_active then
			-- 判定表示（キャラ、飛び道具）
			if global.disp_hitbox then
				for _, p in ipairs(players) do
					for _, box in ipairs(p.hitboxes) do
						if box.flat_throw then
							if box.visible == true and box.type.enabled == true then
								scr:draw_box (box.left , box.top-8 , box.right, box.bottom+8, box.type.fill, box.type.fill)
								scr:draw_line(box.left , box.bottom, box.right, box.bottom  , box.type.outline)
								scr:draw_line(box.left , box.top-8 , box.left , box.bottom+8, box.type.outline)
								scr:draw_line(box.right, box.top-8 , box.right, box.bottom+8, box.type.outline)
							end
						else
							if box.visible == true and box.type.enabled == true then
								scr:draw_box(box.left, box.top, box.right, box.bottom, box.type.fill, box.type.outline)
							end
						end
					end
					for _, fb in pairs(p.fireball) do
						for _, box in ipairs(fb.hitboxes) do
							if box.visible == true and box.type.enabled == true then
								scr:draw_box(box.left, box.top, box.right, box.bottom, box.type.fill, box.type.outline)
							end
						end
					end
				end
			end

			-- コマンド入力とダメージとコンボ表示
			for i, p in ipairs(players) do
				local p1 = i == 1
				local op = players[3-i]

				-- コマンド入力表示
				if p.disp_cmd then
					for k = 1, #p.key_hist do
						draw_cmd(i, k, p.key_frames[k], p.key_hist[k])
					end
					draw_cmd(i, #p.key_hist + 1, 0, "")
				end

				-- コンボ表示などの四角枠
				if p.disp_dmg then
					if p1 then
						scr:draw_box(184+40, 40, 274+40,  63, 0x80404040, 0x80404040)
					else
						scr:draw_box( 45-40, 40, 134-40,  63, 0x80404040, 0x80404040)
					end

					-- コンボ表示
					scr:draw_text(p1 and 228 or  9, 48, "ダメージ:")
					scr:draw_text(p1 and 228 or  9, 55, "コンボ:")
					draw_rtext(   p1 and 281 or 62, 48, op.last_combo_dmg .. "(+" .. op.last_dmg .. ")")
					draw_rtext(   p1 and 281 or 62, 55, op.last_combo)
					scr:draw_text(p1 and 296 or 77, 41, "最大")
					draw_rtext(   p1 and 311 or 92, 48, op.max_dmg)
					draw_rtext(   p1 and 311 or 92, 55, op.max_combo)
				end

				-- BS状態表示
				if p.dummy_bs == true then
					if p1 then
						scr:draw_box(106, 40, 150,  50, 0x80404040, 0x80404040)
					else
						scr:draw_box(169, 40, 213,  50, 0x80404040, 0x80404040)
					end
					scr:draw_text(p1 and 115 or 180, 41, "回ガードでBS")
					draw_rtext(   p1 and 115 or 180, 41, p.dummy_bs_cnt - math.max(p.bs_count, 0))
				end

				-- スタン表示
				if global.disp_stun then
					scr:draw_box(p1 and (138 - p.max_stun) or 180, 29, p1 and 140 or (182 + p.max_stun), 34, 0xDDC0C0C0) -- 枠
					scr:draw_box(p1 and (139 - p.max_stun) or 181, 30, p1 and 139 or (181 + p.max_stun), 33, 0xDD000000) -- 黒背景
					scr:draw_box(p1 and (139 - p.stun)     or 181, 30, p1 and 139 or (181 + p.stun)    , 33, 0xDDFF0000) -- スタン値
				end

				-- 座標表示
				local width = scr:width() * scr:xscale()
				if global.disp_hitbox then
					scr:draw_line(p.hit.pos_x, p.hit.pos_y-global.axis_size, p.hit.pos_x, p.hit.pos_y+global.axis_size, global.axis_color)
					scr:draw_line(p.hit.pos_x-global.axis_size, p.hit.pos_y, p.hit.pos_x+global.axis_size, p.hit.pos_y, global.axis_color)
				end

				--行動IDとフレーム数表示
				if global.disp_frmgap or p.disp_frm then
					local p1 = i == 1
					local row = 1
					local x1 = p1 and 55 or 205
					local prev_name = nil
					local y = 56
					if global.disp_frmgap then
						draw_frame_groups(p.act_frames2, p.act_frames_total, 30, p1 and 64 or 72, 8)
						local j = 0
						for base, _ in pairs(p.fireball_bases) do
							local fb = p.fireball[base]
							if fb.act_frames2 ~= nil then
								-- print(string.format("%x", base) .. " " .. j .. " " .. #fb.act_frames2 ) -- debug
								draw_frame_groups(fb.act_frames2, p.act_frames_total, 30, p1 and 64 or 70, 8)
							end
							j = j + 1
						end
						draw_frame_groups(p.muteki.act_frames2 , p.act_frames_total, 30, p1 and 68 or 76, 3)
						draw_frame_groups(p.frm_gap.act_frames2, p.act_frames_total, 30, p1 and 65 or 73, 3, true)
					end
					if p.disp_frm then
						draw_frames(p.act_frames2, p1 and 160 or 285, true , true, p1 and 40 or 165, 63, 8, 18)
					end
				end
				if global.disp_frmgap then
					--フレーム差表示
					draw_rtext(p1 and 135.5 or 190.5, 34.5,  p.last_frame_gap, shadow_col)
					draw_rtext(p1 and 135   or 190  , 34  ,  p.last_frame_gap)
				end
			end

			-- キャラ間の距離表示
			local abs_space = math.abs(p_space)
			if global.disp_pos then
				draw_rtext(160, 217 - math.floor(get_digit(abs_space)/2), abs_space)
			end

			-- レコーディング状態表示
			if global.dummy_mode == 5 or global.dummy_mode == 6 then
				scr:draw_box (260-25, 208-8, 320-5, 224, 0xBB404040, 0xBB404040)
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
					scr:draw_text(265, 212, frame_to_time(3601-#recording.active_slot.store), 0xFFFF1133)
				elseif global.rec_main == rec_repeat_play then
					-- 自動リプレイまち
					scr:draw_text(265-15, 204, "■ リプレイ中", 0xFFFFFFFF)
					scr:draw_text(265-15, 212, "スタートおしっぱでメニュー", 0xFFFFFFFF)
				elseif global.rec_main == rec_play then
					-- リプレイ中
					scr:draw_text(265-15, 204, "■ リプレイ中", 0xFFFFFFFF)
					scr:draw_text(265-15, 212, "スタートおしっぱでメニュー", 0xFFFFFFFF)
				elseif global.rec_main == rec_play_interval then
					-- リプレイまち
					scr:draw_text(265-15, 204, "■ リプレイ中", 0xFFFFFFFF)
					scr:draw_text(265-15, 212, "スタートおしっぱでメニュー", 0xFFFFFFFF)
				elseif global.rec_main == rec_await_play then
					-- リプレイまち
					scr:draw_text(265-15, 204, "■ スタートでリプレイ", 0xFFFFFFFF)
					scr:draw_text(265-15, 212, "スタートおしっぱでメニュー", 0xFFFFFFFF)
				elseif global.rec_main == rec_fixpos then
					-- 開始位置記憶中
					scr:draw_text(265, 204, "● 位置REC " .. #recording.active_slot.name, 0xFFFF1133)
					scr:draw_text(265-15, 212, "スタートでメニュー", 0xFFFF1133)
				elseif global.rec_main == rec_await_1st_input then
				end
			end
		end

		-- 画面表示
		if global.no_background then
			if pgm:read_u8(0x107BB9) >= 0x05 then
				local match = pgm:read_u8(0x107C22)
				if match == 0x38 then --HUD
					pgm:write_u8(0x107C22, 0x33)
				end
				if match > 0 then --BG layers
					pgm:write_u8(0x107762, 0x00)
					pgm:write_u8(0x107765, 0x01)
				end
				pgm:write_u16(0x401FFE, 0x8F8F)
			end
		end

		for i, p in ipairs(players) do
			local pause = false

			-- 投げ判定が出たらポーズさせる
			for _, box in ipairs(p.hitboxes) do
				if box.type.type == "throw" and global.pausethrow then
					pause = true
					break
				end
			end

			-- ヒット時にポーズさせる
			if p.state ~= 0 and p.state ~= p.old_state and global.pause_hit then
				pause = true
			end

			if pause then
				emu.pause()
				break
			end
		end
	end

	emu.register_start(function() math.randomseed(os.time()) end)

	emu.register_stop(function() end)

	emu.register_menu(function(index, event) return false end, {}, "RB2 Training")

	emu.register_frame(function() end)

	-- メニュー表示
	local menu_max_row = 13
	local menu_nop = function() end
	local menu_to_main = function(cancel)
		local col = tra_menu.pos.col
		local row = tra_menu.pos.row
		local p   = players
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		local scr = manager:machine().screens[":screen"]
		local ec = scr:frame_number()
		global.dummy_mode        = col[ 1]      -- ダミーモード           1
		--                              2          レコード・リプレイ設定 2
		p[1].dummy_act           = col[ 3]      -- 1P アクション          3
		p[2].dummy_act           = col[ 4]      -- 2P アクション          4
		p[1].dummy_gd            = col[ 5]      -- 1P ガード              5
		p[2].dummy_gd            = col[ 6]      -- 2P ガード              6
		global.next_block_grace  = col[ 7] - 1  -- 1ガード持続フレーム数  7
		p[1].dummy_bs            = col[ 8] == 2 -- 1P ブレイクショット    8
		p[2].dummy_bs            = col[ 9] == 2 -- 2P ブレイクショット    9
		p[1].dummy_down          = col[10]      -- 1P やられ時行動       10
		p[2].dummy_down          = col[11]      -- 2P やられ時行動       11
		p[1].fwd_prov            = col[12] == 2 -- 1P 挑発で前進         12
		p[2].fwd_prov            = col[13] == 2 -- 2P 挑発で前進         13

		for _, p in ipairs(players) do
			if p.dummy_gd == 3 then
				p.next_block = false
				-- カウンター初期化
				p.next_block_ec = 75
			elseif p.dummy_gd == 4 then
				p.next_block = true
				-- カウンター初期化
				p.next_block_ec = 75
				p.next_block_grace = global.next_block_grace
			end

			-- ガードカウンター初期化
			p.bs_count = -1
		end

		if global.dummy_mode == 5 then
			-- レコード
			-- 設定でレコーディングに入らずに抜けたとき用にモードを1に戻しておく
			global.dummy_mode = 1
			if not cancel and row == 1 then
				menu_cur = rec_menu
				return
			end
		elseif global.dummy_mode == 6 then
			-- リプレイ
			global.dummy_mode = 1
			play_menu.pos.col[ 8] = recording.do_repeat   and 2 or 1 -- 繰り返し           8
			play_menu.pos.col[ 9] = recording.repeat_interval + 1    -- 繰り返し間隔       9
			play_menu.pos.col[10] = global.await_neutral and 2 or 1  -- 繰り返し開始条件  10
			play_menu.pos.col[11] = global.replay_fix_pos and 2 or 1 -- 開始間合い固定    11
			if not cancel and row == 1 then
				menu_cur = play_menu
				return
			end
		end

		for i, p in ipairs(players) do
			local bs_menu = bs_menus[i][p.char]
			local bs_list = char_bs_list[p.char]
			p.dummy_bs_list = {}
			for j, bs in pairs(bs_list) do
				if bs_menu.pos.col[j+1] == 2 then
					table.insert(p.dummy_bs_list, bs)
				end
			end
			p.dummy_bs_cnt = bs_menu.pos.col[#bs_menu.pos.col]
			p.dummy_bs_chr = p.char
		end
		-- 設定後にメニュー遷移
		for i, p in ipairs(players) do
			if not cancel and row == (7 + i) then
				menu_cur = bs_menus[i][p.char]
				return
			end
		end

		menu_cur = main_menu
	end
	local menu_to_main_cancel = function()
		menu_to_main(true)
	end
	local bar_menu_to_main = function(cancel)
		local col = bar_menu.pos.col
		local row = bar_menu.pos.row
		local p   = players
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		local scr = manager:machine().screens[":screen"]
		local ec = scr:frame_number()
		--                              1                                 1
		p[1].red                 = col[ 2] == 2 -- 1P 体力ゲージ          2
		p[2].red                 = col[ 3] == 2 -- 2P 体力ゲージ          3
		p[1].max                 = col[ 4] == 2 -- 1P POWゲージ           4
		p[2].max                 = col[ 5] == 2 -- 2P POWゲージ           5
		global.disp_stun         = col[ 6] == 2 -- スタン表示             6

		menu_cur = main_menu
	end
	local bar_menu_to_main_cancel = function()
		bar_menu_to_main(true)
	end
	local ex_menu_to_main = function(cancel)
		local col = ex_menu.pos.col
		local row = ex_menu.pos.row
		local p   = players
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		local scr = manager:machine().screens[":screen"]
		local ec = scr:frame_number()
		--                              1                                 1
		global.disp_hitbox       = col[ 2] == 2 -- 判定表示               2
		global.pause_hit         = col[ 3] == 2 -- ヒット時にポーズ       3
		global.pausethrow        = col[ 4] == 2 -- 投げ判定発生時にポーズ 4
		p[1].disp_dmg            = col[ 5] == 2 -- 1P ダメージ表示        5
		p[2].disp_dmg            = col[ 6] == 2 -- 2P ダメージ表示        6
		p[1].disp_cmd            = col[ 7] == 2 -- 1P 入力表示            7
		p[2].disp_cmd            = col[ 8] == 2 -- 2P 入力表示            8
		global.disp_frmgap       = col[ 9] == 2 -- フレーム差表示         9
		p[1].disp_frm            = col[10] == 2 -- 1P フレーム数表示     10
		p[2].disp_frm            = col[11] == 2 -- 2P フレーム数表示     11
		global.disp_pos          = col[12] == 2 -- 1P 2P 距離表示        12
		dip_config.easy_super    = col[13] == 2 -- 簡易超必              13

		for _, p in ipairs(players) do
			local max_life = p.red and 0x60 or 0xC0 -- 赤体力にするかどうか
			pgm:write_u8(p.addr.life, max_life)         -- 体力
			pgm:write_u8(p.addr.stun, p.addr.init_stun) -- スタン値
		end

		menu_cur = main_menu
	end
	local ex_menu_to_main_cancel = function()
		ex_menu_to_main(true)
	end
	local box_type_col_list = { 
		box_type_base.a, box_type_base.t3, box_type_base.pa, box_type_base.t, box_type_base.at, box_type_base.pt,
		box_type_base.p, box_type_base.v1, box_type_base.sv1, box_type_base.v2, box_type_base.sv2, box_type_base.v3,
		box_type_base.v4, box_type_base.v5, box_type_base.v6, box_type_base.x1, box_type_base.x2, box_type_base.x3,
		box_type_base.x4, box_type_base.x5, box_type_base.x6, box_type_base.x7, box_type_base.x8, box_type_base.x9,
		box_type_base.g1, box_type_base.g2, box_type_base.g3, box_type_base.g4, box_type_base.g5, box_type_base.g6,
		box_type_base.g7, box_type_base.g8, box_type_base.g9, box_type_base.g10, box_type_base.g11, box_type_base.g12,
		box_type_base.g13, box_type_base.g14, box_type_base.g15, box_type_base.g16, }
	local col_menu_to_main = function(cancel)
		local col = col_menu.pos.col
		local row = col_menu.pos.row
		local p   = players
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		local scr = manager:machine().screens[":screen"]
		local ec = scr:frame_number()

		for i = 2, #col do
			box_type_col_list[i-1].enabled = col[i] == 2
		end

		menu_cur = main_menu
	end
	local col_menu_to_main_cancel = function()
		col_menu_to_main(true)
	end

	local menu_rec_to_tra = function() menu_cur = tra_menu end
	local exit_menu_to_rec = function(slot_no)
		local col = rec_menu.pos.col
		global.dummy_mode = 5
		global.rec_main = rec_await_no_input
		global.input_accepted = ec
		-- 選択したプレイヤー側の反対側の操作をいじる
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		recording.temp_player = (pgm:read_u8(players[1].addr.reg_pcnt) ~= 0xFF) and 2 or 1
		recording.active_slot = recording.slot[slot_no]
		menu_cur = main_menu
		menu_exit()
	end
	local exit_menu_to_play_common = function()
		local col = play_menu.pos.col
		recording.live_slots = {}
		for i = 2, 6 do
			if col[i] == 2 then
				table.insert(recording.live_slots, i-1)
			end
		end
		recording.do_repeat       = col[ 8] == 2 -- 繰り返し           8
		recording.repeat_interval = col[ 9] - 1  -- 繰り返し間隔       9
		global.await_neutral      = col[10] == 2  -- 繰り返し開始条件  10
		global.replay_fix_pos     = col[11] == 2 -- 開始間合い固定    11
		global.repeat_interval    = recording.repeat_interval
	end
	local exit_menu_to_play = function()
		global.dummy_mode = 6 -- リプレイモードにする
		global.rec_main = rec_await_play
		global.input_accepted = ec
		exit_menu_to_play_common()
		menu_cur = main_menu
		menu_exit()
 	end
	local exit_menu_to_play_cancel = function()
		global.dummy_mode = 6 -- リプレイモードにする
		global.rec_main = rec_await_play
		global.input_accepted = ec
		exit_menu_to_play_common()
		menu_to_tra()
	end
	local exit_menu_to_rec_pos = function()
		global.dummy_mode = 5 -- レコードモードにする
		global.rec_main = rec_fixpos
		global.input_accepted = ec
		-- 選択したプレイヤー側の反対側の操作をいじる
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		recording.temp_player = (pgm:read_u8(players[1].addr.reg_pcnt) ~= 0xFF) and 2 or 1
		exit_menu_to_play_common()
		menu_cur = main_menu
		menu_exit()
	end
	local init_menu_config = function()
		local col = tra_menu.pos.col
		local p = players
		local g = global
		col[ 1] = g.dummy_mode             -- ダミーモード           1
		--   2                                レコード・リプレイ設定 2
		col[ 3] = p[1].dummy_act           -- 1P アクション          3
		col[ 4] = p[2].dummy_act           -- 2P アクション          4
		col[ 5] = p[1].dummy_gd            -- 1P ガード              5
		col[ 6] = p[2].dummy_gd            -- 2P ガード              6
		col[ 7] = g.next_block_grace + 1   -- 1ガード持続フレーム数  7
		col[ 8] = p[1].dummy_bs and 2 or 1 -- 1Pブレイクショット     8
		col[ 9] = p[2].dummy_bs and 2 or 1 -- 2Pブレイクショット     9
		col[10] = p[1].dummy_down          -- 1P やられ時行動       10
		col[11] = p[2].dummy_down          -- 2P やられ時行動       11
		col[12] = p[1].fwd_prov and 2 or 1 -- 1P 挑発で前進         12
		col[13] = p[2].fwd_prov and 2 or 1 -- 2P 挑発で前進         13
	end
	local init_bar_menu_config = function()
		local col = bar_menu.pos.col
		local p = players
		local g = global
		--   1                                                       1
		col[ 2] = p[1].red      and 2 or 1 -- 1P 体力ゲージ          2
		col[ 3] = p[2].red      and 2 or 1 -- 2P 体力ゲージ          3
		col[ 4] = p[1].max      and 2 or 1 -- 1P POWゲージ           4
		col[ 5] = p[2].max      and 2 or 1 -- 2P POWゲージ           5
		col[ 6] = g.disp_stun   and 2 or 1 -- スタンゲージ           6
	end
	local init_ex_menu_config = function()
		local col = ex_menu.pos.col
		local p = players
		local g = global
		--   1                                                       1
		col[ 2] = g.disp_hitbox and 2 or 1 -- 判定表示               2
		col[ 3] = g.pause_hit   and 2 or 1 -- ヒット時にポーズ       3
		col[ 4] = g.pausethrow  and 2 or 1 -- 投げ判定発生時にポーズ 4
		col[ 5] = p[1].disp_dmg and 2 or 1 -- 1P ダメージ表示        5
		col[ 6] = p[2].disp_dmg and 2 or 1 -- 2P ダメージ表示        6
		col[ 7] = p[1].disp_cmd and 2 or 1 -- 1P 入力表示            7
		col[ 8] = p[2].disp_cmd and 2 or 1 -- 2P 入力表示            8
		col[ 9] = g.disp_frmgap and 2 or 1 -- フレーム差表示         9
		col[10] = p[1].disp_frm and 2 or 1 -- 1P フレーム数表示     10
		col[11] = p[2].disp_frm and 2 or 1 -- 2P フレーム数表示     11
		col[12] = g.disp_pos    and 2 or 1 -- 1P 2P 距離表示        12
		col[13] = dip_config.easy_super and 2 or 1 -- 簡易超必      13
	end
	menu_to_tra  = function() menu_cur = tra_menu end
	menu_to_bar  = function() menu_cur = bar_menu end
	menu_to_ex   = function() menu_cur = ex_menu end
	menu_to_col  = function() menu_cur = col_menu end
	menu_exit = function()
		-- Bボタンでトレーニングモードへ切り替え
		main_or_menu_state = tra_main
		cls_joy()
	end
	local menu_player_select = function()
		main_menu.pos.row = 1
		cls_hook()
		goto_player_select()
		cls_joy()
		-- 初期化
		global.dummy_mode = 1
		tra_menu.pos.col[1] = 1
		-- メニューを抜ける
		main_or_menu_state = tra_main
		prev_main_or_menu_state = nil
	end
	local menu_restart_fight = function()
		main_menu.pos.row = 1
		cls_hook()
		restart_fight({
			next_p1       =      main_menu.pos.col[ 7]  , -- 1P セレクト
			next_p2       =      main_menu.pos.col[ 8]  , -- 2P セレクト
			next_p1col    =      main_menu.pos.col[ 9]-1, -- 1P カラー
			next_p2col    =      main_menu.pos.col[10]-1, -- 2P カラー
			next_stage    = stgs[main_menu.pos.col[11]], -- ステージセレクト
			next_bgm      = bgms[main_menu.pos.col[12]].id, -- BGMセレクト
		})
		cls_joy()
		-- 初期化
		global.dummy_mode = 1
		tra_menu.pos.col[1] = 1
		-- メニューを抜ける
		main_or_menu_state = tra_main
	end
	-- 半角スペースで始まっているメニューはラベル行とみなす
	local is_label_line = function(str)
		return str:find('^' .. "  +") ~= nil
	end
	main_menu = {
		list = {
			{ "ダミー設定" },
			{ "ゲージ設定" },
			{ "一般設定" },
			{ "判定個別設定" },
			{ "プレイヤーセレクト画面" },
			{ "                          クイックセレクト" },
			{ "1P セレクト"           , char_names },
			{ "2P セレクト"           , char_names },
			{ "1P カラー"             , { "A", "D" } },
			{ "2P カラー"             , { "A", "D" } },
			{ "ステージセレクト"      , names },
			{ "BGMセレクト"           , bgm_names },
			{ "リスタート" },
		},
		pos = { -- メニュー内の選択位置
			offset = 1,
			row = 1,
			col = {
				0, -- ダミー設定
				0, -- ゲージ設定
				0, -- 一般設定
				0, -- 判定個別設定
				0, -- プレイヤーセレクト画面
				0, -- クイックセレクト
				1, -- 1P セレクト
				1, -- 2P セレクト
				1, -- 1P カラー
				1, -- 2P カラー
				1, -- ステージセレクト
				1, -- BGMセレクト
				0, -- リスタート
			},
		},
		on_a = {
			menu_to_tra, -- ダミー設定
			menu_to_bar, -- ゲージ設定
			menu_to_ex,  -- 一般設定
			menu_to_col, -- 判定個別設定
			menu_player_select, -- プレイヤーセレクト画面
			menu_nop, -- クイックセレクト
			menu_restart_fight, -- 1P セレクト
			menu_restart_fight, -- 2P セレクト
			menu_restart_fight, -- 1P カラー
			menu_restart_fight, -- 2P カラー
			menu_restart_fight, -- ステージセレクト
			menu_restart_fight, -- BGMセレクト
			menu_restart_fight, -- リスタート
		},
		on_b = {
			menu_exit, -- ダミー設定
			menu_exit, -- ゲージ設定
			menu_exit, -- 判定個別設定
			menu_exit, -- プレイヤーセレクト画面
			menu_exit, -- クイックセレクト
			menu_exit, -- 1P セレクト
			menu_exit, -- 2P セレクト
			menu_exit, -- 1P カラー
			menu_exit, -- 2P カラー
			menu_exit, -- ステージセレクト
			menu_exit, -- BGMセレクト
			menu_exit, -- リスタート
		},
	}
	local update_menu_pos = function()
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		-- メニューの更新
		main_menu.pos.col[ 7] = math.min(math.max(pgm:read_u8(0x107BA5)  , 1), #char_names)
		main_menu.pos.col[ 8] = math.min(math.max(pgm:read_u8(0x107BA7)  , 1), #char_names)
		main_menu.pos.col[ 9] = math.min(math.max(pgm:read_u8(0x107BAC)+1, 1), 2)
		main_menu.pos.col[10] = math.min(math.max(pgm:read_u8(0x107BAD)+1, 1), 2)

		local stg1 = pgm:read_u8(0x107BB1)
		local stg2 = pgm:read_u8(0x107BB7)
		local stg3 = pgm:read_u8(0x107BB9) == 1 and 0x01 or 0x0F
		main_menu.pos.col[11] = 1
		for i, data in ipairs(stgs) do
			if data.stg1 == stg1 and data.stg2 == stg2 and data.stg3 == stg3 then
				main_menu.pos.col[11] = i
				break
			end
		end

		main_menu.pos.col[12] = 1
		local bgmid = math.max(pgm:read_u8(0x10A8D5), 1)
		for i, bgm in ipairs(bgms) do
			if bgmid == bgm.id then
				main_menu.pos.col[12] = bgm.name_idx
			end
		end
	end
	-- ブレイクショットメニュー
	bs_menus = {}
	local bs_frms = {}
	for i = 1, 60 do
		table.insert(bs_frms, string.format("%s回ガード後に発動", i))
	end
	local menu_bs_to_tra_menu = function()
		menu_to_tra()
	end
	for i = 1, 2 do
		local pbs = {}
		table.insert(bs_menus, pbs)
		for _, bs_list in pairs(char_bs_list) do
			local list, on_ab, col = {}, {}, {}
			table.insert(list, { "     ONにしたスロットからランダムで発動されます。" })
			table.insert(on_ab, menu_bs_to_tra_menu)
			table.insert(col, 0)
			for _, bs in pairs(bs_list) do
				table.insert(list, { bs.name, { "OFF", "ON", }, })
				table.insert(on_ab, menu_bs_to_tra_menu)
				table.insert(col, 1)
			end
			table.insert(list, { "                   ブレイクショット設定" })
			table.insert(on_ab, menu_bs_to_tra_menu)
			table.insert(col, 0)

			table.insert(list, { "タイミング", bs_frms })
			table.insert(on_ab, menu_bs_to_tra_menu)
			table.insert(col, 1)

			local bs_menu = {
				list = list,
				pos = { -- メニュー内の選択位置
					offset = 1,
					row = 2,
					col = col,
				},
				on_a = on_ab,
				on_b = on_ab,
			}
			table.insert(pbs, bs_menu)
		end
	end
	local gd_frms = {}
	for i = 1, 61 do
		table.insert(gd_frms, string.format("%sF後にガード解除", (i - 1)))
	end
	tra_menu = {
		list = {
			{ "ダミーモード"          , { "プレイヤー vs プレイヤー", "プレイヤー vs CPU", "CPU vs プレイヤー", "1P&2P入れ替え", "レコード", "リプレイ" }, },
			{ "                         ダミー設定" },
			{ "1P アクション"         , { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" }, },
			{ "2P アクション"         , { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" }, },
			{ "1P ガード"             , { "なし", "オート", "1ヒットガード", "1ガード", "常時", "ランダム" }, },
			{ "2P ガード"             , { "なし", "オート", "1ヒットガード", "1ガード", "常時", "ランダム" }, },
			{ "1ガード持続フレーム数" , gd_frms, },
			{ "1P ブレイクショット"   , { "OFF", "ON （Aで選択画面へ）" }, },
			{ "2P ブレイクショット"   , { "OFF", "ON （Aで選択画面へ）" }, },
			{ "1P やられ時行動"       , { "なし", "テクニカルライズ", "グランドスウェー", "起き上がり攻撃", }, },
			{ "2P やられ時行動"       , { "なし", "テクニカルライズ", "グランドスウェー", "起き上がり攻撃", }, },
			{ "1P 挑発で前進"         , { "OFF", "ON" }, },
			{ "2P 挑発で前進"         , { "OFF", "ON" }, },
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
				1, -- 1P ブレイクショット     8
				1, -- 2P ブレイクショット     9
				1, -- 1P やられ時行動        10
				1, -- 2P やられ時行動        11
				1, -- 1P 挑発で前進          12
				1, -- 2P 挑発で前進          13
			},
		},
		on_a = {
			menu_to_main, -- ダミーモード
			menu_to_main, -- －ダミー設定－
			menu_to_main, -- 1P アクション
			menu_to_main, -- 2P アクション
			menu_to_main, -- 1P ガード
			menu_to_main, -- 2P ガード
			menu_to_main, -- 1ガード持続フレーム数
			menu_to_main, -- 1P ブレイクショット
			menu_to_main, -- 2P ブレイクショット
			menu_to_main, -- 1P やられ時行動
			menu_to_main, -- 2P やられ時行動
			menu_to_main, -- 1P 挑発で前進
			menu_to_main, -- 2P 挑発で前進
		},
		on_b = {
			menu_to_main_cancel, -- ダミーモード
			menu_to_main_cancel, -- －ダミー設定－
			menu_to_main_cancel, -- 1P アクション
			menu_to_main_cancel, -- 2P アクション
			menu_to_main_cancel, -- 1P ガード
			menu_to_main_cancel, -- 2P ガード
			menu_to_main_cancel, -- 1ガード持続フレーム数
			menu_to_main_cancel, -- 1P ブレイクショット
			menu_to_main_cancel, -- 2P ブレイクショット
			menu_to_main_cancel, -- 1P やられ時行動
			menu_to_main_cancel, -- 2P やられ時行動
			menu_to_main_cancel, -- 1P 挑発で前進
			menu_to_main_cancel, -- 2P 挑発で前進
		},
	}

	bar_menu = {
		list = {
			{ "                         ゲージ設定" },
			{ "1P 体力ゲージ"         , { "通常", "赤" }, },
			{ "2P 体力ゲージ"         , { "通常", "赤" }, },
			{ "1P POWゲージ"          , { "通常", "無限" }, },
			{ "2P POWゲージ"          , { "通常", "無限" }, },
			{ "スタンゲージ"          , { "OFF", "ON" }, },
		},
		pos = { -- メニュー内の選択位置
			offset = 1,
			row = 2,
			col = {
				0, -- －ゲージ設定－          1
				1, -- 1P 体力ゲージ           2
				1, -- 2P 体力ゲージ           3
				1, -- 1P POWゲージ            4
				1, -- 2P POWゲージ            5
				1, -- スタン表示             12
			},
		},
		on_a = {
			bar_menu_to_main, -- －ゲージ設定－
			bar_menu_to_main, -- 1P 体力ゲージ
			bar_menu_to_main, -- 2P 体力ゲージ
			bar_menu_to_main, -- 1P POWゲージ
			bar_menu_to_main, -- 2P POWゲージ
			bar_menu_to_main, -- スタン表示
		},
		on_b = {
			bar_menu_to_main_cancel, -- －ゲージ設定－
			bar_menu_to_main_cancel, -- 1P 体力ゲージ
			bar_menu_to_main_cancel, -- 2P 体力ゲージ
			bar_menu_to_main_cancel, -- 1P POWゲージ
			bar_menu_to_main_cancel, -- 2P POWゲージ
			bar_menu_to_main_cancel, -- スタン表示
		},
	}

	ex_menu = {
		list = {
			{ "                          一般設定" },
			{ "判定表示"              , { "OFF", "ON" }, },
			{ "ヒット時にポーズ"      , { "OFF", "ON" }, },
			{ "投げ判定発生時にポーズ", { "OFF", "ON" }, },
			{ "1P ダメージ表示"       , { "OFF", "ON" }, },
			{ "2P ダメージ表示"       , { "OFF", "ON" }, },
			{ "1P 入力表示"           , { "OFF", "ON" }, },
			{ "2P 入力表示"           , { "OFF", "ON" }, },
			{ "フレーム差表示"        , { "OFF", "ON" }, },
			{ "1P フレーム数表示"     , { "OFF", "ON" }, },
			{ "2P フレーム数表示"     , { "OFF", "ON" }, },
			{ "1P 2P 距離表示"        , { "OFF", "ON" }, },
			{ "簡易超必"              , { "OFF", "ON" }, },
		},
		pos = { -- メニュー内の選択位置
			offset = 1,
			row = 2,
			col = {
				0, -- －一般設定－            1
				1, -- 判定表示                2
				1, -- ヒット時にポーズ        3
				1, -- 投げ判定ポーズ          4
				1, -- フレーム表示            5
				1, -- 1P ダメージ表示         6
				1, -- 2P ダメージ表示         7
				1, -- 1P 入力表示             8
				1, -- 2P 入力表示             9
				1, -- 1P フレーム数表示      10
				1, -- 2P フレーム数表示      11
				1, -- 1P 2P 距離表示         13
				1, -- 簡易超必               14
			},
		},
		on_a = {
			ex_menu_to_main, -- －一般設定－
			ex_menu_to_main, -- 判定表示
			ex_menu_to_main, -- ヒット時にポーズ
			ex_menu_to_main, -- 投げ判定ポーズ
			ex_menu_to_main, -- 1P ダメージ表示
			ex_menu_to_main, -- 2P ダメージ表示
			ex_menu_to_main, -- 1P 入力表示
			ex_menu_to_main, -- 2P 入力表示
			ex_menu_to_main, -- フレーム差表示
			ex_menu_to_main, -- 1P フレーム数表示
			ex_menu_to_main, -- 2P フレーム数表示
			ex_menu_to_main, -- 1P 2P 距離表示
			ex_menu_to_main, -- 簡易超必
		},
		on_b = {
			ex_menu_to_main_cancel, -- －一般設定－
			ex_menu_to_main_cancel, -- 判定表示
			ex_menu_to_main_cancel, -- ヒット時にポーズ
			ex_menu_to_main_cancel, -- 投げ判定ポーズ
			ex_menu_to_main_cancel, -- フレーム差表示
			ex_menu_to_main_cancel, -- 1P ダメージ表示
			ex_menu_to_main_cancel, -- 2P ダメージ表示
			ex_menu_to_main_cancel, -- 1P 入力表示
			ex_menu_to_main_cancel, -- 2P 入力表示
			ex_menu_to_main_cancel, -- 1P フレーム数表示
			ex_menu_to_main_cancel, -- 2P フレーム数表示
			ex_menu_to_main_cancel, -- 1P 2P 距離表示
			ex_menu_to_main_cancel, -- 簡易超必
		},
	}

	col_menu = {
		list = {},
		pos = { -- メニュー内の選択位置
			offset = 1,
			row = 2,
			col = {},
		},
		on_a = {},
		on_b = {},
	}
	table.insert(col_menu.list, { "                          判定個別設定" })
	table.insert(col_menu.pos.col, 0)
	table.insert(col_menu.on_a, col_menu_to_main)
	table.insert(col_menu.on_b, col_menu_to_main_cancel)
	for _, box in pairs(box_type_col_list) do
		table.insert(col_menu.list, { box.name, { "OFF", "ON", }, { fill = box.fill, outline = box.outline } })
		table.insert(col_menu.pos.col, 2)
		table.insert(col_menu.on_a, col_menu_to_main)
		table.insert(col_menu.on_b, col_menu_to_main_cancel)
	end

	rec_menu = {
		list = {
			{ "            選択したスロットに記憶されます。" },
			{ "スロット1"             , { "Aでレコード開始", }, },
			{ "スロット2"             , { "Aでレコード開始", }, },
			{ "スロット3"             , { "Aでレコード開始", }, },
			{ "スロット4"             , { "Aでレコード開始", }, },
			{ "スロット5"             , { "Aでレコード開始", }, },
		},
		pos = { -- メニュー内の選択位置
			offset = 1,
			row = 2,
			col = {
				0, -- 説明               1
				1, -- スロット1          2
				1, -- スロット2          3
				1, -- スロット3          4
				1, -- スロット4          5
				1, -- スロット5          6
			},
		},
		on_a = {
			menu_rec_to_tra, -- 説明
			function() exit_menu_to_rec(1) end, -- スロット1
			function() exit_menu_to_rec(2) end, -- スロット2
			function() exit_menu_to_rec(3) end, -- スロット3
			function() exit_menu_to_rec(4) end, -- スロット4
			function() exit_menu_to_rec(5) end, -- スロット5
		},
		on_b = {
			menu_rec_to_tra, -- 説明
			menu_to_tra, -- スロット1
			menu_to_tra, -- スロット2
			menu_to_tra, -- スロット3
			menu_to_tra, -- スロット4
			menu_to_tra, -- スロット5
		},
	}
	local play_interval = {}
	for i = 1, 301 do
		table.insert(play_interval, i-1)
	end
	play_menu = {
		list = {
			{ "     ONにしたスロットからランダムでリプレイされます。" },
			{ "スロット1"             , { "OFF", "ON", }, },
			{ "スロット2"             , { "OFF", "ON", }, },
			{ "スロット3"             , { "OFF", "ON", }, },
			{ "スロット4"             , { "OFF", "ON", }, },
			{ "スロット5"             , { "OFF", "ON", }, },
			{ "                        リプレイ設定" },
			{ "繰り返し"              , { "OFF", "ON", }, },
			{ "繰り返し間隔"          , play_interval, },
			{ "繰り返し開始条件"      , { "なし", "両キャラがニュートラル", }, },
			{ "開始間合い固定"        , { "OFF", "ON", }, },
			{ "開始間合い"            , { "Aでレコード開始", }, },
		},
		pos = { -- メニュー内の選択位置
			offset = 1,
			row = 2,
			col = {
				0, -- 説明               1
				2, -- スロット1          2
				2, -- スロット2          3
				2, -- スロット3          4
				2, -- スロット4          5
				2, -- スロット5          6
				0, -- リプレイ設定       7
				1, -- 繰り返し           8
				1, -- 繰り返し間隔       9
				1, -- 繰り返し開始条件   10
				1, -- 開始間合い固定    11
				1, -- 開始間合い        12
			},
		},
		on_a = {
			exit_menu_to_play, -- 説明
			exit_menu_to_play, -- スロット1
			exit_menu_to_play, -- スロット2
			exit_menu_to_play, -- スロット3
			exit_menu_to_play, -- スロット4
			exit_menu_to_play, -- スロット5
			exit_menu_to_play, -- リプレイ設定
			exit_menu_to_play, -- 繰り返し
			exit_menu_to_play, -- 繰り返し間隔
			exit_menu_to_play, -- 繰り返し開始条件
			exit_menu_to_play, -- 開始間合い固定
			exit_menu_to_rec_pos, -- 開始間合い
		},
		on_b = {
			-- TODO キャンセル時にも間合い固定の設定とかが変わるように
			exit_menu_to_play_cancel, -- 説明
			exit_menu_to_play_cancel, -- スロット1
			exit_menu_to_play_cancel, -- スロット2
			exit_menu_to_play_cancel, -- スロット3
			exit_menu_to_play_cancel, -- スロット4
			exit_menu_to_play_cancel, -- スロット5
			exit_menu_to_play_cancel, -- リプレイ設定
			exit_menu_to_play_cancel, -- 繰り返し
			exit_menu_to_play_cancel, -- 繰り返し間隔
			exit_menu_to_play_cancel, -- 開始間合い固定
			exit_menu_to_play_cancel, -- 開始間合い
		},
	}
	init_ex_menu_config()
	init_bar_menu_config()
	init_menu_config()

	menu = {}
	menu.proc = function()
		-- メニュー表示中はDIPかポーズでフリーズさせる
		set_freeze(false)
	end
	menu.draw = function()
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		local scr = manager:machine().screens[":screen"]
		local ec = scr:frame_number()
		local state_past = ec - global.input_accepted
		local width = scr:width() * scr:xscale()
		local height = scr:height() * scr:yscale()

		if not match_active or player_select_active then
			return
		end
		if menu_cur == nil then
			bar_menu_to_main()
			menu_to_main()
		end

		-- 初回のメニュー表示時は状態更新
		if prev_main_or_menu_state ~= menu and main_or_menu_state == menu then
			update_menu_pos()
		end
		-- 前フレームのメニューを更新
		prev_main_or_menu_state = main_or_menu_state

		local joy_val = get_joy()

		if accept_input("Start", joy_val, state_past) then
			-- Menu ON/OFF
			global.input_accepted = ec
		elseif accept_input("Button 1", joy_val, state_past) then
			-- サブメニューへの遷移（あれば）
			menu_cur.on_a[menu_cur.pos.row]()
			global.input_accepted = ec
		elseif accept_input("Button 2", joy_val, state_past) then
			-- メニューから戻る
			menu_cur.on_b[menu_cur.pos.row]()
			global.input_accepted = ec
		elseif accept_input("Up", joy_val, state_past) then
			-- カーソル上移動
			local temp_row = menu_cur.pos.row
			while true do
				temp_row = temp_row-1
				if temp_row <= 0 then
					break
				end
				-- ラベルだけ行の場合はスキップ
				if not is_label_line(menu_cur.list[temp_row][1]) then
					menu_cur.pos.row = temp_row
					break
				end
			end
			if not (menu_cur.pos.offset < menu_cur.pos.row and menu_cur.pos.row < menu_cur.pos.offset + menu_max_row) then
				menu_cur.pos.offset = math.min(menu_cur.pos.offset, menu_cur.pos.row)
			end
			global.input_accepted = ec
		elseif accept_input("Down", joy_val, state_past) then
			-- カーソル下移動
			local temp_row = menu_cur.pos.row
			while true do
				temp_row = temp_row+1
				if temp_row > #menu_cur.list then
					break
				end
				-- ラベルだけ行の場合はスキップ
				if not is_label_line(menu_cur.list[temp_row][1]) then
					menu_cur.pos.row = temp_row
					break
				end
			end
			if not (menu_cur.pos.offset < menu_cur.pos.row and menu_cur.pos.row < menu_cur.pos.offset + menu_max_row) then
				menu_cur.pos.offset = math.max(1, menu_cur.pos.row - menu_max_row)
			end
			global.input_accepted = ec
		elseif accept_input("Left", joy_val, state_past) then
			-- カーソル左移動
			local cols = menu_cur.list[menu_cur.pos.row][2]
			if cols then
				local col_pos = menu_cur.pos.col
				col_pos[menu_cur.pos.row] = col_pos[menu_cur.pos.row] and (col_pos[menu_cur.pos.row]-1) or 1
				if col_pos[menu_cur.pos.row] <= 0 then
					col_pos[menu_cur.pos.row] = 1
				end
			end
			global.input_accepted = ec
		elseif accept_input("Right", joy_val, state_past) then
			-- カーソル右移動
			local cols = menu_cur.list[menu_cur.pos.row][2]
			if cols then
				local col_pos = menu_cur.pos.col
				col_pos[menu_cur.pos.row] = col_pos[menu_cur.pos.row] and (col_pos[menu_cur.pos.row]+1) or 2
				if col_pos[menu_cur.pos.row] > #cols then
					col_pos[menu_cur.pos.row] = #cols
				end
			end
			global.input_accepted = ec
		end

		-- メニュー表示本体
		scr:draw_box (0, 0, width, height, 0xC0000000, 0xC0000000)
		local row_num = 1
		for i = menu_cur.pos.offset, math.min(menu_cur.pos.offset+menu_max_row, #menu_cur.list) do
			row = menu_cur.list[i]
			local y = 48+10*row_num
			local c1, c2, c3, c4
			-- 選択行とそうでない行の色分け判断
			if i == menu_cur.pos.row then
				c1, c2, c3, c4, c5 = 0xFFEE3300, 0xFFDD2200, 0xFFFFFF00, 0xCC000000, 0xAAFFFFFF
			else
				c1, c2, c3, c4, c5 = 0xFFC0C0C0, 0xFFC0C0C0, 0xFF000000, 0x00000000, 0xFF000000
			end
			if is_label_line(row[1]) then
				-- ラベルだけ行
				scr:draw_text(96  , y+1  , row[1], 0xFFFFFFFF)
			else
				-- 通常行 ラベル部分
				scr:draw_box (90  , y+0.5, 230   , y+8.5, c1, c2)
				scr:draw_text(96.5, y+1.5, row[1], c4)
				scr:draw_text(96  , y+1  , row[1], c3)
				if row[2] then
					-- 通常行 オプション部分
					local col_pos_num = menu_cur.pos.col[i] or 1
					if col_pos_num > 0 then
						scr:draw_text(165.5, y+1.5, row[2][col_pos_num], c4)
						scr:draw_text(165  , y+1  , row[2][col_pos_num], c3)
						-- オプション部分の左右移動可否の表示
						if i == menu_cur.pos.row then
							scr:draw_text(160, y+1, "◀", col_pos_num == 1       and c5 or c3)
							scr:draw_text(223, y+1, "▶", col_pos_num == #row[2] and c5 or c3)
						end
					end
				end
				if row[3] and row[3].outline then
					print("col")
					scr:draw_box(200, y+2, 218, y+7, row[3].outline, row[3].outline)
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

	main_or_menu_state = tra_main -- menu or tra_main
	local main_or_menu = function()
		if not manager:machine().devices[":maincpu"] then
			return
		end
		local pgm = manager:machine().devices[":maincpu"].spaces["program"]
		local scr = manager:machine().screens[":screen"]
		local width = scr:width() * scr:xscale()

		-- フレーム更新しているかチェック更新
		local ec = scr:frame_number()
		if mem_last_time == ec then
			return
		end
		mem_last_time = ec

		-- メモリ値の読込と更新
		mem_0x100400  = pgm:read_u8(0x100400)
		mem_0x100500  = pgm:read_u8(0x100500)
		mem_0x100701  = pgm:read_u16(0x100701) -- 22e 22f 対戦中
		mem_0x102557  = pgm:read_u16(0x102557)
		mem_0x1041D2  = pgm:read_u8(0x1041D2)
		mem_0x107C22  = pgm:read_u16(0x107C22) -- 対戦中4400
		mem_0x10B862  = pgm:read_u8(0x10B862) -- 対戦中00
		mem_0x10D4EA  = pgm:read_u8(0x10D4EA)
		mem_0x10FD82  = pgm:read_u8(0x10FD82)
		mem_0x10FDAF  = pgm:read_u8(0x10FDAF)
		mem_0x10FDB6  = pgm:read_u16(0x10FDB6)
		mem_bgm       = math.max(pgm:read_u8(0x10A8D5), 1)
		mem_biostest  = bios_test()
		mem_reg_sts_b = pgm:read_u8(0x380000)
		mem_stage     = pgm:read_u8(0x107BB1)
		mem_stage_tz  = pgm:read_u8(0x107BB7)
		mem_0x10E043  = pgm:read_u8(0x10E043)
		prev_p_space  = (p_space ~= 0) and p_space or prev_p_space
		old_active    = match_active

		-- 対戦中かどうかの判定
		if not mem_biostest
			and active_mem_0x100701[mem_0x100701] ~= nil
			and mem_0x107C22 == 0x4400
			and mem_0x10FDAF == 2
			and (mem_0x10FDB6 == 0x0100 or mem_0x10FDB6 == 0x0101) then
			match_active = true
		else
			match_active = false
		end
		-- プレイヤーセレクト中かどうかの判定
		if not mem_biostest
			and mem_0x100701 == 0x10B
			and (mem_0x107C22 == 0x0000 or mem_0x107C22 == 0x5500)
			and mem_0x10FDAF == 2
			and mem_0x10FDB6 ~= 0
			and mem_0x10E043 == 0 then
			if not player_select_active then
				print("player_select_active = true")
			end
			player_select_active = true
			pgm:write_u8(mem_0x10D4EA, 0x00)
		else
			if player_select_active then
				print("player_select_active = false")
			end
			player_select_active = false -- 状態リセット
			pgm:write_u8(mem_0x10CDD0)
			pgm:write_u32(players[1].addr.select_hook)
			pgm:write_u32(players[2].addr.select_hook)
		end

		--状態チェック用
		local vv = string.format("%x %x %x %x", 
		 mem_0x100701,
		 mem_0x107C22,
		 mem_0x10FDAF,
		 mem_0x10FDB6)
		if not bufuf[vv] and not active_mem_0x100701[mem_0x100701] then
			bufuf[vv] = vv
			print(vv)
		end

		-- ROM部分のメモリエリアへパッチあて
		if mem_biostest then
			pached = false               -- 状態リセット
		elseif not pached then
			--pached = apply_patch_file(pgm, "ps2-p1.pat", true)
			pached = apply_patch_file(pgm, "char1-p1.pat", true)

			-- キャラ選択の時間減らす処理をNOPにする
			pgm:write_direct_u16(0x63336, 0x4E71)
			pgm:write_direct_u16(0x63336, 0x4E71)
			--時間の値にアイコン用のオフセット値を足しむ処理で空表示にする 0632DA: 0640 00EE                addi.w  #$ee, D0
			pgm:write_direct_u16(0x632DC, 0x0DD7)

			-- BSモードの仕込み部分
			-- 実質効いていない避け攻撃ぽいコマンドデータを1発BS用の入れ物に使う
			-- 0xCB243の読込後にD1を技IDに差し替えればA(09)で技が出る。下は例。
			-- bp 03957E,{((A6)==CB244)&&((A4)==100400)&&(maincpu.pb@10048E==2)},{D1=1;g}
			-- bp 03957E,{((A6)==CB244)&&((A4)==100500)&&(maincpu.pb@10058E==2)},{D1=1;g}
			-- 末尾1バイトの20は技のIDになるが、プログラム中で1Eまでの値しか通さないので20だと無害。
			pgm:write_direct_u32(0xCB240, 0xF009FF20)
			pgm:write_direct_u16(0xCB244, 0x0600)
		end

		-- 強制的に家庭用モードに変更
		if not mem_biostest then
			pgm:write_direct_u16(0x10FE32, 0x0000)
		end

		-- デバッグDIP
		local dip1, dip2, dip3 = 0x00, 0x00, 0x00
		if match_active and dip_config.show_hitbox then
			--dip1 = bit32.bor(dip1, 0x40)    --cheat "DIP= 1-7 色々な判定表示"
			dip1 = bit32.bor(dip1, 0x80)    --cheat "DIP= 1-8 当たり判定表示"
		end
		if match_active and dip_config.infinity_life then
			dip1 = bit32.bor(dip1, 0x02)    --cheat "DIP= 1-2 Infinite Energy"
		end
		if match_active and dip_config.easy_super then
			dip2 = bit32.bor(dip2, 0x01)    --Cheat "DIP 2-1 Eeasy Super"
		end
		if dip_config.infinity_time then
			dip2 = bit32.bor(dip2, 0x10)    --cheat "DIP= 2-5 Disable Time Over"
			-- 家庭用オプションの時間無限大設定
			pgm:write_u8(0x10E024, 0x03) -- 1:45 2:60 3:90 4:infinity
			pgm:write_u8(0x107C28, 0xAA) --cheat "Infinite Time"
		else
			pgm:write_u8(0x107C28, dip_config.fix_time)
		end
		if dip_config.stage_select then
			dip1 = bit32.bor(dip1, 0x04)    --cheat "DIP= 1-3 Stage Select Mode"
		end
		if player_select_active and dip_config.alfred then
			dip2 = bit32.bor(dip2, 0x80)    --cheat "DIP= 2-8 Alfred Code (B+C >A)"
		end
		if match_active and dip_config.watch_states then
			dip2 = bit32.bor(dip2, 0x20)    --cheat "DIP= 2-6 Watch States"
		end
		if match_active and dip_config.cpu_cant_move then
			dip3 = bit32.bor(dip3, 0x01)    --cheat "DIP= 3-1 CPU Can't Move"
		end
		pgm:write_u8(0x10E000, dip1)
		pgm:write_u8(0x10E001, dip2)
		pgm:write_u8(0x10E002, dip3)

		if match_active then
			-- 1Pと2Pの操作の設定
			for i, p in ipairs(players) do
				pgm:write_u8(p.addr.control1, i) -- Human 1 or 2, CPU 3
				pgm:write_u8(p.addr.control2, i) -- Human 1 or 2, CPU 3
			end
		end
		if player_select_active then
			--apply_1p2p_active()
			if pgm:read_u8(mem_0x10CDD0) > 12 then
				local addr1 = bit32.band(0xFFFFFF, pgm:read_u32(players[1].addr.select_hook))
				local addr2 = bit32.band(0xFFFFFF, pgm:read_u32(players[2].addr.select_hook))
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

		main_or_menu_state.proc()

		-- メニュー切替のタイミングでフック用に記録した値が状態変更後に謝って読みこまれないように常に初期化する
		cls_hook()
	end

	emu.register_frame_done(function()
		main_or_menu_state.draw()
	end)

	emu.register_periodic(function()
		main_or_menu()
		auto_recovery_debug()
	end)
end

return exports
