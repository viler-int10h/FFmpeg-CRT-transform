:: FFmpeg CRT transform script / VileR 2021
:: parameter 1 = config file
:: parameter 2 = input video/image
:: parameter 3 = output video/image

::+++++++++++++++++++++++++::
:: Check cmdline arguments ::
::+++++++++++++++++++++++++::

@echo off & setlocal EnableDelayedExpansion

if [%1] neq [] if [%2] neq [] goto :ARGS_OK
  echo. & echo FFmpeg CRT transform script / VileR 2021
	echo. & echo USAGE:  %~n0 ^<config_file^> ^<input_file^> [output_file] & echo.
	echo    input_file must be a valid image or video.  If output_file is omitted, the
	echo    output will be named "(input_file)_(config_file).(input_ext)"
	exit /b
:ARGS_OK
	if [%3] neq [] (
		set OUTFILE=%~f3
		set OUTEXT=%~x3
	) else (
		set OUTFILE=%~d2%~p2%~n2_%~n1%~x2
		set OUTEXT=%~x2
	)
	if exist %1 goto :FILE1_OK
	echo. & echo File not found: %1 & exit /b
:FILE1_OK
	if exist %2 goto :FILE2_OK
	echo. & echo File not found: %2 & exit /b
:FILE2_OK
	if [%OUTEXT%] neq [] goto :FILES_OK
	echo. & echo Output filename must have an extension: %OUTFILE% & exit /b
:FILES_OK

::++++++++++++++++++++++++++++++++++++++++++++++::
:: Find input dimensions and type (image/video) ::
::++++++++++++++++++++++++++++++++++++++++++++++::

set IX= & SET IY= & SET FC= 
for /f %%i IN ('ffprobe -hide_banner -loglevel quiet -select_streams v:0 -show_entries stream^=width^,height^,nb_frames %2 ^| find "="') do (
	set x=%%i
	if "!x:~0,6!"=="width=" SET IX=!x:~6!
	if "!x:~0,7!"=="height=" SET IY=!x:~7!
	if "!x:~0,10!"=="nb_frames=" SET FC=!x:~10!
)
if "%IX%" neq " " if "%IY%" neq " " if "%FC%" neq " " goto :ALL_OK
echo. & echo Couldn't get media info for input file "%2" (invalid image/video?) & exit /b

:ALL_OK

if "%FC%" == "N/A" (
	set TMP_EXT=png
	set TMP_OUTPARAMS= 
	set FIN_OUTPARAMS= 
) else (
	set TMP_EXT=avi
	set TMP_OUTPARAMS=-c:a copy -c:v libx264rgb -crf 0
	set FIN_OUTPARAMS=-c:a copy -c:v libx264rgb -crf 8
	set IS_VIDEO=1
)

::++++++++++::
:: Settings ::
::++++++++++::

:: Read config file / check for required external files:

FOR /F "eol=; tokens=1,2" %%i in (%1) do SET %%i=%%j
if not exist _%OVL_TYPE%.png (echo File not found: _%OVL_TYPE%.png & exit /b)

:: Set some shorthand vars and calculate stuff:

set /a "PX=%IX%*%PRESCALE_BY%*%PX_ASPECT%"
set /a "PY=%IY%*%PRESCALE_BY%"
set OX=round(%OY%*%OASPECT%)
set SWSFLAGS=accurate_rnd+full_chroma_int+full_chroma_inp
if /i "%VIGNETTE_ON%"=="yes" (SET VIGNETTE_STR=vignette=PI*%VIGNETTE_POWER%, ) else (SET VIGNETTE_STR=)
if /i "%V_PX_BLUR%"=="0" (SET VSIGMA=0.1) else (SET VSIGMA=%V_PX_BLUR%/100*%PRESCALE_BY%)

:: Curvature factors

