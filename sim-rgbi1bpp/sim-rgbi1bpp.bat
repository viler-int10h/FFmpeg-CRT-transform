::+++++++++++++++++++++++++::
:: Check cmdline arguments ::
::+++++++++++++++++++++++++::

@echo off & setlocal EnableDelayedExpansion

if [%1] neq [] if [%2] neq [] goto :ARGS_OK
  echo. & echo FFmpeg script for RGBI-on-1bpp simulation / VileR 2021
	echo. & echo USAGE:  %~n0 ^<method^> ^<input_file^> [output_file]
	echo         see sim-rgbi1bpp.txt for help
	exit /b
:ARGS_OK
	if [%3] neq [] (
		set OUTFILE=%~f3
		set OUTEXT=%~x3
	) else (
		set OUTFILE=%~d2%~p2%~n2_%~n1%~x2
		set OUTEXT=%~x2
	)
	if exist %2 goto :INPUT_OK
	echo. & echo File not found: %2 & exit /b
:INPUT_OK
	if [%OUTEXT%] neq [] goto :FILES_OK
	echo. & echo Output filename must have an extension: %OUTFILE% & exit /b
:FILES_OK
	set VALID_METHODS=,4x1a,4x2a,4x1b,4x2b,8x2,16x2,t4x1,t4x2,t8x2,t16x2,
	if /i "!VALID_METHODS:,%~1,=!" == "!VALID_METHODS!" (
		echo. & echo Invalid method: %1 ^(see sim-rgbi1bpp.txt for help^)
		exit /b 1
	)

::++++++++++++++++++++++++++++++++++++++++++++++::
:: Find input dimensions and type (image/video) ::
::++++++++++++++++++++++++++++++++++++++++++++++::

SET IX= & SET IY= & SET IR= & SET FC=
for /f %%i IN ('ffprobe -hide_banner -loglevel quiet -select_streams v:0 %2 -show_entries stream^=width^,height^,r_frame_rate^,nb_frames ^| find "="') do (
	set x=%%i
	if "!x:~0,6!"=="width=" SET IX=!x:~6!
	if "!x:~0,7!"=="height=" SET IY=!x:~7!
	if "!x:~0,13!"=="r_frame_rate=" SET IR=!x:~13!
	if "!x:~0,10!"=="nb_frames=" SET FC=!x:~10!
)
if "%IX%" neq " " if "%IY%" neq " " if "%IR%" neq " " if "%FC%" neq " " goto :ALL_OK
echo. & echo Couldn't get media data for input file "%2"^^^! & exit /b
:ALL_OK

if "%FC%" == "N/A" (
	set TMP_EXT=png
	set OUTPARAMS=
	set x=%1
	if /i "!x:~0,1!"=="t" (
		echo. & echo Cannot use a temporal method on a still image: %1 ^(see sim-rgbi1bpp.txt for help^)
		exit /b 1
	)
) else (
	set TMP_EXT=avi
	set OUTPARAMS=-c:a copy -c:v libx264rgb -crf 0
)

::++++++++++++++++++++++++++++++::
:: See if needs scaling + do it ::
::++++++++++++++++++++++++++++++::

SET SCALE_STR= 
if %IX% lss 640 (set FACTOR_W=2) else (set FACTOR_W=1)
if %IY% lss 400 (set FACTOR_H=2) else (set FACTOR_H=1)
SET /a "OX=%IX%*%FACTOR_W%" & SET /a "OY=%IY%*%FACTOR_H%"

if %IX% geq 640 if %IY% geq 400 goto :DO_IT
SET SCALE_STR=, scale=%OX%:%OY%:flags=neighbor

:DO_IT

if "%FC%" neq "N/A" (
	echo. &echo Input frame count: %FC%
	echo ---------------------------
)
call :METHOD_%1 %2 "%OUTFILE%"
del TMPpalette.png
echo. & echo ------------------------
echo Output file: %OUTFILE%
echo.
exit /b

::+++++++++++++::
:: SUBROUTINES ::
::+++++++++++++::

:GEN_RGBI_PAL
:::::::::::::
ffmpeg -hide_banner -loglevel error -stats -y -f lavfi -i color=c=black:s=16x16 -vf ^"^
	format=rgb24,^
	drawbox=01:c=0x0000AA, drawbox=02:c=0x00AA00, drawbox=03:c=0x00AAAA, drawbox=04:c=0xAA0000, drawbox=05:c=0xAA00AA,^
	drawbox=06:c=0xAA5500, drawbox=07:c=0xAAAAAA, drawbox=08:c=0x555555, drawbox=09:c=0x5555FF, drawbox=10:c=0x55FF55,^
	drawbox=11:c=0x55FFFF, drawbox=12:c=0xFF5555, drawbox=13:c=0xFF55FF, drawbox=14:c=0xFFFF55, drawbox=15:c=0xFFFFFF^
" -frames:v 1 TMPpalette.png
exit /b 0

