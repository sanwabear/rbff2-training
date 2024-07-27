@echo off
@call mame_call.bat %~n0 -plugin rbff2training,data,layout -nonvram_save -override_artwork rbff2h -artwork_crop %*
@pause