if %BEZEL_CURVATURE% lss %CRT_CURVATURE% (set BEZEL_CURVATURE=%CRT_CURVATURE%)
if "%CRT_CURVATURE%" neq "0" (SET LENSC=, pad=iw+8:ih+8:4:4:black, lenscorrection=k1=%CRT_CURVATURE%:k2=%CRT_CURVATURE%:i=bilinear, crop=iw-8:ih-8)
if "%BEZEL_CURVATURE%" neq "0" (SET BZLENSC=, scale=iw*2:ih*2:flags=gauss, pad=iw+8:ih+8:4:4:black, lenscorrection=k1=%BEZEL_CURVATURE%:k2=%BEZEL_CURVATURE%:i=bilinear, crop=iw-8:ih-8, scale=iw/2:ih/2:flags=gauss)

:: Scan factor

if /i "%SCAN_FACTOR%"=="half" (
	SET SCAN_FACTOR=0.5
	SET /a SL_COUNT=IY/2
) else (
	if /i "%SCAN_FACTOR%"=="double" (
		SET SCAN_FACTOR=2
		SET /a SL_COUNT=IY*2
	) else (
		SET SCAN_FACTOR=1
		SET /a SL_COUNT=IY
	)
)

:: Handle monochrome settings
:: 'p7' is a special case (decay/latency are processed differently and require a couple more curve maps)

if /i "%MONITOR_COLOR%"=="white"      (set MONOCURVES= )
if /i "%MONITOR_COLOR%"=="paperwhite" (set MONOCURVES= & set PAPER_OVL=1)
if /i "%MONITOR_COLOR%"=="green1"     (set MONOCURVES=curves=r='0/0 .77/0 1/.45':g='0/0 .77/1 1/1':b='0/0 .77/.17 1/.73',)
if /i "%MONITOR_COLOR%"=="green2"     (set MONOCURVES=curves=r='0/0 .43/.16 .72/.30 1/.56':g='0/0 .51/.53 .82/1 1/1':b='0/0 .43/.16 .72/.30 1/.56',)
if /i "%MONITOR_COLOR%"=="bw-tv"      (set MONOCURVES=curves=r='0/0 .5/.49 1/1':g='0/0 .5/.49 1/1':b='0/0 .5/.62 1/1',)
if /i "%MONITOR_COLOR%"=="amber"      (set MONOCURVES=curves=r='0/0 .25/.45 .8/1 1/1':g='0/0 .25/.14 .8/.55 1/.8':b='0/0 .8/0 1/.29',)
SET "MONO_STR1= " & SET "MONO_STR2= "
if /i "%MONITOR_COLOR%" neq "rgb" (
	set OVL_ALPHA=0
	set MONO_STR1=format=gray16le,format=gbrp16le,
	set MONO_STR2=%MONOCURVES%
)
if /i "%MONITOR_COLOR%"=="p7" (
	set MONOCURVES_LAT=curves=r='0/0 .6/.31 1/.75':g='0/0 .25/.16 .75/.83 1/.94':b='0/0 .5/.76 1/.97'
	set MONOCURVES_DEC=curves=r='0/0 .5/.36 1/.86':g='0/0 .5/.52 1/.89':b='0/0 .5/.08 1/.13'
	set /a "DECAYDELAY=%LATENCY%/2"
	if defined IS_VIDEO (
		SET MONO_STR2=^
		split=4 [orig][a][b][c];^
		[a] tmix=%LATENCY%, !MONOCURVES_LAT! [lat];^
		[b] lagfun=%P_DECAY_FACTOR% [dec1]; [c] lagfun=%P_DECAY_FACTOR%*0.95 [dec2];^
		[dec2][dec1] blend=all_mode='lighten':all_opacity=0.3, !MONOCURVES_DEC!, setpts=PTS+^(!DECAYDELAY!/FR^)/TB [decay];^
		[lat][decay] blend=all_mode='lighten':all_opacity=%P_DECAY_ALPHA% [p7];^
		[orig][p7] blend=all_mode='screen',format=rgb24,
	) else (
	  SET MONO_STR2=^
	  split=3 [orig][a][b];^
		[a] !MONOCURVES_LAT! [lat];^
		[b] !MONOCURVES_DEC! [decay];^
		[lat][decay] blend=all_mode='lighten':all_opacity=%P_DECAY_ALPHA% [p7];^
		[orig][p7] blend=all_mode='screen',format=rgb24,
	)
)


