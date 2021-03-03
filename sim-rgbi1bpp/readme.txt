Sim-RGBI1bpp takes an image/video with RGBI (16-color IBM PC) content, and
uses FFmpeg to reduce the colors to 1-bit B&W.  The output can then be used as
FFcrt input.

Use this if you wish to simulate pseudo-grayscale "shading" on strictly 1-bit
monochrome displays.  This was supported by some uncommon video controllers on
older PCs/laptops, e.g. to emulate CGA RGBI on some LCD, electroluminescent,
or monochrome TTL monitors.  (For true grayscale, this is *not* needed.)

These hardware solutions simply replaced each RGBI color with a dot pattern
(static or dynamic) - quite different from what you'd get with common
dithering algorithms.  The target displays often had higher resolutions than
the emulated ones, so 200- scanline modes were doubled to 400.  If required,
this upscaling is done here as well.


USAGE: sim-rgbi1bpp <method> <input_file> [output_file]

  * <input_file> must be a valid image or video.  If output_file is omitted,
    the output will be named "(input_file)_(method).(input_ext)".
  
  * The input will be forced to the 16-color RGBI palette.  Width and/or
    height will be doubled, if they're under 640 and 400 respectively.

  * <method> should be one of the the below; 'readme.webp' shows what each
    method looks like for a sample input at 60fps.
    The following are static "bit- dither" methods, so they apply to both
    videos and still images:
    
    4x1a  - intended for CGA graphics modes; distinguishes 4 shades using a 
            simple bitwise shading pattern (0%-50%-50%-100%).  Similar to
            SIMCGA on a Hercules Graphics Card, or to shading mode 00b (bit-
            dithered) on the HP 100/200LX.
    
    4x2a  - like 4x1a, but exploits double-scanning by shifting the dot
            patterns on alternating scanlines, so the effect is not as rough.

    4x1b  - still intended for CGA graphics in 4 colors, but with a shading
            pattern of 0%-25%-50%-100%.  Similar to shading mode 11b (bit-
            dithered) on the HP 100/200LX.
            
    4x2b  - like 4x1b, but exploits double-scanning for a smoother appearance
            by doubling the vertical frequency of the dot patterns.  Probably
            the best-looking of the static 4-color options.

    8x2   - distinguishes 8 shades w/double scanning (intensity is ignored).
            Usable for text modes as well as CGA graphics modes.
    
    16x2  - distinguishes 16 shades w/double scanning.  Some of them will be
            difficult to tell apart, but this is more versatile for modes that
            use the full RGBI palette (PCjr/Tandy, low-res EGA, text modes).
    
    The following methods add a temporal component by modulating the dot
    patterns across frames (as with flickery, framerate-limited PWM).  That
    means they're video-only, and won't work with still images:
    
    t4x1  - intended for 4-color CGA graphics; uses a 3-frame cycle to
            simulate 4 shades of 0%-33%-67%-100%.  Like shading mode 11b
            (frame-based) on the HP 100/200LX.
            
    t4x2  - like t4x1, but exploits double-scanning for a smoother appearance
            by doubling the vertical frequency of the dot patterns.
       
    t8x2  - uses a 2-frame cycle to implement 8 shades w/double-scanning
            (intensity is ignored).  Usable for text modes as well as CGA
            graphics modes.

    t16x2 - uses a 2-frame cycle to implement 16 shades w/double-scanning.
            Better for modes that use the full RGBI palette.
     

A couple of things to keep in mind: 

  * None of these methods duplicate the *exact* implementation used by a
    specific type of video hardware, just the general principle.  If there's
    demand (and documentation!) for the precise methods used by a particular
    video controller, let me know.
    
  * The temporal modulation ('t') methods naturally introduce flicker, but in
    the real world this approach was mostly used on monochrome LCD panels,
    with enough pixel latency to make it less of a problem (the GRiDCASE
    1537's electroluminescent display is one exception).  When feeding the
    results to FFcrt, use the LATENCY config parameters to mimic that effect.


-VileR 2021-02
