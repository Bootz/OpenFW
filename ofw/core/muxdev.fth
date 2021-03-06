\ See license at end of file
purpose: Multiplexor device collects input and distributes I/O

dev /packages
new-device
" mux" device-name

instance variable first-device
0 first-device !

struct
   /n field >link
   /n field >ihandle
   /n field >read
   /n field >write
   /n field >bell
constant /list-node

: read  ( adr len -- actual )
   first-device @
   begin  dup  while        ( adr len listnode )
      >r                                            ( adr len )
      r@ >read @  ?dup  if                          ( adr len xt )
         >r 2dup r>                                 ( adr len adr len xt )
         r@ >ihandle @  call-package                ( adr len actual )
         dup 0>  if  nip nip  r> drop  exit  then   ( adr len actual )
         drop                                       ( adr len )
      then                                          ( adr len )
      r> >link @            ( adr len listnode' )
   repeat                   ( adr len listnode )
   3drop -2
;
: write  ( adr len -- len )
   first-device @
   begin  dup  while        ( adr len listnode )
      >r                                    ( adr len )
      r@ >write @  ?dup  if                 ( adr len xt )
         >r 2dup r>                         ( adr len adr len xt )
         r@ >ihandle @  call-package  drop  ( adr len )
      then                                  ( adr len )
      r> >link @            ( adr len listnode' )
   repeat                   ( adr len listnode )
   drop nip
;
: ring-bell  ( -- )
   first-device @
   begin  dup  while        ( listnode )
      >r                               ( )
      r@ >bell @  ?dup  if             ( xt )
         r@ >ihandle @  call-package   ( )
      then                             ( )
      r> >link @            ( listnode' )
   repeat                   ( listnode )
   drop                
;

: show-devices  ( -- )
   first-device @
   begin  dup  while        ( listnode )
      >r                    ( )
      r@ >read  @  if  ." R"  else  ."  "  then
      r@ >write @  if  ." W"  else  ."  "  then
      space
      r@ >ihandle @  dup .  iselect  pwd  iunselect
      r> >link @            ( listnode' )
   repeat                   ( listnode )
   drop                     ( )
;

: add-device  ( ihandle -- )
   ?dup  0=  if  exit  then                      ( ihandle )

   /list-node alloc-mem >r                       ( ihandle r: listnode )

   dup r@ >ihandle !                             ( ihandle r: listnode )

   ihandle>phandle                               ( phandle r: listnode )

   " read"  third find-method  0=  if  0  then   ( phandle xt r: listnode )
   r@ >read !

   " write" third find-method  0=  if  0  then   ( phandle xt r: listnode )
   r@ >write !                                   ( phandle r: listnode )
   
   " ring-bell" third find-method  0=  if  0  then  ( phandle xt r: listnode )
   r@ >bell !                                    ( phandle r: listnode )
   
   " install-abort" third find-method  if        ( phandle xt r: listnode )
      r@ >ihandle @ call-package                 ( phandle r: listnode )
   then                                          ( phandle r: listnode )
   
   drop

   first-device @  r@ >link !                    ( r: listnode )
   r> first-device !                             ( )
;

: open  ( -- true )  true  ;

: close  ( -- )
   first-device @
   begin  dup  while                    ( listnode )
      >r                                ( r: listnode )
      " remove-abort"  r@ >ihandle @    ( $ ihandle r: listnode )
      ihandle>phandle  find-method  if  ( xt r: listnode )
         r> >ihandle @ call-package     ( r: listnode )
      then                              ( r: listnode )

      r@ >ihandle @  close-dev          ( r: listnode )
      r@ >link @                        ( next r: listnode )
      r> /list-node free-mem            ( next )
   repeat                               ( 0 )
   drop
;

: remove-device  ( ihandle -- )
   ?dup  0=  if  exit  then             ( ihandle )

   >r  first-device                     ( prev r: ihandle )

   begin  dup >link @  dup  while       ( prev this  r: ihandle )
      dup >ihandle @  r@ =  if          ( prev this  r: ihandle )

         " remove-abort"  r@ ihandle>phandle  find-method  if  ( prev this xt r: ihandle )
            r@ call-package             ( prev this  r: ihandle )
         then                           ( prev this  r: ihandle )
         r> drop                        ( prev this )

         dup >link @                    ( prev this next )
         rot >link !                    ( this )
         /list-node free-mem            ( )
         exit                           ( )
      then                              ( prev this r: ihandle )
      nip                               ( prev'     r: ihandle )
   repeat                               ( prev next r: ihandle )
   r> 3drop
;

: install-abort  ( -- )  ;
: remove-abort  ( -- )  ;

finish-device
device-end

0 value in-mux-ih
0 value out-mux-ih

: new-mux  ( -- ih )
   " "  " mux" $open-package
   dup 0= abort" Can't open mux package"
;

: add-mux   ( ih mux-ih -- )
   over  if  >r " add-device" r>  $call-method  else  2drop  then
;

: remove-mux  ( ih mux-ih -- )  >r " remove-device" r> $call-method  ;

: add-output  ( ih -- )  out-mux-ih add-mux  ;
: remove-output  ( ih -- )  out-mux-ih remove-mux  ;
: add-input  ( ih -- )  in-mux-ih add-mux  ;
: remove-input  ( ih -- )  in-mux-ih remove-mux  ;

: .mux  ( -- )
   in-mux-ih  if
      ." Input mux:" cr
      " show-devices" in-mux-ih $call-method
   then
   out-mux-ih  if
      ." Output mux:" cr
      " show-devices" out-mux-ih $call-method
   then
;

0 value fallback-in-ih
0 value fallback-out-ih

: install-mux-io  ( -- )
   new-mux to in-mux-ih
   new-mux to out-mux-ih

   fallback-device open-dev  dup to fallback-in-ih   add-input
   fallback-device open-dev  dup to fallback-out-ih  add-output

   screen open-dev to screen-ih
   screen-ih add-output

   keyboard open-dev to keyboard-ih
   keyboard-ih add-input

   in-mux-ih set-stdin  out-mux-ih set-stdout

   console-io
;

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
