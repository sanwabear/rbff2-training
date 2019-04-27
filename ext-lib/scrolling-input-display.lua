--[[
Scrolling input display Lua script
requires the Lua gd library (http://luaforge.net/projects/lua-gd/)
written by Dammit (dammit9x at hotmail dot com)

Works with MAME, FBA, pcsx, snes9x and Gens:
http://code.google.com/p/mame-rr/downloads/list
http://code.google.com/p/fbarr/downloads/list
http://code.google.com/p/pcsxrr/downloads/list
http://code.google.com/p/snes9x-rr/downloads/list
http://code.google.com/p/gens-rerecording/downloads/list
]]

version      = "11/10/2010"

iconfile     = "icons-neogeo-8.png"  --file containing the icons to be shown

buffersize   = 24     --how many lines to show
margin_left  = 0      --space from the left of the screen, in tiles, for player 1
margin_right = 3      --space from the right of the screen, in tiles, for player 2
margin_top   = 2      --space from the top of the screen, in tiles
timeout      = 240    --how many idle frames until old lines are cleared on the next input
screenwidth  = 256    --pixel width of the screen for spacing calculations (only applies if emu.screenwidth() is unavailable)

--Key bindings below only apply if the emulator does not support Lua hotkeys.
playerswitch = "Q"         --key pressed to toggle players on/off
clearkey     = "tilde"     --key pressed to clear screen
sizekey      = "semicolon" --key pressed to change icon size
scalekey     = "quote"     --key pressed to toggle icon stretching
recordkey    = "numpad/"   --key pressed to start/stop recording video

----------------------------------------------------------------------------------------------------
;

--folder with scrolling-input-code.lua, icon files, & frame dump folder (relative to this lua file)
resourcepath = "ext-lib/scrolling-input"

dofile(resourcepath .. "/scrolling-input-code.lua")