@SET FFSTART=%time%
if "%FC%" neq "N/A" (
	echo. &echo Input frame count: %FC%
	echo ---------------------------
)

::+++++++++++++++++++++++++++++++++++++++++++++++++::
:: Create bezel with rounded corners and curvature ::
::+++++++++++++++++++++++++++++++++++++++++++++++++::

echo Bezel:
if "%CORNER_RADIUS%"=="0" (
	ffmpeg -hide_banner -loglevel error -stats -y^
	-f lavfi -i "color=c=#ffffff:s=%PX%x%PY%, format=rgb24 %BZLENSC%"^
	-filter_complex "[0]negate[alpha]; color=c=black:s=%PX%x%PY%[black]; [black][alpha] alphamerge" ^
	-frames:v 1 TMPbezel.png
) else (
	ffmpeg -hide_banner -loglevel error -stats -y^
	-f lavfi -i "color=s=1024x1024, format=gray, geq='lum=if(lte((X-W)^2+(Y-H)^2, 1024*1024), 255, 0)', scale=%CORNER_RADIUS%:%CORNER_RADIUS%:flags=lanczos"^
	-filter_complex ^"^
		color=c=black:s=%PX%x%PY%[black];^
		color=c=#ffffff:s=%PX%x%PY%, format=rgb24[bg];^
		[0] split=4 [tl][c2][c3][c4];^
		[c2] transpose=1 [tr];^
		[c3] transpose=3 [br];^
		[c4] transpose=2 [bl];^
		[bg][tl] overlay=0:0:format=rgb [p1];^
		[p1][tr] overlay=%PX%-%CORNER_RADIUS%:0:format=rgb [p2];^
		[p2][br] overlay=%PX%-%CORNER_RADIUS%:%PY%-%CORNER_RADIUS%:format=rgb [p3];^
		[p3][bl] overlay=x=0:y=%PY%-%CORNER_RADIUS%:format=rgb %BZLENSC%, negate, eq=1.2 [alpha];^
		[black][alpha] alphamerge^" ^
	-frames:v 1 TMPbezel.png
)
if errorlevel 1 exit /b

::+++++++++++++++++++++++++++++++++::
:: Create scanlines, add curvature ::
::+++++++++++++++++++++++++++++++++::

if /i "%SCANLINES_ON%"=="yes" (
	echo. & echo Scanlines:
	ffmpeg -hide_banner -loglevel error -stats -y -f lavfi ^
	-i nullsrc=s=1x100^
	-vf ^"^
		format=gray,^
		geq=lum='if^(lt^(Y,%PRESCALE_BY%/%SCAN_FACTOR%^), pow^(sin^(Y*PI/^(%PRESCALE_BY%/%SCAN_FACTOR%^)^), 1/%SL_WEIGHT%^)*255, 0^)',^
		crop=1:%PRESCALE_BY%/%SCAN_FACTOR%:0:0,^
		scale=%PX%:ih:flags=neighbor^"^
	-frames:v 1 TMPscanline.png

	ffmpeg -hide_banner -loglevel error -stats -y -loop 1 -framerate 1 -t %SL_COUNT% ^
	-i TMPscanline.png^
	-vf ^"^
		format=gray16le,^
		tile=layout=1x%SL_COUNT%,^
		scale=iw*3:ih*3:flags=gauss %LENSC%, scale=iw/3:ih/3:flags=gauss,^
		format=gray16le, format=rgb24^"^
	-frames:v 1 TMPscanlines.png
	if errorlevel 1 exit /b
)

::****************************************::
:: Tile shadowmask/overlay, add curvature ::
::****************************************::

echo. & echo Shadowmask overlay:
IF %OVL_ALPHA% gtr 0 goto :DO_MASK

	:: (if shadowmask alpha is 0, just make a blank canvas)
	ffmpeg -hide_banner -loglevel error -stats -y -f lavfi -i "color=c=#00000000:s=%PX%x%PY%,format=rgba" -frames:v 1 TMPshadowmask.png
	goto :MASK_DONE

