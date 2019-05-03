print("On-screen info display for fighting games")
print("October 20, 2012")
print("http://code.google.com/p/mame-rr/")
--print("Lua hotkey 1: toggle numbers")
--print("Lua hotkey 2: toggle bars")

--------------------------------------------------------------------------------
-- user configuration

local function tohex(num)
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

local c = { --colors
	bg            = {fill   = 0x3A3A3AFF, outline  = 0xFFFFFFFF},
	stun_level    = {normal = 0xFF6B00FF, overflow = 0xFFAAAAFF, shadow = 0xFF4A00FF, shadow2 = 0xFF0000FF},
	stun_timeout  = {normal = 0x6BADD6FF, overflow = 0x106BB5FF, shadow = 0x398CC6FF, shadow2 = 0x106BB5FF},
	stun_duration = {normal = 0x00C0FFFF, overflow = 0xA0FFFFFF},
	stun_grace    = {normal = 0x00FF00FF, overflow = 0xFFFFFFFF},

	green  = 0x00FF00FF,
	yellow = 0xFFFF00FF,
	pink   = 0xFFB0FFFF,
	gray   = 0xCCCCFFFF,
	white  = 0xFFFFFFFF,
	cyan   = 0x00FFFFFF,
	cyan2  = 0x003030FF,
	none   = 0x00000000,
}

local show_numbers = true
local show_bars    = true
local show_combos  = true

config_show_numbers = function(flg) show_numbers = flg end
config_show_bars = function(flg) show_bars = flg end
config_show_combos = function(flg) show_combos = flg end

--------------------------------------------------------------------------------
-- game-specific modules

local game, show_OSD, player

local rb, rw, rd = memory.readbyte, memory.readword, memory.readdword
local rbs, rws, rds = memory.readbytesigned, memory.readwordsigned, memory.readdwordsigned

local combo_dmg_ext = {}
local update_dmg = {} -- index 1P=1 2P=-1, value=framecount

local function any_true(condition)
	for n = 1, #condition do
		if condition[n] == true then return true end
	end
end

local get_state = function(t)
	for _, set in ipairs(t) do
		if set.condition == true or set.condition == nil then
			return set.state, set.val, set.max
		end
	end
end

local profile = {
	{	games = {"rbff2"},
		player     = 0x100400, space            = 0x100,
		max_stun   = 0x10B84E, max_stun_space   = 0x08,
		combo      = 0x10B4E5, combo_space      = -0x01,
		tmp_combo  = 0x10B4E1, tmp_combo_space  = -0x01,
		max_combo  = 0x10B4F0, max_combo_space  = -0x01,
		text = {
			life         = {name = "life"         , offset = 0x8B, max = 192, pos_X = 0x30, pos_Y = 0x14, read = rb, align = "align outer"},
			super        = {name = "super"        , offset = 0xBC, max =  60, pos_X = 0x1A, pos_Y = 0xD1, read = rb, align = "align outer"},
			state        = {name = "state"        , offset = 0x8E, max = nil, pos_X = 0x2A, pos_Y = 0x28, read = rb, align = "align outer"},
			move_state   = {name = "move_state"   , offset = 0x61, max = nil, pos_X = 0x2A, pos_Y = 0x2F, read = rb, align = "align outer"},
			last_dmg     = {name = "last_dmg"     , offset = 0x8F, max = nil, pos_X = 0x60, pos_Y = 0x3D, read = rb, align = "align outer2", combo = true,},
			combo_dmg    = {name = "combo_dmg"    , offset = 0x8F, max = nil, pos_X = 0x4C, pos_Y = 0x3D, read = rb, align = "align outer2", combo = true,},
			max_dmg      = {name = "max_dmg"      , offset = 0x8F, max = nil, pos_X = 0x38, pos_Y = 0x3D, read = rb, align = "align outer2", combo = true,},
			combo        = {name = "combo"        , offset = 0x8F, max = nil, pos_X = 0x4C, pos_Y = 0x45, read = rb, align = "align outer2", combo = true,},
			max_combo    = {name = "max_combo"    , offset = 0x8F, max = nil, pos_X = 0x38, pos_Y = 0x45, read = rb, align = "align outer2", combo = true,},

			label_side   = {name = "label_side"   , offset = 0x8F, max = nil, pos_X = 0x78, pos_Y = 0x35, read = rb, align = "align outer2", combo = true,},
			label_dmg    = {name = "label_last"   , offset = 0x8F, max = nil, pos_X = 0x78, pos_Y = 0x3D, read = "DAMAGE", align = "align outer2", combo = true,},
			label_combot = {name = "label_combo"  , offset = 0x8F, max = nil, pos_X = 0x78, pos_Y = 0x45, read = "COMBO ", align = "align outer2", combo = true,},
			label_combo  = {name = "label_combo"  , offset = 0x8F, max = nil, pos_X = 0x4C, pos_Y = 0x35, read = "LAST", align = "align outer2", combo = true,},
			label_max    = {name = "label_max"    , offset = 0x8F, max = nil, pos_X = 0x38, pos_Y = 0x35, read = "BEST", align = "align outer2", combo = true,},
		},
	
		stun_bar = {
			pos_X = 0x0F, pos_Y = 0x28, length = 0x40, height = 0x04, 
			level = function(p) return rb(p.max_stun_base + 0x02), rb(p.max_stun_base) end,
			timeout = function(p)
				local state = rb(p.base + 0x02)
				return get_state({
					{
						state = "countdown", 
						val = rw(p.max_stun_base + 0x06), 
						max = 60, 
						condition = state == 0xBB 
					},
					{
						state = "", 
						val = rw(p.max_stun_base + 0x06), 
						max = 60
					},
				})
			end,
		},

		show_OSD = function()
			return any_true({
				rw(0x107C22) == 0x3800, rw(0x107C22) == 0x4400, rw(0x107C22) == 0x7738, 
			})
		end,
	},
}

