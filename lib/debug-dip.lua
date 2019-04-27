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

local dip_config ={
	infinity_life = false,
	infinity_time = true,
	fix_time = 0x99,
	stage_select = false,
	alfred = true,
	watch_states = false,
	cpu_cant_move = true,
}

debugdip = {}

debugdip.update_debugdips = function()
	local dip1 = 0x00
	local dip2 = 0x00
	local dip3 = 0x00

	if dip_config.infinity_life then
		dip1 = bit.bor(dip1, 0x02)	--cheat "DIP= 1-2 Infinite Energy"
	end

	if dip_config.infinity_time then
		dip2 = bit.bor(dip2, 0x10)	--cheat "DIP= 2-5 Disable Time Over"
		memory.writebyte(0x107C28, 0xAA)	--cheat "Infinite Time"
	end

	if dip_config.stage_select then
		dip1 = bit.bor(dip1, 0x04)	--cheat "DIP= 1-3 Stage Select Mode"
	end

	if dip_config.alfred then
		dip2 = bit.bor(dip2, 0x80)	--cheat "DIP= 2-8 Alfred Code (B+C >A)"
	end

	if dip_config.watch_states then
		dip2 = bit.bor(dip2, 0x20)	--cheat "DIP= 2-6 Watch States"
	end

	if dip_config.cpu_cant_move then
		dip3 = bit.bor(dip3, 0x01)	--cheat "DIP= 3-1 CPU Can't Move"
	end

	memory.writebyte(0x10E000, dip1)
	memory.writebyte(0x10E001, dip2)
	memory.writebyte(0x10E002, dip3)
end

debugdip.release_debugdip = function()
	memory.writebyte(0x107C28, flg and 0x99 or dip_config.fix_time)
	memory.writebyte(0x10E000, 0x00)
	memory.writebyte(0x10E001, 0x00)
	memory.writebyte(0x10E002, 0x00)
end

debugdip.config_fixed_life = function(flg)
	dip_config.infinity_life = flg
	debugdip.release_debugdip()
	debugdip.update_debugdips()
end

debugdip.config_watch_states = function(flg)
	dip_config.watch_states = flg
	debugdip.release_debugdip()
	debugdip.update_debugdips()
end

debugdip.config_inifinity_time = function(flg, fix_time)
	dip_config.infinity_time = flg
	dip_config.fix_time = fix_time or 0x99
	debugdip.release_debugdip()
	debugdip.update_debugdips()
end

debugdip.config_cpu_cant_move = function(flg)
	dip_config.cpu_cant_move = flg
end
