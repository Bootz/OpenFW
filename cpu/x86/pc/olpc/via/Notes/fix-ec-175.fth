purpose: Recover EC FLASH on XO-1.75 using cable from XO-1.5

\ HOWTO USE THIS
\ Put this file and ecimage.bin (32768 bytes) on a USB stick, insert into XO-1.5
\ Connect 6-pin programming cable from XO-1.5 recovery driver port (J3) to
\ XO-1.75 A2 EDI "REFLASH EC HEADER" (J3)
\ Power on XO-1.5
\ Power on XO-1.75
\ ok fload u:\fixec175.fth
\ ok select /spi
\ ok recover-ec

dev /spi

: pio16mhz  ( -- )
   h# 01 h# 6c spi-b!    \ 33/(2*1) MHz
   h# 00 h# 6e spi-b!    \ No special clocking
   h# 08 h# 6d spi-b!    \ Dynamic clock, PIO mode, command posted write off   
;
: pio1.5mhz  ( -- )
   d# 11 h# 6c spi-b!    \ 33/(2*11) = 1.5 MHz
   h# 00 h# 6e spi-b!    \ No special clocking
   h# 08 h# 6d spi-b!    \ Dynamic clock, PIO mode, command posted write off   
;

: edi-go  ( -- )
   h# 802 spi-cmd!    ( )  \ Set go bit
   wait-done     ( )  \ Wait for done bit
   0 spi-cmd!    ( )  \ Clear go bit
   \ The go bit must be cleared before clear-done, otherwise clear-done will not work
   clear-done    ( )  \ Clear done bit
;

variable access-count  0 access-count !
variable out-ptr
variable #in-bytes
: spi-cs-on  ( -- )
\   access-count @ 1 =  if  pio8mhz  2 access-count !  then
\   access-count @ 0=  if  pio1.5mhz  1 access-count ! then
   8 out-ptr !   0 #in-bytes !
