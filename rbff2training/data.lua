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
local ut         = require("rbff2training/util")
local db         = {}

--------------------------------------------------------------------------------------
-- キャラの基本データ
-- 配列のインデックス=キャラID
--------------------------------------------------------------------------------------

local char_id      = {
	terry = 0x01,
	andy = 0x02,
	joe = 0x03,
	mai = 0x04,
	geese = 0x05,
	sokaku = 0x06,
	bob = 0x07,
	honfu = 0x08,
	marry = 0x09,
	franco = 0x0A,
	yamazaki = 0x0B,
	chonshu = 0x0C,
	chonrei = 0x0D,
	duck = 0x0E,
	kim = 0x0F,
	billy = 0x10,
	chin = 0x11,
	tung = 0x12,
	lawrence = 0x13,
	krauser = 0x14,
	rick = 0x15,
	xiangfei = 0x16,
	alfred = 0x17,
}
local chars      = {
	{ id = char_id.terry   , min_y = 9, min_sy = 5, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x3, bs_addr = 0x2E, easy_bs_addr = 0x2E, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 18 }, }, name = "テリー・ボガード", name_en = "Terry" },
	{ id = char_id.andy    , min_y = 10, min_sy = 4, init_stuns = 31, wakeup_frms = 20, sway_act_counts = 0x2, bs_addr = 0x2A, easy_bs_addr = 0x2A, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 18 }, }, name = "アンディ・ボガード", name_en = "Andy" },
	{ id = char_id.joe     , min_y = 8, min_sy = 3, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x4, bs_addr = 0x3A, easy_bs_addr = 0x3A, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 18 }, }, name = "東丈", name_en = "Joe" },
	{ id = char_id.mai     , min_y = 10, min_sy = 3, init_stuns = 29, wakeup_frms = 17, sway_act_counts = 0x3, bs_addr = 0x22, easy_bs_addr = 0x22, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 18 }, }, name = "不知火舞", name_en = "Mai" },
	{ id = char_id.geese   , min_y = 8, min_sy = 1, init_stuns = 33, wakeup_frms = 20, sway_act_counts = 0x3, bs_addr = 0x66, easy_bs_addr = 0x4A, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 19 }, }, name = "ギース・ハワード", name_en = "Geese" },
	{ id = char_id.sokaku  , min_y = 2, min_sy = 5, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x2, bs_addr = 0x46, easy_bs_addr = 0x46, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 18 }, }, name = "望月双角", name_en = "Sokaku" },
	{ id = char_id.bob     , min_y = 9, min_sy = 6, init_stuns = 31, wakeup_frms = 20, sway_act_counts = 0x2, bs_addr = 0x2A, easy_bs_addr = 0x2A, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 19 }, }, name = "ボブ・ウィルソン", name_en = "Bob" },
	{ id = char_id.honfu   , min_y = 10, min_sy = 3, init_stuns = 31, wakeup_frms = 20, sway_act_counts = 0x3, bs_addr = 0x32, easy_bs_addr = 0x32, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 16 }, }, name = "ホンフゥ", name_en = "Hon-Fu" },
	{ id = char_id.marry   , min_y = 9, min_sy = 7, init_stuns = 29, wakeup_frms = 20, sway_act_counts = 0x3, bs_addr = 0x3E, easy_bs_addr = 0x3E, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 41 }, }, name = "ブルー・マリー", name_en = "Marry" },
	{ id = char_id.franco  , min_y = 9, min_sy = 4, init_stuns = 35, wakeup_frms = 20, sway_act_counts = 0x3, bs_addr = 0x2A, easy_bs_addr = 0x2A, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 15 }, }, name = "フランコ・バッシュ", name_en = "Franco" },
	{ id = char_id.yamazaki, min_y = 9, min_sy = 4, init_stuns = 38, wakeup_frms = 20, sway_act_counts = 0x2, bs_addr = 0x56, easy_bs_addr = 0x3A, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 18 }, { name = "中蛇", f = 9, } }, name = "山崎竜二", name_en = "Yamazaki" },
	{ id = char_id.chonshu , min_y = 11, min_sy = 1, init_stuns = 29, wakeup_frms = 20, sway_act_counts = 0xC, bs_addr = 0x3A, easy_bs_addr = 0x3A, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 57 }, { name = "真眼", f = 47, } }, name = "秦崇秀", name_en = "Chonshu" },
	{ id = char_id.chonrei , min_y = 11, min_sy = 4, init_stuns = 29, wakeup_frms = 20, sway_act_counts = 0xC, bs_addr = 0x36, easy_bs_addr = 0x36, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 27 }, { name = "龍転", f = 25, } }, name = "秦崇雷", name_en = "Chonrei" },
	{ id = char_id.duck    , min_y = 9, min_sy = 6, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x2, bs_addr = 0x7A, easy_bs_addr = 0x5E, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 47 }, }, name = "ダック・キング", name_en = "Duck" },
	{ id = char_id.kim     , min_y = 9, min_sy = 5, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x4, bs_addr = 0x36, easy_bs_addr = 0x36, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 19 }, { name = "覇気", f = 28, } }, name = "キム・カッファン", name_en = "Kim" },
	{ id = char_id.billy   , min_y = 4, min_sy = 3, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x4, bs_addr = 0x2A, easy_bs_addr = 0x2A, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 42 }, }, name = "ビリー・カーン", name_en = "Billy" },
	{ id = char_id.chin    , min_y = 9, min_sy = 6, init_stuns = 31, wakeup_frms = 20, sway_act_counts = 0x2, bs_addr = 0x2E, easy_bs_addr = 0x2E, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 23 }, { name = "軟体", f = 20, } }, name = "チン・シンザン", name_en = "Chin" },
	{ id = char_id.tung    , min_y = 11, min_sy = 0, init_stuns = 31, wakeup_frms = 20, sway_act_counts = 0x4, bs_addr = 0x22, easy_bs_addr = 0x22, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 19 }, }, name = "タン・フー・ルー", name_en = "Tung" },
	{ id = char_id.lawrence, min_y = 7, min_sy = 4, init_stuns = 35, wakeup_frms = 20, sway_act_counts = 0x4, bs_addr = 0x22, easy_bs_addr = 0x22, acts = {}, fireballs = {}, faint_cancel = {}, name = "ローレンス・ブラッド", name_en = "Lawrence" },
	{ id = char_id.krauser , min_y = 7, min_sy = 2, init_stuns = 35, wakeup_frms = 20, sway_act_counts = 0x3, bs_addr = 0x52, easy_bs_addr = 0x36, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 17 }, }, name = "ヴォルフガング・クラウザー", name_en = "Krauser" },
	{ id = char_id.rick    , min_y = 9, min_sy = 5, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x7, bs_addr = 0x26, easy_bs_addr = 0x26, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 18 }, }, name = "リック・ストラウド", name_en = "Rick" },
	{ id = char_id.xiangfei, min_y = 9, min_sy = 5, init_stuns = 29, wakeup_frms = 14, sway_act_counts = 0x3, bs_addr = 0x52, easy_bs_addr = 0x32, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 22 }, }, name = "李香緋", name_en = "Xiangfei" },
	{ id = char_id.alfred  , min_y = 10, min_sy = 4, init_stuns = 32, wakeup_frms = 20, sway_act_counts = 0x0, bs_addr = 0x2A, easy_bs_addr = 0x2A, acts = {}, fireballs = {}, faint_cancel = { { name = "フ", f = 13 }, }, name = "アルフレッド", name_en = "Alfred" },
	{ id = 0x18            , min_y = 0, min_sy = 0, init_stuns = 0, wakeup_frms = 0, sway_act_counts = 0x0, bs_addr = 0x0, easy_bs_addr = 0x0, acts = {}, fireballs = {}, faint_cancel = {}, name = "common", },
}
db.char_id       = char_id
db.chars         = chars

chars[0x5].pow   = {
	[0x7C] = { pow_revenge = 6 }, -- 当身投げ
	[0x82] = { pow_revenge = 6 }, -- 当身投げ
	[0x88] = { pow_revenge = 6 }, -- 当身投げ
}
chars[0xB].pow   = {
	[0x82] = { pow_revenge = 6 },               -- サドマゾ
	[0x8E] = { pow_revenge = 7, pow_absorb = 20 }, -- 倍返し
	[0xA0] = { pow_up_hit = 7 },                -- トドメ
}
chars[0x8].pow   = {
	[0x94] = { pow_revenge = 6 }, -- 逆襲脚
}
chars[0x14].pow  = {
	[0x82] = { pow_revenge = 6 }, -- フェニックススルー
}

local char_names = {}
for _, char_data in ipairs(chars) do
	if char_data.name ~= "common" then table.insert(char_names, char_data.name) end
end
db.char_names = char_names


--------------------------------------------------------------------------------------
-- 行動の種類
-- キャラの基本データに追加する
--------------------------------------------------------------------------------------

local act_types                  = {
	free = 2 ^ 0,
	attack = 2 ^ 1,
	low_attack = 2 ^ 2,
	provoke = 2 ^ 3,
	any = 2 ^ 4,
	overhead = 2 ^ 5,
	block = 2 ^ 6,
	hit = 2 ^ 7,
	startup = 2 ^ 8,
	wrap = 2 ^ 9,
	preserve = 2 ^ 10,
	shooting = 2 ^ 11,
	startup_if_ca = 2 ^ 12, -- CAのときのみ開始動作としてフレームデータを作成する
	lunging_throw = 2 ^ 13, -- 移動投げ
	rec_in_detail = 2 ^ 14, -- フレームデータの作成時に判定を詳細に記録する
	parallel = 2 ^ 15,   -- 本体と並列動作する弾
	jump_attack = 2 ^ 16,
}
act_types.low_attack             = act_types.attack | act_types.low_attack
act_types.overhead               = act_types.attack | act_types.overhead
act_types.unblockable            = act_types.low_attack | act_types.overhead
db.act_types                     = act_types

local block_types                = {
	high = 2 ^ 0,   -- 上ガード
	tung = 2 ^ 1,   -- タンのみ上ガードできる位置
	high_low = 2 ^ 2, -- 上ガードだけど上ガードできない位置
	low = 2 ^ 3,    -- 下ガード
	air = 2 ^ 4,    -- 空中ガード可能
	sway = 2 ^ 5,   -- スウェー上でガード
	sway_pass = 2 ^ 6, -- スウェー無敵
}
block_types.high_tung            = block_types.high | block_types.tung
block_types.sway_high            = block_types.sway | block_types.high      -- スウェー上で上ガード
block_types.sway_high_tung       = block_types.sway | block_types.high_tung -- スウェー上でタンのみ上ガードできる位置
block_types.sway_high_low        = block_types.sway | block_types.high_low  -- スウェー上で上ガードだけど上ガードできない位置
block_types.sway_low             = block_types.sway | block_types.low       -- スウェー上で下ガード
db.block_types                   = block_types

--- メインライン上の下段ガードが必要（中段ガードの範囲外）になる高さ
local top_types                  = {
	{ top = 0xFFFF, act_type = act_types.attack },
	{ top = 48,     act_type = act_types.low_attack }, -- タン以外
	{ top = 36,     act_type = act_types.low_attack }, -- 全キャラ
}
--- スウェーライン上の下段ガードが必要（中段ガードの範囲外）になる高さ
local top_sway_types             = {
	{ top = 0xFFFF, act_type = act_types.attack },
	{ top = 59,     act_type = act_types.low_attack }, -- タン以外
	{ top = 48,     act_type = act_types.low_attack }, -- 全キャラ
}

local frame_attack_types         = {
	fb                = 2 ^ 0, -- 0x 1 0000 0001 弾
	attacking         = 2 ^ 1, -- 0x 2 0000 0010 攻撃動作中
	juggle            = 2 ^ 2, -- 0x 4 0000 0100 空中追撃可能
	fake              = 2 ^ 3, -- 0x 8 0000 1000 攻撃能力なし(判定初期から)
	obsolute          = 2 ^ 4, -- 0x F 0001 0000 攻撃能力なし(動作途中から)
	fullhit           = 2 ^ 5, -- 0x20 0010 0000 全段ヒット状態
	harmless          = 2 ^ 6, -- 0x40 0100 0000 攻撃データIDなし
	frame_plus        = 2 ^ 7, -- フレーム有利：Frame advantage
	frame_minus       = 2 ^ 8, -- フレーム不利：Frame disadvantage,
	pre_fireball      = 2 ^ 9, -- 弾処理中
	post_fireball     = 2 ^ 10, -- 弾処理中
	on_fireball       = 2 ^ 11, -- 弾判定あり
	off_fireball      = 2 ^ 12, -- 弾判定あり
	throw_indiv20     = 2 ^ 13, -- 地上コマンド投げ無敵(タイマー20)
	throw_indiv10     = 2 ^ 14, -- 地上コマンド投げ無敵(タイマー10)
	throw_indiv_n     = 2 ^ 15, -- 通常投げ無敵(タイマー24)
	full              = 2 ^ 16, -- 全身無敵
	main              = 2 ^ 17, -- メインライン攻撃無敵
	sway              = 2 ^ 18, -- メインライン攻撃無敵
	high              = 2 ^ 19, -- 上段攻撃無敵
	low               = 2 ^ 20, -- 下段攻撃無敵
	away              = 2 ^ 21, -- 上半身無敵 32 避け
	waving_blow       = 2 ^ 22, -- 上半身無敵 40 ウェービングブロー,龍転身,ダブルローリング
	lawrence_away     = 2 ^ 23, -- 上半身無敵 48 ローレンス避け
	--	crounch60           = , -- 頭部無敵 60 屈 アンディ,東,舞,ホンフゥ,マリー,山崎,崇秀,崇雷,キム,ビリー,チン,タン
	--	crounch64           = , -- 頭部無敵 64 屈 テリー,ギース,双角,ボブ,ダック,リック,シャンフェイ,アルフレッド
	--	crounch68           = , -- 頭部無敵 68 屈 ローレンス
	--	crounch76           = , -- 頭部無敵 76 屈 フランコ
	--	crounch80           = , -- 頭部無敵 80 屈 クラウザー
	levitate40        = 2 ^ 24,                                 -- 足元無敵 対アンディ屈C
	levitate32        = 2 ^ 25,                                 -- 足元無敵 対ギース屈C
	levitate24        = 2 ^ 26,                                 -- 足元無敵 対だいたいの屈B（キムとボブ以外）
	on_air            = 2 ^ 27,                                 -- ジャンプ
	on_ground         = 2 ^ 28,                                 -- 着地
	on_additional_r1  = 2 ^ 29,                                 -- 追加入力確認
	on_additional_r5  = 2 ^ 30,                                 -- 追加入力確認
	on_additional_rsp = 2 ^ 30,                                 -- 追加入力確認
	on_additional_w1  = 2 ^ 31,                                 -- 追加入力確認
	on_additional_w5  = 2 ^ 32,                                 -- 追加入力確認
	on_additional_wsp = 2 ^ 32,                                 -- 追加入力確認
	on_main_line      = 2 ^ 33,                                 -- フレームメーターの装飾用 メインラインへの遷移
	on_main_to_sway   = 2 ^ 34,                                 -- フレームメーターの装飾用 メインラインからの遷移
	act_count         = 35,                                     -- act_count 本体の動作区切り用
	attack            = 43,                                     -- attack
	act               = 51,                                     -- act

	op_cancelable     = 2 ^ 1,                                  -- 0x 2 0000 0010 やられ中で相手キャンセル可能
}
frame_attack_types.fb_effect     = frame_attack_types.act_count -- effect 弾の動作区切り用
frame_attack_types.mask_multihit = (0xFF << frame_attack_types.act_count) | (0xFF << frame_attack_types.fb_effect)
frame_attack_types.mask_attack   = 0xFF << frame_attack_types.attack
frame_attack_types.mask_act      = 0xFFFF << frame_attack_types.act
frame_attack_types.mask_fake     = frame_attack_types.fake
frame_attack_types.mask_fireball =
	frame_attack_types.pre_fireball |
	frame_attack_types.post_fireball |
	frame_attack_types.on_fireball |
	frame_attack_types.off_fireball
frame_attack_types.frame_advance =
	frame_attack_types.frame_plus |
	frame_attack_types.frame_minus
frame_attack_types.mask_jump     =
	frame_attack_types.on_air |
	frame_attack_types.on_ground
frame_attack_types.hits          =
	frame_attack_types.attacking |
	frame_attack_types.fake |
	frame_attack_types.fb |
	frame_attack_types.fullhit |
	frame_attack_types.harmless |
	frame_attack_types.juggle |
	frame_attack_types.obsolute
frame_attack_types.simple_mask   = ut.hex_clear(0xFFFFFFFFFFFFFFFF,
	frame_attack_types.mask_multihit |
	frame_attack_types.mask_attack |
	frame_attack_types.mask_act |
	frame_attack_types.hits |
	frame_attack_types.mask_fireball)
frame_attack_types.dodge_mask    = ut.hex_clear(0xFFFFFFFFFFFFFFFF,
	-- 過剰に部分無敵表示しない
	frame_attack_types.main          | -- メインライン攻撃無敵
	frame_attack_types.sway          | -- メインライン攻撃無敵
	frame_attack_types.high          | -- 上段攻撃無敵
	frame_attack_types.low)         -- 下段攻撃無敵
--	frame_attack_types.crounch60     |                                                    -- 頭部無敵 60 屈 アンディ,東,舞,ホンフゥ,マリー,山崎,崇秀,崇雷,キム,ビリー,チン,タン
--	frame_attack_types.crounch64     |                                                    -- 頭部無敵 64 屈 テリー,ギース,双角,ボブ,ダック,リック,シャンフェイ,アルフレッド
--	frame_attack_types.crounch68     |                                                    -- 頭部無敵 68 屈 ローレンス
--	frame_attack_types.crounch76     |                                                    -- 頭部無敵 76 屈 フランコ
--	frame_attack_types.crounch80)                                                         -- 頭部無敵 80 屈 クラウザー
frame_attack_types.juggle_mask   = ut.hex_clear(0xFFFFFFFFFFFFFFFF,
	frame_attack_types.juggle)
frame_attack_types.main_high     = frame_attack_types.main | frame_attack_types.high -- 対メイン上段攻撃無敵
frame_attack_types.main_low      = frame_attack_types.main | frame_attack_types.low  -- 対メイン下段攻撃無敵
frame_attack_types.sway_high     = frame_attack_types.sway | frame_attack_types.high -- 上半身無敵 対スウェー上段攻撃無敵
frame_attack_types.sway_low      = frame_attack_types.sway | frame_attack_types.low  -- 下半身無敵 対スウェー下段攻撃無敵
frame_attack_types.high_dodges   =                                                   -- 部分無敵としてフレーム表示に反映する部分無敵
	frame_attack_types.away          |                                               -- 上半身無敵 32 避け
	frame_attack_types.waving_blow   |                                               -- 上半身無敵 40 ウェービングブロー,龍転身,ダブルローリング
	frame_attack_types.lawrence_away                                                 -- 上半身無敵 48 ローレンス避け
frame_attack_types.low_dodges    =                                                   -- 部分無敵としてフレーム表示に反映する部分無敵
	frame_attack_types.levitate40    |                                               -- 足元無敵 対アンディ屈C
	frame_attack_types.levitate32    |                                               -- 足元無敵 対ギース屈C
	frame_attack_types.levitate24                                                    -- 足元無敵 対だいたいの屈B（キムとボブ以外）
frame_attack_types.throw_indiv   =                                                   -- 投げ無敵
	frame_attack_types.throw_indiv_n |                                               -- 通常投げ無敵
	frame_attack_types.throw_indiv20 |                                               -- 地上コマンド投げ無敵(タイマー20)
	frame_attack_types.throw_indiv10                                                 -- 地上コマンド投げ無敵(タイマー10)
db.frame_attack_types            = frame_attack_types

-- モーションによる部分無敵
local hurt_dodge_types           = {
	{ top = nil, bottom = nil, act_type = 0 },
	{ top = nil, bottom = 24,  act_type = frame_attack_types.low | frame_attack_types.levitate24, }, -- 足元無敵 対だいたいの屈B（キムとボブ以外）
	{ top = nil, bottom = 32,  act_type = frame_attack_types.low | frame_attack_types.levitate32, }, -- 足元無敵 対ギース屈C
	{ top = nil, bottom = 40,  act_type = frame_attack_types.low | frame_attack_types.levitate40, }, -- 足元無敵 対アンディ屈C
	--	{ top = 80,  bottom = nil, act_type = frame_attack_types.high | frame_attack_types.crounch80, },  -- 頭部無敵 80 屈 クラウザー
	--	{ top = 76,  bottom = nil, act_type = frame_attack_types.high | frame_attack_types.crounch76, },  -- 頭部無敵 76 屈 フランコ
	--	{ top = 68,  bottom = nil, act_type = frame_attack_types.high | frame_attack_types.crounch68, },  -- 頭部無敵 68 屈 ローレンス
	--	{ top = 64,  bottom = nil, act_type = frame_attack_types.high | frame_attack_types.crounch64, },  -- 頭部無敵 64 屈 テリー,ギース,双角,ボブ,ダック,リック,シャンフェイ,アルフレッド
	--	{ top = 60,  bottom = nil, act_type = frame_attack_types.high | frame_attack_types.crounch60, },  -- 頭部無敵 60 屈 アンディ,東,舞,ホンフゥ,マリー,山崎,崇秀,崇雷,キム,ビリー,チン,タン
	{ top = 48,  bottom = nil, act_type = frame_attack_types.high | frame_attack_types.lawrence_away, }, -- 上半身無敵 48 ローレンス避け
	{ top = 40,  bottom = nil, act_type = frame_attack_types.high | frame_attack_types.waving_blow, }, -- 上半身無敵 40 ウェービングブロー,龍転身,ダブルローリング
	{ top = 32,  bottom = nil, act_type = frame_attack_types.high | frame_attack_types.away, },       --上半身無敵 32 避け
}
local hurt_dodge_names           = {
	[frame_attack_types.away] = "Away",
	--	[frame_attack_types.crounch60] = "c.Andy",
	--	[frame_attack_types.crounch64] = "c.Terry",
	--	[frame_attack_types.crounch68] = "c.Lawrence",
	--	[frame_attack_types.crounch76] = "c.Franco",
	--	[frame_attack_types.crounch80] = "c.Krauser",
	[frame_attack_types.full] = "Full",
	[frame_attack_types.lawrence_away] = "Lau.Away",
	[frame_attack_types.levitate24] = "c.B",
	[frame_attack_types.levitate32] = "c.Geese-C",
	[frame_attack_types.levitate40] = "c.Andy-C",
	[frame_attack_types.main] = "Main",
	[frame_attack_types.main_high] = "Sway High",
	[frame_attack_types.main_low] = "Sway Low",
	[frame_attack_types.sway_high] = "High",
	[frame_attack_types.sway_low] = "Low",
	[frame_attack_types.waving_blow] = "W.Blow",
}
db.get_punish_name               = function(type, null_value)
	for _, atype in ipairs({
		frame_attack_types.away,
		frame_attack_types.waving_blow,
		frame_attack_types.lawrence_away,
		--		frame_attack_types.crounch60,
		--		frame_attack_types.crounch64,
		--		frame_attack_types.crounch68,
		--		frame_attack_types.crounch76,
		--		frame_attack_types.crounch80,
	}) do if ut.tstb(type, atype, true) then return hurt_dodge_names[atype] end end
	return null_value
end
db.get_low_dodge_name            = function(type, null_value)
	for _, atype in ipairs({
		frame_attack_types.levitate40,
		frame_attack_types.levitate32,
		frame_attack_types.levitate24,
	}) do if ut.tstb(type, atype, true) then return hurt_dodge_names[atype] end end
	return null_value
end
db.get_dodge_name                = function(type, null_value)
	local h, l = db.get_punish_name(type, null_value), db.get_low_dodge_name(type, null_value)
	for _, atype in ipairs({
		frame_attack_types.main_high,
		frame_attack_types.main_low,
		frame_attack_types.sway_high,
		frame_attack_types.sway_low,
		frame_attack_types.main,
		frame_attack_types.full,
	}) do if ut.tstb(type, atype, true) then return hurt_dodge_names[atype], h, l end end
	return null_value, h, l -- 部分無敵
end
db.hurt_dodge_types              = hurt_dodge_types
db.top_types                     = top_types
db.top_sway_types                = top_sway_types
local hit_top_names              = {
	[act_types.attack] = "High",
	[act_types.low_attack] = "Low",
	[act_types.overhead] = "Mid",
	[act_types.unblockable] = "Unbl.",
}
db.top_type_name                 = function(type)
	local air = ut.tstb(type, act_types.jump_attack, true) and "*" or nil
	for _, atype in ipairs({
		act_types.unblockable,
		act_types.overhead,
		act_types.low_attack,
		act_types.attack,
	}) do
		if ut.tstb(type, atype, true) then
			return air and (air .. hit_top_names[atype]) or hit_top_names[atype]
		end
	end
	return "-"