:METHOD_4x1a
::::::::::::
call :GEN_RGBI_PAL
ffmpeg -hide_banner -loglevel error -stats -y -i %1 -i TMPpalette.png -filter_complex ^"^
	[0][1] paletteuse=dither=none %SCALE_STR%[do1];^
  [do1] colorkey=0x0000AA:0.01:0 [key1]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray                      [pat1]; [pat1][key1] overlay=shortest=1:format=rgb [do2];^
  [do2] colorkey=0x00AA00:0.01:0 [key2]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X,2)', format=gray   [pat2]; [pat2][key2] overlay=shortest=1:format=rgb [do3];^
  [do3] colorkey=0x00AAAA:0.01:0 [key3]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X,2)', format=gray   [pat3]; [pat3][key3] overlay=shortest=1:format=rgb [do4];^
  [do4] colorkey=0xAA0000:0.01:0 [key4]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+1,2)', format=gray [pat4]; [pat4][key4] overlay=shortest=1:format=rgb [do5];^
  [do5] colorkey=0xAA00AA:0.01:0 [key5]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+1,2)', format=gray [pat5]; [pat5][key5] overlay=shortest=1:format=rgb [do6];^
  [do6] colorkey=0xAA5500:0.01:0 [key6]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray                      [pat6]; [pat6][key6] overlay=shortest=1:format=rgb [do7];^
  [do7] colorkey=0xAAAAAA:0.01:0 [key7]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray                      [pat7]; [pat7][key7] overlay=shortest=1:format=rgb [do8];^
  [do8] colorkey=0x555555:0.01:0 [key8]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray                      [pat8]; [pat8][key8] overlay=shortest=1:format=rgb [do9];^
  [do9] colorkey=0x5555FF:0.01:0 [key9]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray                      [pat9]; [pat9][key9] overlay=shortest=1:format=rgb [doA];^
  [doA] colorkey=0x55FF55:0.01:0 [keyA]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X,2)', format=gray   [patA]; [patA][keyA] overlay=shortest=1:format=rgb [doB];^
  [doB] colorkey=0x55FFFF:0.01:0 [keyB]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X,2)', format=gray   [patB]; [patB][keyB] overlay=shortest=1:format=rgb [doC];^
  [doC] colorkey=0xFF5555:0.01:0 [keyC]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+1,2)', format=gray [patC]; [patC][keyC] overlay=shortest=1:format=rgb [doD];^
  [doD] colorkey=0xFF55FF:0.01:0 [keyD]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+1,2)', format=gray [patD]; [patD][keyD] overlay=shortest=1:format=rgb [doE];^
  [doE] colorkey=0xFFFF55:0.01:0 [keyE]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray                      [patE]; [patE][keyE] overlay=shortest=1:format=rgb, ^
eq=3" %OUTPARAMS% %2
exit /b 0

:METHOD_4x2a
::::::::::::
call :GEN_RGBI_PAL
ffmpeg -hide_banner -loglevel error -stats -y -i %1 -i TMPpalette.png -filter_complex ^"^
	[0][1] paletteuse=dither=none %SCALE_STR%[do1];^
  [do1] colorkey=0x0000AA:0.01:0 [key1]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray                               [pat1]; [pat1][key1] overlay=shortest=1:format=rgb [do2];^
  [do2] colorkey=0x00AA00:0.01:0 [key2]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2),2)', format=gray   [pat2]; [pat2][key2] overlay=shortest=1:format=rgb [do3];^
  [do3] colorkey=0x00AAAA:0.01:0 [key3]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2),2)', format=gray   [pat3]; [pat3][key3] overlay=shortest=1:format=rgb [do4];^
  [do4] colorkey=0xAA0000:0.01:0 [key4]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2)+1,2)', format=gray [pat4]; [pat4][key4] overlay=shortest=1:format=rgb [do5];^
  [do5] colorkey=0xAA00AA:0.01:0 [key5]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2)+1,2)', format=gray [pat5]; [pat5][key5] overlay=shortest=1:format=rgb [do6];^
  [do6] colorkey=0xAA5500:0.01:0 [key6]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray                               [pat6]; [pat6][key6] overlay=shortest=1:format=rgb [do7];^
  [do7] colorkey=0xAAAAAA:0.01:0 [key7]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray                               [pat7]; [pat7][key7] overlay=shortest=1:format=rgb [do8];^
  [do8] colorkey=0x555555:0.01:0 [key8]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray                               [pat8]; [pat8][key8] overlay=shortest=1:format=rgb [do9];^
  [do9] colorkey=0x5555FF:0.01:0 [key9]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray                               [pat9]; [pat9][key9] overlay=shortest=1:format=rgb [doA];^
  [doA] colorkey=0x55FF55:0.01:0 [keyA]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2),2)', format=gray   [patA]; [patA][keyA] overlay=shortest=1:format=rgb [doB];^
  [doB] colorkey=0x55FFFF:0.01:0 [keyB]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2),2)', format=gray   [patB]; [patB][keyB] overlay=shortest=1:format=rgb [doC];^
  [doC] colorkey=0xFF5555:0.01:0 [keyC]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2)+1,2)', format=gray [patC]; [patC][keyC] overlay=shortest=1:format=rgb [doD];^
  [doD] colorkey=0xFF55FF:0.01:0 [keyD]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2)+1,2)', format=gray [patD]; [patD][keyD] overlay=shortest=1:format=rgb [doE];^
  [doE] colorkey=0xFFFF55:0.01:0 [keyE]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray                               [patE]; [patE][keyE] overlay=shortest=1:format=rgb, ^
