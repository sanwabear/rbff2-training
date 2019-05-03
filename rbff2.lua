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
package.path = [[.\ext-lib\?.lua;.\lib\?.lua;.\ram-patch\]]..emu.romname()..[[\?.lua;.\rom-patch\]]..emu.romname()..[[\?.lua;]]..package.path

require("strict")
require("rbff2-global")
require("fireflower-patch")
require("life-recover")
require("debug-dip")
require("auto-guard")
require("player-controll")
require("save-memory")
require("slow")
require("adv-frames")
dofile("ext-lib/table.save-0.94.lua")

local osd = new_env("ext-lib/fighting-OSD.lua")
local input_display = new_env("ext-lib/scrolling-input-display.lua")
local hit_boxes = new_env("ext-lib/garou-hitboxes.lua")
local no_op = function() end

local c = { --colors
	red    = 0xFF4444FF,
	green  = 0x00FF00FF,
	yellow = 0xFFFF00FF,
	pink   = 0xFF80CCFF,
	gray   = 0xCCCCFFFF,
	white  = 0xFFFFFFFF,
	gray2  = 0x80C0C0FF,
	gray3  = 0x80A0A0FF,
	none   = 0x00000000,
}

local global = {
	mode_switching = true,
	active_menu = nil,
	next_active_menu = nil,
	next_active_menu_with_save = nil,
	main = nil,
	rec = nil,
	training = nil,
	fighting = nil,
	extra = nil,
	player_and_stg = nil,
	load = 1,
	save = 1,
	autosave = true,
	match_active = false,
	player_select_active = false,
	is_bios_test = function()
		return bios_test(0x100400) or bios_test(0x100500)
	end,
	is_match_active = function()
		local s = memory.readword(0x107C22)
		return not bios_test(0x100400) and not bios_test(0x100500) and
			memory.readword(0x100701) >= 0x200 and
			(s == 0x3800 or s == 0x107C22 or s == 0x4400) and
			memory.readbyte(0x10FDAF) == 2
	end,
	is_player_select_active = function()
		local s = memory.readword(0x107C22)
		return not bios_test(0x100400) and not bios_test(0x100500) and
			memory.readword(0x100701) < 0x200 and memory.readword(0x100701) >= 0x100 and
			(s == 0x0000 or s == 0x5500) and
			memory.readbyte(0x10FDAF) == 2
	end,
	goto_player_select = nil,
	restart_fight = nil,
	input_accept_frame = 0,

	next_stage = 1,
	next_stage_tz = 1,
	next_p1 = 1,
	next_p1col = 1,
	next_p2 = 1,
	next_p2col = 1,
	next_stg_revkeys = {},
	next_bgm = 1,

	do_load = nil,
	do_save = nil,
	do_autosave = nil,
	copy_config = nil,
	apply_menu_options = nil,

	pause = function()
		-- DIP1 bit7 STOP MODE
		joypad.set({["Dip 1"] = bit.bor(joypad.get()["Dip 1"] or 0x00, 0x80) })
	end,
	unpause = no_op,
}
global.next_active_menu = function(menu)
	global.mode_switching = global.is_match_active() or not global.is_player_select_active()
	global.active_menu = menu
end
global.next_active_menu_with_save = function(menu)
	global.next_active_menu(menu)
	global.do_autosave()
end

global.goto_player_select = function()
	dofile("ram-patch/"..emu.romname().."/player-select.lua")
	player_controll.apply_vs_mode(false)
	debugdip.release_debugdip()
	global.next_active_menu(global.fighting)
end

global.restart_fight = function()
	global.next_active_menu(global.fighting)
	local stg1 = global.next_stage
	local stg2 = global.next_stage_tz
	if stg2 == 0x02 and (stg1 == 2 or stg1 == 3 or stg1 == 4 or stg1 == 5 or stg1 == 6 or stg1 == 9) then
		stg2 = 0x01
	end
	local p1 = global.next_p1
	local p2 = global.next_p2
	local p1col = global.next_p1col
	local p2col = global.next_p2col
	local bgm = global.next_bgm

	dofile("ram-patch/"..emu.romname().."/vs-restart.lua")
	player_controll.apply_vs_mode(true)
	debugdip.release_debugdip()

	memory.writebyte(0x107BB1, stg1)
	memory.writebyte(0x107BB7, stg2)
	memory.writebyte(0x107BA5, p1)
	memory.writebyte(0x107BAC, p1col)
	memory.writebyte(0x107BA7, p2)
	if p1 == p2 then
		memory.writebyte(0x107BAD, p1col == 0x00 and 0x01 or 0x00)
	else
		memory.writebyte(0x107BAD, p2col)
	end
	memory.writebyte(0x10A8D5, bgm) --BGM
