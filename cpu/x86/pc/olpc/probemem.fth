\ See license at end of file
purpose: Create memory node properties and lists

\ All RAM, including that assigned to the frame buffer
: total-ram  ( -- ramsize )
   h# 20000018 msr@ nip         ( msr.hi )
   dup d# 12 rshift  h# f and   ( msr.hi dimm0size-code )
   d# 22 + 1 swap lshift        ( msr.hi dimm0size )
   swap  dup h# f0000 and  h#  70000 =  if  ( dimm0size msr.hi )
      \ DIMM1 Not Installed
      drop                      ( total-size )
   else                         ( dimm0size msr.hi )
      d# 28 rshift  h# f and    ( dimm0size dimm1size-code )
      d# 22 + 1 swap lshift     ( dimm0size dimm1size )
      +                         ( total-size )
   then
;

\ Offset of frame buffer/display memory within the memory array
: fb-offset  ( -- offset )  h# 1808 msr@ drop h# 0fffff00 and  4 lshift  ;

\ Excludes RAM assigned to the frame buffer
: system-ram  ( -- extant avail )
   fb-offset
;

\ This may require adjustment if we steal additional SMI memory
: fbsize  ( -- n )  total-ram system-ram -  ;

dev /memory

\ Excludes RAM already used for page tables
: ram-limit  ( -- addr )  mem-info-pa la1+ l@  ;

: release-range  ( start-adr end-adr -- )  over - release  ;

: probe  ( -- )
   system-ram /fw-area - to fw-pa

   0 total-ram  reg   \ Report extant memory

   \ Put h# 10.0000-1f.ffff and 28.0000-memsize in pool,
   \ reserving 0..10.0000 for the firmware
   \ and 20.0000-27.ffff for the "flash"

\   h#  0.0000  h# 02.0000  release   \ A little bit of DMA space, we hope
\   h# 10.0000  h# 0f.ffff  release
\   h# 28.0000  h# 80.0000  release-range

\ Release some of the first meg, between the page tables and the DOS hole,
\ for use as DMA memory.
   mem-info-pa 2 la+ l@   h# a.0000  release-range  \ Below DOS hole

[ifdef] virtual-mode
   \ Release from 1M up to the amount of unallocated (so far) memory
   dropin-base ram-limit u<   if
      \ Except for the area that contains the dropins, if they are in RAM
      h# 10.0000  dropin-base  release-range
      dropin-base dropin-size +  ram-limit  release-range
   else
      h# 10.0000  ram-limit  release-range
   then
[else]
   h# 10.0000  system-ram  release-range

   fw-pa /fw-ram 0 claim  drop

   \ Account for the dropin area if it is in RAM
   dropin-base  system-ram  u<  if
      dropin-base dropin-size 0 claim
   then

   initial-heap  swap >physical swap  0 claim  drop
[then]
;

[ifndef] 8u.h
: 8u.h  ( n -- )  push-hex (.8) type pop-base  ;
[then]
: .chunk  ( adr len -- )  ." Testing memory at: " swap 8u.h ."  size " 8u.h cr  ;
: selftest  ( -- error? )
   " available" get-my-property  if  ." No available property" cr true exit  then
					 ( adr len )
   begin  ?dup  while
      2 decode-ints swap		 ( rem$ chunk$ )
      2dup .chunk			 ( rem$ chunk$ )
[ifdef] virtual-mode
      2dup over swap 3 mmu-map		 ( rem$ chunk$ )
[then]
      memory-test-suite  if  2drop true exit  then	 ( rem$ )
   repeat  drop
   false
;

device-end

also forth definitions
stand-init: Probing memory
   " probe" memory-node @ $call-method  
;
previous definitions

\ LICENSE_BEGIN
\ Copyright (c) 2006 FirmWorks
\ 
\ Permission is hereby granted, free of charge, to any person obtaining
\ a copy of this software and associated documentation files (the
\ "Software"), to deal in the Software without restriction, including
\ without limitation the rights to use, copy, modify, merge, publish,
\ distribute, sublicense, and/or sell copies of the Software, and to
\ permit persons to whom the Software is furnished to do so, subject to
\ the following conditions:
\ 
\ The above copyright notice and this permission notice shall be
\ included in all copies or substantial portions of the Software.
\ 
\ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
\ EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
\ MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
\ NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
\ LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
\ OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
\ WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
\
\ LICENSE_END
