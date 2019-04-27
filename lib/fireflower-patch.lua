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
fireflower_patch = {
	apply_patch = function(s_patch, offset, force)
		local ptn = "%s*(%w+):%s+(%w+)%s+(%w+)%s*[\r\n]+"
		local fixaddr = function(saddr)
			local addr = tonumber(saddr, 16) + offset
			if (addr % 2 == 0) then
				return addr + 1
			else
				return addr - 1
			end
		end
		if not force then
			for saddr, v1, v2 in string.gmatch(s_patch, ptn) do
				local before = memory.readbyte(fixaddr(saddr))
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
		for saddr, v1, v2 in string.gmatch(s_patch, ptn) do
			memory.writebyte(fixaddr(saddr), tonumber(v2, 16))
		end
		print("patch load")
		return true
	end
}
