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
local rbff2         = {}

rbff2.startplugin           = function()
	local ut                 = require("rbff2training/util")
	local db                 = require("rbff2training/data")
	local gm                 = require("rbff2training/game")
	local UTF8toSJIS         = require("rbff2training/UTF8toSJIS")

	local to_sjis            = function(s)
		local sjis, _ = UTF8toSJIS:UTF8_to_SJIS_str_cnv(s)
		return sjis
	end

	-- MAMEのLuaオブジェクトの変数と初期化処理
	local man
	local machine
	local cpu
	local pgm
	local scr
	local ioports
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
		base_path = function()
			local base = emu.subst_env(man.options.entries.homepath:value():match('([^;]+)')) .. "/plugins/rbff2training"
			local dir = ut.cur_dir()
			return dir .. "/" .. base
		end
	end

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
		local dodge, type = 0, box.type
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
	local input_state        = db.input_state

	-- メニュー用変数
	local menu               = {
		max_row = 13,
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

		stage_list = db.stage_list,
		bgms = db.bgm_list,

		labels = {
			fix_scr_tops    = { "OFF" },
			chars           = db.char_names,
			stage_list      = {},
			bgms            = {},
			off_on          = { "OFF", "ON" },
			off_on_1p2p     = { "OFF", "ON", "ON:1P", "ON:2P" },
			life_range      = { "MAX(192)", "RED(96)", }, -- ゼロにするとガードなどで問題が出るので1を最低値にする
			pow_range       = { "MAX(60)", "HALF(30)", "ZERO(0)", },
			block_frames    = {},
			attack_harmless = { "OFF" },
			play_interval   = {},
			force_y_pos     = { "OFF", 0 },
		},

		config = {
			disp_box_range1p    = 2,                -- 02 1P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
			disp_box_range2p    = 2,                -- 03 2P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
			disp_stun           = 2,                -- 06 気絶メーター表示  1:OFF 2:ON 3:1P 4:2P
			disp_damage         = 2,                -- 07 ダメージ表示  1:OFF 2:ON 3:1P 4:2P
			disp_frame          = 2,               -- 10 フレームメーター表示  1:OFF 2:大メーター 3:小メーター 4:1P 小メーターのみ 5:2P 小メーターのみ
			split_frame         = 1,               -- 11 フレームメーター設定  1:ON 2:ON:判定の形毎 3:ON:攻撃判定の形毎 4:ON:くらい判定の形毎
			disp_fb_frame       = true,            -- 12 フレームメーター弾表示  1:OFF 2:ON
			disp_char           = 2,               -- 21 キャラ表示 1:OFF 2:ON 3:1P 4:2P
			disp_phantasm       = 2,               -- 22 残像表示 1:OFF 2:ON 3:1P 4:2P
			disp_effect         = 2,               -- 23 エフェクト表示 1:OFF 2:ON 3:1P 4:2P
		},

		create = function(name, list, on_a, on_b)
			local row, col = nil, {}
			for i, obj in ipairs(list) do
				if not row and not obj.title then row = i end
				table.insert(col, #obj == 1 and 0 or 1)
			end
			return { name = name, list = list, pos = { offset = 1, row = row or 1, col = col }, on_a = on_a, on_b = on_b or on_a }
		end,

		to_tra = nil,
		to_bar = nil,
		to_disp = nil,
		to_ex = nil,
		to_col = nil,
		to_auto = nil,
	}
	for i = -20, 0xF0 do table.insert(menu.labels.fix_scr_tops, "" .. i) end
	for i = 1, 301 do table.insert(menu.labels.play_interval, i - 1) end
	for i = 1, 256 do table.insert(menu.labels.force_y_pos, i) end
	for i = -1, -256, -1 do table.insert(menu.labels.force_y_pos, i) end
	for _, stg in ipairs(menu.stage_list) do table.insert(menu.labels.stage_list, stg.name) end
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
	local mem                                  = {
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
	local mod                                  = {
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
			mem.wd8(gm.fix(0x049951), 0x2)
			mem.wd8(gm.fix(0x049947), 0x9)
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
			mem.wd32(gm.fix(0x500E8), 0x303C0007)
			mem.wd32(gm.fix(0x50118), 0x3E3C0007)
			mem.wd32(gm.fix(0x50150), 0x303C0007)
			mem.wd32(gm.fix(0x501A8), 0x303C0007)
			mem.wd32(gm.fix(0x501CE), 0x303C0007)
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
			shikkyaku_ca = function(enabled)                     -- 自動飛燕失脚CA
				mem.wd16(0x3DE48, enabled and 0x4E71 or 0x660E)  -- レバーN入力チェックをNOPに
				mem.wd16(0x3DE4E, enabled and 0x4E71 or 0x6708)  -- C入力チェックをNOPに
				mem.wd16(0x3DEA6, enabled and 0x4E71 or 0x6612)  -- 一回転+C入力チェックをNOPに
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
		mvs_billy    = function(enabled)
			if enabled then
				for addr = 0x2D442, 0x2D45E, 2 do mem.wd32(addr, 0x4E714E71) end -- NOPで埋める
			else
				--[[
				02D442: 0C6C 0010 0010           cmpi.w  #$10, ($10,A4)      ; キャラID = 0x10 ビリー
				02D448: 6618                     bne     $2d462              ;  でなければ 0x2d462 へ(MVSと同じ流れへ戻る)
				02D44A: 0C6C 006E 0062           cmpi.w  #$6e, ($62,A4)      ; 動作のID(0x100*62)が0x6E
				02D450: 6604                     bne     $2d456              ; でなければ 0x2d456 へ
				02D452: 4E75                     rts                         ; 抜ける。
				02D454: 4E71                     nop                         ;
				02D456: 0C6C 0070 0062           cmpi.w  #$70, ($62,A4)      ; 動作のID(0x100*62)が0x70
				02D45C: 6604                     bne     $2d462              ; でなければ 0x2d462 へ(MVSと同じ流れへ戻る)
				02D45E: 4E75                     rts                         ; 抜ける。
				02D460: 4E71                     nop                         ;
				]]
				mem.wd32(0x2D442, 0x0C6C0010)
				mem.wd32(0x2D446, 0x00106618)
				mem.wd32(0x2D44A, 0x0C6C006E)
				mem.wd32(0x2D44E, 0x00626604)
				mem.wd32(0x2D452, 0x4E754E71)
				mem.wd32(0x2D456, 0x0C6C0070)
				mem.wd32(0x2D45A, 0x00626604)
				mem.wd32(0x2D45E, 0x4E754E71)
			end
		end,
	}
	local in_match                             = false -- 対戦画面のときtrue
	local in_player_select                     = false -- プレイヤー選択画面のときtrue
	local p_space                              = 0     -- 1Pと2Pの間隔
	local prev_space                           = 0     -- 1Pと2Pの間隔(前フレーム)

	local screen                               = {
		offset_x = 0x20,
		offset_z = 0x24,
		offset_y = 0x28,
		left     = 0,
		top      = 0,
	}
	local hide_options                         = {
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
	local global                               = {
		frame_number         = 0,
		lag_frame            = false,
		both_act_neutral     = false,
		old_both_act_neutral = false,
		skip_frame           = false,
		fix_scr_top          = 1,

		-- 当たり判定用
		axis_size            = 12,
		axis_size2           = 5,
		throwbox_height      = 200, --default for ground throws
		disp_bg              = true,
		fix_pos              = false,
		no_bars              = false,
		sync_pos_x           = 1,  -- 1: OFF, 2:1Pと同期, 3:2Pと同期

		disp_pos             = 2, -- 向き・距離・位置表示 1;OFF 2:ON 3:向き・距離のみ 4:位置のみ
		hide                 = hide_options.none,
		disp_frame           = true, -- フレームメーター表示 1:OFF 2:ON
		disp_input           = 1,  -- コマンド入力状態表示 1:OFF 2:1P 3:2P
		disp_normal_frames   = false, -- 通常動作フレーム非表示 1:OFF 2:ON
		pause_hit            = 1,  -- 1:OFF, 2:ON, 3:ON:やられのみ 4:ON:投げやられのみ 5:ON:打撃やられのみ 6:ON:ガードのみ
		pause_hitbox         = 1,  -- 判定発生時にポーズ 1:OFF, 2:投げ, 3:攻撃, 4:変化時
		pause                = false,
		replay_stop_on_dmg   = false, -- ダメージでリプレイ中段

		next_stg3            = 0,

		-- リバーサルとブレイクショットの設定
		dummy_bs_cnt         = 1, -- ブレイクショットのカウンタ
		dummy_rvs_cnt        = 1, -- リバーサルのカウンタ

		auto_input           = {
			otg_throw     = false, -- ダウン投げ              2
			otg_attack    = false, -- ダウン攻撃              3
			combo_throw   = false, -- 通常投げの派生技        4
			rave          = 1, -- デッドリーレイブ        5
			desire        = 1, -- アンリミテッドデザイア  6
			drill         = 1, -- ドリル                  7
			pairon        = 1, -- 超白龍                  8
			real_counter  = 1, -- M.リアルカウンター      9
			auto_3ecst    = false, -- M.トリプルエクスタシー 10
			taneuma       = false, -- 炎の種馬               11
			katsu_ca      = false, -- 喝CA                   12
			sikkyaku_ca   = false, -- 飛燕失脚CA             13
			-- 入力設定                                     14
			esaka_check   = false, -- 詠酒距離チェック       15
			fast_kadenzer = false, -- 必勝！逆襲拳           16
			kara_ca       = false, -- 空振りCA               17
		},

		frzc                 = 1,
		frz                  = { 0x1, 0x0 }, -- DIPによる停止操作用の値とカウンタ

		dummy_mode           = 1,
		old_dummy_mode       = 1,
		rec_main             = nil,

		next_block_grace     = 0, -- 1ガードでの持続フレーム数
		pow_mode             = 2, -- POWモード　1:自動回復 2:固定 3:通常動作
		disp_meters          = true,
		repeat_interval      = 0,
		await_neutral        = false,
		replay_fix_pos       = 1, -- 開始間合い固定 1:OFF 2:位置記憶 3:1Pと2P 4:1P 5:2P
		replay_reset         = 2, -- 状態リセット   1:OFF 2:1Pと2P 3:1P 4:2P
		debug_stop           = 0, -- カウンタ
		damaged_move         = 1,
		all_bs               = false,
		mvs_billy            = false,
		disp_replay          = true, -- レコードリプレイガイド表示
		save_snapshot        = 1, -- 技画像保存 1:OFF 2:新規 3:上書き
		key_hists            = 25,

		rvslog               = false,
	}
	mem.rg                                     = function(id, mask) return (mask == nil) and cpu.state[id].value or (cpu.state[id].value & mask) end
	mem.pc                                     = function() return cpu.state["CURPC"].value end
	mem.wp_cnt, mem.rp_cnt                     = {}, {} -- 負荷確認のための呼び出す回数カウンター
	mem.wp                                     = function(addr1, addr2, name, cb) return pgm:install_write_tap(addr1, addr2, name, cb) end
	mem.rp                                     = function(addr1, addr2, name, cb) return pgm:install_read_tap(addr1, addr2, name, cb) end
	mem.wp8                                    = function(addr, cb, filter)
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
	mem.wp16                                   = function(addr, cb, filter)
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
	mem.wp32                                   = function(addr, cb, filter)
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
	mem.rp8                                    = function(addr, cb, filter)
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
	mem.rp16                                   = function(addr, cb, filter)
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
	mem.rp32                                   = function(addr, cb, filter)
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
	local dip_config                           = {
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
	local set_dip_config                       = function()
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
	local joy_k                                = db.joy_k
	local joy_neutrala                         = db.joy_neutrala

	local rvs_types                            = db.rvs_types
	local hook_cmd_types                       = db.hook_cmd_types

	local get_next_xs                          = function(p, list, cur_menu, top_label_count)
		-- top_label_countはメニュー上部のラベル行数
		local sub_menu, ons = cur_menu[p.num][p.char], {}
		if sub_menu == nil or list == nil then return nil end
		for j, s in pairs(list) do if sub_menu.pos.col[j + top_label_count] == 2 then table.insert(ons, s) end end
		return #ons > 0 and ons[math.random(#ons)] or nil
	end
	local get_next_rvs                         = function(p) return get_next_xs(p, p.char_data and p.char_data.rvs or nil, menu.rvs_menus, 1) end
	local get_next_bs                          = function(p) return get_next_xs(p, p.char_data and p.char_data.bs or nil, menu.bs_menus, 2) end

	local use_joy                              = {
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

	local play_cursor_sound                    = function()
		mem.w32(0x10D612, 0x600004)
		mem.w8(0x10D713, 0x1)
	end

	local new_next_joy                         = function() return ut.deepcopy(joy_neutrala) end
	-- MAMEへの入力の無効化
	local cls_joy                              = function()
		for _, joy in ipairs(use_joy) do ioports[joy.port].fields[joy.field]:set_value(0) end
	end

	-- ポーズ
	local set_freeze                           = function(freeze) mem.w8(0x1041D2, freeze and 0x00 or 0xFF) end

	-- ボタンの色テーブル
	local btn_col                              = { [ut.convert("_A")] = 0xFFCC0000, [ut.convert("_B")] = 0xFFCC8800, [ut.convert("_C")] = 0xFF3333CC, [ut.convert("_D")] = 0xFF336600, }
	local text_col, shadow_col                 = 0xFFFFFFFF, 0xFF000000

	local get_word_len                         = function(str)
		if not str then return 0 end
		str = type(str) ~= "string" and string.format("%s", str) or str
		local len = 0
		for _, c in utf8.codes(str) do len = len + (c < 0x80 and 1 or 2) end
		return len
	end

	local get_string_width                     = function(str)
		if not str then return 0 end
		return man.ui:get_string_width("9") * get_word_len(str) * scr.width
	end

	local get_line_height                      = function(lines)
		return man.ui.line_height * scr.height * (lines or 1)
	end

	local draw_text                            = function(x, y, str, fgcol, bgcol)
		scr:draw_text(x, y, str, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
		--[[
		if not str then return end
		str = type(str) ~= "string" and string.format("%s", str) or str
		if type(x) == "string" then
			scr:draw_text(x, y, str, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
			return
		end
		local len, fix, w1, w2, s = 0, 0, man.ui:get_string_width("9"), man.ui:get_string_width("9") / 2, nil
		for _, c in utf8.codes(str) do
			if c == utf8.codepoint("\n") then
				y, len = y + get_line_height(), 0
			else
				s = utf8.char(c)
				fix = x + ((w1 * len) + w2 - man.ui:get_string_width(s) / 2) * scr.width
				scr:draw_text(fix, y, s, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
				len = len + (c < 0x80 and 1 or 2)
			end
		end
		]]
	end

	local draw_rtext                           = function(x, y, str, fgcol, bgcol)
		if not str then return end
		str = type(str) ~= "string" and string.format("%s", str) or str
		local w = get_string_width(str)
		draw_text(x - w, y, str, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
	end

	local draw_ctext                           = function(x, y, str, fgcol, bgcol)
		if not str then return end
		str = type(str) ~= "string" and string.format("%s", str) or str
		local w = get_string_width(str) / 2
		draw_text(x - w, y, str, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
	end

	local draw_text_with_shadow                = function(x, y, str, fgcol, bgcol)
		if not str then return end
		str = type(str) ~= "string" and string.format("%s", str) or str
		draw_text(x + 0.5, y + 0.5, str, shadow_col, bgcol or 0x00000000)
		draw_text(x, y, str, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
	end

	local draw_rtext_with_shadow               = function(x, y, str, fgcol, bgcol)
		if not str then return end
		draw_rtext(x + 0.5, y + 0.5, str, shadow_col, bgcol)
		draw_rtext(x, y, str, fgcol, bgcol)
	end

	local draw_ctext_with_shadow               = function(x, y, str, fgcol, bgcol)
		if not str then return end
		draw_ctext(x + 0.5, y + 0.5, str, shadow_col, bgcol)
		draw_ctext(x, y, str, fgcol, bgcol)
	end

	-- コマンド文字列表示
	local draw_cmd_text_with_shadow            = function(x, y, str, fgcol, bgcol)
		if not str then return end
		-- 変換しつつUnicodeの文字配列に落とし込む
		local cstr, xx = ut.convert(str), x
		for c in string.gmatch(cstr, "([%z\1-\127\194-\244][\128-\191]*)") do
			-- 文字の影
			draw_text(xx + 0.5, y + 0.5, c, 0xFF000000)
			if btn_col[c] then
				-- ABCDボタンの場合は黒の●を表示した後ABCDを書いて文字の部分を黒く見えるようにする
				draw_text(xx, y, ut.convert("_("), text_col)
				draw_text(xx, y, c, fgcol or btn_col[c])
			else
				draw_text(xx, y, c, fgcol or text_col)
			end
			xx = xx + 5 -- フォントの大きさ問わず5pxずつ表示する
		end
	end

	local format_num                           = function(num) return string.sub(string.format("00%0.03f", num), -7) end

	-- コマンド入力表示
	local draw_cmd                             = function(p, line, frame, str, spid)
		if not str then return end
		local xx, yy = p == 1 and 12 or 294, get_line_height(line + 3)
		local col, spcol = 0xFAFFFFFF, 0x66DD00FF
		local x1, x2, step
		if p == 1 then x1, x2, step = 1, 50, 1 else x1, x2, step = 320, 270, -1 end
		if spid then scr:draw_box(x1, yy + get_line_height(), x2, yy, 0, spcol) end
		for i = x1, x2, step do
			scr:draw_line(i, yy, i + 1, yy, col)
			col = col - 0x05000000
		end
		if 0 < frame then
			local cframe = 999 < frame and "LOT" or string.format("%03d", frame)
			draw_text_with_shadow(p == 1 and 1 or 283, yy, cframe, text_col)
		end
		draw_cmd_text_with_shadow(xx, yy, str)
	end

	-- 処理アドレス表示
	local draw_base                            = function(p, bases)
		local lines = {}
		for _, base in ipairs(bases) do
			local addr, act_name, xmov, cframe = base.addr, base.name, base.xmov, string.format("%03d", base.count)
			if 999 < base.count then cframe = "LOT" end
			local smov = (xmov < 0 and "-" or "+") .. string.format("%03d", math.abs(math.floor(xmov))) .. string.sub(string.format("%0.03f", xmov), -4)
			table.insert(lines, string.format("%3s %05X %8s %-s", cframe, addr, smov, act_name))
		end
		local xx, txt = p == 1 and 60 or 195, table.concat(lines, "\n") -- 1Pと2Pで左右に表示し分ける
		draw_text(xx + 0.5, 80.5, txt, 0xFF000000)                   -- 文字の影
		draw_text(xx, 80, txt, text_col)
	end
	-- 投げ無敵
	local throw_inv_type                       = {
		time24 = { value = 24, disp_label = "タイマー24", name = "通常投げ" },
		time20 = { value = 20, disp_label = "タイマー20", name = "M.リアルカウンター投げ" },
		time10 = { value = 10, disp_label = "タイマー10", name = "真空投げ 羅生門 鬼門陣 M.タイフーン M.スパイダー 爆弾パチキ ドリル ブレスパ ブレスパBR リフトアップブロー デンジャラススルー ギガティックサイクロン マジンガ STOL" },
		sway   = { value = 256, disp_label = "スウェー", name = "スウェー" },
		flag1  = { value = 256, disp_label = "フラグ1", name = "無敵フラグ" },
		flag2  = { value = 256, disp_label = "フラグ2", name = "通常投げ無敵フラグ" },
		state  = { value = 256, disp_label = "やられ状態", name = "相互のやられ状態が非通常値" },
		no_gnd = { value = 256, disp_label = "高度", name = "接地状態ではない（地面へのめり込みも投げ不可）" },
	}
	throw_inv_type.values                      = {
		throw_inv_type.time24, throw_inv_type.time20, throw_inv_type.time10, throw_inv_type.sway, throw_inv_type.flag1, throw_inv_type.flag2,
		throw_inv_type.state, throw_inv_type.no_gnd
	}
	throw_inv_type.get                         = function(p)
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

	local sort_ab                              = function(v1, v2)
		if v1 <= v2 then return v2, v1 end
		return v1, v2
	end

	local sort_ba                              = function(v1, v2)
		if v1 <= v2 then return v1, v2 end
		return v2, v1
	end

	local fix_box_scale                        = function(p, src, dest)
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
	local load_rom_patch                       = function(before)
		if mem.pached then return end
		if before then before() end
		mem.pached = mem.pached or mod.p1_patch()
		mod.bugfix()
		mod.training()
		print("load_rom_patch done")
	end

	-- ヒット効果アドレステーブルの取得
	db.hit_effects.menus, db.hit_effects.addrs = { "OFF" }, { 0 }
	for i, hit_effect in ipairs(db.hit_effects.list) do
		table.insert(db.hit_effects.menus, string.format("%02d %s", i, table.concat(hit_effect, " ")))
	end
	local load_hit_effects      = function()
		if #db.hit_effects.addrs > 1 then return end
		for i, _ in ipairs(db.hit_effects.list) do
			table.insert(db.hit_effects.addrs, mem.r32(0x579DA + (i - 1) * 4))
		end
		print("load_hit_effects")
	end

	local load_hit_system_stops = function()
		if hit_system_stops.loaded then return end
		for addr = 0x57C54, 0x57CC0, 4 do hit_system_stops[mem.r32(addr)] = true end
		hit_system_stops.loaded = true
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
				hitstop       = mem.r32(char4 + gm.fix(0x83C38)),
				damege        = mem.r32(char4 + gm.fix(0x813F0)),
				stun          = mem.r32(char4 + gm.fix(0x85CCA)),
				stun_timer    = mem.r32(char4 + gm.fix(0x85D2A)),
				max_hit       = mem.r32(char4 + gm.fix(0x827B8)),
				esaka         = mem.r32(char4 + 0x23750),
				pow_up        = ((0xC == char) and 0x8C274 or (0x10 == char) and 0x8C29C or 0x8C24C),
				pow_up_ext    = mem.r32(0x8C18C + char4),
				chip          = gm.fix(0x95CCC),
				hitstun1      = gm.fix(0x95CCC),
				hitstun2      = 0x16 + 0x2 + gm.fix(0x5AF7C),
				blockstun     = 0x1A + 0x2 + gm.fix(0x5AF88),
				bs_pow        = mem.r32(char4 + 0x85920),
				bs_invincible = mem.r32(char4 + 0x85920) + 0x1,
				sp_invincible = mem.r32(char4 + 0x8DE62),
			}
		end
		db.chars[#db.chars].proc_base = { -- 共通枠に弾のベースアドレスを入れておく
			forced_down = 0x8E2C0,
			hitstop     = gm.fix(0x884F2),
			damege      = gm.fix(0x88472),
			stun        = gm.fix(0x886F2),
			stun_timer  = gm.fix(0x88772),
			max_hit     = gm.fix(0x885F2),
			baigaeshi   = 0x8E940,
			effect      = gm.fix(0x95BEC) - 0x20, -- 家庭用58232からの処理
			chip        = gm.fix(0x95CCC),
			hitstun1    = gm.fix(0x95CCC),
			hitstun2    = 0x16 + 0x2 + gm.fix(0x5AF7C),
			blockstun   = 0x1A + 0x2 + gm.fix(0x5AF88),
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
		local range = mem.r8(gm.fix(0x5D854) + p.char4)
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

	local border_box            = function(x1, y1, x2, y2, fcol, _, w)
		scr:draw_box(x1 - w, y1 - w, x2 + w, y1, fcol, fcol)
		scr:draw_box(x1 - w, y1 - w, x1, y2 + w, fcol, fcol)
		scr:draw_box(x2, y1 - w, x2 + 1, y2 + w, fcol, fcol)
		scr:draw_box(x1 - w, y2 + w, x2 + w, y2, fcol, fcol)
	end

	local border_waku           = function(x1, y1, x2, y2, fcol, _, w)
		scr:draw_box(x1, y1, x2, y2, fcol, 0)
		scr:draw_box(x1, y1 - w, x2, y1, fcol, fcol)
		scr:draw_box(x1, y2 + w, x2, y2, fcol, fcol)
	end

	-- 判定枠のチェック処理種類
	local hitbox_possible_map   = {
		[0x01311C] = possible_types.none,   -- 常に判定しない
		[0x012FF0] = possible_types.same_line, -- → 013038 同一ライン同士なら判定する
		[0x012FFE] = possible_types.both_line, -- → 013054 異なるライン同士でも判定する
		[0x01300A] = possible_types.unknown, -- → 013018 不明
		[0x012FE2] = possible_types.air_onry, -- → 012ff0 → 013038 相手が空中にいれば判定する
	}
	local get_hitbox_possibles  = function(id)
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

	local fix_box_type          = function(p, attackbit, box)
		attackbit = db.box_with_bit_types.mask & attackbit
		local type = p.in_sway_line and box.sway_type or box.type
		if type ~= db.box_types.attack then return type end
		-- TODO 多段技の状態
		p.max_hit_dn = p.max_hit_dn or 0
		if p.max_hit_dn > 1 or p.max_hit_dn == 0 or (p.char == 0x4 and p.attack == 0x16) then
		end
		local types = p.is_fireball and db.box_with_bit_types.fireballkv or db.box_with_bit_types.bodykv
		type = types[attackbit]
		if type then return type.box_type end
		types = p.is_fireball and db.box_with_bit_types.fireball or db.box_with_bit_types.body
		local hits = {}
		for _, t in ipairs(types) do if ut.tstb(attackbit, t.attackbit, true) then
			table.insert(hits, t.box_type)
			-- print("hit", #hits, t.box_type.name_en)
		end end
		if #hits > 0 then return hits[1] end
		ut.printf("fallback %s", ut.tobitstr(attackbit))
		return types[#types].box_type -- fallback
	end

	-- 遠近間合い取得
	local load_close_far        = function()
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

	local reset_memory_tap      = function(label, enabled)
		if not global.holder then return end
		local subs
		if label then
			local sub = global.holder.sub[label]
			if not sub then return end
			subs = {sub}
		else
			subs = global.holder.sub
		end
		for labels, sub in pairs(subs) do
			if not enabled and sub.on == true then
				sub.on = false
				for _, tap in pairs(sub.taps) do tap:remove() end
				ut.printf("Remove memory taps %s", labels)
			elseif enabled and sub.on ~= true then
				sub.on = true
				for _, tap in pairs(sub.taps) do tap:reinstall() end
				ut.printf("Reinstall memory taps %s", labels)
			end
		end
	end

	local load_memory_tap       = function(label, wps) -- tapの仕込み
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

	local apply_attack_infos    = function(p, id, base_addr)
		-- 削りダメージ計算種別取得 05B2A4 からの処理
		p.chip      = db.calc_chip((0xF & mem.r8(base_addr.chip + id)) + 1, p.damage)
		-- 硬直時間取得 05AF7C(家庭用版)からの処理
		local d2    = 0xF & mem.r8(id + base_addr.hitstun1)
		p.hitstun   = mem.r8(base_addr.hitstun2 + d2) + 1 + 3 -- ヒット硬直
		p.blockstun = mem.r8(base_addr.blockstun + d2) + 1 + 2 -- ガード硬直
	end

	local dummy_gd_type         = {
		none   = 1, -- なし
		auto   = 2, -- オート
		bs     = 3, -- ブレイクショット
		hit1   = 4, -- 1ヒットガード
		block1 = 5, -- 1ガード
		fixed  = 6, -- 常時
		random = 7, -- ランダム
		force  = 8, -- 強制
	}
	local wakeup_type           = {
		none = 1, -- なし
		rvs  = 2, -- リバーサル
		tech = 3, -- テクニカルライズ
		sway = 4, -- グランドスウェー
		atk  = 5, -- 起き上がり攻撃
	}
	local rvs_wake_types        = ut.new_set(wakeup_type.tech, wakeup_type.sway, wakeup_type.rvs)

	local players, all_wps, all_objects, hitboxies, ranges = {}, {}, {}, {}, {}
	local hitboxies_order                                  = function(b1, b2) return (b1.id < b2.id) end
	local ranges_order                                     = function(r1, r2) return (r1.within and 1 or -1) < (r2.within and 1 or -1) end
	local get_object_by_addr                               = function(addr, default) return all_objects[addr] or default end              -- ベースアドレスからオブジェクト解決
	local get_object_by_reg                                = function(reg, default) return all_objects[mem.rg(reg, 0xFFFFFF)] or default end -- レジストリからオブジェクト解決
	local now                                              = function() return global.frame_number + 1 end
	local ggkey_create                                     = function(p1)
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
			xy.xt, xy.yt = xy.x - 2.5, xy.y - 3              -- レバーの丸表示用
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
		return { xoffset = xoffset, yoffset = yoffset, oct_vt = oct_vt, key_xy = key_xy, hist = {} }
	end
	local input                                            = { accepted = 0 }
	input.merge                                            = function(cmd1, cmd2)
		local mask = 0xFF
		for _, m in ut.ifind_all(db.cmd_rev_masks, function(m) return ut.tstb(cmd2, m.cmd) end) do
			mask = mask & m.mask
		end
		return (cmd1 & mask) | cmd2
	end
	input.read                                             = function()
		-- 1Pと2Pの入力読取
		for i, p in ipairs(players) do
			if not p.key then return end
			local status_b, reg_pcnt = mem.r8(p.addr.reg_st_b) ~ 0xFF, mem.r8(p.addr.reg_pcnt) ~ 0xFF
			local on1f, on5f, hold = mem.r8(p.addr.on1f), mem.r8(p.addr.on5f), mem.r8(p.addr.hold)
			local cnt_r, cnt_b, tmp = 0xF & reg_pcnt, 0xF0 & reg_pcnt, {}
			for k, v in pairs(db.cmd_status_b[i]) do tmp[k] = ut.tstb(status_b, v) end
			for k, v in ut.find_all(db.cmd_bytes, function(_, v) return type(v) == "number" end) do
				tmp[k] = (0x10 > v and v == cnt_r) or ut.tstb(cnt_b, v)
			end
			local state, resume = p.key.state or {}, false
			for k, v in pairs(tmp) do
				if v then
					state[k] = (not state[k] or state[k] < 0) and 1 or state[k] + 1
				else
					state[k] = (not state[k] or state[k] > 0) and -1 or state[k] - 1
				end
				if (k == "_A" or k == "_B" or k == "_C" or k == "_D") and state[k] == 1 then
					resume = true
				end
			end
			p.key.status_b = status_b
			p.key.reg_pcnt = reg_pcnt
			p.key.on1f = on1f
			p.key.on5f = on5f
			p.key.hold = hold
			p.key.state = state
			p.key.resume = resume
		end
	end
	input.accept                                           = function(btn, state_past)
		---@diagnostic disable-next-line: undefined-global
		state_past = state_past or (scr:frame_number() - input.accepted)
		local on = { false, false }
		for i, _, state in ut.ifind_all(players, function(p) return p.key.state["_" .. btn] end) do
			on[i] = 12 < state_past and 0 < state and (type(btn) == "number" or state <= state_past)
			on[i] = on[i] or (60 < state and state % 10 == 0)
			if on[i] then
				play_cursor_sound()
				---@diagnostic disable-next-line: undefined-global
				input.accepted = scr:frame_number()
				return true, on[1], on[2]
			end
		end
		return false, false, false
	end
	input.long_start                                       = function(state_past)
		if 12 < state_past then
			for _, p in ipairs(players) do
				if 35 < p.key.state._st then
					play_cursor_sound()
					return true
				end
			end
		end
		return false
	end
	for i = 1, 2 do -- プレイヤーの状態など
		local p1   = (i == 1)
		local base = p1 and 0x100400 or 0x100500
		local p    = {
			num             = i,
			is_fireball     = false,
			base            = 0x0,
			dummy_act       = 1,         -- 立ち, しゃがみ, ジャンプ, 小ジャンプ, スウェー待機
			dummy_gd        = dummy_gd_type.none, -- なし, オート, ブレイクショット, 1ヒットガード, 1ガード, 常時, ランダム, 強制
			dummy_wakeup    = wakeup_type.none, -- なし, リバーサル, テクニカルライズ, グランドスウェー, 起き上がり攻撃
			dummy_bs        = nil,       -- ランダムで選択されたブレイクショット
			dummy_bs_list   = {},        -- ブレイクショットのコマンドテーブル上の技ID
			dummy_bs_chr    = 0,         -- ブレイクショットの設定をした時のキャラID
			bs_count        = -1,        -- ブレイクショットの実施カウント
			dummy_rvs       = nil,       -- ランダムで選択されたリバーサル
			dummy_rvs_list  = {},        -- リバーサルのコマンドテーブル上の技ID
			dummy_rvs_chr   = 0,         -- リバーサルの設定をした時のキャラID
			rvs_count       = -1,        -- リバーサルの実施カウント
			gd_rvs_enabled  = false,     -- ガードリバーサルの実行可否
			gd_bs_enabled   = false,     -- BSの実行可否

			life_rec        = true,      -- 自動で体力回復させるときtrue
			red             = 2,         -- 体力設定     	--"最大", "赤", "ゼロ" ...
			max             = 1,         -- パワー設定       --"最大", "半分", "ゼロ" ...
			disp_hitbox     = true,      -- 判定表示
			disp_range      = true,      -- 間合い表示
			disp_base       = 1,         -- 処理のアドレスを表示するとき "OFF", "本体", "弾1", "弾2", "弾3"
			hide_char       = false,     -- キャラを画面表示しないときtrue
			hide_phantasm   = false,     -- 残像を画面表示しないときtrue
			disp_damage     = true,      -- ダメージ表示するときtrue
			disp_command    = 3,         -- 入力表示 1:OFF 2:ON 3:ログのみ 4:キーディスのみ
			disp_frame      = 1,         -- フレーム数表示する
			disp_fbfrm      = true,      -- 弾のフレーム数表示するときtrue
			disp_stun       = true,      -- 気絶表示
			disp_state      = 1,         -- 状態表示 1:OFF 2:ON 3:ON:小表示 4:ON:大表示 5:ON:フラグ表示
			dis_plain_shift = false,     -- ライン送らない現象
			no_hit          = 0,         -- Nヒット目に空ぶるカウントのカウンタ
			no_hit_limit    = 0,         -- Nヒット目に空ぶるカウントの上限
			force_y_pos     = 1,         -- Y座標強制
			update_act      = false,
			move_count      = 0,         -- スクショ用の動作カウント
			on_punish       = 0,
			on_block        = 0,
			key             = {
				log = ut.new_filled_table(global.key_hists, { key = "", frame = 0 }),
				gg = ggkey_create(i == 1),
				input = {},
			},
			throw_boxies    = {},
			fireballs       = {},
			random_boolean  = math.random(255) % 2 == 0,

			addr            = {
				base        = base,            -- キャラ状態とかのベースのアドレス
				control     = base + 0x12,     -- Human 1 or 2, CPU 3
				pos         = base + 0x20,     -- X座標
				pos_y       = base + 0x28,     -- Y座標
				cmd_side    = base + 0x86,     -- コマンド入力でのキャラ向きチェック用 00:左側 80:右側
				sway_status = base + 0x89,     -- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
				life        = base + 0x8B,     -- 体力
				pow         = base + 0xBC,     -- パワーアドレス
				hurt_state  = base + 0xE4,     -- やられ状態 ライン送らない状態用
				stun_limit  = p1 and 0x10B84E or 0x10B856, -- 最大気絶値
				char        = p1 and 0x107BA5 or 0x107BA7, -- キャラID
				color       = p1 and 0x107BAC or 0x107BAD, -- カラー A=0x00 D=0x01
				stun        = p1 and 0x10B850 or 0x10B858, -- 現在気絶値
				stun_timer  = p1 and 0x10B854 or 0x10B85C, -- 気絶値ゼロ化までの残フレーム数
				reg_pcnt    = p1 and 0x300000 or 0x340000, -- キー入力 REG_P1CNT or REG_P2CNT アドレス
				reg_st_b    = 0x380000,        -- キー入力 REG_STATUS_B アドレス
				on1f        = p1 and 0x1041B0 or 0x1041B4,
				on5f        = p1 and 0x1041AE or 0x1041B2,
				hold        = p1 and 0x1041AF or 0x1041B3,
			},

			add_cmd_hook    = function(cmd)
				local p = players[i]
				p.bs_hook = (p.bs_hook and p.bs_hook.cmd) and p.bs_hook or { cmd = db.cmd_types._5 }
				cmd = type(cmd) == "table" and cmd[p.cmd_side] or cmd
				p.bs_hook.cmd = p.bs_hook.cmd & db.cmd_masks[cmd]
				p.bs_hook.cmd = p.bs_hook.cmd | cmd
			end,
			clear_cmd_hook  = function(mask)
				local p = players[i]
				p.bs_hook = (p.bs_hook and p.bs_hook.cmd) and p.bs_hook or { cmd = db.cmd_types._5 }
				mask = type(mask) == "table" and mask[p.cmd_side] or mask
				mask = 0xFF ~ mask
				p.bs_hook.cmd = p.bs_hook.cmd & mask
			end,
			reset_cmd_hook  = function(cmd)
				local p = players[i]
				p.bs_hook = (p.bs_hook and p.bs_hook.cmd) and p.bs_hook or { cmd = db.cmd_types._5 }
				cmd = type(cmd) == "table" and cmd[p.cmd_side] or cmd
				p.bs_hook = { cmd = cmd }
			end,
			reset_sp_hook   = function(hook) players[i].bs_hook = hook end,
		}
		table.insert(players, p)
		p.body                     = p -- プレイヤーデータ自身、fireballとの互換用
		p.update_char              = function(data)
			p.char, p.char4, p.char8 = data, (data << 2), (data << 3)
			p.char_data = p.is_fireball and db.chars[#db.chars] or db.chars[data] -- 弾はダミーを設定する
			if not p.is_fireball then p.proc_active = true end
		end
		p.update_tmp_combo         = function(data)
			if data == 1 then    -- 一次的なコンボ数が1リセットしたタイミングでコンボ用の情報もリセットする
				p.last_combo             = 1 -- 2以上でのみ0x10B4E4か0x10B4E5が更新されるのでここで1リセットする
				p.last_stun              = 0
				p.last_st_timer          = 0
				p.combo_update           = global.frame_number + 1
				p.combo_damage           = 0
				p.combo_start_stun       = p.hit_stun
				p.combo_start_stun_timer = p.hit_stun_timer
				p.combo_stun             = 0
				p.combo_stun_timer       = 0
				p.combo_pow              = p.hurt_attack == p.op.attack and p.op.pow_up or 0
			elseif data > 1 then
				p.combo_update = global.frame_number + 1
			end
		end
		p.wp8                      = {
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
			[0x87] = function(data) p.on_update_87 = now() end,
			[0x88] = function(data) p.in_bs = data ~= 0 end,                       -- BS動作中
			[0x89] = function(data) p.sway_status, p.in_sway_line = data, data ~= 0x00 end, -- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
			[0x8B] = function(data, ret)
				-- 残体力がゼロだと次の削りガードが失敗するため常に1残すようにもする
				p.life, p.on_damage, ret.value = data, now(), math.max(data, 1) -- 体力
			end,
			[0x8E] = function(data)
				local changed = p.state ~= data
				p.on_block = data == 2 and now() or p.on_block                                -- ガードへの遷移フレームを記録
				p.on_hit = (data == 1 or data == 3) and now() or p.on_hit                     -- ヒットへの遷移フレームを記録
				if p.state == 0 and p.on_hit and not p.act_data.neutral then p.on_punish = now() + 10 end -- 確定反撃
				p.random_boolean = changed and (math.random(255) % 2 == 0) or p.random_boolean
				p.state, p.change_state = data, changed and now() or p.change_state           -- 今の状態と状態更新フレームを記録
				if data == 2 then
					p.update_tmp_combo(changed and 1 or 2)                                    -- 連続ガード用のコンボ状態リセット
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
			[0xA3] = function(data)                                                               -- A3:成立した必殺技コマンドID
				if not p.char_data then return end
				if data == 0 then
					p.on_sp_clear = now()
				elseif data ~= 0 then
					if mem.pc() == 0x395B2 then p.on_sp_established = now() end
					p.last_sp                 = data
					local sp2, proc_base      = (p.last_sp - 1) * 2, p.char_data.proc_base
					p.bs_pow, p.bs_invincible = mem.r8(proc_base.bs_pow + sp2) & 0x7F, mem.r8(proc_base.bs_invincible + sp2)
					p.bs_invincible           = p.bs_invincible == 0xFF and 0 or p.bs_invincible
					p.sp_invincible           = mem.r8(proc_base.sp_invincible + p.last_sp - 1)
					p.bs_invincible           = math.max(p.bs_invincible - 1, 0) -- 発生時に即-1される
					p.sp_invincible           = math.max(p.sp_invincible - 1, 0) -- 発生時に即-1される
				end
			end,
			-- A4:必殺技コマンドの持続残F ?
			[0xA5] = function(data)
				if mem.pc() == 0x395BA then p.on_sp_established = now() end
				p.additional = data
			end,                                         -- 追加入力成立時のデータ
			--[0xAD] = function(data)  end, -- ガード動作用
			[0xAF] = function(data) p.cancelable_data = data end, -- キャンセル可否 00:不可 C0:可 D0:可 正確ではないかも
			[0x68] = function(data) p.skip_frame = data ~= 0 end, -- 潜在能力強制停止
			[0xB6] = function(data)
				if not p.char_data then return end
				-- 攻撃中のみ変化、判定チェック用2 0のときは何もしていない、 詠酒の間合いチェック用など
				p.attackbits.harmless = data == 0
				p.attack_data         = data
				p.on_update_attack    = now()
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
				p.multi_hit         = p.max_hit_dn > 1 or p.max_hit_dn == 0 or p.char == 0x4 and p.attack == 0x16
				if 0x58 > data then
					-- 詠酒距離 家庭用 0236F0 からの処理
					local esaka = mem.r16(base_addr.esaka + ((data + data) & 0xFFFF))
					p.esaka, p.esaka_type = esaka & 0x1FFF, db.esaka_type_names[esaka & 0xE000] or ""
					if 0x27 <= data then                                   -- 家庭用 05B37E からの処理
						p.pow_up_hit = mem.r8((0xFF & (data - 0x27)) + base_addr.pow_up_ext) -- CA技、特殊技
					else
						p.pow_up_hit = mem.r8(base_addr.pow_up + data)     -- ビリー、チョンシュ、その他の通常技
					end
					p.pow_up_block = 0xFF & (p.pow_up_hit >> 1)            -- ガード時増加量 d0の右1ビットシフト=1/2
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
				if data == 0 and mem.pc() == 0x58930 then p.on_bs_clear = now() end                       -- BSフラグのクリア
				if data ~= 0 and mem.pc() == 0x58948 then p.on_bs_established, p.last_bs = now(), data end -- BSフラグ設定
			end,
			[0xD0] = function(data) p.flag_d0 = data end,                                                 -- フラグ群
			[{ addr = 0xD6, filter = 0x395A6 }] = function(data) p.on_sp_established, p.last_sp = now(), data end, -- 技コマンド成立時の技のID
			[0xE2] = function(data) p.sway_close = data == 0 end,
			[0xE4] = function(data) p.hurt_state = data end,                                              -- やられ状態
			[0xE8] = function(data, ret)
				if data < 0x10 and p.dummy_gd == dummy_gd_type.force then ret.value = 0x10 end            -- 0x10以上でガード
			end,
			[0xEC] = function(data) p.push_invincible = data end,                                         -- 押し合い判定の透過状態
			[0xEE] = function(data) p.in_hitstop_value, p.in_hitstun = data, ut.tstb(data, 0x80) end,
			[0xF6] = function(data) p.invincible = data end,                                              -- 打撃と投げの無敵の残フレーム数
			-- [0xF7] = function(data) end -- 技の内部の進行度
			[{ addr = 0xFB, filter = { 0x49418, 0x49428 } }] = function(data)
				p.kaiserwave = p.kaiserwave or {} -- カイザーウェイブのレベルアップ
				local pc = mem.pc()
				if (p.kaiserwave[pc] == nil) or p.kaiserwave[pc] + 1 < global.frame_number then p.on_update_spid = now() end
				p.kaiserwave[pc] = now()
			end,
			[p1 and 0x10B4E1 or 0x10B4E0] = function(data) -- 一時的なコンボ数
				if p.no_hit_limit > 0 and data >= p.no_hit_limit - 1 then
					p.no_hit = true
				elseif p.op.flag_c4 == 0 and p.op.flag_c8 == 0 then
					p.no_hit = false -- 非攻撃状態でヒット無効化状態のリセット
				end
				p.update_tmp_combo(data)
			end,
			[p1 and 0x10B4E5 or 0x10B4E4] = function(data) p.last_combo = data end, -- 最近のコンボ数
			[p1 and 0x10B4E7 or 0x10B4E8] = function(data) p.konck_back4 = data end, -- 1ならやられ中
			--[p1 and 0x10B4EA or 0x10B4E9] = function(data) p.tmp_combo2 = data end,  -- 一時的なコンボ数-1
			--[p1 and 0x10B4F0 or 0x10B4EF] = function(data) p.max_combo = data end, -- 最大コンボ数
			[p1 and 0x10B84E or 0x10B856] = function(data) p.stun_limit = data end, -- 最大気絶値
			[p1 and 0x10B850 or 0x10B858] = function(data) p.hit_stun = data end, -- 現在気絶値
			[p.addr.on1f] = function(data, ret)
				local hook = p.bs_hook
				if not hook or not hook.cmd then return end
				--ut.printf("%s bs_hook cmd %x", p.num, hook.cmd)
				-- フックの処理量軽減のため1F,5F,おしっぱのキー入力をまとめて記録する
				mem.w8(p.addr.on5f, input.merge(mem.r8(p.addr.on5f), hook.on5f or hook.cmd)) -- 押しっぱずっと有効
				mem.w8(p.addr.hold, input.merge(mem.r8(p.addr.hold), hook.hold or hook.cmd)) -- 押しっぱ有効が5Fのみ
				ret.value = input.merge(data, hook.on1f or hook.cmd)             -- 押しっぱ有効が1Fのみ
			end,
		}
		local special_throws       = {
			[0x39E56] = function() return mem.rg("D0", 0xFF) end, -- 汎用
			[0x45ADC] = function() return 0x14 end,      -- ブレイクスパイラルBR
		}
		local special_throw_addrs  = ut.get_hash_key(special_throws)
		local add_throw_box        = function(p, box) p.throw_boxies[box.id] = box end
		local extra_throw_callback = function(data)
			if in_match then
				local pc = mem.pc()
				local id = special_throws[pc]
				if id then add_throw_box(p.op, get_special_throw_box(p.op, id())) end -- 必殺投げ
				if pc == 0x06042A then add_throw_box(p, get_air_throw_box(p)) end -- 空中投げ
			end
		end
		local drill_counts         = { 0x07, 0x09, 0x0B, 0x0C, 0x3C, } -- { 0x00, 0x01, 0x02, 0x03, 0x04, }
		p.rp8                      = {
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
				if global.auto_input.drill > 1 then ret.value = drill_counts[global.auto_input.drill] end -- 自動ドリル
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
		p.wp16                     = {
			[0x34] = function(data) p.thrust = data end,
			[0x36] = function(data) p.thrust_frc = ut.int16tofloat(data) end,
			--[0x92] = function(data) p.anyhit_id = data end,
			--[0x9E] = function(data) p.ophit = all_objects[data] end, -- ヒットさせた相手側のベースアドレス
			[0xDA] = function(data) p.inertia = data end,
			[0xDC] = function(data) p.inertia_frc = ut.int16tofloat(data) end,
			[0xE6] = function(data) p.on_hit_any = now() + 1 end,                                                        -- 0xE6か0xE7 打撃か当身でフラグが立つ
			[p1 and 0x10B854 or 0x10B85C] = function(data) p.hit_stun_timer = data end,                                  -- 気絶値ゼロ化までの残フレーム数
		}
		local nohit                = function(data, ret) if get_object_by_reg("A4", {}).no_hit then ret.value = 0x311C end end -- 0x0001311Cの後半を返す
		p.rp16                     = {
			[{ addr = 0x20, filter = 0x2DD16 }] = function(data)
				if not in_match then return end
				p.main_d_close = mem.rg("D2", 0xFFFF) >= math.abs(p.pos - p.op.pos) -- 対スウェーライン攻撃の遠近判断
			end,
			[0x13124 + 0x2] = nohit,                                    -- 0x13124の読み出しハック
			[0x13128 + 0x2] = nohit,                                    -- 0x13128の読み出しハック
			[0x1312C + 0x2] = nohit,                                    -- 0x1312Cの読み出しハック
			[0x13130 + 0x2] = nohit,                                    -- 0x13130の読み出しハック
		}
		p.wp32                     = {
			[0x00] = function(data, ret)
				p.base   = data
				local pc = mem.pc()
				if (pc == 0x58268 or pc == 0x582AA) and global.damaged_move > 1 then
					ret.value = db.hit_effects.addrs[global.damaged_move]
				end
			end,
			-- [0x0C] = function(data) p.reserve_proc = data end,               -- 予約中の処理アドレス
			[0xC0] = function(data) p.flag_c0 = data end,                  -- フラグ群
			[0xC4] = function(data) p.flag_c4 = data end,                  -- フラグ群
			[0xC8] = function(data) p.flag_c8 = data end,                  -- フラグ群
			[0xCC] = function(data) p.flag_cc = data end,                  -- フラグ群
			[p1 and 0x394C4 or 0x394C8] = function(data) p.input_offset = data end, -- コマンド入力状態のオフセットアドレス
		}
		all_objects[p.addr.base]   = p
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
				[0xE7] = function(data) p.attackbits.fullhit = data ~= 0 
					p.on_hit = now() end,
				[0xE9] = function(data) p.on_hit = now() end,
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
					p.multi_hit     = p.max_hit_dn > 1 or p.max_hit_dn == 0
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
					local inactive_func = function()
						if reset then
							p.grabbable, p.attack_id, p.attackbits = 0, 0, {}
							p.boxies, p.on_fireball, p.body.act_data = #p.boxies == 0 and p.boxies or {}, -1, nil
						end
						p.proc_active = proc_active
					end
					if p.is_fireball and p.on_hit == now() and reset and not proc_active then
						p.delayed_inactive = now() + 1 -- ヒット処理後に判定と処理が終了されることの対応
						p.delayed_inactive_fnc = inactive_func
						-- ut.printf("lazy inactive box %X %X", mem.pc(), data)
						return
					end
					inactive_func()
				end,
			}
			table.insert(body.objects, p)
			body.fireballs[base], all_objects[base] = p, p
		end
		for _, p in pairs(all_objects) do -- 初期化
			p.attackbits       = {}
			p.boxies           = {}
			p.bases            = ut.new_filled_table(16, { count = 0, addr = 0x0, act_data = nil, name = "", pos1 = 0, pos2 = 0, xmov = 0, })
			p.clear_damages    = function()
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
				p.multi_hit = false
			end
			p.clear_frame_data = function()
				p.frames           = {}
				p.frame_gap        = p.frame_gap or 0
				p.act_frames       = {}
				p.frame_groups     = {}
				p.act_frames_total = 0
				p.fb_frames        = { act_frames = {}, frame_groups = {}, }
				p.gap_frames       = { act_frames = {}, frame_groups = {}, }
			end
			p.do_recover       = function(force)
				-- 体力と気絶値とMAX気絶値回復
				local life = { 0xC0, 0x60 }
				local max_life = life[p.red] or (p.red - #life) -- 赤体力にするかどうか
				local init_stuns = p.char_data and p.char_data.init_stuns or 0
				if dip_config.infinity_life then
					mem.w8(p.addr.life, max_life)
					mem.w8(p.addr.stun_limit, init_stuns) -- 最大気絶値
					mem.w8(p.addr.init_stun, init_stuns) -- 最大気絶値
				elseif p.life_rec then
					if force or (p.addr.life ~= max_life and 180 < math.min(p.throw_timer, p.op.throw_timer)) then
						mem.w8(p.addr.life, max_life) -- やられ状態から戻ったときに回復させる
						mem.w8(p.addr.stun, 0) -- 気絶値
						mem.w8(p.addr.stun_limit, init_stuns) -- 最大気絶値
						mem.w8(p.addr.init_stun, init_stuns) -- 最大気絶値
						mem.w16(p.addr.stun_timer, 0) -- 気絶値タイマー
					elseif max_life < p.life then
						mem.w8(p.addr.life, max_life) -- 最大値の方が少ない場合は強制で減らす
					end
				end

				-- パワーゲージ回復  POWモード　1:自動回復 2:固定 3:通常動作
				local fix_pow = { 0x3C, 0x1E, 0x00 }     -- 回復上限の固定値
				local max_pow = fix_pow[p.max] or (p.max - #fix_pow) -- 回復上限
				local cur_pow = mem.r8(p.addr.pow)       -- 現在のパワー値
				if global.pow_mode == 2 then
					mem.w8(p.addr.pow, max_pow)          -- 固定時は常にパワー回復
				elseif global.pow_mode == 1 and 180 < math.min(p.throw_timer, p.op.throw_timer) then
					mem.w8(p.addr.pow, max_pow)          -- 投げ無敵タイマーでパワー回復
				elseif global.pow_mode ~= 3 and max_pow < cur_pow then
					mem.w8(p.addr.pow, max_pow)          -- 最大値の方が少ない場合は強制で減らす
				end
			end
			p.init_state       = function()
				p.input_states = {}
				p.char_data = db.chars[p.char]
				p.do_recover(true)
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
				p.clear_frame_data()
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
				local sp = p.bs_hook
				if sp then
					if sp.ver then
						--ut.printf("bs_hook1 %x %x", sp.id, sp.ver)
						mem.w8(p.addr.base + 0xA3, sp.id)
						mem.w16(p.addr.base + 0xA4, sp.ver)
					else
						--ut.printf("bs_hook2 %x %x", sp.id, sp.f)
						mem.w8(p.addr.base + 0xD6, sp.id)
						mem.w8(p.addr.base + 0xD7, sp.f)
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
				for i, addr, p in ut.ifind(p_bases, get_object_by_addr) do
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
				if p.is_fireball then return end
				if p.multi_hit then
					-- 連続ヒットできるものはカウントで区別できるようにする
					p.attackbits.act_count = data
				elseif ut.tstb(p.flag_cc, db.flag_cc.grabbing) and p.op.last_damage_scaled ~= 0xFF then
					p.attackbits.act_count = p.op.last_damage_scaled
				end
			end,
			[0x67] = function(data) p.act_boxtype = 0xFFFF & (data & 0xC0 * 4) end, -- 現在の行動の判定種類
			[0x6A] = function(data)
				p.flag_6a = data
				p.repeatable = p.flag_c8 == 0 and (data & 0x4) == 0x4 -- 連打キャンセル判定
				p.flip_x1 = ((data & 0x80) == 0) and 0 or 1 -- 判定の反転
				local fake = ((data & 0xFB) == 0 or ut.tstb(data, 0x8) == false)
				local fake_pc = mem.pc() == 0x11E1E and now() ~= p.on_hit -- ヒット時のフラグセットは嘘判定とはしない
				p.attackbits.fake = fake_pc and fake
				if mem.pc() == 0x2D462 and p.char == 0x10 and data == 0x8 then
					p.attackbits.fake = true -- MVSビリーの判定なくなるバグの表現専用
				end
				p.attackbits.obsolute = (not fake_pc) and fake
				-- ut.printf("%s %s | %X %X | %s | %X | %s %s | %s %s", now(), p.on_hit, base, data, ut.tobitstr(data), mem.pc(), fake_pc, fake, p.attackbits.fake, p.attackbits.obsolute)
			end,
			[0x6F] = function(data) p.act_frame = data end, -- 動作パターンの残フレーム
			[0x71] = function(data) p.flip_x2 = (data & 1) end, -- 判定の反転
			[0x73] = function(data) p.box_scale = data + 1 end, -- 判定の拡大率
			--[0x76] = function(data) ut.printf("%X %X %X", base + 0x76, mem.pc(), data) end,
			[0x7A] = function(data)                    -- 攻撃判定とやられ判定
				if p.is_fireball and p.on_hit == now() and data == 0 then
					p.delayed_clearing = now() + 1 -- ヒット処理後に判定が消去されることの対応
					-- ut.printf("lazy clean box %X %X", mem.pc(), data)
					return
				end
				-- ut.printf("%s %s box %x %x %x", now(), p.on_hit, p.addr.base, mem.pc(), data)
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
							p.on_fireball = (p.on_fireball or 0) < 0 and now() or p.on_fireball or 0
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
				if data == 0xFF and p.is_fireball and p.body.char == 0x10 and p.act == 0x266 then
					-- 三節棍中段打ちの攻撃無効化、判定表示の邪魔なのでここで判定を削除する
					p.proc_active = false
				end
			end,
			[0xAB] = function(data) p.max_hit_nm = data end, -- 同一技行動での最大ヒット数 分子
			[0xB1] = function(data) p.hurt_invincible = data > 0 end, -- やられ判定無視の全身無敵
			[0xE9] = function(data) p.dmg_id = data end,     -- 最後にヒット/ガードした技ID
			[0xEB] = function(data) p.hurt_attack = data end, -- やられ中のみ変化
		})
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
				if p.act ~= data and (data == 0x193 or data == 0x13B) then p.on_wakeup = now() end
				p.act, p.on_update_act = data, now() -- 行動ID デバッグディップステータス表示のPと同じ
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
	local apply_1p2p_active  = function()
		if in_match and mem.r8(0x1041D3) == 0 then
			mem.w8(0x100024, 0x03)
			mem.w8(0x100027, 0x03)
		end
	end

	local goto_player_select = function(p_no)
		mod.fast_select()
		mem.w8(0x1041D3, 0x01)  -- 乱入フラグON
		mem.w8(0x107BB5, 0x01)
		mem.w32(0x107BA6, 0x00010001) -- CPU戦の進行数をリセット
		if p_no == 2 then
			mem.w32(0x100024, 0x02020002)
			mem.w16(0x10FDB6, 0x0202)
		else
			mem.w32(0x100024, 0x01010001)
			mem.w16(0x10FDB6, 0x0101)
		end
		mem.w16(0x1041D6, 0x0003) -- 対戦モード3
	end

	local restart_fight      = function(param)
		param              = param or {}
		global.next_stg3   = param.next_stage.stg3 or mem.r16(0x107BB8)
		local p1, p2       = param.next_p1 or 1, param.next_p2 or 21
		local p1col, p2col = param.next_p1col or 0x00, param.next_p2col or 0x01
		mod.fast_restart()
		mem.w8(0x1041D3, 0x01)  -- 乱入フラグON
		mem.w8(0x107C1F, 0x00)  -- キャラデータの読み込み無視フラグをOFF
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
		mem.r16(0x107BA6, param.next_bgm or 21) -- 対戦モード3 BGM

		-- メニュー用にキャラの番号だけ差し替える
		players[1].char, players[2].char = p1, p2
	end

	-- レコード＆リプレイ
	local recording          = {
		state           = 0, -- 0=レコーディング待ち, 1=レコーディング, 2=リプレイ待ち 3=リプレイ開始
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

		info            = { { label = "", col = 0 }, { label = "", col = 0 } },
		info1           = { { label = "● RECORDING %s", col = 0xFFFF1133 }, { label = "", col = 0xFFFF1133 } },
		info2           = { { label = "‣ REPLAYING %s", col = 0xFFFFFFFF }, { label = "HOLD START to MEMU", col = 0xFFFFFFFF } },
		info3           = { { label = "▪ PRESS START to REPLAY", col = 0xFFFFFFFF }, { label = "HOLD START to MEMU", col = 0xFFFFFFFF } },
		info4           = { { label = "● POSITION REC", col = 0xFFFF1133 }, { label = "PRESS START to MENU", col = 0xFFFF1133 } },

		procs           = {
			await_no_input = nil,
			await_1st_input = nil,
			await_play = nil,
			input = nil,
			play = nil,
			repeat_play = nil,
			play_interval = nil,
			fixpos = nil,
		},
	}
	for i = 1, 8 do table.insert(recording.slot, { side = 1, store = {}, name = string.format("スロット%s", i) }) end

	-- 調査用自動再生スロットの準備
	for i, preset_cmd in ipairs(db.research_cmd) do
		for _, reg_pcnt in ipairs(preset_cmd) do table.insert(recording.slot[i].store, { reg_pcnt = reg_pcnt, pos = { 1, -1 } }) end
	end
	recording.player = 1
	recording.active_slot = recording.slot[1]
	recording.active_slot.side = 1

	-- 状態クリア
	local cls_ps = function() for _, p in ipairs(players) do p.init_state() end end

	-- リプレイ開始位置記憶
	recording.procs.fixpos = function()
		recording.info   = recording.info4
		local pos        = { players[1].cmd_side, players[2].cmd_side }
		local fixpos     = { players[1].pos, players[2].pos }
		local fixsway    = { players[1].sway_status, players[2].sway_status }
		local fixscr     = {
			x = mem.r16(mem.stage_base_addr + screen.offset_x),
			y = mem.r16(mem.stage_base_addr + screen.offset_y),
			z = mem.r16(mem.stage_base_addr + screen.offset_z),
		}
		recording.fixpos = { pos = pos, fixpos = fixpos, fixscr = fixscr, fixsway = fixsway, }
	end
	-- 初回入力まち
	-- 未入力状態を待ちける→入力開始まで待ち受ける
	recording.procs.await_no_input = function(_)
		if players[recording.temp_player].key.reg_pcnt == 0 then -- 状態変更
			global.rec_main = recording.procs.await_1st_input
			print(global.frame_number .. " await_no_input -> await_1st_input ", recording.temp_player)
		end
	end
	recording.procs.await_1st_input = function(_)
		recording.info = recording.info1
		local p = players[recording.temp_player]
		if p.key.reg_pcnt ~= 0 then
			local pos = { players[1].cmd_side, players[2].cmd_side }
			recording.player = recording.temp_player
			recording.active_slot.side = p.cmd_side
			recording.active_slot.store = {}
			table.insert(recording.active_slot.store, {
				reg_pcnt = p.key.reg_pcnt,
				on1f = p.key.on1f,
				on5f = p.key.on5f,
				hold = p.key.hold,
				pos = pos
			})
			table.insert(recording.active_slot.store, { reg_pcnt = 0, pos = pos })
			-- 状態変更
			-- 初回のみ開始記憶
			if recording.fixpos == nil then recording.procs.fixpos() end
			global.rec_main = recording.procs.input
			print(global.frame_number .. " await_1st_input -> input")
		end
	end
	recording.procs.input = function(_) -- 入力中+入力保存
		recording.info = recording.info1
		local p = players[recording.temp_player]
		local pos = { players[1].cmd_side, players[2].cmd_side }
		table.remove(recording.active_slot.store)
		table.insert(recording.active_slot.store, {
			reg_pcnt = p.key.reg_pcnt,
			on1f = p.key.on1f,
			on5f = p.key.on5f,
			hold = p.key.hold,
			pos = pos
		})
		table.insert(recording.active_slot.store, { reg_pcnt = 0, pos = pos })
	end
	recording.procs.await_play = function(to_joy) -- リプレイまち
		recording.info = recording.info3
		local force_start_play = global.rec_force_start_play
		global.rec_force_start_play = false -- 初期化

		local tmp_slots = {}
		for j, slot in ipairs(recording.slot) do
			local store = slot.store
			-- 末尾の冗長な未入力を省く
			while #store > 0 and store[#store].reg_pcnt == 0 do table.remove(store, #store) end
			-- コマンド登録があってメニューONになっているスロットを一時保存
			if #store > 0 and recording.live_slots[j] == true then
				table.insert(tmp_slots, slot)
			end
		end

		-- ランダムで1つ選定
		recording.active_slot = #tmp_slots > 0 and tmp_slots[math.random(#tmp_slots)] or { store = {}, name = "EMPTY" }

		if #recording.active_slot.store > 0 and (input.accept("st") or force_start_play == true) then
			recording.force_start_play = false
			-- 状態変更
			recording.play_count = 1
			global.rec_main = recording.procs.play

			-- メインラインでニュートラル状態にする
			for i, p in ipairs(players) do
				-- 状態リセット   1:OFF 2:1Pと2P 3:1P 4:2P
				if global.replay_reset == 2 or (global.replay_reset == 3 and i == 3) or (global.replay_reset == 4 and i == 4) then
					for fnc, tbl in pairs({
						[mem.w16i] = { [0x28] = 0, [0x24] = 0x18, },
						[mem.w16] = { [0x60] = 0x1, [0x64] = 0xFFFF, [0x6E] = 0, },
						-- 0x58D5A = やられからの復帰処理  0x261A0: 素立ち処理
						[mem.w32] = { [p.addr.base] = 0x58D5A, [0x28] = 0, [0x34] = 0, [0x38] = 0, [0x3C] = 0, [0x44] = 0, [0x48] = 0, [0x4C] = 0, [0x50] = 0, [0xDA] = 0, [0xDE] = 0, },
						[mem.w8] = { [0x61] = 0x1, [0x63] = 0x2, [0x65] = 0x2, [0x66] = 0, [0x6A] = 0, [0x7E] = 0, [0xB0] = 0, [0xB1] = 0, [0xC0] = 0x80, [0xC2] = 0, [0xFC] = 0, [0xFD] = 0, [0x89] = 0, },
					}) do for addr, value in pairs(tbl) do fnc(addr, value) end end
					p.do_recover(true)
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
			for _, joy in ipairs(use_joy) do to_joy[joy.field] = next_joy[joy.field] or false end
			return
		end
	end
	-- 繰り返しリプレイ待ち
	recording.procs.repeat_play = function(_)
		recording.info = recording.info2
		-- 繰り返し前の行動が完了するまで待つ
		local p, op, p_ok = players[recording.player], players[3 - recording.player], true
		if global.await_neutral == true then
			p_ok = p.act_data.neutral or (not p.act_data.neutral and p.on_update_act == global.frame_number and recording.last_act ~= p.act)
		end
		if p_ok then
			if recording.last_pos_y == 0 or (recording.last_pos_y > 0 and p.pos_y == 0) then
				-- リプレイ側が通常状態まで待つ
				if op.act_data.neutral and op.state == 0 then
					-- 状態変更
					global.rec_main = recording.procs.await_play
					global.rec_force_start_play = true -- 一時的な強制初期化フラグをON
					print(global.frame_number .. " repeat_play -> await_play(force)")
					return
				end
			end
		end
	end
	-- リプレイ中
	recording.procs.play = function(_)
		recording.info = recording.info2
		if input.accept("st") then
			-- 状態変更
			global.rec_main = recording.procs.await_play
			print(global.frame_number .. " play -> await_play")
			return
		end

		local stop = false
		local store = recording.active_slot.store[recording.play_count]
		local p = players[3 - recording.player]
		if store == nil then
			stop = true
		elseif p.state == 1 then
			if global.replay_stop_on_dmg then stop = true end
		end
		if not stop and store then
			-- 入力再生
			local reg_pcnt, on1f, on5f, hold = store.reg_pcnt, store.on1f, store.on5f, store.hold
			-- 入力時と向きが変わっている場合は左右反転させて反映する
			if recording.active_slot.side == p.cmd_side then -- elseif opside == p.op.cmd_side then
				if p.cmd_side ~= store.pos[p.num] then
					if ut.tstb(reg_pcnt, db.cmd_bytes._4) then
						reg_pcnt = ut.hex_set(ut.hex_clear(reg_pcnt, db.cmd_bytes._4), db.cmd_bytes._6)
						on1f = ut.hex_set(ut.hex_clear(on1f, db.cmd_bytes._4), db.cmd_bytes._6)
						on5f = ut.hex_set(ut.hex_clear(on5f, db.cmd_bytes._4), db.cmd_bytes._6)
						hold = ut.hex_set(ut.hex_clear(hold, db.cmd_bytes._4), db.cmd_bytes._6)
					elseif ut.tstb(reg_pcnt, db.cmd_bytes._6) then
						reg_pcnt = ut.hex_set(ut.hex_clear(reg_pcnt, db.cmd_bytes._6), db.cmd_bytes._4)
						on1f = ut.hex_set(ut.hex_clear(on1f, db.cmd_bytes._6), db.cmd_bytes._4)
						on5f = ut.hex_set(ut.hex_clear(on5f, db.cmd_bytes._6), db.cmd_bytes._4)
						hold = ut.hex_set(ut.hex_clear(hold, db.cmd_bytes._6), db.cmd_bytes._4)
					end
				end
			end
			p.bs_hook = { cmd = reg_pcnt, on1f = on1f, on5f = on5f, hold = hold }
			recording.play_count = recording.play_count + 1

			-- 繰り返し判定
			if 0 < #recording.active_slot.store and #recording.active_slot.store < recording.play_count then
				stop = true
			end
		end

		if stop then
			global.repeat_interval = recording.repeat_interval
			-- 状態変更
			global.rec_main = recording.procs.play_interval
			print(global.frame_number .. " play -> play_interval")
		end
	end

	-- リプレイまでの待ち時間
	recording.procs.play_interval = function(_)
		if input.accept("st") then
			-- 状態変更
			global.rec_main = recording.procs.await_play
			print(global.frame_number .. " play_interval -> await_play")
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
				global.rec_main = recording.procs.repeat_play
				print(global.frame_number .. " play_interval -> repeat_play")
				return
			else
				-- 状態変更
				global.rec_main = recording.procs.await_play
				print(global.frame_number .. " play_interval -> await_play")
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
		local ret = false
		if not last_frame or last_frame.name ~= frame.name or (frame.update and frame.count == 1) then
			table.insert(frame_groups, { frame }) -- ブレイクしたので新規にグループ作成
			frame.last_total = 0         -- グループの先頭はフレーム合計ゼロ開始
			last_group = frame_groups
			ret = true
		elseif last_frame ~= frame then
			table.insert(last_group, frame) -- 同一グループに合計加算して保存
			frame.last_total = last_frame.last_total + last_frame.count
		end
		while 180 < #last_group do table.remove(last_group, 1) end --バッファ長調整
		return ret
	end

	-- グラフでフレームデータを末尾から描画
	local decos = {
		{ type = frame_attack_types.post_fireball, txt = "▪", fix = -0.4 },
		{ type = frame_attack_types.pre_fireball, txt = "▫", fix = -0.4 },
		{ type = frame_attack_types.off_fireball, txt = "◦", fix = -0.35 },
		{ type = frame_attack_types.on_fireball, txt = "•", fix = -0.35 },
		{ type = frame_attack_types.on_air, txt = "▴", fix = -0.5 },
		{ type = frame_attack_types.on_ground, txt = "▾", fix = -0.5 },
	}
	local dodges = {
		{ type = frame_attack_types.full,        y = 1.0, step = 1.6, txt = "Full", border = 0.8, xline = 0xFF00BBDD },
		{ type = frame_attack_types.high_dodges, y = 1.6, step = 3,   txt = "Low",  border = 1,   xline = 0xFF00FFFF },
		{ type = frame_attack_types.low_dodges,  y = 1.6, step = 3,   txt = "High", border = 1,   xline = 0xFF00BBDD },
		{ type = frame_attack_types.main,        y = 1.6, step = 3,   txt = "Main", border = 1,   xline = 0xFFFF6E00 },
		{ type = frame_attack_types.sway,        y = 1.6, step = 3,   txt = "Sway", border = 1,   xline = 0xFFFF6E00 },
	}
	local exclude_dodge = function(attackbit)
		return ut.tstb(attackbit, frame_attack_types.crounch60 |
			frame_attack_types.crounch64 |
			frame_attack_types.crounch68 |
			frame_attack_types.crounch76 |
			frame_attack_types.crounch80)
	end
	local dodraw = function(group, left, top, height, limit, txt_y, disp_name)
		if #group == 0 then return end
		txt_y = txt_y or 0

		if disp_name and (group[1].col + group[1].line) > 0 then
			draw_text_with_shadow(left + 12, txt_y + top, group[1].name, 0xFFC0C0C0) -- 動作名を先に描画
		end

		local right = limit + left
		local xright = math.min(group[#group].last_total + group[#group].count + left, right)
		local frame_txts = {}
		for k = #group, 1, -1 do
			local frame = group[k]
			local xleft = xright - frame.count
			if xleft + xright < left then break end
			xleft = math.max(xleft, left)

			if ((frame.col or 0) + (frame.line or 0)) > 0 then
				scr:draw_box(xleft, top, xright, top + height, frame.line, frame.col)

				local dodge_txt = ""
				if not exclude_dodge(frame.attackbit) then
					for _, s, col in ut.ifind(dodges, function(s) return ut.tstb(frame.attackbit, s.type) and frame.xline or nil end) do
						dodge_txt = s.txt -- 無敵種類
						for i = s.y, height - s.y, s.step do scr:draw_box(xright, top + i, xleft, math.min(top + height, top + i + s.border), 0, col) end
					end
				end

				local deco_txt = ""
				for _, deco in ut.ifind(decos, function(deco) return ut.tstb(frame.attackbit, deco.type) and deco or nil end) do
					deco_txt = deco.txt -- 区切り記号の表示
					draw_text(xleft + get_string_width(deco_txt) * deco.fix, txt_y + top - 6, deco_txt)
					scr:draw_line(xleft, top, xleft, top + height)
				end

				local txtx = (frame.count > 5) and (xleft + 1) or (3 > frame.count) and (xleft - 1) or xleft
				local count_txt = 300 < frame.count and "LOT" or ("" .. frame.count)
				local font_col = frame.font_col or 0xFFFFFFFF
				if font_col > 0 then draw_text_with_shadow(txtx, txt_y + top, count_txt, font_col) end

				-- TODO きれいなテキスト化
				--table.insert(frame_txts, 1, string.format("%s%s%s", deco_txt, count_txt, dodge_txt))
			end
			if xleft <= left then break end
			xright = xleft
		end
		draw_text(right - 40, txt_y + top, table.concat(frame_txts, "/"))
	end

	local draw_frames = function(groups, x, y, limit)
		if groups == nil or #groups == 0 then return end
		local height, span_ratio = get_line_height(), 0.2
		local span = (2 + span_ratio) * height
		-- 縦に描画
		if #groups < 7 then y = y + (7 - #groups) * span end
		for j = #groups - math.min(#groups - 1, 6), #groups do
			dodraw(groups[j], x, y, height, limit, 0, true)
			for _, frame in ipairs(groups[j]) do
				for _, sub_group in ipairs(frame.fb_frames or {}) do
					dodraw(sub_group, x, y, height, limit)
				end
				for _, sub_group in ipairs(frame.gap_frames or {}) do
					dodraw(sub_group, x, y + height, height - 1, limit)
				end
			end
			y = y + span
		end
	end

	local frame_meter = { limit = 70, cell = 3.5 }
	frame_meter.buffer_limit = frame_meter.limit * 2 -- バッファ長=2行まで許容
	frame_meter.add = function(p, frame)          -- フレームデータの追加
		if p.is_fireball then return end
		if not global.both_act_neutral and global.old_both_act_neutral then
			p.frames = {}                                           -- バッファ初期化
		end
		local frames, reset, first, blank = p.frames, false, false, false -- プレイヤーごとのバッファを取得
		local last = frames[#frames]
		blank = ut.tstb(frame.attackbit, frame_attack_types.frame_plus)
		if blank then
			if last and last.blank then
				last.blank = last.blank + 1
				last.attackbit = frame.attackbit
				last.key = frame.key
				last.total = last.total + 1
				return -- 無駄なバッファ消費を避けるためカウントアップだけして抜ける
			end
			-- 有利フレームは透明表示にする
			frame = { col = 0, line = 0, count = 0, attackbit = frame.attackbit, key = frame.key, blank = 1 }
		elseif last and last.blank then
			local cmp = last -- 動作再開時の補完
			for i = last.count + 1, last.blank do
				cmp = ut.deepcopy(cmp)
				cmp.count = cmp.count + 1
				table.insert(frames, cmp)
			end
		end

		first = #frames == 0
		reset = reset or first
		reset = reset or frame.attackbit ~= last.key
		reset = reset or frame.col ~= last.col
		--reset = reset or frame.name ~= last.name
		--reset = reset or frame.update ~= last.update

		frame.count = reset and 1 or last.count + 1
		frame.total = (first or not last.total) and 1 or last.total + 1
		if last and last.startup then
			frame.startup = last.startup
		elseif not frame.startup and ut.tstb(frame.attackbit, frame_attack_types.attacking) and
			not ut.tstb(frame.attackbit, frame_attack_types.fake) then
			frame.startup = frame.total
		end
		for _, deco in ut.ifind(decos, function(deco) return ut.tstb(frame.decobit, deco.type) end) do
			frame.deco = deco.txt
		end
		if not exclude_dodge(frame.attackbit) then
			for _, s in ut.ifind(dodges, function(s) return ut.tstb(frame.attackbit, s.type) end) do
				frame.dodge = s
			end
		end
		table.insert(frames, frame)                                  -- 末尾に追加
		if #frames <= frame_meter.buffer_limit then return end       -- バッファ長が2行以下なら抜ける
		local frame_limit = frame_meter.limit + (blank and 2 or 1)   -- ブランクぶん追加でバッファする
		while frame_limit ~= #frames do table.remove(frames, 1) end  -- 1行目のバッファを削除
	end
	frame_meter.draw = function(p, y1)                               -- フレームメーターの表示
		if p.is_fireball then return end
		local x0 = (scr.width - frame_meter.cell * frame_meter.limit) // 2 -- 表示開始位置
		local height = get_line_height()
		local y2 = y1 + height                                       -- メーター行のY位置
		local frames, max_x = {}, #p.frames
		while (0 < max_x) do
			if not ut.tstb(p.frames[max_x].attackbit, frame_attack_types.frame_plus) then
				for i = 1, max_x do table.insert(frames, p.frames[i]) end
				break
			end
			max_x = max_x - 1
		end
		local remain = (frame_meter.limit < max_x) and (max_x % frame_meter.limit) or 0
		local separators = {}
		local startup = 0 < max_x and frames[max_x] and frames[max_x].startup or "--"
		local total = 0 < max_x and frames[max_x] and frames[max_x].total or "---"
		border_box(x0, y1, x0 + frame_meter.limit * frame_meter.cell, y2, 0xFF000000, 0, 0.5) -- 外枠
		for ix = remain + 1, max_x do
			local frame = frames[ix]
			local x1 = (((ix - 1) % frame_meter.limit) * frame_meter.cell) + x0
			local x2 = x1 + frame_meter.cell
			if frame.deco then
				table.insert(separators, { -- 記号
					deco = { x1, y1, frame.deco },
				})
			end
			if ix == max_x then -- 末尾のみ四方をBOX描画して太線で表示
				table.insert(separators, { -- フレーム終端
					txt = { x2, y1, frame.count },
					box = { x1, y1, x2, y2, frame.line, 0, 1 }
				})
			elseif ((remain == 0) or (remain + 4 < ix)) and (frame.count >= frames[ix + 1].count) then
				table.insert(separators, { -- フレーム区切り
					txt = { x2, y1, 0 < frame.count and frame.count or "" },
					box = { x1, y1, x2, y2, frame.line, 0, 0 }
				})
			end
			scr:draw_box(x1, y1, x2, y2, 0, frame.line) -- 四角の描画
			if frame.dodge then                -- 無敵の描画
				local s, col = frame.dodge, frame.dodge.xline
				for i = s.y, height - s.y, s.step do scr:draw_box(x1, y1 + i, x2, y1 + i + s.border, 0, col) end
			end
			scr:draw_box(x1, y1, x2, y2, 0xFF000000, 0) -- 四角の描画
		end
		-- 区切り描画
		for i, args in ipairs(separators) do
			if i == #separators then break end
			if args.box then scr:draw_box(table.unpack(args.box)) end
			if args.txt then draw_rtext_with_shadow(table.unpack(args.txt)) end
			if args.deco then draw_text_with_shadow(table.unpack(args.deco)) end
		end
		-- マスクの四角描画
		if frame_meter.limit ~= max_x or max_x == 0 then
			for ix = (max_x % frame_meter.limit) + 1, frame_meter.limit do
				local x1 = ((ix - 1) * frame_meter.cell) + x0
				scr:draw_box(x1, y1, x1 + frame_meter.cell, y2, 0xFF000000, 0xCC888888)
			end
		end
		-- 終端の描画
		if 0 < #separators then
			local args = separators[#separators]
			if args.box then border_waku(table.unpack(args.box)) end
			if args.txt then draw_rtext_with_shadow(table.unpack(args.txt)) end
		end
		-- フレーム概要の描画
		local total_num = type(total) == "number" and total or 0
		return startup, total_num, function(op_total) -- 後処理での描画用に関数で返す
			local gap = op_total - total_num
			local gap_txt = string.format("%4s", string.format(gap > 0 and "+%d" or "%d", gap))
			local gap_col = gap == 0 and 0xFFFFFFFF or gap > 0 and 0xFF0088FF or 0xFFFF0088
			local label = string.format("Startup %2s / Total %3s / Recovery", startup, total)
			local ty = p.num == 1 and y1 - height or y1 + height
			draw_text_with_shadow(x0, ty, label)
			if not global.both_act_neutral then gap_txt, gap_col = "---", 0xFFFFFFFF end
			draw_text_with_shadow(x0 + get_string_width(label) - 4, ty, gap_txt, gap_col)
		end
	end

	local proc_frame = function(p)
		-- 弾フレーム数表示の設定を反映する
		local fireballs = p.disp_fbfrm and p.fireballs or {}
		local objects   = p.disp_fbfrm and p.objects or { p }
		-- 弾の情報をマージする
		for _, fb in pairs(fireballs) do if fb.proc_active then p.attackbit = p.attackbit | fb.attackbit end end

		local col, line, xline, attackbit = 0xAAF0E68C, 0xDDF0E68C, 0, p.attackbit
		local boxkey, fbkey = "", "" -- 判定の形ごとの排他につかうキー
		-- フレーム数表示設定ごとのマスク
		local key_mask = ut.hex_clear(0xFFFFFFFFFFFFFFFF,
			frame_attack_types.mask_fireball       | -- 弾とジャンプ状態はキーから省いて無駄な区切りを取り除く
			frame_attack_types.pre_fireball        |
			frame_attack_types.post_fireball       |
			frame_attack_types.on_fireball         |
			frame_attack_types.off_fireball        |
			frame_attack_types.on_air              |
			frame_attack_types.on_ground)
		local attackbit_mask = ut.hex_clear(0xFFFFFFFFFFFFFFFF,
			frame_attack_types.fb                  | -- 0x 1 0000 0001 弾
			frame_attack_types.attacking           | -- 0x 2 0000 0010 攻撃動作中
			frame_attack_types.juggle              | -- 0x 4 0000 0100 空中追撃可能
			frame_attack_types.fake                | -- 0x 8 0000 1000 攻撃能力なし(判定初期から)
			frame_attack_types.obsolute            | -- 0x F 0001 0000 攻撃能力なし(動作途中から)
			frame_attack_types.fullhit             | -- 0x20 0010 0000 全段ヒット状態
			frame_attack_types.harmless            | -- 0x40 0100 0000 攻撃データIDなし
			frame_attack_types.frame_plus          | -- フレーム有利：Frame advantage
			frame_attack_types.frame_minus         | -- フレーム不利：Frame disadvantage,
			frame_attack_types.pre_fireball        | -- 飛び道具処理中
			frame_attack_types.post_fireball       | -- 飛び道具処理中
			frame_attack_types.on_fireball         | -- 飛び道具判定あり
			frame_attack_types.off_fireball        | -- 飛び道具判定あり
			frame_attack_types.full                | -- 全身無敵
			frame_attack_types.main                | -- メインライン攻撃無敵
			frame_attack_types.sway                | -- メインライン攻撃無敵
			frame_attack_types.high                | -- 上段攻撃無敵
			frame_attack_types.low                 | -- 下段攻撃無敵
			frame_attack_types.away                | --上半身無敵 32 避け
			frame_attack_types.waving_blow         | -- 上半身無敵 40 ウェービングブロー,龍転身,ダブルローリング
			frame_attack_types.laurence_away       | -- 上半身無敵 48 ローレンス避け
			frame_attack_types.crounch60           | -- 頭部無敵 60 屈 アンディ,東,舞,ホンフゥ,マリー,山崎,崇秀,崇雷,キム,ビリー,チン,タン
			frame_attack_types.crounch64           | -- 頭部無敵 64 屈 テリー,ギース,双角,ボブ,ダック,リック,シャンフェイ,アルフレッド
			frame_attack_types.crounch68           | -- 頭部無敵 68 屈 ローレンス
			frame_attack_types.crounch76           | -- 頭部無敵 76 屈 フランコ
			frame_attack_types.crounch80           | -- 頭部無敵 80 屈 クラウザー
			frame_attack_types.levitate40          | -- 足元無敵 対アンディ屈C
			frame_attack_types.levitate32          | -- 足元無敵 対ギース屈C
			frame_attack_types.levitate24          | -- 足元無敵 対だいたいの屈B（キムとボブ以外）
			frame_attack_types.on_air              | -- ジャンプ
			frame_attack_types.on_ground           | -- 着地
			(0xFF << frame_attack_types.act_count) | -- act_count 本体の動作区切り用
			(0xFF << frame_attack_types.fb_effect) | -- effect 弾の動作区切り用
			(0xFF << frame_attack_types.attack)    | -- attack
			(0xFFFF << frame_attack_types.act)     | -- act
			frame_attack_types.op_cancelable) -- 自身がやられ中で相手キャンセル可能
		if p.skip_frame then
			col, line = 0xAA000000, 0xAA000000 -- 強制停止
		elseif ut.tstb(p.op.flag_cc, db.flag_cc.thrown) and p.op.on_damage == global.frame_number then
			attackbit = attackbit | frame_attack_types.attacking
			col, line = db.box_types.attack.fill, db.box_types.attack.outline -- 投げダメージ加算タイミング
		elseif not ut.tstb(p.flag_cc | p.op.flag_cc, db.flag_cc.thrown) and
			p.in_hitstop == global.frame_number or p.on_hit_any == global.frame_number then
			col, line = 0xAA444444, 0xDD444444 -- ヒットストップ中
			--elseif p.on_bs_established == global.frame_number then
			--	col, line = 0xAA0022FF, 0xDD0022FF -- BSコマンド成立
		else
			--  1:OFF 2:ON 3:ON:判定の形毎 4:ON:攻撃判定の形毎 5:ON:くらい判定の形毎
			if p.disp_frame == 2 then -- 2:ON
			elseif p.disp_frame == 3 then -- 3:ON:判定の形毎
				for _, fb in pairs(fireballs) do if fb.proc_active then fbkey = fbkey .. "|" .. fb.hitboxkey .. "|" .. fb.hurtboxkey end end
				boxkey = p.hitboxkey .. "|" .. p.hurtboxkey .. "|" .. fbkey
			elseif p.disp_frame == 4 then -- 4:ON:攻撃判定の形毎
				for _, fb in pairs(fireballs) do if fb.proc_active then fbkey = fbkey .. "|" .. fb.hitboxkey end end
				boxkey = p.hitboxkey .. "|" .. fbkey
			elseif p.disp_frame == 5 then -- 5:ON:くらい判定の形毎
				for _, fb in pairs(fireballs) do if fb.proc_active then fbkey = fbkey .. "|" .. fb.hurtboxkey end end
				boxkey = p.hurtboxkey .. "|" .. fbkey
			end
			attackbit_mask = attackbit_mask      |
				frame_attack_types.high_dodges   |
				frame_attack_types.low_dodges    |
				frame_attack_types.frame_plus    |
				frame_attack_types.full          |
				frame_attack_types.main          |
				frame_attack_types.sway          |
				frame_attack_types.on_air        |
				frame_attack_types.on_ground
			if ut.tstb(p.attackbit, frame_attack_types.attacking) and not ut.tstb(p.attackbit, frame_attack_types.fake) then
				attackbit_mask = attackbit_mask | frame_attack_types.attacking
				--attackbit_mask = attackbit_mask | frame_attack_types.fake -- fakeの表現がTODO
				if p.hit.box_count > 0 and p.max_hit_dn > 0 then
					attackbit_mask = attackbit_mask |
						(0xFF << frame_attack_types.act_count) |
						(0xFF << frame_attack_types.fb_effect)
				end
			end
			if ut.tstb(p.flag_d0, db.flag_d0._06) then -- 自身がやられ中で相手キャンセル可能
				attackbit_mask = attackbit_mask |
					frame_attack_types.op_cancelable
			end

			for _, d in ut.ifind(dodges, function(d) return ut.tstb(attackbit, d.type) end) do
				attackbit = attackbit | d.type -- 部分無敵
			end
			for _, xp in ut.ifind_all(objects, function(xp) return xp.proc_active end) do
				if xp.hitbox_types and #xp.hitbox_types > 0 and xp.hitbox_types then
					attackbit = attackbit | xp.attackbit
					table.sort(xp.hitbox_types, function(t1, t2) return t1.sort > t2.sort end) -- ソート
					if xp.hitbox_types[1].kind ~= db.box_kinds.attack and xp.repeatable then
						col, line = 0xAAD2691E, 0xDDD2691E                      -- やられ判定より連キャン状態を優先表示する
					else
						col, line = xp.hitbox_types[1].fill, xp.hitbox_types[1].outline
						col = col > 0xFFFFFF and (col | 0x22111111) or 0
					end
				end
			end
		end

		local decobit  = attackbit
		attackbit      = attackbit & attackbit_mask

		local frame    = p.act_frames[#p.act_frames]
		local prev     = frame and frame.name_plain
		local act_data = p.body.act_data
		local plain    = (frame and act_data.name_set and act_data.name_set[prev]) and prev or act_data.name_plain
		local name     = ut.convert(plain)
		local key      = key_mask & attackbit
		local matchkey = attackbit
		local update   = p.on_update_87 == global.frame_number and p.update_act

		frame_meter.add(p, { line = line, col = col, attackbit = attackbit, key = key, boxkey = boxkey, decobit = decobit, name = name, update = update, })

		if update or not frame or frame.col ~= col or frame.key ~= matchkey or frame.boxkey ~= boxkey then
			--行動IDの更新があった場合にフレーム情報追加
			frame = ut.table_add(p.act_frames, {
				act        = p.act,
				count      = 1,
				name       = name,
				name_plain = plain,
				col        = col,
				line       = line,
				xline      = xline,
				update     = update,
				attackbit  = attackbit,
				key        = key,
				boxkey     = boxkey,
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
		key, boxkey, frame = p.attackbit, fbkey, frames[#frames]
		if update or not frame or upd_group or frame.key ~= key or frame.boxkey ~= boxkey then
			frame = ut.table_add(frames, {
				act        = p.act,
				count      = 1,
				font_col   = 0,
				name       = last_frame.name,
				name_plain = last_frame.name_plain,
				col        = 0x00FFFFFF,
				line       = 0x00FFFFFF,
				update     = update,
				attackbit  = p.attackbit,
				key        = key,
				boxkey     = boxkey,
			}, 180)
		else
			frame.count = frame.count + 1
		end
		if update_frame_groups(frame, groups) and parent and groups then ut.table_add(parent, groups[#groups], 180) end

		-- フレーム差
		---@diagnostic disable-next-line: unbalanced-assignments
		parent, frames, groups = last_frame and last_frame.gap_frames or nil, p.gap_frames.act_frames, p.gap_frames.frame_groups
		key, boxkey, frame = p.attackbit & frame_attack_types.frame_advance, "", frames[#frames]
		if update or not frame or upd_group or frame.key ~= key or frame.boxkey ~= boxkey then
			local col = (p.frame_gap > 0) and 0xFF0088FF or (p.frame_gap < 0) and 0xFFFF0088 or 0xFFFFFFFF
			frame = ut.table_add(frames, {
				act        = p.act,
				count      = 1,
				font_col   = col,
				name       = last_frame.name,
				name_plain = last_frame.name_plain,
				col        = 0x22FFFFFF & col,
				line       = 0xCCFFFFFF & col,
				update     = update,
				key        = key,
				boxkey     = boxkey,
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
		p.reset_sp_hook(p.dummy_rvs)
		if p.dummy_rvs.cmd and rvs_types.knock_back_recovery ~= rvs_type then
			if (((p.flag_c0 | p.old.flag_c0) & 0x2 == 0x2) or db.pre_down_acts[p.act]) and p.dummy_rvs.cmd == db.cmd_types._2D then
				p.reset_sp_hook() -- no act
			end
		end
	end

	-- 技データのIDかフラグから技データを返す
	local resolve_act_neutral = function(p)
		if ut.tstb(p.flag_c0, 0x3FFD723) or (p.attack_data or 0 | p.flag_c4 | p.flag_c8) ~= 0 or ut.tstb(p.flag_cc, 0xFFFFFF3F) or ut.tstb(p.flag_d0, db.flag_d0.hurt) then
			return false
		end
		return true
	end
	local get_act_data = function(p)
		local cache = db.chars[p.char] and db.chars[p.char].acts or {}
		local act_data = cache[p.act]
		if not act_data then
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
			elseif ut.tstb(p.flag_cc, db.flag_cc._00) then
				name = string.format("%s %s %s", db.get_flag_name(p.flag_cc, db.flag_names_cc), db.get_flag_name(p.flag_c0, db.flag_names_c0), p.act)
			else
				name = string.format("%s %s %s", db.get_flag_name(p.flag_c0, db.flag_names_c0), p.act)
			end
			act_data = cache[name] or { bs_name = name, name = name, normal_name = name, slide_name = name, count = 1 }
			if not cache[p.act] then cache[p.act] = act_data end
			if not cache[name] then cache[name] = act_data end
			act_data.neutral = act_data.neutral or resolve_act_neutral(p)
			act_data.type = act_data.type or (act_data.neutral and db.act_types.any or db.act_types.free)
		elseif act_data.neutral == nil then
			-- フラグ状態と技データの両方でニュートラル扱いかどうかを判断する
			act_data.neutral = resolve_act_neutral(p) and ut.tstb(act_data.type, db.act_types.free | db.act_types.block)
		end
		-- 技動作は滑りかBSかを付与する
		act_data.name_plain = p.sliding and act_data.slide_name or p.in_bs and act_data.bs_name or act_data.normal_name
		act_data.name = ut.convert(act_data.name_org)
		return act_data
	end

	-- トレモのメイン処理
	menu.tra_main.proc = function()
		if not in_match or mem._0x10E043 ~= 0 then return end -- ポーズ中は状態を更新しない
		if global.pause then                            -- ポーズ解除判定
			if players[1].key.resume or players[2].key.resume then
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

		local next_joy, state_past = new_next_joy(), scr:frame_number() - input.accepted

		-- スタートボタン（リプレイモード中のみスタートボタンおしっぱでメニュー表示へ切り替え
		if (global.dummy_mode == 6 and input.long_start(state_past)) or
			(global.dummy_mode ~= 6 and input.accept("st", state_past)) then
			menu.state = menu -- メニュー表示状態へ切り替え
			cls_joy()
			return
		end

		if global.lag_frame == true then return end -- ラグ発生時は処理をしないで戻る

		global.old_both_act_neutral, global.both_act_neutral = global.both_act_neutral, true
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
			p.op.attackbits.op_cancelable = p.cancelable

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
			p.skip_frame            = global.skip_frame1 or global.skip_frame2 or p.skip_frame
			p.old.act_data          = p.act_data or get_act_data(p.old)
			p.act_data              = get_act_data(p)

			-- ガード移行可否と有利不利フレームの加減
			global.both_act_neutral = p.act_data.neutral and global.both_act_neutral
			if i == 2 then
				local p1, p2, last = p.op, p, false -- global.both_act_neutral and not global.old_both_act_neutral
				if p1.act_data.neutral and p2.act_data.neutral then
					p1.frame_gap, p2.frame_gap = 0, 0
				elseif not p1.act_data.neutral and not p2.act_data.neutral then
					p1.frame_gap, p2.frame_gap, last = 0, 0, true
				elseif not p1.act_data.neutral then
					p1.frame_gap, p2.frame_gap, last = p1.frame_gap - 1, p2.frame_gap + 1, true
				elseif not p2.act_data.neutral then
					p1.frame_gap, p2.frame_gap, last = p1.frame_gap + 1, p2.frame_gap - 1, true
				end
				if last then
					p1.last_frame_gap, p2.last_frame_gap = p1.frame_gap, p2.frame_gap
				end
			end

			-- 飛び道具の状態読取
			p.attackbits.pre_fireball = false
			p.attackbits.post_fireball = false
			p.attackbits.on_fireball = false
			p.attackbits.off_fireball = false
			for _, fb in pairs(p.fireballs) do
				if fb.proc_active then
					global.both_act_neutral = false
					fb.skip_frame = p.skip_frame -- 親オブジェクトの停止フレームを反映
					p.attackbits.pre_fireball = p.attackbits.pre_fireball or fb.on_prefb == global.frame_number
					p.attackbits.on_fireball = p.attackbits.on_fireball or fb.on_fireball == global.frame_number
					p.attackbits.off_fireball = p.attackbits.off_fireball or fb.on_fireball == -global.frame_number
				else
					p.attackbits.post_fireball = p.attackbits.post_fireball or fb.on_prefb == -global.frame_number
				end
			end

			-- フレーム表示の切替良否
			p.update_act = false
			if not ut.tstb(p.old.flag_cc, db.flag_cc.blocking | db.flag_cc.hitstun) then
				if p.spid > 0 and p.on_update_spid == global.frame_number then
					p.update_act = true
				elseif p.spid == 0 and p.on_update_act == global.frame_number then
					if p.attack_data == 0 then p.update_act = true elseif p.on_update_attack == global.frame_number then p.update_act = true end
				elseif p.act_data.neutral ~= p.old.act_data.neutral and p.on_update_act == global.frame_number then
					p.update_act = true
				end
			end
			p.move_count = p.update_act and 1 or (p.move_count + 1)
		end

		-- 1Pと2Pの状態読取 入力
		for _, p in ipairs(players) do
			p.old.input_states = p.input_states or {}
			p.input_states     = {}
			local debug        = false -- 調査時のみtrue
			local states       = dip_config.easy_super and input_state.states.easy or input_state.states.normal
			states             = debug and states[#states] or states[p.char]
			for ti, tbl in ipairs(states) do
				local old, addr = p.old.input_states[ti], tbl.addr + p.input_offset
				local on, chg_remain = mem.r8(addr - 1), mem.r8(addr)
				local on_prev = on
				local max = (old and old.on_prev == on_prev) and old.max or chg_remain
				local input_estab = old and old.input_estab or false
				local charging, reset, force_reset = false, false, false

				-- コマンド種類ごとの表示用の補正
				if tbl.type == input_state.types.drill5 then
					force_reset = on > 1 or chg_remain > 0 or max > 0
					chg_remain, on, max = 0, 0, 0
				elseif tbl.type == input_state.types.step then
					on = math.max(on - 2, 0)
					if old then reset = old.on == 2 and old.chg_remain > 0 end
				elseif tbl.type == input_state.types.faint then
					on = math.max(on - 2, 0)
					if old then
						reset = old.on == 1 and old.chg_remain > 0
						if on == 0 and chg_remain > 0 then force_reset = true end
					end
				elseif tbl.type == input_state.types.charge then
					if on == 1 and chg_remain == 0 then
						on = 3
					elseif on > 1 then
						on = on + 1
					end
					charging = on == 1
					if old then reset = old.on == #tbl.cmds and old.chg_remain > 0 end
				elseif tbl.type == input_state.types.followup then
					on = math.max(on - 1, 0)
					on = (on == 1) and 0 or on
					if old then
						reset = old.on == #tbl.cmds and old.chg_remain > 0
						if on == 0 and chg_remain > 0 then force_reset = true end
					end
				elseif tbl.type == input_state.types.shinsoku then
					on = (on <= 2) and 0 or (on - 1)
					if old then
						reset = old.on == #tbl.cmds and old.chg_remain > 0
						if on == 0 and chg_remain > 0 then force_reset = true end
					end
				elseif tbl.type == input_state.types.todome then
					on = math.max(on - 1, 0)
					on = (on <= 1) and 0 or (on - 1)
					if old then
						reset = old.on > 0 and old.chg_remain > 0
						if on == 0 and chg_remain > 0 then force_reset = true end
					end
				elseif tbl.type == input_state.types.unknown then
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
				p.update_base = true
				ut.table_add(p.bases, {
					addr     = p.base,
					count    = 1,
					act_data = p.body.act_data,
					name     = p.proc_active and ut.convert(p.body.act_data.name_plain) or "NOP",
					pos1     = p.body.pos_total,
					pos2     = p.body.pos_total,
					xmov     = 0,
				}, 16)
			else
				p.update_base = false
				base.count, base.pos2, base.xmov = base.count + 1, p.body.pos_total, base.pos2 - base.pos1
			end
		end

		-- キャラと飛び道具への当たり判定の反映
		hitboxies, ranges = {}, {} -- ソート前の判定のバッファ

		for _, p in ut.find_all(all_objects, function(_, p) return p.proc_active end) do
			-- 判定表示前の座標補正
			p.x, p.y, p.flip_x = p.pos - screen.left, screen.top - p.pos_y - p.pos_z, (p.flip_x1 ~ p.flip_x2) > 0 and 1 or -1
			p.vulnerable = (p.invincible and p.invincible > 0) or p.hurt_invincible or p.on_vulnerable ~= global.frame_number
			p.grabbable = p.grabbable | (p.grabbable1 and p.grabbable2 and hitbox_grab_bits.baigaeshi or 0)
			p.hitboxies, p.hitbox_types, p.hurt = {}, {}, {} -- 座標補正後データ格納のためバッファのクリア
			local boxkeys = { hit = {}, hurt = {} }
			p.hurt = { max_top = -0xFFFF, min_bottom = 0xFFFF, dodge = p.vulnerable and frame_attack_types.full or 0, }
			p.hit = { box_count = 0 }
			p.attackbit = 0

			for k, v, type in ut.find_all(p.attackbits, function(k) return frame_attack_types[k] end) do
				if k == "act_count" or k == "fb_effect" or k == "attack" or k == "act" then
					p.attackbit = p.attackbit | (v << type)
				elseif v == 1 or v == true then
					p.attackbit = p.attackbit | type
				end
			end
			if p.frame_gap > 0 then
				p.attackbit = p.attackbit | frame_attack_types.frame_plus
			elseif p.frame_gap < 0 then
				p.attackbit = p.attackbit | frame_attack_types.frame_minus
			end

			-- 判定が変わったらポーズさせる  1:OFF, 2:投げ, 3:攻撃, 4:変化時
			if global.pause_hitbox == 4 and p.act_data and not p.act_data.neutral and (p.chg_hitbox or p.chg_hurtbox) then global.pause = true end

			-- 当たりとやられ判定判定
			if p.delayed_clearing == global.frame_number then p.boxies = {} end
			if p.delayed_inactive == global.frame_number then
				p.grabbable, p.attack_id, p.attackbits = 0, 0, {}
				p.boxies, p.on_fireball = #p.boxies == 0 and p.boxies or {}, -1
				if p.is_fireball then p.proc_active = false end
			end
			p.hurt.dodge = frame_attack_types.full -- くらい判定なし＝全身無敵をデフォルトにする
			for _, _, box in ut.ifind_all(p.boxies, function(box)
				local type = fix_box_type(p, p.attackbit, box) -- 属性はヒット状況などで変わるので都度解決する
				if not (db.hurt_boxies[type] and p.vulnerable) then
					local src = box
					box = fix_box_scale(p, src)
					box.type = type
					box.keytxt = string.format("b%2x%2x%2x%2x%2x", box.type.no, src.top, src.bottom, src.left, src.right)
					return box
				end
			end) do
				if box.type.kind == db.box_kinds.attack or box.type.kind == db.box_kinds.parry then
					if global.pause_hitbox == 3 then global.pause = true end -- 強制ポーズ 1:OFF, 2:投げ, 3:攻撃, 4:変化時
					p.hit.box_count = p.hit.box_count + 1     -- 攻撃判定の数
				end
				if box.type.kind == db.box_kinds.attack then  -- 攻撃位置から解決した属性を付与する
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
					local hit = box.type.kind == db.box_kinds.attack or box.type.kind == db.box_kinds.parry
					table.insert(hit and boxkeys.hit or boxkeys.hurt, box.keytxt)
				end
			end
			if not p.is_fireball then p.attackbit = p.attackbit | p.hurt.dodge end -- 本体の部分無敵フラグを設定

			-- 攻撃判定がない場合は関連するフラグを無効化する
			if p.hit.box_count == 0 then p.attackbit = ut.hex_clear(p.attackbit, db.box_with_bit_types.mask) end

			if p.body.disp_hitbox and p.is_fireball ~= true then
				-- 押し合い判定（本体のみ）
				if p.push_invincible and p.push_invincible == 0 and mem._0x10B862 == 0 then
					local src = get_push_box(p)
					local box = fix_box_scale(p, src)
					box.keytxt = string.format("p%2x%2x%2x%2x%2x", box.type.no, src.top, src.bottom, src.left, src.right)
					table.insert(p.hitboxies, box)
					table.insert(hitboxies, box)
					table.insert(boxkeys.hurt, box.keytxt)
					table.insert(p.hitbox_types, box.type)
				end

				-- 投げ判定
				local last_throw_ids = {}
				for _, box in pairs(p.throw_boxies) do
					if global.pause_hitbox == 2 then global.pause = true end -- 強制ポーズ  1:OFF, 2:投げ, 3:攻撃, 4:変化時
					box.keytxt = string.format("t%2x%2x", box.type.no, box.id)
					table.insert(p.hitboxies, box)
					table.insert(hitboxies, box)
					table.insert(boxkeys.hit, box.keytxt)
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
				if not p.in_air then
					table.insert(ranges, {
						label = string.format("%sP", p.num),
						x = p.x,
						y = p.y,
						flip_x = p.cmd_side,
						within = false,
					})
				end
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

			table.sort(boxkeys.hit)
			table.sort(boxkeys.hurt)
			p.old.hitboxkey, p.hitboxkey = p.hitboxkey, table.concat(boxkeys.hit, "|")
			p.old.hurtboxkey, p.hurtboxkey = p.hurtboxkey, table.concat(boxkeys.hurt, "|")
			p.chg_hitbox = p.old.hitboxkey ~= p.hitboxkey
			p.chg_hurtbox = p.old.hurtboxkey ~= p.hurtboxkey
		end
		table.sort(hitboxies, hitboxies_order)
		table.sort(ranges, ranges_order)

		for _, p in pairs(all_objects) do
			-- キャラ、弾ともに通常動作状態ならリセットする
			if not global.both_act_neutral and global.old_both_act_neutral then p.clear_frame_data() end
			-- 全キャラ特別な動作でない場合はフレーム記録しない
			if (global.disp_normal_frames or not global.both_act_neutral) and not p.is_fireball then proc_frame(p) end
		end
		fix_max_framecount() --1Pと2Pともにフレーム数が多すぎる場合は加算をやめる

		-- キャラ間の距離
		prev_space, p_space = (p_space ~= 0) and p_space or prev_space, players[1].pos - players[2].pos

		-- プレイヤー操作事前設定（それぞれCPUか人力か入れ替えか）
		-- キー入力の取得（1P、2Pの操作を入れ替えていたりする場合もあるのでモード判定と一緒に処理する）
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
		end
		apply_1p2p_active()

		-- キーディス用の処理
		for _, p in ipairs(players) do
			local key = "" -- _1~_9 _A_B_C_D
			local ggbutton = { lever = 5, A = false, B = false, C = false, D = false, }

			-- GG風キーディスの更新
			for k, v, kk in ut.find_all(p.key.state, function(k, v) return string.gsub(k, "_", "") end) do
				if tonumber(kk) then
					if 0 < v then key, ggbutton.lever = (k == "_5" and "_N" or k) .. key, tonumber(kk) end
				elseif kk == "st" or kk == "sl" then
				else
					if 0 < v then key, ggbutton[kk] = key .. k, true end
				end
			end
			ut.table_add(p.key.gg.hist, ggbutton, 60)

			-- キーログの更新
			-- 必殺技コマンド成立を直前のキーログに反映する
			if p.on_sp_established == global.frame_number then -- or 0 < p.sp_established_duration
				local prev = p.key.log[#p.key.log]
				if prev and not prev.on_sp_established then
					if prev.frame == 1 then
						prev.spid, prev.on_sp_established = p.last_sp, global.frame_number
					else
						prev.frame = prev.frame - 1
						table.insert(p.key.log, { key = prev.key, frame = 1, spid = p.last_sp, on_sp_established = global.frame_number })
					end
				end
			end
			-- 最新のキーログを追加する
			local prev = p.key.log[#p.key.log]
			if prev and prev.key == key and not prev.on_sp_established then
				prev.frame = prev.frame < 999 and prev.frame + 1 or prev.frame
			else
				table.insert(p.key.log, { key = key, frame = 1 })
				while global.key_hists < #p.key.log do table.remove(p.key.log, 1) end
			end

			p.do_recover()
		end

		-- プレイヤー操作
		for _, p in ipairs(players) do
			p.bs_hook = nil
			if p.control == 1 or p.control == 2 then
				--前進とガード方向
				p.reset_sp_hook()

				-- レコード中、リプレイ中は行動しないためのフラグ
				local in_rec_replay = true
				if global.dummy_mode == 5 then
					in_rec_replay = false
				elseif global.dummy_mode == 6 and global.rec_main == recording.procs.play and recording.player == p.control then
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
							p.reset_cmd_hook(db.cmd_types._2D) -- スウェー待機(スウェー移動)
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
					-- コマンド入力状態を無効にしてバクステ暴発を防ぐ
					local bs_addr = dip_config.easy_super and p.char_data.easy_bs_addr or p.char_data.bs_addr
					mem.w8(p.input_offset + bs_addr, 0x00)
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
					if global.frame_number == p.on_block then
						p.next_unblock = p.on_block + global.next_block_grace
					elseif global.frame_number == p.on_hit then
						p.next_block = true
						p.next_unblock = 0
					end
					if global.frame_number == p.next_unblock then
						p.next_block = false -- ヒット時はガードに切り替え
						p.next_block_ec = 75 -- カウンター初期化
					end
					if p.next_block == false then
						-- カウンター消費しきったらガードするように切り替える
						p.next_block_ec = p.next_block_ec and (p.next_block_ec - 1) or 0
						if p.next_block_ec == 0 then p.next_block = true end
					end
				end

				--挑発中は前進
				if p.fwd_prov and ut.tstb(p.op.flag_cc, db.flag_cc._19) then p.add_cmd_hook(db.cmd_types.front) end

				-- ガードリバーサル
				if p.gd_rvs_enabled ~= true and p.dummy_wakeup == wakeup_type.rvs and p.dummy_rvs and p.on_block == global.frame_number then
					p.rvs_count = (p.rvs_count < 1) and 1 or p.rvs_count + 1
					if global.dummy_rvs_cnt <= p.rvs_count and p.dummy_rvs then p.gd_rvs_enabled, p.rvs_count = true, -1 end
					-- ut.printf("%s rvs %s %s", p.num, p.rvs_count, p.gd_rvs_enabled)
				elseif p.gd_rvs_enabled and p.state ~= 2 then
					p.gd_rvs_enabled = false
				end -- ガード状態が解除されたらリバサ解除

				-- BS
				if p.gd_bs_enabled ~= true and p.dummy_gd == dummy_gd_type.bs and p.dummy_bs and p.on_block == global.frame_number then
					p.bs_count = (p.bs_count < 1) and 1 or p.bs_count + 1
					if global.dummy_bs_cnt <= p.bs_count and p.dummy_bs then p.gd_bs_enabled, p.bs_count = true, -1 end
					-- ut.printf("%s bs %s %s", p.num, p.bs_count, p.gd_bs_enabled)
				elseif p.gd_bs_enabled and p.state ~= 2 then
					p.gd_bs_enabled = false
				end -- ガード状態が解除されたらBS解除

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
					if global.auto_input.otg_throw and p.char_data.otg_throw then
						p.reset_sp_hook(p.char_data.otg_throw) -- 自動ダウン投げ
					end
					if global.auto_input.otg_attack and p.char_data.otg_stomp then
						p.reset_sp_hook(p.char_data.otg_stomp) -- 自動ダウン攻撃
					end
				end

				-- 自動投げ追撃
				if global.auto_input.combo_throw then
					if p.char == 3 and p.act == 0x70 then
						p.reset_cmd_hook(db.cmd_types._2C) -- ジョー
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
				if p.gd_bs_enabled then p.reset_sp_hook(p.dummy_bs) end
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
			if p.force_y_pos > 1 then mem.w16i(p.addr.pos_y, menu.labels.force_y_pos[p.force_y_pos]) end
		end

		-- X座標同期とY座標をだいぶ下に
		if global.sync_pos_x ~= 1 then
			local from = global.sync_pos_x - 1
			local to   = 3 - from
			mem.w16i(players[to].addr.pos, players[from].pos)
			mem.w16i(players[to].addr.pos_y, players[from].pos_y - 124)
		end

		-- コンボ表示と状態表示データ
		for _, p in ipairs(players) do
			local op, col1, col2, col3, label = p.op, {}, {}, {}, {}
			for _, xp in ipairs(p.objects) do
				if xp.proc_active then
					table.insert(label, string.format("Damage %3s/%1s  Stun %2s/%2s Fra.", xp.damage or 0, xp.chip or 0, xp.stun or 0, xp.stun_timer or 0))
					table.insert(label, string.format("HitStop %2s/%2s HitStun %2s/%2s", xp.hitstop or 0, xp.blockstop or 0, xp.hitstun or 0, xp.blockstun or 0))
					table.insert(label, string.format("%2s", db.hit_effects.name(xp.effect)))
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
					for _, box, blockables in ut.ifind_all(xp.hitboxies, function(box) return box.blockables end) do
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
				local stun, timer                       = math.max(op.hit_stun - op.combo_start_stun), math.max(op.hit_stun_timer - op.combo_start_stun_timer, 0)
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
			if p.disp_damage then
				ut.table_add_all(col1, { -- コンボ表示
					"Scaling",
					"Damage",
					"Combo",
					"Stun",
					"Timer",
					"Power",
				})
			end
			p.state_line1, p.combo_col1, p.combo_col2, p.combo_col3 = label, col1, col2, col3
		end

		-- 状態表示データ
		for _, p in ipairs(players) do
			if p.disp_state == 2 or p.disp_state == 3 then -- 1:OFF 2:ON 3:ON:小表示 4:ON:大表示 5:ON:フラグ表示
				local label1 = {}
				table.insert(label1, string.format("%s %02d %03d %03d",
					p.state, p.throwing and p.throwing.threshold or 0, p.throwing and p.throwing.timer or 0, p.throw_timer or 0))
				local diff_pos_y = p.pos_y + p.pos_frc_y - (p.old.pos_y and (p.old.pos_y + p.old.pos_frc_y) or 0)
				table.insert(label1, string.format("%0.03f %0.03f", diff_pos_y, p.pos_y + p.pos_frc_y))
				table.insert(label1, string.format("%02x %02x %02x", p.spid or 0, p.attack or 0, p.attack_id or 0))
				table.insert(label1, string.format("%03x %02x %02x %s%s%s", p.act, p.act_count, p.act_frame, p.update_base and "u" or "k", p.update_act and "U" or "K", p.act_data.neutral and "N" or "A"))
				table.insert(label1, string.format("%02x %02x %02x", p.hurt_state, p.sway_status, p.additional))
				p.state_line2 = label1
			end
			if p.disp_state == 2 or p.disp_state == 5 then -- 1:OFF 2:ON 3:ON:小表示 4:ON:大表示 5:ON:フラグ表示
				local label2 = {}
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
				p.state_line3 = label2
			end
		end

		-- 後処理
		for _, p in ipairs(players) do
			p.skip_frame = false -- 初期化
			-- ヒット時にポーズさせる 強制ポーズ処理
			-- 1:OFF, 2:ON, 3:ON:やられのみ 4:ON:投げやられのみ 5:ON:打撃やられのみ 6:ON:ガードのみ
			if (global.pause_hit == 2 and (p.on_hit == global.frame_number or p.on_block == global.frame_number)) or
				(global.pause_hit == 3 and p.on_hit == global.frame_number) or
				(global.pause_hit == 4 and p.on_hit == global.frame_number and p.state == 3) or
				(global.pause_hit == 5 and p.on_hit == global.frame_number and p.state == 1) or
				(global.pause_hit == 6 and p.on_block == global.frame_number) then
				global.pause = true
			end
		end
		set_freeze(not global.pause)
	end

	-- メイン処理
	menu.tra_main.draw = function()
		if not in_match then return end

		-- 順番に判定表示（キャラ、飛び道具）
		for _, range in ipairs(ranges) do draw_range(range) end -- 座標と範囲
		for _, box in ipairs(hitboxies) do draw_hitbox(box) end -- 各種判定

		-- 技画像保存 1:OFF 2:ON:新規 3:ON:上書き
		local save = global.save_snapshot > 1
		for _, p in ut.ifind_all(players, function(p)
			if save and p.act_data and not p.act_data.neutral and (p.chg_hitbox or p.chg_hurtbox) then
				return p.act_data
			end
			return nil
		end) do
			-- 画像保存先のディレクトリ作成
			local frame_group = p.frame_groups[#p.frame_groups]
			local last_frame = frame_group[#frame_group]
			local act = last_frame.act
			local char_name = p.char_data.name_en
			local name, sub_name = last_frame.name_plain, "_"
			local dir_name = base_path() .. "/capture"
			ut.mkdir(to_sjis(dir_name))
			dir_name = dir_name .. "/" .. char_name
			ut.mkdir(to_sjis(dir_name))
			if p.sliding then sub_name = "_SLIDE_" elseif p.in_bs then sub_name = "_BS_" end
			name = string.format("%s%s%04x_%s_%03d", char_name, sub_name, act, name, p.move_count)
			dir_name = dir_name .. string.format("/%04x", act)
			ut.mkdir(to_sjis(dir_name))

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
				print(to_sjis("save " .. filename))
			end
		end

		-- コマンド入力表示
		for i, p in ipairs(players) do
			-- コマンド入力表示 1:OFF 2:ON 3:ログのみ 4:キーディスのみ
			if p.disp_command == 2 or p.disp_command == 3 then
				for k, log in ipairs(p.key.log) do draw_cmd(i, k, log.frame, log.key, log.spid) end
			end
		end

		-- ベースアドレス表示 --"OFF", "本体", "弾1", "弾2", "弾3"
		for base, p in pairs(all_objects) do
			if (p.body.disp_base - 2) * 0x200 + p.body.addr.base == base then
				draw_base(p.body.num, p.bases)
			end
		end

		local disp_damage = 0
		if players[1].disp_damage and players[2].disp_damage then -- 両方表示
			disp_damage = 3
		elseif players[1].disp_damage then                  -- 1Pだけ表示
			disp_damage = 1
		elseif players[2].disp_damage then                  -- 2Pだけ表示
			disp_damage = 2
		end
		for i, p in ipairs(players) do
			local p1 = i == 1
			-- ダメージとコンボ表示
			if p.combo_col1 and #p.combo_col1 > 0 and disp_damage ~= 0 then
				if disp_damage == 2 or (p1 and disp_damage ~= 2) then
					local col = 0x0C404040 -- to 9C
					for wi = 20, 15, -0.4 do
						local w = get_string_width("9") * wi
						col = col | 0x0C000000
						local x1, x2 = scr.width // 2 - w, scr.width // 2 + w
						if disp_damage == 1 then
							x2 = scr.width // 2 + get_string_width("9") * 5
						elseif disp_damage == 2 then
							x1 = scr.width // 2 - get_string_width("9") * 5
						end
						scr:draw_box(x1, 40, x2, 40 + get_line_height(#p.combo_col1), col, col) -- 四角枠
					end
					draw_text("center", 40, table.concat(p.combo_col1, "\n"))
				end
				draw_text(scr.width // 2 + get_string_width("9") * (p1 and -18 or 4), 40, table.concat(p.combo_col2, "\n"))
				draw_text(scr.width // 2 + get_string_width("9") * (p1 and -9 or 13), 40, table.concat(p.combo_col3, "\n"))
			end
			-- 状態 大表示 1:OFF 2:ON 3:ON:小表示 4:ON:大表示 5:ON:フラグ表示
			if p.state_line1 and #p.state_line1 > 0 and p.disp_state == 2 or p.disp_state == 4 then
				local col = 0x9C404040
				local w1 = get_string_width("9") * (p1 and 42 or -44 + 25)
				local w2 = w1 - get_string_width("9") * 23
				scr:draw_box(scr.width // 2 - w1, 40, scr.width // 2 - w2, 40 + get_line_height(#p.state_line1), col, col) -- 四角枠
				draw_text(scr.width // 2 - w1, 40, table.concat(p.state_line1, "\n"))
			end
		end
		for i, p in ipairs(players) do
			local p1 = i == 1
			-- 状態 小表示 1:OFF 2:ON 3:ON:小表示 4:ON:大表示 5:ON:フラグ表示
			if p.disp_state == 2 or p.disp_state == 3 then
				local label1 = p.state_line2 or {}
				scr:draw_box(p1 and 0 or 277, 0, p1 and 40 or 316, get_line_height(#label1), 0x80404040, 0x80404040)
				draw_text(p1 and 4 or 278, 0, table.concat(label1, "\n"))
			end
			if p.disp_state == 2 or p.disp_state == 5 then
				local label2 = p.state_line3 or {}
				draw_text(40, 50 + get_line_height(p1 and 0 or (#label2 + 0.5)), table.concat(label2, "\n"))
			end

			-- コマンド入力状態表示
			if global.disp_input - 1 == i then
				for ti, state in ipairs(p.input_states) do
					local x, y = 147, 25 + ti * 5
					local x1, x2, y2, cmdx, cmdy = x + 15, x - 8, y + 4, x - 50, y - 2
					draw_text_with_shadow(x1, cmdy, state.tbl.name,
						state.input_estab == true and input_state.col.orange2 or input_state.col.white)
					if state.on > 0 and state.chg_remain > 0 then
						local col, col2 = input_state.col.yellow, input_state.col.yellow2
						if state.charging == true then col, col2 = input_state.col.green, input_state.col.green2 end
						scr:draw_box(x2 + state.max * 2, y, x2, y2, col2, 0)
						scr:draw_box(x2 + state.chg_remain * 2, y, x2, y2, 0, col)
					end
					for ci, c in ipairs(state.tbl.lr_cmds[p.cmd_side]) do
						if c ~= "" then
							cmdx = cmdx + math.max(5.5,
								draw_text_with_shadow(cmdx, cmdy, c,
									state.input_estab == true and input_state.col.orange or
									state.on > ci and input_state.col.red or
									(ci == 1 and state.on >= ci) and input_state.col.red or nil))
						end
					end
					draw_rtext_with_shadow(x + 1, y, state.chg_remain)
					draw_text_with_shadow(x + 4, y, "/")
					draw_text_with_shadow(x + 7, y, state.max)
					if state.debug then
						draw_rtext_with_shadow(x + 25, y, state.on)
						draw_rtext_with_shadow(x + 40, y, state.on_prev)
					end
				end
			end

			-- BS状態表示
			-- ガードリバーサル状態表示
			if global.disp_bg then
				local bs_label = {}
				if p.dummy_gd == dummy_gd_type.bs and global.dummy_bs_cnt > 1 then
					table.insert(bs_label, string.format("%02d回ガードでBS",
						p.gd_bs_enabled and global.dummy_bs_cnt > 1 and 0 or (global.dummy_bs_cnt - math.max(p.bs_count, 0))))
				end
				if p.dummy_wakeup == wakeup_type.rvs and global.dummy_rvs_cnt > 1 then
					table.insert(bs_label, string.format("%02d回ガードでRev.",
						p.gd_rvs_enabled and global.dummy_rvs_cnt > 1 and 0 or (global.dummy_rvs_cnt - math.max(p.rvs_count, 0))))
				end
				if #bs_label > 0 then
					draw_text_with_shadow(p1 and 48 or 230, 40, table.concat(bs_label, "\n"), p.on_block <= global.frame_number and 0xFFFFFFFF or 0xFF00FFFF)
				end
			end

			-- 気絶表示
			if p.disp_stun then
				draw_text_with_shadow(p1 and 112 or 184, 19.7, string.format("%3s/%3s", p.life, 0xC0))
				scr:draw_box(p1 and (138 - p.stun_limit) or 180, 29, p1 and 140 or (182 + p.stun_limit), 34, 0, 0xDDC0C0C0) -- 枠
				scr:draw_box(p1 and (139 - p.stun_limit) or 181, 30, p1 and 139 or (181 + p.stun_limit), 33, 0, 0xDD000000) -- 黒背景
				scr:draw_box(p1 and (139 - p.hit_stun) or 181, 30, p1 and 139 or (181 + p.hit_stun), 33, 0, 0xDDFF0000) -- 気絶値
				draw_text_with_shadow(p1 and 112 or 184, 28, string.format("%3s/%3s", p.hit_stun, p.stun_limit))
				scr:draw_box(p1 and (138 - 90) or 180, 35, p1 and 140 or (182 + 90), 40, 0, 0xDDC0C0C0)                 -- 枠
				scr:draw_box(p1 and (139 - 90) or 181, 36, p1 and 139 or (181 + 90), 39, 0, 0xDD000000)                 -- 黒背景
				scr:draw_box(p1 and (139 - p.hit_stun_timer) or 181, 36, p1 and 139 or (181 + p.hit_stun_timer), 39, 0, 0xDDFFFF00) -- 気絶値
				draw_text_with_shadow(p1 and 112 or 184, 34, string.format("%3s", p.hit_stun_timer))
			end
		end

		-- フレーム表示
		local draw_frame_labels = {}
		for i, p in ipairs(players) do
			local p1 = i == 1
			if p.disp_frame > 1 then -- フレームメーター 1:OFF 2:ON
				draw_frames(p.frame_groups, p1 and 40 or 165, 63, 120)
			end
			if global.disp_frame then -- スト6風フレームメーター 1:OFF 2:ON
				local startup, total, draw_label = frame_meter.draw(p, 160 + get_line_height(p1 and 0 or 1.5))
				table.insert(draw_frame_labels, { total = total, func = draw_label })
				-- 確定反撃の表示
				draw_text_with_shadow(p1 and 112 or 184, get_line_height(1.3), "PUNISH", p.on_punish <= global.frame_number and 0xFF808080 or 0xFF00FFFF)
			end
			if i == 2 then
				for j, draw in ipairs(draw_frame_labels) do draw.func(draw_frame_labels[3 - j].total) end
			end
		end

		-- キャラの向きとキャラ間の距離表示
		-- 向き・距離・位置表示 1;OFF 2:ON 3:向き・距離のみ 4:位置のみ
		if global.disp_pos > 1 then
			for i, p in ipairs(players) do
				local flip   = p.flip_x == 1 and ">" or "<" -- 見た目と判定の向き
				local side   = p.block_side == 1 and ">" or "<" -- ガード方向や内部の向き 1:右向き -1:左向き
				local i_side = p.cmd_side == 1 and ">" or "<" -- コマンド入力の向き
				p.pos_hist   = p.pos_hist or ut.new_filled_table(2, { x = format_num(0), y = format_num(0) })
				table.insert(p.pos_hist, { x = format_num(p.pos + p.pos_frc), y = format_num(p.pos_y + p.pos_frc_y) })
				while 3 < #p.pos_hist do table.remove(p.pos_hist, 1) end
				local y1, y2, y3 = p.pos_hist[1].y, p.pos_hist[2].y, p.pos_hist[3].y
				local x1, x2, x3 = p.pos_hist[1].x, p.pos_hist[2].x, p.pos_hist[3].x
				if y3 ~= y2 or not p.last_posy_txt then
					p.last_posy_txt = string.format("Y:%s>%s>%s", y1, y2, y3)
				end
				if x3 ~= x2 or not p.last_posx_txt then
					p.last_posx_txt = string.format("X:%s>%s>%s", x1, x2, x3)
				end
				if i == 1 then
					draw_text("left", 216 - get_line_height(), string.format("%s", p.last_posx_txt))
					draw_text("left", 216, string.format("%s Disp.%s Block.%s Input.%s", p.last_posy_txt, flip, side, i_side))
				else
					draw_text("right", 216 - get_line_height(), string.format("%s", p.last_posx_txt))
					draw_text("right", 216, string.format("Input.%s Block.%s Disp.%s %s", i_side, side, flip, p.last_posy_txt))
				end
			end
			draw_text("center", 216, string.format("%3d", math.abs(p_space)))
		end

		-- GG風コマンド入力表示
		for _, p in ipairs(players) do
			-- コマンド入力表示 1:OFF 2:ON 3:ログのみ 4:キーディスのみ
			if p.disp_command == 2 or p.disp_command == 4 then
				local xoffset, yoffset = p.key.gg.xoffset, p.key.gg.yoffset
				local oct_vt, key_xy = p.key.gg.oct_vt, p.key.gg.key_xy
				local tracks, max_track = {}, 6 -- 軌跡をつくる 軌跡は6個まで
				scr:draw_box(xoffset - 13, yoffset - 13, xoffset + 35, yoffset + 13, 0x80404040, 0x80404040)
				for ni = 1, 8 do    -- 八角形描画
					local prev = ni > 1 and ni - 1 or 8
					local xy1, xy2 = oct_vt[ni], oct_vt[prev]
					scr:draw_line(xy1.x, xy1.y, xy2.x, xy2.y, 0xDDCCCCCC)
					scr:draw_line(xy1.x1, xy1.y1, xy2.x1, xy2.y1, 0xDDCCCCCC)
					scr:draw_line(xy1.x2, xy1.y2, xy2.x2, xy2.y2, 0xDDCCCCCC)
					scr:draw_line(xy1.x3, xy1.y3, xy2.x3, xy2.y3, 0xDDCCCCCC)
					scr:draw_line(xy1.x4, xy1.y4, xy2.x4, xy2.y4, 0xDDCCCCCC)
				end
				for j = #p.key.gg.hist, 2, -1 do -- 軌跡採取
					local k = j - 1
					local xy1, xy2 = key_xy[p.key.gg.hist[j].lever], key_xy[p.key.gg.hist[k].lever]
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
				local ggbutton = p.key.gg.hist[#p.key.gg.hist]
				if ggbutton then -- ボタン描画
					for _, ctl in ipairs({
						{ key = "",  btn = "_)", x = key_xy[ggbutton.lever].xt, y = key_xy[ggbutton.lever].yt, col = 0xFFCC0000 },
						{ key = "A", btn = "_A", x = key_xy[5].x + 11,          y = key_xy[5].y + 0,           col = 0xFFFFFFFF },
						{ key = "B", btn = "_B", x = key_xy[5].x + 16,          y = key_xy[5].y - 3,           col = 0xFFFFFFFF },
						{ key = "C", btn = "_C", x = key_xy[5].x + 21,          y = key_xy[5].y - 3,           col = 0xFFFFFFFF },
						{ key = "D", btn = "_D", x = key_xy[5].x + 26,          y = key_xy[5].y - 2,           col = 0xFFFFFFFF },
					}) do
						local xx, yy, btn, on = ctl.x, ctl.y, ut.convert(ctl.btn), ctl.key == "" or ggbutton[ctl.key]
						draw_text(xx, yy, ut.convert("_("), on and ctl.col or 0xDDCCCCCC)
						draw_text(xx, yy, btn, on and btn_col[btn] or 0xDD444444)
					end
				end
			end
		end

		-- レコーディング状態表示
		if global.disp_replay and recording.info and (global.dummy_mode == 5 or global.dummy_mode == 6) then
			local time = global.rec_main == recording.procs.play and
				ut.frame_to_time(#recording.active_slot.store - recording.play_count) or ut.frame_to_time(3600 - #recording.active_slot.store)
			scr:draw_box(235, 200, 315, 224, 0xBB404040, 0xBB404040)
			for i, info in ipairs(recording.info) do
				draw_text(239, 204 + get_line_height(i - 1), string.format(info.label, time), info.col)
			end
		end
	end

	-- メニュー表示
	menu.setup_char = function()
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
			p.gd_bs_enabled  = false
			p.rvs_count      = -1
		end
	end
	menu.to_main = function(on_a1, cancel, do_init)
		local col, row, g  = menu.training.pos.col, menu.training.pos.row, global
		local p1, p2       = players[1], players[2]

		g.dummy_mode       = col[1] -- ダミーモード
		-- ダミー設定
		p1.dummy_act       = col[3] -- 1P アクション
		p2.dummy_act       = col[4] -- 2P アクション
		p1.dummy_gd        = col[5] -- 1P ガード
		p2.dummy_gd        = col[6] -- 2P ガード
		g.next_block_grace = col[7] - 1 -- 1ガード持続フレーム数
		g.dummy_bs_cnt     = col[8] -- ブレイクショット設定
		p1.dummy_wakeup    = col[9] -- 1P やられ時行動
		p2.dummy_wakeup    = col[10] -- 2P やられ時行動
		g.dummy_rvs_cnt    = col[11] -- ガードリバーサル設定
		p2.no_hit_limit    = col[12] - 1 -- 1P 強制空振り
		p1.no_hit_limit    = col[13] - 1 -- 2P 強制空振り
		p1.fwd_prov        = col[14] == 2 -- 1P 挑発で前進
		p2.fwd_prov        = col[15] == 2 -- 2P 挑発で前進
		p1.force_y_pos     = col[16] -- 1P Y座標強制
		p2.force_y_pos     = col[17] -- 2P Y座標強制
		g.sync_pos_x       = col[18] -- X座標同期
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

		g.old_dummy_mode = g.dummy_mode

		if g.dummy_mode == 5 then -- レコード
			g.dummy_mode = 1 -- 設定でレコーディングに入らずに抜けたとき用にモードを1に戻しておく
			if not cancel and row == 1 then
				menu.current = menu.recording
				return
			end
		elseif g.dummy_mode == 6 then         -- リプレイ
			local rcol = menu.replay.pos.col
			g.dummy_mode = 1                  -- 設定でリプレイに入らずに抜けたとき用にモードを1に戻しておく
			rcol[11] = recording.do_repeat and 2 or 1 -- 繰り返し
			rcol[12] = recording.repeat_interval + 1 -- 繰り返し間隔
			rcol[13] = g.await_neutral and 2 or 1 -- 繰り返し開始条件
			rcol[14] = g.replay_fix_pos       -- 開始間合い固定
			rcol[15] = g.replay_reset         -- 状態リセット
			rcol[16] = g.disp_replay and 2 or 1 -- ガイド表示
			rcol[17] = g.replay_stop_on_dmg and 2 or 1 -- ダメージでリプレイ中止
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
	menu.to_main_cancel = function() menu.to_main(nil, true, false) end
	for i = 1, 0xC0 - 1 do table.insert(menu.labels.life_range, i) end
	for i = 1, 0x3C - 1 do table.insert(menu.labels.pow_range, i) end

	menu.rec_to_tra               = function() menu.current = menu.training end
	menu.exit_and_rec             = function(slot_no)
		local g               = global
		g.dummy_mode          = 5
		g.rec_main            = recording.procs.await_no_input
		input.accepted        = scr:frame_number()
		recording.temp_player = players[1].reg_pcnt ~= 0 and 1 or 2
		recording.last_slot   = slot_no
		recording.active_slot = recording.slot[slot_no]
		menu.current          = menu.main
		menu.exit()
	end
	menu.exit_and_play_common     = function()
		local col, g = menu.replay.pos.col, global
		recording.live_slots = recording.live_slots or {}
		for i = 1, #recording.slot do
			recording.live_slots[i] = (col[i + 1] == 2)
		end
		recording.do_repeat       = col[11] == 2 -- 繰り返し
		recording.repeat_interval = col[12] - 1 -- 繰り返し間隔
		g.await_neutral           = col[13] == 2 -- 繰り返し開始条件
		g.replay_fix_pos          = col[14] -- 開始間合い固定
		g.replay_reset            = col[15] -- 状態リセット
		g.disp_replay             = col[16] == 2 -- ガイド表示
		g.replay_stop_on_dmg      = col[17] == 2 -- ダメージでリプレイ中止
		g.repeat_interval         = recording.repeat_interval
	end
	menu.exit_and_rec_pos         = function()
		local g = global
		g.dummy_mode = 5 -- レコードモードにする
		g.rec_main = recording.procs.fixpos
		input.accepted = scr:frame_number()
		recording.temp_player = players[1].reg_pcnt ~= 0 and 1 or 2
		menu.exit_and_play_common()
		menu.current = menu.main
		menu.exit()
	end
	menu.exit_and_play            = function()
		local col, g = menu.replay.pos.col, global
		if menu.replay.pos.row == 14 and col[14] == 2 then -- 開始間合い固定 / 記憶
			menu.exit_and_rec_pos()
			return
		end
		g.dummy_mode = 6 -- リプレイモードにする
		g.rec_main = recording.procs.await_play
		input.accepted = scr:frame_number()
		menu.exit_and_play_common()
		menu.current = menu.main
		menu.exit()
	end
	menu.exit_and_play_cancel     = function()
		local g = global
		g.dummy_mode = 6 -- リプレイモードにする
		g.rec_main = recording.procs.await_play
		input.accepted = scr:frame_number()
		menu.exit_and_play_common()
		menu.to_tra()
	end
	menu.init_config              = function()
		---@diagnostic disable-next-line: undefined-field
		local col, p, g = menu.training.pos.col, players, global
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
	menu.init_bar_config          = function()
		---@diagnostic disable-next-line: undefined-field
		local col, p, g = menu.bar.pos.col, players, global
		--   1                                                        1
		col[2] = p[1].red                      -- 1P 体力ゲージ量
		col[3] = p[2].red                      -- 2P 体力ゲージ量
		col[4] = p[1].max                      -- 1P POWゲージ量
		col[5] = p[2].max                      -- 2P POWゲージ量
		col[6] = dip_config.infinity_life and 2 or 1 -- 体力ゲージモード
		col[7] = g.pow_mode                    -- POWゲージモード
	end
	menu.init_disp_config         = function()
		---@diagnostic disable-next-line: undefined-field
		local col, p, g, o, c = menu.disp.pos.col, players, global, hide_options, menu.config
		-- 01 表示設定 label
		col[2] = c.disp_box_range1p                        -- 02 1P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
		col[3] = c.disp_box_range2p                        -- 03 2P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
		col[4] = p[1].disp_command                         -- 04 1P 入力表示  1:OFF 2:ON 3:ログのみ 4:キーディスのみ
		col[5] = p[2].disp_command                         -- 05 2P 入力表示  1:OFF 2:ON 3:ログのみ 4:キーディスのみ
		col[6] = c.disp_stun                               -- 06 気絶メーター表示  1:OFF 2:ON 3:1P 4:2P
		col[7] = c.disp_damage                             -- 07 ダメージ表示  1:OFF 2:ON 3:1P 4:2P
		-- 08 フレーム表示 label
		col[9] = g.disp_input                              -- 09 コマンド入力状態表示  1:OFF 2:1P 3:2P
		col[10] = c.disp_frame                             -- 10 フレームメーター表示  1:OFF 2:大メーター 3:小メーター 4:1P 小メーターのみ 5:2P 小メーターのみ
		col[11] = c.split_frame                            -- 11 フレームメーター設定  1:ON 2:ON:判定の形毎 3:ON:攻撃判定の形毎 4:ON:くらい判定の形毎
		col[12] = c.disp_fb_frame and 2 or 1               -- 12 フレームメーター弾表示  1:OFF 2:ON
		col[13] = g.disp_normal_frames and 2 or 1          -- 13 通常動作フレーム非表示  1:OFF 2:ON
		-- 14 状態表示 label
		col[15] = p[1].disp_state                          -- 15 1P 状態表示  1:OFF 2: ON, ON:小表示, ON:大表示, ON:フラグ表示
		col[16] = p[2].disp_state                          -- 16 2P 状態表示  1:OFF 2:ON, ON:小表示, ON:大表示, ON:フラグ表示
		col[17] = p[1].disp_base                           -- 17 1P 処理アドレス表示  1:OFF 2:本体 3:弾1 4:弾2 5:弾3
		col[18] = p[2].disp_base                           -- 18 2P 処理アドレス表示  1:OFF 2:本体 3:弾1 4:弾2 5:弾3
		col[19] = g.disp_pos                               -- 19 向き・距離・位置表示 1;OFF 2:ON 3:向き・距離のみ 4:位置のみ
		-- 20 撮影用 label
		col[21] = c.disp_char                              -- 21 キャラ表示 1:OFF 2:ON 3:1P 4:2P
		col[22] = c.disp_phantasm                          -- 22 残像表示 1:OFF 2:ON 3:1P 4:2P
		col[23] = c.disp_effect                            -- 23 エフェクト表示 1:OFF 2:ON 3:1P 4:2P
		col[24] = ut.tstb(g.hide, o.p_chan) and 1 or 2     -- 24 Pちゃん表示 1:OFF 2:ON
		col[25] = ut.tstb(g.hide, o.effect) and 1 or 2     -- 25 共通エフェクト表示 1:OFF 2:ON
		-- 26 撮影用(有効化時はリスタートします)
		col[27] = ut.tstb(g.hide, o.meters, true) and 1 or 2 -- 体力,POWゲージ表示 1:OFF 2:ON
		col[28] = ut.tstb(g.hide, o.background, true) and 1 or 2 -- 背景表示 1:OFF 2:ON
		col[29] = ut.tstb(g.hide, o.shadow1, true) and 2 or
			ut.tstb(g.hide, o.shadow2, true) and 3 or 1    -- 影表示  1:ON 2:OFF 3:ON:反射→影
		col[30] = global.fix_scr_top                       -- 画面カメラ位置
	end
	menu.init_ex_config           = function()
		---@diagnostic disable-next-line: undefined-field
		local col, p, g = menu.extra.pos.col, players, global
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
		col[5] = g.pause_hit       -- ヒット時にポーズ
		col[6] = g.pause_hitbox    -- 判定発生時にポーズ
		col[7] = g.save_snapshot   -- 技画像保存
		col[8] = g.damaged_move    -- ヒット効果確認用
		col[9] = g.all_bs and 2 or 1 -- 全必殺技BS
		col[10] = g.mvs_billy and 2 or 1 -- ビリーMVS化
	end
	menu.init_auto_config         = function()
		local col, g = menu.auto.pos.col, global
		-- -- 自動入力設定
		col[2] = g.auto_input.otg_throw and 2 or 1 -- ダウン投げ
		col[3] = g.auto_input.otg_attack and 2 or 1 -- ダウン攻撃
		col[4] = g.auto_input.combo_throw and 2 or 1 -- 通常投げの派生技
		col[5] = g.auto_input.rave                -- デッドリーレイブ
		col[6] = g.auto_input.desire              -- アンリミテッドデザイア
		col[7] = g.auto_input.drill               -- ドリル
		col[8] = g.auto_input.pairon              -- 超白龍
		col[9] = g.auto_input.real_counter        -- M.リアルカウンター
		col[10] = g.auto_input.auto_3ecst and 2 or 1 -- M.トリプルエクスタシー
		col[11] = g.auto_input.taneuma and 2 or 1 -- 炎の種馬
		col[12] = g.auto_input.katsu_ca and 2 or 1 -- 喝CA
		col[13] = g.auto_input.sikkyaku_ca and 2 or 1 -- 飛燕失脚CA
		-- -- 入力設定
		col[15] = g.auto_input.esaka_check        -- 詠酒距離チェック
		col[16] = g.auto_input.fast_kadenzer and 2 or 1 -- 必勝！逆襲拳
		col[17] = g.auto_input.kara_ca and 2 or 1 -- 空振りCA
	end
	menu.to_tra                   = function() menu.current = menu.training end
	menu.to_bar                   = function() menu.current = menu.bar end
	menu.to_disp                  = function() menu.current = menu.disp end
	menu.to_ex                    = function() menu.current = menu.extra end
	menu.to_auto                  = function() menu.current = menu.auto end
	menu.to_col                   = function()
		for i = 2, #menu.color.pos.col do menu.color.pos.col[i] = db.box_type_list[i - 1].enabled and 2 or 1 end
		menu.current = menu.color
	end
	menu.exit                     = function()
		-- Bボタンでトレーニングモードへ切り替え
		menu.state = menu.tra_main
		cls_joy()
		cls_ps()
	end
	menu.on_player_select         = function(p_no)
		--main_menu.pos.row = 1
		cls_ps()
		goto_player_select(p_no)
		--cls_joy()
		--cls_ps()
		-- 初期化
		menu.to_main(nil, false, true)
		-- メニューを抜ける
		menu.state = menu.tra_main
		menu.prev_state = nil
		menu.reset_pos = true
		-- レコード＆リプレイ用の初期化
		if global.old_dummy_mode == 5 then
			-- レコード
			menu.exit_and_rec(recording.last_slot or 1)
		elseif global.old_dummy_mode == 6 then
			-- リプレイ
			menu.exit_and_play()
		end
	end
	menu.on_restart_fight_a      = function()
		---@diagnostic disable-next-line: undefined-field
		local col, g, o = menu.main.pos.col, global, hide_options
		restart_fight({
			next_p1    = col[9],                                   -- 1P セレクト
			next_p2    = col[10],                                  -- 2P セレクト
			next_p1col = col[11] - 1,                              -- 1P カラー
			next_p2col = col[12] - 1,                              -- 2P カラー
			next_stage = menu.stage_list[col[13]],                 -- ステージセレクト
			next_bgm   = menu.bgms[col[14]].id,                    -- BGMセレクト
		})
		mod.camerawork(global.fix_scr_top == 1)

		cls_joy()
		cls_ps()
		menu.to_main(nil, false, true) -- 初期化
		menu.state = menu.tra_main -- メニューを抜ける
		menu.reset_pos = true
		if g.old_dummy_mode == 5 then
			menu.exit_and_rec(recording.last_slot or 1) -- レコード＆リプレイ用の初期化 レコード
		elseif g.old_dummy_mode == 6 then
			menu.exit_and_play()               -- レコード＆リプレイ用の初期化 リプレイ
		end
	end
	menu.main                     = menu.create("main", {
		{ "ダミー設定" },
		{ "ゲージ設定" },
		{ "表示設定" },
		{ "特殊設定" },
		{ "自動入力設定" },
		{ "判定個別設定" },
		{ "プレイヤーセレクト画面" },
		{ title = true, "クイックセレクト(選択時はリスタートします)" },
		{ "1P セレクト", menu.labels.chars },
		{ "2P セレクト", menu.labels.chars },
		{ "1P カラー", { "A", "D" } },
		{ "2P カラー", { "A", "D" } },
		{ "ステージセレクト", menu.labels.stage_list },
		{ "BGMセレクト", menu.labels.bgms },
	}, {
		menu.to_tra,     -- ダミー設定
		menu.to_bar,     -- ゲージ設定
		menu.to_disp,    -- 表示設定
		menu.to_ex,      -- 特殊設定
		menu.to_auto,    -- 自動入力設定
		menu.to_col,     -- 判定個別設定
		menu.on_player_select, -- プレイヤーセレクト画面
		function() end,  -- クイックセレクト
		menu.on_restart_fight_a, -- 1P セレクト
		menu.on_restart_fight_a, -- 2P セレクト
		menu.on_restart_fight_a, -- 1P カラー
		menu.on_restart_fight_a, -- 2P カラー
		menu.on_restart_fight_a, -- ステージセレクト
		menu.on_restart_fight_a, -- BGMセレクト
	}, ut.new_filled_table(14, menu.exit))

	menu.current                  = menu.main -- デフォルト設定
	menu.update_pos               = function()
		---@diagnostic disable-next-line: undefined-field
		local col = menu.main.pos.col

		-- メニューの更新
		col[9] = math.min(math.max(mem.r8(0x107BA5), 1), #menu.labels.chars)
		col[10] = math.min(math.max(mem.r8(0x107BA7), 1), #menu.labels.chars)
		col[11] = math.min(math.max(mem.r8(0x107BAC) + 1, 1), 2)
		col[12] = math.min(math.max(mem.r8(0x107BAD) + 1, 1), 2)

		menu.reset_pos = false

		local stg1, stg2, stg3 = mem.r8(0x107BB1), mem.r8(0x107BB7), mem.r16(0x107BB8)
		for i, stage in ipairs(menu.stage_list) do
			col[13] = i
			if stage.stg1 == stg1 and stage.stg2 == stg2 and stage.stg3 == stg3 then break end
		end

		local bgmid, found = mem.r16(0x1041D6) == 3 and mem.r16(0x10A8D4) or mem.r16(0x107BA6), false
		for name_idx, bgm in ipairs(menu.bgms) do
			if bgmid == bgm.id then
				col[14], found = name_idx, true
				break
			end
		end
		if not found then col[14] = 1 end

		menu.setup_char()
	end
	-- ブレイクショットメニュー
	menu.bs_menus, menu.rvs_menus = {}, {}
	local bs_blocks, rvs_blocks   = {}, {}
	for i = 1, 60 do
		table.insert(bs_blocks, string.format("%s回ガード後に発動", i))
		table.insert(rvs_blocks, string.format("%s回ガード後に発動", i))
	end

	menu.rvs_to_tra = function()
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
		menu.to_tra()
	end
	for i = 1, 2 do
		local pbs, prvs = {}, {}
		table.insert(menu.bs_menus, pbs)
		table.insert(menu.rvs_menus, prvs)
		for _, bs_list in pairs(db.char_bs_list) do
			local list, on_ab, col = {}, {}, {}
			table.insert(list, { title = true, "ONにしたスロットからランダムで発動されます。" })
			table.insert(on_ab, menu.to_tra)
			table.insert(col, 0)
			table.insert(list, { title = true, "*がついたものは「全必殺技でBS可能」がON時のみ有効です。" })
			table.insert(on_ab, menu.to_tra)
			table.insert(col, 0)
			for _, bs in pairs(bs_list) do
				local name = bs.name
				if ut.tstb(bs.hook_type, hook_cmd_types.ex_breakshot, true) then name = "*" .. name end
				table.insert(list, { name, menu.labels.off_on, common = bs.common == true, row = #list, })
				table.insert(on_ab, menu.to_tra)
				table.insert(col, 1)
			end
			table.insert(pbs, { list = list, pos = { offset = 1, row = 3, col = col, }, on_a = on_ab, on_b = on_ab, })
		end
		for _, rvs_list in pairs(db.char_rvs_list) do
			local list, on_ab, col = {}, {}, {}
			table.insert(list, { title = true, "ONにしたスロットからランダムで発動されます。" })
			table.insert(on_ab, menu.rvs_to_tra)
			table.insert(col, 0)
			for _, bs in pairs(rvs_list) do
				table.insert(list, { bs.name, menu.labels.off_on, common = bs.common == true, row = #list, })
				table.insert(on_ab, menu.rvs_to_tra)
				table.insert(col, 1)
			end
			table.insert(prvs, { list = list, pos = { offset = 1, row = 2, col = col, }, on_a = on_ab, on_b = on_ab, })
		end
	end
	for i = 1, 61 do table.insert(menu.labels.block_frames, string.format("%sF後にガード解除", (i - 1))) end
	for i = 1, 99 do table.insert(menu.labels.attack_harmless, string.format("%s段目で空振り", i)) end

	menu.training = menu.create("training", {
		{ "ダミーモード", { "プレイヤー vs プレイヤー", "プレイヤー vs CPU", "CPU vs プレイヤー", "1P&2P入れ替え", "レコード", "リプレイ" }, },
		{ title = true, "ダミー設定" },
		{ "1P アクション", { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" }, },
		{ "2P アクション", { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" }, },
		{ "1P ガード", { "なし", "オート", "ブレイクショット（Aで選択画面へ）", "1ヒットガード", "1ガード", "常時", "ランダム", "強制" }, },
		{ "2P ガード", { "なし", "オート", "ブレイクショット（Aで選択画面へ）", "1ヒットガード", "1ガード", "常時", "ランダム", "強制" }, },
		{ "1ガード持続フレーム数", menu.labels.block_frames, },
		{ "ブレイクショット設定", bs_blocks },
		{ "1P やられ時行動", { "なし", "リバーサル（Aで選択画面へ）", "テクニカルライズ（Aで選択画面へ）", "グランドスウェー（Aで選択画面へ）", "起き上がり攻撃", }, },
		{ "2P やられ時行動", { "なし", "リバーサル（Aで選択画面へ）", "テクニカルライズ（Aで選択画面へ）", "グランドスウェー（Aで選択画面へ）", "起き上がり攻撃", }, },
		{ "ガードリバーサル設定", bs_blocks },
		{ "1P 強制空振り", menu.labels.attack_harmless, },
		{ "2P 強制空振り", menu.labels.attack_harmless, },
		{ "1P 挑発で前進", menu.labels.off_on, },
		{ "2P 挑発で前進", menu.labels.off_on, },
		{ "1P Y座標強制", menu.labels.force_y_pos, },
		{ "2P Y座標強制", menu.labels.force_y_pos, },
		{ "画面下に移動", { "OFF", "2Pを下に移動", "1Pを下に移動", }, },
	}, ut.new_filled_table(18, menu.to_main), ut.new_filled_table(18, menu.to_main_cancel))

	menu.bar = menu.create("bar", {
		{ title = true, "ゲージ設定" },
		{ "1P 体力ゲージ量", menu.labels.life_range, }, -- "最大", "赤", "ゼロ" ...
		{ "2P 体力ゲージ量", menu.labels.life_range, }, -- "最大", "赤", "ゼロ" ...
		{ "1P POWゲージ量", menu.labels.pow_range, }, -- "最大", "半分", "ゼロ" ...
		{ "2P POWゲージ量", menu.labels.pow_range, }, -- "最大", "半分", "ゼロ" ...
		{ "体力ゲージモード", { "自動回復", "固定" }, },
		{ "POWゲージモード", { "自動回復", "固定", "通常動作" }, },
	}, ut.new_filled_table(7, function()
		local col, p, g          = menu.bar.pos.col, players, global
		--  タイトルラベル
		p[1].red                 = col[2] -- 1P 体力ゲージ量
		p[2].red                 = col[3] -- 2P 体力ゲージ量
		p[1].max                 = col[4] -- 1P POWゲージ量
		p[2].max                 = col[5] -- 2P POWゲージ量
		dip_config.infinity_life = col[6] == 2 -- 体力ゲージモード
		g.pow_mode               = col[7] -- POWゲージモード
		menu.current             = menu.main
	end))

	menu.on_disp = function(cancel)
		local col, p, g, o, c = menu.disp.pos.col, players, global, hide_options, menu.config
		local set_hide        = function(bit, val) return ut.hex_set(g.hide, bit, val) end
		-- 01 表示設定 label
		c.disp_box_range1p    = col[2]                         -- 02 1P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
		c.disp_box_range2p    = col[3]                         -- 03 2P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
		p[1].disp_command     = col[4]                         -- 04 1P 入力表示  1:OFF 2:ON 3:ログのみ 4:キーディスのみ
		p[2].disp_command     = col[5]                         -- 05 2P 入力表示  1:OFF 2:ON 3:ログのみ 4:キーディスのみ
		c.disp_stun           = col[6]                         -- 06 気絶メーター表示  1:OFF 2:ON 3:1P 4:2P
		c.disp_damage         = col[7]                         -- 07 ダメージ表示  1:OFF 2:ON 3:1P 4:2P
		-- 08 フレーム表示 label
		g.disp_input          = col[9]                         -- 09 コマンド入力状態表示  1:OFF 2:1P 3:2P
		c.disp_frame          = col[10]                        -- 10 フレームメーター表示  1:OFF 2:大メーター 3:小メーター 4:1P 小メーターのみ 5:2P 小メーターのみ
		c.split_frame         = col[11]                        -- 11 フレームメーター設定  1:ON 2:ON:判定の形毎 3:ON:攻撃判定の形毎 4:ON:くらい判定の形毎
		c.disp_fb_frame       = col[12] == 2                   -- 12 フレームメーター弾表示  1:OFF 2:ON
		g.disp_normal_frames  = col[13] == 2                   -- 13 通常動作フレーム非表示  1:OFF 2:ON
		-- 14 状態表示 label
		p[1].disp_state       = col[15]                        -- 15 1P 状態表示  1:OFF 2: ON, ON:小表示, ON:大表示, ON:フラグ表示
		p[2].disp_state       = col[16]                        -- 16 2P 状態表示  1:OFF 2:ON, ON:小表示, ON:大表示, ON:フラグ表示
		p[1].disp_base        = col[17]                        -- 17 1P 処理アドレス表示  1:OFF 2:本体 3:弾1 4:弾2 5:弾3
		p[2].disp_base        = col[18]                        -- 18 2P 処理アドレス表示  1:OFF 2:本体 3:弾1 4:弾2 5:弾3
		g.disp_pos            = col[19]                        -- 19 向き・距離・位置表示  1;OFF 2:ON 3:向き・距離のみ 4:位置のみ
		-- 20 撮影用 label
		c.disp_char           = col[21]                        -- 21 キャラ表示  1:OFF 2:ON 3:1P 4:2P
		c.disp_phantasm       = col[22]                        -- 22 残像表示  1:OFF 2:ON 3:1P 4:2P
		c.disp_effect         = col[23]                        -- 23 エフェクト表示  1:OFF 2:ON 3:1P 4:2P
		g.hide                = set_hide(o.p_chan, col[24] ~= 1) -- 24 Pちゃん表示 1:OFF 2:ON
		g.hide                = set_hide(o.effect, col[25] ~= 1) -- 25 共通エフェクト表示  1:OFF 2:ON
		-- 26 撮影用(有効化時はリスタートします)
		g.hide                = set_hide(o.meters, col[27] == 2) -- 27 体力,POWゲージ表示  1:OFF 2:ON
		g.hide                = set_hide(o.background, col[28] == 2) -- 28 背景表示  1:OFF 2:ON
		g.hide                = set_hide(o.shadow1, col[29] ~= 2) -- 29 影表示  1:ON 2:OFF 3:ON:反射→影
		g.hide                = set_hide(o.shadow2, col[29] ~= 3) -- 29 影表示  1:ON 2:OFF 3:ON:反射→影
		g.fix_scr_top         = col[30]                         -- 30 画面カメラ位置

		-- 02 1P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
		if c.disp_box_range1p  == 1 then
			p[1].disp_hitbox, p[1].disp_range = false, false
		elseif c.disp_box_range1p  == 2 then
			p[1].disp_hitbox, p[1].disp_range = true, true
		elseif c.disp_box_range1p  == 3 then
			p[1].disp_hitbox, p[1].disp_range = true, false
		elseif c.disp_box_range1p  == 4 then
			p[1].disp_hitbox, p[1].disp_range = false, true
		end
		-- 03 2P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
		if c.disp_box_range2p  == 1 then
			p[2].disp_hitbox, p[2].disp_range = false, false
		elseif c.disp_box_range2  == 2 then
			p[2].disp_hitbox, p[2].disp_range = true, true
		elseif c.disp_box_range2p  == 3 then
			p[2].disp_hitbox, p[2].disp_range = true, false
		elseif c.disp_box_range2p  == 4 then
			p[2].disp_hitbox, p[2].disp_range = false, true
		end
		-- 06 気絶メーター表示  1:OFF 2:ON 3:1P 4:2P
		if c.disp_stun == 1 then
			p[1].disp_stun, p[2].disp_stun = false, false
		elseif c.disp_stun == 2 then
			p[1].disp_stun, p[2].disp_stun = true, true
		elseif c.disp_stun == 3 then
			p[1].disp_stun, p[2].disp_stun = true, false
		elseif c.disp_stun == 4 then
			p[1].disp_stun, p[2].disp_stun = false, true
		end
		-- 07 ダメージ表示  1:OFF 2:ON 3:1P 4:2P
		if c.disp_damage == 1 then
			p[1].disp_damage, p[2].disp_damage = false, false
		elseif c.disp_damage == 2 then
			p[1].disp_damage, p[2].disp_damage = true, true
		elseif c.disp_damage == 3 then
			p[1].disp_damage, p[2].disp_damage = true, false
		elseif c.disp_damage == 4 then
			p[1].disp_damage, p[2].disp_damage = false, true
		end
		-- 10 フレームメーター表示  1:OFF 2:大メーター 3:小メーター 4:1P 小メーターのみ 5:2P 小メーターのみ
		if c.disp_frame == 1 then
			g.disp_frame, p[1].disp_frame, p[2].disp_frame = false, 1, 1
		elseif c.disp_frame == 2 then
			g.disp_frame, p[1].disp_frame, p[2].disp_frame = true, 1, 1
		elseif c.disp_frame == 3 then
			g.disp_frame, p[1].disp_frame, p[2].disp_frame = false, 2, 2
		elseif c.disp_frame == 4 then
			g.disp_frame, p[1].disp_frame, p[2].disp_frame = false, 2, 1
		elseif c.disp_frame == 5 then
			g.disp_frame, p[1].disp_frame, p[2].disp_frame = false, 1, 2
		end
		-- 11 フレームメーター設定  1:ON 2:ON:判定の形毎 3:ON:攻撃判定の形毎 4:ON:くらい判定の形毎
		local set_split_frame = function(p, val) if 1 < p.disp_frame then p.disp_frame = val end end
		set_split_frame(p[1], c.split_frame + 1)
		set_split_frame(p[2], c.split_frame + 1)
		 -- 12 フレームメーター弾表示  1:OFF 2:ON
		p[1].disp_fbfrm, p[2].disp_fbfrm = c.disp_fb_frame, c.disp_fb_frame
		-- 21 キャラ表示 1:OFF 2:ON 3:1P 4:2P
		if c.disp_char == 1 then
			g.hide               = set_hide(o.p1_char, false) -- 1P キャラ表示
			g.hide               = set_hide(o.p2_char, false) -- 2P キャラ表示
		elseif c.disp_char == 2 then
			g.hide               = set_hide(o.p1_char, true) -- 1P キャラ表示
			g.hide               = set_hide(o.p2_char, true) -- 2P キャラ表示
		elseif c.disp_char == 3 then
			g.hide               = set_hide(o.p1_char, true) -- 1P キャラ表示
			g.hide               = set_hide(o.p2_char, false) -- 2P キャラ表示
		elseif c.disp_char == 4 then
			g.hide               = set_hide(o.p1_char, false) -- 1P キャラ表示
			g.hide               = set_hide(o.p2_char, true) -- 2P キャラ表示
		end
		-- 22 残像表示 1:OFF 2:ON 3:1P 4:2P
		g.hide               = set_hide(o.p1_phantasm, c.disp_phantasm) -- 1P 残像表示
		g.hide               = set_hide(o.p2_phantasm, c.disp_phantasm) -- 2P 残像表示
		-- 23 エフェクト表示 1:OFF 2:ON 3:1P 4:2P
		g.hide               = set_hide(o.p1_effect, c.disp_effect) -- 1P エフェクト表示
		g.hide               = set_hide(o.p2_effect, c.disp_effect) -- 2P エフェクト表示
		menu.current         = menu.main

		if not cancel and 27 <= menu.disp.pos.row and menu.disp.pos.row <= 30 then
			menu.on_restart_fight_a()
		end
	end
	menu.disp = menu.create("disp", {
		{ title = true, "表示設定" },
		{ "1P 判定・間合い表示", { "OFF", "ON", "ON:判定のみ", "ON:間合いのみ" }, },
		{ "2P 判定・間合い表示", { "OFF", "ON", "ON:判定のみ", "ON:間合いのみ" }, },
		{ "1P 入力表示", { "OFF", "ON", "ON:ログのみ", "ON:キーディスのみ", }, },
		{ "2P 入力表示", { "OFF", "ON", "ON:ログのみ", "ON:キーディスのみ", }, },
		{ "気絶メーター表示", menu.labels.off_on_1p2p, },
		{ "ダメージ表示", menu.labels.off_on_1p2p, },
		{ title = true, "フレーム表示" },
		{ "コマンド入力状態表示", { "OFF", "ON:1P", "ON:2P", }, },
		{ "フレームメーター表示", { "OFF", "ON:大メーター", "ON:小メーター", "ON:1P 小メーターのみ", "ON:2P 小メーターのみ", }, },
		{ "フレームメーター設定", { "ON", "ON:判定の形毎", "ON:攻撃判定の形毎", "ON:くらい判定の形毎", }, },
		{ "フレームメーター弾表示", menu.labels.off_on, },
		{ "通常動作フレーム非表示", menu.labels.off_on, },
		{ title = true, "状態表示" },
		{ "1P 状態表示", { "OFF", "ON", "ON:小表示", "ON:大表示", "ON:フラグ表示" }, },
		{ "2P 状態表示", { "OFF", "ON", "ON:小表示", "ON:大表示", "ON:フラグ表示" }, },
		{ "1P 処理アドレス表示", { "OFF", "本体", "弾1", "弾2", "弾3", }, },
		{ "2P 処理アドレス表示", { "OFF", "本体", "弾1", "弾2", "弾3", }, },
		{ "向き・距離・位置表示", { "OFF", "ON", "ON:向き・距離のみ", "ON:位置のみ" }, },
		{ title = true, "撮影用" },
		{ "キャラ表示", menu.labels.off_on_1p2p, },
		{ "残像表示", menu.labels.off_on_1p2p, },
		{ "エフェクト表示", menu.labels.off_on_1p2p, },
		{ "Pちゃん表示", menu.labels.off_on, },
		{ "共通エフェクト表示", menu.labels.off_on, },
		{ title = true, "撮影用(有効化時はリスタートします)" },
		{ "体力,POWゲージ表示", menu.labels.off_on, },
		{ "背景表示", menu.labels.off_on, },
		{ "影表示", { "ON", "OFF", "ON:反射→影", } },
		{ "画面カメラ位置", menu.labels.fix_scr_tops, },
	}, ut.new_filled_table(30, 	function() menu.on_disp(false) end), ut.new_filled_table(30, function() menu.on_disp(true) end))

	menu.extra = menu.create("extra", {
		{ title = true, "特殊設定" },
		{ "簡易超必", menu.labels.off_on, },
		{ "半自動潜在能力", menu.labels.off_on, },
		{ "ライン送らない現象", { "OFF", "ON", "ON:1Pのみ", "ON:2Pのみ" }, },
		{ "ヒット時にポーズ", { "OFF", "ON", "ON:やられのみ", "ON:投げやられのみ", "ON:打撃やられのみ", "ON:ガードのみ", }, },
		{ "判定発生時にポーズ", { "OFF", "投げ", "攻撃", "変化時", }, },
		{ "技画像保存", { "OFF", "ON:新規", "ON:上書き", }, },
		{ "ヒット効果確認用", db.hit_effects.menus, },
		{ "全必殺技でBS可能", menu.labels.off_on, },
		{ "ビリーMVS化", menu.labels.off_on, },
	}, ut.new_filled_table(10, function()
		local col, p, g       = menu.extra.pos.col, players, global
		-- タイトルラベル
		dip_config.easy_super = col[2] == 2          -- 簡易超必
		dip_config.semiauto_p = col[3] == 2          -- 半自動潜在能力
		p[1].dis_plain_shift  = col[4] == 2 or col[4] == 3 -- ライン送らない現象
		p[2].dis_plain_shift  = col[4] == 2 or col[4] == 4 -- ライン送らない現象
		g.pause_hit           = col[5]               -- ヒット時にポーズ
		g.pause_hitbox        = col[6]               -- 判定発生時にポーズ
		g.save_snapshot       = col[7]               -- 技画像保存
		g.damaged_move        = col[8]               -- ヒット効果確認用
		g.all_bs              = col[9] == 2          -- 全必殺技BS
		g.mvs_billy           = col[10] == 2         -- ビリーMVS化
		mod.all_bs(g.all_bs)
		mod.mvs_billy(g.mvs_billy)
		menu.current = menu.main
	end))

	menu.auto = menu.create("auto", {
		{ title = true, "自動入力設定" },
		{ "ダウン投げ", menu.labels.off_on, },
		{ "ダウン攻撃", menu.labels.off_on, },
		{ "通常投げの派生技", menu.labels.off_on, },
		{ "デッドリーレイブ", { "通常動作", 2, 3, 4, 5, 6, 7, 8, 9, 10 }, },
		{ "アンリミテッドデザイア", { "通常動作", 2, 3, 4, 5, 6, 7, 8, 9, 10, "ギガティックサイクロン" }, },
		{ "ドリル", { "通常動作", 2, 3, 4, 5 }, },
		{ "超白龍", { "OFF", "C攻撃-判定発生前", "C攻撃-判定発生後" }, },
		{ "M.リアルカウンター", { "OFF", "ジャーマン", "フェイスロック", "投げっぱなしジャーマン", }, },
		{ "M.トリプルエクスタシー", menu.labels.off_on, },
		{ "炎の種馬", menu.labels.off_on, },
		{ "喝CA", menu.labels.off_on, },
		{ "飛燕失脚CA", menu.labels.off_on, },
		{ title = true, "入力設定" },
		{ "詠酒チェック", { "OFF", "距離チェックなし", "いつでも詠酒" }, },
		{ "必勝！逆襲拳", { "OFF", "すぐ発動" }, },
		{ "空振りCA", menu.labels.off_on, },
	}, ut.new_filled_table(17, function()
		local col, g, ez           = menu.auto.pos.col, global, mod.easy_move
		-- 自動入力設定
		g.auto_input.otg_throw     = col[2] == 2 -- ダウン投げ
		g.auto_input.otg_attack    = col[3] == 2 -- ダウン攻撃
		g.auto_input.combo_throw   = col[4] == 2 -- 通常投げの派生技
		g.auto_input.rave          = col[5]    -- デッドリーレイブ
		g.auto_input.desire        = col[6]    -- アンリミテッドデザイア
		g.auto_input.drill         = col[7]    -- ドリル
		g.auto_input.pairon        = col[8]    -- 超白龍
		g.auto_input.real_counter  = col[9]    -- M.リアルカウンター
		g.auto_input.auto_3ecst    = col[10] == 2 -- M.トリプルエクスタシー
		g.auto_input.taneuma       = col[11] == 2 -- 炎の種馬
		g.auto_input.katsu_ca      = col[12] == 2 -- 喝CA
		g.auto_input.sikkyaku_ca   = col[13] == 2 -- 飛燕失脚CA
		-- 入力設定
		g.auto_input.esaka_check   = col[15]   -- 詠酒チェック
		g.auto_input.fast_kadenzer = col[16] == 2 -- 必勝！逆襲拳
		g.auto_input.kara_ca       = col[17] == 2 -- 空振りCA
		-- 簡易入力のROMハックを反映する
		ez.real_counter(g.auto_input.real_counter) -- ジャーマン, フェイスロック, 投げっぱなしジャーマン
		ez.esaka_check(g.auto_input.esaka_check) -- 詠酒の条件チェックを飛ばす
		ez.taneuma_finish(g.auto_input.taneuma) -- 自動 炎の種馬
		ez.fast_kadenzer(g.auto_input.fast_kadenzer) -- 必勝！逆襲拳1発キャッチカデンツァ
		ez.katsu_ca(g.auto_input.katsu_ca)     -- 自動喝CA
		ez.shikkyaku_ca(g.auto_input.sikkyaku_ca) -- 自動飛燕失脚CA
		ez.kara_ca(g.auto_input.kara_ca)       -- 空振りCAできる
		ez.triple_ecstasy(g.auto_input.auto_3ecst) -- 自動マリートリプルエクスタシー
		menu.current = menu.main
	end))

	menu.color = menu.create("color", ut.table_add_conv_all({
		{ title = true, "判定個別設定" }
	}, db.box_type_list, function(b) return { b.name, menu.labels.off_on, { fill = b.fill, outline = b.outline } } end
	), ut.new_filled_table(#db.box_type_list + 1, function()
		local col = menu.color.pos.col
		for i = 2, #col do db.box_type_list[i - 1].enabled = col[i] == 2 end
		menu.current = menu.main
	end))

	menu.recording = menu.create("recording", {
		{ title = true, "選択したスロットに記憶されます。" },
		{ "スロット1", { "Aでレコード開始", }, },
		{ "スロット2", { "Aでレコード開始", }, },
		{ "スロット3", { "Aでレコード開始", }, },
		{ "スロット4", { "Aでレコード開始", }, },
		{ "スロット5", { "Aでレコード開始", }, },
		{ "スロット6", { "Aでレコード開始", }, },
		{ "スロット7", { "Aでレコード開始", }, },
		{ "スロット8", { "Aでレコード開始", }, },
	}, {
		menu.rec_to_tra,               -- 説明
		function() menu.exit_and_rec(1) end, -- スロット1
		function() menu.exit_and_rec(2) end, -- スロット2
		function() menu.exit_and_rec(3) end, -- スロット3
		function() menu.exit_and_rec(4) end, -- スロット4
		function() menu.exit_and_rec(5) end, -- スロット5
		function() menu.exit_and_rec(6) end, -- スロット6
		function() menu.exit_and_rec(7) end, -- スロット7
		function() menu.exit_and_rec(8) end, -- スロット8
	}, ut.new_filled_table(1, menu.rec_to_tra, 8, menu.to_tra))

	menu.replay = menu.create("replay", {
		{ title = true, "ONにしたスロットからランダムでリプレイされます。" },
		{ "スロット1", menu.labels.off_on, },
		{ "スロット2", menu.labels.off_on, },
		{ "スロット3", menu.labels.off_on, },
		{ "スロット4", menu.labels.off_on, },
		{ "スロット5", menu.labels.off_on, },
		{ "スロット6", menu.labels.off_on, },
		{ "スロット7", menu.labels.off_on, },
		{ "スロット8", menu.labels.off_on, },
		{ title = true, "リプレイ設定" },
		{ "繰り返し", menu.labels.off_on, },
		{ "繰り返し間隔", menu.labels.play_interval, },
		{ "繰り返し開始条件", { "なし", "両キャラがニュートラル", }, },
		{ "開始間合い固定", { "OFF", "Aでレコード開始", "1Pと2P", "1P", "2P", }, },
		{ "状態リセット", { "OFF", "1Pと2P", "1P", "2P", }, },
		{ "ガイド表示", menu.labels.off_on, },
		{ "ダメージでリプレイ中止", menu.labels.off_on, },
	}, ut.new_filled_table(17, menu.exit_and_play), ut.new_filled_table(17, menu.exit_and_play_cancel))
	for i = 2, 2 + 8 do menu.replay.pos.col[i] = 2 end -- スロット1-スロット8

	menu.init_auto_config()
	menu.init_disp_config()
	menu.init_ex_config()
	menu.init_bar_config()
	menu.init_config()
	menu.to_main(nil, true)

	menu.proc = function() set_freeze(false) end -- メニュー表示中はDIPかポーズでフリーズさせる
	menu.cursor_ud = function(add_val)
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
			if not menu.current.list[temp_row].title then
				menu.current.pos.row = temp_row
				break
			end
		end
		if not (menu.current.pos.offset < menu.current.pos.row and menu.current.pos.row < menu.current.pos.offset + menu.max_row) then
			menu.current.pos.offset = math.max(1, menu.current.pos.row - menu.max_row)
		end
		input.accepted = scr:frame_number()
	end
	menu.cursor_lr = function(add_val, loop)
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
		input.accepted = scr:frame_number()
	end
	menu.draw = function()
		local width = scr.width * scr.xscale
		local height = scr.height * scr.yscale
		if not in_match or in_player_select then return end
		if menu.prev_state ~= menu and menu.state == menu then menu.update_pos() end -- 初回のメニュー表示時は状態更新
		menu.prev_state = menu.state                                           -- 前フレームのメニューを更新

		local on_a, on_a1, _ = input.accept("A")
		if input.accept("st") then -- Menu ON/OFF
		elseif on_a then
			---@diagnostic disable-next-line: redundant-parameter
			menu.current.on_a[menu.current.pos.row](on_a1 and 1 or 2) -- サブメニューへの遷移
		elseif input.accept("B") then
			menu.current.on_b[menu.current.pos.row]()        -- メニューから戻る
		elseif input.accept("8") then
			menu.cursor_ud(-1)                               -- カーソル上移動
		elseif input.accept("2") then
			menu.cursor_ud(1)                                -- カーソル下移動
		elseif input.accept("4") then
			menu.cursor_lr(-1, true)                         -- カーソル左移動
		elseif input.accept("6") then
			menu.cursor_lr(1, true)                          -- カーソル右移動
		elseif input.accept("C") then
			menu.cursor_lr(-10, false)                       -- カーソル左10移動
		elseif input.accept("D") then
			menu.cursor_lr(10, false)                        -- カーソル右10移動
		end

		-- メニュー表示本体
		scr:draw_box(0, 0, width, height, 0xC0000000, 0xC0000000)
		local row_num, menu_max = 1, math.min(menu.current.pos.offset + menu.max_row, #menu.current.list)
		for i = menu.current.pos.offset, menu_max do
			local row = menu.current.list[i]
			local y = 38 + 10 * row_num
			local c1, c2, c3, c4, c5
			local deep = math.modf((scr:frame_number() / 5) % 20) + 1
			-- 選択行とそうでない行の色分け判断
			if i == menu.current.pos.row then
				c1, c2, c3, c4, c5 = 0xFFDD2200, 0xFF662200, 0xFFFFFF00, 0xCC000000, 0xAAFFFFFF
				c1 = c1 - (0x00110000 * math.abs(deep - 10)) -- アクティブメニュー項目のビカビカ処理
			else
				c1, c2, c3, c4, c5 = 0xFFC0C0C0, 0xFFB0B0B0, 0xFF000000, 0x00000000, 0xFF000000
			end
			if row.title then
				-- ラベルだけ行
				draw_text("center", y + 1, row[1], 0xFFFFFFFF)
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
				draw_text(96.5, y + 1.5, row[1], c4)
				draw_text(96, y + 1, row[1], c3)
				if row[2] then
					-- 通常行 オプション部分
					local col_pos_num = menu.current.pos.col[i] or 1
					if col_pos_num > 0 then
						draw_text(165.5, y + 1.5, string.format("%s", row[2][col_pos_num]), c4)
						draw_text(165, y + 1, string.format("%s", row[2][col_pos_num]), c3)
						-- オプション部分の左右移動可否の表示
						if i == menu.current.pos.row then
							draw_text(160, y + 1, "<", col_pos_num == 1 and c5 or c3)
							draw_text(223, y + 1, ">", col_pos_num == #row[2] and c5 or c3)
						end
					end
				end
				if row[3] and row[3].outline then
					scr:draw_box(200, y + 2, 218, y + 7, 0xAA000000, row[3].outline)
				end
			end
			if i == menu.current.pos.offset then
				local txt, c6 = "▲", 0xFF404040
				if 1 < menu.current.pos.offset then
					txt, c6 = "▲", 0xFFC0C0C0 - (0x00080808 * math.abs(deep - 10)) -- 残メニューマークのビカビカ処理
				end
				draw_text("center", y + 1 - 10, txt, c6) -- 上にメニューあり
			end
			if i == menu_max then
				local txt, c6 = "▼", 0xFF404040
				if menu.current.pos.offset + menu.max_row < #menu.current.list then
					txt, c6 = "▼", 0xFFF0F0F0 - (0x00080808 * math.abs(deep - 10)) -- 残メニューマークのビカビカ処理
				end
				draw_text("center", y + 1 + 10, txt, c6) -- 下にメニューあり
			end
			row_num = row_num + 1
		end
		players[1].max_pos, players[1].min_pos, players[2].max_pos, players[2].min_pos = 0, 1000, 0, 1000
	end

	local active_mem_0x100701 = {}
	for i = 0x022E, 0x0615 do active_mem_0x100701[i] = true end

	menu.state = menu.tra_main -- menu or tra_main

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

	rbff2.emu_start = function()
		setup_emu()
		math.randomseed(os.time())
	end

	rbff2.emu_stop = function()
		if not machine then return end
		reset_memory_tap() -- フック外し
		for i = 1, 4 do mem.w8(0x10E000 + i - 1, 0) end -- デバッグ設定戻し
		machine:hard_reset() -- ハードリセットでメモリ上のロムパッチの戻しも兼ねる
	end

	rbff2.emu_menu = function(index, event) return false end

	rbff2.emu_frame = function() end

	rbff2.emu_pause = function()
		menu.state.draw()
		--print(collectgarbage("count"))
		--for addr, cnt in pairs(mem.wp_cnt) do ut.printf("wp %x %s" ,addr,cnt) end
		--for addr, cnt in pairs(mem.rp_cnt) do ut.printf("rp %x %s" ,addr,cnt) end
	end

	rbff2.emu_resume = function() end

	rbff2.emu_frame_done = function()
		if not machine then return end
		if machine.paused == false then menu.state.draw() end
		collectgarbage("collect")
	end

	rbff2.emu_periodic = function()
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
			reset_memory_tap()
		else
			-- プレイヤーセレクト中かどうかの判定
			in_player_select = _0x100701 == 0x10B and (_0x107C22 == 0 or _0x107C22 == 0x55) and _0x10FDAF == 2 and _0x10FDB6 ~= 0 and mem._0x10E043 == 0
			-- 対戦中かどうかの判定
			in_match = active_mem_0x100701[_0x100701] ~= nil and _0x107C22 == 0x44 and _0x10FDAF == 2 and _0x10FDB6 ~= 0
			if in_match then
				mem.w16(0x10FDB6, 0x0101) -- 操作の設定
				for i, p in ipairs(players) do mem.w16(p.addr.control, i * 0x0101) end
			end
			-- ROM部分のメモリエリアへパッチあて
			load_rom_patch(reset_memory_tap)
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
			input.read()
			menu.state.proc() -- メニュー初期化前に処理されないようにする
		end
	end
end

return rbff2