# FFmpeg CRT Transform

Windows batch script for a configurable simulation of CRT monitors (and some older flat-panel displays too), given an input image/video.<br>
Requires a *git-master* build of FFmpeg from **2021-01-27** or newer, due to a couple of bugfixes and new features.

### Usage and Configuration

Syntax: ```ffcrt <config_file> <input_file> [output_file]```  

- ```input_file``` must be a valid image or video.  If ```output_file``` is omitted, the output will be named "(input_file)_(config_file).(input_ext)".

- For now, input is assumed to be 24-bit RGB (8 bits/channel), and this will be the output pixel format too.  This is planned to be configurable in the future.

- **How to configure**: all settings/parameters are commented in the sample configuration files, which you can find in the "presets" subdir.<br>**NOTE**: the included presets aren't guaranteed to accurately simulate any particular monitor model, but they may give you a good starting point!

### Write-ups, videos, sample images:

1. **Color CRTs:** https://int10h.org/blog/2021/01/simulating-crt-monitors-ffmpeg-pt-1-color/<br><br>
<a href="https://int10h.org/blog/2021/01/simulating-crt-monitors-ffmpeg-pt-1-color/"><img src="../images/r01s.png?raw=true" height="480"> </a>

2. **Monochrome CRTs:** https://int10h.org/blog/2021/02/simulating-crt-monitors-ffmpeg-pt-2-monochrome/<br><br>
<a href="https://int10h.org/blog/2021/02/simulating-crt-monitors-ffmpeg-pt-2-monochrome/"><img src="../images/r02s.png?raw=true" height="480"> </a>

2. **Flat-Panel Displays:** https://int10h.org/blog/2021/03/simulating-non-crt-monitors-ffmpeg-flat-panels/<br><br>
<a href="https://int10h.org/blog/2021/03/simulating-non-crt-monitors-ffmpeg-flat-panels/"><img src="../images/r03s.png?raw=true" height="480"> </a>
