purpose: Secure NAND updater
\ See license at end of file

\ Depends on words from security.fth and copynand.fth

: get-hex#  ( -- n )
   safe-parse-word
   push-hex $number pop-base  " Bad number" ?nand-abort
;

0 value partition-map-offset
0 value next-partition-start

0 value fs-partition#
d# 256 constant /partition-entry
: partition-adr  ( -- adr )  fs-partition# /partition-entry *  load-base +  ;
: max-nand-offset  ( -- n )  " usable-page-limit" $call-nand /nand-page *  ;

: add-partition  ( name$ #eblocks -- )
   fs-partition# " max#partitions" $call-nand >=  abort" Partition map overflow"

   -rot                                                ( #eblocks name$ )
   partition-adr /partition-entry erase                ( #eblocks name$ )
   d# 15 min  partition-adr swap move                  ( #eblocks )
   next-partition-start  partition-adr d# 16 + l!      ( #eblocks )

   dup -1 =  if                                        ( #eblocks )
      drop  max-nand-offset                            ( last-offset )
      next-partition-start -                           ( #bytes )
   else
      /nand-block *                                    ( #bytes )
   then                                                ( #bytes )

   dup partition-adr d# 24 +  l!             \ size    ( #bytes )

   next-partition-start + to next-partition-start      ( )
   next-partition-start max-nand-offset > abort" NAND size overflow"

   fs-partition# 1+ to fs-partition#
;
: start-partition-map  ( -- )
   load-base /nand-block h# ff fill
   0 to fs-partition#
\   0 to next-partition-start
   " partition-map-page#" $call-nand  /nand-page *  to partition-map-offset

   partition-map-offset to next-partition-start
   " FIS directory" 1 add-partition   
;
: write-partition-map  ( -- )
   partition-map-offset /nand-page /  dup " erase-block" $call-nand
   load-base  swap  nand-pages/block  " write-pages" $call-nand
   nand-pages/block <> abort" Can't write partition map"
   " read-partmap" $call-nand
;

0 value partition-page-offset
: map-eblock# ( block# -- block#' )  partition-page-offset +  ;

\ XXX need to check for overwriting existing partition map

vocabulary nand-commands
also nand-commands definitions

: set-partition:  ( "partitionid" -- )  \ partitionid is number or name
   safe-parse-word " $set-partition" $call-nand abort" Nonexistent partition#" 
;

: partitions:  ( "name" "#eblocks" ... -- )
   start-partition-map
   begin  parse-word  dup  while   ( name$ )
      get-hex#  add-partition      ( )
   repeat                          ( null$ )
   2drop
   write-partition-map
;

: data:  ( "filename" -- )
   safe-parse-word fn-buf place
   " ${DN}${PN}\${CN}${FN}" expand$  image-name-buf place
   open-img
;

: erase-all  ( -- )
   #nand-pages >eblock#  show-erasing
   ['] show-bad  ['] show-erased  ['] show-bbt-block " (wipe)" $call-nand
   #image-eblocks show-writing
;

: eblock: ( "eblock#" "hashname" "hash-of-128KiB" -- )
   get-hex#                                    ( eblock# )
   read-image-block
   load-base /nand-block    safe-parse-word    ( eblock# data$ hashname$ )
   crypto-hash                                 ( eblock# result$ )
   safe-parse-word hex-decode  " Malformed hash string" ?nand-abort
   $=  if                                      ( eblock# )
      drop 
   else                                        ( eblock# )
      ." Bad hash for eblock# " .x cr cr
      ." Your USB key may be bad.  Please try a different one." cr
      ." See http://wiki.laptop.org/go/Bad_hash" cr cr
      abort
   then                                        ( )

   load-base " copy-block" $call-nand          ( page# error? )
   " Error writing to NAND FLASH" ?nand-abort  ( page# )
   >eblock# show-written                       ( )
;

: bytes:  ( "eblock#" "page#" "offset" "length" "data" -- )
   get-hex#  get-hex#  2>r                 ( r: eblock# page# )
   get-hex#  get-hex#                      ( offset length r: eblock# page# )
   2dup +  h# 840 >= abort" Offset + length exceeds page + OOB size"
   safe-parse-word hex-decode              ( offset length data$ )
   rot over <> abort" Length mismatch"     ( offset data$ )
   r> r> map-eblock# nand-pages/block * +  ( offset data$ page#')
   -rot 2swap swap                         ( data$ page# offset )
   " pio-write-raw" $call-nand abort" NAND write error"
;

: cleanmarkers  ( -- )
   show-cleaning
   ['] show-clean " put-cleanmarkers" $call-nand
;   

: mark-pending:  ( "eblock#" -- )
   get-hex# map-eblock# nand-pages/block *   ( page# )
   " COMP" rot h# 838 
   " pio-write-raw" $call-nand abort" NAND write error"
;

: mark-complete:  ( "eblock#" -- )
   get-hex# map-eblock# nand-pages/block *
   " LETE" rot h# 83c
   " pio-write-raw" $call-nand abort" NAND write error"
;

previous definitions

: do-fs-update  ( img$ -- )
   tuck  load-base h# 100000 +  swap move  ( len )
   load-base h# 100000 + swap              ( adr len )
   open-nand                               ( adr len )

   ['] noop to show-progress               ( adr len )
   #nand-pages >eblock#  show-init         ( adr len )

\    clear-context  nand-commands
also nand-commands
   
   ['] include-buffer  catch  ?dup  if  nip nip  .error  security-failure  then

previous
\    only forth also definitions

   show-done
   close-nand-ihs
;

: fs-update-from-list  ( devlist$ -- )
   load-crypto  if  visible  ." Crytpo load failed" cr  show-sad  security-failure   then

   visible                            ( devlist$ )
   begin  dup  while                  ( rem$ )
      bl left-parse-string            ( rem$ dev$ )
      dn-buf place                    ( rem$ )

      null$ pn-buf place              ( rem$ )
      null$ cn-buf place              ( rem$ )
      " fs" bundle-present?  if       ( rem$ )
         " Filesystem image found - " ?lease-debug
         fskey$ to pubkey$            ( rem$ )
         img$  sig$  sha-valid?  if   ( rem$ )
            2drop                     ( )
            show-unlock               ( )
            img$ do-fs-update         ( )
            ." Rebooting in 10 seconds ..." cr
            d# 10,000 ms  bye
            exit
         then                         ( rem$ )
         show-lock                    ( rem$ )
      then                            ( rem$ )
   repeat                             ( rem$ )
   2drop
;
: update-devices  " disk: sd: http:\\172.18.0.1"  ;
: try-fs-update  ( -- )
   ." Searching for a NAND file system update image." cr
   " disk: sd:" fs-update-from-list
   ." Trying NANDblaster" cr
   ['] nandblaster catch  0=  if  exit  then
   " http:\\172.18.0.1" fs-update-from-list
;

: $update-nand  ( devspec$ -- )
   load-crypto abort" Can't load the crypto functions"
   null$ cn-buf place                           ( devspec$ )
   2dup                                         ( devspec$ devspec$ )
   [char] : right-split-string dn-buf place     ( devspec$ path+file$ )
   [char] \ right-split-string                  ( devspec$ file$ path$ )
   dup  if  1-  then  pn-buf place              ( devspec$ file$ )
   2drop                                        ( devspec$ )
   boot-read loaded do-fs-update                ( )
;
: update-nand  ( "devspec" -- )  safe-parse-word  $update-nand  ;

\ LICENSE_BEGIN
\ Copyright (c) 2007 FirmWorks
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