:DO_MASK

	ffmpeg -hide_banner -loglevel error -stats -y -i _%OVL_TYPE%.png -vf ^"^
		lutrgb='r=gammaval(2.2):g=gammaval(2.2):b=gammaval(2.2)',^
		scale=round(iw*%OVL_SCALE%):round(ih*%OVL_SCALE%):flags=lanczos+%SWSFLAGS%^" ^
	TMPshadowmask1x.png
	
	set OVL_X= & SET OVL_Y= & for /f %%i IN ('ffprobe -hide_banner -loglevel quiet -show_entries stream^=width^,height TMPshadowmask1x.png ^| find "="') do (
		set w=%%i
		if "!w:~0,6!"=="width=" SET OVL_X=!w:~6!
		if "!w:~0,7!"=="height=" SET OVL_Y=!w:~7!
	)
	set /a "TILES_X=%PX%/%OVL_X%+1"
	set /a "TILES_Y=%PY%/%OVL_Y%+1"
	
	ffmpeg -hide_banner -loglevel error -stats -y -loop 1 -i TMPshadowmask1x.png -vf ^"^
		tile=layout=%TILES_X%x%TILES_Y%,^
		crop=%PX%:%PY%,^
		scale=iw*2:ih*2:flags=gauss %LENSC%,^
		scale=iw/2:ih/2:flags=bicubic,^
		lutrgb='r=gammaval(0.454545):g=gammaval(0.454545):b=gammaval(0.454545)'^" ^
	-frames:v 1 TMPshadowmask.png
	if errorlevel 1 exit /b
	goto :OVL_DONE

:MASK_DONE

if not defined PAPER_OVL goto :OVL_DONE

	:: Phosphor overlay for monochrome "paper white" only, doesn't need curvature
	set /a "PAPERX=%OY%*%OASPECT%*67/100"
	set /a "PAPERY=%OY%*67/100"
	
	echo. & echo Texture overlay:
	ffmpeg -y -hide_banner -f lavfi -i "color=c=#808080:s=%PAPERX%x%PAPERY%" ^
	-filter_complex ^"^
		noise=all_seed=5150:all_strength=100:all_flags=u, format=gray, ^
		lutrgb='r=(val-70)*255/115:g=(val-70)*255/115:b=(val-70)*255/115', ^
		format=rgb24, ^
		lutrgb='^
			r=if(between(val,0,101),207,if(between(val,102,203),253,251)):^
			g=if(between(val,0,101),238,if(between(val,102,203),225,204)):^
			b=if(between(val,0,101),255,if(between(val,102,203),157,255))',^
		format=gbrp16le,^
		lutrgb='r=gammaval(2.2):g=gammaval(2.2):b=gammaval(2.2)',^
		scale=%OX%:%OY%:flags=bilinear,^
		gblur=sigma=3:steps=6,^
		lutrgb='r=gammaval(0.454545):g=gammaval(0.454545):b=gammaval(0.454545)',^
		format=gbrp16le,format=rgb24^
	" -frames:v 1 TMPpaper.png

:OVL_DONE

::++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++::
:: Pre-process if needed: phosphor decay (video only), invert, pixel latency (video only) ::
::++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++::

SET SCALESRC=%2
SET "PREPROCESS=" & SET "VF_INVERT=" & SET "VF_DECAY="

if /i "%INVERT_INPUT%" == "yes" (SET PREPROCESS=1 & SET VF_PRE=negate)

if defined IS_VIDEO if %LATENCY% gtr 0 if /i "%MONITOR_COLOR%" neq "p7" (
	SET PREPROCESS=1
	if defined VF_PRE (SET VF_PRE=tmix=%LATENCY%, !VF_PRE!) else (SET VF_PRE=tmix=%LATENCY%)
)

if defined IS_VIDEO if %P_DECAY_FACTOR% gtr 0 if /i "%MONITOR_COLOR%" neq "p7" (
	SET PREPROCESS=1
	if defined VF_PRE (SET VF_PRE=, !VF_PRE!)
	SET VF_PRE=^
		[0] split [orig][2lag]; ^
		[2lag] lagfun=%P_DECAY_FACTOR% [lag]; ^
		[orig][lag] blend=all_mode='lighten':all_opacity=%P_DECAY_ALPHA% ^
		!VF_PRE!
)

