@echo off
rem フォントインストール用のスクリプト呼出
set NO_FONTS = TRUE
if exist "%windir%\Fonts\Noto Sans Mono CJK JP Bold.otf" (
    goto term
)
if exist "%LOCALAPPDATA%\Microsoft\Windows\Fonts\Noto Sans Mono CJK JP Bold.otf" (
    goto term
)
cscript .\fonts\FontInstall.vbs "Noto Sans Mono CJK JP Bold.otf"

term:
