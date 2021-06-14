cd /d %~dp0
FOR %%a IN (*.png) DO magick convert "%%~nxa" -strip -crop 320x216+0+0 -trim -transparent "#B0B6BE" "tp\%%~nxa"