eq=3" %OUTPARAMS% %2
exit /b 0

:METHOD_4x1b
::::::::::::
call :GEN_RGBI_PAL
ffmpeg -hide_banner -loglevel error -stats -y -i %1 -i TMPpalette.png -filter_complex ^"^
	[0][1] paletteuse=dither=none %SCALE_STR%[do1];^
  [do1] colorkey=0x0000AA:0.01:0 [key1]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray                                                [pat1]; [pat1][key1] overlay=shortest=1:format=rgb [do2];^
  [do2] colorkey=0x00AA00:0.01:0 [key2]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(trunc(Y/2),2),2)', format=gray           [pat2]; [pat2][key2] overlay=shortest=1:format=rgb [do3];^
  [do3] colorkey=0x00AAAA:0.01:0 [key3]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(trunc(Y/2),2),2)', format=gray           [pat3]; [pat3][key3] overlay=shortest=1:format=rgb [do4];^
  [do4] colorkey=0xAA0000:0.01:0 [key4]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*eq(mod(X+1,4)+2*mod(trunc(Y/2),2),3)', format=gray [pat4]; [pat4][key4] overlay=shortest=1:format=rgb [do5];^
  [do5] colorkey=0xAA00AA:0.01:0 [key5]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*eq(mod(X+1,4)+2*mod(trunc(Y/2),2),3)', format=gray [pat5]; [pat5][key5] overlay=shortest=1:format=rgb [do6];^
  [do6] colorkey=0xAA5500:0.01:0 [key6]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray                                                [pat6]; [pat6][key6] overlay=shortest=1:format=rgb [do7];^
  [do7] colorkey=0xAAAAAA:0.01:0 [key7]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray                                                [pat7]; [pat7][key7] overlay=shortest=1:format=rgb [do8];^
  [do8] colorkey=0x555555:0.01:0 [key8]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray                                                [pat8]; [pat8][key8] overlay=shortest=1:format=rgb [do9];^
  [do9] colorkey=0x5555FF:0.01:0 [key9]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray                                                [pat9]; [pat9][key9] overlay=shortest=1:format=rgb [doA];^
  [doA] colorkey=0x55FF55:0.01:0 [keyA]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(trunc(Y/2),2),2)', format=gray           [patA]; [patA][keyA] overlay=shortest=1:format=rgb [doB];^
  [doB] colorkey=0x55FFFF:0.01:0 [keyB]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(trunc(Y/2),2),2)', format=gray           [patB]; [patB][keyB] overlay=shortest=1:format=rgb [doC];^
  [doC] colorkey=0xFF5555:0.01:0 [keyC]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*eq(mod(X+1,4)+2*mod(trunc(Y/2),2),3)', format=gray [patC]; [patC][keyC] overlay=shortest=1:format=rgb [doD];^
  [doD] colorkey=0xFF55FF:0.01:0 [keyD]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*eq(mod(X+1,4)+2*mod(trunc(Y/2),2),3)', format=gray [patD]; [patD][keyD] overlay=shortest=1:format=rgb [doE];^
  [doE] colorkey=0xFFFF55:0.01:0 [keyE]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray                                                [patE]; [patE][keyE] overlay=shortest=1:format=rgb, ^
eq=3" %OUTPARAMS% %2
exit /b 0

:METHOD_4x2b
::::::::::::
call :GEN_RGBI_PAL
ffmpeg -hide_banner -loglevel error -stats -y -i %1 -i TMPpalette.png -filter_complex ^"^
	[0][1] paletteuse=dither=none %SCALE_STR%[do1];^
  [do1] colorkey=0x0000AA:0.01:0 [key1]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray                                       [pat1]; [pat1][key1] overlay=shortest=1:format=rgb [do2];^
  [do2] colorkey=0x00AA00:0.01:0 [key2]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2),2)', format=gray           [pat2]; [pat2][key2] overlay=shortest=1:format=rgb [do3];^
  [do3] colorkey=0x00AAAA:0.01:0 [key3]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2),2)', format=gray           [pat3]; [pat3][key3] overlay=shortest=1:format=rgb [do4];^
  [do4] colorkey=0xAA0000:0.01:0 [key4]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*eq(mod(X+1,4)+2*mod(Y,2),3)', format=gray [pat4]; [pat4][key4] overlay=shortest=1:format=rgb [do5];^
  [do5] colorkey=0xAA00AA:0.01:0 [key5]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*eq(mod(X+1,4)+2*mod(Y,2),3)', format=gray [pat5]; [pat5][key5] overlay=shortest=1:format=rgb [do6];^
  [do6] colorkey=0xAA5500:0.01:0 [key6]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray                                       [pat6]; [pat6][key6] overlay=shortest=1:format=rgb [do7];^
  [do7] colorkey=0xAAAAAA:0.01:0 [key7]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray                                       [pat7]; [pat7][key7] overlay=shortest=1:format=rgb [do8];^
  [do8] colorkey=0x555555:0.01:0 [key8]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray                                       [pat8]; [pat8][key8] overlay=shortest=1:format=rgb [do9];^
  [do9] colorkey=0x5555FF:0.01:0 [key9]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray                                       [pat9]; [pat9][key9] overlay=shortest=1:format=rgb [doA];^
  [doA] colorkey=0x55FF55:0.01:0 [keyA]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2),2)', format=gray           [patA]; [patA][keyA] overlay=shortest=1:format=rgb [doB];^
  [doB] colorkey=0x55FFFF:0.01:0 [keyB]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2),2)', format=gray           [patB]; [patB][keyB] overlay=shortest=1:format=rgb [doC];^
  [doC] colorkey=0xFF5555:0.01:0 [keyC]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*eq(mod(X+1,4)+2*mod(Y,2),3)', format=gray [patC]; [patC][keyC] overlay=shortest=1:format=rgb [doD];^
  [doD] colorkey=0xFF55FF:0.01:0 [keyD]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*eq(mod(X+1,4)+2*mod(Y,2),3)', format=gray [patD]; [patD][keyD] overlay=shortest=1:format=rgb [doE];^
  [doE] colorkey=0xFFFF55:0.01:0 [keyE]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray                                       [patE]; [patE][keyE] overlay=shortest=1:format=rgb, ^
