@echo off
cd /d %~dp0
FOR /F "usebackq" %%a IN (`cd`) DO SET d1=%%a
SET d2=%d1%\tp
SET d3=
setlocal enabledelayedexpansion

FOR /R %%a IN (*.png) DO (
	echo "%%a" | find "\tp\" >NUL
	if ERRORLEVEL 1 (
		set fpath=%%a
		set fto=!!fpath:%d1%=%d2%!!
		set fdir=!!fto:%%~nxa=%d3%!!
		echo ------------
		echo from !fpath!
		echo to   !fto!
		echo dir  !fdir!
		if NOT exist "!fdir!" ( mkdir !fdir! )
		magick convert "!fpath!" -strip -crop 320x216+0+4 -trim -transparent "#B0B6BE" "!fto!"
	)
)
endlocal enabledelayedexpansion
