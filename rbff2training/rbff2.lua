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
local rbff2        = {}

rbff2.self_disable = false
rbff2.startplugin  = function()
	local ut         = require("rbff2training/util")
	local db         = require("rbff2training/data")
	local gm         = require("rbff2training/game")
	local UTF8toSJIS = require("rbff2training/UTF8toSJIS")

	local to_sjis    = function(s)
		if type(s) == "table" then
			for i, ss in ipairs(s) do
				s[i] = UTF8toSJIS:UTF8_to_SJIS_str_cnv(ss)
			end
			return s
		end
		return (select(1, UTF8toSJIS:UTF8_to_SJIS_str_cnv(s)))
	end

	-- MAMEのLuaオブジェクトの変数と初期化処理
	local man        = manager
	local machine    = man.machine
	local cpu        = machine.devices[":maincpu"]
	local pgm        = cpu.spaces["program"]
	local scr        = machine.screens:at(1)
	local ioports    = man.machine.ioport.ports
	local base_path  = function()
		local base = emu.subst_env(man.options.entries.homepath:value():match('([^;]+)')) .. "/plugins/rbff2training"
		local dir = ut.cur_dir()
		return dir .. "/" .. base
	end
	--[[
	for k, v in pairs(cpu.state) do ut.printf("%s %s", k ,v ) end
	for pname, port in pairs(ioports) do
		for fname, field in pairs(port.fields) do ut.printf("%s %s", pname, fname) end
	end
	for p, pk in ipairs(data.joy_k) do
		for _, name in pairs(pk) do
			ut.printf("%s %s %s", ":edge:joy:JOY" .. p, name, ioports[":edge:joy:JOY" .. p].fields[name])
		end
	end
	]]
	--[[
	for char, state in ipairs(db.input_state_easy) do
		for _, tbl in ipairs(state) do
			ut.printf("%s %X %s", char, tbl.addr, to_sjis(tbl.name_plain))
		end
	end
	]]

	-- ヒット時のシステム内での中間処理による停止アドレス
	local hit_system_stops       = {}

	-- 判定種類 frame_attack_typesとp.attackbitsとで属性名を合わせる
	local frame_attack_types     = db.frame_attack_types
	-- ヒット処理の飛び先 家庭用版 0x13120 からのデータテーブル 5種類
	local possible_types         = {
		none      = 0, -- 常に判定しない
		same_line = 2 ^ 0, -- 同一ライン同士なら判定する
		diff_line = 2 ^ 1, -- 異なるライン同士で判定する
		air_onry  = 2 ^ 2, -- 相手が空中にいれば判定する
		unknown   = 2 ^ 3, -- 不明
	}
	-- 同一ライン、異なるラインの両方で判定する
	possible_types.both_line     = possible_types.same_line | possible_types.diff_line
	local get_top_type           = function(top, types)
		local type = 0
		for _, t in ipairs(types) do
			if t.top and top <= t.top then type = type | t.act_type end
		end
		return type
	end
	local get_bottom_type        = function(bottom, types)
		local type = 0
		for _, t in ipairs(types) do
			if t.bottom and bottom >= t.bottom then type = type | t.act_type end
		end
		return type
	end
	local get_dodge              = function(p, box, top, bottom)
		local dodge, type = 0, box.type
		if p.sway_status == 0 then                                  -- メインライン
			dodge = get_top_type(top, db.hurt_dodge_types) | get_bottom_type(bottom, db.hurt_dodge_types)
			if type == db.box_types.hurt1 or type == db.box_types.hurt2 then -- 食らい1 食らい2
			elseif type == db.box_types.down_otg then               -- 食らい(ダウン追撃のみ可)
			elseif type == db.box_types.launch then                 -- 食らい(空中追撃のみ可)
			elseif type == db.box_types.hurt3 then                  -- 食らい(対ライン上攻撃) 対メイン上段無敵
				dodge = dodge | (p.sway_status == 0 and frame_attack_types.main_high or 0)
			elseif type == db.box_types.hurt4 then                  -- 食らい(対ライン下攻撃) 対メイン下段無敵
				dodge = dodge | (p.sway_status == 0 and frame_attack_types.main_low or 0)
			end
		elseif type == db.box_types.sway_hurt1 or type == db.box_types.sway_hurt2 then
			dodge = dodge | frame_attack_types.main                             -- 食らい(スウェー中) メイン無敵
			dodge = dodge | (box.real_top <= 32 and frame_attack_types.sway_high or 0) -- 上半身無敵
			dodge = dodge | (box.real_bottom <= 60 and frame_attack_types.sway_low or 0) -- 下半身無敵
		end
		return dodge
	end

	local hitbox_possibles       = {
		normal          = 0x94D2C, -- 012DBC: 012DC8: 通常状態へのヒット判定処理
		down            = 0x94E0C, -- 012DE4: 012DF0: ダウン状態へのヒット判定処理
		juggle          = 0x94EEC, -- 012E0E: 012E1A: 空中追撃可能状態へのヒット判定処理
		standing_block  = 0x950AC, -- 012EAC: 012EB8: 上段ガード判定処理
		crouching_block = 0x9518C, -- 012ED8: 012EE4: 屈ガード判定処理
		air_block       = 0x9526C, -- 012F04: 012F16: 空中ガード判定処理
		sway_standing   = 0x95A4C, -- 012E60: 012E6C: 対ライン上段の処理
		sway_crouching  = 0x95B2C, -- 012F3A: 012E90: 対ライン下段の処理
		joudan_atemi    = 0x9534C, -- 012F30: 012F82: 上段当身投げの処理
		urakumo         = 0x9542C, -- 012F30: 012F82: 裏雲隠しの処理
		gedan_atemi     = 0x9550C, -- 012F44: 012F82: 下段当身打ちの処理
		gyakushu        = 0x955EC, -- 012F4E: 012F82: 必勝逆襲拳の処理
		sadomazo        = 0x956CC, -- 012F58: 012F82: サドマゾの処理
		phoenix_throw   = 0x9588C, -- 012F6C: 012F82: フェニックススルーの処理
		baigaeshi       = 0x957AC, -- 012F62: 012F82: 倍返しの処理
		unknown1        = 0x94FCC, -- 012E38: 012E44: 不明処理、未使用？
		katsu           = 0x9596C, -- : 012FB2: 喝消し
		nullify         = function(id) -- : 012F9A: 弾消し
			return (0x20 <= id) and possible_types.same_line or possible_types.none
		end,
	}
	local hitbox_parry_bits      = {
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
	local hitbox_parry_range     = function(y1, y2, r1, r2)
		y1, y2 = ut.sort_ba(y1, y2)
		r1, r2 = ut.sort_ba(r1, r2)
		local ret = (r1 <= y1 and y1 <= r2) or (r1 <= y2 and y2 <= r2)
		return ret
	end
	local hitbox_parry_types     = {
		{ name = "none",          label = "",  range = function(y1, y2) return true end,                                value = hitbox_parry_bits.none },
		{ name = "joudan_atemi",  label = "J", range = function(y1, y2) return hitbox_parry_range(y1, y2, 112, 41) end, value = hitbox_parry_bits.joudan_atemi }, -- 上段当身投げと接触判定される
		{ name = "urakumo",       label = "U", range = function(y1, y2) return hitbox_parry_range(y1, y2, 104, 41) end, value = hitbox_parry_bits.urakumo }, -- 裏雲隠しと接触判定される
		{ name = "gedan_atemi",   label = "G", range = function(y1, y2) return hitbox_parry_range(y1, y2, 44, 1) end,   value = hitbox_parry_bits.gedan_atemi }, -- 下段当身打ちと接触判定される
		{ name = "gyakushu",      label = "H", range = function(y1, y2) return hitbox_parry_range(y1, y2, 72, 33) end,  value = hitbox_parry_bits.gyakushu }, -- 必勝逆襲拳と接触判定される
		{ name = "sadomazo",      label = "S", range = function(y1, y2) return hitbox_parry_range(y1, y2, 96, 37) end,  value = hitbox_parry_bits.sadomazo }, -- サドマゾと接触判定される
		{ name = "phoenix_throw", label = "P", range = function(y1, y2) return hitbox_parry_range(y1, y2, 120, 57) end, value = hitbox_parry_bits.phoenix_throw }, -- フェニックススルーと接触判定される
		{ name = "baigaeshi",     label = "B", range = function(y1, y2) return hitbox_parry_range(y1, y2, 84, 1) end,   value = hitbox_parry_bits.baigaeshi }, -- 倍返しと接触判定される
		{ name = "katsu",         label = "K", range = function(y1, y2) return hitbox_parry_range(y1, y2, 84, 1) end,   value = hitbox_parry_bits.katsu },   -- 喝と接触判定されて消される
		{ name = "nullify",       label = "N", range = function(y1, y2) return true end,                                value = hitbox_parry_bits.nullify }, -- 弾同士の接触判定される
		--{ name = "unknown1",      label = "?", value = hitbox_grab_bits.unknown1 }, -- ?
	}
	local txt_hitbox_parry_types = {}
	for _, t in ipairs(hitbox_parry_types) do
		if t.label ~= "" and t.label ~= "N" then table.insert(txt_hitbox_parry_types, t) end
		hitbox_parry_types[t.name] = t
	end
	local parrieable_txt_cache = {}
	local to_parrieable_txt    = function(parrieable)
		if parrieable_txt_cache[parrieable] then return table.unpack(parrieable_txt_cache[parrieable]) end
		local txt, short = "", ""
		for _, t in ipairs(txt_hitbox_parry_types) do
			local match = ut.tstb(parrieable, t.value, true)
			txt = txt .. (match and t.label .. " " or "- ")
			if match then short = short .. t.label end
		end
		if #short == 0 then short = "-" end
		parrieable_txt_cache[parrieable] = { txt, short }
		return txt, short
	end
	local state_line_types     = {
		id      = 1,
		damage  = 2,
		hitstop = 3,
		fb_hits = 4,
		pow     = 5,
		inv     = 6,
		cancel  = 7,
		box     = 8,
		hurt    = 9,
		throw   = 10,
		hit     = 11,
	}
	local max_state_line_types = 0
	for _, _ in pairs(state_line_types) do max_state_line_types = max_state_line_types + 1 end

	-- コマンド入力状態
	local input_state = db.input_state

	-- メニュー用変数
	local menu        = {
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
			disp_box_range1p = 2, -- 02 1P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
			disp_box_range2p = 2, -- 03 2P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
			disp_stun        = 2, -- 06 気絶メーター表示  1:OFF 2:ON 3:1P 4:2P
			disp_damage      = 2, -- 07 ダメージ表示  1:OFF 2:ON 3:1P 4:2P
			disp_frame       = 2, -- 10 フレームメーター表示  1:OFF 2:大メーター 3:小メーター 4:1P 小メーターのみ 5:2P 小メーターのみ
			split_frame      = 1, -- 11 フレームメーター設定  1:ON 2:ON:判定の形毎 3:ON:攻撃判定の形毎 4:ON:くらい判定の形毎
			disp_fb_frame    = true, -- 12 フレームメーター弾表示  1:OFF 2:ON
			disp_char        = 2, -- 21 キャラ表示 1:OFF 2:ON 3:1P 4:2P
			disp_phantasm    = 2, -- 22 残像表示 1:OFF 2:ON 3:1P 4:2P
			disp_effect      = 2, -- 23 エフェクト表示 1:OFF 2:ON 3:1P 4:2P
		},

		create = function(name, desc, list, init, on_a, on_b)
			local row, col = nil, {}
			for i, obj in ipairs(list) do
				if not row and not obj.title then row = i end
				table.insert(col, #obj == 1 and 0 or 1)
			end
			return { name = name, desc = desc, list = list, pos = { offset = 1, row = row or 1, col = col }, init = init, on_a = on_a, on_b = on_b or on_a }
		end,

		to_tra = nil,
		to_bar = nil,
		to_disp = nil,
		to_ex = nil,
		to_col = nil,
		to_auto = nil,
	}
	menu.set_current  = function(next_menu)
		-- print("next", next_menu or "main")
		if next_menu and (type(next_menu) == "string") then
			next_menu = menu[next_menu]
		end
		next_menu = next_menu or menu.main
		if next_menu ~= menu.main and menu.current ~= next_menu and next_menu.init ~= nil and type(next_menu.init) == "function" then
			next_menu.init()
		end
		menu.current = next_menu
	end
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
	local mem                  = {
		last_time          = 0,  -- 最終読込フレーム(キャッシュ用)
		_0x10E043          = 0,  -- 手動でポーズしたときに00以外になる
		stage_base_addr    = 0x100E00,
		close_far_offset   = 0x02AE08, -- 近距離技と遠距離技判断用のデータの開始位置
		close_far_offset_d = 0x02DDAA, -- 対ラインの近距離技と遠距離技判断用のデータの開始位置
		pached             = false, -- Fireflower形式のパッチファイルの読込とメモリへの書込
		w08                = function(addr, value) pgm:write_u8(addr, value) end,
		wd08               = function(addr, value) pgm:write_direct_u8(addr, value) end,
		w16                = function(addr, value) pgm:write_u16(addr, value) end,
		wd16               = function(addr, value) pgm:write_direct_u16(addr, value) end,
		w32                = function(addr, value) pgm:write_u32(addr, value) end,
		wd32               = function(addr, value) pgm:write_direct_u32(addr, value) end,
		w08i               = function(addr, value) pgm:write_i8(addr, value) end,
		w16i               = function(addr, value) pgm:write_i16(addr, value) end,
		w32i               = function(addr, value) pgm:write_i32(addr, value) end,
		r08                = function(addr, value) return pgm:read_u8(addr, value) end,
		r16                = function(addr, value) return pgm:read_u16(addr, value) end,
		r32                = function(addr, value) return pgm:read_u32(addr, value) end,
		r08i               = function(addr, value) return pgm:read_i8(addr, value) end,
		r16i               = function(addr, value) return pgm:read_i16(addr, value) end,
		r32i               = function(addr, value) return pgm:read_i32(addr, value) end,
	}
	-- プログラム改変 romhack
	local mod                  = {
		p1_patch       = function()
			local base = base_path() .. '/patch/rom/'
			local filename = "char1-p1.pat"
			local patch = base .. emu.romname() .. '/' .. filename
			if not ut.is_file(patch) then ut.printf("%s NOT found", patch) end
			return ut.apply_patch_file(pgm, patch, true)
		end,
		aes            = function()
			mem.wd16(0x10FE32, 0x0000) -- 強制的に家庭用モードに変更
		end,
		bugfix         = function()
			-- H POWERの表示バグを修正する 無駄な3段表示から2段表示へ
			mem.wd08(0x025DB3, 0x01)
			-- 簡易超必ONのときにダックのブレイクスパイラルブラザー（BRも）が出るようにする
			mem.wd16(0x0CACC8, 0xC37C)
			-- デバッグDIPによる自動アンリミのバグ修正
			mem.wd08(0x049967, 0x09)
			mem.wd08(0x049971, 0x02)
		end,
		snk_time       = function(mode)
			-- タイムのSNK表示
			mem.wd32(0x01EB56, mode == 3 and 0x00010405 or 0x08090C0D)
			mem.wd32(0x01EBB6, mode == 3 and 0x02030607 or 0x0A0B0E0F)
			mem.wd32(0x01EBBC, mode ~= 1 and 0x20202020 or 0xB2B3B4B5)
			mem.wd32(0x01EBC0, mode ~= 1 and 0x20202020 or 0xB6B7B8B9)
			mem.wd32(0x01EBC4, mode ~= 1 and 0x20202020 or 0xBABBBCBD)
		end,
		cpu_hardest    = function(enabled)
			-- 常にCPUレベルMAX
			--[[ RAM改変によるCPUレベル MAX（ロムハックのほうが楽）
			mem.w16(0x10E792, 0x0007) -- maincpu.pw@10E792=0007
			mem.w16(0x10E796, 0x0007) -- maincpu.pw@10E796=0008
			]]
			mem.wd32(0x050108, enabled and 0x303C0007 or 0x302D6016)
			-- mem.wd32(0x050138, enabled and 0x3E3C0007 or 0x3E2D6792) -- CPU待ち時間用
			mem.wd32(0x050170, enabled and 0x303C0007 or 0x302D6016)
			mem.wd32(0x0501C8, enabled and 0x303C0007 or 0x302D6794)
			mem.wd32(0x0501EE, enabled and 0x303C0007 or 0x302D6796)
		end,
		cpu_stg        = function(change)
			-- CPU戦のステージを常に2ラインの対戦ステージにする
			-- 00F0F8: 41FA 01DE lea ($1de,PC) ; ($f2d8), A0 ; A0 = F2D8 CPUステージテーブル
			mem.wd32(0x00F0F8, change and 0x41FA017E or 0x41FA01DE)
		end,
		sokaku_stg     = function(enabled)
			-- 対戦の双角ステージをビリーステージに変更する（MVSと家庭用共通）
			mem.wd16(0x00F290, enabled and 0x0004 or 0x0001)
		end,
		cpu_wait       = function(mode)
			local pow = { 1, 0.75, 0.5, 0.25, 0 }
			-- CPU動作間隔 052D94-052DD2
			for i, time in ipairs({
				0x0030, 0x0024, 0x001E, 0x0012, 0x002A, 0x001E, 0x0012, 0x000C, 0x0024, 0x0018, 0x000C,
				0x0006, 0x0018, 0x0012, 0x000C, 0x0006, 0x0012, 0x000C, 0x0006, 0x0000, 0x000C, 0x0006,
				0x0000, 0x0000, 0x0006, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
			}) do
				-- mode 1:100% 2:75% 3:50% 4:25% 5:0%
				local addr, newtime = 0x052D94 + ((i - 1) * 2), (mode == 4) and 0 or math.floor(time * pow[mode])
				--ut.printf("%X: %s > %s", addr, time, newtime)
				mem.w16(addr, newtime)
			end
		end,
		training       = function(tra)
			mem.wd16(0x01F3BC, tra and 0x4E75 or 0x082C) -- 1Pのスコア表示をすぐ抜ける 082C
			mem.wd16(0x01F550, tra and 0x4E75 or 0x082C) -- 2Pのスコア表示をすぐ抜ける 082C
			mem.wd08(0x062E9D, tra and 0x00 or 0x01)    -- 乱入されても常にキャラ選択できる 01
			-- 対CPU1体目でボスキャラも選択できるようにする サンキューヒマニトさん
			mem.wd08(0x0633EE, tra and 0x60 or 0x6A)    -- CPUのキャラテーブルをプレイヤーと同じにする 6A
			mem.wd08(0x063440, tra and 0x60 or 0x6A)    -- CPUの座標テーブルをプレイヤーと同じにする 6A
			mem.wd32(0x062FF4, tra and 0x4E714E71 or 0x335000A4) -- PLのカーソル座標修正をNOPにする 3350 00A4
			mem.wd32(0x062FF8, tra and 0x4E714E71 or 0x5B6900A4) -- PLのカーソル座標修正をNOPにする 5B69 00A4
			mem.wd08(0x062EA6, tra and 0x60 or 0x66)    -- CPU選択時にアイコンを減らすのを無効化 66
			mem.wd32(0x063004, tra and 0x4E714E71 or 0x556900A4) -- PLのカーソル座標修正をNOPにする 5569 00A4
			-- キャラ選択の時間減らす処理をNOPにする
			mem.wd32(0x063336, 0x4E714E71)              -- 532C 00B2
			-- キャラ選択の時間の値にアイコン用のオフセット値を改変して空表示にする
			-- 0632D0: 004B -- キャラ選択の時間の内部タイマー初期値1 デフォは4B=75フレーム
			-- 063332: 004B -- キャラ選択の時間の内部タイマー初期値2 デフォは4B=75フレーム
			mem.wd16(0x0632DC, 0x0DD7)
			-- クレジット消費をNOPにする
			mem.wd32(0x00D238, 0x4E714E71) -- 家庭用モードでのクレジット消費をNOPにする
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
			mem.wd08(0x10E003, 0x0C)       -- Auto SDM combo (RB2) 0x56D98A
			mem.wd32(0x1004D5, 0x46A70500) -- 1P Crazy Yamazaki Return (now he can throw projectile "anytime" with some other bug) 0x55FE5C
			mem.wd16(0x1004BF, 0x3CC1)     -- 1P Level 2 Blue Mary 0x55FE46
			]]
			-- 1P,2P,COMの表記を空白にする
			mem.wd16(0x01FF14, tra and 0x07DE or 0x07DF) -- 0x07DF
			mem.wd16(0x01FF16, tra and 0x07DE or 0x07FF) -- 0x07FF
			mem.wd16(0x01FF18, tra and 0x07DE or 0x07CB) -- 0x07CB
			mem.wd16(0x01FF1A, tra and 0x07DE or 0x07EB) -- 0x07EB
			mem.wd16(0x01FF1C, tra and 0x07DE or 0x07FA) -- 0x07FA
			mem.wd16(0x01FF1E, tra and 0x07DE or 0x07FB) -- 0x07FB
		end,
		init_select    = function()
			--[[
			010668: 0C6C FFEF 0022           cmpi.w  #-$11, ($22,A4)                     ; THE CHALLENGER表示のチェック。
			01066E: 6704                     beq     $10674                              ; braにしてチェックを飛ばすとすぐにキャラ選択にいく
			010670: 4E75                     rts                                         ; bp 01066E,1,{PC=00F05E;g} にすると乱入の割り込みからラウンド開始前へ
			010672: 4E71                     nop                                         ; 4EF9 0000 F05E
			]]
			mem.wd32(0x10668, 0xC6CFFEF) -- 元の乱入処理
			mem.wd32(0x1066C, 0x226704) -- 元の乱入処理
			mem.wd08(0x1066E, 0x67) -- 元の乱入処理
		end,
		fast_select    = function()
			mem.wd32(0x10668, 0xC6CFFEF) -- 元の乱入処理
			mem.wd32(0x1066C, 0x226704) -- 元の乱入処理
			mem.wd08(0x1066E, 0x60) -- 乱入時にTHE CHALLENGER表示をさせない
		end,
		fast_restart   = function()
			mem.wd32(0x10668, 0x4EF90000) -- FIGHT表示から対戦開始(F05E)へ飛ばす
			mem.wd32(0x1066C, 0xF33A4E71) -- FIGHT表示から対戦開始
		end,
		all_bs         = function(enabled)
			if enabled then
				-- 全必殺技BS可能
				for addr = 0x085980, 0x085CE8, 2 do mem.wd16(addr, 0x007F|0x8000) end -- 0パワー消費 無敵7Fフレーム
				mem.wd32(0x039F24, 0x4E714E71)                            -- 6600 0014 nop化
			else
				local addr = 0x85980
				for _, b16 in ipairs(db.bs_data) do
					mem.wd16(addr, b16)
					addr = addr + 2
				end
				mem.wd32(0x39F24, 0x66000014)
			end
		end,
		fix_skip_frame = function(enabled)
			-- ガード解除モーションの進行処理
			-- 002800: 4A2D FEBF tst.b   (-$141,A5) 107EBF 暗転停止フレーム
			--         4A6D FEBE tst.w   (-$142,A5) にすべき
			mem.wd32(0x002800, enabled and 0x4A6DFEBE or 0x4A2DFEBF) -- 暗転の瞬間も加味する

			-- 着地ガー不が該当する無敵チェックの修正
			-- 元の処理は暗転フレームを加味していない
			--[[
			02327A: 4A2C 00B1                tst.b   ($b1,A4)               ; 無敵中？
			02327E: 6704                     beq     $23284                 ;
			023280: 4E75                     rts                            ;
			023282: 4E71                     nop                            ;
			023284: 197C 0001 00A9           move.b  #$1, ($a9,A4)          ; 無敵終わりをセット、更新されない場合は無敵継続
			02328A: 4E75                     rts                            ;
            02328C: 4A2D FEBF                tst.b   (-$141,A5)             ; 107EBF 暗転チェック
			]]
			-- 元の処理をNOPにして無敵フレームチェック+消費を伴う処理に移譲する
			mem.wd32(0x02327A, enabled and 0x44E714E71 or 0x4A2C00B1)
			mem.wd16(0x02327E, enabled and 0x44E71 or 0x6704)
			mem.wd16(0x023280, enabled and 0x44E71 or 0x4E75)
			mem.wd32(0x023284, enabled and 0x44E714E71 or 0x197C0001)
			mem.wd32(0x023288, enabled and 0x44E714E71 or 0x00A94E75)
			mem.wd32(0x02328C, enabled and 0x4A6DFEBE or 0x4A2DFEBF) -- 暗転の瞬間も加味する
		end,
		easy_move      = {
			real_counter = function(mode)        -- 1:OFF 2:ジャーマン 3:フェイスロック 4:投げっぱなしジャーマン"
				if mode > 1 then
					mem.wd16(0x0413EE, 0x1C3C)   -- ボタン読み込みをボタンデータ設定に変更
					mem.wd16(0x0413F0, 0x10 * (2 ^ (mode - 2))) -- 0x10, 0x20, 0x40
					mem.wd16(0x0413F2, 0x4E71)
				else
					mem.wd32(0x0413EE, 0x4EB90002)
					mem.wd16(0x0413F2, 0x6396)
				end
			end,
			esaka_check = function(mode)                       -- 詠酒の条件チェックを飛ばす 1:OFF
				mem.wd32(0x023748, mode == 2 and 0x4E714E71 or 0x6E00FC6A) -- 2:技種類と距離チェック飛ばす
				mem.wd32(0x0236FC, mode == 3 and 0x604E4E71 or 0x6400FCB6) -- 3:距離チェックNOP
			end,
			taneuma_finish = function(enabled)                 -- 自動 炎の種馬
				mem.wd16(0x04094A, enabled and 0x6018 or 0x6704) -- 連打チェックを飛ばす
			end,
			fast_kadenzer = function(enabled)                  -- 必勝！逆襲拳1発キャッチカデンツァ
				mem.wd16(0x04098C, enabled and 0x7003 or 0x5210) -- カウンターに3を直接設定する
			end,
			katsu_ca = function(enabled)                       -- 自動喝CA
				mem.wd08(0x03F94C, enabled and 0x60 or 0x67)   -- 入力チェックを飛ばす
				mem.wd16(0x03F986, enabled and 0x4E71 or 0x6628) -- 入力チェックをNOPに
			end,
			shikkyaku_ca = function(mode)                   -- 自動飛燕失脚CA
				local nc, shinku = false, false
				if mode == 2 or mode == 3 then nc = true end
				if mode == 2 or mode == 4 then shinku = true end
				mem.wd16(0x03DE48, nc and 0x4E71 or 0x660E) -- レバーN入力チェックをNOPに
				mem.wd16(0x03DE4E, nc and 0x4E71 or 0x6708) -- C入力チェックをNOPに
				mem.wd16(0x03DEA6, shinku and 0x4E71 or 0x6612) -- 一回転+C入力チェックをNOPに
			end,
			kara_ca = function(enabled)                        -- 空振りCAできる
				mem.wd08(0x02FA5E, enabled and 0x60 or 0x67)   -- テーブルチェックを飛ばす
				--[[ 未適用
				-- 逆にFFにしても個別にCA派生を判定している処理があるため単純に全不可にはできない。
				-- オリジナル（家庭用）
				-- maincpu.rd@02FA72=00000000
				-- maincpu.rd@02FA76=00000000
				-- maincpu.rd@02FA7A=FFFFFFFF
				-- maincpu.rd@02FA7E=00FFFF00
				-- maincpu.rw@02FA82=FFFF
				パッチ（00をFFにするとヒット時限定になる）
				for i = 0x02FA72, 0x02FA82 do mem.wd08(i, 0x00) end
				]]
			end,
			no_charge = function(enabled)        -- タメ時間なし
				mem.wd08(0x039570, enabled and 0x60 or 0x65) -- チェックを飛ばす
			end,
			cancel = function(enabled)
				-- キャンセル可否テーブルからデータ取得せずにFFを固定で設定する(C0 1100 0000 が必、D0 1101 0000 で連)
				mem.wd32(0x02ADAE, enabled and 0x70FF4E71 or 0x10300000) -- 02ADAE: 1030 0000 move.b (A0,D0.w), D0
				mem.wd32(0x02FAE4, enabled and 0x7EFF4E71 or 0x1E327000) -- 02FAE4: 1E32 7000 move.b (A2,D7.w), D7
				mem.wd32(0x02ADB8, enabled and 0x7EFF4E71 or 0x103C0001) -- 02ADB8: 103C 0001 move.b #$1, D0
				mem.wd32(0x076C1C, enabled and 0x70FF4E71 or 0x10300000) -- 076C1C: 1030 0000 move.b (A0,D0.w), D0
			end,
			triple_ecstasy = function(enabled)               -- 自動マリートリプルエクスタシー
				mem.wd08(0x041D00, enabled and 0x60 or 0x66) -- デバッグDIPチェックを飛ばす
			end,
			fast_recover = function(enabled)                 -- 高速気絶回復
				mem.wd32(0x02BD20, enabled and 0x1E3C0004 or 0x1E280001) -- 02BD20: 1E28 0001 move.b ($1,A0), D7
				mem.wd32(0x02BD66, enabled and 0x1C3C00F0 or 0x1C280002) -- 02BD66: 1C28 0002 move.b ($2,A0), D6
			end,
			hebi_damashi = function(enabled)                 -- 最速蛇だまし
				mem.wd16(0x042180, enabled and 0x6066 or 0x670E) -- 042180: 670E beq $42190
			end,
		},
		camerawork     = function(enabled)
			-- 演出のためのカメラワークテーブルを無視して常に追従可能にする
			mem.wd08(0x013AF8, enabled and 0x66 or 0x60) -- 013AF8: 6600 007C bne $13b76
			mem.wd08(0x013B20, enabled and 0x66 or 0x60) -- 013B20: 6600 0054 bne $13b76
			mem.wd08(0x013B2C, enabled and 0x66 or 0x60) -- 013B2C: 6600 0048 bne $13b76
			-- 画面の上限設定を飛ばす
			mem.wd08(0x013AF0, enabled and 0x67 or 0x60) -- 013AF0: 6700 0036 beq $13b28
			mem.wd08(0x013B9A, enabled and 0x6A or 0x60) -- 013B9A: 6A04      bpl $13ba0
		end,
		sadomazo_fix   = function(enabled)
			-- 逆襲拳、サドマゾの初段で相手の状態変更しない（相手が投げられなくなる事象が解消する） 057F40からの処理
			mem.wd08(0x057F43, enabled and 0x00 or 0x03)
		end,
		mvs_billy      = function(enabled)
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
				mem.wd32(0x02D442, 0x0C6C0010)
				mem.wd32(0x02D446, 0x00106618)
				mem.wd32(0x02D44A, 0x0C6C006E)
				mem.wd32(0x02D44E, 0x00626604)
				mem.wd32(0x02D452, 0x4E754E71)
				mem.wd32(0x02D456, 0x0C6C0070)
				mem.wd32(0x02D45A, 0x00626604)
				mem.wd32(0x02D45E, 0x4E754E71)
			end
		end,
	}
	local in_match             = false -- 対戦画面のときtrue
	local in_player_select     = false -- プレイヤー選択画面のときtrue
	local p_space              = 0  -- 1Pと2Pの間隔
	local prev_space           = 0  -- 1Pと2Pの間隔(前フレーム)

	local get_median_width     = function()
		local str = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		local tt = {}
		for i = 1, #str do
			table.insert(tt, man.ui:get_string_width(string.sub(str, i, i)))
		end
		table.sort(tt)
		if math.fmod(#tt, 2) == 0 then
			return (tt[#tt / 2] + tt[(#tt / 2) + 1]) / 2
		else
			return tt[math.ceil(#tt / 2)]
		end
	end

	local screen               = {
		offset_x = 0x20,
		offset_z = 0x24,
		offset_y = 0x28,
		left     = 0,
		top      = 0,
		s_width  = 2.672 * 0.95, -- math.max(, get_median_width() * scr.width * 0.95),
		s_height = man.ui.line_height * scr.height,
	}

	local get_word_len         = function(str)
		if not str then return 0 end
		str = type(str) ~= "string" and string.format("%s", str) or str
		local len = 0
		for _, c in utf8.codes(str) do len = len + (c < 0x80 and 1 or 2) end
		return len
	end

	local get_string_width     = function(str)
		if not str then return 0 end
		return screen.s_width * get_word_len(str)
	end

	local get_line_height      = function(lines)
		return screen.s_height * (lines or 1)
	end

	local hide_options         = {
		none = 0,
		effect = 2 ^ 0, -- ヒットマークなど
		shadow1 = 2 ^ 1, -- 影
		shadow2 = 2 ^ 2, -- 双角ステージの反射→影
		meters = 2 ^ 3, -- ゲージ
		background = 2 ^ 4, -- 背景
		p_chan = 2 ^ 5, -- Pちゃん
		p1_phantasm = 2 ^ 6, -- 1P残像
		p1_effect = 2 ^ 7, -- 1Pエフェクト
		p1_char = 2 ^ 8, -- 1Pキャラ
		p2_phantasm = 2 ^ 9, -- 2P残像
		p2_effect = 2 ^ 10, -- 2Pエフェクト
		p2_char = 2 ^ 11, -- 1Pキャラ
	}
	local global               = {
		frame_number         = 0,
		lag_frame            = false,
		both_act_neutral     = true,
		old_both_act_neutral = true,
		either_throw_indiv   = false,
		skip_frame           = false,
		fix_scr_top          = 1,
		shadow               = false,
		-- 当たり判定用
		axis_size            = 12,
		axis_size2           = 5,
		throwbox_height      = 200, --default for ground throws
		disp_bg              = true,
		fix_pos              = false,
		no_bars              = false,
		sync_pos_x           = 1, -- 1: OFF, 2:1Pと同期, 3:2Pと同期
		hitbox_bold          = 1,

		disp_pos             = 2, -- 向き・距離・位置表示 1;OFF 2:ON 3:向き・距離のみ 4:位置のみ
		hide                 = hide_options.none,
		disp_frame           = 2, -- フレームメーター表示 1:OFF, 2:ON:大表示, 3:ON:大表示(+1P情報), 4:ON:大表示(+2P情報)
		disp_input           = 1, -- コマンド入力状態表示 1:OFF 2:1P 3:2P
		disp_neutral_frames  = false, -- 通常動作フレーム非表示 1:OFF 2:ON
		pause_hit            = 1, -- 1:OFF, 2:ON, 3:ON:やられのみ 4:ON:投げやられのみ 5:ON:打撃やられのみ 6:ON:ガードのみ
		pause_hitbox         = 1, -- 判定発生時にポーズ 1:OFF, 2:投げ, 3:攻撃, 4:変化時
		pause                = false,
		replay_stop_on_dmg   = false, -- ダメージでリプレイ中段

		next_stg3            = 0,

		-- リバーサルとブレイクショットの設定
		dummy_bs_cnt         = 1, -- ブレイクショットのカウンタ
		dummy_rvs_cnt        = 1, -- リバーサルのカウンタ

		auto_input           = {
			otg_throw     = false, -- ダウン投げ
			sp_throw      = false, -- 必殺投げ
			otg_attack    = false, -- ダウン攻撃
			combo_throw   = false, -- 通常投げの派生技
			rave          = 1, -- デッドリーレイブ
			desire        = 1, -- アンリミテッドデザイア
			drill         = 1, -- ドリル
			kanku         = false, -- 閃里肘皇・貫空
			pairon        = 1, -- 超白龍
			real_counter  = 1, -- M.リアルカウンター
			auto_3ecst    = false, -- M.トリプルエクスタシー
			taneuma       = false, -- 炎の種馬
			katsu_ca      = false, -- 喝CA
			sikkyaku_ca   = 1, -- 飛燕失脚CA
			esaka_check   = false, -- 詠酒距離チェック
			fast_kadenzer = false, -- 必勝！逆襲拳
			kara_ca       = false, -- 空振りCA
			no_charge     = false, -- タメ時間なし
			cancel        = false, -- 全通常技キャンセル可能
			fast_recover  = false, -- 気絶回復
			hebi_damashi  = false, -- 最速蛇だまし
		},

		frzc                 = 1,
		frz                  = { 0x1, 0x0 }, -- DIPによる停止操作用の値とカウンタ

		dummy_mode           = 1,
		old_dummy_mode       = 1,
		rec_main             = nil,

		next_block_grace     = 0, -- 1ガードでの持続フレーム数
		crouch_block         = false, -- 可能な限りしゃがみガード
		life_mode            = 1, -- 体力ゲージ 1:自動回復 2:固定 3:通常動作
		pow_mode             = 2, -- POWモード　1:自動回復 2:固定 3:通常動作
		time_mode            = 1, -- タイム設定 1:無限:RB2(デフォルト) 2:無限:RB2 3:無限:SNK 4:90 5:60 6:30
		disp_meters          = true,
		repeat_interval      = 0,
		await_neutral        = false,
		replay_fix_pos       = 1, -- 開始間合い固定 1:OFF 2:位置記憶 3:1Pと2P 4:1P 5:2P
		replay_reset         = 2, -- 状態リセット   1:OFF 2:1Pと2P 3:1P 4:2P
		damaged_move         = 1,
		all_bs               = false,
		fix_skip_frame       = false,
		proceed_cpu          = false, -- CPU戦進行あり
		cpu_hardest          = true, -- CPU難度最高
		cpu_wait             = 4, -- CPU待ち時間 1:100% 2:75% 3:50% 4:25% 5:0%
		cpu_stg              = true, -- CPUステージ
		sokaku_stg           = true, -- 対戦双角ステージ
		mvs_billy            = false,
		sadomazo_fix         = false,
		snk_time             = 2,            -- タイムSNK表示
		disp_replay          = true,         -- レコードリプレイガイド表示
		save_snapshot        = 1,            -- 技画像保存 1:OFF 2:新規 3:上書き

		key_hists_newest_1st = true,         -- 新しいもの順
		key_hists            = 20,
		key_hists_y_offset   = get_line_height(1), -- px

		cmd_hist_limit       = 8,
		key_pos_hist_limit   = 1,
		estab_cmd_y_offset   = get_line_height(15), -- px

		frame_meter_limit    = 100,
		frame_meter_cell     = 3,
		frame_meter_y_offset = get_line_height(23), -- px

		rvslog               = false,
		mini_frame_limit     = 332,

		random_boolean       = function(true_ratio) return math.random() <= true_ratio end,
	}
	local safe_cb              = function(cb)
		return function(...)
			local status, ret_or_msg = pcall(cb, ...)
			if not status then
				emu.print_error(string.format('Error in callback: %s', ret_or_msg))
				return nil
			end
			return ret_or_msg
		end
	end
	mem.rg                     = function(id, mask) return (mask == nil) and cpu.state[id].value or (cpu.state[id].value & mask) end
	mem.pc                     = function() return cpu.state["CURPC"].value end
	mem.wp_cnt, mem.rp_cnt     = {}, {} -- 負荷確認のための呼び出す回数カウンター
	mem.wp                     = function(addr1, addr2, name, cb) return pgm:install_write_tap(addr1, addr2, name, safe_cb(cb)) end
	mem.rp                     = function(addr1, addr2, name, cb) return pgm:install_read_tap(addr1, addr2, name, safe_cb(cb)) end
	mem.wp08                   = function(addr, cb, filter)
		local num = global.holder.countup()
		local name = string.format("wp08_%x_%s", addr, num)
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
							--ut.printf("3 %x %x %x %x", data, mask, ret.value, (ret.value & 0xFF) | (0xFF00 & data))
							return (ret.value & 0xFF) | (0xFF00 & data)
						end
					end
					return data
				end)
		end
		safe_cb(cb)(mem.r08(addr), {})
		return global.holder.taps[name]
	end
	mem.wp16                   = function(addr, cb, filter)
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
		safe_cb(cb)(mem.r16(addr), {})
		--printf("register wp %s %x", name, addr)
		return global.holder.taps[name]
	end
	mem.wp32                   = function(addr, cb, filter)
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
		safe_cb(cb)(mem.r32(addr), {})
		return global.holder.taps[name]
	end
	mem.rp08                   = function(addr, cb, filter)
		local num = global.holder.countup()
		local name = string.format("rp08_%x_%s", addr, num)
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
							--ut.printf("3 %x %x %x %x", data, mask, ret.value, (ret.value & 0xFF) | (0xFF00 & data))
							return (ret.value & 0xFF) | (0xFF00 & data)
						end
					end
					return data
				end)
		end
		safe_cb(cb)(mem.r08(addr), {})
		return global.holder.taps[name]
	end
	mem.rp16                   = function(addr, cb, filter)
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
		safe_cb(cb)(mem.r16(addr), {})
		return global.holder.taps[name]
	end
	mem.rp32                   = function(addr, cb, filter)
		local num = global.holder.countup()
		local name = string.format("rp32_%x_%s", addr, num)
		global.holder.taps[name] = mem.rp(addr, addr + 3, name,
			function(offset, data, mask)
				mem.rp_cnt[addr] = (mem.rp_cnt[addr] or 0) + 1
				if filter and filter[mem.pc()] ~= true then return data end
				if offset == addr then cb(data << 0x10 | mem.r16(addr + 2)) end -- r32を行うと再起でスタックオーバーフローエラーが発生する
				return data
			end)
		safe_cb(cb)(mem.r32(addr))
		return global.holder.taps[name]
	end
	-- DIPスイッチ
	local dip_config           = {
		show_range    = false,
		show_hitbox   = false,
		infinity_life = false,
		easy_super    = false,
		semiauto_p    = false,
		aes_time      = 0x03, -- 残タイム家庭用オプション 0x0:45 0x1:60 0x2:90 0x3:infinity
		fix_time      = 0xAA,
		stage_select  = false,
		alfred        = false,
		watch_states  = false,
		cpu_cant_move = false,
		other_speed   = false,
		cpu_await     = false,
	}
	-- デバッグDIPのセット
	local set_dip_config       = function(on_menu)
		local dip1, dip2, dip3, dip4, dip5, dip6 = 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 -- デバッグDIP
		dip1 = dip1 | (in_match and dip_config.show_range and 0x40 or 0)        --cheat "DIP= 1-7 色々な判定表示"
		dip1 = dip1 | (in_match and dip_config.show_hitbox and 0x80 or 0)       --cheat "DIP= 1-8 当たり判定表示"
		dip1 = dip1 | (in_match and dip_config.infinity_life and 0x02 or 0)     --cheat "DIP= 1-2 Infinite Energy"
		dip2 = dip2 | (in_match and dip_config.easy_super and 0x01 or 0)        --Cheat "DIP 2-1 Eeasy Super"
		dip4 = dip4 | (in_match and dip_config.semiauto_p and 0x08 or 0)        -- DIP4-4
		dip2 = dip2 | ((dip_config.fix_time == 0xAA) and 0x18 or 0)             -- 2-4 PAUSEを消す + cheat "DIP= 2-5 Disable Time Over"
		mem.w08(0x10E024, dip_config.aes_time)                                  -- 残タイム家庭用オプション 0x0:45 0x1:60 0x2:90 0x3:infinity
		if (dip_config.fix_time == 0xAA) or on_menu then
			mem.w08(0x107C28, dip_config.fix_time)
			-- print("aes_time", dip_config.aes_time, "fix_time", dip_config.fix_time)
		end
		dip1 = dip1 | (dip_config.stage_select and 0x04 or 0)          --cheat "DIP= 1-3 Stage Select Mode"
		dip2 = dip2 | (in_player_select and dip_config.alfred and 0x80 or 0) --cheat "DIP= 2-8 Alfred Code (B+C >A)"
		dip2 = dip2 | (in_match and dip_config.watch_states and 0x20 or 0) --cheat "DIP= 2-6 Watch States"
		dip3 = dip3 | (in_match and dip_config.cpu_cant_move and 0x01 or 0) --cheat "DIP= 3-1 CPU Can't Move"
		dip3 = dip3 | (in_match and dip_config.other_speed and 0x10 or 0) --cheat "DIP= 3-5 移動速度変更"
		dip6 = dip6 | (in_match and dip_config.cpu_await and 0x80 or 0) -- 6-8：技を出すまでCOMキャラ停止
		for i, dip in ipairs({ dip1, dip2, dip3, dip4, dip5, dip6 }) do mem.w08(0x10E000 + i - 1, dip) end
	end

	-- キー入力
	local joy_k                = db.joy_k
	local joy_neutrala         = db.joy_neutrala

	local rvs_types            = db.rvs_types
	local hook_cmd_types       = db.hook_cmd_types

	local get_next_xs          = function(p, list, cur_menu, top_label_count)
		-- top_label_countはメニュー上部のラベル行数
		local sub_menu, ons = cur_menu[p.num][p.char], {}
		if sub_menu == nil or list == nil then return nil end
		for j, s in ipairs(list) do
			local idx = j + top_label_count
			if #list < idx then break end
			local col, row = sub_menu.pos.col[idx], sub_menu.list[idx]
			if col == 2 and (not row.ex_breakshot or global.all_bs) then table.insert(ons, s) end
		end
		if #ons == 0 then return nil end
		local idx = math.random(#ons)
		-- ut.printf("next %s %s/%s", top_label_count == 1 and "rvs" or "bs", idx, #ons)
		return ons[idx]
	end
	local get_next_rvs         = function(p) return get_next_xs(p, p.char_data and p.char_data.rvs or nil, menu.rvs_menus, 0) end
	local get_next_bs          = function(p) return get_next_xs(p, p.char_data and p.char_data.bs or nil, menu.bs_menus, 0) end

	local joy1, joy2, joys     = ":edge:joy:JOY1", ":edge:joy:JOY2", ":edge:joy:START"
	local use_joy              = {
		{ port = joy1, field = joy_k[1].a,  frame = 0, prev = 0, player = 1, get = 0, },
		{ port = joy1, field = joy_k[1].b,  frame = 0, prev = 0, player = 1, get = 0, },
		{ port = joy1, field = joy_k[1].c,  frame = 0, prev = 0, player = 1, get = 0, },
		{ port = joy1, field = joy_k[1].d,  frame = 0, prev = 0, player = 1, get = 0, },
		{ port = joy1, field = joy_k[1].dn, frame = 0, prev = 0, player = 1, get = 0, },
		{ port = joy1, field = joy_k[1].lt, frame = 0, prev = 0, player = 1, get = 0, },
		{ port = joy1, field = joy_k[1].rt, frame = 0, prev = 0, player = 1, get = 0, },
		{ port = joy1, field = joy_k[1].up, frame = 0, prev = 0, player = 1, get = 0, },
		{ port = joy2, field = joy_k[2].a,  frame = 0, prev = 0, player = 2, get = 0, },
		{ port = joy2, field = joy_k[2].b,  frame = 0, prev = 0, player = 2, get = 0, },
		{ port = joy2, field = joy_k[2].c,  frame = 0, prev = 0, player = 2, get = 0, },
		{ port = joy2, field = joy_k[2].d,  frame = 0, prev = 0, player = 2, get = 0, },
		{ port = joy2, field = joy_k[2].dn, frame = 0, prev = 0, player = 2, get = 0, },
		{ port = joy2, field = joy_k[2].lt, frame = 0, prev = 0, player = 2, get = 0, },
		{ port = joy2, field = joy_k[2].rt, frame = 0, prev = 0, player = 2, get = 0, },
		{ port = joy2, field = joy_k[2].up, frame = 0, prev = 0, player = 2, get = 0, },
		{ port = joys, field = joy_k[2].st, frame = 0, prev = 0, player = 2, get = 0, },
		{ port = joys, field = joy_k[1].st, frame = 0, prev = 0, player = 1, get = 0, },
	}

	local play_cursor_sound    = function()
		mem.w32(0x10D612, 0x600004)
		mem.w08(0x10D713, 0x1)
	end

	local new_next_joy         = function() return ut.deepcopy(joy_neutrala) end
	-- MAMEへの入力の無効化
	local cls_joy              = function()
		for _, joy in ipairs(use_joy) do ioports[joy.port].fields[joy.field]:set_value(0) end
	end

	-- ポーズ
	local set_freeze           = function(freeze) mem.w08(0x1041D2, freeze and 0x00 or 0xFF) end

	-- ボタンの色テーブル
	local btn_col              = { [ut.convert("_A")] = 0xFFCC0000, [ut.convert("_B")] = 0xFFCC8800, [ut.convert("_C")] = 0xFF3333CC, [ut.convert("_D")] = 0xFF336600, }
	local text_col, shadow_col = 0xFFFFFFFF, 0xFF000000

	local draw_text_helper     = function(x, y, str, align)
		local splits
		if type(str) == "table" then
			splits = str
		else
			if type(align) == "number" or align == "left" then
				str = type(str) ~= "string" and string.format("%s", str) or str
				splits = { str }
			else
				splits = type(str) ~= "string" and { string.format("%s", str) } or ut.split(str, "\n+")
			end
		end
		local resolver
		if align == "right" then
			resolver = function(s) return (x or scr.width) - get_string_width(s) end
		elseif align == "center" then
			resolver = function(s) return (x or (scr.width / 2)) - (get_string_width(s) / 2) end
		elseif align == "left" then
			resolver = function(s) return x or 0 end
		else
			error()
		end
		local i, ii, xx, yy, s = 1, nil, nil, nil, nil
		return function()
			while i <= #splits do
				i, ii, xx, yy, s = i + 1, i, resolver(splits[i]), y + get_line_height(i - 1), splits[i]
				if xx then return ii, s, xx, yy end -- インデックス, 行要素, x座標, y座標
			end
		end
	end

	--[[
	local draw_text                            = function(x, y, str, fgcol, bgcol)
		if not str then return end
		local align
		if type(x) == "string" then align, x = x, nil else align = "left" end
		for _, s, xx, yy in draw_text_helper(x, y, str, align) do
			scr:draw_text(xx, yy, s, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
		end
	end
	]]
	local draw_text                            = function(x, y, str, fgcol, bgcol)
		if not str then return end
		if type(str) == "table" then str = table.concat(str, "\n") end
		scr:draw_text(x, y, str, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
	end

	local draw_rtext                           = function(x, y, str, fgcol, bgcol)
		if not str then return end
		for _, s, xx, yy in draw_text_helper(x, y, str, "right") do
			scr:draw_text(xx, yy, s, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
		end
	end

	local draw_ctext                           = function(x, y, str, fgcol, bgcol)
		if not str then return end
		for _, s, xx, yy in draw_text_helper(x, y, str, "center") do
			scr:draw_text(xx, yy, s, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
		end
	end

	local draw_text_with_shadow                = function(x, y, str, fgcol, bgcol)
		if not str then return end
		local align
		if type(x) == "string" then align, x = x, nil else align = "left" end
		for _, s, xx, yy in draw_text_helper(x, y, str, align) do
			if global.shadow then scr:draw_text(xx + 0.5, yy + 0.5, s, shadow_col, bgcol or 0x00000000) end
			scr:draw_text(xx, yy, s, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
		end
	end

	local draw_rtext_with_shadow               = function(x, y, str, fgcol, bgcol)
		if not str then return end
		for _, s, xx, yy in draw_text_helper(x, y, str, "right") do
			if global.shadow then scr:draw_text(xx + 0.5, yy + 0.5, s, shadow_col, bgcol or 0x00000000) end
			scr:draw_text(xx, yy, s, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
		end
	end

	local draw_ctext_with_shadow               = function(x, y, str, fgcol, bgcol)
		if not str then return end
		for _, s, xx, yy in draw_text_helper(x, y, str, "center") do
			if global.shadow then scr:draw_text(xx + 0.5, yy + 0.5, s, shadow_col, bgcol or 0x00000000) end
			scr:draw_text(xx, yy, s, fgcol or 0xFFFFFFFF, bgcol or 0x00000000)
		end
	end

	-- コマンド文字列表示
	local draw_cmd_text_with_shadow            = function(x, y, str, fgcol, bgcol)
		if not str then return end
		-- 変換しつつUnicodeの文字配列に落とし込む
		local cstr, xx = ut.convert(str), x
		for c in string.gmatch(cstr, "([%z\1-\127\194-\244][\128-\191]*)") do
			-- 文字の影
			if global.shadow then scr:draw_text(xx + 0.5, y + 0.5, c, 0xFF000000) end
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

	local format_num                           = function(num) return string.sub(string.format("00%0.03f", num), -7) end

	-- コマンド入力表示
	local draw_cmd                             = function(p, line, frame, str, spid, max)
		local first_line = line == 1
		if global.key_hists_newest_1st then
			line = global.key_hists - line + 1
		end
		if not str then return end
		local _draw_text = draw_text -- draw_text_with_shadow
		local _draw_cmd_text = draw_cmd_text_with_shadow
		local xx, yy = p == 1 and 12 or 294, get_line_height(line) + global.key_hists_y_offset
		local col, spcol = 0xAAFFFFFF, 0x66DD00FF
		local x1, x2, step
		if p == 1 then x1, x2, step = 0, 50, 8 else x1, x2, step = 320, 270, -8 end
		if first_line then
			for xi = x1, x2, step do
				scr:draw_box(x1, get_line_height(2), xi + 1, get_line_height(max + 2), 0, 0x20303030)
			end
		end
		if spid then scr:draw_box(x1, yy + get_line_height(), x2, yy, 0, spcol) end
		for xi = x1, x2, step do
			scr:draw_line(x1, yy, xi + 1, yy, col)
			col = col - 0x18000000
		end
		if 0 < frame then
			local cframe = 999 < frame and "LOT" or string.format("%03d", frame)
			_draw_text(p == 1 and 1 or 283, yy, cframe, text_col)
		end
		_draw_cmd_text(xx, yy, str)
	end

	-- 処理アドレス表示
	local draw_base                            = function(p, bases)
		local _draw_text = draw_text -- draw_text_with_shadow
		local lines = {}
		for _, base in ipairs(bases) do
			local addr, act_name, xmov, cframe = base.addr, base.name, base.xmov, string.format("%03d", base.count)
			if 999 < base.count then cframe = "LOT" end
			local smov = (xmov < 0 and "-" or "+") .. string.format("%03d", math.abs(math.floor(xmov))) .. string.sub(string.format("%0.03f", xmov), -4)
			table.insert(lines, string.format("%3s %05X %8s %-s", cframe, addr, smov, act_name))
		end
		local xx = p == 1 and 48 or 160 -- 1Pと2Pで左右に表示し分ける
		scr:draw_box(xx, 80, xx + 112, 80 + get_line_height(#lines), 0, 0xA0303030)
		_draw_text(xx + 1, 80, lines, text_col)
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
		local pos_z = 24 - p.pos_z + 24
		dest.real_top = math.tointeger(math.max(dest.top, dest.bottom) + screen.top - pos_z - p.y)
		dest.real_bottom = math.tointeger(math.min(dest.top, dest.bottom) + screen.top - pos_z - p.y + 1)
		dest.real_front = math.tointeger(math.max(dest.left * -1, dest.right * -1) + (p.x - p.body.x) * p.flip_x)
		dest.real_back = math.tointeger(math.min(dest.left * -1, dest.right * -1) + (p.x - p.body.x) * p.flip_x)
		dest.left, dest.right = p.x - dest.left * p.flip_x, p.x - dest.right * p.flip_x
		dest.bottom, dest.top = p.y - dest.bottom, p.y - dest.top
		--ut.printf("%s ->b x=%s y=%s top=%s bottom=%s left=%s right=%s", prev, p.x, p.y, dest.top, dest.bottom, dest.left, dest.right)
		return dest
	end

	-- メモリエリアへパッチ適用して改造
	local execute_mod                          = function(before)
		mod.aes() -- AES化は常に適用
		if mem.pached then return end
		if before then before() end
		mem.pached = mem.pached or mod.p1_patch()
		mod.bugfix()
		mod.training(true)
		mod.cpu_hardest(global.cpu_hardest)
		mod.cpu_wait(global.cpu_wait)
		mod.cpu_stg(global.cpu_stg)
		mod.sokaku_stg(global.sokaku_stg)
		mod.snk_time(global.snk_time)
		print("load_rom_patch done")
	end

	-- ヒット効果アドレステーブルの取得
	db.hit_effects.menus, db.hit_effects.addrs = { "OFF" }, { 0 }
	for i, hit_effect in ipairs(db.hit_effects.list) do
		table.insert(db.hit_effects.menus, string.format("%02d %s", i, table.concat(hit_effect, " ")))
	end
	local load_hit_effects                             = function()
		if #db.hit_effects.addrs > 1 then return end
		for i, _ in ipairs(db.hit_effects.list) do
			table.insert(db.hit_effects.addrs, mem.r32(0x579DA + (i - 1) * 4))
		end
		print("load_hit_effects")
	end

	local load_hit_system_stops                        = function()
		if hit_system_stops.loaded then return end
		for addr = 0x57C54, 0x57CC0, 4 do hit_system_stops[mem.r32(addr)] = true end
		hit_system_stops.loaded = true
		print("load_hit_system_stops")
	end

	-- キャラの基本アドレスの取得
	local load_proc_base                               = function()
		if db.chars[1].proc_base then return end
		for char = 1, #db.chars - 1 do
			local char4 = char << 2
			db.chars[char].proc_base = {
				cancelable    = mem.r32(char4 + 0x850D8),
				forced_down   = 0x88A12,
				hitstop       = mem.r32(char4 + 0x083C58),
				damege        = mem.r32(char4 + 0x081410),
				stun          = mem.r32(char4 + 0x085CEA),
				stun_timer    = mem.r32(char4 + 0x085D4A),
				max_hit       = mem.r32(char4 + 0x0827D8),
				esaka         = mem.r32(char4 + 0x23750),
				pow_up        = ((0xC == char) and 0x8C274 or (0x10 == char) and 0x8C29C or 0x8C24C),
				pow_up_ext    = mem.r32(0x8C18C + char4),
				chip          = 0x095CEC,
				hitstun_fb    = 0x088592,
				hitstun1      = 0x095CEC,
				hitstun2      = 0x05AFB4, -- 0x16 + 0x2 + 0x05AF9C,
				blockstun     = 0x05AFC4, -- 0x1A + 0x2 + 0x05AFA8,
				bs_pow        = mem.r32(char4 + 0x85920),
				bs_invincible = mem.r32(char4 + 0x85920) + 0x1,
				sp_invincible = mem.r32(char4 + 0x8DE62),
				tw_invincible = mem.r32(char4 + 0x89692),
			}
		end
		db.chars[#db.chars].proc_base = { -- 共通枠に弾のベースアドレスを入れておく
			forced_down = 0x8E2C0,
			hitstop     = 0x088512,
			damege      = 0x088492,
			stun        = 0x088712,
			stun_timer  = 0x088792,
			max_hit     = 0x088612,
			baigaeshi   = 0x8E940,
			effect      = 0x095C0C - 0x20, -- 家庭用58232からの処理
			chip        = 0x095CEC,
			hitstun_fb  = 0x088592,
			hitstun1    = 0x095CEC,
			hitstun2    = 0x05AFB4, -- 0x16 + 0x2 + 0x05AF9C,
			blockstun   = 0x05AFC4, -- 0x1A + 0x2 + 0x05AFA8,
		}
		print("load_proc_base done")
	end

	-- 属性情報を数値に変換する
	local calc_attackbit                               = function(attackbits, p)
		local attackbit = 0
		for k, v, type in ut.find_all(attackbits, function(k) return frame_attack_types[k] end) do
			if k == "act_count" or k == "fb_effect" or k == "attack" or k == "act" then
				attackbit = attackbit | (v << type)
			elseif v == 1 or v == true then
				attackbit = attackbit | type
			end
		end
		if p.frame_gap > 0 then
			attackbit = attackbit | frame_attack_types.frame_plus
		elseif p.frame_gap < 0 then
			attackbit = attackbit | frame_attack_types.frame_minus
		end
		return attackbit
	end

	-- 接触判定の取得
	local load_push_box                                = function()
		if db.chars[1].push_box then return end
		-- キャラデータの押し合い判定を作成
		-- キャラごとの4種類の判定データをロードする
		for char = 1, #db.chars - 1 do
			db.chars[char].push_box_mask = mem.r32(0x5C728 + (char << 2))
			db.chars[char].push_box = {}
			for _, addr in ipairs({ 0x5C9BC, 0x5CA7C, 0x5CB3C, 0x5CBFC }) do
				local a2 = addr + (char << 3)
				local y1, y2, x1, x2 = mem.r08i(a2 + 0x1), mem.r08i(a2 + 0x2), mem.r08i(a2 + 0x3), mem.r08i(a2 + 0x4)
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

	local get_push_box                                 = function(p)
		-- 家庭用 05C6D0 からの処理
		local push_box = db.chars[p.char].push_box
		if p.char == db.char_id.geese and ut.tstb(p.flag_c8, db.flag_c8._15) then
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

	local fix_throw_box_pos                            = function(box)
		box.left, box.right = box.x - box.left * box.flip_x, box.x - box.right * box.flip_x
		box.bottom, box.top = box.y - box.bottom, box.y - box.top
		return box
	end

	-- 通常投げ間合い
	-- 家庭用0x05D78Cからの処理
	local get_normal_throw_box                         = function(p)
		-- 相手が向き合いか背向けかで押し合い幅を解決して反映
		local push_box, op_push_box = db.chars[p.char].push_box[0x5C9BC], db.chars[p.op.char].push_box[0x5C9BC]
		local op_edge = (p.block_side == p.op.block_side) and op_push_box.back or op_push_box.front
		local center = ut.int16(((push_box.front - math.abs(op_edge)) * p.box_scale) >> 6)
		local range = mem.r08(0x05D874 + p.char4)
		local left = center - range
		local right = center + range
		return fix_throw_box_pos({
			id = 0x100, -- dummy
			type = db.box_types.normal_throw,
			left = left,
			right = right,
			top = -0x05, -- 地上投げの範囲をわかりやすくする
			bottom = 0x05,
			x = p.pos - screen.left,
			y = screen.top - p.pos_y - p.pos_z,
			threshold = mem.r08(0x3A66C), -- 投げのしきい値 039FA4からの処理
			flip_x = p.block_side, -- 向き補正値
			real_top = 0,
			real_bottom = 0,
			real_front = -left,
			real_back = -right,
		})
	end

	-- 必殺投げ間合い
	local get_special_throw_box                        = function(p, id)
		local a0 = 0x3A542 + (0xFFFF & (id << 3))
		local top, bottom = mem.r16(a0 + 2), mem.r16(a0 + 4)
		local real_top, real_bottom = top, bottom
		if id == 0xA then
			top, bottom = 0x1FFF, 0x1FFF -- ダブルクラッチは上下無制限
			real_top, real_bottom = "∞", "∞"
		elseif top + bottom == 0 then
			top, bottom = 0x05, 0x05 -- 地上投げの範囲をわかりやすくする
			real_top, real_bottom = 0, 0
		end
		local left = -mem.r16(a0)
		local right = 0x0
		return fix_throw_box_pos({
			id = id,
			type = db.box_types.special_throw,
			left = left,
			right = right,
			top = top,
			bottom = -bottom,
			x = p.pos - screen.left,
			y = screen.top - p.pos_y - p.pos_z,
			threshold = mem.r08(0x3A66C + (0xFF & id)), -- 投げのしきい値 039FA4からの処理
			flip_x = p.block_side,             -- 向き補正値
			real_top = real_top,
			real_bottom = real_bottom,
			real_front = -left,
			real_back = -right,
		})
	end

	-- 空中投げ間合い
	-- MEMO: 0x060566(家庭用)のデータを読まずにハードコードにしている
	local get_air_throw_box                            = function(p)
		local left, right, top, bottom = -0x30, 0x0, -0x20, 0x20
		return fix_throw_box_pos({
			id = 0x200, -- dummy
			type = db.box_types.air_throw,
			left = -0x30,
			right = 0x0,
			top = -0x20,
			bottom = 0x20,
			x = p.pos - screen.left,
			y = screen.top - p.pos_y - p.pos_z,
			threshold = 0, -- 投げのしきい値
			flip_x = p.block_side, -- 向き補正値
			real_top = -top,
			real_bottom = -bottom,
			real_front = -left,
			real_back = right,
		})
	end

	local get_throwbox                                 = function(p, id)
		if id == 0x100 then
			return get_normal_throw_box(p)
		elseif id == 0x200 then
			return get_air_throw_box(p)
		end
		return get_special_throw_box(p, id)
	end

	local draw_hitbox                                  = function(box, do_fill)
		--ut.printf("%s  %s", box.type.kind, box.type.enabled)
		-- 背景なしの場合は判定の塗りつぶしをやめる
		local outline, fill = box.type.outline, global.disp_bg and box.type.fill or 0
		local x1, x2 = sort_ab(box.left, box.right)
		local y1, y2 = sort_ab(box.top, box.bottom)
		local b = global.hitbox_bold
		scr:draw_box(x1, y1, x1 - b, y2, 0, outline)
		scr:draw_box(x2, y1, x2 + b, y2, 0, outline)
		scr:draw_box(x1, y1, x2, y1 - b, 0, outline)
		scr:draw_box(x1, y2, x2, y2 + b, outline, outline)
		scr:draw_box(x1, y1, x2, y2, outline, do_fill and fill or 0)
		scr:draw_box(x1, y1, x2, y2, outline, do_fill and fill or 0)
		draw_ctext(x1 + (x2 - x1) / 2, y1 + (y2 - y1 - screen.s_height) / 2, string.format("%s-%X", box.no or "0", box.id), outline)
		--ut.printf("%s  x1=%s x2=%s y1=%s y2=%s",  box.type.kind, x1, x2, y1, y2)
	end

	local draw_range                                   = function(range, do_fill)
		local _draw_text = draw_text                                         -- draw_text_with_shadow
		local label, flip_x, x, y, col = range.label, range.flip_x, range.x, range.y, range.within and 0xFFFFFF00 or 0xFFBBBBBB
		local size = range.within == nil and global.axis_size or global.axis_size2 -- 範囲判定がないものは単純な座標とみなす
		local b = global.hitbox_bold
		scr:draw_box(x, y - size, x + flip_x, y + size, 0, col)
		scr:draw_box(x - size + flip_x, y, x + size, y - b, 0, col)
		_draw_text(x + ((flip_x > 0) and 2 or 1), y, label or "", col)
	end

	local border_box                                   = function(x1, y1, x2, y2, fcol, _, w)
		scr:draw_box(x1 - w, y1 - w, x2 + w, y1, fcol, fcol)
		scr:draw_box(x1 - w, y1 - w, x1, y2 + w, fcol, fcol)
		scr:draw_box(x2, y1 - w, x2 + 1, y2 + w, fcol, fcol)
		scr:draw_box(x1 - w, y2 + w, x2 + w, y2, fcol, fcol)
	end

	local border_waku                                  = function(x1, y1, x2, y2, fcol, _, w)
		scr:draw_box(x1, y1, x2, y2, fcol, 0)
		scr:draw_box(x1, y1 - w, x2, y1, fcol, fcol)
		scr:draw_box(x1, y2 + w, x2, y2, fcol, fcol)
	end

	-- 判定枠のチェック処理種類
	local hitbox_possible_map                          = {
		[0x01311C] = possible_types.none, -- 常に判定しない
		[0x012FF0] = possible_types.same_line, -- → 013038 同一ライン同士なら判定する
		[0x012FFE] = possible_types.both_line, -- → 013054 異なるライン同士でも判定する
		[0x01300A] = possible_types.unknown, -- → 013018 不明
		[0x012FE2] = possible_types.air_onry, -- → 012ff0 → 013038 相手が空中にいれば判定する
	}
	local get_hitbox_possibles_cache                   = {}
	local get_hitbox_possibles                         = function(id)
		if get_hitbox_possibles_cache[id] then return get_hitbox_possibles_cache[id] end
		local possibles = {}
		for k, addr_or_func in pairs(hitbox_possibles) do
			local ret = possible_types.none
			if type(addr_or_func) == "number" then
				-- 家庭用版 012DBC~012F04,012F30~012F96のデータ取得処理をベースに判定＆属性チェック
				local d2 = 0xFF & (id - 0x20)
				if d2 >= 0 then ret = hitbox_possible_map[mem.r32(0x13120 + (mem.r08(addr_or_func + d2) << 2))] end
			else
				ret = addr_or_func(id)
			end
			if possible_types.none ~= ret then possibles[k] = ret end
		end
		get_hitbox_possibles_cache[id] = possibles
		return possibles
	end

	local fix_box_type                                 = function(p, attackbit, box)
		attackbit = db.box_with_bit_types.mask & attackbit
		attackbit = attackbit & frame_attack_types.juggle_mask
		if box.attackbits then attackbit = attackbit | calc_attackbit(box.attackbits, p) end
		local type = p.in_sway_line and box.sway_type or box.type
		if type ~= db.box_types.attack then return type end
		local types = p.is_fireball and db.box_with_bit_types.fireballkv or db.box_with_bit_types.bodykv
		type = types[attackbit]
		if type then return type.box_type end
		types = p.is_fireball and db.box_with_bit_types.fireball or db.box_with_bit_types.body
		local hits = {}
		for _, t in ipairs(types) do
			if ut.tstb(attackbit, t.attackbit, true) then
				table.insert(hits, t.box_type)
				-- print("hit", #hits, t.box_type.name_en)
			end
		end
		if #hits > 0 then return hits[1] end
		ut.printf("fallback %s", ut.tobitstr(attackbit))
		return types[#types].box_type -- fallback
	end

	-- 遠近間合い取得
	local load_close_far                               = function()
		if db.chars[1].close_far then return end
		-- 地上通常技の近距離間合い 家庭用 02DD02 からの処理
		for org_char = 1, #db.chars - 1 do
			local char                   = org_char - 1
			local abc_offset             = mem.close_far_offset + (char * 4)
			local d_offset               = mem.close_far_offset_d + (char * 2)
			-- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
			db.chars[org_char].close_far = {
				[0x00] = {
					A = { x1 = 0, x2 = mem.r08(abc_offset) },
					B = { x1 = 0, x2 = mem.r08(abc_offset + 1) },
					C = { x1 = 0, x2 = mem.r08(abc_offset + 2) },
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
			get_lmo_range_internal(ret, "", mem.r08(mem.r32(0x2EE06 + 0x0 * 4) + org_char * 6), 0x2A000, true)
			ret["Cl"] = { x1 = 0, x2 = 72 }        -- 近距離の対メインライン攻撃になる距離
			if org_char == 6 then
				get_lmo_range_internal(ret, "Sp", 24, 0x40000) -- 渦炎陣
			elseif org_char == 14 then
				get_lmo_range_internal(ret, "Sp", 24, 0x80000) -- クロスヘッドスピン
			end
			-- printf("%s %s %x %s %x %s", chars[char].name, act_name, d0, d0, d1, decd1)
			db.chars[org_char].close_far[0x80] = ret
		end
		print("load_close_far done")
	end

	local reset_memory_tap                             = function(label, enabled, force)
		if not global.holder then return end
		local subs
		if label then
			local sub = global.holder.sub[label]
			if not sub then return end
			subs = { sub }
		else
			subs = global.holder.sub
		end
		for labels, sub in pairs(subs) do
			if (not enabled and sub.on == true) or force then
				sub.on = false
				for _, tap in pairs(sub.taps) do tap:remove() end
				ut.printf("Remove memory taps %s %s", labels, label)
			elseif enabled and sub.on ~= true then
				sub.on = true
				for _, tap in pairs(sub.taps) do tap:reinstall() end
				ut.printf("Reinstall memory taps %s %s", labels, label)
			end
		end
	end

	local load_memory_tap                              = function(label, wps) -- tapの仕込み
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
			for _, k in ipairs({ "wp08", "wp16", "wp32", "rp08", "rp16", "rp32", }) do
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

	local dummy_gd_type                                = {
		none   = 1, -- なし
		auto   = 2, -- オート
		hit1   = 3, -- 1ヒットガード
		block1 = 4, -- 1ガード
		high   = 5, -- 上段
		low    = 6, -- 下段
		action = 7, -- アクション
		random = 8, -- ランダム
		force  = 9, -- 強制
	}
	local wakeup_type                                  = {
		none = 1, -- なし
		rvs  = 2, -- リバーサル
		tech = 3, -- テクニカルライズ
		sway = 4, -- グランドスウェー
		atk  = 5, -- 起き上がり攻撃
	}
	local rvs_wake_types                               = ut.new_set(wakeup_type.tech, wakeup_type.sway, wakeup_type.rvs)

	local phase_count                                  = 1
	local players, all_objects, hitboxies, ranges, wps = {}, {}, {}, {}, { all = {}, select = {}, hide = {} }
	local is_ready_match_p                             = function()
		if #players ~= 2 then return false end
		return db.chars[players[1].char] and db.chars[players[2].char]
	end
	local hitboxies_order                              = function(b1, b2) return (b1.id < b2.id) end
	local ranges_order                                 = function(r1, r2) return (r1.within and 1 or -1) < (r2.within and 1 or -1) end
	local get_object_by_addr                           = function(addr, default) return all_objects[addr] or default end              -- ベースアドレスからオブジェクト解決
	local get_object_by_addr2                          = function(addr, _) return all_objects[addr] end                               -- ベースアドレスからオブジェクト解決
	local get_object_by_reg                            = function(reg, default) return all_objects[mem.rg(reg, 0xFFFFFF)] or default end -- レジストリからオブジェクト解決
	local now                                          = function(add) return global.frame_number + 1 + (add or 0) end
	local ggkey_create                                 = function(p1)
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
	local input                                        = { accepted = 0 }
	input.merge                                        = function(cmd1, cmd2)
		local mask = 0xFF
		for _, m in ut.ifind_all(db.cmd_rev_masks, function(m) return ut.tstb(cmd2, m.cmd) end) do
			mask = mask & m.mask
		end
		return (cmd1 & mask) | cmd2
	end
	input.read                                         = function(target_p, merge_bs_hook)
		-- 1Pと2Pの入力読取
		for i, p in ut.ifind_all(players, function(p) return not target_p or target_p == p.num end) do
			if not p.key then return end
			local status_b, reg_pcnt = mem.r08(p.addr.reg_st_b) ~ 0xFF, mem.r08(p.addr.reg_pcnt) ~ 0xFF
			local on1f, on5f, hold = mem.r08(p.addr.on1f), mem.r08(p.addr.on5f), mem.r08(p.addr.hold)
			if merge_bs_hook and p.bs_hook and p.bs_hook.cmd then
				reg_pcnt, on1f, on5f, hold = p.bs_hook.cmd, p.bs_hook.on1f, p.bs_hook.on5f, p.bs_hook.hold
			end
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

			local btn = 0xF0 & on1f
			if (btn ~= 0) and p.in_air and not ut.tstb(p.flag_d0, db.flag_d0._06) then
				local keybuff = ""
				for k, v in ut.find_all(db.cmd_bytes, function(_, v) return type(v) == "number" end) do
					if ut.tstb(btn, v) then
						keybuff = keybuff .. k
					end
				end
				table.insert(p.key.pos_hist, {
					on1f = on1f, label = keybuff, flip_x = p.flip_x,
					x = p.x + screen.left,
					y = p.y - screen.top,
				}) -- ジャンプ中のキー入力位置を保存
				while global.key_pos_hist_limit < #p.key.pos_hist do table.remove(p.key.pos_hist, 1) end --バッファ長調整
			end
		end
	end
	input.accept                                       = function(btn, state_past)
		---@diagnostic disable-next-line: undefined-global
		state_past = state_past or (scr:frame_number() - input.accepted)
		local on = { false, false }
		for _, p, state in ut.ifind_all(players, function(p) return p.key.state["_" .. btn] end) do
			on[p.num] = (12 < state_past) and (0 < state) and (type(btn) == "number" or (state <= state_past))
			on[p.num] = on[p.num] or ((20 < state) and (state % 10 == 0))
		end
		if on[1] or on[2] then
			play_cursor_sound()
			---@diagnostic disable-next-line: undefined-global
			input.accepted = scr:frame_number()
			return true, on[1], on[2]
		end
		return false, false, false
	end
	input.long_start                                   = function()
		-- ut.printf("long start %s %s %s", players[1].key.state._st, players[2].key.state._st)
		return 35 < math.max(players[1].key.state._st, players[2].key.state._st)
	end
	for i = 1, 2 do -- プレイヤーの状態など
		local p1   = (i == 1)
		local base = p1 and 0x100400 or 0x100500
		local p    = {
			num             = i,
			is_fireball     = false,
			base            = 0x0,
			dummy_act       = 1,         -- 立ち, しゃがみ, ジャンプ, 小ジャンプ, スウェー待機
			dummy_gd        = dummy_gd_type.none, -- なし, オート1, オート2, 1ヒットガード, 1ガード, 上段, 下段, アクション, ランダム, 強制
			bs              = false,     -- ブレイクショット
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
			fwd_prov        = true,      -- 挑発で自動前進

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
			disp_fb_frame   = true,      -- 弾のフレーム数表示するときtrue
			disp_stun       = true,      -- 気絶表示
			disp_state      = 1,         -- 状態表示 1:OFF 2:ON 3:ON:小表示 4:ON:フラグ表示 5:ON:ALL
			dis_plain_shift = false,     -- ラインずらさない現象
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
				cmd_hist = {},
				pos_hist = {}, -- ジャンプ中の入力位置
			},
			throw_boxies    = {},
			fireballs       = {},
			pos_hist        = ut.new_filled_table(3, { x = format_num(0), y = format_num(0), z = "00", pos = 0, pos_frc = 0, pos_y = 0, pos_frc_y = 0, }),
			away_anti_air   = {
				enabled = false,
				jump_limit1 = 75, -- 通常ジャンプ高度
				jump_limit2 = 50, -- 上りジャンプ攻撃高度
				jump_limit3 = 75, -- 下りジャンプ攻撃高度
				hop_limit1 = 45, -- 小ジャンプ高度
				hop_limit2 = 45, -- 上り小ジャンプ攻撃高度
				hop_limit3 = 60, -- 下り小ジャンプ攻撃高度
			},

			addr            = {
				base        = base,            -- キャラ状態とかのベースのアドレス
				control     = base + 0x12,     -- Human 1 or 2, CPU 3
				pos         = base + 0x20,     -- X座標
				pos_y       = base + 0x28,     -- Y座標
				cmd_side    = base + 0x86,     -- コマンド入力でのキャラ向きチェック用 00:左側 80:右側
				sway_status = base + 0x89,     -- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
				life        = base + 0x8B,     -- 体力
				pow         = base + 0xBC,     -- パワーアドレス
				hurt_state  = base + 0xE4,     -- やられ状態 ラインずらさない状態用
				stun_limit  = p1 and 0x10B84E or 0x10B856, -- 最大気絶値
				char        = p1 and 0x107BA5 or 0x107BA7, -- キャラID
				color       = p1 and 0x107BAC or 0x107BAD, -- カラー A=0x00 D=0x01
				stun        = p1 and 0x10B850 or 0x10B858, -- 現在気絶値
				stun_timer  = p1 and 0x10B854 or 0x10B85C, -- 気絶値ゼロ化までの残フレーム数
				reg_pcnt    = p1 and 0x300000 or 0x340000, -- キー入力 REG_P1CNT or REG_P2CNT アドレス
				reg_st_b    = 0x380000,        -- キー入力 REG_STATUS_B アドレス
				hold        = p1 and 0x1041AE or 0x1041B2,
				on5f        = p1 and 0x1041AF or 0x1041B3,
				on1f        = p1 and 0x1041B0 or 0x1041B4,
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
			reset_sp_hook   = function(hook)
				if hook and hook.cmd then
					local p = players[i]
					p.bs_hook = (p.bs_hook and p.bs_hook.cmd) and p.bs_hook or { cmd = db.cmd_types._5 }
					local cmd = hook.cmd
					cmd = type(cmd) == "table" and cmd[p.cmd_side] or cmd
					emu.print_info(global.frame_number .. ' cmd ')
					p.bs_hook = { cmd = cmd }
				else
					players[i].bs_hook = hook
				end
			end,
		}
		table.insert(players, p)
		p.body                     = p -- プレイヤーデータ自身、fireballとの互換用
		p.update_char              = function(data)
			data = data or mem.r08(p.addr.char)
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
		p.add_sp_establish_hist    = function(last_sp, exp, count, on_input_estab)
			if not exp or (0x10 <= last_sp and last_sp <= 0x13) then exp = 0 end
			local states = dip_config.easy_super and db.input_state_easy or db.input_state_normal
			states = states[p.char] or {}
			local states_count = mem.r16(mem.r32((dip_config.easy_super and 0xCA32E or 0xCA2CE) + p.char * 4))
			local addr = count and (states_count - count) * 0x4 + 0x2 or nil
			--ut.printf("%X %X %s %s %s %s %s", count or 0, addr or 0, dip_config.easy_super, count, #states[p.char], states == db.input_state_easy, states == db.input_state_normal)
			for _, tbl in ut.ifind_all(states, function(tbl)
				--[[
				ut.printf("%s %X %X | %X %X | %X %X %X %X | %s%s | %s",
					now(), states_count, count or 0,
					addr or 0, tbl.addr,
					tbl.id, tbl.estab or 0, last_sp or 0, exp or 0,
					string.sub(string.format("00%X", last_sp), -2), string.sub(string.format("0000%X", exp), -4),
					to_sjis(tbl.name_plain))
				]]
				if addr then return addr == tbl.addr else return tbl.id == last_sp and tbl.estab == exp end
			end) do
				tbl.on_input_estab = on_input_estab
				table.insert(p.key.cmd_hist, { txt = table.concat(tbl.lr_cmds[p.cmd_side]), time = now(60) })
				p.last_spids = p.last_spids or {}
				table.insert(p.last_spids, tbl.spid)
			end
			while global.cmd_hist_limit < #p.key.cmd_hist do table.remove(p.key.cmd_hist, 1) end --バッファ長調整
		end
		p.wp08                     = {
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
			[0x87] = function(data) p.flag_87, p.on_update_87 = data, now() end,   -- 80=動作中
			[0x88] = function(data) p.in_bs = data ~= 0 end,                       -- BS動作中
			[0x89] = function(data) p.sway_status, p.in_sway_line = data, data ~= 0x00 end, -- 80:奥ライン 1:奥へ移動中 82:手前へ移動中 0:手前
			[0x8B] = function(data, ret)
				p.life, p.on_damage = data, now()
				if global.life_mode ~= 3 then ret.value = math.max(data, 1) end -- 残体力がゼロだと次の削りガードが失敗するため常に1残すようにもする
			end,
			[0x8E] = function(data)
				local changed, n = p.state ~= data, now()
				p.on_block = data == 2 and n or p.on_block                                     -- ガードへの遷移フレームを記録
				p.on_hit = (data == 1 or data == 3) and n or p.on_hit                          -- ヒットへの遷移フレームを記録
				if p.state == 0 and p.on_hit == n and not p.act_data.neutral then p.on_punish = n + 10 end -- カウンターor確定反撃
				p.state, p.change_state = data, changed and n or p.change_state                -- 今の状態と状態更新フレームを記録
				if data == 2 or (data == 3 and p.old.state == 0) then
					p.update_tmp_combo(changed and 1 or 2)                                     -- 連続ガード用のコンボ状態リセット
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
					p.last_sp = data
				end
				if mem.pc() == 0x395B2 then
					local count = mem.rg("D0", 0xFFFF) + 1
					local exp = mem.r16(mem.rg("A6", 0xFFFFF) + 1) -- 追加データ
					if data ~= 0 or exp ~= 0 then p.add_sp_establish_hist(data, exp, count, now()) end
				end
			end,
			-- A4:必殺技コマンドの持続残F ?
			[0xA5] = function(data)
				if mem.pc() == 0x395BA then
					p.on_sp_established = now()
					if data ~= 0 then p.on_additional_w1 = now() end
				end
				p.additional = data
			end, -- 追加入力成立時のデータ
			--[0xAD] = function(data)  end, -- ガード動作用
			-- キャンセル可否テーブルのデータ取得 家庭用 02AD90 からの処理
			[0xAF] = function(data) -- キャンセル可否 00:不可 C0:可 D0:可 正確ではないかも
				p.cancelable_data = data
				p.cancelable = data & 0xC0 == 0xC0
				p.repeatable = data & 0xD0 == 0xD0
			end,
			[0x68] = function(data) p.skip_frame = data ~= 0 end, -- 潜在能力強制停止
			[0xB6] = function(data)
				if not p.char_data then return end
				-- 攻撃中のみ変化、判定チェック用2 0のときは何もしていない、 詠酒の間合いチェック用など
				p.attackbits.harmless = data == 0
				--ut.printf("harmless %X %s %s | %X %X | %s | %X %X %X | %s", mem.pc(), now(), p.on_hit, base, data, ut.tobitstr(data), p.act, p.act_count, p.act_frame, p.attackbits.harmless)
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
				p.last_attack_data  = p.attack
				p.on_update_attack  = now()
				p.attackbits.attack = data
				local base_addr     = p.char_data.proc_base
				p.forced_down       = 2 <= mem.r08(data + base_addr.forced_down) -- テクニカルライズ可否 家庭用 05A9BA からの処理
				-- ヒットストップ 家庭用 攻撃側:05AE2A やられ側:05AE50 からの処理 OK
				p.hitstop           = 0x7F & mem.r08(data + base_addr.hitstop)
				p.blockstop         = math.max(0, p.hitstop - 1) -- ガード時の補正
				p.damage            = mem.r08(data + base_addr.damege) -- 補正前ダメージ  家庭用 05B118 からの処理
				p.stun              = mem.r08(data + base_addr.stun) -- 気絶値 05C1CA からの処理
				p.stun_timer        = mem.r08(data + base_addr.stun_timer) -- 気絶タイマー 05C1CA からの処理
				p.max_hit_dn        = data > 0 and mem.r08(data + base_addr.max_hit) or 0
				p.multi_hit         = p.max_hit_dn > 1 or p.max_hit_dn == 0 or (p.char == db.char_id.mai and p.attack == 0x16)
				p.tw_muteki2        = data >= 0x70 and mem.r08(base_addr.tw_invincible + (0xFF & (data - 0x70))) or 0 -- 投げ無敵 家庭用 039FE4からの処理
				p.esaka_target      = false
				if 0x58 > data then
					-- 詠酒距離 家庭用 0236F0 からの処理
					local esaka           = mem.r16(base_addr.esaka + ((data + data) & 0xFFFF))
					p.esaka, p.esaka_type = esaka & 0x1FFF, db.esaka_type_names[esaka & 0xE000] or ""
					p.esaka_target        = p.esaka > 0
					if 0x27 <= data then                                    -- 家庭用 05B37E からの処理
						p.pow_up_hit = mem.r08((0xFF & (data - 0x27)) + base_addr.pow_up_ext) -- CA技、特殊技
					else
						p.pow_up_hit = mem.r08(base_addr.pow_up + data)     -- ビリー、チョンシュ、その他の通常技
					end
					p.pow_up_block = 0xFF & (p.pow_up_hit >> 1)             -- ガード時増加量 d0の右1ビットシフト=1/2
				end
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
				if data ~= 0 and data <= 0x1E then
					local sp2, proc_base      = (data - 1) * 2, p.char_data.proc_base
					p.bs_pow, p.bs_invincible = mem.r08(proc_base.bs_pow + sp2) & 0x7F, mem.r08(proc_base.bs_invincible + sp2)
					p.bs_invincible           = p.bs_invincible == 0xFF and 0 or p.bs_invincible
					p.sp_invincible           = mem.r08(proc_base.sp_invincible + data - 1)
					p.bs_invincible           = math.max(p.bs_invincible - 1, 0) -- 発生時に即-1される
					p.sp_invincible           = math.max(p.sp_invincible - 1, 0) -- 発生時に即-1される
				end
			end,
			[{ addr = 0xB9, filter = { 0x58930, 0x58948 } }] = function(data)
				if data == 0 and mem.pc() == 0x58930 then p.on_bs_clear = now() end            -- BSフラグのクリア
				if data ~= 0 and mem.pc() == 0x58948 then p.on_bs_established, p.last_bs = now(), data end -- BSフラグ設定
			end,
			[0xBC] = function(data) p.pow = data end,                                          -- パワー
			[0xCF] = function(data) p.on_update_ca = data == 0x01 and now() or p.on_update_ca end,
			[0xD0] = function(data) p.flag_d0 = data end,                                      -- フラグ群
			[{ addr = 0xD6, filter = 0x395A6 }] = function(data)
				p.on_sp_established, p.last_sp = now(), data                                   -- 技コマンド成立時の技のID
				local count = mem.rg("D0", 0xFFFF) + 1
				local exp = mem.r16(mem.rg("A6", 0xFFFFF) + 1)                                 -- 追加データ
				if data ~= 0 or exp ~= 0 then p.add_sp_establish_hist(data, exp, count, now()) end
			end,
			[0xE2] = function(data) p.sway_close = data == 0 end,
			--[0xE3] = function(data) p.on_last_frame = data == 0xFF and now(-1) or p.on_last_frame end,
			[0xE4] = function(data) p.hurt_state = data end,                       -- やられ状態
			[0xE8] = function(data, ret)
				if data < 0x10 and p.dummy_gd == dummy_gd_type.force then ret.value = 0x10 end -- 0x10以上でガード
			end,
			[0xEC] = function(data) p.push_invincible = data end,                  -- 押し合い判定の透過状態
			[0xEE] = function(data) p.in_hitstop_value, p.in_hitstun = data, ut.tstb(data, 0x80) end,
			[0xF6] = function(data) p.invincible = data end,                       -- 打撃と投げの無敵の残フレーム数
			-- [0xF7] = function(data) end -- 技の内部の進行度
			[{ addr = 0xFB, filter = { 0x49418, 0x49428, 0x42158 } }] = function(data)
				-- 0x49418, 0x49428 -- カイザーウェイブのレベルアップ
				-- 0x42158 蛇使いレベルアップ 5以上が大蛇
				local pc = mem.pc()
				if pc == 0x49418 or pc == 0x49428 or (0x42158 == pc and data == 5) then
					p.kaiserwave = p.kaiserwave or {}
					if (p.kaiserwave[pc] == nil) or p.kaiserwave[pc] + 1 < global.frame_number then p.on_update_spid = now() end
					p.kaiserwave[pc] = now()
				end
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
				mem.w08(p.addr.on5f, input.merge(mem.r08(p.addr.on5f), hook.on5f or hook.cmd)) -- 押しっぱずっと有効
				mem.w08(p.addr.hold, input.merge(mem.r08(p.addr.hold), hook.hold or hook.cmd)) -- 押しっぱ有効が5Fのみ
				ret.value = input.merge(data, hook.on1f or hook.cmd)               -- 押しっぱ有効が1Fのみ
			end,
		}
		local special_throws       = {
			[0x39E56] = function() return mem.rg("D0", 0xFF) end, -- 汎用
			[0x45ADC] = function() return 0x14 end,      -- ブレイクスパイラルBR
		}
		local special_throw_addrs  = ut.get_hash_key(special_throws)
		local add_throw_box        = function(p, box) p.throw_boxies[box.id] = box end
		local extra_throw_callback = function(data)
			if is_ready_match_p() then
				local pc = mem.pc()
				local id = special_throws[pc]
				if id then add_throw_box(p.op, get_special_throw_box(p.op, id())) end -- 必殺投げ
				if pc == 0x06042A then add_throw_box(p, get_air_throw_box(p)) end -- 空中投げ
			end
		end
		-- ドリル回数 0x42C3Eからのデータと合わせrう
		local drill_counts         = { 0x07, 0x09, 0x0B, 0x0C, 0x3C, } -- { 0x00, 0x01, 0x02, 0x03, 0x04, }
		local additional_buttons   = {
			--0x038FF8,
			--0x03DC74,
			--[0x03DE38] = 0x40, -- 失脚CA C  tst.w   ($fe,A4)とセット
			--[0x04213C] = 0x80, -- 蛇だまし btst    #$7, ($7e,A4)とセット
			[0x042BCA] = 0x40, -- ドリル
			--[0x048B16] = 0x20, -- ?
			--[0x049CD2] = 0x80, -- フェイクブラスト 動作とセット
			--[0x04A84C] = 0x20, -- ?
			[0x03F8FE] = 0x40, -- 喝CA
			[0x0410CC] = 0x70, -- M.カウンター
			[0x041796] = 0x26, -- ヤングダイブ ←+B受付
			[0x043C9E] = 0x0F, -- 心眼拳ワープ後 上左右受付
			[0x043D30] = 0xF0, -- 心眼拳ワープ後 ボタン受付
			[0x043F24] = 0x0F, -- 心眼拳ワープ後 左右受付
			[0x045196] = 0x40, -- 宿命拳 C受付
			[0x047BF4] = 0x10, -- 旋風棍 持続
			[0x05DA0C] = 0x02, -- 夏のおもひで
		}
		local additional_sps       = {
			{}, -- テリー・ボガード
			{}, -- アンディ・ボガード
			{ [0x2AA9A] = 0x08 --[[236C]], id = ut.new_set(0x08) }, -- 東丈
			{}, -- 不知火舞
			{}, -- ギース・ハワード
			{ [0x2AA9A] = 0x08 --[[623A]], id = ut.new_set(0x08) }, -- 望月双角
			{}, -- ボブ・ウィルソン
			{}, -- ホンフゥ
			{}, -- ブルー・マリー
			{}, -- フランコ・バッシュ
			{ [0x4239A] = 0x09 --[[ヤキ入れ→トドメ]], id = ut.new_set(0x09) }, -- 山崎竜二
			{ [0x2AA9A] = 0x07 --[[64C]], id = ut.new_set(0x07) }, -- 秦崇秀
			{}, -- 秦崇雷,
			{ [0x2AA9A] = 0x08 --[[旧ブレイクストーム]], id = ut.new_set(0x08) }, -- ダック・キング
			{}, -- キム・カッファン
			{ [0x2AA9A] = 0x07 --[[236C]], id = ut.new_set(0x07) }, -- ビリー・カーン
			{ [0x2AA9A] = 0x08 --[[44B]], id = ut.new_set(0x08) }, -- チン・シンザン
			{}, -- タン・フー・ルー,
			{ [0x2AA9A] = 0x06 --[[632C]], id = ut.new_set(0x06) }, -- ローレンス・ブラッド
			{ [0x2AA9A] = 0x09 --[[236C]], id = ut.new_set(0x09) }, -- ヴォルフガング・クラウザー
			{ [0x2AA9A] = 0x0C --[[33B]], [0x2AAD8] = 0x0B --[[22C]], id = ut.new_set(0x0B, 0x0C) }, -- リック・ストラウド
			{ [0x2AA9A] = 0x0B --[[66A]], id = ut.new_set(0x0B) }, -- 李香緋
			{}, -- アルフレッド
		}
		local check_add_button     = function(data, btn_frame)
			--ut.printf("%sF %X %X %X %X", btn_frame, data, mem.pc(), p.base, mem.r16(p.addr.base + 0xFE))
			local simple = additional_buttons[p.base]
			local wk, rk = string.format("on_additional_w%s", btn_frame), string.format("on_additional_r%s", btn_frame)
			if simple then
				if (simple & data) > 0 then p[wk] = now() else p[rk] = now() end
				return
			end
			if p.base == 0x03DE38 and mem.r16(p.addr.base + 0xFE) ~= 0 then -- 飛燕失脚CA C
				if (0x40 & data) > 0 then p[wk] = now() else p[rk] = now() end
			end
			if p.base == 0x04213C and (p.act == 0x87 or p.act == 0x91 or p.act == 0x9B) then -- 蛇だまし
				if (0x80 & data) > 0 then p[wk] = now() else p[rk] = now() end
			end
			if p.base == 0x049CD2 and p.act == 0x9C then -- フェイクブラスト
				if (0x80 & data) > 0 then p[wk] = now() else p[rk] = now() end
			end
		end
		p.rp08                     = {
			[{ addr = 0x12, filter = { 0x3DCF8, 0x49B2C } }] = function(data, ret)
				local check_count = 0
				if p.char == db.char_id.geese then check_count = global.auto_input.rave == 10 and 9 or (global.auto_input.rave - 1) end
				if p.char == db.char_id.krauser then check_count = global.auto_input.desire == 11 and 9 or (global.auto_input.desire - 1) end
				if mem.rg("D1", 0xFF) < check_count then ret.value = 0x3 end -- 自動デッドリー、自動アンリミ1
			end,
			[{ addr = 0x28, filter = ut.table_add_all(special_throw_addrs, { 0x6042A }) }] = extra_throw_callback,
			[{ addr = 0x8A, filter = { 0x5A9A2, 0x5AB34 } }] = function(data)
				local pc = mem.pc()
				if p.dummy_wakeup == wakeup_type.sway and pc == 0x5A9A2 then
					mem.w08(mem.rg("A0", 0xFFFFFF) + (data & 0x1) * 2, 2) -- 起き上がり動作の入力を更新
				elseif p.dummy_wakeup == wakeup_type.tech and pc == 0x5AB34 then
					mem.w08(mem.rg("A0", 0xFFFFFF) + (data & 0x1) * 2, 1) -- 起き上がり動作の入力を更新
				end
			end,
			[{ addr = 0x8E, filter = 0x39F8A }] = function(data)
				if is_ready_match_p() and 0x05CD70 == mem.rg("A0") then add_throw_box(p.op, get_normal_throw_box(p.op)) end -- 通常投げ
			end,
			[{ addr = 0x8F, filter = 0x5B41E }] = function(data, ret)
				-- 残体力を攻撃力が上回ると気絶値が加算がされずにフックが失敗するので、残体力より大きい値を返さないようにもする
				if global.life_mode ~= 3 then ret.value = math.min(p.life, data) end
				p.last_damage_scaled = data
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
			-- 着地暗転ガー不では無敵フラグチェックまでの隙間にヒットチェックが入るのでヒットチェック時のフレームを記録する
			[{ addr = 0xA9, filter = { 0x5C2B4, 0x5C2CC } }] = function(data) if data ~= 0 then p.on_hitcheck = now() end end,
			--[{ addr = 0xA5, filter = { 0x3DBE6, 0x49988, 0x42C26 } }] = function(data, ret)
			[0xA5] = function(data, ret)
				local pc = mem.pc()
				if not in_match or 0x100000 < pc or db.ignore_a5_pc[pc] then return end
				p.on_additional_r5 = now()
				if p.char == db.char_id.geese and global.auto_input.rave == 10 then ret.value = 0xFF end -- 自動デッドリー
				if p.char == db.char_id.krauser and global.auto_input.desire == 11 then ret.value = 0xFE end -- 自動アンリミ2
				if p.char == db.char_id.yamazaki and global.auto_input.drill == 5 then ret.value = 0xFE end -- 自動ドリルLv.5
			end,
			[{ addr = 0xB8, filter = { --[[0x3A6A4,]] 0x3AA62 } }] = function(data)              -- 必殺技IDチェック
				local ac = additional_sps[p.char]
				if not ac then return end
				if ac[p.base] == data then p.on_additional_wsp = now() elseif ac[p.base] then p.on_additional_rsp = now() end
			end,
			[{ addr = 0xB9, filter = { 0x396B4, 0x39756 } }] = function(data) p.on_bs_check = now() end, -- BSの技IDチェック
			[{ addr = 0xBF, filter = { 0x3BEF6, 0x3BF24, 0x5B346, 0x5B368 } }] = function(data)
				if data ~= 0 then                                                               -- 増加量を確認するためなのでBSチェックは省く
					local pc, pow_up = mem.pc(), 0
					if pc == 0x3BEF6 then
						local a3 = mem.r08(base + 0xA3) -- 必殺技発生時のパワー増加 家庭用 03C140 からの処理
						p.pow_up = a3 ~= 0 and mem.r08(mem.r32(0x8C1EC + p.char4) + a3 - 1) or 0
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
			[{ addr = p.addr.on1f, filter = { 0x0263AC } }] = function(data) check_add_button(data, 1) end, -- D7 = 押しっぱ  D6 = 押し1F有効
			[{ addr = p.addr.on5f, filter = { 0x026390 } }] = function(data) check_add_button(data, 5) end, -- D7 = 押しっぱ  D6 = 押し5F有効
			[{ addr = p.addr.hurt_state, filter = { 0x05A1A4, 0x05A43C, 0x05A48A } }] = function(data, ret) -- ラインずらさない状態
				if p.dis_plain_shift then ret.value = data | 0x40 end
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
				if not is_ready_match_p() then return end
				if not p.pos or not p.op.pos then return end
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
			[0xCC] = function(data)
				p.flag_cc, p.on_update_flag_cc = data, now()               -- フラグ群
			end,
			[p1 and 0x394C4 or 0x394C8] = function(data) p.input_offset = data end, -- コマンド入力状態のオフセットアドレス
		}
		all_objects[p.addr.base]   = p
	end
	players[1].op, players[2].op = players[2], players[1]
	for _, body in ipairs(players) do -- 弾領域の作成
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
			p.wp08 = {
				[0xB5] = function(data) p.fireball_rank = data end,
				[0xE7] = function(data) p.attackbits.fullhit, p.on_hit = data ~= 0, now() end,
				[0xE9] = function(data) p.on_hit = now() end,
				[0x8A] = function(data) p.parrieable1 = 0x2 >= data end,
				[0xA3] = function(data) p.firing = data ~= 0 end, -- 攻撃中に値が入る ガード判断用
			}
			p.wp16 = {
				[0x64] = function(data) p.actb = data end,
				[0xBE] = function(data)
					if data == 0 or not p.proc_active then return end
					if p.attack ~= data then p.clear_damages() end
					local base_addr = db.chars[#db.chars].proc_base
					p.attack        = data
					p.forced_down   = 2 <= mem.r08(data + base_addr.forced_down)       -- テクニカルライズ可否 家庭用 05A9D6 からの処理
					p.hitstop       = mem.r08(data + base_addr.hitstop)                -- ヒットストップ
					p.blockstop     = math.max(0, p.hitstop - 1)                       -- ガードストップ
					p.damage        = mem.r08(data + base_addr.damege)                 -- 補正前ダメージ 家庭用 05B146 からの処理
					p.stun          = mem.r08(data + base_addr.stun)                   -- 気絶値 家庭用 05C1B0 からの処理
					p.stun_timer    = mem.r08(data + base_addr.stun_timer)             -- 気絶タイマー 家庭用 05C1B0 からの処理
					p.max_hit_dn    = mem.r08(data + base_addr.max_hit)                -- 最大ヒット数 家庭用 061356 からの処理 OK
					p.multi_hit     = p.max_hit_dn > 1 or p.max_hit_dn == 0
					p.parrieable2   = mem.r08((0xFFFF & (data + data)) + base_addr.baigaeshi) == 0x01 -- 倍返し可否
					-- ut.printf("%x %s %s  hitstun %s %s", data, p.hitstop, p.blockstop, p.hitstun, p.blockstun)
				end,
			}
			local asm_is_active = function(asm) return asm ~= 0x4E75 and asm ~= 0x197C end
			p.wp32 = {
				[0x00] = function(data)
					p.base, p.asm     = data, mem.r16(data)
					local proc_active = in_match and asm_is_active(p.asm)
					local old_active  = in_match and asm_is_active(p.old.asm)
					local reset       = false
					if old_active and not proc_active then reset, p.on_prefb = true, now() * -1 end
					if not old_active and proc_active then reset, p.on_prefb = true, now() end
					if p.is_fireball and p.on_hit == now() and reset and not proc_active then
						p.delayed_inactive = now() + 1 -- ヒット処理後に判定と処理が終了されることの対応
						-- ut.printf("lazy inactive box %X %X", mem.pc(), data)
						return
					end
					if reset then
						p.parrieable, p.attack_id, p.attackbits = 0, 0, {}
						p.boxies, p.on_fireball, p.body.act_data = #p.boxies == 0 and p.boxies or {}, -1, nil
					end
					p.proc_active = proc_active
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
					p.hit_cancelable  = false
					p.cancelable_data = 0
					p.repeatable      = false
					p.hit_repeatable  = false
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
				if global.life_mode ~= 3 then
					if dip_config.infinity_life then
						mem.w08(p.addr.life, max_life)
						mem.w08(p.addr.stun_limit, init_stuns) -- 最大気絶値
						mem.w08(p.addr.init_stun, init_stuns) -- 最大気絶値
					elseif p.life_rec then
						if force or (p.addr.life ~= max_life and 180 < math.min(p.throw_timer, p.op.throw_timer)) then
							mem.w08(p.addr.life, max_life) -- やられ状態から戻ったときに回復させる
							mem.w08(p.addr.stun, 0) -- 気絶値
							mem.w08(p.addr.stun_limit, init_stuns) -- 最大気絶値
							mem.w08(p.addr.init_stun, init_stuns) -- 最大気絶値
							mem.w16(p.addr.stun_timer, 0) -- 気絶値タイマー
						elseif max_life < p.life then
							mem.w08(p.addr.life, max_life) -- 最大値の方が少ない場合は強制で減らす
						end
					end
				end

				-- パワーゲージ回復  POWモード　1:自動回復 2:固定 3:通常動作
				local fix_pow = { 0x3C, 0x1E, 0x00 }     -- 回復上限の固定値
				local max_pow = fix_pow[p.max] or (p.max - #fix_pow) -- 回復上限
				local cur_pow = mem.r08(p.addr.pow)      -- 現在のパワー値
				if global.pow_mode == 2 then
					mem.w08(p.addr.pow, max_pow)         -- 固定時は常にパワー回復
				elseif global.pow_mode == 1 and 180 < math.min(p.throw_timer, p.op.throw_timer) then
					mem.w08(p.addr.pow, max_pow)         -- 投げ無敵タイマーでパワー回復
				elseif global.pow_mode ~= 3 and max_pow < cur_pow then
					mem.w08(p.addr.pow, max_pow)         -- 最大値の方が少ない場合は強制で減らす
				end
			end
			p.init_state       = function(call_recover)
				p.input_states = {}
				p.char_data = db.chars[p.char]
				if call_recover then p.do_recover(true) end
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
				p.last_combo_attributes = {}
				p.clear_frame_data()
			end
			if not p.is_fireball then p.update_char() end
			p.init_state(false)
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
		local a4, sel              = mem.rg("A4", 0xFFFFFF), mem.r08(0x100026)
		local p_num, op_num, p_sel = mem.r08(a4 + 0x12), 0, {}
		op_num, p_sel[p_num]       = 3 - p_num, a4 + 0x13
		if sel == op_num and p_sel[op_num] then mem.w08(p_sel[p_num], op_num) end -- プレイヤー選択時に1P2P操作を入れ替え
	end
	table.insert(wps.all, {                                                 -- プレイヤー別ではない共通のフック
		wp08 = {
			[0x10B862] = function(data) mem._0x10B862 = data end,           -- 押し合い判定で使用
			[0x107EBF] = function(data) global.skip_frame2 = data ~= 0 end, -- 潜在能力強制停止
			--[0x107C1F] = function(data) global.skip_frame3 = data ~= 0 end, -- 潜在能力強制停止
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
		rp08 = {
			[{ addr = 0x107C1F, filter = 0x39456 }] = function(data)
				local p = get_object_by_reg("A4", {})
				local sp = p.bs_hook
				if not sp then return end
				if sp ~= p.dummy_rvs and sp == p.dummy_bs and p.base ~= 0x5893A then return end
				-- 自動必殺投げの場合は技成立データに別の必殺投げが含まれているならそれを優先させるために抜ける
				if sp.ver then
					if sp.auto_sp_throw and (sp.char == p.char) and db.sp_throws[mem.r08(p.addr.base + 0xA3)] then return end
					--ut.printf("bs_hook1 %x %x", sp.id, sp.ver)
					mem.w08(p.addr.base + 0xA3, sp.id)
					mem.w16(p.addr.base + 0xA4, sp.ver)
				else
					if sp.auto_sp_throw and (sp.char == p.char) and db.sp_throws[mem.r08(p.addr.base + 0xD6)] then return end
					--ut.printf("bs_hook2 %x %x", sp.id, sp.f)
					mem.w08(p.addr.base + 0xD6, sp.id)
					mem.w08(p.addr.base + 0xD7, sp.f)
				end
			end,
		},
		rp16 = {
			[{ addr = 0x107BB8, filter = {
				0xF6AC,                   -- BGMロード鳴らしたいので  --[[ 0x1589Eと0x158BCは雨発動用にそのままとする ]]
				0x17694,                  -- 必要な事前処理ぽいので
				0x1E39A,                  -- FIXの表示をしたいので
				0x22AD8,                  -- データロードぽいので
				0x22D32,                  -- 必要な事前処理ぽいので
			} }] = function(data, ret)
				if global.proceed_cpu then return end -- 通常CPU戦では無視する
				ret.value = 1             -- 双角ステージの雨バリエーション時でも1ラウンド相当の前処理を行う
			end,
			[mem.stage_base_addr + 0x46] = function(data, ret) if global.fix_scr_top > 1 then ret.value = data + global.fix_scr_top - 20 end end,
			[mem.stage_base_addr + 0xA4] = function(data, ret) if global.fix_scr_top > 1 then ret.value = data + global.fix_scr_top - 20 end end,
			[{ addr = 0x107EBE, filter = { 0x24C5E, 0x24CE2 } }] = function(data) global.skip_frame1 = data ~= 0 end, -- 潜在能力強制停止
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
	})
	table.insert(wps.hide, {
		wp08 = {
			[0x107C22] = function(data, ret)
				if ut.tstb(global.hide, hide_options.meters, true) and data == 0x38 then  -- ゲージのFIX非表示
					ret.value = 0x0
					mem.w08(0x10E024, 0x3)                                                -- 3にしないと0x107C2Aのカウントが進まなくなる
				end
				if ut.tstb(global.hide, hide_options.background, true) and mem.r08(0x107C22) > 0 then -- 背景消し
					mem.w08(0x107762, 0x00)
					mem.w16(0x401FFE, 0x5ABB)                                             -- 背景色
				end
			end,
		},
		rp08 = {
			[{ addr = 0x107765, filter = { 0x40EE, 004114, 0x413A } }] = function(_, ret)
				local pc = mem.pc()
				local a = mem.rg("A4", 0xFFFFFF)
				local b = mem.r32(a + 0x8A)
				local c = mem.r16(a + 0xA) + 0x100000
				local d = mem.r16(c + 0xA) + 0x100000
				local e = (mem.r32(a + 0x18) << 32) + mem.r32(a + 0x1C)
				local p_bases = { a, b, c, d, } -- ベースアドレス候補
				if db.p_chan[e] then ret.value = 0 end
				for i, addr, p in ut.ifind(p_bases, get_object_by_addr2) do
					--ut.printf("%s %s %6x", global.frame_number, i, addr)
					local num = p.body.num
					if i == 1 and ut.tstb(global.hide, hide_options["p" .. num .. "_char"], true) then
						ret.value = 4
					elseif i == 2 and ut.tstb(global.hide, hide_options["p" .. num .. "_phantasm"], true) then
						ret.value = 4
					elseif i >= 3 and ut.tstb(global.hide, hide_options["p" .. num .. "_effect"], true) then
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
	})
	table.insert(wps.select, {
		wp08 = {
			[{ addr = 0x107EC6, filter = 0x11DE8 }] = change_player_input,
		},
		rp08 = {
			[{ addr = 0x107EC6, filter = 0x11DC4 }] = function(data)
				if in_player_select ~= true then return end
				if data == mem.rg("D0", 0xFF) then change_player_input() end
			end,
		}
	})
	for base, p in pairs(all_objects) do
		-- 判定表示前の座標がらみの関数
		p.x, p.y, p.flip_x = 0, 0, 0
		p.calc_range_x = function(range_x) return p.x + range_x * p.flip_x end -- 自身の範囲の座標計算
		-- 自身が指定の範囲内かどうかの関数
		p.within = function(x1, x2) return (x1 <= p.op.x and p.op.x <= x2) or (x1 >= p.op.x and p.op.x >= x2) end

		p.wp08 = ut.hash_add_all(p.wp08, {
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
				p.hit_repeatable = p.flag_c8 == 0 and (data & 0x4) == 0x4 -- 連打キャンセル判定
				p.flip_x1 = ((data & 0x80) == 0) and 0 or 1   -- 判定の反転
				local fake = ((data & 0xFB) == 0 or ut.tstb(data, 0x8) == false)
				local fake_pc = mem.pc() == 0x11E1E and now() ~= p.on_hit -- ヒット時のフラグセットは嘘判定とはしない
				-- クラウザー6Aの攻撃判定なしの判定表示が邪魔なので嘘判定にする
				if p.body.char == db.char_id.krauser and p.act == 0x68 and p.act_count == 5 then fake_pc, fake = true, true end
				if p.body.char == db.char_id.mai then
					-- 舞小JA,小JCの攻撃判定なしの判定表示が邪魔なので嘘判定にする
					if ((p.act == 0x50 or p.act == 0x53) and p.act_count ~= 3) or ((p.act == 0x52 or p.act == 0x55) and p.act_count ~= 2) then fake_pc, fake = true, true end
				end
				p.attackbits.fake = fake_pc and fake
				-- if mem.pc() == 0x2D462 and p.char == db.char_id.billy and data == 0x8 then p.attackbits.fake = true end -- MVSビリーの判定なくなるバグの表現専用
				p.attackbits.obsolute = (not fake_pc) and fake
				if fake_pc and p.attackbits.harmless and p.on_update_act then p.attackbits.fake = true end
				-- ut.printf("%X %s %s | %X %X | %s | %s %s | %X %X %X | %s %s", mem.pc(), now(), p.on_hit, base, data, ut.tobitstr(data), fake_pc, fake, p.act, p.act_count, p.act_frame, p.attackbits.fake, p.attackbits.obsolute)
			end,
			[0x6F] = function(data) p.act_frame = data end, -- 動作パターンの残フレーム
			[0x71] = function(data) p.flip_x2 = (data & 1) end, -- 判定の反転
			[0x73] = function(data) p.box_scale = data + 1 end, -- 判定の拡大率
			--[0x76] = function(data) ut.printf("%X %X %X", base + 0x76, mem.pc(), data) end,
			[0x7A] = function(data)                    -- 攻撃判定とやられ判定
				if p.is_fireball and (p.on_hit == now()) and (data == 0) then
					p.delayed_clearing = now() + 1     -- ヒット処理後に判定が消去されることの対応
					-- ut.printf("lazy clean box %X %X", mem.pc(), data)
					return
				end
				-- ut.printf("%s %s box %x %x %x", now(), p.on_hit, p.addr.base, mem.pc(), data)
				p.boxies = {}
				if data <= 0 then return end
				p.attackbits.fb = p.is_fireball
				p.attackbits.attacking = false
				p.attackbits.juggle = false
				p.attackbits.fb_effect = 0
				p.attack_infos = {}
				if not p.body.char_data then p.body.update_char() end
				local base_addr = p.body.char_data.proc_base
				local a2base = mem.r32(base + 0x7A)
				local ai, counts, ids = {}, {}, {}
				for a2 = a2base, a2base + (data - 1) * 5, 5 do -- 家庭用 004A9E からの処理
					local id = mem.r08(a2)
					local top, bottom = sort_ba(mem.r08i(a2 + 0x1), mem.r08i(a2 + 0x2))
					local left, right = sort_ba(mem.r08i(a2 + 0x3), mem.r08i(a2 + 0x4))
					local type = db.main_box_types[id] or (id < 0x20) and db.box_types.unknown or db.box_types.attack
					local blockable, possible, possibles
					if type == db.box_types.attack and ids[id] == nil then
						ai = { attackbits = {} }
						ids[id] = ai
						table.insert(p.attack_infos, ai)
						-- ut.printf("%s %x %x %x", now(), p.addr.base, data, id)
						ai.attack_id           = id
						possibles              = get_hitbox_possibles(ai.attack_id)
						ai.effect              = mem.r08(ai.attack_id + db.chars[#db.chars].proc_base.effect) -- ヒット効果
						ai.attackbits.juggle   = possibles.juggle and true or false
						p.attackbits.attacking = true
						p.attackbits.juggle    = p.attackbits.juggle or ai.attackbits.juggle
						if p.is_fireball then
							p.attackbits.fb_effect = ai.effect
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
						if possibles.air_block then
							blockable = blockable | db.act_types.jump_attack -- 空中ガード可能
						end
						-- 判定の場所を加味しない属性を保存する
						ai.parrieable = 0
						for _, t in ipairs(hitbox_parry_types) do ai.parrieable = ai.parrieable | (possibles[t.name] and t.value or 0) end
						local d2 = 0xF & mem.r08(id + base_addr.hitstun1)
						ai.chip  = db.calc_chip(d2 + 1, ai.damage) -- 削りダメージ計算種別取得 05B2A4 からの処理
						if ai.parrieable1 then
							-- 硬直時間取得 05AF54(家庭用版)からの処理
							--local d = 0x7F & mem.r08(id + base_addr.hitstun_fb)
							--local d7 = (d <= 0) and 0x18 or 0
							--ai.hitstun, ai.blockstun = d7, d7
							--ut.printf("fb %X %X %X %X %X", id, ai.hitstun, ai.blockstun, d, d7)
							ai.hitstun, ai.blockstun = 0x18, 0x18
						elseif id then
							-- 硬直時間取得 05AF7C(家庭用版)からの処理
							ai.hitstun   = mem.r08(base_addr.hitstun2 + d2) -- ヒット硬直
							ai.blockstun = mem.r08(base_addr.blockstun + d2) -- ガード硬直
							--ut.printf("box %s %X %X %X %X", ai.num, id, ai.hitstun, ai.blockstun, ai.flag_cc & 0xE0)
						end
						p.attack_id = ai.attack_id
						p.last_attack_id = ai.last_attack_id
						p.chip = ai.chip
						p.effect = ai.effect
						p.hitstun = ai.hitstun
						p.blockstun = ai.blockstun
						p.parrieable = ai.parrieable
						p.parrieable1 = ai.parrieable1
						--[[
						for k, v in pairs(ai) do
							for _, xai in ipairs(p.attack_infos) do
								if ai[k] ~= xai[k] then
									ut.printf("mix attack key:%s id:%x value:%s | id:%x value:%s", k, id, v, xai["attack_id"], xai[k])
								end
							end
						end
						]]
					end
					counts[type.kind] = counts[type.kind] and (counts[type.kind] + 1) or 1
					table.insert(p.boxies, {
						no = counts[type.kind],
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
						attackbits = ids and ids[id] and ids[id].attackbits or {},
					})
					--[[
					ut.printf("p=%x %x %x %x %s addr=%x id=%02x knd=%s l=%s r=%s t=%s b=%s ps=%s bl=%s",
						p.addr.base, data, base, p.box_addr, 0, a2, id,
						type.kind,
						left, right, top, bottom,
						possible, blockable)
					]]
				end
				-- ut.printf("%s %s box %x %x %x %s", now(), p.on_hit, p.addr.base, mem.pc(), data, #p.boxies)
			end,
			[0x8D] = function(data)
				p.hitstop_remain, p.in_hitstop = data, (data > 0 or (p.hitstop_remain and p.hitstop_remain > 0)) and now() or p.in_hitstop -- 0になるタイミングも含める
			end,
			[{ addr = 0x94, filter = { 0x434C8, 0x434E0 } }] = function(data) p.drill_count = data end,                        -- ドリルのCカウント 0x434C8 Cカウント加算, 0x434E0 C以外押下でCカウントリセット
			[0xAA] = function(data)
				p.attackbits.fullhit = data ~= 0
				-- ut.printf("full %X %s %s | %X %X | %s | %X %X %X | %s", mem.pc(), now(), p.on_hit, base, data, ut.tobitstr(data), p.act, p.act_count, p.act_frame, p.attackbits.fullhit)
				if p.is_fireball and data == 0xFF then p.on_fireball = now() * -1 end
				local fake = true
				if data == 0xFF and p.is_fireball and p.body.char == db.char_id.billy and p.act == 0x266 then
					-- 三節棍中段打ちの攻撃無効化、判定表示の邪魔なのでここで判定を削除する
				elseif data == 0xFF and p.is_fireball and p.body.char == db.char_id.sokaku and p.act == 0x274 then
					-- まきびしの攻撃無効化、判定表示の邪魔なのでここで判定を削除する
				elseif data == 0xFF and p.is_fireball and p.body.char == db.char_id.chonshu and (p.act == 0x26F or p.act == 0x26C) then
					-- 帝王漏尽拳の攻撃無効化、判定表示の邪魔なのでここで判定を削除する
				elseif data == 0xFF and p.is_fireball and p.body.char == db.char_id.chonrei and p.act == 0x266 then
					-- 帝王漏尽拳の攻撃無効化、判定表示の邪魔なのでここで判定を削除する
				else
					fake = false
				end
				if fake then p.boxies, p.attackbits.fake = {}, true end
			end,
			[0xAB] = function(data) p.max_hit_nm = data end,                                   -- 同一技行動での最大ヒット数 分子
			[0xB1] = function(data) p.hurt_invincible = data > 0 end,                          -- やられ判定無視の全身無敵
			[0xE9] = function(data) p.dmg_id = data end,                                       -- 最後にヒット/ガードした技ID
			[0xEB] = function(data) p.hurt_attack = data end,                                  -- やられ中のみ変化
			[{ addr = 0xF1, filter = { 0x408D4, 0x40954 } }] = function(data) p.drill_count = data end, -- 炎の種馬の追加連打の成立回数
		})
		p.wp16 = ut.hash_add_all(p.wp16, {
			[0x20] = function(data) p.pos, p.max_pos, p.min_pos = data, math.max(p.max_pos or 0, data), math.min(p.min_pos or 1000, data) end,
			[0x22] = function(data) p.pos_frc = ut.int16tofloat(data) end, -- X座標(小数部)
			[0x24] = function(data)
				local nowv        = now()
				p.on_sway_line    = (p.pos_z ~= 40 and 40 == data) and nowv or p.on_sway_line
				p.on_main_line    = (p.pos_z ~= 24 and 24 == data) and nowv or p.on_main_line
				p.on_main_to_sway = (p.pos_z == 24 and data ~= 24) and nowv or p.on_main_to_sway
				p.pos_z           = data                                                                  -- Z座標
			end,
			[0x28] = function(data) p.pos_y = ut.int16(data) end,                                         -- Y座標
			[0x2A] = function(data) p.pos_frc_y = ut.int16tofloat(data) end,                              -- Y座標(小数部)
			[{ addr = 0x5E, filter = 0x011E10 }] = function(data) p.box_addr = mem.rg("A0", 0xFFFFFFFF) - 0x2 end, -- 判定のアドレス
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
		table.insert(wps.all, p)
	end
	-- 場面変更
	local apply_1p2p_active  = function()
		if global.proceed_cpu then return end                                    -- 通常CPU戦のため修正せず抜ける
		for _, p in ipairs(players) do mem.w16(p.addr.control, 0x0101 * p.control) end -- Human 1 or 2, CPU 3
		if in_match and mem.r08(0x1041D3) == 0 then
			mem.w08(0x100024, 0x03)
			mem.w08(0x100027, 0x03)
		end
	end

	local goto_player_select = function(p_no)
		mod.fast_select()
		mem.w08(0x1041D3, 0x01) -- 乱入フラグON
		mem.w08(0x107BB5, 0x01)
		mem.w32(0x107BA6, 0x00010001) -- CPU戦の進行数をリセット
		if p_no == 2 then
			mem.w32(0x100024, 0x02020002)
			mem.w16(0x10FDB6, 0x0202)
		else
			mem.w32(0x100024, 0x01010001)
			mem.w16(0x10FDB6, 0x0101)
		end
		if global.proceed_cpu then
			--mem.w16(players[p_no].addr.control, 0x0101 * (players[p_no].control or 1)) -- Human 1 or 2, CPU 3
			--mem.w16(players[3 - p_no].addr.control, 0x0101 * 3) -- Human 1 or 2, CPU 3
			--mem.w16(0x1041D6, p_no) -- 対戦モード
		else
			mem.w16(0x1041D6, 0x0003) -- 対戦モード=対戦
		end
	end

	local restart_fight      = function(param)
		param              = param or {}
		global.next_stg3   = param.next_stage.stg3 or mem.r16(0x107BB8)
		local p1, p2       = param.next_p1 or 1, param.next_p2 or 21
		local p1col, p2col = param.next_p1col or 0x00, param.next_p2col or 0x01
		mod.fast_restart()
		if global.proceed_cpu ~= true then
			-- 通常CPU戦回避のための設定
			mem.w08(0x1041D3, 0x01) -- 乱入フラグON
			mem.w08(0x107C1F, 0x00) -- キャラデータの読み込み無視フラグをOFF
			mem.w32(0x107BA6, 0x00010001) -- CPU戦の進行数をリセット
			mem.w08(0x100024, 0x03)
			mem.w08(0x100027, 0x03)
			mem.w16(0x10FDB6, 0x0101)

			mem.w16(0x1041D6, 0x0003) -- 対戦モード3
		end
		mem.w08(0x107BB1, param.next_stage.stg1 or mem.r08(0x107BB1))
		mem.w08(0x107BB7, param.next_stage.stg2 or mem.r08(0x107BB7))
		mem.w16(0x107BB8, global.next_stg3) -- ステージのバリエーション
		mem.w08(players[1].addr.char, p1)
		mem.w08(players[1].addr.color, p1col)
		mem.w08(players[2].addr.char, p2)
		if p1 == p2 then p2col = p1col == 0x00 and 0x01 or 0x00 end
		mem.w08(players[2].addr.color, p2col)
		mem.w16(0x10A8D4, param.next_bgm or 21) -- 対戦モード3 BGM
		mem.r16(0x107BA6, param.next_bgm or 21) -- 対戦モード3 BGM

		-- メニュー用にキャラの番号だけ差し替える
		players[1].char, players[2].char = p1, p2
	end

	-- レコード＆リプレイ
	local recording          = {
		max_frames      = 3600,
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
		info1           = { { label = "● RECORDING #%s %s", col = 0xFFFF1133 }, { label = "", col = 0xFFFF1133 } },
		info2           = { { label = "▶ REPLAYING #%s %s", col = 0xFFFFFFFF }, { label = "HOLD START to MEMU", col = 0xFFFFFFFF } },
		info3           = { { label = "■ PRESS START to REPLAY #%s", col = 0xFFFFFFFF }, { label = "HOLD START to MEMU", col = 0xFFFFFFFF } },
		info4           = { { label = "● POSITION REC #s", col = 0xFFFF1133 }, { label = "PRESS START to MENU", col = 0xFFFF1133 } },

		procs           = {
			await_no_input = nil,
			await_1st_input = nil,
			await_play = nil,
			await_fixpos = nil,
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
	local cls_ps = function() for _, p in ipairs(players) do p.init_state(true) end end

	-- リプレイ開始位置記憶
	recording.procs.fixpos = function()
		recording.info   = recording.info4
		local fixpos2    = {
			p1 = {
				w08 = {
					[0x100458] = mem.r08(0x100458), -- 1P 向き
					[0x100486] = mem.r08(0x100486), -- 1P コマンド入力向き
					[0x100489] = mem.r08(0x100489), -- 1P ライン状態
				},
				w16 = {},
				w32 = {
					[0x100420] = mem.r32(0x100420), -- 1P X
					[0x100424] = mem.r32(0x100424), -- 1P Y
					[0x100428] = mem.r32(0x100428), -- 1P Z
				}
			},
			p2 = {
				w08 = {
					[0x100558] = mem.r08(0x100558), -- 2P 向き
					[0x100586] = mem.r08(0x100586), -- 2P コマンド入力向き
					[0x100589] = mem.r08(0x100589), -- 2P ライン状態
				},
				w16 = {},
				w32 = {
					[0x100520] = mem.r32(0x100520), -- 2P X
					[0x100524] = mem.r32(0x100524), -- 2P X
					[0x100528] = mem.r32(0x100528), -- 2P X
				}
			},
			stg = {
				w08 = {},
				w16 = {
					[0x100E7C] = mem.r16(0x100E7C), -- ステージ
				},
				w32 = {
					[0x100E20] = mem.r32(0x100E20), -- ステージ X
					[0x100E24] = mem.r32(0x100E24), -- ステージ Y
					[0x100E28] = mem.r32(0x100E28), -- ステージ Z
					[0x100E2C] = mem.r32(0x100E2C), -- ステージ
					[0x100E30] = mem.r32(0x100E30), -- ステージ
					[0x100E34] = mem.r32(0x100E34), -- ステージ
					[0x100E38] = mem.r32(0x100E38), -- ステージ
					[0x100E3C] = mem.r32(0x100E3C), -- ステージ
					[0x10B1A4] = mem.r32(0x10B1A4),
				}
			},
		}
		recording.fixpos = { fixpos2 = fixpos2, }
	end
	-- 初回入力まち
	-- 未入力状態を待ちける→入力開始まで待ち受ける
	recording.procs.await_no_input = function(_)
		if players[recording.temp_player].key.reg_pcnt == 0 then -- 状態変更
			global.rec_main = recording.procs.await_1st_input
			ut.printf("%s await_no_input -> await_1st_input %s", global.frame_number, recording.temp_player)
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
			ut.printf("%s await_1st_input -> input", global.frame_number)
		end
	end
	recording.procs.input = function(_) -- 入力中+入力保存
		if recording.max_frames <= #recording.active_slot.store then
			menu.state = menu        -- メニュー表示に強制遷移
			menu.set_current("recording")
			return
		end
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
			global.rec_main = recording.procs.await_fixpos
			recording.fixpos.await_fixpos_frame = global.frame_number
			ut.printf("%s await_play -> await_fixpos", global.frame_number)

			-- メインラインでニュートラル状態にする
			for i, p in ipairs(players) do
				-- 状態リセット   1:OFF 2:1Pと2P 3:1P 4:2P
				if global.replay_reset == 2 or (global.replay_reset == 3 and i == 3) or (global.replay_reset == 4 and i == 4) then
					for fnc, tbl in pairs({
						[mem.w16i] = { [0x28] = 0, [0x24] = 0x18, },
						[mem.w16] = { [0x60] = 0x1, [0x64] = 0xFFFF, [0x6E] = 0, },
						-- 0x58D5A = やられからの復帰処理  0x261A0: 素立ち処理
						[mem.w32] = { [p.addr.base] = 0x58D5A, [0x28] = 0, [0x34] = 0, [0x38] = 0, [0x3C] = 0, [0x44] = 0, [0x48] = 0, [0x4C] = 0, [0x50] = 0, [0xDA] = 0, [0xDE] = 0, },
						[mem.w08] = { [0x61] = 0x1, [0x63] = 0x2, [0x65] = 0x2, [0x66] = 0, [0x6A] = 0, [0x7E] = 0, [0xB0] = 0, [0xB1] = 0, [0xC0] = 0x80, [0xC2] = 0, [0xFC] = 0, [0xFD] = 0, [0x89] = 0, },
					}) do for addr, value in pairs(tbl) do fnc(addr, value) end end
					p.do_recover(true)
					p.old.frame_gap = 0
				end
			end

			-- 入力リセット
			local next_joy = new_next_joy()
			for _, joy in ipairs(use_joy) do to_joy[joy.field] = next_joy[joy.field] or false end
			return
		end
	end
	-- 開始位置調整
	recording.procs.await_fixpos = function(_)
		-- 開始間合い固定 1:OFF 2:位置記憶 3:1Pと2P 4:1P 5:2P
		local fixpos = recording.fixpos
		if fixpos and global.replay_fix_pos and global.replay_fix_pos ~= 1 then
			local timeout = ((fixpos.await_fixpos_frame + 8) <= global.frame_number)
			local memrs = { w08 = mem.r08, w16 = mem.r16, w32 = mem.r32, }
			local fixmem = function(obj)
				local fixed = true
				for m, datas in pairs(obj) do
					local memw, memr = mem[m], memrs[m]
					for addr, data in pairs(datas) do
						local currdata = memr(addr)
						if currdata ~= data then
							fixed = false
							memw(addr, data)
							ut.printf("%s fixpos[%s] %s %X %X -> %X", global.frame_number, global.frame_number - fixpos.await_fixpos_frame, m, addr, currdata, data)
						end
					end
				end
				return fixed
			end
			-- 2:位置記憶
			local all_fixed = fixmem(fixpos.fixpos2.stg)
			-- 3:1Pと2P 4:1P
			if global.replay_fix_pos == 3 or global.replay_fix_pos == 4 then all_fixed = fixmem(fixpos.fixpos2.p1) and all_fixed end
			-- 3:1Pと2P 5:2P
			if global.replay_fix_pos == 3 or global.replay_fix_pos == 5 then all_fixed = fixmem(fixpos.fixpos2.p2) and all_fixed end
			if all_fixed or timeout then
				global.rec_main = recording.procs.play
				ut.printf("%s await_fixpos -> play", global.frame_number)
			else
				-- 補正位置に戻りきるまでループさせる
				global.rec_main = recording.procs.await_fixpos
				ut.printf("%s await_fixpos -> await_fixpos", global.frame_number)
			end
		else
			global.rec_main = recording.procs.play
			ut.printf("%s await_fixpos -> play", global.frame_number)
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
					ut.printf("%s repeat_play -> await_play(force)", global.frame_number)
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
			ut.printf("%s play -> await_play", global.frame_number)
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
			ut.printf("%s play -> play_interval", global.frame_number)
		end
	end

	-- リプレイまでの待ち時間
	recording.procs.play_interval = function(_)
		if input.accept("st") then
			-- 状態変更
			global.rec_main = recording.procs.await_play
			ut.printf("%s play_interval -> await_play", global.frame_number)
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
				ut.printf("%s play_interval -> repeat_play", global.frame_number)
				return
			else
				-- 状態変更
				global.rec_main = recording.procs.await_play
				ut.printf("%s play_interval -> await_play", global.frame_number)
				return
			end
		end
	end
	--

	local frame_meter = { limit = global.frame_meter_limit, cell = global.frame_meter_cell, y_offset = global.frame_meter_y_offset }
	-- 1Pと2Pともにフレーム数が多すぎる場合は加算をやめる
	-- グラフの描画最大範囲（画面の横幅）までにとどめる
	frame_meter.adjust_buffer = function()
		local min_count = global.mini_frame_limit
		for _, p in ipairs(players) do
			local frame1 = p.act_frames[#p.act_frames]
			if frame1 and frame1.count > global.mini_frame_limit then min_count = math.min(min_count, frame1.count) end

			frame1 = p.fb_frames.act_frames[#p.fb_frames.act_frames]
			if frame1 and frame1.count > global.mini_frame_limit then min_count = math.min(min_count, frame1.count) end

			frame1 = p.gap_frames.act_frames[#p.gap_frames.act_frames]
			if frame1 and frame1.count > global.mini_frame_limit then min_count = math.min(min_count, frame1.count) end
		end

		local fix = min_count - global.mini_frame_limit
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
	frame_meter.grouping = function(frame, frame_groups)
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
	-- フレームメーターの追加情報
	frame_meter.decos = {
		{ type = frame_attack_types.on_additional_w1, txt = "+", fix = -0.3, top = get_line_height(0.4), col = 0xFF00FF00 }, -- 成立した追加入力データの設定時 1F
		{ type = frame_attack_types.on_additional_r1, txt = "-", fix = -0.4, top = get_line_height(0.4), col = 0xFF00FF00 }, -- 追加入力データの確認時 1F
		{ type = frame_attack_types.on_additional_w5, txt = "+", fix = -0.3, top = get_line_height(0.4), col = 0xFF00FF00 }, -- 成立した追加入力データの設定時 5F
		{ type = frame_attack_types.on_additional_r5, txt = "=", fix = -0.4, top = get_line_height(0.4), col = 0xFF00FF00 }, -- 追加入力データの確認時 5F
		{ type = frame_attack_types.on_additional_wsp, txt = "+", fix = -0.3, top = get_line_height(0.4), col = 0xFF00FF00 }, -- 成立した追加入力データの設定時 Flag
		{ type = frame_attack_types.on_additional_rsp, txt = "-", fix = -0.4, top = get_line_height(0.4), col = 0xFF00FF00 }, -- 追加入力データの確認時 Flag
		{ type = frame_attack_types.post_fireball, txt = "◇", fix = -0.4, separator = true }, -- 弾処理の消失時
		{ type = frame_attack_types.pre_fireball, txt = "◆", fix = -0.4, separator = true }, -- 弾処理の開始時(種類によっては発生保証)
		{ type = frame_attack_types.off_fireball, txt = "○", fix = -0.35, separator = true }, -- 弾判定の消失時
		{ type = frame_attack_types.on_fireball, txt = "●", fix = -0.35, separator = true }, -- 弾判定の発生時
		{ type = frame_attack_types.on_main_to_sway, txt = "△", fix = -0.5, separator = true }, -- スウェーラインへの遷移時
		{ type = frame_attack_types.on_main_line, txt = "▽", fix = -0.5, separator = true }, -- メインラインへの遷移時
		{ type = frame_attack_types.on_air, txt = "▲", fix = -0.5, separator = true }, -- 空中状態への遷移時
		{ type = frame_attack_types.on_ground, txt = "▼", fix = -0.5, separator = true }, -- 地上状態への遷移時
	}
	for _, deco in ipairs(frame_meter.decos) do
		deco.fix2 = deco.separator and (-get_string_width(deco.txt) / 2) or 1
	end
	-- フレームメーターの無敵情報
	frame_meter.dodges = {
		{ type = frame_attack_types.full,        y = 1.0, step = 1.6, txt = "Full", border = 0.8, xline = 0xFF00BBDD }, -- 全身無敵
		{ type = frame_attack_types.high_dodges, y = 1.6, step = 3,   txt = "Low",  border = 1,   xline = 0xFF00FFFF }, -- 上部無敵
		{ type = frame_attack_types.low_dodges,  y = 1.6, step = 3,   txt = "High", border = 1,   xline = 0xFF00BBDD }, -- 下部無敵
		{ type = frame_attack_types.main,        y = 1.6, step = 3,   txt = "Main", border = 1,   xline = 0xFFD8BFD8 }, -- メインライン上の攻撃に無敵
		{ type = frame_attack_types.sway,        y = 1.6, step = 3,   txt = "Sway", border = 1,   xline = 0xFFD8BFD8 }, -- 対スウェーライン攻撃に無敵
	}
	frame_meter.throw_indivs = {
		{ type = frame_attack_types.throw_indiv10, y = 5, step = 1, txt = "10Throw", border = 1, xline = 0xFFFF8C00 }, -- 地上コマンド投げ無敵(タイマー10)
		{ type = frame_attack_types.throw_indiv20, y = 5, step = 1, txt = "20Throw", border = 1, xline = 0xFFFFF352 }, -- 地上コマンド投げ無敵(タイマー20)
	}
	frame_meter.throw_indivn = {
		{ type = frame_attack_types.throw_indiv_n, y = 6, step = 1, txt = "nThrow", border = 1, xline = 0xFF33FF55 }, -- 通常投げ無敵(タイマー24)
	}
	frame_meter.exclude_dodge = function(attackbit)
		return false
		--[[
		return ut.tstb(attackbit, frame_attack_types.crounch60 |
			frame_attack_types.crounch64 |
			frame_attack_types.crounch68 |
			frame_attack_types.crounch76 |
			frame_attack_types.crounch80)
		]]
	end
	frame_meter.do_mini_draw = function(group, left, top, height, limit, txt_y, disp_name)
		if #group == 0 then return end
		txt_y = txt_y or 0
		local _draw_text = draw_text                             -- draw_text_with_shadow
		if disp_name and (group[1].col + group[1].line) > 0 then
			_draw_text(left + 12, txt_y + top, group[1].name, 0xFFC0C0C0) -- 動作名を先に描画
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

				if not frame_meter.exclude_dodge(frame.attackbit) then
					for _, s, col in ut.ifind(frame_meter.dodges, function(s) return ut.tstb(frame.attackbit, s.type) and frame.xline or nil end) do
						for i = s.y, height - s.y, s.step do scr:draw_box(xright, top + i, xleft, math.min(top + height, top + i + s.border), 0, col) end
					end
				end

				local deco_txt = ""
				for _, deco in ut.ifind(frame_meter.decos, function(deco) return ut.tstb(frame.attackbit, deco.type) and deco or nil end) do
					deco_txt = deco.txt -- 区切り記号の表示
					_draw_text(xleft + get_string_width(deco_txt) * deco.fix, txt_y + top - 6, deco_txt)
					scr:draw_line(xleft, top, xleft, top + height)
				end

				local txtx = (frame.count > 5) and (xleft + 1) or (3 > frame.count) and (xleft - 1) or xleft
				local count_txt = 300 < frame.count and "LOT" or ("" .. frame.count)
				local font_col = frame.font_col or 0xFFFFFFFF
				if font_col > 0 then _draw_text(txtx, txt_y + top, count_txt, font_col) end
			end
			if xleft <= left then break end
			xright = xleft
		end
		_draw_text(right - 40, txt_y + top, table.concat(frame_txts, "/"))
	end

	frame_meter.draw_mini = function(groups, x, y, limit)
		if groups == nil or #groups == 0 then return end
		local height, span_ratio = get_line_height(), 0.2
		local span = (2 + span_ratio) * height
		-- 縦に描画
		if #groups < 7 then y = y + (7 - #groups) * span end
		for j = #groups - math.min(#groups - 1, 6), #groups do
			frame_meter.do_mini_draw(groups[j], x, y, height, limit, 0, true)
			for _, frame in ipairs(groups[j]) do
				for _, sub_group in ipairs(frame.fb_frames or {}) do
					frame_meter.do_mini_draw(sub_group, x, y, height, limit)
				end
				for _, sub_group in ipairs(frame.gap_frames or {}) do
					frame_meter.do_mini_draw(sub_group, x, y + height, height - 1, limit)
				end
			end
			y = y + span
		end
	end

	frame_meter.buffer_limit = frame_meter.limit * 2 -- バッファ長=2行まで許容
	frame_meter.add = function(p, frame)          -- フレームデータの追加
		if p.is_fireball then return end
		if not global.both_act_neutral and global.old_both_act_neutral then
			p.frames = {}               -- バッファ初期化
		end
		local frames, reset = p.frames, false -- プレイヤーごとのバッファを取得
		local last = frames[#frames]
		local first = #frames == 0
		reset = reset or first
		if last then
			reset = reset or frame.key ~= last.key -- frame.attackbit ~= last.key
			reset = reset or frame.col ~= last.col
		end
		--reset = reset or frame.name ~= last.name
		--reset = reset or frame.update ~= last.update

		frame.count = reset and 1 or last.count + 1
		if frame.act_neutral then
			frame.total = (first or not last.total) and 0 or last.total
		else
			frame.total = (first or not last.total) and 1 or last.total + 1
		end
		if last and last.startup then
			frame.startup = last.startup
		elseif not frame.startup and ut.tstb(frame.attackbit, frame_attack_types.attacking) and
			not ut.tstb(frame.attackbit, frame_attack_types.fake) then
			frame.startup = frame.total
		end
		for _, deco in ut.ifind(frame_meter.decos, function(deco) return ut.tstb(frame.decobit, deco.type) end) do
			frame.deco, frame.deco_fix, frame.deco_top = deco.txt, deco.fix2, deco.top
		end
		if not frame_meter.exclude_dodge(frame.attackbit) then
			for _, s in ut.ifind(frame_meter.dodges, function(s) return ut.tstb(frame.attackbit, s.type) end) do
				frame.dodge = s
			end
		end
		frame.throw_indiv = {}
		for _, s in ut.ifind(frame_meter.throw_indivs, function(s) return ut.tstb(frame.attackbit, s.type) end) do
			table.insert(frame.throw_indiv, s)
		end
		for _, s in ut.ifind(frame_meter.throw_indivn, function(s) return ut.tstb(frame.attackbit, s.type) end) do
			table.insert(frame.throw_indiv, s)
		end
		table.insert(frames, frame)                                  -- 末尾に追加
		if #frames <= frame_meter.buffer_limit then return end       -- バッファ長が2行以下なら抜ける
		local frame_limit = frame_meter.limit
		while frame_limit ~= #frames do table.remove(frames, 1) end  -- 1行目のバッファを削除
	end
	frame_meter.draw_sf6 = function(p, y1)                           -- フレームメーターの表示
		if p.is_fireball then return end
		local _draw_text = draw_text                                 -- draw_text_with_shadow
		local x0 = (scr.width - frame_meter.cell * frame_meter.limit) // 2 -- 表示開始位置
		local height = get_line_height()
		local y2 = y1 + height                                       -- メーター行のY位置
		local frames, max_x = {}, #p.frames
		while (0 < max_x) do
			local frame = p.frames[max_x]
			if (not frame.both_act_neutral) or frame.either_throw_indiv then
				for i = 1, max_x do table.insert(frames, p.frames[i]) end
				break
			end
			max_x = max_x - 1
		end
		local remain = (frame_meter.limit < max_x) and (max_x % frame_meter.limit) or 0
		local draw_term = remain ~= 0 and frame_meter.limit ~= max_x
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
					deco = { x1 + frame.deco_fix, y1 + (frame.deco_top or 0), frame.deco, 0xFFBBBBBB },
				})
			end
			if ix == max_x then -- 末尾のみ四方をBOX描画して太線で表示
				local count = string.format("%s", frame.count)
				table.insert(separators, { -- フレーム終端
					txt = { x2 - 0.5 - #count * screen.s_width, y1, count },
					box = { x1, y1, x2, y2, frame.line, 0, 1 }
				})
			elseif ((remain == 0) or (remain + 4 < ix)) and (frame.count >= frames[ix + 1].count) then
				local count = string.format("%s", 0 < frame.count and frame.count or "")
				table.insert(separators, { -- フレーム区切り
					txt = { x2 - 0.5 - #count * screen.s_width, y1, count },
					box = { x1, y1, x2, y2, frame.line, 0, 0 }
				})
			end
			if draw_term and ix == remain + 1 then
				scr:draw_box(x1, y1, x2, y2, 0xFF000000, 0xFF000000) -- 四角の描画
			else
				scr:draw_box(x1, y1, x2, y2, 0, frame.line) -- 四角の描画
				if frame.dodge then                      -- 無敵の描画
					local s, col = frame.dodge, frame.dodge.xline
					for i = s.y, height - s.y, s.step do scr:draw_box(x1, y1 + i, x2, y1 + i + s.border, 0, col) end
				end
				for _, throw_indiv in ipairs(frame.throw_indiv) do
					local s, col = throw_indiv, throw_indiv.xline
					scr:draw_box(x1, y1 + s.y, x2, y1 + s.y + s.border, 0, col)
				end
				scr:draw_box(x1, y1, x2, y2, 0xFF000000, 0) -- 四角の描画
			end
		end
		-- 区切り描画
		for i, args in ipairs(separators) do
			if i == #separators then break end
			if args.box then scr:draw_box(table.unpack(args.box)) end
			if args.deco then _draw_text(table.unpack(args.deco)) end
		end
		for i, args in ipairs(separators) do
			if i == #separators then break end
			if args.txt then _draw_text(table.unpack(args.txt)) end
		end
		-- マスクの四角描画
		if frame_meter.limit ~= max_x or max_x == 0 then
			local mc1, mc2
			if remain ~= 0 then mc1, mc2 = 0xFF000000, 0xFF000000 else mc1, mc2 = 0xFF000000, 0xEE303030 end
			for ix = (max_x % frame_meter.limit) + (draw_term and 2 or 1), frame_meter.limit do
				local x1 = ((ix - 1) * frame_meter.cell) + x0
				if remain ~= 0 then mc2 = math.max(mc2 - 0x11000000, 0x33000000) end
				scr:draw_box(x1, y1, x1 + frame_meter.cell, y2, mc1, mc2)
			end
		end
		-- 終端の描画
		if 0 < #separators then
			local args = separators[#separators]
			if args.box then border_waku(table.unpack(args.box)) end
			if args.txt then _draw_text(table.unpack(args.txt)) end
		end
		-- フレーム概要の描画
		local total_num = type(total) == "number" and total or 0
		return startup, total_num, function(op_total) -- 後処理での描画用に関数で返す
			local gap = p.last_frame_gap or 0
			local gap_txt = string.format("%4s", string.format(gap > 0 and "+%d" or "%d", gap))
			local gap_col = gap == 0 and 0xFFFFFFFF or gap > 0 and 0xFF0088FF or 0xFFFF0088
			local label = string.format("Startup %2s / Total %3s / Recovery", startup, total)
			local ty = p.num == 1 and y1 - height or y1 + height
			scr:draw_box(x0, ty, x0 + 166, ty + get_line_height(), 0, 0xA0303030)
			_draw_text(x0 + 1, ty, label)
			if not global.both_act_neutral then gap_txt, gap_col = " ---", 0xFFFFFFFF end
			local tx = x0 + get_string_width(label) + 1
			_draw_text(tx, ty, gap_txt, gap_col)
			-- スト6風フレームメーター -- 1:OFF, 2:ON:大表示, 3:ON:大表示(+1P情報), 4:ON:大表示(+2P情報)
			if (global.disp_frame == 3 and p.num == 1) or (global.disp_frame == 4 and p.num == 2) then
				local boxy = p.frame_info and (ty - get_line_height(#p.frame_info.latest)) or ty
				scr:draw_box(x0, boxy, x0 + 160, ty, 0, 0xA0303030)
				for ri, info in ipairs(p.frame_info and p.frame_info.latest or {}) do
					_draw_text(x0 + 1, get_line_height(ri) + (ty - get_line_height(#p.frame_info.latest + 1)), info)
				end
			end

			if p.char == db.char_id.yamazaki and p.flag_c8 == 0x20000 then
				_draw_text(tx + 20, ty, string.format("Drill %2s", p.drill_count))
			elseif p.char == db.char_id.honfu and p.flag_c8 == 0x4000000 then
				_draw_text(tx + 20, ty, string.format("Taneuma %2s", p.drill_count))
			end
			--draw_text(tx + 20, ty, string.format("Skip %s", global.skip_frame1))
		end
	end

	frame_meter.update_frame = 0
	frame_meter.attackbit_mask_base = ut.hex_clear(0xFFFFFFFFFFFFFFFF,
		frame_attack_types.fb                  | -- 0x 1 0000 0001 弾
		frame_attack_types.attacking           | -- 0x 2 0000 0010 攻撃動作中
		frame_attack_types.juggle              | -- 0x 4 0000 0100 空中追撃可能
		frame_attack_types.fake                | -- 0x 8 0000 1000 攻撃能力なし(判定初期から)
		frame_attack_types.obsolute            | -- 0x F 0001 0000 攻撃能力なし(動作途中から)
		frame_attack_types.fullhit             | -- 0x20 0010 0000 全段ヒット状態
		frame_attack_types.harmless            | -- 0x40 0100 0000 攻撃データIDなし
		frame_attack_types.frame_plus          | -- フレーム有利：Frame advantage
		frame_attack_types.frame_minus         | -- フレーム不利：Frame disadvantage,
		frame_attack_types.pre_fireball        | -- 弾処理中
		frame_attack_types.post_fireball       | -- 弾処理中
		frame_attack_types.on_fireball         | -- 弾判定あり
		frame_attack_types.off_fireball        | -- 弾判定あり
		frame_attack_types.throw_indiv20       | -- 地上コマンド投げ無敵(タイマー20)
		frame_attack_types.throw_indiv10       | -- 地上コマンド投げ無敵(タイマー10)
		frame_attack_types.throw_indiv_n       | -- 通常投げ無敵(タイマー24)
		frame_attack_types.full                | -- 全身無敵
		frame_attack_types.main                | -- メインライン攻撃無敵
		frame_attack_types.sway                | -- メインライン攻撃無敵
		frame_attack_types.high                | -- 上段攻撃無敵
		frame_attack_types.low                 | -- 下段攻撃無敵
		frame_attack_types.away                | --上半身無敵 32 避け
		frame_attack_types.waving_blow         | -- 上半身無敵 40 ウェービングブロー,龍転身,ダブルローリング
		frame_attack_types.lawrence_away       | -- 上半身無敵 48 ローレンス避け
		--frame_attack_types.crounch60           | -- 頭部無敵 60 屈 アンディ,東,舞,ホンフゥ,マリー,山崎,崇秀,崇雷,キム,ビリー,チン,タン
		--frame_attack_types.crounch64           | -- 頭部無敵 64 屈 テリー,ギース,双角,ボブ,ダック,リック,シャンフェイ,アルフレッド
		--frame_attack_types.crounch68           | -- 頭部無敵 68 屈 ローレンス
		--frame_attack_types.crounch76           | -- 頭部無敵 76 屈 フランコ
		--frame_attack_types.crounch80           | -- 頭部無敵 80 屈 クラウザー
		frame_attack_types.levitate40          | -- 足元無敵 対アンディ屈C
		frame_attack_types.levitate32          | -- 足元無敵 対ギース屈C
		frame_attack_types.levitate24          | -- 足元無敵 対だいたいの屈B（キムとボブ以外）
		frame_attack_types.on_air              | -- ジャンプ
		frame_attack_types.on_ground           | -- 着地
		frame_attack_types.on_additional_r1  | -- 追加入力
		frame_attack_types.on_additional_r5  | -- 追加入力
		frame_attack_types.on_additional_rsp  | -- 追加入力
		frame_attack_types.on_additional_w1 | -- 追加入力
		frame_attack_types.on_additional_w5 | -- 追加入力
		frame_attack_types.on_additional_wsp | -- 追加入力
		frame_attack_types.on_main_line        | -- フレームメーターの装飾用 メインラインへの遷移
		frame_attack_types.on_main_to_sway     | -- フレームメーターの装飾用 メインラインからの遷移
		(0xFF << frame_attack_types.act_count) | -- act_count 本体の動作区切り用
		(0xFF << frame_attack_types.fb_effect) | -- effect 弾の動作区切り用
		(0xFF << frame_attack_types.attack)    | -- attack
		(0xFFFF << frame_attack_types.act)     | -- act
		frame_attack_types.op_cancelable)  -- 自身がやられ中で相手キャンセル可能
	frame_meter.attackbit_mask_additional =
		frame_attack_types.high_dodges   |
		frame_attack_types.low_dodges    |
		frame_attack_types.frame_plus    |
		frame_attack_types.throw_indiv20 |
		frame_attack_types.throw_indiv10 |
		frame_attack_types.throw_indiv_n |
		frame_attack_types.full          |
		frame_attack_types.main          |
		frame_attack_types.sway          |
		frame_attack_types.on_air        |
		frame_attack_types.on_ground     |
		frame_attack_types.on_main_line  |
		frame_attack_types.on_main_to_sway |
		frame_attack_types.on_additional_r1 |
		frame_attack_types.on_additional_r5 |
		frame_attack_types.on_additional_rsp |
		frame_attack_types.on_additional_w1 |
		frame_attack_types.on_additional_w5 |
		frame_attack_types.on_additional_wsp
	frame_meter.key_mask_base =
		frame_attack_types.mask_fireball      | -- 弾とジャンプ状態はキーから省いて無駄な区切りを取り除く
		frame_attack_types.obsolute |     -- 0x F 0001 0000 攻撃能力なし(動作途中から)
		frame_attack_types.fullhit  |     -- 0x20 0010 0000 全段ヒット状態
		frame_attack_types.harmless       -- 0x40 0100 0000 攻撃データIDなし
	frame_meter.update = function(p)
		frame_meter.update_frame = global.frame_number
		-- 弾フレーム数表示の設定を反映する
		local fireballs          = p.disp_fb_frame and p.fireballs or {}
		local objects            = p.disp_fb_frame and p.objects or { p }
		-- 弾の情報をマージする
		for _, fb in pairs(fireballs) do if fb.proc_active then p.attackbit = p.attackbit | fb.attackbit end end

		local col, line, xline, attackbit = 0xAAF0E68C, 0xDDF0E68C, 0, p.attackbit
		local boxkey, fbkey               = "", "" -- 判定の形ごとの排他につかうキー
		local no_hit                      = global.frame_number ~= p.body.op.on_hit and global.frame_number ~= p.body.op.on_block
		-- フレーム数表示設定ごとのマスク
		local key_mask                    = frame_meter.key_mask_base
		for _, d in ipairs(frame_meter.decos) do key_mask = key_mask | d.type end  -- フレームメーターの追加情報
		for _, d in ipairs(frame_meter.dodges) do key_mask = key_mask | d.type end -- フレームメーターの無敵情報
		for _, d in ipairs(frame_meter.throw_indivn) do key_mask = key_mask | d.type end -- フレームメーターの無敵情報
		for _, d in ipairs(frame_meter.throw_indivs) do key_mask = key_mask | d.type end -- フレームメーターの無敵情報
		key_mask = ut.hex_clear(0xFFFFFFFFFFFFFFFF, key_mask)

		local attackbit_mask = frame_meter.attackbit_mask_base
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
			attackbit_mask = attackbit_mask      | frame_meter.attackbit_mask_additional
			if ut.tstb(p.attackbit, frame_attack_types.attacking) and not ut.tstb(p.attackbit, frame_attack_types.fake) then
				attackbit_mask = attackbit_mask | frame_attack_types.attacking
				if p.multi_hit then --if p.hit.box_count > 0 and p.max_hit_dn > 0 then
					attackbit_mask = attackbit_mask | frame_attack_types.mask_multihit
				end
			end
			if ut.tstb(p.flag_d0, db.flag_d0._06) then -- 自身がやられ中で相手キャンセル可能
				attackbit_mask = attackbit_mask |
					frame_attack_types.op_cancelable
			end

			for _, d in ut.ifind(frame_meter.dodges, function(d) return ut.tstb(attackbit, d.type) end) do
				attackbit = attackbit | d.type -- 部分無敵
			end
			-- ヒットタイミングは攻撃前の表示を引き継ぐようにする
			local replace_types = no_hit and {} or {
				[db.box_types.harmless_attack] = db.box_types.attack,
				[db.box_types.harmless_juggle] = db.box_types.juggle,
				[db.box_types.harmless_fireball] = db.box_types.fireball,
				[db.box_types.harmless_juggle_fb] = db.box_types.juggle_fireball,
			}
			for _, xp in ut.ifind_all(objects, function(xp) return xp.proc_active end) do
				if xp.hitbox_types and #xp.hitbox_types > 0 and xp.hitbox_types then
					attackbit = attackbit | xp.attackbit
					table.sort(xp.hitbox_types, function(t1, t2) return t1.sort > t2.sort end) -- ソート
					local best_type = xp.hitbox_types[1]
					best_type = replace_types[best_type] or best_type
					if best_type.kind ~= db.box_kinds.attack and xp.hit_repeatable then
						col, line = 0xAA3366FF, 0xDD3366FF -- やられ判定より連キャン状態を優先表示する
					elseif best_type.kind == db.box_kinds.push then
						col, line = 0xA0303030, 0xDD303030 -- 接触判定だけのものはグレーにする
					else
						col, line = best_type.fill, best_type.outline
						col = col > 0xFFFFFF and (col | 0x22111111) or 0
					end
				end
			end
		end
		local decobit = attackbit
		attackbit     = attackbit & attackbit_mask

		local frame   = p.act_frames[#p.act_frames]
		local plain   = p.body.act_data.last_plain
		local name    = p.body.act_data.last_name
		local key     = key_mask & attackbit
		local update  = (p.on_update_87 == global.frame_number) and p.update_act
		-- カイザーウェーブ、蛇使いレベルアップ
		if p.kaiserwave and p.on_update_spid == global.frame_number then
			if (p.kaiserwave[0x49418] == global.frame_number)
				or (p.kaiserwave[0x49428] == global.frame_number)
				or (p.kaiserwave[0x42158] == global.frame_number) then
				update = true
			end
		end
		if p.flag_cc ~= p.old.flag_cc and ut.tstb(p.flag_7e, db.flag_7e._02) then
			update = true
		end
		local f_plus = ut.tstb(p.attackbit, frame_attack_types.frame_plus)

		local mcol   = f_plus and 0xA0303080 or (p.act_data.neutral and 0xA0808080 or line)
		frame_meter.add(p, {
			key = key,
			name = name,
			boxkey = boxkey,
			update = update,
			decobit = decobit,
			attackbit = attackbit,
			act_neutral = p.act_data.neutral,
			either_throw_indiv = global.either_throw_indiv,
			both_act_neutral = global.both_act_neutral,
			line = mcol,
			col = mcol,
		})

		if update or not frame or frame.col ~= col or frame.key ~= key or frame.boxkey ~= boxkey then
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
			frame.count = frame.count + 1                       --同一行動IDが継続している場合はフレーム値加算
		end
		local upd_group = frame_meter.grouping(frame, p.frame_groups) -- フレームデータをグループ化
		-- 表示可能範囲（最大で横画面幅）以上は加算しない
		p.act_frames_total = not p.act_frames_total and 0 or
			(global.mini_frame_limit < p.act_frames_total) and global.mini_frame_limit or (p.act_frames_total + 1)

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
		if frame_meter.grouping(frame, groups) and parent and groups then ut.table_add(parent, groups[#groups], 180) end

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
		if frame_meter.grouping(frame, groups) and parent and groups then ut.table_add(parent, groups[#groups], 180) end
	end

	local frame_txt = {
		buf = {
			{ { act = 0, name = "", key = 0, count = 0, is_act_break = function() return true end } },
			{ { act = 0, name = "", key = 0, count = 0, is_act_break = function() return true end } },
			body = {
				{ { act = 0, name = "", key = 0, count = 0, is_act_break = function() return true end } },
				{ { act = 0, name = "", key = 0, count = 0, is_act_break = function() return true end } },
			},
		},
		basic_mask =
			0,
		--frame_attack_types.full                | -- 全身無敵
		--frame_attack_types.main                | -- メインライン攻撃無敵
		--frame_attack_types.sway                | -- メインライン攻撃無敵
		--frame_attack_types.high                | -- 上段攻撃無敵
		--frame_attack_types.low                 , -- 下段攻撃無敵
		attack_mask =
			(0xFF << frame_attack_types.act_count) | -- act_count 本体の動作区切り用
			frame_attack_types.fb                  | -- 0x 1 0000 0001 弾
			frame_attack_types.attacking           | -- 0x 2 0000 0010 攻撃動作中
			frame_attack_types.juggle              | -- 0x 4 0000 0100 空中追撃可能
			frame_attack_types.fake,        -- 0x 8 0000 1000 攻撃能力なし(判定初期から)
		deco_mask =
			frame_attack_types.pre_fireball        | -- 弾処理中
			--frame_attack_types.post_fireball       | -- 弾処理中
			frame_attack_types.on_fireball         | -- 弾判定あり
			--frame_attack_types.off_fireball        | -- 弾判定あり
			frame_attack_types.on_air              | -- ジャンプ
			frame_attack_types.on_ground           | -- 着地
			frame_attack_types.on_main_line        | -- フレームメーターの装飾用 メインラインへの遷移
			frame_attack_types.on_main_to_sway, -- フレームメーターの装飾用 メインラインからの遷移
	}
	frame_txt.add_to = function(p, objects, frame_info, buf)
		local last, key, dodge_key, mask = buf[#buf], 0, 0, frame_txt.basic_mask
		local condition = function(p)
			if p.proc_active and p.attackbits.attacking and not p.attackbits.fake and (p.hit.box_count > 0) then
				return p.latest_states
			end
			return nil
		end
		local c4_air_move = db.flag_c4.hop | db.flag_c4.jump
		local c0, c4, c8, cc_ca, cc_sp = p.flag_c0, ut.hex_clear(p.flag_c4, c4_air_move), p.flag_c8, p.flag_cc & 1, p.flag_cc & 0xFF -- ccはCAフラグのみ対象にする
		local neutral, act_break, txt_break, attack = p.act_data.neutral, last.is_act_break(), false, false
		local hit_main, hit_sway, hit_punish, hit_parrieable = 0, 0, 0, 0
		if p.hit and p.hit.blockbit then
			hit_main, hit_sway, hit_punish, hit_parrieable = p.hit.blockbit.main, p.hit.blockbit.sway, p.hit.blockbit.pulish, p.hit.blockbit.parrieable
		end
		act_break = act_break or (neutral and (not p.firing) and p.old.firing) -- 弾だけ残って本体が自由行動してしまう時のためのもの
		local max_front = nil
		for _, xp, st in ut.ifind_all(objects, condition) do
			attack = true
			local max_hit_dn = xp.max_hit_dn or -1
			txt_break = txt_break or ((max_hit_dn > 1 or max_hit_dn == 0) and (xp.old.act_count ~= xp.act_count))
			key, mask = key | xp.attackbit, frame_txt.attack_mask
			if ut.tstb(xp.attackbit, frame_attack_types.high_dodges) then dodge_key = dodge_key | frame_attack_types.high_dodges end
			if ut.tstb(xp.attackbit, frame_attack_types.low_dodges) then dodge_key = dodge_key | frame_attack_types.low_dodges end
			for _, h in ipairs(st.hits) do
				max_front = math.max(max_front or 0, h.real_front)
			end
			max_front = ((p.pos - frame_info.pos) * p.flip_x) + (max_front or 0)
		end
		if buf.max_front2 and max_front then buf.max_front2[#buf.max_front2] = max_front end
		key = (key & mask) | dodge_key
		txt_break = txt_break or
			(last.key ~= key) or (p.old.attack ~= p.attack) or act_break or (ut.tstb(p.old.flag_c4, c4_air_move) ~= ut.tstb(p.flag_c4, c4_air_move)) or
			(last.hit_main ~= hit_main) or (last.hit_sway ~= hit_sway) or (last.hit_punish ~= hit_punish) or (last.hit_parrieable ~= hit_parrieable)
		local deco_bits, deco_txt = frame_txt.deco_mask & p.attackbit, nil
		for _, deco in ipairs(frame_meter.decos) do
			if ut.tstb(deco.type, deco_bits) then
				deco_txt, txt_break = deco.txt, true
				last.deco_txt = deco_txt
				break
			end
		end
		local count_up = (p.skip_frame or p.in_hitstop == global.frame_number or p.on_hit_any == global.frame_number) and 0 or 1
		local add = function(uniq, list, value)
			if not uniq[value] then
				table.insert(list, value)
				uniq[value] = true
			end
		end
		if last.attack and not attack and buf.max_front2 and buf.max_front1 then
			if buf.max_front1[#buf.max_front1] ~= buf.max_front2[#buf.max_front2] then
				buf.max_front1[#buf.max_front1] = string.format("%s-%s", buf.max_front1[#buf.max_front1], buf.max_front2[#buf.max_front2])
			end
		end
		if txt_break then
			if act_break and not p.firing then -- firingチェックは弾だけ残って本体が自由行動してしまう時のためのもの
				-- 初期化
				frame_info.name = buf[1].name or p.latest_states.name
				frame_info.latest = frame_info and frame_info.latest or {}
				frame_info.frames = ""
				frame_info.damages = ""
				frame_info.blockable_mains = ""
				frame_info.blockable_sways = ""
				frame_info.anti_aways = ""
				frame_info.parries = ""
				frame_info.blockstuns = ""
				frame_info.hitstuns = ""
				frame_info.fb_ranks = ""
				frame_info.effects1 = ""
				frame_info.effects2 = ""
				frame_info.max_front1 = ""
				frame_info.pos = p.pos
				local started, prev, recovery = false, nil, nil
				for i = #buf, 1, -1 do
					if buf[i].attack then
						recovery = i + 1
						break
					end
				end
				local sep1, sep2, space = nil, nil, "" -- " "ログ用はスペース
				for i, a1 in ipairs(buf) do
					sep1 = (i == 1) and "" or ((prev and prev.deco_txt) and space or (sep2 == ")" and "" or ","))
					if (not started and a1.attack) or (recovery == i) then sep1, started = string.gsub(sep1 .. "/", ",", ""), true end
					if started and i < recovery and not a1.attack then sep1, sep2 = "(", ")" else sep2 = "" end
					frame_info.name = (prev and prev.name ~= a1.name) and string.format("%s > %s", frame_info.name, a1.name) or frame_info.name
					frame_info.frames = string.format("%s%s%s%s%s", frame_info.frames, sep1, a1.count, sep2, a1.deco_txt or "")
					frame_info.damages = buf.damages and table.concat(buf.damages, ",") or ""
					frame_info.blockable_mains = buf.blockable_mains and table.concat(buf.blockable_mains, ",") or ""
					frame_info.blockable_sways = buf.blockable_sways and table.concat(buf.blockable_sways, ",") or ""
					frame_info.anti_aways = buf.anti_aways and table.concat(buf.anti_aways, ",") or ""
					frame_info.parries = buf.parries and table.concat(buf.parries, ",") or ""
					frame_info.blockstuns = buf.blockstuns and table.concat(buf.blockstuns, ",") or ""
					frame_info.hitstuns = buf.hitstuns and table.concat(buf.hitstuns, ",") or ""
					frame_info.fb_ranks = buf.fb_ranks and table.concat(buf.fb_ranks, ",") or ""
					frame_info.effects1 = buf.effects1 and table.concat(buf.effects1, ",") or ""
					frame_info.effects2 = buf.effects2 and table.concat(buf.effects2, ",") or ""
					frame_info.max_front1 = buf.max_front1 and table.concat(buf.max_front1, ",") or ""
					prev = a1
				end
				--if frame_info.body and frame_info.body.frames then print(to_sjis(frame_info.body.frames)) end
				local namelen, name = utf8.len(frame_info.name), frame_info.name
				if namelen > 30 then name = "..." .. string.sub(name, utf8.offset(name, namelen - 25) - 1) end
				frame_info.latest = buf[1].neutral and frame_info.latest or {
					string.format("       Move: %s", name),
					string.format("      Frame: %s", ut.compress_txt(frame_info.body and frame_info.body.frames or "")),
					string.format(" Frame(w/FB: %s", ut.compress_txt((frame_info.body and (frame_info.body.frames ~= frame_info.frames)) and frame_info.frames or "")),
					string.format("     Damage: %s", ut.compress_txt(frame_info.damages)),
					string.format("Blockable(M: %s", ut.compress_txt(frame_info.blockable_mains)),
					string.format("Blockable(S: %s", ut.compress_txt(frame_info.blockable_sways)),
					string.format("  Anti-Away: %s", ut.compress_txt(frame_info.anti_aways)),
					string.format("  Parriable: %s", ut.compress_txt(frame_info.parries)),
					string.format("  Blockstop: %s", ut.compress_txt(frame_info.blockstuns)),
					string.format("    Hitstun: %s", ut.compress_txt(frame_info.hitstuns)),
					string.format(" Effect(Gnd: %s", ut.compress_txt(frame_info.effects1)),
					string.format(" Effect(Air: %s", ut.compress_txt(frame_info.effects2)),
					string.format("      Reach: %s", ut.compress_txt(frame_info.max_front1)),
				}
				while 0 < #buf do table.remove(buf, 1) end
				buf.damages = {}
				buf.blockable_mains = {}
				buf.blockable_sways = {}
				buf.anti_aways = {}
				buf.parries = {}
				buf.blockstuns = {}
				buf.hitstuns = {}
				buf.fb_ranks = {}
				buf.effects1 = {}
				buf.effects2 = {}
				buf.max_front1 = {}
				buf.max_front2 = {}
			end
			for _, xp, st in ut.ifind_all(objects, condition) do
				if xp.is_fireball then
					table.insert(buf.damages, (xp.chip == 0) and xp.damage or string.format("[%s]%s(%s)", xp.latest_states.fb_rank, xp.damage, xp.chip))
				else
					table.insert(buf.damages, (xp.chip == 0) and xp.damage or string.format("%s(%s)", xp.damage, xp.chip))
				end
				local u_main, u_sway, u_anti, u_parry = {}, {}, {}, {}
				local main, sway, anti, parry = {}, {}, {}, {}
				for _, h in ipairs(st.hits) do
					add(u_main, main, h.blockable_main)
					add(u_sway, sway, h.blockable_sway)
					add(u_anti, anti, h.anti_away_short)
					add(u_parry, parry, h.short_parry)
				end
				if #main > 0 then table.insert(buf.blockable_mains, table.concat(main, "+")) end
				if #sway > 0 then table.insert(buf.blockable_sways, table.concat(sway, "+")) end
				if #anti > 0 then table.insert(buf.anti_aways, table.concat(anti, "+")) end
				if #parry > 0 then table.insert(buf.parries, table.concat(parry, "+")) end
				table.insert(buf.blockstuns, st.blockstop)
				table.insert(buf.hitstuns, st.hitstun_short or "-")
				table.insert(buf.fb_ranks, st.fb_rank)
				table.insert(buf.effects1, st.effect_name1)
				table.insert(buf.effects2, st.effect_name2)
				table.insert(buf.max_front1, max_front)
				table.insert(buf.max_front2, max_front)
			end

			table.insert(buf, {
				name = p.latest_states.name,
				attack = attack,
				act = act_break and p.act or last.act,
				neutral = p.act_data.neutral,
				key = key,
				hit_main = hit_main,
				hit_sway = hit_sway,
				hit_punish = hit_punish,
				hit_parrieable = hit_parrieable,
				count = count_up,
				is_act_break =
					(c4 > 0) and function()
						local ret = (
							(p.flag_cc == 0 and c4 ~= ut.hex_clear(p.flag_c4, c4_air_move)) or
							(p.old.flag_c4 == 0) or
							((p.flag_cc & 1) ~= cc_ca) or
							(((p.flag_cc & 1) == 1) and p.on_update_ca == global.frame_number) or
							(p.flag_c8 > 0)
						) and p.on_update_act == global.frame_number
						--ut.printf("c4 %s %X %X %X %X %s %s %s", ret, c4, p.flag_c4, p.flag_cc, p.old.flag_c4, p.on_update_flag_cc, p.on_update_act, global.frame_number)
						return ret
					end or
					(c8 > 0) and function()
						local ret = (
								(p.flag_cc == 0 and c8 ~= p.flag_c8) or
								(p.old.flag_c8 == 0) or
								((p.flag_cc & 0xFF) ~= cc_sp)
							) and
							(buf[#buf].name ~= p.latest_states.name or p.flag_c8 ~= 0) and -- スナッチャー用
							p.on_update_act == global.frame_number
						--ut.printf("c8 %s %X %X %X %X %X %s %s", ret, c8, attack_data, p.flag_c8, p.flag_cc, p.old.flag_c8, p.on_update_act, global.frame_number)
						return ret
					end or function()
						local ret = (
							(not neutral and p.act_data.neutral) or
							(not p.act_data.neutral and ut.tstb(p.flag_7e, db.flag_7e._02) and ut.tstb(p.flag_c0, db.flag_c0.startups) and p.flag_c0 ~= c0) or
							(ut.hex_clear(p.flag_c4, c4_air_move) > 0 or p.flag_c8 > 0)
						) and p.on_update_act == global.frame_number
						--ut.printf("df %s %X %X %s %s %s %s", ret, c0, p.flag_c0, p.act_data.neutral, ut.tstb(p.flag_7e, db.flag_7e._02), ut.tstb(p.flag_c0, db.flag_c0.startups), global.frame_number)
						return ret
					end,
			})
		else
			last.count = last.count + count_up
		end
	end
	frame_txt.add = function(p)
		p.frame_info = p.frame_info or { body = {} }
		local frame_info = p.frame_info
		frame_txt.add_to(p, { p }, frame_info.body, frame_txt.buf.body[p.num])
		frame_txt.add_to(p, p.objects, frame_info, frame_txt.buf[p.num])
	end

	local input_rvs = function(rvs_type, p, logtxt)
		if global.rvslog and logtxt then emu.print_info(logtxt) end -- else emu.print_info("nolog rvs") 
		if ut.tstb(p.dummy_rvs.hook_type, hook_cmd_types.throw) then
			if p.act == 0x9 and p.act_frame > 1 then return end -- 着地硬直は投げでないのでスルー
			if p.op.in_air then return end
			if p.op.sway_status ~= 0x00 then return end -- 全投げ無敵
		elseif ut.tstb(p.dummy_rvs.hook_type, hook_cmd_types.jump) then
			if p.state == 0 and p.old.state == 0 and ((p.flag_c0 | p.old.flag_c0) & 0x10000) == 0x10000 then
				return -- 連続通常ジャンプを繰り返さない
			end
		end
		emu.print_info("aa")
		p.reset_sp_hook(p.dummy_rvs)
		if p.dummy_rvs.cmd and rvs_types.knock_back_recovery ~= rvs_type then
			if (((p.flag_c0 | p.old.flag_c0) & 0x2 == 0x2) or db.pre_down_acts[p.act]) and p.dummy_rvs.cmd == db.cmd_types._2D then
				p.reset_sp_hook() -- no act
			end
		end
	end

	-- 技データのIDかフラグから技データを返す
	local resolve_act_neutral = function(p)
		--[[
		if p.act <= 6 then
			return true
		end
		if ut.tstb(p.flag_c0, 0x3FFD723) or ((p.attack_data or 0) | p.flag_c4 | p.flag_c8) ~= 0 or ut.tstb(p.flag_cc, 0xFFFFFF3F) or ut.tstb(p.flag_d0, db.flag_d0.hurt) then
			return false -- ガードできない動作中
		end
		if p.act == 0x3B then
			return false
		end
		]]
		if p.firing then
			return false -- 飛び道具残存中にフレームメータの攻撃表示が持続するための措置
		end
		return p.base == 0x261A0 or p.base == 0x2D79E
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
				name = string.format("%s %s", db.get_flag_name(p.flag_c0, db.flag_names_c0), p.act)
			end
			act_data = cache[name] or { bs_name = name, name = name, normal_name = name, slide_name = name, count = 1 }
			if not cache[p.act] then cache[p.act] = act_data end
			if not cache[name] then cache[name] = act_data end
			act_data.neutral = --[[act_data.neutral or ]] resolve_act_neutral(p)
			act_data.type = act_data.type or (act_data.neutral and db.act_types.free or db.act_types.any)
			--if act_data.neutral then print(global.frame_number, p.num, string.format("%X", p.act), "act neutral") end
		elseif act_data then                    -- フラグ状態と技データの両方でニュートラル扱いかどうかを判断する
			local n1 --[[, n2]] = resolve_act_neutral(p) --, ut.tstb(act_data.type, db.act_types.free | db.act_types.block)
			--if n1 then print(global.frame_number, p.num, "flag neutral") end
			--if n2 then print(global.frame_number, p.num, "act neutral") else print(global.frame_number, p.num, ut.tobitstr(act_data.type)) end
			act_data.neutral = n1 -- and n2
		end
		-- 技動作は滑りかBSかを付与する
		act_data.name_plain = p.sliding and act_data.slide_name or p.in_bs and act_data.bs_name or act_data.normal_name
		act_data.name = ut.convert(act_data.name_org)
		return act_data
	end

	-- 状態表示用
	local kagenui_names = { "-", "Weak", "Strong" }
	local throw_names = {
		[db.box_types.air_throw] = "Air",
		[db.box_types.special_throw] = "Special",
		[db.box_types.normal_throw] = "Normal",
	}
	local block_names = {
		[0x10] = "Overhead",
		[0x11] = "Low",
		[0x12] = "Air",
	}

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
		if (global.dummy_mode == 6 and input.long_start()) or
			(global.dummy_mode ~= 6 and input.accept("st", state_past)) or
			(global.rec_main == recording.procs.fixpos and input.accept("st", state_past)) then
			menu.state = menu -- メニュー表示状態へ切り替え
			cls_joy()
			if global.dummy_mode == 5 then
				menu.set_current("recording")
			elseif global.dummy_mode == 6 then
				menu.set_current("replay")
			end
			return
		end

		if global.lag_frame == true then return end -- ラグ発生時は処理をしないで戻る

		global.old_both_act_neutral, global.both_act_neutral = global.both_act_neutral, true

		-- 1Pと2Pの状態読取
		for i, p in ipairs(players) do
			local op = players[3 - i]
			p.op     = op
			p.update_char()
			p.sliding = ut.tstb(p.flag_cc, db.flag_cc._02) -- ダッシュ滑り攻撃
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
			p.tw_muteki2        = p.tw_muteki2 or 0
			p.n_throwable       = p.throwable and p.tw_muteki2 == 0                                                            -- 通常投げ可能
			p.thrust            = p.thrust + p.thrust_frc
			p.inertia           = p.inertia + p.inertia_frc
			p.inertial          = not p.sliding and p.thrust == 0 and p.inertia > 0 and ut.tstb(p.flag_c0, db.flag_c0._31) -- ダッシュ慣性残し
			p.pos_total         = p.pos + p.pos_frc
			p.diff_pos_total    = p.old.pos_total and p.pos_total - p.old.pos_total or 0
			-- 位置の保存(文字と数値)
			local old_pos       = p.pos_hist[#p.pos_hist]
			table.insert(p.pos_hist, {
				x = format_num(p.pos + p.pos_frc),
				y = format_num(p.pos_y + p.pos_frc_y),
				z = string.format("%02d", p.pos_z or 0),
				pos = p.pos,
				pos_frc = p.pos_frc,
				pos_y = p.pos_y,
				pos_frc_y = p.pos_frc_y,
			})
			while 3 < #p.pos_hist do table.remove(p.pos_hist, 1) end
			p.old.pos       = old_pos.pos
			p.old.pos_frc   = old_pos.pos_frc
			p.old.pos_y     = old_pos.pos_y
			p.old.pos_frc_y = old_pos.pos_frc_y
			p.in_air        = 0 ~= p.pos_y or 0 ~= p.pos_frc_y
			-- ジャンプの遷移ポイントかどうか
			if not p.old.in_air and p.in_air then
				p.attackbits.on_air, p.attackbits.on_ground = true, false
			elseif p.old.in_air and not p.in_air then
				p.attackbits.on_air, p.attackbits.on_ground = false, true
			else
				p.attackbits.on_air, p.attackbits.on_ground = false, false
			end
			if p.on_hit == global.frame_number or p.on_block == global.frame_number then p.last_block_side = p.block_side end
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
			p.attackbits.on_main_line = p.on_main_line == global.frame_number
			p.attackbits.on_main_to_sway = p.on_main_to_sway == global.frame_number

			-- リバーサルとBS動作の再抽選
			p.dummy_rvs, p.dummy_bs = get_next_rvs(p), get_next_bs(p)

			-- キャンセル可否家庭用 02AD90 からの処理と各種呼び出し元からの断片
			p.hit_cancelable = false
			local d0 = p.cancelable_data & 0xC0
			if d0 ~= 0 and (d0 << 1) > 0xFF then
				p.hit_cancelable = ut.tstb(p.flag_7e, db.flag_7e._05, true)
			elseif d0 ~= 0 and (d0 << 2) > 0xFF then
				p.hit_cancelable = not ut.tstb(p.flag_7e, db.flag_7e._04, true)
			end
			p.op.attackbits.op_cancelable = p.hit_cancelable
			--ut.printf("hit_cancelable %X %s %s", d0, ut.tobitstr(p.flag_7e), p.hit_cancelable)

			-- 追加入力確認
			p.attackbits.on_additional_r1 = p.on_additional_r1 == global.frame_number
			p.attackbits.on_additional_r5 = p.on_additional_r5 == global.frame_number
			p.attackbits.on_additional_rsp = p.on_additional_rsp == global.frame_number
			p.attackbits.on_additional_w1 = p.on_additional_w1 == global.frame_number
			p.attackbits.on_additional_w5 = p.on_additional_w5 == global.frame_number
			p.attackbits.on_additional_wsp = p.on_additional_wsp == global.frame_number

			-- ガード持続の種類 家庭用 0271FC からの処理 0:攻撃無し 1:ガード継続小 2:ガード継続大
			if p.firing then
				p.kagenui_type = 2
			elseif p.attack and p.attack ~= 0 then
				local b2 = 0x80 == (0x80 & pgm:read_u8(pgm:read_u32(0x8C9E2 + p.char4) + p.attack))
				p.kagenui_type = b2 and 3 or 2
			else
				p.kagenui_type = 1
			end

			--フレーム用
			p.skip_frame            = global.skip_frame1 or global.skip_frame2 or p.skip_frame
			p.old.act_data          = p.act_data or get_act_data(p.old)
			p.act_data              = get_act_data(p)
			local prev              = p.old.act_data and p.old.act_data.name_plain
			p.act_data.last_plain   = (p.act_data.name_set and p.act_data.name_set[prev]) and prev or p.act_data.name_plain
			p.act_data.last_name    = ut.convert(p.act_data.last_plain)

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

			-- 弾の状態読取
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
				end
				p.attackbits.post_fireball = p.attackbits.post_fireball or fb.on_prefb == -global.frame_number
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
			if p.old and p.old.char == p.char then
				p.old.input_states = p.input_states or {}
				p.input_states     = {}
				p.old.chaging      = p.chaging or {}
				p.chaging          = {}
			else
				p.old.input_states = {}
				p.input_states     = {}
				p.old.chaging      = {}
				p.chaging          = {}
			end
			local debug  = false -- 調査時のみtrue
			local states = dip_config.easy_super and db.input_state_easy or db.input_state_normal
			--ut.printf("%s %s %s", dip_config.easy_super, states == db.input_state_easy, states == db.input_state_normal)
			states       = debug and states[#states] or states[p.char]
			for ti, tbl in ipairs(states) do
				local old, addr = p.old.input_states[ti], tbl.addr + p.input_offset
				local on, chg_remain = mem.r08(addr - 1), mem.r08(addr)
				local on_prev = on
				local max = (old and old.on_prev == on_prev) and old.max or chg_remain
				local input_estab = old and old.input_estab or false
				local charging, reset, force_reset = false, false, false

				-- コマンド種類ごとの表示用の補正
				if tbl.type == input_state.types.charge then
					if on == 1 and chg_remain == 0 then
						on = 3
					elseif on > 1 then
						on = on + 1
					end
					charging = on == 1
					if old then reset = old.on == #tbl.cmds and old.chg_remain > 0 end
					local c_old = p.old.chaging[#p.chaging + 1]
					table.insert(p.chaging, { -- ため時間だけの履歴を登録する
						charging = charging,
						chg_remain = charging and chg_remain or on > 1 and 0 or (c_old and c_old.chg_remain or 0),
						max = charging and max or (c_old and c_old.max or max),
						tbl = tbl,
					})
				else
					if old then reset = old.on == #tbl.cmds and old.chg_remain > 0 end
				end
				if old then
					if p.char ~= old.char or on == 1 then
						input_estab = false
						tbl.on_input_estab = nil
					elseif tbl.on_input_estab then
						input_estab = tbl.on_input_estab <= global.frame_number
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
					xmov     = p.body.diff_pos_total,
				}, 16)
			else
				p.update_base = false
				base.count, base.xmov = base.count + 1, base.xmov + p.body.diff_pos_total
			end
		end

		-- キャラと弾への当たり判定の反映
		hitboxies, ranges = {}, {} -- ソート前の判定のバッファ

		for _, p in ut.find_all(all_objects, function(_, p) return p.proc_active end) do
			-- 判定表示前の座標補正
			p.x, p.y, p.flip_x = p.pos - screen.left, screen.top - p.pos_y - p.pos_z, (p.flip_x1 ~ p.flip_x2) > 0 and 1 or -1
			p.vulnerable = (p.invincible and p.invincible > 0) or p.hurt_invincible or (p.on_hitcheck ~= global.frame_number and p.on_vulnerable ~= global.frame_number)
			-- ut.printf("%x p.vulnerable %s %s %s %s %s %s", p.addr.base, p.vulnerable, p.invincible, p.hurt_invincible, p.on_vulnerable, global.frame_number, p.on_vulnerable ~= global.frame_number)
			-- 判定位置を考慮しない属性を追加
			p.parrieable = (p.parrieable or 0) | (p.parrieable1 and p.parrieable2 and hitbox_parry_bits.baigaeshi or 0)
			p.hitboxies, p.hitbox_types, p.hurt = {}, {}, {} -- 座標補正後データ格納のためバッファのクリア
			local boxkeys = { hit = {}, hurt = {} }
			p.hurt = {
				max_top = -0xFFFF,
				min_bottom = 0xFFFF,
				dodge = p.vulnerable and frame_attack_types.full or 0,
				main = 0, -- 通常のやられ判定の数
				sway = 0, -- スウェイ上のやられ判定の数
				launch = 0, -- 空中追撃可能なやられ判定の数
				down_otg = 0, -- ダウン追撃可能なやられ判定の数
			}
			p.hit = { box_count = 0 }
			p.attackbit = calc_attackbit(p.attackbits, p)

			-- 判定が変わったらポーズさせる  1:OFF, 2:投げ, 3:攻撃, 4:変化時
			if global.pause_hitbox == 4 and p.act_data and not p.act_data.neutral and (p.chg_hitbox or p.chg_hurtbox) then global.pause = true end

			-- 当たりとやられ判定判定
			if p.delayed_clearing == global.frame_number then p.boxies = {} end
			if p.delayed_inactive == global.frame_number then
				p.parrieable, p.attack_id, p.attackbits = 0, 0, {}
				p.boxies, p.on_fireball = #p.boxies == 0 and p.boxies or {}, -1
				if p.is_fireball then p.proc_active = false end
			end
			p.hurt.dodge = frame_attack_types.full -- くらい判定なし＝全身無敵をデフォルトにする
			p.hit.blockbit = {
				main = 0,
				sway = 0,
				punish = 0,
				parrieable = 0,
			}
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
				if box.type == db.box_types.hurt1 or box.type == db.box_types.hurt2 then
					p.hurt.main = p.hurt.main + 1
				elseif box.type == db.box_types.down_otg then
					p.hurt.down_otg = p.hurt.down_otg + 1
				elseif box.type == db.box_types.launch then
					p.hurt.launch = p.hurt.launch + 1
				elseif box.type == db.box_types.hurt3 or box.type == db.box_types.hurt4 then
					p.hurt.sway = p.hurt.sway + 1
				end
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
					-- 判定位置を考慮した属性を追加
					local parrieable, possibles = 0, get_hitbox_possibles(box.id)
					for _, t in ipairs(hitbox_parry_types) do
						local in_range = possibles[t.name] and t.range(box.real_top, box.real_bottom)
						if t == hitbox_parry_bits.baigaeshi then
							if p.is_fireball and p.proc_active and p.parrieable1 and p.parrieable2 and in_range then
								parrieable = parrieable | t.value
							end
						else
							parrieable = parrieable | (in_range and t.value or 0)
						end
					end
					box.parrieable = parrieable
					p.hit.blockbit.main = p.hit.blockbit.main | box.blockables.main
					p.hit.blockbit.sway = p.hit.blockbit.sway | box.blockables.sway
					p.hit.blockbit.punish = p.hit.blockbit.punish | box.blockables.punish
					p.hit.blockbit.parrieable = p.hit.blockbit.parrieable | box.parrieable
				elseif box.type.kind == db.box_kinds.hurt then -- くらいの無敵(部分無敵)の属性を付与する
					if (not ut.tstb(p.flag_c0, db.flag_c0._01)) and (box.type == db.box_types.down_otg) then
						-- ignore
					else
						p.hurt.max_top = math.max(p.hurt.max_top or 0, box.real_top)
						p.hurt.min_bottom = math.min(p.hurt.min_bottom or 0xFFFF, box.real_bottom)
					end
					if p.hurt.max_top ~= -0xFFFF and p.hurt.min_bottom ~= 0xFFFF then
						p.hurt.dodge = get_dodge(p, box, p.hurt.max_top, p.hurt.min_bottom)
					end
				end
				if p.body.disp_hitbox and box.type.visible(p, box) then
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
				local new_throw_ids = {}
				for _, box in pairs(p.throw_boxies) do
					if global.pause_hitbox == 2 then global.pause = true end -- 強制ポーズ  1:OFF, 2:投げ, 3:攻撃, 4:変化時
					box.keytxt = string.format("t%2x%2x", box.type.no, box.id)
					table.insert(p.hitboxies, box)
					table.insert(hitboxies, box)
					table.insert(boxkeys.hit, box.keytxt)
					table.insert(p.hitbox_types, box.type)
					table.insert(new_throw_ids, { char = p.char, id = box.id })
				end
				p.throw_boxies = {}
				if 0 < #new_throw_ids then
					p.last_throw_ids = new_throw_ids
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
				-- 入力座標
				for _, ph in ipairs(p.key.pos_hist) do
					table.insert(ranges, {
						label = string.format("%sP %s", p.num, ph.label),
						x = ph.x - screen.left,
						y = ph.y + screen.top,
						flip_x = ph.flip_x,
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

		-- 投げ無敵
		local either_throw_indiv = true -- 両キャラともメインライン上でいずれかが投げ無敵中
		for _, p in ipairs(players) do
			local sway_flag = ut.tstb(p.flag_c0, 0x3F38)
			local sway_status = (p.sway_status ~= 0x00)
			local non_main = sway_flag or sway_status -- スウェー状態(フラグと状態)
			local com_indiv =
				(p.state ~= 0 or p.op.state ~= 0) or -- 双方とも非やられ状態
				(p.old.pos_y ~= 0 or p.old.pos_frc_y ~= 0) or -- 空中状態
				ut.tstb(p.flag_c0, db.flag_c0._01) -- ダウン中(フラグ)
			local sp_indiv = com_indiv or
				sway_status or
				(p.old.invincible ~= 0) -- 無敵フレーム(1フレずれる)
			local n_indiv = com_indiv or
				non_main or -- メインライン上ではない
				(p.invincible ~= 0) -- 無敵フレーム
			-- 通常投げ無敵(技動作の無敵フラグ 投げ無敵タイマー24)
			local tw_muteki2 = (p.attack_data ~= 0 and p.tw_muteki2 ~= 0)
			if n_indiv or tw_muteki2 or p.throw_timer <= 24 then p.attackbit = p.attackbit | frame_attack_types.throw_indiv_n end
			-- 地上コマンド投げ無敵(投げ無敵タイマー10)
			if sp_indiv or p.throw_timer <= 10 then p.attackbit = p.attackbit | frame_attack_types.throw_indiv10 end
			-- 地上コマンド投げ無敵(投げ無敵タイマー20)
			if sp_indiv or p.throw_timer <= 20 then p.attackbit = p.attackbit | frame_attack_types.throw_indiv20 end
			if non_main then either_throw_indiv = false end
		end
		if not ut.tstb(players[1].attackbit | players[2].attackbit, frame_attack_types.throw_indiv) then either_throw_indiv = false end
		global.either_throw_indiv = either_throw_indiv

		-- キャラ、弾ともに通常動作状態ならリセットする
		for _, p in pairs(all_objects) do
			if not global.both_act_neutral and global.old_both_act_neutral then p.clear_frame_data() end
		end
		-- 全キャラ特別な動作でない場合はフレーム記録しない
		local disp_neutral = global.disp_neutral_frames
		disp_neutral = disp_neutral or (either_throw_indiv and ((frame_meter.update_frame + 1) >= global.frame_number))
		for _, p in ipairs(players) do
			if disp_neutral or not global.both_act_neutral then frame_meter.update(p) end
		end
		frame_meter.adjust_buffer() --1Pと2Pともにフレーム数が多すぎる場合は加算をやめる

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
			p.bs_hook = nil -- フックを無効化
		end
		apply_1p2p_active()

		-- プレイヤー操作 人操作のみ処理対象にする
		for _, p in ut.ifind_all(players, function(p) return p.control == 1 or p.control == 2 end) do
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
				local cpu_block, cpu_block_next = mem.r08(0x56226 + p.op.attack), true
				while cpu_block_next do
					if cpu_block == 0 then
						act_type, cpu_block_next = act_type | db.act_types.attack, false
					elseif cpu_block == 1 then
						act_type, cpu_block_next = act_type | db.act_types.low_attack, false
					elseif cpu_block == 2 then
						cpu_block = mem.r08(((p.char - 1) << 3) + p.op.attack - 0x27 + 0x562FE)
					elseif cpu_block == 3 then
						cpu_block = mem.r08(((p.char - 1) << 5) + p.op.attack - 0x30 + 0x563B6)
					else
						cpu_block_next = false
					end
				end
			end
			-- リプレイ中は自動ガードしない
			if p.dummy_gd ~= dummy_gd_type.none and ut.tstb(act_type, db.act_types.attack) and in_rec_replay then
				p.clear_cmd_hook(db.cmd_types._8) -- 上は無効化

				-- 投げ無敵タイマーを使って256F経過後はガード状態を解除
				if p.throw_timer >= 0xFF then
					if p.dummy_gd == dummy_gd_type.block1 and p.next_block ~= true then
						p.next_block = true
					elseif p.dummy_gd == dummy_gd_type.hit1 and p.next_block == true then
						p.next_block = false
					end
				end

				if p.dummy_gd == dummy_gd_type.action then
					-- アクション（ガード方向はダミーモードに従う）
					p.add_cmd_hook(db.cmd_types.back)
				elseif p.dummy_gd == dummy_gd_type.high then
					-- 上段
					p.clear_cmd_hook(db.cmd_types._2)
					p.add_cmd_hook(db.cmd_types.back)
				elseif p.dummy_gd == dummy_gd_type.low then
					-- 下段
					p.add_cmd_hook(db.cmd_types._2)
					p.add_cmd_hook(db.cmd_types.back)
				elseif p.dummy_gd == dummy_gd_type.auto or  -- オート
					p.dummy_gd == dummy_gd_type.bs or       -- ブレイクショット
					p.dummy_gd == dummy_gd_type.random or   -- ランダム
					(p.dummy_gd == dummy_gd_type.hit1 and p.next_block) or -- 1ヒットガード
					(p.dummy_gd == dummy_gd_type.block1)    -- 1ガード
				then
					-- 中段から優先
					if ut.tstb(act_type, db.act_types.overhead, true) then
						p.clear_cmd_hook(db.cmd_types._2)
					elseif ut.tstb(p.op.flag_c4, db.flag_c4.overhead) then
						p.clear_cmd_hook(db.cmd_types._2)
					elseif ut.tstb(p.op.flag_c0, db.flag_c0.jump) and (p.op.flag_c4 > 0) then
						p.clear_cmd_hook(db.cmd_types._2)
					elseif ut.tstb(act_type, db.act_types.low_attack, true) then
						p.add_cmd_hook(db.cmd_types._2)
					elseif global.crouch_block then
						p.add_cmd_hook(db.cmd_types._2)
					end
					if p.dummy_gd == dummy_gd_type.block1 and p.next_block ~= true then
						-- 1ガードの時は連続ガードの上下段のみ対応させる
						p.clear_cmd_hook(db.cmd_types.back)
					else
						if p.dummy_gd ~= dummy_gd_type.random then
							p.next_block = true
						elseif p.op.on_update_act == global.frame_number then
							p.next_block = global.random_boolean(0.65)
						end
						if p.next_block then p.add_cmd_hook(db.cmd_types.back) end
					end
				end
				-- コマンド入力状態を無効にしてバクステ暴発を防ぐ
				local bs_addr = dip_config.easy_super and p.char_data.easy_bs_addr or p.char_data.bs_addr
				mem.w08(p.input_offset + bs_addr, 0x80)
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

			-- 相手がプレイヤーで挑発中は前進
			if not global.proceed_cpu then
				if p.fwd_prov and (p.op.control ~= 3) and ut.tstb(p.op.flag_cc, db.flag_cc._19) then p.add_cmd_hook(db.cmd_types.front) end
			end

			-- ガードリバーサル
			if not p.gd_rvs_enabled and (p.dummy_wakeup == wakeup_type.rvs) and p.dummy_rvs and (p.on_block == global.frame_number) then
				p.rvs_count = (p.rvs_count < 1) and 1 or p.rvs_count + 1
				if global.dummy_rvs_cnt <= p.rvs_count and p.dummy_rvs then p.gd_rvs_enabled, p.rvs_count = true, -1 end
				-- ut.printf("%s rvs %s %s", p.num, p.rvs_count, p.gd_rvs_enabled)
			elseif p.gd_rvs_enabled and p.state ~= 2 then
				p.gd_rvs_enabled = false
			end -- ガード状態が解除されたらリバサ解除

			-- BS
			if not p.gd_bs_enabled and p.bs and p.dummy_bs and p.on_block == global.frame_number then
				p.bs_count = (p.bs_count < 1) and 1 or p.bs_count + 1
				if global.dummy_bs_cnt <= p.bs_count and p.dummy_bs then p.gd_bs_enabled, p.bs_count = true, -1 end
				-- ut.printf("%s bs %s %s", p.num, p.bs_count, p.gd_bs_enabled)
			elseif p.gd_bs_enabled and p.state ~= 2 then
				p.gd_bs_enabled = false
			end -- ガード状態が解除されたらBS解除

			-- print(p.state, p.knockback2, p.knockback1, p.flag_7e, p.hitstop_remain, rvs_types.in_knock_back, p.last_blockstun, string.format("%x", p.act), p.act_count, p.act_frame)
			-- ヒットストップ中は無視
			-- なし, リバーサル, テクニカルライズ, グランドスウェー, 起き上がり攻撃
			if not p.skip_frame and rvs_wake_types[p.dummy_wakeup] and p.dummy_rvs then
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
				-- ut.printf("aa" .. (p.act_data.name or "") .. " %X %s %X %s", p.flag_cc, ut.tstb(p.flag_cc, db.flag_cc.hurt), p.old.flag_cc, ut.tstb(p.old.flag_cc, db.flag_cc.hurt))
				-- if p.state == 0 and p.act_data.name ~= "やられ" and p.old.act_data.name == "やられ" and p.knockback2 == 0 then
				if p.state == 1 and ut.tstb(p.flag_cc, db.flag_cc.hurt) == true and p.knockback2 == 0 then
					input_rvs(rvs_types.knock_back_recovery, p, "[Reversal] blockstun 1")
				end
				-- のけぞりのリバーサル入力
				if (p.state == 1 or (p.state == 2 and p.gd_rvs_enabled)) and p.hitstop_remain == 0 then
					-- のけぞり中のデータをみてのけぞり終了の2F前に入力確定する
					-- 奥ラインへずらした場合だけ無視する（p.act ~= 0x14A）
					if p.flag_7e == 0x80 and p.knockback2 == 0 and p.act ~= 0x14A and not ut.tstb(p.flag_7e, db.flag_7e._02) and not p.on_block then
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
				-- 奥ラインへずらしたあとのリバサ
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

			-- 避け攻撃対空
			if p.away_anti_air.enabled and not p.op.in_hitstun then
				local jump = p.op.in_air and ut.tstb(p.op.flag_c0, db.flag_c0._21 | db.flag_c0._22 | db.flag_c0._23)
				local hop = p.op.in_air and ut.tstb(p.op.flag_c0, db.flag_c0._18 | db.flag_c0._19 | db.flag_c0._20)
				local aaa, falling, attacking = p.away_anti_air, (jump or hop) and p.op.pos_y < p.op.old.pos_y, 0 < p.op.flag_c4
				local ant_air = false
				ant_air = ant_air or (attacking and hop and falling and aaa.hop_limit3 < p.op.pos_y) -- 小ジャンプ下り攻撃
				ant_air = ant_air or (attacking and hop and not falling and aaa.hop_limit2 < p.op.pos_y) -- 小ジャンプ上り攻撃
				ant_air = ant_air or (attacking and jump and falling and aaa.jump_limit3 < p.op.pos_y) -- ジャンプ下り攻撃
				ant_air = ant_air or (attacking and jump and not falling and aaa.jump_limit2 < p.op.pos_y) -- ジャンプ上り攻撃
				ant_air = ant_air or (falling and jump and p.op.pos_y <= aaa.jump_limit1)      -- ジャンプ下り
				ant_air = ant_air or (falling and hop and p.op.pos_y <= aaa.hop_limit1)        -- 小ジャンプ下り
				if ant_air then p.reset_cmd_hook(db.cmd_types._AB) end
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

			-- 自動必殺投げの切り替え
			local sp_throw_hook = nil
			if p.last_spids then
				-- 成立コマンドから切り替え
				table.sort(p.last_spids)
				for _, spid in ipairs(p.last_spids) do
					--ut.printf("try switch %X %X", p.char, spid)
					for throw_id, sp_throw in pairs(db.sp_throws) do
						if sp_throw.char == p.char and sp_throw.id == spid then
							--ut.printf("switch %X %X %X %X %s", p.char, throw_id, sp_throw.id, sp_throw.ver, to_sjis(sp_throw.name))
							sp_throw_hook = sp_throw
							break
						end
					end
					if sp_throw_hook then break end
				end
			end
			p.last_spids, p.sp_throw_hook = {}, sp_throw_hook and sp_throw_hook or p.sp_throw_hook
			-- 自動必殺投げ
			if global.auto_input.sp_throw and p.sp_throw_hook and (p.sp_throw_hook.char == p.char) then
				--ut.printf("reset_sp_hook %X %X %X", p.char, p.sp_throw_hook.id, p.sp_throw_hook.f)
				p.reset_sp_hook(p.sp_throw_hook)
			end

			-- 自動投げ追撃
			if global.auto_input.combo_throw then
				if p.char == db.char_id.joe and p.act == 0x70 then
					p.reset_cmd_hook(db.cmd_types._2C) -- ジョー
				elseif p.act == 0x6D and p.char_data.add_throw then
					p.reset_sp_hook(p.char_data.add_throw) -- ボブ、ギース、双角、マリー
				elseif p.char == db.char_id.xiangfei and p.act == 0x9F and p.act_count == 2 and p.act_frame >= 0 and p.char_data.add_throw then
					p.reset_sp_hook(p.char_data.add_throw) -- 閃里肘皇・心砕把
				elseif p.char == db.char_id.duck and (p.act == 0xAF or p.act == 0xB8 or p.act == 0xB9) then
					p.reset_sp_hook(p.char_data.add_throw) -- ダック
				end
			end

			-- 自動閃里肘皇・貫空
			if global.auto_input.kanku and p.char == db.char_id.xiangfei then
				if p.act == 0xA1 and p.act_count == 6 and p.act_frame >= 0 then
					p.reset_sp_hook(db.rvs_bs_list[p.char][21]) -- 閃里肘皇・貫空
				end
			end

			-- 自動超白龍
			if 1 < global.auto_input.pairon and p.char == db.char_id.xiangfei then
				if p.act == 0x43 and p.act_count >= 0 and p.act_count <= 3 and p.act_frame >= 0 and 2 == global.auto_input.pairon then
					p.reset_sp_hook(db.rvs_bs_list[p.char][28]) -- 超白龍
				elseif p.act == 0x43 and p.act_count == 3 and p.act_count <= 3 and p.act_frame >= 0 and 3 == global.auto_input.pairon then
					p.reset_sp_hook(db.rvs_bs_list[p.char][28]) -- 超白龍
				end
				if p.act == 0xFE then
					p.reset_sp_hook(db.rvs_bs_list[p.char][29]) -- 超白龍2
				end
			end

			-- ブレイクショット
			if p.gd_bs_enabled then p.reset_sp_hook(p.dummy_bs) end
		end

		-- レコード＆リプレイ
		if global.dummy_mode == 5 or global.dummy_mode == 6 then
			local prev_rec_main, called = nil, {}
			repeat
				prev_rec_main = global.rec_main
				called[prev_rec_main or "NOT DEFINED"] = true
				global.rec_main(next_joy)
			until global.rec_main == prev_rec_main or called[global.rec_main] == true
			input.read(3 - recording.player, global.rec_main == recording.procs.play)
		end

		-- キーディス用の処理
		for _, p in ipairs(players) do
			local key, keybuf = "", {} -- _1~_9 _A_B_C_D
			local ggbutton = { lever = 5, A = false, B = false, C = false, D = false, }

			-- GG風キーディスの更新
			for k, v, kk in ut.find_all(p.key.state, function(k, v) return string.gsub(k, "_", "") end) do
				if tonumber(kk) then
					if 0 < v then key, ggbutton.lever = (k == "_5" and "_N" or k), tonumber(kk) end
				elseif kk == "st" or kk == "sl" then
				else
					if 0 < v then keybuf[#keybuf + 1], ggbutton[kk] = k, true end
				end
			end
			ut.table_add(p.key.gg.hist, ggbutton, 60)
			table.sort(keybuf)
			key = key .. table.concat(keybuf)

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

		-- 状態表示(大)データの更新
		for _, p in ipairs(players) do
			local add = function(xp, typev, txt)
				xp.large_states[typev] = { txt = txt, attack = xp.body.attack, attack_id = xp.attack_id }
			end
			for _, xp in ipairs(p.objects) do
				xp.large_states = xp.body.char == xp.body.old.char and xp.large_states or {}
				xp.latest_states = {}
				if xp.proc_active then
					local st = xp.latest_states
					st.parent_id = xp.body.attack and string.format("%3X", xp.body.attack) or "---"
					st.fbid = (xp.attack and xp.is_fireball) and string.format("%3X", xp.attack) or "---"
					st.id = xp.attack_id and string.format("%3X", xp.attack_id) or "---"
					st.fake = xp.attackbits.fake
					st.name = "---"
					if xp.act_data then st.name = xp.act_data and xp.act_data.last_name or xp.act_data.name or "---" end
					st.damage = xp.damage or 0
					st.chip = xp.chip or 0
					st.stun = xp.stun or 0
					st.stun_timer = xp.stun_timer or 0
					st.effect, st.effect_name1, st.effect_name2 = db.hit_effects.get_name(xp.effect, "---")
					st.nokezori = db.hit_effects.is_nokezori(xp.effect)
					-- フレームデータがある場合は-1、システム固定処理による+2で補正する
					st.hitstop = (not xp.hitstop or xp.hitstop == 0) and "--" or (math.max(0, xp.hitstop - 1) + 2)
					-- フレームデータがある場合は-1、システム固定処理による+2で補正する
					st.blockstop = (not xp.blockstop or xp.hitstop == "--") and "--" or (math.max(0, xp.blockstop - 1) + 2)
					-- システム固定処理による+3で補正する
					st.hitstun_short = (st.nokezori and xp.hitstun and xp.hitstun > 0) and (xp.hitstun + 3) or nil
					st.hitstun = st.hitstun_short or "--"
					-- システム固定処理による+2で補正する
					st.blockstun = (not xp.blockstun or xp.blockstun == 0) and "--" or (xp.blockstun + 2)
					st.parrieable = to_parrieable_txt(xp.parrieable)
					st.max_hit_nm = xp.max_hit_nm or "-"
					st.max_hit_dn = xp.max_hit_dn or "-"
					st.multi_hit = xp.multi_hit
					st.fb_rank = xp.fireball_rank or "--"
					st.pow_up = p.pow_up_direct == 0 and p.pow_up or p.pow_up_direct or 0
					st.pow_up_hit = p.pow_up_hit or 0
					st.pow_up_block = p.pow_up_block or 0
					st.pow_revenge = p.pow_revenge or "-"
					st.pow_absorb = p.pow_absorb or "-"
					st.sp_invincible = xp.sp_invincible or "--"
					st.bs_pow = (ut.tstb(xp.flag_cc, db.flag_cc._21) and xp.bs_pow and xp.bs_pow > 0) and -xp.bs_pow or "---"
					st.bs_invincible = (ut.tstb(xp.flag_cc, db.flag_cc._21) and xp.bs_invincible) or "--"
					st.esaka = xp.esaka_target and xp.esaka or "---"
					st.esaka_type = xp.esaka_target and xp.esaka_type or "---"
					st.kagenui_name = kagenui_names[p.kagenui_type]
					st.repeatable = xp.repeatable and "Repeat" or "---"
					st.cancelable = xp.cancelable and "Special" or "---"
					st.cancelable_short = xp.repeatable and "Rep." or xp.cancelable and "Sp." or "-"
					st.teching = (xp.forced_down or xp.in_bs) and "Can't" or "Can"
					st.sliding = p.sliding and "Slide" or (p.inertial and "Inertial" or "---")
					st.hurt_dodge1, st.hurt_dodge2, st.hurt_dodge3 = "", "", ""
					if p.hurt then st.hurt_dodge1, st.hurt_dodge2, st.hurt_dodge3 = db.get_dodge_name(p.hurt.dodge, "") end
					st.hurt_dodge_name = table.concat({ st.hurt_dodge1, st.hurt_dodge2, st.hurt_dodge3 }, "")
					if #st.hurt_dodge_name > 0 then st.hurt_dodge_name = "Dodge-" .. st.hurt_dodge_name end
					st.hits = {}
					st.hurts = {}
					st.throws = {}
					for _, box in ipairs(xp.hitboxies) do
						--        Top Btm Fwd Bwd Note
						-- %-6s   %3s %3s %3s %3s %-5s
						-- Hurt 1 %3s %3s %3s %3s %-5s
						-- Throw2 %3s %3s %3s %3s %-5s
						if box.type.kind == db.box_kinds.attack or box.type.kind == db.box_kinds.parry then
							local blockables = not st.fake and box.blockables or nil
							local blockable_main = blockables and db.top_type_name(blockables.main) or "-"
							local blockable_sway = blockables and db.top_type_name(blockables.sway) or "-"
							local punish_name = blockables and db.get_punish_name(blockables.punish) or ""
							local anti_away = #punish_name > 0 and "Anti-" .. punish_name or "-"
							local anti_away_short = #punish_name > 0 and punish_name or "-"
							local rank = xp.is_fireball and string.format("[%s]", st.fb_rank) or ""
							local attribute = string.format("%s/%s/%s%s", blockable_main, blockable_sway, anti_away, rank)
							local parry, short_parry
							if box.type.kind == db.box_kinds.attack then
								parry, short_parry = to_parrieable_txt(box.parrieable)
							else
								parry, short_parry = "", ""
							end
							table.insert(st.hits, {
								reach = string.format("%-5s%s %3s %3s %3s %3s %-s%-s", box.type.kind, box.no, box.real_top, box.real_bottom, box.real_front, box.real_back, parry, attribute),
								attribute = attribute,
								real_top = box.real_top,
								real_bottom = box.real_bottom,
								real_front = box.real_front,
								real_back = box.real_back,
								blockable_main = blockable_main,
								blockable_sway = blockable_sway,
								punish_name = punish_name,
								anti_away = anti_away,
								anti_away_short = anti_away_short,
								rank = rank,
								parry = parry,
								short_parry = short_parry,
							})
						elseif box.type.kind == db.box_kinds.hurt or box.type.kind == db.box_kinds.block then
							local note = box.type.kind ~= db.box_kinds.block and st.hurt_dodge_name or block_names[box.id]
							table.insert(st.hurts, {
								reach = string.format("%-5s%s %3s %3s %3s %3s %-s", box.type.kind, box.no, box.real_top, box.real_bottom, box.real_front, box.real_back, note),
							})
						elseif box.type.kind == db.box_kinds.throw then
							local threshold = box.type == db.box_types.air_throw and 0 or box.threshold
							local type_name = throw_names[box.type]
							local note = string.format("Threshold %2s %-s", threshold, type_name)
							table.insert(st.throws, {
								reach = string.format("%-5s%s %3s %3s %3s %3s %-s", box.type.kind, box.no or "", box.real_top, box.real_bottom, box.real_front, box.real_back, note),
								real_top = box.real_top,
								real_bottom = box.real_bottom,
								real_front = box.real_front,
								real_back = box.real_back,
								threshold = threshold,
								type_name = type_name,
							})
						end
					end

					add(xp, state_line_types.id, string.format("Id %3s  Fb %3s  Hitbox %2s  %s", st.parent_id, st.fbid, st.id, st.name))
					if xp.attack_data ~= 0 then
						add(xp, state_line_types.damage, string.format("Damage %3s/%1s  Stun %2s/%2s Frame  %2s %s/%s", st.damage, st.chip, st.stun, st.stun_timer, st.effect, st.effect_name1, st.effect_name2))
						add(xp, state_line_types.hitstop, string.format("HitStop %2s/%2s  HitStun %2s/%2s  Parry %-s", st.hitstop, st.blockstop, st.hitstun, st.blockstun, st.parrieable))
						if xp.is_fireball then
							add(xp, state_line_types.fb_hits, string.format("%s/%s Hit  Fireball-Lv. %2s", st.max_hit_nm, st.max_hit_dn, st.fb_rank))
						else
							add(xp, state_line_types.pow, string.format("Pow  Bonus %2s  Hit %2s  Block %2s  Parry %2s  Absorb %2s  B.S. %3s", st.pow_up, st.pow_up_hit, st.pow_up_block, st.pow_revenge, st.pow_absorb, st.bs_pow))
							add(xp, state_line_types.inv, string.format("Invincible %2s  B.S. %2s  Hit %s/%s  Esaka %3s %-5s  Kagenui %-s", st.sp_invincible, st.bs_invincible, st.max_hit_nm, st.max_hit_dn, st.esaka, st.esaka_type, st.kagenui_name))
							add(xp, state_line_types.cancel, string.format("Cancel %-7s/%-7s  Teching %-5s  Rush %-s", st.repeatable, st.cancelable, st.teching, st.sliding))
						end
					end
					add(xp, state_line_types.box, "Box  # Top Btm Fwd Bwd Note")
					local uniq, buff, hurt_labels = {}, {}, {}
					for _, hit in ipairs(st.hits) do
						if not uniq[hit.attribute] then
							table.insert(buff, hit.attribute)
							uniq[hit.attribute] = true
						end
					end
					for _, hit in ipairs(st.hurts) do table.insert(hurt_labels, hit.reach) end
					if #st.hurts == 0 and not xp.is_fireball then
						table.insert(hurt_labels, string.format("%-5s%s %3s %3s %3s %3s %-s", db.box_kinds.hurt, "-", "---", "---", "---", "---", st.hurt_dodge_name))
					end
					if #hurt_labels > 0 then add(xp, state_line_types.hurt, hurt_labels) end
					if xp.attack_id ~= 0 and #st.throws > 0 then
						local throw_labels = {}
						for _, hit in ipairs(st.throws) do table.insert(throw_labels, hit.reach) end
						if #throw_labels > 0 then add(xp, state_line_types.throw, throw_labels) end
					end
					if xp.attack_id ~= 0 and #st.hits > 0 then
						local hit_labels = {}
						for _, hit in ipairs(st.hits) do table.insert(hit_labels, hit.reach) end
						if #hit_labels > 0 then add(xp, state_line_types.hit, hit_labels) end
					end
					if #buff > 0 then
						table.insert(buff, 1, st.parrieable)
						p.last_combo_attributes = buff
					end
				end
			end
			frame_txt.add(p)
		end

		-- コンボダメージ表示の更新
		for _, p in ipairs(players) do
			local op, col1, col2, col3 = p.op, {}, {}, {}
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
			table.insert(col2, string.format("%3X", op.last_combo))
			table.insert(col2, string.format("%3d(%4s)", op.combo_stun or 0, string.format("+%d", op.last_stun or 0)))
			table.insert(col2, string.format("%3d(%4s)", op.combo_stun_timer or 0, string.format("+%d", op.last_stun_timer or 0)))
			table.insert(col2, string.format("%3d(%4s)", op.combo_pow or 0, string.format("+%d", p.last_pow_up or 0)))
			table.insert(col2, #p.last_combo_attributes > 0 and p.last_combo_attributes[1] or "")
			table.insert(col3, "")
			table.insert(col3, string.format("%3d", op.max_combo_damage or 0))
			table.insert(col3, string.format("%3X", op.max_combo or 0))
			table.insert(col3, string.format("%3d", op.max_combo_stun or 0))
			table.insert(col3, string.format("%3d", op.max_combo_stun_timer or 0))
			table.insert(col3, string.format("%3d", op.max_combo_pow or 0))
			table.insert(col3, "")
			if p.disp_damage then
				ut.table_add_all(col1, { -- コンボ表示
					"Scaling",
					"Damage",
					"Combo",
					"Stun",
					"Timer",
					"Power",
					"Attribute",
				})
			end
			p.combo_col1, p.combo_col2, p.combo_col3 = col1, col2, col3
		end

		-- 状態表示データ
		for _, p in ipairs(players) do
			if p.disp_state == 2 or p.disp_state == 3 then -- 1:OFF 2:ON 3:ON:小表示 4:ON:フラグ表示 5:ON:ALL
				local label1 = {}
				local plus = ut.tstb(p.attackbit, frame_attack_types.frame_plus, true)
				local minus = ut.tstb(p.attackbit, frame_attack_types.frame_minus, true)
				table.insert(label1, string.format("%s %02d %03d %03d", p.state, p.throwing and p.throwing.threshold or 0, p.throwing and p.throwing.timer or 0, p.throw_timer or 0))
				table.insert(label1, string.format("%03X %02X %02X %02X", p.acta or 0, p.spid or 0, p.attack_data or 0, p.attack_id or 0))
				table.insert(label1, string.format("%03X %02X %02X %s%s%s", p.act, p.act_count, p.act_frame, p.update_base and "u" or "k", p.update_act and "U" or "K", p.act_data.neutral and "N" or "A"))
				table.insert(label1, string.format("%02X %02X %02X %s %s", p.hurt_state, p.sway_status, p.additional, #p.boxies, plus and "+" or (minus and "-" or "")))
				p.state_line2 = label1
			end
			if p.disp_state == 4 or p.disp_state == 5 then -- 1:OFF 2:ON 3:ON:小表示 4:ON:フラグ表示 5:ON:ALL
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

		for _, p in pairs(all_objects) do p.old_copy() end

		set_freeze(not global.pause)
	end

	local draws = {
		box = function()
			-- 順番に判定表示（キャラ、弾）
			local do_fill = not ut.tstb(global.hide, hide_options.background, true)
			for _, range in ipairs(ranges) do draw_range(range, do_fill) end -- 座標と範囲
			for _, box in ipairs(hitboxies) do draw_hitbox(box, do_fill) end -- 各種判定
		end,
		save_snap = function()
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
		end,
		key_hist = function()
			-- コマンド入力表示
			for i, p in ipairs(players) do
				local p1 = i == 1
				-- コマンド入力表示 1:OFF 2:ON 3:ログのみ 4:キーディスのみ
				if p.disp_command == 2 or p.disp_command == 3 then
					for k, log in ipairs(p.key.log) do draw_cmd(i, k, log.frame, log.key, log.spid, #p.key.log) end
					if global.frame_number <= p.on_sp_established + 60 then
						local disp, hist = {}, nil
						for hi = #p.key.cmd_hist, 1, -1 do
							hist = p.key.cmd_hist[hi]
							if global.frame_number <= hist.time then table.insert(disp, hist.txt) end
						end
						if #disp > 0 then -- 成立コマンドを表示
							local y0, col1, col2 = global.estab_cmd_y_offset, 0xFAC71585, 0x40303030
							local y1, y2 = y0 + get_line_height(), y0 + get_line_height(#disp + 1)
							local x1, x2, step
							if p1 then x1, x2, step = 0, 50, 8 else x1, x2, step = 320, 270, -8 end
							local col = col1
							for xi = x1, x2, step do
								scr:draw_box(x1, y1 - 1, xi + 1, y2 + 1, 0, col1)
								col = col - 0x18000000
							end
							draw_text(p1 and x1 + 4 or x2 + 4, y1, disp)
							for yy = y1, y1 + get_line_height(#disp), get_line_height() do
								col = 0xFAFFFFFF
								for xi = x1, x2, step do
									scr:draw_line(x1, yy, xi + 1, yy, col)
									col = col - 0x18000000
								end
							end
							draw_text(p1 and x1 + 4 or x2 + 4, y0 + 0.5, "SUCCESS", col1)
						end
					end
				end
			end
		end,
		key_gg = function()
			-- GG風コマンド入力表示
			for _, p in ipairs(players) do
				-- コマンド入力表示 1:OFF 2:ON 3:ログのみ 4:キーディスのみ
				if p.disp_command == 2 or p.disp_command == 4 then
					local xoffset, yoffset = p.key.gg.xoffset, p.key.gg.yoffset
					local oct_vt, key_xy = p.key.gg.oct_vt, p.key.gg.key_xy
					local tracks, max_track = {}, 6 -- 軌跡をつくる 軌跡は6個まで
					scr:draw_box(xoffset - 13, yoffset - 13, xoffset + 35, yoffset + 13, 0xA0303030, 0xA0303030)
					for ni = 1, 8 do -- 八角形描画
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
		end,
		proc_addr = function()
			-- ベースアドレス表示 --"OFF", "本体", "弾1", "弾2", "弾3"
			for base, p in pairs(all_objects) do
				if (p.body.disp_base - 2) * 0x200 + p.body.addr.base == base then
					draw_base(p.body.num, p.bases)
				end
			end
		end,
		damage = function()
			local _draw_text = draw_text -- draw_text_with_shadow
			local _draw_ctext = draw_ctext -- draw_ctext_with_shadow
			-- ダメージとコンボ表示
			local disp_damage = 0
			if players[1].disp_damage and players[2].disp_damage then -- 両方表示
				disp_damage = 3
			elseif players[1].disp_damage then               -- 1Pだけ表示
				disp_damage = 1
			elseif players[2].disp_damage then               -- 2Pだけ表示
				disp_damage = 2
			end
			for i, p in ipairs(players) do
				local p1 = i == 1
				--       2        1        0        1         2
				-- ------+--------+--------+--------+---------+------
				-- 999>999(100.000%)    Scaling   999>999(100.000%)
				-- 999(+999)     999     Damage   999(+999)     999
				-- 999(+999)     999     Combo    999(+999)     999
				-- 999(+999)     999     Stun     999(+999)     999
				-- 999(+999)     999     Timer    999(+999)     999
				-- 999(+999)     999     Power    999(+999)     999
				-- - - - - - - - - - - Attribute  - - - - - - - - - -
				-- High/High/Anti-Away[0]         High/High/Anti-Away[0]
				if p.combo_col1 and #p.combo_col1 > 0 and disp_damage ~= 0 then
					local y = 19.7
					local col2_lines = #p.combo_col2 + math.max(#players[1].last_combo_attributes, #players[2].last_combo_attributes, 1) - 1
					local h = math.max(#p.combo_col1, col2_lines, #p.combo_col3)
					if disp_damage == 2 or (p1 and disp_damage ~= 2) then
						local col, wi = 0xA0303030, 27
						local w = screen.s_width * wi
						local x1, x2 = scr.width // 2 - w, scr.width // 2 + w
						if disp_damage == 1 then
							x2 = scr.width // 2 + screen.s_width * 5
						elseif disp_damage == 2 then
							x1 = scr.width // 2 - screen.s_width * 5
						end
						for ri = 1, 6 do
							scr:draw_box(x1, y + get_line_height(ri - 1) + 0.5,
								x2, y + get_line_height(ri), 0, col) -- 四角枠
						end
						scr:draw_box(x1, y + get_line_height(6) + 0.5,
							x2, y + get_line_height(h), 0, col) -- 四角枠
						_draw_text("center", y, p.combo_col1)
					end
					local x = scr.width // 2 + screen.s_width * (p1 and -23 or 5)
					_draw_text(x, y, p.combo_col2)
					local attris = {}
					for ai = 2, #p.last_combo_attributes do table.insert(attris, p.last_combo_attributes[ai]) end
					_draw_ctext(x + screen.s_width * 10, y + get_line_height(7), attris)
					_draw_text(scr.width // 2 + screen.s_width * (p1 and -10 or 18), y, p.combo_col3)
				end
			end
		end,
		state_large = function()
			local _draw_text = draw_text -- draw_text_with_shadow
			local h = screen.s_height * 0.8
			-- 状態 大表示 1:OFF 2:ON 3:ON:小表示 4:ON:フラグ表示 5:ON:ALL
			for i, ap in ut.ifind_all(players, function(p) return p.disp_state == 5 or p.disp_state == 2 end) do
				local p1, x1, y1 = i == 1, 0, 40
				local x2 = x1 + 160
				if not p1 then x1, x2 = scr.width - x2, scr.width - x1 end
				scr:draw_box(x1, 40, x2, scr.height, 0, 0xA0303030) -- 四角枠
				for _, p in ipairs(ap.objects) do
					x1 = x1 + 1
					for li = 1, max_state_line_types do
						local line = p.large_states[li]
						if line then
							local col = 0xFFA0A0A0
							if (p.is_fireball and p.proc_active) or (not p.is_fireball and p.last_attack_data == line.attack) then
								col = 0xFFFFFFFF
							end
							if type(line.txt) == "table" then
								for _, txt in ipairs(line.txt) do
									_draw_text(x1 + 1, y1, txt, col)
									y1 = y1 + h
								end
							elseif line.txt then
								_draw_text(x1 + 1, y1, line.txt, col)
								y1 = y1 + h
							end
						end
					end
				end
			end
			--for i, p in ut.ifind_all(players, function(p) return p.disp_state == 5 or p.disp_state == 2 end) do
		end,
		state_small = function()
			local _draw_text = draw_text -- draw_text_with_shadow
			-- 状態 大表示 1:OFF 2:ON 3:ON:小表示 4:ON:フラグ表示 5:ON:ALL
			for i, p in ut.ifind_all(players, function(p) return p.disp_state == 2 or p.disp_state == 3 or p.disp_state == 5 end) do
				local p1 = i == 1
				local x1, y1 = 0, 0.3
				local x2 = x1 + 35
				if not p1 then x1, x2 = scr.width - x2, scr.width - x1 end
				local label1 = p.state_line2 or {}
				scr:draw_box(x1, get_line_height(y1), x2, get_line_height(y1 + #label1), 0, 0xA0303030)
				_draw_text(1 + x1, get_line_height(y1), label1)
			end
		end,
		state_flag = function()
			local _draw_text = draw_text -- draw_text_with_shadow
			-- 状態 大表示 1:OFF 2:ON 3:ON:小表示 4:ON:フラグ表示 5:ON:ALL
			for i, p in ut.ifind_all(players, function(p) return p.disp_state == 4 or p.disp_state == 5 end) do
				local p1 = i == 1
				local label2 = p.state_line3 or {}
				local y1 = 50 + get_line_height(p1 and 0 or (#label2 + 0.5))
				scr:draw_box(40, y1, 280, y1 + get_line_height(#p.state_line3), 0, 0xA0303030)
				_draw_text(40, y1, label2)
			end
		end,
		stun = function()
			local _draw_text = draw_text -- draw_text_with_shadow
			-- 気絶表示
			for i, p in ipairs(players) do
				local p1 = i == 1
				if p.disp_stun then
					local b1, b2, mt, remain, tx = {}, {}, {}, math.max(0, p.stun_limit - p.hit_stun), 56
					b1.x1, b1.y1, b1.x2, b1.y2   = 48, 29, 48 + p.stun_limit + 2, 35
					b2.x1, b2.y1, b2.x2, b2.y2   = b1.x1 + 1, b1.y1 + 1, b1.x2 - 1, b1.y2 - 1
					mt.x1, mt.y1, mt.x2, mt.y2   = b2.x1 + p.hit_stun, b2.y1, b2.x2, b2.y2
					if not p1 then
						b1.x1, b1.x2 = 320 - b1.x1, 320 - b1.x2
						b2.x1, b2.x2 = 320 - b2.x1, 320 - b2.x2
						mt.x1, mt.x2 = 320 - mt.x1, 320 - mt.x2
						tx = 300 - tx
					end
					scr:draw_box(b1.x1, b1.y1, b1.x2, b1.y2, 0, 0xFF676767) -- 枠
					scr:draw_box(b2.x1, b2.y1, b2.x2, b2.y2, 0, 0xFFFF0000) -- 黒背景
					scr:draw_box(mt.x1, mt.y1, mt.x2, mt.y2, 0, 0xFF000000) -- 気絶値
					local stun_y = b1.y1 - 1

					b1.x1, b1.y1, b1.x2, b1.y2 = 48, b1.y1 + 5, 140, b1.y2 + 5
					b2.x1, b2.y1, b2.x2, b2.y2 = b1.x1 + 1, b1.y1 + 1, b1.x2 - 1, b1.y2 - 1
					mt.x1, mt.y1, mt.x2, mt.y2 = b2.x1, b2.y1, b2.x1 + p.hit_stun_timer, b2.y2

					if not p1 then
						b1.x1, b1.x2 = 320 - b1.x1, 320 - b1.x2
						b2.x1, b2.x2 = 320 - b2.x1, 320 - b2.x2
						mt.x1, mt.x2 = 320 - mt.x1, 320 - mt.x2
					end
					scr:draw_box(b1.x1, b1.y1, b1.x2, b1.y2, 0, 0xFF676767) -- 枠
					scr:draw_box(b2.x1, b2.y1, b2.x2, b2.y2, 0, 0xFF000000) -- 黒背景
					scr:draw_box(mt.x1, mt.y1, mt.x2, mt.y2, 0, 0xFFFF8C00) -- 気絶タイマー
					_draw_text(tx, b1.y1 - 1, string.format("%3s", p.hit_stun_timer), 0xFFDDDDFF)
					_draw_text(tx - 6, stun_y, string.format("(%3s)%3s/%3s", math.max(0, p.stun_limit - p.hit_stun), p.hit_stun, p.stun_limit), 0xFFDDDDFF)
					_draw_text(tx, 19.7, string.format("%3s/%3s", p.life, 0xC0), 0xFFDDDDFF)
					_draw_text(tx, scr.height - get_line_height(2.2), string.format("%3s/%3s", p.pow, 0x3C), 0xFFDDDDFF)
				end
			end
		end,
		command = function()
			local _draw_text = draw_text -- draw_text_with_shadow
			local _draw_rtext = draw_rtext -- draw_rtext_with_shadow
			-- コマンド入力状態表示
			for i, p in ut.ifind(players, function(p, i) return global.disp_input < 4 and global.disp_input - 1 == i end) do
				local scale = 0.8
				local height = get_line_height(#p.input_states) * scale
				local yoffset = math.max(0, (scr.height - height) / 2)
				scr:draw_box(70, yoffset, 250, yoffset + height, 0xA0303030, 0xA0303030)
				for ti, state in ipairs(p.input_states) do
					local x, y = 147, yoffset + get_line_height(ti - 1) * scale
					local x1, x2, y2, cmdx, cmdy = x + 15, x - 8, y, x - 50, y
					_draw_text(x1, cmdy, state.tbl.name,
						state.input_estab == true and input_state.col.orange2 or input_state.col.white)
					if state.on > 0 and state.chg_remain > 0 then
						local col, col2 = input_state.col.yellow, input_state.col.yellow2
						if state.charging == true then col, col2 = input_state.col.green, input_state.col.green2 end
						scr:draw_box(x2 + state.max * 2, y + 1, x2, y + get_line_height() - 1, col2, 0)
						scr:draw_box(x2 + state.chg_remain * 2, y + 1, x2, y + get_line_height() - 1, 0, col)
					end
					for ci, c in ipairs(state.tbl.lr_cmds[p.cmd_side]) do
						if c ~= "" then
							_draw_text(cmdx, cmdy, c,
								state.input_estab == true and input_state.col.orange or
								state.on > ci and input_state.col.red or
								(ci == 1 and state.on >= ci) and input_state.col.red or nil)
							if #c > 3 then
								cmdx = cmdx + get_string_width(c)
							else
								cmdx = cmdx + 5.5
							end
						end
					end
					_draw_rtext(x + 1, y, state.chg_remain)
					_draw_text(x + 4, y, "/")
					_draw_text(x + 7, y, state.max)
					if state.debug then
						_draw_rtext(x + 25, y, state.on)
						_draw_rtext(x + 40, y, state.on_prev)
					end
				end
			end
		end,
		charge = function()
			local _draw_text = draw_text -- draw_text_with_shadow
			local _draw_rtext = draw_rtext -- draw_rtext_with_shadow
			-- コマンド入力状態表示 ため時間
			for i, p in ut.ifind(players, function(p, i) return global.disp_input > 3 and ((global.disp_input - 4 == i) or global.disp_input == 4) end) do
				local buff = p.chaging or {}
				local scale = 0.8
				local yoffset = scr.height / 2 - get_line_height(#buff)
				for ti, state in ipairs(buff) do
					local x, y = math.min(230, p.pos - 20 - screen.left), yoffset + get_line_height(ti - 1) * scale
					local x1, x2, y2, cmdx, cmdy = x + 15, x - 8, y, x - 50, y
					_draw_text(x1, cmdy, state.tbl.name,
						state.input_estab == true and input_state.col.orange2 or input_state.col.white)
					local col, col2 = input_state.col.yellow, input_state.col.yellow2
					if state.charging then
						col, col2 = input_state.col.green, input_state.col.green2
					else
						col, col2 = input_state.col.gray, input_state.col.gray2
					end
					if state.chg_remain > 0 then
						scr:draw_box(x2 + state.max * 2, y + 1, x2, y + get_line_height() - 1, col2, 0)
						scr:draw_box(x2 + state.chg_remain * 2, y + 1, x2, y + get_line_height() - 1, 0, col)
					elseif state.max > 0 then
						scr:draw_box(x2 + state.max * 2, y + 1, x2, y + get_line_height() - 1, col2, 0)
						scr:draw_box(x2 + state.chg_remain * 2, y + 1, x2, y + get_line_height() - 1, 0, col)
					elseif state.chg_remain == 0 then
						scr:draw_box(x2 + state.max * 2, y + 1, x2, y + get_line_height() - 1, col2, 0)
						scr:draw_box(x2 + state.chg_remain * 2, y + 1, x2, y + get_line_height() - 1, 0, col)
					end
					_draw_rtext(x + 1, y, state.chg_remain)
					_draw_text(x + 4, y, "/")
					_draw_text(x + 7, y, state.max)
				end
			end
		end,
		revenge_count = function()
			local _draw_text = draw_text -- draw_text_with_shadow
			-- BS状態表示
			-- ガードリバーサル状態表示
			for i, p in ipairs(players) do
				local p1 = i == 1
				if global.disp_bg then
					local bs_label = {}
					if p.bs and global.dummy_bs_cnt > 1 then
						table.insert(bs_label, string.format("%02d回ガードでBS",
							p.gd_bs_enabled and global.dummy_bs_cnt > 1 and 0 or (global.dummy_bs_cnt - math.max(p.bs_count, 0))))
					end
					if p.dummy_wakeup == wakeup_type.rvs and global.dummy_rvs_cnt > 1 then
						table.insert(bs_label, string.format("%02d回ガードでRev.",
							p.gd_rvs_enabled and global.dummy_rvs_cnt > 1 and 0 or (global.dummy_rvs_cnt - math.max(p.rvs_count, 0))))
					end
					if #bs_label > 0 then
						_draw_text(p1 and 48 or 230, 40, bs_label, p.on_block <= global.frame_number and 0xFFFFFFFF or 0xFF00FFFF)
					end
				end
			end
		end,
		frame_mini = function()
			-- フレーム表示
			for i, p in ipairs(players) do
				local p1 = i == 1
				if p.disp_frame > 1 then -- フレームメーター 1:OFF 2:ON
					frame_meter.draw_mini(p.frame_groups, p1 and 40 or 165, 63, 120)
				end
			end
		end,
		frame_sf6 = function()
			local _draw_text = draw_text -- draw_text_with_shadow
			-- フレーム表示
			local draw_frame_labels = {}
			for i, p in ipairs(players) do
				local p1 = i == 1
				if global.disp_frame > 1 then -- スト6風フレームメーター -- 1:OFF, 2:ON:大表示, 3:ON:大表示(+1P情報), 4:ON:大表示(+2P情報)
					local startup, total, draw_label = frame_meter.draw_sf6(p, frame_meter.y_offset + get_line_height(p1 and 0 or 1.5))
					table.insert(draw_frame_labels, { total = total, func = draw_label })
					-- 確定反撃の表示
					_draw_text(p1 and 112 or 184, get_line_height(1.3), "PUNISH", p.on_punish <= global.frame_number and 0xFF808080 or 0xFF00FFFF)
				end
				if i == 2 then for j, draw in ipairs(draw_frame_labels) do draw.func(draw_frame_labels[3 - j].total) end end
			end
		end,
		position = function()
			local _draw_text = draw_text -- draw_text_with_shadow
			-- キャラの向きとキャラ間の距離表示
			-- 向き・距離・位置表示 1;OFF 2:ON 3:向き・距離のみ 4:位置のみ
			if global.disp_pos > 1 then
				local col, y4, y5, y6 = 0xA0303030, get_line_height(2.3), get_line_height(0.3), scr.height - get_line_height(1.5)
				scr:draw_box(88, y6, scr.width - 88, y6 + get_line_height(), 0, col)
				for i, p in ipairs(players) do
					local flip       = p.flip_x == 1 and ">" or "<" -- 見た目と判定の向き
					local side       = p.block_side == 1 and ">" or "<" -- ガード方向や内部の向き 1:右向き -1:左向き
					local i_side     = p.cmd_side == 1 and ">" or "<" -- コマンド入力の向き
					local b_side     = p.last_block_side and (p.last_block_side == 1 and ">" or "<") or " " -- ヒットorガード時の方向
					local z1, z2, z3 = p.pos_hist[1].z, p.pos_hist[2].z, p.pos_hist[3].z
					local y1, y2, y3 = p.pos_hist[1].y, p.pos_hist[2].y, p.pos_hist[3].y
					local x1, x2, x3 = p.pos_hist[1].x, p.pos_hist[2].x, p.pos_hist[3].x
					if z3 ~= z2 or not p.last_posz_txt then
						p.last_posz_txt = string.format("Z:%s>%s>%s", z1, z2, z3)
					end
					if y3 ~= y2 or not p.last_posy_txt then
						p.last_posy_txt = string.format("Y:%s>%s>%s", y1, y2, y3)
					end
					if x3 ~= x2 or not p.last_posx_txt then
						p.last_posx_txt = string.format("X:%s>%s>%s", x1, x2, x3)
					end
					if global.disp_pos == 2 or global.disp_pos == 4 then
						local tx1 = i == 1 and 36 or 221
						local tx2 = i == 1 and 100 or 193
						scr:draw_box(tx1, y5, tx1 + 63, y5 + get_line_height(2), 0, col)
						scr:draw_box(tx2, y5, tx2 + 27, y5 + get_line_height(), 0, col)
						--_draw_text(i == 1 and "left" or "right", y5 - get_line_height(), { p.last_posx_txt, p.last_posy_txt })
						_draw_text(tx1 + 1, y5, { p.last_posx_txt, p.last_posy_txt })
						_draw_text(tx2 + 1, y5, p.last_posz_txt)
					end
					local tx = i == 1 and 90 or 170 - screen.s_width
					if global.disp_pos == 2 or global.disp_pos == 3 then
						if i == 1 then
							_draw_text(tx, y6, string.format("Disp.%s Block.%s(%s) Input.%s", flip, side, b_side, i_side))
						else
							_draw_text(tx, y6, string.format("Input.%s Block.%s(%s) Disp.%s", i_side, side, b_side, flip))
						end
					end
				end
				_draw_text("center", y6, string.format("%3d", math.abs(p_space)))
			end
		end,
		record_replay = function()
			-- レコーディング状態表示
			if global.disp_replay and recording.info and (global.dummy_mode == 5 or global.dummy_mode == 6) then
				local time = global.rec_main == recording.procs.play and
					ut.frame_to_time(#recording.active_slot.store - recording.play_count) or
					ut.frame_to_time(recording.max_frames - #recording.active_slot.store)
				scr:draw_box(235, 200, 315, 224, 0, 0xA0303030)
				for i, info in ipairs(recording.info) do
					draw_text(239, 204 + get_line_height(i - 1), string.format(info.label, recording.last_slot, time), info.col)
				end
			end
		end,
	}

	-- メイン処理
	menu.tra_main.draw = function()
		if not in_match then return end
		draws.box()
		draws.save_snap()
		draws.key_hist()
		draws.key_gg()
		draws.stun()
		draws.damage()
		draws.revenge_count()
		draws.position()
		draws.frame_sf6()
		draws.proc_addr()
		draws.frame_mini()
		draws.state_small()
		draws.state_large()
		draws.state_flag()
		draws.command()
		draws.charge()
		draws.record_replay()
	end

	menu.to_main = function(on_a1, cancel, do_init)
		local col, row, g        = menu.training.pos.col, menu.training.pos.row, global
		local p1, p2             = players[1], players[2]

		g.dummy_mode             = col[1] -- 01 ダミーモード
		p1.dummy_act             = col[2] -- 02 1P アクション
		p2.dummy_act             = col[3] -- 03 2P アクション
		-- 04 ガード・ブレイクショット設定
		p1.dummy_gd              = col[5] -- 05 1P ガード
		p2.dummy_gd              = col[6] -- 06 2P ガード
		g.crouch_block           = col[7] == 2 -- 07 可能な限りしゃがみガード
		g.next_block_grace       = col[8] - 1 -- 08 1ガード持続フレーム数
		p1.bs                    = col[9] == 2 -- 09 1P ブレイクショット
		p2.bs                    = col[10] == 2 -- 10 2P ブレイクショット
		g.dummy_bs_cnt           = col[11] -- 11 ブレイクショット設定
		-- 12 やられ時行動・リバーサル設定
		p1.dummy_wakeup          = col[13] -- 13 1P やられ時行動
		p2.dummy_wakeup          = col[14] -- 14 2P やられ時行動
		g.dummy_rvs_cnt          = col[15] -- 15 ガードリバーサル設定
		-- 16 避け攻撃対空設定
		p1.away_anti_air.enabled = col[17] == 2 -- 17 1P 避け攻撃対空
		p2.away_anti_air.enabled = col[18] == 2 -- 18 2P 避け攻撃対空
		-- 19 その他設定
		p1.fwd_prov              = col[20] == 2 -- 20 1P 挑発で前進
		p2.fwd_prov              = col[21] == 2 -- 21 2P 挑発で前進
		for _, p in ipairs(players) do
			p.update_char()
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

		local next_menu = nil

		if p1.away_anti_air.enabled and not cancel and row == 14 then -- 1P 避け攻撃対空
			next_menu = "away_anti_air1"
		elseif p2.away_anti_air.enabled and not cancel and row == 15 then -- 2P 避け攻撃対空
			next_menu = "away_anti_air2"
		end

		if g.dummy_mode == 5 then -- レコード
			g.dummy_mode = 1 -- 設定でレコーディングに入らずに抜けたとき用にモードを1に戻しておく
			menu.recording.init()
			if not cancel and row == 1 then next_menu = "recording" end
		elseif g.dummy_mode == 6 then -- リプレイ
			g.dummy_mode = 1    -- 設定でリプレイに入らずに抜けたとき用にモードを1に戻しておく
			menu.replay.init()
			if not cancel and row == 1 then next_menu = "replay" end
		end

		-- プレイヤー選択しなおしなどで初期化したいときはサブメニュー遷移しない
		if do_init ~= true and not cancel then
			-- ブレイクショット ガードのメニュー設定
			if row == 9 and p1.bs then next_menu = menu.bs_menus[1][p1.char] end
			if row == 10 and p2.bs then next_menu = menu.bs_menus[2][p2.char] end
			if row == 5 or row == 6 then -- 特殊設定の出張設定項目
				local col1 = menu.bs_menus[1][p1.char].pos.col
				local col2 = menu.bs_menus[2][p1.char].pos.col
				col1[#col1] = g.all_bs and 2 or 1
				col2[#col2] = g.all_bs and 2 or 1
			end
			-- リバーサル やられ時行動のメニュー設定
			if row == 13 and rvs_wake_types[p1.dummy_wakeup] then next_menu = menu.rvs_menus[1][p1.char] end
			if row == 14 and rvs_wake_types[p2.dummy_wakeup] then next_menu = menu.rvs_menus[2][p2.char] end
		end

		menu.set_current(next_menu)
	end
	menu.to_main_cancel = function() menu.to_main(nil, true, false) end
	for i = 1, 0xC0 - 1 do table.insert(menu.labels.life_range, i) end
	for i = 1, 0x3C - 1 do table.insert(menu.labels.pow_range, i) end

	menu.rec_to_tra           = function() menu.set_current("training") end
	menu.exit_and_rec         = function(slot_no, enabled)
		if not enabled then return end
		local g               = global
		g.dummy_mode          = 5
		g.rec_main            = recording.procs.await_no_input
		input.accepted        = scr:frame_number()
		recording.temp_player = players[1].reg_pcnt ~= 0 and 1 or 2
		recording.last_slot   = slot_no
		recording.active_slot = recording.slot[slot_no]
		menu.set_current()
		menu.exit()
	end
	menu.exit_and_play_common = function()
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
	menu.exit_and_rec_pos     = function()
		local g = global
		g.dummy_mode = 6 -- リプレイモードにする
		g.rec_main = recording.procs.fixpos
		input.accepted = scr:frame_number()
		recording.temp_player = players[1].reg_pcnt ~= 0 and 1 or 2
		menu.exit_and_play_common()
		menu.set_current()
		menu.exit()
	end
	menu.exit_and_play        = function()
		local col, g = menu.replay.pos.col, global
		if menu.replay.pos.row == 14 and col[14] == 2 then -- 開始間合い固定 / 記憶
			menu.exit_and_rec_pos()
			return
		end
		g.dummy_mode = 6 -- リプレイモードにする
		g.rec_main = recording.procs.await_play
		input.accepted = scr:frame_number()
		menu.exit_and_play_common()
		menu.set_current()
		menu.exit()
	end
	menu.exit_and_play_cancel = function()
		local g = global
		g.dummy_mode = 6 -- リプレイモードにする
		g.rec_main = recording.procs.await_play
		input.accepted = scr:frame_number()
		menu.exit_and_play_common()
		menu.to_tra()
	end


	menu.to_tra                   = function() menu.set_current("training") end
	menu.to_bar                   = function() menu.set_current("bar") end
	menu.to_disp                  = function() menu.set_current("disp") end
	menu.to_ex                    = function() menu.set_current("extra") end
	menu.to_auto                  = function() menu.set_current("auto") end
	menu.to_col                   = function() menu.set_current("color") end
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
	menu.on_restart_fight_a       = function()
		---@diagnostic disable-next-line: undefined-field
		local col, g, o = menu.main.pos.col, global, hide_options
		restart_fight({
			next_p1    = col[9],          -- 1P セレクト
			next_p2    = col[10],         -- 2P セレクト
			next_p1col = col[11] - 1,     -- 1P カラー
			next_p2col = col[12] - 1,     -- 2P カラー
			next_stage = menu.stage_list[col[13]], -- ステージセレクト
			next_bgm   = menu.bgms[col[14]].id, -- BGMセレクト
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
	menu.set_hide                 = function(bit, val) return ut.hex_set(global.hide, bit, val) end
	menu.organize_disp_config     = function()
		local col, p, g, o, c = menu.disp.pos.col, players, global, hide_options, menu.config
		-- 01 1P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
		if c.disp_box_range1p == 1 then
			p[1].disp_hitbox, p[1].disp_range = false, false
		elseif c.disp_box_range1p == 2 then
			p[1].disp_hitbox, p[1].disp_range = true, true
		elseif c.disp_box_range1p == 3 then
			p[1].disp_hitbox, p[1].disp_range = true, false
		elseif c.disp_box_range1p == 4 then
			p[1].disp_hitbox, p[1].disp_range = false, true
		end
		-- 02 2P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
		if c.disp_box_range2p == 1 then
			p[2].disp_hitbox, p[2].disp_range = false, false
		elseif c.disp_box_range2 == 2 then
			p[2].disp_hitbox, p[2].disp_range = true, true
		elseif c.disp_box_range2p == 3 then
			p[2].disp_hitbox, p[2].disp_range = true, false
		elseif c.disp_box_range2p == 4 then
			p[2].disp_hitbox, p[2].disp_range = false, true
		end
		-- 03 気絶メーター表示  1:OFF 2:ON 3:1P 4:2P
		if c.disp_stun == 1 then
			p[1].disp_stun, p[2].disp_stun = false, false
		elseif c.disp_stun == 2 then
			p[1].disp_stun, p[2].disp_stun = true, true
		elseif c.disp_stun == 3 then
			p[1].disp_stun, p[2].disp_stun = true, false
		elseif c.disp_stun == 4 then
			p[1].disp_stun, p[2].disp_stun = false, true
		end
		-- 04 ダメージ表示  1:OFF 2:ON 3:1P 4:2P
		if c.disp_damage == 1 then
			p[1].disp_damage, p[2].disp_damage = false, false
		elseif c.disp_damage == 2 then
			p[1].disp_damage, p[2].disp_damage = true, true
		elseif c.disp_damage == 3 then
			p[1].disp_damage, p[2].disp_damage = true, false
		elseif c.disp_damage == 4 then
			p[1].disp_damage, p[2].disp_damage = false, true
		end
		-- 9 フレームメーター表示
		-- 1:OFF, 2:ON:大表示, 3:ON:大表示(+1P情報), 4:ON:大表示(+2P情報), 5:ON:小表示, 6:ON:小表示 1Pのみ, 7:ON:小表示 2Pのみ
		if c.disp_frame == 1 then
			g.disp_frame, p[1].disp_frame, p[2].disp_frame = 1, 1, 1
		elseif c.disp_frame == 2 then
			g.disp_frame, p[1].disp_frame, p[2].disp_frame = 2, 1, 1
		elseif c.disp_frame == 3 then
			g.disp_frame, p[1].disp_frame, p[2].disp_frame = 3, 1, 1
		elseif c.disp_frame == 4 then
			g.disp_frame, p[1].disp_frame, p[2].disp_frame = 4, 1, 1
		elseif c.disp_frame == 5 then
			g.disp_frame, p[1].disp_frame, p[2].disp_frame = 1, 2, 2
		elseif c.disp_frame == 6 then
			g.disp_frame, p[1].disp_frame, p[2].disp_frame = 1, 2, 1
		elseif c.disp_frame == 7 then
			g.disp_frame, p[1].disp_frame, p[2].disp_frame = 1, 1, 2
		end
		-- 10 フレームメーター設定  1:ON 2:ON:判定の形毎 3:ON:攻撃判定の形毎 4:ON:くらい判定の形毎
		local set_split_frame = function(p, val) if 1 < p.disp_frame then p.disp_frame = val end end
		set_split_frame(p[1], c.split_frame + 1)
		set_split_frame(p[2], c.split_frame + 1)
		-- 11 フレームメーター弾表示  1:OFF 2:ON
		p[1].disp_fb_frame, p[2].disp_fb_frame = c.disp_fb_frame, c.disp_fb_frame
		-- 20 キャラ表示 1:OFF 2:ON 3:1P 4:2P
		if c.disp_char == 1 then
			g.hide = menu.set_hide(o.p1_char, false) -- 1P キャラ表示
			g.hide = menu.set_hide(o.p2_char, false) -- 2P キャラ表示
		elseif c.disp_char == 2 then
			g.hide = menu.set_hide(o.p1_char, true) -- 1P キャラ表示
			g.hide = menu.set_hide(o.p2_char, true) -- 2P キャラ表示
		elseif c.disp_char == 3 then
			g.hide = menu.set_hide(o.p1_char, true) -- 1P キャラ表示
			g.hide = menu.set_hide(o.p2_char, false) -- 2P キャラ表示
		elseif c.disp_char == 4 then
			g.hide = menu.set_hide(o.p1_char, false) -- 1P キャラ表示
			g.hide = menu.set_hide(o.p2_char, true) -- 2P キャラ表示
		end
		-- 21 残像表示 1:OFF 2:ON 3:1P 4:2P
		g.hide = menu.set_hide(o.p1_phantasm, c.disp_phantasm) -- 1P 残像表示
		g.hide = menu.set_hide(o.p2_phantasm, c.disp_phantasm) -- 2P 残像表示
		-- 22 エフェクト表示 1:OFF 2:ON 3:1P 4:2P
		g.hide = menu.set_hide(o.p1_effect, c.disp_effect) -- 1P エフェクト表示
		g.hide = menu.set_hide(o.p2_effect, c.disp_effect) -- 2P エフェクト表示		
	end
	menu.organize_time_config     = function(time_mode, proceed_cpu)
		local g, d                 = global, dip_config
		g.time_mode, g.proceed_cpu = time_mode, proceed_cpu
		if g.time_mode == 4 then
			g.snk_time, d.fix_time, d.aes_time = 1, 0x90, 0x02  -- 残タイム家庭用オプション 0x0:45 0x1:60 0x2:90 0x3:infinity
		elseif g.time_mode == 5 then
			g.snk_time, d.fix_time, d.aes_time = 1, 0x60, 0x01  -- 残タイム家庭用オプション 0x0:45 0x1:60 0x2:90 0x3:infinity
		elseif g.time_mode == 6 then
			g.snk_time, d.fix_time, d.aes_time = 1, 0x45, 0x00  -- 残タイム家庭用オプション 0x0:45 0x1:60 0x2:90 0x3:infinity
		else
			g.snk_time, d.fix_time, d.aes_time = g.time_mode, 0xAA, 0x03 -- 残タイム家庭用オプション 0x0:45 0x1:60 0x2:90 0x3:infinity
		end
		mod.snk_time(g.snk_time)
	end
	menu.organize_life_config     = function(life_mode)
		local g, d                   = global, dip_config
		g.life_mode, d.infinity_life = life_mode, life_mode == 2 -- 体力ゲージモード 1:自動回復 2:固定 3:通常動作
	end
	menu.on_mode_change           = function(p_no)
		---@diagnostic disable-next-line: undefined-field
		local col, g, c = menu.main.pos.col, global, menu.config
		local cpu = col[16] == 2
		c.disp_frame = cpu and 1 or 2            -- フレームメーター表示 1:OFF 2:ON:大表示
		menu.organize_disp_config()
		menu.organize_time_config(cpu and 4 or 1, cpu) -- タイム設定 4:90 1:RB2(デフォルト)
		menu.organize_life_config(cpu and 3 or 1) -- 体力ゲージモード 3:通常動作 1:自動回復
		g.pow_mode = cpu and 3 or 2              -- POWゲージモード 3:通常動作 2:固定
		g.cpu_wait = cpu and 4 or 5              -- CPU待ち時間 4:25% 5:0%
		mod.cpu_wait(g.cpu_wait)
		g.sokaku_stg = not cpu                   -- 対戦双角ステージ
		mod.sokaku_stg(global.sokaku_stg)
		set_dip_config(true)
		menu.on_player_select(p_no)
		if cpu then mod.init_select() end
		mod.training(not cpu)
		machine:soft_reset()
	end
	menu.main                     = menu.create(
		"トレーニングメニュー",
		"",
		{
			{ "ダミー設定", { "Aでダミー設定へ" } },
			{ "ゲージ設定", { "Aでゲージ設定へ" } },
			{ "表示設定", { "Aで表示設定へ" } },
			{ "追加動作・改造動作設定", { "Aで追加動作・改造動作設定へ" } },
			{ "特殊設定", { "Aで特殊設定へ" } },
			{ "判定個別設定", { "Aで判定個別設定へ" } },
			{ "プレイヤーセレクト画面", { "Aでプレイヤーセレクト画面へ" } },
			{ title = true, "クイックセレクト(選択時はリスタートします)" },
			{ "1P セレクト", menu.labels.chars },
			{ "2P セレクト", menu.labels.chars },
			{ "1P カラー", { "Aボタンカラー", "Dボタンカラー" } },
			{ "2P カラー", { "Aボタンカラー", "Dボタンカラー" } },
			{ "ステージセレクト", menu.labels.stage_list },
			{ "BGMセレクト", menu.labels.bgms },
			{ title = true, "トレーニングと通常のCPU戦を切り替えます" },
			{ "モード切替", { "Aでトレーニングへ切替&リセット", "AでCPU戦モードへ切替&リセット" } },
			{ title = true, "プラグイン終了後もMEMEメニューから再度有効化できます" },
			{ "プラグイン終了", { "----", "Aでプラグイン終了&リセット" } },
		},
		function() end,
		{
			menu.to_tra,                                           -- ダミー設定
			menu.to_bar,                                           -- ゲージ設定
			menu.to_disp,                                          -- 表示設定
			menu.to_auto,                                          -- 追加動作・改造動作設定
			menu.to_ex,                                            -- 特殊設定
			menu.to_col,                                           -- 判定個別設定
			menu.on_player_select,                                 -- プレイヤーセレクト画面
			function() end,                                        -- クイックセレクト
			menu.on_restart_fight_a,                               -- 1P セレクト
			menu.on_restart_fight_a,                               -- 2P セレクト
			menu.on_restart_fight_a,                               -- 1P カラー
			menu.on_restart_fight_a,                               -- 2P カラー
			menu.on_restart_fight_a,                               -- ステージセレクト
			menu.on_restart_fight_a,                               -- BGMセレクト
			function() end,                                        -- ラベル
			menu.on_mode_change,
			function() end,                                        -- ラベル
			function() rbff2.self_disable = menu.main.pos.col[18] == 2 end, -- プラグイン終了
		},
		ut.new_filled_table(18, menu.exit))

	menu.current                  = menu.main -- デフォルト設定
	menu.update_pos               = function()
		---@diagnostic disable-next-line: undefined-field
		local col = menu.main.pos.col

		-- メニューの更新
		col[9] = math.min(math.max(mem.r08(0x107BA5), 1), #menu.labels.chars)
		col[10] = math.min(math.max(mem.r08(0x107BA7), 1), #menu.labels.chars)
		col[11] = math.min(math.max(mem.r08(0x107BAC) + 1, 1), 2)
		col[12] = math.min(math.max(mem.r08(0x107BAD) + 1, 1), 2)

		menu.reset_pos = false

		local stg1, stg2, stg3 = mem.r08(0x107BB1), mem.r08(0x107BB7), mem.r16(0x107BB8)
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

		col[18] = 1 -- プラグイン終了可否 表示時は常に1

		-- キャラにあわせたメニュー設定
		for _, p in ipairs(players) do
			p.update_char()
			if p.dummy_gd == dummy_gd_type.hit1 then
				p.next_block, p.next_block_ec = false, 75 -- カウンター初期化 false
			elseif p.dummy_gd == dummy_gd_type.block1 then
				p.next_block, p.next_block_ec = true, 75 -- カウンター初期化 true
			end
			p.block1 = 0
			p.rvs_count, p.dummy_rvs_chr, p.dummy_rvs = -1, p.char, get_next_rvs(p) -- リバサガードカウンター初期化、キャラとBSセット
			p.bs_count, p.dummy_bs_chr, p.dummy_bs = -1, p.char, get_next_bs(p) -- BSガードカウンター初期化、キャラとBSセット
		end
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
		for _, prvs in ipairs(menu.rvs_menus) do
			for _, a_bs_menu in ipairs(prvs) do
				if menu.current == a_bs_menu then
					cur_prvs = prvs
					break
				end
			end
			if cur_prvs then break end
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
		for _, char_data in pairs(db.chars) do
			if not char_data.bs then break end
			local list, on_ab, col = {}, {}, {}
			table.insert(pbs, {
				name = string.format("ブレイクショット選択(%s)", char_data.name),
				desc = "ONにしたスロットからランダムで発動されます。\n*がついたものは「全必殺技でBS可能」がON時のみ有効です。",
				list = list,
				pos = { offset = 1, row = 1, col = col, },
				on_a = on_ab,
				on_b = on_ab,
			})
			local to_tra = function()
				local g = global
				g.all_bs = col[#col] == 2
				mod.all_bs(g.all_bs)
				menu.to_tra()
			end
			for _, bs in ipairs(char_data.bs) do
				local name, ex_breakshot = bs.name, ut.tstb(bs.hook_type, hook_cmd_types.ex_breakshot, true)
				if ex_breakshot then name = "*" .. name end
				table.insert(list, { name, menu.labels.off_on, common = bs.common == true, row = #list, ex_breakshot = ex_breakshot })
				table.insert(on_ab, to_tra)
				table.insert(col, 1)
			end
			table.insert(list, { title = true, "特殊設定" })
			table.insert(on_ab, to_tra)
			table.insert(col, 0)
			table.insert(list, { "全必殺技でBS可能", menu.labels.off_on })
			table.insert(on_ab, to_tra)
			table.insert(col, 1)
		end
		for _, char_data in pairs(db.chars) do
			if not char_data.rvs then break end
			local list, on_ab, col = {}, {}, {}
			table.insert(prvs, {
				name = string.format("リバーサル技選択(%s)", char_data.name),
				desc = "ONにしたスロットからランダムで発動されます。",
				list = list,
				pos = { offset = 1, row = 1, col = col, },
				on_a = on_ab,
				on_b = on_ab,
			})
			for _, bs in ipairs(char_data.rvs) do
				table.insert(list, { ut.convert(bs.name), menu.labels.off_on, common = bs.common == true, row = #list, })
				table.insert(on_ab, menu.rvs_to_tra)
				table.insert(col, 1)
			end
		end
	end
	for i = 1, 61 do table.insert(menu.labels.block_frames, string.format("%sF後にガード解除", (i - 1))) end
	for i = 1, 99 do table.insert(menu.labels.attack_harmless, string.format("%s段目で空振り", i)) end

	for i = 1, 2 do
		local limit = { "OFF" }
		for px = 1, 100 do table.insert(limit, px) end
		local key = string.format("away_anti_air%s", i)
		menu[key] = menu.create(
			string.format("%sP 避け攻撃対空設定", i),
			"トレーニングダミーが避け攻撃を出す条件を設定します。",
			{
				{ "通常ジャンプ高度", limit },
				{ "上りジャンプ攻撃高度", limit },
				{ "下りジャンプ攻撃高度", limit },
				{ "小ジャンプ高度", limit },
				{ "上り小ジャンプ攻撃高度", limit },
				{ "下り小ジャンプ攻撃高度", limit },
			},
			function()
				local col, a = menu[key].pos.col, players[i].away_anti_air
				col[1] = a.jump_limit1 + 1 -- 通常ジャンプ高度
				col[2] = a.jump_limit2 + 1 -- 上りジャンプ攻撃高度
				col[3] = a.jump_limit3 + 1 -- 下りジャンプ攻撃高度
				col[4] = a.hop_limit1 + 1 -- 小ジャンプ高度
				col[5] = a.hop_limit2 + 1 -- 上り小ジャンプ攻撃高度
				col[6] = a.hop_limit3 + 1 -- 下り小ジャンプ攻撃高度
			end,
			ut.new_filled_table(18, function()
				local col, a  = menu[key].pos.col, players[i].away_anti_air
				a.jump_limit1 = col[1] - 1 -- 通常ジャンプ高度
				a.jump_limit2 = col[2] - 1 -- 上りジャンプ攻撃高度
				a.jump_limit3 = col[3] - 1 -- 下りジャンプ攻撃高度
				a.hop_limit1  = col[4] - 1 -- 小ジャンプ高度
				a.hop_limit2  = col[5] - 1 -- 上り小ジャンプ攻撃高度
				a.hop_limit3  = col[6] - 1 -- 下り小ジャンプ攻撃高度
				menu.set_current()
			end))
	end

	menu.training  = menu.create(
		"ダミー設定",
		"トレーニングダミーの基本動作を設定します。",
		{
			{ "ダミーモード", { "プレイヤー vs プレイヤー", "プレイヤー vs CPU", "CPU vs プレイヤー", "1P&2P入れ替え", "レコード", "リプレイ" }, },
			{ "1P アクション", { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" }, },
			{ "2P アクション", { "立ち", "しゃがみ", "ジャンプ", "小ジャンプ", "スウェー待機" }, },
			{ title = true, "ガード・ブレイクショット設定" },
			{ "1P ガード", { "なし", "オート", "1ヒットガード", "1ガード", "上段", "下段", "アクション", "ランダム", "強制" }, },
			{ "2P ガード", { "なし", "オート", "1ヒットガード", "1ガード", "上段", "下段", "アクション", "ランダム", "強制" }, },
			{ "可能な限りしゃがみガード", menu.labels.off_on, },
			{ "1ガード持続フレーム数", menu.labels.block_frames, },
			{ "1P ブレイクショット", { "OFF", "ON（Aで選択画面へ）", }, },
			{ "2P ブレイクショット", { "OFF", "ON（Aで選択画面へ）", }, },
			{ "ブレイクショット設定", bs_blocks },
			{ title = true, "やられ時行動・リバーサル設定" },
			{ "1P やられ時行動", { "なし", "リバーサル（Aで選択画面へ）", "テクニカルライズ（Aで選択画面へ）", "グランドスウェー（Aで選択画面へ）", "起き上がり攻撃", }, },
			{ "2P やられ時行動", { "なし", "リバーサル（Aで選択画面へ）", "テクニカルライズ（Aで選択画面へ）", "グランドスウェー（Aで選択画面へ）", "起き上がり攻撃", }, },
			{ "ガードリバーサル設定", bs_blocks },
			{ title = true, "避け攻撃対空設定" },
			{ "1P 避け攻撃対空", { "OFF", "ON（Aで選択画面へ）", }, },
			{ "2P 避け攻撃対空", { "OFF", "ON（Aで選択画面へ）", }, },
			{ title = true, "その他設定" },
			{ "1P 挑発で前進", menu.labels.off_on, },
			{ "2P 挑発で前進", menu.labels.off_on, },
		},
		function()
			---@diagnostic disable-next-line: undefined-field
			local col, p, g = menu.training.pos.col, players, global
			col[1]          = g.dummy_mode                 -- 01 ダミーモード
			col[2]          = p[1].dummy_act               -- 02 1P アクション
			col[3]          = p[2].dummy_act               -- 03 2P アクション
			-- 04 ガード・ブレイクショット設定
			col[5]          = p[1].dummy_gd                -- 05 1P ガード
			col[6]          = p[2].dummy_gd                -- 06 2P ガード
			col[7]          = g.crouch_block and 2 or 1    -- 07 可能な限りしゃがみガード
			col[8]          = g.next_block_grace + 1       -- 08 1ガード持続フレーム数
			col[9]          = p[1].bs and 2 or 1           -- 08 1P ブレイクショット
			col[10]          = p[2].bs and 2 or 1           -- 10 2P ブレイクショット
			col[11]         = g.dummy_bs_cnt               -- 11 ブレイクショット設定
			-- 12 やられ時行動・リバーサル設定
			col[13]         = p[1].dummy_wakeup            -- 13 1P やられ時行動
			col[14]         = p[2].dummy_wakeup            -- 14 2P やられ時行動
			col[15]         = g.dummy_rvs_cnt              -- 15 ガードリバーサル設定
			-- 16 避け攻撃対空設定
			col[17]         = p[1].away_anti_air.enabled and 2 or 1 -- 17 1P 避け攻撃対空
			col[18]         = p[2].away_anti_air.enabled and 2 or 1 -- 18 2P 避け攻撃対空
			-- 19 その他設定
			col[20]         = p[1].fwd_prov and 2 or 1     -- 20 1P 挑発で前進
			col[21]         = p[2].fwd_prov and 2 or 1     -- 21 2P 挑発で前進
		end,
		ut.new_filled_table(21, menu.to_main),
		ut.new_filled_table(21, menu.to_main_cancel))

	menu.bar       = menu.create(
		"ゲージ設定",
		"ゲージ量とゲージ動作を設定します。",
		{
			{ "1P 体力ゲージ量", menu.labels.life_range, }, -- "最大", "赤", "ゼロ" ...
			{ "2P 体力ゲージ量", menu.labels.life_range, }, -- "最大", "赤", "ゼロ" ...
			{ "1P POWゲージ量", menu.labels.pow_range, }, -- "最大", "半分", "ゼロ" ...
			{ "2P POWゲージ量", menu.labels.pow_range, }, -- "最大", "半分", "ゼロ" ...
			{ "体力ゲージモード", { "自動回復", "固定", "通常動作" }, },
			{ "POWゲージモード", { "自動回復", "固定", "通常動作" }, },
		},
		function()
			---@diagnostic disable-next-line: undefined-field
			local col, p, g = menu.bar.pos.col, players, global
			col[1] = p[1].red -- 1P 体力ゲージ量
			col[2] = p[2].red -- 2P 体力ゲージ量
			col[3] = p[1].max -- 1P POWゲージ量
			col[4] = p[2].max -- 2P POWゲージ量
			col[5] = g.life_mode -- 体力ゲージモード
			col[6] = g.pow_mode -- POWゲージモード
		end,
		ut.new_filled_table(6, function()
			local col, p, g = menu.bar.pos.col, players, global
			p[1].red        = col[1] -- 1P 体力ゲージ量
			p[2].red        = col[2] -- 2P 体力ゲージ量
			p[1].max        = col[3] -- 1P POWゲージ量
			p[2].max        = col[4] -- 2P POWゲージ量
			menu.organize_life_config(col[5]) -- 体力ゲージモード 1:自動回復 2:固定 3:通常動作
			g.pow_mode = col[6]      -- POWゲージモード 1:自動回復 2:固定 3:通常動作
			set_dip_config(true)
			menu.set_current()
		end))

	menu.on_disp   = function(cancel)
		local col, p, g, o, c = menu.disp.pos.col, players, global, hide_options, menu.config
		c.disp_box_range1p    = col[1]                              -- 01 1P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
		c.disp_box_range2p    = col[2]                              -- 02 2P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
		p[1].disp_command     = col[3]                              -- 03 1P 入力表示  1:OFF 2:ON 3:ログのみ 4:キーディスのみ
		p[2].disp_command     = col[4]                              -- 04 2P 入力表示  1:OFF 2:ON 3:ログのみ 4:キーディスのみ
		c.disp_stun           = col[5]                              -- 05 気絶メーター表示  1:OFF 2:ON 3:1P 4:2P
		c.disp_damage         = col[6]                              -- 06 ダメージ表示  1:OFF 2:ON 3:1P 4:2P
		-- 07 フレーム表示 label
		g.disp_input          = col[8]                              -- 08 コマンド入力状態表示  1:OFF 2:1P 3:2P 4:1Pため時間 5:2Pため時間
		c.disp_frame          = col[9]                              -- 09 フレームメーター表示
		-- 1:OFF, 2:ON:大表示, 3:ON:大表示(+1P情報), 4:ON:大表示(+2P情報), 5:ON:小表示, 6:ON:小表示 1Pのみ, 7:ON:小表示 2Pのみ
		c.split_frame         = col[10]                             -- 10 フレームメーター設定  1:ON 2:ON:判定の形毎 3:ON:攻撃判定の形毎 4:ON:くらい判定の形毎
		c.disp_fb_frame       = col[11] == 2                        -- 11 フレームメーター弾表示  1:OFF 2:ON
		g.disp_neutral_frames = col[12] == 2                        -- 12 通常動作フレーム非表示  1:OFF 2:ON
		-- 13 状態表示 label
		p[1].disp_state       = col[14]                             -- 13 1P 状態表示  1:OFF 2: ON, ON:小表示, ON:大表示, ON:フラグ表示
		p[2].disp_state       = col[15]                             -- 15 2P 状態表示  1:OFF 2:ON, ON:小表示, ON:大表示, ON:フラグ表示
		p[1].disp_base        = col[16]                             -- 16 1P 処理アドレス表示  1:OFF 2:本体 3:弾1 4:弾2 5:弾3
		p[2].disp_base        = col[17]                             -- 17 2P 処理アドレス表示  1:OFF 2:本体 3:弾1 4:弾2 5:弾3
		g.disp_pos            = col[18]                             -- 18 向き・距離・位置表示  1;OFF 2:ON 3:向き・距離のみ 4:位置のみ
		-- 19 撮影用 label
		c.disp_char           = col[20]                             -- 19 キャラ表示  1:OFF 2:ON 3:1P 4:2P
		c.disp_phantasm       = col[21]                             -- 21 残像表示  1:OFF 2:ON 3:1P 4:2P
		c.disp_effect         = col[22]                             -- 22 エフェクト表示  1:OFF 2:ON 3:1P 4:2P
		g.hide                = menu.set_hide(o.p_chan, col[23] ~= 1) -- 23 Pちゃん表示 1:OFF 2:ON
		g.hide                = menu.set_hide(o.effect, col[24] ~= 1) -- 24 共通エフェクト表示  1:OFF 2:ON
		-- 25 撮影用(有効化時はリスタートします)
		g.hide                = menu.set_hide(o.meters, col[26] == 2) -- 26 体力,POWゲージ表示  1:OFF 2:ON
		g.hide                = menu.set_hide(o.background, col[27] == 2) -- 27 背景表示  1:OFF 2:ON
		g.hide                = menu.set_hide(o.shadow1, col[28] ~= 2) -- 28 影表示  1:ON 2:OFF 3:ON:反射→影
		g.hide                = menu.set_hide(o.shadow2, col[28] ~= 3) -- 29 影表示  1:ON 2:OFF 3:ON:反射→影
		g.fix_scr_top         = col[29]                             -- 29 画面カメラ位置
		-- 30 撮影用(特殊動作の強制)
		p[2].no_hit_limit     = col[31] - 1                         -- 31 1P 強制空振り
		p[1].no_hit_limit     = col[32] - 1                         -- 32 2P 強制空振り
		p[1].force_y_pos      = col[33]                             -- 33 1P Y座標強制
		p[2].force_y_pos      = col[34]                             -- 34 2P Y座標強制
		g.sync_pos_x          = col[35]                             -- 35 画面下に移動

		menu.organize_disp_config()

		menu.set_current()

		if not cancel and 26 <= menu.disp.pos.row and menu.disp.pos.row <= 29 then
			menu.on_restart_fight_a()
		end
	end

	menu.disp      = menu.create(
		"表示設定",
		"補助的な情報表示を設定します。",
		{
			{ "1P 判定・間合い表示", { "OFF", "ON", "ON:判定のみ", "ON:間合いのみ" }, },
			{ "2P 判定・間合い表示", { "OFF", "ON", "ON:判定のみ", "ON:間合いのみ" }, },
			{ "1P 入力表示", { "OFF", "ON", "ON:ログのみ", "ON:キーディスのみ", }, },
			{ "2P 入力表示", { "OFF", "ON", "ON:ログのみ", "ON:キーディスのみ", }, },
			{ "気絶メーター表示", menu.labels.off_on_1p2p, },
			{ "ダメージ表示", menu.labels.off_on_1p2p, },
			{ title = true, "フレーム表示" },
			{ "コマンド入力状態表示", { "OFF", "ON:1P", "ON:2P", "ON:ため時間", "ON:1Pため時間", "ON:2Pため時間" }, },
			{ "フレームメーター表示", { "OFF", "ON:大表示", "ON:大表示(+1P情報)", "ON:大表示(+2P情報)", "ON:小表示", "ON:小表示 1Pのみ", "ON:小表示 2Pのみ", }, },
			{ "フレームメーター設定", { "ON", "ON:判定の形毎", "ON:攻撃判定の形毎", "ON:くらい判定の形毎", }, },
			{ "フレームメーター弾表示", menu.labels.off_on, },
			{ "通常動作フレーム非表示", menu.labels.off_on, },
			{ title = true, "状態表示" },
			{ "1P 状態表示", { "OFF", "ON", "ON:小表示", "ON:フラグ表示", "ON:ALL" }, },
			{ "2P 状態表示", { "OFF", "ON", "ON:小表示", "ON:フラグ表示", "ON:ALL" }, },
			{ "1P 処理アドレス表示", { "OFF", "本体", "弾-1", "弾-2", "弾-3", }, },
			{ "2P 処理アドレス表示", { "OFF", "本体", "弾-1", "弾-2", "弾-3", }, },
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
			{ title = true, "撮影用(特殊動作の強制)" },
			{ "1P 強制空振り", menu.labels.attack_harmless, },
			{ "2P 強制空振り", menu.labels.attack_harmless, },
			{ "1P Y座標強制", menu.labels.force_y_pos, },
			{ "2P Y座標強制", menu.labels.force_y_pos, },
			{ "画面下に移動", { "OFF", "2Pを下に移動", "1Pを下に移動", }, },
		},
		function()
			---@diagnostic disable-next-line: undefined-field
			local col, p, g, o, c = menu.disp.pos.col, players, global, hide_options, menu.config
			col[1] = c.disp_box_range1p                     -- 01 1P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
			col[2] = c.disp_box_range2p                     -- 02 2P 判定・間合い表示  1:OFF 2:ON 3:ON:判定のみ 4:ON:間合いのみ
			col[3] = p[1].disp_command                      -- 03 1P 入力表示  1:OFF 2:ON 3:ログのみ 4:キーディスのみ
			col[4] = p[2].disp_command                      -- 04 2P 入力表示  1:OFF 2:ON 3:ログのみ 4:キーディスのみ
			col[5] = c.disp_stun                            -- 05 気絶メーター表示  1:OFF 2:ON 3:1P 4:2P
			col[6] = c.disp_damage                          -- 06 ダメージ表示  1:OFF 2:ON 3:1P 4:2P
			-- 07 フレーム表示 label
			col[8] = g.disp_input                           -- 08 コマンド入力状態表示  1:OFF 2:1P 3:2P
			col[9] = c.disp_frame                           -- 09 フレームメーター表示
			-- 1:OFF, 2:ON:大表示, 3:ON:大表示(+1P情報), 4:ON:大表示(+2P情報), 5:ON:小表示, 6:ON:小表示 1Pのみ, 7:ON:小表示 2Pのみ
			col[10] = c.split_frame                         -- 10 フレームメーター設定  1:ON 2:ON:判定の形毎 3:ON:攻撃判定の形毎 4:ON:くらい判定の形毎
			col[11] = c.disp_fb_frame and 2 or 1            -- 11 フレームメーター弾表示  1:OFF 2:ON
			col[12] = g.disp_neutral_frames and 2 or 1      -- 12 通常動作フレーム非表示  1:OFF 2:ON
			--  13 状態表示 label
			col[14] = p[1].disp_state                       -- 14 1P 状態表示  1:OFF 2: ON, ON:小表示, ON:大表示, ON:フラグ表示
			col[15] = p[2].disp_state                       -- 15 2P 状態表示  1:OFF 2:ON, ON:小表示, ON:大表示, ON:フラグ表示
			col[16] = p[1].disp_base                        -- 16 1P 処理アドレス表示  1:OFF 2:本体 3:弾1 4:弾2 5:弾3
			col[17] = p[2].disp_base                        -- 17 2P 処理アドレス表示  1:OFF 2:本体 3:弾1 4:弾2 5:弾3
			col[18] = g.disp_pos                            -- 18 向き・距離・位置表示 1;OFF 2:ON 3:向き・距離のみ 4:位置のみ
			--  19 撮影用 label
			col[20] = c.disp_char                           -- 20 キャラ表示 1:OFF 2:ON 3:1P 4:2P
			col[21] = c.disp_phantasm                       -- 21 残像表示 1:OFF 2:ON 3:1P 4:2P
			col[22] = c.disp_effect                         -- 22 エフェクト表示 1:OFF 2:ON 3:1P 4:2P
			col[23] = ut.tstb(g.hide, o.p_chan) and 1 or 2  -- 23 Pちゃん表示 1:OFF 2:ON
			col[24] = ut.tstb(g.hide, o.effect) and 1 or 2  -- 24 共通エフェクト表示 1:OFF 2:ON
			--  25 撮影用(有効化時はリスタートします)             25
			col[26] = ut.tstb(g.hide, o.meters, true) and 1 or 2 -- 26 体力,POWゲージ表示 1:OFF 2:ON
			col[27] = ut.tstb(g.hide, o.background, true) and 1 or 2 -- 27 背景表示 1:OFF 2:ON
			col[28] = ut.tstb(g.hide, o.shadow1, true) and 2 or
				ut.tstb(g.hide, o.shadow2, true) and 3 or 1 -- 28 影表示  1:ON 2:OFF 3:ON:反射→影
			col[29] = global.fix_scr_top                    -- 29 画面カメラ位置
			--  30 撮影用(特殊動作の強制)
			col[31] = p[2].no_hit_limit + 1                 -- 31 1P 強制空振り
			col[32] = p[1].no_hit_limit + 1                 -- 32 2P 強制空振り
			col[33] = p[1].force_y_pos                      -- 33 1P Y座標強制
			col[34] = p[2].force_y_pos                      -- 34 2P Y座標強制
			g.sync_pos_x = col[35]                          -- 35 X座標同期
		end,
		ut.new_filled_table(35, function() menu.on_disp(false) end),
		ut.new_filled_table(35, function() menu.on_disp(true) end))

	menu.extra     = menu.create(
		"特殊設定",
		"調査や情報確認のための特殊な動作を設定します。",
		{
			{ "ラインずらさない現象", { "OFF", "ON", "ON:1Pのみ", "ON:2Pのみ" }, },
			{ "ヒット時にポーズ", { "OFF", "ON", "ON:やられのみ", "ON:投げやられのみ", "ON:打撃やられのみ", "ON:ガードのみ", }, },
			{ "判定発生時にポーズ", { "OFF", "投げ", "攻撃", "変化時", }, },
			{ "技画像保存", { "OFF", "ON:新規", "ON:上書き", }, },
			{ "ヒット効果確認用", db.hit_effects.menus, },
			{ "ビリーMVS化", menu.labels.off_on, },
			{ "サドマゾと逆襲拳のバグ修正", menu.labels.off_on, },
			{ "暗転フレームチェック処理修正", menu.labels.off_on, },
			{ "タイム設定(リスタートで反映)", { "無限:RB2(デフォルト)", "無限:RB2", "無限:SNK", "90", "60", "45", }, },
			{ "CPU戦進行あり", menu.labels.off_on, },
			{ "CPU難度最高", menu.labels.off_on, },
			{ "CPU待ち時間", { "等倍", "4分の3", "2分の1", "4分の1", "0", }, },
			{ "CPUステージ", { "通常", "対戦の2ラインステージ" }, },
			{ "対戦双角ステージ", { "通常", "ビリーステージ" }, },
		},
		function()
			---@diagnostic disable-next-line: undefined-field
			local col, p, g = menu.extra.pos.col, players, global
			col[1] = 1 -- ラインずらさない現象
			if p[1].dis_plain_shift and p[2].dis_plain_shift then
				col[1] = 2
			elseif p[1].dis_plain_shift then
				col[1] = 3
			elseif p[2].dis_plain_shift then
				col[1] = 4
			end
			col[2] = g.pause_hit        -- ヒット時にポーズ
			col[3] = g.pause_hitbox     -- 判定発生時にポーズ
			col[4] = g.save_snapshot    -- 技画像保存
			col[5] = g.damaged_move     -- ヒット効果確認用
			col[6] = g.mvs_billy and 2 or 1 -- ビリーMVS化
			col[7] = g.sadomazo_fix and 2 or 1 -- サドマゾと必勝!逆襲拳空振り時の投げ無敵化修正
			col[8] = g.fix_skip_frame and 2 or 1 -- 暗転フレームチェック処理修正
			col[9] = g.time_mode        -- タイム設定 1:無限:RB2(デフォルト) 2:無限:RB2 3:無限:SNK 4:90 5:60 6:30
			col[10] = g.proceed_cpu and 2 or 1 -- CPU戦進行あり
			col[11] = g.cpu_hardest and 2 or 1 -- CPU難度最高
			col[12] = g.cpu_wait        -- CPU待ち時間 1:100% 2:75% 3:50% 4:25% 5:0%
			col[13] = g.cpu_stg and 2 or 1 -- CPUステージ
			col[14] = g.sokaku_stg and 2 or 1 -- 対戦双角ステージ
		end,
		ut.new_filled_table(14, function()
			local col, p, g = menu.extra.pos.col, players, global
			p[1].dis_plain_shift = col[1] == 2 or col[1] == 3 -- ラインずらさない現象
			p[2].dis_plain_shift = col[1] == 2 or col[1] == 4 -- ラインずらさない現象
			g.pause_hit      = col[2] -- ヒット時にポーズ
			g.pause_hitbox   = col[3] -- 判定発生時にポーズ
			g.save_snapshot  = col[4] -- 技画像保存
			g.damaged_move   = col[5] -- ヒット効果確認用
			g.mvs_billy      = col[6] == 2 -- ビリーMVS化
			g.sadomazo_fix   = col[7] == 2 -- サドマゾと必勝!逆襲拳空振り時の投げ無敵化修正
			g.fix_skip_frame = col[8] == 2 -- 暗転フレームチェック処理修正
			-- タイム設定 1:無限:RB2(デフォルト) 2:無限:RB2 3:無限:SNK 4:90 5:60 6:45
			-- CPU戦進行あり
			menu.organize_time_config(col[9], col[10] == 2)
			g.cpu_hardest = col[11] == 2 -- CPU難度最高
			g.cpu_wait    = col[12] -- CPU待ち時間 1:100% 2:75% 3:50% 4:25% 5:0%
			g.cpu_stg     = col[13] == 2 -- CPUステージ
			g.sokaku_stg  = col[14] == 2 -- 対戦双角ステージ
			mod.mvs_billy(g.mvs_billy)
			mod.sadomazo_fix(g.sadomazo_fix)
			mod.fix_skip_frame(g.fix_skip_frame)
			set_dip_config(true)
			menu.set_current()
			mod.cpu_hardest(g.cpu_hardest)
			mod.cpu_wait(g.cpu_wait)
			mod.cpu_stg(g.cpu_stg)
			mod.sokaku_stg(g.sokaku_stg)
		end))
	menu.auto      = menu.create(
		"追加動作・改造動作設定",
		"技の発動についての動作を設定します。",
		{
			{ "DEBUG2-1 簡易超必", menu.labels.off_on, },
			{ "DEBUG4-4 半自動潜在能力", menu.labels.off_on, },
			{ title = true, "自動追加動作" },
			{ "自動ダウン投げ", menu.labels.off_on, },
			{ "自動必殺投げ", menu.labels.off_on, },
			{ "自動ダウン攻撃", menu.labels.off_on, },
			{ "自動投げ派生", menu.labels.off_on, },
			{ "デッドリーレイブ", { "通常動作", 2, 3, 4, 5, 6, 7, 8, 9, 10 }, },
			{ "アンリミテッドデザイア", { "通常動作", 2, 3, 4, 5, 6, 7, 8, 9, 10, "ギガティックサイクロン" }, },
			{ "ドリル", { "通常動作", 2, 3, 4, 5 }, },
			{ "閃里肘皇・貫空", menu.labels.off_on, },
			{ "超白龍", { "OFF", "C攻撃-判定発生前", "C攻撃-判定発生後" }, },
			{ "M.リアルカウンター", { "OFF", "ジャーマン", "フェイスロック", "投げっぱなしジャーマン", }, },
			{ "M.トリプルエクスタシー", menu.labels.off_on, },
			{ "炎の種馬", menu.labels.off_on, },
			{ "喝CA", menu.labels.off_on, },
			{ "飛燕失脚CA", { "OFF", "ON", "N+Cのみ", "CA真空投げのみ"}, },
			{ title = true, "改造動作" },
			{ "詠酒", { "OFF", "距離チェックなし", "技&距離チェックなし" }, },
			{ "必勝！逆襲拳", { "OFF", "1発で発動" }, },
			{ "空振りCA", menu.labels.off_on, },
			{ "タメ時間なし", menu.labels.off_on, },
			{ "(ほぼ)全通常技キャンセル可能", menu.labels.off_on, },
			{ "高速気絶回復", menu.labels.off_on, },
			{ "最速蛇だまし", menu.labels.off_on, },
		},
		function()
			local col, g = menu.auto.pos.col, global
			col[1] = dip_config.easy_super and 2 or 1 -- 簡易超必
			col[2] = dip_config.semiauto_p and 2 or 1 -- 半自動潜在能力
			-- 3 自動追加動作
			col[4] = g.auto_input.otg_throw and 2 or 1 -- ダウン投げ
			col[5] = g.auto_input.sp_throw and 2 or 1 -- 必殺投げ
			col[6] = g.auto_input.otg_attack and 2 or 1 -- ダウン攻撃
			col[7] = g.auto_input.combo_throw and 2 or 1 -- 通常投げの派生技
			col[8] = g.auto_input.rave             -- デッドリーレイブ
			col[9] = g.auto_input.desire           -- アンリミテッドデザイア
			col[10] = g.auto_input.drill           -- ドリル
			col[11] = g.auto_input.kanku and 2 or 1 -- 閃里肘皇・貫空
			col[12] = g.auto_input.pairon          -- 超白龍
			col[13] = g.auto_input.real_counter    -- M.リアルカウンター
			col[14] = g.auto_input.auto_3ecst and 2 or 1 -- M.トリプルエクスタシー
			col[15] = g.auto_input.taneuma and 2 or 1 -- 炎の種馬
			col[16] = g.auto_input.katsu_ca and 2 or 1 -- 喝CA
			col[17] = g.auto_input.sikkyaku_ca     -- 飛燕失脚CA
			-- 18 MOD
			col[19] = g.auto_input.esaka_check     -- 詠酒距離チェック
			col[20] = g.auto_input.fast_kadenzer and 2 or 1 -- 必勝！逆襲拳
			col[21] = g.auto_input.kara_ca and 2 or 1 -- 空振りCA
			col[22] = g.auto_input.no_charge and 2 or 1 -- タメ時間なし
			col[23] = g.auto_input.cancel and 2 or 1 -- 全通常技キャンセル可能
			col[24] = g.auto_input.fast_recover and 2 or 1 -- 高速気絶回復
			col[25] = g.auto_input.hebi_damashi and 2 or 1 -- 最速蛇だまし
		end,
		ut.new_filled_table(25, function()
			local col, g, ez           = menu.auto.pos.col, global, mod.easy_move
			dip_config.easy_super      = col[1] == 2 -- 簡易超必
			dip_config.semiauto_p      = col[2] == 2 -- 半自動潜在能力
			-- 3 自動追加動作
			g.auto_input.otg_throw     = col[4] == 2 -- ダウン投げ
			g.auto_input.sp_throw      = col[5] == 2 -- 必殺投げ
			g.auto_input.otg_attack    = col[6] == 2 -- ダウン攻撃
			g.auto_input.combo_throw   = col[7] == 2 -- 通常投げの派生技
			g.auto_input.rave          = col[8] -- デッドリーレイブ
			g.auto_input.desire        = col[9] -- アンリミテッドデザイア
			g.auto_input.drill         = col[10] -- ドリル
			g.auto_input.kanku         = col[11] == 2 -- 閃里肘皇・貫空
			g.auto_input.pairon        = col[12] -- 超白龍
			g.auto_input.real_counter  = col[13] -- M.リアルカウンター
			g.auto_input.auto_3ecst    = col[14] == 2 -- M.トリプルエクスタシー
			g.auto_input.taneuma       = col[15] == 2 -- 炎の種馬
			g.auto_input.katsu_ca      = col[16] == 2 -- 喝CA
			g.auto_input.sikkyaku_ca   = col[17] -- 飛燕失脚CA
			-- 18 MOD
			g.auto_input.esaka_check   = col[19] -- 詠酒チェック
			g.auto_input.fast_kadenzer = col[20] == 2 -- 必勝！逆襲拳
			g.auto_input.kara_ca       = col[21] == 2 -- 空振りCA
			g.auto_input.no_charge     = col[22] == 2 -- タメ時間なし
			g.auto_input.cancel        = col[23] == 2 -- 全通常技キャンセル可能
			g.auto_input.fast_recover  = col[24] == 2 -- 高速気絶回復
			g.auto_input.hebi_damashi  = col[25] == 2 -- 最速蛇だまし
			-- 簡易入力のROMハックを反映する
			ez.real_counter(g.auto_input.real_counter) -- ジャーマン, フェイスロック, 投げっぱなしジャーマン
			ez.esaka_check(g.auto_input.esaka_check) -- 詠酒の条件チェックを飛ばす
			ez.taneuma_finish(g.auto_input.taneuma) -- 自動 炎の種馬
			ez.fast_kadenzer(g.auto_input.fast_kadenzer) -- 必勝！逆襲拳1発キャッチカデンツァ
			ez.katsu_ca(g.auto_input.katsu_ca)  -- 自動喝CA
			ez.shikkyaku_ca(g.auto_input.sikkyaku_ca) -- 自動飛燕失脚CA
			ez.kara_ca(g.auto_input.kara_ca)    -- 空振りCAできる
			ez.triple_ecstasy(g.auto_input.auto_3ecst) -- 自動マリートリプルエクスタシー
			ez.no_charge(g.auto_input.no_charge) -- タメ時間なし
			ez.cancel(g.auto_input.cancel)      -- 全通常技キャンセル可能
			ez.fast_recover(g.auto_input.fast_recover) -- 高速気絶回復
			ez.hebi_damashi(g.auto_input.hebi_damashi) -- 最速蛇だまし
			menu.set_current()
		end))

	menu.color     = menu.create(
		"判定個別設定",
		"判定枠の表示を設定します。",
		ut.table_add_conv_all({ { title = true, "判定個別設定" } }, db.box_type_list,
			function(b) -- b as box_type
				local menu_off_on = menu.labels.off_on
				if b == db.box_types.down_otg then
					-- ダウン追撃用判定はトドメの範囲外なら表示しない＝ON、常に表示＝ALL
					menu_off_on = { "OFF", "ON", "ON:ALL" }
				elseif b == db.box_types.launch then
					-- 空中追撃用判定はメインラインでないなら表示しない＝ON、常に表示＝ALL
					menu_off_on = { "OFF", "ON", "ON:ALL" }
				end
				return { b.name, menu_off_on, { fill = b.fill, outline = b.outline } } -- rowオブジェクト
			end),
		function()
			local col = menu.color.pos.col
			for i = 2, #col do col[i] = db.box_type_list[i - 1].enabled end -- 1:OFF 2~3:ON or ON:ALL
		end,
		ut.new_filled_table(#db.box_type_list + 1, function()
			local col = menu.color.pos.col
			for i = 2, #col do db.box_type_list[i - 1].enabled = col[i] end -- 1:OFF 2~3:ON or ON:ALL
			menu.set_current()
		end))

	menu.recording = menu.create(
		"レコーディング",
		"Aでレコーディングを開始します。",
		{
			{ title = true, "選択したスロットに記憶されます。" },
			{ "スロット1", { "ロック", "Aでレコード開始", }, },
			{ "スロット2", { "ロック", "Aでレコード開始", }, },
			{ "スロット3", { "ロック", "Aでレコード開始", }, },
			{ "スロット4", { "ロック", "Aでレコード開始", }, },
			{ "スロット5", { "ロック", "Aでレコード開始", }, },
			{ "スロット6", { "ロック", "Aでレコード開始", }, },
			{ "スロット7", { "ロック", "Aでレコード開始", }, },
			{ "スロット8", { "ロック", "Aでレコード開始", }, },
		},
		-- スロット1-スロット8
		function(first)
			local col = menu.recording.pos.col
			for i = 2, 1 + 8 do
				if first then col[i] = 2 end
				local store_len = #recording.slot[i - 1].store
				local time = ut.frame_to_time(store_len)
				col[i] = store_len > 1 and 1 or 2
				menu.recording.list[i][2] = {
					string.format("ロック %s", time),
					string.format("Aでレコード開始 %s", time),
				}
			end
		end,
		{
			menu.rec_to_tra,                                            -- 説明
			function() menu.exit_and_rec(1, menu.recording.pos.col[2] == 2) end, -- スロット1
			function() menu.exit_and_rec(2, menu.recording.pos.col[3] == 2) end, -- スロット2
			function() menu.exit_and_rec(3, menu.recording.pos.col[4] == 2) end, -- スロット3
			function() menu.exit_and_rec(4, menu.recording.pos.col[5] == 2) end, -- スロット4
			function() menu.exit_and_rec(5, menu.recording.pos.col[6] == 2) end, -- スロット5
			function() menu.exit_and_rec(6, menu.recording.pos.col[7] == 2) end, -- スロット6
			function() menu.exit_and_rec(7, menu.recording.pos.col[8] == 2) end, -- スロット7
			function() menu.exit_and_rec(8, menu.recording.pos.col[9] == 2) end, -- スロット8
		},
		ut.new_filled_table(1, menu.rec_to_tra, 8, menu.to_tra))

	menu.replay    = menu.create(
		"リプレイ",
		"Aでリプレイを開始します。",
		{
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
		},
		-- スロット1-スロット8
		function(first)
			local col, g = menu.replay.pos.col, global
			col[11] = recording.do_repeat and 2 or 1 -- 繰り返し
			col[12] = recording.repeat_interval + 1 -- 繰り返し間隔
			col[13] = g.await_neutral and 2 or 1 -- 繰り返し開始条件
			col[14] = g.replay_fix_pos       -- 開始間合い固定
			col[15] = g.replay_reset         -- 状態リセット
			col[16] = g.disp_replay and 2 or 1 -- ガイド表示
			col[17] = g.replay_stop_on_dmg and 2 or 1 -- ダメージでリプレイ中止
			for i = 2, 1 + 8 do
				if first then col[i] = 2 end
				local store_len = #recording.slot[i - 1].store
				local time = ut.frame_to_time(store_len)
				menu.replay.list[i][2] = {
					string.format("OFF %s", time),
					string.format("ON  %s", time),
				}
			end
		end,
		ut.new_filled_table(17, menu.exit_and_play),
		ut.new_filled_table(17, menu.exit_and_play_cancel))

	for key, sub_menu in pairs(menu) do
		if type(sub_menu) == "table" and sub_menu.init and type(sub_menu.init) == "function" then
			ut.printf("init menu %s", key)
			sub_menu.init(true)
		end
	end
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
		local menu_top_y, menu_row_height = 38, 10
		for i = menu.current.pos.offset, menu_max do
			local row = menu.current.list[i]
			local y = menu_top_y + menu_row_height * row_num
			local c1, c2, c3, c4, c5, c6
			local deep = math.modf((scr:frame_number() / 5) % 20) + 1
			-- 選択行とそうでない行の色分け判断
			if i == menu.current.pos.row then
				c1, c2, c3, c4, c5 = 0xFFDD2200, 0xFF662200, 0xFFFFFF00, 0xCC000000, 0xAAFFFFFF
				c1 = c1 - (0x00110000 * math.abs(deep - 10)) -- アクティブメニュー項目のビカビカ処理
				c6 = 0xFF00FFFF                  -- 非デフォルト設定の文字色
			else
				c1, c2, c3, c4, c5 = 0xFFC0C0C0, 0xFFB0B0B0, 0xFF000000, 0x00000000, 0xFF000000
				c6 = 0xFF0000FF                                   -- 非デフォルト設定の文字色
			end
			local mx1, my1, mx2, my2, tx1 = 70, y + 0.5, 250, y + 8.5, 150 -- 枠と文字の位置
			if row.title then
				-- ラベルだけ行
				scr:draw_box(mx1, my1, mx2, my2, 0xFF484848, 0xFF484848)
				draw_text("center", y + 1, row[1], 0xFFFFFFFF)
			else
				-- 通常行 ラベル部分
				scr:draw_box(mx1, my1, mx2, my2, c2, c1)
				if i == menu.current.pos.row then
					scr:draw_line(mx1, my1, mx2, my1, 0xFFDD2200)
					scr:draw_line(mx1, my1, mx1, my2, 0xFFDD2200)
				else
					scr:draw_box(mx1, y + 7.0, mx2, my2, 0xFFB8B8B8, 0xFFB8B8B8)
					scr:draw_box(mx1, y + 8.0, mx2, my2, 0xFFA8A8A8, 0xFFA8A8A8)
				end
				draw_text(mx1 + 6.5, y + 1.5, row[1], c4)
				draw_text(mx1 + 6, y + 1, row[1], c3)
				if row[2] then
					-- 通常行 オプション部分
					local col_pos_num = menu.current.pos.col[i] or 1
					if col_pos_num > 0 then
						local opt_txt = string.format("%s", row[2][col_pos_num])
						draw_text(tx1 + 5.5, y + 1.5, opt_txt, c4)
						local opt_txt_col = col_pos_num == 1 and c3 or c6 -- TODO デフォルト設定の組み込み
						draw_text(tx1 + 5.0, y + 1.0, opt_txt, opt_txt_col)
						-- オプション部分の左右移動可否の表示
						if i == menu.current.pos.row then
							draw_text(tx1, y + 1, "<", col_pos_num == 1 and c5 or c3)
							draw_text(mx2 - 7, y + 1, ">", col_pos_num == #row[2] and c5 or c3)
						end
					end
				end
				-- 判定個別表示の判定色の表示枠
				if row[3] and row[3].outline and menu.color.pos.col[i] > 1 then
					scr:draw_box(mx2 - 60, y + 2, mx2 - 18, y + 7, 0xAA000000, row[3].outline)
				end
			end
			if i == menu.current.pos.offset then
				if menu.current.name then
					draw_text("center", menu_top_y - menu_row_height, menu.current.name, 0xFFFFFFFF)
				end
				local txt, c6 = "▲", 0xFF404040
				if 1 < menu.current.pos.offset then
					txt, c6 = "▲", 0xFFC0C0C0 - (0x00080808 * math.abs(deep - 10)) -- 残メニューマークのビカビカ処理
				end
				draw_text("center", y + 1 - 10, txt, c6) -- 上にメニューあり
			end
			if i == menu_max then
				if menu.current.desc then
					draw_text("center", y + 2 + menu_row_height * 2, menu.current.desc, 0xFFFFFFFF)
				end
				local txt, c6 = "▼", 0xFF404040
				if menu.current.pos.offset + menu.max_row < #menu.current.list then
					txt, c6 = "▼", 0xFFF0F0F0 - (0x00080808 * math.abs(deep - 10)) -- 残メニューマークのビカビカ処理
				end
				draw_text("center", y + 1 + menu_row_height, txt, c6) -- 下にメニューあり
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

	local get_game_state = function()
		local _0x100701        = mem.r16(0x100701) -- 22e 22f 対戦中
		local _0x107C22        = mem.r08(0x107C22) --[[
			11 ラウンド開始前 白描画
			22 ラウンド開始前 黒描画
			28 ラウンド開始前 黒描画解除
			29 ラウンド開始前 オブジェクト表示
			33 ラウンド開始前 オブジェクト表示
			38 ラウンド開始前 FIGHT表示
			44 対戦中
			77 KO
			00 その他
		]]
		local _0x10FDAF        = mem.r08(0x10FDAF)
		local _0x10FDB6        = mem.r16(0x10FDB6)
		local _0x10E043        = mem.r08(0x10E043)
		local round_no         = mem.r16(0x107BB8)
		local _0x1041D0        = mem.r16(0x1041D0)
		local life_p1          = mem.r08(0x10048B)
		local life_p2          = mem.r08(0x10058B)
		-- プレイヤーセレクト中かどうかの判定
		local in_player_select = round_no == 0 and _0x1041D0 == 0xA and _0x100701 == 0x10B and (_0x107C22 == 0 or _0x107C22 == 0x55) and _0x10FDAF == 2 and _0x10FDB6 ~= 0 and _0x10E043 == 0
		-- if in_player_select then ut.printf("%X %X %X %X %X %X %X %X %X", round_no, _0x1041D0, _0x100701, _0x107C22, _0x10FDAF, _0x10FDB6, _0x10E043, life_p1, life_p2) end
		-- 対戦中かどうかの判定
		local in_match         = active_mem_0x100701[_0x100701] ~= nil and _0x107C22 == 0x44 and _0x10FDAF == 2 and _0x10FDB6 ~= 0
		return in_match, in_player_select
	end

	local self_destruct = function()
		local before = collectgarbage("count")
		for k, _ in pairs(rbff2) do
			if k ~= "startplugin" then
				rbff2[k] = nil
			end
		end
		collectgarbage("collect")
		print("destruct", before, collectgarbage("count"))
	end

	local phase_gate = function(expected, name)
		if phase_count > expected then return 1 end
		if phase_count < expected then return -1 end
		phase_count = phase_count + 1
		ut.printf("phase %s %s", expected, name)
		return 0
	end

	rbff2.emu_start = function()
		math.randomseed(os.time())
		phase_gate(1, "start")
	end

	rbff2.emu_stop = function()
		if not machine then return end
		reset_memory_tap(nil, false, true)         -- フック外し
		for i = 1, 4 do mem.w08(0x10E000 + i - 1, 0) end -- デバッグ設定戻し
		-- フックの呼び出し回数を出力
		for addr, cnt in pairs(mem.wp_cnt) do ut.printf("wp %x %s", addr, cnt) end
		for addr, cnt in pairs(mem.rp_cnt) do ut.printf("rp %x %s", addr, cnt) end
		mem.wp_cnt, mem.rp_cnt = {}, {}
		self_destruct()
		machine:hard_reset() -- ハードリセットでメモリ上のロムパッチの戻しも兼ねる
	end

	rbff2.emu_menu = function(index, event) return false end

	rbff2.emu_pause = function() menu.state.draw() end

	rbff2.emu_frame_done = function()
		if not machine then return end
		if machine.paused then return end
		if phase_gate(5, "draw") == -1 then return end
		menu.state.draw()
		collectgarbage("collect")
	end

	rbff2.emu_periodic = function()
		if not machine then return end
		if machine.paused then return end
		if phase_gate(2, "init") == -1 then return end
		local ec = scr:frame_number() -- フレーム更新しているか
		if mem.last_time == ec then return end
		mem.last_time = ec
		mem._0x10E043 = mem.r08(0x10E043)

		-- メモリ値の読込と更新
		if bios_test() then
			in_match, in_player_select, mem.pached = false, false, false -- 状態リセット
			reset_memory_tap()
			return
		end
		-- プレイヤーセレクト中かどうかの判定, 対戦中かどうかの判定
		in_match, in_player_select = get_game_state()
		if in_match and (not global.proceed_cpu) then
			mem.w16(0x10FDB6, 0x0101) -- 操作の設定
			for i, p in ipairs(players) do mem.w16(p.addr.control, i * 0x0101) end
		end
		-- ROM部分のメモリエリアへパッチあて
		execute_mod(reset_memory_tap)
		set_dip_config()          -- デバッグDIPのセット
		load_hit_effects()        -- ヒット効果アドレステーブルの取得
		load_hit_system_stops()   -- ヒット時のシステム内での中間処理による停止アドレス取得
		load_proc_base()          -- キャラの基本アドレスの取得
		load_push_box()           -- 接触判定の取得
		load_close_far()          -- 遠近間合い取得
		load_memory_tap("all", wps.all) -- tapの仕込み
		if global.hide > 0 then load_memory_tap("hide", wps.hide) else reset_memory_tap("hide") end
		if in_player_select then load_memory_tap("select", wps.select) else reset_memory_tap("select") end
		if phase_gate(4, "proc") ~= -1 then
			input.read()
			menu.state.proc() -- メニュー初期化前に処理されないようにする
		end
		phase_gate(3, "inited")
	end
end

return rbff2