eq=3" %OUTPARAMS% %2
exit /b 0

:METHOD_8x2
::::::::::::
call :GEN_RGBI_PAL
ffmpeg -hide_banner -loglevel error -stats -y -i %1 -i TMPpalette.png -filter_complex ^"^
	[0][1] paletteuse=dither=none %SCALE_STR%[do1];^
  [do1] colorkey=0x0000AA:0.01:0 [key1]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*eq(mod(X,2)+2*mod(Y,2),3)',     format=gray [pat1]; [pat1][key1] overlay=shortest=1:format=rgb [do2];^
  [do2] colorkey=0x00AA00:0.01:0 [key2]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*(1-eq(mod(X,2)+2*mod(Y,2),0))', format=gray [pat2]; [pat2][key2] overlay=shortest=1:format=rgb [do3];^
  [do3] colorkey=0x00AAAA:0.01:0 [key3]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*(1-eq(mod(X,2)+2*mod(Y,2),3))', format=gray [pat3]; [pat3][key3] overlay=shortest=1:format=rgb [do4];^
  [do4] colorkey=0xAA0000:0.01:0 [key4]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X,2)',                      format=gray [pat4]; [pat4][key4] overlay=shortest=1:format=rgb [do5];^
  [do5] colorkey=0xAA00AA:0.01:0 [key5]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2)+1,2)',           format=gray [pat5]; [pat5][key5] overlay=shortest=1:format=rgb [do6];^
  [do6] colorkey=0xAA5500:0.01:0 [key6]; color=c=white:s=%OX%x%OY%:r=%IR%,                                        format=gray [pat6]; [pat6][key6] overlay=shortest=1:format=rgb [do7];^
  [do7] colorkey=0xAAAAAA:0.01:0 [key7]; color=c=white:s=%OX%x%OY%:r=%IR%,                                        format=gray [pat7]; [pat7][key7] overlay=shortest=1:format=rgb [do8];^
  [do8] colorkey=0x555555:0.01:0 [key8]; color=c=black:s=%OX%x%OY%:r=%IR%,                                        format=gray [pat8]; [pat8][key8] overlay=shortest=1:format=rgb [do9];^
  [do9] colorkey=0x5555FF:0.01:0 [key9]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*eq(mod(X,2)+2*mod(Y,2),3)',     format=gray [pat9]; [pat9][key9] overlay=shortest=1:format=rgb [doA];^
  [doA] colorkey=0x55FF55:0.01:0 [keyA]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*(1-eq(mod(X,2)+2*mod(Y,2),0))', format=gray [patA]; [patA][keyA] overlay=shortest=1:format=rgb [doB];^
  [doB] colorkey=0x55FFFF:0.01:0 [keyB]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*(1-eq(mod(X,2)+2*mod(Y,2),3))', format=gray [patB]; [patB][keyB] overlay=shortest=1:format=rgb [doC];^
  [doC] colorkey=0xFF5555:0.01:0 [keyC]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X,2)',                      format=gray [patC]; [patC][keyC] overlay=shortest=1:format=rgb [doD];^
  [doD] colorkey=0xFF55FF:0.01:0 [keyD]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2)+1,2)',           format=gray [patD]; [patD][keyD] overlay=shortest=1:format=rgb [doE];^
  [doE] colorkey=0xFFFF55:0.01:0 [keyE]; color=c=white:s=%OX%x%OY%:r=%IR%,                                        format=gray [patE]; [patE][keyE] overlay=shortest=1:format=rgb, ^
eq=3" %OUTPARAMS% %2
exit /b 0

