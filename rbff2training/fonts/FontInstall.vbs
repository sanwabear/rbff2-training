Const FONTS = &H14& 

fontfile = WScript.Arguments(0) '第一引数:フォントファイル名

Set objShell = CreateObject("Shell.Application")
Set objWshShell = CreateObject("WScript.Shell")

Set objFolder = objShell.Namespace(FONTS)
WScript.echo "Workdir= " & objWshShell.CurrentDirectory
objFolder.CopyHere objWshShell.CurrentDirectory & "\Fonts\" & fontfile