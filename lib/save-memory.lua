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

local save_memory = {
	fcount = 1,
	enabled = false,
	save = nil,
	on_event = nil,
}

local rdpr = function(addr)
	local v = memory.readbyte(addr)
	if v ~= 0x00 then
		print(tohex(addr) .. " " .. tohex(v))
	end
end

local rdpr = function(addr)
	local v = memory.readbyte(addr)
	if v ~= 0x00 then
		print(tohex(addr) .. " " .. tohex(v))
	end
end

save_memory.save = function()
	if save_memory.enabled then
		local f = io.open(emu.framecount() .. "-" .. save_memory.fcount .. ".lua", "w")
		f:write("--MIT License\n")
		f:write("--\n")
		f:write("--Copyright (c) 2019 @ym2601 (https://github.com/sanwabear)\n")
		f:write("--\n")
		f:write("--Permission is hereby granted, free of charge, to any person obtaining a copy\n")
		f:write("--of this software and associated documentation files (the \"Software\"), to deal\n")
		f:write("--in the Software without restriction, including without limitation the rights\n")
		f:write("--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell\n")
		f:write("--copies of the Software, and to permit persons to whom the Software is\n")
		f:write("--furnished to do so, subject to the following conditions:\n")
		f:write("--\n")
		f:write("--The above copyright notice and this permission notice shall be included in all\n")
		f:write("--copies or substantial portions of the Software.\n")
		f:write("--\n")
		f:write("--THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\n")
		f:write("--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\n")
		f:write("--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\n")
		f:write("--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\n")
		f:write("--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\n")
		f:write("--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\n")
		f:write("--SOFTWARE.\n")
		f:write("for i = 0x100000, 0x10ffff do memory.writebyte(i, 0) end\n")
		f:write("local sr, wb = memory.setregister, memory.writebyte\n")
		for i = 0, 7 do
			f:write("--")
			f:write("sr(\"m68000.a")
			f:write(i)
			f:write("\", 0x")
			f:write(tohex(memory.getregister("m68000.a"..i)))
			f:write(")\n")
		end
		for i = 0, 7 do
			f:write("--")
			f:write("sr(\"m68000.d")
			f:write(i)
			f:write("\", 0x")
			f:write(tohex(memory.getregister("m68000.d"..i)))
			f:write(")\n")
		end
			f:write("--")
		f:write("sr(\"m68000.pc\", 0x")
		f:write(memory.getregister("m68000.pc"))
		f:write(")\n")
		for a = 0x100000, 0x1FFFFF do
			if memory.readbyte(a) ~= 0 then
				f:write("wb(0x")
				f:write(tohex(a))
				f:write(", 0x")
				f:write(string.format("%02s", tohex(memory.readbyte(a))))
				f:write(")\n")
			end
		end
		f:close()
		save_memory.fcount = save_memory.fcount + 1
	end
end
save_memory.on_event = function()
	local tbl = joypad.get()
	if save_memory.enabled and tbl["P1 Button A"] and tbl["P1 Start"] then
		save_memory.save()
	elseif save_memory.enabled and tbl["P1 Button B"] and tbl["P1 Start"] then
	end
end


--local back = nil
--local printpc =function(label)
--	return function()
--		print(label, back , tohex(memory.getregister("m68000.pc")))
--	end
--end
----memory.resisterwrite(0x100701, printpc("0x100701"))
--local regs = { "pc", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "d0", "d1", "d2", "d3", "d4", "d5", "d6", "d7", }
--local flga = false


--memory.registerwrite(0x107BA7, function() save_memory.enabled = true end)
--memory.registerwrite(0x107BB1, function() save_memory.enabled = true end)
--memory.registerwrite(0x107BB7, function() save_memory.enabled = true end)
--memory.registerread(0x107BA5, function() save_memory.enabled = false end)
--memory.registerread(0x107BAC, function() save_memory.enabled = false end)
--memory.registerread(0x107BA7, function() save_memory.enabled = false end)
--memory.registerread(0x107BAD, function() save_memory.enabled = false end)
--save_memory.enabled = true
--
--local prevp1 = memory.readbyte(0x107BA5)
--local p1ec = 0
--
--	if memory.readbyte(0x107BA5) ~= 0xFF then
--		save_memory.save()
--		p1ec = 1
--		save_memory.enabled = true
--	elseif p1ec == 1 then
--		save_memory.enabled = true
--	end
--	prevp1 = memory.readbyte(0x107BA5)
--
--	save_memory.save()
--save_memory.enabled = false