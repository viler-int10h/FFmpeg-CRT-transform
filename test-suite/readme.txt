This directory contains a few images and (very short) videos for testing
FFcrt.  Each one has an associated configuration file with appropriate
settings.  The idea is:

- To let you test any changes you make to the FFcrt script, by getting
  "before" and "after" result sets which you can compare to check for
  regressions
  
- More generally, to give some examples of the kind of input that FFcrt is
  designed to work with, along with some nice sample settings

The first time you run the "run-tests" script, it'll call FFcrt for each input
file and suffix the result filename with "-out".  On subsequent runs, existing
"-out" files will be suffixed "-OLD", and new ones will be generated; any
existing "-OLD" files are deleted first.  This should always preserve two
result sets, "before" (??-out-OLD.*) and "after" (??-out.*).

-VileR 2021-03