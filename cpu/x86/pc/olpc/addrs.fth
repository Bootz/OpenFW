\ See license at end of file
purpose: Establish address and I/O configuration definitions

[ifdef] use-meg0
h#  f0.0000 constant dropin-base
h#  08.0000 constant dropin-size
h#   0.4000 constant fw-pa
h#   f.c000 constant /fw-ram
[then]

[ifdef] rom-loaded
h# fff0.0000   constant rom-pa		\ Physical address of boot ROM
h#   10.0000   constant /rom		\ Size of boot ROM
rom-pa  h# 1.0000 +  constant dropin-base

h#    8.0000   constant dropin-size

dropin-base h# 20 +  constant ResetBase	\ Location of "reset" dropin in ROM

h#  ec0.0000 value    fw-pa     \ Changed in probemem.fth
h#   20.0000 constant /fw-ram
h#   40.0000 constant /fw-area
[then]

h#  80.0000 constant def-load-base      \ Convenient for initrd

\ The heap starts at RAMtop, which on this system is "fw-pa /fw-ram +"

\ We leave some memory in the /memory available list above the heap
\ for DMA allocation by the sound and USB driver.  OFW's normal memory
\ usage thus fits in one 4M page-directory mapping region.

h#  18.0000 constant heap-size

h# 300.0000 constant jffs2-dirent-base
h# 500.0000 constant jffs2-inode-base
h# 700.0000 constant dma-base
h# 900.0000 constant dma-size

h# f.0000 constant suspend-base      \ In the DOS hole
h# f.0008 constant resume-entry
h# f.1000 constant resume-data

\ If you change these, also change {g/l}xmsrs.fth and {g/l}xearly.fth
h# fd00.0000 constant fw-map-base
h# ffc0.0000 constant fw-map-limit

h# fd00.0000 constant fb-pci-base
h# fe00.0000 constant gp-pci-base
h# fe00.4000 constant dc-pci-base
h# fe00.8000 constant vp-pci-base
h# fe00.c000 constant vip-pci-base
h# fe01.0000 constant aes-pci-base
h# fe01.a000 constant ohci-pci-base
h# fe01.b000 constant ehci-pci-base
h# fe02.0000 constant nand-pci-base
h# fe02.4000 constant sd-pci-base
h# fe02.8000 constant camera-pci-base
h# fe02.c000 constant uoc-pci-base

h# e0000 constant rsdp-adr
h# e0040 constant rsdt-adr
h# e0080 constant fadt-adr
h# e0180 constant facs-adr
h# e01c0 constant dbgp-adr
h# fc000 constant dsdt-adr
h# fd000 constant ssdt-adr

\ Must agree with lxmsrs.fth
h# 3d constant cmos-alarm-day	\ Offset of day alarm in CMOS
h# 3e constant cmos-alarm-month	\ Offset of month alarm in CMOS
h# 32 constant cmos-century	\ Offset of century byte in CMOS

[ifdef] use-flash-nvram
h# d.0000 constant nvram-offset
[then]

h# e.0000 constant mfg-data-offset     \ Offset to manufacturing data area in SPI FLASH
h# f.0000 constant mfg-data-end-offset \ Offset to end of manufacturing data area in SPI FLASH
h# f.ffd0 constant crc-offset

fload ${BP}/cpu/x86/pc/virtaddr.fth
[ifndef] virtual-mode
h# ff80.0000 to fw-virt-base  \ Override the usual setting; we use an MSR to double-map some memory up high
h#   40.0000 to fw-virt-size
[then]


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