--------------------------------------------------------------------------------
-- post-process the modules

local functionize = function(param)
	if type(param) == "number" then
		return (function() return param end)
	end
	return param
end

for _, g in ipairs(profile) do
	g.space     = g.space    or 0x400
	g.nplayers  = g.nplayers or 2
	g.X_offset  = g.X_offset or {0, 0}
	g.Y_offset  = g.Y_offset or {0, 0}
	g.base_type = g.player_ptr and "pointer" or "direct"
	g.player_active = g.player_active or function() return true end
	g.swap_sides    = g.swap_sides    or function() end
	local max_dmg_func = nil
	for _, text in pairs(g.text or {}) do
		if text.offset then
			if type(text.read) == "string" then
				text.val = function(p) return text.read end
			else
				text.val = function(p) return (text.read or rw)(p.base + text.offset) end
			end
		end
		text.max = functionize(text.max)
		text.pos_X = functionize(text.pos_X)
		text.pos_Y = functionize(text.pos_Y)
		text.condition = text.condition or function() return true end

		if text.name == "label_side" then
			text.val = function(p)
				if p.side == 1 then
					return "-1P-  "
				else
					return "-2P-  "
				end
			end		
		elseif text.name == "combo_dmg" then
			text.ext = { }
			text.val = function(p)
				local combo = tonumber(tohex(rb(p.tmp_combo_base)))
				local now_dmg = g.text.last_dmg.val(p)
				local state = g.text.state.val(p) ~= 0

				text.ext = combo_dmg_ext[p.side]
				if state == false then
					text.ext.combo_dmg = 0
				end				

				if emu.framecount() == text.ext.update_dmg then
					text.ext.combo_dmg = text.ext.combo_dmg + now_dmg
					text.ext.old_combo_dmg = text.ext.combo_dmg
					if text.ext.max_dmg < text.ext.combo_dmg then
						text.ext.max_dmg = text.ext.combo_dmg
					end
				end

				if text.ext.last_combo < combo then
					text.ext.old_combo = combo	    
				end

				text.ext.last_combo = combo
				text.ext.last_state = state
				return text.ext.old_combo_dmg
			end
		elseif text.name == "combo" then
			text.val = function(p) return combo_dmg_ext[p.side].old_combo end
		elseif text.name == "max_combo" then
			text.val = function(p) return tohex(rb(p.max_combo_base)) end
		elseif text.name == "max_dmg" then
			text.val = function(p) return combo_dmg_ext[p.side].max_dmg end
		end
	end
	if g.stun_bar then
		g.stun_bar.align = g.stun_bar.align or "align inner"
	end
	g.initial = g.initial or function() end
	g.special = g.special or function() end
end

--------------------------------------------------------------------------------
-- hotkey functions
--[[
input.registerhotkey(1, function()
	show_numbers = not show_numbers
	print((show_numbers and "showing" or "hiding") .. " numbers")
end)

input.registerhotkey(2, function()
	show_bars = not show_bars
	print((show_bars and "showing" or "hiding") .. " bars")
end)
]]
--------------------------------------------------------------------------------
-- data update functions

