#!/usr/bin/env bash
#
# Bootloader unlock for the ZTE Blade V40 Vita (P606F02 / UMS9230 / UFS).
#
# Linux port of the vendor's unlock_autopatch_9230.bat from the
# ums9230_universal_unlock_UFS package. Same commands, same order, same addresses.
#
# Run ONE step at a time. Re-enter BROM (USB 1782:4d00) before every step and keep
# VOL_UP + VOL_DOWN held while it runs. NEVER hold POWER -- that hard-resets the
# phone in the middle of the FDL2 upload and you get "connection closed".
#
#   1  back up splloader + uboot_b, then erase splloader (+ splloader_bak)
#   2  prepare the SPL image and the uboot backup locally (no phone involved)
#   3  write fdl2-cboot.bin to uboot_b    <-- phone cannot boot Android after this
#   4  run the unlock (fallback download). Ends in "connection closed" and that works.
#   5  read miscdata back and check the unlock token
#   6  restore uboot_b + splloader, write the wipe BCB   <-- always finish with this
#
# This script operates on the CURRENT directory, so run it from wherever you put
# spd_dump, chsize, gen_spl-unlock and the UFS package files (or set WORK=/that/dir).
#
set -u

WORK="${WORK:-$PWD}"
cd "$WORK" || { echo "cannot cd to $WORK" >&2; exit 1; }

SD="./spd_dump"
EXEC_ADDR=0x65015f08
FDL1_ADDR=0x65000800
FDL2_ADDR=0x9efffe00
WAIT="${WAIT:-600}"

say() { printf '\n#################################\n# %s\n#################################\n' "$*"; }

need_brom() {
  say "$1"
  echo " -> working dir : $WORK"
  echo " -> phone OFF, hold VOL_UP + VOL_DOWN, plug USB while holding"
  echo " -> waiting ${WAIT}s for USB 1782:4d00"
  echo " -> DO NOT hold POWER (tap it once if you need a reset)"
}

# sanity: everything the flow needs must be here
for f in spd_dump fdl1-dl.bin fdl2-dl.bin fdl2-cboot.bin; do
  [ -e "$f" ] || { echo "missing $f in $WORK" >&2; exit 1; }
done

case "${1:-}" in
  1)
    need_brom "STEP 1/6: back up SPL + uboot_b, then erase the SPL"
    $SD --wait "$WAIT" exec_addr $EXEC_ADDR \
        fdl fdl1-dl.bin $FDL1_ADDR fdl fdl2-dl.bin $FDL2_ADDR exec \
        r splloader r uboot e splloader e splloader_bak reset
    echo
    echo "--- backups (keep these, they are unique to your firmware revision):"
    ls -l splloader.bin uboot.bin 2>/dev/null
    [ -s splloader.bin ] && [ -s uboot.bin ] || \
      echo "!! backups missing or empty -- DO NOT continue until you have them" >&2
    ;;

  2)
    say "STEP 2/6: prepare the images locally (no phone needed)"
    [ -s uboot.bin ] || { echo "uboot.bin missing -- run step 1 first" >&2; exit 1; }
    [ -x ./gen_spl-unlock ] || { echo "gen_spl-unlock not built/next to this script" >&2; exit 1; }

    # vendor .bat:  gen_spl-unlock splloader.bin ; rename splloader.bin u-boot-spl-16k-sign.bin
    # gen_spl-unlock trims the dump to the size in its DHTB header, patches the
    # signcheck pattern if it finds one, and writes a patched copy to spl-unlock.bin.
    echo "--- gen_spl-unlock splloader.bin"
    ./gen_spl-unlock splloader.bin
    mv -f splloader.bin u-boot-spl-16k-sign.bin

    # vendor .bat:  chsize uboot.bin ; rename uboot.bin uboot_bak.bin
    echo "--- chsize uboot.bin"
    ./chsize uboot.bin
    mv -f uboot.bin uboot_bak.bin

    ls -l u-boot-spl-16k-sign.bin uboot_bak.bin spl-unlock.bin 2>/dev/null
    echo
    echo "note: on this phone gen_spl-unlock found no signcheck pattern in the UFS SPL,"
    echo "so spl-unlock.bin is byte-identical to the stock SPL. That is expected and fine:"
    echo "the unlock runs through the BROM custom_exec_no_verify_65015f08.bin path."
    ;;

  3)
    need_brom "STEP 3/6: write the unlock payload (fdl2-cboot.bin) to uboot_b"
    echo " -> after this the phone cannot boot Android. Step 6 undoes it."
    $SD --wait "$WAIT" exec_addr $EXEC_ADDR \
        fdl fdl1-dl.bin $FDL1_ADDR fdl fdl2-dl.bin $FDL2_ADDR exec \
        w uboot fdl2-cboot.bin reset
    ;;

  4)
    need_brom "STEP 4/6: run the unlock (fallback download)"
    echo " -> this is the actual exploit. It may need to be run twice."
    echo " -> it normally ENDS in 'connection closed' after EXEC FDL1. That is success,"
    echo "    not a failure: the phone reboots itself out of the exploit."
    $SD --wait "$WAIT" exec_addr $EXEC_ADDR fdl spl-unlock.bin $FDL1_ADDR
    echo
    echo "--- now run step 5 to check whether the token landed"
    ;;

  5)
    need_brom "STEP 5/6: read miscdata and check the unlock token"
    rm -f m.bin
    $SD --wait "$WAIT" exec_addr $EXEC_ADDR \
        fdl fdl1-dl.bin $FDL1_ADDR fdl fdl2-dl.bin $FDL2_ADDR exec \
        verbose 2 read_part miscdata 8192 64 m.bin reset
    echo
    echo "--- m.bin (64 bytes at miscdata+8192):"
    od -A x -t x1z m.bin 2>/dev/null | head -5
    echo
    if [ -s m.bin ] && od -An -tx1 m.bin | tr -d ' \n' | grep -q '[1-9a-f]'; then
      echo "==> token present -- 32-byte string + 16-byte hash + 16-byte hash = UNLOCKED"
    else
      echo "==> all zeros -- still locked. Re-enter BROM and run step 4 again."
    fi
    ;;

  6)
    need_brom "STEP 6/6: restore uboot_b + splloader, write the wipe BCB"
    echo " -> never skip this: leaving fdl2-cboot.bin in uboot_b bricks the boot"
    $SD --wait "$WAIT" exec_addr $EXEC_ADDR \
        fdl fdl1-dl.bin $FDL1_ADDR fdl fdl2-dl.bin $FDL2_ADDR exec \
        r boot w splloader u-boot-spl-16k-sign.bin w uboot uboot_bak.bin \
        w misc misc-wipe.bin reset
    echo
    echo "--- done. The phone will boot, show the orange unlock notice, and then"
    echo "    probably hang on the MyOS logo. That is the FBE problem: see"
    echo "    scripts/fix-post-unlock-hang.sh and the README."
    ;;

  *)
    echo "usage: sudo $0 {1|2|3|4|5|6}"
    echo "  run the steps in order; re-enter BROM before each one"
    exit 1
    ;;
esac