;
: spi-out  ( b -- )  out-ptr @ spi-b!  1 out-ptr +!  ;
: spi-cs-off  ( -- )
   out-ptr @ 8 -                ( #out-bytes )
   dup 0=  if  drop exit  then  ( #out-bytes )
   #in-bytes @ +  8 lshift  2 or  spi-cmd!
   wait-done
   0 spi-cmd!
   clear-done
;
: spi-in  ( -- b )
   1 #in-bytes !
   spi-cs-off
   out-ptr @ spi-b@
   8 out-ptr !
;

: edi-wait-b  ( -- b )
   4 #in-bytes !
   spi-cs-off
   out-ptr @  #in-bytes @  bounds  ?do
      i spi-b@ h# 50 =  if
         i 1+ spi-b@  unloop exit
      then
   loop
   true abort" Did not receive EDI data ready byte"
;

\ This cheats by assuming how long it takes for the data to return
\ It's interesting as an example of how fast the hardware can go.
: edi-really-fast-next-b@  ( -- b )
   h# 33 8 spi-b!
   h# 402 spi-cmd!  wait-done
   0 spi-cmd!
   clear-done
   b spi-b@
;


\ *** Start of verbatim inclusion of edi.fth

\ The following code depends on externally-privided low-level SPI bus
\ access primitives that are defined in "bbedi.fth" for the "native"
\ case (EC and CPU on the same machine).  They can also be implemented
\ for tethered programming from a different machine like an XO-1.5.
\
\ Low-level primitives:
\  spi-start  ( -- )      - Init SPI bus
\  spi-cs-on  ( -- )      - Assert SPI-bus CS#
\  spi-cs-off ( -- )      - Deassert SPI-bus CS#
\  spi-out    ( byte -- ) - Send byte
\  spi-in     ( -- byte ) - Receive byte

d# 128 constant /flash-page

: edi-cmd,adr  ( offset cmd -- )   \ Send command plus 3 address bytes
   spi-cs-on     ( offset cmd )
   spi-out       ( offset )
   lbsplit drop  spi-out spi-out spi-out  ( )
;
: edi-b!  ( byte offset -- )  \ Write byte to address inside EC chip
   h# 40 edi-cmd,adr spi-out spi-cs-off
;
[ifndef] edi-wait-b
: edi-wait-b  ( -- b )  \ Wait for and receive EC response byte
   d# 10 0  do 
      spi-in h# 50 =  if
         spi-in           ( b )
         spi-cs-off       ( b )
         unloop exit
      then
   loop
   spi-cs-off
   true abort" EDI byte in timeout"
;
[then]
: edi-b@  ( offset -- b )  \ Read byte from address inside EC chip
   h# 30 edi-cmd,adr  edi-wait-b
;
: edi-next-b@  ( -- b )  \ Read the next EC byte - auto-increment address
   spi-cs-on  h# 33 spi-out  edi-wait-b
;
: edi-disable  ( -- )  \ Turn off the EC EDI interface
   spi-cs-on
   h# f3 spi-out
   spi-in      ( b )
   spi-cs-off
   h# 8c <>  if
      ." Unexpected response from edi-disable" cr
   then 
;

0 [if]
: edi-w@  ( offset -- w )  \ Read 16-bit word from address inside EC chip
   dup 1+  edi-b@         ( offset b.low )
   swap edi-b@            ( b.low b.high )
   bwjoin
;
[else]
: edi-w@  ( offset -- w )  \ Read 16-bit word from address inside EC chip
   edi-b@ edi-next-b@ swap bwjoin
;
[then]
: reset-8051  ( -- )  \ Reset 8-5
   h# f010 edi-b@  1 or  h# f010 edi-b!
;
: unreset-8051  ( -- )  \ Reset 8-5
   h# f010 edi-b@  1 invert and  h# f010 edi-b!
;

\ 0 in bit 0 selects masked ROM as code source for 8051, 1 selects FLASH
\ The 8051 should be in reset mode when changing that bit.
: select-flash  ( -- )  \ Setup for access to FLASH inside the EC
   h# f011 edi-b@  1 or  h# f011 edi-b!
;

: probe-rdid  ( -- found? )  \ Verify that the EC is the one we think it is
   select-flash
   h# f01c ['] edi-w@ catch  if   ( x )
      drop false exit             ( -- false )
   then                           ( id )

   1 invert and  h# 3730 =
;

: wait-flash-busy  ( -- )  \ Wait for an erase/programming operation to complete
   get-msecs  h# 1000 +    ( limit )
   begin                   ( limit )
      h# fea0 edi-b@       ( limit b )
      h# 80 and  if        ( limit )
         drop exit
      then                 ( limit )
      dup get-msecs - 0<=  ( limit timeout? )
   until                   ( limit )
   drop
   true abort" EDI FLASH busy timeout"
;

: flash-cmd  ( b -- )  h# fea7 edi-b!  ;

: set-offset  ( offset -- )
   wbsplit                          ( offset-low offset-hi )
   h# fea9 edi-b!  h# fea8 edi-b!   ( )
;

: erase-page  ( offset -- )
   wait-flash-busy     ( offset )
   set-offset          ( )
   h# 20 flash-cmd     ( )
;

: erase-chip  ( -- )  wait-flash-busy  h# 60 flash-cmd  wait-flash-busy  ;

: send-byte  ( b offset -- )  set-offset  h# feaa edi-b!  2 flash-cmd  ;

: edi-program-page  ( adr offset -- )
   \ Clear HVPL
   wait-flash-busy  h# 80 flash-cmd  ( adr offset )

   \ Fill the page buffer
   swap  /flash-page  bounds  do  ( offset )
      i c@  over  send-byte       ( offset )
      1+                          ( offset' )
   loop                           ( offset )
   drop                           ( )

   \ Commit the buffer to the FLASH memory
   wait-flash-busy                ( )  \ Redundant wait?
   h# 70 flash-cmd                ( )
   wait-flash-busy                ( )
;
h# 7e80 constant ec-flags-offset
: edi-program-flash  ( adr len offset -- )
   cr                                          ( adr len offset )
   swap  0  ?do                                ( adr offset )
      (cr i .                                  ( adr offset )
      dup i + ec-flags-offset <>  if           ( adr offset )
         dup i + erase-page                    ( adr offset )
         over i +  over i +  edi-program-page  ( adr offset )
      then                                     ( adr offset )
   /flash-page +loop                           ( adr offset )
   2drop                                       ( )
;
: edi-read-flash  ( adr len offset -- )
   over 0=  if  3drop exit  then  ( adr len offset )
   edi-b@                         ( adr len byte )
   third c!                       ( adr len )
   1 /string  bounds  ?do         ( )
      edi-next-b@ i c!            ( )
   loop                           ( )
;
: trim@  ( offset -- b )
   set-offset
   h# 90 flash-cmd
   wait-flash-busy
   h# feab edi-b@
;
: trim-tune  ( -- )
\   firmware-id  0=  if
      \ Read trim data and write to register (for ENE macros)
      h# 100 trim@  h# 5a =  if
         \ Low Voltage Detect TRIM register
         h# f035 edi-b@               ( val )
         h# 1f invert and             ( val' )
         h# 101 trim@ h# 1f and  or   ( val' )
         h# f035 edi-b!               ( )

         \ Int Oscillator Control register - HKCOMOS32K
         h# f02b edi-b@               ( val )
         h# 0f invert and             ( val' )
         h# 102 trim@ h# 0f and  or   ( val' )
         h# f02b edi-b!               ( )
      then

      \ Read trim data and write to register (for HHNEC macros)
      h# 1ff trim@  0<>  if
         \ XBIMISC register - S[4:0]
         h# fea6 edi-b@               ( val )
         h# 1f invert and             ( val' )
         h# 1f0 trim@ h# 1f and  or   ( val' )
         h# fea6 edi-b!               ( )
         
         \ XBI Pump IP register - Pdac[3:0] | Ndac[3:0]
         h# 1f1 trim@ 4 lshift        ( val )
         h# 1f2 trim@ h# 0f and or    ( val' )
         h# fea3 edi-b!               ( )
         
         \ XBI Flash IP register - Bdac[3:0]
         h# fea4 edi-b@               ( val )
         h# 0f invert and             ( val' )
         h# 1f4 trim@ h# 0f and  or   ( val' )
         h# fea4 edi-b!               ( )
         
         \ XB VR IP register - Tctrim[3:0] | Abstrim[3:0]  (Vref temp coef and absolute value)
         h# 1f5 trim@ 4 lshift        ( val )
         h# 1f6 trim@ h# 0f and or    ( val' )
         h# fea5 edi-b!               ( )
         
         \ XBI Flash IP register - Itim[3:0] - Must be last
         h# fea4 edi-b@               ( val )
         h# f0 invert and             ( val' )
         h# 1f4 trim@ 4 lshift  or    ( val' )
         h# fea4 edi-b!               ( )
         
         3 us  \ Required after Itim[3:0] update

         \ XBI Embedded Flash Configuration register
         h# 10 h# fea0 edi-b!    \ Set FLASH clock

         h# fea0 edi-b@  h# d0  =  if
            ." Warning - XBIECFG is 0xd0" cr
         then
      then
\   then
;
: edi-open  ( -- )
   \ slow-edi-clock   \ Target speed between 1 and 2 MHz
   spi-start
   \ The first operation often fails so retry it
   ['] select-flash  catch  if  select-flash  then
   reset-8051
   trim-tune
   \ fast-edi-clock   \ Target speed up to 16 MHz
   \ reset
;
\ *** End of verbatim inclusion of edi.fth

: recover-ec  ( -- )
   pio1.5mhz
   edi-open
   " u:\ecimage.bin" $read-file abort" Read error"    ( adr len )
   erase-chip                                         ( adr len )
   2dup 0 edi-program-flash                           ( adr len )
   load-base 8000 0 edi-read-flash                    ( adr len )
   2dup load-base swap comp  if  ." Different"  then  ( adr len )
   free-mem                                           ( )
;

: read-ec  ( -- )
   pio1.5mhz
   edi-open
   load-base h# 8000 0 edi-read-flash                    ( )
   ." Writing EC image to u:\ecimage.bin"
   " u:\ecimage.bin" $new-file                           ( )
   load-base h# 8000 ofd @ fputs                         ( )
   ofd @ fclose                                          ( )
   ." Written" cr
;

dend


\ LICENSE_BEGIN
\ Copyright (c) 2009 FirmWorks
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