:METHOD_16x2
::::::::::::
call :GEN_RGBI_PAL
ffmpeg -hide_banner -loglevel error -stats -y -i %1 -i TMPpalette.png -filter_complex ^"^
	[0][1] paletteuse=dither=none %SCALE_STR%[do1];^
  [do1] colorkey=0x0000AA:0.01:0 [key1]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*eq(mod(X,2)+2*mod(Y,2),3)',     format=gray [pat1]; [pat1][key1] overlay=shortest=1:format=rgb [do2];^
  [do2] colorkey=0x00AA00:0.01:0 [key2]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2)+1,2)',           format=gray [pat2]; [pat2][key2] overlay=shortest=1:format=rgb [do3];^
  [do3] colorkey=0x00AAAA:0.01:0 [key3]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+mod(Y,2),2)',             format=gray [pat3]; [pat3][key3] overlay=shortest=1:format=rgb [do4];^
  [do4] colorkey=0xAA0000:0.01:0 [key4]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*eq(mod(X,2)+2*mod(Y,2),1)',     format=gray [pat4]; [pat4][key4] overlay=shortest=1:format=rgb [do5];^
  [do5] colorkey=0xAA00AA:0.01:0 [key5]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*eq(mod(X,2)+2*mod(Y,2),0)',     format=gray [pat5]; [pat5][key5] overlay=shortest=1:format=rgb [do6];^
  [do6] colorkey=0xAA5500:0.01:0 [key6]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X,2)',                      format=gray [pat6]; [pat6][key6] overlay=shortest=1:format=rgb [do7];^
  [do7] colorkey=0xAAAAAA:0.01:0 [key7]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(Y,2)',                      format=gray [pat7]; [pat7][key7] overlay=shortest=1:format=rgb [do8];^
  [do8] colorkey=0x555555:0.01:0 [key8]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*eq(mod(X,2)+2*mod(Y,2),2)',     format=gray [pat8]; [pat8][key8] overlay=shortest=1:format=rgb [do9];^
  [do9] colorkey=0x5555FF:0.01:0 [key9]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(X+1,2)',                    format=gray [pat9]; [pat9][key9] overlay=shortest=1:format=rgb [doA];^
  [doA] colorkey=0x55FF55:0.01:0 [keyA]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*(1-eq(mod(X,2)+2*mod(Y,2),2))', format=gray [patA]; [patA][keyA] overlay=shortest=1:format=rgb [doB];^
  [doB] colorkey=0x55FFFF:0.01:0 [keyB]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*(1-eq(mod(X,2)+2*mod(Y,2),1))', format=gray [patB]; [patB][keyB] overlay=shortest=1:format=rgb [doC];^
  [doC] colorkey=0xFF5555:0.01:0 [keyC]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*mod(Y+1,2)',                    format=gray [patC]; [patC][keyC] overlay=shortest=1:format=rgb [doD];^
  [doD] colorkey=0xFF55FF:0.01:0 [keyD]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*(1-eq(mod(X,2)+2*mod(Y,2),0))', format=gray [patD]; [patD][keyD] overlay=shortest=1:format=rgb [doE];^
  [doE] colorkey=0xFFFF55:0.01:0 [keyE]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*(1-eq(mod(X,2)+2*mod(Y,2),3))', format=gray [patE]; [patE][keyE] overlay=shortest=1:format=rgb, ^
eq=3" %OUTPARAMS% %2
exit /b 0