if defined PREPROCESS (
	echo. & echo Step00 ^(preprocess^):
	ffmpeg -hide_banner -loglevel error -stats -y -i %2 -filter_complex ^"%VF_PRE%^" %TMP_OUTPARAMS% TMPstep00.%TMP_EXT%
	if errorlevel 1 exit /b
	SET SCALESRC=TMPstep00.%TMP_EXT%
)

::++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++::
:: Scale nearest neighbor, go 16bit/channel, apply gamma & pixel blur ::
::++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++::

echo. & echo Step01:
ffmpeg -hide_banner -loglevel error -stats -y -i %SCALESRC% -vf ^"^
	scale=iw*%PRESCALE_BY%:ih:flags=neighbor,^
	format=gbrp16le,^
	lutrgb='r=gammaval(2.2):g=gammaval(2.2):b=gammaval(2.2)',^
	scale=iw*%PX_ASPECT%:ih:flags=fast_bilinear,^
	scale=iw:ih*%PRESCALE_BY%:flags=neighbor,^
	gblur=sigma=%H_PX_BLUR%/100*%PRESCALE_BY%*%PX_ASPECT%:sigmaV=%VSIGMA%:steps=3^" ^
-c:v ffv1 -c:a copy TMPstep01.nut

if errorlevel 1 exit /b

::+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++::
:: Add halation, revert gamma, normalize blackpoint, revert bit depth, add curvature ::
::+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++::

:: (Real halation should come after scanlines & before shadowmask, but that turned out ugly)

echo. & echo Step02:
if /i "%HALATION_ON%"=="yes" (
	ffmpeg -hide_banner -loglevel error -stats -y -i TMPstep01.nut -filter_complex ^"^
		[0]split[a][b],^
		[a]gblur=sigma=%HALATION_RADIUS%:steps=6[h],^
		[b][h]blend=all_mode='lighten':all_opacity=%HALATION_ALPHA%,^
		lutrgb='r=gammaval^(0.454545^):g=gammaval^(0.454545^):b=gammaval^(0.454545^)',^
		lutrgb='r=val+^(%BLACKPOINT%*256*^(maxval-val^)/maxval^):g=val+^(%BLACKPOINT%*256*^(maxval-val^)/maxval^):b=val+^(%BLACKPOINT%*256*^(maxval-val^)/maxval^)',^
		format=rgb24^
		%LENSC%^"^
	%TMP_OUTPARAMS% TMPstep02.%TMP_EXT%
) else (
	ffmpeg -hide_banner -loglevel error -stats -y -i TMPstep01.nut -vf ^"^
		lutrgb='r=gammaval^(0.454545^):g=gammaval^(0.454545^):b=gammaval^(0.454545^)',^
		lutrgb='r=val+^(%BLACKPOINT%*256*^(maxval-val^)/maxval^):g=val+^(%BLACKPOINT%*256*^(maxval-val^)/maxval^):b=val+^(%BLACKPOINT%*256*^(maxval-val^)/maxval^)',^
		format=rgb24^
		%LENSC%^"^
	%TMP_OUTPARAMS% TMPstep02.%TMP_EXT%
)
if errorlevel 1 exit /b

::++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++::
:: Add bloom, scanlines, shadowmask, rounded corners + brightness fix ::
::++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++::

