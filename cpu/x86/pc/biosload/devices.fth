\ See license at end of file
purpose: Load device drivers according to configuration definitions

fload ${BP}/cpu/x86/pc/isaio.fth

fload ${BP}/dev/pci/configm1.fth	\ Generic PCI configuration access

0 0  " "  " /"  begin-package
   fload ${BP}/cpu/x86/pc/mappci.fth	\ Map PCI to root
   fload ${BP}/dev/pcibus.fth		\ Generic PCI bus package

[ifdef] addresses-assigned
   0 0  " addresses-preassigned" property
0 [if]
   \ Suppress PCI address assignment; use the addresses the BIOS assigned
   patch false true master-probe
   patch noop assign-all-addresses prober
   patch noop clear-addresses populate-device-node
   patch noop clear-addresses populate-device-node
   patch noop temp-assign-addresses find-fcode?
   patch 2drop my-w! populate-device-node
   : or-w!  ( bitmask reg# -- )  tuck my-w@  or  swap my-w!  ;
   patch or-w! my-w! find-fcode?
   patch 2drop my-w! find-fcode?
[then]
[then]

   fload ${BP}/cpu/x86/pc/biosload/pcinode.fth	\ System-specific words for PCI
end-package
stand-init: PCI host bridge
   " /pci" " init" execute-device-method drop
;

fload ${BP}/cpu/x86/pc/biosload/i945.fth	\ Intel 945 hacks

fload ${BP}/dev/pciprobe.fth		\ Generic PCI probing

[ifdef] use-timestamp-counter
\ Use the CPU chip's Time Stamp Counter for timing; it does just what we want
fload ${BP}/cpu/x86/tsc.fth
[then]

[ifdef] use-ega
0 0 " " " /" begin-package
   fload ${BP}/dev/egatext.fth
end-package
devalias screen /ega-text
[then]

[ifdef] use-root-isa
0 0  " "  " /" begin-package
   fload ${BP}/cpu/x86/pc/isabus.fth	\ ISA Bus Bridge under root node
end-package
[then]

[ifndef] use-timestamp-counter
fload ${BP}/cpu/x86/pc/getms.fth
[then]

[ifdef] use-pci-isa

[ifdef] addresses-assigned
\ This must precede isamisc.fth in the load file, to execute it first
fload ${BP}/cpu/x86/pc/moveisa.fth
[then]

0 0  " 0"  " /pci" begin-package
   fload ${BP}/dev/pci/isa.fth		\ ISA bus bridge under PCI node
   fload ${BP}/dev/pci/isamisc.fth
end-package
[then]

[ifdef] use-pc87560
0 0  " 5,1"  " /pci" begin-package	\ ISA bus bridge
   fload ${BP}/dev/pc87560.fth	\ SouthBridge ISA bus bridge
end-package
[then]

dev /interrupt-controller
h# 20 to vector-base0
h# 28 to vector-base1
device-end

[ifdef] use-pc87317
fload ${BP}/dev/pc87317.fth		\ National PC87317 superIO
[then]

[ifdef] via-demo
fload ${BP}/cpu/x86/pc/olpc/via/smbus.fth	\ SMBUS driver
fload ${BP}/cpu/x86/pc/olpc/via/dumpvia.fth	\ Config register dumps
[then]

[ifdef] olpc
\ Create the top-level device node to access the entire boot FLASH device
0 0  " fff00000"  " /" begin-package
   " flash" device-name

   h# 10.0000 value /device
   h# 10.0000 constant /device-phys
   my-address my-space /device-phys reg
   fload ${BP}/dev/flashpkg.fth
   fload ${BP}/dev/flashwrite.fth
end-package
[then]

0 0  dropin-base <# u#s u#>  " /" begin-package
   " flash" device-name

   dropin-size
   dup value /device
   constant /device-phys
   my-address my-space /device-phys reg
\   fload ${BP}/cpu/x86/pc/flashpkg.fth
   fload ${BP}/dev/flashpkg.fth
end-package

[ifdef] notdef
\ Create a node below the top-level FLASH node to accessing the portion
\ containing the dropin modules
0 0   0 0    " flash" begin-package
   " dropins" device-name

   dropin-size constant /device
   fload ${BP}/dev/subrange.fth
end-package
[then]

\ devalias dropins /dropins
devalias dropins /flash

\ Create a pseudo-device that presents the dropin modules as a filesystem.
fload ${BP}/ofw/fs/dropinfs.fth

\ This devalias lets us say, for example, "dir rom:"
devalias rom     /dropin-fs

fload ${BP}/cpu/x86/forthint.fth	\ Low-level interrupt handling code
fload ${BP}/dev/isa/irq.fth		\ ISA interrupt dispatcher
fload ${BP}/cpu/x86/pc/isatick.fth		\ Use ISA timer as the alarm tick timer

[ifdef] resident-packages
support-package: 16550
fload ${BP}/dev/16550pkg/16550.fth  \ Serial port support package
end-support-package
[then]

fload ${BP}/dev/pci/isaall.fth
devalias seriala /isa/serial@i3f8
devalias com1 /isa/serial@i3f8:115200
devalias serialb /isa/serial@i2f8
devalias com2 /isa/serial@i2f8
devalias a /isa/fdc/disk@0
devalias b /isa/fdc/disk@1
devalias mouse /isa/8042/mouse

[ifdef] use-timestamp-counter
fload ${BP}/cpu/x86/pc/tsccal1.fth
[then]

[ifdef] use-ega
dev /8042      patch false ctlr-selftest open   device-end
[then]

[ifdef] use-16552
0 0  " i3a0"  " /isa" begin-package
   3 encode-int  0 encode-int encode+    " interrupts" property
   fload ${BP}/dev/16550pkg/ns16550p.fth
   fload ${BP}/dev/16550pkg/isa-int.fth
end-package

0 0  " i3a8"  " /isa" begin-package
   4 encode-int  0 encode-int encode+    " interrupts" property
   fload ${BP}/dev/16550pkg/ns16550p.fth
   fload ${BP}/dev/16550pkg/isa-int.fth
end-package

devalias seriald /isa/serial@i3a0	: seriald " seriald"  ;
devalias serialc /isa/serial@i3a8	: serialc " serialc"  ;
[then]

0 0  " i70"  " /isa" begin-package   	\ Real-time clock node
   fload ${BP}/dev/ds1385r.fth
   8 encode-int  0 encode-int encode+    " interrupts" property
   2 encode-int " device#" property
end-package
stand-init: RTC
   " /rtc" open-dev  clock-node !
;

fload ${BP}/cpu/x86/pc/cpunode.fth

[ifndef] serial-console
fload ${BP}/ofw/core/bailout.fth
stand-init:  Keyboard overrides
   ?bailout
;
[then]

fload ${BP}/ofw/core/countdwn.fth	\ Startup countdown
fload ${BP}/forth/lib/pattern.fth	\ Text string pattern matching
fload ${BP}/forth/lib/tofile.fth	\ to-file and append-to-file
\ XXX remove the OS file commands from tools.dic
fload ${BP}/ofw/core/filecmds.fth	\ File commands: dir, del, ren, etc.

[ifdef] pseudo-nvram
fload ${BP}/cpu/x86/pc/biosload/filenv.fth
dev /file-nvram
: fd-nv-file  ( -- )  " a:\nvram.dat"  ;
: hd-nv-file  ( -- )  " c:\nvram.dat"  ;
: usb-nv-file  ( -- )  " u:\nvram.dat"  ;
[ifdef] virtualbox-loaded
   ' fd-nv-file to nv-file
[else]
   ' usb-nv-file to nv-file
[then]
device-end
: reread-config-vars  ( -- )
   config-valid?  if  exit  then
   ['] init-config-vars catch drop
;
stand-init: Pseudo-NVRAM
   " /file-nvram" open-dev  to nvram-node
   nvram-node 0=  if
      ." The configuration EEPROM is not working" cr
   then
   reread-config-vars
;
[then]

[ifdef] use-vga
0 0  " i3c0" " /isa" begin-package
  " vga" name
  my-address my-space h# 20 reg
  fload ${BP}/dev/video/common/defer.fth	\ Defered words
  fload ${BP}/dev/video/common/graphics.fth	\ Graphics and color routines
  fload ${BP}/dev/video/controlr/vga.fth	\ Controller code
  use-vga
  fload ${BP}/dev/video/common/init.fth		\ Init code
  fload ${BP}/dev/video/common/display.fth	\ High level interface code
  fload ${BP}/dev/video/common/textmode.fth	\ VGA text mode
  : (map-io-regs)  h# ffff0000 to io-base  ;
  ' (map-io-regs) to map-io-regs
end-package
[then]

[ifdef] use-vesa
0 0  " "  " /" begin-package
   " display" name
   " vesa" " compatible" string-property
   fload ${BP}/dev/video/controlr/vesalfb.fth
end-package
devalias screen /display		\ Explicit, because it's not probed
[then]

[ifdef] use-pineview
0 0  " 2,0"  " /pci" begin-package
   " display" name
   fload ${BP}/dev/intel/graphics/pineview.fth
end-package
devalias screen /pci/display@2,0	\ Explicit, because it's not probed
[then]

[ifdef] use-ct65550
0 0  " i3b0" " /isa" begin-package
   fload ${BP}/dev/ct6555x/loadpkg.fth	\ Video driver
end-package
devalias screen /isa/display		\ Explicit, because it's not probed
[then]

[ifdef] use-es1887
fload ${BP}/dev/isa/es1887.fth		\ Sound chip driver
devalias audio /isa/sound
fload ${BP}/cpu/x86/decnc/sound.fth	\ Startup sound
[then]

[ifdef] use-isa-ide
0 0  " i1f0" " /isa" begin-package
   fload ${BP}/dev/ide/isaintf.fth
   fload ${BP}/dev/ide/generic.fth
   2 to max#drives
   fload ${BP}/dev/ide/onelevel.fth
end-package
\ One-level IDE
[then]

\ Create the alias unless it already exists
: $?devalias  ( alias$ value$ -- )
   2over  not-alias?  if  $devalias exit  then  ( alias$ value$ alias$ )
   2drop 4drop
;

: report-pci-fb  ( -- )
   " /pci/display" locate-device 0=  if  ( phandle )
      " open" rot find-method  if        ( xt )
         drop
         " screen" " /pci/display"  $devalias
      then
   then
;

: report-disk  ( -- )
   " /scsi" locate-device  0=  if
      drop
      " scsi" " /scsi"        $devalias
      " disk" " /scsi/disk@0" $devalias
      " c"    " /scsi/disk@0" $devalias
      " d"    " /scsi/disk@1" $devalias
      " e"    " /scsi/disk@2" $devalias
      " f"    " /scsi/disk@3" $devalias
      exit
   then
   " /pci-ide" locate-device  0=  if
      drop
      " disk" " /pci-ide/ide@0/disk@0" $devalias
      " c"    " /pci-ide/ide@0/disk@0" $devalias
      " d"    " /pci-ide/ide@0/disk@1" $devalias
      " e"    " /pci-ide/ide@1/disk@0" $devalias
      " f"    " /pci-ide/ide@1/disk@1" $devalias
      exit
   then
   " /ide" locate-device  0=  if
      drop
      " disk" " /ide@1f0/disk@0" $devalias
      " c"    " /ide@1f0/disk@0" $devalias
      " d"    " /ide@170/disk@1" $devalias
      " e"    " /ide@1f0/disk@0" $devalias
      " f"    " /ide@170/disk@2" $devalias
      exit
   then
;

fload ${BP}/cpu/x86/inoutstr.fth	\ Multiple I/O port read/write
[ifdef] use-isa-ide
dev /ide
' pseudo-dma-in  ' pseudo-dma-out  set-blk-w
device-end
[then]

[ifdef] use-ne2000
0 0  " i300" " /isa" begin-package
   start-module
      fload ${BP}/dev/ne2000/ne2000.fth	\ Ethernet Driver
   end-module
end-package
[then]

[ifdef] use-usb-debug-port
fload ${BP}/dev/usb2/device/debugport.fth	\ ISA COM port driver
[else]
fload ${BP}/dev/isa/diaguart.fth	\ ISA COM port driver
[then]

fload ${BP}/forth/lib/sysuart.fth	\ Use UART for key and emit
[ifndef] no-ega-startup-messages
fload ${BP}/cpu/x86/pc/egauart.fth	\ Output also to EGA
[then]

0 value keyboard-ih
0 value screen-ih

fload ${BP}/ofw/core/muxdev.fth		\ I/O collection/distribution device

fload ${BP}/cpu/x86/pc/reset.fth	\ reset-all

[ifdef] olpc
\ true constant lx?			\ 
h# fff0.0000   constant rom-pa		\ Physical address of boot ROM
[ifdef] geode
fload ${BP}/dev/geode/acpi.fth           \ Power management
[then]
fload ${BP}/dev/olpc/kb3700/ecspi.fth      \ EC chip SPI FLASH access

warning @ warning off
: stand-init-io  stand-init-io  h# fff0.0000 to flash-base  ;
warning !

fload ${BP}/dev/olpc/kb3700/ecserial.fth   \ Serial access to EC chip

fload ${BP}/dev/olpc/kb3700/ecio.fth       \ I/O space access to EC chip

\ fload ${BP}/cpu/x86/pc/olpc/boardrev.fth   \ Board revision decoding
fload ${BP}/cpu/x86/pc/olpc/mfgdata.fth      \ Manufacturing data
fload ${BP}/cpu/x86/pc/olpc/mfgtree.fth      \ Manufacturing data in device tree
fload ${BP}/dev/olpc/kb3700/battery.fth      \ Battery status reports

fload ${BP}/dev/olpc/spiflash/spiflash.fth   \ SPI FLASH programming
fload ${BP}/dev/olpc/spiflash/spiui.fth      \ User interface for SPI FLASH programming
fload ${BP}/dev/olpc/spiflash/recover.fth    \ XO-to-XO SPI FLASH recovery
fload ${BP}/cpu/x86/pc/olpc/iflash.fth       \ Insyde BIOS replacement tools
: ofw-fw-filename$  " u:\olpcofw.rom"  ;
' ofw-fw-filename$ to fw-filename$
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