:METHOD_t4x1
::::::::::::
call :GEN_RGBI_PAL
ffmpeg -hide_banner -loglevel error -stats -y -i %1 -i TMPpalette.png -filter_complex ^"^
	[0][1] paletteuse=dither=none %SCALE_STR%[do1];^
  [do1] colorkey=0x0000AA:0.01:0 [key1]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray   [pat1]; [pat1][key1] overlay=shortest=1:format=rgb [do2];^
  [do2] colorkey=0x00AA00:0.01:0 [key2]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0),mod(X+mod(trunc(Y/2),2),2), if(eq(mod(N,3),1),(1-eq(mod(X,2)+2*mod(trunc(Y/2),2),1)),(1-eq(mod(X,2)+2*mod(trunc(Y/2),2),2)) ))', format=gray [pat2]; [pat2][key2] overlay=shortest=1:format=rgb [do3];^
  [do3] colorkey=0x00AAAA:0.01:0 [key3]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0),mod(X+mod(trunc(Y/2),2),2), if(eq(mod(N,3),1),(1-eq(mod(X,2)+2*mod(trunc(Y/2),2),1)),(1-eq(mod(X,2)+2*mod(trunc(Y/2),2),2)) ))', format=gray [pat3]; [pat3][key3] overlay=shortest=1:format=rgb [do4];^
  [do4] colorkey=0xAA0000:0.01:0 [key4]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0), mod(X+mod(trunc(Y/2),2)+1,2), if(eq(mod(N,3),1), eq(mod(X,2)+2*mod(trunc(Y/2),2),1), eq(mod(X,2)+2*mod(trunc(Y/2),2),2) ))', format=gray [pat4]; [pat4][key4] overlay=shortest=1:format=rgb [do5];^
  [do5] colorkey=0xAA00AA:0.01:0 [key5]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0), mod(X+mod(trunc(Y/2),2)+1,2), if(eq(mod(N,3),1), eq(mod(X,2)+2*mod(trunc(Y/2),2),1), eq(mod(X,2)+2*mod(trunc(Y/2),2),2) ))', format=gray [pat5]; [pat5][key5] overlay=shortest=1:format=rgb [do6];^
  [do6] colorkey=0xAA5500:0.01:0 [key6]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray   [pat6]; [pat6][key6] overlay=shortest=1:format=rgb [do7];^
  [do7] colorkey=0xAAAAAA:0.01:0 [key7]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray   [pat7]; [pat7][key7] overlay=shortest=1:format=rgb [do8];^
  [do8] colorkey=0x555555:0.01:0 [key8]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray   [pat8]; [pat8][key8] overlay=shortest=1:format=rgb [do9];^
  [do9] colorkey=0x5555FF:0.01:0 [key9]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray   [pat9]; [pat9][key9] overlay=shortest=1:format=rgb [doA];^
  [doA] colorkey=0x55FF55:0.01:0 [keyA]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0),mod(X+mod(trunc(Y/2),2),2), if(eq(mod(N,3),1),(1-eq(mod(X,2)+2*mod(trunc(Y/2),2),1)),(1-eq(mod(X,2)+2*mod(trunc(Y/2),2),2)) ))', format=gray [patA]; [patA][keyA] overlay=shortest=1:format=rgb [doB];^
  [doB] colorkey=0x55FFFF:0.01:0 [keyB]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0),mod(X+mod(trunc(Y/2),2),2), if(eq(mod(N,3),1),(1-eq(mod(X,2)+2*mod(trunc(Y/2),2),1)),(1-eq(mod(X,2)+2*mod(trunc(Y/2),2),2)) ))', format=gray [patB]; [patB][keyB] overlay=shortest=1:format=rgb [doC];^
  [doC] colorkey=0xFF5555:0.01:0 [keyC]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0), mod(X+mod(trunc(Y/2),2)+1,2), if(eq(mod(N,3),1), eq(mod(X,2)+2*mod(trunc(Y/2),2),1), eq(mod(X,2)+2*mod(trunc(Y/2),2),2) ))', format=gray [patC]; [patC][keyC] overlay=shortest=1:format=rgb [doD];^
  [doD] colorkey=0xFF55FF:0.01:0 [keyD]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0), mod(X+mod(trunc(Y/2),2)+1,2), if(eq(mod(N,3),1), eq(mod(X,2)+2*mod(trunc(Y/2),2),1), eq(mod(X,2)+2*mod(trunc(Y/2),2),2) ))', format=gray [patD]; [patD][keyD] overlay=shortest=1:format=rgb [doE];^
  [doE] colorkey=0xFFFF55:0.01:0 [keyE]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray   [patE]; [patE][keyE] overlay=shortest=1:format=rgb, ^
eq=3" %OUTPARAMS% %2
exit /b 0

:METHOD_t4x2
::::::::::::
call :GEN_RGBI_PAL
ffmpeg -hide_banner -loglevel error -stats -y -i %1 -i TMPpalette.png -filter_complex ^"^
	[0][1] paletteuse=dither=none %SCALE_STR%[do1];^
  [do1] colorkey=0x0000AA:0.01:0 [key1]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray   [pat1]; [pat1][key1] overlay=shortest=1:format=rgb [do2];^
  [do2] colorkey=0x00AA00:0.01:0 [key2]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0),mod(X+mod(Y,2),2), if(eq(mod(N,3),1),(1-eq(mod(X,2)+2*mod(Y,2),1)),(1-eq(mod(X,2)+2*mod(Y,2),2)) ))', format=gray [pat2]; [pat2][key2] overlay=shortest=1:format=rgb [do3];^
  [do3] colorkey=0x00AAAA:0.01:0 [key3]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0),mod(X+mod(Y,2),2), if(eq(mod(N,3),1),(1-eq(mod(X,2)+2*mod(Y,2),1)),(1-eq(mod(X,2)+2*mod(Y,2),2)) ))', format=gray [pat3]; [pat3][key3] overlay=shortest=1:format=rgb [do4];^
  [do4] colorkey=0xAA0000:0.01:0 [key4]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0), mod(X+mod(Y,2)+1,2), if(eq(mod(N,3),1), eq(mod(X,2)+2*mod(Y,2),1), eq(mod(X,2)+2*mod(Y,2),2) ))', format=gray [pat4]; [pat4][key4] overlay=shortest=1:format=rgb [do5];^
  [do5] colorkey=0xAA00AA:0.01:0 [key5]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0), mod(X+mod(Y,2)+1,2), if(eq(mod(N,3),1), eq(mod(X,2)+2*mod(Y,2),1), eq(mod(X,2)+2*mod(Y,2),2) ))', format=gray [pat5]; [pat5][key5] overlay=shortest=1:format=rgb [do6];^
  [do6] colorkey=0xAA5500:0.01:0 [key6]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray   [pat6]; [pat6][key6] overlay=shortest=1:format=rgb [do7];^
  [do7] colorkey=0xAAAAAA:0.01:0 [key7]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray   [pat7]; [pat7][key7] overlay=shortest=1:format=rgb [do8];^
  [do8] colorkey=0x555555:0.01:0 [key8]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray   [pat8]; [pat8][key8] overlay=shortest=1:format=rgb [do9];^
  [do9] colorkey=0x5555FF:0.01:0 [key9]; color=c=black:s=%OX%x%OY%:r=%IR%,format=gray   [pat9]; [pat9][key9] overlay=shortest=1:format=rgb [doA];^
  [doA] colorkey=0x55FF55:0.01:0 [keyA]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0),mod(X+mod(Y,2),2), if(eq(mod(N,3),1),(1-eq(mod(X,2)+2*mod(Y,2),1)),(1-eq(mod(X,2)+2*mod(Y,2),2)) ))', format=gray [patA]; [patA][keyA] overlay=shortest=1:format=rgb [doB];^
  [doB] colorkey=0x55FFFF:0.01:0 [keyB]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0),mod(X+mod(Y,2),2), if(eq(mod(N,3),1),(1-eq(mod(X,2)+2*mod(Y,2),1)),(1-eq(mod(X,2)+2*mod(Y,2),2)) ))', format=gray [patB]; [patB][keyB] overlay=shortest=1:format=rgb [doC];^
  [doC] colorkey=0xFF5555:0.01:0 [keyC]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0), mod(X+mod(Y,2)+1,2), if(eq(mod(N,3),1), eq(mod(X,2)+2*mod(Y,2),1), eq(mod(X,2)+2*mod(Y,2),2) ))', format=gray [patC]; [patC][keyC] overlay=shortest=1:format=rgb [doD];^
  [doD] colorkey=0xFF55FF:0.01:0 [keyD]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(eq(mod(N,3),0), mod(X+mod(Y,2)+1,2), if(eq(mod(N,3),1), eq(mod(X,2)+2*mod(Y,2),1), eq(mod(X,2)+2*mod(Y,2),2) ))', format=gray [patD]; [patD][keyD] overlay=shortest=1:format=rgb [doE];^
  [doE] colorkey=0xFFFF55:0.01:0 [keyE]; color=c=white:s=%OX%x%OY%:r=%IR%,format=gray   [patE]; [patE][keyE] overlay=shortest=1:format=rgb, ^
