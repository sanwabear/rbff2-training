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
local exports            = {}
exports.name             = "rbff2training"
exports.version          = "0.0.1"
exports.description      = "RBFF2 Training"
exports.license          = "MIT License"
exports.author           = { name = "Sanwabear" }

local ut                 = require("rbff2training/util")
local db                 = require("rbff2training/data")
local UTF8toSJIS         = require("rbff2training/UTF8toSJIS")

local save_file          = function(path, score)
	local file, err = io.open(UTF8toSJIS:UTF8_to_SJIS_str_cnv(path), 'w') -- windows向け
	if file then
		file:write(tostring(score))
		file:close()
	else
		print("error:", err)
	end
end
--save_file(ut.cur_dir() .. "/plugins/rbff2training/テスト.txt", "")

-- MAMEのLuaオブジェクトの変数と初期化処理
local man
local machine
local cpu
local pgm
local scr
local ioports
local debugger
local base_path
local setup_emu          = function()
	man = manager
	machine = man.machine
	cpu = machine.devices[":maincpu"]
	-- for k, v in pairs(cpu.state) do ut.printf("%s %s", k ,v ) end
	pgm = cpu.spaces["program"]
	scr = machine.screens:at(1)
	ioports = man.machine.ioport.ports
	--[[
	for pname, port in pairs(ioports) do
		for fname, field in pairs(port.fields) do ut.printf("%s %s", pname, fname) end
	end
	for p, pk in ipairs(data.joy_k) do
		for _, name in pairs(pk) do
			ut.printf("%s %s %s", ":edge:joy:JOY" .. p, name, ioports[":edge:joy:JOY" .. p].fields[name])
		end
	end
	]]
	debugger = machine.debugger
	base_path = function()
		local base = emu.subst_env(man.options.entries.homepath:value():match('([^;]+)')) .. '/plugins/' .. exports.name
		local dir = ut.cur_dir()
		return dir .. "/" .. base
	end
end

local rbff2              = exports

-- ヒット効果
local hit_effect_addrs   = { 0 }
local hit_effect_menus   = { "OFF" }

-- ヒット時のシステム内での中間処理による停止アドレス
local hit_system_stops   = {}

-- 判定種類
local frame_attack_types = db.frame_attack_types
-- ヒット処理の飛び先 家庭用版 0x13120 からのデータテーブル 5種類
local possible_types     = {
	none      = 0,  -- 常に判定しない
	same_line = 2 ^ 0, -- 同一ライン同士なら判定する
	diff_line = 2 ^ 1, -- 異なるライン同士で判定する
	air_onry  = 2 ^ 2, -- 相手が空中にいれば判定する
	unknown   = 2 ^ 3, -- 不明
}
-- 同一ライン、異なるラインの両方で判定する
possible_types.both_line = possible_types.same_line | possible_types.diff_line
local get_top_type       = function(top, types)
	local type = 0
	for _, t in ipairs(types) do
		if t.top and top <= t.top then type = type | t.act_type end
	end
	return type
end
local get_bottom_type    = function(bottom, types)
	local type = 0
	for _, t in ipairs(types) do
		if t.bottom and bottom >= t.bottom then type = type | t.act_type end
	end
	return type
end
local get_dodge          = function(p, box, top, bottom)
	local dodge = 0
	if p.sway_status == 0 then                                     -- メインライン
		dodge = get_top_type(top, db.hurt_dodge_types) | get_bottom_type(bottom, db.hurt_dodge_types)
		if type == db.box_types.hurt1 or type == db.box_types.hurt2 then -- 食らい1 食らい2
		elseif type == db.box_types.down_otg then                  -- 食らい(ダウン追撃のみ可)
		elseif type == db.box_types.launch then                    -- 食らい(空中追撃のみ可)
		elseif type == db.box_types.hurt3 then                     -- 食らい(対ライン上攻撃) 対メイン上段無敵
			dodge = dodge | (p.sway_status == 0 and frame_attack_types.main_high or 0)
		elseif type == db.box_types.hurt4 then                     -- 食らい(対ライン下攻撃) 対メイン下段無敵
			dodge = dodge | (p.sway_status == 0 and frame_attack_types.main_low or 0)
		end
	elseif type == db.box_types.sway_hurt1 or type == db.box_types.sway_hurt2 then
		dodge = dodge | frame_attack_types.main                                -- 食らい(スウェー中) メイン無敵
		dodge = dodge | (box.real_top <= 32 and frame_attack_types.sway_high or 0) -- 上半身無敵
		dodge = dodge | (box.real_bottom <= 60 and frame_attack_types.sway_low or 0) -- 下半身無敵
	end
	return dodge
end

