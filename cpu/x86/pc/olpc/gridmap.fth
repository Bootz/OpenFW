
d# 24 d# 24 2value ulhc

8 constant glyph-w
8 constant glyph-h

9 constant grid-w
9 constant grid-h

d# 128 value #cols
\needs xy+ : xy+  ( x1 y1 x2 y2 -- x3 y3 )  rot + -rot  + swap  ;
\needs xy* : xy*  ( x y w h -- x*w y*h )  rot *  >r  * r>  ;

: do-fill  ( color x y w h -- )  " fill-rectangle" $call-screen  ;

\ States:  0:erased  1:bad  2:waiting for write  3:written

: >loc  ( eblock# -- x y )  #cols /mod  grid-w grid-h xy*  ulhc xy+  ;

: show-state  ( eblock# state -- )  swap >loc  glyph-w glyph-h  do-fill  ;

code map-color  ( color24 -- color565 )
   bx pop
   bx ax mov  3 # ax shr  h#   1f # ax and            \ Blue in correct place
   bx cx mov  5 # cx shr  h#  7e0 # cx and  cx ax or  \ Green and blue in place
              8 # bx shr  h# f800 # bx and  bx ax or  \ Red, green and blue in place
   ax push   
c;
: show-color  ( eblock# color32 -- )  map-color show-state  ;

dev screen  : erase-screen erase-screen ;  dend