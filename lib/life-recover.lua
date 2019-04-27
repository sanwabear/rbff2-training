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
require("rbff2-global")

local max_stun = {}
max_stun[0x01] = 32--Terry Bogard
max_stun[0x02] = 31--Andy Bogard
max_stun[0x03] = 32--Joe Higashi
max_stun[0x04] = 29--Mai Shiranui
max_stun[0x05] = 33--Geese Howard
max_stun[0x06] = 32--Sokaku Mochizuki
max_stun[0x07] = 31--Bob Wilson
max_stun[0x08] = 31--Hon-Fu
max_stun[0x09] = 29--Blue Mary
max_stun[0x0A] = 35--Franco Bash
max_stun[0x0B] = 38--Ryuji Yamazaki
max_stun[0x0C] = 29--Jin Chonshu
max_stun[0x0D] = 29--Jin Chonrei
max_stun[0x0E] = 32--Duck King
max_stun[0x0F] = 32--Kim Kaphwan
max_stun[0x10] = 32--Billy Kane
max_stun[0x11] = 31--Cheng Sinzan
max_stun[0x12] = 31--Tung Fu Rue
max_stun[0x13] = 35--Laurence Blood
max_stun[0x14] = 35--Wolfgang Krauser
max_stun[0x15] = 32--Rick Strowd
max_stun[0x16] = 29--Li Xiangfei
max_stun[0x17] = 32--#Alfred#

local life_config = {
	timer = false, --false is imidiate recover, true is time-delayed recovery.
	players = {
		{ old_state = 0, life_addr = 0x10048B, state_addr = 0x10048E, char_addr = 0x107BA5, stun_addr = 0x10B84E,        timer = 0, state = 0, max_life = 0x60, pow_addr = 0x1004BC, max_pow = 0x3C, life_rec = true },
		{ old_state = 0, life_addr = 0x10058B, state_addr = 0x10058E, char_addr = 0x107BA7, stun_addr = 0x10B84E + 0x08, timer = 0, state = 0, max_life = 0xC0, pow_addr = 0x1005BC, max_pow = 0x00, life_rec = true },
	},
}

local recovery = function(player)
	if not player.life_rec then
		return
	end

	-- Recovery vital & stun -- apply
	memory.writebyte(player.life_addr, player.max_life)	--cheat "Energy Full=0xC0 Half=0x60"
	if max_stun[memory.readbyte(player.char_addr)] then
		memory.writebyte(player.stun_addr, max_stun[memory.readbyte(player.char_addr)]) -- max stun
	end
end

life_recover = {}

life_recover.term_life_recover = function()
	for _, player in ipairs(life_config.players) do
		memory.writebyte(player.life_addr, 0xC0)	--cheat "Energy Full=0xC0 Half=0x60"
	end
	memory.writebyte(0x1004BC, 0x00)	--cheat "Power PL1"
	memory.writebyte(0x1005BC, 0x00)	--cheat "Power PL2
end

life_recover.update_life_recover = function()
	for _, player in ipairs(life_config.players) do
		local stun = memory.readbyte(player.stun_addr)
		local life = memory.readbyte(player.life_addr)
		player.state = memory.readbyte(player.state_addr)

		if life_config.timer then
			if player.timer == -1 then
				if player.life ~= p.max_life then
					player.timer = 1
				end
			else
				if player.state ~= 0 then
					player.timer = -1
				else
					player.timer = player.timer + 1
				end
			end
			if 180 < player.timer or player.max_life < life then
				recovery(player)
				player.timer = -1
			end
		else
			if player.old_state ~= player.state or player.max_life < life then
				recovery(player)
			end
			player.old_state = player.state
		end

		if player.max_pow ~= 0 then
			memory.writebyte(player.pow_addr, player.max_pow)	--cheat "Infinite Power"
		end
	end
end

local fixside = function(pside)
	local p = 0
	if pside == -1 then
		return 1
	else
		return 2
	end
end

life_recover.config_life = function(pside, true_is_full)
	local player = life_config.players[fixside(pside)]
	player.max_life = true_is_full and 0xC0 or 0x60
	player.timer = 0
	player.state = 0
	player.life_rec = true
	recovery(player)
end

life_recover.config_life_off = function(pside)
	life_config.players[fixside(pside)].life_rec = false
end

life_recover.config_pow = function(pside, true_is_full)
	life_config.players[fixside(pside)].max_pow = true_is_full and 0x3C or 0x00
end