end

global.copy_config = function(from, to)
	local keys = {}
	for k, _ in pairs(from or {}) do
		table.insert(keys, k)
	end
	for k, _ in pairs(to or {}) do
		table.insert(keys, k)
	end
	for i = 1, #keys do
		local k = keys[i]
		local v = from[k]
		if type(v) == "table" then
			to[k] = to[k] or { }
			global.copy_config(v, to[k])
		else
			to[k] = v
		end
	end
end

global.apply_menu_options = function(menu)
	for k, v in pairs(menu.config) do
		local kk = k * 2
		local vv = v * 2
		if menu.body[kk] then
			if menu.body[kk][vv] then
				menu.body[kk][vv]()
			end
		end
	end
end

local create_menu = function(title, build_callback, on_apply, on_cancel, default_callback)
	local menu = {
		title = title,
		body = { },
		body_len = 0,
		opt_len = { },
		config = { },
		p = 1,
		opt_p = {},
		box_offset = 42, box_x1 = 72, box_y1 = 34, --[[offset - 8,]] box_x2 = 248, box_y2 = 0, -- #menu_indexes * 8 + offset + 24
		title_x = 0, --[[ emu.screenwidth() - 4 * #title / 2]] title_y = 42,
		on_apply = on_apply or no_op,
		on_cancel = on_cancel or no_op,
	}
	build_callback(menu.body)
	menu.body_len = #menu.body
	for i = 1, menu.body_len, 2 do
		local p = (i + 1) /2
		menu.opt_len[p] = #menu.body[i + 1]
		local opt_p = menu.opt_len[p] == 0 and 0 or 1
		menu.config[i] = opt_p
		menu.opt_p[i] = opt_p
	end
	menu.box_y2 = menu.body_len/2 * 8 + menu.box_offset + 24
	menu.title_x = emu.screenwidth()/2 - 4 * #menu.title/2

	global.copy_config(menu.opt_p, menu.config)
	default_callback(menu)
	global.copy_config(menu.config, menu.opt_p)
	return menu
end

local console_guard = function(menu)
	if memory.readbyte(0x10FD82) == 0x00
		and memory.readbyte(0x1041D2) == 0x00
		and menu ~= global.fighting then
		return true
	end
	return false
end

local draw_screen = function(menu)
	gui.clearuncommitted()

	if not global.match_active then
		return
	end

	if menu == global.fighting then
		player_controll.draw_playing_status()
		input_display.draw_input()
		osd.draw_OSD()
		hit_boxes.render_hitboxes()
		auto_guard.draw_guard_status()
		adv_frames.draw_frames()
		return
	end

	local y = menu.box_offset
	gui.box(menu.box_x1, menu.box_y1, menu.box_x2, menu.box_y2, c.gray2, c.gray3)
	gui.text(menu.title_x, menu.title_y, menu.title, c.white)
	y = y + 8
	for i = 2, menu.body_len, 2 do
		y = y + 8
		local p = i / 2
		local color = menu.p == p and c.pink or c.white
		gui.text(76, y, p, color)
		gui.text(88, y, menu.body[i - 1], color)
		menu.opt_p[p] = menu.opt_p[p] == nil and 1 or menu.opt_p[p]
		if 0 < menu.opt_len[p] then
			gui.text(160, y, menu.body[i][menu.opt_p[p] * 2 - 1], color)
			gui.text(236, y, menu.opt_p[p], color)
		end
	end
end

local in_pause = function()
	return memory.readbyte(0x104191) == 0xFF
end

local wait_for_switching = function(menu)
	-- MEMO: メニュー表示の制御をきれいにしたい
	if global.is_match_active() then
		if (menu == global.fighting and in_pause())
			or (menu ~= global.fighting and not in_pause()) then
			-- 対戦画面へ遷移時はポーズ解除まで待機
			-- メニューへ遷移時はポーズまで待機
			joypad.set({["P1 Select"] = emu.framecount() % 4 == 0})
			return
		else
			global.mode_switching = false
		end
	else
		global.next_active_menu(global.fighting)
	end
end

local execute = function(menu)
	local old_active = global.match_active
	local kio1, kio2, kio3, key, pre_key = rb2key.capture_keys()
	local ec = emu.framecount()
	local state_past = ec - global.input_accept_frame

	global.match_active = global.is_match_active()
	global.player_select_active = global.is_player_select_active()

	if global.player_select_active then
		player_controll.hack_player_select()
		return
	elseif not global.match_active then
	elseif global.match_active ~= old_active then
		global.next_active_menu(global.fighting)
		global.input_accept_frame = ec
	end

	if menu == global.fighting then
		global.unpause()
		if 15 < state_past and 1 < key.sl and state_past >= key.sl then
			global.input_accept_frame = ec
			menu.on_apply(menu)
			return
		else
			slow.apply_slow()
			osd.update_OSD()
			player_controll.apply_player_controll()
			hit_boxes.hitboxes_update_func()
			input_display.do_registerafter()
			life_recover.update_life_recover()
			auto_guard.update_guard()
			debugdip.update_debugdips()
			adv_frames.update_frames()
		end
	else
		global.pause()
		if 15 < state_past then
			local x, y = 0, 0
			if 0 < key.up then
				y = -1
			elseif 0 < key.dn then
				y = 1
			elseif 0 < key.rt then
				x = 1
			elseif 0 < key.lt then
				x = -1
			elseif 0 < key.a and state_past >= key.a then
				-- save and apply
				global.input_accept_frame = ec
				global.copy_config(menu.opt_p, menu.config)
				global.apply_menu_options(menu)
				menu.on_apply(menu)
				return
			elseif (1 < key.b and state_past >= key.b)
				or (1 < key.sl and state_past >= key.sl) then
				-- cancel
				global.input_accept_frame = ec
				global.copy_config(menu.config, menu.opt_p)
				menu.on_cancel(menu)
				return
			end
			if y ~= 0 then
				global.input_accept_frame = ec
				menu.p = (menu.p - 1 + y) % (menu.body_len/2) + 1
				return
			end
			if x ~= 0 then
				global.input_accept_frame = ec
				local opt_p = menu.p * 2
				if menu.opt_len[menu.p] > 0 then
					local max = menu.opt_len[menu.p] / 2
					menu.opt_p[menu.p] = (menu.opt_p[menu.p] - 1 + x) % max + 1
				else
					menu.opt_p[menu.p] = 0
				end
				return
			end
		end
	end
end

global.fighting = create_menu(
	"- IN FIGHT -",
	function(menu) end,
	function(menu)
		global.next_active_menu(global.main)
	end,
	function(menu) end,
	function(menu) end)

global.player_and_stg = create_menu(
	"- PLAYER & STAGE -",
	function(menu)
		local options = nil
		local chars = { "TERRY BOGARD", "ANDY BOGARD", "JOE HIGASHI", "MAI SHIRANUI", "GEESE HOWARD",
			"SOKAKU MOCHIZUKI", "BOB WILSON", "HON-FU", "BLUE MARY", "FRANCO BASH", "RYUJI YAMAZAKI",
			"JIN CHONSHU", "JIN CHONREI", "DUCK KING", "KIM KAPHWAN", "BILLY KANE", "CHENG SINZAN",
			"TUNG FU RUE", "LAURENCE BLOOD", "WOLFGANG KRAUSER", "RICK STROWD", "LI XIANGFEI", "ALFRED",}
		local stgs1 = { 0x07, 0x01, 0x08, 0x01, 0x04, 0x01, 0x08, 0x0A, 0x06, 0x08,
			0x02, 0x09, 0x09, 0x06, 0x03, 0x04, 0x02, 0x03, 0x05, 0x05, 0x07, 0x0A, 0x07, }
		local stgs2 = { 0x00, 0x02, 0x02, 0x00, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01,
			0x01, 0x00, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x01,0x00, 0x01, 0x00, 0x02, }
		for p = 1, 2 do
			table.insert(menu, p.."P CHARACTOR:")
			options = {}
			for i = 1, #chars do
				table.insert(options, chars[i])
				table.insert(options, function() global["next_p"..p] = i end)
			end
			table.insert(menu, options)
			table.insert(menu, "   COLOR:")
			table.insert(menu, {
				"A", function() global["next_p"..p.."col"] = 0x00 end,
				"D", function() global["next_p"..p.."col"] = 0x01 end,
			})
		end
		table.insert(menu, "STAGE:")
		options = {}
		for i = 1, #chars do
			table.insert(options, chars[i])
			table.insert(options, function()
				global.next_stage  = stgs1[i]
				global.next_stage_tz = stgs2[i]
			end)
			global.next_stg_revkeys[tohex(stgs1[i]).."-"..tohex(stgs2[i])] = i
		end
		table.insert(menu, options)
		table.insert(menu, "BGM:")
		options = {}
		for i = 1, #chars do
			table.insert(options, chars[i])
			table.insert(options, function() global.next_bgm = i end)
		end
		table.insert(options, "NONE")
		table.insert(options, function() global.next_bgm = 0x00 end)
		table.insert(menu, options)
	end,
	function(menu)
		global.restart_fight()
	end,
	function(menu)
		global.next_active_menu(global.main)
	end,
	function(menu)
		menu.config[1] = 1
		menu.config[2] = 1
		menu.config[3] = 1
		menu.config[4] = 1
		menu.config[5] = 1
		menu.config[6] = 1
	end)

global.training = create_menu(
	"- TRAINING MENU -",
	function(menu)
		for pside = -1, 1, 2 do
			local pl = pside == -1 and "1P " or "2P "
			local pside2 = pside * -1
			table.insert(menu, pl .. "GUARD:")
			table.insert(menu, {
				"OFF", function() auto_guard.config_no_guard(pside2) end,
				"AUTO GUARD", function() auto_guard.config_auto_guard(pside2) end,
				"STANDING", function() auto_guard.config_standing_guard(pside2) end,
				"CROUCHING", function() auto_guard.config_crouching_guard(pside2) end,
				"1HIT GUARD", function() auto_guard.config_1hit_guard(pside2) end,
				"RANDOM", function() auto_guard.config_random_guard(pside2) end,
				"SWAY", function() auto_guard.config_sway(pside2) end,
				"ATTACK AVOIDER", function() auto_guard.config_attack_avoider(pside2) end,
				"ESAKA STAND", function() auto_guard.config_esaka_anti_stand(pside2) end,
				"ESAKA LOW", function() auto_guard.config_esaka_anti_crouch(pside2) end,
				"ESAKA UPPER", function() auto_guard.config_esaka_anti_air(pside2) end,
			})
			table.insert(menu, "   LIFE:")
			table.insert(menu, {
				"FULL", function() life_recover.config_life(pside, true) end,
				"RED", function() life_recover.config_life(pside, false) end,
				"OFF", function() life_recover.config_life_off(pside) end,
			})
			table.insert(menu, "   POW:")
			table.insert(menu, {
				"FULL", function() life_recover.config_pow(pside, true) end,
				"OFF", function() life_recover.config_pow(pside, false) end,
			})
		end
		table.insert(menu, "INPUTS:")
		table.insert(menu, {
			"SHOW", function() input_display.config_draw_inputs(true) end,
			"HIDE", function() input_display.config_draw_inputs(false) end,
		})
		table.insert(menu, "HITBOXES:")
		table.insert(menu, {
			"SHOW", function() hit_boxes.config_draw_all(true) end,
			"HIDE", function() hit_boxes.config_draw_all(false) end,
		})
		table.insert(menu, "ADV. FRAMES:")
		table.insert(menu, {
			"SHOW", function() adv_frames.config_draw(true) end,
			"HIDE", function() adv_frames.config_draw(false) end,
		})
		table.insert(menu, "BACK GROUND:")
		table.insert(menu, {
			"SHOW", function() hit_boxes.config_draw_bg(true) end,
			"HIDE", function() hit_boxes.config_draw_bg(false) end,
		})
	end,
	function(menu)
		global.next_active_menu_with_save(global.main)
	end,
	function(menu)
		global.next_active_menu(global.main)
	end,
	function(menu)
		menu.config[1] = 1
		menu.config[2] = 2
		menu.config[3] = 1
		menu.config[4] = 5
		menu.config[5] = 1
		menu.config[6] = 2
		menu.config[7] = 1
		menu.config[8] = 1
	end)

global.extra = create_menu(
	"- EXTRA MENU -",
	function(menu)
		table.insert(menu, "LIFE GAUGE:")
		table.insert(menu, {
			"FIXED", function() debugdip.config_fixed_life(true) end,
			"VARIABLE", function() debugdip.config_fixed_life(false) end,
		})
		table.insert(menu, "TIMER:")
		table.insert(menu, {
			"INFINITY", function() debugdip.config_inifinity_time(true) end,
			"99", function() debugdip.config_inifinity_time(false, 0x99) end,
			"60", function() debugdip.config_inifinity_time(false, 0x61) end,
			"30", function() debugdip.config_inifinity_time(false, 0x31) end,
		})
		table.insert(menu, "STATUS:")
		table.insert(menu, {
			"HIDE", function() debugdip.config_watch_states(false) end,
			"SHOW", function() debugdip.config_watch_states(true) end,
		})
		table.insert(menu, "NUMBERS:")
		table.insert(menu, {
			"HIDE", function() osd.config_show_numbers(false) end,
			"SHOW", function() osd.config_show_numbers(true) end,
		})
		table.insert(menu, "STUNS:")
		table.insert(menu, {
			"SHOW", function() osd.config_show_bars(true) end,
			"HIDE", function() osd.config_show_bars(false) end,
		})
		table.insert(menu, "COMBOS:")
		table.insert(menu, {
			"SHOW", function() osd.config_show_combos(true) end,
			"HIDE", function() osd.config_show_combos(false) end,
		})
		table.insert(menu, "SLOW:")
		local options = {}
		table.insert(options, "OFF")
		local config_slow = function(new_max)
			slow.config_slow(new_max)
			hit_boxes.initialize_buffers()
		end
		table.insert(options, function() config_slow(0) end)
		table.insert(options, "STEP-1")
		table.insert(options, function() config_slow(-1) end)
		table.insert(options, "STEP-2")
		table.insert(options, function() config_slow(-2) end)
		for i = 3, 60 do
			table.insert(options, tostring(i))
			table.insert(options, function() config_slow(i) end)
		end
		table.insert(menu, options)
		table.insert(menu, "TEST:")
		table.insert(menu, {
			"OFF", no_op,
			"RUN", no_op,
		})
	end,
	function(menu)
		global.next_active_menu_with_save(global.main)
	end,
	function(menu)
		global.next_active_menu(global.main)
	end,
	function(menu)
		menu.config[1] = 1
		menu.config[2] = 1
		menu.config[3] = 2
		menu.config[4] = 1
		menu.config[5] = 1
		menu.config[6] = 1
		menu.config[7] = 1
		menu.config[8] = 1
	end)

global.rec = create_menu(
	"- RE-PLAY MENU -",
	function(menu)
		table.insert(menu, "PLAY MODE:")
		table.insert(menu, {
			"RECORD", function()
				player_controll.config_mode_record()
				debugdip.config_cpu_cant_move(true)
				auto_guard.config_forward(true)
			end,
			"RE-PLAY", function()
				player_controll.config_mode_replay()
				debugdip.config_cpu_cant_move(true)
				auto_guard.config_forward(true)
			end,
			"1P vs 2P", function()
				player_controll.config_mode_off()
				debugdip.config_cpu_cant_move(true)
				auto_guard.config_forward(true)
			end,
			"1P vs COM", function()
				player_controll.config_mode_cpu(1)
				debugdip.config_cpu_cant_move(false)
				auto_guard.config_forward(false)
			end,
			"COM vs 2P", function()
				player_controll.config_mode_cpu(2)
				debugdip.config_cpu_cant_move(false)
				auto_guard.config_forward(false)
			end,
			"COM vs COM", function()
				player_controll.config_mode_cpu(3)
				debugdip.config_cpu_cant_move(false)
				auto_guard.config_forward(false)
			end,
		})
		local options = {}
		for slot = 1, 10 do
			options[#options + 1] = tostring(slot)
			options[#options + 1] = function() player_controll.config_player_slot(slot) end
		end
		table.insert(menu, "SLOT:")
		table.insert(menu, options)
		table.insert(menu, "ON DAMAGE:")
		table.insert(menu, {
			"CONTINUE", function() player_controll.config_replay_on_damage_stop(false) end,
			"STOP", function() player_controll.config_replay_on_damage_stop(true) end,
		})
		table.insert(menu, "REPEAT:")
		table.insert(menu, {
			"ON", function() player_controll.config_replay_repeat(true) end,
			"OFF", function() player_controll.config_replay_repeat(false) end,
		})
		table.insert(menu, "POSITION:")
		table.insert(menu, {
			"FIXED", function() player_controll.config_replay_position_fixed() end,
			"RELATIVE", function() player_controll.config_replay_position_relative() end,
			"OFF", function() player_controll.config_replay_position_off() end,
		})
	end,
	function(menu)
		global.next_active_menu_with_save(global.main)
	end,
	function(menu)
		global.next_active_menu(global.main)
	end,
	function(menu)
		menu.config[1] = 3
		menu.config[2] = 1
		menu.config[3] = 2
		menu.config[4] = 1
		menu.config[5] = 1
	end)

global.main = create_menu(
	"- MAIN MENU -",
	function(menu)
		table.insert(menu, "TRAINIG MENU")
		table.insert(menu, { "", no_op, })
		table.insert(menu, "RE-PLAY MENU")
		table.insert(menu, { "", no_op, })
		local save_max = 10
		local options = nil

		table.insert(menu, "LOAD:")
		options = { }
		for i = 1, save_max do
			options[#options + 1] = "SLOT "..i
			options[#options + 1] = function() global.load = i end
		end
		table.insert(menu, options)

		table.insert(menu, "SAVE:")
		options = { }
		for i = 1, save_max do
			options[#options + 1] = "SLOT "..i
			options[#options + 1] = function() global.save = i end
		end
		table.insert(menu, options)

		table.insert(menu, "AUTO SAVE & LOAD:")
		table.insert(menu, {
			"ON", function() global.autosave = true end,
			"OFF", function() global.autosave = false end,
		})
		table.insert(menu, "PLAYER & STAGE:")
		table.insert(menu, {
			"QUICK SELECT", no_op,
			"ROUND RESTART", no_op,
			"BACK PLAYER SELECT", no_op,
		})
		table.insert(menu, "EXTRA MENU")
		table.insert(menu, { "", no_op, })
		table.insert(menu, "EXIT MENU")
		table.insert(menu, { "", no_op, })
	end,
	function(menu)
		if menu.p == 1 then
			global.next_active_menu(global.training)
		elseif menu.p == 2 then
			global.next_active_menu(global.rec)
		elseif menu.p == 3 then
			global.do_load()
		elseif menu.p == 4 then
			global.do_save()
		elseif menu.p == 5 then
		elseif menu.p == 6 then
			local opt = menu.opt_p[menu.p]
			if opt == 1 then
				hit_boxes.initialize_buffers()
				global.player_and_stg.opt_p[1] = memory.readbyte(0x107BA5)
				global.player_and_stg.opt_p[2] = memory.readbyte(0x107BAC) + 1
				global.player_and_stg.opt_p[3] = memory.readbyte(0x107BA7)
				global.player_and_stg.opt_p[4] = memory.readbyte(0x107BAD) + 1
				global.player_and_stg.opt_p[5] = global.next_stg_revkeys[ tohex(memory.readbyte(0x107BB1)).."-"..tohex(memory.readbyte(0x107BB7) )]
				global.player_and_stg.opt_p[6] = math.max(memory.readbyte(0x10A8D5), 1)
				global.next_active_menu(global.player_and_stg)
			elseif opt == 1 then
				hit_boxes.initialize_buffers()
				global.next_p1 = memory.readbyte(0x107BA5)
				global.next_p1col = memory.readbyte(0x107BAC)
				global.next_p2 = memory.readbyte(0x107BA7)
				global.next_p2col = memory.readbyte(0x107BAD)
				global.next_stage = memory.readbyte(0x107BB1)
				global.next_stage_tz = memory.readbyte(0x107BB7)
				global.next_bgm = math.max(memory.readbyte(0x10A8D5), 1)
				global.restart_fight()
			elseif opt == 3 then
				global.goto_player_select()
			end
		elseif menu.p == 7 then
			global.next_active_menu(global.extra)
		else
			global.next_active_menu(global.fighting)
			-- -auto save only the main menu
			table.save(menu.config, "save\\rbff2-main.tbl")
		end
		collectgarbage("count")
	end,
	function(menu)
		global.next_active_menu(global.fighting)
	end,
	function(menu)
		menu.config[1] = 1
		menu.config[2] = 1
		menu.config[3] = 1
		menu.config[4] = 1
		menu.config[5] = 1
	end)

global.next_active_menu(global.fighting)

global.do_load = function()
	local loc = "save\\"..global.load.."\\"

	global.copy_config(table.load(loc.."rbff2-training.tbl"), global.training.config)
	global.copy_config(table.load(loc.."rbff2-rec.tbl"), global.rec.config)
	player_controll.each_replay_slots(function(i, slot)
		global.copy_config(table.load(loc.."rbff2-rec-slot".. i ..".tbl"), slot)
	end)
	global.copy_config(table.load(loc.."rbff2-player-stg.tbl"), global.player_and_stg.config)
	global.copy_config(table.load(loc.."rbff2-extra.tbl"), global.extra.config)

	global.apply_menu_options(global.training)
	global.apply_menu_options(global.rec)
	global.apply_menu_options(global.player_and_stg)
	global.apply_menu_options(global.extra)
	collectgarbage("count")
end

global.do_save = function()
	local loc = "save\\"..global.save.."\\"
	os.execute("mkdir " .. loc)
	table.save(global.training.config, loc.."rbff2-training.tbl")
	table.save(global.rec.config, loc.."rbff2-rec.tbl")
	player_controll.each_replay_slots(function(i, slot)
		table.save(slot, loc.."rbff2-rec-slot".. i ..".tbl")
	end)
	table.save(global.player_and_stg.config, loc.."rbff2-player-stg.tbl")
	table.save(global.extra.config, loc.."rbff2-extra.tbl")
	collectgarbage("count")
end

global.do_autosave = function()
	if global.autosave then
		global.do_save()
	end
end

gui.register(function()
	if global.mode_switching then
		gui.clearuncommitted()
	else
		draw_screen(global.active_menu)
	end
end)

emu.registerbefore(function()
	end)

save_memory.enabled = false

emu.registerafter(function()
	if global.mode_switching then
		wait_for_switching(global.active_menu)
	else
		execute(global.active_menu)
	end

	save_memory.save()

end)

emu.registerexit(function()
	slow.term()
	debugdip.release_debugdip()
	life_recover.term_life_recover()
end)

savestate.registerload(function()
	hit_boxes.initialize_buffers()
end)

emu.registerstart(function()
	debugdip.release_debugdip()
	osd.whatgame_OSD()
	hit_boxes.whatgame()
	fireflower_patch.apply_patch_file([[.\rom-patch\]]..emu.romname()..[[\char1-p1.pat]], 0x000000, false)

	-- auto load only the main menu
	global.copy_config(table.load("save\\rbff2-main.tbl"), global.main.config)
	if global.main.config[5] == 1 then
		global.autosave = true
		global.do_load()
	end
	for _, menu in pairs({ global.main, global.rec, global.training,
		global.fighting, global.extra, global.player_and_stg }) do
		global.copy_config(menu.config, menu.opt_p)
		global.apply_menu_options(menu)
	end
end)

collectgarbage("count")