local set_bar_text_X = {
	["align inner"] = function(text) --default
		return game.stun_bar.pos_X + game.stun_bar.length + 0x4
	end,

	["align outer"] = function(text)
		return game.stun_bar.pos_X - string.len(text) * 4 - 0x4
	end,
}


local set_text_X = {
	["align inner"] = function(p, text) --default
		return emu.screenwidth()/2 + p.side * (text.X + p.X_offset) - (p.side < 1 and 1 or 0) * text.width
	end,

	["align outer"] = function(p, text)
		return (p.side < 1 and 0 or 1) * (emu.screenwidth() - text.width) - p.side * text.X
	end,

	["align outer2"] = function(p, text)
		if p.side < 1 then
			return emu.screenwidth()*.63 + p.side * (text.X + p.X_offset) - text.width
		else
			return (emu.screenwidth() - text.width) - p.side * text.X
		end
	end,
}


local set_bar_base = {
	["align inner"] = function(p) --default
		return emu.screenwidth()/2, p.side
	end,

	["align outer"] = function(p)
		return (p.side < 1 and 0 or 1) * emu.screenwidth(), -p.side
	end,
}


local function set_bar_params(p, bar)
	bar.X = bar.X + p.X_offset
	bar.top = bar.Y + p.Y_offset
	bar.bottom = bar.top + bar.height
	bar.bg_inner = bar.base + bar.side * bar.X
	bar.bg_outer = bar.base + bar.side * (bar.X + bar.length)
	if bar.data.val == 0 then
		return
	end
	bar.normal_inner = bar.bg_inner
	bar.normal_outer = bar.data.val/bar.data.max >= 1 and bar.bg_outer or 
		bar.base + bar.side * (bar.X + bar.data.val/bar.data.max%1 * bar.length)
	if bar.data.val/bar.data.max < 1 then
		return
	end
	bar.over_inner = bar.bg_inner
	bar.over_outer = bar.base + bar.side * (bar.X + bar.data.val/bar.data.max%1 * bar.length)
end


local get_player_base = {
	["direct"] = function(p)
		return game.player + (p-1)*game.space
	end,
}

local get_max_stun_base = {
	["direct"] = function(p)
		return game.max_stun + (p-1)*game.max_stun_space
	end,
}

local get_combo_base = {
	["direct"] = function(p)
		return game.combo + (p-1)*game.combo_space
	end,
}

local get_tmp_combo_base = {
	["direct"] = function(p)
		return game.tmp_combo + (p-1)*game.tmp_combo_space
	end,
}

local get_max_combo_base = {
	["direct"] = function(p)
		return game.max_combo + (p-1)*game.max_combo_space
	end,
}
 

local get_char_data = function(p)
	for _, text in pairs(game.text or {}) do
		if text.condition(p) then
			local data = {X = text.pos_X(p), Y = text.pos_Y(p), color = text.color, 
				align = text.align, val = text.val(p), max = text.max and text.max(p), 
				label = text.label, combo = text.combo, }
			if text.max then
				data.max = text.max(p)
				data.val = (data.val > data.max and "-" or data.val) .. "/" .. data.max
			end
			table.insert(p.text, data)
		end
	end

	game.special(p)

	if not game.stun_bar then
		return
	end

	p.text.stun_level = {Y = game.stun_bar.pos_Y , align = game.stun_bar.align}
	p.text.stun_level.val, p.text.stun_level.max = game.stun_bar.level(p)
	p.bar.stun_level = {X = game.stun_bar.pos_X, Y = game.stun_bar.pos_Y + 1, 
		length = game.stun_bar.length, height = game.stun_bar.height, 
		data = p.text.stun_level, align = game.stun_bar.align, color = c.stun_level}

	p.text.stun_timeout = {Y = game.stun_bar.pos_Y + 6, align = game.stun_bar.align}
	p.bar.stun_timeout = {X = game.stun_bar.pos_X, Y = game.stun_bar.pos_Y + game.stun_bar.height + 3, 
		length = game.stun_bar.length, height = game.stun_bar.height, 
		data = p.text.stun_timeout, align = game.stun_bar.align}

	p.state, p.text.stun_timeout.val, p.text.stun_timeout.max = game.stun_bar.timeout(p)
	if p.state == "countdown" then
		p.bar.stun_timeout.color = c.stun_duration
	elseif p.state == "grace" then
		p.bar.stun_timeout.color = c.stun_grace
	else
		p.bar.stun_timeout.color = c.stun_timeout
	end

	p.text.stun_level.display = p.text.stun_level.val
	if p.state == "precountdown" or p.state == "countdown" then
		p.text.stun_level.val = p.text.stun_level.max
		p.text.stun_level.display = "-"
	end
	p.text.stun_level.display = p.text.stun_level.display .. "/" .. p.text.stun_level.max
	p.text.stun_level.X   = set_bar_text_X[game.stun_bar.align](p.text.stun_level.display)
	p.text.stun_timeout.X = set_bar_text_X[game.stun_bar.align](p.text.stun_timeout.val)
