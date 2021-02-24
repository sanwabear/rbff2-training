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
require('lfs')

exports.name = "rbff2training"
exports.version = "0.0.1"
exports.description = "RBFF2 Training"
exports.license = "MIT License"
exports.author = { name = "Sanwabear" }

local rbff2 = exports

local main_or_menu_state, prev_main_or_menu_state
local menu_cur, main_menu, tra_menu, rec_menu, play_menu, menu, tra_main, menu_exit, bs_menus, rvs_menus, bar_menu, ex_menu, col_menu, auto_menu

local mem_last_time         = 0      -- 最終読込フレーム(キャッシュ用)
local mem_0x100701          = 0      -- 場面判定用
local mem_0x107C22          = 0      -- 場面判定用
local mem_0x10B862          = 0      -- ガードヒット=FF
local mem_0x10D4EA          = 0      -- 潜在発動時の停止時間
local mem_0x10FD82          = 0      -- console 0x00, mvs 0x01
local mem_0x10FDAF          = 0      -- 場面判定用
local mem_0x10FDB6          = 0      -- P1 P2 開始判定用
local mem_0x10E043          = 0      -- 手動でポーズしたときに00以外になる
local mem_biostest          = false  -- 初期化中のときtrue
local match_active          = false  -- 対戦画面のときtrue
local player_select_active  = false  -- プレイヤー選択画面のときtrue
local mem_0x10CDD0          = 0x10CDD0 -- プレイヤー選択のハック用 
local p_space               = 0      -- 1Pと2Pの間隔
local prev_p_space          = 0      -- 1Pと2Pの間隔(前フレーム)
local stage_base_addr       = 0x100E00
local close_far_offset      = 0x02AE08 -- 近距離技と遠距離技判断用のデータの開始位置
local close_far_offset_d    = 0x02DDAA -- 対ラインの近距離技と遠距離技判断用のデータの開始位置
local offset_pos_x          = 0x20
local offset_pos_z          = 0x24
local offset_pos_y          = 0x28
local screen_left           = 0
local screen_top            = 0
local bios_test             = function()
	local cpu = manager.machine.devices[":maincpu"]
	local pgm = cpu.spaces["program"]
	for _, addr in ipairs({0x100400, 0x100500}) do
		local ram_value = pgm:read_u8(addr)
		for _, test_value in ipairs({0x5555, 0xAAAA, (0xFFFF & addr)}) do
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
	axis_air_color  = 0xFFFF00FF,
	axis_internal_color = 0xFF00FFFF,
	axis_size       = 12,
	axis_size2      = 5,
	no_alpha        = true, --fill = 0x00, outline = 0xFF for all box types
	throwbox_height = 200, --default for ground throws
	no_background   = false,
	no_background_addr = 0x10DDF0,
	no_bars         = false,
	sync_pos_x      = 1, -- 1: OFF, 2:1Pと同期, 3:2Pと同期

	disp_pos        = true, -- 1P 2P 距離表示
	disp_hitbox     = 4, -- 判定表示
	disp_frmgap     = 3, -- フレーム差表示
	pause_hit       = false, -- ヒット時にポーズ
	pausethrow      = false, -- 投げ判定表示時にポーズ

	auto_input      = {
		otg_thw     = false, -- ダウン投げ              2
		otg_atk     = false, -- ダウン攻撃              3
		thw_otg     = false, -- 通常投げの派生技        4
		rave        = 1,     -- デッドリーレイブ        5
		desire      = 1,     -- アンリミテッドデザイア  6
		drill       = 5,     -- ドリル                  7
		pairon      = 1,     -- 超白龍                  8
		real_counter= 1,     -- M.リアルカウンター      9
		-- 入力設定
		esaka_check = false, -- 詠酒距離チェック       11
	},

	frzc            = 1,
	frz             = {0x1, 0x0},  -- DIPによる停止操作用の値とカウンタ

	dummy_mode      = 1,
	rec_main        = nil,

	input_accepted  = 0,

	next_block_grace = 0,     -- 1ガードでの持続フレーム数
	infinity_life2   = true,
	pow_mode         = 2,     -- POWモード　1:自動回復 2:固定 3:通常動作
	repeat_interval  = 0,
	await_neutral    = false,
	replay_fix_pos   = 1,     -- 開始間合い固定 1:OFF 2:1Pと2P 3:1P 4:2P
	replay_reset     = 2,     -- 状態リセット   1:OFF 2:1Pと2P 3:1P 4:2P
	mame_debug_wnd   = false, -- MAMEデバッグウィンドウ表示のときtrue
	damaged_move     = 1,
	disp_replay      = true,  -- レコードリプレイガイド表示

	-- log
	log              = {
		poslog       = false, -- 位置ログ
		atklog       = false, -- 攻撃情報ログ
		baselog      = false, -- フレーム事の処理アドレスログ
		keylog       = false, -- 入力ログ
		rvslog       = true , -- リバサログ
	},
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
local damaged_move_keys = {}
local damaged_move_map = {}
for i = 1, #damaged_moves do
	local k = i == 1 and "通常" or string.format("全て%2s番", i - 2)
	table.insert(damaged_move_keys, k)
	damaged_move_map[k] = damaged_moves[i]
end

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
-- 起き上がりフレーム数
local wakeup_frms = {
	20 --[[ TERRY ]] ,20 --[[ ANDY ]] ,20 --[[ JOE ]], 17 --[[ MAI ]], 20 --[[ GEESE ]], 20 --[[ SOKAKU ]],
	20 --[[ BOB ]] ,20 --[[ HON-FU ]] ,20 --[[ MARY ]] ,20 --[[ BASH ]] ,20 --[[ YAMAZAKI ]] ,20 --[[ CHONSHU ]],
	20 --[[ CHONREI ]] ,20 --[[ DUCK ]] ,20 --[[ KIM ]] ,20 --[[ BILLY ]] ,20 --[[ CHENG ]] ,20 --[[ TUNG ]],
	20 --[[ LAURENCE ]] ,20 --[[ KRAUSER ]] ,20 --[[ RICK ]] ,14 --[[ XIANGFEI ]] ,20 --[[ ALFRED ]]
}

-- 行動の種類
local act_types = { free = -1, attack = 0, low_attack = 1, provoke =  2, any = 3, overhead = 4, guard = 5, hit = 6, }

local char_names = {
	"テリー・ボガード", "アンディ・ボガード", "東丈", "不知火舞", "ギース・ハワード", "望月双角",
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
	{ id = 0x0D, name = "パンドラの箱より 第3番「決断」 ", }, --秦崇雷 崇秀と崇雷が同じBGMなので名前にスペースいれて排他かける
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
for _, bgm in ipairs(bgms) do
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
	{ stg1 = 0x01, stg2 = 0x00, stg3 = 0x01, name = "日本 [1]"          , no_background = false, }, -- 不知火舞
	{ stg1 = 0x01, stg2 = 0x01, stg3 = 0x01, name = "日本 [2]"          , no_background = false, }, -- 望月双角,
	{ stg1 = 0x01, stg2 = 0x01, stg3 = 0x0F, name = "日本 [2] 雨"       , no_background = false, }, -- 望月双角,
	{ stg1 = 0x01, stg2 = 0x02, stg3 = 0x01, name = "日本 [3]"          , no_background = false, }, -- アンディ・ボガード
	{ stg1 = 0x02, stg2 = 0x00, stg3 = 0x01, name = "香港1 [1]"         , no_background = false, }, -- チン・シンザン
	{ stg1 = 0x02, stg2 = 0x01, stg3 = 0x01, name = "香港1 [2]"         , no_background = false, }, -- 山崎竜二
	{ stg1 = 0x03, stg2 = 0x00, stg3 = 0x01, name = "韓国 [1]"          , no_background = false, }, -- キム・カッファン
	{ stg1 = 0x03, stg2 = 0x01, stg3 = 0x01, name = "韓国 [2]"          , no_background = false, }, -- タン・フー・ルー,
	{ stg1 = 0x04, stg2 = 0x00, stg3 = 0x01, name = "サウスタウン [1]"  , no_background = false, }, -- ギース・ハワード
	{ stg1 = 0x04, stg2 = 0x01, stg3 = 0x01, name = "サウスタウン [2]"  , no_background = false, }, -- ビリー・カーン
	{ stg1 = 0x05, stg2 = 0x00, stg3 = 0x01, name = "ドイツ [1]"        , no_background = false, }, -- ヴォルフガング・クラウザー
	{ stg1 = 0x05, stg2 = 0x01, stg3 = 0x01, name = "ドイツ [2]"        , no_background = false, }, -- ローレンス・ブラッド
	{ stg1 = 0x06, stg2 = 0x00, stg3 = 0x01, name = "アメリカ1 [1]"     , no_background = false, }, -- ダック・キング
	{ stg1 = 0x06, stg2 = 0x01, stg3 = 0x01, name = "アメリカ1 [2]"     , no_background = false, }, -- ブルー・マリー
	{ stg1 = 0x07, stg2 = 0x00, stg3 = 0x01, name = "アメリカ2 [1]"     , no_background = false, }, -- テリー・ボガード
	{ stg1 = 0x07, stg2 = 0x01, stg3 = 0x01, name = "アメリカ2 [2]"     , no_background = false, }, -- リック・ストラウド
	{ stg1 = 0x07, stg2 = 0x02, stg3 = 0x01, name = "アメリカ2 [2]"     , no_background = false, }, -- アルフレッド
	{ stg1 = 0x08, stg2 = 0x00, stg3 = 0x01, name = "タイ [1]"          , no_background = false, }, -- ボブ・ウィルソン
	{ stg1 = 0x08, stg2 = 0x01, stg3 = 0x01, name = "タイ [2]"          , no_background = false, }, -- フランコ・バッシュ
	{ stg1 = 0x08, stg2 = 0x02, stg3 = 0x01, name = "タイ [3]"          , no_background = false, }, -- 東丈
	{ stg1 = 0x09, stg2 = 0x00, stg3 = 0x01, name = "香港2 [1]"         , no_background = false, }, -- 秦崇秀
	{ stg1 = 0x09, stg2 = 0x01, stg3 = 0x01, name = "香港2 [2]"         , no_background = false, }, -- 秦崇雷,
	{ stg1 = 0x0A, stg2 = 0x00, stg3 = 0x01, name = "NEW CHALLENGERS[1]", no_background = false, }, -- 李香緋
	{ stg1 = 0x0A, stg2 = 0x01, stg3 = 0x01, name = "NEW CHALLENGERS[2]", no_background = false, }, -- ホンフゥ
	{ stg1 = 0x04, stg2 = 0x01, stg3 = 0x01, name = "背景なし"          , no_background = true , }, -- 背景なし
	{ stg1 = 0x07, stg2 = 0x02, stg3 = 0x01, name = "背景なし(1LINE)"   , no_background = true , }, -- 背景なし(1LINE)
}
local names = {}
for _, stg in ipairs(stgs) do
	table.insert(names, stg.name)
end
local sts_flg_names = {
	"01:J振向",             -- 01
	"02:ダウン",             -- 02
	"03:屈途中",             -- 03
	"04:奥後退",             -- 04
	"05:奥前進",             -- 05
	"06:奥振向",             -- 06
	"07:屈振向",             -- 07
	"08:立振向",             -- 08
	"09:奥後ダッシュ～戻り", -- 09
	"10:奥前ダッシュ～戻り", -- 10
	"11:奥→メイン",         -- 11
	"12:奥立",               -- 12
	"13:メイン→奥移動中",   -- 13
	"14:奥維持",             -- 14
	"15:未確認",             -- 15
	"16:未確認",             -- 16
	"17:着地",               -- 17
	"18:J移行",              -- 18
	"19:後小J",              -- 19
	"20:前小J",              -- 20
	"21:垂小J",              -- 21
	"22:後J",                -- 22
	"23:前J",                -- 23
	"24:垂J",                -- 24
	"25:ダッシュ",           -- 25
	"26:バックステップ",     -- 26
	"27:屈前進",             -- 27
	"28:立途中",             -- 28
	"29:屈",                 -- 29
	"30:後退",               -- 30
	"31:前進",               -- 31
	"32:立",                 -- 32
}
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
		{ name = "パワーウェイブ", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, firing = true, },
		{ name = "ランドウェイブ", type = act_types.low_attack, ids = { 0xA4, 0xA5, 0xA6, }, firing = true, },
		{ name = "ファイヤーキック", type = act_types.low_attack, ids = { 0xB8, 0xB9, 0xBC, 0xBA, 0xBB, }, },
		{ name = "クラックシュート", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, }, },
		{ name = "ライジングタックル", type = act_types.attack, ids = { 0xCC, 0xCD, 0xCE, 0xCF, 0xD0, }, },
		{ name = "パッシングスウェー", type = act_types.attack, ids = { 0xC2, 0xC3, 0xC4, }, },
		{ name = "パワーゲイザー", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, }, firing = true, },
		{ name = "トリプルゲイザー", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x10E, }, firing = true, },
		{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x241, }, },
		{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x242, }, },
		{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x244, }, },
		{ disp_name = "CA _6C", name = "CA 5C(3段目)", type = act_types.attack, ids = { 0x245, }, },
		{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x246, }, },
		{ disp_name = "CA 下C", name = "CA 下C(2段目or3段目)", type = act_types.low_attack, ids = { 0x247, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x240, }, },
		{ disp_name = "CA 下C", name = "CA 下C(2段目)", type = act_types.attack, ids = { 0x243, }, },
		{ disp_name = "パワーチャージ", name = "CA パワーチャージ", type = act_types.attack, ids = { 0x24D, }, },
		{ disp_name = "CA 対スゥエーライン攻撃", name = "CA 立D(2段目)", type = act_types.attack, ids = { 0x24A, }, },
		{ disp_name = "CA 対スゥエーライン攻撃", name = "CA 下D(2段目)", type = act_types.low_attack, ids = { 0x24B, }, },
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
		{ name = "飛翔拳", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, firing = true },
		{ name = "激飛翔拳", type = act_types.attack, ids = { 0xA7, 0xA4, 0xA5, 0xA6, }, firing = true, },
		{ name = "昇龍弾", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, }, },
		{ name = "空破弾", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, 0xBB, }, },
		{ name = "幻影不知火", type = act_types.attack, ids = { 0xC8, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, }, },
		{ name = "超裂破弾", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, }, },
		{ name = "男打弾", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10E, 0x10F, 0x10B, 0x10C, 0x10D, }, firing = true, },
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
		{ name = "夏のおもひで", type = act_types.any, ids = { 0x24E, 0x24F, }, },
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
		{ name = "ハリケーンアッパー", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, }, firing = true, },
		{ name = "爆裂ハリケーン", type = act_types.attack, ids = { 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, }, },
		{ name = "スクリューアッパー", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, }, firing = true, },
		{ disp_name = "サンダーファイヤー", name = "サンダーファイヤー(C)", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x10E, 0x10F, 0x110, 0x111, }, },
		{ disp_name = "サンダーファイヤー", name = "サンダーファイヤー(D)", type = act_types.attack, ids = { 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, }, },
		{ disp_name = "CA 立A", name = "CA 立A(2段目)", type = act_types.attack, ids = { 0x24B, }, },
		{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x42, }, },
		{ disp_name = "CA 立B", name = "CA 遠立B(2段目)", type = act_types.attack, ids = { 0x244, }, },
		{ disp_name = "CA 立C", name = "CA 遠立C(3段目)", type = act_types.attack, ids = { 0x245, }, },
		{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x48, }, },
		{ disp_name = "CA 立A", name = "CA 立A(3段目)", type = act_types.attack, ids = { 0x24C, }, },
		{ disp_name = "CA 立B", name = "CA 立B(3段目)", type = act_types.attack, ids = { 0x45, }, },
		{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x25, }, },
		{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x246, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x240, }, },
		{ disp_name = "CA _8C", name = "CA 8C(3段目)", type = act_types.overhead, ids = { 0x251, 0x252, 0x253, }, },
		{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x46, }, },
		{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x24B, }, },
		{ disp_name = "CA _2_3_6+C", name = "CA 236C(3段目)", type = act_types.attack, ids = { 0x24A, }, },
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
		{ name = "花蝶扇", type = act_types.attack, ids = { 0x86, 0x87, 0x88, }, firing = true, },
		{ name = "龍炎舞", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, firing = true, },
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
		{ disp_name = "立C", name = "立C", type = act_types.low_attack, ids = { 0x46, 0xF4, }, },
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
		{ name = "烈風拳", type = act_types.attack, ids = { 0x86, 0x87, 0x88, }, firing = true, },
		{ name = "ダブル烈風拳", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, firing = true, },
		{ name = "下段当て身打ち", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, }, },
		{ name = "裏雲隠し", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, }, },
		{ name = "上段当て身投げ", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D, }, },
		{ name = "雷鳴豪波投げ", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, }, },
		{ name = "真空投げ", type = act_types.attack, ids = { 0xC2, 0xC3, }, },
		{ name = "レイジングストーム", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, }, firing = true, },
		{ name = "羅生門", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, }, },
		{ name = "デッドリーレイブ", type = act_types.attack, ids = { 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC, }, },
		{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x241, }, },
		{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x242, }, },
		{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x245, }, },
		{ disp_name = "CA 下C", name = "CA 下C(3段目)", type = act_types.low_attack, ids = { 0x247, }, },
		{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x246, }, },
		{ disp_name = "CA 立C", name = "CA 近C(2段目)", type = act_types.attack, ids = { 0x244, }, },
		{ disp_name = "CA 下C", name = "CA 下C(2段目)昇天明星打ちルート", type = act_types.low_attack, ids = { 0x247, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)昇天明星打ちルート", type = act_types.attack, ids = { 0x249, }, },
		{ disp_name = "CA _8C", name = "CA 8C(3段目)昇天明星打ちルート", type = act_types.attack, ids = { 0x24E, 0x24F, 0x250, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)近立Bルート", type = act_types.attack, ids = { 0x24D, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)下Aルート", type = act_types.attack, ids = { 0x240, }, },
		{ disp_name = "CA 下C", name = "CA 下C(2段目)下Aルート", type = act_types.attack, ids = { 0x24B, }, },
		{ disp_name = "CA 対スゥエーライン攻撃", name = "CA 立D(2段目)", type = act_types.attack, ids = { 0x248, }, },
		{ disp_name = "CA 対スゥエーライン攻撃", name = "CA 下D(2段目)", type = act_types.low_attack, ids = { 0x24A, }, },
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
		{ name = "まきびし", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, firing = true, },
		{ name = "憑依弾", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D, }, firing = true, },
		{ name = "鬼門陣", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, }, },
		{ name = "邪棍舞", type = act_types.low_attack, ids = { 0xAE, 0xAF, 0xB0, }, firing = true, },
		{ name = "喝", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, 0xBB, }, firing = true, },
		{ name = "渦炎陣", type = act_types.attack, ids = { 0xC2, 0xC3, 0xC4, 0xC5, }, },
		{ name = "いかづち", type = act_types.attack, ids = { 0xFE, 0xFF, 0x103, 0x100, 0x101, }, firing = true, },
		{ name = "無惨弾", type = act_types.overhead, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x241, }, },
		{ disp_name = "CA 立C", name = "CA 近立C(2段目)", type = act_types.attack, ids = { 0x240, }, },
		{ disp_name = "CA _6C", name = "CA 6C(2段目)", type = act_types.attack, ids = { 0x243, }, },
		{ disp_name = "CA _2_2C", name = "CA 雷撃棍(3段目)", type = act_types.attack, ids = { 0x24B, }, firing = true, },
		{ disp_name = "CA 6B", name = "CA 6B(2段目)", type = act_types.attack, ids = { 0x247, }, },
		{ disp_name = "CA _6_2_3+A", name = "CA 623A(3段目)", type = act_types.attack, ids = { 0x242, }, },
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
		{ name = "デンジャラスウルフ", type = act_types.overhead, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, 0x103, 0x104, }, },
		{ name = "ダンシングバイソン", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, }, },
		{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x243, }, },
		{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x240, }, },
		{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x242, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x245, }, },
		{ disp_name = "CA _6C", name = "CA 6C(3段目)", type = act_types.attack, ids = { 0x247, }, },
		{ disp_name = "CA _8C", name = "CA 8C(3段目)", type = act_types.overhead, ids = { 0x24A, 0x24B, 0x24C, }, },
		{ disp_name = "CA 下B", name = "CA CA 下B(2段目)3Aルート", type = act_types.attack, ids = { 0x249, }, },
		{ disp_name = "CA 下C", name = "CA CA 下C(3段目)3Aルート", type = act_types.low_attack, ids = { 0x248, }, },
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
		{ disp_name = "制空烈火棍", name = "大 制空烈火棍", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9D, }, },
		{ name = "大 制空烈火棍", names = { "大 制空烈火棍", "爆発ゴロー" }, type = act_types.attack, ids = { 0x9C, }, },
		{ name = "電光石火の天", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, }, },
		{ name = "電光石火の地", type = act_types.low_attack, ids = { 0xA4, 0xA5, 0xA6, }, },
		{ name = "電光パチキ", type = act_types.attack, ids = { 0xA7, 0xA8, }, },
		{ name = "炎の種馬", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0, }, },
		{ name = "必勝！逆襲拳", type = act_types.any, ids = { 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xD1 }, },
		{ name = "必勝！逆襲拳-1", names = { "必勝！逆襲拳" }, type = act_types.low_attack, ids = { 0xCA, 0xCC, }, },
		{ name = "必勝！逆襲拳-2", names = { "必勝！逆襲拳" }, type = act_types.overhead, ids = { 0xCD, 0xCE, }, },
		{ name = "必勝！逆襲拳-3", names = { "必勝！逆襲拳" }, type = act_types.attack, ids = { 0xCF, 0xD0, 0xCB, }, },
		{ name = "爆発ゴロー", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, }, firing = true, },
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
		{ name = "M.リアルカウンター", type = act_types.attack, ids = { 0xA4, 0xA5, }, },
		{ name = "CA 投げ移行", names = { "CA 投げ移行", "M.リアルカウンター" }, type = act_types.attack, ids = { 0xA6, }, },
		{ name = "M.リアルカウンター投げ移行", type = act_types.attack, ids = { 0xAC, }, },
		{ disp_name = "ジャーマンスープレックス", name = "M.リアルカウンターA投げ", type = act_types.attack, ids = { 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, }, },
		{ disp_name = "フェイスロック", name = "M.リアルカウンターB投げ", type = act_types.attack, ids = { 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, }, },
		{ disp_name = "投げっぱなしジャーマンスープレックス", name = "M.リアルカウンターC投げ", type = act_types.attack, ids = { 0xE5, 0xE6, 0xE7, }, },
		{ name = "ヤングダイブ", type = act_types.overhead, ids = { 0xEA, 0xEB, 0xEC, 0xED, }, },
		{ name = "リバースキック", type = act_types.overhead, ids = { 0xEE, 0xEF, }, },

		{ name = "M.スパイダー", type = act_types.attack, ids = { 0x8C, 0x86, }, },
		{ name = "デンジャラススパイダー", type = act_types.attack, ids = { 0xF0, }, },
		{ name = "スピンフォール", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, }, },
		{ name = "ダブルスパイダー", names = { "M.スパイダー", "デンジャラススパイダー", "ダブルスパイダー" }, type = act_types.attack, ids = { 0x87, 0x88, 0x89, 0x8A, 0x8B, }, },

		{ name = "M.スナッチャー", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
		{ name = "バーチカルアロー", type = act_types.overhead, ids = { 0xB8, 0xB9, 0xBA, 0xBB, }, },
		{ name = "ダブルスナッチャー", names = { "M.スナッチャー", "ダブルスナッチャー" }, type = act_types.attack, ids = { 0x93, 0x94, 0x95, 0x96, }, },

		{ name = "M.クラブクラッチ", type = act_types.low_attack, ids = { 0x9A, 0x9B, }, },
		{ name = "ストレートスライサー", type = act_types.low_attack, ids = { 0xC2, 0xC3, }, },
		{ name = "ストレートスライサー", names = { "M.クラブクラッチ", "ストレートスライサー" }, type = act_types.low_attack, ids = { 0xC4, 0xC5, }, },
		{ name = "ダブルクラッチ", names = { "M.クラブクラッチ", "ダブルクラッチ" }, type = act_types.attack, ids = { 0x9D, 0x9E, 0x9F, 0xA0, 0xA1, }, },

		{ name = "M.ダイナマイトスウィング", type = act_types.attack, ids = { 0xCC, 0xCD, 0xCE, 0xCF, 0xD0, 0xD1, }, },
		{ name = "M.タイフーン", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, 0x103, 0x104, 0x105, 0x106, 0x107, 0x116, }, },
		{ name = "M.エスカレーション", type = act_types.attack, ids = { 0x10B, }, },
		{ name = "M.トリプルエクスタシー", type = act_types.attack, ids = { 0xD6, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF, }, },
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
		{ name = "ザッパー", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, firing = true, },
		{ name = "ウェービングブロー", type = act_types.attack, ids = { 0x9A, 0x9B, }, },
		{ name = "ガッツダンク", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xAC, }, },
		{ name = "ゴールデンボンバー", type = act_types.attack, ids = { 0xAD, 0xAE, 0xAF, 0xB0, 0xB1, }, },
		{ name = "ファイナルオメガショット", type = act_types.overhead, ids = { 0xFE, 0xFF, 0x100, }, firing = true, },
		{ name = "メガトンスクリュー", type = act_types.attack, ids = { 0xF4, 0xF5, 0xF6, 0xF7, 0xFC, 0xF8, }, },
		{ name = "ハルマゲドンバスター", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, }, },
		{ disp_name = "CA 立A", name = "CA 立A(3段目)", type = act_types.attack, ids = { 0x248, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x247, }, },
		{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x242, }, },
		{ disp_name = "CA 立D", name = "CA 立D(2段目)", type = act_types.attack, ids = { 0x240, }, },
		{ disp_name = "CA 立B", name = "CA 立B(3段目)", type = act_types.low_attack, ids = { 0x246, }, },
		{ disp_name = "CA 下C", name = "CA 下C(3段目)", type = act_types.low_attack, ids = { 0x249, }, },
		{ disp_name = "CA _6C", name = "CA 6C(3段目)", type = act_types.attack, ids = { 0x24A, 0x24B, }, },
		{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.overhead, ids = { 0x24C, }, },
		{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x24D, }, },
	},
	-- 山崎竜二
	{
		{ disp_name = "フェイント", name = "フェイント 裁きの匕首", type = act_types.any, ids = { 0x112, }, },
		{ name = "ブン投げ", type = act_types.any, ids = { 0x6D, 0x6E, }, },
		{ name = "目ツブシ", type = act_types.attack, ids = { 0x68, 0x6C, }, },
		{ name = "カチ上げ", type = act_types.attack, ids = { 0x69, }, },
		{ name = "ブッ刺し", type = act_types.overhead, ids = { 0x6A, }, },
		{ name = "昇天", type = act_types.attack, ids = { 0x6B, }, },
		{ name = "蛇使い・上段", type = act_types.attack, ids = { 0x86, 0x87, 0x88, }, },
		{ name = "蛇だまし・上段", type = act_types.attack, ids = { 0x89, }, },
		{ name = "蛇使い・中段", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
		{ name = "蛇だまし・中段", type = act_types.attack, ids = { 0x93, }, },
		{ name = "蛇使い・下段", type = act_types.low_attack, ids = { 0x9A, 0x9B, 0x9C, }, },
		{ name = "蛇だまし・下段", type = act_types.low_attack, ids = { 0x9D, }, },
		{ name = "大蛇", type = act_types.low_attack, ids = { 0x94, }, },
		{ name = "サドマゾ", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, }, },
		{ name = "裁きの匕首", type = act_types.attack, ids = { 0xC2, 0xC3, 0xC4, 0xC5, }, },
		{ name = "ヤキ入れ", type = act_types.overhead, ids = { 0xAE, 0xAF, 0xB0, 0xB4, }, },
		{ name = "倍返し", type = act_types.attack, ids = { 0xB8, 0xBA, 0xB9, 0xBB, 0xBC, }, firing = true, },
		{ name = "爆弾パチキ", type = act_types.attack, ids = { 0xCC, 0xCD, 0xCE, 0xCF, }, },
		{ name = "トドメ", type = act_types.attack, ids = { 0xD6, 0xDA, 0xD8, 0xDB, 0xD9, 0xD7, }, },
		{ name = "ギロチン", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, 0x103, }, },
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
		{ name = "小 帝王天眼拳", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, firing = true, },
		{ name = "大 帝王天眼拳", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, firing = true, },
		{ name = "小 帝王天耳拳", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, }, },
		{ name = "大 帝王天耳拳", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, }, },
		{ name = "帝王神眼拳（その場）", type = act_types.attack, ids = { 0xC2, 0xC3, }, },
		{ name = "帝王神眼拳（空中）", type = act_types.attack, ids = { 0xCC, 0xCD, 0xCF, }, },
		{ name = "帝王神眼拳（背後）", type = act_types.attack, ids = { 0xD6, 0xD7, }, },
		{ name = "帝王空殺神眼拳", type = act_types.attack, ids = { 0xE0, 0xE1, }, },
		{ name = "竜灯掌", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, }, },
		{ name = "竜灯掌・幻殺", type = act_types.attack, ids = { 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, }, },
		{ name = "帝王漏尽拳", type = act_types.attack, ids = { 0xFE, 0xFF, 0x101, 0x100, }, firing = true, },
		{ name = "帝王空殺漏尽拳", type = act_types.attack, ids = { 0xEA, 0xEB, 0xEC, 0xEE, 0xEF, 0xED, }, firing = true, },
		{ name = "海龍照臨", type = act_types.attack, ids = { 0x108, 0x109, 0x109, 0x10A, 0x10B, }, firing = true, },
		{ name = "立ち", type = act_types.free, ids = { 0x6C, }, },
		{ disp_name = "CA 立A", name = "CA 立A(2段目)", type = act_types.attack, ids = { 0x247, }, },
		{ disp_name = "CA 立B", name = "CA 立B(2段目)", type = act_types.attack, ids = { 0x246, }, },
		{ disp_name = "CA 下B", name = "CA 下B(2段目)", type = act_types.low_attack, ids = { 0x24B, }, },
		{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x240, }, },
		{ disp_name = "CA 下C", name = "CA 下C(3段目)", type = act_types.low_attack, ids = { 0x24C, }, },
		{ disp_name = "CA _6C", name = "CA 6C(3段目)", type = act_types.attack, ids = { 0x242, }, },
		{ disp_name = "CA _3C", name = "CA 3C(3段目)", type = act_types.attack, ids = { 0x241, }, },
		{ disp_name = "龍回頭", name = "CA 下C(2段目) 龍回頭", type = act_types.low_attack, ids = { 0x248, }, },
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
		{ name = "大 帝王天眼拳", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, firing = true, },
		{ name = "小 帝王天眼拳", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, firing = true, },
		{ name = "小 帝王天耳拳", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, }, },
		{ name = "大 帝王天耳拳", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, }, },
		{ name = "帝王漏尽拳", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBB, 0xBA, 0xBC, }, firing = true, },
		{ name = "龍転身（前方）", type = act_types.any, ids = { 0xC2, 0xC3, 0xC4, }, firing = true, },
		{ name = "龍転身（後方）", type = act_types.any, ids = { 0xCC, 0xCD, 0xCE, }, },
		{ name = "帝王宿命拳", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, }, firing = true, },
		{ name = "帝王宿命拳", type = act_types.attack, ids = { 0x101, 0x102, 0x104, 0x105, 0x107, 0x115, 0x116, 0x103, 0x106, }, firing = true, },
		{ name = "帝王龍声拳", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, }, firing = true, },
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
		{ name = "小ヘッドスピンアタック", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, 0x8A, }, },
		{ name = "大ヘッドスピンアタック", type = act_types.attack, ids = { 0x90, 0x91, 0x92, 0x93, 0x95, 0x96, 0x94, }, },
		{ name = "地上振り向き", names = { "小ヘッドスピンアタック", "大ヘッドスピンアタック", "地上振り向き" }, type = act_types.any, ids = { 0x3D, }, },
		{ name = "フライングスピンアタック", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0x9E, }, },
		{ name = "ダンシングダイブ", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, }, },
		{ name = "ブレイクストーム", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, 0xB2, 0xB6, 0xB4, 0xB5, 0xB3, 0xB7, }, },
		{ name = "ダックフェイント・地", type = act_types.any, ids = { 0xC2, 0xC3, 0xC4, }, },
		{ name = "ダックフェイント・空", type = act_types.any, ids = { 0xB8, 0xB9, 0xBA, }, },
		{ name = "クロスヘッドスピン", type = act_types.attack, ids = { 0xD6, 0xD7, 0xD8, 0xD9, }, },
		{ name = "ダイビングパニッシャー", type = act_types.attack, ids = { 0xE0, 0xE1, 0xE2, 0xE3, }, },
		{ name = "ローリングパニッシャー", type = act_types.attack, ids = { 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, }, },
		{ name = "ダンシングキャリバー", type = act_types.low_attack, ids = { 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0x115, }, },
		{ name = "ブレイクハリケーン", type = act_types.low_attack, ids = { 0xEE, 0xEF, 0xF0, 0xF1, 0xF2, 0xF3, 0x116, 0xF4, }, },
		{ name = "ブレイクスパイラル", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x102, }, },
		{ disp_name = "ブレイクスパイラルBR", name = "ブレイクスパイラルBR/クレイジーBR", type = act_types.attack, ids = { 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, }, },
		{ name = "ダックダンス", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x10E, 0x10F, }, },
		{ name = "スーパーポンピングマシーン", type = act_types.low_attack, ids = { 0x77, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F, 0x82, 0x80, 0x81, }, },
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
		{ name = "小 半月斬", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
		{ name = "大 半月斬", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
		{ name = "飛翔脚", type = act_types.low_attack, ids = { 0xA4, 0xA6, 0xA5, 0xA7, }, },
		{ name = "戒脚", type = act_types.attack, ids = {  0xA8, 0xA9, }, },
		{ name = "空砂塵", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, }, },
		{ name = "天昇斬", type = act_types.attack, ids = { 0xB2, 0xB3, }, },
		{ names = { "空砂塵", "天昇斬" }, type = act_types.attack, ids = { 0xB4, }, },
		{ name = "覇気脚", type = act_types.low_attack, ids = { 0xB8, }, },
		{ name = "鳳凰天舞脚", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, 0x103, 0x104, 0x105, 0x106, 0x107, }, },
		{ name = "鳳凰脚", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x10E, 0x10F, 0x110, 0x115, }, },
		{ name = "CA ネリチャギ", type = act_types.overhead, ids = { 0x24A, 0x24B, 0x24C, }, },
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
		{ name = "三節棍中段打ち", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, 0x90, 0x91, 0x92, 0x93, }, firing = true, },
		{ name = "燕落とし", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
		{ name = "火龍追撃棍", type = act_types.attack, ids = { 0xB8, 0xB9, }, },
		{ name = "旋風棍", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, }, },
		{ name = "強襲飛翔棍", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, }, },
		{ name = "超火炎旋風棍", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, }, firing = true, },
		{ name = "紅蓮殺棍", type = act_types.attack, ids = { 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, }, },
		{ name = "サラマンダーストリーム", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, }, firing = true, },
		{ name = "立C", type = act_types.attack, ids = { 0x46, 0x6C, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.low_attack, ids = { 0x241, }, },
		{ disp_name = "CA 立C 2段", name = "CA 立C(2段目)送りルート", type = act_types.low_attack, ids = { 0x242, }, },
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
		{ name = "気雷砲（前方）", type = act_types.attack, ids = { 0x86, 0x87, 0x88, }, firing = true, },
		{ name = "気雷砲（対空）", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, firing = true, },
		{ name = "小 破岩撃", type = act_types.low_attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, }, },
		{ name = "大 破岩撃", type = act_types.low_attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, 0xB2, }, },
		{ name = "超太鼓腹打ち", type = act_types.attack, ids = { 0x9A, 0x9B, }, },
		{ name = "満腹滞空", type = act_types.attack, ids = { 0x9F, 0xA0, }, },
		{ names = { "超太鼓腹打ち", "滞空滞空" }, type = act_types.attack, ids = { 0x9D, 0x9E, 0x9C, }, },
		{ name = "軟体オヤジ", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, 0xBB, }, },
		{ name = "クッサメ砲", type = act_types.attack, ids = { 0xC2, 0xC3, 0xC4, 0xC5, }, },
		{ name = "爆雷砲", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, }, firing = true, },
		{ name = "ホエホエ弾", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x114, 0x115, 0x116, 0x10E, 0x110, 0x10F, }, firing = true, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)近立Aルート", type = act_types.low_attack, ids = { 0x24A, }, },
		{ disp_name = "CA _3C", name = "CA 3C(2段目)近立Aルート", type = act_types.attack, ids = { 0x242, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)立Aルート", type = act_types.attack, ids = { 0x240, }, },
		{ disp_name = "CA _3C", name = "CA 3C(2段目)立Aルート", type = act_types.attack, ids = { 0x249, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)立Cルート", type = act_types.attack, ids = { 0x241, }, },
		{ disp_name = "CA 下C", name = "CA 下C(2段目)ライン攻撃ルート", type = act_types.attack, ids = { 0x246, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)ライン攻撃ルート", type = act_types.attack, ids = { 0x24B, 0x24C, 0x24D, }, },
		{ disp_name = "CA 立C", name = "CA 立C(3段目)ライン攻撃ルート", type = act_types.low_attack, ids = { 0x247, }, },
		{ disp_name = "CA _6_6+B", name = "CA 66B(3段目)ライン攻撃ルート", type = act_types.any, ids = { 0x248, }, },
		{ disp_name = "CA D", name = "CA D(2段目)", type = act_types.overhead, ids = { 0x243, }, },
		{ disp_name = "CA _3C", name = "CA 3C(2段目)6Aルート", type = act_types.any, ids = { 0x244, }, },
		{ disp_name = "CA _1C", name = "CA 1C(2段目)6Aルート", type = act_types.any, ids = { 0x245, }, },
	},
	-- タン・フー・ルー,
	{
		{ disp_name = "フェイント", name = "フェイント 旋風剛拳", type = act_types.any, ids = { 0x112, }, },
		{ name = "裂千掌", type = act_types.any, ids = { 0x6D, 0x6E, }, },
		{ name = "右降龍", type = act_types.attack, ids = { 0x68, }, },
		{ name = "衝波", type = act_types.attack, ids = { 0x86, 0x87, 0x88, }, firing = true, },
		{ name = "小 箭疾歩", type = act_types.attack, ids = { 0x90, 0x91, 0x92, }, },
		{ name = "大 箭疾歩", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
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
		{ name = "小ブラッディスピン", type = act_types.attack, ids = { 0x86, 0x87, 0x88, 0x89, }, },
		{ name = "大ブラッディスピン", type = act_types.attack, ids = { 0x90, 0x91, 0x93, 0x94, 0x92, }, },
		{ names = { "小ブラッディスピン", "大ブラッディスピン", "地上振り向き" }, type = act_types.attack, ids = { 0x3D, }, },
		{ name = "ブラッディサーベル", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, firing = true, },
		{ name = "ブラッディカッター", type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0, 0xB1, 0xB2, }, },
		{ name = "ブラッディミキサー", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, }, firing = true, },
		{ name = "ブラッディフラッシュ", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, }, },
		{ name = "ブラッディシャドー", type = act_types.attack, ids = { 0x108, 0x109, 0x10E, 0x10D, 0x10B, 0x10C, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)", type = act_types.attack, ids = { 0x245, }, },
		{ disp_name = "CA 立C", name = "CA 立C(3段目)", type = act_types.attack, ids = { 0x246, }, },
		{ disp_name = "CA 立D", name = "CA 立D(2段目)", type = act_types.attack, ids = { 0x24C, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)オーレィ", type = act_types.attack, ids = { 0x248, }, },
		{ disp_name = "CA _6_3_2+C", name = "CA 632C(3段目)オーレィ", type = act_types.overhead, ids = { 0x249, 0x24A, 0x24B, }, },
	},
	-- ヴォルフガング・クラウザー
	{
		{ disp_name = "フェイント", name = "フェイント ブリッツボール", type = act_types.any, ids = { 0x112, }, },
		{ disp_name = "フェイント", name = "フェイント カイザーウェイブ", type = act_types.any, ids = { 0x113, }, },
		{ name = "ニースマッシャー", type = act_types.any, ids = { 0x6D, 0x6E, }, },
		{ name = "デスハンマー", type = act_types.overhead, ids = { 0x68, }, },
		{ name = "カイザーボディプレス", type = act_types.attack, ids = { 0x69, 0x72, }, },
		{ name = "ダイビングエルボー", type = act_types.attack, ids = { 0x6A, 0x73, 0x74, 0x75, }, },
		{ disp_name = "ブリッツボール", name = "ブリッツボール・上段", type = act_types.attack, ids = { 0x86, 0x87, 0x88, }, firing = true, },
		{ disp_name = "ブリッツボール", name = "ブリッツボール・下段", type = act_types.low_attack, ids = { 0x90, 0x91, 0x92, }, firing = true, },
		{ name = "レッグトマホーク", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
		{ name = "デンジャラススルー", type = act_types.attack, ids = { 0xAE, 0xAF, }, },
		{ name = "グリフォンアッパー", type = act_types.attack, ids = { 0x248, }, },
		{ name = "リフトアップブロー", type = act_types.attack, ids = { 0xC2, 0xC3, }, },
		{ name = "フェニックススルー", type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6, 0xA7, }, },
		{ name = "カイザークロー", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, }, },
		{ name = "カイザーウェイブ", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, }, firing = true, },
		{ name = "ギガティックサイクロン", names = { "アンリミテッドデザイア", "ギガティックサイクロン", "ジャンプ" }, type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0xC, 0x10C, 0x10D, 0x10C, 0x10E, }, },
		{ name = "アンリミテッドデザイア", type = act_types.attack, ids = { 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)近立Aルート", type = act_types.attack, ids = { 0x240, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)立Aルート", type = act_types.attack, ids = { 0x24E, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)立Bルート", type = act_types.attack, ids = { 0x242, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)下Aルート", type = act_types.attack, ids = { 0x241, }, },
		{ disp_name = "CA 下C", name = "CA 下C(2段目)", type = act_types.low_attack, ids = { 0x244, }, },
		{ disp_name = "CA 立C", name = "CA 立C(2段目)近立Cルート", type = act_types.attack, ids = { 0x243, }, },
		{ disp_name = "CA _2_3_6+C", name = "CA 236C(2段目)近立Cルート", type = act_types.attack, ids = { 0x245, }, },
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
		{ name = "ガイアブレス", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, }, firing = true, },
		{ name = "ハウリング・ブル", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, }, firing = true, },
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
		{ disp_name = "CA _2_2+C", name = "CA 22C(3段目)遠立Bルート", type = act_types.overhead, ids = { 0xE6, 0xE7, }, },
		{ disp_name = "CA _3_3+B", name = "CA 33B(2段目)", type = act_types.overhead, ids = { 0xE0, 0xE1, }, },
		{ disp_name = "CA _4C", name = "CA 4C(2段目)", type = act_types.attack, ids = { 0x249, }, },
	},
	-- 李香緋
	{
		{ disp_name = "フェイント", name = "フェイント 天崩山", type = act_types.any, ids = { 0x113, }, },
		{ disp_name = "フェイント", name = "フェイント 大鉄神", type = act_types.any, ids = { 0x112, }, },
		{ name = "力千後宴", type = act_types.any, ids = { 0x6D, 0x6E, }, },
		{ name = "裡門頂肘", type = act_types.attack, ids = { 0x68, 0x69, 0x6A, }, },
		{ name = "後捜腿", type = act_types.attack, ids = { 0x6B, }, },
		{ name = "小 那夢波", type = act_types.attack, ids = { 0x86, 0x87, 0x88, }, firing = true, },
		{ name = "大 那夢波", type = act_types.attack, ids = { 0x90, 0x91, 0x92, 0x93, }, firing = true, },
		--[[
			0x9E, 0x9F, 閃里肘皇移動
			0xA2, 閃里肘皇スカり
			0xA1, 0xA7, 閃里肘皇ヒット
			0xAD, 閃里肘皇・心砕把スカり
			0xA3, 0xA4, 0xA5, 0xA6, 閃里肘皇・貫空
			0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 閃里肘皇・心砕把
		]]
		{ name = "閃里肘皇", type = act_types.attack, ids = { 0x9E, 0x9F, 0xA2, 0xA1, 0xA7, }, },
		{ name = "閃里肘皇・貫空", type = act_types.attack, ids = { 0xA3, 0xA4, 0xA5, 0xA6, }, },
		{ name = "閃里肘皇・心砕把", type = act_types.attack, ids = { 0xAD, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC, }, },
		{ name = "天崩山", type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D, }, },
		{ name = "詠酒・対ジャンプ攻撃", type = act_types.attack, ids = { 0xB8, }, },
		{ name = "詠酒・対立ち攻撃", type = act_types.attack, ids = { 0xAE, }, },
		{ name = "詠酒・対しゃがみ攻撃", type = act_types.attack, ids = { 0xC2, }, },
		{ name = "大鉄神", type = act_types.attack, ids = { 0xF4, 0xF5, 0xF6, 0xF7, }, },
		{ name = "超白龍", type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, 0x103, }, },
		{ name = "真心牙", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x10E, 0x10F, 0x110, }, firing = true, },
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
		{ disp_name = "CA _6_6+A", name = "CA 66A", type = act_types.attack, ids = { 0x24F, }, },
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
		{ name = "ダイバージェンス", type = act_types.attack, ids = { 0xA4, 0xA5, }, firing = true, },
		{ name = "メーデーメーデー", type = act_types.attack, ids = { 0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xAE, 0xAF, 0xB0, 0xB1, }, },
		{ name = "S.TOL", type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, }, },
		{ name = "ショックストール", type = act_types.attack, ids = { 0x100, 0x101, 0x102, 0x103, 0x104, 0x105, 0xFE, 0xFF, 0x100, 0xF4, 0xF5, 0xF6, 0xF7, }, },
		{ name = "ウェーブライダー", type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, }, },
	},
	{
		-- 共通行動
		{ name = "立ち", type = act_types.free, ids = { 0x1, 0x0, 0x23, 0x22, 0x3C, }, },
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
		{ disp_name = "スゥエー移動", name = "スゥエー移動立ち", type = act_types.any, ids = { 0x26, 0x27, 0x28, }, },
		{ disp_name = "スゥエー移動", name = "スゥエー移動しゃがみ", type = act_types.any, ids = { 0x29, 0x2A, 0x2B, }, },
		{ name = "スゥエー振り向き移動", type = act_types.any, ids = { 0x2BC, 0x2BD, }, },
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
		{ names = { "着地", "やられ", } , type = act_types.any, ids = { 0x9, }, },
		{ names = { "ジャンプ", "アンリミテッドデザイア", "ギガティックサイクロン", }, type = act_types.any, ids = { 
			0xB, 0xC, -- 垂直ジャンプ
			0xD, 0xE, -- 前ジャンプ
			0xF, 0x10, -- 後ジャンプ
			0xB, 0x11, 0x12, -- 垂直小ジャンプ
			0xD, 0x13, 0x14, -- 前小ジャンプ
			0xF, 0x15, 0x16, -- 後小ジャンプ
		}, },
		{ name = "グランドスゥエー", type = act_types.any, ids = { 0x13C, 0x13D, 0x13E, }, },
		{ name = "テクニカルライズ", type = act_types.any, ids = { 0x2CA, 0x2C8, 0x2C9, }, },
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
		{ name = "ジャンプ振り向き", type = act_types.any, ids = { 0x1F, }, },
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
		--{ name = "投げ", type = act_types.any, ids = { 0x6D, 0x6E, }, },
		{ name = "ダウン", type = act_types.any, ids = { 0x18E, 0x192, 0x190, }, },
		{ disp_name = "おきあがり", name = "ダウンおきあがり", type = act_types.any, ids = { 0x193, 0x13B, 0x2C7, }, },
		{ name = "気絶", type = act_types.any, ids = { 0x194, 0x195, }, },
		{ name = "ガード", type = act_types.guard, ids = { 0x117, 0x118, 0x119, 0x11A, 0x11B, 0x11C, 0x11D, 0x11E, 0x11F, 0x120, 0x121, 0x122, 0x123, 0x124, 0x125, 0x126, 0x127, 0x128, 0x129, 0x12A, 0x12B, 0x12C, 0x12C, 0x12D, 0x12E, 0x131, 0x132, 0x133, 0x134, 0x135, 0x136, 0x137, 0x139, }, },
		{ name = "やられ", type = act_types.hit, ids = { 0x13F, 0x140, 0x141, 0x142, 0x143, 0x144, 0x145, 0x146, 0x147, 0x148, 0x149, 0x14A, 0x14B, 0x14C, 0x14C, 0x14D, 0x14E, 0x14F, 0x1E9, 0x239 }, },
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
		{ name = "ハリケーンアッパー", type = act_types.attack, ids = { 0x266, 0x267, 0x269, }, },
		-- { name = "爆裂ハリケーン", type = act_types.attack, ids = {  0x266, 0x267, 0x269, }, },
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
		{ name = "倒破", type = act_types.overhead, ids = { 0xF7, }, },
		{ name = "払破", type = act_types.low_attack, ids = { 0xF8, }, },
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
		{ name = "小 那夢波", type = act_types.attack, ids = { 0x263, }, },
		{ name = "大 那夢波", type = act_types.attack, ids = { 0x268, }, },
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
			if acts.type == act_types.guard or acts.type == act_types.hit then
				-- char_1st_actsには登録しない
			elseif acts.name == "振り向き中" or acts.name == "しゃがみ振り向き中" then
				-- char_1st_actsには登録しない
			elseif acts.names then
				-- char_1st_actsには登録しない
			else
				char_1st_acts[char][id] = i == 1
			end
			char_acts[char][id] = acts
		end
	end
end
local char_fireballs = { }
for char, fireballs_base in pairs(char_fireball_base) do
	char_fireballs [char] = {}
	for _, fireball in pairs(fireballs_base) do
		for _, id in pairs(fireball.ids) do
			char_fireballs[char][id] = fireball
		end
	end
end
local jump_acts = {
	[0x9] = true,
	[0x0B] = true, [0x0C] = true,
	[0x0D] = true, [0x0E] = true,
	[0x0F] = true, [0x10] = true,
	[0x0B] = true, [0x11] = true, [0x12] = true,
	[0x0D] = true, [0x13] = true, [0x14] = true,
	[0x0F] = true, [0x15] = true, [0x16] = true,
}
local wakeup_acts = { [0x193] = true, [0x13B] = true, }
local down_acts = { [0x190] = true,  [0x191] = true, [0x192] = true, [0x18E] = true, }
local get_act_name = function(act_data)
	if act_data then
		return act_data.disp_name or (act_data.names and act_data.names[1] or act_data.name) or act_data.name or ""
	else
		return ""
	end
	---return a.disp_name or ((a.names and #a.names > 0) and a.names[1] or a.name)
end

-- キー入力2
local cmd_neutral = function(p, next_joy)
	next_joy["P" .. p.control .. " Up"] = false
	next_joy["P" .. p.control .. " Down"] = false
	next_joy[p.block_side] = false
	next_joy[p.front_side] = false
	next_joy["P" .. p.control .. " Button 1"] = false
	next_joy["P" .. p.control .. " Button 2"] = false
	next_joy["P" .. p.control .. " Button 3"] = false
	next_joy["P" .. p.control .. " Button 4"] = false
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
		next_joy["P" .. p.control .. " Button 1"] = true
	end,
	_b = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Button 2"] = true
	end,
	_c = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Button 3"] = true
	end,
	_d = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Button 4"] = true
	end,
	_ab = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Button 1"] = true
		next_joy["P" .. p.control .. " Button 2"] = true
	end,
	_bc = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Button 2"] = true
		next_joy["P" .. p.control .. " Button 3"] = true
	end,
	_6a = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.front_side] = true
		next_joy["P" .. p.control .. " Button 1"] = true
	end,
	_3a = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.front_side] = true
		next_joy["P" .. p.control .. " Down"] = true
		next_joy["P" .. p.control .. " Button 1"] = true
	end,
	_2a = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Down"] = true
		next_joy["P" .. p.control .. " Button 1"] = true
	end,
	_4a = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.block_side] = true
		next_joy["P" .. p.control .. " Button 1"] = true
	end,
	_6b = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.front_side] = true
		next_joy["P" .. p.control .. " Button 2"] = true
	end,
	_3b = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.front_side] = true
		next_joy["P" .. p.control .. " Down"] = true
		next_joy["P" .. p.control .. " Button 2"] = true
	end,
	_2b = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Down"] = true
		next_joy["P" .. p.control .. " Button 2"] = true
	end,
	_4b = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.block_side] = true
		next_joy["P" .. p.control .. " Button 2"] = true
	end,
	_6c = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.front_side] = true
		next_joy["P" .. p.control .. " Button 3"] = true
	end,
	_3c = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.front_side] = true
		next_joy["P" .. p.control .. " Down"] = true
		next_joy["P" .. p.control .. " Button 3"] = true
	end,
	_2c = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Down"] = true
		next_joy["P" .. p.control .. " Button 3"] = true
	end,
	_4c = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy[p.block_side] = true
		next_joy["P" .. p.control .. " Button 3"] = true
	end,
	_8d = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Up"] = true
		next_joy["P" .. p.control .. " Button 4"] = true
	end,
	_2d = function(p, next_joy)
		cmd_neutral(p, next_joy)
		next_joy["P" .. p.control .. " Down"] = true
		next_joy["P" .. p.control .. " Button 4"] = true
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
-- コマンドテーブル上の技ID
local common_rvs = {
	{ cmd = cmd_base._a      , bs = false, name = "立A", },
	{ cmd = cmd_base._b      , bs = false, name = "立B", },
	{ cmd = cmd_base._c      , bs = false, name = "立C", },
	{ cmd = cmd_base._d      , bs = false, name = "立D", },
	{ cmd = cmd_base._ab     , bs = false, name = "避け攻撃", },
	{ cmd = cmd_base._6c     , bs = false, name = "投げ", throw = true, },
	{ cmd = cmd_base._2a     , bs = false, name = "下A", },
	{ cmd = cmd_base._2b     , bs = false, name = "下B", },
	{ cmd = cmd_base._2c     , bs = false, name = "下C", },
	{ cmd = cmd_base._2d     , bs = false, name = "下D", },
	{ cmd = cmd_base._8      , bs = false, name = "垂直ジャンプ", },
	{ cmd = cmd_base._9      , bs = false, name = "前ジャンプ", },
	{ cmd = cmd_base._7      , bs = false, name = "後ジャンプ", },
	{ id = 0x1E, ver = 0x0600, bs = false, name = "ダッシュ", },
	{ id = 0x1F, ver = 0x0600, bs = false, name = "飛び退き", },
}
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
		{ id = 0x00, ver = 0x0CFF, bs = false, name = "炎の種馬連打", },
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
		-- { id = 0x00, ver = 0x06FF, bs = false, name = "火炎三節棍中段打ち", },
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
		{ cmd = cmd_base._4b     , bs = false, name = "バックステップキック", },
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

