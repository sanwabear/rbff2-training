@echo off
cd /d %~dp0

@rem Noto Sans Mono CJK JP Boldフォントのインストール
call fonts\FontInstall.bat

if NOT exist mame.exe cd ..
if NOT exist mame.exe cd ..
if NOT exist mame.exe exit

set common_opts=-rompath roms;C:\tools\roms\humblebundle_neogeo25th
set common_opts=%common_opts% -bios unibios40 -confirm_quit -verbose -pause_brightness 1
@rem 前提
@rem ASIO4ALLのインストール
rem set common_opts=%common_opts% -samplerate 44100 -nocompressor -audio_latency 1
rem set common_opts=%common_opts% -sound portaudio -pa_api "Windows WDM-KS" -pa_latency 0.001
rem set common_opts=%common_opts% -volume -5 -samples
rem set common_opts=%common_opts% -sound auto
set common_opts=%common_opts% -cheat -cheatpath plugins\rbff2training\cheat
set common_opts=%common_opts% -fontpath plugins\rbff2training\fonts
set common_opts=%common_opts% -artpath plugins\rbff2training\artwork
set common_opts=%common_opts% -uifont "Noto Sans Mono CJK JP Bold"
set common_opts=%common_opts% -nofilter -frameskip 0 -noautoframeskip -throttle -lowlatency -refreshspeed -nosleep
rem set common_opts=%common_opts% -switchres 
rem set common_opts=%common_opts% -resolution 0x0@120
set common_opts=%common_opts% -language Japanese
set common_opts=%common_opts% -skip_gameinfo
set common_opts=%common_opts% %debug% %nvram_save%
rem set common_opts=%common_opts% -prescale 4
rem set common_opts=%common_opts% -video d3d
rem set common_opts=%common_opts% -ramsize 1024K
rem set common_opts=%common_opts% -resolution 1600x1120@144
rem set common_opts=%common_opts%

@echo on
chcp 65001
mame.exe %common_opts% %*
