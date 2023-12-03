@echo off
@call mame_call.bat %~n0 -plugin rbff2training,data -nonvram_save %*
@pause