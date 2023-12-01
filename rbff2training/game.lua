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
local gm          = {}

local ver = {
    mvs = "rbff2", aes = "rbff2h", korea = "rbff2k",
}

local addr_offset = {
    [0x012C42] = { [ver.korea] = 0x28, [ver.aes] = 0x00 },
    [0x012C88] = { [ver.korea] = 0x28, [ver.aes] = 0x00 },
    [0x012D4C] = { [ver.korea] = 0x28, [ver.aes] = 0x00 }, --p1 push
    [0x012D92] = { [ver.korea] = 0x28, [ver.aes] = 0x00 }, --p2 push
    [0x039F2A] = { [ver.korea] = 0x0C, [ver.aes] = 0x20 }, --special throws
    [0x017300] = { [ver.korea] = 0x28, [ver.aes] = 0x00 }, --solid shadows
}

local addr_clone  = { [ver.korea] = -0x104, [ver.aes] = 0x20 }

gm.fix_addr       = function(addr)
    local fix1 = addr_clone[emu.romname()] or 0
    local fix2 = addr_offset[addr] and (addr_offset[addr][emu.romname()] or fix1) or fix1
    return addr + fix2
end

return gm