eq=3" %OUTPARAMS% %2
exit /b 0

:METHOD_t8x2
:::::::::::::
call :GEN_RGBI_PAL
ffmpeg -hide_banner -loglevel error -stats -y -i %1 -i TMPpalette.png -filter_complex ^"^
	[0][1] paletteuse=dither=none %SCALE_STR%[do1];^
  [do1] colorkey=0x0000AA:0.01:0 [key1]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), eq(mod(X,2)+2*mod(Y,2),1)  , eq(mod(X,2)+2*mod(Y,2),2)   )', format=gray [pat1]; [pat1][key1] overlay=shortest=1:format=rgb [do2];^
  [do2] colorkey=0x00AA00:0.01:0 [key2]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), mod(X+mod(Y,2),2)          , 1-eq(mod(X,2)+2*mod(Y,2),1) )', format=gray [pat2]; [pat2][key2] overlay=shortest=1:format=rgb [do3];^
  [do3] colorkey=0x00AAAA:0.01:0 [key3]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), 1-eq(mod(X,2)+2*mod(Y,2),0), 1-eq(mod(X,2)+2*mod(Y,2),3) )', format=gray [pat3]; [pat3][key3] overlay=shortest=1:format=rgb [do4];^
  [do4] colorkey=0xAA0000:0.01:0 [key4]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), mod(X+mod(Y,2)+1,2)        , eq(mod(X,2)+2*mod(Y,2),1)   )', format=gray [pat4]; [pat4][key4] overlay=shortest=1:format=rgb [do5];^
  [do5] colorkey=0xAA00AA:0.01:0 [key5]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), mod(X+mod(Y,2),2)          , mod(X+mod(Y,2)+1,2)         )', format=gray [pat5]; [pat5][key5] overlay=shortest=1:format=rgb [do6];^
  [do6] colorkey=0xAA5500:0.01:0 [key6]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), 1                          , 1-eq(mod(X,2)+2*mod(Y,2),3) )', format=gray [pat6]; [pat6][key6] overlay=shortest=1:format=rgb [do7];^
  [do7] colorkey=0xAAAAAA:0.01:0 [key7]; color=c=white:s=%OX%x%OY%:r=%IR%,                                                                                  format=gray [pat7]; [pat7][key7] overlay=shortest=1:format=rgb [do8];^
  [do8] colorkey=0x555555:0.01:0 [key8]; color=c=black:s=%OX%x%OY%:r=%IR%,                                                                                  format=gray [pat8]; [pat8][key8] overlay=shortest=1:format=rgb [do9];^
  [do9] colorkey=0x5555FF:0.01:0 [key9]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), eq(mod(X,2)+2*mod(Y,2),1)  , eq(mod(X,2)+2*mod(Y,2),2)   )', format=gray [pat9]; [pat9][key9] overlay=shortest=1:format=rgb [doA];^
  [doA] colorkey=0x55FF55:0.01:0 [keyA]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), mod(X+mod(Y,2),2)          , 1-eq(mod(X,2)+2*mod(Y,2),1) )', format=gray [patA]; [patA][keyA] overlay=shortest=1:format=rgb [doB];^
  [doB] colorkey=0x55FFFF:0.01:0 [keyB]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), 1-eq(mod(X,2)+2*mod(Y,2),0), 1-eq(mod(X,2)+2*mod(Y,2),3) )', format=gray [patB]; [patB][keyB] overlay=shortest=1:format=rgb [doC];^
  [doC] colorkey=0xFF5555:0.01:0 [keyC]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), mod(X+mod(Y,2)+1,2)        , eq(mod(X,2)+2*mod(Y,2),1)   )', format=gray [patC]; [patC][keyC] overlay=shortest=1:format=rgb [doD];^
  [doD] colorkey=0xFF55FF:0.01:0 [keyD]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), mod(X+mod(Y,2),2)          , mod(X+mod(Y,2)+1,2)         )', format=gray [patD]; [patD][keyD] overlay=shortest=1:format=rgb [doE];^
  [doE] colorkey=0xFFFF55:0.01:0 [keyE]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), 1                          , 1-eq(mod(X,2)+2*mod(Y,2),3) )', format=gray [patE]; [patE][keyE] overlay=shortest=1:format=rgb, ^