end


local guard_ext = {}

local update_guard = function()
end

update_OSD = function()
	if not game then
		return
	end
	show_OSD = game.show_OSD(game.player)
	for p = 1, game.nplayers do
		player[p].base = get_player_base[game.base_type](p)
		player[p].max_stun_base = get_max_stun_base[game.base_type](p)
		player[p].combo_base = get_combo_base[game.base_type](p)
		player[p].tmp_combo_base = get_tmp_combo_base[game.base_type](p)
		player[p].max_combo_base = get_max_combo_base[game.base_type](p)
		player[p].active = game.player_active(player[p])
		player[p].side = bit.band(p, 1) > 0 and -1 or 1
		player[p].X_offset = game.X_offset[p]
		player[p].Y_offset = game.Y_offset[p]
	end
	game.swap_sides(player)
	for p = 1, game.nplayers do
		local p = player[p]
		p.bar, p.text = {}, {}
		if p.active then
			get_char_data(p)
		end
		for _, text in pairs(p.text) do
			text.label = text.label or "" 
			text.combo = text.combo or false 
			text.display = text.display or text.val
			text.width = 4 * string.len(text.display)
			text.X = set_text_X[text.align or "align inner"](p, text)
			text.Y = text.Y + p.Y_offset
		end
		for _, bar in pairs(p.bar) do
			bar.base, bar.side = set_bar_base[bar.align or "align inner"](p)
			set_bar_params(p, bar)
		end
		local bar = p.bar.stun_level
		if bar then
			p.stun_X = bar.base + bar.side * (bar.X + bar.length/2) - 13
			p.stun_Y = bar.Y - 1
		end
	end
	--emu.message(string.format("P1: %s, P2: %s", player[1].state, player[2].state)) --debug
	
	update_guard()
end

--------------------------------------------------------------------------------
-- drawing functions

local function pixel(x1, y1, color, dx, dy)
	gui.pixel(x1 + dx, y1 + dy, color)
end

local function line(x1, y1, x2, y2, color, dx, dy)
	gui.line(x1 + dx, y1 + dy, x2 + dx, y2 + dy, color)
end

local function box(x1, y1, x2, y2, color, dx, dy)
	gui.box(x1 + dx, y1 + dy, x2 + dx, y2 + dy, color)
end

local draw_stun = function(p)
	local f, s, o = 0xF8B000FF, 0xB06000FF, 0x500000FF --fill, shade, outline colors
	local x, y = p.stun_X, p.stun_Y+1
	box(0,1,6,6, o, x, y)
	line(7,3,7,5, o, x, y)
	box(1,0,28,2, o, x, y)
	box(9,3,12,6, o, x, y)
	box(14,3,28,6, o, x, y)
	box(1,1,6,5, f, x, y)
	line(3,2,6,2, o, x, y)
	line(1,4,4,4, o, x, y)
	pixel(1,1, s, x, y)
	pixel(1,3, s, x, y)
	pixel(6,3, s, x, y)
	pixel(6,5, s, x, y)
	line(8,1,13,1, f, x, y)
	box(10,2,11,5, f, x, y)
	box(15,1,20,5, f, x, y)
	box(17,1,18,4, o, x, y)
	pixel(15,5, s, x, y)
	pixel(20,5, s, x, y)
	box(22,1,23,5, f, x, y)
	box(26,1,27,5, f, x, y)
	line(24,2,25,3, f, x, y)
	line(24,3,25,4, f, x, y)
end