-- エミュレータ本体の入力取得
local joyk = {
	p1 = {
		dn = "P1 Down"       , -- joyk.p1.dn
		lt = "P1 Left"       , -- joyk.p1.lt
		rt = "P1 Right"      , -- joyk.p1.rt
		up = "P1 Up"         , -- joyk.p1.up
		a  = "P1 Button 1"   , -- joyk.p1.a
		b  = "P1 Button 2"   , -- joyk.p1.b
		c  = "P1 Button 3"   , -- joyk.p1.c
		d  = "P1 Button 4"   , -- joyk.p1.d
		st = "1 Player Start", -- joyk.p1.st
	},
	p2 = {
		dn = "P2 Down"        , -- joyk.p2.dn
		lt = "P2 Left"        , -- joyk.p2.lt
		rt = "P2 Right"       , -- joyk.p2.rt
		up = "P2 Up"          , -- joyk.p2.up
		a  = "P2 Button 1"    , -- joyk.p2.a
		b  = "P2 Button 2"    , -- joyk.p2.b
		c  = "P2 Button 3"    , -- joyk.p2.c
		d  = "P2 Button 4"    , -- joyk.p2.d
		st = "2 Players Start", -- joyk.p2.st
	},
}
local use_joy = {
	{ port = ":edge:joy:JOY1" , field = joyk.p1.a , frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1" , field = joyk.p1.b , frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1" , field = joyk.p1.c , frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1" , field = joyk.p1.d , frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1" , field = joyk.p1.dn, frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1" , field = joyk.p1.lt, frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1" , field = joyk.p1.rt, frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY1" , field = joyk.p1.up, frame = 0, prev = 0, player = 1, get = 0, },
	{ port = ":edge:joy:JOY2" , field = joyk.p2.a , frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2" , field = joyk.p2.b , frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2" , field = joyk.p2.c , frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2" , field = joyk.p2.d , frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2" , field = joyk.p2.dn, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2" , field = joyk.p2.lt, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2" , field = joyk.p2.rt, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:JOY2" , field = joyk.p2.up, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:START", field = joyk.p2.st, frame = 0, prev = 0, player = 2, get = 0, },
	{ port = ":edge:joy:START", field = joyk.p1.st, frame = 0, prev = 0, player = 1, get = 0, },
}
local get_joy_base = function(prev, exclude_player)
	local scr = manager.machine.screens:at(1)
	local ec = scr:frame_number()
	local joy_port = {}
	local joy_val = {}
	local prev_joy_val = {}
	for _, joy in ipairs(use_joy) do
		local state = 0
		if not joy_port[joy.port] then
			joy_port[joy.port] = manager.machine.ioport.ports[joy.port]:read()
		end
		local field = manager.machine.ioport.ports[joy.port].fields[joy.field]
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
			--if "P2 Button 1" == joy.field then
			--	print(string.format("%s %s %s %s", global.frame_number, joy.field, joy.prev, joy.frame))
			--end
		end
	end
	return prev and prev_joy_val or joy_val
end
local get_joy = function(exclude_player)
	return get_joy_base(false, exclude_player)
end
local accept_input = function(btn, joy_val, state_past)
	if 12 < state_past then
		local p1 = btn == "Start" and "1 Player Start" or ("P1 " .. btn)
		local p2 = btn == "Start" and "2 Players Start" or ("P2 " .. btn)
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
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
local is_start_a = function(joy_val, state_past)
	if 12 < state_past then
		for i = 1, 2 do
			local st = i == 1 and "1 Player Start" or "2 Players Start"
			local pgm = manager.machine.devices[":maincpu"].spaces["program"]
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
		[joyk.p1.dn] = false, [joyk.p1.a] = false, [joyk.p2.dn] = false, [joyk.p2.a] = false,
		[joyk.p1.lt] = false, [joyk.p1.b] = false, [joyk.p2.lt] = false, [joyk.p2.b] = false,
		[joyk.p1.rt] = false, [joyk.p1.c] = false, [joyk.p2.rt] = false, [joyk.p2.c] = false,
		[joyk.p1.up] = false, [joyk.p1.d] = false, [joyk.p2.up] = false, [joyk.p2.d] = false,
	}
end
-- 入力の1P、2P反転用のテーブル
local rev_joy = {
	[joyk.p1.a ] = joyk.p2.a , [joyk.p2.a ] = joyk.p1.a ,
	[joyk.p1.b ] = joyk.p2.b , [joyk.p2.b ] = joyk.p1.b ,
	[joyk.p1.c ] = joyk.p2.c , [joyk.p2.c ] = joyk.p1.c ,
	[joyk.p1.d ] = joyk.p2.d , [joyk.p2.d ] = joyk.p1.d ,
	[joyk.p1.dn] = joyk.p2.dn, [joyk.p2.dn] = joyk.p1.dn,
	[joyk.p1.lt] = joyk.p2.lt, [joyk.p2.lt] = joyk.p1.lt,
	[joyk.p1.rt] = joyk.p2.rt, [joyk.p2.rt] = joyk.p1.rt,
	[joyk.p1.up] = joyk.p2.up, [joyk.p2.up] = joyk.p1.up,
}
-- 入力から1P、2Pを判定するテーブル
local joy_pside = {
	[joyk.p1.dn] = 1, [joyk.p1.a] = 1, [joyk.p2.dn] = 2, [joyk.p2.a] = 2,
	[joyk.p1.lt] = 1, [joyk.p1.b] = 1, [joyk.p2.lt] = 2, [joyk.p2.b] = 2,
	[joyk.p1.rt] = 1, [joyk.p1.c] = 1, [joyk.p2.rt] = 2, [joyk.p2.c] = 2,
	[joyk.p1.up] = 1, [joyk.p1.d] = 1, [joyk.p2.up] = 2, [joyk.p2.d] = 2,
}
-- 入力の左右反転用のテーブル
local joy_frontback = {
	[joyk.p1.lt] = joyk.p1.rt, [joyk.p2.lt] = joyk.p2.rt,
	[joyk.p1.rt] = joyk.p1.lt, [joyk.p2.rt] = joyk.p2.lt,
}
-- MAMEへの入力の無効化
local cls_joy = function()
	for _, joy in ipairs(use_joy) do
		manager.machine.ioport.ports[joy.port].fields[joy.field]:set_value(0)
	end
end

-- キー入力
local kprops = { "d", "c", "b", "a", "rt", "lt", "dn", "up", "sl", "st", }
local posi_or_pl1 = function(v) return 0 <= v and v + 1 or 1 end
local nega_or_mi1 = function(v) return 0 >= v and v - 1 or -1 end

-- ポーズ
local set_freeze = function(frz_expected)
	local dswport = manager.machine.ioport.ports[":DSW"]
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
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		pgm:write_u8(0x1041D2, frz_expected and 0x00 or 0xFF)
	end
end