if /i "%SCANLINES_ON%"=="yes" (

	SET SL_INPUT=TMPscanlines.png
	if /i "%BLOOM_ON%"=="yes" (
		SET SL_INPUT=TMPbloom.%TMP_EXT%
		echo. & echo Step02-bloom:
		ffmpeg -hide_banner -loglevel error -stats -y^
		-i TMPscanlines.png -i TMPstep02.%TMP_EXT% -filter_complex ^"^
			[1]lutrgb='r=gammaval^(2.2^):g=gammaval^(2.2^):b=gammaval^(2.2^)', hue=s=0, lutrgb='r=gammaval^(0.454545^):g=gammaval^(0.454545^):b=gammaval^(0.454545^)'[g],^
			[g][0]blend=all_expr='if^(gte^(A,128^), ^(B+^(255-B^)*%BLOOM_POWER%*^(A-128^)/128^), B^)',^
			setsar=sar=1/1^"^
		%TMP_OUTPARAMS% !SL_INPUT!
	)
	echo. & echo Step03:
	ffmpeg -hide_banner -loglevel error -stats -y^
	-i TMPstep02.%TMP_EXT% -i !SL_INPUT! -i TMPshadowmask.png -i TMPbezel.png -filter_complex ^"^
		[0][1]blend=all_mode='multiply':all_opacity=%SL_ALPHA%[a],^
		[a][2]blend=all_mode='multiply':all_opacity=%OVL_ALPHA%[b],^
		[b][3]overlay=0:0:format=gbrp,^
		lutrgb='r=clip^(val*%BRIGHTEN%,0,255^):g=clip^(val*%BRIGHTEN%,0,255^):b=clip^(val*%BRIGHTEN%,0,255^)'^"^
	%TMP_OUTPARAMS% TMPstep03.%TMP_EXT%

) else (

	echo. & echo Step03:
	ffmpeg -hide_banner -loglevel error -stats -y^
	-i TMPstep02.%TMP_EXT% -i TMPshadowmask.png -i TMPbezel.png -filter_complex ^"^
		[0][1]blend=all_mode='multiply':all_opacity=%OVL_ALPHA%[b],^
		[b][2]overlay=0:0:format=gbrp,^
		lutrgb='r=clip^(val*%BRIGHTEN%,0,255^):g=clip^(val*%BRIGHTEN%,0,255^):b=clip^(val*%BRIGHTEN%,0,255^)'^"^
	%TMP_OUTPARAMS% TMPstep03.%TMP_EXT%
)

if errorlevel 1 exit /b

::++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++::
:: Detect crop area; crop, rescale, monochrome (if set), vignette, pad, set sar/dar ::
::++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++::

ffmpeg -hide_banner -y ^
	-f lavfi -i "color=c=#ffffff:s=%PX%x%PY%"	-i TMPbezel.png^
	-filter_complex "[0]format=rgb24 %LENSC%[crt]; [crt][1]overlay, cropdetect=limit=0:round=2"^
	-frames:v 3 -f null - 2>&1 ^
| find ^"crop^" > TMPcrop
if errorlevel 1 exit /b

for /f "tokens=*" %%a IN (TMPcrop) do set CROPTEMP=%%a
for %%a IN (%CROPTEMP%) do set CROP_STR=%%a

if defined PAPER_OVL (set PAPER_STR=[nop];movie=TMPpaper.png[paper];[nop][paper]blend=all_mode='multiply':eof_action='repeat')

echo. & echo Output:
ffmpeg -hide_banner -loglevel error -stats -y -i TMPstep03.%TMP_EXT% -filter_complex ^"^
	crop=%CROP_STR%,^
	format=gbrp16le,^
	lutrgb='r=gammaval(2.2):g=gammaval(2.2):b=gammaval(2.2)',^
	%MONO_STR1%^
	scale=w=%OX%-%OMARGIN%*2:h=%OY%-%OMARGIN%*2:force_original_aspect_ratio=decrease:flags=%OFILTER%+%SWSFLAGS%,^
	lutrgb='r=gammaval(0.454545):g=gammaval(0.454545):b=gammaval(0.454545)',^
	format=gbrp16le,^
	format=rgb24,^
	%MONO_STR2%^
	setsar=sar=1/1,^
	%VIGNETTE_STR%^
	pad=%OX%:%OY%:-1:-1:black^
	%PAPER_STR%^
" %FIN_OUTPARAMS% "%OUTFILE%"
if errorlevel 1 exit /b

::++++++++++::
:: Clean up ::
::++++++++++::

del TMPbezel.png;TMPscanline?.png;TMPshadow*.png;TMPpaper.png;TMPstep0?.*;TMPbloom.*;TMPcrop
@echo. & echo ------------------------
@echo Output file: %OUTFILE%
@echo Started:     %FFSTART%
@echo Finished:    %time%
@echo.
exit /b %ERRORLEVEL%