local draw_player_objects = function(p)
	if show_bars then
		for _, bar in pairs(p.bar) do
			gui.box(bar.bg_inner-1*p.side, bar.top+1, bar.bg_outer+1*p.side, bar.bottom-1, c.bg.fill, c.bg.outline)
			gui.box(bar.bg_inner, bar.top, bar.bg_outer, bar.bottom, c.bg.fill, c.bg.outline)
			if bar.normal_outer then
				gui.box(bar.normal_inner, bar.top, bar.normal_outer, bar.bottom, bar.color.shadow, 0)
				gui.box(bar.normal_inner, bar.top+1, bar.normal_outer, bar.bottom, bar.color.shadow2, 0)
				gui.box(bar.normal_inner, bar.top+1, bar.normal_outer, bar.bottom-1, bar.color.normal, 0)
			end
			if bar.over_outer then
				gui.box(bar.over_inner, bar.top, bar.over_outer, bar.bottom, bar.color.shadow, 0)
				gui.box(bar.over_inner, bar.top+1, bar.over_outer, bar.bottom, bar.color.shadow2, 0)
				gui.box(bar.over_inner, bar.top+1, bar.over_outer, bar.bottom-1, bar.color.overflow, 0)
			end
		end
		if (p.state == "precountdown" or p.state == "countdown") 
			and bit.band(emu.framecount(), 8) > 0 
			then
			draw_stun(p)
		end
	end
	if show_numbers or show_combos then
		for _, text in pairs(p.text) do
			if (show_numbers and not text.combo) or (show_combos and text.combo) then
				gui.text(text.X, text.Y, text.label .. text.display, text.color or c.cyan)
			end
		end
	end
end

local stun_box = {
	box = {
		{ inner = emu.screenwidth()/2-15, top = 40, outer = emu.screenwidth()/2+15, bottom = 53, color = 0xFFFFFFFF, },
	},
	label = { 
		{ label = "STUN", x = emu.screenwidth()/2-8, y = 40, color = c.gray, color2 = c.cyan2, },
		{ label = "S.FRAME", x = emu.screenwidth()/2-13, y = 46, color = c.gray, color2 = c.cyan2, },
	}
}

draw_OSD = function()
	if not game or not show_OSD then
		return
	end
	for p = 1, game.nplayers do
		if player[p].active then
			draw_player_objects(player[p])
		end
	end
	if show_bars then
		for _, box in pairs(stun_box.box) do
			gui.box(box.inner, box.top, box.outer, box.bottom, box.color, 0)
		end
		for _, label in pairs(stun_box.label) do
			gui.text(label.x, label.y, label.label, label.color, label.color2)
		end
	end
end

--------------------------------------------------------------------------------
-- initialize on game startup

function whatgame_OSD()
	-- init latest combo and damage
	for _, addr in pairs({
		0x10048F, 0x10058F, 
		0x10B4E0, 0x10B4E1, 
		0x10B4EF, 0x10B4F0,
		}) do
		memory.writebyte(addr, 0x00)
	end

	for pside = -1, 1, 2 do
		combo_dmg_ext[pside] = {
			combo_dmg = 0, -- in COMBO temporary
			last_combo = 0, -- in COMBO temporary
			old_combo_dmg = 0, -- for COMBO DAMAGE
			old_combo = 0, -- for COMBO
			max_dmg = 0, -- for MAX DAMAGE
			last_state = false,
			update_dmg = 0, -- 
		}
		local hook_addr = 0x10058F 
		if pside == -1 then
			hook_addr = 0x10048F
		end
		
		memory.registerwrite(hook_addr, function() combo_dmg_ext[pside].update_dmg = emu.framecount() end)
	end

	update_guard = function()
		local pos_diff = memory.readwordsigned(0x100420) - memory.readwordsigned(0x100520)
		for pside, _ in pairs(guard_ext) do
			if guard_ext[pside].get_attack_type() then
				local tbl = { }
			 	if 0 > pside * pos_diff then
					tbl["P" .. guard_ext[pside].opponent_num .. " Left"] = true
			 	else
 					tbl["P" .. guard_ext[pside].opponent_num .. " Right"] = true
			 	end
				tbl["P" .. guard_ext[pside].opponent_num .. " Down"] = true
		
				--print(tbl)
				joypad.set(tbl)
			end
		end
	end

	game = nil
	player = {}
	for _, module in ipairs(profile) do
		for _, shortname in ipairs(module.games) do
			if emu.romname() == shortname or emu.parentname() == shortname then
				print("showing OSD for: " .. emu.gamename())
				game = module
				for p = 1, game.nplayers do
					player[p] = {}
				end
				game.initial()
				update_OSD()
				return
			end
		end
	end
	print("not prepared to show OSD for: " .. emu.gamename())
end

--[[
emu.registerstart(function()
	whatgame_OSD()
end)

emu.registerafter(function()
	update_OSD()
end)

gui.register(function()
	gui.clearuncommitted()
	draw_OSD()
end)
]]