local hitbox_possibles   = {
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
local hitbox_grab_bits   = {
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
local hitbox_grab_types  = {
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

-- コマンド入力状態
local input_state_types  = db.input_state_types
local input_states       = db.input_states
local input_state_col    = db.input_state_col

local chip_types         = db.chip_types

-- メニュー用変数
local menu               = {
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

	stgs = db.stage_list,
	bgms = db.bgm_list,

	labels = {
		fix_scr_tops = { "OFF" },
		chars        = {},
		stgs         = {},
		bgms         = {},
		off_on       = { "OFF", "ON" }
	},
}
menu.labels.chars        = db.char_names
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
local mem                       = {
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
-- プログラム改変
local mod                       = {
	p1_patch     = function()
		local base = base_path() .. '/patch/rom/'
		local filename = "char1-p1.pat"
		local patch = base .. emu.romname() .. '/' .. filename
		if not ut.is_file(patch) then ut.printf("%s NOT found", patch) end
		return ut.apply_patch_file(pgm, patch, true)
	end,
	aes          = function()
		mem.wd16(0x10FE32, 0x0000) -- 強制的に家庭用モードに変更
	end,
	bugfix       = function()
		-- H POWERの表示バグを修正する 無駄な3段表示から2段表示へ
		mem.wd8(0x25DB3, 0x1)
		-- 簡易超必ONのときにダックのブレイクスパイラルブラザー（BRも）が出るようにする
		mem.wd16(0x0CACC8, 0xC37C)
		-- デバッグDIPによる自動アンリミのバグ修正
		mem.wd8(fix_addr(0x049951), 0x2)
		mem.wd8(fix_addr(0x049947), 0x9)
		-- 逆襲拳、サドマゾの初段で相手の状態変更しない（相手が投げられなくなる事象が解消する）
		-- mem.wd8(0x57F43, 0x00)
	end,
	training     = function()
		mem.wd16(0x1F3BC, 0x4E75) -- 1Pのスコア表示をすぐ抜ける
		mem.wd16(0x1F550, 0x4E75) -- 2Pのスコア表示をすぐ抜ける
		mem.wd32(0xD238, 0x4E714E71) -- 家庭用モードでのクレジット消費をNOPにする
		mem.wd8(0x62E9D, 0x00)  -- 乱入されても常にキャラ選択できる
		-- 対CPU1体目でボスキャラも選択できるようにする サンキューヒマニトさん
		mem.wd8(0x633EE, 0x60)  -- CPUのキャラテーブルをプレイヤーと同じにする
		mem.wd8(0x63440, 0x60)  -- CPUの座標テーブルをプレイヤーと同じにする
		mem.wd32(0x62FF4, 0x4E714E71) -- PLのカーソル座標修正をNOPにする
		mem.wd32(0x62FF8, 0x4E714E71) -- PLのカーソル座標修正をNOPにする
		mem.wd8(0x62EA6, 0x60)  -- CPU選択時にアイコンを減らすのを無効化
		mem.wd32(0x63004, 0x4E714E71) -- PLのカーソル座標修正をNOPにする
		-- キャラ選択の時間減らす処理をNOPにする
		mem.wd16(0x63336, 0x4E71)
		mem.wd16(0x63338, 0x4E71)
		--時間の値にアイコン用のオフセット値を改変して空表示にする
		-- 0632D0: 004B -- キャラ選択の時間の内部タイマー初期値1 デフォは4B=75フレーム
		-- 063332: 004B -- キャラ選択の時間の内部タイマー初期値2 デフォは4B=75フレーム
		mem.wd16(0x632DC, 0x0DD7)
		-- 常にCPUレベルMAX
		--[[ RAM改変によるCPUレベル MAX（ロムハックのほうが楽）
		mem.w16(0x10E792, 0x0007) -- maincpu.pw@10E792=0007
		mem.w16(0x10E796, 0x0007) -- maincpu.pw@10E796=0008
		]]
		mem.wd32(fix_addr(0x0500E8), 0x303C0007)
		mem.wd32(fix_addr(0x050118), 0x3E3C0007)
		mem.wd32(fix_addr(0x050150), 0x303C0007)
		mem.wd32(fix_addr(0x0501A8), 0x303C0007)
		mem.wd32(fix_addr(0x0501CE), 0x303C0007)
		-- 対戦の双角ステージをビリーステージに変更する（MVSと家庭用共通）
		mem.wd16(0xF290, 0x0004)
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
		--[[ 未適用ハック よそで見つけたチート
		-- https://www.neo-geo.com/forums/index.php?threads/universe-bios-released-good-news-for-mvs-owners.41967/page-7
		mem.wd8 (10E003, 0x0C)       -- Auto SDM combo (RB2) 0x56D98A
		mem.wd32(1004D5, 0x46A70500) -- 1P Crazy Yamazaki Return (now he can throw projectile "anytime" with some other bug) 0x55FE5C
		mem.wd16(1004BF, 0x3CC1)     -- 1P Level 2 Blue Mary 0x55FE46
		]]
	end,
	fast_select  = function()
		--[[
		010668: 0C6C FFEF 0022           cmpi.w  #-$11, ($22,A4)                     ; THE CHALLENGER表示のチェック。
		01066E: 6704                     beq     $10674                              ; braにしてチェックを飛ばすとすぐにキャラ選択にいく
		010670: 4E75                     rts                                         ; bp 01066E,1,{PC=00F05E;g} にすると乱入の割り込みからラウンド開始前へ
		010672: 4E71                     nop                                         ; 4EF9 0000 F05E
		]]
		mem.wd32(0x10668, 0xC6CFFEF) -- 元の乱入処理
		mem.wd32(0x1066C, 0x226704) -- 元の乱入処理
		mem.wd8(0x1066E, 0x60) -- 乱入時にTHE CHALLENGER表示をさせない
	end,
	fast_restart = function()
		mem.wd32(0x10668, 0x4EF90000) -- FIGHT表示から対戦開始(F05E)へ飛ばす
		mem.wd32(0x1066C, 0xF33A4E71) -- FIGHT表示から対戦開始
	end,
	all_bs       = function(enabled)
		if enabled then
			-- 全必殺技BS可能
			for addr = 0x85980, 0x85CE8, 2 do mem.wd16(addr, 0x007F|0x8000) end -- 0パワー消費 無敵7Fフレーム
			mem.wd32(0x39F24, 0x4E714E71)                              -- 6600 0014 nop化
		else
			local addr = 0x85980
			for _, b16 in ipairs(db.bs_data) do
				mem.wd16(addr, b16)
				addr = addr + 2
			end
			mem.wd32(0x39F24, 0x66000014)
		end
	end,
	easy_move    = {
		real_counter = function(mode) -- 1:OFF 2:ジャーマン 3:フェイスロック 4:投げっぱなしジャーマン"
			if mode > 1 then
				mem.wd16(0x413EE, 0x1C3C) -- ボタン読み込みをボタンデータ設定に変更
				mem.wd16(0x413F0, 0x10 * (2 ^ (mode - 2)))
				mem.wd16(0x413F2, 0x4E71)
			else
				mem.wd32(0x413EE, 0x4EB90002)
				mem.wd16(0x413F2, 0x6396)
			end
		end,
		esaka_check = function(mode)                         -- 詠酒の条件チェックを飛ばす 1:OFF
			mem.wd32(0x23748, mode == 2 and 0x4E714E71 or 0x6E00FC6A) -- 2:技種類と距離チェック飛ばす
			mem.wd32(0x236FC, mode == 3 and 0x604E4E71 or 0x6400FCB6) -- 3:距離チェックNOP
		end,
		taneuma_finish = function(enabled)                   -- 自動 炎の種馬
			mem.wd16(0x4094A, enabled and 0x6018 or 0x6704)  -- 連打チェックを飛ばす
		end,
		fast_kadenzer = function(enabled)                    -- 必勝！逆襲拳1発キャッチカデンツァ
			mem.wd16(0x4098C, enabled and 0x7003 or 0x5210)  -- カウンターに3を直接設定する
		end,
		katsu_ca = function(enabled)                         -- 自動喝CA
			mem.wd8(0x3F94C, enabled and 0x60 or 0x67)       -- 入力チェックを飛ばす
			mem.wd16(0x3F986, enabled and 0x4E71 or 0x6628)  -- 入力チェックをNOPに
		end,
		kara_ca = function(enabled)                          -- 空振りCAできる
			mem.wd8(0x2FA5E, enabled and 0x60 or 0x67)       -- テーブルチェックを飛ばす
			--[[ 未適用
			-- 逆にFFにしても個別にCA派生を判定している処理があるため単純に全不可にはできない。
			-- オリジナル（家庭用）
			-- maincpu.rd@02FA72=00000000
			-- maincpu.rd@02FA76=00000000
			-- maincpu.rd@02FA7A=FFFFFFFF
			-- maincpu.rd@02FA7E=00FFFF00
			-- maincpu.rw@02FA82=FFFF
			パッチ（00をFFにするとヒット時限定になる）
			for i = 0x02FA72, 0x02FA82 do mem.wd8(i, 0x00) end
			]]
		end,
		rapid = function(mode)
			-- 連キャン、必キャン可否テーブルに連キャンデータを設定する。C0が必、D0で連。
			for i = 0x085138, 0x08591F do mem.wd8(i, 0xD0) end
		end,
		triple_ecstasy = function(enabled)    -- 自動マリートリプルエクスタシー
			mem.wd8(0x41D00, enabled and 0x60 or 0x66) -- デバッグDIPチェックを飛ばす
		end,
	},
	camerawork   = function(enabled)
		if enabled then
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
		mem.wd8(0x13AF0, enabled and 0x67 or 0x60) -- 013AF0: 6700 0036 beq $13b28
		mem.wd8(0x13B9A, enabled and 0x6A or 0x60) -- 013B9A: 6A04      bpl $13ba0
	end,
}
local in_match                  = false -- 対戦画面のときtrue
local in_player_select          = false -- プレイヤー選択画面のときtrue
local p_space                   = 0     -- 1Pと2Pの間隔
local prev_space                = 0     -- 1Pと2Pの間隔(前フレーム)

local screen                    = {
	offset_x = 0x20,
	offset_z = 0x24,
	offset_y = 0x28,
	left     = 0,
	top      = 0,
}
local hide_options              = {
	none = 0,
	effect = 2 ^ 0,   -- ヒットマークなど
	shadow1 = 2 ^ 1,  -- 影
	shadow2 = 2 ^ 2,  -- 双角ステージの反射→影
	meters = 2 ^ 3,   -- ゲージ
	background = 2 ^ 4, -- 背景
	p_chan = 2 ^ 5,   -- Pちゃん
	p1_phantasm = 2 ^ 6, -- 1P残像
	p1_effect = 2 ^ 7, -- 1Pエフェクト
	p1_char = 2 ^ 8,  -- 1Pキャラ
	p2_phantasm = 2 ^ 9, -- 2P残像
	p2_effect = 2 ^ 10, -- 2Pエフェクト
	p2_char = 2 ^ 11, -- 1Pキャラ
}
local global                    = {
	frame_number        = 0,
	lag_frame           = false,
	all_act_normal      = false,
	old_all_act_normal  = false,
	skip_frame          = false,
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
	hide                = hide_options.none,
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
	all_bs              = false,
	disp_replay         = true, -- レコードリプレイガイド表示
	save_snapshot       = 1, -- 技画像保存 1:OFF 2:新規 3:上書き
}
mem.rg                          = function(id, mask) return (mask == nil) and cpu.state[id].value or (cpu.state[id].value & mask) end
mem.pc                          = function() return cpu.state["CURPC"].value end
mem.wp_cnt, mem.rp_cnt          = {}, {} -- 負荷確認のための呼び出す回数カウンター
mem.wp                          = function(addr1, addr2, name, cb) return pgm:install_write_tap(addr1, addr2, name, cb) end
mem.rp                          = function(addr1, addr2, name, cb) return pgm:install_read_tap(addr1, addr2, name, cb) end
mem.wp8                         = function(addr, cb, filter)
	local num = global.holder.countup()
	local name = string.format("wp8_%x_%s", addr, num)
	if addr % 2 == 0 then
		global.holder.taps[name] = mem.wp(addr, addr + 1, name,
			function(offset, data, mask)
				mem.wp_cnt[addr] = (mem.wp_cnt[addr] or 0) + 1
				if filter and filter[mem.pc()] ~= true then return data end
				local ret = {}
				if mask > 0xFF then
					cb((data & mask) >> 8, ret)
					if ret.value then
						--ut.printf("1 %x %x %x %x", data, mask, ret.value, (ret.value << 8) & mask)
						return (ret.value << 8) & mask
					end
				elseif offset == (addr + 1) then
					cb(data & mask, ret)
					if ret.value then
						--ut.printf("2 %x %x %x %x", data, mask, ret.value, ret.value & mask)
						return ret.value & mask
					end
				end
				return data
			end)
	else
		global.holder.taps[name] = mem.wp(addr - 1, addr, name,
			function(offset, data, mask)
				mem.wp_cnt[addr] = (mem.wp_cnt[addr] or 0) + 1
				if filter and filter[mem.pc()] ~= true then return data end
				local ret = {}
				if mask == 0xFF or mask == 0xFFFF then
					cb(0xFF & data, ret)
					if ret.value then
						if mask == 0xFFFF then
							--ut.printf("3 %x %x %x %x", data, mask, ret.value, (ret.value & 0xFF) | (0xFF00 & data))
							return (ret.value & 0xFF) | (0xFF00 & data)
						else
							--ut.printf("4 %x %x %x %x", data, mask, ret.value, (ret.value & 0xFF) | (0xFF00 & data))
							return (ret.value & 0xFF) | (0xFF00 & data)
						end
					end
				end
				return data
			end)
	end
	cb(mem.r8(addr), {})
	return global.holder.taps[name]
end
mem.wp16                        = function(addr, cb, filter)
	local num = global.holder.countup()
	local name = string.format("wp16_%x_%s", addr, num)
	global.holder.taps[name] = mem.wp(addr, addr + 1, name,
		function(offset, data, mask)
			local ret = {}
			mem.wp_cnt[addr] = (mem.wp_cnt[addr] or 0) + 1
			if filter and filter[mem.pc()] ~= true then return data end
			if mask == 0xFFFF then
				cb(data & mask, ret)
				--ut.printf("wp16 %x %x %x %x",addr, data, mask, ret.value or 0)
				return ret.value or data
			end
			local data2, mask2, mask3, data3
			local prev = mem.r32(addr)
			if mask == 0xFF00 or mask == 0xFF then mask2 = mask << 16 end
			mask3 = 0xFFFF ~ mask2
			data2 = data & mask
			data3 = (prev & mask3) | data2
			cb(data3, ret)
			--ut.printf("wp16 %x %x %x %x",addr, data, mask, ret.value or 0)
			return ret.value or data
		end)
	cb(mem.r16(addr), {})
	--printf("register wp %s %x", name, addr)
	return global.holder.taps[name]
end
mem.wp32                        = function(addr, cb, filter)
	local num = global.holder.countup()
	local name = string.format("wp32_%x_%s", addr, num)
	global.holder.taps[name] = mem.wp(addr, addr + 3, name,
		function(offset, data, mask)
			mem.wp_cnt[addr] = (mem.wp_cnt[addr] or 0) + 1
			if filter and filter[mem.pc()] ~= true then return data end
			local ret = {}
			--ut.printf("wp32-1 %x %x %x %x %x", addr, offset, data, data, mask, ret.value or 0)
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
			--ut.printf("wp32-3 %x %x %x %x %x %x", addr, offset, data, data3, mask, ret.value or 0)
			return ret.value or data
		end)
	cb(mem.r32(addr), {})
	return global.holder.taps[name]
end
mem.rp8                         = function(addr, cb, filter)
	local num = global.holder.countup()
	local name = string.format("rp8_%x_%s", addr, num)
	if addr % 2 == 0 then
		global.holder.taps[name] = mem.rp(addr, addr + 1, name,
			function(offset, data, mask)
				mem.rp_cnt[addr] = (mem.wp_cnt[addr] or 0) + 1
				if filter and filter[mem.pc()] ~= true then return data end
				local ret = {}
				if mask > 0xFF then
					cb((data & mask) >> 8, ret)
					if ret.value then
						--ut.printf("1 %x %x %x %x", data, mask, ret.value, (ret.value << 8) & mask)
						return (ret.value << 8) & mask
					end
				elseif offset == (addr + 1) then
					cb(data & mask, ret)
					if ret.value then
						--ut.printf("2 %x %x %x %x", data, mask, ret.value, ret.value & mask)
						return ret.value & mask
					end
				end
				return data
			end)
	else
		global.holder.taps[name] = mem.rp(addr - 1, addr, name,
			function(offset, data, mask)
				mem.rp_cnt[addr] = (mem.wp_cnt[addr] or 0) + 1
				if filter and filter[mem.pc()] ~= true then return data end
				local ret = {}
				if mask == 0xFF or mask == 0xFFFF then
					cb(0xFF & data, ret)
					if ret.value then
						if mask == 0xFFFF then
							--ut.printf("3 %x %x %x %x", data, mask, ret.value, (ret.value & 0xFF) | (0xFF00 & data))
							return (ret.value & 0xFF) | (0xFF00 & data)
						else
							--ut.printf("4 %x %x %x %x", data, mask, ret.value, (ret.value & 0xFF) | (0xFF00 & data))
							return (ret.value & 0xFF) | (0xFF00 & data)
						end
					end
				end
				return data
			end)
	end
	cb(mem.r8(addr), {})
	return global.holder.taps[name]
end
mem.rp16                        = function(addr, cb, filter)
	local num = global.holder.countup()
	local name = string.format("rp16_%x_%s", addr, num)
	global.holder.taps[name] = mem.rp(addr, addr + 1, name,
		function(offset, data, mask)
			mem.rp_cnt[addr] = (mem.rp_cnt[addr] or 0) + 1
			if filter and filter[mem.pc()] ~= true then return data end
			local ret = {}
			if offset == addr then cb(data, ret) end
			return ret.value or data
		end)
	cb(mem.r16(addr), {})
	return global.holder.taps[name]
end
mem.rp32                        = function(addr, cb, filter)
	local num = global.holder.countup()
	local name = string.format("rp32_%x_%s", addr, num)
	global.holder.taps[name] = mem.rp(addr, addr + 3, name,
		function(offset, data, mask)
			mem.rp_cnt[addr] = (mem.rp_cnt[addr] or 0) + 1
			if filter and filter[mem.pc()] ~= true then return data end
			if offset == addr then cb(mem.r32(addr)) end
			return data
		end)
	cb(mem.r32(addr))
	return global.holder.taps[name]
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
local joy_k                     = db.joy_k
local rev_joy                   = db.rev_joy
local joy_frontback             = db.joy_frontback
local joy_pside                 = db.joy_pside
local joy_neutrala              = db.joy_neutrala
local joy_neutralp              = db.joy_neutralp
local joy_ezmap                 = db.joy_ezmap
local kprops                    = db.kprops
local cmd_funcs                 = db.cmd_funcs

local rvs_types                 = db.rvs_types
local hook_cmd_types            = db.hook_cmd_types

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
	return joy_val, prev_joy_val
end

local play_cursor_sound         = function()
	mem.w32(0x10D612, 0x600004)
	mem.w8(0x10D713, 0x1)
end
local input_1f                  = function(btn, joy_val, prev_joy)
	local k1, k2 = joy_k[1][btn], joy_k[2][btn]
	local j1, j2, p1, p2 = joy_val[k1], joy_val[k2], prev_joy[k1], prev_joy[k2]
	if (p1 < 0 and 0 < j1) or (p2 < 0 and 0 < j2) then
		return true
	end
	return false
end
local accept_input              = function(btn, joy_val, state_past)
	joy_val = joy_val or get_joy()
	state_past = state_past or (scr:frame_number() - global.input_accepted)
	if 12 < state_past then
		local p1, p2 = joy_k[1][btn], joy_k[2][btn]
		if btn == "Up" or btn == "Down" or btn == "Right" or btn == "Left" then
			local on1 = (0 < joy_val[p1])
			local on2 = (0 < joy_val[p2])
			if on1 or on2 then
				play_cursor_sound()
				return true, on1, on2
			end
		else
			local on1 = (0 < joy_val[p1] and state_past >= joy_val[p1])
			local on2 = (0 < joy_val[p2] and state_past >= joy_val[p2])
			if on1 or on2 then
				if global.disp_replay then
					play_cursor_sound()
				end
				return true, on1, on2
			end
		end
	end
	return false, false, false
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
local new_next_joy              = function() return ut.deepcopy(joy_neutrala) end
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
local ggkey_set                 = { new_ggkey_set(true), new_ggkey_set(false) }

-- ボタンの色テーブル
local btn_col                   = { [ut.convert("_A")] = 0xFFCC0000, [ut.convert("_B")] = 0xFFCC8800, [ut.convert("_C")] = 0xFF3333CC, [ut.convert("_D")] = 0xFF336600, }
local text_col, shadow_col      = 0xFFFFFFFF, 0xFF000000

local get_string_width          = function(str)
	return man.ui:get_string_width(str) * scr.width
end

local get_line_height           = function(lines)
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

-- コマンド文字列表示
local draw_cmd_text_with_shadow = function(x, y, str, fgcol, bgcol)
	-- 変換しつつUnicodeの文字配列に落とし込む
	local cstr, xx = ut.convert(str), x
	for c in string.gmatch(cstr, "([%z\1-\127\194-\244][\128-\191]*)") do
		-- 文字の影
		scr:draw_text(xx + 0.5, y + 0.5, c, 0xFF000000)
		if btn_col[c] then
			-- ABCDボタンの場合は黒の●を表示した後ABCDを書いて文字の部分を黒く見えるようにする
			scr:draw_text(xx, y, ut.convert("_("), text_col)
			scr:draw_text(xx, y, c, fgcol or btn_col[c])
		else
			scr:draw_text(xx, y, c, fgcol or text_col)
		end
		xx = xx + 5 -- フォントの大きさ問わず5pxずつ表示する
	end
end
-- コマンド入力表示
local draw_cmd                  = function(p, line, frame, str)
	local xx, yy = p == 1 and 12 or 294, get_line_height(line + 9)
	if 0 < frame then
		local cframe = 999 < frame and "LOT" or string.format("%03d", frame)
		draw_text_with_shadow(p == 1 and 1 or 283, yy, cframe, text_col)
	end
	local col = 0xFAFFFFFF
	if p == 1 then
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
local draw_base                 = function(p, bases)
	local lines = {}
	for _, base in ipairs(bases) do
		local addr, act_name, xmov, cframe = base.addr, base.name, base.xmov, string.format("%03d", base.count)
		if 999 < base.count then cframe = "LOT" end
		local smov = (xmov < 0 and "-" or "+") .. string.format("%03d", math.abs(math.floor(xmov))) .. string.sub(string.format("%0.03f", xmov), -4)
		table.insert(lines, string.format("%3s %05X %8s %-s", cframe, addr, smov, act_name))
	end
	local xx, txt = p == 1 and 60 or 195, table.concat(lines, "\n") -- 1Pと2Pで左右に表示し分ける
	scr:draw_text(xx + 0.5, 80.5, txt, 0xFF000000)               -- 文字の影
	scr:draw_text(xx, 80, txt, text_col)
end
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
	dest = dest or ut.deepcopy(src) -- 計算元のboxを汚さないようにディープコピーしてから処理する
	-- 全座標について p.box_scale / 0x1000 の整数値に計算しなおす
	dest.top, dest.bottom = ut.int16((src.top * p.box_scale) >> 6), ut.int16((src.bottom * p.box_scale) >> 6)
	dest.left, dest.right = ut.int16((src.left * p.box_scale) >> 6), ut.int16((src.right * p.box_scale) >> 6)
	--ut.printf("%s ->a top=%s bottom=%s left=%s right=%s", prev, dest.top, dest.bottom, dest.left, dest.right)
	-- キャラの座標と合算して画面上への表示位置に座標を変換する
	local real_top = math.tointeger(math.max(dest.top, dest.bottom) + screen.top - p.pos_z - p.y)
	local real_bottom = math.tointeger(math.min(dest.top, dest.bottom) + screen.top - p.pos_z - p.y) + 1
	dest.real_top, dest.real_bottom = real_top, real_bottom
	dest.left, dest.right = p.x - dest.left * p.flip_x, p.x - dest.right * p.flip_x
	dest.bottom, dest.top = p.y - dest.bottom, p.y - dest.top
	--ut.printf("%s ->b x=%s y=%s top=%s bottom=%s left=%s right=%s", prev, p.x, p.y, dest.top, dest.bottom, dest.left, dest.right)
	return dest
end

-- ROM部分のメモリエリアへパッチあて
local load_rom_patch            = function()
	if mem.pached then return end
	mem.pached = mem.pached or mod.p1_patch()
	mod.bugfix()
	mod.training()
	print("load_rom_patch done")
end

-- ヒット効果アドレステーブルの取得
for i, _ in ipairs(db.hit_effects) do
	table.insert(hit_effect_menus, string.format("%02d %s", i, table.concat(db.hit_effects[i], " ")))
end
local load_hit_effects      = function()
	if #hit_effect_addrs > 1 then return end
	for i, _ in ipairs(db.hit_effects) do
		table.insert(hit_effect_addrs, mem.r32(0x579DA + (i - 1) * 4))
	end
	print("load_hit_effects")
end

local load_hit_system_stops = function()
	if hit_system_stops["a"] then return end
	for addr = 0x57C54, 0x57CC0, 4 do hit_system_stops[mem.r32(addr)] = true end
	hit_system_stops["a"] = true
	print("load_hit_system_stops")
end

-- キャラの基本アドレスの取得
local load_proc_base        = function()
	if db.chars[1].proc_base then return end
	for char = 1, #db.chars - 1 do
		local char4 = char << 2
		db.chars[char].proc_base = {
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
			chip          = fix_addr(0x95CCC),
			hitstun1      = fix_addr(0x95CCC),
			hitstun2      = 0x16 + 0x2 + fix_addr(0x5AF7C),
			blockstun     = 0x1A + 0x2 + fix_addr(0x5AF88),
			bs_pow        = mem.r32(char4 + 0x85920),
			bs_invincible = mem.r32(char4 + 0x85920) + 0x1,
			sp_invincible = mem.r32(char4 + 0x8DE62),
		}
	end
	db.chars[#db.chars].proc_base = { -- 共通枠に弾のベースアドレスを入れておく
		forced_down = 0x8E2C0,
		hitstop     = fix_addr(0x884F2),
		damege      = fix_addr(0x88472),
		stun        = fix_addr(0x886F2),
		stun_timer  = fix_addr(0x88772),
		max_hit     = fix_addr(0x885F2),
		baigaeshi   = 0x8E940,
		effect      = fix_addr(0x95BEC) - 0x20, -- 家庭用58232からの処理
		chip        = fix_addr(0x95CCC),
		hitstun1    = fix_addr(0x95CCC),
		hitstun2    = 0x16 + 0x2 + fix_addr(0x5AF7C),
		blockstun   = 0x1A + 0x2 + fix_addr(0x5AF88),
	}
	print("load_proc_base done")
end

-- 接触判定の取得
local load_push_box         = function()
	if db.chars[1].push_box then return end
	-- キャラデータの押し合い判定を作成
	-- キャラごとの4種類の判定データをロードする
	for char = 1, #db.chars - 1 do
		db.chars[char].push_box_mask = mem.r32(0x5C728 + (char << 2))
		db.chars[char].push_box = {}
		for _, addr in ipairs({ 0x5C9BC, 0x5CA7C, 0x5CB3C, 0x5CBFC }) do
			local a2 = addr + (char << 3)
			local y1, y2, x1, x2 = mem.r8i(a2 + 0x1), mem.r8i(a2 + 0x2), mem.r8i(a2 + 0x3), mem.r8i(a2 + 0x4)
			db.chars[char].push_box[addr] = {
				addr = addr,
				id = 0,
				type = db.box_types.push,
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
	print("load_push_box done")
end

local get_push_box          = function(p)
	-- 家庭用 05C6D0 からの処理
	local push_box = db.chars[p.char].push_box
	if p.char == 0x5 and ut.tstb(p.flag_c8, db.flag_c8._15) then
		return push_box[0x5C9BC]
	else
		if ut.tstb(p.flag_c0, db.flag_c0._01) ~= true and p.pos_y ~= 0 then
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

local fix_throw_box_pos     = function(box)
	box.left, box.right = box.x - box.left * box.flip_x, box.x - box.right * box.flip_x
	box.bottom, box.top = box.y - box.bottom, box.y - box.top
	return box
end

-- 通常投げ間合い
-- 家庭用0x05D78Cからの処理
local get_normal_throw_box  = function(p)
	-- 相手が向き合いか背向けかで押し合い幅を解決して反映
	local push_box, op_push_box = db.chars[p.char].push_box[0x5C9BC], db.chars[p.op.char].push_box[0x5C9BC]
	local op_edge = (p.block_side == p.op.block_side) and op_push_box.back or op_push_box.front
	local center = ut.int16(((push_box.front - math.abs(op_edge)) * p.box_scale) >> 6)
	local range = mem.r8(fix_addr(0x5D854) + p.char4)
	return fix_throw_box_pos({
		id = 0x100, -- dummy
		type = db.box_types.normal_throw,
		left = center - range,
		right = center + range,
		top = -0x05, -- 地上投げの範囲をわかりやすくする
		bottom = 0x05,
		x = p.pos - screen.left,
		y = screen.top - p.pos_y - p.pos_z,
		threshold = mem.r8(0x3A66C), -- 投げのしきい値 039FA4からの処理
		flip_x = p.block_side, -- 向き補正値
	})
end

-- 必殺投げ間合い
local get_special_throw_box = function(p, id)
	local a0 = 0x3A542 + (0xFFFF & (id << 3))
	local top, bottom = mem.r16(a0 + 2), mem.r16(a0 + 4)
	if id == 0xA then
		top, bottom = 0x1FFF, 0x1FFF -- ダブルクラッチは上下無制限
	elseif top + bottom == 0 then
		top, bottom = 0x05, 0x05 -- 地上投げの範囲をわかりやすくする
	end
	return fix_throw_box_pos({
		id = id,
		type = db.box_types.special_throw,
		left = -mem.r16(a0),
		right = 0x0,
		top = top,
		bottom = -bottom,
		x = p.pos - screen.left,
		y = screen.top - p.pos_y - p.pos_z,
		threshold = mem.r8(0x3A66C + (0xFF & id)), -- 投げのしきい値 039FA4からの処理
		flip_x = p.block_side,               -- 向き補正値
	})
end

-- 空中投げ間合い
-- MEMO: 0x060566(家庭用)のデータを読まずにハードコードにしている
local get_air_throw_box     = function(p)
	return fix_throw_box_pos({
		id = 0x200, -- dummy
		type = db.box_types.air_throw,
		left = -0x30,
		right = 0x0,
		top = -0x20,
		bottom = 0x20,
		x = p.pos - screen.left,
		y = screen.top - p.pos_y - p.pos_z,
		threshold = 0,   -- 投げのしきい値
		flip_x = p.block_side, -- 向き補正値
	})
end

local get_throwbox          = function(p, id)
	if id == 0x100 then
		return get_normal_throw_box(p)
	elseif id == 0x200 then
		return get_air_throw_box(p)
	end
	return get_special_throw_box(p, id)
end

local draw_hitbox           = function(box)
	--ut.printf("%s  %s", box.type.kind, box.type.enabled)
	-- 背景なしの場合は判定の塗りつぶしをやめる
	local outline, fill = box.type.outline, global.disp_bg and box.type.fill or 0
	local x1, x2 = sort_ab(box.left, box.right)
	local y1, y2 = sort_ab(box.top, box.bottom)
	scr:draw_box(x1, y1, x1 - 1, y2, 0, outline)
	scr:draw_box(x2, y1, x2 + 1, y2, 0, outline)
	scr:draw_box(x1, y1, x2, y1 - 1, 0, outline)
	scr:draw_box(x1, y2, x2, y2 + 1, outline, outline)
	scr:draw_box(x1, y1, x2, y2, outline, fill)
	--ut.printf("%s  x1=%s x2=%s y1=%s y2=%s",  box.type.kind, x1, x2, y1, y2)
end

local draw_range            = function(range)
	local label, flip_x, x, y, col = range.label, range.flip_x, range.x, range.y, range.within and 0xFFFFFF00 or 0xFFBBBBBB
	local size = range.within == nil and global.axis_size or global.axis_size2 -- 範囲判定がないものは単純な座標とみなす
	scr:draw_box(x, y - size, x + flip_x, y + size, 0, col)
	scr:draw_box(x - size + flip_x, y, x + size + flip_x, y - 1, 0, col)
	draw_ctext_with_shadow(x, y, label or "", col)
end


-- 判定枠のチェック処理種類
local hitbox_possible_map  = {
	[0x01311C] = possible_types.none,   -- 常に判定しない
	[0x012FF0] = possible_types.same_line, -- → 013038 同一ライン同士なら判定する
	[0x012FFE] = possible_types.both_line, -- → 013054 異なるライン同士でも判定する
	[0x01300A] = possible_types.unknown, -- → 013018 不明
	[0x012FE2] = possible_types.air_onry, -- → 012ff0 → 013038 相手が空中にいれば判定する
}
local get_hitbox_possibles = function(id)
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

local box_with_bit_types   = ut.table_sort({
	{ box_type = db.box_types.fake_juggle_fb,     attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.fake | frame_attack_types.juggle },
	{ box_type = db.box_types.fake_fireball,      attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.fake },
	{ box_type = db.box_types.fake_juggle,        attackbit = frame_attack_types.attacking | frame_attack_types.fake | frame_attack_types.juggle },
	{ box_type = db.box_types.fake_attack,        attackbit = frame_attack_types.attacking | frame_attack_types.fake },
	{ box_type = db.box_types.harmless_juggle_fb, attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.fullhit | frame_attack_types.juggle },
	{ box_type = db.box_types.harmless_juggle_fb, attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.obsolute | frame_attack_types.juggle },
	{ box_type = db.box_types.harmless_juggle_fb, attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.harmless | frame_attack_types.juggle },
	{ box_type = db.box_types.juggle_fireball,    attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.juggle },
	{ box_type = db.box_types.harmless_fireball,  attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.fullhit },
	{ box_type = db.box_types.harmless_fireball,  attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.obsolute },
	{ box_type = db.box_types.harmless_fireball,  attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.harmless },
	{ box_type = db.box_types.fireball,           attackbit = frame_attack_types.attacking | frame_attack_types.fb | frame_attack_types.attacking },
	{ box_type = db.box_types.harmless_juggle,    attackbit = frame_attack_types.attacking | frame_attack_types.fullhit | frame_attack_types.juggle },
	{ box_type = db.box_types.harmless_juggle,    attackbit = frame_attack_types.attacking | frame_attack_types.harmless | frame_attack_types.juggle },
	{ box_type = db.box_types.harmless_juggle,    attackbit = frame_attack_types.attacking | frame_attack_types.obsolute | frame_attack_types.juggle },
	{ box_type = db.box_types.juggle,             attackbit = frame_attack_types.attacking | frame_attack_types.juggle },
	{ box_type = db.box_types.harmless_attack,    attackbit = frame_attack_types.attacking | frame_attack_types.fullhit },
	{ box_type = db.box_types.harmless_attack,    attackbit = frame_attack_types.attacking | frame_attack_types.obsolute },
	{ box_type = db.box_types.harmless_attack,    attackbit = frame_attack_types.attacking | frame_attack_types.harmless },
	{ box_type = db.box_types.attack,             attackbit = frame_attack_types.attacking },
}, function(t1, t2) return t1.box_type.sort < t2.box_type.sort end)

for i, item in ipairs(box_with_bit_types) do
	ut.printf("%s %s", i, item.box_type.name_en)
end

local fix_box_type         = function(p, box)
	local type = p.in_sway_line and box.sway_type or box.type
	if type ~= db.box_types.attack then return type end
	-- TODO 多段技の状態
	p.max_hit_dn = p.max_hit_dn or 0
	if p.max_hit_dn > 1 or p.max_hit_dn == 0 or (p.char == 0x4 and p.attack == 0x16) then
	end
	-- TODO つかみ技はダメージ加算タイミングがわかるようにする
	if ut.tstb(p.flag_cc, db.flag_cc.grabbing) and p.op.last_damage_scaled ~= 0xFF then
	end
	local attackbit = frame_attack_types.hitbox_type_mask & p.attackbit
	for _, item in ipairs(box_with_bit_types) do
		if ut.tstb(attackbit, item.attackbit, true) then
			--ut.printf("%x %s", p.addr.base, item.box_type.name_en)
			return item.box_type
		end
	end
	return box_with_bit_types[#box_with_bit_types].box_type
end
-- 遠近間合い取得
local load_close_far       = function()
	if db.chars[1].close_far then return end
	-- 地上通常技の近距離間合い 家庭用 02DD02 からの処理
	for org_char = 1, #db.chars - 1 do
		local char                   = org_char - 1
		local abc_offset             = mem.close_far_offset + (char * 4)
		local d_offset               = mem.close_far_offset_d + (char * 2)
		-- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
		db.chars[org_char].close_far = {
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
		local decd1 = ut.int16tofloat(d1)
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
	for org_char = 1, #db.chars - 1 do
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
		db.chars[org_char].close_far[0x80] = ret
	end
	print("load_close_far done")
end

local reset_memory_tap     = function(label, enabled)
	if not global.holder then return end
	local sub = global.holder.sub[label]
	if not sub then return end
	if not enabled and sub.on == true then
		sub.on = false
		for name, tap in pairs(sub.taps) do tap:remove() end
		--ut.printf("remove %s", label)
	elseif enabled and sub.on ~= true then
		sub.on = true
		for name, tap in pairs(sub.taps) do tap:reinstall() end
		--ut.printf("reinstall %s", label)
	end
end

local load_memory_tap      = function(label, wps) -- tapの仕込み
	if global.holder and global.holder.sub[label] then
		reset_memory_tap(label, true)
		return
	end
	if global.holder == nil then
		global.holder = { on = true, taps = {}, sub = {}, cnt = 0, }
		global.holder.countup = function(label)
			global.holder.cnt = global.holder.cnt + 1
			return global.holder.cnt
		end
	end
	local sub = { on = true, taps = {} }
	for _, p in ipairs(wps) do
		for _, k in ipairs({ "wp8", "wp16", "wp32", "rp8", "rp16", "rp32", }) do
			for any, cb in pairs(p[k] or {}) do
				local addr = type(any) == "number" and any or any.addr
				addr = addr > 0xFF and addr or ((p.addr and p.addr.base) + addr)
				local filter = type(any) == "number" and {} or not any.filter and {} or
					type(any.filter) == "table" and any.filter or type(any.filter) == "number" and { any.filter }
				---@diagnostic disable-next-line: redundant-parameter
				local wp = mem[k](addr, cb, filter and #filter > 0 and ut.table_to_set(filter) or nil)
				---@diagnostic disable-next-line: need-check-nil
				sub.taps[wp.name] = wp
			end
		end
	end
	global.holder.sub[label] = sub
	print("load_memory_tap [" .. label .. "] done")
end

local apply_attack_infos   = function(p, id, base_addr)
	-- 削りダメージ計算種別取得 05B2A4 からの処理
	p.chip      = db.calc_chip((0xF & mem.r8(base_addr.chip + id)) + 1, p.damage)
	-- 硬直時間取得 05AF7C(家庭用版)からの処理
	local d2    = 0xF & mem.r8(id + base_addr.hitstun1)
	p.hitstun   = mem.r8(base_addr.hitstun2 + d2) + 1 + 3 -- ヒット硬直
	p.blockstun = mem.r8(base_addr.blockstun + d2) + 1 + 2 -- ガード硬直
end

local dummy_gd_type        = {
	none   = 1, -- なし
	auto   = 2, -- オート
	bs     = 3, -- ブレイクショット
	hit1   = 4, -- 1ヒットガード
	block1 = 5, -- 1ガード
	fixed  = 6, -- 常時
	random = 7, -- ランダム
	force  = 8, -- 強制
}
local wakeup_type          = {
	none = 1, -- なし
	rvs  = 2, -- リバーサル
	tech = 3, -- テクニカルライズ
	sway = 4, -- グランドスウェー
	atk  = 5, -- 起き上がり攻撃
}
local rvs_wake_types       = ut.new_set(wakeup_type.tech, wakeup_type.sway, wakeup_type.rvs)
rbff2.startplugin          = function()
	local players, all_wps, all_objects, hitboxies, ranges = {}, {}, {}, {}, {}
	local hitboxies_order = function(b1, b2) return (b1.id < b2.id) end
	local ranges_order = function(r1, r2) return (r1.within and 1 or -1) < (r2.within and 1 or -1) end
	local ifind = function(sources, resolver) -- sourcesの要素をresolverを通して得た結果で最初の非nilの値を返す
		sources = sources or {}
		local i, ii, p, a = 1, nil, nil, nil
		return function()
			while i <= #sources and p == nil do
				i, ii, p, a = i + 1, i, resolver(sources[i]), sources[i]
				if p then return ii, a, p end -- インデックス, sources要素, convert結果
			end
		end
	end
	local ifind_all = function(sources, resolver) -- sourcesの要素をresolverを通して得た結果で非nilの値を返す
		sources = sources or {}
		local i, ii, p, a = 1, nil, nil, nil
		return function()
			while i <= #sources do
				i, ii, p, a = i + 1, i, resolver(sources[i]), sources[i]
				if p then return ii, a, p end -- インデックス, sources要素, convert結果
			end
		end
	end
	local find_all = function(sources, resolver) -- sourcesの要素をresolverを通して得た結果で非nilの値を返す
		local i, col, ret = 1, {}, nil
		for k, v in pairs(sources) do
			local v2 = resolver(k, v)
			if v2 then table.insert(col, { k, v, v2 }) end
		end
		return function()
			while i <= #col do
				i, ret = i + 1, col[i]
				return ret[1], ret[2], ret[3]
			end
		end
	end
	local get_object_by_addr = function(addr, default) return all_objects[addr] or default end             -- ベースアドレスからオブジェクト解決
	local get_object_by_reg = function(reg, default) return all_objects[mem.rg(reg, 0xFFFFFF)] or default end -- レジストリからオブジェクト解決
	local now = function() return global.frame_number + 1 end
	for i = 1, 2 do                                                                                        -- プレイヤーの状態など
		local p1      = (i == 1)
		local base    = p1 and 0x100400 or 0x100500
		players[i]    = {
			num               = i,
			is_fireball       = false,
			base              = 0x0,
			dummy_act         = 1,         -- 立ち, しゃがみ, ジャンプ, 小ジャンプ, スウェー待機
			dummy_gd          = dummy_gd_type.none, -- なし, オート, ブレイクショット, 1ヒットガード, 1ガード, 常時, ランダム, 強制
			dummy_wakeup      = wakeup_type.none, -- なし, リバーサル, テクニカルライズ, グランドスウェー, 起き上がり攻撃
			dummy_bs          = nil, -- ランダムで選択されたブレイクショット
			dummy_bs_list     = {}, -- ブレイクショットのコマンドテーブル上の技ID
			dummy_bs_chr      = 0, -- ブレイクショットの設定をした時のキャラID
			bs_count          = -1, -- ブレイクショットの実施カウント
			dummy_rvs         = nil, -- ランダムで選択されたリバーサル
			dummy_rvs_list    = {}, -- リバーサルのコマンドテーブル上の技ID
			dummy_rvs_chr     = 0, -- リバーサルの設定をした時のキャラID
			rvs_count         = -1, -- リバーサルの実施カウント
			gd_rvs_enabled    = false, -- ガードリバーサルの実行可否

			life_rec          = true, -- 自動で体力回復させるときtrue
			red               = 2, -- 体力設定     	--"最大", "赤", "ゼロ" ...
			max               = 1, -- パワー設定       --"最大", "半分", "ゼロ" ...
			disp_hitbox       = true, -- 判定表示
			disp_range        = true, -- 間合い表示
			disp_base         = 1, -- 処理のアドレスを表示するとき "OFF", "本体", "弾1", "弾2", "弾3"
			hide_char         = false, -- キャラを画面表示しないときtrue
			hide_phantasm     = false, -- 残像を画面表示しないときtrue
			disp_dmg          = true, -- ダメージ表示するときtrue
			disp_cmd          = 2, -- 入力表示 1:OFF 2:ON 3:ログのみ 4:キーディスのみ
			disp_frm          = 2, -- フレーム数表示する
			disp_fbfrm        = true, -- 弾のフレーム数表示するときtrue
			disp_stun         = true, -- 気絶表示
			disp_sts          = 3, -- 状態表示 "OFF", "ON", "ON:小表示", "ON:大表示"
			dis_plain_shift   = false, -- ライン送らない現象
			no_hit            = 0, -- Nヒット目に空ぶるカウントのカウンタ
			no_hit_limit      = 0, -- Nヒット目に空ぶるカウントの上限
			force_y_pos       = 1, -- Y座標強制
			update_act        = false,
			move_count        = 0, -- スクショ用の動作カウント
			on_punish         = 0,
			key_now           = {}, -- 個別キー入力フレーム
			key_pre           = {}, -- 前フレームまでの個別キー入力フレーム
			key_hist          = ut.new_filled_table(16, ""),
			key_frames        = ut.new_filled_table(16, 0),
			ggkey_hist        = {},
			throw_boxies      = {},
			fireballs         = {},
			random_boolean    = math.random(255) % 2 == 0,
			addr              = {
				base        = base, -- キャラ状態とかのベースのアドレス
				control     = base + 0x12, -- Human 1 or 2, CPU 3
				pos         = base + 0x20, -- X座標
				pos_y       = base + 0x28, -- Y座標
				cmd_side    = base + 0x86, -- コマンド入力でのキャラ向きチェック用 00:左側 80:右側
				sway_status = base + 0x89, -- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
				life        = base + 0x8B, -- 体力
				pow         = base + 0xBC, -- パワーアドレス
				hurt_state  = base + 0xE4, -- やられ状態 ライン送らない状態用
				stun_limit  = p1 and 0x10B84E or 0x10B856, -- 最大気絶値
				char        = p1 and 0x107BA5 or 0x107BA7, -- キャラID
				color       = p1 and 0x107BAC or 0x107BAD, -- カラー A=0x00 D=0x01
				stun        = p1 and 0x10B850 or 0x10B858, -- 現在気絶値
				stun_timer  = p1 and 0x10B854 or 0x10B85C, -- 気絶値ゼロ化までの残フレーム数
				reg_pcnt    = p1 and 0x300000 or 0x340000, -- キー入力 REG_P1CNT or REG_P2CNT アドレス
				reg_st_b    = 0x380000,        -- キー入力 REG_STATUS_B アドレス
			},

			add_cmd_hook      = function(input)
				local p = players[i]
				p.bs_hook = (p.bs_hook and p.bs_hook.cmd_type) and p.bs_hook or { cmd_type = db.cmd_types._5 }
				input = type(input) == "table" and input[p.cmd_side] or input
				p.bs_hook.cmd_type = p.bs_hook.cmd_type & db.cmd_masks[input]
				p.bs_hook.cmd_type = p.bs_hook.cmd_type | input
			end,
			clear_cmd_hook    = function(mask)
				local p = players[i]
				p.bs_hook = (p.bs_hook and p.bs_hook.cmd_type) and p.bs_hook or { cmd_type = db.cmd_types._5 }
				mask = type(mask) == "table" and mask[p.cmd_side] or mask
				mask = 0xFF ~ mask
				p.bs_hook.cmd_type = p.bs_hook.cmd_type & mask
			end,
			reset_cmd_hook    = function(input)
				local p = players[i]
				p.bs_hook = (p.bs_hook and p.bs_hook.cmd_type) and p.bs_hook or { cmd_type = db.cmd_types._5 }
				input = type(input) == "table" and input[p.cmd_side] or input
				p.bs_hook = { cmd_type = input }
			end,
			is_block_cmd_hook = function()
				local p = players[i]
				return p.bs_hook and p.bs_hook.cmd_type and
					ut.tstb(p.bs_hook.cmd_type, db.cmd_types.back[p.cmd_side]) and
					ut.tstb(p.bs_hook.cmd_type, db.cmd_types._2) ~= true
			end,
			reset_sp_hook     = function(hook) players[i].bs_hook = hook end,
		}
		local p       = players[i]
		p.body        = players[i] -- プレイヤーデータ自身、fireballとの互換用
		p.update_char = function(data)
			p.char, p.char4, p.char8 = data, (data << 2), (data << 3)
			p.char_data = p.is_fireball and db.chars[#db.chars] or db.chars[data] -- 弾はダミーを設定する
			if not p.is_fireball then p.proc_active = true end
		end
		for k = 1, #kprops do p.key_now[kprops[k]], p.key_pre[kprops[k]] = 0, 0 end
		p.update_tmp_combo = function(data)
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
			[0x16] = function(data) p.knockback1 = data end, -- のけぞり確認用2(裏雲隠し)
			[0x69] = function(data) p.knockback2 = data end, -- のけぞり確認用1(色々)
			[0x7E] = function(data) p.flag_7e = data end, -- のけぞり確認用3(フェニックススルー)
			[{ addr = 0x82, filter = { 0x2668C, 0x2AD24, 0x2AD2C } }] = function(data, ret)
				local pc = mem.pc()
				if pc == 0x2668C then p.input1, p.flag_fin = data, false end
				if pc == 0x2AD24 or pc == 0x2AD2C then p.flag_fin = ut.tstb(data, 0x80) end -- キー入力 直近Fの入力, 動作の最終F
			end,
			[0x83] = function(data) p.input2 = data end,                           -- キー入力 1F前の入力
			[0x84] = function(data) p.cln_btn = data end,                          -- クリアリングされたボタン入力
			[0x86] = function(data) p.cmd_side = ut.int8(data) < 0 and -1 or 1 end, -- コマンド入力でのキャラ向きチェック用 00:左側 80:右側
			[0x88] = function(data) p.in_bs = data ~= 0 end,                       -- BS動作中
			[0x89] = function(data) p.sway_status, p.in_sway_line = data, data ~= 0x00 end, -- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
			[0x8B] = function(data, ret)
				-- 残体力がゼロだと次の削りガードが失敗するため常に1残すようにもする
				p.life, p.on_damage, ret.value = data, now(), math.max(data, 1) -- 体力
			end,
			[0x8E] = function(data)
				local changed = p.state ~= data
				p.on_block = data == 2 and now() or p.on_block                          -- ガードへの遷移フレームを記録
				p.on_hit = data == 1 or data == 3 and now() or p.on_hit                 -- ヒットへの遷移フレームを記録
				if p.state == 0 and p.on_hit and not p.act_normal then p.on_punish = now() + 10 end -- 確定反撃
				p.random_boolean = changed and (math.random(255) % 2 == 0) or p.random_boolean
				p.state, p.change_state = data, changed and now() or p.change_state     -- 今の状態と状態更新フレームを記録
				if data == 2 then
					p.update_tmp_combo(changed and 1 or 2)                              -- 連続ガード用のコンボ状態リセット
					p.last_combo = changed and 1 or p.last_combo + 1
				end
			end,
			[{ addr = 0x8F, filter = { 0x5B134, 0x5B154 } }] = function(data)
				p.last_damage, p.last_damage_scaled = data, data                                  -- 補正前攻撃力
			end,
			[0x90] = function(data) p.throw_timer = data end,                                     -- 投げ可能かどうかのフレーム経過
			[{ addr = 0xA9, filter = { 0x23284, 0x232B0 } }] = function(data) p.on_vulnerable = now() end, -- 判定無敵でない, 判定無敵+無敵タイマーONでない
			-- [0x92] = function(data) end, -- 弾ヒット?
			[0xA2] = function(data) p.firing = data ~= 0 end,                                     -- 弾発射時に値が入る ガード判断用
			[0xA3] = function(data)                                                               -- A3:成立した必殺技コマンドID A4:必殺技コマンドの持続残F
				if data == 0 then
					p.on_sp_clear = now()
				elseif data ~= 0 then
					p.on_sp_established, p.last_sp = now(), data
					local sp2, proc_base           = (p.last_sp - 1) * 2, p.char_data.proc_base
					p.bs_pow, p.bs_invincible      = mem.r8(proc_base.bs_pow + sp2) & 0x7F, mem.r8(proc_base.bs_invincible + sp2)
					p.bs_invincible                = p.bs_invincible == 0xFF and 0 or p.bs_invincible
					p.sp_invincible                = mem.r8(proc_base.sp_invincible + p.last_sp - 1)
					p.bs_invincible                = math.max(p.bs_invincible - 1, 0) -- 発生時に即-1される
					p.sp_invincible                = math.max(p.sp_invincible - 1, 0) -- 発生時に即-1される
				end
			end,
			[0xA5] = function(data) p.additional = data end, -- 追加入力成立時のデータ
			--[0xAD] = function(data)  end, -- ガード動作用
			[0xAF] = function(data) p.cancelable_data = data end, -- キャンセル可否 00:不可 C0:可 D0:可 正確ではないかも
			[0x68] = function(data) p.skip_frame = data ~= 0 end, -- 潜在能力強制停止
			[0xB6] = function(data)
				-- 攻撃中のみ変化、判定チェック用2 0のときは何もしていない、 詠酒の間合いチェック用など
				p.attackbits.harmless = data == 0
				p.attack_data = data
				if data == 0 then return end
				if p.attack ~= data then
					p.clear_damages()
					p.pow_up        = 0x58 > data and 0 or p.pow_up
					p.pow_up_direct = 0x58 > data and 0 or p.pow_up_direct
				end
				-- ut.printf("attack %x", data)
				p.attack            = data
				p.on_update_attack  = now()
				p.attackbits.attack = data
				local base_addr     = p.char_data.proc_base
				p.forced_down       = 2 <= mem.r8(data + base_addr.forced_down) -- テクニカルライズ可否 家庭用 05A9BA からの処理
				-- ヒットストップ 家庭用 攻撃側:05AE2A やられ側:05AE50 からの処理 OK
				p.hitstop           = math.max(2, (0x7F & mem.r8(data + base_addr.hitstop)) - 1)
				p.blockstop         = math.max(2, p.hitstop - 1) -- ガード時の補正
				p.damage            = mem.r8(data + base_addr.damege) -- 補正前ダメージ  家庭用 05B118 からの処理
				p.stun              = mem.r8(data + base_addr.stun) -- 気絶値 05C1CA からの処理
				p.stun_timer        = mem.r8(data + base_addr.stun_timer) -- 気絶タイマー 05C1CA からの処理
				p.max_hit_dn        = data > 0 and mem.r8(data + base_addr.max_hit) or 0
				if 0x58 > data then
					-- 詠酒距離 家庭用 0236F0 からの処理
					local esaka = mem.r16(base_addr.esaka + ((data + data) & 0xFFFF))
					p.esaka, p.esaka_type = esaka & 0x1FFF, db.esaka_type_names[esaka & 0xE000] or ""
					if 0x27 <= data then                                   -- 家庭用 05B37E からの処理
						p.pow_up_hit = mem.r8((0xFF & (data - 0x27)) + base_addr.pow_up_ext) -- CA技、特殊技
					else
						p.pow_up_hit = mem.r8(base_addr.pow_up + data)     -- ビリー、チョンシュ、その他の通常技
					end
					p.pow_up_block = 0xFF & (p.pow_up_hit >> 1)               -- ガード時増加量 d0の右1ビットシフト=1/2
				end
				apply_attack_infos(p, data, base_addr)
				if p.char_data.pow and p.char_data.pow[data] then
					p.pow_revenge = p.char_data.pow[data].pow_revenge or p.pow_revenge
					p.pow_absorb = p.char_data.pow[data].pow_absorb or p.pow_absorb
					p.pow_up_hit = p.char_data.pow[data].pow_up_hit or p.pow_up_hit
				end
				p.stand_close = mem.pc() == 0x2AE02 -- 0x2AE02は近距離版動作へのデータ補正の処理アドレス
				-- ut.printf("%x dmg %x %s %s %s %s %s", p.addr.base, data, p.damage, p.stun, p.stun_timer, p.pow_up_hit, p.pow_up_block)
			end,
			-- [0xB7] = function(data) p.corner = data end, -- 画面端状態 0:端以外 1:画面端 3:端押し付け
			[0xB8] = function(data)
				p.spid, p.sp_flag, p.on_update_spid = data, mem.r32(0x3AAAC + (data << 2)), now() -- 技コマンド成立時の技のID, 0xC8へ設定するデータ(03AA8Aからの処理)
			end,
			[{ addr = 0xB9, filter = { 0x58930, 0x58948 } }] = function(data)
				if data == 0 and mem.pc() == 0x58930 then p.on_bs_clear = now() end            -- BSフラグのクリア
				if data ~= 0 and mem.pc() == 0x58948 then p.on_bs_established, p.last_bs = now(), data end -- BSフラグ設定
			end,
			[0xD0] = function(data) p.flag_d0 = data end,                                      -- フラグ群
			[0xE2] = function(data) p.sway_close = data == 0 end,
			[0xE4] = function(data) p.hurt_state = data end,                                   -- やられ状態
			[0xE8] = function(data, ret)
				if data < 0x10 and p.dummy_gd == dummy_gd_type.force then ret.value = 0x10 end -- 0x10以上でガード
			end,
			[0xEC] = function(data) p.push_invincible = data end,                              -- 押し合い判定の透過状態
			[0xEE] = function(data) p.in_hitstop_value, p.in_hitstun = data, ut.tstb(data, 0x80) end,
			[0xF6] = function(data) p.invincible = data end,                                   -- 打撃と投げの無敵の残フレーム数
			-- [0xF7] = function(data) end -- 技の内部の進行度
			[{ addr = 0xFB, filter = { 0x49418, 0x49428 } }] = function(data)
				p.kaiserwave = p.kaiserwave or {} -- カイザーウェイブのレベルアップ
				local pc = mem.pc()
				if (p.kaiserwave[pc] == nil) or p.kaiserwave[pc] + 1 < global.frame_number then p.on_update_spid = now() end
				p.kaiserwave[pc] = now()
			end,
			[p1 and 0x10B4E1 or 0x10B4E0] = p.update_tmp_combo,
			[p1 and 0x10B4E5 or 0x10B4E4] = function(data) p.last_combo = data end, -- 最近のコンボ数
			[p1 and 0x10B4E7 or 0x10B4E8] = function(data) p.konck_back4 = data end, -- 1ならやられ中
			--[p1 and 0x10B4F0 or 0x10B4EF] = function(data) p.max_combo = data end, -- 最大コンボ数
			[p1 and 0x10B84E or 0x10B856] = function(data) p.stun_limit = data end, -- 最大気絶値
			[p1 and 0x10B850 or 0x10B858] = function(data) p.stun = data end, -- 現在気絶値
			[p1 and 0x1041B0 or 0x1041B4] = function(data, ret)
				if p.bs_hook and p.bs_hook.cmd_type then
					--ut.printf("%s bs_hook cmd %x", p.num, p.bs_hook.cmd_type)
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
		local special_throw_addrs = ut.get_hash_key(special_throws)
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
			[{ addr = 0x28, filter = ut.table_add_all(special_throw_addrs, { 0x6042A }) }] = extra_throw_callback,
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
				if p.char == 0x5 and global.auto_input.rave == 10 then ret.value = 0xFF end     -- 自動デッドリー
				if p.char == 0x14 and global.auto_input.desire == 11 then ret.value = 0xFE end  -- 自動アンリミ2
				if p.char == 0xB and global.auto_input.drill == 5 then ret.value = 0xFE end     -- 自動ドリルLv.5
			end,
			[{ addr = 0xB9, filter = { 0x396B4, 0x39756 } }] = function(data) p.on_bs_check = now() end, -- BSの技IDチェック
			[{ addr = 0xBF, filter = { 0x3BEF6, 0x3BF24, 0x5B346, 0x5B368 } }] = function(data)
				if data ~= 0 then                                                               -- 増加量を確認するためなのでBSチェックは省く
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
						pow_up = (p.flag_cc & 0xE0 == 0) and p.pow_up_hit or p.pow_up_block or 0
					end
					p.last_pow_up, p.op.combo_pow = pow_up, (p.op.combo_pow or 0) + pow_up
					--ut.printf("%x %x data=%s last_pow_up=%s combo_pow=%s", base, pc, data, p.last_pow_up, p.op.combo_pow)
				end
			end,
			[{ addr = 0xCD, filter = special_throw_addrs }] = extra_throw_callback,
			[{ addr = 0xD6, filter = 0x5A7B4 }] = function(data, ret)
				if p.dummy_wakeup == wakeup_type.atk and p.char_data.wakeup then ret.value = 0x23 end -- 成立コマンド値を返す
			end,
		}
		p.wp16 = {
			[0x34] = function(data) p.thrust = data end,
			[0x36] = function(data) p.thrust_frc = ut.int16tofloat(data) end,
			--[0x92] = function(data) p.anyhit_id = data end,
			--[0x9E] = function(data) p.ophit = all_objects[data] end, -- ヒットさせた相手側のベースアドレス
			[0xDA] = function(data) p.inertia = data end,
			[0xDC] = function(data) p.inertia_frc = ut.int16tofloat(data) end,
			[0xE6] = function(data) p.on_hit_any = now() + 1 end,          -- 0xE6か0xE7 打撃か当身でフラグが立つ
			[p1 and 0x10B854 or 0x10B85C] = function(data) p.stun_timer = data end, -- 気絶値ゼロ化までの残フレーム数
		}
		local nohit = function(data, ret)
			if p.no_hit_limit > 0 and p.last_combo >= p.no_hit_limit then ret.value = 0x311C end --  0x0001311Cの後半を返す
		end
		p.rp16 = {
			[{ addr = 0x20, filter = 0x2DD16 }] = function(data)
				if not in_match then return end
				p.main_d_close = mem.rg("D2", 0xFFFF) >= math.abs(p.pos - p.op.pos) -- 対スウェーライン攻撃の遠近判断
			end,
			[0x13124 + 0x2] = nohit, -- 0x13124の後半読み出しハック
			[0x13128 + 0x2] = nohit, -- 0x13128の後半読み出しハック 0x1311Cを返す
			[0x1312C + 0x2] = nohit, -- 0x1312Cの後半読み出しハック 0x1311Cを返す
			[0x13130 + 0x2] = nohit, -- 0x13130の後半読み出しハック 0x1311Cを返す
		}
		p.wp32 = {
			[0x00] = function(data, ret)
				p.base   = data
				local pc = mem.pc()
				if (pc == 0x58268 or pc == 0x582AA) and global.damaged_move > 1 then
					ret.value = hit_effect_addrs[global.damaged_move]
				end
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
	for _, body in ipairs(players) do -- 飛び道具領域の作成
		body.objects = { body }
		for fb_base = 1, 3 do
			local base = fb_base * 0x200 + body.addr.base
			local p = {
				fb_num      = fb_base,
				is_fireball = true,
				body        = body,
				addr        = {
					base = base, -- キャラ状態とかのベースのアドレス
				}
			}
			p.wp8 = {
				[0xB5] = function(data) p.fireball_rank = data end,
				[0xE7] = function(data) p.attackbits.fullhit = data ~= 0 end,
				[0x8A] = function(data) p.grabbable1 = 0x2 >= data end,
				[0xA3] = function(data) p.firing = data ~= 0 end, -- 攻撃中に値が入る ガード判断用
			}
			p.wp16 = {
				[0x64] = function(data) p.actb = data end,
				[0xBE] = function(data)
					if data == 0 or not p.proc_active then return end
					if p.attack ~= data then p.clear_damages() end
					local base_addr = db.chars[#db.chars].proc_base
					p.attack        = data
					p.forced_down   = 2 <= mem.r8(data + base_addr.forced_down)       -- テクニカルライズ可否 家庭用 05A9D6 からの処理
					p.hitstop       = math.max(2, mem.r8(data + base_addr.hitstop) - 1) -- ヒットストップ 家庭用 弾やられ側:05AE50 からの処理 OK
					p.blockstop     = math.max(2, p.hitstop - 1)                      -- ガード時の補正
					p.damage        = mem.r8(data + base_addr.damege)                 -- 補正前ダメージ 家庭用 05B146 からの処理
					p.stun          = mem.r8(data + base_addr.stun)                   -- 気絶値 家庭用 05C1B0 からの処理
					p.stun_timer    = mem.r8(data + base_addr.stun_timer)             -- 気絶タイマー 家庭用 05C1B0 からの処理
					p.max_hit_dn    = mem.r8(data + base_addr.max_hit)                -- 最大ヒット数 家庭用 061356 からの処理 OK
					p.grabbable2    = mem.r8((0xFFFF & (data + data)) + base_addr.baigaeshi) == 0x01 -- 倍返し可否
					apply_attack_infos(p, data, base_addr)
					-- ut.printf("%x %s %s  hitstun %s %s", data, p.hitstop, p.blockstop, p.hitstun, p.blockstun)
				end,
			}
			p.wp32 = {
				[0x00] = function(data)
					p.base, p.asm     = data, mem.r16(data)
					local proc_active = p.asm ~= 0x4E75 and p.asm ~= 0x197C
					local reset       = false
					if p.proc_active and not proc_active then reset, p.on_prefb = true, now() * -1 end
					if not p.proc_active and proc_active then reset, p.on_prefb = true, now() end
					if reset then
						p.grabbable, p.attack_id, p.attackbits = 0, 0, {}
						p.boxies, p.on_fireball, p.body.act_data = #p.boxies == 0 and p.boxies or {}, -1, nil
					end
					p.proc_active = proc_active
				end,
			}
			table.insert(body.objects, p)
			body.fireballs[base], all_objects[base] = p, p
		end
		for _, p in pairs(all_objects) do -- 初期化
			p.attackbits    = {}
			p.boxies        = {}
			p.bases         = ut.new_filled_table(16, { count = 0, addr = 0x0, act_data = nil, name = "", pos1 = 0, pos2 = 0, xmov = 0, })
			p.clear_damages = function()
				if not p.is_fireball then
					p.cancelable      = false
					p.cancelable_data = 0
					p.repeatable      = false
					p.forced_down     = false
					p.esaka_range     = 0
					p.pow_up_hit      = 0
					p.pow_up_block    = 0
					p.pow_revenge     = 0
					p.pow_absorb      = 0
					p.pow_up_hit      = 0
					p.pow_revenge     = 0
					p.pow_up          = 0
					p.pow_up_direct   = 0
				end
				p.hitstop = 0
				p.hitstun = 0
				p.blockstop = 0
				p.blockstun = 0
				p.damage = 0
				p.chip = 0
				p.stun = 0
				p.stun_timer = 0
				p.effect = 0
				p.forced_down = false
				p.max_hit_dn = 0
			end
			p.clear_frame_data = function()
				p.frame_gap        = p.frame_gap or 0
				p.act_frames       = {}
				p.frame_groups     = {}
				p.act_frames_total = 0
				p.fb_frames        = { act_frames = {}, frame_groups = {}, }
				p.gap_frames       = { act_frames = {}, frame_groups = {}, }
			end
			p.clear_frame_data()
			local old_copy = function(src)
				if type(src) ~= "table" then return src end
				local dest = {}
				for k, v in pairs(src) do if v ~= nil and type(v) ~= "table" then dest[k] = v end end
				return dest
			end
			p.old_copy = function() p.old = old_copy(p) end
			p.old_copy()
		end
	end
	local change_player_input = function()
		if in_player_select ~= true then return end
		local a4, sel              = mem.rg("A4", 0xFFFFFF), mem.r8(0x100026)
		local p_num, op_num, p_sel = mem.r8(a4 + 0x12), 0, {}
		op_num, p_sel[p_num]       = 3 - p_num, a4 + 0x13
		if sel == op_num and p_sel[op_num] then mem.w8(p_sel[p_num], op_num) end -- プレイヤー選択時に1P2P操作を入れ替え
	end
	local common_p = {                                                     -- プレイヤー別ではない共通のフック
		wp8 = {
			[0x10B862] = function(data) mem._0x10B862 = data end,          -- 押し合い判定で使用
			--[0x107C1F] = function(data) global.skip_frame1 = data ~= 0 end, -- 潜在能力強制停止
			[0x107EBF] = function(data) global.skip_frame2 = data ~= 0 end, -- 潜在能力強制停止
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
		},
		rp8 = {
			[{ addr = 0x107C1F, filter = 0x39456 }] = function(data)
				local p = get_object_by_reg("A4", {})
				if p.bs_hook then
					if p.bs_hook.ver then
						--ut.printf("bs_hook1 %x %x", p.bs_hook.id, p.bs_hook.ver)
						mem.w8(p.addr.base + 0xA3, p.bs_hook.id)
						mem.w16(p.addr.base + 0xA4, p.bs_hook.ver)
					else
						--ut.printf("bs_hook2 %x %x", p.bs_hook.id, p.bs_hook.f)
						mem.w8(p.addr.base + 0xD6, p.bs_hook.id)
						mem.w8(p.addr.base + 0xD7, p.bs_hook.f)
					end
				end
			end,
		},
		rp16 = {
			[{ addr = 0x107BB8, filter = {
				0xF6AC,                          -- BGMロード鳴らしたいので  --[[ 0x1589Eと0x158BCは雨発動用にそのままとする ]]
				0x17694,                         -- 必要な事前処理ぽいので
				0x1E39A,                         -- FIXの表示をしたいので
				0x22AD8,                         -- データロードぽいので
				0x22D32,                         -- 必要な事前処理ぽいので
			} }] = function(data, ret) ret.value = 1 end, -- 双角ステージの雨バリエーション時でも1ラウンド相当の前処理を行う
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
	local hide_wps = {
		wp8 = {
			[0x107C22] = function(data, ret)
				if ut.tstb(global.hide, hide_options.meters, true) and data == 0x38 then -- ゲージのFIX非表示
					ret.value = 0x0
					mem.w8(0x10E024, 0x3)                                                -- 3にしないと0x107C2Aのカウントが進まなくなる
				end
				if ut.tstb(global.hide, hide_options.background, true) and mem.r8(0x107C22) > 0 then -- 背景消し
					mem.w8(0x107762, 0x00)
					mem.w16(0x401FFE, 0x5ABB)                                            -- 背景色
				end
			end,
		},
		rp8 = {
			[{ addr = 0x107765, filter = { 0x40EE, 004114, 0x413A } }] = function(_, ret)
				local pc = mem.pc()
				local a = mem.rg("A4", 0xFFFFFF)
				local b = mem.r32(a + 0x8A)
				local c = mem.r16(a + 0xA) + 0x100000
				local d = mem.r16(c + 0xA) + 0x100000
				local e = (mem.r32(a + 0x18) << 32) + mem.r32(a + 0x1C)
				local p_bases = { a, b, c, d, } -- ベースアドレス候補
				if db.p_chan[e] then ret.value = 0 end
				for i, addr, p in ifind(p_bases, get_object_by_addr) do
					--ut.printf("%s %s %6x", global.frame_number, i, addr)
					if i == 1 and ut.tstb(global.hide, hide_options["p" .. p.num .. "_char"], true) then
						ret.value = 4
					elseif i == 2 and ut.tstb(global.hide, hide_options["p" .. p.num .. "_phantasm"], true) then
						ret.value = 4
					elseif i >= 3 and ut.tstb(global.hide, hide_options["p" .. p.num .. "_effect"], true) then
						ret.value = 4
					end
					return
				end
				if ut.tstb(global.hide, hide_options.effect, true) then
					ret.value = 4
					return
				end
				--ut.printf("%6x %8x %8x %8x | %8x %16x %s", a, b, c, d, pc, e, data.get_obj_name(e))
			end,
		},
		rp16 = {
			[{ addr = 0x107BB0, filter = { 0x1728E, 0x172DE } }] = function(data, ret) -- 影消し or 双角ステージの反射→影化
				if ut.tstb(global.hide, hide_options.shadow1 |hide_options.shadow2) then
					ret.value = ut.tstb(global.hide, hide_options.shadow1, true) and 2 or 0
				end
			end,
		},
	}
	local select_wps = {
		wp8 = {
			[{ addr = 0x107EC6, filter = 0x11DE8 }] = change_player_input,
		},
		rp8 = {
			[{ addr = 0x107EC6, filter = 0x11DC4 }] = function(data)
				if in_player_select ~= true then return end
				if data == mem.rg("D0", 0xFF) then change_player_input() end
			end,
		}
	}
	table.insert(all_wps, common_p)
	for base, p in pairs(all_objects) do
		-- 判定表示前の座標がらみの関数
		p.x, p.y, p.flip_x = 0, 0, 0
		p.calc_range_x = function(range_x) return p.x + range_x * p.flip_x end -- 自身の範囲の座標計算
		-- 自身が指定の範囲内かどうかの関数
		p.within = function(x1, x2) return (x1 <= p.op.x and p.op.x <= x2) or (x1 >= p.op.x and p.op.x >= x2) end

		p.wp8 = ut.hash_add_all(p.wp8, {
			[0x10] = p.update_char,
			[0x58] = function(data) p.block_side = ut.int8(data) < 0 and -1 or 1 end, -- 向き 00:左側 80:右側
			[0x66] = function(data)
				p.act_count = data                                           -- 現在の行動のカウンタ
				if p.is_fireball ~= true then
					local hits, shifts = p.max_hit_dn or 0, frame_attack_types.act_count
					if hits > 1 or hits == 0 or (p.char == 0x4 and p.attack == 0x16) then
						-- 連続ヒットできるものはカウントで区別できるようにする
						p.attackbits.act_count = data
					elseif ut.tstb(p.flag_cc, db.flag_cc.grabbing) and p.op.last_damage_scaled ~= 0xFF then
						p.attackbits.act_count = p.op.last_damage_scaled
					end
				end
			end,
			[0x67] = function(data) p.act_boxtype = 0xFFFF & (data & 0xC0 * 4) end, -- 現在の行動の判定種類
			[0x6A] = function(data)
				p.flag_6a = data
				--ut.printf("%X %X | %s", base, data, ut.tobitstr(data))
				p.repeatable = p.flag_c8 == 0 and (data & 0x4) == 0x4      -- 連打キャンセル判定
				p.flip_x1 = ((data & 0x80) == 0) and 0 or 1                -- 判定の反転
				local fake, fake_pc = ((data & 0xFB) == 0 or ut.tstb(data, 0x8) == false), mem.pc() == fix_addr(0x011DFE)
				p.attackbits.fake = fake_pc and fake
				p.attackbits.obsolute = (not fake_pc) and fake
				--if base == 0x100600 then ut.printf("W %s %X %X %X %s %s", now(), mem.pc(), base, data, (fake or fake2), ut.tobitstr(data)) end
			end,
			[0x6F] = function(data) p.act_frame = data end, -- 動作パターンの残フレーム
			[0x71] = function(data) p.flip_x2 = (data & 1) end, -- 判定の反転
			[0x73] = function(data) p.box_scale = data + 1 end, -- 判定の拡大率
			--[0x76] = function(data) ut.printf("%X %X %X", base + 0x76, mem.pc(), data) end,
			[0x7A] = function(data)                    -- 攻撃判定とやられ判定
				--if base == 0x100600 then ut.printf("W %s box %X %X %X %X %s data", now(), mem.pc(), base, mem.r8(base + 0x6A), data, p.attackbits.fake) end
				--p.attackbits.pre = p.attackbits.pre_fake
				--ut.printf("box %x %x %x", p.addr.base, mem.pc(), data)
				p.boxies, p.grabbable = {}, 0
				if data <= 0 then return end
				p.attackbits.fb = p.is_fireball
				p.attackbits.attacking = false
				p.attackbits.juggle = false
				p.attackbits.fb_effect = 0
				local a2base = mem.r32(base + 0x7A)
				for a2 = a2base, a2base + (data - 1) * 5, 5 do -- 家庭用 004A9E からの処理
					local id = mem.r8(a2)
					local top, bottom = sort_ba(mem.r8i(a2 + 0x1), mem.r8i(a2 + 0x2))
					local left, right = sort_ba(mem.r8i(a2 + 0x3), mem.r8i(a2 + 0x4))
					local type = db.main_box_types[id] or (id < 0x20) and db.box_types.unknown or db.box_types.attack
					p.attack_id = type == db.box_types.attack and id or p.attack_id
					local blockable, possible, possibles
					if type == db.box_types.attack then
						possibles              = get_hitbox_possibles(p.attack_id)
						p.effect               = mem.r8(p.attack_id + db.chars[#db.chars].proc_base.effect) -- ヒット効果
						p.attackbits.attacking = true
						p.attackbits.juggle    = possibles.juggle and true or false
						if p.is_fireball then
							p.attackbits.fb_effect = p.effect
							p.on_fireball = p.on_fireball < 0 and now() or p.on_fireball
						else
							p.attackbits.fb_effect = 0
						end
						possible = ut.hex_set(ut.hex_set(possibles.normal, possibles.sway_standing), possibles.sway_crouching)
						blockable = db.act_types.unblockable -- ガード属性 -- 不能
						if possibles.crouching_block and possibles.standing_block then
							blockable = db.act_types.attack -- 上段
						elseif possibles.crouching_block then
							blockable = db.act_types.low_attack -- 下段
						elseif possibles.standing_block then
							blockable = db.act_types.overhead -- 中段
						end
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
						sway_type = db.sway_box_types[id] or type,
						possibles = possibles or {},
						possible = possible or 0,
						blockable = blockable or 0,
					})
					-- ut.printf("p=%x %x %x %x %s addr=%x id=%02x l=%s r=%s t=%s b=%s", p.addr.base, data, base, p.box_addr, 0, a2, id, x1, x2, y1, y2)
				end
			end,
			[0x8D] = function(data)
				p.hitstop_remain, p.in_hitstop = data, (data > 0 or (p.hitstop_remain and p.hitstop_remain > 0)) and now() or p.in_hitstop -- 0になるタイミングも含める
			end,
			[0xAA] = function(data)
				p.attackbits.fullhit = data ~= 0
				--ut.printf("full %X %s %X", p.act or 0, now(), data)
				if p.is_fireball and data == 0xFF then p.on_fireball = now() * -1 end
			end,
			[0xAB] = function(data) p.max_hit_nm = data end, -- 同一技行動での最大ヒット数 分子
			[0xB1] = function(data) p.hurt_invincible = data > 0 end, -- やられ判定無視の全身無敵
			[0xE9] = function(data) p.dmg_id = data end,     -- 最後にヒット/ガードした技ID
			[0xEB] = function(data) p.hurt_attack = data end, -- やられ中のみ変化
		})
		--[[
		p.rp8 = ut.hash_add_all(p.rp8, {
			[0x6A] = function(data)
				if base == 0x100600 then
					ut.printf("R %s %X %X %X %s %s", now(), mem.pc(), base, data, "", ut.tobitstr(data))
				end
			end,
		})
		]]
		p.wp16 = ut.hash_add_all(p.wp16, {
			[0x20] = function(data) p.pos, p.max_pos, p.min_pos = data, math.max(p.max_pos or 0, data), math.min(p.min_pos or 1000, data) end,
			[0x22] = function(data) p.pos_frc = ut.int16tofloat(data) end,                                                         -- X座標(小数部)
			[0x24] = function(data)
				p.pos_z, p.on_sway_line, p.on_main_line = data, 40 == data and now() or p.on_sway_line, 24 == data and now() or p.on_main_line -- Z座標
			end,
			[0x28] = function(data) p.pos_y = ut.int16(data) end,                                                                  -- Y座標
			[0x2A] = function(data) p.pos_frc_y = ut.int16tofloat(data) end,                                                       -- Y座標(小数部)
			[{ addr = 0x5E, filter = 0x011E10 }] = function(data) p.box_addr = mem.rg("A0", 0xFFFFFFFF) - 0x2 end,                 -- 判定のアドレス
			[0x60] = function(data)
				p.act, p.on_update_act = data, now()                                                                               -- 行動ID デバッグディップステータス表示のPと同じ
				p.attackbits.act = data
				if p.is_fireball then
					p.act_data = p.body.char_data and p.body.char_data.fireballs[data] or p.act_data
				elseif p.char_data then
					p.act_data = p.char_data.acts[data] or p.act_data
				end
			end,
			[0x62] = function(data) p.acta = data end, -- 行動ID デバッグディップステータス表示のAと同じ
		})
		table.insert(all_wps, p)
	end

	-- 場面変更
	local apply_1p2p_active = function()
		if in_match and mem.r8(0x1041D3) == 0 then
			mem.w8(0x100024, 0x03)
			mem.w8(0x100027, 0x03)
		end
	end

	local goto_player_select = function()
		mod.fast_select()
		mem.w8(0x1041D3, 0x01)     -- 乱入フラグON
		mem.w8(0x107BB5, 0x01)
		mem.w32(0x107BA6, 0x00010001) -- CPU戦の進行数をリセット
		local _, _, on2 = accept_input("a")
		if on2 then
			mem.w32(0x100024, 0x02020002)
			mem.w16(0x10FDB6, 0x0202)
		else
			mem.w32(0x100024, 0x01010001)
			mem.w16(0x10FDB6, 0x0101)
		end
		mem.w16(0x1041D6, 0x0003) -- 対戦モード3
	end

	local restart_fight = function(param)
		param              = param or {}
		global.next_stg3   = param.next_stage.stg3 or mem.r16(0x107BB8)
		local p1, p2       = param.next_p1 or 1, param.next_p2 or 21
		local p1col, p2col = param.next_p1col or 0x00, param.next_p2col or 0x01
		mod.fast_restart()
		mem.w8(0x1041D3, 0x01)     -- 乱入フラグON
		mem.w8(0x107C1F, 0x00)     -- キャラデータの読み込み無視フラグをOFF
		mem.w32(0x107BA6, 0x00010001) -- CPU戦の進行数をリセット
		mem.w8(0x100024, 0x03)
		mem.w8(0x100027, 0x03)
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
	for i, preset_cmd in ipairs(db.research_cmd) do
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
			p.char_data = db.chars[p.char]

			do_recover(p, true)

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
		local pos        = { players[1].cmd_side, players[2].cmd_side }
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
		local pos = { players[1].cmd_side, players[2].cmd_side }
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
		local pos = { players[1].cmd_side, players[2].cmd_side }
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
			recording.active_slot = { store = {}, name = "EMPTY" }
		end

		if #recording.active_slot.store > 0 and (accept_input("st") or force_start_play == true) then
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
					do_recover(p, true)
					p.old.frame_gap = 0
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
			players[1].cmd_side = mem.r8(players[1].addr.cmd_side)
			players[2].cmd_side = mem.r8(players[2].addr.cmd_side)

			-- 入力リセット
			local next_joy      = new_next_joy()
			for _, joy in ipairs(use_joy) do
				to_joy[joy.field] = next_joy[joy.field] or false
			end
			return
		end
	end
	-- 繰り返しリプレイ待ち
	rec_repeat_play = function(to_joy)
		-- 繰り返し前の行動が完了するまで待つ
		local p, op, p_ok = players[3 - recording.player], players[recording.player], true
		if global.await_neutral == true then
			p_ok = p.act_normal or (not p.act_normal and p.on_update_act == global.frame_number and recording.last_act ~= p.act)
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

		if accept_input("st") then
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
			local pos = { players[1].cmd_side, players[2].cmd_side }
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

		if accept_input("st") then
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
			if frame1 and frame1.count > 332 then min_count = math.min(min_count, frame1.count) end

			frame1 = p.fb_frames.act_frames[#p.fb_frames.act_frames]
			if frame1 and frame1.count > 332 then min_count = math.min(min_count, frame1.count) end

			frame1 = p.gap_frames.act_frames[#p.gap_frames.act_frames]
			if frame1 and frame1.count > 332 then min_count = math.min(min_count, frame1.count) end
		end

		local fix = min_count - 332
		for _, p in ipairs(players) do
			local frame1 = p.act_frames[#p.act_frames]
			if frame1 then frame1.count = frame1.count - fix end

			frame1 = p.fb_frames.act_frames[#p.fb_frames.act_frames]
			if frame1 then frame1.count = frame1.count - fix end

			frame1 = p.gap_frames.act_frames[#p.gap_frames.act_frames]
			if frame1 then frame1.count = frame1.count - fix end
		end
	end

	-- 技名でグループ化したフレームデータの配列をマージ生成する
	local update_frame_groups = function(frame, frame_groups)
		local last_group = frame_groups[#frame_groups]
		local last_frame = last_group and last_group[#last_group] or nil
		if not last_frame or last_frame.name ~= frame.name or     -- 名前違いでブレイク
			(frame.update and frame.count == 1)                  -- カウンタでブレイク
		then
			table.insert(frame_groups, { frame })                 -- ブレイクしたので新規にグループ作成
			while 180 < #frame_groups do table.remove(frame_groups, 1) end --バッファ長調整
			frame.last_total = 0                                  -- グループの先頭はフレーム合計ゼロ開始
			return true
		elseif last_frame and last_frame ~= frame then
			table.insert(last_group, frame)                   -- 同一グループに合計加算して保存
			frame.last_total = last_frame.last_total + last_frame.count
			while 180 < #last_group do table.remove(last_group, 1) end --バッファ長調整
		end
		return false
	end

	-- グラフでフレームデータを末尾から描画
	local dodraw = function(y, txty, frame_group, main_frame, height, xmin, xmax)
		if #frame_group == 0 then return end
		local x1 = frame_group[#frame_group].last_total + frame_group[#frame_group].count + xmin
		x1 = xmax < x1 and xmax or x1
		if main_frame and (frame_group[1].col + frame_group[1].line) > 0 then
			draw_text_with_shadow(xmin + 12, txty + y, frame_group[1].name, 0xFFC0C0C0) -- 名称を描画
		end
		local frame_txts = {}
		for k = #frame_group, 1, -1 do
			local frame = frame_group[k]
			local x2 = x1 - frame.count
			if x2 + x1 < xmin and not main_frame then
				break
			elseif x2 < xmin then
				x2 = xmin
			end

			if ((frame.col or 0) + (frame.line or 0)) > 0 then
				local evx, deco1, deco2, deco3, dodge = math.min(x1, x2), nil, nil, nil, ""
				if ut.tstb(frame.attackbit, frame_attack_types.off_fireball) then deco1 = "○" end
				if ut.tstb(frame.attackbit, frame_attack_types.post_fireball) then deco2 = "◇" end
				if ut.tstb(frame.attackbit, frame_attack_types.pre_fireball) then deco2 = "◆" end
				if ut.tstb(frame.attackbit, frame_attack_types.on_fireball) then deco1 = "●" end
				if ut.tstb(frame.attackbit, frame_attack_types.on_air) then deco3 = "▴" end
				if ut.tstb(frame.attackbit, frame_attack_types.on_ground) then deco3 = "▾" end
				if deco2 then
					scr:draw_text(evx - get_string_width(deco2) * 0.35, txty + y - 6, deco2)
					scr:draw_line(x2, y, x2, y + height)
				elseif deco1 then
					scr:draw_text(evx - get_string_width(deco1) * 0.4, txty + y - 6, deco1)
					scr:draw_line(x2, y, x2, y + height)
				elseif deco3 then
					scr:draw_text(evx - get_string_width(deco3) * 0.5, txty + y - 4.5, deco3)
					scr:draw_line(x2, y, x2, y + height)
				end
				scr:draw_box(x1, y, x2, y + height, frame.line, frame.col)
				if frame.xline and frame.xline > 0 then
					if ut.tstb(frame.attackbit, frame_attack_types.full) then
						for i = 0.5, height, 1.5 do scr:draw_box(x1, y + i, x2, math.min(y + height, y + i + 0.5), 0, frame.xline) end
						dodge = "Full"
					elseif ut.tstb(frame.attackbit, frame_attack_types.high) then
						for i = 1.5, height, 3 do scr:draw_box(x1, y + i, x2, math.min(y + height, y + i + 1), 0, frame.xline) end
						dodge = "High"
					else -- if ut.tstb(frame.attackbit, frame_attack_types.low) then
						for i = 1.5, height, 3 do scr:draw_box(x1, y + i, x2, math.min(y + height, y + i + 1), 0, frame.xline) end
						dodge = "Low"
					end
				end
				local txtx = (frame.count > 5) and (x2 + 1) or (3 > frame.count) and (x2 - 1) or x2
				local count_txt = 300 < frame.count and "LOT" or ("" .. frame.count)
				local font_col = frame.font_col or 0xFFFFFFFF
				if font_col > 0 then draw_text_with_shadow(txtx, txty + y, count_txt, font_col) end

				--[[ TODO きれいなテキスト化
				dodge = ""
				table.insert(frame_txts, 1, string.format("%s%s%s", deco1 or deco2 or "", count_txt, dodge))
				]]
			end
			if x2 <= xmin then break end
			x1 = x2
		end
		scr:draw_text(xmax - 40, txty + y, table.concat(frame_txts, "/"))
	end
	local draw_frames = function(frame_groups, xmax, x, y, height, span_ratio)
		if frame_groups == nil or #frame_groups == 0 then return end
		local span = (2 + span_ratio) * height
		-- 縦に描画
		if #frame_groups < 7 then y = y + (7 - #frame_groups) * span end
		for j = #frame_groups - math.min(#frame_groups - 1, 6), #frame_groups do
			dodraw(y, 0, frame_groups[j], true, height, x, xmax)
			for _, frame in ipairs(frame_groups[j]) do
				for _, sub_group in ipairs(frame.fb_frames or {}) do
					dodraw(y, 0, sub_group, false, height, x, xmax)
				end
				for _, sub_group in ipairs(frame.gap_frames or {}) do
					dodraw(y + get_line_height(), -0.5, sub_group, false, height - 1, x, xmax)
				end
			end
			y = y + span
		end
	end
	local draw_frame_groups = function(frame_groups, act_frames_total, x, y, height, show_count)
		if #frame_groups == 0 then return end

		-- 横に描画
		local xmin = x                                              --30
		local xa, xb, xmax = 325 - xmin, act_frames_total + xmin, 0
		xmax = xa < xb and xa or (act_frames_total + xmin) % (325 - xmin) -- 左寄せで開始
		-- xmax = math.min(325 - xmin, act_frames_total + xmin) -- 右寄せで開始
		local x1, loopend = xmax, false
		for j = #frame_groups, 1, -1 do
			local frame_group, first = frame_groups[j], true
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

	do_recover = function(p, force)
		-- 体力と気絶値とMAX気絶値回復
		local life = { 0xC0, 0x60, 0x00 }
		local max_life = life[p.red] or (p.red - #life) -- 赤体力にするかどうか
		local init_stuns = p.char_data and p.char_data.init_stuns or 0
		if dip_config.infinity_life then
			mem.w8(p.addr.life, max_life)
			mem.w8(p.addr.stun_limit, init_stuns) -- 最大気絶値
			mem.w8(p.addr.init_stun, init_stuns) -- 最大気絶値
		elseif p.life_rec then
			if force or (p.addr.life ~= max_life and 180 < math.min(p.throw_timer, p.op.throw_timer)) then
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

	local proc_frame = function(p)
		local col, font_col, line, xline, attackbit = 0xAAF0E68C, 0xFFFFFFFF, 0xDDF0E68C, 0, 0
		for _, xp in ipairs(p.objects) do
			if p.skip_frame then
			elseif p.in_hitstop == global.frame_number or p.on_hit_any == global.frame_number then
			elseif xp.proc_active and xp.hitbox_types and #xp.hitbox_types > 0 and xp.hitbox_types then
				attackbit = attackbit | p.attackbit
				table.sort(xp.hitbox_types, function(t1, t2) return t1.sort > t2.sort end) -- ソート
				if xp.hitbox_types[1].sort < 3 and xp.repeatable then
					col, line = 0xAAD2691E, 0xDDD2691E                         -- やられ判定より連キャン状態を優先表示する
				else
					col, line = xp.hitbox_types[1].fill, xp.hitbox_types[1].outline
					col = col > 0xFFFFFF and (col | 0x22111111) or 0
				end
			end
			if not xp.is_fireball then
				-- 本体状態
				if xp.skip_frame then
					col, line = 0xAA000000, 0xAA000000
				elseif xp.on_bs_established == global.frame_number then
					col, line = 0xAA0022FF, 0xDD0022FF
				elseif xp.on_bs_clear == global.frame_number then
					col, line = 0xAA00FF22, 0xDD00FF22
				elseif xp.in_hitstop == global.frame_number or xp.on_hit_any == global.frame_number then
					col, line = 0xAA444444, 0xDD444444
				elseif xp.on_bs_check == global.frame_number then
					col, line = 0xAAFF0022, 0xDDFF0022
				end

				-- 無敵
				if p.skip_frame or p.in_hitstop == global.frame_number or p.on_hit_any == global.frame_number or p.jumping then
					-- 無視
				elseif ut.tstb(p.hurt.dodge, frame_attack_types.full, true) then
					attackbit, xline = attackbit | frame_attack_types.full, 0xFF00FFFF -- 全身無敵
				elseif ut.tstb(p.hurt.dodge, frame_attack_types.frame_dodges) then
					attackbit, xline = attackbit | frame_attack_types.frame_dodges, 0xFF00BBDD -- 部分無敵
				end

				-- フレーム差
				if p.frame_gap > 0 then
					attackbit, font_col = attackbit | frame_attack_types.frame_plus, 0xFF0088FF
				elseif p.frame_gap < 0 then
					attackbit, font_col = attackbit | frame_attack_types.frame_minus, 0xFFFF0088
				end
			end
		end

		-- フレーム数表示
		local attackbit_mask = frame_attack_types.simple_mask
		if p.disp_frm == 2 then -- 2:ON
			if p.max_hit_dn and p.max_hit_dn > 0 and p.attackbits.attacking and not p.attackbits.fake then
				attackbit_mask = 0xFFFFFFFFFFFFFFFF
			end
		elseif p.disp_frm == 3 then -- 3:ON:判定の形毎
			attackbit_mask = 0xFFFFFFFFFFFFFFFF
		elseif p.disp_frm == 4 then -- 4:ON:攻撃判定の形毎
			if p.attackbits.attacking and not p.attackbits.fake then
				attackbit_mask = 0xFFFFFFFFFFFFFFFF
			end
		elseif p.disp_frm == 5 then -- 5:ON:くらい判定の形毎
			if not p.attackbits.attacking or p.attackbits.fake then
				attackbit_mask = 0xFFFFFFFFFFFFFFFF
			end
		end
		attackbit      = attackbit & attackbit_mask
		--ut.printf("%x %x %x | %s", p.num, attackbit_mask, attackbit, ut.tobitstr(attackbit, " "))

		local frame    = p.act_frames[#p.act_frames]
		local prev     = frame and frame.name
		local act_data = p.body.act_data
		local name     = (frame and act_data.name_set and act_data.name_set[prev]) and prev or act_data.name

		if p.update_act or not frame or frame.col ~= col or frame.key ~= attackbit then
			-- 弾とジャンプ状態はキーから省いて無駄な区切りを取り除く
			local key_mask = ut.hex_clear(0xFFFFFFFFFFFFFFFF, frame_attack_types.mask_fireball | frame_attack_types.mask_jump)
			--行動IDの更新があった場合にフレーム情報追加
			frame = ut.table_add(p.act_frames, {
				act        = p.act,
				count      = 1,
				name       = name,
				col        = col,
				line       = line,
				xline      = xline,
				update     = p.update_act,
				attackbit  = attackbit,
				key        = key_mask & attackbit,
				fb_frames  = {},
				gap_frames = {},
			}, 180)
		elseif frame then
			frame.count = frame.count + 1                      --同一行動IDが継続している場合はフレーム値加算
		end
		local upd_group = update_frame_groups(frame, p.frame_groups) -- フレームデータをグループ化
		-- 表示可能範囲（最大で横画面幅）以上は加算しない
		p.act_frames_total = not p.act_frames_total and 0 or (332 < p.act_frames_total) and 332 or (p.act_frames_total + 1)

		local last_frame, key = frame, nil
		local parent, frames, groups = nil, nil, nil

		-- 弾処理
		---@diagnostic disable-next-line: unbalanced-assignments
		parent, frames, groups = last_frame and last_frame.fb_frames or nil, p.fb_frames.act_frames, p.fb_frames.frame_groups
		key, frame = p.attackbit, frames[#frames]
		if p.update_act or not frame or upd_group or frame.key ~= key then
			frame = ut.table_add(frames, {
				act = p.act,
				count = 1,
				font_col = 0,
				name = last_frame.name,
				col = 0x00FFFFFF,
				line = 0x00FFFFFF,
				update  = p.update_act,
				attackbit  = p.attackbit,
				key = key,
			}, 180)
		else
			frame.count = frame.count + 1
		end
		if update_frame_groups(frame, groups) and parent and groups then ut.table_add(parent, groups[#groups], 180) end

		-- フレーム差
		---@diagnostic disable-next-line: unbalanced-assignments
		parent, frames, groups = last_frame and last_frame.gap_frames or nil, p.gap_frames.act_frames, p.gap_frames.frame_groups
		key, frame = attackbit & frame_attack_types.mask_frame_advance, frames[#frames]
		if p.update_act or not frame or upd_group or frame.key ~= key then
			frame = ut.table_add(frames, {
				act = p.act,
				count = 1,
				font_col = font_col,
				name = last_frame.name,
				col = 0x22FFFFFF & font_col,
				line = 0xCCFFFFFF & font_col,
				update  = p.update_act,
				key = key,
			}, 180)
		else
			frame.count = frame.count + 1
		end
		if update_frame_groups(frame, groups) and parent and groups then ut.table_add(parent, groups[#groups], 180) end
	end

	local input_rvs = function(rvs_type, p, logtxt)
		if global.rvslog and logtxt then emu.print_info(logtxt) end
		if ut.tstb(p.dummy_rvs.hook_type, hook_cmd_types.throw) then
			if p.act == 0x9 and p.act_frame > 1 then return end -- 着地硬直は投げでないのでスルー
			if p.op.in_air then return end
			if p.op.sway_status ~= 0x00 then return end -- 全投げ無敵
		elseif ut.tstb(p.dummy_rvs.hook_type, hook_cmd_types.jump) then
			if p.state == 0 and p.old.state == 0 and (p.flag_c0 | p.old.flag_c0) & 0x10000 == 0x10000 then
				return -- 連続通常ジャンプを繰り返さない
			end
		end
		p.bs_hook = p.dummy_rvs.id and p.dummy_rvs or nil
		if p.dummy_rvs.cmd_type then
			if rvs_types.knock_back_recovery ~= rvs_type then
				if (((p.flag_c0 | p.old.flag_c0) & 0x2 == 0x2) or db.pre_down_acts[p.act]) and p.dummy_rvs.cmd_type == db.cmd_types._2d then
					-- no act
				else
					p.bs_hook = p.dummy_rvs
				end
			end
		end
	end

	-- フラグから技データを返す
	local gen_act_data = function(p)
		local name
		if p.flag_c4 == 0 and p.flag_c8 == 0 then
			name = ut.tstb(p.flag_cc, db.flag_cc.blocking) and "ガード" or p.flag_cc > 0 and
				db.get_flag_name(p.flag_cc, db.flag_names_cc) or db.get_flag_name(p.flag_c0, db.flag_names_c0)
		elseif p.flag_c4 > 0 and p.flag_c8 == 0 and not ut.tstb(p.flag_cc, db.flag_cc._00) then
			local slide = ut.tstb(p.flag_cc, db.flag_cc._02) and db.get_flag_name(db.flag_cc._02, db.flag_names_cc) or ""
			local close
			if ut.tstb(p.flag_c4, db.flag_c4._01 | db.flag_c4._02) then
				close = p.main_d_close and "近" or "遠"
			elseif ut.tstb(p.flag_c4, db.flag_c4._03 | db.flag_c4._04 | db.flag_c4._05) then
				close = p.sway_close and "近" or "遠"
			elseif ut.tstb(p.flag_c4, db.flag_c4._29 | db.flag_c4._30 | db.flag_c4._31) then
				close = p.stand_close and "近" or "遠"
			end
			name = string.format("%s%s%s", slide, close or "", db.get_flag_name(p.flag_c4, db.flag_names_c4))
		else
			return nil
		end
		p.act_data_cache = p.act_data_cache or {}
		local act_data = p.act_data_cache[name]
		if not act_data then
			act_data = { bs_name = name, name = name, normal_name = name, slide_name = name, type = db.act_types.free | db.act_types.startup, count = 1 }
			p.act_data_cache[name] = act_data
		end
		return act_data
	end

	-- トレモのメイン処理
	menu.tra_main.proc = function()
		if not in_match or mem._0x10E043 ~= 0 then return end -- ポーズ中は状態を更新しない
		if global.pause then                            -- ポーズ解除判定
			local curr, prev = get_joy()
			if input_1f("a", curr, prev) or input_1f("b", curr, prev) or input_1f("c", curr, prev) or input_1f("d", curr, prev) then
				global.pause = false
				set_freeze(true)
				for _, joy in ipairs(use_joy) do ioports[joy.port].fields[joy.field]:set_value(0) end
			end
			return
		end
		global.pause = false
		if menu.reset_pos then menu.update_pos() end
		global.frame_number = global.frame_number + 1
		set_freeze((not in_match) or true) -- ポーズ解除状態

		local next_joy, joy_val, state_past = new_next_joy(), get_joy(), scr:frame_number() - global.input_accepted

		-- スタートボタン（リプレイモード中のみスタートボタンおしっぱでメニュー表示へ切り替え
		if (global.dummy_mode == 6 and is_start_a(joy_val, state_past)) or
			(global.dummy_mode ~= 6 and accept_input("st", joy_val, state_past)) then
			-- メニュー表示状態へ切り替え
			global.input_accepted, menu.state = global.frame_number, menu
			cls_joy()
			return
		end

		if global.lag_frame == true then return end -- ラグ発生時は処理をしないで戻る

		global.old_all_act_normal, global.all_act_normal = global.all_act_normal, true
		for _, p in pairs(all_objects) do p.old_copy() end

		-- 1Pと2Pの状態読取
		for i, p in ipairs(players) do
			local op = players[3 - i]
			p.op     = op
			p.update_char(mem.r8(p.addr.char))
			p.change_c0 = p.flag_c0 ~= p.old.flag_c0
			p.change_c4 = p.flag_c4 ~= p.old.flag_c4
			p.change_c8 = p.flag_c8 ~= p.old.flag_c8
			p.sliding   = ut.tstb(p.flag_cc, db.flag_cc._02) -- ダッシュ滑り攻撃
			-- やられ状態
			if p.flag_fin or ut.tstb(p.flag_c0, db.flag_c0._16) then
				-- 最終フレームか着地フレームの場合は前フレームのを踏襲する
				p.in_hitstun = p.in_hitstun
			elseif p.flag_c8 == 0 and p.hurt_state then
				p.in_hitstun = p.hurt_state > 0 or
					ut.tstb(p.flag_cc, db.flag_cc.hitstun) or
					ut.tstb(p.flag_d0, db.flag_d0._06) or -- ガード中、やられ中
					ut.tstb(p.flag_c0, db.flag_c0._01) -- ダウン
			else
				p.in_hitstun = false
			end
			if ut.tstb(p.flag_c4, db.flag_c4.hop) then
				p.pos_miny = p.char_data.min_sy
			elseif ut.tstb(p.flag_c4, db.flag_c4.jump) then
				p.pos_miny = p.char_data.min_y
			end
			p.last_normal_state = p.normal_state
			p.normal_state      = p.state == 0                                                                                 -- 素立ち
			-- 通常投げ無敵判断 その2(HOME 039FC6から03A000の処理を再現して投げ無敵の値を求める)
			p.throwable         = p.state == 0 and op.state == 0 and p.throw_timer > 24 and p.sway_status == 0x00 and p.invincible == 0 -- 投げ可能ベース
			p.n_throwable       = p.throwable and p.tw_muteki2 == 0                                                            -- 通常投げ可能
			p.thrust            = p.thrust + p.thrust_frc
			p.inertia           = p.inertia + p.inertia_frc
			p.inertial          = not p.sliding and p.thrust == 0 and p.inertia > 0 and ut.tstb(p.flag_c0, db.flag_c0._31) -- ダッシュ慣性残し
			p.pos_total         = p.pos + p.pos_frc
			p.diff_pos_total    = p.old.pos_total and p.pos_total - p.old.pos_total or 0
			p.in_air            = 0 ~= p.pos_y or 0 ~= p.pos_frc_y
			-- ジャンプの遷移ポイントかどうか
			if not p.old.in_air and p.in_air then
				p.attackbits.on_air, p.attackbits.on_ground = true, false
			elseif p.old.in_air and not p.in_air then
				p.attackbits.on_air, p.attackbits.on_ground = false, true
			else
				p.attackbits.on_air, p.attackbits.on_ground = false, false
			end
			--p.attackbits.in_air, p.attackbits.in_ground = p.in_air, not p.in_air
			-- 高さが0になった時点でジャンプ中状態を解除する
			if p.attackbits.on_ground then p.jumping = false end
			-- ジャンプ以降直後に空中になっていればジャンプ中とみなす
			-- 部分無敵の判断にジャンプ中かどうかを使う
			p.jumping = ut.tstb(p.old.flag_c0, db.flag_c0._17, true) and p.attackbits.on_air or p.jumping
			p.pos_y_peek = p.in_air and math.max(p.pos_y_peek or 0, p.pos_y) or 0
			if p.pos_y < p.old.pos_y or (p.pos_y == p.old.pos_y and p.pos_frc_y < p.old.pos_frc_y) then
				p.pos_y_down = p.pos_y_down and (p.pos_y_down + 1) or 1
			else
				p.pos_y_down = 0
			end

			-- キャンセル可否家庭用2AD90からの処理と各種呼び出し元からの断片
			p.cancelable = false
			if p.attack and p.attack < 0x70 then
				if (p.cancelable_data + p.cancelable_data) > 0xFF then
					p.cancelable = ut.tstb(p.flag_7e, db.flag_7e._05, true)
				elseif (p.cancelable_data << 2) > 0xFF then
					p.cancelable = ut.tstb(p.flag_7e, db.flag_7e._04, true)
				end
			end

			-- ガード持続の種類 家庭用 0271FC からの処理 0:攻撃無し 1:ガード継続小 2:ガード継続大
			if p.firing then
				p.kagenui_type = 2
			elseif p.attack and p.attack ~= 0 then
				local b2 = 0x80 == (0x80 & pgm:read_u8(pgm:read_u32(0x8C9E2 + p.char4) + p.attack))
				p.kagenui_type = b2 and 3 or 2
			else
				p.kagenui_type = 1
			end

			-- ライン送らない状態のデータ書き込み
			if p.dis_plain_shift then mem.w8(p.addr.hurt_state, p.hurt_state | 0x40) end

			--フレーム用
			p.skip_frame   = global.skip_frame1 or global.skip_frame2 or p.skip_frame
			p.old.act_data = p.act_data or { name = "", type = db.act_types.startup | db.act_types.free, }
			p.act_data = gen_act_data(p)
			if not p.act_data then
				if p.char_data.acts and p.char_data.acts[p.act] then
					p.act_data = p.char_data.acts[p.act]
				else
					p.act_data.name = string.format("%X", p.act)
				end
				-- 技動作は滑りかBSかを付与する
				p.act_data.name = p.sliding and p.act_data.slide_name or p.in_bs and p.act_data.bs_name or p.act_data.normal_name
			end

			-- ガード移行可否
			p.act_normal = true
			if ut.tstb(p.flag_c0, 0x3FFD723) or (p.attack_data | p.flag_c4 | p.flag_c8) ~= 0 or ut.tstb(p.flag_cc, 0xFFFFFF3F) or
				not ut.tstb(p.act_data.type, db.act_types.free | db.act_types.block) then
				global.all_act_normal, p.act_normal = false, false
			end
			if i == 2 then
				local p1, p2 = p.op, p
				if p1.act_normal == p2.act_normal then
					p1.frame_gap, p2.frame_gap = 0, 0
				elseif not p1.act_normal then
					p1.frame_gap, p2.frame_gap = p1.frame_gap - 1, p2.frame_gap + 1
				else --if not p2.act_normal then
					p1.frame_gap, p2.frame_gap = p1.frame_gap + 1, p2.frame_gap - 1
				end
			end

			-- 飛び道具の状態読取
			p.attackbits.pre_fireball = false
			p.attackbits.post_fireball = false
			p.attackbits.on_fireball = false
			p.attackbits.off_fireball = false
			for _, fb in pairs(p.fireballs) do
				if fb.proc_active then
					global.all_act_normal = false
					fb.skip_frame = p.skip_frame -- 親オブジェクトの停止フレームを反映
					p.attackbits.pre_fireball = p.attackbits.pre_fireball or fb.on_prefb == global.frame_number
					p.attackbits.on_fireball = p.attackbits.on_fireball or fb.on_fireball == global.frame_number
					p.attackbits.off_fireball = p.attackbits.off_fireball or fb.on_fireball == -global.frame_number
				else
					p.attackbits.post_fireball = p.attackbits.post_fireball or fb.on_prefb == -global.frame_number
				end
			end

			p.update_act = (p.spid > 0 and p.on_update_spid == global.frame_number) or (p.spid == 0 and p.on_update_act == global.frame_number and (p.attack == 0 or p.on_update_attack == global.frame_number))
			if p.update_act and ut.tstb(p.old.flag_cc, db.flag_cc.blocking) and ut.tstb(p.flag_cc, db.flag_cc.blocking) then
				p.update_act = false
			end
			p.move_count = p.update_act and 1 or (p.move_count + 1)
		end

		-- 1Pと2Pの状態読取 入力
		for _, p in ipairs(players) do
			p.old.input_states = p.input_states or {}
			p.input_states     = {}
			local debug        = false -- 調査時のみtrue
			local states       = dip_config.easy_super and input_states.easy or input_states.normal
			states             = debug and states[#states] or states[p.char]
			for ti, tbl in ipairs(states) do
				local old, addr = p.old.input_states[ti], tbl.addr + p.input_offset
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
					if old then reset = old.on == 2 and old.chg_remain > 0 end
				elseif tbl.type == input_state_types.faint then
					on = math.max(on - 2, 0)
					if old then
						reset = old.on == 1 and old.chg_remain > 0
						if on == 0 and chg_remain > 0 then force_reset = true end
					end
				elseif tbl.type == input_state_types.charge then
					if on == 1 and chg_remain == 0 then
						on = 3
					elseif on > 1 then
						on = on + 1
					end
					charging = on == 1
					if old then reset = old.on == #tbl.cmds and old.chg_remain > 0 end
				elseif tbl.type == input_state_types.followup then
					on = math.max(on - 1, 0)
					on = (on == 1) and 0 or on
					if old then
						reset = old.on == #tbl.cmds and old.chg_remain > 0
						if on == 0 and chg_remain > 0 then force_reset = true end
					end
				elseif tbl.type == input_state_types.shinsoku then
					on = (on <= 2) and 0 or (on - 1)
					if old then
						reset = old.on == #tbl.cmds and old.chg_remain > 0
						if on == 0 and chg_remain > 0 then force_reset = true end
					end
				elseif tbl.type == input_state_types.todome then
					on = math.max(on - 1, 0)
					on = (on <= 1) and 0 or (on - 1)
					if old then
						reset = old.on > 0 and old.chg_remain > 0
						if on == 0 and chg_remain > 0 then force_reset = true end
					end
				elseif tbl.type == input_state_types.unknown then
					if old then reset = old.on > 0 and old.chg_remain > 0 end
				else
					if old then reset = old.on == #tbl.cmds and old.chg_remain > 0 end
				end
				if old then
					if p.char ~= old.char or on == 1 then
						input_estab = false
					else
						if 0 < tbl.id and tbl.id < 0x1E then reset = p.additional == tbl.exp_extab and p.spid == tbl.id or input_estab end
						if chg_remain == 0 and on == 0 and reset then input_estab = true end
					end
					if force_reset then input_estab = false end
				end
				table.insert(p.input_states, {
					char = p.char,
					chg_remain = chg_remain, -- 次の入力の受付猶予F
					on = on,
					on_prev = on_prev, -- 加工前の入力のすすみの数値
					tbl = tbl,
					debug = debug,
					input_estab = input_estab,
					charging = charging,
					max = max,
				})
			end
		end

		for _, p in pairs(all_objects) do -- 処理アドレス保存
			local base = p.bases[#p.bases]
			if not base or base.addr ~= p.base then
				ut.table_add(p.bases, {
					addr     = p.base,
					count    = 1,
					act_data = p.body.act_data,
					name     = p.proc_active and p.body.act_data.name or "NOP",
					pos1     = p.body.pos_total,
					pos2     = p.body.pos_total,
					xmov     = 0,
				}, 16)
			else
				base.count, base.pos2, base.xmov = base.count + 1, p.body.pos_total, base.pos2 - base.pos1
			end
		end

		-- キャラと飛び道具への当たり判定の反映
		hitboxies, ranges = {}, {} -- ソート前の判定のバッファ

		for _, p in find_all(all_objects, function(_, p) return p.proc_active end) do
			-- 判定表示前の座標補正
			p.x, p.y, p.flip_x = p.pos - screen.left, screen.top - p.pos_y - p.pos_z, (p.flip_x1 ~ p.flip_x2) > 0 and 1 or -1
			p.vulnerable = (p.invincible and p.invincible > 0) or p.hurt_invincible or p.on_vulnerable ~= global.frame_number
			p.grabbable = p.grabbable | (p.grabbable1 and p.grabbable2 and hitbox_grab_bits.baigaeshi or 0)
			p.hitboxies, p.hitbox_types, p.hurt = {}, {}, {} -- 座標補正後データ格納のためバッファのクリア
			p.hurt = { max_top = -0xFFFF, min_bottom = 0xFFFF, dodge = p.vulnerable and frame_attack_types.full or 0, }
			p.attackbit = 0
			for k, v in pairs(p.attackbits) do
				local type = frame_attack_types[k]
				if type then
					if k == "act_count" or k == "fb_effect" or k == "attack" or k == "act" then
						p.attackbit = p.attackbit | (v << type)
					elseif v == 1 or v == true then
						p.attackbit = p.attackbit | type
					end
				end
			end

			-- 当たりとやられ判定判定
			for _, _, box in ifind_all(p.boxies, function(box)
				local type = fix_box_type(p, box) -- 属性はヒット状況などで変わるので都度解決する
				if not (db.hurt_boxies[type] and p.vulnerable) then
					box = fix_box_scale(p, box)
					box.type = type
					return box
				end
			end) do
				if (box.type.kind == db.box_kinds.attack or box.type.kind == db.box_kinds.parry) and global.pause_hitbox == 3 then
					global.pause = true          -- 強制ポーズ
				end
				if box.type.kind == db.box_kinds.attack then -- 攻撃位置から解決した属性を付与する
					box.blockables = {
						main = ut.tstb(box.possible, possible_types.same_line) and box.blockable | get_top_type(box.real_top, db.top_types) or 0,
						sway = ut.tstb(box.possible, possible_types.diff_line) and box.blockable | get_top_type(box.real_top, db.top_sway_types) or 0,
						punish = ut.tstb(box.possible, possible_types.same_line) and get_top_type(box.real_bottom, db.hurt_dodge_types) or 0,
					}
				elseif box.type.kind == db.box_kinds.hurt then -- くらいの無敵(部分無敵)の属性を付与する
					p.hurt.max_top = math.max(p.hurt.max_top or 0, box.real_top)
					p.hurt.min_bottom = math.min(p.hurt.min_bottom or 0xFFFF, box.real_bottom)
					p.hurt.dodge = get_dodge(p, box, p.hurt.max_top, p.hurt.min_bottom)
				end
				if p.body.disp_hitbox and box.type.enabled then
					table.insert(p.hitboxies, box)
					table.insert(hitboxies, box)
					table.insert(p.hitbox_types, box.type)
				end
			end

			if global.pause_hitbox == 2 and #p.body.throw_boxies then global.pause = true end -- 強制ポーズ

			if p.body.disp_hitbox and p.is_fireball ~= true then
				-- 押し合い判定（本体のみ）
				if p.push_invincible and p.push_invincible == 0 and mem._0x10B862 == 0 then
					local box = fix_box_scale(p, get_push_box(p))
					table.insert(p.hitboxies, box)
					table.insert(hitboxies, box)
					table.insert(p.hitbox_types, box.type)
				end

				-- 投げ判定
				local last_throw_ids = {}
				for _, box in pairs(p.throw_boxies) do
					table.insert(p.hitboxies, box)
					table.insert(hitboxies, box)
					table.insert(p.hitbox_types, box.type)
					table.insert(last_throw_ids, { char = p.char, id = box.id })
				end
				if 0 < #last_throw_ids then
					p.throw_boxies, p.last_throw_ids = {}, last_throw_ids
				elseif p.last_throw_ids then
					for _, item in ipairs(p.last_throw_ids) do
						if item.char == p.char then
							local box = get_throwbox(p, item.id)
							box.type = db.box_types.push
							table.insert(p.hitboxies, box)
							table.insert(hitboxies, box)
						end
					end
				end

				-- 座標
				table.insert(ranges, {
					label = string.format("%sP", p.num),
					x = p.x,
					y = p.y,
					flip_x = p.cmd_side,
					within = false,
				})
			end

			if p.body.disp_range and p.is_fireball ~= true then
				-- 詠酒を発動される範囲
				if p.esaka and p.esaka > 0 then
					p.esaka_range = p.calc_range_x(p.esaka) -- 位置を反映した座標を計算
					table.insert(ranges, {
						label = string.format("E%sP%s", p.num, p.esaka_type),
						x = p.esaka_range,
						y = p.y,
						flip_x = -p.flip_x, -- 内側に太線を引きたいのでflipを反転する
						within = p.within(p.x, p.esaka_range)
					})
				end

				-- 地上通常技かライン移動技の遠近判断距離
				if p.pos_y + p.pos_frc_y == 0 then
					for label, close_far in pairs(p.char_data.close_far[p.sway_status]) do
						local x1, x2 = close_far.x1 == 0 and p.x or p.calc_range_x(close_far.x1), p.calc_range_x(close_far.x2)
						table.insert(ranges, {
							label = label,
							x = x2,
							y = p.y,
							flip_x = -p.flip_x, -- 内側に太線を引きたいのでflipを反転する
							within = p.within(x1, x2)
						})
					end
				end
			end
		end
		table.sort(hitboxies, hitboxies_order)
		table.sort(ranges, ranges_order)

		--[[
		-- フレーム表示などの前処理1
		for _, p in ipairs(players) do
			local op         = p.op

			--フレーム数
			p.frame_gap      = p.frame_gap or 0
			p.old.frame_gap = p.old.frame_gap or 0
			if mem._0x10B862 ~= 0 then
				local hitstun, blockstun = 0, 0
				if p.ophit and p.ophit.hitboxies then
					for _, box in pairs(p.ophit.hitboxies) do
						if box.type.kind == db.box_kinds.attack then
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
				p.last_blockstun = p.knockback1 + 3
			end
		end

		-- フレーム表示などの前処理2
		for _, p in ipairs(players) do
			-- ヒットフレームの判断
			if p.state ~= 1 and p.state ~= 3 then
				p.hit1 = 0
			elseif p.on_hit == global.frame_number then
				p.hit1 = 1 -- 1ヒット確定
			end
			-- 停止時間なしのヒットガードのためelseifで繋げない
			if (p.hit1 == 1 and p.skip_frame == false) or
				((p.state == 1 or p.state == 3) and p.old.skip_frame == true and p.skip_frame == false) then
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
				(p.state == 2 and p.old.skip_frame == true and p.skip_frame == false) then
				p.block1 = 2 -- ガード後のヒットストップ解除フレームの記録
				p.on_block1 = global.frame_number
			end
		end
		]]

		for _, p in pairs(all_objects) do
			-- キャラ、弾ともに通常動作状態ならリセットする
			if not global.all_act_normal and global.old_all_act_normal then p.clear_frame_data() end
			-- 全キャラ特別な動作でない場合はフレーム記録しない
			if (global.disp_normal_frms == 1 or not global.all_act_normal) and not p.is_fireball then proc_frame(p) end
		end
		fix_max_framecount() --1Pと2Pともにフレーム数が多すぎる場合は加算をやめる

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
				p.reg_pcnt, p.reg_st_b = reg_p1cnt, reg_st_b
			elseif p.control == 2 then
				p.reg_pcnt, p.reg_st_b = reg_p2cnt, reg_st_b
			else
				p.reg_pcnt, p.reg_st_b = 0xFF, 0xFF
			end
		end
		apply_1p2p_active()

		-- キーディス用の処理
		for i, p in ipairs(players) do
			local p1, key_now = i == 1, p.key_now

			-- 入力表示用の情報構築
			for iv, k in ipairs({ "up", "dn", "lt", "rt", "a", "b", "c", "d", }) do
				key_now[k] = (p.reg_pcnt & (2 ^ (iv - 1))) == 0 and posi_or_pl1(key_now[k]) or nega_or_mi1(key_now[k])
			end
			key_now.sl  = (p.reg_st_b & (p1 and 0x02 or 0x08)) == 0x00 and posi_or_pl1(key_now.sl) or nega_or_mi1(key_now.sl)
			key_now.st  = (p.reg_st_b & (p1 and 0x01 or 0x04)) == 0x00 and posi_or_pl1(key_now.st) or nega_or_mi1(key_now.st)

			local lever = "_N"
			local ggkey = { l = 5, a = false, b = false, c = false, d = false, }

			-- GG風キーディスの更新
			for l, mask in ipairs({ 0x06, 0x02, 0x0A, 0x04, 0xFF, 0x08, 0x05, 0x01, 0x09, }) do
				if (p.reg_pcnt & 0xF) + mask == 0xF then lever, ggkey.l = "_" .. l, l end
			end
			for iv, btn in ipairs({ "a", "b", "c", "d" }) do
				if (p.reg_pcnt & ((2 ^ (iv - 1)) * 0x10)) == 0 then lever, ggkey[btn] = lever .. "_" .. btn, true end
			end
			ut.table_add(p.ggkey_hist, ggkey, 60)

			-- キーログの更新
			lever = string.upper(lever)
			if p.key_hist[#p.key_hist] ~= lever then
				for k = 2, #p.key_hist do
					p.key_hist[k - 1], p.key_frames[k - 1] = p.key_hist[k], p.key_frames[k]
				end
				if 16 ~= #p.key_hist then
					p.key_hist[#p.key_hist + 1], p.key_frames[#p.key_frames + 1] = lever, 1
				else
					p.key_hist[#p.key_hist], p.key_frames[#p.key_frames] = lever, 1
				end
			elseif p.key_frames[#p.key_frames] < 999 then
				p.key_frames[#p.key_frames] = p.key_frames[#p.key_frames] + 1 --999が上限
			end

			do_recover(p)
		end

		-- プレイヤー操作
		for i, p in ipairs(players) do
			p.bs_hook = nil
			if p.control == 1 or p.control == 2 then
				--前進とガード方向
				p.reset_sp_hook()

				-- レコード中、リプレイ中は行動しないためのフラグ
				local in_rec_replay = true
				if global.dummy_mode == 5 then
					in_rec_replay = false
				elseif global.dummy_mode == 6 and global.rec_main == rec_play and recording.player == p.control then
					in_rec_replay = false
				end

				-- 立ち, しゃがみ, ジャンプ, 小ジャンプ, スウェー待機
				-- { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" },
				-- レコード中、リプレイ中は行動しない
				if in_rec_replay then
					if p.sway_status == 0x00 then
						if p.dummy_act == 2 then
							p.reset_cmd_hook(db.cmd_types._2) -- しゃがみ
						elseif p.dummy_act == 3 then
							p.reset_cmd_hook(db.cmd_types._8) -- ジャンプ
						elseif p.dummy_act == 4 and not ut.tstb(p.flag_c0, db.flag_c0._17, true) then
							p.reset_cmd_hook(db.cmd_types._8) -- 地上のジャンプ移行モーション以外だったら上入力
						elseif p.dummy_act == 5 and p.op.sway_status == 0x00 and p.state == 0 then
							p.reset_cmd_hook(db.cmd_types._2d) -- スウェー待機(スウェー移動)
						end
					elseif p.dummy_act == 5 and p.in_sway_line then
						p.reset_cmd_hook(db.cmd_types._8) -- スウェー待機
					end
				end

				-- 自動ガード用
				local act_type = p.op.act_data.type
				for _, fb in pairs(p.op.fireballs) do
					if fb.proc_active and fb.act_data then act_type = act_type | fb.act_data.type end
				end
				if not p.op.attackbits.harmless and p.op.attack and p.op.attack > 0 then
					-- CPU自動ガードの処理の一部より。家庭用 056140 から
					local cpu_block, cpu_block_next = mem.r8(0x56226 + p.op.attack), true
					while cpu_block_next do
						if cpu_block == 0 then
							act_type, cpu_block_next = act_type | db.act_types.attack, false
						elseif cpu_block == 1 then
							act_type, cpu_block_next = act_type | db.act_types.low_attack, false
						elseif cpu_block == 2 then
							cpu_block = mem.r8(((p.char - 1) << 3) + p.op.attack - 0x27 + 0x562FE)
						elseif cpu_block == 3 then
							cpu_block = mem.r8(((p.char - 1) << 5) + p.op.attack - 0x30 + 0x563B6)
						else
							cpu_block_next = false
						end
					end
				end
				-- リプレイ中は自動ガードしない
				if p.dummy_gd ~= dummy_gd_type.none and ut.tstb(act_type, db.act_types.attack) and in_rec_replay then
					p.clear_cmd_hook(db.cmd_types._8) -- 上は無効化
					if p.dummy_gd == dummy_gd_type.fixed then
						-- 常時（ガード方向はダミーモードに従う）
						p.add_cmd_hook(db.cmd_types.back)
					elseif p.dummy_gd == dummy_gd_type.auto or     -- オート
						p.dummy_gd == dummy_gd_type.bs or          -- ブレイクショット
						(p.dummy_gd == dummy_gd_type.random and p.random_boolean) or -- ランダム
						(p.dummy_gd == dummy_gd_type.hit1 and p.next_block) or -- 1ヒットガード
						(p.dummy_gd == dummy_gd_type.block1)       -- 1ガード
					then
						-- 中段から優先
						if ut.tstb(act_type, db.act_types.overhead, true) then
							p.clear_cmd_hook(db.cmd_types._2)
						elseif ut.tstb(act_type, db.act_types.low_attack, true) then
							p.add_cmd_hook(db.cmd_types._2)
						end
						if p.dummy_gd == dummy_gd_type.block1 and p.next_block ~= true then
							-- 1ガードの時は連続ガードの上下段のみ対応させる
							p.clear_cmd_hook(db.cmd_types.back)
						else
							p.add_cmd_hook(db.cmd_types.back)
						end
					end
					p.backstep_killer = p.is_block_cmd_hook()
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
						if p.next_block_ec == 0 then p.next_block = false end
					end
				elseif p.dummy_gd == dummy_gd_type.block1 then
					if p.block1 == 0 and p.next_block_ec == 75 then
						p.next_block = true
					elseif p.block1 == 1 then
						p.next_block, p.next_block_ec = true, 75 -- カウンター初期化
					elseif p.block1 == 2 and global.frame_number <= (p.on_block1 + global.next_block_grace) then
						p.next_block = true
					else
						-- カウンター消費しきったらガードするように切り替える
						p.next_block_ec = p.next_block_ec and (p.next_block_ec - 1) or 0
						if p.next_block_ec == 0 then
							p.next_block, p.next_block_ec, p.block1 = true, 75, 0 -- カウンター初期化
						elseif global.frame_number == p.on_block then
							p.next_block_ec, p.next_block = 75, false -- カウンター初期化
						else
							p.next_block = false
						end
					end
					if global.frame_number == p.on_hit then -- ヒット時はガードに切り替え
						p.next_block, p.next_block_ec, p.block1 = true, 75, 0 -- カウンター初期化
					end
				end

				--挑発中は前進
				if p.fwd_prov and ut.tstb(p.op.flag_cc, db.flag_cc._19) then p.add_cmd_hook(db.cmd_types.front) end

				-- ガードリバーサル
				if global.dummy_rvs_cnt == 1 then
					p.gd_rvs_enabled = true
				elseif p.gd_rvs_enabled ~= true and p.dummy_wakeup == wakeup_type.rvs and p.dummy_rvs and p.on_block == global.frame_number then
					p.rvs_count = (p.rvs_count < 1) and 1 or p.rvs_count + 1
					if global.dummy_rvs_cnt <= p.rvs_count and p.dummy_rvs then p.gd_rvs_enabled, p.rvs_count = true, -1 end
				elseif p.gd_rvs_enabled and p.state ~= 2 then
					p.gd_rvs_enabled = false
				end -- ガード状態が解除されたらリバサ解除

				-- TODO: ライン送られのリバーサルを修正する。猶予1F
				-- print(p.state, p.knockback2, p.knockback1, p.flag_7e, p.hitstop_remain, rvs_types.in_knock_back, p.last_blockstun, string.format("%x", p.act), p.act_count, p.act_frame)
				-- ヒットストップ中は無視
				if not p.skip_frame then
					-- なし, リバーサル, テクニカルライズ, グランドスウェー, 起き上がり攻撃
					if rvs_wake_types[p.dummy_wakeup] and p.dummy_rvs then
						-- ダウン起き上がりリバーサル入力
						if db.wakeup_acts[p.act] and (p.char_data.wakeup_frms - 3) <= (global.frame_number - p.on_wakeup) then
							input_rvs(rvs_types.on_wakeup, p, string.format("[Reversal] wakeup %s %s",
								p.char_data.wakeup_frms, (global.frame_number - p.on_wakeup)))
						end
						-- 着地リバーサル入力（やられの着地）
						if 1 < p.pos_y_down and p.old.pos_y > p.pos_y and p.in_air ~= true then
							input_rvs(rvs_types.knock_back_landing, p, "[Reversal] blown landing")
						end
						-- 着地リバーサル入力（通常ジャンプの着地）
						if p.act == 0x9 and (p.act_frame == 2 or p.act_frame == 0) then
							input_rvs(rvs_types.jump_landing, p, "[Reversal] jump landing")
						end
						-- リバーサルじゃない最速入力
						if p.state == 0 and p.act_data.name ~= "やられ" and p.old.act_data.name == "やられ" and p.knockback2 == 0 then
							input_rvs(rvs_types.knock_back_recovery, p, "[Reversal] blockstun 1")
						end
						-- のけぞりのリバーサル入力
						if (p.state == 1 or (p.state == 2 and p.gd_rvs_enabled)) and p.hitstop_remain == 0 then
							-- のけぞり中のデータをみてのけぞり終了の2F前に入力確定する
							-- 奥ラインへ送った場合だけ無視する（p.act ~= 0x14A）
							if p.flag_7e == 0x80 and p.knockback2 == 0 and p.act ~= 0x14A then
								-- のけぞり中のデータをみてのけぞり終了の2F前に入力確定する1
								input_rvs(rvs_types.in_knock_back, p, "[Reversal] blockstun 2")
							elseif p.old.knockback2 > 0 and p.knockback2 == 0 then
								-- のけぞり中のデータをみてのけぞり終了の2F前に入力確定する2
								input_rvs(rvs_types.in_knock_back, p, "[Reversal] blockstun 3")
							end
							-- デンジャラススルー用
							if p.flag_7e == 0x0 and p.hitstop_remain < 3 and p.base == 0x34538 then
								input_rvs(rvs_types.dangerous_through, p, "[Reversal] blockstun 4")
							end
						elseif p.state == 3 and p.hitstop_remain == 0 and p.knockback1 <= 1 then
							-- 当身うち空振りと裏雲隠し用
							input_rvs(rvs_types.atemi, p, "[Reversal] blockstun 5")
						end
						-- 奥ラインへ送ったあとのリバサ
						if p.act == 0x14A and (p.act_count == 4 or p.act_count == 5) and p.old.act_frame == 0 and p.act_frame == 0 and p.throw_timer == 0 then
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
				if p.op.act == 0x190 or p.op.act == 0x192 or p.op.act == 0x18E or p.op.act == 0x13B then
					if global.auto_input.otg_thw and p.char_data.otg_throw then
						p.reset_sp_hook(p.char_data.otg_throw) -- 自動ダウン投げ
					end
					if global.auto_input.otg_atk and p.char_data.otg_stomp then
						p.reset_sp_hook(p.char_data.otg_stomp) -- 自動ダウン攻撃
					end
				end

				-- 自動投げ追撃
				if global.auto_input.thw_otg then
					if p.char == 3 and p.act == 0x70 then
						p.reset_cmd_hook(db.cmd_types._2c) -- ジョー
					elseif p.act == 0x6D and p.char_data.add_throw then
						p.reset_sp_hook(p.char_data.add_throw) -- ボブ、ギース、双角、マリー
					elseif p.char == 22 and p.act == 0x9F and p.act_count == 2 and p.act_frame >= 0 and p.char_data.add_throw then
						p.reset_sp_hook(p.char_data.add_throw) -- 閃里肘皇・心砕把
					end
				end

				-- 自動超白龍
				if 1 < global.auto_input.pairon and p.char == 22 then
					if p.act == 0x43 and p.act_count >= 0 and p.act_count <= 3 and p.act_frame >= 0 and 2 == global.auto_input.pairon then
						p.reset_sp_hook(db.rvs_bs_list[p.char][28]) -- 超白龍
					elseif p.act == 0x43 and p.act_count == 3 and p.act_count <= 3 and p.act_frame >= 0 and 3 == global.auto_input.pairon then
						p.reset_sp_hook(db.rvs_bs_list[p.char][28]) -- 超白龍
					elseif p.act == 0xA1 and p.act_count == 6 and p.act_frame >= 0 then
						p.reset_sp_hook(db.rvs_bs_list[p.char][21]) -- 閃里肘皇・貫空
					end
					if p.act == 0xFE then
						p.reset_sp_hook(db.rvs_bs_list[p.char][29]) -- 超白龍2
					end
				end

				-- ブレイクショット
				if p.dummy_gd == dummy_gd_type.bs and p.on_block == global.frame_number then
					p.bs_count = (p.bs_count < 1) and 1 or p.bs_count + 1
					if global.dummy_bs_cnt <= p.bs_count and p.dummy_bs then
						p.reset_sp_hook(p.dummy_bs)
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
			if next_joy[joy.field] then ioports[joy.port].fields[joy.field]:set_value(1) end
		end

		-- Y座標強制
		for _, p in ipairs(players) do
			if p.force_y_pos > 1 then mem.w16i(p.addr.pos_y, force_y_pos[p.force_y_pos]) end
		end
		-- X座標同期とY座標をだいぶ下に
		if global.sync_pos_x ~= 1 then
			local from = global.sync_pos_x - 1
			local to   = 3 - from
			mem.w16i(players[to].addr.pos, players[from].pos)
			mem.w16i(players[to].addr.pos_y, players[from].pos_y - 124)
		end

		-- 強制ポーズ処理
		for _, p in ipairs(players) do
			-- ヒット時にポーズさせる
			if p.state ~= 0 and p.state ~= p.old.state and global.pause_hit > 0 then
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

		set_freeze(not global.pause)
	end

	menu.tra_main.draw = function()
		-- メイン処理
		if in_match then
			-- 順番に判定表示（キャラ、飛び道具）
			for _, range in ipairs(ranges) do draw_range(range) end -- 座標と範囲
			for _, box in ipairs(hitboxies) do draw_hitbox(box) end -- 各種判定

			-- スクショ保存
			for _, p in ipairs(players) do
				local chg_y = p.attackbits.on_air or p.attackbits.on_ground
				local chg_act = p.old.act_normal ~= p.act_normal
				local chg_hit = p.chg_hitbox_frm == global.frame_number
				local chg_hurt = p.chg_hurtbox_frm == global.frame_number
				local chg_sway = p.on_sway_line == global.frame_number or p.on_main_line == global.frame_number
				for _, fb in pairs(p.fireballs) do
					if fb.chg_hitbox_frm == global.frame_number then chg_hit = true end
					if fb.chg_hurtbox_frm == global.frame_number then chg_hurt = true end
				end
				local chg_hitbox = p.act_normal ~= true and (p.update_act or chg_act or chg_y or chg_hit or chg_hurt or chg_sway)

				-- 判定が変わったらポーズさせる
				if chg_hitbox and global.pause_hitbox == 4 then global.pause = true end

				-- 画像保存 1:OFF 2:1P動作 3:2P動作
				if (chg_hitbox or p.state ~= 0) and global.save_snapshot > 1 then
					-- 画像保存先のディレクトリ作成
					local frame_group = p.frame_groups[#p.frame_groups]
					local name, sub_name, dir_name = frame_group[#frame_group].name, "_", base_path() .. "/capture"
					ut.mkdir(dir_name)
					dir_name = dir_name .. "/" .. p.char_data.names2
					ut.mkdir(dir_name)
					if p.sliding then sub_name = "_SLIDE_" elseif p.in_bs then sub_name = "_BS_" end
					name = string.format("%s%s%04x_%s_%03d", p.char_data.names2, sub_name, p.act_data.id_1st or 0, name, p.move_count)
					dir_name = dir_name .. string.format("/%04x", p.act_data.id_1st or 0)
					ut.mkdir(dir_name)

					-- ファイル名を設定してMAMEのスクショ機能で画像保存
					local filename, dowrite = dir_name .. "/" .. name .. ".png", false
					if ut.is_file(filename) then
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

			-- ベースアドレス表示 --"OFF", "本体", "弾1", "弾2", "弾3"
			for base, p in pairs(all_objects) do
				if (p.body.disp_base - 2) * 0x200 + p.body.addr.base == base then
					draw_base(p.body.num, p.bases)
				end
			end

			-- ダメージとコンボ表示
			for i, p in ipairs(players) do
				local p1, op, col1, col2, col3, label = i == 1, p.op, {}, {}, {}, {}
				for _, xp in ipairs(p.objects) do
					if xp.proc_active then
						table.insert(label, string.format("Damage %3s/%1s  Stun %2s/%2s Fra.", xp.damage or 0, xp.chip or 0, xp.stun or 0, xp.stun_timer or 0))
						table.insert(label, string.format("HitStop %2s/%2s HitStun %2s/%2s", xp.hitstop or 0, xp.blockstop or 0, xp.hitstun or 0, xp.blockstun or 0))
						table.insert(label, string.format("%2s", db.hit_effect_name(xp.effect)))
						local grabl = ""
						for _, t in ipairs(hitbox_grab_types) do grabl = grabl .. (ut.tstb(xp.grabbable, t.value, true) and t.label or "- ") end
						table.insert(label, string.format("Grab %-s", grabl))
						if xp.is_fireball then
							table.insert(label, string.format("%s/%s Hit  Fireball-Lv. %s", xp.max_hit_nm or 0, xp.max_hit_dn or 0, xp.fireball_rank or 0))
						else
							local kagenui_names = { "-", "Weak", "Strong" }
							table.insert(label, string.format("Pow. %2s/%2s/%2s Rev.%2s Abs.%2s",
								p.pow_up_direct == 0 and p.pow_up or p.pow_up_direct or 0, p.pow_up_hit or 0, p.pow_up_block or 0, p.pow_revenge or 0, p.pow_absorb or 0))
							table.insert(label, string.format("Inv.%2s  BS-Pow.%2s BS-Inv.%2s", xp.sp_invincible or 0, xp.bs_pow or 0, xp.bs_invincible or 0))
							table.insert(label, string.format("%s/%s Hit  Esaka %s %s", xp.max_hit_nm or 0, xp.max_hit_dn or 0, xp.esaka or 0, p.esaka_type or ""))
							table.insert(label, string.format("Kagenui %s", kagenui_names[p.kagenui_type]))
							table.insert(label, string.format("Cancel %-2s/%-2s Teching %s", xp.repeatable and "Ch" or "", xp.cancelable and "Sp" or "",
								xp.forced_down or xp.in_bs and "Can't" or "Can"))
							table.insert(label, string.format(" %-8s/%-8s", p.sliding and "Slide" or "", p.inertial and "Inertial" or ""))
						end
						if p.hurt then
							table.insert(label, string.format("Hurt Top %3s Bottom %3s", p.hurt.max_top, p.hurt.min_bottom))
							table.insert(label, string.format(" Dodge %-s", db.get_dodge_name(p.hurt.dodge)))
						end
						for _, box, blockables in ifind_all(xp.hitboxies, function(box) return box.blockables end) do
							table.insert(label, string.format("Hit Top %3s Bottom %3s", box.real_top, box.real_bottom))
							table.insert(label, string.format(" Main %-5s  Sway %-5s", db.top_type_name(blockables.main), db.top_type_name(blockables.sway)))
							table.insert(label, string.format(" Punish %-9s", db.get_punish_name(blockables.punish)))
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
				table.insert(col2, string.format("%3d>%3d(%.3f%%)", op.last_damage, op.last_damage_scaled, last_damage_scaling))
				table.insert(col2, string.format("%3d(%4s)", op.combo_damage or 0, string.format("+%d", op.last_damage_scaled)))
				table.insert(col2, string.format("%3d", op.last_combo))
				table.insert(col2, string.format("%3d(%4s)", op.combo_stun or 0, string.format("+%d", op.last_stun or 0)))
				table.insert(col2, string.format("%3d(%4s)", op.combo_stun_timer or 0, string.format("+%d", op.last_stun_timer or 0)))
				table.insert(col2, string.format("%3d(%4s)", op.combo_pow or 0, string.format("+%d", p.last_pow_up or 0)))
				table.insert(col3, "")
				table.insert(col3, string.format("%3d", op.max_combo_damage or 0))
				table.insert(col3, string.format("%3d", op.max_combo or 0))
				table.insert(col3, string.format("%3d", op.max_combo_stun or 0))
				table.insert(col3, string.format("%3d", op.max_combo_stun_timer or 0))
				table.insert(col3, string.format("%3d", op.max_combo_pow or 0))
				if p.disp_dmg then
					ut.table_add_all(col1, { -- コンボ表示
						"Scaling",
						"Damage",
						"Combo",
						"Stun",
						"Timer",
						"Power",
					})
				end
				if p.disp_sts == 2 or p.disp_sts == 4 then ut.table_add_all(col1, label) end
				if #col1 > 0 then
					local box_bottom = get_line_height(#col1)
					scr:draw_box(p1 and 224 or 0, 40, p1 and 320 or 96, 40 + box_bottom, 0x80404040, 0x80404040) -- 四角枠
					scr:draw_text(p1 and 224 + 4 or 4, 40, table.concat(col1, "\n"))
					if p.disp_dmg then
						scr:draw_text(p1 and 224 + 36 or 36, 40, table.concat(col2, "\n"))
						scr:draw_text(p1 and 224 + 68 or 68, 40, table.concat(col3, "\n"))
					end
				end

				-- 状態 小表示
				if p.disp_sts == 2 or p.disp_sts == 3 then
					local label1, label2 = {}, {}
					table.insert(label1, string.format("%s %02d %03d %03d",
						p.state, p.throwing and p.throwing.threshold or 0, p.throwing and p.throwing.timer or 0, p.throw_timer or 0))
					local diff_pos_y = p.pos_y + p.pos_frc_y - (p.old.pos_y and (p.old.pos_y + p.old.pos_frc_y) or 0)
					table.insert(label1, string.format("%0.03f %0.03f", diff_pos_y, p.pos_y + p.pos_frc_y))
					table.insert(label1, string.format("%02x %02x %02x", p.spid or 0, p.attack or 0, p.attack_id or 0))
					table.insert(label1, string.format("%03x %02x %02x", p.act, p.act_count, p.act_frame))
					table.insert(label1, string.format("%02x %02x %02x", p.hurt_state, p.sway_status, p.additional))
					local box_bottom = get_line_height(#label1)
					scr:draw_box(p1 and 0 or 277, 0, p1 and 40 or 316, box_bottom, 0x80404040, 0x80404040)
					scr:draw_text(p1 and 4 or 278, 0, table.concat(label1, "\n"))
					local c0, c4 = string.format("%08X", p.flag_c0 or 0), string.format("%08X", p.flag_c4 or 0)
					local c8, cc = string.format("%08X", p.flag_c8 or 0), string.format("%08X", p.flag_cc or 0)
					local d0, _7e = string.format("%02X", p.flag_d0 or 0), string.format("%02X", p.flag_7e or 0)
					table.insert(label2, string.format("C0 %-32s %s %-s", ut.hextobitstr(c0, " "), c0, db.get_flag_name(p.flag_c0, db.flag_names_c0)))
					table.insert(label2, string.format("C4 %-32s %s %-s", ut.hextobitstr(c4, " "), c4, db.get_flag_name(p.flag_c4, db.flag_names_c4)))
					table.insert(label2, string.format("C8 %-32s %s %-s", ut.hextobitstr(c8, " "), c8, db.get_flag_name(p.flag_c8, db.flag_names_c8)))
					table.insert(label2, string.format("CC %-32s %s %-s", ut.hextobitstr(cc, " "), cc, db.get_flag_name(p.flag_cc, db.flag_names_cc)))
					table.insert(label2, string.format("D0 %-8s %s %-s", ut.hextobitstr(d0, " "), d0, db.get_flag_name(p.flag_d0, db.flag_names_d0)))
					table.insert(label2, string.format("7E %-8s %s %-s", ut.hextobitstr(_7e, " "), _7e, db.get_flag_name(p.flag_7e, db.flag_names_7e)))
					table.insert(label2, string.format("%3s %3s", p.knockback1, p.knockback2))
					scr:draw_text(40, 50 + get_line_height(p1 and 0 or (#label2 + 0.5)), table.concat(label2, "\n"))
				end

				-- コマンド入力状態表示
				if global.disp_input_sts - 1 == i then
					for ti, input_state in ipairs(p.input_states) do
						local x, y = 147, 25 + ti * 5
						local x1, x2, y2, cmdx, cmdy = x + 15, x - 8, y + 4, x - 50, y - 2
						draw_text_with_shadow(x1, cmdy, input_state.tbl.name,
							input_state.input_estab == true and input_state_col.orange2 or input_state_col.white)
						if input_state.on > 0 and input_state.chg_remain > 0 then
							local col, col2 = input_state_col.yellow, input_state_col.yellow2
							if input_state.charging == true then col, col2 = input_state_col.green, input_state_col.green2 end
							scr:draw_box(x2 + input_state.max * 2, y, x2, y2, col2, 0)
							scr:draw_box(x2 + input_state.chg_remain * 2, y, x2, y2, 0, col)
						end
						for ci, c in ipairs(input_state.tbl.lr_cmds[p.cmd_side]) do
							if c ~= "" then
								cmdx = cmdx + math.max(5.5,
									draw_text_with_shadow(cmdx, cmdy, c,
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
						draw_frame_groups(p.frame_groups, p.act_frames_total, 30, p1 and 64 or 70, get_line_height(), true)
					end
					draw_frames(p.frame_groups, p1 and 160 or 285, p1 and 40 or 165, 63, get_line_height(), 0.2)
				end
				--フレーム差と確定反撃の表示
				if global.disp_frmgap > 1 then
					draw_text_with_shadow(p1 and 140 or 165, 40, string.format("%4s", string.format(p.frame_gap > 0 and "+%d" or "%d", p.frame_gap)),
						p.frame_gap == 0 and 0xFFFFFFFF or p.frame_gap > 0 and 0xFF0088FF or 0xFFFF0088)
					draw_text_with_shadow(p1 and 112 or 184, 40, "PUNISH", p.on_punish <= global.frame_number and 0xFF808080 or 0xFF00FFFF)
				end
			end

			-- キャラの向きとキャラ間の距離表示
			local abs_space = math.abs(p_space)
			if global.disp_pos then
				local foot_label = {}
				for i, p in ipairs(players) do
					local flip   = p.flip_x == 1 and ">" or "<" -- 見た目と判定の向き
					local side   = p.block_side == 1 and ">" or "<" -- ガード方向や内部の向き 1:右向き -1:左向き
					local i_side = p.cmd_side == 1 and ">" or "<" -- コマンド入力の向き
					if p.old.pos_y ~= p.pos_y or p.last_posy_txt == nil then
						p.last_posy_txt = string.format("Y %3s>%3s", p.old.pos_y or 0, p.pos_y)
					end
					if i == 1 then
						table.insert(foot_label, string.format("%s  Disp.%s Block.%s Input.%s", p.last_posy_txt, flip, side, i_side))
					else
						table.insert(foot_label, string.format("Input.%s Block.%s Disp.%s  %s", i_side, side, flip, p.last_posy_txt))
					end
				end
				table.insert(foot_label, 2, string.format("%3d", abs_space))
				draw_ctext_with_shadow(scr.width / 2, 216, table.concat(foot_label, " "))
			end

			-- GG風コマンド入力表示
			for i, p in ipairs(players) do
				-- コマンド入力表示 1:OFF 2:ON 3:ログのみ 4:キーディスのみ
				if p.disp_cmd == 2 or p.disp_cmd == 4 then
					local xoffset, yoffset = ggkey_set[i].xoffset, ggkey_set[i].yoffset
					local oct_vt, key_xy = ggkey_set[i].oct_vt, ggkey_set[i].key_xy
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
							if #tracks >= max_track then break end
						end
					end
					local fixj = max_track - #tracks -- 軌跡の上限補正用
					for j, track in ipairs(tracks) do
						-- 青→ピンクのグラデーション
						local col, xy1, xy2 = 0xFF0000FF + 0x002A0000 * (fixj + j), track.xy1, track.xy2
						if xy1.x == xy2.x then
							scr:draw_box(xy1.x - 0.6, xy1.y, xy2.x + 0.6, xy2.y, col, col)
						elseif xy1.y == xy2.y then
							scr:draw_box(xy1.x, xy1.y - 0.6, xy2.x, xy2.y + 0.6, col, col)
						elseif xy1.op == xy2.no or xy1.dg1 == xy2.no or xy1.dg2 == xy2.no or xy1.no == 9 or xy2.no == 9 then
							for k = -0.6, 0.6, 0.3 do scr:draw_line(xy1.x + k, xy1.y + k, xy2.x + k, xy2.y + k, col) end
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
						for _, ctl in ipairs({
							{ key = "",  btn = "_)", x = key_xy[ggkey.l].xt, y = key_xy[ggkey.l].yt, col = 0xFFCC0000 },
							{ key = "a", btn = "_A", x = key_xy[5].x + 11,   y = key_xy[5].y + 0,    col = 0xFFFFFFFF },
							{ key = "b", btn = "_B", x = key_xy[5].x + 16,   y = key_xy[5].y - 3,    col = 0xFFFFFFFF },
							{ key = "c", btn = "_C", x = key_xy[5].x + 21,   y = key_xy[5].y - 3,    col = 0xFFFFFFFF },
							{ key = "d", btn = "_D", x = key_xy[5].x + 26,   y = key_xy[5].y - 2,    col = 0xFFFFFFFF },
						}) do
							local xx, yy, btn, on = ctl.x, ctl.y, ut.convert(ctl.btn), ctl.key == "" or ggkey[ctl.key]
							scr:draw_text(xx, yy, ut.convert("_("), on and ctl.col or 0xDDCCCCCC)
							scr:draw_text(xx, yy, btn, on and btn_col[btn] or 0xDD444444)
						end
					end
				end
			end

			-- レコーディング状態表示
			if global.disp_replay and (global.dummy_mode == 5 or global.dummy_mode == 6) then
				scr:draw_box(260 - 25, 208 - 8, 320 - 5, 224, 0xBB404040, 0xBB404040)
				if global.rec_main == rec_await_1st_input then -- 初回入力まち
					scr:draw_text(265, 204, "● REC " .. #recording.active_slot.name, 0xFFFF1133)
					scr:draw_text(290, 212, frame_to_time(3600), 0xFFFF1133)
				elseif global.rec_main == rec_await_1st_input then
					scr:draw_text(265, 204, "● REC " .. #recording.active_slot.name, 0xFFFF1133)
					scr:draw_text(290, 212, frame_to_time(3600), 0xFFFF1133)
				elseif global.rec_main == rec_input then -- 入力中
					scr:draw_text(265, 204, "● REC " .. #recording.active_slot.name .. "\n" ..
						frame_to_time(3601 - #recording.active_slot.store), 0xFFFF1133)
				elseif global.rec_main == rec_repeat_play then -- 自動リプレイまち
					scr:draw_text(265 - 15, 204, "■ リプレイ中\n" .. "スタートおしっぱでメニュー", 0xFFFFFFFF)
				elseif global.rec_main == rec_play then -- リプレイ中
					scr:draw_text(265 - 15, 204, "■ リプレイ中\n" .. "スタートおしっぱでメニュー", 0xFFFFFFFF)
				elseif global.rec_main == rec_play_interval then -- リプレイまち
					scr:draw_text(265 - 15, 204, "■ リプレイ中\n" .. "スタートおしっぱでメニュー", 0xFFFFFFFF)
				elseif global.rec_main == rec_await_play then -- リプレイまち
					scr:draw_text(265 - 15, 204, "■ スタートでリプレイ\n" .. "スタートおしっぱでメニュー", 0xFFFFFFFF)
				elseif global.rec_main == rec_fixpos then -- 開始位置記憶中
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
				p.char, p.char_data, p.dummy_bs_chr = tmp_chr, db.chars[tmp_chr], tmp_chr
				p.dummy_bs = get_next_bs(p)
			end

			-- リバーサル
			if not p.dummy_rvs_chr or p.dummy_rvs_chr ~= tmp_chr then
				p.char, p.char_data, p.dummy_rvs_chr = tmp_chr, db.chars[tmp_chr], tmp_chr
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
	local life_range, pow_range = { "最大", "赤", "ゼロ", }, { "最大", "半分", "ゼロ", }
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
		p[1].disp_hitbox        = col[2] == 2                                               -- 1P 判定表示
		p[2].disp_hitbox        = col[3] == 2                                               -- 2P 判定表示
		p[1].disp_range         = col[4] == 2                                               -- 1P 間合い表示
		p[2].disp_range         = col[5] == 2                                               -- 2P 間合い表示
		p[1].disp_stun          = col[6] == 2                                               -- 1P 気絶ゲージ表示
		p[2].disp_stun          = col[7] == 2                                               -- 2P 気絶ゲージ表示
		p[1].disp_dmg           = col[8] == 2                                               -- 1P ダメージ表示
		p[2].disp_dmg           = col[9] == 2                                               -- 2P ダメージ表示
		p[1].disp_cmd           = col[10]                                                   -- 1P 入力表示
		p[2].disp_cmd           = col[11]                                                   -- 2P 入力表示
		global.disp_input_sts   = col[12]                                                   -- コマンド入力状態表示
		global.disp_normal_frms = col[13]                                                   -- 通常動作フレーム非表示
		global.disp_frmgap      = col[14]                                                   -- フレーム差表示
		p[1].disp_frm           = col[15]                                                   -- 1P フレーム数表示
		p[2].disp_frm           = col[16]                                                   -- 2P フレーム数表示
		p[1].disp_fbfrm         = col[17] == 2                                              -- 1P 弾フレーム数表示
		p[2].disp_fbfrm         = col[18] == 2                                              -- 2P 弾フレーム数表示
		p[1].disp_sts           = col[19]                                                   -- 1P 状態表示
		p[2].disp_sts           = col[20]                                                   -- 2P 状態表示
		p[1].disp_base          = col[21]                                                   -- 1P 処理アドレス表示
		p[2].disp_base          = col[22]                                                   -- 2P 処理アドレス表示
		global.disp_pos         = col[23]                                                   -- 1P 2P 距離表示
		global.hide             = ut.hex_set(global.hide, hide_options.p1_char, col[24] ~= 1) -- 1P キャラ表示
		global.hide             = ut.hex_set(global.hide, hide_options.p2_char, col[25] ~= 1) -- 2P キャラ表示
		global.hide             = ut.hex_set(global.hide, hide_options.p1_phantasm, col[26] ~= 1) -- 1P 残像表示
		global.hide             = ut.hex_set(global.hide, hide_options.p2_phantasm, col[27] ~= 1) -- 2P 残像表示
		global.hide             = ut.hex_set(global.hide, hide_options.p1_effect, col[28] ~= 1) -- 1P エフェクト表示
		global.hide             = ut.hex_set(global.hide, hide_options.p2_effect, col[29] ~= 1) -- 2P エフェクト表示
		global.hide             = ut.hex_set(global.hide, hide_options.p_chan, col[30] ~= 1) -- Pちゃん表示
		global.hide             = ut.hex_set(global.hide, hide_options.effect, col[31] ~= 1) -- エフェクト表示
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

		mod.all_bs(global.all_bs)

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
		mod.easy_move.real_counter(global.auto_input.real_counter)
		-- 詠酒の条件チェックを飛ばす
		mod.easy_move.esaka_check(global.auto_input.esaka_check)
		-- 自動 炎の種馬
		mod.easy_move.taneuma_finish(global.auto_input.auto_taneuma)
		-- 必勝！逆襲拳1発キャッチカデンツァ
		mod.easy_move.fast_kadenzer(global.auto_input.fast_kadenzer)
		-- 自動喝CA
		mod.easy_move.katsu_ca(global.auto_input.auto_katsu)
		-- 空振りCAできる
		mod.easy_move.kara_ca(global.auto_input.kara_ca)
		-- 自動マリートリプルエクスタシー
		mod.easy_move.triple_ecstasy(global.auto_input.auto_3ecst)
		menu.current = menu.main
	end
	local col_menu_to_main         = function()
		local col = menu.color.pos.col
		--ut.printf("col_menu_to_main %s %s", #col, #data.box_type_list)
		for i = 2, #col do db.box_type_list[i - 1].enabled = col[i] == 2 end
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
		col[2] = p[1].disp_hitbox and 2 or 1                          -- 判定表示
		col[3] = p[2].disp_hitbox and 2 or 1                          -- 判定表示
		col[4] = p[1].disp_range and 2 or 1                           -- 間合い表示
		col[5] = p[2].disp_range and 2 or 1                           -- 間合い表示
		col[6] = p[1].disp_stun and 2 or 1                            -- 1P 気絶ゲージ表示
		col[7] = p[2].disp_stun and 2 or 1                            -- 2P 気絶ゲージ表示
		col[8] = p[1].disp_dmg and 2 or 1                             -- 1P ダメージ表示
		col[9] = p[2].disp_dmg and 2 or 1                             -- 2P ダメージ表示
		col[10] = p[1].disp_cmd                                       -- 1P 入力表示
		col[11] = p[2].disp_cmd                                       -- 2P 入力表示
		col[12] = g.disp_input_sts                                    -- コマンド入力状態表示
		col[13] = g.disp_normal_frms                                  -- 通常動作フレーム非表示
		col[14] = g.disp_frmgap                                       -- フレーム差表示
		col[15] = p[1].disp_frm                                       -- 1P フレーム数表示
		col[16] = p[2].disp_frm                                       -- 2P フレーム数表示
		col[17] = p[1].disp_fbfrm and 2 or 1                          -- 1P 弾フレーム数表示
		col[18] = p[2].disp_fbfrm and 2 or 1                          -- 2P 弾フレーム数表示
		col[19] = p[1].disp_sts                                       -- 1P 状態表示
		col[20] = p[2].disp_sts                                       -- 2P 状態表示
		col[21] = p[1].disp_base                                      -- 1P 処理アドレス表示
		col[22] = p[2].disp_base                                      -- 2P 処理アドレス表示
		col[23] = g.disp_pos and 2 or 1                               -- 1P 2P 距離表示
		col[24] = ut.tstb(global.hide, hide_options.p1_char) and 1 or 2 -- 1P キャラ表示
		col[25] = ut.tstb(global.hide, hide_options.p2_char) and 1 or 2 -- 2P キャラ表示
		col[26] = ut.tstb(global.hide, hide_options.p1_phantasm) and 1 or 2 -- 1P 残像表示
		col[27] = ut.tstb(global.hide, hide_options.p2_phantasm) and 1 or 2 -- 2P 残像表示
		col[28] = ut.tstb(global.hide, hide_options.p1_effect) and 1 or 2 -- 1P エフェクト表示
		col[29] = ut.tstb(global.hide, hide_options.p2_effect) and 1 or 2 -- 2P エフェクト表示
		col[30] = ut.tstb(global.hide, hide_options.p_chan) and 1 or 2 -- Pちゃん表示
		col[31] = ut.tstb(global.hide, hide_options.effect) and 1 or 2 -- エフェクト表示
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
		col[10] = g.all_bs and 2 or 1  -- 全必殺技BS
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
		global.hide = ut.hex_set(global.hide, hide_options.meters, menu.main.pos.col[15] == 2) -- 体力,POWゲージ表示
		global.hide = ut.hex_set(global.hide, hide_options.background, menu.main.pos.col[16] == 2) -- 背景表示
		global.hide = ut.hex_set(global.hide, hide_options.shadow1, menu.main.pos.col[17] ~= 2) -- 影表示
		global.hide = ut.hex_set(global.hide, hide_options.shadow2, menu.main.pos.col[17] ~= 3) -- 影表示
		restart_fight({
			next_p1    = menu.main.pos.col[9],                                               -- 1P セレクト
			next_p2    = menu.main.pos.col[10],                                              -- 2P セレクト
			next_p1col = menu.main.pos.col[11] - 1,                                          -- 1P カラー
			next_p2col = menu.main.pos.col[12] - 1,                                          -- 2P カラー
			next_stage = menu.stgs[menu.main.pos.col[13]],                                   -- ステージセレクト
			next_bgm   = menu.bgms[menu.main.pos.col[14]].id,                                -- BGMセレクト
		})
		global.fix_scr_top = menu.main.pos.col[18]
		mod.camerawork(global.fix_scr_top == 1)

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
			{ "影表示", { "ON", "OFF", "ON:反射→影", } },
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
		on_b = ut.new_filled_table(19, menu.exit),
	}
	menu.current                   = menu.main -- デフォルト設定
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
		menu.main.pos.col[15] = ut.tstb(global.hide, hide_options.meters, true) and 1 or 2 -- 体力,POWゲージ表示
		menu.main.pos.col[16] = ut.tstb(global.hide, hide_options.background, true) and 1 or 2 -- 背景表示
		menu.main.pos.col[17] = ut.tstb(global.hide, hide_options.shadow1, true) and 2 or
			ut.tstb(global.hide, hide_options.shadow2, true) and 3 or 1                  -- 影表示
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
		for _, bs_list in pairs(db.char_bs_list) do
			local list, on_ab, col = {}, {}, {}
			table.insert(list, { "     ONにしたスロットからランダムで発動されます。" })
			table.insert(on_ab, menu_bs_to_tra_menu)
			table.insert(col, 0)
			for _, bs in pairs(bs_list) do
				local name = bs.name
				if ut.tstb(bs.hook_type, hook_cmd_types.ex_breakshot, true) then bs.name = "*" .. bs.name end
				table.insert(list, { name, menu.labels.off_on, common = bs.common == true, row = #list, })
				table.insert(on_ab, menu_bs_to_tra_menu)
				table.insert(col, 1)
			end
			table.insert(pbs, { list = list, pos = { offset = 1, row = 2, col = col, }, on_a = on_ab, on_b = on_ab, })
		end
		for _, rvs_list in pairs(db.char_rvs_list) do
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
		on_a = ut.new_filled_table(18, menu_to_main),
		on_b = ut.new_filled_table(18, menu_to_main_cancel),
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
		on_a = ut.new_filled_table(7, bar_menu_to_main),
		on_b = ut.new_filled_table(7, bar_menu_to_main),
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
			{ "1P 処理アドレス表示", { "OFF", "本体", "弾1", "弾2", "弾3", }, },
			{ "2P 処理アドレス表示", { "OFF", "本体", "弾1", "弾2", "弾3", }, },
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
				2, -- 1P フレーム数表示      15
				2, -- 2P フレーム数表示      16
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
		on_a = ut.new_filled_table(31, disp_menu_to_main),
		on_b = ut.new_filled_table(31, disp_menu_to_main),
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
			{ "ヒット効果確認用", hit_effect_menus, },
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
		on_a = ut.new_filled_table(10, ex_menu_to_main),
		on_b = ut.new_filled_table(10, ex_menu_to_main),
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
		on_a = ut.new_filled_table(16, auto_menu_to_main),
		on_b = ut.new_filled_table(16, auto_menu_to_main),
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
	for _, box in pairs(db.box_type_list) do -- TODO 修正する
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
		on_b = ut.new_filled_table(1, menu_rec_to_tra, 8, menu_to_tra),
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
		on_a = ut.new_filled_table(17, exit_menu_to_play),
		-- TODO キャンセル時にも間合い固定の設定とかが変わるように
		on_b = ut.new_filled_table(17, exit_menu_to_play_cancel),
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
		local width = scr.width * scr.xscale
		local height = scr.height * scr.yscale
		if not in_match or in_player_select then return end
		if menu.prev_state ~= menu and menu.state == menu then menu.update_pos() end -- 初回のメニュー表示時は状態更新
		menu.prev_state = menu.state                                           -- 前フレームのメニューを更新

		if accept_input("st") then
			-- Menu ON/OFF
			global.input_accepted = ec
		elseif accept_input("a") then
			-- サブメニューへの遷移（あれば）
			menu.current.on_a[menu.current.pos.row]()
			global.input_accepted = ec
		elseif accept_input("b") then
			-- メニューから戻る
			menu.current.on_b[menu.current.pos.row]()
			global.input_accepted = ec
		elseif accept_input("up") then
			-- カーソル上移動
			menu_cur_updown(-1)
		elseif accept_input("dn") then
			-- カーソル下移動
			menu_cur_updown(1)
		elseif accept_input("lt") then
			-- カーソル左移動
			menu_cur_lr(-1, true)
		elseif accept_input("rt") then
			-- カーソル右移動
			menu_cur_lr(1, true)
		elseif accept_input("c") then
			-- カーソル左10移動
			menu_cur_lr(-10, false)
		elseif accept_input("d") then
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

	emu.register_pause(function()
		menu.state.draw()
		--print(collectgarbage("count"))
		--for addr, cnt in pairs(mem.wp_cnt) do ut.printf("wp %x %s" ,addr,cnt) end
		--for addr, cnt in pairs(mem.rp_cnt) do ut.printf("rp %x %s" ,addr,cnt) end
	end)

	emu.register_resume(function() end)

	emu.register_frame_done(function()
		if not machine then return end
		if machine.paused == false then menu.state.draw() end
		collectgarbage("collect")
	end)

	local bios_test = function()
		local ram_value1, ram_value2 = mem.r16(players[1].addr.base), mem.r16(players[2].addr.base)
		for _, test_value in ipairs({ 0x5555, 0xAAAA, 0xFFFF & players[1].addr.base, 0xFFFF & players[2].addr.base }) do
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
			reset_memory_tap("all_wps")
			reset_memory_tap("hide_wps")
			reset_memory_tap("select_wps")
		else
			-- プレイヤーセレクト中かどうかの判定
			in_player_select = _0x100701 == 0x10B and (_0x107C22 == 0 or _0x107C22 == 0x55) and _0x10FDAF == 2 and _0x10FDB6 ~= 0 and mem._0x10E043 == 0
			-- 対戦中かどうかの判定
			in_match = active_mem_0x100701[_0x100701] ~= nil and _0x107C22 == 0x44 and _0x10FDAF == 2 and _0x10FDB6 ~= 0
			if in_match then
				mem.w16(0x10FDB6, 0x0101) -- 操作の設定
				for i, p in ipairs(players) do mem.w16(p.addr.control, i * 0x0101) end
			end
			load_rom_patch()           -- ROM部分のメモリエリアへパッチあて
			mod.aes()
			set_dip_config()           -- デバッグDIPのセット
			load_hit_effects()         -- ヒット効果アドレステーブルの取得
			load_hit_system_stops()    -- ヒット時のシステム内での中間処理による停止アドレス取得
			load_proc_base()           -- キャラの基本アドレスの取得
			load_push_box()            -- 接触判定の取得
			load_close_far()           -- 遠近間合い取得
			load_memory_tap("all_wps", all_wps) -- tapの仕込み
			if global.hide > 0 then
				load_memory_tap("hide_wps", { hide_wps })
			else
				reset_memory_tap("hide_wps")
			end
			if in_player_select then
				load_memory_tap("select_wps", { select_wps })
			else
				reset_memory_tap("select_wps")
			end
			menu.state.proc() -- メニュー初期化前に処理されないようにする
		end
	end)
end

return exports
