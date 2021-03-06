purpose: Common code for fetching and building the WLAN microcode

\ The macro WLAN_VERSION, and optionally GET_WLAN, must be defined externally

\needs to-file       fload ${BP}/forth/lib/tofile.fth
\needs $md5sum-file  fload ${BP}/forth/lib/md5file.fth

" macro: WLAN_FILE ${WLAN_PREFIX}${WLAN_VERSION}.bin" expand$ eval

" ${GET_WLAN}" expand$  nip  [if]
   " ${GET_WLAN}" expand$ $sh
[else]
" rm -f sd8686.bin sd8686_helper.bin" expand$ $sh

" wget -q http://dev.laptop.org/pub/firmware/libertas/${WLAN_SUBDIR}${WLAN_FILE}" expand$ $sh
" wget -q http://dev.laptop.org/pub/firmware/libertas/${WLAN_SUBDIR}${WLAN_FILE}.md5" expand$ $sh

to-file md5string  "  "  " ${WLAN_FILE}" expand$ $md5sum-file
" cmp md5string ${WLAN_FILE}.md5" expand$ $sh

" cp ${WLAN_FILE} sd8686.bin" expand$ $sh

" wget -q http://dev.laptop.org/pub/firmware/libertas/sd8686_helper.bin" expand$ $sh
" wget -q http://dev.laptop.org/pub/firmware/libertas/sd8686_helper.bin.md5" expand$ $sh
to-file md5string  " *" " sd8686_helper.bin" $md5sum-file
" cmp md5string sd8686_helper.bin.md5" expand$ $sh

" rm ${WLAN_FILE}.md5 sd8686_helper.bin.md5 md5string" expand$ $sh
[then]

\ This forces the creation of a .log file, so we don't re-fetch
writing sd8686.version
" ${WLAN_VERSION}"n" expand$  ofd @ fputs
ofd @ fclose