-- 当たり判定
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
	a   = { id = 0x00, name = "攻撃",                     enabled = true, type_check = type_ck_atk,  type = "attack", color = 0xFF00FF, fill = 0x40, outline = 0xFF },
	fa  = { id = 0x00, name = "攻撃(嘘)",                 enabled = false, type_check = type_ck_und,  type = "attack", color = 0x00FF00, fill = 0x00, outline = 0xFF },
	da  = { id = 0x00, name = "攻撃(無効)",               enabled = true, type_check = type_ck_und,  type = "attack", color = 0xFF00FF, fill = 0x00, outline = 0xFF },

	aa  = { id = 0x00, name = "攻撃(空中追撃可)",         enabled = true, type_check = type_ck_atk,  type = "attack", color = 0xFF00FF, fill = 0x40, outline = 0xFF },
	faa = { id = 0x00, name = "攻撃(嘘、空中追撃可)",     enabled = false, type_check = type_ck_und,  type = "attack", color = 0x00FF00, fill = 0x00, outline = 0xFF },
	daa = { id = 0x00, name = "攻撃(無効、空中追撃可)",   enabled = true, type_check = type_ck_und,  type = "attack", color = 0xFF00FF, fill = 0x00, outline = 0xFF },

	t3  = { id = 0x00, name = "未使用",                   enabled = true, type_check = type_ck_thw,  type = "throw",  color = 0x8B4513, fill = 0x40, outline = 0xFF },

	pa  = { id = 0x00, name = "飛び道具",                 enabled = true, type_check = type_ck_atk,  type = "attack", color = 0xFF0033, fill = 0x40, outline = 0xFF },
	pfa = { id = 0x00, name = "飛び道具(嘘)",             enabled = true, type_check = type_ck_atk,  type = "attack", color = 0x00FF33, fill = 0x00, outline = 0xFF },
	pda = { id = 0x00, name = "飛び道具(無効)",           enabled = true, type_check = type_ck_atk,  type = "attack", color = 0xFF0033, fill = 0x00, outline = 0xFF },

	paa = { id = 0x00, name = "飛び道具(空中追撃可)",     enabled = true, type_check = type_ck_atk,  type = "attack", color = 0xFF0033, fill = 0x40, outline = 0xFF },
	pfaa= { id = 0x00, name = "飛び道具(嘘、空中追撃可)", enabled = true, type_check = type_ck_atk,  type = "attack", color = 0x00FF33, fill = 0x00, outline = 0xFF },
	pdaa= { id = 0x00, name = "飛び道具(無効、空中追撃可)",enabled = true, type_check = type_ck_atk,  type = "attack", color = 0xFF0033, fill = 0x00, outline = 0xFF },

	t   = { id = 0x00, name = "投げ",                     enabled = true, type_check = type_ck_thw,  type = "throw",  color = 0xFFFF00, fill = 0x40, outline = 0xFF },
	at  = { id = 0x00, name = "必殺技投げ",               enabled = true, type_check = type_ck_thw,  type = "throw",  color = 0xFFFF00, fill = 0x40, outline = 0xFF },
	pt  = { id = 0x00, name = "空中投げ",                 enabled = true, type_check = type_ck_thw,  type = "throw",  color = 0xFFFF00, fill = 0x40, outline = 0xFF },
	p   = { id = 0x01, name = "押し合い",                 enabled = true, type_check = type_ck_push, type = "push",   color = 0xDDDDDD, fill = 0x00, outline = 0xFF },
	v1  = { id = 0x02, name = "食らい1",                  enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x0000FF, fill = 0x40, outline = 0xFF },
	v2  = { id = 0x03, name = "食らい2",                  enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x0000FF, fill = 0x40, outline = 0xFF },
	v3  = { id = 0x04, name = "食らい(ダウン追撃のみ可)", enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x00FFFF, fill = 0x80, outline = 0xFF },
	v4  = { id = 0x05, name = "食らい(空中追撃のみ可)",   enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x00FFFF, fill = 0x80, outline = 0xFF },
	v5  = { id = 0x06, name = "食らい5(未使用?)",         enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x606060, fill = 0x40, outline = 0xFF },
	v6  = { id = 0x07, name = "食らい(対ライン上攻撃)",   enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x00FFFF, fill = 0x80, outline = 0xFF },
	x1  = { id = 0x08, name = "食らい(対ライン下攻撃)",   enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x00FFFF, fill = 0x80, outline = 0xFF },
	x2  = { id = 0x09, name = "用途不明2",                enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
	x3  = { id = 0x0A, name = "用途不明3",                enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF }, -- 1311C
	x4  = { id = 0x0B, name = "用途不明4",                enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
	x5  = { id = 0x0C, name = "用途不明5",                enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
	x6  = { id = 0x0D, name = "用途不明6",                enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
	x7  = { id = 0x0E, name = "用途不明7",                enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
	x8  = { id = 0x0F, name = "用途不明8",                enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
	x9  = { id = 0x10, name = "用途不明9",                enabled = true, type_check = type_ck_und,  type = "unkown", color = 0x00FF00, fill = 0x40, outline = 0xFF },
	g1  = { id = 0x11, name = "立ガード",                 enabled = true, type_check = type_ck_gd,   type = "guard",  color = 0xC0C0C0, fill = 0x40, outline = 0xFF },--rbff2 stand-guard
	g2  = { id = 0x12, name = "下段ガード",               enabled = true, type_check = type_ck_gd,   type = "guard",  color = 0xC0C0C0, fill = 0x40, outline = 0xFF },--rbff2 counch-guard
	g3  = { id = 0x13, name = "空中ガード",               enabled = true, type_check = type_ck_gd,   type = "guard",  color = 0xC0C0C0, fill = 0x40, outline = 0xFF },--rbff2 air-guard
	g4  = { id = 0x14, name = "上段当身投げ",             enabled = true, type_check = type_ck_gd,   type = "atemi",  color = 0xFF7F00, fill = 0x40, outline = 0xFF },--rbff2 j.atemi-nage        012DBC
	g5  = { id = 0x15, name = "裏雲隠し",                 enabled = true, type_check = type_ck_gd,   type = "atemi",  color = 0xFF7F00, fill = 0x40, outline = 0xFF },--rbff2 c.atemi-nage        012DBC
	g6  = { id = 0x16, name = "下段当身打ち",             enabled = true, type_check = type_ck_gd,   type = "atemi",  color = 0xFF7F00, fill = 0x40, outline = 0xFF },--rbff2 g.ateminage         012DBC
	g7  = { id = 0x17, name = "必勝逆襲拳",               enabled = true, type_check = type_ck_gd,   type = "atemi",  color = 0xFF7F00, fill = 0x40, outline = 0xFF },--rbff2 h.gyakushu-kyaku    012DBC
	g8  = { id = 0x18, name = "サドマゾ",                 enabled = true, type_check = type_ck_gd,   type = "atemi",  color = 0xFF7F00, fill = 0x40, outline = 0xFF },--rbff2 sadomazo            012DBC
	g9  = { id = 0x19, name = "倍返し",                   enabled = true, type_check = type_ck_gd,   type = "guard",  color = 0xFF007F, fill = 0x40, outline = 0xFF },--rbff2 bai-gaeshi          012DBC
	g12 = { id = 0x1A, name = "ガード?1",                 enabled = true, type_check = type_ck_und,  type = "guard",  color = 0x006400, fill = 0x40, outline = 0xFF },--?
	g11 = { id = 0x1B, name = "ガード?2",                 enabled = true, type_check = type_ck_und,  type = "guard",  color = 0x006400, fill = 0x40, outline = 0xFF },--?
	g10 = { id = 0x1C, name = "フェニックススルー",       enabled = true, type_check = type_ck_gd,   type = "guard",  color = 0xFF7F00, fill = 0x40, outline = 0xFF },--rbff2 p.throw?            012DBC
	g13 = { id = 0x1D, name = "ガード?4",                 enabled = true, type_check = type_ck_und,  type = "guard",  color = 0x006400, fill = 0x40, outline = 0xFF },--?
	g14 = { id = 0x1E, name = "ガード?5",                 enabled = true, type_check = type_ck_gd,   type = "guard",  color = 0x006400, fill = 0x40, outline = 0xFF },--?
	g15 = { id = 0x1F, name = "ガード?6",                 enabled = true, type_check = type_ck_und,  type = "guard",  color = 0x006400, fill = 0x40, outline = 0xFF },--?
	g16 = { id = 0x20, name = "ガード?7",                 enabled = true, type_check = type_ck_und,  type = "guard",  color = 0x006400, fill = 0x40, outline = 0xFF },--?
	sv1 = { id = 0x02, name = "食らい1(スウェー中)",      enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x7FFF00, fill = 0x40, outline = 0xFF, sway = true },
	sv2 = { id = 0x03, name = "食らい2(スウェー中)",      enabled = true, type_check = type_ck_vuln, type = "vuln",   color = 0x7FFF00, fill = 0x40, outline = 0xFF, sway = true, },
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
	box.fill    = (0xFFFFFFFF & (box.fill    << 24)) + box.color
	box.outline = (0xFFFFFFFF & (box.outline << 24)) + box.color
end

-- ボタンの色テーブル
local convert = require("data/button_char")
local btn_col = { [convert("_A")] = 0xFFCC0000, [convert("_B")] = 0xFFCC8800, [convert("_C")] = 0xFF3333CC, [convert("_D")] = 0xFF336600, }
local text_col, shadow_col = 0xFFFFFFFF, 0xFF000000

local exists = function(name)
	if type(name)~="string" then return false end
	return os.rename(name,name) and true or false
end

local is_file = function(name)
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
	return emu.subst_env(manager.options.entries.homepath:value():match('([^;]+)')) .. '/plugins/' .. exports.name
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
	local scr = manager.machine.screens:at(1)
	scr:draw_text(x - manager.ui:get_string_width(str, scr.xscale * scr.height), y, str, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
end

-- コマンド入力表示
local draw_cmd = function(p, line, frame, str)
	local scr = manager.machine.screens:at(1)
	local cstr = convert(str)

	local p1 = p == 1
	local xx = p1 and 12 or 294   -- 1Pと2Pで左右に表示し分ける
	local yy = (line + 10 - 1) * 8 -- +8はオフセット位置

	if 0 < frame then
		local cframe = 999 < frame and "LOT" or frame
		draw_rtext(p1 and 10.5 or 292.5, yy + 0.5, cframe, shadow_col)
		draw_rtext(p1 and 10   or 292  ,       yy, cframe, text_col)
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
-- 処理アドレス表示
local draw_base = function(p, line, frame, addr, act_name, xmov)
	local scr = manager.machine.screens:at(1)

	local p1 = p == 1
	local xx = p1 and 60 or 195    -- 1Pと2Pで左右に表示し分ける
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
	[0x012C42] = { ["rbff2k"] =   0x28, ["rbff2h"] = 0x00 },
	[0x012C88] = { ["rbff2k"] =   0x28, ["rbff2h"] = 0x00 },
	[0x012D4C] = { ["rbff2k"] =   0x28, ["rbff2h"] = 0x00 }, --p1 push 
	[0x012D92] = { ["rbff2k"] =   0x28, ["rbff2h"] = 0x00 }, --p2 push
	[0x039F2A] = { ["rbff2k"] =   0x0C, ["rbff2h"] = 0x20 }, --special throws
	[0x017300] = { ["rbff2k"] =   0x28, ["rbff2h"] = 0x00 }, --solid shadows
}
local bp_clone = { ["rbff2k"] = -0x104, ["rbff2h"] = 0x20 }
local fix_bp_addr = function(addr)
	local fix1 = bp_clone[emu.romname()] or 0
	local fix2 = bp_offset[addr] and (bp_offset[addr][emu.romname()] or fix1) or fix1
	return addr + fix2
end

-- 削りダメージ補正
local chip_dmg_types = {
	zero = { -- ゼロ
		name = "zero",
		calc = function(pure_dmg)
			return 0
		end,
	},
	rshift4 = { -- 1/16
		name = "1/16",
		calc = function(pure_dmg)
			return math.max(1, 0xFFFF & (pure_dmg >> 4))
		end,
	},
	rshift5 = { -- 1/32
		name = "1/32",
		calc = function(pure_dmg)
			return math.max(1, 0xFFFF & (pure_dmg >> 5))
		end,
	},
}
-- 削りダメージ計算種別 補正処理の分岐先の種類分用意する
local chip_dmg_type_tbl = {
	chip_dmg_types.zero,    --  0 ダメージ無し
	chip_dmg_types.zero,    --  1 ダメージ無し
	chip_dmg_types.rshift4, --  2 1/16
	chip_dmg_types.rshift4, --  3 1/16
	chip_dmg_types.zero,    --  4 ダメージ無し
	chip_dmg_types.zero,    --  5 ダメージ無し
	chip_dmg_types.rshift4, --  6 1/16
	chip_dmg_types.rshift5, --  7 1/32
	chip_dmg_types.rshift5, --  8 1/32
	chip_dmg_types.zero,    --  9 ダメージ無し
	chip_dmg_types.zero,    -- 10 ダメージ無し
	chip_dmg_types.rshift4, -- 11 1/16
	chip_dmg_types.rshift4, -- 12 1/16
	chip_dmg_types.rshift4, -- 13 1/16
	chip_dmg_types.rshift4, -- 14 1/16
	chip_dmg_types.rshift4, -- 15 1/16
	chip_dmg_types.zero,    -- 16 ダメージ無し
}
-- 削りダメージ計算種別取得
local get_chip_dmg_type = function(box)
	local pgm = manager.machine.devices[":maincpu"].spaces["program"]
	local a0 = fix_bp_addr(0x95CCC)
	local d0 = 0xF & pgm:read_u8(a0 + box.id)
	local func = chip_dmg_type_tbl[d0 + 1]
	return func
end
-- ヒット処理の飛び先 家庭用版 0x13120 からのデータテーブル 5種類
local hit_proc_types = {
	none      = nil,    -- 常に判定しない
	same_line = "main", -- 同一ライン同士なら判定する
	diff_line = "sway", -- 異なるライン同士でも判定する
	unknown   = "?",    -- 不明
	air_onry  = "air",  -- 相手が空中にいれば判定する
}
local hit_sub_procs = {
	[0x01311C] = hit_proc_types.none,      -- 常に判定しない
	[0x012FF0] = hit_proc_types.same_line, -- → 013038 同一ライン同士なら判定する
	[0x012FFE] = hit_proc_types.diff_line, -- → 013054 異なるライン同士でも判定する
	[0x01300A] = hit_proc_types.unknown,   -- → 013018 不明
	[0x012FE2] = hit_proc_types.air_onry,  -- → 012ff0 → 013038 相手が空中にいれば判定する
}
-- 判定枠のチェック処理種類
local hit_box_proc = function(id, addr)
	-- 家庭用版 012DBC~012F04のデータ取得処理をベースに判定＆属性チェック
	-- 家庭用版 012F30~012F96のデータ取得処理をベースに判定＆属性チェック
	local pgm = manager.machine.devices[":maincpu"].spaces["program"]
	local d2 = id - 0x20
	if d2 >= 0 then
		d2 = pgm:read_u8(addr + d2)
		d2 = 0xFFFF & (d2 + d2)
		d2 = 0xFFFF & (d2 + d2)
		local a0 = pgm:read_u32(0x13120 + d2)
		--print(string.format(" ext attack %x %x %s", id, addr, hit_sub_procs[a0] or "none"))
		return hit_sub_procs[a0]
	end
	return hit_proc_types.none
end
local hit_box_procs = {
	normal_hit = function(id) return hit_box_proc(id, 0x94D2C) end, -- 012DBC: 012DC8: 通常状態へのヒット判定処理
	down_hit   = function(id) return hit_box_proc(id, 0x94E0C) end, -- 012DE4: 012DF0: ダウン状態へのヒット判定処理
	air_hit    = function(id) return hit_box_proc(id, 0x94EEC) end, -- 012E0E: 012E1A: 空中追撃可能状態へのヒット判定処理
	up_guard   = function(id) return hit_box_proc(id, 0x950AC) end, -- 012EAC: 012EB8: 上段ガード判定処理
	low_guard  = function(id) return hit_box_proc(id, 0x9518C) end, -- 012ED8: 012EE4: 下段ガード判定処理
	air_guard  = function(id) return hit_box_proc(id, 0x9526C) end, -- 012F04: 012F16: 空中ガード判定処理
	sway_up_gd = function(id) return hit_box_proc(id, 0x95A4C) end, -- 012E60: 012E6C: 対ライン上段の謎処理
	sway_low_gd= function(id) return hit_box_proc(id, 0x95B2C) end, -- 012F3A: 012E90: 対ライン下段の謎処理
	j_atm_nage = function(id) return hit_box_proc(id, 0x9534C) end, -- 012F30: 012F82: 上段当身投げの処理
	urakumo    = function(id) return hit_box_proc(id, 0x9542C) end, -- 012F30: 012F82: 裏雲隠しの処理
	g_atm_uchi = function(id) return hit_box_proc(id, 0x9550C) end, -- 012F44: 012F82: 下段当身打ちの処理
	gyakushu   = function(id) return hit_box_proc(id, 0x955EC) end, -- 012F4E: 012F82: 必勝逆襲拳の処理
	sadomazo   = function(id) return hit_box_proc(id, 0x956CC) end, -- 012F58: 012F82: サドマゾの処理
	phx_tw     = function(id) return hit_box_proc(id, 0x9588C) end, -- 012F6C: 012F82: フェニックススルーの処理
	baigaeshi  = function(id) return hit_box_proc(id, 0x957AC) end, -- 012F62: 012F82: 倍返しの処理
	unknown1   = function(id) return hit_box_proc(id, 0x94FCC) end, -- 012E38: 012E44: 不明処理、未使用？
}
local new_hitbox = function(p, id, pos_x, pos_y, top, bottom, left, right, attack_only, is_fireball)
	local box = {id = id}
	box.type = nil
	local atk = false
	local pgm = manager.machine.devices[":maincpu"].spaces["program"]
	if (box.id + 1 > #box_types) then
		atk = true
		local air = hit_box_procs.air_hit(box.id) ~= nil
		if is_fireball and air then
			if p.hit.fake_hit then
				box.type = box_type_base.pfaa -- 飛び道具(空中追撃可、嘘)
			elseif p.hit.harmless then
				box.type = box_type_base.pdaa -- 飛び道具(空中追撃可、無効)
			else
				box.type = box_type_base.paa  -- 飛び道具(空中追撃可)
			end
		elseif is_fireball and not air then
			if p.hit.fake_hit then
				box.type = box_type_base.pfa -- 飛び道具(嘘)
			elseif p.hit.harmless then
				box.type = box_type_base.pda -- 飛び道具(無効)
			else
				box.type = box_type_base.pa  -- 飛び道具
			end
		elseif not is_fireball and air then
			if p.hit.fake_hit then
				box.type = box_type_base.faa -- 攻撃(嘘)
			elseif p.hit.harmless then
				box.type = box_type_base.daa -- 攻撃(無効、空中追撃可)
			else
				box.type = box_type_base.aa  -- 攻撃(空中追撃可)
			end
		else
			if p.hit.fake_hit then
				box.type = box_type_base.fa  -- 攻撃(嘘)
			elseif p.hit.harmless then
				box.type = box_type_base.da  -- 攻撃(無効)
			else
				box.type = box_type_base.a   -- 攻撃(空中追撃可)
			end
		end
		-- ヒット効果
		-- 058232(家庭用版)からの処理
		-- 1004E9のデータ＝5C83Eでセット 技ID
		-- 1004E9のデータ-0x20 + 0x95C0C のデータがヒット効果の元ネタ D0
		-- D0 = 0x9だったら 1005E4 くらった側E4 OR 0x40の結果をセット （7ビット目に1）
		-- D0 = 0xAだったら 1005E4 くらった側E4 OR 0x40の結果をセット （7ビット目に1）
		-- D0 x 4 + 579da
		-- d0 = fix_bp_addr(0x0579DA + d0 * 4) --0x0579DA から4バイトのデータの並びがヒット効果の処理アドレスになる
		box.effect = pgm:read_u8(box.id - 0x20 + fix_bp_addr(0x95BEC))
		-- 削りダメージ計算種別取得 05B2A4 からの処理
		box.chip_dmg_type = get_chip_dmg_type(box)
		-- のけぞり時間取得 05AF7C(家庭用版)からの処理
		local d2 = 0xF & pgm:read_u8(box.id + fix_bp_addr(0x95CCC))
		box.hitstun   = pgm:read_u8(0x16 + 0x2 + fix_bp_addr(0x5AF7C) + d2) + 1 + 3 -- ヒット硬直
		box.blockstun = pgm:read_u8(0x1A + 0x2 + fix_bp_addr(0x5AF88) + d2) + 1 + 2 -- ガード硬直
	else
		box.type = box_types[box.id + 1]
		if p.in_sway_line and sway_box_types[box.id + 1] then
			box.type = sway_box_types[box.id + 1] 
		end
	end
	box.type = box.type or box_type_base.x1
	if (box.type == box_type_base.a or box.type == box_type_base.aa) and
		(is_fireball == true or (p.hit.harmless == false and p.hit.obsl_hit == false)) then
		-- 攻撃中のフラグをたてる
		p.attacking = true
		p.attack_id = id
	end

	pos_y  = pos_y - p.hit.pos_z
	top    = 0xFFFF & (pos_y - (0xFFFFF & ((top    * p.hit.scale) >> 6)))
	bottom = 0xFFFF & (pos_y - (0xFFFFF & ((bottom * p.hit.scale) >> 6)))
	left   = 0xFFFF & (pos_x - (0xFFFFF & ((left   * p.hit.scale) >> 6)) * p.hit.flip_x)
	right  = 0xFFFF & (pos_x - (0xFFFFF & ((right  * p.hit.scale) >> 6)) * p.hit.flip_x)

	box.top , box.bottom = bottom, top
	box.left, box.right  = left, right

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
		if box.top > 224 then
			box.top = 224
		end
	else
		if box.bottom > 224 then
			box.bottom = 0
		end
	end

	-- 座標補正後にキー情報を作成する
	box.key = string.format("%x %x id:%x x1:%x x2:%x y1:%x y2:%x", global.frame_number, p.addr.base, box.id, box.top, box.bottom, box.left, box.right)

	local fb_pos_x, fb_pos_y = pos_x, pos_y
	pos_x              = is_fireball and math.floor(p.parent.pos - screen_left) or pos_x
	pos_y              = is_fireball and math.floor(p.parent.pos_y) or pos_y

	local get_reach = function(pos_x, pos_y)
		local top_reach    = pos_y - math.min(box.top, box.bottom)
		local bottom_reach = pos_y - math.max(box.top, box.bottom)
		local front_reach, back_reach
		if p.hit.flip_x == 1 then
			front_reach = math.max(box.left, box.right) - pos_x
			back_reach  = math.min(box.left, box.right) - pos_x
		else
			front_reach = pos_x - math.min(box.left, box.right)
			back_reach  = pos_x - math.max(box.left, box.right)
		end
		local reach_memo1 = string.format("%3s %3s %3s %3s",
			front_reach,                        -- キャラ本体座標からの前のリーチ
			back_reach,                         -- キャラ本体座標からの後のリーチ
			top_reach,                          -- キャラ本体座標からの上のリーチ
			bottom_reach                        -- キャラ本体座標からの下のリーチ
		)
		local reach_memo = string.format("%3s %2s %3s %3s %s %3s %3s",
			screen_top,
			p.hit.flip_x,                       -- 1:右向き -1:左向き
			pos_x,                              -- X位置
			pos_y,                              -- Y位置
			reach_memo1,                        -- リーチ
			top_reach    + pos_y,               -- 地面からの上のリーチ
			bottom_reach + pos_y                -- 地面からの下のリーチ
		)
		local reach_data = {
			front    = math.floor(front_reach),             -- キャラ本体座標からの前のリーチ
			back     = math.floor(back_reach),              -- キャラ本体座標からの後のリーチ
			top      = math.floor(top_reach),               -- キャラ本体座標からの上のリーチ
			bottom   = math.floor(bottom_reach),            -- キャラ本体座標からの下のリーチ
			top_g    = math.floor(top_reach    + pos_y),    -- 地面からの上のリーチ
			bottom_g = math.floor(bottom_reach + pos_y),    -- 地面からの下のリーチ
		}
		return reach_memo1, reach_memo, reach_data
	end
	local reach_memo1, reach_memo, reach_data = get_reach(pos_x, pos_y)
	box.reach = reach_data
	if is_fireball then
		reach_memo1 = get_reach(fb_pos_x, fb_pos_y)
	end

	p.hit.reach_edge = p.hit.reach_edge or {}
	local reach_edge = p.hit.reach_edge[box.type.type] or {}
	p.hit.reach_edge[box.type.type] = reach_edge
	reach_edge.front    = math.max(box.reach.front   , reach_edge.front    or 0)
	reach_edge.back     = math.min(box.reach.back    , reach_edge.back     or 0)
	reach_edge.top      = math.max(box.reach.top     , reach_edge.top      or 0)
	reach_edge.bottom   = math.min(box.reach.bottom  , reach_edge.bottom   or 0)
	reach_edge.top_g    = math.max(box.reach.top_g   , reach_edge.top_g    or 0)
	reach_edge.bottom_g = math.min(box.reach.bottom_g, reach_edge.bottom_g or 0)

	-- 3 "ON:判定の形毎", 4 "ON:攻撃判定の形毎", 5 "ON:くらい判定の形毎",
	if global.disp_hitbox == 3 or (global.disp_hitbox == 4 and atk) or (global.disp_hitbox == 5 and not atk) then
		if p.reach_tbl[reach_memo1] ~= true then
			p.reach_tbl[reach_memo1] = true
			p.reach_memo = p.reach_memo .. "," .. reach_memo1
		end
	end

	if atk then
		local memo = ""
		memo = memo .. " nml=" .. (hit_box_procs.normal_hit(box.id) or "-")
		memo = memo .. " dwn=" .. (hit_box_procs.down_hit(box.id) or "-")
		memo = memo .. " air=" .. (hit_box_procs.air_hit(box.id) or "-")
		memo = memo .. " ugd=" .. (hit_box_procs.up_guard(box.id) or "-")
		memo = memo .. " lgd=" .. (hit_box_procs.low_guard(box.id) or "-")
		memo = memo .. " agd=" .. (hit_box_procs.air_guard(box.id) or "-")
		memo = memo .. " sugd=".. (hit_box_procs.sway_up_gd(box.id) or "-")
		memo = memo .. " slgd=".. (hit_box_procs.sway_low_gd(box.id) or "-")
		memo = memo .. " jatm=".. (hit_box_procs.j_atm_nage(box.id) or"-")
		memo = memo .. " urkm=".. (hit_box_procs.urakumo(box.id) or"-")
		memo = memo .. " gatm=".. (hit_box_procs.g_atm_uchi(box.id) or"-")
		memo = memo .. " gsyu=".. (hit_box_procs.gyakushu(box.id) or"-")
		memo = memo .. " sdmz=".. (hit_box_procs.sadomazo(box.id) or"-")
		memo = memo .. " phx=" .. (hit_box_procs.phx_tw(box.id) or"-")
		memo = memo .. " bai=" .. (hit_box_procs.baigaeshi(box.id) or"-")
		memo = memo .. " ?1="  .. (hit_box_procs.unknown1(box.id) or "-")
		memo = memo .. " catch="  .. (p.bai_catch == true and "v" or "-")

		-- ログ用
		box.log_txt = string.format(
			"hit %6x %3x %3x %2s %3s %2x %2x %2x %s %s %x %2s %4s %4s %4s %2s %2s/%2s %3s %s %2s %2s %2s %2s %2s %2s %2s %2s %2x %3s "..memo,
			p.addr.base,                        -- 1P:100400 2P:100500 1P弾:100600 2P弾:100700 1P弾:100800 2P弾:100900 1P弾:100A00 2P弾:100B00
			p.act,                              --
			p.acta,                             --
			p.act_count,                        --
			p.act_frame,                        --
			p.act_contact,                      --
			p.attack,                           --
			p.hitstop_id,                       -- ガード硬直のID
			p.gd_strength,                      -- 相手のガード持続の種類
			reach_memo,
			box.id,                             -- 判定のID
			p.hit.harmless  and "hm"   or "",   -- 無害化
			p.hit.fake_hit  and "fake" or "",   -- 嘘判定
			p.hit.obsl_hit  and "obsl" or "",   -- 嘘判定
			p.hit.full_hit  and "full" or "",   -- 最大ヒット
			p.hit.harmless2 and "h2"   or "",   -- 無害化
			p.hit.max_hit_nm,                   -- p.act_frame中の行動最大ヒット 分子
			p.hit.max_hit_dn,                   -- p.act_frame中の行動最大ヒット 分母
			p.pure_dmg,                         -- 補正前攻撃力 %3s
			box.chip_dmg_type.calc(p.pure_dmg), -- 補正前削りダメージ %s
			box.chip_dmg_type.name,             -- 削り補正値 %4s
			p.hitstop,                          -- ヒットストップ %2s
			p.hitstop_gd,                       -- ガード時ヒットストップ %2s
			box.hitstun,                        -- ヒット後硬直F %2s
			box.blockstun,                      -- ガード後硬直F %2s
			box.effect,                         -- ヒット効果 %2s
			p.pure_st,                          -- スタン値 %2s
			p.pure_st_tm,                       -- スタンタイマー %2s
			p.prj_rank,                         -- 飛び道具の強さ
			p.esaka_range or "-"                -- 詠酒範囲
		)
	elseif box.type.type_check == type_ck_gd then
		box.log_txt = string.format("guard %6x %s %x", p.addr.base, reach_memo, box.id)
	end
	if box.log_txt then
		box.log_txt = box.log_txt .. " " .. box.key
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
	local scr = manager.machine.screens:at(1)
	local height = scr.height * scr.yscale
	--print("a", box.opp_id, box.top, box.bottom, p.hit.flip_x)
	p.throwing = true
	box.flat_throw = box.top == nil
	box.top    = box.top or box.pos_y - global.throwbox_height
	box.left   = box.pos_x + (box.left or 0)
	box.right  = box.pos_x + (box.right or 0)
	box.top    = box.top and box.pos_y - box.top --air throw
	box.bottom = box.bottom and (box.pos_y - box.bottom) or height + screen_top - p.hit.pos_z
	box.type   = box.type or box_type_base.t
	box.visible = true
	--print("b", box.opp_id, box.top, box.bottom, p.hit.flip_x)
	return box
end

local get_flip_x = function(p)
	local obj_base = p.addr.base
	local pgm = manager.machine.devices[":maincpu"].spaces["program"]
	local flip_x = pgm:read_i16(obj_base + 0x6A) < 0 and 1 or 0
	flip_x = flip_x ~ (pgm:read_u8(obj_base + 0x71) & 1)
	flip_x = flip_x > 0 and 1 or -1
	return flip_x
end

-- 当たり判定用のキャラ情報更新と判定表示用の情報作成
local update_object = function(p)
	local pgm = manager.machine.devices[":maincpu"].spaces["program"]
	local scr = manager.machine.screens:at(1)
	local height = scr.height * scr.yscale

	local obj_base = p.addr.base

	p.hit.pos_x   = p.pos - screen_left
	if p.min_pos then
		p.hit.min_pos_x = p.min_pos - screen_left
	else
		p.hit.min_pos_x = nil
	end
	if p.max_pos then
		p.hit.max_pos_x = p.max_pos - screen_left
	else
		p.hit.max_pos_x = nil
	end
	p.hit.pos_z   = p.pos_z
	p.hit.old_pos_y = p.hit.pos_y
	p.hit.pos_y   = height - p.pos_y - p.hit.pos_z
	p.hit.pos_y   = screen_top + p.hit.pos_y
	p.hit.on      = pgm:read_u32(obj_base)
	p.hit.flip_x  = get_flip_x(p)
	p.hit.scale   = pgm:read_u8(obj_base + 0x73) + 1
	p.hit.char_id = pgm:read_u16(obj_base + 0x10)
	p.hit.base    = obj_base

	p.attacking   = false
	p.attack_id   = 0
	p.throwing    = false

	-- ヒットするかどうか
	p.hit.harmless = p.obsl_hit or p.full_hit or p.harmless2
	p.hit.fake_hit = p.fake_hit
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
	local uniq_hitboxes = {}
	for _, box in ipairs(p.buffer) do
		local hitbox = new_hitbox(p, box.id, box.pos_x, box.pos_y, box.top, box.bottom, box.left, box.right, box.attack_only, box.is_fireball)
		if hitbox then
			if not uniq_hitboxes[hitbox.key] then
				uniq_hitboxes[hitbox.key] = true
				table.insert(p.hitboxes, hitbox)
				-- 攻撃情報ログ
				if global.log.atklog then
					if hitbox.log_txt then
						print(hitbox.log_txt)
					end
				end
			else
				--print("DROP " .. box.key) --debug
			end
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

local dummy_gd_type = {
	none   = 1, -- なし
	auto   = 2, -- オート
	bs     = 3, -- ブレイクショット
	hit1   = 4, -- 1ヒットガード
	guard1 = 5, -- 1ガード
	fixed  = 6, -- 常時
	random = 7, -- ランダム
}
local wakeup_type = {
	none = 1, -- なし
	rvs  = 2, -- リバーサル
	tech = 3, -- テクニカルライズ
	sway = 4, -- グランドスウェー
	atk  = 5, -- 起き上がり攻撃
}

function rbff2.startplugin()
	-- プレイヤーの状態など
	local players = {}
	for p = 1, 2 do
		local p1 = (p == 1)
		players[p] = {
			base             = 0x0,
			bases            = {},

			dummy_act        = 1,           -- 立ち, しゃがみ, ジャンプ, 小ジャンプ, スウェー待機
			dummy_gd         = dummy_gd_type.none, -- なし, オート, ブレイクショット, 1ヒットガード, 1ガード, 常時, ランダム
			dummy_wakeup     = wakeup_type.none,  -- なし, リバーサル, テクニカルライズ, グランドスウェー, 起き上がり攻撃

			dummy_bs         = nil,         -- ランダムで選択されたブレイクショット
			dummy_bs_list    = {},          -- ブレイクショットのコマンドテーブル上の技ID
			dummy_bs_cnt     = 1,           -- ブレイクショットのカウンタ
			dummy_bs_chr     = 0,           -- ブレイクショットの設定をした時のキャラID
			bs_count         = -1,          -- ブレイクショットの実施カウント

			dummy_rvs        = nil,         -- ランダムで選択されたリバーサル
			dummy_rvs_list   = {},          -- リバーサルのコマンドテーブル上の技ID
			dummy_rvs_cnt    = 1,           -- リバーサルのカウンタ
			dummy_rvs_chr    = 0,           -- リバーサルの設定をした時のキャラID
			rvs_count        = -1,          -- リバーサルの実施カウント

			life_rec         = true,        -- 自動で体力回復させるときtrue
			red              = 2,           -- 体力設定     	--"最大", "赤", "ゼロ" ...
			max              = 1,           -- パワー設定       --"最大", "半分", "ゼロ" ...
			disp_base        = false,       -- 処理のアドレスを表示するときtrue
			disp_dmg         = true,        -- ダメージ表示するときtrue
			disp_cmd         = true,        -- 入力表示するときtrue
			disp_frm         = true,        -- フレーム数表示するときtrue
			disp_stun        = true,        -- スタン表示
			disp_sts         = true,        -- 状態表示

			no_hit           = 0,           -- Nヒット目に空ぶるカウントのカウンタ
			no_hit_limit     = 0,           -- Nヒット目に空ぶるカウントの上限

			combo            = 0,           -- 最近のコンボ数
			last_combo       = 0,
			last_dmg         = 0,           -- ダメージ
			last_pow         = 0,           -- POWゲージ増加量
			tmp_pow          = 0,           -- POWゲージ増加量
			tmp_pow_rsv      = 0,           -- POWゲージ増加量(予約値)
			tmp_pow_atc      = 0,           -- POWゲージ増加量(予約時の行動)
			tmp_stun         = 0,
			tmp_st_timer     = 0,
			dmg_scaling      = 1,
			dmg_scl7         = 0,
			dmg_scl6         = 0,
			dmg_scl5         = 0,
			dmg_scl4         = 0,
			last_pure_dmg    = 0,
			last_stun        = 0,
			last_st_timer    = 0,
			last_normal_state = true,
			last_effects     = {},
			life             = 0,           -- いまの体力
			max_combo        = 0,           -- 最大コンボ数
			max_dmg          = 0,
			max_combo_pow    = 0,
			max_disp_stun    = 0,
			max_st_timer     = 0,
			mv_state         = 0,           -- 動作
			old_combo        = 0,           -- 前フレームのコンボ数
			last_combo_dmg   = 0,
			last_combo_pow   = 0,
			last_dmg_scaling = 1,
			last_combo_stun  = 0,
			last_combo_st_timer = 0,
			old_state        = 0,           -- 前フレームのやられ状態
			char             = 0,
			close_far        = {
				a = { x1 = 0, x2 = 0 },
				b = { x1 = 0, x2 = 0 },
				c = { x1 = 0, x2 = 0 },
				d = { x1 = 0, x2 = 0 },
			},
			close_far_lma    = {
				["1"] = { x1 = 0, x2 = 0 },
				["2"] = { x1 = 0, x2 = 0 },
				["M"] = { x1 = 0, x2 = 0 },
				["C"] = { x1 = 0, x2 = 0 },
			},
			act              = 0,
			acta             = 0,
			attack           = 0,           -- 攻撃中のみ変化
			hitstop_id       = 0,           -- ヒット/ガードしている相手側のattackと同値
			hitstop          = 0,           -- 攻撃側のガード硬直
			old_pos          = 0,           -- X位置
			old_pos_frc      = 0,           -- X位置少数部
			pos              = 0,           -- X位置
			pos_frc          = 0,           -- X位置少数部
			old_posd         = 0,           -- X位置
			posd             = 0,           -- X位置
			poslr            = "L",         -- 右側か左側か
			max_pos          = 0,           -- X位置最大
			min_pos          = 0,           -- X位置最小
			pos_y            = 0,           -- Y位置
			pos_frc_y        = 0,           -- Y位置少数部
			old_pos_y        = 0,           -- Y位置
			old_pos_frc_y    = 0,           -- Y位置少数部
			reach_memo       = "",          -- リーチ
			reach_tbl        = {},          -- リーチ排他
			old_in_air       = false,
			in_air           = false,
			chg_air_state    = 0,           -- ジャンプの遷移ポイントかどうか
			force_y_pos      = 0,           -- Y位置強制
			pos_z            = 0,           -- Z位置
			old_pos_z        = 0,           -- Z位置
			on_main_line     = 0,           -- Z位置メインに移動した瞬間フレーム
			on_sway_line     = 0,           -- Z位置スウェイに移動した瞬間フレーム
			in_sway_line     = false,       -- Z位置
			sway_status      = 0,           --
			side             = 0,           -- 向き
			state            = 0,           -- いまのやられ状態
			state_flags      = 0,           -- 処理で使われているフラグ群
			tmp_combo        = 0,           -- 一次的なコンボ数
			tmp_combo_dmg    = 0,
			tmp_combo_pow    = 0,
			last_combo_stun_offset = 0,
			last_combo_st_timer_offset = 0,
			tmp_dmg          = 0,           -- ダメージが入ったフレーム
			color            = 0,           -- カラー A=0x00 D=0x01

			frame_gap        = 0,
			last_frame_gap   = 0,
			act_contact      = 0,
			guard1           = 0,          -- ガード時（硬直前後）フレームの判断用
			on_guard         = 0,          -- ガード時（硬直前）フレーム
			on_guard1        = 0,          -- ガード時（硬直後）フレーム
			hit1             = 0,          -- ヒット時（硬直前後）フレームの判断用
			on_hit           = 0,          -- ヒット時（硬直前）フレーム
			on_hit1          = 0,          -- ヒット時（硬直後）フレーム
			on_wakeup        = 0,
			on_down          = 0,
			hit_skip         = 0,
			old_skip_frame   = false,
			skip_frame       = false,
			last_blockstun   = 0,
			last_hitstop     = 0,

			knock_back1      = 0, -- のけぞり確認用1(色々)
			knock_back2      = 0, -- のけぞり確認用2(裏雲隠し)
			knock_back3      = 0, -- のけぞり確認用3(フェニックススルー)
			old_knock_back1  = 0, -- のけぞり確認用1(色々)
			old_knock_back2  = 0, -- のけぞり確認用2(裏雲隠し)
			old_knock_back3  = 0, -- のけぞり確認用3(フェニックススルー)
			fake_hit         = false,
			obsl_hit         = false, -- 嘘判定チェック用
			full_hit         = false, -- 判定チェック用1
			harmless2        = false, -- 判定チェック用2 飛び道具専用
			prj_rank         = 0,           -- 飛び道具の強さ
			esaka_range      = nil,           -- 詠酒の間合いチェック用

			key_now          = {},          -- 前フレームまでの個別キー入力フレーム
			key_pre          = {},          -- 個別キー入力フレーム
			key_hist         = {},
			key_frames       = {},
			act_frame        = 0,
			act_frames       = {},
			act_frames2      = {},
			act_frames_total = 0,

			muteki           = {
				type         = 0,
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
			fake_hits        = p1 and { [0x100600] = 0x10DDF5, [0x100800] = 0x10DDF7, [0x100A00] = 0x10DDF9, } or
									  { [0x100700] = 0x10DDF6, [0x100900] = 0x10DDF8, [0x100B00] = 0x10DDFA, },
			fireball         = {},

			bs_hooked        = 0,           -- BSモードのフック処理フレーム数。

			hit              = {
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
				vulnerable22 = 0,           -- 0の時vulnerable=true
				reach_edge   = {},
			},

			throw            = {
				x1           = 0,
				x2           = 0,
				half_range   = 0,
				full_range   = 0,
				in_range     = false,
			},

			n_throw          = {
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
				id           = 0,
				pos_x        = 0,
				pos_y        = 0,
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
					id       = p1 and 0x10CDA7 or 0x10CDC7,
					pos_x    = p1 and 0x10CDA8 or 0x10CDC8,
					pos_y    = p1 and 0x100DAA or 0x10CDCA,
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
				id           = 0,
				pos_x        = 0,
				pos_y        = 0,
				addr         = {
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

			sp_throw         = {
				on           = 0,
				front        = 0,
				top          = 0,
				base         = 0,
				opp_base     = 0,
				opp_id       = 0,
				side         = 0,
				bottom       = 0,
				id           = 0,
				pos_x        = 0,
				pos_y        = 0,
				addr         = {
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

			addr           = {
				base         = p1 and 0x100400 or 0x100500, -- キャラ状態とかのベースのアドレス
				act          = p1 and 0x100460 or 0x100560, -- 行動ID デバッグディップステータス表示のPと同じ
				acta         = p1 and 0x100462 or 0x100562, -- 行動ID デバッグディップステータス表示のAと同じ
				act_count    = p1 and 0x100466 or 0x100566, -- 現在の行動のカウンタ
				act_frame    = p1 and 0x10046F or 0x10056F, -- 現在の行動の残フレーム、ゼロになると次の行動へ
				act_contact  = p1 and 0x100401 or 0x100501, -- 通常=2、必殺技中=3 ガードヒット=5 潜在ガード=6
				attack       = p1 and 0x1004B6 or 0x1005B6, -- 攻撃中のみ変化
				hitstop_id   = p1 and 0x1004EB or 0x1005EB, -- 被害中のみ変化
				ophit_base   = p1 and 0x10049E or 0x10059E, -- ヒットさせた相手側のベースアドレス
				char         = p1 and 0x107BA5 or 0x107BA7, -- キャラ()
				color        = p1 and 0x107BAC or 0x107BAD, -- カラー A=0x00 D=0x01
				combo        = p1 and 0x10B4E4 or 0x10B4E5, -- コンボ
				combo2       = p1 and 0x10B4E5 or 0x10B4E4, -- 最近のコンボ数のアドレス
				dmg_id       = p1 and 0x1004E9 or 0x1005E9, -- ダメージ算出の技ID(最後にヒット/ガードした技のID)
				tmp_combo2   = p1 and 0x10B4E1 or 0x10B4E0, -- 一次的なコンボ数のアドレス
				max_combo2   = p1 and 0x10B4F0 or 0x10B4EF, -- 最大コンボ数のアドレス
				dmg_scl7     = p1 and 0x10DE50 or 0x10DE51, -- 補正 7/8 の回数
				dmg_scl6     = p1 and 0x10DE52 or 0x10DE53, -- 補正 6/8 の回数
				dmg_scl5     = p1 and 0x10DE54 or 0x10DE55, -- 補正 5/8 の回数
				dmg_scl4     = p1 and 0x10DE56 or 0x10DE57, -- 補正 4/8 の回数
				last_dmg     = p1 and 0x10048F or 0x10058F, -- 最終ダメージ
				tmp_dmg      = p1 and 0x10CA10 or 0x10CA11, -- 最終ダメージの更新フック
				pure_dmg     = p1 and 0x10DDFB or 0x10DDFC, -- 最終ダメージ(補正前)
				tmp_pow      = p1 and 0x10DE59 or 0x10DE58, -- POWゲージ増加量
				tmp_pow_rsv  = p1 and 0x10DE5B or 0x10DE5A, -- POWゲージ増加量(予約値)
				tmp_stun     = p1 and 0x10DDFD or 0x10DDFF, -- 最終スタン値
				tmp_st_timer = p1 and 0x10DDFE or 0x10DE00, -- 最終スタンタイマー
				life         = p1 and 0x10048B or 0x10058B, -- 体力
				max_combo    = p1 and 0x10B4EF or 0x10B4F0, -- 最大コンボ
				max_stun     = p1 and 0x10B84E or 0x10B856, -- 最大スタン値
				pos          = p1 and 0x100420 or 0x100520, -- X位置
				pos_frc      = p1 and 0x100422 or 0x100522, -- X位置 少数部
				max_pos      = p1 and 0x10DDE6 or 0x10DDE8, -- X位置最大
				min_pos      = p1 and 0x10DDEA or 0x10DDEC, -- X位置最小
				pos_y        = p1 and 0x100428 or 0x100528, -- Y位置
				pos_frc_y    = p1 and 0x10042A or 0x10052A, -- Y位置 少数部
				pos_z        = p1 and 0x100424 or 0x100524, -- Z位置
				sway_status  = p1 and 0x100489 or 0x100589, -- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
 				side         = p1 and 0x100458 or 0x100558, -- 向き
				state        = p1 and 0x10048E or 0x10058E, -- 状態
				state_flags  = p1 and 0x1004C0 or 0x1005C0, -- フラグ群
				stop         = p1 and 0x10048D or 0x10058D, -- ヒットストップ
				knock_back1  = p1 and 0x100469 or 0x100569, -- のけぞり確認用1(色々)
				knock_back2  = p1 and 0x100416 or 0x100516, -- のけぞり確認用2(裏雲隠し)
				knock_back3  = p1 and 0x10047E or 0x10057E, -- のけぞり確認用3(フェニックススルー)
				prj_rank     = p1 and 0x1004B5 or 0x1005B5, -- 飛び道具の強さ
				esaka_range  = p1 and 0x1004B6 or 0x1005B6, -- 詠酒の間合いチェック用

				no_hit       = p1 and 0x10DDF2 or 0x10DDF1, -- ヒットしないフック

				stun         = p1 and 0x10B850 or 0x10B858, -- 現在スタン値
 				stun_timer   = p1 and 0x10B854 or 0x10B85C, -- スタン値ゼロ化までの残フレーム数
 				tmp_combo    = p1 and 0x10B4E0 or 0x10B4E1, -- コンボテンポラリ
				pow          = p1 and 0x1004BC or 0x1005BC, -- パワーアドレス
				reg_pcnt     = p1 and 0x300000 or 0x340000, -- キー入力 REG_P1CNT or REG_P2CNT アドレス
				reg_st_b     = 0x380000,                    -- キー入力 REG_STATUS_B アドレス
				control1     = p1 and 0x100412 or 0x100512, -- Human 1 or 2, CPU 3
				control2     = p1 and 0x100413 or 0x100513, -- Human 1 or 2, CPU 3
				select_hook  = p1 and 0x10CDD1 or 0x10CDD5, -- プレイヤーセレクト画面のフック処理用アドレス
				bs_hook1     = p1 and 0x10DDDA or 0x10DDDE, -- BSモードのフック処理用アドレス。技のID。
				bs_hook2     = p1 and 0x10DDDB or 0x10DDDF, -- BSモードのフック処理用アドレス。技のバリエーション。
				bs_hook3     = p1 and 0x10DDDD or 0x10DDE1, -- BSモードのフック処理用アドレス。技発動。

				tw_threshold = p1 and 0x10DDE2 or 0x10DDE3, -- 投げ可能かどうかのフレーム判定のしきい値
				tw_frame     = p1 and 0x100490 or 0x100590, -- 投げ可能かどうかのフレーム経過
				tw_accepted  = p1 and 0x10DDE4 or 0x10DDE5, -- 投げ確定時のフレーム経過
				tw_muteki    = p1 and 0x1004F6 or 0x1005F6, -- 投げ無敵の残フレーム数

				-- フックできないかわり用
				state2       = p1 and 0x10CA0E or 0x10CA0F, -- 状態
				act2         = p1 and 0x10CA12 or 0x10CA13, -- 行動ID デバッグディップステータス表示のPと同じ

				-- フックできないかわり用-当たり判定
				vulnerable1  = p1 and 0x10CB30 or 0x10CB31,
				vulnerable21 = p1 and 0x10CB32 or 0x10CB33,
				vulnerable22 = p1 and 0x10CB34 or 0x10CB35, -- 0の時vulnerable=true

				-- ヒットするかどうか
				fake_hit     = p1 and 0x10DDF3 or 0x10DDF4, -- 出だしから嘘判定のフック
				obsl_hit     = p1 and 0x10046A or 0x10056A, -- 嘘判定チェック用 3ビット目が立っていると嘘判定
				full_hit     = p1 and 0x1004AA or 0x1005AA, -- 判定チェック用1 0じゃないとき全段攻撃ヒット/ガード
				harmless2    = p1 and 0x1004B6 or 0x1005B6, -- 判定チェック用2 0のときは何もしていない 同一技の連続ヒット数加算
				max_hit_nm   = p1 and 0x1004AB or 0x1005AB, -- 同一技行動での最大ヒット数 分子
			},
		}

		for i = 1, #kprops do
			players[p].key_now[kprops[i]] = 0
			players[p].key_pre[kprops[i]] = 0
		end
		for i = 1, 16 do
			players[p].key_hist[i] = ""
			players[p].key_frames[i] = 0
			players[p].act_frames[i] = {0,0}
			players[p].bases[i] = { count = 0, addr = 0x0, act_data = nil, name = "", pos1 = 0, pos2 = 0, xmov = 0, }
		end
	end
	players[1].op = players[2]
	players[2].op = players[1]
	-- 飛び道具領域の作成
	for i, p in ipairs(players) do
		for base, _ in pairs(p.fireball_bases) do
			p.fireball[base] = {
				parent         = p,
				is_fireball    = true,
				act            = 0,
				acta           = 0,

				act_count      = 0, -- 現在の行動のカウンタ
				act_frame      = 0, -- 現在の行動の残フレーム、ゼロになると次の行動へ
				act_contact    = 0, -- 通常=2、必殺技中=3 ガードヒット=5 潜在ガード=6

				asm            = 0,
				pos            = 0, -- X位置
				pos_y          = 0, -- Y位置
				reach_memo     = "", -- リーチ
				reach_tbl      = {}, -- リーチ排他
				pos_z          = 0, -- Z位置
				attack         = 0, -- 攻撃中のみ変化
				hitstop_id     = 0, -- ガード硬直のID
				hitstop        = 0, -- ガード硬直
				fake_hit       = false,
				obsl_hit       = false, -- 嘘判定チェック用
				full_hit       = false, -- 判定チェック用1
				harmless2      = false, -- 判定チェック用2 飛び道具専用
				prj_rank       = 0,     -- 飛び道具の強さ
				bai_chk1       = 0,     -- 倍返しチェック1
				bai_chk2       = 0,     -- 倍返しチェック2
				max_hit_dn     = 0,     -- 同一技行動での最大ヒット数 分母
				max_hit_nm     = 0,     -- 同一技行動での最大ヒット数 分子
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
					harmless   = false,
					fake_hit   = false,
					obsl_hit   = false,
					full_hit   = false,
					harmless2  = false,
					max_hit_dn = 0,
					max_hit_nm = 0,
				},
				addr           = {
					base       = base, -- キャラ状態とかのベースのアドレス
					char       = base + 0x10, -- 技のキャラID
					act        = base + 0x60, -- 技のID デバッグのP
					acta       = base + 0x62, -- 技のID デバッグのA
					actb       = base + 0x64, -- 技のID?
					act_count  = base + 0x66, -- 現在の行動のカウンタ
					act_frame  = base + 0x6F, -- 現在の行動の残フレーム、ゼロになると次の行動へ
					act_contact= base + 0x01, -- 通常=2、必殺技中=3 ガードヒット=5 潜在ガード=6
					dmg_id     = base + 0xE9, -- ダメージ算出の技ID
					pos        = base + 0x20, -- X位置
					pos_y      = base + 0x28, -- Y位置
	 				pos_z      = base + 0x24, -- Z位置
					attack     = base + 0xBF, -- デバッグのNO
					hitstop_id = base + 0xBE, -- ヒット硬直用ID
					-- ヒットするかどうか
					fake_hit   = p.fake_hits[base],
					obsl_hit   = base + 0x6A, -- 嘘判定チェック用 3ビット目が立っていると嘘判定
					full_hit   = base + 0xAA, -- 判定チェック用1 0じゃないとき全段攻撃ヒット/ガード
					harmless2  = base + 0xE7, -- 判定チェック用2 0じゃないときヒット/ガード
					max_hit_nm = base + 0xAB, -- 同一技行動での最大ヒット数 分子
					prj_rank   = base + 0xB5, -- 飛び道具の強さ

					bai_chk1   = base + 0x8A, -- 倍返しチェック1
					bai_chk2   = base + 0xBE, -- 倍返しチェック2
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
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		pgm:write_direct_u8(0x100024, 0x03) -- 1P or 2P
		pgm:write_direct_u8(0x100027, 0x03) -- 1P or 2P
	end

	local apply_vs_mode = function(continue)
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		apply_1p2p_active()
		if not continue then
			pgm:write_direct_u8(0x107BB5, 0x01) -- vs 1st CPU mode
		end
	end

	local goto_player_select = function()
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		dofile(ram_patch_path("player-select.lua"))
		apply_vs_mode(false)
	end

	local restart_fight = function(param)
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		param = param or {}
		local stg1  = param.next_stage.stg1 or stgs[1].stg1
		local stg2  = param.next_stage.stg2 or stgs[1].stg2
		local stg3  = param.next_stage.stg3 or stgs[1].stg3
		global.no_background = (param.next_stage or stgs[1]).no_background
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

		-- メニュー用にキャラの番号だけ差し替える
		players[1].char = p1
		players[2].char = p2
	end
	--

	-- ブレイクポイント発動時のデバッグ画面表示と停止をさせない
	local debug_stop = 0
	local auto_recovery_debug = function()
		if manager.machine.debugger then
			if manager.machine.debugger.execution_state ~= "run" then
				debug_stop = debug_stop + 1
			end
			if 3 > debug_stop then
				manager.machine.debugger.execution_state = "run"
				debug_stop = 0
			end
		end
	end
	--

	-- ダッシュとバックステップを抑止する
	local set_step = function(p, enabled)
		local cpu = manager.machine.devices[":maincpu"]
		if enabled then
			if p.step_bp == nil then
				p.step_bp = cpu.debug:bpset(0x026216, "(A4)==$" .. string.format("%x", p.addr.base), "PC=$02622A;g")
			end
			cpu.debug:bpenable(p.step_bp)
		else
			if p.step_bp then
				cpu.debug:bpdisable(p.step_bp)
			end
		end
	end

	-- 対スウェーライン攻撃の近距離間合い
	-- 地上通常技の近距離間合い
	-- char 0=テリー
	local get_close_far_pos = function(char)
		char =  char - 1
		local cpu = manager.machine.devices[":maincpu"]
		local pgm = cpu.spaces["program"]
		local abc_offset = close_far_offset + (char * 4)
		-- 家庭用02DD02からの処理
		local d_offset = close_far_offset_d + (char * 2)
		return {
			a = { x1 = 0, x2 = pgm:read_u8(abc_offset)     },
			b = { x1 = 0, x2 = pgm:read_u8(abc_offset + 1) },
			c = { x1 = 0, x2 = pgm:read_u8(abc_offset + 2) },
			d = { x1 = 0, x2 = pgm:read_u16(d_offset)      },
		}
	end

	local get_lmo_range_internal = function(ret, name, d0, d1, incl_last)
		local decd1 = int16tofloat(d1)
		local intd1 = math.floor(decd1)
		local x1, x2 = 0, 0
		for d = 1, intd1 do
			x2 = d * d0
			ret[name .. d-1] = { x1 = x1, x2 = x2-1}
			x1 = x2
		end
		if incl_last then
			ret[name .. intd1]  = { x1 = x1, x2 = math.floor(d0 * decd1) } -- 1Fあたりの最大移動量になる距離
		end
		return ret
	end

	local cache_close_far_pos_lmo = {} 
	local get_close_far_pos_line_move_attack = function(char, logging)
		if cache_close_far_pos_lmo[char] then
			return cache_close_far_pos_lmo[char]
		end

		-- 家庭用2EC72,2EDEE,2E1FEからの処理
		local cpu = manager.machine.devices[":maincpu"]
		local pgm = cpu.spaces["program"]
		local offset = 0x2EE06
		local d1 = 0x2A000 -- 整数部上部4バイト、少数部下部4バイト
		local decd1 = int16tofloat(d1)
		local ret = {}
		-- 0:近A 1:遠A 2:近B 3:遠B 4:近C 5:遠C
		for i, act_name in ipairs({"近A", "遠A", "近B", "遠B", "近C", "遠C"}) do
			local d0 = pgm:read_u8(pgm:read_u32(offset + (i-1) * 4) + char * 6)
			-- データが近距離、遠距離の2種類しかないのと実質的に意味があるのが近距離のものなので最初のデータだけ返す
			if i == 1 then
				get_lmo_range_internal(ret, "", d0, d1, true)
				ret["近"]  = { x1 =  0, x2 = 72         } -- 近距離攻撃になる距離

				if char == 6 then
					-- 渦炎陣
					get_lmo_range_internal(ret, "必", 24, 0x40000)
				elseif char == 14 then
					-- クロスヘッドスピン
					get_lmo_range_internal(ret, "必", 24, 0x80000)
				end
			end
			if logging then
				print(string.format("%s %s %x %s %x %s",char_names[char], act_name, d0, d0, d1, decd1))
			end
		end
		cache_close_far_pos_lmo[char] = ret
		return ret
	end

	-- 詠酒の距離チェックを飛ばす
	local set_skip_esaka_check = function(p, enabled)
		local cpu = manager.machine.devices[":maincpu"]
		if enabled then
			if p.skip_esaka_check == nil then
				p.skip_esaka_check = cpu.debug:bpset(0x0236F2, "(A4)==$" .. string.format("%x", p.addr.base), "PC=2374C;g")
			end
			cpu.debug:bpenable(p.skip_esaka_check)
		else
			if p.skip_esaka_check then
				cpu.debug:bpdisable(p.skip_esaka_check)
			end
		end
	end

	-- 当たり判定と投げ判定用のブレイクポイントとウォッチポイントのセット
	local wps = {}
	local set_wps = function(reset)
		local cpu = manager.machine.devices[":maincpu"]
		local pgm = cpu.spaces["program"]
		if reset then
			cpu.debug:bpdisable()
			return
		elseif #wps > 0 then
			cpu.debug:bpenable()
			return
		end

		if #wps == 0 then
			--debug:wpset(space, type, addr, len, [opt] cond, [opt] act)
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x1006BF, 1, "wpdata!=0", "maincpu.pb@10CA00=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x1007BF, 1, "wpdata!=0", "maincpu.pb@10CA01=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x100620, 1, "wpdata!=0", "maincpu.pb@10CA02=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x10062C, 1, "wpdata!=0", "maincpu.pb@10CA03=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x100820, 1, "wpdata!=0", "maincpu.pb@10CA04=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x10082C, 1, "wpdata!=0", "maincpu.pb@10CA05=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x100A20, 1, "wpdata!=0", "maincpu.pb@10CA06=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x100A2C, 1, "wpdata!=0", "maincpu.pb@10CA07=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x100720, 1, "wpdata!=0", "maincpu.pb@10CA08=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x10072C, 1, "wpdata!=0", "maincpu.pb@10CA09=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x100920, 1, "wpdata!=0", "maincpu.pb@10CA0A=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x10092C, 1, "wpdata!=0", "maincpu.pb@10CA0B=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x100B20, 1, "wpdata!=0", "maincpu.pb@10CA0C=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x100B2C, 1, "wpdata!=0", "maincpu.pb@10CA0D=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x10048E, 1, "wpdata!=0", "maincpu.pb@10CA0E=maincpu.pb@10048E;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x10058E, 1, "wpdata!=0", "maincpu.pb@10CA0F=maincpu.pb@10058E;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x10048F, 1, "1", "maincpu.pb@10CA10=wpdata;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x10058F, 1, "1", "maincpu.pb@10CA11=wpdata;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x100460, 1, "wpdata!=0", "maincpu.pb@10CA12=1;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x100560, 1, "wpdata!=0", "maincpu.pb@10CA13=1;g"))

			-- X軸のMAXとMIN
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x100420, 2, "wpdata>maincpu.pw@10DDE6", "maincpu.pw@10DDE6=wpdata;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x100420, 2, "wpdata<maincpu.pw@10DDEA", "maincpu.pw@10DDEA=wpdata;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x100520, 2, "wpdata>maincpu.pw@10DDE8", "maincpu.pw@10DDE8=wpdata;g"))
			table.insert(wps, cpu.debug:wpset(pgm, "w", 0x100520, 2, "wpdata<maincpu.pw@10DDEC", "maincpu.pw@10DDEC=wpdata;g"))
		end
	end

	local bps = {}
	local set_bps = function(reset)
		local cpu = manager.machine.devices[":maincpu"]
		if reset then
			cpu.debug:wpdisable()
			-- bps = {} -- clearではなくdisableにする場合は消さなくてもいい
			return
		elseif #bps > 0 then
			cpu.debug:wpenable()
			return
		end

		if #bps == 0 then
			if global.infinity_life2 then
				--bp 05B480,{(maincpu.pw@107C22>0)&&($100400<=((A3)&$FFFFFF))&&(((A3)&$FFFFFF)<=$100500)},{PC=5B48E;g}
				table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x05B460),
					"1",
					string.format("PC=%x;g", fix_bp_addr(0x05B46E))))
				table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x05B466),
					"1",
					string.format("PC=%x;g", fix_bp_addr(0x05B46E))))
			end

			-- リバーサルとBSモードのフック
			-- ダッシュとか用
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x03957E),
				"(maincpu.pw@107C22>0)&&((A6)==CB244)&&((($1E<=maincpu.pb@10DDDA)&&(maincpu.pb@10DDDD==$1)&&($100400==((A4)&$FFFFFF)))||(($1E<=maincpu.pb@10DDDE)&&(maincpu.pb@10DDE1==$1)&&($100500==((A4)&$FFFFFF))))",
				"temp1=$10DDDA+((((A4)&$FFFFFF)-$100400)/$40);D1=(maincpu.pb@(temp1));A6=((A6)+1);maincpu.pb@((A4)+$D6)=D1;maincpu.pb@((A4)+$D7)=maincpu.pb@(temp1+1);PC=((PC)+$20);g"))
			-- 必殺技用
			-- bp 03957E,{((A6)==CB244)&&((A4)==100400)&&(maincpu.pb@10048E==2)},{D1=1;g}
			-- bp 03957E,{((A6)==CB244)&&((A4)==100500)&&(maincpu.pb@10058E==2)},{D1=1;g}
			-- 0395B2: 1941 00A3                move.b  D1, ($a3,A4) -- 確定した技データ
			-- 0395B6: 195E 00A4                move.b  (A6)+, ($a4,A4) -- 技データ読込 だいたい06
			-- 0395BA: 195E 00A5                move.b  (A6)+, ($a5,A4) -- 技データ読込 だいたい00、飛燕斬01、02、03
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x03957E),
				"(maincpu.pw@107C22>0)&&((A6)==CB244)&&((($1E>maincpu.pb@10DDDA)&&(maincpu.pb@10DDDD==$1)&&($100400==((A4)&$FFFFFF)))||(($1E>maincpu.pb@10DDDE)&&(maincpu.pb@10DDE1==$1)&&($100500==((A4)&$FFFFFF))))",
				"temp1=$10DDDA+((((A4)&$FFFFFF)-$100400)/$40);D1=(maincpu.pb@(temp1));A6=((A6)+2);maincpu.pb@((A4)+$A3)=D1;maincpu.pb@((A4)+$A4)=maincpu.pb@(temp1+1);maincpu.pb@((A4)+$A5)=maincpu.pb@(temp1+2);PC=((PC)+$20);g"))

			-- ステージ設定用。メニューでFを設定した場合にのみ動作させる
			-- ラウンド数を1に初期化→スキップ
			table.insert(bps, cpu.debug:bpset(0x0F368, "maincpu.pw@((A5)-$448)==$F", "PC=F36E;g"))
			-- ラウンド2以上の場合の初期化処理→無条件で実施
			table.insert(bps, cpu.debug:bpset(0x22AD8, "maincpu.pw@((A5)-$448)==$F", "PC=22AF4;g"))
			-- キャラ読込 ラウンド1の時だけ読み込む→無条件で実施
			table.insert(bps, cpu.debug:bpset(0x22D32, "maincpu.pw@((A5)-$448)==$F", "PC=22D3E;g"))
			-- ラウンド2以上の時の処理→データロード直後の状態なので不要。スキップしないとBGMが変わらない
			table.insert(bps, cpu.debug:bpset(0x0F6AC, "maincpu.pw@((A5)-$448)==$F", "PC=F6B6;g"))
			-- ラウンド1じゃないときの処理 →スキップ
			table.insert(bps, cpu.debug:bpset(0x1E39A, "maincpu.pw@((A5)-$448)==$F", "PC=1E3A4;g"))
			-- ラウンド1の時だけ読み込む →無条件で実施。データを1ラウンド目の値に戻す
			table.insert(bps, cpu.debug:bpset(0x17694, "maincpu.pw@((A5)-$448)==$F", "maincpu.pw@((A5)-$448)=1;PC=176A0;g"))

			-- 当たり判定用
			-- 喰らい判定フラグ用
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x5C2DA),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CB30+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=$01;g"))

			-- 喰らい判定用
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x5C2E6),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CB32+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=$01;maincpu.pb@(temp1+$2)=(maincpu.pb@(((A4)+$B1)&$FFFFFF));g"))

			--判定追加1 攻撃判定
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x012C42),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100F00)",
				"temp0=($10CB41+((maincpu.pb@10CB40)*$10));maincpu.pb@(temp0)=1;maincpu.pb@(temp0+1)=maincpu.pb@(A2);maincpu.pb@(temp0+2)=maincpu.pb@((A2)+$1);maincpu.pb@(temp0+3)=maincpu.pb@((A2)+$2);maincpu.pb@(temp0+4)=maincpu.pb@((A2)+$3);maincpu.pb@(temp0+5)=maincpu.pb@((A2)+$4);maincpu.pd@(temp0+6)=((A4)&$FFFFFFFF);maincpu.pb@(temp0+$A)=$FF;maincpu.pd@(temp0+$B)=maincpu.pd@((A2)+$5);maincpu.pw@(temp0+$C)=maincpu.pw@(((A4)&$FFFFFF)+$20);maincpu.pw@(temp0+$E)=maincpu.pw@(((A4)&$FFFFFF)+$28);maincpu.pb@10CB40=((maincpu.pb@10CB40)+1);g"))

			--判定追加2 攻撃判定
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x012C88),
				"(maincpu.pw@107C22>0)&&($100400<=((A3)&$FFFFFF))&&(((A3)&$FFFFFF)<=$100F00)",
				"temp0=($10CB41+((maincpu.pb@10CB40)*$10));maincpu.pb@(temp0)=1;maincpu.pb@(temp0+1)=maincpu.pb@(A1);maincpu.pb@(temp0+2)=maincpu.pb@((A1)+$1);maincpu.pb@(temp0+3)=maincpu.pb@((A1)+$2);maincpu.pb@(temp0+4)=maincpu.pb@((A1)+$3);maincpu.pb@(temp0+5)=maincpu.pb@((A1)+$4);maincpu.pd@(temp0+6)=((A3)&$FFFFFFFF);maincpu.pb@(temp0+$A)=$01;maincpu.pd@(temp0+$B)=maincpu.pd@((A1)+$5);maincpu.pw@(temp0+$C)=maincpu.pw@(((A3)&$FFFFFF)+$20);maincpu.pw@(temp0+$E)=maincpu.pw@(((A3)&$FFFFFF)+$28);maincpu.pb@10CB40=((maincpu.pb@10CB40)+1);g"))

			--判定追加3 1P押し合い判定
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x012D4C),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100F00)",
				"temp0=($10CB41+((maincpu.pb@10CB40)*$10));maincpu.pb@(temp0)=1;maincpu.pb@(temp0+1)=maincpu.pb@(A2);maincpu.pb@(temp0+2)=maincpu.pb@((A2)+$1);maincpu.pb@(temp0+3)=maincpu.pb@((A2)+$2);maincpu.pb@(temp0+4)=maincpu.pb@((A2)+$3);maincpu.pb@(temp0+5)=maincpu.pb@((A2)+$4);maincpu.pd@(temp0+6)=((A4)&$FFFFFFFF);maincpu.pb@(temp0+$A)=$FF;maincpu.pw@(temp0+$C)=maincpu.pw@(((A4)&$FFFFFF)+$20);maincpu.pw@(temp0+$E)=maincpu.pw@(((A4)&$FFFFFF)+$28);maincpu.pb@10CB40=((maincpu.pb@10CB40)+1);g"))

			--判定追加4 2P押し合い判定
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x012D92),
				"(maincpu.pw@107C22>0)&&($100400<=((A3)&$FFFFFF))&&(((A3)&$FFFFFF)<=$100F00)",
				"temp0=($10CB41+((maincpu.pb@10CB40)*$10));maincpu.pb@(temp0)=1;maincpu.pb@(temp0+1)=maincpu.pb@(A1);maincpu.pb@(temp0+2)=maincpu.pb@((A1)+$1);maincpu.pb@(temp0+3)=maincpu.pb@((A1)+$2);maincpu.pb@(temp0+4)=maincpu.pb@((A1)+$3);maincpu.pb@(temp0+5)=maincpu.pb@((A1)+$4);maincpu.pd@(temp0+6)=((A3)&$FFFFFFFF);maincpu.pb@(temp0+$A)=$FF;maincpu.pw@(temp0+$C)=maincpu.pw@(((A3)&$FFFFFF)+$20);maincpu.pw@(temp0+$E)=maincpu.pw@(((A3)&$FFFFFF)+$28);maincpu.pb@10CB40=((maincpu.pb@10CB40)+1);g"))

			-- 地上通常投げ
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x05D782),
				"(maincpu.pw@107C22>0)&&((((D7)&$FFFF)!=0x65))&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CD90+((((A4)&$FFFFFF)-$100400)/$8);maincpu.pb@(temp1)=$1;maincpu.pd@(temp1+$1)=((A4)&$FFFFFF);maincpu.pd@(temp1+$5)=maincpu.pd@(((A4)&$FFFFFF)+$96);maincpu.pw@(temp1+$A)=maincpu.pw@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$10);maincpu.pw@(temp1+$C)=maincpu.pw@(((A4)&$FFFFFF)+$10);maincpu.pb@(temp1+$10)=maincpu.pb@(((A4)&$FFFFFF)+$96+$58);maincpu.pb@(temp1+$11)=maincpu.pb@(((A4)&$FFFFFF)+$58);maincpu.pb@(temp1+$12)=maincpu.pb@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$58);maincpu.pb@(temp1+$13)=maincpu.pb@(maincpu.pd@((PC)+$2));maincpu.pb@(temp1+$14)=maincpu.pb@((maincpu.pd@((PC)+$02))+((maincpu.pw@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$10))<<3)+$3);maincpu.pb@(temp1+$15)=maincpu.pb@((maincpu.pd@((PC)+$02))+((maincpu.pw@((maincpu.pd@(((A4)&$FFFFFF)+$96))+$10))<<3)+$4);maincpu.pb@(temp1+$16)=maincpu.pb@((maincpu.pd@((PC)+$2))+((maincpu.pw@(((A4)&$FFFFFF)+$10))<<3)+$3);maincpu.pb@(temp1+$17)=maincpu.pb@((PC)+$D2+(maincpu.pw@((A4)&$FFFFFF)+$10)*4+((((D7)&$FFFF)-$60)&$7));maincpu.pw@(temp1+$18)=maincpu.pw@(($FFFFFF&(A4))+$20);maincpu.pw@(temp1+$1A)=maincpu.pw@(($FFFFFF&(A4))+$28);g"))

			-- 空中投げ
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x060428),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CD00+((((A4)&$FFFFFF)-$100400)/$8);maincpu.pb@(temp1)=$1;maincpu.pw@(temp1+$1)=maincpu.pw@(A0);maincpu.pw@(temp1+$3)=maincpu.pw@((A0)+$2);maincpu.pd@(temp1+$5)=$FFFFFF&(A4);maincpu.pd@(temp1+$9)=maincpu.pd@(($FFFFFF&(A4))+$96);maincpu.pw@(temp1+$D)=maincpu.pw@(maincpu.pd@(($FFFFFF&(A4))+$96)+$10);maincpu.pd@(temp1+$11)=maincpu.rb@(($FFFFFF&(A4))+$58);maincpu.pw@(temp1+$13)=maincpu.pw@(($FFFFFF&(A4))+$20);maincpu.pw@(temp1+$15)=maincpu.pw@(($FFFFFF&(A4))+$28);g"))

			-- 必殺投げ
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x039F2A),
				"(maincpu.pw@107C22>0)&&($100400<=((A4)&$FFFFFF))&&(((A4)&$FFFFFF)<=$100500)",
				"temp1=$10CD40+((((A4)&$FFFFFF)-$100400)/$8);maincpu.pb@(temp1)=$1;maincpu.pw@(temp1+$1)=maincpu.pw@(A0);maincpu.pw@(temp1+$3)=maincpu.pw@((A0)+$2);maincpu.pd@(temp1+$5)=$FFFFFF&(A4);maincpu.pd@(temp1+$9)=maincpu.pd@(($FFFFFF&(A4))+$96);maincpu.pw@(temp1+$D)=maincpu.pw@(maincpu.pd@(($FFFFFF&(A4))+$96)+$10);maincpu.pd@(temp1+$11)=maincpu.rb@(($FFFFFF&(A4))+$58);maincpu.pw@(temp1+$12)=maincpu.pw@(A0+$4);maincpu.pw@(temp1+$15)=maincpu.pw@(($FFFFFF&(A4))+$20);maincpu.pw@(temp1+$17)=maincpu.pw@(($FFFFFF&(A4))+$28);g"))

			-- プレイヤー選択時のカーソル操作表示用データのオフセット
			-- PC=11EE2のときのA4レジスタのアドレスがプレイヤー選択のアイコンの参照場所
			-- データの領域を未使用の別メモリ領域に退避して1P操作で2Pカーソル移動ができるようにする
			-- maincpu.pw@((A4)+$60)=$00F8を付けたすとカーソルをCPUにできる
			table.insert(bps, cpu.debug:bpset(0x11EE2, --アドレス修正不要
				"(maincpu.pw@((A4)+2)==2D98||maincpu.pw@((A4)+2)==33B8)&&maincpu.pw@100701==10B&&maincpu.pb@10FDAF==2&&maincpu.pw@10FDB6!=0&&maincpu.pb@100026==2",
				"maincpu.pb@10CDD0=($FF&((maincpu.pb@10CDD0)+1));maincpu.pd@10CDD1=((A4)+$13);g"))
			table.insert(bps, cpu.debug:bpset(0x11EE2, --アドレス修正不要
				"(maincpu.pw@((A4)+2)==2D98||maincpu.pw@((A4)+2)==33B8)&&maincpu.pw@100701==10B&&maincpu.pb@10FDAF==2&&maincpu.pw@10FDB6!=0&&maincpu.pb@100026==1",
				"maincpu.pb@10CDD0=($FF&((maincpu.pb@10CDD0)+1));maincpu.pd@10CDD5=((A4)+$13);g"))

			-- プレイヤー選択時に1Pか2Pの選択ボタン押したときに対戦モードに移行する
			-- PC=  C5D0 読取反映先=?? スタートボタンの読取してるけど関係なし
			-- PC= 12376 読取反映先=D0 スタートボタンの読取してるけど関係なし
			-- PC=C096A8 読取反映先=D1 スタートボタンの読取してるけど関係なし
			-- PC=C1B954 読取反映先=D2 スタートボタンの読取してるとこ 
			table.insert(bps, cpu.debug:bpset(0xC1B95A,
				"(maincpu.pb@100024==1&&maincpu.pw@100701==10B&&maincpu.pb@10FDAF==2&&maincpu.pw@10FDB6!=0)&&((((maincpu.pb@300000)&$10)==0)||(((maincpu.pb@300000)&$80)==0))",
				"D2=($FF^$04);g"))
			table.insert(bps, cpu.debug:bpset(0xC1B95A,
				"(maincpu.pb@100024==2&&maincpu.pw@100701==10B&&maincpu.pb@10FDAF==2&&maincpu.pw@10FDB6!=0)&&((((maincpu.pb@340000)&$10)==0)||(((maincpu.pb@340000)&$80)==0))",
				"D2=($FF^$01);g"))

			-- 影表示
			--{base = 0x017300, ["rbff2k"] = 0x28, ["rbff2h"] = 0x0, no_background = true,
			--			func = function() memory.pgm:write_u8(gr("a4") + 0x82, 0) end},
			--solid shadows 01
			--no    shadows FF
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x017300), "maincpu.pw@107C22>0&&maincpu.pb@10DDF0==FF", "maincpu.pb@((A4)+$82)=$FF;g"))

			-- 潜在ぜったい投げるマン
			--table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x039F8C), "1",
			--	"maincpu.pb@((A3)+$90)=$19;g"))
			-- 投げ可能判定用フレーム
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x039F90), "maincpu.pw@107C22>0",
				"temp1=$10DDE2+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=D7;g"))
			-- 投げ確定時の判定用フレーム
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x039F96), "maincpu.pw@107C22>0",
				"temp1=$10DDE4+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=maincpu.pb@((A3)+$90);g"))

			-- 判定の接触判定が無視される
			-- bp 13118,1,{PC=1311C;g}

			-- 攻撃のヒットをむりやりガードに変更する
			-- bp 0580F4,1,{pc=5810a;g}

			-- 投げ確定時の判定用フレーム
			--[[
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x012FD0),
				"maincpu.pw@107C22>0&&((maincpu.pb@10DDF1>0&&(A4)==100500)||(maincpu.pb@10DDF1>0&&(A4)==100400))",
				"temp1=$10DDF1+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=0;PC=" .. string.format("%x", fix_bp_addr(0x012FDA)) .. ";g"))
			]]

			-- N段目で空ぶりさせるフック
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x0130F8),
				"maincpu.pw@107C22>0&&((maincpu.pb@10DDF1>0&&(A4)==100500)||(maincpu.pb@10DDF2>0&&(A4)==100400))",
				"maincpu.pb@(temp1)=0;PC=" .. string.format("%x", fix_bp_addr(0x012FDA)) .. ";g"))
	
			-- ヒット後ではなく技の出だしから嘘判定であることの判定用フック
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x011DFE),
				"maincpu.pw@107C22>0",
				"temp1=$10DDF3+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=(D5);g"))

			-- 補正前ダメージ取得用フック
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x05B11A),
				"maincpu.pw@107C22>0",
				"temp1=$10DDFB+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=maincpu.pb@((A4)+$8F);g"))

			-- スタン値とスタン値タイマー取得用フック
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x05C1E0),
				"maincpu.pw@107C22>0",
				"temp1=$10DDFD+((((A4)&$FFFFFF)-$100400)/$80);maincpu.pb@(temp1)=(D0);maincpu.pb@(temp1+$1)=(D1);g"))

			--ダメージ補正 7/8
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x5B1E0),
				"maincpu.pw@107C22>0",
				"temp1=$10DE50+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=maincpu.pb@(temp1)+1;g"))
			--ダメージ補正 6/8
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x5B1F6),
				"maincpu.pw@107C22>0",
				"temp1=$10DE52+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=maincpu.pb@(temp1)+1;g"))
			--ダメージ補正 5/8
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x5B20C),
				"maincpu.pw@107C22>0",
				"temp1=$10DE54+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=maincpu.pb@(temp1)+1;g"))
			--ダメージ補正 4/8
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x5B224),
				"maincpu.pw@107C22>0",
				"temp1=$10DE56+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=maincpu.pb@(temp1)+1;g"))

			-- POWゲージ増加量取得用フック 通常技
			-- 中間のチェックをスキップして算出処理へ飛ぶ
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x03BEDA),
				"maincpu.pw@107C22>0",
				string.format("PC=%x;g", fix_bp_addr(0x03BEEC))))
			-- 中間チェックに抵触するパターンは値採取後にRTSへ移動する
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x05B3AC),
				"maincpu.pw@107C22>0&&(maincpu.pb@((A3)+$BF)!=$0||maincpu.pb@((A3)+$BC)==$3C)",
				"temp1=$10DE58+((((A3)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=(maincpu.pb@(temp1)+(D0));" .. string.format("PC=%x", fix_bp_addr(0x05B34E)) .. ";g"))
			-- 中間チェックに抵触しないパターン
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x05B3AC),
				"maincpu.pw@107C22>0&&maincpu.pb@((A3)+$BF)==$0&&maincpu.pb@((A3)+$BC)!=$3C",
				"temp1=$10DE58+((((A3)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=(maincpu.pb@(temp1)+(D0));g"))

			-- POWゲージ増加量取得用フック 必殺技
			-- 中間のチェックをスキップして算出処理へ飛ぶ
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x05B34C),
				"maincpu.pw@107C22>0",
				string.format("PC=%x;g", fix_bp_addr(0x05B35E))))
			-- 中間チェックに抵触するパターンは値採取後にRTSへ移動する
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x03C144),
				"maincpu.pw@107C22>0&&maincpu.pb@((A4)+$BF)!=$0",
				"temp1=$10DE5A+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=(maincpu.pb@(temp1)+(D0));" .. string.format("PC=%x", fix_bp_addr(0x03C13A)) .. ";g"))
			-- 中間チェックに抵触しないパターン
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x03C144),
				"maincpu.pw@107C22>0&&maincpu.pb@((A4)+$BF)==$0",
				"temp1=$10DE5A+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=(maincpu.pb@(temp1)+(D0));g"))

			-- POWゲージ増加量取得用フック 倍がえしとか
			-- 中間のチェック以前に値がD0に入っているのでそれを採取する
			table.insert(bps, cpu.debug:bpset(fix_bp_addr(0x03BF04),
				"maincpu.pw@107C22>0",
				"temp1=$10DE5A+((((A4)&$FFFFFF)-$100400)/$100);maincpu.pb@(temp1)=(maincpu.pb@(temp1)+(D0));g"))

			-- bp 3B5CE,1,{maincpu.pb@1007B5=0;g} -- 2P 飛び道具の強さ0に

			-- bp 39db0,1,{PC=39db4;g} -- 必殺投げの高度チェックを無視

			-- ライン移動攻撃の移動量のしきい値 調査用
			table.insert(bps, cpu.debug:bpset(0x029768,
				"1",
				"printf \"CH=%D D0=%X D1=%X PREF_ADDR=%X\",maincpu.pw@((A4)+10), D0,D1,PREF_ADDR;g"))
		end
	end

	local bps_rg = {}
	local set_bps_rg = function(reset)
		local cpu = manager.machine.devices[":maincpu"]
		if reset then
			cpu.debug:bpdisable()
			-- bps_rg = {} -- clearではなくdisableにする場合は消さなくてもいい
			return
		elseif #bps_rg > 0 then
			cpu.debug:bpenable()
			return
		end

		if #bps_rg == 0 then
			-- この処理をそのまま有効にすると通常時でも食らい判定が見えるようになるが、MVS版ビリーの本来は攻撃判定無しの垂直ジャンプ攻撃がヒットしてしまう
			-- ビリーの判定が出ない(maincpu.pb@((A0)+$B6)==0)な垂直小ジャンプAと垂直小ジャンプBと斜め小ジャンプBときはこのワークアラウンドが動作しないようにする
			local cond1 = "(maincpu.pw@107C22>0)&&(maincpu.pb@((A0)+$B6)==0)&&(maincpu.pw@((A0)+$60)!=$50)&&(maincpu.pw@((A0)+$60)!=$51)&&(maincpu.pw@((A0)+$60)!=$54)"
			--check vuln at all times *** setregister for m68000.pc is broken *** --bp 05C2E8, 1, {PC=((PC)+$6);g}
			table.insert(bps_rg, cpu.debug:bpset(fix_bp_addr(0x5C2E8), cond1.."&&(maincpu.pb@((A3)+$B6)==0)", "PC=((PC)+$6);g"))
			--この条件で動作させると攻撃判定がでてしまってヒットしてしまうのでダメ
			--[[
			local cond2 = "(maincpu.pw@107C22>0)&&(maincpu.pb@((A0)+$B6)==0)&&((maincpu.pw@((A0)+$60)==$50)||(maincpu.pw@((A0)+$60)==$51)||(maincpu.pw@((A0)+$60)==$54))"
			table.insert(bps_rg, cpu.debug:bpset(fix_bp_addr(0x5C2E8), cond2, "maincpu.pb@((A3)+$B6)=1;g"))
			]]
			--check vuln at all times *** hackish workaround *** --bp 05C2E8, 1, {A3=((A3)-$B5);g}
			table.insert(bps_rg, cpu.debug:bpset(fix_bp_addr(0x5C2E8), cond1, "A3=((A3)-$B5);g"))
			--*** fix for hackish workaround *** --bp 05C2EE, 1, {A3=((A3)+$B5);g}
			table.insert(bps_rg, cpu.debug:bpset(fix_bp_addr(0x5C2EE), cond1, "A3=((A3)+$B5);g"))
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
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]

		-- 各種当たり判定のフック
		-- 0x10CB40 当たり判定の発生個数
		-- 0x10CB41 から 0x10 間隔で当たり判定をbpsetのフックで記録する
		for addr = 0x10CB41, 0x10CB41 + pgm:read_u8(0x10CB40) * 0x11 do
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
	for i = 1, 8 do
		recording.slot[i] = {
			side  = 1, -- レコーディング対象のプレイヤー番号 1=1P, 2=2P
			store = {}, -- 入力保存先
			name = "スロット" .. i,
		}
	end

	-- 調査用自動再生スロットの準備
	local research_cmd = function()
		local make_cmd = function(joykp, ...)
			local joy = new_next_joy()
			if ... then
				for _, k in ipairs({...}) do
					joy[joykp[k]] = true
				end
			end
			return joy
		end
		local _1     = function(joykp) return make_cmd(joykp, "lt", "dn") end
		local _1a    = function(joykp) return make_cmd(joykp, "lt", "dn", "a") end
		local _1b    = function(joykp) return make_cmd(joykp, "lt", "dn", "b") end
		local _1ab   = function(joykp) return make_cmd(joykp, "lt", "dn", "a", "b") end
		local _1c    = function(joykp) return make_cmd(joykp, "lt", "dn", "c") end
		local _1ac   = function(joykp) return make_cmd(joykp, "lt", "dn", "a", "c") end
		local _1bc   = function(joykp) return make_cmd(joykp, "lt", "dn", "b", "c") end
		local _1abc  = function(joykp) return make_cmd(joykp, "lt", "dn", "a", "b", "c") end
		local _1d    = function(joykp) return make_cmd(joykp, "lt", "dn", "d") end
		local _1ad   = function(joykp) return make_cmd(joykp, "lt", "dn", "a", "d") end
		local _1bd   = function(joykp) return make_cmd(joykp, "lt", "dn", "b", "d") end
		local _1abd  = function(joykp) return make_cmd(joykp, "lt", "dn", "a", "b", "d") end
		local _1cd   = function(joykp) return make_cmd(joykp, "lt", "dn", "c", "d") end
		local _1acd  = function(joykp) return make_cmd(joykp, "lt", "dn", "a", "c", "d") end
		local _1bcd  = function(joykp) return make_cmd(joykp, "lt", "dn", "b", "c", "d") end
		local _1abcd = function(joykp) return make_cmd(joykp, "lt", "dn", "a", "b", "c", "d") end
		local _2     = function(joykp) return make_cmd(joykp, "dn") end
		local _2a    = function(joykp) return make_cmd(joykp, "dn", "a") end
		local _2b    = function(joykp) return make_cmd(joykp, "dn", "b") end
		local _2ab   = function(joykp) return make_cmd(joykp, "dn", "a", "b") end
		local _2c    = function(joykp) return make_cmd(joykp, "dn", "c") end
		local _2ac   = function(joykp) return make_cmd(joykp, "dn", "a", "c") end
		local _2bc   = function(joykp) return make_cmd(joykp, "dn", "b", "c") end
		local _2abc  = function(joykp) return make_cmd(joykp, "dn", "a", "b", "c") end
		local _2d    = function(joykp) return make_cmd(joykp, "dn", "d") end
		local _2ad   = function(joykp) return make_cmd(joykp, "dn", "a", "d") end
		local _2bd   = function(joykp) return make_cmd(joykp, "dn", "b", "d") end
		local _2abd  = function(joykp) return make_cmd(joykp, "dn", "a", "b", "d") end
		local _2cd   = function(joykp) return make_cmd(joykp, "dn", "c", "d") end
		local _2acd  = function(joykp) return make_cmd(joykp, "dn", "a", "c", "d") end
		local _2bcd  = function(joykp) return make_cmd(joykp, "dn", "b", "c", "d") end
		local _2abcd = function(joykp) return make_cmd(joykp, "dn", "a", "b", "c", "d") end
		local _3     = function(joykp) return make_cmd(joykp, "rt", "dn") end
		local _3a    = function(joykp) return make_cmd(joykp, "rt", "dn", "a") end
		local _3b    = function(joykp) return make_cmd(joykp, "rt", "dn", "b") end
		local _3ab   = function(joykp) return make_cmd(joykp, "rt", "dn", "a", "b") end
		local _3c    = function(joykp) return make_cmd(joykp, "rt", "dn", "c") end
		local _3ac   = function(joykp) return make_cmd(joykp, "rt", "dn", "a", "c") end
		local _3bc   = function(joykp) return make_cmd(joykp, "rt", "dn", "b", "c") end
		local _3abc  = function(joykp) return make_cmd(joykp, "rt", "dn", "a", "b", "c") end
		local _3d    = function(joykp) return make_cmd(joykp, "rt", "dn", "d") end
		local _3ad   = function(joykp) return make_cmd(joykp, "rt", "dn", "a", "d") end
		local _3bd   = function(joykp) return make_cmd(joykp, "rt", "dn", "b", "d") end
		local _3abd  = function(joykp) return make_cmd(joykp, "rt", "dn", "a", "b", "d") end
		local _3cd   = function(joykp) return make_cmd(joykp, "rt", "dn", "c", "d") end
		local _3acd  = function(joykp) return make_cmd(joykp, "rt", "dn", "a", "c", "d") end
		local _3bcd  = function(joykp) return make_cmd(joykp, "rt", "dn", "b", "c", "d") end
		local _3abcd = function(joykp) return make_cmd(joykp, "rt", "dn", "a", "b", "c", "d") end
		local _4     = function(joykp) return make_cmd(joykp, "lt") end
		local _4a    = function(joykp) return make_cmd(joykp, "lt", "a") end
		local _4b    = function(joykp) return make_cmd(joykp, "lt", "b") end
		local _4ab   = function(joykp) return make_cmd(joykp, "lt", "a", "b") end
		local _4c    = function(joykp) return make_cmd(joykp, "lt", "c") end
		local _4ac   = function(joykp) return make_cmd(joykp, "lt", "a", "c") end
		local _4bc   = function(joykp) return make_cmd(joykp, "lt", "b", "c") end
		local _4abc  = function(joykp) return make_cmd(joykp, "lt", "a", "b", "c") end
		local _4d    = function(joykp) return make_cmd(joykp, "lt", "d") end
		local _4ad   = function(joykp) return make_cmd(joykp, "lt", "a", "d") end
		local _4bd   = function(joykp) return make_cmd(joykp, "lt", "b", "d") end
		local _4abd  = function(joykp) return make_cmd(joykp, "lt", "a", "b", "d") end
		local _4cd   = function(joykp) return make_cmd(joykp, "lt", "c", "d") end
		local _4acd  = function(joykp) return make_cmd(joykp, "lt", "a", "c", "d") end
		local _4bcd  = function(joykp) return make_cmd(joykp, "lt", "b", "c", "d") end
		local _4abcd = function(joykp) return make_cmd(joykp, "lt", "a", "b", "c", "d") end
		local _5     = function(joykp) return make_cmd(joykp) end
		local _5a    = function(joykp) return make_cmd(joykp, "a") end
		local _5b    = function(joykp) return make_cmd(joykp, "b") end
		local _5ab   = function(joykp) return make_cmd(joykp, "a", "b") end
		local _5c    = function(joykp) return make_cmd(joykp, "c") end
		local _5ac   = function(joykp) return make_cmd(joykp, "a", "c") end
		local _5bc   = function(joykp) return make_cmd(joykp, "b", "c") end
		local _5abc  = function(joykp) return make_cmd(joykp, "a", "b", "c") end
		local _5d    = function(joykp) return make_cmd(joykp, "d") end
		local _5ad   = function(joykp) return make_cmd(joykp, "a", "d") end
		local _5bd   = function(joykp) return make_cmd(joykp, "b", "d") end
		local _5abd  = function(joykp) return make_cmd(joykp, "a", "b", "d") end
		local _5cd   = function(joykp) return make_cmd(joykp, "c", "d") end
		local _5acd  = function(joykp) return make_cmd(joykp, "a", "c", "d") end
		local _5bcd  = function(joykp) return make_cmd(joykp, "b", "c", "d") end
		local _5abcd = function(joykp) return make_cmd(joykp, "a", "b", "c", "d") end
		local _a     = _5a
		local _b     = _5b
		local _ab    = _5ab
		local _c     = _5c
		local _ac    = _5ac
		local _bc    = _5bc
		local _abc   = _5abc
		local _d     = _5d
		local _ad    = _5ad
		local _bd    = _5bd
		local _abd   = _5abd
		local _cd    = _5cd
		local _acd   = _5acd
		local _bcd   = _5bcd
		local _abcd  = _5abcd
		local _6     = function(joykp) return make_cmd(joykp, "rt") end
		local _6a    = function(joykp) return make_cmd(joykp, "rt", "a") end
		local _6b    = function(joykp) return make_cmd(joykp, "rt", "b") end
		local _6ab   = function(joykp) return make_cmd(joykp, "rt", "a", "b") end
		local _6c    = function(joykp) return make_cmd(joykp, "rt", "c") end
		local _6ac   = function(joykp) return make_cmd(joykp, "rt", "a", "c") end
		local _6bc   = function(joykp) return make_cmd(joykp, "rt", "b", "c") end
		local _6abc  = function(joykp) return make_cmd(joykp, "rt", "a", "b", "c") end
		local _6d    = function(joykp) return make_cmd(joykp, "rt", "d") end
		local _6ad   = function(joykp) return make_cmd(joykp, "rt", "a", "d") end
		local _6bd   = function(joykp) return make_cmd(joykp, "rt", "b", "d") end
		local _6abd  = function(joykp) return make_cmd(joykp, "rt", "a", "b", "d") end
		local _6cd   = function(joykp) return make_cmd(joykp, "rt", "c", "d") end
		local _6acd  = function(joykp) return make_cmd(joykp, "rt", "a", "c", "d") end
		local _6bcd  = function(joykp) return make_cmd(joykp, "rt", "b", "c", "d") end
		local _6abcd = function(joykp) return make_cmd(joykp, "rt", "a", "b", "c", "d") end
		local _7     = function(joykp) return make_cmd(joykp, "lt", "up") end
		local _7a    = function(joykp) return make_cmd(joykp, "lt", "up", "a") end
		local _7b    = function(joykp) return make_cmd(joykp, "lt", "up", "b") end
		local _7ab   = function(joykp) return make_cmd(joykp, "lt", "up", "a", "b") end
		local _7c    = function(joykp) return make_cmd(joykp, "lt", "up", "c") end
		local _7ac   = function(joykp) return make_cmd(joykp, "lt", "up", "a", "c") end
		local _7bc   = function(joykp) return make_cmd(joykp, "lt", "up", "b", "c") end
		local _7abc  = function(joykp) return make_cmd(joykp, "lt", "up", "a", "b", "c") end
		local _7d    = function(joykp) return make_cmd(joykp, "lt", "up", "d") end
		local _7ad   = function(joykp) return make_cmd(joykp, "lt", "up", "a", "d") end
		local _7bd   = function(joykp) return make_cmd(joykp, "lt", "up", "b", "d") end
		local _7abd  = function(joykp) return make_cmd(joykp, "lt", "up", "a", "b", "d") end
		local _7cd   = function(joykp) return make_cmd(joykp, "lt", "up", "c", "d") end
		local _7acd  = function(joykp) return make_cmd(joykp, "lt", "up", "a", "c", "d") end
		local _7bcd  = function(joykp) return make_cmd(joykp, "lt", "up", "b", "c", "d") end
		local _7abcd = function(joykp) return make_cmd(joykp, "lt", "up", "a", "b", "c", "d") end
		local _8     = function(joykp) return make_cmd(joykp, "up") end
		local _8a    = function(joykp) return make_cmd(joykp, "up", "a") end
		local _8b    = function(joykp) return make_cmd(joykp, "up", "b") end
		local _8ab   = function(joykp) return make_cmd(joykp, "up", "a", "b") end
		local _8c    = function(joykp) return make_cmd(joykp, "up", "c") end
		local _8ac   = function(joykp) return make_cmd(joykp, "up", "a", "c") end
		local _8bc   = function(joykp) return make_cmd(joykp, "up", "b", "c") end
		local _8abc  = function(joykp) return make_cmd(joykp, "up", "a", "b", "c") end
		local _8d    = function(joykp) return make_cmd(joykp, "up", "d") end
		local _8ad   = function(joykp) return make_cmd(joykp, "up", "a", "d") end
		local _8bd   = function(joykp) return make_cmd(joykp, "up", "b", "d") end
		local _8abd  = function(joykp) return make_cmd(joykp, "up", "a", "b", "d") end
		local _8cd   = function(joykp) return make_cmd(joykp, "up", "c", "d") end
		local _8acd  = function(joykp) return make_cmd(joykp, "up", "a", "c", "d") end
		local _8bcd  = function(joykp) return make_cmd(joykp, "up", "b", "c", "d") end
		local _8abcd = function(joykp) return make_cmd(joykp, "up", "a", "b", "c", "d") end
		local _9     = function(joykp) return make_cmd(joykp, "rt", "up") end
		local _9a    = function(joykp) return make_cmd(joykp, "rt", "up", "a") end
		local _9b    = function(joykp) return make_cmd(joykp, "rt", "up", "b") end
		local _9ab   = function(joykp) return make_cmd(joykp, "rt", "up", "a", "b") end
		local _9c    = function(joykp) return make_cmd(joykp, "rt", "up", "c") end
		local _9ac   = function(joykp) return make_cmd(joykp, "rt", "up", "a", "c") end
		local _9bc   = function(joykp) return make_cmd(joykp, "rt", "up", "b", "c") end
		local _9abc  = function(joykp) return make_cmd(joykp, "rt", "up", "a", "b", "c") end
		local _9d    = function(joykp) return make_cmd(joykp, "rt", "up", "d") end
		local _9ad   = function(joykp) return make_cmd(joykp, "rt", "up", "a", "d") end
		local _9bd   = function(joykp) return make_cmd(joykp, "rt", "up", "b", "d") end
		local _9abd  = function(joykp) return make_cmd(joykp, "rt", "up", "a", "b", "d") end
		local _9cd   = function(joykp) return make_cmd(joykp, "rt", "up", "c", "d") end
		local _9acd  = function(joykp) return make_cmd(joykp, "rt", "up", "a", "c", "d") end
		local _9bcd  = function(joykp) return make_cmd(joykp, "rt", "up", "b", "c", "d") end
		local _9abcd = function(joykp) return make_cmd(joykp, "rt", "up", "a", "b", "c", "d") end
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
		local merge_cmd = function(cmd_ary1, cmd_ary2)
			local keys1, keys2 = extract_cmd(joyk.p1, cmd_ary1), extract_cmd(joyk.p2, cmd_ary2)
			local ret, max = {}, math.max(#keys1, #keys2)
			for i = 1, max do
				local joy = new_next_joy()
				for _, key in ipairs({keys1[i] or {}, keys2[i] or {}}) do
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
		local rec1, rec2, rec3, rec4, rec5, rec6, rec7, rec8 = {}, {}, {}, {}, {}, {}, {}, {}
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
		rec3 = merge_cmd( -- ガー不ジャンプB リバサバクステキャンセル真空投げ
			{ _8, _5, 46, _2a, _5, 5, _2c, _5, 15, _6, _5, _4, _1, _2, _3, _bc, _5, 155, _9, _5, 29, _b, _1, 81, _5, },
			{ _8, _5, 46, _2, 15, _2 , _5, 191, _2, _4, _8, _6, _2, _4, _5, _6, _5, _6, _5, 4, _5a, })
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

	local rec_await_no_input, rec_await_1st_input, rec_await_play, rec_input, rec_play, rec_repeat_play, rec_play_interval, rec_fixpos
	local do_recover
	local menu_to_tra, menu_to_bar, menu_to_ex, menu_to_col, menu_to_auto

	local frame_to_time = function(frame_number)
		local min = math.floor(frame_number / 3600)
		local sec = math.floor((frame_number % 3600) / 60)
		local frame = math.floor((frame_number % 3600) % 60)
		return string.format("%02d:%02d:%02d", min, sec, frame)
	end
	-- リプレイ開始位置記憶
	rec_fixpos = function()
		local pos = { get_flip_x(players[1]), get_flip_x(players[2]) }
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		local fixpos  = { pgm:read_i16(players[1].addr.pos)       , pgm:read_i16(players[2].addr.pos)        }
		local fixsway = { pgm:read_u8(players[1].addr.sway_status), pgm:read_u8(players[2].addr.sway_status) }
		local fixscr  = {
			x = pgm:read_u16(stage_base_addr + offset_pos_x),
			y = pgm:read_u16(stage_base_addr + offset_pos_y),
			z = pgm:read_u16(stage_base_addr + offset_pos_z),
		}
		recording.fixpos = { pos = pos, fixpos = fixpos, fixscr = fixscr, fixsway = fixsway, fixstate = fixstate, }
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
		local pos = { get_flip_x(players[1]), get_flip_x(players[2]) }
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
		local pos = { get_flip_x(players[1]), get_flip_x(players[2]) }
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
	rec_await_play = function(to_joy)
		local force_start_play = global.rec_force_start_play
		global.rec_force_start_play = false -- 初期化
		local scr = manager.machine.screens:at(1)
		local ec = scr:frame_number()
		local state_past = ec - global.input_accepted

		local empty = true
		for i = 1, #recording.slot do
			if #recording.slot[i].store > 0 then
				empty = false
			end
		end

		recording.active_slot = { store = {}, name = "空" }
		if not empty and #recording.live_slots > 0 then
			local count = #recording.live_slots
			while count > 0 do
				count = count - 1
				local random_i = math.random(#recording.live_slots)
				local slot_no = recording.live_slots[random_i]
				recording.active_slot = recording.slot[slot_no]
				if #recording.slot[slot_no].store > 0 then
					break
				end
			end
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

			local pgm = manager.machine.devices[":maincpu"].spaces["program"]

			-- メインラインでニュートラル状態にする
			for i, p in ipairs(players) do
				local op = players[3 - i]

				-- 状態リセット   1:OFF 2:1Pと2P 3:1P 4:2P
				if global.replay_reset == 2 or (global.replay_reset == 3 and i == 3) or (global.replay_reset == 4 and i == 4) then
					pgm:write_u8( p.addr.sway_status, 0x00) --fixpos.fixsway[i])
					--pgm:write_u32(p.addr.base, 0x000261A0) -- 素立ち処理
					pgm:write_u32(p.addr.base, 0x00058D5A) -- やられからの復帰処理

					pgm:write_u8( p.addr.base + 0xC0, 0x80)
					pgm:write_u8( p.addr.base + 0xC2, 0x00)
					pgm:write_u8( p.addr.base + 0xFC, 0x00)
					pgm:write_u8( p.addr.base + 0xFD, 0x00)

					pgm:write_u8( p.addr.base + 0x61, 0x01)
					pgm:write_u8( p.addr.base + 0x63, 0x02)
					pgm:write_u8( p.addr.base + 0x65, 0x02)

					pgm:write_i16(p.addr.pos_y      , 0x00)
					pgm:write_i16(p.addr.pos_z      , 0x18)

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
					pgm:write_u8( p.addr.base + 0x66, 0x00)
					pgm:write_u16(p.addr.base + 0x6E, 0x00)
					pgm:write_u8( p.addr.base + 0x6A, 0x00)
					pgm:write_u8( p.addr.base + 0x7E, 0x00)
					pgm:write_u8( p.addr.base + 0xB0, 0x00)
					pgm:write_u8( p.addr.base + 0xB1, 0x00)

					do_recover(p, op, true)
				end
			end

			local fixpos = recording.fixpos
			if fixpos then
				-- 開始間合い固定 1:OFF 2:1Pと2P 3:1P 4:2P
				if fixpos.fixpos then
					for i, p in ipairs(players) do
						if global.replay_fix_pos == 2 or (global.replay_fix_pos == 3 and i == 3) or (global.replay_fix_pos == 4 and i == 4) then
							pgm:write_i16(p.addr.pos, fixpos.fixpos[i])
						end
					end
				end
				if fixpos.fixscr and global.replay_fix_pos and global.replay_fix_pos ~= 1 then
					pgm:write_u16(stage_base_addr + offset_pos_x, fixpos.fixscr.x)
					pgm:write_u16(stage_base_addr + offset_pos_x + 0x30, fixpos.fixscr.x)
					pgm:write_u16(stage_base_addr + offset_pos_x + 0x2C, fixpos.fixscr.x)
					pgm:write_u16(stage_base_addr + offset_pos_x + 0x34, fixpos.fixscr.x)
					pgm:write_u16(stage_base_addr + offset_pos_y, fixpos.fixscr.y)
					pgm:write_u16(stage_base_addr + offset_pos_z, fixpos.fixscr.z)
				end
			end

			-- 入力リセット
			local next_joy = new_next_joy()
			for _, joy in ipairs(use_joy) do
				to_joy[joy.field] = next_joy[joy.field] or false
			end
			return
		end
	end
	-- 繰り返しリプレイ待ち
	rec_repeat_play= function(to_joy)
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
		local scr = manager.machine.screens:at(1)
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
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
		if store == nil or pgm:read_u8(players[recording.player].addr.state) == 1 then
			stop = true
		else
			-- 入力再生
			local pos = { get_flip_x(players[1]), get_flip_x(players[2]) }
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
		local scr = manager.machine.screens:at(1)
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
				recording.last_act = players[3-recording.player].act
				recording.last_pos_y = players[3-recording.player].pos_y
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

	-- TODO データのログ形式を決めて出力できるようにする
	-- OpenTracing OpenCensus の形みたいにしてグラフ化して出せるのが理想
	-- 発生、持続のほか、メタデータで各種データを残すとか
	local log_data = {
		id,             -- ID
		parent_id,      -- 親ID
		frame = {
			startup , -- 発生
			total , -- 全体硬直
			adv_on_hit , -- ヒット時有利不利
			adv_on_block , --- ガード時有利不利
			active , -- 持続
			hit_stop, -- ヒットストップ
			block_stop, -- ガードストップ
			hit_stun, -- ヒット後硬直
			block_stun, -- ガード後硬直
			strike_invincible, -- 打撃無敵
			normal_throw_invincible, -- 通常投げ無敵
			jumping, -- 空中移動まで
			throw_invincible_threshold, -- 投げ無敵Fしきい値
			throw_invincible_resettable, -- 投げ無敵Fリセット
		},
		attack = {
			damage , -- 攻撃力
			chip_ratio, -- 削り補正
			stun, -- 気絶値
			stun_timer , -- 気絶タイマー
			meter_gain , -- パワーゲージ増加量
		},
		effect = {
			name , -- ヒット効果
			no , -- ヒット効果＃
			technical_rise_enable , -- テクニカルライズ可
			ground_sway_enable , -- グランドスウェー可
			ground_sway_enable , -- 避け攻撃相性
			projectile_level , -- 飛び道具レベル
		},
		main_line = {
			gound_hit, -- 地上
			air_hit, -- 空中
			juggle_hit, -- 追撃
			gound_block, -- 地上ガード
			air_block, -- 空中ガード
		},
		sway_line = {
			gound_hit, -- 地上
			air_hit, -- 空中
			juggle_hit, -- 追撃
			gound_block, -- 地上ガード
			air_block, -- 空中ガード
		},
		counter = {
			jodan_ateminage, -- 上段当身投げ
			urakumo_kaushi,-- 裏雲隠し
			gedan_ateminage,-- 下段当身打ち
			assured_victory_retaliation, -- 必勝！逆襲拳
			sadomazo, -- サドマゾ
			phoenix_throw,-- フェニックススルー
			baigaeshi, -- 倍返し
		},
	}

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
					scr:draw_text(x+12.5, txty+y+ 0.5, disp_name, shadow_col)
					scr:draw_text(x+12  , txty+y     , disp_name, 0xFFC0C0C0)
				end
			end
			-- グループのフレーム数を末尾から描画
			for k = #frame_group, 1, -1 do
				local frame = frame_group[k]
				local x2 = x1 - frame.count
				local on_fb, on_ar, on_gd = false, false, false
				if x2 < xmin then
					if x2 + x1 < xmin and not main_frame then
						break
					end
					x2 = xmin
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
					scr:draw_box(x1, y, x2, y+height, frame.line, frame.col)
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
		return overflow
	end
	local draw_frames = function(frames2, xmax, show_name, show_count, x, y, height, span)
		if #frames2 == 0 then
			return
		end
		local scr = manager.machine.screens:at(1)
		span = span or height
		local txty = math.max(-2, height-8)

		-- 縦に描画
		local x1 = xmax
		if #frames2 < 7 then
			y = y + (7 - #frames2) * span
		end
		for j = #frames2 - math.min(#frames2 - 1, 6), #frames2 do
			local frame_group = frames2[j]
			local overflow = dodraw(x1, y + span, frame_group, true, height, x, xmax, show_name, show_count, x, scr, txty)
		
			for _, frame in ipairs(frame_group) do
				if frame.fireball then
					for _, fb in pairs(frame.fireball) do
						for _, sub_group in ipairs(fb) do
							dodraw(x1, y + 0 + span, sub_group, false, height, x, xmax, show_name, show_count, x+sub_group.parent_count-overflow, scr, txty-1)
						end
					end
				end
				if frame.frm_gap then
					for _, sub_group in ipairs(frame.frm_gap) do
						dodraw(x1, y + 6 + span, sub_group, false, height-3, x, xmax, show_name, show_count, x, scr, txty-1)
					end
				end
				if frame.muteki then
					for _, sub_group in ipairs(frame.muteki) do
						dodraw(x1, y + 11 + span, sub_group, false, height-3, x, xmax, show_name, show_count, x, scr, txty-1)
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
		local scr = manager.machine.screens:at(1)

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
					scr:draw_box (x1, y, x2, y+height, frame.line, frame.col)
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

	do_recover = function(p, op, force)
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		-- 体力とスタン値とMAXスタン値回復
		local life = { 0xC0, 0x60, 0x00 }
		local max_life = life[p.red] or (p.red - #life) -- 赤体力にするかどうか
		if dip_config.infinity_life then
			pgm:write_u8(p.addr.life, max_life)
			pgm:write_u8(p.addr.max_stun,  p.init_stun) -- 最大スタン値 
			pgm:write_u8(p.addr.init_stun, p.init_stun) -- 最大スタン値
		elseif p.life_rec then
			-- 回復判定して回復
			if force or ((math.max(p.update_dmg, op.update_dmg) + 180) <= global.frame_number and p.state == 0) then
				-- やられ状態から戻ったときに回復させる
				pgm:write_u8(p.addr.life, max_life) -- 体力
				pgm:write_u8(p.addr.stun, 0) -- スタン値
				pgm:write_u8(p.addr.max_stun,  p.init_stun) -- 最大スタン値 
				pgm:write_u8(p.addr.init_stun, p.init_stun) -- 最大スタン値
				pgm:write_u8(p.addr.stun_timer, 0) -- スタン値タイマー
			elseif max_life < p.life then
				-- 最大値の方が少ない場合は強制で減らす
				pgm:write_u8(p.addr.life, max_life)
			end
		end

		-- パワーゲージ回復
		-- 0x3C, 0x1E, 0x00
		local pow = { 0x3C, 0x1E, 0x00 }
		local max_pow  = pow[p.max] or (p.max - #pow) -- パワーMAXにするかどうか
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
	local get_n_throw = function(p, op)
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		local d0, d1, d4, d5, a0_1, a0_2 = 0, 0, 0, 0, 0x5C9BC, 0x5D874
		local char1, char2 = pgm:read_u16(p.addr.base + 0x10), pgm:read_u16(op.addr.base + 0x10)
		local op_pos = op.max_pos or op.min_pos or op.pos -- 投げられ側のX位置は補正前の値
		local p_pos = p.pos                             -- 投げ側のX位置は補正後の値

		d0 = char2                                      -- D0 = 100510アドレスの値(相手のキャラID)
		d0 = 0xFFFF & (d0 << 3)                         -- D0 を3ビット左シフト
		if p.side == op.side then                       -- 自分の向きと相手の向きが違ったら
			d0 = pgm:read_u8(0x4 + a0_1 + d0)           -- D0 = A0+4+D0アドレスのデータ(0x5CAC3~)
		else                                            -- 自分の向きと相手の向きが同じなら
			d0 = pgm:read_u8(0x3 + a0_1 + d0)           -- D0 = A0+3+D0アドレスのデータ(0x5CABB~)
		end
		d0 = 0xFF00 + d0
		if 0 > op.side then                             -- 位置がマイナスなら
			d0 = 0x10000 - d0                           -- NEG
		end
		d0 = 0xFFFF & (d0 + d0)                         -- 2倍値に
		d0 = 0xFFFF & (d0 + d0)                         -- さらに2倍値に
		d1 = op_pos                                     -- D1 = 相手のX位置
		d1 = 0xFFFF & (d1 - d0)                         -- 相手との距離計算
		local op_d0 = d0                                -- 投げ間合いの補正値
		local op_d1 = d1

		d5 = char1                                      -- D5 = 100410アドレスの値(キャラID)
		d5 = 0xFFFF & (d5 << 3)                         -- D5 = D5を3ビット左シフト
		d5 = pgm:read_u8(0x3 + a0_1 + d5)               -- D5 = 3+A0+D5アドレスのデータ
		d5 = 0xFF00 + d5
		if 0 > p.side then                              -- 位置がマイナスなら
			d5 = 0x10000 - d5                           -- NEG
		end
		d5 = 0xFFFF & (d5 + d5)                         -- 2倍値に
		d5 = 0xFFFF & (d5 + d5)                         -- さらに2倍値に
		d0 = p_pos                                      -- 自分のX位置
		d0 = 0xFFFF & (d0 - d5)                         -- 投げ間合いの限界距離
		local p_d0 = d0

		d0 = d1 > d0 and (d1 - d0) or (d0 - d1)         -- D1(相手との距離) と D0 を比較して差分算出
		d0 = 0xFFFF & d0
		local gap = d0

		local d1 = char1
		d1 = 0xFFFF & (d1 + d1)                         -- 2倍値に
		d1 = 0xFFFF & (d1 + d1)                         -- さらに2倍値に
		d4 = pgm:read_u8(a0_2 + d1)                     -- 投げ間合いから相手座標の距離の±許容幅
		local ret = d4 >= d0
		local a = math.abs(op_pos - op_d1)
		if 0 > p.side  then
			p_d0 = p_d0 - a - screen_left
		else
			p_d0 = p_d0 + a - screen_left
		end
		--print(string.format("%x %s %s %s %s %s %s %s", p.addr.base, ret, gap, p_d0, op_d0, d4, p_pos, op_pos))
		-- 投げ間合いセット
		p.throw = {
			x1 = p_d0 - d4,
			x2 = p_d0 + d4,
			half_range = d4,
			full_range = d4 + d4,
			in_range = ret,
		}
	end
	-- 0:攻撃無し 1:ガード継続小 1:ガード継続大
	local get_gd_strength = function(p)
		-- 飛び道具は無視
		if p.addr.base ~= 0x100400 and p.addr.base ~= 0x100500 then
			return 0
		end
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		local char  = pgm:read_u16(p.addr.base + 0x10)
		local char_4times = 0xFFFF & (char + char)
		char_4times = 0xFFFF & (char_4times + char_4times)
		-- 家庭用0271FCからの処理
		local cond1 = pgm:read_u8(p.addr.base + 0xA2) -- ガード判断用 0のときは何もしていない
		local cond2 = pgm:read_u8(p.addr.base + 0xB6) -- ガード判断用 0のときは何もしていない
		local ret = 0
		if cond1 ~= 0 then
			ret = 1
		elseif cond2 ~= 0 then
			--local b1 = 0x80 == (0x80 & pgm:read_u8(pgm:read_u32(0x83C58 + char_4times) + cond2))
			local b2 = 0x80 == (0x80 & pgm:read_u8(pgm:read_u32(0x8C9E2 + char_4times) + cond2))
			ret = b2 and 2 or 1
		end
		-- if ret ~= 0 then
		-- 	print(string.format("%s %x %s",  global.frame_number, p.addr.base, ret))
		-- end
		return ret
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

		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		local scr = manager.machine.screens:at(1)
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
			main_or_menu_state = menu
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

			p.base           = pgm:read_u32(p.addr.base)
			p.char           = pgm:read_u8(p.addr.char)
			p.char_4times    = 0xFFFF & (p.char + p.char)
			p.char_4times    = 0xFFFF & (p.char_4times + p.char_4times)
			p.close_far      = get_close_far_pos(p.char)
			p.close_far_lma  = get_close_far_pos_line_move_attack(p.char)
			p.life           = pgm:read_u8(p.addr.life)                 -- 今の体力
			p.old_state      = p.state                                  -- 前フレームの状態保存
			p.state          = pgm:read_u8(p.addr.state)                -- 今の状態
			p.state_flags    = pgm:read_u32(p.addr.state_flags)        -- フラグ群
			p.last_normal_state = p.normal_state
			p.normal_state   = p.state == 0 -- 素立ち
			p.combo          = tohexnum(pgm:read_u8(p.addr.combo2))     -- 最近のコンボ数
			p.tmp_combo      = tohexnum(pgm:read_u8(p.addr.tmp_combo2)) -- 一次的なコンボ数
			p.max_combo      = tohexnum(pgm:read_u8(p.addr.max_combo2)) -- 最大コンボ数
			p.tmp_dmg        = pgm:read_u8(p.addr.tmp_dmg)              -- ダメージ
			p.attack         = pgm:read_u8(p.addr.attack)
			p.pure_dmg       = pgm:read_u8(p.addr.pure_dmg)             -- ダメージ(フック処理)
			p.tmp_pow        = pgm:read_u8(p.addr.tmp_pow)              -- POWゲージ増加量
			p.tmp_pow_rsv    = pgm:read_u8(p.addr.tmp_pow_rsv)          -- POWゲージ増加量(予約値)
			if p.tmp_pow_rsv > 0 then
				p.tmp_pow_atc = p.attack                                -- POWゲージ増加量(予約時の行動)
			end
			p.tmp_stun       = pgm:read_u8(p.addr.tmp_stun)             -- スタン値
			p.tmp_st_timer   = pgm:read_u8(p.addr.tmp_st_timer)         -- スタンタイマー
			pgm:write_u8(p.addr.tmp_dmg, 0)
			pgm:write_u8(p.addr.pure_dmg, 0)
			pgm:write_u8(p.addr.tmp_pow, 0)
			pgm:write_u8(p.addr.tmp_pow_rsv, 0)
			pgm:write_u8(p.addr.tmp_stun, 0)
			pgm:write_u8(p.addr.tmp_st_timer, 0)
			p.tw_threshold   = pgm:read_u8(p.addr.tw_threshold)
			p.tw_accepted    = pgm:read_u8(p.addr.tw_accepted)
			p.tw_frame       = pgm:read_u8(p.addr.tw_frame)
			p.tw_muteki      = pgm:read_u8(p.addr.tw_muteki)
			-- 通常投げ無敵判断 その2(HOME 039FC6から03A000の処理を再現して投げ無敵の値を求める)
			p.tw_muteki2     = 0
			if 0x70 <= p.attack then
				local d1 = pgm:read_u16(p.addr.base + 0x10)
				d1 = 0xFF & (d1 + d1)
				d1 = 0xFF & (d1 + d1)
				local a0 = pgm:read_u32(d1 + 0x89692)
				local d2 = p.attack - 0x70
				p.tw_muteki2 = pgm:read_u8(a0 + d2)
				--print(string.format("%x", a0 + d2))
			end

			p.old_act        = p.act or 0x00
			p.act            = pgm:read_u16(p.addr.act)
			p.acta           = pgm:read_u16(p.addr.acta)
			p.act_count      = pgm:read_u8(p.addr.act_count)
			p.act_frame      = pgm:read_u8(p.addr.act_frame)
			p.provoke        = 0x0196 == p.act --挑発中
			p.stop           = pgm:read_u8(p.addr.stop)
			p.gd_strength    = get_gd_strength(p)
			p.old_knock_back1= p.knock_back1
			p.old_knock_back2= p.knock_back2
			p.old_knock_back3= p.knock_back3
			p.knock_back1    = pgm:read_u8(p.addr.knock_back1)
			p.knock_back2    = pgm:read_u8(p.addr.knock_back2)
			p.knock_back3    = pgm:read_u8(p.addr.knock_back3)
			p.hitstop_id     = pgm:read_u8(p.addr.hitstop_id)
			if p.attack == 0 then
				p.hitstop    = 0
				p.hitstop_gd = 0
				p.pure_dmg   = 0
				p.pure_st    = 0
				p.pure_st_tm = 0
			else
				p.hitstop    = 0x7F & pgm:read_u8(pgm:read_u32(fix_bp_addr(0x83C38) + p.char_4times) + p.attack)
				p.hitstop    = p.hitstop == 0 and 2 or p.hitstop + 1  -- システムで消費される分を加算
				p.hitstop_gd = math.max(2, p.hitstop - 1) -- ガード時の補正
				-- 補正前ダメージ量取得 家庭用 05B118 からの処理
				p.pure_dmg   = pgm:read_u8(pgm:read_u32(p.char_4times + fix_bp_addr(0x813F0)) + p.attack)
				-- スタン値とスタンタイマー取得 05C1CA からの処理
				p.pure_st    = pgm:read_u8(pgm:read_u32(p.char_4times + fix_bp_addr(0x85CCA)) + p.attack)
				p.pure_st_tm = pgm:read_u8(pgm:read_u32(p.char_4times + fix_bp_addr(0x85D2A)) + p.attack)
			end
			p.fake_hit       = (pgm:read_u8(p.addr.fake_hit) & 0xB) == 0
			p.obsl_hit       = (pgm:read_u8(p.addr.obsl_hit) & 0xB) == 0
			p.full_hit       = pgm:read_u8(p.addr.full_hit) > 0
			p.harmless2      = pgm:read_u8(p.addr.harmless2) == 0
			p.prj_rank       = pgm:read_u8(p.addr.prj_rank)
			p.esaka_range    = nil
			if 0x58 > p.attack then
				-- 家庭用 0236F0 からの処理
				local d1 = pgm:read_u8(p.addr.esaka_range)
				local d0 = pgm:read_u16(pgm:read_u32(p.char_4times + 0x23750) + ((d1 + d1) & 0xFFFF)) & 0x1FFF
				if d0 ~= 0 then
					p.esaka_range = d0
				end
			end
			p.max_hit_dn     = p.attack > 0 and pgm:read_u8(pgm:read_u32(fix_bp_addr(0x827B8) + p.char_4times) + p.attack) or 0
			p.max_hit_nm     = pgm:read_u8(p.addr.max_hit_nm)
			p.last_dmg       = p.last_dmg or 0
			p.last_pow       = p.last_pow or 0
			p.last_pure_dmg  = p.last_pure_dmg or 0
			p.last_stun      = p.last_stun or 0
			p.last_st_timer  = p.last_st_timer or 0
			p.last_effects   = p.last_effects or {}
			p.dmg_scl7       = pgm:read_u8(p.addr.dmg_scl7)
			p.dmg_scl6       = pgm:read_u8(p.addr.dmg_scl6)
			p.dmg_scl5       = pgm:read_u8(p.addr.dmg_scl5)
			p.dmg_scl4       = pgm:read_u8(p.addr.dmg_scl4)
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
			p.old_posd       = p.posd
			p.posd           = pgm:read_i32(p.addr.pos)
			p.poslr          = p.posd == op.posd and "=" or p.posd < op.posd  and "L" or "R"
			p.old_pos        = p.pos
			p.old_pos_frc    = p.pos_frc
			p.pos            = pgm:read_i16(p.addr.pos)
			p.pos_frc        = pgm:read_u16(p.addr.pos_frc)
			p.thrust        = pgm:read_i16(p.addr.base + 0x34) + int16tofloat(pgm:read_u16(p.addr.base + 0x36))
			p.inertia       = pgm:read_i16(p.addr.base + 0xDA) + int16tofloat(pgm:read_u16(p.addr.base + 0xDC))
			p.pos_total     = p.pos + int16tofloat(p.pos_frc)
			p.old_pos_total = p.old_pos + int16tofloat(p.old_pos_frc)
			p.max_pos        = pgm:read_i16(p.addr.max_pos)
			if p.max_pos == 0 or p.max_pos == p.pos then
				p.max_pos = nil
			end
			pgm:write_i16(p.addr.max_pos, 0)
			p.min_pos        = pgm:read_i16(p.addr.min_pos)
			if p.min_pos == 1000 or p.min_pos == p.pos then
				p.min_pos = nil
			end
			pgm:write_i16(p.addr.min_pos, 1000)
			p.old_pos_y      = p.pos_y
			p.old_pos_frc_y  = p.pos_frc_y
			p.old_in_air     = p.in_air
			p.pos_y          = pgm:read_i16(p.addr.pos_y)
			p.pos_frc_y      = pgm:read_u16(p.addr.pos_frc_y)
			p.in_air         = 0 < p.pos_y or 0 < p.pos_frc_y
			p.reach_memo     = ""
			p.reach_tbl      = {}

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
			p.old_pos_z      = p.pos_z
			p.pos_z          = pgm:read_i16(p.addr.pos_z)
			p.on_sway_line   = (40 == p.pos_z and 40 > p.old_pos_z) and global.frame_number or p.on_sway_line
			p.on_main_line   = (24 == p.pos_z and 24 < p.old_pos_z) and global.frame_number or p.on_main_line
			p.sway_status    = pgm:read_u8(p.addr.sway_status) -- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
			if p.sway_status == 0x00 then
				p.in_sway_line = false
			else
				p.in_sway_line = true
			end
			p.side           = pgm:read_i8(p.addr.side) < 0 and -1 or 1

			p.life           = pgm:read_u8(p.addr.life)
			p.pow            = pgm:read_u8(p.addr.pow)
			p.init_stun      = init_stuns[p.char]
			p.max_stun       = pgm:read_u8(p.addr.max_stun)
			p.stun           = pgm:read_u8(p.addr.stun)
			p.stun_timer     = pgm:read_u16(p.addr.stun_timer)
			p.act_contact    = pgm:read_u8(p.addr.act_contact)
			p.ophit_base     = pgm:read_u32(p.addr.ophit_base)
			p.ophit          = nil
			if p.ophit_base == 0x100400 or p.ophit_base == 0x100500 then
				p.ophit = op
			else
				p.ophit = op.fireball[p.ophit_base]
			end

			--フレーム数
			p.frame_gap      = p.frame_gap or 0
			p.last_frame_gap = p.last_frame_gap or 0
			p.last_blockstun = p.last_blockstun or 0
			p.last_hitstop   = p.last_hitstop   or 0
			p.on_hit         = p.on_hit or 0
			p.on_guard       = p.on_guard or 0
			p.hit_skip       = p.hit_skip or 0
			if mem_0x10B862 ~= 0 and p.act_contact ~= 0 then
				if p.state == 2 then
					p.on_guard = global.frame_number
					--print(string.format("on guard %x" , p.act))
				elseif p.state == 1 or p.state == 3 then
					p.on_hit = global.frame_number
				end
				p.hit_skip = 2
			end

			-- 起き上がりフレーム
			if wakeup_acts[p.old_act] ~= true and wakeup_acts[p.act] == true then
				p.on_wakeup = global.frame_number
			end
			-- ダウンフレーム
			if (down_acts[p.old_act] ~= true and down_acts[p.act] == true) or
				(p.old_in_air ~= true and p.in_air == true and down_acts[p.act] == true) then
				p.on_down = global.frame_number
			end
			-- フレーム表示用処理
			p.act_frames     = p.act_frames  or {}
			p.act_frames2    = p.act_frames2 or {}
			p.act_frames_total = p.act_frames_total or 0

			p.muteki.act_frames    = p.muteki.act_frames   or {}
			p.muteki.act_frames2   = p.muteki.act_frames2  or {}
			p.frm_gap.act_frames   = p.frm_gap.act_frames  or {}
			p.frm_gap.act_frames2  = p.frm_gap.act_frames2 or {}

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
			if p.act_data.name == "やられ" then
				p.act_1st    = false
			elseif p.act_data.name ~= "ダウン" and (p.state == 1 or p.state == 3) then
				p.act_data   = {
					name     = "やられ",
					type     = act_types.any,
				}
				p.act_1st    = false
			end
			p.old_act_normal = p.act_normal
			p.act_normal     = p.act_data.type == act_types.free

			-- アドレス保存
			if not p.bases[#p.bases] or p.bases[#p.bases].addr ~= p.base then
				table.insert(p.bases, {
					addr     = p.base,
					count    = 1,
					act_data = p.act_data,
					name     = get_act_name(p.act_data),
					pos1     = p.pos_total,
					pos2     = p.pos_total,
					xmov     = 0,
				} )
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
				fb.act            = pgm:read_u16(fb.addr.act)
				fb.acta           = pgm:read_u16(fb.addr.acta)
				fb.actb           = pgm:read_u16(fb.addr.actb)
				fb.act_count      = pgm:read_u8(fb.addr.act_count)
				fb.act_frame      = pgm:read_u8(fb.addr.act_frame)
				fb.act_contact    = pgm:read_u8(fb.addr.act_contact)
				fb.pos            = pgm:read_i16(fb.addr.pos)
				fb.pos_y          = pgm:read_i16(fb.addr.pos_y)
				fb.reach_memo     = ""
				fb.reach_tbl      = {}
				fb.pos_z          = pgm:read_i16(fb.addr.pos_z)
				fb.hit.projectile = true
				fb.gd_strength    = get_gd_strength(fb)
				fb.asm            = pgm:read_u16(pgm:read_u32(fb.addr.base))
				fb.attack         = pgm:read_u16(pgm:read_u32(fb.addr.attack))
				fb.hitstop_id     = pgm:read_u16(fb.addr.hitstop_id)
				if fb.hitstop_id == 0 then
					fb.hitstop    = 0
					fb.hitstop_gd = 0
					fb.pure_dmg   = 0
					fb.pure_st    = 0
					fb.pure_st_tm = 0
				else
					-- ヒットストップ取得 家庭用 061656 からの処理
					fb.hitstop    = pgm:read_u8(fb.hitstop_id + fix_bp_addr(0x884F2))
					fb.hitstop    = fb.hitstop == 0 and 2 or fb.hitstop + 1 -- システムで消費される分を加算
					fb.hitstop_gd = math.max(2, fb.hitstop - 1) -- ガード時の補正
					-- 補正前ダメージ量取得 家庭用 05B146 からの処理
					fb.pure_dmg   = pgm:read_u8(fb.hitstop_id + fix_bp_addr(0x88472))
					-- スタン値とスタンタイマー取得 家庭用 05C1B0 からの処理
					fb.pure_st    = pgm:read_u8(fb.hitstop_id + fix_bp_addr(0x886F2))
					fb.pure_st_tm = pgm:read_u8(fb.hitstop_id + fix_bp_addr(0x88772))
				end
				fb.fake_hit       = (pgm:read_u8(fb.addr.fake_hit) & 0xB) == 0
				fb.obsl_hit       = (pgm:read_u8(fb.addr.obsl_hit) & 0xB) == 0
				fb.full_hit       = pgm:read_u8(fb.addr.full_hit ) > 0
				fb.harmless2      = pgm:read_u8(fb.addr.harmless2) > 0
				fb.prj_rank       = pgm:read_u8(fb.addr.prj_rank)

				--[[
				倍返しチェック
				05C8CE: 0C2B 0002 008A           cmpi.b  #$2, ($8a,A3)        -- 10078A と 0x2 を比較     飛翔拳は03
				05C8D4: 6D1A                     blt     $5c8f0               -- 小さかったら 5c8f0 へ
				05C8D6: 41F9 0008 E940           lea     $8e940.l, A0         -- A0 = 8e940
				05C8DC: 0C6C 000B 0010           cmpi.w  #$b, ($10,A4)        -- 100410 と 0xB を比較 山崎かどうかチェック
				05C8E2: 6618                     bne     $5c8fc               -- 違ったら 5c8fc へ
				05C8E4: 302B 00BE                move.w  ($be,A3), D0         -- D0 = 1007BE              飛翔拳は09
				05C8E8: D040                     add.w   D0, D0               -- D0 = D0 + D0
				05C8EA: 4A30 0000                tst.b   (A0,D0.w)            -- 8e940 + D0 の値チェック  データテーブルチェック 8e940 飛翔拳は01
				05C8EE: 6754                     beq     $5c944               -- 0だったら 5c944 へ
				]]
				fb.bai_chk1       = pgm:read_u8(fb.addr.bai_chk1)
				fb.bai_chk2       = pgm:read_u16(fb.addr.bai_chk2)
				fb.bai_chk2       = pgm:read_u8(0x8E940 + (0xFFFF & (fb.bai_chk2 + fb.bai_chk2)))
				fb.bai_catch      = 0x2 >= fb.bai_chk1 and fb.bai_chk2 == 0x01

				fb.max_hit_dn     = pgm:read_u8(fix_bp_addr(0x885F2) + fb.hitstop_id)
				fb.max_hit_nm     = pgm:read_u8(fb.addr.max_hit_nm)
				fb.hitboxes       = {}
				fb.buffer         = {}
				fb.act_data_fired = p.act_data -- 発射したタイミングの行動ID

				fb.act_frames     = fb.act_frames  or {}
				fb.act_frames2    = fb.act_frames2 or {}

				-- 当たり判定の構築
				if fb.asm ~= 0x4E75 then --0x4E75 is rts instruction
					temp_hits[fb.addr.base] = fb
					fb.count = (fb.count or 0) +1
					fb.atk_count = fb.atk_count or 0
				else
					fb.count      = 0
					fb.atk_count  = 0
					fb.hitstop    = 0
					fb.pure_dmg   = 0
					fb.pure_st    = 0
					fb.pure_st_tm = 0
				end
				--[[
				if fb.asm ~= 0x4E75 then
					print(string.format("%x %1s  %2x(%s) %2x(%s) %2x(%s)",
						fb.addr.base,
						(fb.obsl_hit or fb.full_hit  or fb.harmless2) and " " or "H",
						pgm:read_u8(fb.addr.obsl_hit),
						fb.obsl_hit and "o" or "-",
						pgm:read_u8(fb.addr.full_hit),
						fb.full_hit  and "o" or "-",
						pgm:read_u8(fb.addr.harmless2),
						fb.harmless2 and "o" or "-"))
				end
				]]
				--if fb.hitstop > 0 then
				--	print(string.format("%x:2 hit:%s gd:%s", fb.addr.base, fb.hitstop, math.max(2, fb.hitstop-1)))
				--end
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

			-- リーチ
			p.hit.reach_edge   = {}

			-- 投げ判定取得
			get_n_throw(p, op)
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
			p.n_throw.pos_x    = pgm:read_i16(p.n_throw.addr.pos_x) - screen_left
			p.n_throw.pos_y    = height - pgm:read_i16(p.n_throw.addr.pos_y) + screen_top
			local range = (p.n_throw.range1 == p.n_throw.range2 and math.abs(p.n_throw.range42*4)) or math.abs(p.n_throw.range41*4)
			range = range + p.n_throw.range5 * -4
			range = range + p.throw.half_range
			p.n_throw.range    = range
			p.n_throw.right    = p.n_throw.range * p.side
			p.n_throw.left     = (p.n_throw.range - p.throw.full_range) * p.side
			p.n_throw.type     = box_type_base.t
			p.n_throw.on = p.addr.base == p.n_throw.base and p.n_throw.on or 0xFF

			-- 空中投げ判定取得
			p.air_throw.left     = nil
			p.air_throw.right    = nil
			p.air_throw.on       = pgm:read_u8(p.air_throw.addr.on)
			p.air_throw.range_x  = pgm:read_i16(p.air_throw.addr.range_x)
			p.air_throw.range_y  = pgm:read_i16(p.air_throw.addr.range_y)
			p.air_throw.base     = pgm:read_u32(p.air_throw.addr.base)
			p.air_throw.opp_base = pgm:read_u32(p.air_throw.addr.opp_base)
			p.air_throw.opp_id   = pgm:read_u16(p.air_throw.addr.opp_id)
			p.air_throw.pos_x    = pgm:read_i16(p.air_throw.addr.pos_x) - screen_left
			p.air_throw.pos_y    = height - pgm:read_i16(p.air_throw.addr.pos_y) + screen_top
			p.air_throw.side     = p.side
			p.air_throw.right    = p.air_throw.range_x * p.side
			p.air_throw.top      = -p.air_throw.range_y
			p.air_throw.bottom   =  p.air_throw.range_y
			p.air_throw.type     = box_type_base.at
			p.air_throw.on = p.addr.base == p.air_throw.base and p.air_throw.on or 0xFF

			-- 必殺投げ判定取得
			p.sp_throw.left      = nil
			p.sp_throw.right     = nil
			p.sp_throw.top       = nil
			p.sp_throw.bottom    = nil
			p.sp_throw.on        = pgm:read_u8(p.sp_throw.addr.on)
			p.sp_throw.front     = pgm:read_i16(p.sp_throw.addr.front)
			p.sp_throw.top       = -pgm:read_i16(p.sp_throw.addr.top)
			p.sp_throw.base      = pgm:read_u32(p.sp_throw.addr.base)
			p.sp_throw.opp_base  = pgm:read_u32(p.sp_throw.addr.opp_base)
			p.sp_throw.opp_id    = pgm:read_u16(p.sp_throw.addr.opp_id)
			p.sp_throw.side      = p.side
			p.sp_throw.bottom    = pgm:read_i16(p.sp_throw.addr.bottom)
			p.sp_throw.pos_x     = pgm:read_i16(p.sp_throw.addr.pos_x) - screen_left
			p.sp_throw.pos_y     = height - pgm:read_i16(p.sp_throw.addr.pos_y) + screen_top
			p.sp_throw.right     = p.sp_throw.front * p.side
			p.sp_throw.type      = box_type_base.pt
			p.sp_throw.on        = p.addr.base == p.sp_throw.base and p.sp_throw.on or 0xFF
			if p.sp_throw.top == 0 then
				p.sp_throw.top    = nil
				p.sp_throw.bottom = nil
			end
			if p.sp_throw.on ~= 0xFF then
				--print(i, p.sp_throw.on, p.sp_throw.top, p.sp_throw.bottom, p.sp_throw.front, p.sp_throw.side, p.hit.flip_x)
			end

			-- 当たり判定の構築用バッファのリフレッシュ
			p.hitboxes, p.buffer = {}, {}
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
					if char_fireballs[p.char][fb.act] then
						-- 双角だけ中段と下段の飛び道具がある
						act_type = char_fireballs[p.char][fb.act].type
						fb.char_fireball = char_fireballs[p.char][fb.act]
					end
					op.need_block     = op.need_block or (act_type == act_types.low_attack) or (act_type == act_types.attack) or (act_type == act_types.overhead)
					op.need_low_block = op.need_low_block or (act_type == act_types.low_attack)
					op.need_ovh_block = op.need_ovh_block or (act_type == act_types.overhead)
					--print(string.format("%x %s", fb.act, act_type)) -- debug
				end
			end
		end

		-- キャラと飛び道具の当たり判定取得
		for addr = 0x10CB41, 0x10CB41 + pgm:read_u8(0x10CB40) * 0x10, 0x10 do
			local box = {
				on          = pgm:read_u8(addr),
				id          = pgm:read_u8(addr+0x1),
				top         = pgm:read_i8(addr+0x2),
				bottom      = pgm:read_i8(addr+0x3),
				left        = pgm:read_i8(addr+0x4),
				right       = pgm:read_i8(addr+0x5),
				base        = pgm:read_u32(addr+0x6),
				attack_only = (pgm:read_u8(addr+0xA) == 1),
				attack_only_val = pgm:read_u8(addr+0xA),
				pos_x       = pgm:read_i16(addr+0xC) - screen_left,
				pos_y       = height - pgm:read_i16(addr+0xE) + screen_top,
			}
			if box.on ~= 0xFF and temp_hits[box.base] then
				box.is_fireball = temp_hits[box.base].is_fireball == true
				table.insert(temp_hits[box.base].buffer, box)
			else
				--print("DROP " .. box.key) --debug
			end
		end
		for _, p in pairs(temp_hits) do
			-- キャラと飛び道具への当たり判定の反映
			-- update_objectはキャラの位置情報と当たり判定の情報を読み込んだ後で実行すること
			update_object(p)
		end

		for i, p in ipairs(players) do
			local op         = players[3-i]

			--フレーム数
			p.frame_gap      = p.frame_gap or 0
			p.last_frame_gap = p.last_frame_gap or 0
			if mem_0x10B862 ~= 0 and p.act_contact ~= 0 then
				local hitstun, blockstun = 0, 0
				if p.ophit and p.ophit.hitboxes then
					for _, box in pairs(p.ophit.hitboxes) do
						if box.type.type == "attack" then
							hitstun, blockstun = box.hitstun, box.blockstun
							break
						end
					end
				end
				if p.on_guard == global.frame_number then
					if p.ophit then
						p.last_blockstun = blockstun + p.ophit.hitstop_gd
					end
					p.last_hitstop = p.ophit.hitstop_gd
				elseif p.on_hit == global.frame_number then
					if p.ophit then
						p.last_blockstun = hitstun + p.ophit.hitstop
					end
					p.last_hitstop = p.ophit.hitstop
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
			if p.last_blockstun > 0 then
				p.last_blockstun = p.last_blockstun - 1
			end
			if p.last_hitstop > 0 then
				p.last_hitstop = p.last_hitstop - 1
			end
		end
		
		for i, p in ipairs(players) do
			-- 無敵表示
			p.muteki.type = 0 -- 無敵
			p.vul_hi, p.vul_lo = 240, 0
			for _, box in pairs(p.hitboxes) do
				if box.type.type == "vuln" then
					p.muteki.type = 3
					if box.top < box.bottom then
						p.vul_hi = math.min(p.vul_hi, box.top-screen_top)
						p.vul_lo = math.max(p.vul_lo, box.bottom-screen_top)
					else
						p.vul_hi = math.min(p.vul_hi, box.bottom-screen_top)
						p.vul_lo = math.max(p.vul_lo, box.top-screen_top)
					end
				end
			end
			if p.in_sway_line then
				p.muteki.type = 4 -- スウェー上
			elseif p.muteki.type == 0 then
				p.muteki.type = 0 -- 全身無敵
			elseif 152 <= p.vul_hi and p.in_air ~= true then -- 152 ローレンス避け 156 兄龍転身 168 その他避け
				p.muteki.type = 1 -- 上半身無敵（地上）
			elseif p.vul_lo <= 172 and p.in_air ~= true then -- 160 164 168 172 ダブルローリング サイドワインダー
				p.muteki.type = 2 -- 足元無敵（地上）
			else
				p.muteki.type = 3
			end

			--停止演出のチェック
			p.old_skip_frame = p.skip_frame
			p.skip_frame = p.hit_skip ~= 0 or p.stop ~= 0 or mem_0x10D4EA ~= 0

			--[[調査用ログ
			local printdata = function()
				print(string.format("%2x %2s %2s %2s %2s %2s %2s %2x %2s %2s %2x", 
				p.state,                  --1
				p.stop,                   --2 0x10058D
				pgm:read_u8(0x100569), 
				p.stop                & pgm:read_u8(0x10054c), --  2 24
				pgm:read_u8(0x100569) & pgm:read_u8(0x100550), --  4 25
				pgm:read_u8(0x100516),  -- 17 25
				p.pos_z,
				p.knock_back3,
				p.on_sway_line,
				p.on_main_line,
				p.act
				))
			end
			if p.state == 1 or p.state == 2 or p.state == 3 then
				if p.old_state ~= p.state then
					print("--")
				end
				printdata()
			elseif p.old_state == 1 or p.old_state == 2 or p.old_state == 3 then
				printdata()
			end
			]]

			if p.hit_skip ~= 0 or mem_0x10D4EA ~= 0 then
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
				p.guard1 = 0
			elseif p.on_guard == global.frame_number then
				p.guard1 = 1 -- 1ガード確定
			end
			-- 停止時間なしのヒットガードのためelseifで繋げない
			if (p.guard1 == 1 and p.skip_frame == false) or (p.state == 2 and p.old_skip_frame == true and p.skip_frame == false) then
				p.guard1 = 2 -- ガード後のヒットストップ解除フレームの記録
				p.on_guard1 = global.frame_number
			end
		end

		if global.log.baselog or global.log.keylog or global.log.poslog then
			local p1, p2 = players[1], players[2]
			local log1, log2 = string.format("P1 %s ", get_act_name(p1.act_data)), string.format("P2 %s ", get_act_name(p2.act_data))

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

		for _, p in ipairs(players) do
			-- リバーサルのランダム選択
			p.dummy_rvs = nil
			if p.dummy_bs_chr == p.char then
				if p.dummy_wakeup == wakeup_type.rvs and #p.dummy_rvs_list > 0 then
					p.dummy_rvs = p.dummy_rvs_list[math.random(#p.dummy_rvs_list)]
				end
			end
			-- ブレイクショットのランダム選択
			p.dummy_bs = nil
			if p.dummy_rvs_chr == p.char then
				if p.dummy_gd == dummy_gd_type.bs and #p.dummy_bs_list > 0 then
					if p.state == 2 and p.skip_frame then
						p.dummy_bs = p.dummy_bs_list[math.random(#p.dummy_bs_list)]
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
					--print(string.format("bshook %s %x %x %x", global.frame_number, p.act, bs_hook.id or 0x20, bs_hook.ver or 0x0600))
				else
					pgm:write_u8(p.addr.bs_hook1, 0x00)
					pgm:write_u16(p.addr.bs_hook2, 0x0600)
					pgm:write_u8(p.addr.bs_hook3, 0xFF)
					-- print(string.format("bshook %s %x %x %x", global.frame_number, 0x20, 0x0600))
				end
			end
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

			-- 飛び道具
			local chg_fireball_state = false
			local fb_upd_groups, fb_atk = {}, {}
			for fb_base, fb in pairs(p.fireball) do
				fb_atk[fb_base] = false -- 攻撃判定 発生中
				for _, box in pairs(fb.hitboxes) do
					fb_atk [fb_base] = box.asm ~= 0x4E75
					if fb_atk[fb_base] then
						fb.atk_count = (fb.atk_count or 0) + 1 -- 攻撃判定発生のカウント
						if fb.atk_count == 1 and get_act_name(fb.act_data_fired) == get_act_name(p.act_data) then
							chg_fireball_state = true
						end
						break
					end
				end
			end

			--ガード移行できない行動は色替えする
			local col, line = 0xAAF0E68C, 0xDDF0E68C
			if p.skip_frame then
				col, line = 0xAA888888, 0xDD888888
			elseif p.attacking then
				col, line = 0xAAFF1493, 0xDDFF1493
			elseif p.throwing then
				col, line = 0xAAD2691E, 0xDDD2691E
			elseif p.act_normal then
				col, line = 0x44FFFFFF, 0xDDFFFFFF
			end

			local reach_memo = p.reach_memo or ""
			local act_count  = p.act_count  or 0
			local max_hit_dn = p.attacking and p.hit.max_hit_dn or 0

			-- 行動が変わったかのフラグ
			local frame = p.act_frames[#p.act_frames]
			--[[
			local chg_act_name = (p.old_act_data.name ~= p.act_data.name)
			local disp_name = convert(p.act_data.disp_name or p.act_data.name)
			]]
			local concrete_name, chg_act_name, disp_name
			if frame ~= nil then
				if p.act_data.names then
					chg_act_name = true
					for _, name in pairs(p.act_data.names) do
						if frame.name == name then
							chg_act_name = false
							concrete_name = frame.name
							disp_name = frame.disp_name
							p.act_1st = false
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
			if #p.act_frames == 0 or chg_act_name or frame.col ~= col or p.chg_air_state ~= 0 or chg_fireball_state == true or p.act_1st or frame.reach_memo ~= reach_memo  or (max_hit_dn > 1 and frame.act_count ~= act_count) then
				--行動IDの更新があった場合にフレーム情報追加
				frame = {
					act = p.act,
					count = 1,
					col = col,
					name = concrete_name,
					disp_name = disp_name,
					line = line,
					chg_fireball_state = chg_fireball_state,
					chg_air_state = p.chg_air_state,
					act_1st = p.act_1st,
					reach_memo = reach_memo,
					act_count = act_count,
					max_hit_dn = max_hit_dn,
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
			if p.muteki.type == 4 then -- スウェー上
				col, line = 0xAAFFA500, 0xDDAFEEEE
			elseif p.muteki.type == 0 then -- 全身無敵
				col, line = 0xAAB0E0E6, 0xDDAFEEEE
			elseif p.muteki.type == 1 then -- 上半身無敵（地上）
				col, line = 0xAA32CD32, 0xDDAFEEEE
			elseif p.muteki.type == 2 then -- 足元無敵（地上）
				col, line = 0xAA9400D3, 0xDDAFEEEE
			else
				col, line = 0x00000000, 0x00000000
			end
			--print(string.format("top %s, hi %s, lo %s", screen_top, vul_hi, vul_lo))

			frame = p.muteki.act_frames[#p.muteki.act_frames]
			if frame == nil or chg_act_name or frame.col ~= col or p.state ~= p.old_state or p.act_1st then
				--行動IDの更新があった場合にフレーム情報追加
				frame = {
					act = p.act,
					count = 1,
					col = col,
					name = concrete_name,
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
				if not p.old_act_normal and not op.old_act_normal then
					p.last_frame_gap = 0
				end
				p.frame_gap = 0
				col, line = 0x00000000, 0x00000000
			elseif not p.act_normal and not op.act_normal then
				if p.state == 0 and op.state ~= 0 then
					p.frame_gap = p.frame_gap + 1
					p.last_frame_gap = p.frame_gap
					col, line = 0xAA0000FF, 0xDD0000FF
				elseif p.state ~= 0 and op.state == 0 then
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
					name = concrete_name,
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

			-- 飛び道具2
			for fb_base, fb in pairs(p.fireball) do
				local frame = fb.act_frames[#fb.act_frames]
				local reset, new_name, hasbox = false, get_act_name(fb.act_data_fired), false
				for _, _ in ipairs(fb.hitboxes) do
					hasbox = true
					break
				end
				if p.act_data.firing then
					if p.act_1st then
						reset = true
					elseif not frame or frame.name ~= get_act_name(fb.act_data_fired) then
						reset = true
					end
				elseif fb.act == 0 and (not frame or frame.name ~= "") then
					reset = true
					new_name = ""
				end
				local col, line, act
				if p.skip_frame then
					col, line, act = 0x00000000, 0x00000000, 0
				elseif hasbox and fb.obsl_hit or fb.full_hit or fb.harmless2 then
					col, line, act = 0x00000000, 0xDDFF1493, 0
				elseif hasbox and fb.fake_hit then
					col, line, act = 0xAA00FF33, 0xDD00FF33, 2
				elseif fb_atk[fb_base] then
					col, line, act = 0xAAFF1493, 0xDDFF1493, 1
				else
					col, line, act = 0x00000000, 0x00000000, 0
				end

				local reach_memo = fb.reach_memo
				local act_count  = fb.actb
				local max_hit_dn = fb.hit.max_hit_dn

				if #fb.act_frames == 0 or (frame == nil) or frame.col ~= col or reset or frame.reach_memo ~= reach_memo  or (max_hit_dn > 1 and frame.act_count ~= act_count)  then
					-- 軽量化のため攻撃の有無だけで記録を残す
					frame = {
						act = act,
						count = 1,
						col = col,
						name = new_name,
						line = line,
						act_1st = reset,
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
				if fb_upd_group then
					last_frame.fireball = last_frame.fireball or {}
					last_frame.fireball[fb_base] = last_frame.fireball[fb_upd_group] or {}
					local last_fb_frame = last_frame.fireball[fb_base]
					table.insert(last_fb_frame, p.fireball[fb_base].act_frames2[# p.fireball[fb_base].act_frames2])
					last_fb_frame[#last_fb_frame].parent_count = last_frame.last_total
				end
			end
		end
		--1Pと2Pともにフレーム数が多すぎる場合は加算をやめる
		fix_max_framecount()

		for i, p in ipairs(players) do
			local p1 = i == 1
			local op = players[3-i]

			-- 入力表示用の情報構築
			local key_now = p.key_now
			key_now.d  = (p.reg_pcnt & 0x80) == 0x00 and posi_or_pl1(key_now.d ) or nega_or_mi1(key_now.d ) -- Button D
			key_now.c  = (p.reg_pcnt & 0x40) == 0x00 and posi_or_pl1(key_now.c ) or nega_or_mi1(key_now.c ) -- Button C
			key_now.b  = (p.reg_pcnt & 0x20) == 0x00 and posi_or_pl1(key_now.b ) or nega_or_mi1(key_now.b ) -- Button B
			key_now.a  = (p.reg_pcnt & 0x10) == 0x00 and posi_or_pl1(key_now.a ) or nega_or_mi1(key_now.a ) -- Button A
			key_now.rt = (p.reg_pcnt & 0x08) == 0x00 and posi_or_pl1(key_now.rt) or nega_or_mi1(key_now.rt) -- Right
			key_now.lt = (p.reg_pcnt & 0x04) == 0x00 and posi_or_pl1(key_now.lt) or nega_or_mi1(key_now.lt) -- Left
			key_now.dn = (p.reg_pcnt & 0x02) == 0x00 and posi_or_pl1(key_now.dn) or nega_or_mi1(key_now.dn) -- Down
			key_now.up = (p.reg_pcnt & 0x01) == 0x00 and posi_or_pl1(key_now.up) or nega_or_mi1(key_now.up) -- Up
			key_now.sl = (p.reg_st_b & (p1 and 0x02 or 0x08)) == 0x00 and posi_or_pl1(key_now.sl) or nega_or_mi1(key_now.sl) -- Select
			key_now.st = (p.reg_st_b & (p1 and 0x01 or 0x04)) == 0x00 and posi_or_pl1(key_now.st) or nega_or_mi1(key_now.st) -- Start
			local lever
			if (p.reg_pcnt & 0x05) == 0x00 then
				lever = "_7"
			elseif (p.reg_pcnt & 0x09) == 0x00 then
				lever = "_9"
			elseif (p.reg_pcnt & 0x06) == 0x00 then
				lever = "_1"
			elseif (p.reg_pcnt & 0x0A) == 0x00 then
				lever = "_3"
			elseif (p.reg_pcnt & 0x01) == 0x00 then
				lever = "_8"
			elseif (p.reg_pcnt & 0x02) == 0x00 then
				lever = "_2"
			elseif (p.reg_pcnt & 0x04) == 0x00 then
				lever = "_4"
			elseif (p.reg_pcnt & 0x08) == 0x00 then
				lever = "_6"
			else
				lever = "_N"
			end
			if (p.reg_pcnt & 0x10) == 0x00 then
				lever = lever .. "_A"
			end
			if (p.reg_pcnt & 0x20) == 0x00 then
				lever = lever .. "_B"
			end
			if (p.reg_pcnt & 0x40) == 0x00 then
				lever = lever .. "_C"
			end
			if (p.reg_pcnt & 0x80) == 0x00 then
				lever = lever .. "_D"
			end
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
			--if p.hitstop > 0 then
			--	print(string.format("%x:%s hit:%s gd:%s %s %s", p.addr.base, p.hitstop, p.hitstop, math.max(2, p.hitstop-1), p.dmg_scaling, p.tmp_dmg))
			--end
			if p.tmp_pow_rsv > 0 then
				p.tmp_pow = p.tmp_pow + p.tmp_pow_rsv
			end
			if p.tmp_pow > 0 then
				p.last_pow = p.tmp_pow
				-- TODO: 大バーン→クラックシュートみたいな繋ぎのときにちゃんと加算されない
				if p.last_normal_state == true and p.normal_state == true  then
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
			end

			do_recover(p, op)
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
						if not p.in_sway_line and p.state == 0 then
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
					if jump_acts[p.act] then
						next_joy["P" .. p.control .. " Up"] = false
					end
					if p.dummy_gd == dummy_gd_type.fixed then
						-- 常時（ガード方向はダミーモードに従う）
						next_joy[p.block_side] = true
						p.backstep_killer = true
					elseif p.dummy_gd == dummy_gd_type.auto or -- オート
						p.dummy_gd == dummy_gd_type.bs or -- ブレイクショット
						(p.dummy_gd == dummy_gd_type.random and p.random_boolean) or -- ランダム
						(p.dummy_gd == dummy_gd_type.hit1 and p.next_block) or -- 1ヒットガード
						(p.dummy_gd == dummy_gd_type.guard1) -- 1ガード
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
						if p.dummy_gd == dummy_gd_type.guard1 and p.next_block ~= true then
							-- 1ガードの時は連続ガードの上下段のみ対応させる
							next_joy[p.block_side] = false
							p.backstep_killer = false
						else
							next_joy[p.block_side] = true
						end
					end
				else
					if p.backstep_killer then
 						next_joy["P" .. p.control .. " Down"] = true
						p.backstep_killer = false
					end
				end

				-- 次のガード要否を判断する
				if p.dummy_gd == dummy_gd_type.hit1 then
					-- 1ヒットガードのときは次ガードすべきかどうかの状態を切り替える
					if global.frame_number == p.on_hit then
						p.next_block = true	-- ヒット時はガードに切り替え
						p.next_block_ec = 75 -- カウンター初期化
					elseif global.frame_number == p.on_guard then
						p.next_block = false
					end
					if p.next_block == false then
						-- カウンター消費しきったらヒットするように切り替える
						p.next_block_ec = p.next_block_ec and (p.next_block_ec - 1) or 0
						if p.next_block_ec == 0 then
							p.next_block = false
						end
					end
				elseif p.dummy_gd == dummy_gd_type.guard1 then
					if p.guard1 == 0 and p.next_block_ec == 75 then
						p.next_block = true
						--print("guard0")
					elseif p.guard1 == 1 then
						p.next_block = true
						p.next_block_ec = 75 -- カウンター初期化
						--print("guard1")
					elseif p.guard1 == 2 and global.frame_number <= (p.on_guard1 + global.next_block_grace) then
						p.next_block = true
						--print("in grace")
					else
						-- カウンター消費しきったらガードするように切り替える
						p.next_block_ec = p.next_block_ec and (p.next_block_ec - 1) or 0
						if p.next_block_ec == 0 then
							p.next_block = true
							p.next_block_ec = 75 -- カウンター初期化
							p.guard1 = 0
							--print("reset")
						elseif global.frame_number == p.on_guard then
							p.next_block_ec = 75 -- カウンター初期化
							p.next_block = false
							--print("countdown " .. p.next_block_ec)
						else
							p.next_block = false
							--print("countdown " .. p.next_block_ec)
						end
					end
					if global.frame_number == p.on_hit then
						-- ヒット時はガードに切り替え
						p.next_block = true	
						p.next_block_ec = 75 -- カウンター初期化
						p.guard1 = 0
						--print("HIT reset")
					end
					--print((p.next_block and "G" or "-") .. " " .. p.next_block_ec .. " " .. p.state .. " " .. op.old_state)
				end

				--挑発中は前進
				if p.fwd_prov and op.provoke then
					next_joy[p.front_side] = true
				end

				local input_bs = function()
					p.write_bs_hook(p.dummy_bs)
				end
				local input_rvs = function(rvs_type, logtxt)
					if global.log.rvslog and logtxt then
						print(logtxt)
					end
					-- set_step(p, true)
					if p.dummy_rvs.throw then
						if op.in_air then
							return
						end
						if p.dummy_rvs.cmd and p.throw.in_range and op.sway_status == 0x00 then
						else
							return
						end
					end
					if p.dummy_rvs.cmd then
						if rvs_types.knock_back_recovery ~= rvs_type then
							p.dummy_rvs.cmd(p, next_joy)
						end
					else
						p.write_bs_hook(p.dummy_rvs)
					end
				end

				-- print(p.state, p.knock_back1, p.knock_back2, p.knock_back3, p.stop, rvs_types.in_knock_back, p.last_blockstun, string.format("%x", p.act), p.act_count, p.act_frame)
				-- ヒットストップ中は無視
				if not p.skip_frame then
					-- なし, リバーサル, テクニカルライズ, グランドスウェー, 起き上がり攻撃
					if p.dummy_wakeup == wakeup_type.rvs and p.dummy_rvs then
						-- ダウン起き上がりリバーサル入力
						if wakeup_acts[p.act] and (p.on_wakeup+wakeup_frms[p.char] - 2) <= global.frame_number then
							input_rvs(rvs_types.on_wakeup, "ダウン起き上がりリバーサル入力")
						end
						-- 着地リバーサル入力（やられの着地）
						if 1 < p.pos_y_down and p.old_pos_y > p.pos_y and p.in_air ~= true then
							input_rvs(rvs_types.knock_back_landing, "着地リバーサル入力（やられの着地）")
						end
						-- 着地リバーサル入力（通常ジャンプの着地）
						if p.act == 0x9 and (p.act_frame == 2 or p.act_frame == 0) then
							input_rvs(rvs_types.jump_landing, "着地リバーサル入力（通常ジャンプの着地）")
						end
						-- リバーサルじゃない最速入力
						if p.state == 0 and p.act_data.name ~= "やられ" and p.old_act_data.name == "やられ" and p.knock_back1 == 0 then
							input_rvs(rvs_types.knock_back_recovery, "リバーサルじゃない最速入力")
						end
						-- のけぞりのリバーサル入力
						if (p.state == 1 or p.state == 2) and p.stop == 0 then
							-- のけぞり中のデータをみてのけぞり終了の2F前に入力確定する
							-- 奥ラインへ送った場合だけ無視する（p.act ~= 0x14A）
							if p.knock_back3 == 0x80 and p.knock_back1 == 0 and p.act ~= 0x14A then
								input_rvs(rvs_types.in_knock_back, "のけぞり中のデータをみてのけぞり終了の2F前に入力確定する1")
							elseif p.old_knock_back1 > 0 and p.knock_back1 == 0 then
								input_rvs(rvs_types.in_knock_back, "のけぞり中のデータをみてのけぞり終了の2F前に入力確定する2")
							end
							-- デンジャラススルー用
							if p.knock_back3 == 0x0 and p.stop < 3 and p.base == 0x34538 then
								input_rvs(rvs_types.dangerous_through, "デンジャラススルー用")
							end
						elseif p.state == 3 and p.stop == 0 and p.knock_back2 <= 1 then
							-- 当身うち空振りと裏雲隠し用
							input_rvs(rvs_types.atemi, "当身うち空振りと裏雲隠し用")
						end
						-- 奥ラインへ送ったあとのリバサ
						if p.act == 0x14A and p.act_count == 5  and p.act_frame == 0 and p.tw_frame == 1 then
							input_rvs(rvs_types.in_knock_back, "奥ラインへ送ったあとのリバサ")
						end
					elseif p.on_down == global.frame_number then
						if p.dummy_wakeup == wakeup_type.tech then
							-- テクニカルライズ入力
							cmd_base._2d(p, next_joy)
						elseif p.dummy_wakeup == wakeup_type.sway then
							-- グランドスウェー入力
							cmd_base._8d(p, next_joy)
						elseif p.dummy_wakeup == wakeup_type.atk then
							-- 起き上がり攻撃入力
							-- 舞、ボブ、フランコ、山崎のみなのでキャラをチェックする
							if p.char == 0x04 or p.char == 0x07 or p.char == 0x0A or p.char == 0x0B then
								p.write_bs_hook({ id = 0x23, ver = 0x7800, bs = false, name = "起き上がり攻撃", })
							end
						end
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
						if  p.act == 0x6D  and p.act_count == 5  and p.act_frame == 0 then
							p.write_bs_hook({ id = 0x00, ver = 0x1EFF, bs = false, name = "ホーネットアタック", })
						end
					elseif p.char == 3 then
						-- ジョー
						if  p.act == 0x70  and p.act_count == 0  and p.act_frame == 11 then
							cmd_base._2c(p, next_joy)
						end
					elseif p.char == 5 then
						-- ギース
						if  p.act == 0x6D  and p.act_count == 0  and p.act_frame == 0 then
							p.write_bs_hook({ id = 0x50, ver = 0x0600, bs = false, name = "絶命人中打ち", })
						end
					elseif p.char == 6 then
						-- 双角
						if  p.act == 0x6D  and p.act_count == 0  and p.act_frame == 0 then
							p.write_bs_hook({ id = 0x50, ver = 0x0600, bs = false, name = "地獄門", })
						end
					elseif p.char == 9 then
						-- マリー
						if  p.act == 0x6D  and p.act_count == 0  and p.act_frame == 0 then
							p.write_bs_hook({ id = 0x50, ver = 0x0600, bs = false, name = "アキレスホールド", })
						end
					elseif p.char == 22 then
						if p.act == 0xA1 and p.act_count == 6  and p.act_frame >= 0 then
							p.write_bs_hook({ id = 0x03, ver = 0x06FF, bs = false, name = "閃里肘皇", })
						end
					end
				end
				-- 自動デッドリーレイブ
				if 1 < global.auto_input.rave and p.char == 5 then
					-- ギース
					if p.skip_frame and op.state == 1 then
						if p.act == 0xE1 and 2 <= global.auto_input.rave then
							cmd_base._a(p, next_joy)
						elseif p.act == 0xE3 and 3 <= global.auto_input.rave then
							cmd_base._a(p, next_joy)
						elseif p.act == 0xE4 and 4 <= global.auto_input.rave then
							cmd_base._b(p, next_joy)
						elseif p.act == 0xE5 and 5 <= global.auto_input.rave then
							cmd_base._b(p, next_joy)
						elseif p.act == 0xE6 and 6 <= global.auto_input.rave then
							cmd_base._b(p, next_joy)
						elseif p.act == 0xE7 and 7 <= global.auto_input.rave then
							cmd_base._c(p, next_joy)
						elseif p.act == 0xE8 and 8 <= global.auto_input.rave then
							cmd_base._c(p, next_joy)
						elseif p.act == 0xE9 and 9 <= global.auto_input.rave then
							cmd_base._c(p, next_joy)
						elseif p.act == 0xEA and 10 <= global.auto_input.rave then
							p.write_bs_hook({ id = 0x00, ver = 0x1EFF, bs = false, name = "デッドリーレイブ(フィニッシュ)", })
						end
					end
				end
				-- 自動アンリミテッドデザイア
				if 1 < global.auto_input.desire and p.char == 20 then
					-- クラウザー
					if p.skip_frame and op.state == 1 then
						if p.act == 0xE1 and 2 <= global.auto_input.desire then
							cmd_base._a(p, next_joy)
						elseif p.act == 0xE3 and 3 <= global.auto_input.desire then
							cmd_base._b(p, next_joy)
						elseif p.act == 0xE4 and 4 <= global.auto_input.desire then
							cmd_base._c(p, next_joy)
						elseif p.act == 0xE5 and 5 <= global.auto_input.desire then
							cmd_base._b(p, next_joy)
						elseif p.act == 0xE6 and 6 <= global.auto_input.desire then
							cmd_base._c(p, next_joy)
						elseif p.act == 0xE7 and 7 <= global.auto_input.desire then
							cmd_base._a(p, next_joy)
						elseif p.act == 0xE8 and 8 <= global.auto_input.desire then
							cmd_base._b(p, next_joy)
						elseif p.act == 0xE9 and 9 <= global.auto_input.desire then
							cmd_base._c(p, next_joy)
						elseif p.act == 0xEA and 10 == global.auto_input.desire then
							cmd_base._c(p, next_joy)
						elseif p.act == 0xEA and 11 == global.auto_input.desire then
							p.write_bs_hook({ id = 0x00, ver = 0x06FE, bs = false, name = "アンリミテッドデザイア2", })
						end
					end
				end
				-- 自動ドリル
				if 1 < global.auto_input.drill and p.char == 11 and 1 < global.auto_input.drill then
					if p.act >= 0x108 and p.act <= 0x10D and p.act_frame % 2 == 0 then
						local lv = pgm:read_u8(p.addr.base + 0x94)
						if (lv < 9 and 2 <= global.auto_input.drill) or (lv < 10 and 3 <= global.auto_input.drill) or 4 <= global.auto_input.drill then
							cmd_base._c(p, next_joy)
						end
					elseif p.act == 0x10E and p.act_count == 0  and p.act_frame == 0 then
						if 5 == global.auto_input.drill then
							p.write_bs_hook({ id = 0x00, ver = 0x06FE, bs = false, name = "ドリル Lv.5", })
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
				if p.dummy_gd == dummy_gd_type.bs and p.on_guard == global.frame_number then
					if p.bs_count < 1 then
						p.bs_count = 1
					else
						p.bs_count = p.bs_count + 1
					end
					if p.dummy_bs_cnt <= p.bs_count and p.dummy_bs then
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
				called[prev_rec_main] = true
				global.rec_main(next_joy)
			until global.rec_main == prev_rec_main or called[global.rec_main] == true
		end

		-- ジョイスティック入力の反映
		for _, joy in ipairs(use_joy) do
			if next_joy[joy.field] ~= nil then
				manager.machine.ioport.ports[joy.port].fields[joy.field]:set_value(next_joy[joy.field] and 1 or 0)
			end
		end

		for i, p in ipairs(players) do
			local op = players[3 - i]
			if p.no_hit_limit == 1 then
				pgm:write_u8(p.addr.no_hit, 1)
			elseif p.on_hit == global.frame_number and p.state ~= 0 then
				p.no_hit = p.no_hit - 1
				if p.no_hit == 0 and p.no_hit_limit > 0  then
					pgm:write_u8(p.addr.no_hit, 1)
					--print(string.format("nohit %x %x %s", p.addr.base, p.no_hit, op.attack))
				else
					--print(string.format("hit   %x %x %s", p.addr.base, p.no_hit, op.attack))
				end
			elseif op.attack == 0 then
				p.no_hit = p.no_hit_limit
				pgm:write_u8(p.addr.no_hit, 0)
				if p.no_hit ~= p.no_hit_limit then
					--print(string.format("reset %x %x %s", p.addr.base, p.no_hit, op.attack))
				end
			end
		end

		-- Y座標強制
		for i, p in ipairs(players) do
			if p.force_y_pos ~= 0 and p.state == 0 then
				pgm:write_i16(p.addr.pos_y, p.force_y_pos)
			end
		end
		-- X座標同期とY座標をだいぶ上に
		if global.sync_pos_x ~= 1 then
			local from = global.sync_pos_x - 1
			local to   = 3 - from
			pgm:write_i16(players[to].addr.pos, players[from].pos)
			pgm:write_i16(players[to].addr.pos_y, 240)
		end
	end

	tra_main.draw = function()
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		local scr = manager.machine.screens:at(1)

		-- メイン処理
		if match_active then
			-- 判定表示（キャラ、飛び道具）
			if global.disp_hitbox > 1 then
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
							--[[
							if box_type_base.at == box.type then
								print("box at ", box.left, box.top, box.right, box.bottom)
							elseif box_type_base.pt == box.type then
								print("box pt ", box.left, box.top, box.right, box.bottom)
							end
							]]

							if box.visible == true and box.type.enabled == true then
								scr:draw_box(box.left, box.top, box.right, box.bottom, box.type.outline, box.type.fill)
							end
						end
					end
					for _, fb in pairs(p.fireball) do
						for _, box in ipairs(fb.hitboxes) do
							if box.visible == true and box.type.enabled == true then
								scr:draw_box(box.left, box.top, box.right, box.bottom, box.type.outline, box.type.fill)
							end
						end
					end
				end
			end

			-- コマンド入力表示
			for i, p in ipairs(players) do
				-- コマンド入力表示
				if p.disp_cmd then
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
				--if p.disp_base then
				--	draw_base(i, #p.bases + 1, 0, "", "")
				--end
			end
			-- ダメージとコンボ表示
			for i, p in ipairs(players) do
				local p1 = i == 1
				local op = players[3-i]
			
				-- コンボ表示などの四角枠
				if p.disp_dmg then
					if p1 then
						--scr:draw_box(184+40, 40, 274+40,  77, 0x80404040, 0x80404040)
						scr:draw_box(184+40, 40, 274+40,  84, 0x80404040, 0x80404040)
					else
						--scr:draw_box( 45-40, 40, 134-40,  77, 0x80404040, 0x80404040)
						scr:draw_box( 45-40, 40, 134-40,  84, 0x80404040, 0x80404040)
					end

					-- コンボ表示
					scr:draw_text(p1 and 228 or  9, 41, "補正:")
					scr:draw_text(p1 and 228 or  9, 48, "ダメージ:")
					scr:draw_text(p1 and 228 or  9, 55, "コンボ:")
					scr:draw_text(p1 and 228 or  9, 62, "スタン値:")
					scr:draw_text(p1 and 228 or  9, 69, "ｽﾀﾝ値ﾀｲﾏｰ:")
					scr:draw_text(p1 and 228 or  9, 76, "POW:")
					draw_rtext(   p1 and 296 or 77, 41, string.format("%s>%s(%s%%)", p.last_pure_dmg, op.last_dmg, (op.last_dmg_scaling-1) * 100))
					draw_rtext(   p1 and 296 or 77, 48, string.format("%s(+%s)", op.last_combo_dmg, op.last_dmg))
					draw_rtext(   p1 and 296 or 77, 55, op.last_combo)
					draw_rtext(   p1 and 296 or 77, 62, string.format("%s(+%s)", op.last_combo_stun, op.last_stun))
					draw_rtext(   p1 and 296 or 77, 69, string.format("%s(+%s)", op.last_combo_st_timer, op.last_st_timer))
					draw_rtext(   p1 and 296 or 77, 76, string.format("%s(+%s)", op.last_combo_pow, op.last_pow))
					scr:draw_text(p1 and 301 or 82, 41, "最大")
					draw_rtext(   p1 and 311 or 92, 48, op.max_dmg)
					draw_rtext(   p1 and 311 or 92, 55, op.max_combo)
					draw_rtext(   p1 and 311 or 92, 62, op.max_disp_stun)
					draw_rtext(   p1 and 311 or 92, 69, op.max_st_timer)
					draw_rtext(   p1 and 311 or 92, 76, op.max_combo_pow)

					-- TODO 実験的
					local bi = 1
					for _, box in ipairs(p.hitboxes) do
						if box.hitstun then
							draw_rtext(   p1 and 296 or 77, 76+bi*7, string.format("%2s/%2s/%2s", box.hitstun, box.blockstun, box.effect))
							bi = bi + 1
						end
					end
					for _, fb in pairs(p.fireball) do
						for _, box in ipairs(fb.hitboxes) do
							if box.hitstun then
								draw_rtext(   p1 and 296 or 77, 76+bi*7, string.format("%2s/%2s/%2s", box.hitstun, box.blockstun, box.effect))
								bi = bi + 1
							end
						end
					end
				end

				if p.disp_sts then
					if p1 then
						scr:draw_box(  2, 1,  40,  36, 0x80404040, 0x80404040)
					else
						scr:draw_box(277, 1, 316,  36, 0x80404040, 0x80404040)
					end

					scr:draw_text( p1 and  4 or 278,  1, string.format("%s", p.state))
					draw_rtext(    p1 and 16 or 290,  1, string.format("%2s", p.tw_threshold))
					draw_rtext(    p1 and 28 or 302,  1, string.format("%3s", p.tw_accepted))
					draw_rtext(    p1 and 40 or 314,  1, string.format("%3s", p.tw_frame))

					scr:draw_text( p1 and  4 or 278,  8, p.hit.vulnerable and "V" or "-")
					draw_rtext(    p1 and 16 or 290,  8, string.format("%s", p.tw_muteki2))
					draw_rtext(    p1 and 24 or 298,  8, string.format("%s", p.tw_muteki))
					draw_rtext(    p1 and 32 or 306,  8, string.format("%2x", p.sway_status))
					scr:draw_text( p1 and 36 or 310,  8, p.in_air and "A" or "G")

					scr:draw_text( p1 and  4 or 278, 15, p.hit.harmless and "-" or "H")
					draw_rtext(    p1 and 16 or 290, 15, string.format("%2x", p.attack))
					draw_rtext(    p1 and 28 or 302, 15, string.format("%2x", p.attack_id))
					draw_rtext(    p1 and 40 or 314, 15, string.format("%2x", p.hitstop_id))

					draw_rtext(    p1 and 16 or 290, 22, string.format("%4x", p.act))
					draw_rtext(    p1 and 28 or 302, 22, string.format("%2x", p.act_count))
					draw_rtext(    p1 and 40 or 314, 22, string.format("%2x", p.act_frame))

					local throwable   = p.state == 0 and op.state == 0 and p.tw_frame > 24 and p.sway_status == 0x00 and p.tw_muteki == 0 -- 投げ可能ベース
					local n_throwable = throwable and p.tw_muteki2 == 0 -- 通常投げ可能
					--[[
						p.tw_frame のしきい値。しきい値より大きければ投げ処理継続可能。
						0  空投げ M.スナッチャー0
						10 真空投げ 羅生門 鬼門陣 M.タイフーン M.スパイダー 爆弾パチキ ドリル ブレスパ ブレスパBR リフトアップブロー デンジャラススルー ギガティックサイクロン マジンガ STOL
						20 M.リアルカウンター投げ
						24 通常投げ しんさいは
					]]
					if not p.hit.vulnerable or not n_throwable or not throwable then
						local throw_txt = throwable and "" or "投"
						if p.tw_frame <= 10 then
							throw_txt = throw_txt .. "<"
						end
						if p.tw_frame <= 20 then
							throw_txt = throw_txt .. "<"
						end
						scr:draw_text( p1 and  1 or 275, 29, "無敵")
						scr:draw_text( p1 and 15 or 289, 29, p.hit.vulnerable and "" or "打")
						scr:draw_text( p1 and 24 or 298, 29, n_throwable and "" or "通")
						scr:draw_text( p1 and 30 or 304, 29, throwable and "" or throw_txt)
					end

					-- 状態フラグ
					local flgtbl = tobits(p.state_flags)
					local flgtxt = ""
					for j = 32, 1, -1  do
						if flgtbl[j] == 1 then
							flgtxt = flgtxt .. sts_flg_names[j] .. " "
						end
						--[[
						-- ビット値の表示版
						local num = string.format("%s", j % 10)
						local txt = flgtbl[j] == 1 and "1" or "-"
						if p1 then
							local x = 147 - (j * 3)
							scr:draw_text(x+0.5, 1.5, num, shadow_col)
							scr:draw_text(x    , 1    , num)
							scr:draw_text(x+0.5, 8.5, txt, shadow_col)
							scr:draw_text(x    , 8    , txt)
						else
							local x = 269 - (j * 3)
							scr:draw_text(x+0.5, 1+0.5, num, shadow_col)
							scr:draw_text(x    , 1    , num)
							scr:draw_text(x+0.5, 8+0.5, txt, shadow_col)
							scr:draw_text(x    , 8    , txt)
						end
						]]
					end

					local draw_rtext_col = function(x, y, fmt, dec)
						local txt = string.format(fmt, dec)
						draw_rtext(x + 0.5, y + 0.5, txt, shadow_col)
						local col = 0xFFFFFFFF
						if dec < 0 then
							col = 0xFFFF0033
						elseif dec > 0 then
							col = 0xFF0000FF
						end
						draw_rtext(x, y, txt, col)
					end
					draw_rtext_col(p1 and  70 or 200, 8, "%0.03f", p.inertia)
					draw_rtext_col(p1 and  90 or 220, 8, "%0.03f", p.thrust)
					draw_rtext_col(p1 and 110 or 240, 8, "%0.03f", p.pos_total - p.old_pos_total)

					if p1 then
						local x = 148
						draw_rtext(x+0.5, 1.5  , flgtxt, shadow_col)
						draw_rtext(x    , 1    , flgtxt)
					else
						local x = 176
						scr:draw_text(x+0.5, 1+0.5, flgtxt, shadow_col)
						scr:draw_text(x    , 1    , flgtxt)
					end
				end

				-- BS状態表示
				if p.dummy_gd == dummy_gd_type.bs then
					if p1 then
						scr:draw_box(106, 40, 150,  50, 0x80404040, 0x80404040)
					else
						scr:draw_box(169, 40, 213,  50, 0x80404040, 0x80404040)
					end
					scr:draw_text(p1 and 115 or 180, 41, "回ガードでBS")
					draw_rtext(   p1 and 115 or 180, 41, p.dummy_bs_cnt - math.max(p.bs_count, 0))
				end

				-- スタン表示
				if p.disp_stun then
					scr:draw_box(p1 and (138 - p.max_stun)   or 180, 29, p1 and 140 or (182 + p.max_stun)  , 34, 0, 0xDDC0C0C0) -- 枠
					scr:draw_box(p1 and (139 - p.max_stun)   or 181, 30, p1 and 139 or (181 + p.max_stun)  , 33, 0, 0xDD000000) -- 黒背景
					scr:draw_box(p1 and (139 - p.stun)       or 181, 30, p1 and 139 or (181 + p.stun)      , 33, 0, 0xDDFF0000) -- スタン値
					draw_rtext(p1 and 135.5 or 190.5, 28.5,  p.stun, shadow_col)
					draw_rtext(p1 and 135   or 190  , 28  ,  p.stun)

					scr:draw_box(p1 and (138 - 90)           or 180, 35, p1 and 140 or (182 + 90)          , 40, 0, 0xDDC0C0C0) -- 枠
					scr:draw_box(p1 and (139 - 90)           or 181, 36, p1 and 139 or (181 + 90)          , 39, 0, 0xDD000000) -- 黒背景
					scr:draw_box(p1 and (139 - p.stun_timer) or 181, 36, p1 and 139 or (181 + p.stun_timer), 39, 0, 0xDDFFFF00) -- スタン値
					draw_rtext(p1 and 135.5 or 190.5, 34.5,  p.stun_timer, shadow_col)
					draw_rtext(p1 and 135   or 190  , 34  ,  p.stun_timer)
				end
			end

			-- コマンド入力とダメージとコンボ表示
			for i, p in ipairs(players) do
				local op = players[3-i]
				local draw_axis = function(x, col)
					if x then
						scr:draw_line(x, p.hit.pos_y-global.axis_size, x, p.hit.pos_y+global.axis_size, col)
						scr:draw_line(x-global.axis_size, p.hit.pos_y, x+global.axis_size, p.hit.pos_y, col)
						scr:draw_text(x-1  , p.hit.pos_y+global.axis_size+0.5, string.format("%d", i), shadow_col)
						scr:draw_text(x-1.5, p.hit.pos_y+global.axis_size    , string.format("%d", i), col)
					end
				end
				local draw_esaka = function(x, col)
					if x and 0 <= x then
						local y1, y2 = 0, 200+global.axis_size
						scr:draw_line(x, y1, x, y2, col)
						scr:draw_text(x-2  , y2+0.5, string.format("え%d", i), shadow_col)
						scr:draw_text(x-2.5, y2    , string.format("え%d", i), col)
					end
				end
				local draw_close_far = function(btn, x1, x2)
					if x1 and x2 then
						local diff = math.abs(p.pos - op.pos)
						local in_range = x1 <= diff and diff <= x2 
						x1 = p.hit.pos_x + x1 * p.side
						x2 = p.hit.pos_x + x2 * p.side
						-- 間合い
						local color = in_range and 0xFFFFFF00 or 0xFFBBBBBB
						scr:draw_line(x2-2, p.hit.pos_y  , x2+2, p.hit.pos_y  , color)
						scr:draw_line(x2  , p.hit.pos_y-2, x2  , p.hit.pos_y+2, color)
						if in_range then
							scr:draw_text(x2-2.5, p.hit.pos_y+4.5, string.format("%s%d", btn, i), shadow_col)
							scr:draw_text(x2-2.5, p.hit.pos_y+4  , string.format("%s%d", btn, i), color)
						end
					end
				end
				-- 座標表示
				if global.disp_hitbox > 1 then
					if p.in_air ~= true and p.sway_status == 0x00 then
						-- 通常投げ間合い
						local color = p.throw.in_range and 0xFFFFFF00 or 0xFFBBBBBB
						scr:draw_line(p.throw.x1, p.hit.pos_y  , p.throw.x2, p.hit.pos_y  , color)
						scr:draw_line(p.throw.x1, p.hit.pos_y-4, p.throw.x1, p.hit.pos_y+4, color)
						scr:draw_line(p.throw.x2, p.hit.pos_y-4, p.throw.x2, p.hit.pos_y+4, color)
						if p.throw.in_range then
							scr:draw_text(p.throw.x1+2.5, p.hit.pos_y+4.5, string.format("投%d", i), shadow_col)
							scr:draw_text(p.throw.x1+2.5, p.hit.pos_y+4  , string.format("投%d", i), color)
						end

						-- 地上通常技の遠近判断距離
						for btn, range in pairs(p.close_far) do
							draw_close_far(string.upper(btn), range.x1, range.x2)
						end
					elseif p.sway_status == 0x80 then
						-- ライン移動技の遠近判断距離
						for btn, range in pairs(p.close_far_lma) do
							draw_close_far(string.upper(btn), range.x1, range.x2)
						end
					end

					-- 中心座標
					draw_axis(p.hit.pos_x, p.in_air == true and global.axis_air_color or global.axis_color)
					draw_axis(p.hit.max_pos_x, global.axis_internal_color)
					draw_axis(p.hit.min_pos_x, global.axis_internal_color)

					-- 詠酒範囲
					if p.esaka_range then
						draw_esaka(p.hit.pos_x + p.esaka_range, global.axis_internal_color)
						draw_esaka(p.hit.pos_x - p.esaka_range, global.axis_internal_color)
					end
				end
			end
			-- コマンド入力とダメージとコンボ表示
			for i, p in ipairs(players) do
				local p1 = i == 1

				--行動IDとフレーム数表示
				if global.disp_frmgap > 1 or p.disp_frm then
					if global.disp_frmgap == 2 then
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
						draw_frames(p.act_frames2, p1 and 160 or 285, true , true, p1 and 40 or 165, 63, 8, 16)
					end
				end
				if global.disp_frmgap > 1 then
					--フレーム差表示
					--scr:draw_box(p1 and (138 - 90)           or 180, 41, p1 and 140 or (182 + 90)          , 41+5, 0, 0xDDC0C0C0) -- 枠
					--scr:draw_box(p1 and (139 - 90)           or 181, 42, p1 and 139 or (181 + 90)          , 42+3, 0, 0xDD000000) -- 黒背景
					scr:draw_box(p1 and (139 - p.last_blockstun) or 181, 41, p1 and 139 or (181 + p.last_blockstun), 41+5, 0, p.skip_frame and 0xDDC0C0C0 or 0xDDFF007F)
					draw_rtext(p1 and 135.5 or 190.5, 40.5,  p.last_blockstun, shadow_col)
					draw_rtext(p1 and 135   or 190  , 40  ,  p.last_blockstun)

					draw_rtext(p1 and 155.5 or 170.5, 40.5,  p.last_frame_gap, shadow_col)
					draw_rtext(p1 and 155   or 170  , 40  ,  p.last_frame_gap)
					--draw_rtext(p1 and 135.5 or 190.5, 47.5,  p.last_blockstun, shadow_col)
					--draw_rtext(p1 and 135   or 190  , 47  ,  p.last_blockstun)
					--draw_rtext(p1 and 135.5 or 190.5, 54.5,  p.last_hitstop, shadow_col)
					--draw_rtext(p1 and 135   or 190  , 54  ,  p.last_hitstop)
				end
			end

			-- キャラ間の距離表示
			local abs_space = math.abs(p_space)
			if global.disp_pos then
				local y = 217 -- math.floor(get_digit(abs_space)/2)
				draw_rtext(167.5, y+0.5, abs_space, shadow_col)
				draw_rtext(167  , y    , abs_space)

				-- キャラの向き
				for i, p in ipairs(players) do
					local p1 = i == 1
					local op = players[3-i]

					-- 詠酒発動可能範囲、最大リーチ、最大やられ
					local atk_reach, vuln_reach = p.hit.reach_edge["attack"] or {}, p.hit.reach_edge["vuln"] or {}
					local label = {"E:%3d","A:%3d","V:%3d",}
					for j, v in ipairs({p.esaka_range, atk_reach.front, vuln_reach.front}) do
						if v and v > 0 then
							local x = (p1 and 140 or 180) + ((18 * j) * (p1 and - 1 or 1))
							local txt = string.format(label[j], v)
							draw_rtext(x+0.5, y+0.5, txt, shadow_col)
							draw_rtext(x    , y    , txt, global.axis_internal_color)
						end
					end

					-- 1:右向き -1:左向き
					local flip_x = p.hit.flip_x == 1 and ">" or "<"
					local side   = p.side       == 1 and "(>)" or "(<)"
					local postxt = p.poslr
					if p1 then
						local txt = string.format("%s%s%s", flip_x, side, postxt)
						draw_rtext(   150.5, y+0.5, txt, shadow_col)
						draw_rtext(   150  , y    , txt)
					else
						local txt = string.format("%s%s%s", postxt, side, flip_x)
						scr:draw_text(170.5, y+0.5, txt, shadow_col)
						scr:draw_text(170  , y    , txt)
					end
				end
				--print(string.format("%3s %3s %3s %3s xx %3s %3s", players[1].min_pos, players[2].min_pos, players[1].max_pos, players[2].max_pos, players[1].pos, players[2].pos))
			end

			-- レコーディング状態表示
			if global.disp_replay and (global.dummy_mode == 5 or global.dummy_mode == 6) then
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

		-- ログ
		local log = ""
		for i, p in ipairs(players) do
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
					tw, range = "NT", string.format("%sx%s", math.abs(box.left-box.right), math.abs(box.top-box.bottom))
				elseif box.type == box_type_base.at then
					tw, range = "AT", string.format("%sx%s", math.abs(box.left-box.right), math.abs(box.top-box.bottom))
				elseif box.type == box_type_base.pt then
					tw, range = "PT", string.format("%sx%s", math.abs(box.left-box.right), math.abs(box.top-box.bottom))
				else
					tw, range = "", ""
				end
				log = log .. string.format("%2x %1s %1s ", box.id or 0xFF, tw, range)
			end
		end
		--print(log)
		--[[
		for i, p in ipairs(players) do
			if i == 1 then
				--print(p.old_pos - p.pos)
				if p.act_data then
					print(p.char, p.posd, p.act_data.name, p.old_posd)
				end
			end
		end	

		-- ダッシュ中の投げ不能フレーム数確認ログ
		for i, p in ipairs(players) do
			local op = players[3-i]
			if p.act_data then
				if     p.old_act_data.name ~= "ダッシュ" and p.act_data.name == "ダッシュ" then
					p.throw_log = {}
				elseif p.old_act_data.name == "ダッシュ" and p.act_data.name ~= "ダッシュ" then
					local twlog = string.format("%x %2s %2s", p.addr.base, p.char, op.char)
					local cnt = 0
					for _, f in ipairs(p.throw_log) do
						if f > 0 then
							twlog = twlog .. string.format(" o:%s-%s", cnt+1, cnt+math.abs(f))
						else
							twlog = twlog .. string.format(" x:%s-%s", cnt+1, cnt+math.abs(f))
						end
						cnt = cnt+math.abs(f)
					end
					print(twlog)
				end
				if p.act_data.name == "ダッシュ" then
					local len = #p.throw_log
					if op.throw.in_range == true then
						if len == 0 then
							p.throw_log[len+1] = 1
						elseif p.throw_log[len] > 0 then
							p.throw_log[len] = p.throw_log[len] + 1
						else
							p.throw_log[len+1] = 1
						end
					else
						if len == 0 then
							p.throw_log[len+1] = -1
						elseif p.throw_log[len] > 0 then
							p.throw_log[len+1] = -1
						else
							p.throw_log[len] = p.throw_log[len] - 1
						end
					end
				end
			end
		end
		]]

		-- 画面表示
		if global.no_background then
			if pgm:read_u8(0x107BB9) == 0x01 then
				local match = pgm:read_u8(0x107C22)
				if match == 0x38 then --HUD
					pgm:write_u8(0x107C22, 0x33)
				end
				if match > 0 then --BG layers
					pgm:write_u8(0x107762, 0x00)
					pgm:write_u8(0x107765, 0x01)
				end
			end
			--pgm:write_u16(0x401FFE, 0x8F8F)
			pgm:write_u16(0x401FFE, 0x5ABB)
			pgm:write_u8(global.no_background_addr, 0xFF)
		else
			pgm:write_u8(global.no_background_addr, 0x00)
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

		global.dummy_mode        = col[ 1]      -- ダミーモード           1
		--                              2          レコード・リプレイ設定 2
		p[1].dummy_act           = col[ 3]      -- 1P アクション          3
		p[2].dummy_act           = col[ 4]      -- 2P アクション          4
		p[1].dummy_gd            = col[ 5]      -- 1P ガード              5
		p[2].dummy_gd            = col[ 6]      -- 2P ガード              6
		global.next_block_grace  = col[ 7] - 1  -- 1ガード持続フレーム数  7
		p[1].dummy_wakeup        = col[ 8]      -- 1P やられ時行動        8
		p[2].dummy_wakeup        = col[ 9]      -- 2P やられ時行動        9
		p[2].no_hit_limit        = col[10] - 1  -- 1P 強制空振り         10
		p[1].no_hit_limit        = col[11] - 1  -- 2P 強制空振り         11
		p[1].fwd_prov            = col[12] == 2 -- 1P 挑発で前進         12
		p[2].fwd_prov            = col[13] == 2 -- 2P 挑発で前進         13
		p[1].force_y_pos         = col[14] - 1  -- 1P Y座標強制          14
		p[2].force_y_pos         = col[15] - 1  -- 2P Y座標強制          15
		global.sync_pos_x        = col[16]      -- X座標同期             16

		-- キャラにあわせたメニュー設定
		for i, p in ipairs(players) do
			-- ブレイクショット
			p.dummy_bs_chr = p.char
			p.dummy_bs_list = {}
			local bs_menu = bs_menus[i][p.char]
			if bs_menu then
				p.dummy_bs_cnt = bs_menu.pos.col[#bs_menu.pos.col]
				for j, bs in pairs(char_bs_list[p.char]) do
					if bs_menu.pos.col[j+1] == 2 then
						table.insert(p.dummy_bs_list, bs)
					end
				end
			else
				p.dummy_bs_cnt = -1
			end

			-- リバーサル
			p.dummy_rvs_chr = p.char
			p.dummy_rvs_list = {}
			local rvs_menu = rvs_menus[i][p.char]
			if rvs_menu then
				p.dummy_rvs_cnt = rvs_menu.pos.col[#rvs_menu.pos.col]
				for j, rvs in pairs(char_rvs_list[p.char]) do
					if rvs_menu.pos.col[j+1] == 2 then
						table.insert(p.dummy_rvs_list, rvs)
					end
				end
			else
				p.dummy_rvs_cnt = -1
			end
		end

		for _, p in ipairs(players) do
			if p.dummy_gd == dummy_gd_type.hit1 then
				p.next_block = false
				p.next_block_ec = 75 -- カウンター初期化
			elseif p.dummy_gd == dummy_gd_type.guard1 then
				p.next_block = true
				p.next_block_ec = 75 -- カウンター初期化
			end
			p.bs_count = -1 -- BSガードカウンター初期化
			p.rvs_count = -1 -- リバサカウンター初期化
			p.guard1 = 0
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
			play_menu.pos.col[11] = recording.do_repeat and 2 or 1   -- 繰り返し          11
			play_menu.pos.col[12] = recording.repeat_interval + 1    -- 繰り返し間隔      12
			play_menu.pos.col[13] = global.await_neutral and 2 or 1  -- 繰り返し開始条件  13
			play_menu.pos.col[14] = global.replay_fix_pos            -- 開始間合い固定    14
			play_menu.pos.col[15] = global.replay_reset              -- 状態リセット      15
			play_menu.pos.col[16] = global.disp_replay and 2 or 1    -- ガイド表示        16
			if not cancel and row == 1 then
				menu_cur = play_menu
				return
			end
		end

		-- 設定後にメニュー遷移
		for i, p in ipairs(players) do
			-- ブレイクショット
			if not cancel and row == (4 + i) and p.dummy_gd == dummy_gd_type.bs then
				menu_cur = bs_menus[i][p.char]
				return
			end
			-- リバーサル
			if not cancel and row == (7 + i) and p.dummy_wakeup == wakeup_type.rvs then
				menu_cur = rvs_menus[i][p.char]
				return
			end
		end

		menu_cur = main_menu
	end
	local menu_to_main_cancel = function()
		menu_to_main(true)
	end
	local life_range = { "最大", "赤", "ゼロ", }
	for i = 1, 0xC0 do
		table.insert(life_range, i)
	end
	local pow_range = { "最大", "半分", "ゼロ", }
	for i = 1, 0x3C do
		table.insert(pow_range, i)
	end
	local bar_menu_to_main = function(cancel)
		local col = bar_menu.pos.col
		local p   = players
		--                              1                                      1
		p[1].red                 = col[ 2]      -- 1P 体力ゲージ量             2
		p[2].red                 = col[ 3]      -- 2P 体力ゲージ量             3
		p[1].max                 = col[ 4]      -- 1P POWゲージ量              4
		p[2].max                 = col[ 5]      -- 2P POWゲージ量              5
		p[1].disp_stun           = col[ 6] == 2 -- 1P スタンゲージ表示         6
		p[2].disp_stun           = col[ 7] == 2 -- 2P スタンゲージ表示         7
		dip_config.infinity_life = col[ 8] == 2 -- 体力ゲージモード            8
		global.pow_mode          = col[ 9]      -- POWゲージモード             9

		menu_cur = main_menu
	end
	local bar_menu_to_main_cancel = function()
		bar_menu_to_main(true)
	end
	local ex_menu_to_main = function(cancel)
		local col = ex_menu.pos.col
		local p   = players
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		--                              1                                 1
		global.disp_hitbox       = col[ 2]      -- 判定表示               2
		global.pause_hit         = col[ 3] == 2 -- ヒット時にポーズ       3
		global.pausethrow        = col[ 4] == 2 -- 投げ判定発生時にポーズ 4
		p[1].disp_dmg            = col[ 5] == 2 -- 1P ダメージ表示        5
		p[2].disp_dmg            = col[ 6] == 2 -- 2P ダメージ表示        6
		p[1].disp_cmd            = col[ 7] == 2 -- 1P 入力表示            7
		p[2].disp_cmd            = col[ 8] == 2 -- 2P 入力表示            8
		global.disp_frmgap       = col[ 9]      -- フレーム差表示         9
		p[1].disp_frm            = col[10] == 2 -- 1P フレーム数表示     10
		p[2].disp_frm            = col[11] == 2 -- 2P フレーム数表示     11
		p[1].disp_sts            = col[12] == 2 -- 1P 状態表示           12
		p[2].disp_sts            = col[13] == 2 -- 2P 状態表示           13
		p[1].disp_base           = col[14] == 2 -- 1P 処理アドレス表示   14
		p[2].disp_base           = col[15] == 2 -- 2P 処理アドレス表示   15
		global.disp_pos          = col[16] == 2 -- 1P 2P 距離表示        16
		dip_config.easy_super    = col[17] == 2 -- 簡易超必              17
		global.mame_debug_wnd    = col[18] == 2 -- MAMEデバッグウィンドウ18
		global.damaged_move      = col[19]      -- ヒット効果確認用      19
		global.log.poslog        = col[20] == 2 -- 位置ログ              20
		global.log.atklog        = col[21] == 2 -- 攻撃情報ログ          21
		global.log.baselog       = col[22] == 2 -- 処理アドレスログ      22
		global.log.keylog        = col[23] == 2 -- 入力ログ              23
		global.log.rvslog        = col[24] == 2 -- リバサログ            24

		local dmove = damaged_moves[global.damaged_move]
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

		menu_cur = main_menu
	end
	local ex_menu_to_main_cancel = function()
		ex_menu_to_main(true)
	end
	local auto_menu_to_main = function(cancel)
		local p   = players
		local col = auto_menu.pos.col
		-- 自動入力設定                                                          1
		global.auto_input.otg_thw      = col[ 2] == 2 -- ダウン投げ              2
		global.auto_input.otg_atk      = col[ 3] == 2 -- ダウン攻撃              3
		global.auto_input.thw_otg      = col[ 4] == 2 -- 通常投げの派生技        4
		global.auto_input.rave         = col[ 5]      -- デッドリーレイブ        5
		global.auto_input.desire       = col[ 6]      -- アンリミテッドデザイア  6
		global.auto_input.drill        = col[ 7]      -- ドリル                  7
		global.auto_input.pairon       = col[ 8]      -- 超白龍                  8
		global.auto_input.real_counter = col[ 9]      -- M.リアルカウンター      9
		-- 入力設定                                                             10
		global.auto_input.esaka_check  = col[11] == 2 -- 詠酒距離チェック       11

		set_skip_esaka_check(p[1], global.auto_input.esaka_check)
		set_skip_esaka_check(p[2], global.auto_input.esaka_check)

		menu_cur = main_menu
	end
	local auto_menu_to_main_cancel = function()
		auto_menu_to_main(true)
	end
	local box_type_col_list = { 
		box_type_base.a, box_type_base.fa, box_type_base.da, box_type_base.aa, box_type_base.faa, box_type_base.daa,
		box_type_base.pa, box_type_base.pfa, box_type_base.pda, box_type_base.paa, box_type_base.pfaa, box_type_base.pdaa,
		box_type_base.t3, box_type_base.t, box_type_base.at, box_type_base.pt,
		box_type_base.p, box_type_base.v1, box_type_base.sv1, box_type_base.v2, box_type_base.sv2, box_type_base.v3,
		box_type_base.v4, box_type_base.v5, box_type_base.v6, box_type_base.x1, box_type_base.x2, box_type_base.x3,
		box_type_base.x4, box_type_base.x5, box_type_base.x6, box_type_base.x7, box_type_base.x8, box_type_base.x9,
		box_type_base.g1, box_type_base.g2, box_type_base.g3, box_type_base.g4, box_type_base.g5, box_type_base.g6,
		box_type_base.g7, box_type_base.g8, box_type_base.g9, box_type_base.g10, box_type_base.g11, box_type_base.g12,
		box_type_base.g13, box_type_base.g14, box_type_base.g15, box_type_base.g16, }
	local col_menu_to_main = function(cancel)
		local col = col_menu.pos.col

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
		local scr = manager.machine.screens:at(1)
		local ec = scr:frame_number()
		global.dummy_mode = 5
		global.rec_main = rec_await_no_input
		global.input_accepted = ec
		-- 選択したプレイヤー側の反対側の操作をいじる
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		recording.temp_player = (pgm:read_u8(players[1].addr.reg_pcnt) ~= 0xFF) and 2 or 1
		recording.active_slot = recording.slot[slot_no]
		menu_cur = main_menu
		menu_exit()
	end
	local exit_menu_to_play_common = function()
		local col = play_menu.pos.col
		recording.live_slots = {}
		for i = 1, #recording.slot do
			if col[i+1] == 2 then
				table.insert(recording.live_slots, i)
			end
		end
		recording.do_repeat       = col[11] == 2 -- 繰り返し          11
		recording.repeat_interval = col[12] - 1  -- 繰り返し間隔      12
		global.await_neutral      = col[13] == 2 -- 繰り返し開始条件  13
		global.replay_fix_pos     = col[14]      -- 開始間合い固定    14
		global.replay_reset       = col[15]      -- 状態リセット      15
		global.disp_replay        = col[16] == 2 -- ガイド表示        16
		global.repeat_interval    = recording.repeat_interval
	end
	local exit_menu_to_play = function()
		local scr = manager.machine.screens:at(1)
		local ec = scr:frame_number()
		global.dummy_mode = 6 -- リプレイモードにする
		global.rec_main = rec_await_play
		global.input_accepted = ec
		exit_menu_to_play_common()
		menu_cur = main_menu
		menu_exit()
 	end
	local exit_menu_to_play_cancel = function()
		local scr = manager.machine.screens:at(1)
		local ec = scr:frame_number()
		global.dummy_mode = 6 -- リプレイモードにする
		global.rec_main = rec_await_play
		global.input_accepted = ec
		exit_menu_to_play_common()
		menu_to_tra()
	end
	local exit_menu_to_rec_pos = function()
		local scr = manager.machine.screens:at(1)
		local ec = scr:frame_number()
		global.dummy_mode = 5 -- レコードモードにする
		global.rec_main = rec_fixpos
		global.input_accepted = ec
		-- 選択したプレイヤー側の反対側の操作をいじる
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
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
		col[ 8] = p[1].dummy_wakeup        -- 1P やられ時行動        8
		col[ 9] = p[2].dummy_wakeup        -- 2P やられ時行動        9
		col[10] = p[2].no_hit_limit + 1    -- 1P 強制空振り         10
		col[11] = p[1].no_hit_limit + 1    -- 2P 強制空振り         11
		col[12] = p[1].fwd_prov and 2 or 1 -- 1P 挑発で前進         12
		col[13] = p[2].fwd_prov and 2 or 1 -- 2P 挑発で前進         13
		col[14] = p[1].force_y_pos + 1     -- 1P Y座標強制          14
		col[15] = p[2].force_y_pos + 1     -- 2P Y座標強制          15
		g.sync_pos_x = col[16]             -- X座標同期             16
	end
	local init_bar_menu_config = function()
		local col = bar_menu.pos.col
		local p = players
		local g = global
		--   1                                                        1
		col[ 2] = p[1].red                  -- 1P 体力ゲージ量        2
		col[ 3] = p[2].red                  -- 2P 体力ゲージ量        3
		col[ 4] = p[1].max                  -- 1P POWゲージ量         4
		col[ 5] = p[2].max                  -- 2P POWゲージ量         5
		col[ 6] = p[1].disp_stun and 2 or 1 -- 1P スタンゲージ表示    6
		col[ 7] = p[2].disp_stun and 2 or 1 -- 2P スタンゲージ表示    7
		col[ 8] = dip_config.infinity_life and 2 or 1 -- 体力ゲージモード 8
		col[ 9] = g.pow_mode                -- POWゲージモード        9
	end
	local init_ex_menu_config = function()
		local col = ex_menu.pos.col
		local p = players
		local g = global
		--   1                                                       1
		col[ 2] = g.disp_hitbox            -- 判定表示               2
		col[ 3] = g.pause_hit   and 2 or 1 -- ヒット時にポーズ       3
		col[ 4] = g.pausethrow  and 2 or 1 -- 投げ判定発生時にポーズ 4
		col[ 5] = p[1].disp_dmg and 2 or 1 -- 1P ダメージ表示        5
		col[ 6] = p[2].disp_dmg and 2 or 1 -- 2P ダメージ表示        6
		col[ 7] = p[1].disp_cmd and 2 or 1 -- 1P 入力表示            7
		col[ 8] = p[2].disp_cmd and 2 or 1 -- 2P 入力表示            8
		col[ 9] = g.disp_frmgap            -- フレーム差表示         9
		col[10] = p[1].disp_frm and 2 or 1 -- 1P フレーム数表示     10
		col[11] = p[2].disp_frm and 2 or 1 -- 2P フレーム数表示     11
		col[12] = p[1].disp_sts and 2 or 1 -- 1P 状態表示           12
		col[13] = p[2].disp_sts and 2 or 1 -- 2P 状態表示           13
		col[14] = p[1].disp_base and 2 or 1 -- 1P 処理アドレス表示  14
		col[15] = p[2].disp_base and 2 or 1 -- 2P 処理アドレス表示  15
		col[16] = g.disp_pos    and 2 or 1 -- 1P 2P 距離表示        16
		col[17] = dip_config.easy_super and 2 or 1 -- 簡易超必      17
		col[18] = g.mame_debug_wnd and 2 or 1 -- MAMEデバッグウィンドウ18
		col[19] = g.damaged_move           -- ヒット効果確認用      19
		col[20] = g.log.poslog  and 2 or 1 -- 位置ログ              20
		col[21] = g.log.atklog  and 2 or 1 -- 攻撃情報ログ          21
		col[22] = g.log.baselog and 2 or 1 -- 処理アドレスログ      22
		col[23] = g.log.keylog  and 2 or 1 -- 入力ログ              23
		col[24] = g.log.rvslog  and 2 or 1 -- リバサログ            24
	end
	local init_auto_menu_config = function()
		local col = auto_menu.pos.col
		local p = players
		local g = global
		                                          -- 自動入力設定            1
		col[ 2] = g.auto_input.otg_thw and 2 or 1 -- ダウン投げ              2
		col[ 3] = g.auto_input.otg_atk and 2 or 1 -- ダウン攻撃              3
		col[ 4] = g.auto_input.thw_otg and 2 or 1 -- 通常投げの派生技        4
		col[ 5] = g.auto_input.rave               -- デッドリーレイブ        5
		col[ 6] = g.auto_input.desire             -- アンリミテッドデザイア  6
		col[ 7] = g.auto_input.drill              -- ドリル                  7
		col[ 8] = g.auto_input.pairon             -- 超白龍                  8
		col[ 9] = g.auto_input.real_counter       -- M.リアルカウンター      9
		                                          -- 入力設定               10
		col[11] = g.auto_input.esaka_check        -- 詠酒距離チェック       11
	end
	local init_restart_fight = function()
		local col = tra_menu.pos.col
		local p = players
		local g = global
	end
	menu_to_tra  = function() menu_cur = tra_menu end
	menu_to_bar  = function() menu_cur = bar_menu end
	menu_to_ex   = function() menu_cur = ex_menu end
	menu_to_auto = function() menu_cur = auto_menu end
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
			next_p1       =      main_menu.pos.col[ 8]  , -- 1P セレクト
			next_p2       =      main_menu.pos.col[ 9]  , -- 2P セレクト
			next_p1col    =      main_menu.pos.col[10]-1, -- 1P カラー
			next_p2col    =      main_menu.pos.col[11]-1, -- 2P カラー
			next_stage    = stgs[main_menu.pos.col[12]], -- ステージセレクト
			next_bgm      = bgms[main_menu.pos.col[13]].id, -- BGMセレクト
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
			{ "自動入力設定" },
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
				0, -- 自動入力設定
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
			menu_to_auto, -- 自動入力設定
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
			menu_exit,  -- 一般設定
			menu_exit, -- 判定個別設定
			menu_exit, -- 自動入力設定
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
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		-- メニューの更新
		main_menu.pos.col[ 8] = math.min(math.max(pgm:read_u8(0x107BA5)  , 1), #char_names)
		main_menu.pos.col[ 9] = math.min(math.max(pgm:read_u8(0x107BA7)  , 1), #char_names)
		main_menu.pos.col[10] = math.min(math.max(pgm:read_u8(0x107BAC)+1, 1), 2)
		main_menu.pos.col[11] = math.min(math.max(pgm:read_u8(0x107BAD)+1, 1), 2)

		local stg1 = pgm:read_u8(0x107BB1)
		local stg2 = pgm:read_u8(0x107BB7)
		local stg3 = pgm:read_u8(0x107BB9) == 1 and 0x01 or 0x0F
		main_menu.pos.col[12] = 1
		for i, data in ipairs(stgs) do
			if data.stg1 == stg1 and data.stg2 == stg2 and data.stg3 == stg3 then
				main_menu.pos.col[12] = i
				break
			end
		end

		main_menu.pos.col[13] = 1
		local bgmid = math.max(pgm:read_u8(0x10A8D5), 1)
		for i, bgm in ipairs(bgms) do
			if bgmid == bgm.id then
				main_menu.pos.col[13] = bgm.name_idx
			end
		end
	end
	-- ブレイクショットメニュー
	bs_menus, rvs_menus = {}, {}
	local bs_guards = {}
	for i = 1, 60 do
		table.insert(bs_guards, string.format("%s回ガード後に発動", i))
	end
	local menu_bs_to_tra_menu = function()
		menu_to_tra()
	end
	local menu_rvs_to_tra_menu = function()
		menu_to_tra()
	end
	for i = 1, 2 do
		local pbs, prvs = {}, {}
		table.insert(bs_menus, pbs)
		table.insert(rvs_menus, prvs)
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

			table.insert(list, { "タイミング", bs_guards })
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
		for _, rvs_list in pairs(char_rvs_list) do
			local list, on_ab, col = {}, {}, {}
			table.insert(list, { "     ONにしたスロットからランダムで発動されます。" })
			table.insert(on_ab, menu_rvs_to_tra_menu)
			table.insert(col, 0)
			for _, bs in pairs(rvs_list) do
				table.insert(list, { bs.name, { "OFF", "ON", }, })
				table.insert(on_ab, menu_rvs_to_tra_menu)
				table.insert(col, 1)
			end
			table.insert(list, { "                   ブレイクショット設定" })
			table.insert(on_ab, menu_rvs_to_tra_menu)
			table.insert(col, 0)

			local rvs_menu = {
				list = list,
				pos = { -- メニュー内の選択位置
					offset = 1,
					row = 2,
					col = col,
				},
				on_a = on_ab,
				on_b = on_ab,
			}
			table.insert(prvs, rvs_menu)
		end
	end
	local gd_frms = {}
	for i = 1, 61 do
		table.insert(gd_frms, string.format("%sF後にガード解除", (i - 1)))
	end
	local force_y_pos = {}
	for i = 1, 256 do
		table.insert(force_y_pos, i - 1)
	end
	local no_hit_row = { "OFF", }
	for i = 1, 99 do
		table.insert(no_hit_row, string.format("%s段目で空振り", i))
	end
	tra_menu = {
		list = {
			{ "ダミーモード"          , { "プレイヤー vs プレイヤー", "プレイヤー vs CPU", "CPU vs プレイヤー", "1P&2P入れ替え", "レコード", "リプレイ" }, },
			{ "                         ダミー設定" },
			{ "1P アクション"         , { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" }, },
			{ "2P アクション"         , { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" }, },
			{ "1P ガード"             , { "なし", "オート", "ブレイクショット（Aで選択画面へ）", "1ヒットガード", "1ガード", "常時", "ランダム" }, },
			{ "2P ガード"             , { "なし", "オート", "ブレイクショット（Aで選択画面へ）", "1ヒットガード", "1ガード", "常時", "ランダム" }, },
			{ "1ガード持続フレーム数" , gd_frms, },
			{ "1P やられ時行動"       , { "なし", "リバーサル（Aで選択画面へ）", "テクニカルライズ", "グランドスウェー", "起き上がり攻撃", }, },
			{ "2P やられ時行動"       , { "なし", "リバーサル（Aで選択画面へ）", "テクニカルライズ", "グランドスウェー", "起き上がり攻撃", }, },
			{ "1P 強制空振り"         , no_hit_row, },
			{ "2P 強制空振り"         , no_hit_row, },
			{ "1P 挑発で前進"         , { "OFF", "ON" }, },
			{ "2P 挑発で前進"         , { "OFF", "ON" }, },
			{ "1P Y座標強制"          , force_y_pos, },
			{ "2P Y座標強制"          , force_y_pos, },
			{ "画面上に移動"          , { "OFF", "2Pを上に移動", "1Pを上に移動", }, },
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
				1, -- 1P やられ時行動         8
				1, -- 2P やられ時行動         9
				1, -- 1P 強制空振り          10
				1, -- 2P 強制空振り          11
				1, -- 1P 挑発で前進          12
				1, -- 2P 挑発で前進          13
				1, -- 1P Y座標強制           14
				1, -- 2P Y座標強制           15
				1, -- X座標同期              16
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
			menu_to_main, -- 1P やられ時行動
			menu_to_main, -- 2P やられ時行動
			menu_to_main, -- 1P 強制空振り
			menu_to_main, -- 2P 強制空振り
			menu_to_main, -- 1P 挑発で前進
			menu_to_main, -- 2P 挑発で前進
			menu_to_main, -- 1P Y座標強制
			menu_to_main, -- 2P Y座標強制
			menu_to_main, -- X座標同期
		},
		on_b = {
			menu_to_main_cancel, -- ダミーモード
			menu_to_main_cancel, -- －ダミー設定－
			menu_to_main_cancel, -- 1P アクション
			menu_to_main_cancel, -- 2P アクション
			menu_to_main_cancel, -- 1P ガード
			menu_to_main_cancel, -- 2P ガード
			menu_to_main_cancel, -- 1ガード持続フレーム数
			menu_to_main_cancel, -- 1P やられ時行動
			menu_to_main_cancel, -- 2P やられ時行動
			menu_to_main_cancel, -- 1P 強制空振り
			menu_to_main_cancel, -- 2P 強制空振り
			menu_to_main_cancel, -- 1P 挑発で前進
			menu_to_main_cancel, -- 2P 挑発で前進
			menu_to_main_cancel, -- 1P Y座標強制
			menu_to_main_cancel, -- 2P Y座標強制
			menu_to_main_cancel, -- X座標同期
		},
	}

	bar_menu = {
		list = {
			{ "                         ゲージ設定" },
			{ "1P 体力ゲージ量"       , life_range, }, 	-- "最大", "赤", "ゼロ" ...
			{ "2P 体力ゲージ量"       , life_range, }, 	-- "最大", "赤", "ゼロ" ...
			{ "1P POWゲージ量"        , pow_range, },   -- "最大", "半分", "ゼロ" ...
			{ "2P POWゲージ量"        , pow_range, },   -- "最大", "半分", "ゼロ" ...
			{ "1P スタンゲージ表示"   , { "OFF", "ON" }, },
			{ "2P スタンゲージ表示"   , { "OFF", "ON" }, },
			{ "体力ゲージモード"      , { "自動回復", "固定" }, },
			{ "POWゲージモード"       , { "自動回復", "固定", "通常動作" }, },
		},
		pos = { -- メニュー内の選択位置
			offset = 1,
			row = 2,
			col = {
				0, -- －ゲージ設定－          1
				2, -- 1P 体力ゲージ量         2
				2, -- 2P 体力ゲージ量         3
				2, -- 1P POWゲージ量          4
				2, -- 2P POWゲージ量          5
				2, -- 1P スタンゲージ表示     6
				2, -- 2P スタンゲージ表示     7
				2, -- 体力ゲージモード        8
				2, -- POWゲージモード         9
			},
		},
		on_a = {
			bar_menu_to_main, -- －ゲージ設定－          1
			bar_menu_to_main, -- 1P 体力ゲージ量         2
			bar_menu_to_main, -- 2P 体力ゲージ量         3
			bar_menu_to_main, -- 1P POWゲージ量          4
			bar_menu_to_main, -- 2P POWゲージ量          5
			bar_menu_to_main, -- 1P スタンゲージ表示     6
			bar_menu_to_main, -- 2P スタンゲージ表示     7
			bar_menu_to_main, -- 体力ゲージモード        8
			bar_menu_to_main, -- POWゲージモード         9
		},
		on_b = {
			bar_menu_to_main_cancel, -- －ゲージ設定－          1
			bar_menu_to_main_cancel, -- 1P 体力ゲージ量         2
			bar_menu_to_main_cancel, -- 2P 体力ゲージ量         3
			bar_menu_to_main_cancel, -- 1P POWゲージ量          4
			bar_menu_to_main_cancel, -- 2P POWゲージ量          5
			bar_menu_to_main_cancel, -- 1P スタンゲージ表示     6
			bar_menu_to_main_cancel, -- 2P スタンゲージ表示     7
			bar_menu_to_main_cancel, -- 体力ゲージモード        8
			bar_menu_to_main_cancel, -- POWゲージモード         9
		},
	}

	ex_menu = {
		list = {
			{ "                          一般設定" },
			{ "判定表示"              , { "OFF", "ON", "ON:判定の形毎", "ON:攻撃判定の形毎", "ON:くらい判定の形毎", }, },
			{ "ヒット時にポーズ"      , { "OFF", "ON" }, },
			{ "投げ判定発生時にポーズ", { "OFF", "ON" }, },
			{ "1P ダメージ表示"       , { "OFF", "ON" }, },
			{ "2P ダメージ表示"       , { "OFF", "ON" }, },
			{ "1P 入力表示"           , { "OFF", "ON" }, },
			{ "2P 入力表示"           , { "OFF", "ON" }, },
			{ "フレーム差表示"        , { "OFF", "数値とグラフ", "数値" }, },
			{ "1P フレーム数表示"     , { "OFF", "ON" }, },
			{ "2P フレーム数表示"     , { "OFF", "ON" }, },
			{ "1P 状態表示"           , { "OFF", "ON" }, },
			{ "2P 状態表示"           , { "OFF", "ON" }, },
			{ "1P 処理アドレス表示"   , { "OFF", "ON" }, },
			{ "2P 処理アドレス表示"   , { "OFF", "ON" }, },
			{ "1P 2P 距離表示"        , { "OFF", "ON" }, },
			{ "簡易超必"              , { "OFF", "ON" }, },
			{ "MAMEデバッグウィンドウ", { "OFF", "ON" }, },
			{ "ヒット効果確認用"      , damaged_move_keys },
			{ "位置ログ"              , { "OFF", "ON" }, },
			{ "攻撃情報ログ"          , { "OFF", "ON" }, },
			{ "処理アドレスログ"      , { "OFF", "ON" }, },
			{ "入力ログ"              , { "OFF", "ON" }, },
			{ "リバサログ"            , { "OFF", "ON" }, },
		},
		pos = { -- メニュー内の選択位置
			offset = 1,
			row = 2,
			col = {
				0, -- －一般設定－            1
				4, -- 判定表示                2
				1, -- ヒット時にポーズ        3
				1, -- 投げ判定ポーズ          4
				1, -- 1P ダメージ表示         5
				1, -- 2P ダメージ表示         6
				1, -- 1P 入力表示             7
				1, -- 2P 入力表示             8
				3, -- フレーム差表示          9
				1, -- 1P フレーム数表示      10
				1, -- 2P フレーム数表示      11
				1, -- 1P 状態表示            12
				1, -- 2P 状態表示            13
				1, -- 1P 処理アドレス表示    14
				1, -- 2P 処理アドレス表示    15
				1, -- 1P 2P 距離表示         16
				1, -- 簡易超必               17
				1, -- MAMEデバッグウィンドウ 18
				1, -- ヒット効果確認用       19
				1, -- 位置ログ               20
				1, -- 攻撃情報ログ           21
				1, -- 処理アドレスログ       22
				1, -- 入力ログ               23
				1, -- リバサログ             24
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
			ex_menu_to_main, -- 1P 状態表示
			ex_menu_to_main, -- 2P 状態表示
			ex_menu_to_main, -- 1P 処理アドレス表示
			ex_menu_to_main, -- 2P 処理アドレス表示
			ex_menu_to_main, -- 1P 2P 距離表示
			ex_menu_to_main, -- 簡易超必
			ex_menu_to_main, -- MAMEデバッグウィンドウ
			ex_menu_to_main, -- ヒット効果確認用
			ex_menu_to_main, -- 位置ログ
			ex_menu_to_main, -- 攻撃情報ログ
			ex_menu_to_main, -- 処理アドレスログ
			ex_menu_to_main, -- 入力ログ
			ex_menu_to_main, -- リバサログ
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
			ex_menu_to_main_cancel, -- 1P 状態表示
			ex_menu_to_main_cancel, -- 2P 状態表示
			ex_menu_to_main_cancel, -- 1P 処理アドレス表示
			ex_menu_to_main_cancel, -- 2P 処理アドレス表示
			ex_menu_to_main_cancel, -- 1P 2P 距離表示
			ex_menu_to_main_cancel, -- 簡易超必
			ex_menu_to_main_cancel, -- MAMEデバッグウィンドウ
			ex_menu_to_main_cancel, -- ヒット効果確認用
			ex_menu_to_main_cancel, -- 位置ログ
			ex_menu_to_main_cancel, -- 攻撃情報ログ
			ex_menu_to_main_cancel, -- 処理アドレスログ
			ex_menu_to_main_cancel, -- 入力ログ
			ex_menu_to_main_cancel, -- リバサログ
		},
	}

	auto_menu = {
		list = {
			{ "                        自動入力設定" },
			{ "ダウン投げ"            , { "OFF", "ON" }, },
			{ "ダウン攻撃"            , { "OFF", "ON" }, },
			{ "通常投げの派生技"      , { "OFF", "ON" }, },
			{ "デッドリーレイブ"      , { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, },
			{ "アンリミテッドデザイア", { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, "ギガティックサイクロン" }, },
			{ "ドリル"                , { 1, 2, 3, 4, 5 }, },
			{ "超白龍"                , { "OFF", "C攻撃-判定発生前", "C攻撃-判定発生後" }, },
			{ "M.リアルカウンター"    , { "OFF", "ジャーマン", "フェイスロック", "投げっぱなしジャーマン", "ランダム", }, },
			{ "                          入力設定" },
			{ "詠酒距離チェック"      , { "OFF", "ON" }, }
		},
		pos = { -- メニュー内の選択位置
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
				0, -- 入力設定               10
				1, -- 詠酒距離チェック       11
			},
		},
		on_a = {
			auto_menu_to_main, -- 自動入力設定            1
			auto_menu_to_main, -- ダウン投げ              2
			auto_menu_to_main, -- ダウン攻撃              3
			auto_menu_to_main, -- 通常投げの派生技        4
			auto_menu_to_main, -- デッドリーレイブ        5
			auto_menu_to_main, -- アンリミテッドデザイア  6
			auto_menu_to_main, -- ドリル                  7
			auto_menu_to_main, -- 超白龍                  8
			auto_menu_to_main, -- M.リアルカウンター      9
			auto_menu_to_main, -- 入力設定               10
			auto_menu_to_main, -- 詠酒距離チェック       11
		},
		on_b = {
			auto_menu_to_main_cancel, -- 自動入力設定            1
			auto_menu_to_main_cancel, -- ダウン投げ              2
			auto_menu_to_main_cancel, -- ダウン攻撃              3
			auto_menu_to_main_cancel, -- 通常投げの派生技        4
			auto_menu_to_main_cancel, -- デッドリーレイブ        5
			auto_menu_to_main_cancel, -- アンリミテッドデザイア  6
			auto_menu_to_main_cancel, -- ドリル                  7
			auto_menu_to_main_cancel, -- 超白龍                  8
			auto_menu_to_main_cancel, -- リアルカウンター        9
			auto_menu_to_main_cancel, -- 入力設定               10
			auto_menu_to_main_cancel, -- 詠酒距離チェック       11
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
		table.insert(col_menu.pos.col, box.enabled and 2 or 1)
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
			{ "スロット6"             , { "Aでレコード開始", }, },
			{ "スロット7"             , { "Aでレコード開始", }, },
			{ "スロット8"             , { "Aでレコード開始", }, },
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
				1, -- スロット6          7
				1, -- スロット7          8
				1, -- スロット8          9
			},
		},
		on_a = {
			menu_rec_to_tra, -- 説明
			function() exit_menu_to_rec(1) end, -- スロット1
			function() exit_menu_to_rec(2) end, -- スロット2
			function() exit_menu_to_rec(3) end, -- スロット3
			function() exit_menu_to_rec(4) end, -- スロット4
			function() exit_menu_to_rec(5) end, -- スロット5
			function() exit_menu_to_rec(6) end, -- スロット6
			function() exit_menu_to_rec(7) end, -- スロット7
			function() exit_menu_to_rec(8) end, -- スロット8
		},
		on_b = {
			menu_rec_to_tra, -- 説明
			menu_to_tra, -- スロット1
			menu_to_tra, -- スロット2
			menu_to_tra, -- スロット3
			menu_to_tra, -- スロット4
			menu_to_tra, -- スロット5
			menu_to_tra, -- スロット6
			menu_to_tra, -- スロット7
			menu_to_tra, -- スロット8
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
			{ "スロット6"             , { "OFF", "ON", }, },
			{ "スロット7"             , { "OFF", "ON", }, },
			{ "スロット8"             , { "OFF", "ON", }, },
			{ "                        リプレイ設定" },
			{ "繰り返し"              , { "OFF", "ON", }, },
			{ "繰り返し間隔"          , play_interval, },
			{ "繰り返し開始条件"      , { "なし", "両キャラがニュートラル", }, },
			{ "開始間合い固定"        , { "OFF", "1Pと2P", "1P", "2P", }, },
			{ "状態リセット"          , { "OFF", "1Pと2P", "1P", "2P", }, },
			{ "ガイド表示"            , { "OFF", "ON", }, },
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
				2, -- スロット6          7
				2, -- スロット7          8
				2, -- スロット8          9
				0, -- リプレイ設定      10
				1, -- 繰り返し          11
				1, -- 繰り返し間隔      12
				1, -- 繰り返し開始条件  13
				global.replay_fix_pos, -- 開始間合い固定    14
				global.replay_reset,   -- 状態リセット      15
				2, -- ガイド表示        16
				1, -- 開始間合い        17
			},
		},
		on_a = {
			exit_menu_to_play, -- 説明
			exit_menu_to_play, -- スロット1
			exit_menu_to_play, -- スロット2
			exit_menu_to_play, -- スロット3
			exit_menu_to_play, -- スロット4
			exit_menu_to_play, -- スロット5
			exit_menu_to_play, -- スロット6
			exit_menu_to_play, -- スロット7
			exit_menu_to_play, -- スロット8
			exit_menu_to_play, -- リプレイ設定
			exit_menu_to_play, -- 繰り返し
			exit_menu_to_play, -- 繰り返し間隔
			exit_menu_to_play, -- 繰り返し開始条件
			exit_menu_to_play, -- 開始間合い固定
			exit_menu_to_play, -- 状態リセット
			exit_menu_to_play, -- ガイド表示
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
			exit_menu_to_play_cancel, -- スロット6
			exit_menu_to_play_cancel, -- スロット7
			exit_menu_to_play_cancel, -- スロット8
			exit_menu_to_play_cancel, -- リプレイ設定
			exit_menu_to_play_cancel, -- 繰り返し
			exit_menu_to_play_cancel, -- 繰り返し間隔
			exit_menu_to_play_cancel, -- 開始間合い固定
			exit_menu_to_play_cancel, -- 状態リセット
			exit_menu_to_play_cancel, -- ガイド表示
			exit_menu_to_play_cancel, -- 開始間合い
		},
	}
	init_auto_menu_config()
	init_ex_menu_config()
	init_bar_menu_config()
	init_menu_config()
	init_restart_fight()
	menu_to_main(true)

	menu = {}
	menu.proc = function()
		-- メニュー表示中はDIPかポーズでフリーズさせる
		set_freeze(false)
	end
	menu.draw = function()
		local scr = manager.machine.screens:at(1)
		local ec = scr:frame_number()
		local state_past = ec - global.input_accepted
		local width = scr.width * scr.xscale
		local height = scr.height * scr.yscale

		if not match_active or player_select_active then
			return
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
		elseif accept_input("Button 3", joy_val, state_past) then
			-- カーソル左10移動
			local cols = menu_cur.list[menu_cur.pos.row][2]
			if cols then
				local col_pos = menu_cur.pos.col
				col_pos[menu_cur.pos.row] = col_pos[menu_cur.pos.row] and (col_pos[menu_cur.pos.row]-10) or 1
				if col_pos[menu_cur.pos.row] <= 0 then
					col_pos[menu_cur.pos.row] = 1
				end
			end
			global.input_accepted = ec
		elseif accept_input("Button 4", joy_val, state_past) then
			-- カーソル右10移動
			local cols = menu_cur.list[menu_cur.pos.row][2]
			if cols then
				local col_pos = menu_cur.pos.col
				col_pos[menu_cur.pos.row] = col_pos[menu_cur.pos.row] and (col_pos[menu_cur.pos.row]+10) or 11
				if col_pos[menu_cur.pos.row] > #cols then
					col_pos[menu_cur.pos.row] = #cols
				end
			end
			global.input_accepted = ec
		end

		-- メニュー表示本体
		scr:draw_box (0, 0, width, height, 0xC0000000, 0xC0000000)
		local row_num, menu_max = 1, math.min(menu_cur.pos.offset+menu_max_row, #menu_cur.list)
		for i = menu_cur.pos.offset, menu_max do
			local row = menu_cur.list[i]
			local y = 48+10*row_num
			local c1, c2, c3, c4, c5
			-- 選択行とそうでない行の色分け判断
			if i == menu_cur.pos.row then
				c1, c2, c3, c4, c5 = 0xFFDD2200, 0xFF662200, 0xFFFFFF00, 0xCC000000, 0xAAFFFFFF
				-- アクティブメニュー項目のビカビカ処理
				local deep, _ = math.modf((scr:frame_number() / 5) % 20) + 1
				c1 = c1 - (0x00110000 * math.abs(deep - 10))
			else
				c1, c2, c3, c4, c5 = 0xFFC0C0C0, 0xFFB0B0B0, 0xFF000000, 0x00000000, 0xFF000000
			end
			if is_label_line(row[1]) then
				-- ラベルだけ行
				scr:draw_text(96  , y+1  , row[1], 0xFFFFFFFF)
			else
				-- 通常行 ラベル部分
				scr:draw_box (90  , y+0.5, 230   , y+8.5, c2, c1)
				if i == menu_cur.pos.row then
					scr:draw_line(90  , y+0.5, 230 , y+0.5, 0xFFDD2200)
					scr:draw_line(90  , y+0.5, 90  , y+8.5, 0xFFDD2200)
				else
					scr:draw_box (90  , y+7.0, 230 , y+8.5, 0xFFB8B8B8, 0xFFB8B8B8)
					scr:draw_box (90  , y+8.0, 230 , y+8.5, 0xFFA8A8A8, 0xFFA8A8A8)
				end
				scr:draw_text(96.5, y+1.5, row[1], c4)
				scr:draw_text(96  , y+1  , row[1], c3)
				if row[2] then
					-- 通常行 オプション部分
					local col_pos_num = menu_cur.pos.col[i] or 1
					if col_pos_num > 0 then
						scr:draw_text(165.5, y+1.5, string.format("%s", row[2][col_pos_num]), c4)
						scr:draw_text(165  , y+1  , string.format("%s", row[2][col_pos_num]), c3)
						-- オプション部分の左右移動可否の表示
						if i == menu_cur.pos.row then
							scr:draw_text(160, y+1, "◀", col_pos_num == 1       and c5 or c3)
							scr:draw_text(223, y+1, "▶", col_pos_num == #row[2] and c5 or c3)
						end
					end
				end
				if row[3] and row[3].outline then
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
		if not manager.machine.devices[":maincpu"] then
			return
		end
		local pgm = manager.machine.devices[":maincpu"].spaces["program"]
		local scr = manager.machine.screens:at(1)
		local width = scr.width * scr.xscale

		-- フレーム更新しているかチェック更新
		local ec = scr:frame_number()
		if mem_last_time == ec then
			return
		end
		mem_last_time = ec

		-- メモリ値の読込と更新
		mem_0x100701  = pgm:read_u16(0x100701) -- 22e 22f 対戦中
		mem_0x107C22  = pgm:read_u16(0x107C22) -- 対戦中4400
		mem_0x10B862  = pgm:read_u8(0x10B862) -- 対戦中00
		mem_0x10D4EA  = pgm:read_u8(0x10D4EA)
		mem_0x10FD82  = pgm:read_u8(0x10FD82)
		mem_0x10FDAF  = pgm:read_u8(0x10FDAF)
		mem_0x10FDB6  = pgm:read_u16(0x10FDB6)
		mem_biostest  = bios_test()
		mem_0x10E043  = pgm:read_u8(0x10E043)
		prev_p_space  = (p_space ~= 0) and p_space or prev_p_space

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
				--print("player_select_active = true")
			end
			player_select_active = true
			pgm:write_u8(mem_0x10D4EA, 0x00)
		else
			if player_select_active then
				--print("player_select_active = false")
			end
			player_select_active = false -- 状態リセット
			pgm:write_u8(mem_0x10CDD0)
			pgm:write_u32(players[1].addr.select_hook)
			pgm:write_u32(players[2].addr.select_hook)
		end

		--状態チェック用
		--[[
		local vv = string.format("%x %x %x %x", mem_0x100701, mem_0x107C22, mem_0x10FDAF, mem_0x10FDB6)
		if not bufuf[vv] and not active_mem_0x100701[mem_0x100701] then
			bufuf[vv] = vv
			print(vv)
		end
		]]

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

			-- リバーサルとBSモードの仕込み部分
			-- 実質効いていない避け攻撃ぽいコマンドデータを1発BS用の入れ物に使う
			-- 0xCB243の読込後にD1を技IDに差し替えれば未入力(00)で技が出る。下は例。
			-- bp 03957E,{((A6)==CB244)&&((A4)==100400)&&(maincpu.pb@10048E==2)},{D1=1;g}
			-- bp 03957E,{((A6)==CB244)&&((A4)==100500)&&(maincpu.pb@10058E==2)},{D1=1;g}
			-- 末尾1バイトの20は技のIDになるが、プログラム中で1Eまでの値しか通さないのと、00だと無害。
			pgm:write_direct_u32(0xCB240, 0xF000FF00)
			pgm:write_direct_u16(0xCB244, 0x0000)

			-- 逆襲拳、サドマゾの初段で相手の状態変更しない（相手が投げられなくなる事象が解消する）
			-- pgm:write_direct_u8(0x57F43, 0x00)
		end

		-- 強制的に家庭用モードに変更
		if not mem_biostest then
			pgm:write_direct_u16(0x10FE32, 0x0000)
		end

		-- デバッグDIP
		local dip1, dip2, dip3 = 0x00, 0x00, 0x00
		if match_active and dip_config.show_hitbox then
			--dip1 = dip1 | 0x40    --cheat "DIP= 1-7 色々な判定表示"
			dip1 = dip1 | 0x80    --cheat "DIP= 1-8 当たり判定表示"
		end
		if match_active and dip_config.infinity_life then
			dip1 = dip1 | 0x02    --cheat "DIP= 1-2 Infinite Energy"
		end
		if match_active and dip_config.easy_super then
			dip2 = dip2 | 0x01    --Cheat "DIP 2-1 Eeasy Super"
		end
		if dip_config.infinity_time then
			dip2 = dip2 | 0x10    --cheat "DIP= 2-5 Disable Time Over"
			-- 家庭用オプションの時間無限大設定
			pgm:write_u8(0x10E024, 0x03) -- 1:45 2:60 3:90 4:infinity
			pgm:write_u8(0x107C28, 0xAA) --cheat "Infinite Time"
		else
			pgm:write_u8(0x107C28, dip_config.fix_time)
		end
		if dip_config.stage_select then
			dip1 = dip1 | 0x04    --cheat "DIP= 1-3 Stage Select Mode"
		end
		if player_select_active and dip_config.alfred then
			dip2 = dip2 | 0x80    --cheat "DIP= 2-8 Alfred Code (B+C >A)"
		end
		if match_active and dip_config.watch_states then
			dip2 = dip2 | 0x20    --cheat "DIP= 2-6 Watch States"
		end
		if match_active and dip_config.cpu_cant_move then
			dip3 = dip3 | 0x01    --cheat "DIP= 3-1 CPU Can't Move"
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
		main_or_menu_state.proc()

		-- メニュー切替のタイミングでフック用に記録した値が状態変更後に謝って読みこまれないように常に初期化する
		cls_hook()
	end

	-- メニューの初期化
	if menu_cur == nil then
		menu_cur = main_menu
		--bar_menu_to_main()
		--menu_to_main()
	end

	emu.register_frame_done(function()
		main_or_menu_state.draw()
		--collectgarbage("collect")
	end)

	emu.register_periodic(function()
		main_or_menu()
		if global.mame_debug_wnd == false then
			auto_recovery_debug()
		end
	end)
end

return exports