eq=3" %OUTPARAMS% %2
exit /b 0

:METHOD_t16x2
:::::::::::::
call :GEN_RGBI_PAL
ffmpeg -hide_banner -loglevel error -stats -y -i %1 -i TMPpalette.png -filter_complex ^"^
	[0][1] paletteuse=dither=none %SCALE_STR%[do1];^
  [do1] colorkey=0x0000AA:0.01:0 [key1]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), 0                          , eq(mod(X,2)+2*mod(Y,2),3)   )', format=gray [pat1]; [pat1][key1] overlay=shortest=1:format=rgb [do2];^
  [do2] colorkey=0x00AA00:0.01:0 [key2]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), mod(X+mod(Y,2),2)          , mod(X+mod(Y,2)+1,2)         )', format=gray [pat2]; [pat2][key2] overlay=shortest=1:format=rgb [do3];^
  [do3] colorkey=0x00AAAA:0.01:0 [key3]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), mod(X+mod(Y,2)+1,2)        , mod(X+mod(Y,2),2)           )', format=gray [pat3]; [pat3][key3] overlay=shortest=1:format=rgb [do4];^
  [do4] colorkey=0xAA0000:0.01:0 [key4]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), eq(mod(X,2)+2*mod(Y,2),1)  , eq(mod(X,2)+2*mod(Y,2),2)   )', format=gray [pat4]; [pat4][key4] overlay=shortest=1:format=rgb [do5];^
  [do5] colorkey=0xAA00AA:0.01:0 [key5]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), eq(mod(X,2)+2*mod(Y,2),0)  , eq(mod(X,2)+2*mod(Y,2),3)   )', format=gray [pat5]; [pat5][key5] overlay=shortest=1:format=rgb [do6];^
  [do6] colorkey=0xAA5500:0.01:0 [key6]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), mod(X+mod(Y,2)+1,2)        , eq(mod(X,2)+2*mod(Y,2),1)   )', format=gray [pat6]; [pat6][key6] overlay=shortest=1:format=rgb [do7];^
  [do7] colorkey=0xAAAAAA:0.01:0 [key7]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), mod(X+mod(Y,2),2)          , 1-eq(mod(X,2)+2*mod(Y,2),1) )', format=gray [pat7]; [pat7][key7] overlay=shortest=1:format=rgb [do8];^
  [do8] colorkey=0x555555:0.01:0 [key8]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), eq(mod(X,2)+2*mod(Y,2),0)  , 0                           )', format=gray [pat8]; [pat8][key8] overlay=shortest=1:format=rgb [do9];^
  [do9] colorkey=0x5555FF:0.01:0 [key9]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), eq(mod(X,2)+2*mod(Y,2),3)  , mod(X+mod(Y,2),2)           )', format=gray [pat9]; [pat9][key9] overlay=shortest=1:format=rgb [doA];^
  [doA] colorkey=0x55FF55:0.01:0 [keyA]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), 1-eq(mod(X,2)+2*mod(Y,2),1), 1-eq(mod(X,2)+2*mod(Y,2),2) )', format=gray [patA]; [patA][keyA] overlay=shortest=1:format=rgb [doB];^
  [doB] colorkey=0x55FFFF:0.01:0 [keyB]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), 1-eq(mod(X,2)+2*mod(Y,2),0), 1                           )', format=gray [patB]; [patB][keyB] overlay=shortest=1:format=rgb [doC];^
  [doC] colorkey=0xFF5555:0.01:0 [keyC]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), 1-eq(mod(X,2)+2*mod(Y,2),3), mod(X+mod(Y,2)+1,2)         )', format=gray [patC]; [patC][keyC] overlay=shortest=1:format=rgb [doD];^
  [doD] colorkey=0xFF55FF:0.01:0 [keyD]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), 1-eq(mod(X,2)+2*mod(Y,2),0), 1-eq(mod(X,2)+2*mod(Y,2),3) )', format=gray [patD]; [patD][keyD] overlay=shortest=1:format=rgb [doE];^
  [doE] colorkey=0xFFFF55:0.01:0 [keyE]; nullsrc=s=%OX%x%OY%:r=%IR%, geq='lum=255*if(mod(N,2), 1                          , 1-eq(mod(X,2)+2*mod(Y,2),3) )', format=gray [patE]; [patE][keyE] overlay=shortest=1:format=rgb, ^
eq=3" %OUTPARAMS% %2
exit /b 0

