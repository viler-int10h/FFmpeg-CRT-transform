# FFmpeg CRT Transform

Windows batch script for a configurable simulation of CRT monitors, given an input image/video.<br>
Requires a build of FFmpeg from **2021-01-27** or newer, due to a couple of bugfixes and new features.

Usage: ```ffcrt <config_file> <input_file> [output_file]```  
- ```input_file``` must be a valid image or video.  If ```output_file``` is omitted, the output will be named "(input_file)_OUT.(input_ext)".
- See the "presets" subdir for sample configuration files (comments for each setting included).

Write-ups, instructions, sample images:
1. **Color:** https://int10h.org/blog/2021/01/simulating-crt-monitors-ffmpeg-pt-1-color/
2. **Monochrome:** https://int10h.org/blog/2021/02/simulating-crt-monitors-ffmpeg-pt-2-monochrome/

Video samples:
1. **Color:** https://www.youtube.com/watch?v=oMibMBPSO-o
2. **Monochrome:** https://www.youtube.com/watch?v=DGAt3Y6Pxn4