end
-- !!注意!!後隙が配列の後ろに来るように定義すること
local char_acts_base             = {
	-- テリー・ボガード
	{
		{ names = { "フェイント パワーゲイザー" }, type = act_types.any, ids = { 0x113, }, },
		{ names = { "フェイント バーンナックル" }, type = act_types.any, ids = { 0x112, }, },
		{ names = { "バスタースルー" }, type = act_types.any, ids = { 0x6D, 0x6E, }, },
		{ names = { "ワイルドアッパー" }, type = act_types.attack, ids = { 0x69, }, },
		{ names = { "バックスピンキック" }, type = act_types.attack, ids = { 0x68, }, },
		{ names = { "チャージキック" }, type = act_types.overhead, ids = { 0x6A, }, },
		{ names = { "小バーンナックル" }, type = act_types.attack, ids = { 0x86, 0x87, }, },
		{ names = { "小バーンナックル" }, type = act_types.any, ids = { 0x88, }, },
		{ names = { "大バーンナックル" }, type = act_types.attack, ids = { 0x90, 0x91, }, },
		{ names = { "大バーンナックル" }, type = act_types.any, ids = { 0x92, }, },
		{ names = { "パワーウェイブ" }, type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, }, },
		{ names = { "ラウンドウェイブ" }, type = act_types.low_attack, ids = { 0xA4, 0xA5, }, },
		{ names = { "ラウンドウェイブ" }, type = act_types.any, ids = { 0xA6, }, },
		{ names = { "ファイヤーキック" }, type = act_types.low_attack, ids = { 0xB8, 0xB9, }, },
		{ names = { "ファイヤーキック" }, type = act_types.any, ids = { 0xBC, }, },
		{ names = { "ファイヤーキック ヒット" }, type = act_types.attack, ids = { 0xBA, 0xBB, }, },
		{ names = { "クラックシュート" }, type = act_types.attack, ids = { 0xAE, 0xAF, }, },
		{ names = { "クラックシュート" }, type = act_types.any, ids = { 0xB0, }, },
		{ names = { "ライジングタックル" }, type = act_types.attack, ids = { 0xCC, 0xCD, 0xCE, }, },
		{ names = { "ライジングタックル" }, type = act_types.any, ids = { 0xCF, 0xD0, }, },
		{ names = { "パッシングスウェー" }, type = act_types.attack, ids = { 0xC2, 0xC3, }, },
		{ names = { "パッシングスウェー" }, type = act_types.attack, ids = { 0xC4, }, },
		{ names = { "パワーゲイザー" }, type = act_types.attack, ids = { 0xFE, 0xFF, }, },
		{ names = { "パワーゲイザー" }, type = act_types.attack, ids = { 0x100, }, },
		{ names = { "トリプルゲイザー" }, type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, }, },
		{ names = { "トリプルゲイザー" }, type = act_types.attack, ids = { 0x10E, }, },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x241, }, },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x242, }, },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x244, }, },
		{ names = { "CA _6_+C" }, type = act_types.attack, ids = { 0x245, }, },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x246, }, },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x247, }, },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x247, }, },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x240, }, },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x24C, }, },
		{ names = { "CA 屈C" }, type = act_types.attack, ids = { 0x243, }, },
		{ names = { "パワーチャージ" }, type = act_types.attack, ids = { 0x24D, }, },
		{ names = { "CA 対スウェーライン上段攻撃" }, type = act_types.overhead, ids = { 0x24A, }, },
		{ names = { "CA 対スウェーライン下段攻撃" }, type = act_types.low_attack, ids = { 0x24B, }, },
		{ names = { "パワーダンク" }, type = act_types.attack, ids = { 0xE0, }, },
		{ names = { "パワーダンク" }, type = act_types.overhead, ids = { 0xE1, }, },
		{ names = { "パワーダンク" }, type = act_types.attack, ids = { 0xE2, }, },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x248, }, },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x249, }, },
	},
	-- アンディ・ボガード
	{
		{ names = { "フェイント 残影拳" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "フェイント 飛翔拳" }, type = act_types.any, ids = { 0x113 } },
		{ names = { "フェイント 超裂破弾" }, type = act_types.any, ids = { 0x114 } },
		{ names = { "内股" }, type = act_types.attack, ids = { 0x6D, 0x6E } },
		{ names = { "上げ面" }, type = act_types.attack, ids = { 0x69 } },
		{ names = { "浴びせ蹴り" }, type = act_types.attack, ids = { 0x68 } },
		{ names = { "小残影拳" }, type = act_types.attack, ids = { 0x86, 0x87, 0x8A } },
		{ names = { "小残影拳" }, type = act_types.any, ids = { 0x88, 0x89 } },
		{ names = { "大残影拳" }, type = act_types.attack, ids = { 0x90, 0x91, 0x94 } },
		{ names = { "大残影拳" }, type = act_types.any, ids = { 0x92 } },
		{ names = { "疾風裏拳" }, type = act_types.attack, ids = { 0x95 } },
		{ names = { "大残影拳", "疾風裏拳" }, type = act_types.any, ids = { 0x93 } },
		{ names = { "飛翔拳" }, type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C }, },
		{ names = { "激飛翔拳" }, type = act_types.attack, ids = { 0xA7, 0xA4, 0xA5 }, },
		{ names = { "激飛翔拳" }, type = act_types.any, ids = { 0xA6 } },
		{ names = { "昇龍弾" }, type = act_types.attack, ids = { 0xAE, 0xAF } },
		{ names = { "昇龍弾" }, type = act_types.any, ids = { 0xB0, 0xB1 } },
		{ names = { "空破弾" }, type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA } },
		{ names = { "空破弾" }, type = act_types.any, ids = { 0xBB } },
		{ names = { "幻影不知火" }, type = act_types.attack, ids = { 0xC8, 0xC2 } },
		{ names = { "幻影不知火" }, type = act_types.any, ids = { 0xC3 } },
		{ names = { "幻影不知火 地上攻撃" }, type = act_types.attack, ids = { 0xC4, 0xC5, 0xC6 } },
		{ names = { "幻影不知火 地上攻撃" }, type = act_types.any, ids = { 0xC7 } },
		{ names = { "超裂破弾" }, type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101 } },
		{ names = { "男打弾" }, type = act_types.attack, ids = { 0x108, 0x109, 0x10A }, },
		{ names = { "男打弾 2段目" }, type = act_types.attack, ids = { 0x10B }, },
		{ names = { "男打弾 3段目" }, type = act_types.attack, ids = { 0x10C }, },
		{ names = { "男打弾 4段目" }, type = act_types.attack, ids = { 0x10D }, },
		{ names = { "男打弾 5段目" }, type = act_types.attack, ids = { 0x10E, 0x10F }, },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x240 } },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x241 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x242 } },
		{ names = { "CA _6_+C" }, type = act_types.attack, ids = { 0x243 } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x245 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x246 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x244 } },
		{ names = { "浴びせ蹴り 追撃" }, type = act_types.attack, ids = { 0xF4, 0xF5 } },
		{ names = { "浴びせ蹴り 追撃" }, type = act_types.any, ids = { 0xF6 } },
		{ names = { "上げ面追加 B" }, type = act_types.attack, ids = { 0x24A, 0x24B } },
		{ names = { "上げ面追加 B" }, type = act_types.any, ids = { 0x24C } },
		{ names = { "上げ面追加 C" }, type = act_types.overhead, ids = { 0x24D } },
		{ names = { "上げ面追加 C" }, type = act_types.any, ids = { 0x24E } },
		{ names = { "上げ面追加 立C" }, type = act_types.attack, ids = { 0x247 } },
		{ names = { "上げ面追加 立C" }, type = act_types.attack, ids = { 0x248 } },
	},
	-- 東丈
	{
		{ names = { "フェイント スラッシュキック" }, type = act_types.any, ids = { 0x113 } },
		{ names = { "フェイント ハリケーンアッパー" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "ジョースペシャル" }, type = act_types.any, ids = { 0x6D, 0x6E, 0x6F, 0x70, 0x71 } },
		{ names = { "夏のおもひで" }, type = act_types.any, ids = { 0x24E, 0x24F } },
		{ names = { "膝地獄" }, type = act_types.any, ids = { 0x81, 0x82, 0x83, 0x84 } },
		{ names = { "スライディング" }, type = act_types.low_attack, ids = { 0x68, 0xF4 } },
		{ names = { "スライディング" }, type = act_types.any, ids = { 0xF5 } },
		{ names = { "ハイキック" }, type = act_types.attack, ids = { 0x69 } },
		{ names = { "炎の指先" }, type = act_types.any, ids = { 0x6A } },
		{ names = { "小スラッシュキック" }, type = act_types.attack, ids = { 0x86, 0x87, 0x88 } },
		{ names = { "小スラッシュキック" }, type = act_types.any, ids = { 0x89 } },
		{ names = { "大スラッシュキック" }, type = act_types.attack, ids = { 0x90, 0x91 } },
		{ names = { "大スラッシュキック ヒット" }, type = act_types.attack, ids = { 0x92 } },
		{ names = { "大スラッシュキック", "大スラッシュキック ヒット" }, type = act_types.any, ids = { 0x93, 0x94 } },
		{ names = { "黄金のカカト" }, type = act_types.attack, ids = { 0x9A, 0x9B } },
		{ names = { "黄金のカカト" }, type = act_types.any, ids = { 0x9C } },
		{ names = { "タイガーキック" }, type = act_types.attack, ids = { 0xA4, 0xA5 } },
		{ names = { "タイガーキック" }, type = act_types.any, ids = { 0xA6, 0xA7 } },
		{ names = { "爆裂拳" }, type = act_types.attack, ids = { 0xAE } },
		{ names = { "爆裂拳 持続" }, type = act_types.attack, ids = { 0xAF, 0xB1, 0xB0 } },
		{ names = { "爆裂拳 隙" }, type = act_types.any, ids = { 0xB2 } },
		{ names = { "爆裂フック" }, type = act_types.overhead, ids = { 0xB3, 0xB4 } },
		{ names = { "爆裂フック" }, type = act_types.any, ids = { 0xB5 } },
		{ names = { "爆裂アッパー" }, type = act_types.attack, ids = { 0xF8, 0xF9, 0xFA } },
		{ names = { "爆裂アッパー" }, type = act_types.any, ids = { 0xFB } },
		{ names = { "ハリケーンアッパー" }, type = act_types.attack, ids = { 0xB8 } },
		{ names = { "ハリケーンアッパー" }, type = act_types.any, ids = { 0xB9, 0xBA }, },
		{ names = { "爆裂ハリケーン" }, type = act_types.attack, ids = { 0xC2, 0xC3, 0xC4, 0xC5 }, },
		{ names = { "爆裂ハリケーン" }, type = act_types.any, ids = { 0xC6 } },
		{ names = { "スクリューアッパー" }, type = act_types.attack, ids = { 0xFE, 0xFF }, },
		{ names = { "スクリューアッパー" }, type = act_types.any, ids = { 0x100 } },
		{ names = { "サンダーファイヤー(C)" }, type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C, 0x10D, 0x10E, 0x10F, 0x110 } },
		{ names = { "サンダーファイヤー(C)" }, type = act_types.any, ids = { 0x111 } },
		{ names = { "サンダーファイヤー(D)" }, type = act_types.attack, ids = { 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA } },
		{ names = { "サンダーファイヤー(D)" }, type = act_types.any, ids = { 0xEB } },
		{ names = { "CA 立A" }, type = act_types.attack, ids = { 0x24B } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x42 } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x244 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x245 } },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x48 } },
		{ names = { "CA 立A" }, type = act_types.attack, ids = { 0x24C } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x45 } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x246 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x240 } },
		{ names = { "CA _8_+C" }, type = act_types.overhead, ids = { 0x251, 0x252 } },
		{ names = { "CA _8_+C" }, type = act_types.any, ids = { 0x253 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x46 } },
		{ names = { "CA _2_3_6_+C" }, type = act_types.attack, ids = { 0x24A } },
	},
	-- 不知火舞
	{
		{ names = { "フェイント 花蝶扇" }, type = act_types.attack, ids = { 0x112 } },
		{ names = { "フェイント 花嵐" }, type = act_types.attack, ids = { 0x113 } },
		{ names = { "風車崩し・改" }, type = act_types.attack, ids = { 0x6D, 0x6E } },
		{ names = { "夢桜・改" }, type = act_types.attack, ids = { 0x72, 0x73 } },
		{ names = { "跳ね蹴り" }, type = act_types.attack, ids = { 0x68 } },
		{ names = { "三角跳び" }, type = act_types.any, ids = { 0x69 } },
		{ names = { "龍の舞" }, type = act_types.attack, ids = { 0x6A } },
		{ names = { "花蝶扇" }, type = act_types.attack, ids = { 0x86, 0x87, 0x88 }, },
		{ names = { "龍炎舞" }, type = act_types.attack, ids = { 0x90, 0x91 }, },
		{ names = { "龍炎舞" }, type = act_types.any, ids = { 0x92 } },
		{ names = { "小夜千鳥" }, type = act_types.attack, ids = { 0x9A, 0x9B } },
		{ names = { "小夜千鳥" }, type = act_types.any, ids = { 0x9C } },
		{ names = { "必殺忍蜂" }, type = act_types.attack, ids = { 0xA4, 0xA5, 0xA6 } },
		{ names = { "必殺忍蜂" }, type = act_types.any, ids = { 0xA7 } },
		{ names = { "ムササビの舞" }, type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0 } },
		{ names = { "ムササビの舞" }, type = act_types.any, ids = { 0xB0 } },
		{ names = { "超必殺忍蜂" }, type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101 } },
		{ names = { "超必殺忍蜂" }, type = act_types.any, ids = { 0x102, 0x103 } },
		{ names = { "花嵐" }, type = act_types.attack, ids = { 0x108 } },
		{ names = { "花嵐 突進" }, type = act_types.attack, ids = { 0x109 } },
		{ names = { "花嵐 突進" }, type = act_types.any, ids = { 0x10F } },
		{ names = { "花嵐 上昇" }, type = act_types.attack, ids = { 0x10A, 0x10B, 0x10C } },
		{ names = { "花嵐 上昇" }, type = act_types.any, ids = { 0x10D, 0x10E } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x42 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x43 } },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x242 } },
		{ names = { "CA 屈C" }, type = act_types.attack, ids = { 0x243 } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x244 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x246 } },
		{ names = { "CA 対スウェーライン上段攻撃" }, type = act_types.overhead, ids = { 0x249 } },
		{ names = { "CA C" }, type = act_types.attack, ids = { 0x24A, 0x24B } },
		{ names = { "CA C" }, type = act_types.any, ids = { 0x24C } },
		{ names = { "CA B" }, type = act_types.overhead, ids = { 0x24D } },
		{ names = { "CA B" }, type = act_types.any, ids = { 0x24E } },
		{ names = { "CA C" }, type = act_types.overhead, ids = { 0x24F } },
		{ names = { "CA C" }, type = act_types.any, ids = { 0x250 } },
		{ names = { "CA 屈C" }, type = act_types.attack, ids = { 0x247 } },
	},
	-- ギース・ハワード
	{
		{ names = { "フェイント 烈風拳" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "フェイント レイジングストーム" }, type = act_types.any, ids = { 0x113 } },
		{ names = { "虎殺投げ" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "絶命人中打ち" }, type = act_types.any, ids = { 0x7C, 0x7D, 0x7E, 0x7F } },
		{ names = { "虎殺掌" }, type = act_types.any, ids = { 0x81, 0x82, 0x83, 0x84 } },
		{ names = { "昇天明星打ち" }, type = act_types.attack, ids = { 0x69 } },
		{ names = { "飛燕失脚" }, type = act_types.overhead, ids = { 0x68, 0x6B, 0x6C } },
		{ names = { "雷光回し蹴り" }, type = act_types.attack, ids = { 0x6A } },
		{ names = { "烈風拳" }, type = act_types.attack, ids = { 0x86, 0x87 }, },
		{ names = { "烈風拳" }, type = act_types.any, ids = { 0x88 } },
		{ names = { "ダブル烈風拳" }, type = act_types.attack, ids = { 0x90, 0x91, 0x92 }, },
		{ names = { "屈段当て身打ち" }, type = act_types.any, ids = { 0xAE } },
		{ names = { "屈段当て身打ちキャッチ" }, type = act_types.attack, ids = { 0xAF, 0xB0, 0xB1 } },
		{ names = { "裏雲隠し" }, type = act_types.any, ids = { 0xA4 } },
		{ names = { "裏雲隠しキャッチ" }, type = act_types.any, ids = { 0xA5, 0xA6, 0xA7 } },
		{ names = { "上段当て身投げ" }, type = act_types.any, ids = { 0x9A } },
		{ names = { "上段当て身投げキャッチ" }, type = act_types.any, ids = { 0x9B, 0x9C, 0x9D } },
		{ names = { "雷鳴豪波投げ" }, type = act_types.any, ids = { 0xB8, 0xB9, 0xBA } },
		{ names = { "真空投げ" }, type = act_types.any, ids = { 0xC2, 0xC3 } },
		{ names = { "レイジングストーム" }, type = act_types.attack, ids = { 0xFE, 0xFF, 0x100 }, },
		{ names = { "羅生門" }, type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B } },
		{ names = { "デッドリーレイブ" }, type = act_types.attack, ids = { 0xE0, 0xE1, 0xE2 } },
		{ names = { "デッドリーレイブ2段目" }, type = act_types.attack, ids = { 0xE3 } },
		{ names = { "デッドリーレイブ3段目" }, type = act_types.attack, ids = { 0xE4 } },
		{ names = { "デッドリーレイブ4段目" }, type = act_types.attack, ids = { 0xE5 } },
		{ names = { "デッドリーレイブ5段目" }, type = act_types.attack, ids = { 0xE6 } },
		{ names = { "デッドリーレイブ6段目" }, type = act_types.attack, ids = { 0xE7 } },
		{ names = { "デッドリーレイブ7段目" }, type = act_types.attack, ids = { 0xE8 } },
		{ names = { "デッドリーレイブ8段目" }, type = act_types.attack, ids = { 0xE9 } },
		{ names = { "デッドリーレイブ9段目" }, type = act_types.attack, ids = { 0xEA } },
		{ names = { "デッドリーレイブ10段目" }, type = act_types.attack, ids = { 0xEB, 0xEC } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x241 } },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x242 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x243 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x245 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x247 } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x246 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x244 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x247 } },
		{ names = { "CA 立C" }, type = act_types.low_attack, ids = { 0x249 } },
		{ names = { "CA _2_+C" }, type = act_types.overhead, ids = { 0x24E, 0x24F } },
		{ names = { "CA _2_+C" }, type = act_types.any, ids = { 0x250 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x24D } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x240 } },
		{ names = { "CA 屈C" }, type = act_types.attack, ids = { 0x24B } },
		{ names = { "CA 対スウェーライン上段攻撃" }, type = act_types.overhead, ids = { 0x248 } },
		{ names = { "CA 対スウェーライン下段攻撃" }, type = act_types.low_attack, ids = { 0x24A } },
	},
	-- 望月双角,
	{
		{ names = { "フェイント まきびし" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "フェイント いかづち" }, type = act_types.any, ids = { 0x113 } },
		{ names = { "無道縛り投げ" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "地獄門" }, type = act_types.any, ids = { 0x7C, 0x7D, 0x7E, 0x7F } },
		{ names = { "昇天殺" }, type = act_types.attack, ids = { 0x72, 0x73 } },
		{ names = { "雷撃棍" }, type = act_types.any, ids = { 0x69, 0x6A, 0x6B } },
		{ names = { "錫杖上段打ち" }, type = act_types.attack, ids = { 0x68 } },
		{ names = { "野猿狩り" }, type = act_types.attack, ids = { 0x86, 0x87 }, },
		{ names = { "喝CA 野猿狩り", "野猿狩り" }, type = act_types.attack, ids = { 0x88 }, },
		{ names = { "野猿狩り", "喝CA 野猿狩り" }, type = act_types.any, ids = { 0x89 } },
		{ names = { "まきびし" }, type = act_types.low_attack, ids = { 0x90, 0x91, 0x92 }, },
		{ names = { "憑依弾" }, type = act_types.attack, ids = { 0x9A, 0x9B }, },
		{ names = { "憑依弾" }, type = act_types.any, ids = { 0x9C, 0x9D } },
		{ names = { "鬼門陣" }, type = act_types.any, ids = { 0xA4, 0xA5, 0xA6, 0xA7 } },
		{ names = { "邪棍舞" }, type = act_types.low_attack, ids = { 0xAE }, },
		{ names = { "邪棍舞 持続", "邪棍舞 突破", "邪棍舞 降破", "邪棍舞 倒破", "邪棍舞 払破", "邪棍舞 天破", }, type = act_types.low_attack, ids = { 0xAF }, },
		{ names = { "邪棍舞 隙", "邪棍舞 突破", "邪棍舞 降破", "邪棍舞 倒破", "邪棍舞 払破", "邪棍舞 天破", }, type = act_types.any, ids = { 0xB0 }, },
		{ names = { "喝" }, type = act_types.attack, ids = { 0xB8, 0xB9, 0xBA, 0xBB }, },
		{ names = { "渦炎陣" }, type = act_types.overhead, ids = { 0xC2, 0xC3 } },
		{ names = { "渦炎陣" }, type = act_types.any, ids = { 0xC4, 0xC5 } },
		{ names = { "いかづち" }, type = act_types.attack, ids = { 0xFE, 0xFF, 0x103 }, },
		{ names = { "いかづち" }, type = act_types.any, ids = { 0x100, 0x101 } },
		{ names = { "無惨弾" }, type = act_types.overhead, ids = { 0x108, 0x109, 0x10A } },
		{ names = { "無惨弾" }, type = act_types.any, ids = { 0x10B, 0x10C } },
		{ names = { "避け攻撃" }, type = act_types.low_attack, ids = { 0x67 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x241 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x240 } },
		{ names = { "CA _6_+C" }, type = act_types.attack, ids = { 0x243 } },
		{ names = { "CA _2_2_+C" }, type = act_types.low_attack, ids = { 0x24B }, },
		{ names = { "CA 6B" }, type = act_types.overhead, ids = { 0x247 } },
		{ names = { "CA _6_2_3_+A" }, type = act_types.attack, ids = { 0x242 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x244 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x24D } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0xBC } },
	},
	-- ボブ・ウィルソン
	{
		{ names = { "フェイント ダンシングバイソン" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "ファルコン" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "ホーネットアタック" }, type = act_types.any, ids = { 0x7C, 0x7D, 0x7E } },
		{ names = { "イーグルキャッチ" }, type = act_types.any, ids = { 0x72, 0x73, 0x74 } },
		{ names = { "フライングフィッシュ" }, type = act_types.attack, ids = { 0x68, 0x77 } },
		{ names = { "フライングフィッシュ" }, type = act_types.any, ids = { 0x78 } },
		{ names = { "イーグルステップ" }, type = act_types.overhead, ids = { 0x69 } },
		{ names = { "リンクスファング" }, type = act_types.any, ids = { 0x6A, 0x7A, 0x7B } },
		{ names = { "エレファントタスク" }, type = act_types.attack, ids = { 0x6B } },
		{ names = { "H・ヘッジホック" }, type = act_types.attack, ids = { 0x6C } },
		{ names = { "ローリングタートル" }, type = act_types.attack, ids = { 0x86, 0x87, 0x88 } },
		{ names = { "ローリングタートル" }, type = act_types.any, ids = { 0x89 } },
		{ names = { "サイドワインダー" }, type = act_types.low_attack, ids = { 0x90, 0x91, 0x92 } },
		{ names = { "サイドワインダー" }, type = act_types.any, ids = { 0x93 } },
		{ names = { "モンキーダンス" }, type = act_types.attack, ids = { 0xAE, 0xAF } },
		{ names = { "モンキーダンス" }, type = act_types.any, ids = { 0xB0, 0xB1 } },
		{ names = { "ワイルドウルフ" }, type = act_types.overhead, ids = { 0xA4, 0xA5, 0xA6 } },
		{ names = { "バイソンホーン" }, type = act_types.low_attack, ids = { 0x9A, 0x9B } },
		{ names = { "バイソンホーン" }, type = act_types.any, ids = { 0x9D, 0x9C } },
		{ names = { "フロッグハンティング" }, type = act_types.attack, ids = { 0xB8, 0xB9 } },
		{ names = { "フロッグハンティング" }, type = act_types.any, ids = { 0xBD, 0xBE, 0xBA, 0xBB, 0xBC } },
		{ names = { "デンジャラスウルフ" }, type = act_types.overhead, ids = { 0xFE, 0xFF, 0x100, 0x101, 0x102, 0x103 } },
		{ names = { "デンジャラスウルフ" }, type = act_types.any, ids = { 0x104 } },
		{ names = { "ダンシングバイソン" }, type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B } },
		{ names = { "ダンシングバイソン" }, type = act_types.any, ids = { 0x10C, 0x10D } },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x48 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x49 } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x243 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x240 } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x242 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x245 } },
		{ names = { "CA _6_+C" }, type = act_types.attack, ids = { 0x247 } },
		{ names = { "CA _8_+C" }, type = act_types.overhead, ids = { 0x24A, 0x24B } },
		{ names = { "CA _8_+C" }, type = act_types.any, ids = { 0x24C } },
		{ names = { "CA 屈B" }, type = act_types.attack, ids = { 0x249 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x248 } },
	},
	-- ホンフゥ
	{
		{ names = { "フェイント 制空烈火棍" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "バックフリップ" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "経絡乱打" }, type = act_types.any, ids = { 0x81, 0x82, 0x83, 0x84 } },
		{ names = { "ハエタタキ" }, type = act_types.attack, ids = { 0x69 } },
		{ names = { "踏み込み側蹴り" }, type = act_types.attack, ids = { 0x68 } },
		{ names = { "トドメヌンチャク" }, type = act_types.attack, ids = { 0x6A } },
		{ names = { "九龍の読み" }, type = act_types.attack, ids = { 0x86 } },
		{ names = { "九龍の読み反撃" }, type = act_types.attack, ids = { 0x87, 0x88, 0x89 } },
		{ names = { "黒龍" }, type = act_types.attack, ids = { 0xD7, 0xD8 } },
		{ names = { "黒龍" }, type = act_types.any, ids = { 0xD9, 0xDA } },
		{ names = { "小 制空烈火棍" }, type = act_types.attack, ids = { 0x90, 0x91 } },
		{ names = { "小 制空烈火棍" }, type = act_types.any, ids = { 0x92, 0x93 } },
		{ names = { "大 制空烈火棍" }, type = act_types.attack, ids = { 0x9A, 0x9B } },
		{ names = { "大 制空烈火棍", "爆発ゴロー" }, type = act_types.any, ids = { 0x9D, 0x9C } },
		{ names = { "電光石火の天" }, type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0 } },
		{ names = { "電光石火の地" }, type = act_types.low_attack, ids = { 0xA4, 0xA5 } },
		{ names = { "電光石火の地" }, type = act_types.any, ids = { 0xA6 } },
		{ names = { "電光パチキ" }, type = act_types.attack, ids = { 0xA7 } },
		{ names = { "電光パチキ" }, type = act_types.any, ids = { 0xA8 } },
		{ names = { "炎の種馬" }, type = act_types.attack, ids = { 0xB8 } },
		{ names = { "炎の種馬 持続" }, type = act_types.attack, ids = { 0xB9, 0xBA, 0xBB } },
		{ names = { "炎の種馬 最終段" }, type = act_types.attack, ids = { 0xBC, 0xBD } },
		{ names = { "炎の種馬 失敗" }, type = act_types.any, ids = { 0xBE, 0xBF, 0xC0 } },
		{ names = { "必勝！逆襲拳" }, type = act_types.any, ids = { 0xC2 } },
		{ names = { "必勝！逆襲拳 1回目" }, type = act_types.any, ids = { 0xC3, 0xC4, 0xC5 } },
		{ names = { "必勝！逆襲拳 2回目" }, type = act_types.any, ids = { 0xC6, 0xC7, 0xC8 } },
		{ names = { "必勝！逆襲拳 1段目" }, type = act_types.attack, ids = { 0xC9, 0xCA, 0xCB } },
		{ names = { "必勝！逆襲拳 2~5段目" }, type = act_types.low_attack, ids = { 0xCC } },
		{ names = { "必勝！逆襲拳 6~7段目" }, type = act_types.overhead, ids = { 0xCD } },
		{ names = { "必勝！逆襲拳 8~10段目" }, type = act_types.overhead, ids = { 0xCE } },
		{ names = { "必勝！逆襲拳 11~12段目" }, type = act_types.attack, ids = { 0xCF, 0xD0 } },
		{ names = { "必勝！逆襲拳 11~12段目" }, type = act_types.attack, ids = { 0xD1 } },
		{ names = { "爆発ゴロー" }, type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101 } },
		{ names = { "爆発ゴロー" }, type = act_types.any, ids = { 0x102 } },
		{ names = { "よかトンハンマー" }, type = act_types.overhead, ids = { 0x108, 0x109, 0x10A } },
		{ names = { "よかトンハンマー" }, type = act_types.any, ids = { 0x10B }, },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x245 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x240 } },
		{ names = { "CA _6_+C" }, type = act_types.attack, ids = { 0x241 } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x242 } },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x246 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x247 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x248 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x252 } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x24C, 0x24D } },
		{ names = { "CA 立B" }, type = act_types.any, ids = { 0x24E } },
		{ names = { "CA 立C" }, type = act_types.overhead, ids = { 0x24F } },
		{ names = { "CA 立C" }, type = act_types.any, ids = { 0x250 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x243 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x244 } },
		{ names = { "CA 屈C" }, type = act_types.attack, ids = { 0x24A } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x24B } },
		{ names = { "CA _3_+C " }, type = act_types.low_attack, ids = { 0x251 } },
	},
	-- ブルー・マリー
	{
		{ names = { "フェイント M.スナッチャー" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "ヘッドスロー" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "アキレスホールド" }, type = act_types.any, ids = { 0x7C, 0x7E, 0x7F } },
		{ names = { "ヒールフォール" }, type = act_types.overhead, ids = { 0x69 } },
		{ names = { "ダブルローリング" }, type = act_types.attack, ids = { 0x68 } },
		{ names = { "ダブルローリング" }, type = act_types.low_attack, ids = { 0x6C } },
		{ names = { "レッグプレス" }, type = act_types.any, ids = { 0x6A } },
		{ names = { "M.リアルカウンター" }, type = act_types.attack, ids = { 0xA4, 0xA5 } },
		{ names = { "CAジャーマンスープレックス", "M.リアルカウンター" }, type = act_types.any, ids = { 0xA6 } },
		{ names = { "M.リアルカウンター投げ移行" }, type = act_types.any, ids = { 0xAC } },
		{ names = { "ジャーマンスープレックス", "CAジャーマンスープレックス" }, type = act_types.any, ids = { 0xA7, 0xA8, 0xA9, 0xAA, 0xAB } },
		{ names = { "フェイスロック" }, type = act_types.any, ids = { 0xE0, 0xE1, 0xE2, 0xE3, 0xE4 } },
		{ names = { "投げっぱなしジャーマンスープレックス" }, type = act_types.any, ids = { 0xE5, 0xE6, 0xE7 } },
		{ names = { "ヤングダイブ" }, type = act_types.overhead, ids = { 0xEA, 0xEB, 0xEC } },
		{ names = { "ヤングダイブ" }, type = act_types.any, ids = { 0xED } },
		{ names = { "リバースキック" }, type = act_types.overhead, ids = { 0xEE } },
		{ names = { "リバースキック" }, type = act_types.any, ids = { 0xEF } },
		{ names = { "M.スパイダー" }, type = act_types.lunging_throw | act_types.attack, ids = { 0x8C, 0x86 } },
		{ names = { "デンジャラススパイダー" }, type = act_types.lunging_throw | act_types.attack, ids = { 0xF0 } },
		{ names = { "スピンフォール" }, type = act_types.attack, ids = { 0xAE, 0xAF } },
		{ names = { "スピンフォール" }, type = act_types.attack, ids = { 0xB0 } },
		{ names = { "M.スパイダー", "デンジャラススパイダー" }, type = act_types.any, ids = { 0x87 } },
		{ names = { "ダブルスパイダー", "M.スパイダー", "デンジャラススパイダー" }, type = act_types.any, ids = { 0x88, 0x89, 0x8A, 0x8B } },
		{ names = { "M.スナッチャー" }, type = act_types.lunging_throw | act_types.attack, ids = { 0x90 } },
		{ names = { "M.スナッチャー" }, type = act_types.lunging_throw | act_types.any, ids = { 0x91, 0x92 } },
		{ names = { "バーチカルアロー" }, type = act_types.overhead, ids = { 0xB8, 0xB9 } },
		{ names = { "バーチカルアロー" }, type = act_types.any, ids = { 0xBA, 0xBB } },
		{ names = { "ダブルスナッチャー", "M.スナッチャー" }, type = act_types.any, ids = { 0x93, 0x94, 0x95, 0x96 } },
		{ names = { "M.クラブクラッチ" }, type = act_types.low_attack, ids = { 0x9A, 0x9B } },
		{ names = { "ストレートスライサー" }, type = act_types.low_attack, ids = { 0xC2, 0xC3 } },
		{ names = { "ストレートスライサー", "M.クラブクラッチ" }, type = act_types.any, ids = { 0xC4, 0xC5 } },
		{ names = { "ダブルクラッチ", "M.クラブクラッチ" }, type = act_types.any, ids = { 0x9D, 0x9E, 0x9F, 0xA0, 0xA1 } },
		{ names = { "M.ダイナマイトスウィング" }, type = act_types.any, ids = { 0xCC, 0xCD, 0xCE, 0xCF, 0xD0, 0xD1 } },
		{ names = { "M.タイフーン" }, type = act_types.lunging_throw | act_types.attack, ids = { 0xFE, 0xFF, 0x100 } },
		{ names = { "M.タイフーン" }, type = act_types.lunging_throw | act_types.any, ids = { 0x100 } },
		{ names = { "M.タイフーン ヒット" }, type = act_types.lunging_throw | act_types.any, ids = { 0x101, 0x102, 0x103, 0x104, 0x105, 0x106, 0x107, 0x116 } },
		{ names = { "M.エスカレーション" }, type = act_types.attack, ids = { 0x10B } },
		{ names = { "M.トリプルエクスタシー" }, type = act_types.any, ids = { 0xD6, 0xD8, 0xD7, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x24C } },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x251 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x246 } },
		{ names = { "CA _6_+C" }, type = act_types.attack, ids = { 0x24E, 0x24F } },
		{ names = { "CA _6_+C" }, type = act_types.any, ids = { 0x250 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x247 } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x242 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x241 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x240 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x243, 0x244 } },
		{ names = { "CA 立C" }, type = act_types.any, ids = { 0x245 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x252, 0x253 } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x24D } },
		{ names = { "CA _6_+C" }, type = act_types.attack, ids = { 0x249, 0x24A } },
		{ names = { "CA _6_+C" }, type = act_types.any, ids = { 0x24B } },
	},
	-- フランコ・バッシュ
	{
		{ names = { "フェイント ガッツダンク" }, type = act_types.any, ids = { 0x113 } },
		{ names = { "フェイント ハルマゲドンバスター" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "ゴリラッシュ" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "スマッシュ" }, type = act_types.attack, ids = { 0x68 } },
		{ names = { "バッシュトルネード" }, type = act_types.attack, ids = { 0x6A } },
		{ names = { "バロムパンチ" }, type = act_types.low_attack, ids = { 0x69 } },
		{ names = { "ダブルコング" }, type = act_types.attack, ids = { 0x86, 0x87 } },
		{ names = { "ダブルコング" }, type = act_types.overhead, ids = { 0x88 } },
		{ names = { "ダブルコング" }, type = act_types.any, ids = { 0x89 } },
		{ names = { "ザッパー" }, type = act_types.attack, ids = { 0x90, 0x91 }, },
		{ names = { "ザッパー" }, type = act_types.any, ids = { 0x92 }, },
		{ names = { "ウェービングブロー" }, type = act_types.attack, ids = { 0x9A, 0x9B } },
		{ names = { "ガッツダンク" }, type = act_types.attack, ids = { 0xA4, 0xA5 } },
		{ names = { "ガッツダンク" }, type = act_types.overhead, ids = { 0xA6, 0xA7 } },
		{ names = { "ガッツダンク" }, type = act_types.any, ids = { 0xA8, 0xAC } },
		{ names = { "ゴールデンボンバー" }, type = act_types.attack, ids = { 0xAD, 0xAE, 0xAF, 0xB0 } },
		{ names = { "ゴールデンボンバー" }, type = act_types.any, ids = { 0xB1 } },
		{ names = { "ファイナルオメガショット" }, type = act_types.overhead, ids = { 0xFE, 0xFF, 0x100 }, },
		{ names = { "メガトンスクリュー" }, type = act_types.attack, ids = { 0xF4, 0xF5, 0xF6, 0xF7, 0xFC } },
		{ names = { "メガトンスクリュー" }, type = act_types.any, ids = { 0xF8 } },
		{ names = { "ハルマゲドンバスター" }, type = act_types.attack, ids = { 0x108 } },
		{ names = { "ハルマゲドンバスター" }, type = act_types.any, ids = { 0x109 } },
		{ names = { "ハルマゲドンバスター ヒット" }, type = act_types.attack, ids = { 0x10A } },
		{ names = { "ハルマゲドンバスター ヒット" }, type = act_types.any, ids = { 0x10B } },
		{ names = { "CA 立A" }, type = act_types.attack, ids = { 0x248 } },
		{ names = { "CA 立C" }, type = act_types.low_attack, ids = { 0x247 } },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x242 } },
		{ names = { "CA 立D" }, type = act_types.attack, ids = { 0x240 } },
		{ names = { "CA 立B" }, type = act_types.low_attack, ids = { 0x246 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x249 } },
		{ names = { "CA 立C" }, type = act_types.overhead, ids = { 0x24A, 0x24B } },
		{ names = { "CA 立C" }, type = act_types.any, ids = { 0x24C } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x24D } },
	},
	-- 山崎竜二
	{
		{ names = { "フェイント 裁きの匕首" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "ブン投げ" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "目ツブシ" }, type = act_types.attack, ids = { 0x68, 0x6C }, },
		{ names = { "カチ上げ" }, type = act_types.attack, ids = { 0x69 } },
		{ names = { "ブッ刺し" }, type = act_types.overhead, ids = { 0x6A } },
		{ names = { "昇天" }, type = act_types.attack, ids = { 0x6B } },
		{ names = { "蛇使い・上段かまえ" }, type = act_types.any, ids = { 0x86, 0x87 } },
		{ names = { "蛇使い・上段" }, type = act_types.attack, ids = { 0x88 } },
		{ names = { "蛇だまし・上段" }, type = act_types.any, ids = { 0x89 } },
		{ names = { "蛇使い・中段かまえ" }, type = act_types.any, ids = { 0x90, 0x91 } },
		{ names = { "蛇使い・中段" }, type = act_types.attack, ids = { 0x92 } },
		{ names = { "蛇だまし・中段" }, type = act_types.any, ids = { 0x93 } },
		{ names = { "蛇使い・下段かまえ" }, type = act_types.any, ids = { 0x9A, 0x9B } },
		{ names = { "蛇使い・下段" }, type = act_types.low_attack, ids = { 0x9C } },
		{ names = { "蛇だまし・下段" }, type = act_types.any, ids = { 0x9D } },
		{ names = { "大蛇" }, type = act_types.low_attack, ids = { 0x94 } },
		{ names = { "サドマゾ" }, type = act_types.any, ids = { 0xA4 } },
		{ names = { "サドマゾ攻撃" }, type = act_types.low_attack, ids = { 0xA5, 0xA6 } },
		{ names = { "裁きの匕首" }, type = act_types.attack, ids = { 0xC2, 0xC3 } },
		{ names = { "裁きの匕首" }, type = act_types.any, ids = { 0xC4 } },
		{ names = { "裁きの匕首 ヒット" }, type = act_types.attack, ids = { 0xC5 } },
		{ names = { "ヤキ入れ" }, type = act_types.overhead, ids = { 0xAE, 0xAF, 0xB0 } },
		{ names = { "ヤキ入れ" }, type = act_types.any, ids = { 0xB4 } },
		{ names = { "倍返し" }, type = act_types.attack, ids = { 0xB8 } },
		{ names = { "倍返し キャッチ" }, type = act_types.any, ids = { 0xB9 } },
		{ names = { "倍返し 吸収" }, type = act_types.any, ids = { 0xBA } },
		{ names = { "倍返し 発射" }, type = act_types.attack, ids = { 0xBB, 0xBC }, },
		{ names = { "爆弾パチキ" }, type = act_types.any, ids = { 0xCC, 0xCD, 0xCE, 0xCF } },
		{ names = { "トドメ" }, type = act_types.any, ids = { 0xD6, 0xD7 } },
		{ names = { "トドメ ヒット" }, type = act_types.any, ids = { 0xDA, 0xD8, 0xDB, 0xD9 } },
		{ names = { "ギロチン" }, type = act_types.attack, ids = { 0xFE } },
		{ names = { "ギロチン" }, type = act_types.overhead, ids = { 0xFF, 0x100 } },
		{ names = { "ギロチン" }, type = act_types.any, ids = { 0x101 } },
		{ names = { "ギロチン ヒット" }, type = act_types.any, ids = { 0x102, 0x103 } },
		{ names = { "ドリル" }, type = act_types.any, ids = { 0x108, 0x109 } },
		{ names = { "ドリル ため Lv.1" }, type = act_types.any, ids = { 0x10A, 0x10B } },
		{ names = { "ドリル ため Lv.2" }, type = act_types.any, ids = { 0x10C } },
		{ names = { "ドリル ため Lv.3" }, type = act_types.any, ids = { 0x10D } },
		{ names = { "ドリル ため Lv.4" }, type = act_types.any, ids = { 0x10E } },
		{ names = { "ドリル Lv.1" }, type = act_types.any, ids = { 0xE0, 0xE1, 0xE2 } },
		{ names = { "ドリル Lv.2" }, type = act_types.any, ids = { 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9 } },
		{ names = { "ドリル Lv.3" }, type = act_types.any, ids = { 0xEA, 0xEB, 0xEC, 0xF1 } },
		{ names = { "ドリル Lv.4" }, type = act_types.any, ids = { 0xED, 0xEE, 0xEF, 0xF0 } },
		{ names = { "ドリル Lv.5" }, type = act_types.any, ids = { 0xF2, 0xF3, 0xF4, 0xF5, 0xF6 } },
		{ names = { "ドリル フィニッシュ" }, type = act_types.any, ids = { 0x10F, 0x110 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x245 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x247, 0x248, 0x249 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x244 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x24D } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x242 } },
		{ names = { "CA _6_+C" }, type = act_types.attack, ids = { 0x241 } },
	},
	-- 秦崇秀
	{
		{ names = { "フェイント 海龍照臨" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "発勁龍" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "光輪殺" }, type = act_types.overhead, ids = { 0x68 } },
		{ names = { "帝王神足拳" }, type = act_types.attack, ids = { 0x86, 0x87 } },
		{ names = { "帝王神足拳" }, type = act_types.any, ids = { 0x88 } },
		{ names = { "帝王神足拳 ヒット" }, type = act_types.any, ids = { 0x89, 0x8A } },
		{ names = { "小 帝王天眼拳" }, type = act_types.attack, ids = { 0x90, 0x91 }, },
		{ names = { "小 帝王天眼拳" }, type = act_types.any, ids = { 0x92 }, },
		{ names = { "大 帝王天眼拳" }, type = act_types.attack, ids = { 0x9A, 0x9B }, },
		{ names = { "大 帝王天眼拳" }, type = act_types.any, ids = { 0x9C }, },
		{ names = { "小 帝王天耳拳" }, type = act_types.attack, ids = { 0xA4, 0xA5 } },
		{ names = { "小 帝王天耳拳" }, type = act_types.any, ids = { 0xA6, 0xA7 } },
		{ names = { "大 帝王天耳拳" }, type = act_types.attack, ids = { 0xAE, 0xAF } },
		{ names = { "大 帝王天耳拳" }, type = act_types.any, ids = { 0xB0, 0xB1 } },
		{ names = { "帝王神眼拳（その場）" }, type = act_types.any, ids = { 0xC2, 0xC3 } },
		{ names = { "帝王神眼拳（空中）" }, type = act_types.any, ids = { 0xCC, 0xCD } },
		{ names = { "帝王神眼拳（空中攻撃）" }, type = act_types.attack, ids = { 0xCE } },
		{ names = { "帝王神眼拳（空中攻撃）" }, type = act_types.any, ids = { 0xCF } },
		{ names = { "帝王神眼拳（背後）" }, type = act_types.any, ids = { 0xD6, 0xD7 } },
		{ names = { "帝王空殺神眼拳" }, type = act_types.any, ids = { 0xE0, 0xE1 } },
		{ names = { "竜灯掌" }, type = act_types.attack, ids = { 0xB8 } },
		{ names = { "竜灯掌 ヒット" }, type = act_types.any, ids = { 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE } },
		{ names = { "竜灯掌・幻殺" }, type = act_types.any, ids = { 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB } },
		{ names = { "帝王漏尽拳" }, type = act_types.attack, ids = { 0xFE, 0xFF }, },
		{ names = { "帝王漏尽拳" }, type = act_types.any, ids = { 0x100 }, },
		{ names = { "帝王漏尽拳 ヒット" }, type = act_types.any, ids = { 0x101 }, },
		{ names = { "帝王空殺漏尽拳" }, type = act_types.low_attack, ids = { 0xEA, 0xEB, 0xEC }, },
		{ names = { "帝王空殺漏尽拳 ヒット" }, type = act_types.any, ids = { 0xED }, },
		{ names = { "帝王空殺漏尽拳", "帝王空殺漏尽拳 ヒット" }, type = act_types.any, ids = { 0xEE, 0xEF }, },
		{ names = { "海龍照臨" }, type = act_types.attack, ids = { 0x108, 0x109, 0x109, 0x10A }, },
		{ names = { "海龍照臨" }, type = act_types.any, ids = { 0x10B }, },
		{ names = { "CA 立A" }, type = act_types.attack, ids = { 0x247 } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x246 } },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x24B } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x240 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x24C } },
		{ names = { "CA _6_+C" }, type = act_types.attack, ids = { 0x242 } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x241 } },
		{ names = { "龍回頭" }, type = act_types.low_attack, ids = { 0x248 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x245 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x243 } },
		{ names = { "CA _6_4_+C" }, type = act_types.attack, ids = { 0x244 } },
	},
	-- 秦崇雷,
	{
		{ names = { "フェイント 帝王宿命拳" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "発勁龍" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "龍脚殺" }, type = act_types.overhead, ids = { 0x68 } },
		{ names = { "帝王神足拳" }, type = act_types.attack, ids = { 0x86, 0x87, 0x89 } },
		{ names = { "帝王神足拳" }, type = act_types.any, ids = { 0x88 } },
		{ names = { "小 帝王天眼拳" }, type = act_types.attack, ids = { 0x90, 0x91 }, },
		{ names = { "小 帝王天眼拳" }, type = act_types.any, ids = { 0x92 }, },
		{ names = { "大 帝王天眼拳" }, type = act_types.attack, ids = { 0x9A, 0x9B }, },
		{ names = { "大 帝王天眼拳" }, type = act_types.any, ids = { 0x9C }, },
		{ names = { "小 帝王天耳拳" }, type = act_types.attack, ids = { 0xA4, 0xA5 } },
		{ names = { "小 帝王天耳拳" }, type = act_types.any, ids = { 0xA6, 0xA7 } },
		{ names = { "大 帝王天耳拳" }, type = act_types.attack, ids = { 0xAE, 0xAF } },
		{ names = { "大 帝王天耳拳" }, type = act_types.any, ids = { 0xB0, 0xB1 } },
		{ names = { "帝王漏尽拳" }, type = act_types.attack, ids = { 0xB8, 0xB9 }, },
		{ names = { "帝王漏尽拳" }, type = act_types.any, ids = { 0xBC }, },
		{ names = { "帝王漏尽拳 ヒット" }, type = act_types.attack, ids = { 0xBB, 0xBA }, },
		{ names = { "龍転身（前方）" }, type = act_types.any, ids = { 0xC2, 0xC3, 0xC4 } },
		{ names = { "龍転身（後方）" }, type = act_types.any, ids = { 0xCC, 0xCD, 0xCE } },
		{ names = { "帝王宿命拳" }, type = act_types.attack, ids = { 0xFE, 0xFF }, },
		{ names = { "帝王宿命拳" }, type = act_types.any, ids = { 0x100 }, },
		{ names = { "帝王宿命拳2" }, type = act_types.attack, ids = { 0x101, 0x102 }, },
		{ names = { "帝王宿命拳2" }, type = act_types.any, ids = { 0x103 }, },
		{ names = { "帝王宿命拳3" }, type = act_types.attack, ids = { 0x104, 0x105 }, },
		{ names = { "帝王宿命拳3" }, type = act_types.any, ids = { 0x106 }, },
		{ names = { "帝王宿命拳4" }, type = act_types.attack, ids = { 0x107, 0x115 }, },
		{ names = { "帝王宿命拳4" }, type = act_types.any, ids = { 0x116 }, },
		{ names = { "帝王龍声拳" }, type = act_types.attack, ids = { 0x108, 0x109 }, },
		{ names = { "帝王龍声拳" }, type = act_types.any, ids = { 0x10A }, },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x48 } },
		{ names = { "CA _6_+C" }, type = act_types.attack, ids = { 0x243 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x242 } },
		{ names = { "CA _8_+C" }, type = act_types.overhead, ids = { 0x244, 0x245 } },
		{ names = { "CA _8_+C" }, type = act_types.any, ids = { 0x246 } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x240 } },
	},
	-- ダック・キング
	{
		{ names = { "フェイント ダックダンス" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "ローリングネックスルー" }, type = act_types.attack, ids = { 0x6D, 0x6E, 0x6F, 0x70, 0x71 } },
		{ names = { "ニードルロー" }, type = act_types.low_attack, ids = { 0x68 } },
		{ names = { "ニードルロー" }, type = act_types.any, ids = { 0x72 } },
		{ names = { "マッドスピンハンマー" }, type = act_types.overhead, ids = { 0x69 } },
		{ names = { "ショッキングボール" }, type = act_types.any, ids = { 0x6A, 0x6B, 0x6C } },
		{ names = { "小ヘッドスピンアタック" }, type = act_types.attack, ids = { 0x86, 0x87 } },
		{ names = { "小ヘッドスピンアタック" }, type = act_types.any, ids = { 0x8A } },
		{ names = { "小ヘッドスピンアタック 接触" }, type = act_types.any, ids = { 0x88, 0x89 } },
		{ names = { "大ヘッドスピンアタック" }, type = act_types.attack, ids = { 0x90, 0x91 } },
		{ names = { "大ヘッドスピンアタック" }, type = act_types.attack, ids = { 0x94 } },
		{ names = { "大ヘッドスピンアタック 接触" }, type = act_types.any, ids = { 0x92, 0x93 } },
		{ names = { "オーバーヘッドキック" }, type = act_types.attack, ids = { 0x95 } },
		{ names = { "オーバーヘッドキック" }, type = act_types.any, ids = { 0x96 } },
		{ names = { "地上振り向き", "小ヘッドスピンアタック", "大ヘッドスピンアタック" }, type = act_types.any, ids = { 0x3D } },
		{ names = { "フライングスピンアタック" }, type = act_types.attack, ids = { 0x9A, 0x9B } },
		{ names = { "フライングスピンアタック 接触" }, type = act_types.any, ids = { 0x9C } },
		{ names = { "フライングスピンアタック" }, type = act_types.any, ids = { 0x9D, 0x9E } },
		{ names = { "ダンシングダイブ" }, type = act_types.attack, ids = { 0xA4, 0xA5 } },
		{ names = { "ダンシングダイブ" }, type = act_types.any, ids = { 0xA6, 0xA7 } },
		{ names = { "リバースダイブ" }, type = act_types.attack, ids = { 0xA8, 0xA9 } },
		{ names = { "リバースダイブ" }, type = act_types.any, ids = { 0xAA } },
		{ names = { "ブレイクストーム" }, type = act_types.attack, ids = { 0xAE, 0xAF } },
		{ names = { "ブレイクストーム" }, type = act_types.any, ids = { 0xB0, 0xB1 } },
		{ names = { "ブレイクストーム 2段階目" }, type = act_types.attack, ids = { 0xB2, 0xB6 } },
		{ names = { "ブレイクストーム 3段階目" }, type = act_types.attack, ids = { 0xB3, 0xB7 } },
		{ names = { "ブレイクストーム", "ブレイクストーム 2段階目", "ブレイクストーム 3段階目" }, type = act_types.any, ids = { 0xB4, 0xB5 } },
		{ names = { "ダックフェイント・地" }, type = act_types.any, ids = { 0xC2, 0xC3, 0xC4 } },
		{ names = { "ダックフェイント・空" }, type = act_types.any, ids = { 0xB8 } },
		{ names = { "ダックフェイント・空" }, type = act_types.any, ids = { 0xB9, 0xBA } },
		{ names = { "クロスヘッドスピン" }, type = act_types.attack, ids = { 0xD6, 0xD7 } },
		{ names = { "クロスヘッドスピン" }, type = act_types.any, ids = { 0xD8, 0xD9 } },
		{ names = { "ダイビングパニッシャー" }, type = act_types.attack, ids = { 0xE0, 0xE1, } },
		{ names = { "ダイビングパニッシャー 接触" }, type = act_types.any, ids = { 0xE2 } },
		{ names = { "ダイビングパニッシャー", "ダイビングパニッシャー 接触" }, type = act_types.any, ids = { 0xE3 } },
		{ names = { "ローリングパニッシャー" }, type = act_types.attack, ids = { 0xE4, 0xE5 } },
		{ names = { "ローリングパニッシャー" }, type = act_types.any, ids = { 0xE8 } },
		{ names = { "ローリングパニッシャー 接触" }, type = act_types.any, ids = { 0xE6, 0xE7 } },
		{ names = { "ダンシングキャリバー" }, type = act_types.low_attack, ids = { 0xE9 } },
		{ names = { "ダンシングキャリバー" }, type = act_types.attack, ids = { 0xEA, 0xEB, 0xEC } },
		{ names = { "ダンシングキャリバー" }, type = act_types.any, ids = { 0xED, 0x115 } },
		{ names = { "ブレイクハリケーン" }, type = act_types.low_attack, ids = { 0xEE, 0xF1 } },
		{ names = { "ブレイクハリケーン" }, type = act_types.attack, ids = { 0xEF, 0xF0, 0xF2, 0xF3 } },
		{ names = { "ブレイクハリケーン" }, type = act_types.any, ids = { 0x116, 0xF4 } },
		{ names = { "ブレイクスパイラル" }, type = act_types.any, ids = { 0xFE, 0xFF, 0x100, 0x102 } },
		{ names = { "ブレイクスパイラルブラザー" }, type = act_types.any, ids = { 0xF8 } },
		{ names = { "ブレイクスパイラルブラザー" }, type = act_types.any, ids = { 0xF9 } },
		{ names = { "ブレイクスパイラルブラザー" }, type = act_types.any, ids = { 0xFA, 0xFB, 0xFC, 0xFD } },
		{ names = { "ダックダンス" }, type = act_types.attack, ids = { 0x108 } },
		{ names = { "ダックダンス Lv.1" }, type = act_types.any, ids = { 0x109, 0x10C } },
		{ names = { "ダックダンス Lv.2" }, type = act_types.any, ids = { 0x10A, 0x10D } },
		{ names = { "ダックダンス Lv.3" }, type = act_types.any, ids = { 0x10B, 0x10E } },
		{ names = { "ダックダンス Lv.4" }, type = act_types.any, ids = { 0x10F } },
		{ names = { "スーパーポンピングマシーン" }, type = act_types.low_attack, ids = { 0x77, 0x78 } },
		{ names = { "スーパーポンピングマシーン" }, type = act_types.any, ids = { 0x79 } },
		{ names = { "スーパーポンピングマシーン ヒット" }, type = act_types.any, ids = { 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F, 0x82, 0x80, 0x81 } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x24E } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x240 } },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x24F } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x243 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x24D } },
		{ names = { "CA _6_+C" }, type = act_types.attack, ids = { 0x242 } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x244 } },
		{ names = { "CA 屈C" }, type = act_types.any, ids = { 0x24C } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x245 } },
		{ names = { "旧ブレイクストーム" }, type = act_types.low_attack, ids = { 0x247, 0x248 } },
		{ names = { "旧ブレイクストーム" }, type = act_types.any, ids = { 0x249, 0x24A } },
		{ names = { "避け攻撃" }, type = act_types.low_attack, ids = { 0x67 } },
	},
	-- キム・カッファン
	{
		{ names = { "フェイント 鳳凰脚" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "体落とし" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "ネリチャギ" }, type = act_types.overhead, ids = { 0x68, 0x69 } },
		{ names = { "ネリチャギ" }, type = act_types.any, ids = { 0x6A } },
		{ names = { "飛燕斬" }, type = act_types.attack, ids = { 0x86, 0x87 } },
		{ names = { "飛燕斬" }, type = act_types.any, ids = { 0x88, 0x89 } },
		{ names = { "小 半月斬" }, type = act_types.attack, ids = { 0x90, 0x91, 0x92 } },
		{ names = { "大 半月斬" }, type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C } },
		{ names = { "飛翔脚" }, type = act_types.low_attack, ids = { 0xA4, 0xA5 } },
		{ names = { "飛翔脚" }, type = act_types.any, ids = { 0xA6 } },
		{ names = { "戒脚" }, type = act_types.low_attack, ids = { 0xA7, 0xA8 } },
		{ names = { "戒脚" }, type = act_types.any, ids = { 0xA9 } },
		{ names = { "空砂塵" }, type = act_types.attack, ids = { 0xAE, 0xAF } },
		{ names = { "空砂塵" }, type = act_types.any, ids = { 0xB0, 0xB1 } },
		{ names = { "天昇斬" }, type = act_types.attack, ids = { 0xB2 } },
		{ names = { "天昇斬" }, type = act_types.any, ids = { 0xB3, 0xB4 } },
		{ names = { "覇気脚" }, type = act_types.low_attack, ids = { 0xB8 } },
		{ names = { "鳳凰天舞脚" }, type = act_types.low_attack, ids = { 0xFE, 0xFF } },
		{ names = { "鳳凰天舞脚" }, type = act_types.any, ids = { 0x100 } },
		{ names = { "鳳凰天舞脚 ヒット" }, type = act_types.any, ids = { 0x101, 0x102, 0x103, 0x104, 0x105, 0x106, 0x107 } },
		{ names = { "鳳凰脚" }, type = act_types.attack, ids = { 0x108, 0x109, 0x10A } },
		{ names = { "鳳凰脚 ヒット" }, type = act_types.any, ids = { 0x10B, 0x10C, 0x10D, 0x10E, 0x10F, 0x110, 0x115 } },
		{ names = { "CA ネリチャギ" }, type = act_types.overhead, ids = { 0x24A, 0x24B } },
		{ names = { "CA ネリチャギ" }, type = act_types.any, ids = { 0x24C } },
		{ names = { "CA 立A" }, type = act_types.attack, ids = { 0x241 } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x244 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x246, 0x247 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x248 } },
		{ names = { "CA 立A" }, type = act_types.attack, ids = { 0x240 } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x243 } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x249 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x242 } },
	},
	-- ビリー・カーン
	{
		{ names = { "フェイント 強襲飛翔棍" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "一本釣り投げ" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "地獄落とし" }, type = act_types.any, ids = { 0x81, 0x82, 0x83, 0x84 } },
		{ names = { "三節棍中段打ち" }, type = act_types.attack, ids = { 0x86, 0x87 }, },
		{ names = { "三節棍中段打ち" }, type = act_types.any, ids = { 0x88, 0x89 } },
		{ names = { "火炎三節棍中段突き" }, type = act_types.attack, ids = { 0x90, 0x91, }, },
		{ names = { "火炎三節棍中段突き" }, type = act_types.any, ids = { 0x92, 0x93 } },
		{ names = { "燕落とし" }, type = act_types.attack, ids = { 0x9A, 0x9B } },
		{ names = { "燕落とし" }, type = act_types.any, ids = { 0x9C } },
		{ names = { "火龍追撃棍" }, type = act_types.low_attack, ids = { 0xB8 } },
		{ names = { "火龍追撃棍" }, type = act_types.attack, ids = { 0xB9 } },
		{ names = { "旋風棍" }, type = act_types.attack, ids = { 0xA4 } },
		{ names = { "旋風棍 持続" }, type = act_types.attack, ids = { 0xA5 } },
		{ names = { "旋風棍 隙" }, type = act_types.any, ids = { 0xA6 } },
		{ names = { "強襲飛翔棍" }, type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0 } },
		{ names = { "強襲飛翔棍" }, type = act_types.any, ids = { 0xB1 } },
		{ names = { "超火炎旋風棍" }, type = act_types.attack, ids = { 0xFE, 0xFF, 0x100 }, },
		{ names = { "紅蓮殺棍" }, type = act_types.attack, ids = { 0xF4, 0xF5, 0xF6 } },
		{ names = { "紅蓮殺棍" }, type = act_types.any, ids = { 0xF7, 0xF8 } },
		{ names = { "サラマンダーストリーム" }, type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C }, },
		{ names = { "近立C" }, type = act_types.low_attack, ids = { 0x43 } },
		{ names = { "CA 立C" }, type = act_types.low_attack, ids = { 0x241 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x248 } },
		{ names = { "CA 立C _6C" }, type = act_types.attack, ids = { 0x242 } },
		{ names = { "CA 屈C" }, type = act_types.attack, ids = { 0x243 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x245 } },
		{ names = { "集点連破棍" }, type = act_types.attack, ids = { 0x246 } },
	},
	-- チン・シンザン
	{
		{ names = { "フェイント 破岩撃" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "フェイント クッサメ砲" }, type = act_types.any, ids = { 0x113 } },
		{ names = { "合気投げ" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "頭突殺" }, type = act_types.any, ids = { 0x81, 0x83, 0x84 } },
		{ names = { "発勁裏拳" }, type = act_types.attack, ids = { 0x68 } },
		{ names = { "落撃双拳" }, type = act_types.overhead, ids = { 0x69 } },
		{ names = { "気雷砲（前方）" }, type = act_types.attack, ids = { 0x86, 0x87, 0x88 }, },
		{ names = { "気雷砲（対空）" }, type = act_types.attack, ids = { 0x90, 0x91, 0x92 }, },
		{ names = { "小 破岩撃" }, type = act_types.low_attack, ids = { 0xA4, 0xA5 } },
		{ names = { "小 破岩撃" }, type = act_types.any, ids = { 0xA6 } },
		{ names = { "小 破岩撃 接触" }, type = act_types.any, ids = { 0xA7, 0xA8 } },
		{ names = { "大 破岩撃" }, type = act_types.low_attack, ids = { 0xAE, 0xAF } },
		{ names = { "大 破岩撃" }, type = act_types.any, ids = { 0xB0 } },
		{ names = { "大 破岩撃 接触" }, type = act_types.any, ids = { 0xB1, 0xB2 } },
		{ names = { "超太鼓腹打ち" }, type = act_types.attack, ids = { 0x9A, 0x9B } },
		{ names = { "満腹滞空" }, type = act_types.attack, ids = { 0x9F, 0xA0 } },
		{ names = { "超太鼓腹打ち", "滞空滞空" }, type = act_types.any, ids = { 0x9C } },
		{ names = { "超太鼓腹打ち 接触", "滞空滞空 接触" }, type = act_types.any, ids = { 0x9D, 0x9E } },
		{ names = { "軟体オヤジ" }, type = act_types.any, ids = { 0xB8 } },
		{ names = { "軟体オヤジ 持続" }, type = act_types.any, ids = { 0xB9 } },
		{ names = { "軟体オヤジ 隙" }, type = act_types.any, ids = { 0xBB } },
		{ names = { "軟体オヤジ 息切れ" }, type = act_types.any, ids = { 0xBA } },
		{ names = { "クッサメ砲" }, type = act_types.low_attack, ids = { 0xC2, 0xC3 }, },
		{ names = { "クッサメ砲" }, type = act_types.any, ids = { 0xC4, 0xC5 }, },
		{ names = { "爆雷砲" }, type = act_types.attack, ids = { 0xFE, 0xFF, 0x100 }, },
		{ names = { "ホエホエ弾" }, type = act_types.low_attack, ids = { 0x108, }, },
		{ names = { "ホエホエ弾 滞空" }, type = act_types.low_attack, ids = { 0x109, 0x10C, 0x10D, 0x114 }, },
		{ names = { "ホエホエ弾 落下1" }, type = act_types.any, ids = { 0x10A }, },
		{ names = { "ホエホエ弾 着地1" }, type = act_types.any, ids = { 0x10B }, },
		{ names = { "ホエホエ弾 落下2" }, type = act_types.any, ids = { 0x115 }, },
		{ names = { "ホエホエ弾 着地2" }, type = act_types.any, ids = { 0x116 }, },
		{ names = { "ホエホエ弾 落下3" }, type = act_types.overhead, ids = { 0x10E }, },
		{ names = { "ホエホエ弾 落下3 接触" }, type = act_types.any, ids = { 0x10F }, },
		{ names = { "ホエホエ弾 着地3" }, type = act_types.any, ids = { 0x110 }, },
		{ names = { "CA 立C" }, type = act_types.low_attack, ids = { 0x24A } },
		{ names = { "CA _3_+C(近)" }, type = act_types.attack, ids = { 0x242 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x240 } },
		{ names = { "CA _3_+C(遠)" }, type = act_types.attack, ids = { 0x249 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x241 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x246 } },
		{ names = { "CA 立C2" }, type = act_types.overhead, ids = { 0x24B, 0x24C } },
		{ names = { "CA 立C2" }, type = act_types.low_attack, ids = { 0x24D } },
		{ names = { "CA 立C3" }, type = act_types.low_attack, ids = { 0x247 } },
		{ names = { "CA _6_6_+B" }, type = act_types.any, ids = { 0x248 } },
		{ names = { "CA D" }, type = act_types.overhead, ids = { 0x243 } },
		{ names = { "CA _3_+C" }, type = act_types.any, ids = { 0x244 } },
		{ names = { "CA _1_+C" }, type = act_types.any, ids = { 0x245 } },
	},
	-- タン・フー・ルー,
	{
		{ names = { "フェイント 旋風剛拳" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "裂千掌" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "右降龍" }, type = act_types.attack, ids = { 0x68 } },
		{ names = { "衝波" }, type = act_types.attack, ids = { 0x86, 0x87 }, },
		{ names = { "衝波" }, type = act_types.any, ids = { 0x88 } },
		{ names = { "小 箭疾歩" }, type = act_types.attack, ids = { 0x90, 0x91 } },
		{ names = { "小 箭疾歩" }, type = act_types.any, ids = { 0x92 } },
		{ names = { "大 箭疾歩" }, type = act_types.attack, ids = { 0x9A, 0x9B } },
		{ names = { "大 箭疾歩" }, type = act_types.any, ids = { 0x9C } },
		{ names = { "裂千脚" }, type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0 } },
		{ names = { "裂千脚" }, type = act_types.any, ids = { 0xB1, 0xB2 } },
		{ names = { "撃放" }, type = act_types.attack, ids = { 0xA4 } },
		{ names = { "撃放 タメ" }, type = act_types.attack, ids = { 0xA5 } },
		{ names = { "撃放 タメ開放" }, type = act_types.attack, ids = { 0xA7, 0xA8, 0xA9 } },
		{ names = { "撃放 隙" }, type = act_types.any, ids = { 0xA6 } },
		{ names = { "旋風剛拳" }, type = act_types.attack, ids = { 0xFE, 0xFF, 0x100 } },
		{ names = { "旋風剛拳" }, type = act_types.any, ids = { 0x101, 0x102 } },
		{ names = { "大撃放" }, type = act_types.attack, ids = { 0x108, 0x109, } },
		{ names = { "大撃放" }, type = act_types.overhead, ids = { 0x10A, 0x10B } },
		{ names = { "大撃放" }, type = act_types.any, ids = { 0x10C } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x67 } },
		{ names = { "CA 立C" }, type = act_types.overhead, ids = { 0x247, 0x248 } },
		{ names = { "CA 立C" }, type = act_types.overhead, ids = { 0x249 } },
		{ names = { "挑発2" }, type = act_types.provoke, ids = { 0x24A } },
		{ names = { "挑発3" }, type = act_types.provoke, ids = { 0x24B } },
	},
	-- ローレンス・ブラッド
	{
		{ names = { "マタドールバスター" }, type = act_types.any, ids = { 0x6D, 0x6E, 0x6F } },
		{ names = { "トルネードキック" }, type = act_types.attack, ids = { 0x68 } },
		{ names = { "オーレィ" }, type = act_types.any, ids = { 0x69 } },
		{ names = { "小ブラッディスピン" }, type = act_types.attack, ids = { 0x86, 0x87 } },
		{ names = { "小ブラッディスピン" }, type = act_types.any, ids = { 0x88, 0x89 } },
		{ names = { "大ブラッディスピン" }, type = act_types.attack, ids = { 0x90, 0x91 } },
		{ names = { "大ブラッディスピン", "大ブラッディスピン ヒット" }, type = act_types.any, ids = { 0x93, 0x94 } },
		{ names = { "大ブラッディスピン ヒット" }, type = act_types.attack, ids = { 0x92 } },
		{ names = { "地上振り向き", "小ブラッディスピン", "大ブラッディスピン" }, type = act_types.any, ids = { 0x3D } },
		{ names = { "ブラッディサーベル" }, type = act_types.attack, ids = { 0x9A, 0x9B }, },
		{ names = { "ブラッディサーベル" }, type = act_types.any, ids = { 0x9C } },
		{ names = { "ブラッディカッター" }, type = act_types.attack, ids = { 0xAE, 0xAF, 0xB0 } },
		{ names = { "ブラッディカッター" }, type = act_types.any, ids = { 0xB2, 0xB1 } },
		{ names = { "ブラッディミキサー" }, type = act_types.attack, ids = { 0xA4 }, },
		{ names = { "ブラッディミキサー持続" }, type = act_types.attack, ids = { 0xA5 }, },
		{ names = { "ブラッディミキサー隙" }, type = act_types.any, ids = { 0xA6 } },
		{ names = { "ブラッディフラッシュ" }, type = act_types.attack, ids = { 0xFE, 0xFF, 0x100, 0x101 } },
		{ names = { "ブラッディフラッシュ フィニッシュ" }, type = act_types.attack, ids = { 0x102 } },
		{ names = { "ブラッディシャドー" }, type = act_types.attack, ids = { 0x108 } },
		{ names = { "ブラッディシャドー ヒット" }, type = act_types.any, ids = { 0x109, 0x10E, 0x10D, 0x10B, 0x10C } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x245 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x246 } },
		{ names = { "CA 立D" }, type = act_types.attack, ids = { 0x24C } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x248 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x49 } },
		{ names = { "CA _6_3_2_+C" }, type = act_types.overhead, ids = { 0x249, 0x24A } },
		{ names = { "CA _6_3_2_+C" }, type = act_types.any, ids = { 0x24B } },
	},
	-- ヴォルフガング・クラウザー
	{
		{ names = { "フェイント ブリッツボール" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "フェイント カイザーウェイブ" }, type = act_types.any, ids = { 0x113 } },
		{ names = { "ニースマッシャー" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "デスハンマー" }, type = act_types.overhead, ids = { 0x68 } },
		{ names = { "カイザーボディプレス" }, type = act_types.attack, ids = { 0x69 } },
		{ names = { "着地", "ジャンプ着地(カイザーボディプレス)" }, type = act_types.any, ids = { 0x72 } },
		{ names = { "ダイビングエルボー" }, type = act_types.any, ids = { 0x6A, 0x73, 0x74, 0x75 } },
		{ names = { "ブリッツボール・上段" }, type = act_types.attack, ids = { 0x86, 0x87, 0x88 }, },
		{ names = { "ブリッツボール・下段" }, type = act_types.low_attack, ids = { 0x90, 0x91, 0x92 }, },
		{ names = { "レッグトマホーク" }, type = act_types.overhead, ids = { 0x9A, 0x9B } },
		{ names = { "レッグトマホーク" }, type = act_types.any, ids = { 0x9C } },
		{ names = { "デンジャラススルー" }, type = act_types.any, ids = { 0xAE, 0xAF } },
		{ names = { "グリフォンアッパー" }, type = act_types.attack, ids = { 0x248 } },
		{ names = { "リフトアップブロー" }, type = act_types.any, ids = { 0xC2, 0xC3 } },
		{ names = { "フェニックススルー" }, type = act_types.any, ids = { 0xA4 } },
		{ names = { "フェニックススルー 捕獲" }, type = act_types.any, ids = { 0xA5, 0xA6, 0xA7 } },
		{ names = { "カイザークロー" }, type = act_types.attack, ids = { 0xB8 } },
		{ names = { "カイザークロー ヒット" }, type = act_types.attack, ids = { 0xB9, 0xBA } },
		{ names = { "カイザーウェイブ" }, type = act_types.attack, ids = { 0xFE } },
		{ names = { "カイザーウェイブため" }, type = act_types.attack, ids = { 0xFF } },
		{ names = { "カイザーウェイブ発射" }, type = act_types.attack, ids = { 0x100, 0x101, 0x102 }, },
		{ names = { "ギガティックサイクロン", "アンリミテッドデザイア2", "ジャンプ" }, type = act_types.any, ids = { 0x108, 0x109, 0x10A, 0x10B, 0xC, 0x10C, 0x10D, 0x10C, 0x10E } },
		{ names = { "アンリミテッドデザイア" }, type = act_types.attack, ids = { 0xE0, 0xE1, } },
		{ names = { "アンリミテッドデザイア" }, type = act_types.any, ids = { 0xE2 } },
		{ names = { "アンリミテッドデザイア(2)" }, type = act_types.attack, ids = { 0xE3 } },
		{ names = { "アンリミテッドデザイア(3)" }, type = act_types.attack, ids = { 0xE4 } },
		{ names = { "アンリミテッドデザイア(4)" }, type = act_types.attack, ids = { 0xE5 } },
		{ names = { "アンリミテッドデザイア(5)" }, type = act_types.attack, ids = { 0xE6 } },
		{ names = { "アンリミテッドデザイア(6)" }, type = act_types.attack, ids = { 0xE7 } },
		{ names = { "アンリミテッドデザイア(7)" }, type = act_types.attack, ids = { 0xE8 } },
		{ names = { "アンリミテッドデザイア(8)" }, type = act_types.attack, ids = { 0xE9 } },
		{ names = { "アンリミテッドデザイア(9)" }, type = act_types.attack, ids = { 0xEA } },
		{ names = { "アンリミテッドデザイア(10)" }, type = act_types.attack, ids = { 0xEB } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x240 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x24E } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x242 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x241 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x244 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x243 } },
		{ names = { "CA _2_3_6_+C" }, type = act_types.attack, ids = { 0x245 } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x247 } },
	},
	-- リック・ストラウド
	{
		{ names = { "フェイント シューティングスター" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "ガング・ホー" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "チョッピングライト" }, type = act_types.overhead, ids = { 0x68, 0x69 } },
		{ names = { "スマッシュソード" }, type = act_types.attack, ids = { 0x6A } },
		{ names = { "パニッシャー" }, type = act_types.attack, ids = { 0x6B } },
		{ names = { "小 シューティングスター" }, type = act_types.attack, ids = { 0x86, 0x87 } },
		{ names = { "小 シューティングスター" }, type = act_types.any, ids = { 0x8C } },
		{ names = { "小 シューティングスター ヒット" }, type = act_types.attack, ids = { 0x88, 0x89, 0x8A } },
		{ names = { "小 シューティングスター ヒット" }, type = act_types.any, ids = { 0x8B } },
		{ names = { "大 シューティングスター" }, type = act_types.attack, ids = { 0x90, 0x91, 0x92, 0x93, 0x94 } },
		{ names = { "シューティングスターEX" }, type = act_types.attack, ids = { 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8 } },
		{ names = { "シューティングスターEX" }, type = act_types.any, ids = { 0xC9, 0xCA } },
		{ names = { "地上振り向き", "シューティングスターEX" }, type = act_types.any, ids = { 0x3D } },
		{ names = { "ブレイジングサンバースト" }, type = act_types.attack, ids = { 0xB8, 0xB9 } },
		{ names = { "ブレイジングサンバースト" }, type = act_types.any, ids = { 0xBA } },
		{ names = { "ヘリオン" }, type = act_types.attack, ids = { 0xAE, 0xAF, 0xB1 } },
		{ names = { "ヘリオン" }, type = act_types.any, ids = { 0xB0 } },
		{ names = { "フルムーンフィーバー" }, type = act_types.any, ids = { 0xA4 } },
		{ names = { "フルムーンフィーバー 持続" }, type = act_types.any, ids = { 0xA5 } },
		{ names = { "フルムーンフィーバー 隙" }, type = act_types.any, ids = { 0xA6 } },
		{ names = { "ディバインブラスト" }, type = act_types.attack, ids = { 0x9A, 0x9B, 0x9C, 0x9D } },
		{ names = { "ディバインブラスト" }, type = act_types.any, ids = { 0x9E } },
		{ names = { "フェイクブラスト" }, type = act_types.any, ids = { 0x9F } },
		{ names = { "ガイアブレス" }, type = act_types.attack, ids = { 0xFE, 0xFF }, },
		{ names = { "ガイアブレス" }, type = act_types.any, ids = { 0x100 } },
		{ names = { "ハウリング・ブル" }, type = act_types.low_attack, ids = { 0x108, 0x109, 0x10A, 0x10B, 0x10C }, },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x240 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x243 } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x241 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x24D } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x244 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x246 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x253 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x251 } },
		{ names = { "CA _3C" }, type = act_types.attack, ids = { 0x248 } },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x242 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x247 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x245 } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x24C } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x24A } },
		{ names = { "CA _6_+C" }, type = act_types.attack, ids = { 0x24E, 0x24F } },
		{ names = { "CA _6_+C" }, type = act_types.any, ids = { 0x250 } },
		{ names = { "CA _2_2_+C" }, type = act_types.overhead, ids = { 0xE6 } },
		{ names = { "CA _2_2_+C" }, type = act_types.any, ids = { 0xE7 } },
		{ names = { "CA _3_3_+B" }, type = act_types.overhead, ids = { 0xE0, 0xE1 } },
		{ names = { "CA _3_3_+B" }, type = act_types.any, ids = { 0xE2 } },
		{ names = { "CA _4_+C" }, type = act_types.attack, ids = { 0x249 } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x24B } },
	},
	-- 李香緋
	{
		{ names = { "フェイント 天崩山" }, type = act_types.any, ids = { 0x113 } },
		{ names = { "フェイント 大鉄神" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "力千後宴" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "裡門頂肘" }, type = act_types.attack, ids = { 0x68, 0x69, 0x6A } },
		{ names = { "後捜腿" }, type = act_types.low_attack, ids = { 0x6B } },
		{ names = { "小 那夢波" }, type = act_types.attack, ids = { 0x86, 0x87, 0x88 }, },
		{ names = { "大 那夢波" }, type = act_types.attack, ids = { 0x90, 0x91, 0x92, 0x93 }, },
		--[[
		  f = ,  0x9E, 0x9F, 閃里肘皇移動
		  f = ,  0xA2, 閃里肘皇スカり
		  f = ,  0xA1, 0xA7, 閃里肘皇ヒット
		  f = ,  0xAD, 閃里肘皇・心砕把スカり
		  f = ,  0xA3, 0xA4, 0xA5, 0xA6, 閃里肘皇・貫空
		  f = ,  0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 閃里肘皇・心砕把
		]]
		{ names = { "閃里肘皇" }, type = act_types.attack, ids = { 0x9E, 0x9F } },
		{ names = { "閃里肘皇" }, type = act_types.any, ids = { 0xA2 } },
		{ names = { "閃里肘皇 ヒット" }, type = act_types.attack, ids = { 0xA1, 0xA7 } },
		{ names = { "閃里肘皇・貫空" }, type = act_types.attack, ids = { 0xA3, 0xA4 } },
		{ names = { "閃里肘皇・貫空" }, type = act_types.attack, ids = { 0xA5, 0xA6 } },
		{ names = { "閃里肘皇・心砕把" }, type = act_types.lunging_throw | act_types.any, ids = { 0xAD } },
		{ names = { "閃里肘皇・心砕把 ヒット" }, type = act_types.attack, ids = { 0xA8, 0xA9, 0xAA, 0xAB, 0xAC } },
		{ names = { "天崩山" }, type = act_types.attack, ids = { 0x9A, 0x9B } },
		{ names = { "天崩山" }, type = act_types.any, ids = { 0x9C, 0x9D } },
		{ names = { "詠酒・対ジャンプ攻撃" }, type = act_types.attack, ids = { 0xB8 } },
		{ names = { "詠酒・対立ち攻撃" }, type = act_types.attack, ids = { 0xAE } },
		{ names = { "詠酒・対しゃがみ攻撃" }, type = act_types.low_attack, ids = { 0xC2 } },
		{ names = { "大鉄神" }, type = act_types.attack, ids = { 0xF4, 0xF5 } },
		{ names = { "大鉄神" }, type = act_types.any, ids = { 0xF6, 0xF7 } },
		{ names = { "超白龍" }, type = act_types.attack, ids = { 0xFE, 0xFF } },
		{ names = { "超白龍 2段目" }, type = act_types.attack, ids = { 0x100, 0x101, 0x102 } },
		{ names = { "超白龍 2段目" }, type = act_types.any, ids = { 0x103 } },
		{ names = { "真心牙" }, type = act_types.attack, ids = { 0x108, 0x109, 0x10D }, },
		{ names = { "真心牙" }, type = act_types.any, ids = { 0x10E, 0x10F, 0x110 } },
		{ names = { "真心牙 ヒット" }, type = act_types.any, ids = { 0x10A, 0x10B, 0x10C } },
		{ names = { "CA 立A" }, type = act_types.attack, ids = { 0x241 } },
		{ names = { "CA 立A" }, type = act_types.attack, ids = { 0x242 } },
		{ names = { "CA 立A" }, type = act_types.attack, ids = { 0x243 } },
		{ names = { "CA 屈A" }, type = act_types.attack, ids = { 0x244 } },
		{ names = { "CA 屈A" }, type = act_types.attack, ids = { 0x245 } },
		{ names = { "CA 屈A" }, type = act_types.attack, ids = { 0x247 } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x24C } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x24D } },
		{ names = { "CA 立C" }, type = act_types.attack, ids = { 0x24A } },
		{ names = { "CA 立A" }, type = act_types.attack, ids = { 0x24B } },
		{ names = { "アッチョンブリケ" }, type = act_types.provoke, ids = { 0x283 } },
		{ names = { "CA 立B" }, type = act_types.attack, ids = { 0x246 } },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x48 } },
		{ names = { "CA 屈B" }, type = act_types.low_attack, ids = { 0x24E } },
		{ names = { "CA 立C" }, type = act_types.overhead, ids = { 0x249 } },
		{ names = { "CA _3_+C" }, type = act_types.attack, ids = { 0x250, 0x251 } },
		{ names = { "CA _3_+C" }, type = act_types.any, ids = { 0x252 } },
		{ names = { "CA 屈C" }, type = act_types.low_attack, ids = { 0x287 } },
		{ names = { "CA _6_6_+A" }, type = act_types.any, ids = { 0x24F } },
		{ names = { "CA _N_+_C" }, type = act_types.any, ids = { 0x284, 0x285, 0x286 } },
	},
	-- アルフレッド
	{
		{ names = { "フェイント クリティカルウィング" }, type = act_types.any, ids = { 0x112 } },
		{ names = { "フェイント オーグメンターウィング" }, type = act_types.any, ids = { 0x113 } },
		{ names = { "バスタソニックウィング" }, type = act_types.any, ids = { 0x6D, 0x6E } },
		{ names = { "フロントステップキック" }, type = act_types.attack, ids = { 0x68 } },
		{ names = { "飛び退きキック" }, type = act_types.attack, ids = { 0x78 } },
		{ names = { "フォッカー" }, type = act_types.overhead, ids = { 0x69 } },
		{ names = { "フォッカー" }, type = act_types.any, ids = { 0x79 } },
		{ names = { "小 クリティカルウィング" }, type = act_types.attack, ids = { 0x86, 0x87, 0x88 } },
		{ names = { "小 クリティカルウィング" }, type = act_types.any, ids = { 0x89 } },
		{ names = { "大 クリティカルウィング" }, type = act_types.attack, ids = { 0x90, 0x91, 0x92 } },
		{ names = { "大 クリティカルウィング" }, type = act_types.any, ids = { 0x93 } },
		{ names = { "オーグメンターウィング" }, type = act_types.attack, ids = { 0x9A, 0x9B } },
		{ names = { "オーグメンターウィング" }, type = act_types.any, ids = { 0x9C, 0x9D } },
		{ names = { "ダイバージェンス" }, type = act_types.attack, ids = { 0xA4, 0xA5 }, },
		{ names = { "メーデーメーデー" }, type = act_types.overhead, ids = { 0xAE } },
		{ names = { "メーデーメーデー" }, type = act_types.overhead, ids = { 0xAF } },
		{ names = { "メーデーメーデー", "メーデーメーデー 攻撃" }, type = act_types.any, ids = { 0xB0 } },
		{ names = { "メーデーメーデー 攻撃" }, type = act_types.overhead, ids = { 0xB1 } },
		{ names = { "メーデーメーデー 追加1" }, type = act_types.overhead, ids = { 0xB2 } },
		{ names = { "メーデーメーデー 追加2" }, type = act_types.overhead, ids = { 0xB3 } },
		{ names = { "メーデーメーデー?" }, type = act_types.overhead, ids = { 0xB4 } },
		{ names = { "メーデーメーデー 追加3" }, type = act_types.overhead, ids = { 0xB5 } },
		{ names = { "メーデーメーデー 追加1", "メーデーメーデー 追加2", "メーデーメーデー 追加3" }, type = act_types.any, ids = { 0xB6 } },
		{ names = { "メーデーメーデー 追加1", "メーデーメーデー 追加2", "メーデーメーデー 追加3" }, type = act_types.any, ids = { 0xB7 } },
		{ names = { "S.TOL" }, type = act_types.lunging_throw | act_types.attack, ids = { 0xB8, 0xB9, 0xBA } },
		{ names = { "S.TOL ヒット" }, type = act_types.any, ids = { 0xBB, 0xBC, 0xBD, 0xBE, 0xBF } },
		{ names = { "ショックストール" }, type = act_types.attack, ids = { 0xFE, 0xFF } },
		{ names = { "ショックストール" }, type = act_types.any, ids = { 0x100, 0x101 } },
		{ names = { "ショックストール ヒット" }, type = act_types.attack, ids = { 0x102, 0x103 } },
		{ names = { "ショックストール ヒット" }, type = act_types.any, ids = { 0x104, 0x105 } },
		{ names = { "ショックストール空中 ヒット" }, type = act_types.attack, ids = { 0xF4, 0xF5 } },
		{ names = { "ショックストール空中 ヒット" }, type = act_types.any, ids = { 0xF6, 0xF7 } },
		{ names = { "ウェーブライダー" }, type = act_types.attack, ids = { 0x108, 0x109, 0x10A, 0x10B } },
		{ names = { "ウェーブライダー" }, type = act_types.any, ids = { 0x10C } },
	},
	{
		-- 共通行動
		{ names = { "ジャンプ", "アンリミテッドデザイア", "ギガティックサイクロン", "絶命人中打ち", "地獄門", "アキレスホールド" }, type = act_types.any, ids = { 0xB, 0xC, 0xD, 0xE, 0xF, 0x10, 0xB, 0x11, 0x12, 0xD, 0x13, 0x14, 0xF, 0x15, 0x16, } },
		{ names = { "ジャンプ移行", "絶命人中打ち", "地獄門", "アキレスホールド" }, type = act_types.any, ids = { 0x8 } },
		{ names = { "着地", "やられ", "絶命人中打ち", "地獄門", "経絡乱打", "アキレスホールド" }, type = act_types.any, ids = { 0x9 } },
		{ names = { "グランドスウェー" }, type = act_types.any, ids = { 0x13C, 0x13D, 0x13E } },
		{ names = { "テクニカルライズ" }, type = act_types.any, ids = { 0x2CA, 0x2C8, 0x2C9 } },
	},
}
local char_fireball_base         = {
	-- テリー・ボガード
	{
		{ names = { "パワーウェイブ" }, type = act_types.attack | act_types.parallel, ids = { 0x265, 0x266, 0x26A, }, },
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
		{ names = { "ハリケーンアッパー" }, type = act_types.attack | act_types.parallel, ids = { 0x266, 0x267, 0x269, }, },
		{ names = { "スクリューアッパー" }, type = act_types.attack | act_types.parallel, ids = { 0x269, 0x26A, 0x26B, }, },
	},
	-- 不知火舞
	{
		{ names = { "花蝶扇" }, type = act_types.attack | act_types.parallel, ids = { 0x261, 0x262, 0x263, }, },
		{ names = { "龍炎舞" }, type = act_types.attack, ids = { 0x264, }, },
	},
	-- ギース・ハワード
	{
		{ names = { "烈風拳" }, type = act_types.attack | act_types.parallel, ids = { 0x261, 0x260, 0x276, }, },
		{ names = { "ダブル烈風拳" }, type = act_types.attack | act_types.parallel, ids = { 0x262, 0x263, 0x264, 0x265, }, },
		{ names = { "レイジングストーム" }, type = act_types.attack, ids = { 0x269, 0x26B, 0x26A, }, },
	},
	-- 望月双角,
	{
		{ names = { "雷撃棍" }, type = act_types.attack, ids = { 0x260, }, },
		{ names = { "野猿狩り/掴み" }, type = act_types.attack, ids = { 0x277, 0x27C, }, },
		{ names = { "まきびし" }, type = act_types.low_attack | act_types.parallel, ids = { 0x274, 0x275, }, },
		{ names = { "憑依弾" }, type = act_types.attack, ids = { 0x263, 0x266, }, },
		{ names = { "邪棍舞" }, type = act_types.attack, ids = { 0xF4, 0xF5, }, },
		{ names = { "邪棍舞 天破" }, type = act_types.attack, ids = { 0xF6, }, },
		{ names = { "邪棍舞 払破" }, type = act_types.low_attack, ids = { 0xF7, }, },
		{ names = { "邪棍舞 倒破" }, type = act_types.overhead, ids = { 0xF8, }, },
		{ names = { "邪棍舞 降破" }, type = act_types.overhead, ids = { 0xF9, }, },
		{ names = { "邪棍舞 突破" }, type = act_types.attack, ids = { 0xFA, }, },
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
		{ names = { "帝王天眼拳" }, type = act_types.attack | act_types.parallel, ids = { 0x262, 0x263, 0x265, }, },
		{ names = { "海龍照臨" }, type = act_types.attack | act_types.rec_in_detail, ids = { 0x273, 0x274, }, },
		{ names = { "帝王漏尽拳" }, type = act_types.attack, ids = { 0x26C, }, },
		{ names = { "帝王空殺漏尽拳" }, type = act_types.low_attack, ids = { 0x26F, }, },
	},
	-- 秦崇雷,
	{
		{ names = { "帝王漏尽拳" }, type = act_types.attack, ids = { 0x266, }, },
		{ names = { "帝王天眼拳" }, type = act_types.attack | act_types.parallel, ids = { 0x26E, }, },
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
		{ names = { "超火炎旋風棍（回転）" }, type = act_types.attack, ids = { 0x261, }, },
		{ names = { "超火炎旋風棍" }, type = act_types.attack, ids = { 0x263, }, },
		{ names = { "超火炎旋風棍（消失）" }, type = act_types.any, ids = { 0x262, }, },
		{ names = { "サラマンダーストリーム" }, type = act_types.attack, ids = { 0x27A, 0x278, }, },
	},
	-- チン・シンザン
	{
		{ names = { "気雷砲（前方）" }, type = act_types.attack | act_types.parallel, ids = { 0x26C, }, },
		{ names = { "気雷砲（前方）" }, type = act_types.low_attack | act_types.parallel, ids = { 0x267, }, },
		{ names = { "気雷砲（対空）" }, type = act_types.attack | act_types.parallel, ids = { 0x26D, }, },
		{ names = { "気雷砲（対空）" }, type = act_types.low_attack | act_types.parallel, ids = { 0x26E, }, },
		{ names = { "気雷砲（着弾）" }, type = act_types.low_attack | act_types.parallel, ids = { 0x268 }, },
		{ names = { "爆雷砲（保持）" }, type = act_types.attack, ids = { 0x287, }, },
		{ names = { "爆雷砲" }, type = act_types.low_attack, ids = { 0x272, }, },
		{ names = { "爆雷砲（着弾）" }, type = act_types.low_attack, ids = { 0x273, }, },
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
		{ names = { "ブリッツボール・上段" }, type = act_types.attack | act_types.parallel, ids = { 0x263, 0x262, }, },
		{ names = { "ブリッツボール・下段" }, type = act_types.low_attack | act_types.parallel, ids = { 0x263, 0x266 }, },
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
local extend_act_names           = function(acts)
	for i = 1, #acts.names do acts.names[i] = acts.names[i] end
	acts.name_set = ut.table_to_set(acts.names)
	acts.name = acts.names[1]
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
end
local register_act_datas         = function(acts, char_acts)
	for i, id in ipairs(acts.ids) do
		if i == 1 then
			acts.id_1st = id
		end
		char_acts[id] = acts
	end
end
for char, acts_base in pairs(char_acts_base) do
	-- キャラごとのテーブル作成
	for _, acts in pairs(acts_base) do
		extend_act_names(acts)
		register_act_datas(acts, chars[char].acts)
	end
end
for char, fireballs_base in pairs(char_fireball_base) do
	for _, acts in pairs(fireballs_base) do
		extend_act_names(acts)
		register_act_datas(acts, chars[char].fireballs)
	end
end
for char = 1, #chars - 1 do
	-- TODO この処理はいらないかも
	for id, acts in pairs(chars[#chars].acts) do
		chars[char].acts[id] = acts
	end
	for id, acts in pairs(chars[#chars].fireballs) do
		chars[char].fireballs[id] = acts
	end
end

db.wakeup_acts = ut.new_set(0x193, 0x13B)
db.pre_down_acts = ut.new_set(0x142, 0x145, 0x156, 0x15A, 0x15B, 0x15E, 0x15F, 0x160, 0x162, 0x166, 0x16A, 0x16C, 0x16D, 0x174, 0x175, 0x186, 0x188, 0x189, 0x1E0, 0x1E1, 0x2AE, 0x2BA)

--------------------------------------------------------------------------------------
-- ブレイクショットデータおよびリバーサルコマンド
-- キャラの基本データに追加する
--------------------------------------------------------------------------------------

local rvs_types = {
	on_wakeup           = 1, -- ダウン起き上がりリバーサル入力
	jump_landing        = 2, -- 着地リバーサル入力（やられの着地）
	knock_back_landing  = 3, -- 着地リバーサル入力（通常ジャンプの着地）
	knock_back_recovery = 4, -- リバーサルじゃない最速入力
	in_knock_back       = 5, -- のけぞり中のデータをみてのけぞり修了の_2F前に入力確定する
	dangerous_through   = 6, -- デンジャラススルー用
	atemi               = 7, -- 当身うち空振りと裏雲隠し用
}
--レバー 7=05 8=01 9=09  ボタン A=10 B=20 C=40 D=80
--       4=04 5=00 6=08
--       1=06 2=02 3=0A
--レバー 7=0101 8=0001 9=1001  ボタン A=00010000 B=00100000 C=01000000 D=10000000
--       4=0100 5=0000 6=1000
--       1=0110 2=0010 3=1010
local cmd_bytes = {
	_1 = 0x6,
	_2 = 0x2,
	_3 = 0xA,
	_4 = 0x4,
	_5 = 0x0,
	_6 = 0x8,
	_7 = 0x5,
	_8 = 0x1,
	_9 = 0x9,
	_A = 0x10,
	_B = 0x20,
	_C = 0x40,
	_D = 0x80,
	front = "front",
	back = "back",
}
local cmd_status_b = {
	{
		_st = 2 ^ 0, -- Start P1
		_sl = 2 ^ 2, -- Select P1
	},
	{
		_st = 2 ^ 1, -- Start P2
		_sl = 2 ^ 3, -- Select P2
	},
}
local cmd_rev_masks = {
	{ cmd = 0x01, mask = 0xFD }, -- 1111 1101
	{ cmd = 0x02, mask = 0xFE }, -- 1111 1110
	{ cmd = 0x04, mask = 0xF7 }, -- 1111 0111
	{ cmd = 0x08, mask = 0xFB }, -- 1111 1011
	{ cmd = 0x10, mask = 0xDF }, -- 1110 1111
	{ cmd = 0x20, mask = 0xEF }, -- 1101 1111
	{ cmd = 0x40, mask = 0x7F }, -- 1011 1111
	{ cmd = 0x80, mask = 0xBF }, -- 0111 1111
}
local cmd_masks = {
	[cmd_bytes._1] = 0xFF ~ cmd_bytes._9,
	[cmd_bytes._2] = 0xFF ~ cmd_bytes._8,
	[cmd_bytes._3] = 0xFF ~ cmd_bytes._7,
	[cmd_bytes._4] = 0xFF ~ cmd_bytes._6,
	[cmd_bytes._5] = 0xFF,
	[cmd_bytes._6] = 0xFF ~ cmd_bytes._4,
	[cmd_bytes._7] = 0xFF ~ cmd_bytes._3,
	[cmd_bytes._8] = 0xFF ~ cmd_bytes._2,
	[cmd_bytes._9] = 0xFF ~ cmd_bytes._1,
	[cmd_bytes._A] = 0xFF,
	[cmd_bytes._B] = 0xFF,
	[cmd_bytes._C] = 0xFF,
	[cmd_bytes._D] = 0xFF,
}
local cmd_types = {
	_1  = cmd_bytes._1,
	_2  = cmd_bytes._2,
	_3  = cmd_bytes._3,
	_4  = cmd_bytes._4,
	_5  = cmd_bytes._5,
	_6  = cmd_bytes._6,
	_7  = cmd_bytes._7,
	_8  = cmd_bytes._8,
	_9  = cmd_bytes._9,
	_A  = cmd_bytes._A,
	_B  = cmd_bytes._B,
	_C  = cmd_bytes._C,
	_D  = cmd_bytes._D,
	_AB = cmd_bytes._A | cmd_bytes._B,
	_BC = cmd_bytes._B | cmd_bytes._C,
	_6A = cmd_bytes._6 | cmd_bytes._A,
	_3A = cmd_bytes._3 | cmd_bytes._A,
	_2A = cmd_bytes._2 | cmd_bytes._A,
	_4A = cmd_bytes._4 | cmd_bytes._A,
	_6B = cmd_bytes._6 | cmd_bytes._B,
	_3B = cmd_bytes._3 | cmd_bytes._B,
	_2B = cmd_bytes._2 | cmd_bytes._B,
	_4B = cmd_bytes._4 | cmd_bytes._B,
	_6C = cmd_bytes._6 | cmd_bytes._C,
	_3C = cmd_bytes._3 | cmd_bytes._C,
	_2C = cmd_bytes._2 | cmd_bytes._C,
	_4C = cmd_bytes._4 | cmd_bytes._C,
	_8D = cmd_bytes._8 | cmd_bytes._D,
	_2D = cmd_bytes._2 | cmd_bytes._D,
}
cmd_types.front = { [-1] = cmd_types._4, [1] = cmd_types._6, }
cmd_types.back = { [-1] = cmd_types._6, [1] = cmd_types._4, }
local hook_cmd_types = {
	none = 0,
	reversal = 2 ^ 0,
	breakshot = 2 ^ 1,
	otg_stomp = 2 ^ 2,
	otg_throw = 2 ^ 3,
	add_throw = 2 ^ 4,
	add_attack = 2 ^ 5,
	wakeup = 2 ^ 6,
	throw = 2 ^ 7,
	jump = 2 ^ 8,
	ex_breakshot = 2 ^ 9,
}
hook_cmd_types.ex_breakshot = hook_cmd_types.breakshot | hook_cmd_types.ex_breakshot
local common_rvs = {
	{ cmd = cmd_types._6C, hook_type = hook_cmd_types.reversal| hook_cmd_types.throw, common = true, name = "[共通] 投げ(_6_+_C)", },
	{ cmd = cmd_types._AB, hook_type = hook_cmd_types.reversal, common = true, name = "[共通] 避け攻撃(_A_+_B)", },
	{ cmd = cmd_types._2A, hook_type = hook_cmd_types.reversal, common = true, name = "[共通] 屈A(_2_+_A)", },
	{ cmd = cmd_types._A, hook_type = hook_cmd_types.reversal, common = true, name = "[共通] 立A", },
	{ cmd = cmd_types._2B, hook_type = hook_cmd_types.reversal, common = true, name = "[共通] 屈B(_2_+_B)", },
	{ cmd = cmd_types._B, hook_type = hook_cmd_types.reversal, common = true, name = "[共通] 立B", },
	{ cmd = cmd_types._2C, hook_type = hook_cmd_types.reversal, common = true, name = "[共通] 屈C(_2_+_C)", },
	{ cmd = cmd_types._2D, hook_type = hook_cmd_types.reversal, common = true, name = "[共通] 屈D(_2_+_D)", },
	{ cmd = cmd_types._C, hook_type = hook_cmd_types.reversal, common = true, name = "[共通] 立C", },
	{ cmd = cmd_types._D, hook_type = hook_cmd_types.reversal, common = true, name = "[共通] 立D", },
	{ cmd = cmd_types._8, hook_type = hook_cmd_types.reversal| hook_cmd_types.jump, common = true, name = "[共通] 垂直ジャンプ(_8)", },
	{ cmd = cmd_types._9, hook_type = hook_cmd_types.reversal| hook_cmd_types.jump, common = true, name = "[共通] 前ジャンプ(_9)", },
	{ cmd = cmd_types._7, hook_type = hook_cmd_types.reversal| hook_cmd_types.jump, common = true, name = "[共通] 後ジャンプ(_7)", },
	{ id = 0x1E, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, common = true, name = "[共通] ダッシュ", },
	{ id = 0x1F, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, common = true, name = "[共通] 飛び退き", },
}
-- idはコマンドテーブル上の技ID
-- verは追加入力フラグとして認識される技ID
local rvs_bs_list = {
	-- id: 技ID f:コマンド成立持続フレーム a:追加入力成立ID（コマンド成立持続フレームの影響を受けない）
	-- テリー・ボガード
	{
		{ cmd = cmd_types._3A, hook_type = hook_cmd_types.reversal, name = "ワイルドアッパー(_3_+_A)", },
		{ cmd = cmd_types._6B, hook_type = hook_cmd_types.reversal, name = "バックスピンキック(_6_+_B)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小バーンナックル", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "大バーンナックル", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "パワーウェイブ", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ランドウェイブ", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "クラックシュート", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ファイヤーキック", },
		{ id = 0x07, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "パッシングスウェー", },
		{ id = 0x08, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ライジングタックル", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "パワーゲイザー", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "トリプルゲイザー", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント バーンナックル", },
		{ id = 0x47, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント パワーゲイザー", },
	},
	-- アンディ・ボガード
	{
		{ cmd = cmd_types._3A, hook_type = hook_cmd_types.reversal, name = "上げ面(_3_+_A)", },
		{ cmd = cmd_types._6B, hook_type = hook_cmd_types.reversal, name = "浴びせ蹴り(_6_+_B)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "小残影拳", },
		{ id = 0x02, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "大残影拳", },
		{ id = 0x02, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.add_attack, name = "疾風裏拳", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "飛翔拳", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "激飛翔拳", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "昇龍弾", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "空破弾", },
		{ id = 0x07, f = 0x12, a = 0x00, hook_type = hook_cmd_types.none | hook_cmd_types.ex_breakshot, name = "幻影不知火", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "超裂破弾", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "男打弾", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 残影拳", },
		{ id = 0x47, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 飛翔拳", },
		{ id = 0x48, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 超裂破弾", },
	},
	-- 東丈
	{
		{ cmd = cmd_types._3C, hook_type = hook_cmd_types.reversal, name = "膝地獄(_3_+_C)", },
		{ cmd = cmd_types._3B, hook_type = hook_cmd_types.reversal, name = "上げ面(_3_+_A)", },
		{ cmd = cmd_types._4B, hook_type = hook_cmd_types.reversal, name = "ハイキック(_4_+_B)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "小スラッシュキック", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "大スラッシュキック", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "黄金のカカト", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "タイガーキック", },
		{ id = 0x05, f = 0x0C, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "爆裂拳", },
		{ id = 0x00, f = 0x0C, a = 0xFF, hook_type = hook_cmd_types.add_attack, name = "爆裂フック", },
		{ id = 0x00, f = 0x0C, a = 0xFE, hook_type = hook_cmd_types.add_attack, name = "爆裂アッパー", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ハリケーンアッパー", },
		{ id = 0x07, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "爆裂ハリケーン", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "スクリューアッパー", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "サンダーファイヤー(C)", },
		{ id = 0x13, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "サンダーファイヤー(D)", },
		{ id = 0x21, f = 0x06, a = 0x00, hook_type = hook_cmd_types.otg_stomp, name = "炎の指先", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント ハリケーンアッパー", },
		{ id = 0x47, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント スラッシュキック", },
	},
	-- 不知火舞
	{
		{ cmd = cmd_types._4A, hook_type = hook_cmd_types.reversal, name = "龍の舞(_4_+_A)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "花蝶扇", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "龍炎舞", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小夜千鳥", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "必殺忍蜂", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.none | hook_cmd_types.ex_breakshot, name = "ムササビの舞", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "超必殺忍蜂", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "花嵐", },
		{ id = 0x23, f = 0x78, a = 0x00, hook_type = hook_cmd_types.wakeup, name = "跳ね蹴り", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 花蝶扇", },
		{ id = 0x47, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 花嵐", },
	},
	-- ギース・ハワード
	{
		{ cmd = cmd_types._3C, hook_type = hook_cmd_types.reversal, name = "虎殺掌(_3_+_C)", },
		{ cmd = cmd_types._3A, hook_type = hook_cmd_types.reversal, name = "昇天明星打ち(_3_+_A)", },
		{ cmd = cmd_types._6A, hook_type = hook_cmd_types.reversal, name = "飛燕失脚(_6_+_A)", },
		{ cmd = cmd_types._4B, hook_type = hook_cmd_types.reversal, name = "雷光回し蹴り(_4_+_B)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "烈風拳", },
		{ id = 0x02, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ダブル烈風拳", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "上段当て身投げ", },
		{ id = 0x04, f = 0x06, a = 0xFE, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "裏雲隠し", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "下段当て身打ち", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.otg_throw, name = "雷鳴豪波投げ", },
		{ id = 0x07, f = 0x06, a = 0xFD, hook_type = hook_cmd_types.reversal | hook_cmd_types.throw | hook_cmd_types.ex_breakshot, name = "真空投げ", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "レイジングストーム", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "羅生門", },
		{ id = 0x13, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "デッドリーレイブ", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 烈風拳", },
		{ id = 0x47, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント レイジングストーム", },
		{ id = 0x50, f = 0x06, a = 0x00, hook_type = hook_cmd_types.add_throw, name = "絶命人中打ち", }
	},
	-- 望月双角
	{
		{ cmd = cmd_types._3A, hook_type = hook_cmd_types.reversal, name = "錫杖上段打ち(_3_+_A)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "野猿狩り", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "まきびし", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "憑依弾", },
		{ id = 0x04, f = 0x06, a = 0xFE, hook_type = hook_cmd_types.reversal| hook_cmd_types.throw | hook_cmd_types.ex_breakshot, name = "鬼門陣", },
		{ id = 0x05, f = 0x0C, a = 0xFF, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "邪棍舞", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "喝", },
		{ id = 0x07, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "渦炎陣", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "いかづち", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "無惨弾", },
		{ id = 0x21, f = 0x06, a = 0x00, hook_type = hook_cmd_types.otg_stomp, name = "雷撃棍", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント まきびし", },
		{ id = 0x47, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント いかづち", },
		{ id = 0x50, f = 0x06, a = 0x00, hook_type = hook_cmd_types.add_throw, name = "地獄門", }
	},
	-- ボブ・ウィルソン
	{
		{ cmd = cmd_types._3A, hook_type = hook_cmd_types.reversal, name = "エレファントタスク(_3_+_A)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ローリングタートル", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "サイドワインダー", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "バイソンホーン", },
		{ id = 0x04, f = 0x06, a = 0x02, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ワイルドウルフ", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "モンキーダンス", },
		{ id = 0x06, f = 0x06, a = 0xFE, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "フロッグハンティング", },
		{ id = 0x00, f = 0x1E, a = 0xFF, hook_type = hook_cmd_types.add_throw, name = "ホーネットアタック", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "デンジャラスウルフ", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ダンシングバイソン", },
		{ id = 0x21, f = 0x06, a = 0x00, hook_type = hook_cmd_types.otg_stomp, name = "リンクスファング", },
		{ id = 0x23, f = 0x78, a = 0x00, hook_type = hook_cmd_types.wakeup, name = "ボブサマー", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント ダンシングバイソン", },
	},
	-- ホンフゥ
	{
		{ cmd = cmd_types._3A, hook_type = hook_cmd_types.reversal, name = "ハエタタキ(_3_+_A)", },
		{ cmd = cmd_types._6B, hook_type = hook_cmd_types.reversal, name = "踏み込み側蹴り(_6_+_B)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "九龍の読み", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小 制空烈火棍", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "大 制空烈火棍", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "電光石火の地", },
		{ id = 0x00, f = 0x0C, a = 0xFE, hook_type = hook_cmd_types.add_attack, name = "電光パチキ", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "電光石火の天", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "炎の種馬", },
		{ id = 0x00, f = 0x0C, a = 0xFF, hook_type = hook_cmd_types.add_attack, name = "炎の種馬連打", },
		{ id = 0x07, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "必勝！逆襲拳", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "爆発ゴロー", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "よかトンハンマー", },
		{ id = 0x21, f = 0x06, a = 0x00, hook_type = hook_cmd_types.otg_stomp, name = "トドメヌンチャク", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 制空烈火棍", },
	},
	-- ブルー・マリー
	{
		{ cmd = cmd_types._6B, hook_type = hook_cmd_types.reversal, name = "ヒールフォール(_6_+_B)", },
		{ cmd = cmd_types._4B, hook_type = hook_cmd_types.reversal, name = "ダブルローリング(_4_+_B)", },
		{ id = 0x01, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.none | hook_cmd_types.ex_breakshot, name = "M.スパイダー", },
		{ id = 0x01, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.add_attack, name = "ダブルスパイダー", },
		{ id = 0x02, f = 0x06, a = 0xFE, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "M.スナッチャー", },
		{ id = 0x02, f = 0x06, a = 0xFE, hook_type = hook_cmd_types.add_attack, name = "ダブルスナッチャー", },
		{ id = 0x03, f = 0x06, a = 0xFD, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "M.クラブクラッチ", },
		{ id = 0x00, f = 0x06, a = 0xFD, hook_type = hook_cmd_types.add_attack, name = "ダブルクラッチ", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "M.リアルカウンター", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "スピンフォール", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "バーチカルアロー", },
		{ id = 0x07, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ストレートスライサー", },
		{ id = 0x09, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ヤングダイブ", },
		{ id = 0x08, f = 0x06, a = 0xF9, hook_type = hook_cmd_types.otg_throw, name = "M.ダイナマイトスウィング", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "M.タイフーン", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "M.エスカレーション", },
		{ id = 0x28, f = 0x06, a = 0x00, hook_type = hook_cmd_types.add_attack, name = "M.トリプルエクスタシー", },
		{ id = 0x24, f = 0x06, a = 0x00, hook_type = hook_cmd_types.otg_stomp, name = "レッグプレス", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント M.スナッチャー", },
		{ id = 0x50, f = 0x06, a = 0x00, hook_type = hook_cmd_types.add_throw, name = "アキレスホールド", }
	},
	-- フランコ・バッシュ
	{
		{ cmd = cmd_types._6B, hook_type = hook_cmd_types.reversal, name = "バッシュトルネード(_6_+_B)", },
		{ cmd = cmd_types._BC, hook_type = hook_cmd_types.reversal, name = "バロムパンチ(_B_+_C)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ダブルコング", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ザッパー", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ウェービングブロー", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ガッツダンク", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ゴールデンボンバー", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ファイナルオメガショット", },
		{ id = 0x11, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "メガトンスクリュー", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ハルマゲドンバスター", },
		{ id = 0x23, f = 0x78, a = 0x00, hook_type = hook_cmd_types.wakeup, name = "スマッシュ", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント ハルマゲドンバスター", },
		{ id = 0x47, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント ガッツダンク", },
	},
	-- 山崎竜二
	{
		{ cmd = cmd_types._6A, hook_type = hook_cmd_types.reversal, name = "ブッ刺し(_6_+_A)", },
		{ cmd = cmd_types._3A, hook_type = hook_cmd_types.reversal, name = "昇天(_3_+_A)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "蛇使い・上段", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "蛇使い・中段", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "蛇使い・下段", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "サドマゾ", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ヤキ入れ", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "倍返し", },
		{ id = 0x07, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "裁きの匕首", },
		{ id = 0x08, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal| hook_cmd_types.throw | hook_cmd_types.ex_breakshot, name = "爆弾パチキ", },
		{ id = 0x09, f = 0x0C, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.otg_stomp | hook_cmd_types.add_throw | hook_cmd_types.ex_breakshot, name = "トドメ", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ギロチン", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal| hook_cmd_types.throw | hook_cmd_types.ex_breakshot, name = "ドリル", },
		{ id = 0x23, f = 0x78, a = 0x00, hook_type = hook_cmd_types.wakeup, name = "メツブシ", },
		{ id = 0x00, f = 0x06, a = 0xFE, hook_type = hook_cmd_types.add_attack, name = "ドリル Lv.5", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 裁きの匕首", },
	},
	-- 秦崇秀
	{
		{ cmd = cmd_types._6A, hook_type = hook_cmd_types.reversal, name = "光輪殺(_6_+_A)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "帝王神足拳", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小 帝王天眼拳", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "大 帝王天眼拳", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小 帝王天耳拳", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "大 帝王天耳拳", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 海龍照臨", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "竜灯掌", },
		{ id = 0x08, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.add_attack, name = "竜灯掌・幻殺", },
		{ id = 0x07, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "帝王神眼拳（その場）", },
		{ id = 0x08, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "帝王神眼拳（空中）", },
		{ id = 0x09, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "帝王神眼拳（背後）", },
		{ id = 0x0A, f = 0x06, a = 0x00, hook_type = hook_cmd_types.none | hook_cmd_types.ex_breakshot, name = "帝王空殺神眼拳", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "帝王漏尽拳", },
		{ id = 0x11, f = 0x06, a = 0x00, hook_type = hook_cmd_types.none | hook_cmd_types.ex_breakshot, name = "帝王空殺漏尽拳", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "海龍照臨", },
	},
	-- 秦崇雷,
	{
		{ cmd = cmd_types._6B, hook_type = hook_cmd_types.reversal, name = "龍殺脚(_6_+_B)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "帝王神足拳", },
		{ id = 0x01, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "真 帝王神足拳", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小 帝王天眼拳", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "大 帝王天眼拳", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小 帝王天耳拳", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "大 帝王天耳拳", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "帝王漏尽拳", },
		{ id = 0x07, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "龍転身（前方）", },
		{ id = 0x08, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "龍転身（後方）", },
		{ id = 0x10, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "帝王宿命拳", },
		{ id = 0x00, f = 0x06, a = 0xFE, hook_type = hook_cmd_types.add_attack, name = "帝王宿命拳(連射)", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "帝王龍声拳", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 帝王宿命拳", },
	},
	-- ダック・キング
	{
		{ cmd = cmd_types._3B, hook_type = hook_cmd_types.reversal, name = "ニードルロー(_3_+_B)", },
		{ cmd = cmd_types._4A, hook_type = hook_cmd_types.reversal, name = "マッドスピンハンマー(_4_+_A)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小ヘッドスピンアタック", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "大ヘッドスピンアタック", },
		{ id = 0x00, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.add_attack, act = 0x91, name = "オーバーヘッドキック", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "フライングスピンアタック", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ダンシングダイブ", },
		{ id = 0x00, f = 0x06, a = 0xFE, hook_type = hook_cmd_types.reversal, act = 0xA5, name = "リバースダイブ", },
		{ id = 0x05, f = 0x06, a = 0xFE, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ブレイクストーム", },
		{ id = 0x00, f = 0x06, a = 0xFD, hook_type = hook_cmd_types.add_attack, act = 0xAF, name = "ブレイクストーム追撃1段階目", },
		{ id = 0x00, f = 0x06, a = 0xFC, hook_type = hook_cmd_types.add_attack, act = 0xAF, name = "ブレイクストーム追撃2段階目", },
		{ id = 0x00, f = 0x06, a = 0xFB, hook_type = hook_cmd_types.add_attack, act = 0xAF, name = "ブレイクストーム追撃3段階目", },
		{ id = 0x11, f = 0x06, a = 0xFA, hook_type = hook_cmd_types.add_throw, act = 0xAF, name = "クレイジーブラザー", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.add_attack | hook_cmd_types.ex_breakshot, name = "ダックフェイント・空", },
		{ id = 0x07, f = 0x06, a = 0x00, hook_type = hook_cmd_types.none, name = "ダックフェイント・地", },
		{ id = 0x08, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "クロスヘッドスピン", },
		{ id = 0x09, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ダンシングキャリバー", },
		{ id = 0x0A, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ローリングパニッシャー", },
		{ id = 0x0C, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ブレイクハリケーン", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal| hook_cmd_types.throw | hook_cmd_types.ex_breakshot, name = "ブレイクスパイラル", },
		{ id = 0x11, f = 0x06, a = 0xFA, hook_type = hook_cmd_types.none | hook_cmd_types.ex_breakshot, name = "ブレイクスパイラルBR", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ダックダンス", },
		{ id = 0x00, f = 0x06, a = 0xF8, hook_type = hook_cmd_types.add_attack, name = "ダックダンス継続", },
		{ id = 0x13, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "スーパーポンピングマシーン", },
		{ id = 0x00, f = 0x06, a = 0xF9, hook_type = hook_cmd_types.none, name = "ダイビングパニッシャー", },
		{ id = 0x21, f = 0x06, a = 0x00, hook_type = hook_cmd_types.otg_stomp, name = "ショッキングボール", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント ダックダンス", },
		{ id = 0x28, f = 0x06, a = 0x00, hook_type = hook_cmd_types.add_attack, act = 0x245, name = "旧ブレイクストーム", },
	},
	-- キム・カッファン
	{
		{ cmd = cmd_types._6B, hook_type = hook_cmd_types.reversal, name = "ネリチャギ(_4_+_B)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "飛燕斬・真上", },
		{ id = 0x01, f = 0x06, a = 0x01, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "飛燕斬・前方", },
		{ id = 0x01, f = 0x06, a = 0x02, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "飛燕斬・後方", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小 半月斬", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "大 半月斬", },
		{ id = 0x04, f = 0x08, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "飛翔脚", },
		{ id = 0x00, f = 0x08, a = 0xFF, hook_type = hook_cmd_types.add_attack, name = "戒脚", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "空砂塵", },
		{ id = 0x00, f = 0x06, a = 0xFE, hook_type = hook_cmd_types.add_attack, name = "天昇斬", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "覇気脚", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.none | hook_cmd_types.ex_breakshot, name = "鳳凰天舞脚", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "鳳凰脚", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 鳳凰脚", },
	},
	-- ビリー・カーン
	{
		{ cmd = cmd_types._3C, hook_type = hook_cmd_types.reversal, name = "地獄落とし(_3_+_C)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "三節棍中段打ち", },
		{ id = 0x00, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.add_attack, name = "火炎三節棍中段突き", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "雀落とし", },
		{ id = 0x04, f = 0x0C, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "旋風棍", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "強襲飛翔棍", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "火龍追撃棍", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "超火炎旋風棍", },
		{ id = 0x11, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "紅蓮殺棍", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "サラマンダーストリーム", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 強襲飛翔棍", },
	},
	-- チン・シンザン
	{
		{ cmd = cmd_types._6A, hook_type = hook_cmd_types.reversal, name = "落撃双拳(_6_+_A)", },
		{ cmd = cmd_types._4A, hook_type = hook_cmd_types.reversal, name = "発勁裏拳(_4_+_A)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "気雷砲（前方）", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "気雷砲（対空）", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "超太鼓腹打ち", },
		{ id = 0x00, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.add_attack | hook_cmd_types.ex_breakshot, name = "満腹対空", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小 破岩撃", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "大 破岩撃", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "軟体オヤジ", },
		{ id = 0x07, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "クッサメ砲", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "爆雷砲", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ホエホエ弾", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 破岩撃", },
		{ id = 0x47, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント クッサメ砲", },
	},
	-- タン・フー・ルー,
	{
		{ cmd = cmd_types._3A, hook_type = hook_cmd_types.reversal, name = "右降龍(_3_+_A)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "衝波", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小 箭疾歩", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "大 箭疾歩", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "撃放", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "裂千脚", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "旋風剛拳", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "大撃放", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 旋風剛拳", },
	},
	-- ローレンス・ブラッド
	{
		{ cmd = cmd_types._6B, hook_type = hook_cmd_types.reversal, name = "トルネードキック(_6_+_B)", },
		{ cmd = cmd_types._BC, hook_type = hook_cmd_types.reversal, name = "オーレィ(_B_+_C)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小 ブラッディスピン", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "大 ブラッディスピン", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ブラッディサーベル", },
		{ id = 0x04, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ブラッディミキサー", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ブラッディカッター", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ブラッディフラッシュ", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ブラッディシャドー", },
	},
	-- ヴォルフガング・クラウザー
	{
		{ cmd = cmd_types._6A, hook_type = hook_cmd_types.reversal, name = "デスハンマー(_6_+_A)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ブリッツボール・上段", },
		{ id = 0x02, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ブリッツボール・下段", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "レッグトマホーク", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal| hook_cmd_types.throw | hook_cmd_types.ex_breakshot, name = "フェニックススルー", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal| hook_cmd_types.throw | hook_cmd_types.ex_breakshot, name = "デンジャラススルー", },
		{ id = 0x00, f = 0x06, a = 0xFD, hook_type = hook_cmd_types.add_attack, name = "グリフォンアッパー", },
		{ id = 0x06, f = 0x06, a = 0xFC, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "カイザークロー", },
		{ id = 0x07, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "リフトアップブロー", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "カイザーウェイブ", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal| hook_cmd_types.throw | hook_cmd_types.ex_breakshot, name = "ギガティックサイクロン", },
		{ id = 0x13, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "アンリミテッドデザイア", },
		{ id = 0x00, f = 0x06, a = 0xFE, hook_type = hook_cmd_types.add_attack, name = "アンリミテッドデザイア2", },
		{ id = 0x21, f = 0x06, a = 0x00, hook_type = hook_cmd_types.otg_stomp, name = "ダイビングエルボー", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント ブリッツボール", },
		{ id = 0x47, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント カイザーウェイブ", },
	},
	-- リック・ストラウド
	{
		{ cmd = cmd_types._6A, hook_type = hook_cmd_types.reversal, name = "チョッピングライト(_6_+_A)", },
		{ cmd = cmd_types._3A, hook_type = hook_cmd_types.reversal, name = "スマッシュソード(_3_+_A)", },
		--{ id = 0x28, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot , name = "?", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小 シューティングスター", },
		{ id = 0x02, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "大 シューティングスター", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ディバインブラスト", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "フルムーンフィーバー", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ヘリオン", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ブレイジングサンバースト", },
		-- { id = 0x09, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "?", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ガイアブレス", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ハウリング・ブル", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント シューティングスター", },
	},
	-- 李香緋
	{
		{ cmd = cmd_types._6A, hook_type = hook_cmd_types.reversal, name = "裡門頂肘(_6_+_A)", },
		{ cmd = cmd_types._4B, hook_type = hook_cmd_types.reversal, name = "後捜腿(_4_+_B)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小 那夢波", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "大 那夢波", },
		{ id = 0x03, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "閃里肘皇", },
		{ id = 0x03, f = 0x06, a = 0xFF, hook_type = hook_cmd_types.add_attack, name = "閃里肘皇・貫空", },
		{ id = 0x00, f = 0x06, a = 0xFE, hook_type = hook_cmd_types.add_throw, name = "閃里肘皇・心砕把", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "天崩山", },
		{ id = 0x07, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "詠酒・対ジャンプ攻撃", },
		{ id = 0x08, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "詠酒・対立ち攻撃", },
		{ id = 0x09, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "詠酒・対しゃがみ攻撃", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "大鉄神", },
		{ id = 0x11, f = 0x06, a = 0xFD, hook_type = hook_cmd_types.reversal, name = "超白龍", },
		{ id = 0x00, f = 0x06, a = 0xFD, hook_type = hook_cmd_types.add_attack, name = "超白龍2", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal| hook_cmd_types.throw | hook_cmd_types.ex_breakshot, name = "真心牙", },
		{ id = 0x47, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 天崩山", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント 大鉄神", },
	},
	-- アルフレッド
	{
		{ cmd = cmd_types._6B, hook_type = hook_cmd_types.reversal, name = "フロントステップキック(_6_+_B)", },
		{ cmd = cmd_types._4B, hook_type = hook_cmd_types.reversal, name = "飛び退きキック(_4_+_B)", },
		{ id = 0x01, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "小 クリティカルウィング", },
		{ id = 0x02, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "大 クリティカルウィング", },
		{ id = 0x03, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "オーグメンターウィング", },
		{ id = 0x04, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.breakshot, name = "ダイバージェンス", },
		{ id = 0x05, f = 0x06, a = 0x00, hook_type = hook_cmd_types.none | hook_cmd_types.ex_breakshot, name = "メーデーメーデー", },
		{ id = 0x06, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "S.TOL", },
		{ id = 0x10, f = 0x06, a = 0x00, hook_type = hook_cmd_types.none | hook_cmd_types.ex_breakshot, name = "ショックストール", },
		{ id = 0x12, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal | hook_cmd_types.ex_breakshot, name = "ウェーブライダー", },
		{ id = 0x46, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント クリティカルウィング", },
		{ id = 0x47, f = 0x06, a = 0x00, hook_type = hook_cmd_types.reversal, name = "フェイント オーグメンターウィング", },
	},
}
local calc_ver = function(rvs)
	if rvs.id and rvs.id < 0x1E then rvs.ver = (rvs.f << 0x8) | rvs.a end
	return rvs
end
local char_rvs_list, char_bs_list = {}, {}
for char, list in ipairs(rvs_bs_list) do
	local rvs_list, bs_list = {}, {}
	for i, rvs in pairs(common_rvs) do table.insert(list, i, rvs) end
	for _, rvs in pairs(list) do
		if rvs.cmd and type(rvs.cmd) ~= "table" then -- 左右それぞれの向きのコマンドに変換分割する
			local cmd, rev = rvs.cmd, rvs.cmd
			if (rev & cmd_types._6) == cmd_types._6 then
				rev = (rev - cmd_types._6) | cmd_types._4
			end
			rvs.cmd = { [-1] = rev, [1] = cmd }
		end
		rvs = calc_ver(rvs)
		local type = rvs.hook_type
		if ut.tstb(type, hook_cmd_types.breakshot) then table.insert(bs_list, rvs) end
		if ut.tstb(type, hook_cmd_types.reversal) then table.insert(rvs_list, rvs) end
		if ut.tstb(type, hook_cmd_types.otg_stomp) then chars[char].otg_stomp = rvs end
		if ut.tstb(type, hook_cmd_types.otg_throw) then chars[char].otg_throw = rvs end
		if ut.tstb(type, hook_cmd_types.add_throw) then chars[char].add_throw = rvs end
		if ut.tstb(type, hook_cmd_types.wakeup) then chars[char].wakeup = rvs end
	end
	table.insert(char_rvs_list, rvs_list)
	table.insert(char_bs_list, bs_list)
	chars[char].rvs, chars[char].bs = rvs_list, bs_list
end
local sp_throws     = { -- 投げ技IDごとのテーブル
	[0x05] = calc_ver({ char = 0x05, id = 0x07, f = 0x06, a = 0xFD, auto_sp_throw = true, name = "真空投げ", }),
	[0x06] = calc_ver({ char = 0x05, id = 0x12, f = 0x06, a = 0x00, auto_sp_throw = true, name = "羅生門", }),
	[0x07] = calc_ver({ char = 0x06, id = 0x04, f = 0x06, a = 0xFE, auto_sp_throw = true, name = "鬼門陣", }),
	[0x10] = calc_ver({ char = 0x0B, id = 0x08, f = 0x06, a = 0x00, auto_sp_throw = true, name = "爆弾パチキ", }),
	[0x11] = calc_ver({ char = 0x0B, id = 0x12, f = 0x06, a = 0x00, auto_sp_throw = true, name = "ドリル", }),
	[0x13] = calc_ver({ char = 0x0E, id = 0x10, f = 0x06, a = 0x00, auto_sp_throw = true, name = "ブレイクスパイラル", }),
	[0x14] = calc_ver({ char = 0x0E, id = 0x11, f = 0x06, a = 0xFA, auto_sp_throw = true, name = "ブレイクスパイラルBR", }),
	[0x15] = calc_ver({ char = 0x14, id = 0x05, f = 0x06, a = 0x00, auto_sp_throw = true, name = "デンジャラススルー", }),
	[0x16] = calc_ver({ char = 0x14, id = 0x07, f = 0x06, a = 0x00, auto_sp_throw = true, name = "リフトアップブロー", }),
	[0x17] = calc_ver({ char = 0x14, id = 0x12, f = 0x06, a = 0x00, auto_sp_throw = true, name = "ギガティックサイクロン", }),
}

db.cmd_bytes        = cmd_bytes
db.cmd_status_b     = cmd_status_b
db.hook_cmd_types   = hook_cmd_types
db.rvs_types        = rvs_types
db.cmd_rev_masks    = cmd_rev_masks
db.cmd_masks        = cmd_masks
db.cmd_types        = cmd_types
db.char_rvs_list    = char_rvs_list
db.char_bs_list     = char_bs_list
db.rvs_bs_list      = rvs_bs_list
db.sp_throws        = sp_throws

--------------------------------------------------------------------------------------
-- 状態フラグ
--------------------------------------------------------------------------------------

db.esaka_type_names = {
	[0x2000] = "Low",
	[0x4000] = "High",
	[0x8000] = "Upper",
}
local flag_c0       = {
	_00 = 2 ^ 0, -- ジャンプ振向
	_01 = 2 ^ 1, -- ダウン
	_02 = 2 ^ 2, -- 屈途中
	_03 = 2 ^ 3, -- 奥後退
	_04 = 2 ^ 4, -- 奥前進
	_05 = 2 ^ 5, -- 奥振向
	_06 = 2 ^ 6, -- 屈振向
	_07 = 2 ^ 7, -- 立振向
	_08 = 2 ^ 8, -- スウェーライン上飛び退き～戻り
	_09 = 2 ^ 9, -- スウェーライン上ダッシュ～戻り
	_10 = 2 ^ 10, -- スウェーライン→メイン
	_11 = 2 ^ 11, -- スウェーライン上立
	_12 = 2 ^ 12, -- メインライン→スウェーライン移動中
	_13 = 2 ^ 13, -- スウェーライン上維持
	_14 = 2 ^ 14, -- 17
	_15 = 2 ^ 15, -- 16
	_16 = 2 ^ 16, -- 着地
	_17 = 2 ^ 17, -- ジャンプ移行
	_18 = 2 ^ 18, -- 後方小ジャンプ
	_19 = 2 ^ 19, -- 前方小ジャンプ
	_20 = 2 ^ 20, -- 垂直小ジャンプ
	_21 = 2 ^ 21, -- 後方ジャンプ
	_22 = 2 ^ 22, -- 前方ジャンプ
	_23 = 2 ^ 23, -- 垂直ジャンプ
	_24 = 2 ^ 24, -- ダッシュ
	_25 = 2 ^ 25, -- 飛び退き
	_26 = 2 ^ 26, -- 屈前進
	_27 = 2 ^ 27, -- 立途中
	_28 = 2 ^ 28, -- 屈
	_29 = 2 ^ 29, -- 後退
	_30 = 2 ^ 30, -- 前進
	_31 = 2 ^ 31, -- 立
}
flag_c0.startups    =
	flag_c0._08 | -- スウェーライン上飛び退き～戻り
	flag_c0._09 | -- スウェーライン上ダッシュ～戻り
	flag_c0._10 | -- スウェーライン→メイン
	flag_c0._12 | -- メインライン→スウェーライン移動中
	flag_c0._17 | -- ジャンプ移行
	flag_c0._24 | -- ダッシュ
	flag_c0._25 -- 飛び退き
flag_c0.jump        =
	flag_c0._18 | -- 後方小ジャンプ
	flag_c0._19 | -- 前方小ジャンプ
	flag_c0._20 | -- 垂直小ジャンプ
	flag_c0._21 | -- 後方ジャンプ
	flag_c0._22 | -- 前方ジャンプ
	flag_c0._23 -- 垂直ジャンプ
local flag_c4       = {
	_00 = 2 ^ 0, -- 避け攻撃
	_01 = 2 ^ 1, -- 対スウェーライン下段攻撃
	_02 = 2 ^ 2, -- 対スウェーライン上段攻撃
	_03 = 2 ^ 3, -- 対メインライン威力大攻撃
	_04 = 2 ^ 4, -- 対メインラインB攻撃
	_05 = 2 ^ 5, -- 対メインラインA攻撃
	_06 = 2 ^ 6, -- 後方小ジャンプC
	_07 = 2 ^ 7, -- 後方小ジャンプB
	_08 = 2 ^ 8, -- 後方小ジャンプA
	_09 = 2 ^ 9, -- 前方小ジャンプC
	_10 = 2 ^ 10, -- 前方小ジャンプB
	_11 = 2 ^ 11, -- 前方小ジャンプA
	_12 = 2 ^ 12, -- 垂直小ジャンプC
	_13 = 2 ^ 13, -- 垂直小ジャンプB
	_14 = 2 ^ 14, -- 垂直小ジャンプA
	_15 = 2 ^ 15, -- 後方ジャンプC
	_16 = 2 ^ 16, -- 後方ジャンプB
	_17 = 2 ^ 17, -- 後方ジャンプA
	_18 = 2 ^ 18, -- 前方ジャンプC
	_19 = 2 ^ 19, -- 前方ジャンプB
	_20 = 2 ^ 20, -- 前方ジャンプA
	_21 = 2 ^ 21, -- 垂直ジャンプC
	_22 = 2 ^ 22, -- 垂直ジャンプB
	_23 = 2 ^ 23, -- 垂直ジャンプA
	_24 = 2 ^ 24, -- C4 24
	_25 = 2 ^ 25, -- C4 25
	_26 = 2 ^ 26, -- 屈C
	_27 = 2 ^ 27, -- 屈B
	_28 = 2 ^ 28, -- 屈A
	_29 = 2 ^ 29, -- 立C
	_30 = 2 ^ 30, -- 立B
	_31 = 2 ^ 31, -- 立A
}
local flag_c8       = {
	_00 = 2 ^ 0, --
	_01 = 2 ^ 1, --
	_02 = 2 ^ 2, --
	_03 = 2 ^ 3, --
	_04 = 2 ^ 4, --
	_05 = 2 ^ 5, --
	_06 = 2 ^ 6, --
	_07 = 2 ^ 7, --
	_08 = 2 ^ 8, -- 特殊技
	_09 = 2 ^ 9, --
	_10 = 2 ^ 10, --
	_11 = 2 ^ 11, -- 特殊技
	_12 = 2 ^ 12, -- 特殊技
	_13 = 2 ^ 13, -- 特殊技
	_14 = 2 ^ 14, -- 特殊技
	_15 = 2 ^ 15, -- 特殊技
	_16 = 2 ^ 16, -- 潜在能力
	_17 = 2 ^ 17, -- 潜在能力
	_18 = 2 ^ 18, -- 超必殺技
	_19 = 2 ^ 19, -- 超必殺技
	_20 = 2 ^ 20, -- 必殺技
	_21 = 2 ^ 21, -- 必殺技
	_22 = 2 ^ 22, -- 必殺技
	_23 = 2 ^ 23, -- 必殺技
	_24 = 2 ^ 24, -- 必殺技
	_25 = 2 ^ 25, -- 必殺技
	_26 = 2 ^ 26, -- 必殺技
	_27 = 2 ^ 27, -- 必殺技
	_28 = 2 ^ 28, -- 必殺技
	_29 = 2 ^ 29, -- 必殺技
	_30 = 2 ^ 30, -- 必殺技
	_31 = 2 ^ 31, -- 必殺技
}
local flag_cc       = {
	_00 = 2 ^ 0, -- CA
	_01 = 2 ^ 1, -- AかB攻撃
	_02 = 2 ^ 2, -- 滑り
	_03 = 2 ^ 3, -- 必殺投げやられ
	_04 = 2 ^ 4, --
	_05 = 2 ^ 5, -- 空中ガード
	_06 = 2 ^ 6, -- 屈ガード
	_07 = 2 ^ 7, -- 立ガード
	_08 = 2 ^ 8, -- 投げ派生やられ
	_09 = 2 ^ 9, -- つかみ投げやられ
	_10 = 2 ^ 10, -- 投げられ
	_11 = 2 ^ 11, --
	_12 = 2 ^ 12, -- ラインずらしやられ
	_13 = 2 ^ 13, -- ダウン
	_14 = 2 ^ 14, -- 空中やられ
	_15 = 2 ^ 15, -- 地上やられ
	_16 = 2 ^ 16, --
	_17 = 2 ^ 17, -- 気絶
	_18 = 2 ^ 18, -- 気絶起き上がり
	_19 = 2 ^ 19, -- 挑発
	_20 = 2 ^ 20, -- ブレイクショット
	_21 = 2 ^ 21, -- 必殺技中
	_22 = 2 ^ 22, --
	_23 = 2 ^ 23, -- 起き上がり
	_24 = 2 ^ 24, -- フェイント
	_25 = 2 ^ 25, -- つかみ技
	_26 = 2 ^ 26, --
	_27 = 2 ^ 27, -- 投げ追撃
	_28 = 2 ^ 28, --
	_29 = 2 ^ 29, --
	_30 = 2 ^ 30, -- 空中投げ
	_31 = 2 ^ 31, -- 投げ
}
-- 小ジャンプ
flag_c4.hop         = flag_c4._06 |
	flag_c4._07 |
	flag_c4._08 |
	flag_c4._09 |
	flag_c4._10 |
	flag_c4._11 |
	flag_c4._12 |
	flag_c4._13 |
	flag_c4._14
-- ジャンプ
flag_c4.jump        = flag_c4._15 |
	flag_c4._16 |
	flag_c4._17 |
	flag_c4._18 |
	flag_c4._19 |
	flag_c4._20 |
	flag_c4._21 |
	flag_c4._22 |
	flag_c4._23
flag_c4.overhead    = flag_c4.hop |
	flag_c4.jump |
	flag_c4._02 | -- 対スウェーライン上段攻撃
	flag_c4._05 -- 対メインラインA攻撃
local flag_d0       = {
	_00 = 0x1, --
	_01 = 0x2, --
	_02 = 0x4, --
	_03 = 0x8, -- ギガティック投げられ
	_04 = 0x10, --
	_05 = 0x20, -- 追撃投げ中
	_06 = 0x40, -- ガード中、やられ中
	_07 = 0x80, -- 攻撃ヒット
}
local flag_7e       = {
	_00 = 0x1, -- 制止中
	_01 = 0x2, --
	_02 = 0x4, -- 動作切替
	_03 = 0x8, --
	_04 = 0x10, -- ガードさせ中
	_05 = 0x20, -- ヒットさせ中
	_06 = 0x40, --
	_07 = 0x80 -- 近距離
}
flag_cc.hitstun     =
	flag_cc._03 | -- 必殺投げやられ
	flag_cc._08 | -- 投げ派生やられ
	flag_cc._09 | -- つかみ投げやられ
	flag_cc._10 | -- 投げられ
	flag_cc._12 | -- ラインずらしやられ
	flag_cc._13 | -- ダウン
	flag_cc._14 | -- 空中やられ
	flag_cc._15 | -- 地上やられ
	flag_cc._17 | -- 気絶
	flag_cc._18 | -- 気絶起き上がり
	flag_cc._23 -- 起き上がり
flag_cc.blocking    =
	flag_cc._05 | -- 空中ガード
	flag_cc._06 | -- 屈ガード
	flag_cc._07 -- 立ガード
flag_cc.attacking   =
	flag_cc._00 | -- CA
	flag_cc._01 | -- AかB攻撃
	flag_cc._20 | -- ブレイクショット
	flag_cc._21 | -- 必殺技中
	flag_cc._25 | -- つかみ技
	flag_cc._27 | -- 投げ追撃
	flag_cc._30 | -- 空中投げ
	flag_cc._31 -- 投げ
flag_cc.grabbing    =
	flag_cc._25 | -- つかみ技
	flag_cc._27 -- 投げ追撃
flag_cc.thrown      =
	flag_cc._03 | -- 必殺投げやられ
	flag_cc._08 | -- 投げ派生やられ
	flag_cc._09 | -- つかみ投げやられ
	flag_cc._10 -- 投げられ
flag_cc.hurt     =
	flag_cc._03 | -- 必殺投げやられ
	flag_cc._08 | -- 投げ派生やられ
	flag_cc._09 | -- つかみ投げやられ
	flag_cc._12 | -- ラインずらしやられ
	flag_cc._14 | -- 空中やられ
	flag_cc._15 -- 地上やられ
flag_d0.hurt        =
	flag_d0._03 | -- ギガティック投げられ
	flag_d0._06 | -- ガード中、やられ中
	flag_d0._07 -- 攻撃ヒット
db.flag_c0          = flag_c0
db.flag_c4          = flag_c4
db.flag_c8          = flag_c8
db.flag_cc          = flag_cc
db.flag_d0          = flag_d0
db.flag_7e          = flag_7e
db.flag_names_c0    = {
	"ジャンプ振向", -- 0
	"ダウン", -- 1
	"屈途中", -- 2
	"奥後退", -- 3
	"奥前進", -- 4
	"奥振向", -- 5
	"屈振向", -- 6
	"立振向", -- 7
	"スウェーライン上飛び退き～戻り", -- 8
	"スウェーライン上ダッシュ～戻り", -- 9
	"スウェーライン→メイン", -- 10
	"スウェーライン上立", -- 11
	"メインライン→スウェーライン移動中", -- 12
	"スウェーライン上維持", -- 13
	"17", -- 14
	"16", -- 15
	"着地", -- 16
	"ジャンプ移行", -- 17
	"後方小ジャンプ", -- 18
	"前方小ジャンプ", -- 19
	"垂直小ジャンプ", -- 20
	"後方ジャンプ", -- 21
	"前方ジャンプ", -- 22
	"垂直ジャンプ", -- 23
	"ダッシュ", -- 24
	"飛び退き", -- 25
	"屈前進", -- 26
	"立途中", -- 27
	"屈", -- 28
	"後退", -- 29
	"前進", -- 30
	"立", -- 31
}
db.flag_names_c4    = {
	"避け攻撃", -- 0
	"対スウェーライン下段攻撃", -- 1
	"対スウェーライン上段攻撃", -- 2
	"対メインライン威力大攻撃", -- 3
	"対メインラインB攻撃", -- 4
	"対メインラインA攻撃", -- 5
	"後方小ジャンプC", -- 6
	"後方小ジャンプB", -- 7
	"後方小ジャンプA", -- 8
	"前方小ジャンプC", -- 9
	"前方小ジャンプB", -- 10
	"前方小ジャンプA", -- 11
	"垂直小ジャンプC", -- 12
	"垂直小ジャンプB", -- 13
	"垂直小ジャンプA", -- 14
	"後方ジャンプC", -- 15
	"後方ジャンプB", -- 16
	"後方ジャンプA", -- 17
	"前方ジャンプC", -- 18
	"前方ジャンプB", -- 19
	"前方ジャンプA", -- 20
	"垂直ジャンプC", -- 21
	"垂直ジャンプB", -- 22
	"垂直ジャンプA", -- 23
	"C4 24", -- 24
	"C4 25", -- 25
	"屈C", -- 26
	"屈B", -- 27
	"屈A", -- 28
	"立C", -- 29
	"立B", -- 30
	"立A", -- 31
}
db.flag_names_c8    = {
	"", -- 0
	"", -- 1
	"", -- 2
	"", -- 3
	"", -- 4
	"", -- 5
	"", -- 6
	"", -- 7
	"特殊技", -- 8
	"", -- 9
	"", -- 10
	"特殊技", -- 11
	"特殊技", -- 12
	"特殊技", -- 13
	"特殊技", -- 14
	"特殊技", -- 15
	"潜在能力", -- 16
	"潜在能力", -- 17
	"超必殺技", -- 18
	"超必殺技", -- 19
	"必殺技", -- 20
	"必殺技", -- 21
	"必殺技", -- 22
	"必殺技", -- 23
	"必殺技", -- 24
	"必殺技", -- 25
	"必殺技", -- 26
	"必殺技", -- 27
	"必殺技", -- 28
	"必殺技", -- 29
	"必殺技", -- 30
	"必殺技", -- 31
}
db.flag_names_cc    = {
	"CA", -- 0
	"AかB攻撃", -- 1
	"滑り", -- 2
	"必殺投げやられ", -- 3
	"", -- 4
	"空中ガード", -- 5
	"屈ガード", -- 6
	"立ガード", -- 7
	"投げ派生やられ", -- 8
	"つかみ投げやられ", -- 9
	"投げられ", -- 10
	"", -- 11
	"ラインずらしやられ", -- 12
	"ダウン", -- 13
	"空中やられ", -- 14
	"地上やられ", -- 15
	"", -- 16
	"気絶", -- 17
	"気絶起き上がり", -- 18
	"挑発", -- 19
	"ブレイクショット", -- 20
	"必殺技中", -- 21
	"", -- 22
	"起き上がり", -- 23
	"フェイント", -- 24
	"つかみ技", -- 25
	"", -- 26
	"投げ追撃", -- 27
	"", -- 28
	"", -- 29
	"空中投げ", -- 30
	"投げ", -- 31
}
db.flag_names_d0    = {
	"", -- 0
	"", -- 1
	"", -- 2
	"ギガティック投げられ", -- 3
	"", -- 4
	"追撃投げ中", -- 5
	"ガード中、やられ中", -- 6
	"攻撃ヒット", -- 7
}
db.flag_names_7e    = {
	"制止中", -- 0
	"", -- 1
	"動作切替", -- 2
	"", -- 3
	"ガードさせ中", -- 4
	"ヒットさせ中", -- 5
	"", -- 6
	"近距離", -- 7
}
db.get_flag_name    = function(flags, flag_names)
	local flgtxt = ""
	if flags == nil or flags <= 0 then return flgtxt end
	for i, name in ipairs(flag_names) do
		if flags & 2 ^ (i - 1) ~= 0 then
			flgtxt = #flgtxt == 0 and name or string.format("%s|%s", flgtxt, name)
		end
	end
	return flgtxt
end


--------------------------------------------------------------------------------------
-- ヒット効果
--------------------------------------------------------------------------------------

local hit_effect_types  = {
	down = "ダ", -- ダウン
	extra = "特", -- 特殊なやられ
	extra_launch = "特浮", -- 特殊な空中追撃可能ダウン
	force_stun = "気", -- 強制気絶
	fukitobi = "吹", -- 吹き飛び
	hikikomi = "後", -- 後ろ向きのけぞり
	hikikomi_launch = "後浮", -- 後ろ向き浮き
	launch = "浮", -- 空中とダウン追撃可能ダウン
	launch2 = "浮", -- 浮のけぞり～ダウン
	launch_nokezori = "浮", -- 浮のけぞり
	nokezori = "の", -- のけぞり
	nokezori2 = "*の", -- のけぞり 対スウェー時はダウン追撃可能ダウン
	otg_down = "*ダ", -- ダウン追撃可能ダウン
	plane_shift = "ず", -- スウェーラインずらし
	plane_shift_down = "ずダ", -- スウェーラインずらしダウン
	standup = "立", -- 強制立のけぞり
}
local hit_effects       = {
	types     = hit_effect_types,
	en_types  = {
		[hit_effect_types.down] = "Down",                   -- ダウン
		[hit_effect_types.extra] = "Extra",                 -- 特殊なやられ
		[hit_effect_types.extra_launch] = "Ex.Launch",      -- 特殊な空中追撃可能ダウン
		[hit_effect_types.force_stun] = "Force Stun",       -- 強制気絶
		[hit_effect_types.fukitobi] = "Blow Off",           -- 吹き飛び特殊な
		[hit_effect_types.hikikomi] = "Revers",             -- 後ろ向きのけぞり
		[hit_effect_types.hikikomi_launch] = "Launch",      -- 後ろ向き浮き
		[hit_effect_types.launch] = "Launch",               -- 空中とダウン追撃可能ダウン
		[hit_effect_types.launch2] = "Ex.Launch",           -- 浮のけぞり～ダウン
		[hit_effect_types.launch_nokezori] = "Launch",      -- 浮のけぞり
		[hit_effect_types.nokezori] = "Knockback",          -- のけぞり
		[hit_effect_types.nokezori2] = "K.B./*Down",        -- のけぞり 対スウェー時はダウン追撃可能ダウン
		[hit_effect_types.otg_down] = "*Down",              -- ダウン追撃可能ダウン
		[hit_effect_types.plane_shift] = "Plane Shift",     -- スウェーラインずらし
		[hit_effect_types.plane_shift_down] = "Plane Shift Down", -- スウェーラインずらしダウン
		[hit_effect_types.standup] = "Standup",             -- 強制立のけぞり
	},
	nokezoris = ut.new_set(
		hit_effect_types.nokezori,
		hit_effect_types.nokezori2,
		hit_effect_types.standup,
		hit_effect_types.hikikomi,
		hit_effect_types.plane_shift),
	list      = {
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
		{ hit_effect_types.nokezori,         hit_effect_types.launch,           hit_effect_types.otg_down },
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
	},
}
hit_effects.get_name    = function(effect, nill_value)
	local e = effect and hit_effects.list[effect + 1] or nil --luaの配列は1からになるので+1する
	if e then
		return effect, hit_effects.en_types[e[1]] or nill_value, hit_effects.en_types[e[2]] or nill_value
	else
		return effect, nill_value, nill_value
	end
end
hit_effects.is_nokezori = function(effect)
	local e = effect and hit_effects.list[effect + 1] or nil --luaの配列は1からになるので+1する
	if e then
		return hit_effects.nokezoris[e[1]]
	else
		return false
	end
end
db.hit_effects          = hit_effects


--------------------------------------------------------------------------------------
-- コマンド入力状態
--------------------------------------------------------------------------------------

local input_state_types              = {
	step = 1,
	faint = 2,
	charge = 3,
	unknown = 4,
	followup = 5,
	shinsoku = 6,
	todome = 7,
	drill5 = 8,
}
local create_input_states            = function()
	local _1236b___ = "_1|_2|_3|_6|_+_B"
	local _1_6_a___ = "_1|_6|_+_A"
	local _1_6_b___ = "_1|_6|_+_B"
	local _1_6_c___ = "_1|_6|_+_C"
	local _1chg26bc = "_1|Hold|_2||_6|_+_B_+_C"
	local _1chg6_b_ = "_1|Hold|_6|_+_B"
	local _1chg6_c_ = "_1|Hold|_6|_+_C"
	local _21416bc_ = "_2|_1|_4|_1|_6|_+_B_+_C"
	local _21416c__ = "_2|_1|_4|_1|_6|_+_C"
	local _2146bc__ = "_2|_1|_4|_6|_+_B_+_C"
	local _2146c___ = "_2|_1|_4|_6|_+_C"
	local _214a____ = "_2|_1|_4|_+_A"
	local _214b____ = "_2|_1|_4|_+_B"
	local _214bc___ = "_2|_1|_4|_+_B_+_C"
	local _214c____ = "_2|_1|_4|_+_C"
	local _214d____ = "_2|_1|_4|_+_D"
	local _2_2_____ = "_N|_2|_N|_2"
	local _2_2_a___ = "_N|_2|_N|_2|_+_A"
	local _2_2_b___ = "_N|_2|_N|_2|_+_B"
	local _2_2_c___ = "_N|_2|_N|_2|_+_C"
	local _2_2_d___ = "_N|_2|_N|_2|_+_D"
	local _2369b___ = "_2|_3|_6|_9|_+_B"
	local _236a____ = "_2|_3|_6|_+_A"
	local _236b____ = "_2|_3|_6|_+_B"
	local _236bc___ = "_2|_3|_6|_+_B_+_C"
	local _236c____ = "_2|_3|_6|_+_C"
	local _236d____ = "_2|_3|_6|_+_D"
	local _2486a___ = "_2|_4|_8|_6|_+_A"
	local _2486bc__ = "_2|_4|_8|_6|_+_B_+_C"
	local _2486c___ = "_2|_4|_8|_6|_+_C"
	local _2684a___ = "_2|_6|_8|_4|_+_A"
	local _2684bc__ = "_2|_6|_8|_4|_+_B_+_C"
	local _2684c___ = "_2|_6|_8|_4|_+_C"
	local _2_a_____ = "_N|_2|_+_A"
	local _2_ab____ = "_N|_2|_+_A_+_B"
	local _2_ac____ = "_N|_2|_+_A_+_C"
	local _2_b_____ = "_N|_2|_+_B"
	local _2_bc____ = "_N|_2|_+_B_+_C"
	local _2_c_____ = "_N|_2|_+_C"
	local _2chg7_b_ = "_2|Hold|_7|_+_B"
	local _2chg8_a_ = "_2|Hold|_8|_+_A"
	local _2chg8_b_ = "_2|Hold|_8|_+_B"
	local _2chg8_c_ = "_2|Hold|_8|_+_C"
	local _2chg9_b_ = "_2|Hold|_9|_+_B"
	local _3_3_b___ = "_N|_3|_N|_3|_+_B"
	local _3_3_c___ = "_N|_3|_N|_3|_+_C"
	local _3_b_____ = "_N|_3|_+_B"
	local _3_5_c___ = "_3|_N|_+_C"
	local _412c____ = "_4|_1|_2|_+_C"
	local _41236a__ = "_4|_1|_2|_3|_6|_+_A"
	local _41236b__ = "_4|_1|_2|_3|_6|_+_B"
	local _41236bc_ = "_4|_1|_2|_3|_6|_+_B_+_C"
	local _41236c__ = "_4|_1|_2|_3|_6|_+_C"
	local _421ac___ = "_4|_2|_1|_+_A_+_C"
	local _4268a___ = "_4|_2|_6|_8|_+_A"
	local _4268bc__ = "_4|_2|_6|_8|_+_B_+_C"
	local _4268c___ = "_4|_2|_6|_8|_+_C"
	local _4_4_____ = "_N|_4|_N|_4"
	local _466bc___ = "_4|_6|_N|_6|_+_B_+_C"
	local _46b_____ = "_4|_6|_+_B"
	local _4_6_c___ = "_4|_6|_+_C"
	local _4862a___ = "_4|_8|_6|_2|_+_A"
	local _4862bc__ = "_4|_8|_6|_2|_+_B_+_C"
	local _4862c___ = "_4|_8|_6|_2|_+_C"
	local _4_ac____ = "_N|_4|_+_A_+_C"
	local _4chg6_a_ = "_4|Hold|_6|_+_A"
	local _4chg6_b_ = "_4|Hold|_6|_+_B"
	local _4chg6_bc = "_4|Hold|_6|_+_B_+_C"
	local _4chg6_c_ = "_4|Hold|_6|_+_C"
	local _616ab___ = "_6|_1|_6|_+_A_+_B"
	local _623a____ = "_6|_2|_3|_+_A"
	local _623ab___ = "_6|_2|_3|_+_A_+_B"
	local _623b____ = "_6|_2|_3|_+_B"
	local _623bc___ = "_6|_2|_3|_+_B_+_C"
	local _623c____ = "_6|_2|_3|_+_C"
	local _6248a___ = "_6|_2|_4|_8|_+_A"
	local _6248bc__ = "_6|_2|_4|_8|_+_B_+_C"
	local _6248c___ = "_6|_2|_4|_8|_+_C"
	local _632146a_ = "_6|_3|_2|_1|_4|_6|_+_A"
	local _63214a__ = "_6|_3|_2|_1|_4|_+_A"
	local _63214b__ = "_6|_3|_2|_1|_4|_+_B"
	local _63214bc_ = "_6|_3|_2|_1|_4|_+_B_+_C"
	local _63214c__ = "_6|_3|_2|_1|_4|_+_C"
	local _632c____ = "_6|_3|_2|_+_C"
	local _64123bc_ = "_6|_4|_1|_2|_3|_+_B_+_C"
	local _64123c__ = "_6|_4|_1|_2|_3|_+_C"
	local _64123d__ = "_6|_4|_1|_2|_3|_+_D"
	local _6428c___ = "_6|_4|_2|_8|_+_C"
	local _6_4_6_c_ = "_6|_4|_6|_+_C"
	local _6_4_c___ = "_6|_4|_+_C"
	local _6_6_____ = "_N|_6|_N|_6"
	local _6_6_6_a_ = "_N|_6|_N|_6|_N|_6|_+_A"
	local _6_6_a___ = "_N|_6|_N|_6|_+_A"
	local ca_6_6_a_ = "_6|_N|_6|_+_A"
	local _6_6_6_c_ = "_6|_N|_6|_N|_6|_+_C"
	local _6842a___ = "_6|_8|_4|_2|_+_A"
	local _6842bc__ = "_6|_8|_4|_2|_+_B_+_C"
	local _6842c___ = "_6|_8|_4|_2|_+_C"
	local _698b____ = "_6|_9|_8|_+_B"
	local _6_ac____ = "_N|_6|_+_A_+_C"
	local _8_2_d___ = "_8|_2|_+_D"
	local _8426a___ = "_8|_4|_2|_6|_+_A"
	local _8426bc__ = "_8|_4|_2|_6|_+_B_+_C"
	local _8426c___ = "_8|_4|_2|_6|_+_C"
	local _8624a___ = "_8|_6|_2|_4|_+_A"
	local _8624bc__ = "_8|_6|_2|_4|_+_B_+_C"
	local _8624c___ = "_8|_6|_2|_4|_+_C"
	local _8_c_____ = "_8|_N|_+_C"
	local _a_2_____ = "_A|_N|_2"
	local _a_6_____ = "_A|_N|_6"
	local _a_8_____ = "_A|_N|_8"
	local _a_a_____ = "_A|_A"
	local _a_a_a_a_ = "_A|_A|_A|_A"
	local _b_b_b___ = "_B|_B|_B"
	local _b_b_b_b_ = "_B|_B|_B|_B"
	local _b_x6____ = "_B|_B|_B|_B|_B|_B"
	local _b_x8____ = "_B|_B|_B|_B|_B|_B|_B|_B"
	local _c_c_____ = "_C|_C|_C|_C|_C"
	local _c_c_c___ = "_C|_C|_C"
	local _c_c_c_c_ = "_C|_C|_C|_C"
	local _4_6_a___ = "_4|_N|_6|_+_A"
	local _412d____ = "_4|_1|_2|_+_D"
	local _4_4_b___ = "_N|_4|_N|_4|_+_B"
	local _4_4_d___ = "_N|_4|_N|_4|_+_D"
	local _abc_____ = "_N|_A_+_B_+_C"
	local _6_b_____ = "_N|_6|_+_B"
	local _6_c_____ = "_N|_6|_+_C"
	local ____ = nil  -- 未定義を表すスペーサー
	local addr = nil  -- addrと同値とすることをあらわすためのスペーサー
	local _EZ_ = nil  -- 簡易必殺技にのみ含むことを表すスペーサー
	local ________ = nil -- 未定義を表すスペーサー
	local _____ = nil -- 未定義を表すスペーサー
	local __ = nil    -- 未定義を表すスペーサー
	local _A = "a"    -- 簡易必殺技 sdm Aボタン
	local _B = "b"    -- 簡易必殺技 sdm Bボタン
	local _C = "c"    -- 簡易必殺技 sdm Cボタン
	local _D = "d"    -- 簡易必殺技 sdm Dボタン
	local _X = "x"    -- 簡易必殺技に含まない
	local sdm_cmd = { ["a"] = _2_2_a___, ["b"] = _2_2_b___, ["c"] = _2_2_c___, ["d"] = _2_2_d___ }
	local sdm_estab = { ["a"] = 0x100000, ["b"] = 0x110000, ["c"] = 0x120000, ["d"] = 0x130000 }

	local no = function (no) return no * 4 + 2 end

	local input_states = {
		{ --テリー・ボガード
			{ spid = 0x01, addr = 0x02, estab = 0x010000, cmd = _214a____, sdm = __, name = "小バーンナックル", },
			{ spid = 0x02, addr = 0x06, estab = 0x020000, cmd = _214c____, sdm = __, name = "大バーンナックル", },
			{ spid = 0x03, addr = 0x0A, estab = 0x030000, cmd = _236a____, sdm = __, name = "パワーウェイブ", },
			{ spid = 0x04, addr = 0x0E, estab = 0x040000, cmd = _236c____, sdm = __, name = "ラウンドウェイブ", },
			{ spid = 0x05, addr = 0x12, estab = 0x050000, cmd = _214b____, sdm = __, name = "クラックシュート", },
			{ spid = 0x06, addr = 0x16, estab = 0x060000, cmd = _236b____, sdm = __, name = "ファイヤーキック", },
			{ spid = 0x07, addr = 0x1A, estab = 0x070000, cmd = _236d____, sdm = __, name = "パッシングスウェー", },
			{ spid = 0x08, addr = 0x1E, estab = 0x0800FF, cmd = _2chg8_a_, sdm = __, type = input_state_types.charge, name = "ライジングタックル", },
			{ spid = 0x10, addr = 0x22, estab = 0x100000, cmd = _21416bc_, sdm = _A, name = "パワーゲイザー", },
			{ spid = 0x12, addr = 0x26, estab = 0x120000, cmd = _21416c__, sdm = _C, name = "トリプルゲイザー", },
			{ spid = 0x1E, addr = 0x2A, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x2E, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x32, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = ____, addr = 0x36, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x3A, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x46, addr = 0x3E, estab = 0x460000, cmd = _6_ac____, sdm = __, name = "フェイント バーンナックル", },
			{ spid = 0x47, addr = 0x42, estab = 0x470000, cmd = _2_bc____, sdm = __, name = "フェイント パワーゲイザー", },
		},
		{ --アンディ・ボガード
			{ spid = 0x01, addr = 0x02, estab = 0x0100FF, cmd = _1_6_a___, sdm = __, name = "小残影拳", },
			{ spid = 0x02, addr = 0x06, estab = 0x02FFFF, cmd = _1_6_c___, sdm = __, name = "大残影拳 or 疾風裏拳", },
			{ spid = 0x03, addr = 0x0A, estab = 0x030000, cmd = _214a____, sdm = __, name = "飛翔拳", },
			{ spid = 0x04, addr = 0x0E, estab = 0x040000, cmd = _214c____, sdm = __, name = "激飛翔拳", },
			{ spid = 0x05, addr = 0x12, estab = 0x050000, cmd = _623c____, sdm = __, name = "昇龍弾", },
			{ spid = 0x06, addr = 0x16, estab = 0x0600FF, cmd = _1236b___, sdm = __, name = "空破弾", },
			{ spid = 0x07, addr = 0x1A, estab = 0x070000, cmd = _214d____, sdm = __, name = "幻影不知火", },
			{ spid = 0x10, addr = 0x1E, estab = 0x100000, cmd = _21416bc_, sdm = _A, name = "超裂破弾", },
			{ spid = 0x12, addr = 0x22, estab = 0x120000, cmd = _21416c__, sdm = _C, name = "男打弾", },
			{ spid = 0x1E, addr = 0x26, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x2A, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x2E, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = ____, addr = 0x32, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x36, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x46, addr = 0x3A, estab = 0x460000, cmd = _6_ac____, sdm = __, name = "フェイント 斬影拳", },
			{ spid = 0x47, addr = 0x3E, estab = 0x470000, cmd = _2_ac____, sdm = __, name = "フェイント 飛翔拳", },
			{ spid = 0x48, addr = 0x42, estab = 0x480000, cmd = _2_bc____, sdm = __, name = "フェイント 超裂破弾", },
		},
		{ --東丈
			{ spid = ____, addr = 0x02, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = 0x01, addr = 0x06, estab = 0x0100FF, cmd = _1_6_b___, sdm = __, name = "小スラッシュキック", },
			{ spid = 0x02, addr = 0x0A, estab = 0x0200FF, cmd = _1_6_c___, sdm = __, name = "大スラッシュキック", },
			{ spid = 0x03, addr = 0x0E, estab = 0x030000, cmd = _214b____, sdm = __, name = "黄金のカカト", },
			{ spid = 0x04, addr = 0x12, estab = 0x040000, cmd = _623b____, sdm = __, name = "タイガーキック", },
			{ spid = 0x05, addr = 0x16, estab = 0x050000, cmd = _a_a_a_a_, sdm = __, name = "爆裂拳", },
			{ spid = ____, addr = 0x1A, estab = 0x00FF00, cmd = _236a____, sdm = __, name = "爆裂フック", },
			{ spid = ____, addr = 0x1E, estab = 0x00FE00, cmd = _236c____, sdm = __, name = "爆裂アッパー", },
			{ spid = 0x06, addr = 0x22, estab = 0x060000, cmd = _41236a__, sdm = __, name = "ハリケーンアッパー", },
			{ spid = 0x07, addr = 0x26, estab = 0x070000, cmd = _41236c__, sdm = __, name = "爆裂ハリケーン", },
			{ spid = 0x10, addr = 0x2A, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "スクリューアッパー", },
			{ spid = 0x12, addr = 0x2E, estab = 0x120000, cmd = _64123c__, sdm = _C, name = "サンダーファイヤーC", },
			{ spid = 0x13, addr = 0x32, estab = 0x130000, cmd = _64123d__, sdm = _D, name = "サンダーファイヤーD", },
			{ spid = 0x1E, addr = 0x36, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x3A, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x3E, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = 0x21, addr = 0x42, estab = 0x210000, cmd = _2_c_____, sdm = __, name = "炎の指先", },
			{ spid = 0x28, addr = 0x46, estab = 0x280000, cmd = _236c____, sdm = __, name = "CA _2_3_6_+_C", },
			{ spid = ____, addr = 0x4A, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x46, addr = 0x4E, estab = 0x460000, cmd = _2_ac____, sdm = __, name = "フェイント ハリケーンアッパー", },
			{ spid = 0x47, addr = 0x52, estab = 0x470000, cmd = _6_ac____, sdm = __, name = "フェイント スラッシュキック", },
		},
		{ --不知火舞
			{ spid = 0x01, addr = 0x02, estab = 0x010000, cmd = _236a____, sdm = __, name = "花蝶扇", },
			{ spid = 0x02, addr = 0x06, estab = 0x020000, cmd = _214a____, sdm = __, name = "龍炎舞", },
			{ spid = 0x03, addr = 0x0A, estab = 0x030000, cmd = _214c____, sdm = __, name = "小夜千鳥", },
			{ spid = 0x04, addr = 0x0E, estab = 0x040000, cmd = _41236c__, sdm = __, name = "必殺忍蜂", },
			{ spid = 0x05, addr = 0x12, estab = 0x0500FF, cmd = _2_ab____, sdm = __, name = "ムササビの舞", },
			{ spid = 0x10, addr = 0x16, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "超必殺忍蜂", },
			{ spid = 0x12, addr = 0x1A, estab = 0x120000, cmd = _64123c__, sdm = _C, name = "花嵐", },
			{ spid = 0x1E, addr = 0x1E, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x22, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x26, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = 0x23, addr = 0x2A, estab = 0x230000, cmd = _c_c_c___, sdm = __, name = "跳ね蹴り", },
			{ spid = ____, addr = 0x2E, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x32, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x46, addr = 0x36, estab = 0x460000, cmd = _2_ac____, sdm = __, name = "フェイント 花蝶扇", },
			{ spid = 0x47, addr = 0x3A, estab = 0x470000, cmd = _2_bc____, sdm = __, name = "フェイント 花嵐", },
		},
		{ --ギース・ハワード
			{ spid = 0x21, addr = 0x02, easy_addr = addr, estab = 0x210000, cmd = _2_c_____, sdm = __, name = "雷鳴豪破投げ", },
			{ spid = 0x01, addr = 0x06, easy_addr = addr, estab = 0x010000, cmd = _214a____, sdm = __, name = "烈風拳", },
			{ spid = 0x02, addr = 0x0A, easy_addr = addr, estab = 0x02FF00, cmd = _214c____, sdm = __, name = "ダブル烈風拳", },
			{ spid = 0x03, addr = 0x0E, easy_addr = addr, estab = 0x030000, cmd = _41236b__, sdm = __, name = "上段当身投げ", },
			{ spid = 0x04, addr = 0x12, easy_addr = addr, estab = 0x04FE00, cmd = _41236c__, sdm = __, name = "裏雲隠し", },
			{ spid = 0x05, addr = 0x16, easy_addr = addr, estab = 0x050000, cmd = _41236a__, sdm = __, name = "下段当身打ち", },
			{ spid = 0x10, addr = 0x1A, easy_addr = addr, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "レイジングストーム", },
			{ spid = 0x12, addr = _EZ_, easy_addr = 0x1E, estab = ________, cmd = _2_2_c___, sdm = _C, name = "羅生門", },
			{ spid = 0x13, addr = 0x1E, easy_addr = 0x22, estab = 0x07FDFF, cmd = _632146a_, sdm = _D, name = "デッドリーレイブ", },
			{ spid = 0x07, addr = 0x22, easy_addr = 0x26, estab = 0x07FDFF, cmd = _8624a___, sdm = __, name = "真空投げ_8_6_2_4 or CA 真空投げ", },
			{ spid = 0x07, addr = 0x26, easy_addr = 0x2A, estab = 0x07FDFF, cmd = _6248a___, sdm = __, name = "真空投げ_6_2_4_8 or CA 真空投げ", },
			{ spid = 0x07, addr = 0x2A, easy_addr = 0x2E, estab = 0x07FDFF, cmd = _2486a___, sdm = __, name = "真空投げ_2_4_8_6 or CA 真空投げ", },
			{ spid = 0x07, addr = 0x2E, easy_addr = 0x32, estab = 0x07FDFF, cmd = _4862a___, sdm = __, name = "真空投げ_4_8_6_2 or CA 真空投げ", },
			{ spid = 0x07, addr = 0x32, easy_addr = 0x36, estab = 0x07FDFF, cmd = _8426a___, sdm = __, name = "真空投げ_8_4_2_6 or CA 真空投げ", },
			{ spid = 0x07, addr = 0x36, easy_addr = 0x3A, estab = 0x07FDFF, cmd = _4268a___, sdm = __, name = "真空投げ_4_2_6_8 or CA 真空投げ", },
			{ spid = 0x07, addr = 0x3A, easy_addr = 0x3E, estab = 0x07FDFF, cmd = _2684a___, sdm = __, name = "真空投げ_2_6_8_4 or CA 真空投げ", },
			{ spid = 0x07, addr = 0x3E, easy_addr = 0x42, estab = 0x07FDFF, cmd = _6842a___, sdm = __, name = "真空投げ_6_8_4_2 or CA 真空投げ", },
			{ spid = 0x12, addr = 0x42, easy_addr = ____, estab = 0x120000, cmd = _8624c___, sdm = _X, name = "羅生門_8_6_2_4", },
			{ spid = 0x12, addr = 0x46, easy_addr = ____, estab = 0x120000, cmd = _6248c___, sdm = _X, name = "羅生門_6_2_4_8", },
			{ spid = 0x12, addr = 0x4A, easy_addr = ____, estab = 0x120000, cmd = _2486c___, sdm = _X, name = "羅生門_2_4_8_6", },
			{ spid = 0x12, addr = 0x4E, easy_addr = ____, estab = 0x120000, cmd = _4862c___, sdm = _X, name = "羅生門_4_8_6_2", },
			{ spid = 0x12, addr = 0x52, easy_addr = ____, estab = 0x120000, cmd = _8426c___, sdm = _X, name = "羅生門_8_4_2_6", },
			{ spid = 0x12, addr = 0x56, easy_addr = ____, estab = 0x120000, cmd = _4268c___, sdm = _X, name = "羅生門_4_2_6_8", },
			{ spid = 0x12, addr = 0x5A, easy_addr = ____, estab = 0x120000, cmd = _2684c___, sdm = _X, name = "羅生門_2_6_8_4", },
			{ spid = 0x12, addr = 0x5E, easy_addr = ____, estab = 0x120000, cmd = _6842c___, sdm = _X, name = "羅生門_6_8_4_2", },
			{ spid = 0x1E, addr = 0x62, easy_addr = 0x46, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x66, easy_addr = 0x4A, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x6A, easy_addr = 0x4E, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = ____, addr = 0x6E, easy_addr = 0x52, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x72, easy_addr = 0x56, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x50, addr = 0x76, easy_addr = 0x5A, estab = 0x500000, cmd = _632c____, sdm = __, name = "絶命人中打ち", },
			{ spid = 0x51, addr = 0x7A, easy_addr = 0x5E, estab = 0x510000, cmd = _412c____, sdm = __, name = "絶命人中打ち", },
			{ spid = 0x46, addr = 0x7E, easy_addr = 0x62, estab = 0x460000, cmd = _2_ac____, sdm = __, name = "フェイント 烈風拳", },
			{ spid = 0x47, addr = 0x82, easy_addr = 0x66, estab = 0x470000, cmd = _2_bc____, sdm = __, name = "フェイント レイジングストーム", },
		},
		{ --望月双角
			{ spid = 0x01, addr = 0x02, estab = 0x010000, cmd = _214a____, sdm = __, name = "野猿狩り", },
			{ spid = 0x02, addr = 0x06, estab = 0x020000, cmd = _236a____, sdm = __, name = "まきびし", },
			{ spid = 0x03, addr = 0x0A, estab = 0x030000, cmd = _6_4_6_c_, sdm = __, name = "憑依弾", },
			{ spid = 0x05, addr = 0x0E, estab = 0x050CFF, cmd = _a_a_a_a_, sdm = __, name = "邪棍舞", },
			{ spid = 0x06, addr = 0x12, estab = 0x060000, cmd = _63214b__, sdm = __, name = "喝", },
			{ spid = 0x07, addr = 0x16, estab = 0x070000, cmd = _8_2_d___, sdm = __, name = "禍炎陣", },
			{ spid = 0x10, addr = 0x1A, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "いかづち", },
			{ spid = 0x12, addr = 0x1E, estab = 0x120000, cmd = _64123c__, sdm = _C, name = "無残弾", },
			{ spid = 0x04, addr = 0x22, estab = 0x0406FE, cmd = _8624c___, sdm = __, name = "鬼門陣_8_6_2_4 or 喝CAの投げ", },
			{ spid = 0x04, addr = 0x26, estab = 0x0406FE, cmd = _6248c___, sdm = __, name = "鬼門陣_6_2_4_8 or 喝CAの投げ", },
			{ spid = 0x04, addr = 0x2A, estab = 0x0406FE, cmd = _2486c___, sdm = __, name = "鬼門陣_2_4_8_6 or 喝CAの投げ", },
			{ spid = 0x04, addr = 0x2E, estab = 0x0406FE, cmd = _4862c___, sdm = __, name = "鬼門陣_4_8_6_2 or 喝CAの投げ", },
			{ spid = 0x04, addr = 0x32, estab = 0x0406FE, cmd = _8426c___, sdm = __, name = "鬼門陣_8_4_2_6 or 喝CAの投げ", },
			{ spid = 0x04, addr = 0x36, estab = 0x0406FE, cmd = _4268c___, sdm = __, name = "鬼門陣_4_2_6_8 or 喝CAの投げ", },
			{ spid = 0x04, addr = 0x3A, estab = 0x0406FE, cmd = _2684c___, sdm = __, name = "鬼門陣_2_6_8_4 or 喝CAの投げ", },
			{ spid = 0x04, addr = 0x3E, estab = 0x0406FE, cmd = _6842c___, sdm = __, name = "鬼門陣_6_8_4_2 or 喝CAの投げ", },
			{ spid = 0x1E, addr = 0x42, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x46, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "バックダッシュ", },
			{ spid = 0x20, addr = 0x4A, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = 0x21, addr = 0x4E, estab = 0x210000, cmd = _2_c_____, sdm = __, name = "雷撃棍", },
			{ spid = ____, addr = 0x52, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x56, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x50, addr = 0x5A, estab = 0x500000, cmd = _632c____, sdm = __, name = "地獄門", },
			{ spid = 0x51, addr = 0x5E, estab = 0x510000, cmd = _412c____, sdm = __, name = "地獄門", },
			{ spid = 0x28, addr = 0x62, estab = 0x280000, cmd = _623a____, sdm = __, name = "CA _6_2_3_+_A", },
			{ spid = 0x29, addr = 0x66, estab = 0x290000, cmd = _2_2_c___, sdm = __, name = "CA _2_2_+_C", },
			{ spid = 0x46, addr = 0x6A, estab = 0x460000, cmd = _2_ac____, sdm = __, name = "フェイント まきびし", },
			{ spid = 0x47, addr = 0x6E, estab = 0x470000, cmd = _2_bc____, sdm = __, name = "フェイント いかづち", },
		},
		{ --ボブ・ウィルソン
			{ spid = 0x01, addr = 0x02, estab = 0x010000, cmd = _214b____, sdm = __, name = "ローリングタートル", },
			{ spid = 0x02, addr = 0x06, estab = 0x020000, cmd = _214c____, sdm = __, name = "サイドワインダー", },
			{ spid = 0x03, addr = 0x0A, estab = 0x030000, cmd = _2chg8_c_, sdm = __, type = input_state_types.charge, name = "バイソンホーン", },
			{ spid = 0x04, addr = 0x0E, estab = 0x040602, cmd = _4chg6_b_, sdm = __, type = input_state_types.charge, name = "ワイルドウルフ", },
			{ spid = 0x05, addr = 0x12, estab = 0x050000, cmd = _623b____, sdm = __, name = "モンキーダンス", },
			{ spid = 0x06, addr = 0x16, estab = 0x0606FE, cmd = _466bc___, sdm = __, name = "フロッグハンティング", },
			{ spid = 0x10, addr = 0x1A, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "デンジャラスウルフ", },
			{ spid = 0x12, addr = 0x1E, estab = 0x120000, cmd = _64123c__, sdm = _C, name = "ダンシングバイソン", },
			{ spid = 0x1E, addr = 0x22, estab = 0x1EFFFF, cmd = _3_3_c___, sdm = __, name = "ホーネットアタック", },
			{ spid = 0x1E, addr = 0x26, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x2A, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x2E, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = 0x23, addr = 0x32, estab = 0x237800, cmd = _c_c_c___, sdm = __, name = "フライングフィッシュ", },
			{ spid = 0x21, addr = 0x36, estab = 0x210000, cmd = _8_c_____, sdm = __, name = "リンクスファング", },
			{ spid = ____, addr = 0x3A, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x3E, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x06, addr = 0x42, estab = 0x0600FF, cmd = _2_bc____, sdm = __, name = "フェイント ダンシングバイソン", },
		},
		{ --ホンフゥ
			{ spid = 0x01, addr = 0x02, estab = 0x010000, cmd = _41236c__, sdm = __, name = "九龍の読み/黒龍", },
			{ spid = 0x02, addr = 0x06, estab = 0x020000, cmd = _623a____, sdm = __, name = "小制空烈火棍", },
			{ spid = 0x03, addr = 0x0A, estab = 0x030000, cmd = _623c____, sdm = __, name = "大制空烈火棍", },
			{ spid = 0x04, addr = 0x0E, estab = 0x040000, cmd = _1chg6_b_, sdm = __, type = input_state_types.charge, name = "電光石火の地", },
			{ spid = ____, addr = 0x12, estab = 0x000CFE, cmd = _b_b_b___, sdm = __, name = "電光パチキ", },
			{ spid = 0x05, addr = 0x16, estab = 0x050000, cmd = _214b____, sdm = __, name = "電光石火の天", },
			{ spid = 0x06, addr = 0x1A, estab = 0x060000, cmd = _214a____, sdm = __, name = "炎の種馬", },
			{ spid = ____, addr = 0x1E, estab = 0x000CFF, cmd = _a_a_a_a_, sdm = __, name = "炎の種馬 連打", },
			{ spid = 0x07, addr = 0x22, estab = 0x070000, cmd = _214c____, sdm = __, name = "必勝！逆襲拳", },
			{ spid = 0x10, addr = 0x26, estab = 0x100000, cmd = _21416bc_, sdm = _A, name = "爆発ゴロー", },
			{ spid = 0x12, addr = 0x2A, estab = 0x120000, cmd = _21416c__, sdm = _C, name = "よかトンハンマー", },
			{ spid = 0x1E, addr = 0x2E, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x32, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x36, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = 0x06, addr = 0x3A, estab = 0x0600FF, cmd = _2_c_____, name = "トドメヌンチャク", },
			{ spid = ____, addr = 0x3E, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x42, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x46, addr = 0x46, estab = 0x460000, cmd = _4_ac____, sdm = __, name = "フェイント 制空烈火棍", },
		},
		{ --ブルー・マリー
			{ spid = 0x21, addr = 0x02, estab = 0x210000, cmd = _2_c_____, sdm = __, name = "M.ダイナマイトスイング", },
			{ spid = 0x01, addr = 0x06, estab = 0x0106FF, cmd = _236c____, sdm = __, name = "M.ｽﾊﾟｲﾀﾞｰ or ｽﾋﾟﾝﾌｫｰﾙ or ﾀﾞﾌﾞﾙｽﾊﾟｲﾀﾞｰ", },
			{ spid = 0x02, addr = 0x0A, estab = 0x0206FE, cmd = _623b____, sdm = __, name = "M.スナッチャー or ダブルスナッチャー", },
			{ spid = ____, addr = 0x0E, estab = 0x0006FD, cmd = _46b_____, sdm = __, name = "ダブルクラッチ", },
			{ spid = 0x03, addr = 0x12, estab = 0x0306FD, cmd = _4chg6_b_, sdm = __, type = input_state_types.charge, name = "M.クラブクラッチ", },
			{ spid = 0x04, addr = 0x16, estab = 0x040000, cmd = _214a____, sdm = __, name = "M.リアルカウンター", },
			{ spid = 0x06, addr = 0x1A, estab = 0x060000, cmd = _623a____, sdm = __, name = "バーチカルアロー", },
			{ spid = 0x07, addr = 0x1E, estab = 0x070000, cmd = _4chg6_a_, sdm = __, type = input_state_types.charge, name = "ストレートスライサー", },
			{ spid = 0x09, addr = 0x22, estab = 0x090000, cmd = _2chg8_c_, sdm = __, type = input_state_types.charge, name = "ヤングダイブ", },
			{ spid = 0x10, addr = 0x26, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "M.タイフーン", },
			{ spid = 0x12, addr = 0x2A, estab = 0x120000, cmd = _64123c__, sdm = _C, name = "M.エスカレーション", },
			{ spid = 0x28, addr = 0x2E, estab = 0x280000, cmd = _3_3_c___, sdm = __, name = "CA ジャーマンスープレックス", },
			{ spid = 0x50, addr = 0x32, estab = 0x500000, cmd = _632c____, sdm = __, name = "アキレスホールド", },
			{ spid = 0x51, addr = 0x36, estab = 0x510000, cmd = _412c____, sdm = __, name = "アキレスホールド", },
			{ spid = 0x1E, addr = 0x3A, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x3E, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x42, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = 0x24, addr = 0x46, estab = 0x240000, cmd = _2_b_____, sdm = __, name = "レッグプレス", },
			{ spid = ____, addr = 0x4A, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x4E, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x46, addr = 0x52, estab = 0x460000, cmd = _4_ac____, sdm = __, name = "フェイント M.スナッチャー", },
		},
		{ --フランコ・バッシュ
			{ spid = ____, addr = 0x02, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = 0x01, addr = 0x06, estab = 0x010000, cmd = _214a____, sdm = __, name = "ダブルコング", },
			{ spid = 0x02, addr = 0x0A, estab = 0x020000, cmd = _236a____, sdm = __, name = "ザッパー", },
			{ spid = 0x03, addr = 0x0E, estab = 0x030000, cmd = _236d____, sdm = __, name = "ウエービングブロー", },
			{ spid = 0x06, addr = 0x12, estab = 0x0600FF, cmd = _2369b___, sdm = __, name = "ガッツダンク", },
			{ spid = 0x06, addr = 0x16, estab = 0x0600FF, cmd = _1chg6_c_, sdm = __, type = input_state_types.charge, name = "ゴールデンボンバー", },
			{ spid = 0x10, addr = 0x1A, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "ファイナルオメガショット", },
			{ spid = 0x11, addr = 0x1E, estab = 0x110000, cmd = _63214bc_, sdm = _B, name = "メガトンスクリュー", },
			{ spid = 0x12, addr = 0x22, estab = 0x120000, cmd = _64123c__, sdm = _C, name = "ハルマゲドンバスター", },
			{ spid = 0x1E, addr = 0x26, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x2A, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x2E, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = 0x78, addr = 0x32, estab = 0x7800FF, cmd = _c_c_c___, sdm = __, name = "スマッシュ", },
			{ spid = ____, addr = 0x36, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x06, addr = 0x3A, estab = 0x0600FF, cmd = _2_bc____, sdm = __, name = "フェイント ハルマゲドンバスター", },
			{ spid = 0x06, addr = 0x3E, estab = 0x0600FF, cmd = _6_ac____, sdm = __, name = "フェイント ガッツダンク", },
		},
		{ --山崎竜二
			{ spid = ____, addr = 0x02, easy_addr = addr, estab = 0x0006FE, cmd = _abc_____, sdm = __, name = "_A_B_C", },
			{ spid = ____, addr = 0x06, easy_addr = addr, estab = 0x0006FF, cmd = _2_2_____, sdm = __, name = "_2_2", },
			{ spid = 0x01, addr = 0x0A, easy_addr = addr, estab = 0x010000, cmd = _214a____, sdm = __, name = "蛇使い・上段 ", },
			{ spid = 0x02, addr = 0x0E, easy_addr = addr, estab = 0x020000, cmd = _214b____, sdm = __, name = "蛇使い・中段", },
			{ spid = 0x03, addr = 0x12, easy_addr = addr, estab = 0x030000, cmd = _214c____, sdm = __, name = "蛇使い・下段", },
			{ spid = 0x04, addr = 0x16, easy_addr = addr, estab = 0x040000, cmd = _41236b__, sdm = __, name = "サドマゾ", },
			{ spid = 0x05, addr = 0x1A, easy_addr = addr, estab = 0x050000, cmd = _623b____, sdm = __, name = "ヤキ入れ", },
			{ spid = 0x06, addr = 0x1E, easy_addr = addr, estab = 0x060000, cmd = _236c____, sdm = __, name = "倍返し", },
			{ spid = 0x07, addr = 0x22, easy_addr = addr, estab = 0x070000, cmd = _623a____, sdm = __, name = "裁きの匕首", },
			{ spid = 0x08, addr = 0x26, easy_addr = addr, estab = 0x080000, cmd = _6428c___, sdm = __, name = "爆弾パチキ", },
			{ spid = 0x09, addr = 0x2A, easy_addr = addr, estab = 0x090C00, cmd = _2_2_c___, sdm = __, name = "トドメ", },
			{ spid = 0x10, addr = 0x2E, easy_addr = addr, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "ギロチン", },
			{ spid = 0x12, addr = 0x32, easy_addr = ____, estab = 0x120000, cmd = _8624c___, sdm = _X, name = "ドリル_8_6_2_4", },
			{ spid = 0x12, addr = 0x36, easy_addr = ____, estab = 0x120000, cmd = _6248c___, sdm = _X, name = "ドリル_6_2_4_8", },
			{ spid = 0x12, addr = 0x3A, easy_addr = ____, estab = 0x120000, cmd = _2486c___, sdm = _X, name = "ドリル_2_4_8_6", },
			{ spid = 0x12, addr = 0x3E, easy_addr = ____, estab = 0x120000, cmd = _4862c___, sdm = _X, name = "ドリル_4_8_6_2", },
			{ spid = 0x12, addr = 0x42, easy_addr = ____, estab = 0x120000, cmd = _8426c___, sdm = _X, name = "ドリル_8_4_2_6", },
			{ spid = 0x12, addr = 0x46, easy_addr = ____, estab = 0x120000, cmd = _4268c___, sdm = _X, name = "ドリル_4_2_6_8", },
			{ spid = 0x12, addr = 0x4A, easy_addr = ____, estab = 0x120000, cmd = _2684c___, sdm = _X, name = "ドリル_2_6_8_4", },
			{ spid = 0x12, addr = 0x4E, easy_addr = ____, estab = 0x120000, cmd = _6842c___, sdm = _X, name = "ドリル_6_8_4_2", },
			{ spid = 0x12, addr = _EZ_, easy_addr = 0x32, estab = 0x120000, cmd = _2_2_c___, sdm = _C, name = "ドリル", },
			{ spid = 0x1E, addr = 0x52, easy_addr = 0x36, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x56, easy_addr = 0x3A, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x5A, easy_addr = 0x3E, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = 0x78, addr = 0x5E, easy_addr = 0x42, estab = 0x7800FF, cmd = _c_c_c___, sdm = __, name = "砂かけ", },
			{ spid = ____, addr = 0x62, easy_addr = 0x46, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x66, easy_addr = 0x4A, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x46, addr = 0x6A, easy_addr = 0x4E, estab = 0x460000, cmd = _6_ac____, sdm = __, name = "フェイント 裁きの匕首", },
		},
		{ --秦崇秀
			{ spid = 0x01, addr = 0x02, estab = 0x010000, cmd = _6_6_a___, sdm = __, name = "帝王神足拳", },
			{ spid = 0x02, addr = 0x06, estab = 0x020000, cmd = _236a____, sdm = __, name = "小帝王天眼拳", },
			{ spid = 0x03, addr = 0x0A, estab = 0x030000, cmd = _236c____, sdm = __, name = "大帝王天眼拳", },
			{ spid = 0x04, addr = 0x0E, estab = 0x040000, cmd = _623a____, sdm = __, name = "小帝王天耳拳", },
			{ spid = 0x05, addr = 0x12, estab = 0x050000, cmd = _623c____, sdm = __, name = "大帝王天耳拳", },
			{ spid = 0x0A, addr = 0x16, estab = 0x0A0000, cmd = _214b____, sdm = __, name = "空中 帝王神眼拳", },
			{ spid = 0x06, addr = 0x1A, estab = 0x060000, cmd = _236b____, sdm = __, name = "竜灯掌", },
			{ spid = 0x07, addr = 0x1E, estab = 0x070000, cmd = _63214a__, sdm = __, name = "帝王神眼拳A", },
			{ spid = 0x08, addr = 0x22, estab = 0x0806FF, cmd = _63214b__, sdm = __, name = "帝王神眼拳B or 竜灯掌・幻殺", },
			{ spid = 0x09, addr = 0x26, estab = 0x090000, cmd = _63214c__, sdm = __, name = "帝王神眼拳C", },
			{ spid = 0x10, addr = 0x2A, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "帝王漏尽拳", },
			{ spid = 0x0A, addr = 0x2E, estab = 0x0A0000, cmd = _2146bc__, sdm = _B, name = "帝王空殺漏尽拳", },
			{ spid = 0x12, addr = 0x32, estab = 0x120000, cmd = _64123c__, sdm = _C, name = "海龍照臨", },
			{ spid = 0x1E, addr = 0x36, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x3A, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x3E, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = 0x28, addr = 0x42, estab = 0x280000, cmd = _6_4_c___, sdm = __, name = "CA _6_4_+_C", },
			{ spid = ____, addr = 0x46, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x4A, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x46, addr = 0x4E, estab = 0x460000, cmd = _2_bc____, sdm = __, name = "フェイント 海龍照臨", },
		},
		{ --秦崇雷
			{ spid = 0x01, addr = 0x02, estab = 0x010000, cmd = _6_6_a___, sdm = __, name = "帝王神足拳", },
			{ spid = 0x01, addr = 0x06, estab = 0x0106FF, cmd = _6_6_6_a_, sdm = __, name = "真・帝王神足拳", },
			{ spid = 0x02, addr = 0x0A, estab = 0x020000, cmd = _236a____, sdm = __, name = "小帝王天眼拳", },
			{ spid = 0x03, addr = 0x0E, estab = 0x030000, cmd = _236c____, sdm = __, name = "大帝王天眼拳", },
			{ spid = 0x04, addr = 0x12, estab = 0x040000, cmd = _623a____, sdm = __, name = "小帝王天耳拳", },
			{ spid = 0x05, addr = 0x16, estab = 0x050000, cmd = _623c____, sdm = __, name = "大帝王天耳拳", },
			{ spid = 0x06, addr = 0x1A, estab = 0x060000, cmd = _2146c___, sdm = __, name = "帝王漏尽拳", },
			{ spid = 0x07, addr = 0x1E, estab = 0x070000, cmd = _236b____, sdm = __, name = "龍転身（前方）", },
			{ spid = 0x08, addr = 0x22, estab = 0x080000, cmd = _214b____, sdm = __, name = "龍転身（後方）", },
			{ spid = 0x10, addr = 0x26, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "帝王宿命拳", },
			{ spid = ____, addr = 0x2A, estab = 0x0006FE, cmd = _c_c_c___, sdm = __, name = "_C_C_C", },
			{ spid = 0x12, addr = 0x2E, estab = 0x120000, cmd = _64123c__, sdm = _C, name = "帝王龍声拳", },
			{ spid = 0x1E, addr = 0x32, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x36, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x3A, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = ____, addr = 0x3E, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x42, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x46, addr = 0x46, estab = 0x460000, cmd = _2_bc____, sdm = __, name = "フェイント 帝王宿命拳", },
		},
		{ --ダック・キング
			-- ROMパッチをあてて簡易発動時も通常コマンドでﾌﾞﾚｲｸｽﾊﾟｲﾗﾙﾌﾞﾗｻﾞｰを出せるようにしているため
			-- こちらのほうもコマンド変更
			{ spid = 0x07, addr = 0x02, easy_addr = addr, estab = 0x070000, cmd = _3_5_c___, sdm = __, name = "_3_N_C", },
			{ spid = 0x01, addr = 0x06, easy_addr = addr, estab = 0x010000, cmd = _236a____, sdm = __, name = "小ヘッドスピンアタック", },
			{ spid = 0x02, addr = 0x0A, easy_addr = addr, estab = 0x020000, cmd = _236c____, sdm = __, name = "大ヘッドスピンアタック", },
			-- オーバーヘッドキックはCCで成立するが、成立時に次のC入力が1回消費される作りのため見ためが他と違う
			{ spid = 0x06, addr = 0x0E, easy_addr = addr, estab = 0x06FFFF, cmd = _c_c_____, sdm = __, name = "オーバーヘッドキック", },
			{ spid = 0x03, addr = 0x12, easy_addr = addr, estab = 0x030000, cmd = _214a____, sdm = __, name = "フライングスピンアタック", },
			{ spid = 0x04, addr = 0x16, easy_addr = addr, estab = 0x040000, cmd = _214b____, sdm = __, name = "ダンシングダイブ", },
			{ spid = ____, addr = 0x1A, easy_addr = addr, estab = 0x0006FE, cmd = _236b____, sdm = __, name = "リバースダイブ", },
			{ spid = 0x05, addr = 0x1E, easy_addr = addr, estab = 0x050000, cmd = _623b____, sdm = __, name = "ブレイクストーム", },
			{ spid = ____, addr = 0x22, easy_addr = addr, estab = 0x0006FD, cmd = _b_b_b_b_, sdm = __, name = "ブレイクストーム追加1段階", },
			{ spid = ____, addr = 0x26, easy_addr = addr, estab = 0x0006FC, cmd = _b_x6____, sdm = __, name = "ブレイクストーム追加2段階", },
			{ spid = ____, addr = 0x2A, easy_addr = addr, estab = 0x0006FB, cmd = _b_x8____, sdm = __, name = "ブレイクストーム追加3段階", },
			{ spid = 0x06, addr = 0x2E, easy_addr = addr, estab = 0x060000, cmd = _2_2_____, sdm = __, name = "ダックフェイント・空", },
			{ spid = 0x08, addr = 0x32, easy_addr = addr, estab = 0x080000, cmd = _8_2_d___, sdm = __, name = "クロスヘッドスピン", },
			{ spid = 0x09, addr = 0x36, easy_addr = addr, estab = 0x090000, cmd = _214bc___, sdm = __, name = "ﾀﾞｲﾋﾞﾝｸﾞﾊﾟﾆｯｼｬｰ or ﾀﾞﾝｼﾝｸﾞｷｬﾘﾊﾞｰ", },
			{ spid = 0x0A, addr = 0x3A, easy_addr = addr, estab = 0x0A0000, cmd = _236bc___, sdm = __, name = "ローリングパニッシャー", },
			{ spid = 0x0C, addr = 0x3E, easy_addr = addr, estab = 0x0C0000, cmd = _623bc___, sdm = __, name = "ブレイクハリケーン", },
			{ spid = 0x10, addr = 0x42, easy_addr = ____, estab = 0x100000, cmd = _8624bc__, sdm = _X, name = "ブレイクスパイラル_8_6_2_4", },
			{ spid = 0x10, addr = 0x46, easy_addr = ____, estab = 0x100000, cmd = _6248bc__, sdm = _X, name = "ブレイクスパイラル_6_2_4_8", },
			{ spid = 0x10, addr = 0x4A, easy_addr = ____, estab = 0x100000, cmd = _2486bc__, sdm = _X, name = "ブレイクスパイラル_2_4_8_6", },
			{ spid = 0x10, addr = 0x4E, easy_addr = ____, estab = 0x100000, cmd = _4862bc__, sdm = _X, name = "ブレイクスパイラル_4_8_6_2", },
			{ spid = 0x10, addr = 0x52, easy_addr = ____, estab = 0x100000, cmd = _8426bc__, sdm = _X, name = "ブレイクスパイラル_8_4_2_6", },
			{ spid = 0x10, addr = 0x56, easy_addr = ____, estab = 0x100000, cmd = _4268bc__, sdm = _X, name = "ブレイクスパイラル_4_2_6_8", },
			{ spid = 0x10, addr = 0x5A, easy_addr = ____, estab = 0x100000, cmd = _2684bc__, sdm = _X, name = "ブレイクスパイラル_2_6_8_4", },
			{ spid = 0x10, addr = 0x5E, easy_addr = ____, estab = 0x100000, cmd = _6842bc__, sdm = _X, name = "ブレイクスパイラル_6_8_4_2", },
			{ spid = 0x11, addr = 0x62, easy_addr = ____, estab = 0x1106FA, cmd = _41236bc_, sdm = _X, name = "ﾌﾞﾚｲｸｽﾊﾟｲﾗﾙﾌﾞﾗｻﾞｰ or ｸﾚｲｼﾞｰBR", },
			{ spid = 0x13, addr = 0x66, easy_addr = ____, estab = 0x130000, cmd = _63214c__, sdm = _X, name = "スーパーポンピングマシーン", },
			{ spid = ____, addr = 0x6A, easy_addr = 0x56, estab = 0x0006F9, cmd = _623c____, sdm = __, name = "_6_2_3_+_C", },
			{ spid = 0x12, addr = 0x6E, easy_addr = ____, estab = 0x120000, cmd = _64123c__, sdm = _X, name = "ダックダンス", },
			{ spid = 0x10, addr = _EZ_, easy_addr = 0x42, estab = ________, cmd = _2_2_a___, sdm = _A, name = "ブレイクスパイラル", },
			{ spid = 0x11, addr = _EZ_, easy_addr = 0x46, estab = 0x1106FA, cmd = _41236bc_, sdm = __, name = "ﾌﾞﾚｲｸｽﾊﾟｲﾗﾙﾌﾞﾗｻﾞｰ or ｸﾚｲｼﾞｰBR", },
			{ spid = 0x12, addr = _EZ_, easy_addr = 0x4A, estab = ________, cmd = _2_2_c___, sdm = _C, name = "ダックダンス", },
			{ spid = 0x13, addr = _EZ_, easy_addr = 0x4E, estab = ________, cmd = _2_2_d___, sdm = _D, name = "スーパーポンピングマシーン", },
			{ spid = ____, addr = 0x72, easy_addr = 0x52, estab = 0x0006F8, cmd = _c_c_c_c_, sdm = __, name = "ダックダンスC連打", },
			{ spid = 0x1E, addr = 0x76, easy_addr = 0x5A, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x7A, easy_addr = 0x5E, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x7E, easy_addr = 0x62, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = ____, addr = 0x82, easy_addr = 0x66, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x86, easy_addr = 0x6A, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x21, addr = 0x8A, easy_addr = 0x6E, estab = 0x210000, cmd = _2_c_____, sdm = __, name = "ショッキングボール", },
			{ spid = 0x28, addr = 0x8E, easy_addr = 0x72, estab = 0x280000, cmd = _2369b___, sdm = __, name = "CA ブレイクストーム", },
			{ spid = 0x46, addr = 0x92, easy_addr = 0x76, estab = 0x460000, cmd = _2_bc____, sdm = __, name = "フェイント ダックダンス", },
		},
		{ --キム・カッファン
			{ spid = 0x01, addr = 0x02, estab = 0x010000, cmd = _2chg8_b_, sdm = __, type = input_state_types.charge, name = "飛燕斬", },
			{ spid = 0x01, addr = 0x06, estab = 0x010601, cmd = _2chg9_b_, sdm = __, type = input_state_types.charge, name = "飛燕斬", },
			{ spid = 0x01, addr = 0x0A, estab = 0x010602, cmd = _2chg7_b_, sdm = __, type = input_state_types.charge, name = "飛燕斬", },
			{ spid = 0x04, addr = 0x0E, estab = 0x040800, cmd = _2_b_____, sdm = __, name = "飛翔脚", },
			{ spid = ____, addr = 0x12, estab = 0x0008FF, cmd = _3_b_____, sdm = __, name = "戒脚", },
			{ spid = 0x02, addr = 0x16, estab = 0x020000, cmd = _214b____, sdm = __, name = "小半月斬", },
			{ spid = 0x03, addr = 0x1A, estab = 0x030000, cmd = _214c____, sdm = __, name = "大半月斬", },
			{ spid = 0x05, addr = 0x1E, estab = 0x050000, cmd = _2chg8_a_, sdm = __, type = input_state_types.charge, name = "空砂塵", },
			{ spid = 0x06, addr = 0x22, estab = 0x06FEFF, cmd = _2_a_____, sdm = __, name = "天昇斬", },
			{ spid = ____, addr = 0x26, estab = 0x0006FE, cmd = _2_2_b___, sdm = __, name = "覇気脚", },
			{ spid = 0x10, addr = 0x2A, estab = 0x100000, cmd = _41236bc_, sdm = _A, name = "鳳凰天舞脚", },
			{ spid = 0x12, addr = 0x2E, estab = 0x120000, cmd = _21416c__, sdm = _C, name = "鳳凰脚", },
			{ spid = 0x1E, addr = 0x32, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x36, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x3A, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = ____, addr = 0x3E, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x42, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x46, addr = 0x46, estab = 0x460000, cmd = _2_bc____, sdm = __, name = "フェイント 鳳凰脚", },
		},
		{ --ビリー・カーン
			{ spid = 0x01, addr = 0x02, estab = 0x010000, cmd = _4chg6_a_, sdm = __, type = input_state_types.charge, name = "三節棍中段打ち", },
			{ spid = ____, addr = 0x06, estab = 0x0006FF, cmd = _4_6_c___, sdm = __, name = "火炎三節棍中段突き", },
			{ spid = 0x03, addr = 0x0A, estab = 0x030000, cmd = _214a____, sdm = __, name = "雀落とし", },
			{ spid = 0x04, addr = 0x0E, estab = 0x040C00, cmd = _a_a_a_a_, sdm = __, name = "旋風棍", },
			{ spid = 0x05, addr = 0x12, estab = 0x050000, cmd = _1236b___, sdm = __, name = "強襲飛翔棍", },
			{ spid = 0x06, addr = 0x16, estab = 0x060000, cmd = _214b____, sdm = __, name = "火龍追撃棍", },
			{ spid = 0x10, addr = 0x1A, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "超火炎旋風棍", },
			{ spid = 0x11, addr = 0x1E, estab = 0x110000, cmd = _632c____, sdm = _B, name = "紅蓮殺棍", },
			{ spid = 0x12, addr = 0x22, estab = 0x120000, cmd = _64123c__, sdm = _C, name = "サラマンダーストーム", },
			{ spid = 0x1E, addr = 0x26, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x2A, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x2E, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = ____, addr = 0x32, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x36, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x28, addr = 0x3A, estab = 0x280000, cmd = _236c____, sdm = __, name = "CA 集点連破棍", },
			{ spid = 0x46, addr = 0x3E, estab = 0x460000, cmd = _4_ac____, sdm = __, name = "フェイント 強襲飛翔棍", },
		},
		{ --チン・シンザン
			{ spid = 0x01, addr = 0x02, estab = 0x010000, cmd = _236a____, sdm = __, name = "氣雷砲（前方）", },
			{ spid = 0x02, addr = 0x06, estab = 0x020000, cmd = _623a____, sdm = __, name = "氣雷砲（対空）", },
			{ spid = 0x03, addr = 0x0A, estab = 0x030000, cmd = _2chg8_a_, sdm = __, type = input_state_types.charge, name = "超太鼓腹打ち", },
			{ spid = ____, addr = 0x0E, estab = 0x0006FF, cmd = _a_a_____, sdm = __, name = "満腹滞空", },
			{ spid = 0x04, addr = 0x12, estab = 0x040000, cmd = _4chg6_b_, sdm = __, type = input_state_types.charge, name = "小破岩撃", },
			{ spid = 0x05, addr = 0x16, estab = 0x050000, cmd = _4chg6_c_, sdm = __, type = input_state_types.charge, name = "大破岩撃", },
			{ spid = 0x06, addr = 0x1A, estab = 0x060000, cmd = _214b____, sdm = __, name = "軟体オヤジ", },
			{ spid = 0x07, addr = 0x1E, estab = 0x070000, cmd = _214c____, sdm = __, name = "クッサメ砲", },
			{ spid = 0x10, addr = 0x22, estab = 0x100000, cmd = _1chg26bc, sdm = _A, type = input_state_types.charge, name = "爆雷砲", },
			{ spid = 0x12, addr = 0x26, estab = 0x120000, cmd = _64123c__, sdm = _C, name = "ホエホエ弾", },
			{ spid = 0x1E, addr = 0x2A, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x2E, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x32, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = ____, addr = 0x36, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x3A, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x28, addr = 0x3E, estab = 0x280000, cmd = _4_4_b___, sdm = __, name = "CA _4_4_+_B", },
			{ spid = 0x46, addr = 0x42, estab = 0x460000, cmd = _6_ac____, sdm = __, name = "フェイント 破岩撃", },
			{ spid = 0x47, addr = 0x46, estab = 0x470000, cmd = _2_ac____, sdm = __, name = "フェイント クッサメ砲", },
		},
		{ --タン・フー・ルー
			{ spid = 0x01, addr = 0x02, estab = 0x010000, cmd = _236a____, sdm = __, name = "衝波", },
			{ spid = 0x02, addr = 0x06, estab = 0x020000, cmd = _214a____, sdm = __, name = "小箭疾歩", },
			{ spid = 0x03, addr = 0x0A, estab = 0x030000, cmd = _214c____, sdm = __, name = "大箭疾歩", },
			{ spid = 0x04, addr = 0x0E, estab = 0x040000, cmd = _236c____, sdm = __, name = "撃放", },
			{ spid = 0x05, addr = 0x12, estab = 0x050000, cmd = _623b____, sdm = __, name = "烈千脚", },
			{ spid = 0x10, addr = 0x16, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "旋風剛拳", },
			{ spid = 0x12, addr = 0x1A, estab = 0x120000, cmd = _64123c__, sdm = _C, name = "大撃砲", },
			{ spid = 0x1E, addr = 0x1E, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x22, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x26, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = ____, addr = 0x2A, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x2E, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x28, addr = 0x32, estab = 0x280000, cmd = _6_b_____, sdm = __, name = "_6_+_B", },
			{ spid = 0x29, addr = 0x36, estab = 0x290000, cmd = _6_c_____, sdm = __, name = "_6_+_C", },
			{ spid = 0x46, addr = 0x3A, estab = 0x460000, cmd = _2_bc____, sdm = __, name = "フェイント 旋風剛拳", },
		},
		{ --ローレンス・ブブラッド
			{ spid = 0x01, addr = 0x02, estab = 0x010000, cmd = _63214a__, sdm = __, name = "小ブラッディスピン", },
			{ spid = 0x02, addr = 0x06, estab = 0x020000, cmd = _63214c__, sdm = __, name = "大ブラッディスピン", },
			{ spid = 0x03, addr = 0x0A, estab = 0x030000, cmd = _4chg6_c_, sdm = __, type = input_state_types.charge, name = "ブラッディサーベル", },
			{ spid = 0x04, addr = 0x0E, estab = 0x0406FF, cmd = _a_a_a_a_, sdm = __, name = "ブラッディミキサー", },
			{ spid = 0x05, addr = 0x12, estab = 0x050000, cmd = _2chg8_c_, sdm = __, type = input_state_types.charge, name = "ブラッディカッター", },
			{ spid = 0x10, addr = 0x16, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "ブラッディフラッシュ", },
			{ spid = 0x12, addr = 0x1A, estab = 0x120000, cmd = _64123c__, sdm = _C, name = "ブラッディシャドー", },
			{ spid = 0x1E, addr = 0x1E, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x22, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x26, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = ____, addr = 0x2A, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x2E, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x28, addr = 0x32, estab = 0x280000, cmd = _632c____, sdm = __, name = "CA _6_3_2_C", },
		},
		{ --ヴォルフガング・クラウザー
			{ spid = ____, addr = 0x02, easy_addr = addr, estab = 0x0006FE, cmd = _421ac___, sdm = __, name = "アンリミテッドデザイア2 Finish", },
			{ spid = 0x01, addr = 0x06, easy_addr = addr, estab = 0x010000, cmd = _214a____, sdm = __, name = "小ブリッツボール", },
			{ spid = 0x02, addr = 0x0A, easy_addr = addr, estab = 0x0206FF, cmd = _214c____, sdm = __, name = "大ブリッツボール", },
			{ spid = 0x03, addr = 0x0E, easy_addr = addr, estab = 0x030000, cmd = _236b____, sdm = __, name = "レッグトマホーク", },
			{ spid = 0x04, addr = 0x12, easy_addr = addr, estab = 0x040000, cmd = _41236c__, sdm = __, name = "フェニックススルー", },
			{ spid = 0x05, addr = 0x16, easy_addr = addr, estab = 0x050000, cmd = _41236a__, sdm = __, name = "デンジャラススルー", },
			{ spid = 0x06, addr = 0x1A, easy_addr = addr, estab = 0x0006FD, cmd = _6_6_6_c_, sdm = __, name = "グリフォンアッパー", },
			{ spid = 0x07, addr = 0x1E, easy_addr = addr, estab = 0x0606FC, cmd = _623c____, sdm = __, name = "カイザークロー", },
			{ spid = 0x10, addr = 0x22, easy_addr = addr, estab = 0x070000, cmd = _63214b__, sdm = __, name = "リフトアップブロー", },
			{ spid = ____, addr = 0x26, easy_addr = 0x26, estab = 0x100000, cmd = _4chg6_bc, sdm = _A, type = input_state_types.charge, name = "カイザーウェイブ", },
			{ spid = 0x12, addr = 0x2A, easy_addr = ____, estab = 0x120000, cmd = _8624c___, sdm = _X, name = "ギガティックサイクロン_8_6_2_4", },
			{ spid = 0x12, addr = 0x2E, easy_addr = ____, estab = 0x120000, cmd = _6248c___, sdm = _X, name = "ギガティックサイクロン_6_2_4_8", },
			{ spid = 0x12, addr = 0x32, easy_addr = ____, estab = 0x120000, cmd = _2486c___, sdm = _X, name = "ギガティックサイクロン_2_4_8_6", },
			{ spid = 0x12, addr = 0x36, easy_addr = ____, estab = 0x120000, cmd = _4862c___, sdm = _X, name = "ギガティックサイクロン_4_8_6_2", },
			{ spid = 0x12, addr = 0x3A, easy_addr = ____, estab = 0x120000, cmd = _8426c___, sdm = _X, name = "ギガティックサイクロン_8_4_2_6", },
			{ spid = 0x12, addr = 0x3E, easy_addr = ____, estab = 0x120000, cmd = _4268c___, sdm = _X, name = "ギガティックサイクロン_4_2_6_8", },
			{ spid = 0x12, addr = 0x42, easy_addr = ____, estab = 0x120000, cmd = _2684c___, sdm = _X, name = "ギガティックサイクロン_2_6_8_4", },
			{ spid = 0x12, addr = 0x46, easy_addr = ____, estab = 0x120000, cmd = _6842c___, sdm = _X, name = "ギガティックサイクロン_6_8_4_2", },
			{ spid = 0x12, addr = _EZ_, easy_addr = 0x2A, estab = ________, cmd = _2_2_c___, sdm = _C, name = "ギガティックサイクロン", },
			{ spid = 0x13, addr = 0x4A, easy_addr = 0x2E, estab = 0x130000, cmd = _632146a_, sdm = _D, name = "アンリミテッドデザイア", },
			{ spid = 0x1E, addr = 0x4E, easy_addr = 0x32, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x52, easy_addr = 0x36, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x56, easy_addr = 0x3A, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = ____, addr = 0x5A, easy_addr = 0x3E, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x5E, easy_addr = 0x42, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x21, addr = 0x62, easy_addr = 0x46, estab = 0x210000, cmd = _2_c_____, sdm = __, name = "ダイビングエルボー", },
			{ spid = 0x28, addr = 0x66, easy_addr = 0x4A, estab = 0x280000, cmd = _236c____, sdm = __, name = "CA _2_3_6_C", },
			{ spid = 0x46, addr = 0x6A, easy_addr = 0x4E, estab = 0x460000, cmd = _2_ac____, sdm = __, name = "フェイント ブリッツボール", },
			{ spid = 0x47, addr = 0x6E, easy_addr = 0x52, estab = 0x470000, cmd = _2_bc____, sdm = __, name = "フェイント カイザーウェイブ", },
		},
		{ --リック・ストラウド
			{ spid = 0x01, addr = 0x02, estab = 0x010000, cmd = _236a____, sdm = __, name = "小シューティングスター", },
			{ spid = 0x02, addr = 0x06, estab = 0x0206FF, cmd = _236c____, sdm = __, name = "大シューティングスター", },
			{ spid = 0x03, addr = 0x0A, estab = 0x030000, cmd = _214c____, sdm = __, name = "ディバインブラスト", },
			{ spid = 0x04, addr = 0x0E, estab = 0x040000, cmd = _214b____, sdm = __, name = "フルムーンフィーバー", },
			{ spid = 0x05, addr = 0x12, estab = 0x050000, cmd = _623a____, sdm = __, name = "ヘリオン", },
			{ spid = 0x06, addr = 0x16, estab = 0x060000, cmd = _214a____, sdm = __, name = "ブレイジングサンバースト", },
			{ spid = 0x10, addr = 0x1A, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "ガイアブレス", },
			{ spid = 0x12, addr = 0x1E, estab = 0x120000, cmd = _64123c__, sdm = _C, name = "ハウリング・ブル", },
			{ spid = 0x1E, addr = 0x22, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x26, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x2A, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = ____, addr = 0x2E, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x32, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x28, addr = 0x36, estab = 0x280000, cmd = _3_3_b___, sdm = __, name = "CA _3_3_B", },
			{ spid = 0x29, addr = 0x3A, estab = 0x290000, cmd = _2_2_c___, sdm = __, name = "CA _2_2_C", },
			{ spid = 0x46, addr = 0x3E, estab = 0x460000, cmd = _6_ac____, sdm = __, name = "フェイント シューティングスター", },
		},
		{ --李香緋
			{ spid = 0x07, addr = 0x02, easy_addr = addr, estab = 0x070000, cmd = _a_8_____, sdm = __, name = "詠酒・対ジャンプ攻撃", },
			{ spid = 0x08, addr = 0x06, easy_addr = addr, estab = 0x080000, cmd = _a_6_____, sdm = __, name = "詠酒・対立ち攻撃", },
			{ spid = 0x09, addr = 0x0A, easy_addr = addr, estab = 0x090000, cmd = _a_2_____, sdm = __, name = "詠酒・対しゃがみ攻撃 ", },
			{ spid = 0x01, addr = 0x0E, easy_addr = addr, estab = 0x010000, cmd = _236a____, sdm = __, name = "小那夢波", },
			{ spid = 0x02, addr = 0x12, easy_addr = addr, estab = 0x020000, cmd = _236c____, sdm = __, name = "大那夢波", },
			{ spid = 0x03, addr = 0x16, easy_addr = addr, estab = 0x0306FF, cmd = _236b____, sdm = __, name = "閃里肘皇 or 閃里肘皇・貫空", },
			{ spid = ____, addr = 0x1A, easy_addr = addr, estab = 0x0006FE, cmd = _214b____, sdm = __, name = "閃里肘皇・心砕把", },
			{ spid = 0x06, addr = 0x1E, easy_addr = addr, estab = 0x060000, cmd = _623b____, sdm = __, name = "天崩山", },
			{ spid = 0x10, addr = 0x22, easy_addr = addr, estab = 0x100000, cmd = _64123bc_, sdm = _A, name = "大鉄神", },
			{ spid = 0x11, addr = 0x26, easy_addr = addr, estab = 0x1106FD, cmd = _616ab___, sdm = _B, name = "超白龍", }, -- 1段目or2段目?
			{ spid = ____, addr = 0x2A, easy_addr = ____, estab = 0x0006FD, cmd = _623ab___, sdm = _X, name = "超白龍 2段目のみ", },
			{ spid = 0x12, addr = 0x2E, easy_addr = ____, estab = 0x120000, cmd = _8624c___, sdm = _X, name = "真心牙_8_6_2_4", },
			{ spid = 0x12, addr = 0x32, easy_addr = ____, estab = 0x120000, cmd = _6248c___, sdm = _X, name = "真心牙_6_2_4_8", },
			{ spid = 0x12, addr = 0x36, easy_addr = ____, estab = 0x120000, cmd = _2486c___, sdm = _X, name = "真心牙_2_4_8_6", },
			{ spid = 0x12, addr = 0x3A, easy_addr = ____, estab = 0x120000, cmd = _4862c___, sdm = _X, name = "真心牙_4_8_6_2", },
			{ spid = 0x12, addr = 0x3E, easy_addr = ____, estab = 0x120000, cmd = _8426c___, sdm = _X, name = "真心牙_8_4_2_6", },
			{ spid = 0x12, addr = 0x42, easy_addr = ____, estab = 0x120000, cmd = _4268c___, sdm = _X, name = "真心牙_4_2_6_8", },
			{ spid = 0x12, addr = 0x46, easy_addr = ____, estab = 0x120000, cmd = _2684c___, sdm = _X, name = "真心牙_2_6_8_4", },
			{ spid = 0x12, addr = 0x4A, easy_addr = ____, estab = 0x120000, cmd = _6842c___, sdm = _X, name = "真心牙_6_8_4_2", },
			{ spid = 0x12, addr = _EZ_, easy_addr = 0x2A, estab = ________, cmd = _2_2_c___, sdm = _C, name = "真心牙", },
			{ spid = 0x1E, addr = 0x4E, easy_addr = 0x2E, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x52, easy_addr = 0x32, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x56, easy_addr = 0x36, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = ____, addr = 0x5A, easy_addr = 0x3A, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x5E, easy_addr = 0x3E, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x28, addr = 0x62, easy_addr = 0x42, estab = 0x280000, cmd = ca_6_6_a_, sdm = __, name = "CA _6_6_A", },
			{ spid = 0x46, addr = 0x66, easy_addr = 0x46, estab = 0x460000, cmd = _4_ac____, sdm = __, name = "フェイント 天崩山", },
			{ spid = 0x47, addr = 0x6A, easy_addr = 0x4A, estab = 0x470000, cmd = _2_bc____, sdm = __, name = "フェイント 大鉄神", },
		},
		{ --アルフレッド
			{ spid = 0x01, addr = 0x02, estab = 0x010000, cmd = _214a____, sdm = __, name = "小クリティカルウィング", },
			{ spid = 0x02, addr = 0x06, estab = 0x020000, cmd = _214c____, sdm = __, name = "大クリティカルウィング", },
			{ spid = 0x03, addr = 0x0A, estab = 0x030000, cmd = _236a____, sdm = __, name = "オーグメンターウィング", },
			{ spid = 0x04, addr = 0x0E, estab = 0x040000, cmd = _236c____, sdm = __, name = "ダイバージェンス", },
			{ spid = 0x05, addr = 0x12, estab = 0x050000, cmd = _214b____, sdm = __, name = "メーデーメーデー", },
			{ spid = 0x06, addr = 0x16, estab = 0x06FFFF, cmd = _b_b_b___, sdm = __, name = "メーデーメーデー追加", },
			{ spid = 0x06, addr = 0x1A, estab = 0x060000, cmd = _698b____, sdm = __, name = "S.TOL", },
			{ spid = 0x10, addr = 0x1E, estab = 0x100000, cmd = _41236bc_, sdm = _A, name = "ショックストール", },
			{ spid = 0x12, addr = 0x22, estab = 0x120000, cmd = _64123c__, sdm = _C, name = "ウェーブライダー", },
			{ spid = 0x1E, addr = 0x26, estab = 0x1E0000, cmd = _6_6_____, sdm = __, name = "ダッシュ", },
			{ spid = 0x1F, addr = 0x2A, estab = 0x1F0000, cmd = _4_4_____, sdm = __, name = "飛び退き", },
			{ spid = 0x20, addr = 0x2E, estab = 0x200000, cmd = _4_6_a___, sdm = __, name = "_4_6_+_A", },
			{ spid = ____, addr = 0x32, estab = 0x003300, cmd = _412d____, sdm = __, name = "_4_1_2_+_D", },
			{ spid = ____, addr = 0x36, estab = 0x0027FF, cmd = _4_4_d___, sdm = __, name = "_4_4_+_D", },
			{ spid = 0x46, addr = 0x3A, estab = 0x460000, cmd = _2_ac____, sdm = __, name = "フェイント クリティカルウィング", },
			{ spid = 0x47, addr = 0x3E, estab = 0x470000, cmd = _4_ac____, sdm = __, name = "フェイント オーグメンターウィング", },
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
	local id_estab = function(tbl)
		tbl.estab = sdm_estab[tbl.sdm] or tbl.estab
		tbl.id = (0xFF0000 & tbl.estab) / 0x10000
		tbl.estab = tbl.estab & 0xFFFF
		tbl.exp_extab = tbl.estab & 0x00FF
	end
	local do_remove = function(target, indexies)
		for i = #indexies, 1, -1 do
			table.remove(target, indexies[i])
		end
	end
	-- DEBUG DIP 2-1 ON時の簡易コマンドテーブルの準備としてSDMのフラグからコマンド情報を変更
	local input_easy_states = ut.deepcopy(input_states)
	for _, char_tbl in ipairs(input_easy_states) do
		local removes = {}
		for i, tbl in ipairs(char_tbl) do
			if tbl.sdm == "x" then
				-- 削除
				table.insert(removes, i)
			elseif tbl.sdm ~= nil then
				-- 簡易コマンドへ変更
				tbl.cmd = sdm_cmd[tbl.sdm]
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
	local input_convert = function(input_tables)
		for _, char_tbl in ipairs(input_tables) do
			for _, tbl in ipairs(char_tbl) do
				-- 左右反転コマンド表示用
				tbl.r_cmd = string.gsub(tbl.cmd, "[134679]", {
					["1"] = "3", ["3"] = "1", ["4"] = "6", ["6"] = "4", ["7"] = "9", ["9"] = "7",
				})
				local r_cmds, cmds = {}, {}
				for c in string.gmatch(ut.convert(tbl.r_cmd), "([^|]*)|?") do
					table.insert(r_cmds, c)
				end
				for c in string.gmatch(ut.convert(tbl.cmd), "([^|]*)|?") do
					table.insert(cmds, c)
				end
				-- コマンドの右向き左向きをあらわすデータ値をキーにしたテーブルを用意
				tbl.lr_cmds = { [1] = cmds, [-1] = r_cmds, }
				tbl.cmds = cmds
				tbl.name_plain = tbl.name
				tbl.name = ut.convert(tbl.name)
			end
		end
		return input_tables
	end
	return { normal = input_convert(input_states), easy = input_convert(input_easy_states) }
end
local input_state                    = {
	types  = input_state_types,
	states = create_input_states(),
	col    = {
		orange = 0xFFFF8800,
		ol_orange2 = 0xC0FF8800,
		red = 0xFFFF0000,
		green = 0xC07FFF00,
		green2 = 0xFF7FFF00,
		yellow = 0xC0FFFF00,
		yellow2 = 0xFFFFFF00,
		white = 0xC0FFFFFF,
		gray2 = 0xFFC0C0C0,
		gray = 0xC0C0C0C0,
	},
}
db.input_state                       = input_state
db.input_state_types                 = input_state_types
db.input_state_normal                = input_state.states.normal
db.input_state_easy                  = input_state.states.easy

--------------------------------------------------------------------------------------
-- 判定の種類
--------------------------------------------------------------------------------------

local box_kinds                      = {
	parry   = "Parry",
	attack  = "Hit",
	block   = "Block",
	push    = "Push",
	throw   = "Throw",
	unknown = "Unkown",
	hurt    = "Hurt",
}
local box_types                      = {
	attack             = { no = 1, id = 0x00, enabled = 2, kind = box_kinds.attack, sort = 4, color = 0xFF00FF, fill = 0x40, outline = 0xFF, sway = false, name = "攻撃", name_en = "attack", },
	fake_attack        = { no = 2, id = 0x00, enabled = 1, kind = box_kinds.attack, sort = 1, color = 0x00FF00, fill = 0x00, outline = 0xFF, sway = false, name = "攻撃(嘘)", name_en = "fake_attack", },
	harmless_attack    = { no = 3, id = 0x00, enabled = 2, kind = box_kinds.attack, sort = 3, color = 0xFF00FF, fill = 0x00, outline = 0xFF, sway = false, name = "攻撃(無効)", name_en = "harmless_attack", },
	juggle             = { no = 4, id = 0x00, enabled = 2, kind = box_kinds.attack, sort = 4, color = 0xFF0033, fill = 0x40, outline = 0xFF, sway = false, name = "攻撃(空中追撃可)", name_en = "juggle", },
	fake_juggle        = { no = 5, id = 0x00, enabled = 1, kind = box_kinds.attack, sort = 1, color = 0x00FF33, fill = 0x00, outline = 0xFF, sway = false, name = "攻撃(嘘、空中追撃可)", name_en = "fake_juggle", },
	harmless_juggle    = { no = 6, id = 0x00, enabled = 2, kind = box_kinds.attack, sort = 2, color = 0xFF0033, fill = 0x00, outline = 0xFF, sway = false, name = "攻撃(無効、空中追撃可)", name_en = "harmless_juggle", },
	unknown            = { no = 7, id = 0x00, enabled = 1, kind = box_kinds.throw, sort = -1, color = 0x8B4513, fill = 0x40, outline = 0xFF, sway = false, name = "用途不明", name_en = "unknown", },
	fireball           = { no = 8, id = 0x00, enabled = 2, kind = box_kinds.attack, sort = 5, color = 0xFF00FF, fill = 0x40, outline = 0xFF, sway = false, name = "弾", name_en = "fireball", },
	fake_fireball      = { no = 9, id = 0x00, enabled = 2, kind = box_kinds.attack, sort = 1, color = 0x00FF00, fill = 0x00, outline = 0xFF, sway = false, name = "弾(嘘)", name_en = "fake_fireball", },
	harmless_fireball  = { no = 10, id = 0x00, enabled = 2, kind = box_kinds.attack, sort = 3, color = 0xFF00FF, fill = 0x00, outline = 0xFF, sway = false, name = "弾(無効)", name_en = "harmless_fireball", },
	juggle_fireball    = { no = 11, id = 0x00, enabled = 2, kind = box_kinds.attack, sort = 5, color = 0xFF0033, fill = 0x40, outline = 0xFF, sway = false, name = "弾(空中追撃可)", name_en = "juggle_fireball", },
	fake_juggle_fb     = { no = 12, id = 0x00, enabled = 2, kind = box_kinds.attack, sort = 1, color = 0x00FF33, fill = 0x00, outline = 0xFF, sway = false, name = "弾(嘘、空中追撃可)", name_en = "fake_juggle_fb", },
	harmless_juggle_fb = { no = 13, id = 0x00, enabled = 2, kind = box_kinds.attack, sort = 2, color = 0xFF0033, fill = 0x00, outline = 0xFF, sway = false, name = "弾(無効、空中追撃可)", name_en = "harmless_juggle_fb", },
	normal_throw       = { no = 14, id = 0x00, enabled = 2, kind = box_kinds.throw, sort = 6, color = 0xFFFF00, fill = 0x40, outline = 0xFF, sway = false, name = "投げ", name_en = "normal_throw", },
	special_throw      = { no = 15, id = 0x00, enabled = 2, kind = box_kinds.throw, sort = 6, color = 0xFFFF00, fill = 0x40, outline = 0xFF, sway = false, name = "必殺技投げ", name_en = "special_throw", },
	air_throw          = { no = 16, id = 0x00, enabled = 2, kind = box_kinds.throw, sort = 6, color = 0xFFFF00, fill = 0x40, outline = 0xFF, sway = false, name = "空中投げ", name_en = "air_throw", },
	push               = { no = 17, id = 0x01, enabled = 2, kind = box_kinds.push, sort = 1, color = 0xDDDDDD, fill = 0x00, outline = 0xFF, sway = false, name = "押し合い", name_en = "push", },
	hurt1              = { no = 18, id = 0x02, enabled = 2, kind = box_kinds.hurt, sort = 2, color = 0x0000FF, fill = 0x40, outline = 0xFF, sway = false, name = "食らい1", name_en = "hurt1", },
	hurt2              = { no = 19, id = 0x03, enabled = 2, kind = box_kinds.hurt, sort = 2, color = 0x0000FF, fill = 0x40, outline = 0xFF, sway = false, name = "食らい2", name_en = "hurt2", },
	down_otg           = { no = 20, id = 0x04, enabled = 2, kind = box_kinds.hurt, sort = 2, color = 0x00FFFF, fill = 0x80, outline = 0xFF, sway = false, name = "食らい(ダウン追撃のみ可)", name_en = "down_otg", },
	launch             = { no = 21, id = 0x05, enabled = 2, kind = box_kinds.hurt, sort = 2, color = 0x00FFFF, fill = 0x80, outline = 0xFF, sway = false, name = "食らい(空中追撃のみ可)", name_en = "launch", },
	hurt3              = { no = 22, id = 0x07, enabled = 2, kind = box_kinds.hurt, sort = 2, color = 0x00CC77, fill = 0x80, outline = 0xFF, sway = false, name = "食らい(対ライン上攻撃)", name_en = "hurt3", },
	hurt4              = { no = 23, id = 0x08, enabled = 2, kind = box_kinds.hurt, sort = 2, color = 0x00CC77, fill = 0x80, outline = 0xFF, sway = false, name = "食らい(対ライン下攻撃)", name_en = "hurt4", },
	block_overhead     = { no = 24, id = 0x11, enabled = 2, kind = box_kinds.block, sort = 3, color = 0xC0C0C0, fill = 0x40, outline = 0xFF, sway = false, name = "立ガード", name_en = "block_overhead", },
	block_low          = { no = 25, id = 0x12, enabled = 2, kind = box_kinds.block, sort = 3, color = 0xC0C0C0, fill = 0x40, outline = 0xFF, sway = false, name = "下段ガード", name_en = "block_low", },
	block_air          = { no = 26, id = 0x13, enabled = 2, kind = box_kinds.block, sort = 3, color = 0xC0C0C0, fill = 0x40, outline = 0xFF, sway = false, name = "空中ガード", name_en = "block_air", },
	joudan_atemi       = { no = 27, id = 0x14, enabled = 2, kind = box_kinds.parry, sort = 3, color = 0xFF7F00, fill = 0x40, outline = 0xFF, sway = false, name = "上段当身投げ", name_en = "joudan_atemi", },
	urakumo_kakushi    = { no = 28, id = 0x15, enabled = 2, kind = box_kinds.parry, sort = 3, color = 0xFF7F00, fill = 0x40, outline = 0xFF, sway = false, name = "裏雲隠し", name_en = "urakumo_kakushi", },
	gedan_atemiuchi    = { no = 29, id = 0x16, enabled = 2, kind = box_kinds.parry, sort = 3, color = 0xFF7F00, fill = 0x40, outline = 0xFF, sway = false, name = "下段当身打ち", name_en = "gedan_atemiuchi", },
	gyakusyuken        = { no = 30, id = 0x17, enabled = 2, kind = box_kinds.parry, sort = 3, color = 0xFF7F00, fill = 0x40, outline = 0xFF, sway = false, name = "必勝逆襲拳", name_en = "gyakusyuken", },
	sadomazo           = { no = 31, id = 0x18, enabled = 2, kind = box_kinds.parry, sort = 3, color = 0xFF7F00, fill = 0x40, outline = 0xFF, sway = false, name = "サドマゾ", name_en = "sadomazo", },
	baigaeshi          = { no = 32, id = 0x19, enabled = 2, kind = box_kinds.parry, sort = 3, color = 0xFF007F, fill = 0x40, outline = 0xFF, sway = false, name = "倍返し", name_en = "baigaeshi", },
	phoenix_throw      = { no = 33, id = 0x1C, enabled = 2, kind = box_kinds.parry, sort = 3, color = 0xFF7F00, fill = 0x40, outline = 0xFF, sway = false, name = "フェニックススルー", name_en = "phoenix_throw", },
	sway_hurt1         = { no = 34, id = 0x02, enabled = 2, kind = box_kinds.hurt, sort = 2, color = 0x8000FF, fill = 0x40, outline = 0xFF, sway = true, name = "食らい1(スウェー中)", name_en = "sway_hurt1", },
	sway_hurt2         = { no = 35, id = 0x03, enabled = 2, kind = box_kinds.hurt, sort = 2, color = 0x8000FF, fill = 0x40, outline = 0xFF, sway = true, name = "食らい2(スウェー中)", name_en = "sway_hurt2", },
}
local main_box_types, sway_box_types = {}, {}
for _, boxtype in pairs(box_types) do
	if 0 < boxtype.id then
		if boxtype.sway then
			sway_box_types[boxtype.id - 1] = boxtype
		else
			main_box_types[boxtype.id - 1] = boxtype
		end
	end
	boxtype.fill    = (0xFFFFFFFF & (boxtype.fill << 24)) | boxtype.color
	boxtype.outline = (0xFFFFFFFF & (boxtype.outline << 24)) | boxtype.color
	if boxtype == box_types.down_otg then
		-- visible ... 1:OFF 2:ON(条件付き) or 3:ON:ALL
		boxtype.visible = function(p, box)
			if box.type.enabled == 1 then return false end
			if box.type.enabled == 3 then return true end
			-- トドメの範囲判定
			-- 東の3B、シャンフェイの4B、アルフレッドのAは表示。フランコの5A5A5Cは非表示
			if 0 < box.real_top and box.real_top < 13 then
				return true
			elseif 0 < box.real_bottom and box.real_bottom < 13 then
				return true
			end
			return false
		end
	elseif boxtype == box_types.launch then
		boxtype.visible = function(p, box)
			if box.type.enabled == 1 then return false end
			if box.type.enabled == 3 then return true end
			-- メインライン上だけ表示
			-- 東の対メインCは非表示
			return p.pos_z == 24
		end
	else
		boxtype.visible = function(p, box) return box.type.enabled > 1 end
	end
end
local hurt_boxies   = ut.new_set(
	box_types.hurt1,  -- 食らい1
	box_types.hurt2,  -- 食らい2
	box_types.down_otg, -- 食らい(ダウン追撃のみ可)
	box_types.launch, -- 食らい(空中追撃のみ可)
	box_types.unknown02, -- 食らい5(未使用?)
	box_types.hurt3,  -- 食らい(対ライン上攻撃)
	box_types.hurt4)  -- 食らい(対ライン下攻撃)
local box_type_list = {}
for _, box_type in pairs(box_types) do table.insert(box_type_list, box_type) end
table.sort(box_type_list, function(a, b) return a.no < b.no end)
db.box_kinds             = box_kinds
db.box_types             = box_types
db.main_box_types        = main_box_types
db.sway_box_types        = sway_box_types
db.hurt_boxies           = hurt_boxies
db.box_type_list         = box_type_list

local box_with_bit_types = {
	body = ut.table_sort({
		{ box_type = box_types.fake_juggle,     attackbit = frame_attack_types.attacking | frame_attack_types.fake | frame_attack_types.juggle }, -- 1
		{ box_type = box_types.fake_attack,     attackbit = frame_attack_types.attacking | frame_attack_types.fake },                           -- 1
		{ box_type = box_types.harmless_juggle, attackbit = frame_attack_types.attacking | frame_attack_types.fullhit | frame_attack_types.juggle }, -- 2
		{ box_type = box_types.harmless_juggle, attackbit = frame_attack_types.attacking | frame_attack_types.harmless | frame_attack_types.juggle }, -- 2
		{ box_type = box_types.harmless_juggle, attackbit = frame_attack_types.attacking | frame_attack_types.obsolute | frame_attack_types.juggle }, -- 2
		{ box_type = box_types.juggle,          attackbit = frame_attack_types.attacking | frame_attack_types.juggle },                         -- 4
		{ box_type = box_types.harmless_attack, attackbit = frame_attack_types.attacking | frame_attack_types.fullhit },                        -- 2
		{ box_type = box_types.harmless_attack, attackbit = frame_attack_types.attacking | frame_attack_types.obsolute },                       -- 2
		{ box_type = box_types.harmless_attack, attackbit = frame_attack_types.attacking | frame_attack_types.harmless },                       -- 2
		{ box_type = box_types.attack,          attackbit = frame_attack_types.attacking },                                                     -- 4
	}, function(t1, t2) return t1.box_type.sort < t2.box_type.sort end),
	fireball = ut.table_sort({
		{ box_type = box_types.fake_juggle_fb,     attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.fake | frame_attack_types.juggle },
		{ box_type = box_types.fake_fireball,      attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.fake },
		{ box_type = box_types.harmless_juggle_fb, attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.fullhit | frame_attack_types.juggle },
		{ box_type = box_types.harmless_juggle_fb, attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.obsolute | frame_attack_types.juggle },
		{ box_type = box_types.harmless_juggle_fb, attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.harmless | frame_attack_types.juggle },
		{ box_type = box_types.juggle_fireball,    attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.juggle },
		{ box_type = box_types.harmless_fireball,  attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.fullhit },
		{ box_type = box_types.harmless_fireball,  attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.obsolute },
		{ box_type = box_types.harmless_fireball,  attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.harmless },
		{ box_type = box_types.fireball,           attackbit = frame_attack_types.attacking | frame_attack_types.fb },
	}, function(t1, t2) return t1.box_type.sort < t2.box_type.sort end),
	bodykv = {},
	fireballkv = {},
	mask = 0,
}
for _, type in ipairs(box_with_bit_types.body) do box_with_bit_types.bodykv[type.attackbit] = type end
for _, type in ipairs(box_with_bit_types.fireball) do box_with_bit_types.fireballkv[type.attackbit] = type end
for k, _ in pairs(box_with_bit_types.bodykv) do box_with_bit_types.mask = k | box_with_bit_types.mask end
for k, _ in pairs(box_with_bit_types.fireballkv) do box_with_bit_types.mask = k | box_with_bit_types.mask end
db.box_with_bit_types            = box_with_bit_types

--------------------------------------------------------------------------------------
-- ステージデータ
--------------------------------------------------------------------------------------

db.stage_list                    = {
	{ stg1 = 0x01, stg2 = 0x00, stg3 = 0x01, name = "日本[1] 舞", },
	{ stg1 = 0x01, stg2 = 0x01, stg3 = 0x01, name = "日本[2] 双角1", },
	{ stg1 = 0x01, stg2 = 0x01, stg3 = 0x02, name = "日本[2] 双角2", },
	{ stg1 = 0x01, stg2 = 0x02, stg3 = 0x01, name = "日本[3] アンディ", },
	{ stg1 = 0x02, stg2 = 0x00, stg3 = 0x01, name = "香港1[1] チン", },
	{ stg1 = 0x02, stg2 = 0x01, stg3 = 0x01, name = "香港1[2] 山崎", },
	{ stg1 = 0x03, stg2 = 0x00, stg3 = 0x01, name = "韓国[1] キム", },
	{ stg1 = 0x03, stg2 = 0x01, stg3 = 0x01, name = "韓国[2] タン", },
	{ stg1 = 0x04, stg2 = 0x00, stg3 = 0x01, name = "サウスタウン[1] ギース", },
	{ stg1 = 0x04, stg2 = 0x01, stg3 = 0x01, name = "サウスタウン[2] ビリー", },
	{ stg1 = 0x05, stg2 = 0x00, stg3 = 0x01, name = "ドイツ[1] クラウザー", },
	{ stg1 = 0x05, stg2 = 0x01, stg3 = 0x01, name = "ドイツ[2] ローレンス", },
	{ stg1 = 0x06, stg2 = 0x00, stg3 = 0x01, name = "アメリカ1[1] ダック", },
	{ stg1 = 0x06, stg2 = 0x01, stg3 = 0x01, name = "アメリカ1[2] マリー", },
	{ stg1 = 0x07, stg2 = 0x00, stg3 = 0x01, name = "アメリカ2[1] テリー", },
	{ stg1 = 0x07, stg2 = 0x01, stg3 = 0x01, name = "アメリカ2[2] リック", },
	{ stg1 = 0x07, stg2 = 0x02, stg3 = 0x01, name = "アメリカ2[3] アルフレッド", },
	{ stg1 = 0x08, stg2 = 0x00, stg3 = 0x01, name = "タイ[1] ボブ", },
	{ stg1 = 0x08, stg2 = 0x01, stg3 = 0x01, name = "タイ[2] フランコ", },
	{ stg1 = 0x08, stg2 = 0x02, stg3 = 0x01, name = "タイ[3] 東", },
	{ stg1 = 0x09, stg2 = 0x00, stg3 = 0x01, name = "香港2[1] 崇秀", },
	{ stg1 = 0x09, stg2 = 0x01, stg3 = 0x01, name = "香港2[2] 崇雷", },
	{ stg1 = 0x0A, stg2 = 0x00, stg3 = 0x01, name = "NEW CHALLENGERS[1] 香緋", },
	{ stg1 = 0x0A, stg2 = 0x01, stg3 = 0x01, name = "NEW CHALLENGERS[2] ホンフゥ", },
}

db.bgm_list                      = {
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
}

--------------------------------------------------------------------------------------
-- キー入力
--------------------------------------------------------------------------------------
local _p                         = emu.lang_translate
local _f                         = function(p, name)
	local pformat = string.gsub(_p("input-name", "P%1$u"), "%%1%$u", "%%s")
	return string.gsub(_p("input-name", "%p " .. name), "%%p", string.format(pformat, p))
end
local _start                     = function(p) return _p("input-name", p == 1 and "1 Player Start" or "2 Players Start") end
local joy_k                      = {
	{ dn = _f(1, "Down"), lt = _f(1, "Left"), rt = _f(1, "Right"), up = _f(1, "Up"), a = _f(1, "A"), b = _f(1, "B"), c = _f(1, "C"), d = _f(1, "D"), st = _start(1), },
	{ dn = _f(2, "Down"), lt = _f(2, "Left"), rt = _f(2, "Right"), up = _f(2, "Up"), a = _f(2, "A"), b = _f(2, "B"), c = _f(2, "C"), d = _f(2, "D"), st = _start(2), },
}
-- ニュートラル入力
local joy_neutrala, joy_neutralp = {}, { {}, {} }
for p, ks in ipairs(joy_k) do
	for _, k in pairs(ks) do
		joy_neutrala[k], joy_neutralp[p][k] = false, false
	end
end

local cmd_funcs       = {}
cmd_funcs.make        = function(joykp, ...)
	local joy = ut.deepcopy(joy_neutrala)
	if ... then
		for _, k in ipairs({ ... }) do
			joy[joykp[k]] = true
		end
	end
	return joy
end
cmd_funcs.extract     = function(joyk, cmd_ary)
	if not cmd_ary then
		return {}
	end
	local ret, prev = {}, cmd_funcs.make
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
cmd_funcs.merge       = function(cmd_ary1, cmd_ary2)
	local keys1, keys2 = cmd_funcs.extract(joy_k[1], cmd_ary1), cmd_funcs.extract(joy_k[2], cmd_ary2)
	local ret, max = {}, math.max(#keys1, #keys2)
	for i = 1, max do
		local joy = ut.deepcopy(joy_neutrala)
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
local cmd_base        = {
	_1     = function(joykp) return cmd_funcs.make(joykp, "lt", "dn") end,
	_1a    = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "a") end,
	_1b    = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "b") end,
	_1ab   = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "a", "b") end,
	_1c    = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "c") end,
	_1ac   = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "a", "c") end,
	_1bc   = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "b", "c") end,
	_1abc  = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "a", "b", "c") end,
	_1d    = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "d") end,
	_1ad   = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "a", "d") end,
	_1bd   = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "b", "d") end,
	_1abd  = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "a", "b", "d") end,
	_1cd   = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "c", "d") end,
	_1acd  = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "a", "c", "d") end,
	_1bcd  = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "b", "c", "d") end,
	_1abcd = function(joykp) return cmd_funcs.make(joykp, "lt", "dn", "a", "b", "c", "d") end,
	_2     = function(joykp) return cmd_funcs.make(joykp, "dn") end,
	_2a    = function(joykp) return cmd_funcs.make(joykp, "dn", "a") end,
	_2b    = function(joykp) return cmd_funcs.make(joykp, "dn", "b") end,
	_2ab   = function(joykp) return cmd_funcs.make(joykp, "dn", "a", "b") end,
	_2c    = function(joykp) return cmd_funcs.make(joykp, "dn", "c") end,
	_2ac   = function(joykp) return cmd_funcs.make(joykp, "dn", "a", "c") end,
	_2bc   = function(joykp) return cmd_funcs.make(joykp, "dn", "b", "c") end,
	_2abc  = function(joykp) return cmd_funcs.make(joykp, "dn", "a", "b", "c") end,
	_2d    = function(joykp) return cmd_funcs.make(joykp, "dn", "d") end,
	_2ad   = function(joykp) return cmd_funcs.make(joykp, "dn", "a", "d") end,
	_2bd   = function(joykp) return cmd_funcs.make(joykp, "dn", "b", "d") end,
	_2abd  = function(joykp) return cmd_funcs.make(joykp, "dn", "a", "b", "d") end,
	_2cd   = function(joykp) return cmd_funcs.make(joykp, "dn", "c", "d") end,
	_2acd  = function(joykp) return cmd_funcs.make(joykp, "dn", "a", "c", "d") end,
	_2bcd  = function(joykp) return cmd_funcs.make(joykp, "dn", "b", "c", "d") end,
	_2abcd = function(joykp) return cmd_funcs.make(joykp, "dn", "a", "b", "c", "d") end,
	_3     = function(joykp) return cmd_funcs.make(joykp, "rt", "dn") end,
	_3a    = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "a") end,
	_3b    = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "b") end,
	_3ab   = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "a", "b") end,
	_3c    = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "c") end,
	_3ac   = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "a", "c") end,
	_3bc   = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "b", "c") end,
	_3abc  = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "a", "b", "c") end,
	_3d    = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "d") end,
	_3ad   = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "a", "d") end,
	_3bd   = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "b", "d") end,
	_3abd  = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "a", "b", "d") end,
	_3cd   = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "c", "d") end,
	_3acd  = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "a", "c", "d") end,
	_3bcd  = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "b", "c", "d") end,
	_3abcd = function(joykp) return cmd_funcs.make(joykp, "rt", "dn", "a", "b", "c", "d") end,
	_4     = function(joykp) return cmd_funcs.make(joykp, "lt") end,
	_4a    = function(joykp) return cmd_funcs.make(joykp, "lt", "a") end,
	_4b    = function(joykp) return cmd_funcs.make(joykp, "lt", "b") end,
	_4ab   = function(joykp) return cmd_funcs.make(joykp, "lt", "a", "b") end,
	_4c    = function(joykp) return cmd_funcs.make(joykp, "lt", "c") end,
	_4ac   = function(joykp) return cmd_funcs.make(joykp, "lt", "a", "c") end,
	_4bc   = function(joykp) return cmd_funcs.make(joykp, "lt", "b", "c") end,
	_4abc  = function(joykp) return cmd_funcs.make(joykp, "lt", "a", "b", "c") end,
	_4d    = function(joykp) return cmd_funcs.make(joykp, "lt", "d") end,
	_4ad   = function(joykp) return cmd_funcs.make(joykp, "lt", "a", "d") end,
	_4bd   = function(joykp) return cmd_funcs.make(joykp, "lt", "b", "d") end,
	_4abd  = function(joykp) return cmd_funcs.make(joykp, "lt", "a", "b", "d") end,
	_4cd   = function(joykp) return cmd_funcs.make(joykp, "lt", "c", "d") end,
	_4acd  = function(joykp) return cmd_funcs.make(joykp, "lt", "a", "c", "d") end,
	_4bcd  = function(joykp) return cmd_funcs.make(joykp, "lt", "b", "c", "d") end,
	_4abcd = function(joykp) return cmd_funcs.make(joykp, "lt", "a", "b", "c", "d") end,
	_5     = function(joykp) return cmd_funcs.make(joykp) end,
	_5a    = function(joykp) return cmd_funcs.make(joykp, "a") end,
	_5b    = function(joykp) return cmd_funcs.make(joykp, "b") end,
	_5ab   = function(joykp) return cmd_funcs.make(joykp, "a", "b") end,
	_5c    = function(joykp) return cmd_funcs.make(joykp, "c") end,
	_5ac   = function(joykp) return cmd_funcs.make(joykp, "a", "c") end,
	_5bc   = function(joykp) return cmd_funcs.make(joykp, "b", "c") end,
	_5abc  = function(joykp) return cmd_funcs.make(joykp, "a", "b", "c") end,
	_5d    = function(joykp) return cmd_funcs.make(joykp, "d") end,
	_5ad   = function(joykp) return cmd_funcs.make(joykp, "a", "d") end,
	_5bd   = function(joykp) return cmd_funcs.make(joykp, "b", "d") end,
	_5abd  = function(joykp) return cmd_funcs.make(joykp, "a", "b", "d") end,
	_5cd   = function(joykp) return cmd_funcs.make(joykp, "c", "d") end,
	_5acd  = function(joykp) return cmd_funcs.make(joykp, "a", "c", "d") end,
	_5bcd  = function(joykp) return cmd_funcs.make(joykp, "b", "c", "d") end,
	_5abcd = function(joykp) return cmd_funcs.make(joykp, "a", "b", "c", "d") end,
	_a     = function(joykp) return cmd_funcs.make(joykp, "a") end,
	_b     = function(joykp) return cmd_funcs.make(joykp, "b") end,
	_ab    = function(joykp) return cmd_funcs.make(joykp, "a", "b") end,
	_c     = function(joykp) return cmd_funcs.make(joykp, "c") end,
	_ac    = function(joykp) return cmd_funcs.make(joykp, "a", "c") end,
	_bc    = function(joykp) return cmd_funcs.make(joykp, "b", "c") end,
	_abc   = function(joykp) return cmd_funcs.make(joykp, "a", "b", "c") end,
	_d     = function(joykp) return cmd_funcs.make(joykp, "d") end,
	_ad    = function(joykp) return cmd_funcs.make(joykp, "a", "d") end,
	_bd    = function(joykp) return cmd_funcs.make(joykp, "b", "d") end,
	_abd   = function(joykp) return cmd_funcs.make(joykp, "a", "b", "d") end,
	_cd    = function(joykp) return cmd_funcs.make(joykp, "c", "d") end,
	_acd   = function(joykp) return cmd_funcs.make(joykp, "a", "c", "d") end,
	_bcd   = function(joykp) return cmd_funcs.make(joykp, "b", "c", "d") end,
	_abcd  = function(joykp) return cmd_funcs.make(joykp, "a", "b", "c", "d") end,
	_6     = function(joykp) return cmd_funcs.make(joykp, "rt") end,
	_6a    = function(joykp) return cmd_funcs.make(joykp, "rt", "a") end,
	_6b    = function(joykp) return cmd_funcs.make(joykp, "rt", "b") end,
	_6ab   = function(joykp) return cmd_funcs.make(joykp, "rt", "a", "b") end,
	_6c    = function(joykp) return cmd_funcs.make(joykp, "rt", "c") end,
	_6ac   = function(joykp) return cmd_funcs.make(joykp, "rt", "a", "c") end,
	_6bc   = function(joykp) return cmd_funcs.make(joykp, "rt", "b", "c") end,
	_6abc  = function(joykp) return cmd_funcs.make(joykp, "rt", "a", "b", "c") end,
	_6d    = function(joykp) return cmd_funcs.make(joykp, "rt", "d") end,
	_6ad   = function(joykp) return cmd_funcs.make(joykp, "rt", "a", "d") end,
	_6bd   = function(joykp) return cmd_funcs.make(joykp, "rt", "b", "d") end,
	_6abd  = function(joykp) return cmd_funcs.make(joykp, "rt", "a", "b", "d") end,
	_6cd   = function(joykp) return cmd_funcs.make(joykp, "rt", "c", "d") end,
	_6acd  = function(joykp) return cmd_funcs.make(joykp, "rt", "a", "c", "d") end,
	_6bcd  = function(joykp) return cmd_funcs.make(joykp, "rt", "b", "c", "d") end,
	_6abcd = function(joykp) return cmd_funcs.make(joykp, "rt", "a", "b", "c", "d") end,
	_7     = function(joykp) return cmd_funcs.make(joykp, "lt", "up") end,
	_7a    = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "a") end,
	_7b    = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "b") end,
	_7ab   = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "a", "b") end,
	_7c    = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "c") end,
	_7ac   = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "a", "c") end,
	_7bc   = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "b", "c") end,
	_7abc  = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "a", "b", "c") end,
	_7d    = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "d") end,
	_7ad   = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "a", "d") end,
	_7bd   = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "b", "d") end,
	_7abd  = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "a", "b", "d") end,
	_7cd   = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "c", "d") end,
	_7acd  = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "a", "c", "d") end,
	_7bcd  = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "b", "c", "d") end,
	_7abcd = function(joykp) return cmd_funcs.make(joykp, "lt", "up", "a", "b", "c", "d") end,
	_8     = function(joykp) return cmd_funcs.make(joykp, "up") end,
	_8a    = function(joykp) return cmd_funcs.make(joykp, "up", "a") end,
	_8b    = function(joykp) return cmd_funcs.make(joykp, "up", "b") end,
	_8ab   = function(joykp) return cmd_funcs.make(joykp, "up", "a", "b") end,
	_8c    = function(joykp) return cmd_funcs.make(joykp, "up", "c") end,
	_8ac   = function(joykp) return cmd_funcs.make(joykp, "up", "a", "c") end,
	_8bc   = function(joykp) return cmd_funcs.make(joykp, "up", "b", "c") end,
	_8abc  = function(joykp) return cmd_funcs.make(joykp, "up", "a", "b", "c") end,
	_8d    = function(joykp) return cmd_funcs.make(joykp, "up", "d") end,
	_8ad   = function(joykp) return cmd_funcs.make(joykp, "up", "a", "d") end,
	_8bd   = function(joykp) return cmd_funcs.make(joykp, "up", "b", "d") end,
	_8abd  = function(joykp) return cmd_funcs.make(joykp, "up", "a", "b", "d") end,
	_8cd   = function(joykp) return cmd_funcs.make(joykp, "up", "c", "d") end,
	_8acd  = function(joykp) return cmd_funcs.make(joykp, "up", "a", "c", "d") end,
	_8bcd  = function(joykp) return cmd_funcs.make(joykp, "up", "b", "c", "d") end,
	_8abcd = function(joykp) return cmd_funcs.make(joykp, "up", "a", "b", "c", "d") end,
	_9     = function(joykp) return cmd_funcs.make(joykp, "rt", "up") end,
	_9a    = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "a") end,
	_9b    = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "b") end,
	_9ab   = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "a", "b") end,
	_9c    = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "c") end,
	_9ac   = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "a", "c") end,
	_9bc   = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "b", "c") end,
	_9abc  = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "a", "b", "c") end,
	_9d    = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "d") end,
	_9ad   = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "a", "d") end,
	_9bd   = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "b", "d") end,
	_9abd  = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "a", "b", "d") end,
	_9cd   = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "c", "d") end,
	_9acd  = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "a", "c", "d") end,
	_9bcd  = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "b", "c", "d") end,
	_9abcd = function(joykp) return cmd_funcs.make(joykp, "rt", "up", "a", "b", "c", "d") end,
}
local research_cmd    = function()
	local ret = ut.new_filled_table(8, {})
	-- TODO: 変数設定
	--[[
	ret[1] = cmd_funcs.merge( -- ボブ対クラウザー100% ラグがでると落ちる
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

	ret[1] = cmd_funcs.merge( -- 対ビリー 自動ガード+リバサ立A向けの炎の種馬相打ちコンボ
		{ _4, 11, _2a, 7, _2, 1, _3, 2, _6, 7, _6a, 2, _5, 38, _1a, 15, _5, 7, _6ac, 3, _5, 13, _1a, 6, _5, 16, _5c, 7, _5, 12, _5c, 5, _5, 12, _4, 3, _2, 3, _1c, 3, _5, 76, _4, 15, _5, 16, _2, 3, _5c, 2, _5, 1, },
		{ _5, }
	)
	ret[1] = cmd_funcs.merge( -- 対アンディ 自動ガード+リバサ立A向けの炎の種馬相打ちコンボ
		{ _4, 11, _2a, 4, _2, 1, _3, 2, _6, 7, _6a, 2, _5, 40, _2a, 6, _2c, 5, _5, 5, _6ac, 3, _5, 28, _1a, 6, _5, 16, _5c, 7, _5, 20, _5c, 5, _5, 23, _4, 6, _2, 4, _1c, 3, _5, 68, _5b, 3, _5, 4, _5b, 4, _5, 33, _2, 3, _5c, 2, _5, 1, },
		{ _5, }
	)
	ret[1] = cmd_funcs.merge( -- 対ギース 自動ガード+リバサ下A向けの炎の種馬相打ちコンボ
		{ _4, 11, _2a, 4, _2, 1, _3, 2, _6, 7, _6a, 2, _5, 38, _2b, 6, _2c, 5, _5, 9, _6ac, 3, _5, 28, _1a, 6, _5, 16, _5c, 7, _5, 15, _5c, 5, _5, 15, _4, 6, _2, 4, _1c, 3, _5, 76, _4, 15, _5, 16, _2, 3, _5c, 2, _5, 1, },
		{ _5, }
	)

	ret[1] = cmd_funcs.merge(  -- ガード解除直前のNのあと2とNの繰り返しでガード硬直延長,をさらに投げる
		{ _8, _5, 46, _6, 15, _5, 13, _4, _1, 5, _2, 2, _3, 4, _6, 6, _4c, 4, _c, 102, _5, 36, _c, 12, _5, _c, 11, _5, },
		{ _5, }
	)

	ret[1] = cmd_funcs.merge(  -- ガード解除直前のNのあと2とNの繰り返しでガード硬直延長,をさらに投げる
		{ _8, _5, 46, _1, 20, _2, 27, _5, 6, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1,
		_5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1,},
		{ _8, _5, 46, _2b, _5, 12, _2b, _5, 50, _4, _5, _4, _5, _7, 6, _7d, _5, 15, _c, _5, }
	)
	ret[1] = cmd_funcs.merge(  -- ガード解除直前のNのあと2とNの繰り返しでガード硬直延長,をさらに投げる
		{ _8, _5, 46, _1, 20, _2, 27, _5, 6, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1,
		_5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1,},
		{ _8, _5, 46, _2b, _5, 12, _2b, _5, 50, _4, _5, _4, _5, _7, 6, _7d, _5, 41, _c, _5, }
	)

	ret[1] = cmd_funcs.merge(  -- ガード解除直前のNでガード硬直延長
		{ _8, _5, 46, _1, 20, _2, 27, _5, },
		{ _8, _5, 46, _2b, _5, 12, _2b, _5, }
	)
	ret[1] = cmd_funcs.merge(  -- ガード解除直前のNのあと2とNの繰り返しでガード硬直延長,をさらに投げる
		{ _8, _5, 46, _1, 20, _2, 27, _5, 6, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1,
		_5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1, _5, 2, _2, 1,},
		{ _8, _5, 46, _2b, _5, 12, _2b, _5, 42, _4, 20, _4c, _5, }
	)

	-- LINNさんネタの確認 ... リバサバクステキャンセルサイクロンで重ね飛燕失脚の迎撃
	ret[1] = cmd_funcs.merge( -- バクステ回避
		{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
		{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, })
	ret[2] = cmd_funcs.merge( -- サイクロン成立
		{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
		{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 2, _5c, })
	ret[3] = cmd_funcs.merge( -- サイクロン成立
		{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
		{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 3, _5c, })
	ret[4] = cmd_funcs.merge( -- サイクロン成立
		{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
		{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 4, _c, })
	ret[5] = cmd_funcs.merge( -- サイクロン成立
		{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
		{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 5, _c, })
	ret[3] = cmd_funcs.merge( -- サイクロン不成立
		{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
		{ _8, _5, 46, _2, 15, _2 , _5, 111, _8, _4, _2, _6, _5, _4, _5, _4, _5, 6, _c, })
	ret[4] = cmd_funcs.merge( -- サイクロン不成立
		{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
		{ _8, _5, 46, _2, 15, _2 , _5, 110, _8, _4, _2, _6, _5, _4, _5, _4, _5, 7, _c, })
	ret[1] = cmd_funcs.merge( -- リバサバクステキャンセルアンリミ
		{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, },
		{ _8, _5, 46, _2, 15, _2 , _5, 110, _6, _3, _2, _1, _4, _6, _5, _4, _5, _4, _5, 5, _a, })
	ret[1] = cmd_funcs.merge( -- リバササイクロンが飛燕失脚を投げられない状態でCがでて喰らう
		{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, }, -- 通常投げ→飛燕失脚重ね
		{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 1, _c, })
	ret[2] = cmd_funcs.merge( -- リバササイクロンが飛燕失脚を投げられない状態でバクステがでる
		{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, }, -- 通常投げ→飛燕失脚重ね
		{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 2, _c, })
	ret[3] = cmd_funcs.merge( -- リバサバクステキャンセルサイクロン
		{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, }, -- 通常投げ→飛燕失脚重ね
		{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 3, _c, })
	ret[4] = cmd_funcs.merge( -- リバサバクステキャンセルサイクロン
		{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, }, -- 通常投げ→飛燕失脚重ね
		{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 4, _c, })
	ret[5] = cmd_funcs.merge( -- リバサバクステキャンセルサイクロン
		{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, }, -- 通常投げ→飛燕失脚重ね
		{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 5, _c, })
	ret[1] = cmd_funcs.merge( -- ガー不飛燕失脚 リバサバクステキャンセルサイクロン
		{ _8, _5, 46, _6, 15, _6c, _5,  87, _6, _6a, }, -- 通常投げ→飛燕失脚重ね
		{ _8, _5, 46, _2, 15, _2 , _5, 112, _8, _4, _2, _6, _5, _4, _5, _4, _5, 6, _5c, })
	ret[2] = cmd_funcs.merge( -- ガー不ジャンプB リバサバクステキャンセルレイブ
		{ _8, _5, 46, _2a, _5, 5, _2c, _5, 15, _6, _5, _4, _1, _2, _3, _bc, _5, 155, _9, _5, 29, _b, _1, 81, _5, },
		{ _8, _5, 46, _2, 15, _2 , _5, 191, _4, _1, _2, _3, _6, _4, _5, _6, _5, _6, _5, 4, _a, })
	ret[2] = cmd_funcs.merge( -- ガー不ジャンプB リバサバクステキャンセルレイブ
		{ _8, _5, 46, _2a, _5, 5, _2c, _5, 15, _6, _5, _4, _1, _2, _3, _bc, _5, 155, _9, _5, 29, _b, _1, 81, _1, 289, _6, _5, _4, _1, _2, _3, _5, _4, _5, _4, _5, 3, _bc, _5, 178, _4, 23, _5, 26, _cd, _5, 51, _2, _1, _4, _5, _4, _5, _4, 3, _c, _5, 40, _cd, _5 },
		{ _8, _5, 46, _2, 15, _2 , _5, 191, _4, _1, _2, _3, _6, _4, _5, _6, _5, _6, _5, 4, _a, _5, 340, _4a, _5, 270, _6, _2, _3, _6, _c, _5, 76, _cd, _5  })
	ret[3] = cmd_funcs.merge( -- ガー不ジャンプB リバサバクステキャンセル真空投げ
		{ _8, _5, 46, _2a, _5, 5, _2c, _5, 15, _6, _5, _4, _1, _2, _3, _bc, _5, 155, _9, _5, 29, _b, _1, 81, _5, },
		{ _8, _5, 46, _2, 15, _2 , _5, 191, _2, _4, _8, _6, _2, _4, _5, _6, _5, _6, _5, 4, _5a, })
	]]
	return ret
end

db.joy_k              = joy_k
db.joy_neutrala       = joy_neutrala
db.joy_neutralp       = joy_neutralp
db.cmd_funcs          = cmd_funcs
db.cmd_base           = cmd_base
db.research_cmd       = research_cmd()

-- 削りダメージ補正
local chip_types      = {
	zero = { name = "0", calc = function(_) return 0 end },
	rshift4 = { name = "1/16", calc = function(pure_dmg) return pure_dmg and math.max(1, 0xFF & (pure_dmg >> 4)) or 0 end },
	rshift5 = { name = "1/32", calc = function(pure_dmg) return pure_dmg and math.max(1, 0xFF & (pure_dmg >> 5)) or 0 end },
}
-- 削りダメージ計算種別 補正処理の分岐先の種類分用意する
local chip_type_table = {
	chip_types.zero, --  0 ダメージ無し
	chip_types.zero, --  1 ダメージ無し
	chip_types.rshift4, --  2 1/16
	chip_types.rshift4, --  3 1/16
	chip_types.zero, --  4 ダメージ無し
	chip_types.zero, --  5 ダメージ無し
	chip_types.rshift4, --  6 1/16
	chip_types.rshift5, --  7 1/32
	chip_types.rshift5, --  8 1/32
	chip_types.zero, --  9 ダメージ無し
	chip_types.zero, -- 10 ダメージ無し
	chip_types.rshift4, -- 11 1/16
	chip_types.rshift4, -- 12 1/16
	chip_types.rshift4, -- 13 1/16
	chip_types.rshift4, -- 14 1/16
	chip_types.rshift4, -- 15 1/16
	chip_types.rshift4, -- 16 1/16
}
db.chip_type_table    = chip_type_table
db.calc_chip          = function(addr, damage)
	local chip_type = db.chip_type_table[addr]
	return chip_type.calc(damage)
end

--------------------------------------------------------------------------------------
-- 描画用データ
--------------------------------------------------------------------------------------
local obj_names       = {
	[0x20204c4556455220] = "  LEVER ",
	[0x2020502053414e20] = "  P SAN ",
	[0x20425554544f4e20] = " BUTTON ",
	[0x20454e44494e4720] = " ENDING ",
	[0x20455820204b4f20] = " EX  KO ",
	[0x204d4f5448455220] = " MOTHER ",
	[0x2050204348414e20] = " P CHAN ",
	[0x20534841444f5720] = " SHADOW ",
	[0x20544c204d41494e] = " TL MAIN",
	[0x205a414e5a4f2031] = " ZANZO 1",
	[0x205a414e5a4f2032] = " ZANZO 2",
	[0x205a414e5a4f2033] = " ZANZO 3",
	[0x205a414e5a4f2034] = " ZANZO 4",
	[0x205a414e5a4f2035] = " ZANZO 5",
	[0x205a414e5a4f2036] = " ZANZO 6",
	[0x205a414e5a4f2037] = " ZANZO 7",
	[0x205a414e5a4f2038] = " ZANZO 8",
	[0x3c57494e444f573e] = "<WINDOW>",
	[0x414c504852454420] = "ALPHRED ",
	[0x4152454120424547] = "AREA BEG",
	[0x4241434b204f424a] = "BACK OBJ",
	[0x424c4f4f44202020] = "BLOOD   ",
	[0x424e4420534d4f4b] = "BND SMOK",
	[0x42544e2041202020] = "BTN A   ",
	[0x42544e2042202020] = "BTN B   ",
	[0x42544e2043202020] = "BTN C   ",
	[0x42544e2044202020] = "BTN D   ",
	[0x4348415220535020] = "CHAR SP ",
	[0x434d422044415441] = "CMB DATA",
	[0x434d42204f424a20] = "CMB OBJ ",
	[0x434d42204f424a31] = "CMB OBJ1",
	[0x434d42204f424a33] = "CMB OBJ3",
	[0x434d422053595320] = "CMB SYS ",
	[0x434d424f204d4553] = "CMBO MES",
	[0x434e54434f554e54] = "CNTCOUNT",
	[0x434f4c2043484720] = "COL CHG ",
	[0x434f4c204354524c] = "COL CTRL",
	[0x434f4e54494e5545] = "CONTINUE",
	[0x435552534f4c2020] = "CURSOL  ",
	[0x442d50414c474f44] = "D-PALGOD",
	[0x44454b4143484152] = "DEKACHAR",
	[0x4546203373657475] = "EF 3setu",
	[0x454620486973686f] = "EF Hisho",
	[0x455820524f554e44] = "EX ROUND",
	[0x4649582048494445] = "FIX HIDE",
	[0x464c415348202020] = "FLASH   ",
	[0x47414d454f564552] = "GAMEOVER",
	[0x4741524f55322020] = "GAROU2  ",
	[0x4743414e204d4553] = "GCAN MES",
	[0x475250204c495354] = "GRP LIST",
	[0x484f5732504c4159] = "HOW2PLAY",
	[0x494e545255444552] = "INTRUDER",
	[0x4c49535420454420] = "LIST ED ",
	[0x4d41494e4d454e55] = "MAINMENU",
	[0x4d454d5345545550] = "MEMSETUP",
	[0x4d45535341474520] = "MESSAGE ",
	[0x4d4f44452053454c] = "MODE SEL",
	[0x4e414d4520454e54] = "NAME ENT",
	[0x4e414d45204d4153] = "NAME MAS",
	[0x4e414d454f564552] = "NAMEOVER",
	[0x4e554d2052414e4b] = "NUM RANK",
	[0x4f424a2041444420] = "OBJ ADD ",
	[0x4f424a2041444433] = "OBJ ADD3",
	[0x4f424a204354524c] = "OBJ CTRL",
	[0x4f424a20454e4449] = "OBJ ENDI",
	[0x4f424a204e4f524d] = "OBJ NORM",
	[0x4f424a4745455345] = "OBJGEESE",
	[0x502053454c454354] = "P SELECT",
	[0x50414c20474f4420] = "PAL GOD ",
	[0x50414c204c4f4f50] = "PAL LOOP",
	[0x50414c2050414c20] = "PAL PAL ",
	[0x50414c20524f4c4c] = "PAL ROLL",
	[0x50414e454c202020] = "PANEL   ",
	[0x50414e454c203031] = "PANEL 01",
	[0x50414e454c203032] = "PANEL 02",
	[0x50414e454c203033] = "PANEL 03",
	[0x50414e454c203034] = "PANEL 04",
	[0x50414e454c203035] = "PANEL 05",
	[0x50414e454c203036] = "PANEL 06",
	[0x50414e454c203037] = "PANEL 07",
	[0x50414e454c203038] = "PANEL 08",
	[0x50414e454c203039] = "PANEL 09",
	[0x50414e454c203041] = "PANEL 0A",
	[0x50414e454c203042] = "PANEL 0B",
	[0x50414e454c203043] = "PANEL 0C",
	[0x50414e454c203044] = "PANEL 0D",
	[0x50414e454c203045] = "PANEL 0E",
	[0x50414e454c203046] = "PANEL 0F",
	[0x50414e454c203130] = "PANEL 10",
	[0x50414e454c203131] = "PANEL 11",
	[0x50414e454c203132] = "PANEL 12",
	[0x50414e454c203133] = "PANEL 13",
	[0x50414e454c203134] = "PANEL 14",
	[0x50414e454c203135] = "PANEL 15",
	[0x50414e454c203136] = "PANEL 16",
	[0x50414e454c203137] = "PANEL 17",
	[0x50414e454c203138] = "PANEL 18",
	[0x50504f57204d4553] = "PPOW MES",
	[0x50504f57324d4553] = "PPOW2MES",
	[0x52414e4b44454d4f] = "RANKDEMO",
	[0x52414e4b4a554447] = "RANKJUDG",
	[0x5242322000000000] = "RB2     ",
	[0x5242322052423253] = "RB2 RB2S",
	[0x5242325300000000] = "RB2S    ",
	[0x5245414c424f5554] = "REALBOUT",
	[0x52455354204e414d] = "REST NAM",
	[0x5245535420535020] = "REST SP ",
	[0x52455354434f554e] = "RESTCOUN",
	[0x52455652204d4553] = "REVR MES",
	[0x524f4f544c495354] = "ROOTLIST",
	[0x53454c4620494e54] = "SELF INT",
	[0x5345512053454e44] = "SEQ SEND",
	[0x534552204c4f474f] = "SER LOGO",
	[0x5345525649434520] = "SERVICE ",
	[0x5354414745205345] = "STAGE SE",
	[0x544845204e455743] = "THE NEWC",
	[0x54494d4552455354] = "TIMEREST",
	[0x54494d45544f4f4c] = "TIMETOOL",
	[0x54494d4745444954] = "TIMGEDIT",
	[0x5653204253545550] = "VS BSTUP",
	[0x582053454c454354] = "X SELECT",
	[0x59455320204e4f20] = "YES  NO ",
	[0x00c0042600c00426] = "", -- how to playのダッシュ中キャラ
}
local p_chan          = {
	[0x2020502053414e20] = "  P SAN ",
	[0x2050204348414e20] = " P CHAN ",
}
for k, v in pairs(ut.deepcopy(obj_names)) do
	obj_names[0xFFFFFFFF & k] = v
end
local get_obj_name = function(value)
	local name, bak = obj_names[value], value
	if name then return name, false end
	local a = {}
	while value > 0x1F do
		table.insert(a, 1, string.char(value & 0xFF))
		value = value >> 8
	end
	name = table.concat(a, "")
	obj_names[bak] = name
	return name, true
end
local shadow_addr = ut.new_set(0x17300)
local nobg_addr = ut.new_set(
--0x3bb12, -- ヒットエフェクト へび
--0x3bb88, -- ヒットエフェクト バーン
--0x3576e, -- ヒットエフェクト 電撃、燃える 舞の桜
	0x6114a, -- ヒットエフェクト
	0x60b72, -- 弾
	0x3580a, -- 電撃、燃える

	0x25666, -- ヒット数
	0x256b2, -- ヒット数
	0x256e6, -- ヒット数
	--0x15a8a, -- アンディステージの花びら
	--0x15ac6, -- アンディステージの花びら
	--0x15d7a, -- 双角ステージの雨
	0x17300 -- 影、アンディステージの花びら
--0x17472, -- 水たまり反射
--0x17738, -- フランコステージのカメラのフラッシュ
--0x261A0, -- 双角ステージの雨
--0x6114a -- PPOW MES
)
db.get_obj_name = get_obj_name
db.p_chan = p_chan
db.nobg_addr = nobg_addr
db.shadow_addr = shadow_addr


-- BSゲージ消費と無敵フレームデータのオリジナル
db.bs_data = {
	0x981C,
	0x981C,
	0x98FF,
	0x98FF,
	0x98FF,
	0x980E,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x98FF,
	0x9810,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x98FF,
	0x98FF,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x98FF,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x9418,
	0x942A,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x982A,
	0x98FF,
	0x98FF,
	0x0000,
	0x0000,
	0x9810,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x9818,
	0x0000,
	0x98FF,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x98FF,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x9846,
	0x0000,
	0x0000,
	0x9810,
	0x0000,
	0x0000,
	0x9818,
	0x9814,
	0x9814,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x0000,
	0x98FF,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x9812,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x98FF,
	0x98FF,
	0x0000,
	0x98FF,
	0x98FF,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x98FF,
	0x98FF,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x0000,
	0x9814,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x98FF,
	0x0000,
	0x0000,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x0000,
	0x9818,
	0x98FF,
	0x0000,
	0x0000,
	0x9EFF,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x0000,
	0x9807,
	0x981A,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x98FF,
	0x0000,
	0x98FF,
	0x0000,
	0x0000,
	0x9E0E,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x0000,
	0x0000,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x9818,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x0000,
	0x98FF,
	0x0000,
	0x98FF,
	0x9814,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x98FF,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x98FF,
	0x98FF,
	0x98FF,
	0x98FF,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000,
	0x0000, }

db.ignore_a5_pc = ut.new_set(
	0x3C904,
	0x3CE74,
	0x3DB9A,
	0x3DE8E,
	0x3F9B0,
	0x40540,
	0x4085E,
	0x40950,
	0x40E1C,
	0x414A4,
	0x4154C,
	0x415E0,
	0x41760,
	0x42132,
	0x434DA,
	0x43818,
	0x451D4,
	0x4527C,
	0x4530E,
	0x456A2,
	0x4583E,
	0x46252,
	0x464FE,
	0x469B6,
	0x46A8A,
	0x472B4,
	0x48150,
	0x481E4,
	0x48CA2,
	0x4909C,
	0x49120,
	0x49950,
	0x49F30,
	0x49F58,
	0x4A2E0,
	0x4A484,
	0x4A81A,
	0x4AACE,
	0x5486E,
	0x5487A,
	0x54886,
	0x54890,
	0x548AE,
	0x548C2,
	0x548CC,
	0x548D6,
	0x548FC,
	0x54906,
	0x5491C,
	0x54932,
	0x5496C,
	0x54DD0,
	0x54DEE,
	0x54E0C,
	0x54E2A,
	0x54E48,
	0x54E66,
	0x54EA8,
	0x54F5C,
	0x54FD6,
	0x54FFA,
	0x5501E,
	0x55042,
	0x55066,
	0x5508A,
	0x550AE,
	0x5513A,
	0x551A6,
	0x55222,
	0x5525C,
	0x552D8,
	0x55324,
	0x553F6,
	0x5543E,
	0x5547A,
	0x55508,
	0x5556A,
	0x5559E,
	0x555EA,
	0x55648,
	0x55724,
	0x5596C,
	0x55A08,
	0x55CC8,
	0x5883A,
	0x5CD06,
	0x5CF38,
	-- move.b
	0x4174C,
	0x420FC,
	0x42A60,
	0x4692C,
	0x67688,
	0x67726)

print("data loaded")
return db
