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
local exports             = {}
exports.name              = "rbff2training"
exports.version           = "1.0.0"
exports.description       = "RBFF2 Training"
exports.license           = "MIT License"
exports.author            = { name = "Sanwabear" }
local rbff2training       = exports
local subscription        = { reset = nil, stop = nil, frame = nil, pause = nil, resume = nil, }

rbff2training.startplugin = function()
    local mode = 1 -- 1:ON 0:OFF 自動有効化のためデフォルト値は1にする
    local dummy, core, rbff2

    local is_target_rom = function()
        return emu.romname() == "rbff2h" -- TODO: rbff2, rbff2k
    end

    local core_to_dummy = function()
        if not core.is_dummy and is_target_rom() then
            print("Disable Training-Core")
            core.emu_stop()
            core = dummy
            rbff2 = nil
        end
        mode = core.is_dummy and 0 or 1
    end

    local core_to_rbff2 = function()
        if core.is_dummy and is_target_rom() then
            print("Enable Training-Core")
            rbff2 = rbff2 or require("rbff2training/rbff2")
            rbff2.self_disable = false
            rbff2.startplugin()
            rbff2.emu_start()
            core = rbff2
            manager.machine:soft_reset()
        end
        mode = core.is_dummy and 0 or 1
    end

    local null_function = function() end
    local auto_start = function() if is_target_rom() and mode == 1 then core_to_rbff2() else core_to_dummy() end end

    core = {
        is_dummy = true,
        emu_pause = null_function,
        emu_frame_done = null_function,
        emu_periodic = null_function,
        emu_menu = null_function,
        emu_start = auto_start,
        emu_stop = null_function,
    }
    dummy = core

    subscription.reset = emu.add_machine_reset_notifier(function() core.emu_start() end)
    subscription.stop = emu.add_machine_stop_notifier(function() core.emu_stop() end)
    subscription.pause = emu.add_machine_pause_notifier(function() core.emu_pause() end)
    emu.register_frame_done(function() core.emu_frame_done() end)
    emu.register_periodic(function()
        if core.self_disable then
            mode = 2
            core_to_dummy()
        else
            core.emu_periodic()
        end
    end)

    local menu_callback = function(index, event)
        if not is_target_rom() then
            mode = 0
            return false
        end
        if (event == "left") or (event == "right") then
            mode = (mode ~= 0) and 0 or 1
            return true
        elseif (event == "select") then
            if mode > 0 then core_to_rbff2() else core_to_dummy() end
            return true
        end
        return false
    end

    local menu_populate = function()
        local result = {}
        if is_target_rom() then
            table.insert(result, { exports.description, (mode > 0) and "ON" or "OFF", (mode > 0) and "l" or "r" })
        else
            table.insert(result, { exports.description, "---", "" })
        end
        return result
    end

    emu.register_menu(menu_callback, menu_populate, exports.description)
end

return exports
