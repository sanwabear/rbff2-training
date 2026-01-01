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
local ut         = require("rbff2training/util")
local man        = manager
local machine    = man.machine
local cpu        = machine.devices[":maincpu"]
local pgm        = cpu.spaces["program"]
local safe_cb          = function(cb)
    return function(...)
        local status, ret_or_msg = pcall(cb, ...)
        if not status then
            emu.print_error(string.format('Error in callback: %s', ret_or_msg))
            return nil
        end
        return ret_or_msg
    end
end
local mem              = {
    w08    = function(addr, value) pgm:write_u8(addr, value) end,
    wd08   = function(addr, value) pgm:write_direct_u8(addr, value) end,
    w16    = function(addr, value) pgm:write_u16(addr, value) end,
    wd16   = function(addr, value) pgm:write_direct_u16(addr, value) end,
    w32    = function(addr, value) pgm:write_u32(addr, value) end,
    wd32   = function(addr, value) pgm:write_direct_u32(addr, value) end,
    w08i   = function(addr, value) pgm:write_i8(addr, value) end,
    w16i   = function(addr, value) pgm:write_i16(addr, value) end,
    w32i   = function(addr, value) pgm:write_i32(addr, value) end,
    r08    = function(addr, value) return pgm:read_u8(addr, value) end,
    r16    = function(addr, value) return pgm:read_u16(addr, value) end,
    r32    = function(addr, value) return pgm:read_u32(addr, value) end,
    r08i   = function(addr, value) return pgm:read_i8(addr, value) end,
    r16i   = function(addr, value) return pgm:read_i16(addr, value) end,
    r32i   = function(addr, value) return pgm:read_i32(addr, value) end,
    holder = { cnt = 0, },
}
local count            = 0
local countup          = function(label)
    count = count + 1
    return count
end
local holder           = nil
mem.rg                 = function(id, mask) return (mask == nil) and cpu.state[id].value or (cpu.state[id].value & mask) end
mem.pc                 = function() return cpu.state["CURPC"].value end
mem.wp_cnt, mem.rp_cnt = {}, {} -- 負荷確認のための呼び出す回数カウンター
mem.wp                 = function(addr1, addr2, name, cb) return pgm:install_write_tap(addr1, addr2, name, safe_cb(cb)) end
mem.rp                 = function(addr1, addr2, name, cb) return pgm:install_read_tap(addr1, addr2, name, safe_cb(cb)) end
mem.wp08               = function(addr, cb, filter)
    local num = countup()
    local name = string.format("wp08_%x_%s", addr, num)
    if addr % 2 == 0 then
        holder.taps[name] = mem.wp(addr, addr + 1, name,
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
        holder.taps[name] = mem.wp(addr - 1, addr, name,
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
    return holder.taps[name]
end
mem.wp16               = function(addr, cb, filter)
    local num = countup()
    local name = string.format("wp16_%x_%s", addr, num)
    holder.taps[name] = mem.wp(addr, addr + 1, name,
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
    return holder.taps[name]
end
mem.wp32               = function(addr, cb, filter)
    local num = countup()
    local name = string.format("wp32_%x_%s", addr, num)
    holder.taps[name] = mem.wp(addr, addr + 3, name,
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
    return holder.taps[name]
end
mem.rp08               = function(addr, cb, filter)
    local num = countup()
    local name = string.format("rp08_%x_%s", addr, num)
    if addr % 2 == 0 then
        holder.taps[name] = mem.rp(addr, addr + 1, name,
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
        holder.taps[name] = mem.rp(addr - 1, addr, name,
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
    return holder.taps[name]
end
mem.rp16               = function(addr, cb, filter)
    local num = countup()
    local name = string.format("rp16_%x_%s", addr, num)
    holder.taps[name] = mem.rp(addr, addr + 1, name,
        function(offset, data, mask)
            mem.rp_cnt[addr] = (mem.rp_cnt[addr] or 0) + 1
            if filter and filter[mem.pc()] ~= true then return data end
            local ret = {}
            if offset == addr then cb(data, ret) end
            return ret.value or data
        end)
    safe_cb(cb)(mem.r16(addr), {})
    return holder.taps[name]
end
mem.rp32               = function(addr, cb, filter)
    local num = countup()
    local name = string.format("rp32_%x_%s", addr, num)
    holder.taps[name] = mem.rp(addr, addr + 3, name,
        function(offset, data, mask)
            mem.rp_cnt[addr] = (mem.rp_cnt[addr] or 0) + 1
            if filter and filter[mem.pc()] ~= true then return data end
            if offset == addr then cb(data << 0x10 | mem.r16(addr + 2)) end -- r32を行うと再起でスタックオーバーフローエラーが発生する
            return data
        end)
    safe_cb(cb)(mem.r32(addr))
    return holder.taps[name]
end

local reset_memory_tap = function(label, enabled, force)
    if not holder then return end
    local subs
    if label then
        local sub = holder.sub[label]
        if not sub then return end
        subs = { sub }
    else
        subs = holder.sub
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
local load_memory_tap  = function(label, wps)                             -- tapの仕込み
    --[[
    wpsはプレイヤーサイドごとのフック設定でアドレス、CURPCフィルターをキー、フックロジックを値要素とするテーブル構造

    ]]
    if holder and holder.sub[label] then
        reset_memory_tap(label, true)
        return
    end
    if holder == nil then
        holder = { on = true, taps = {}, sub = {}, }
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
    holder.sub[label] = sub
    print("load_memory_tap [" .. label .. "] done")
end
mem.reset_memory_tap   = reset_memory_tap
mem.load_memory_tap    = load_memory_tap

print("mem loaded")
return mem
