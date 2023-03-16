# Simple Utilities for the ZX80)

## Amazing Adaptive Display (4K ROM, PAL)

A small machine code routine, by Ron Bissell and Ken Macdonald, which
allows you to pause a BASIC program for a defined period of time and
display the screen.  The routine was published in Tim Hartnell, "Making
The Most of Your ZX80", Computer Publications (1980).

The original listing has been updated slightly, to address potential errors, including some of those noted in Syntax ZX80 magazine, Vol. 2, N. 11, Page 2 -- notably: "In line 30, defining M$, change the 61st and 62nd hex digits (DE) to FE. Change the 75th and 76th digits (38) to (20). Change the 111th and 112th (EC) to FC."

The second change (38h to 20h) is for NTSC television signals, and has not been included in this version (though is easy to do).

I have also corrected the displacement for the final `jr` statement and adjusted some of the timings to match the ZX80 ROM routine.
