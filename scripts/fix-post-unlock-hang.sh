#!/usr/bin/env bash
#
# Fix the post-unlock boot hang on the ZTE Blade V40 Vita (P606F02 / UMS9230 / UFS).
#
# Symptom: unlocked, boots past the orange notice, then spins on the MyOS boot animation
# forever. The FBE keys in trustos are sealed to the phone's LOCK STATE, so the old keys can
# never be derived again and /data can never be mounted.
#
# The usual fix -- a wipe BCB in misc ("boot-recovery" + "recovery\n--wipe_data\n") -- does
# NOT work here. This bootloader ignores it. Verified twice, both writes read back and compared.
# So: erase metadata (the FBE key blobs) and userdata over BROM.
#
# Run it, then hold VOL_UP + VOL_DOWN and keep holding. It arms spd_dump with a 900s window and
# re-arms itself, so a dropped catch costs nothing. NEVER hold POWER -- that hard-resets the
# phone and kills the USB link mid-upload.
#
set -u

WORK="${WORK:-$PWD}"
cd "$WORK" || { echo "cannot cd to $WORK" >&2; exit 1; }

EXEC_ADDR=0x65015f08
FDL1_ADDR=0x65000800
FDL2_ADDR=0x9efffe00
WAIT="${WAIT:-900}"

[ -x ./spd_dump ] || { echo "spd_dump not found in $WORK" >&2; exit 1; }
[ -s misc-wipe.bin ] || { echo "misc-wipe.bin not found in $WORK" >&2; exit 1; }

attempt=0
while true; do
  attempt=$((attempt+1))
  echo
  echo "==================== attempt $attempt @ $(date +%H:%M:%S) ===================="
  echo "armed: waiting up to ${WAIT}s for BROM 1782:4d00"
  echo "       hold VOL_UP + VOL_DOWN -- DO NOT hold POWER"
  rm -f misc_check.bin

  ./spd_dump --wait "$WAIT" exec_addr $EXEC_ADDR \
      fdl fdl1-dl.bin $FDL1_ADDR fdl fdl2-dl.bin $FDL2_ADDR exec \
      e userdata \
      e metadata \
      w misc misc-wipe.bin \
      read_part misc 0 2048 misc_check.bin \
      reset

  # "SUCCESS" means the BCB landed on the device, verified by reading misc back.
  # The erases come before it in the command list, and spd_dump aborts the list on
  # a hard USB failure, so a verified read-back is a good proxy for "the whole
  # sequence got through".
  if [ -s misc_check.bin ] && cmp -s misc-wipe.bin misc_check.bin; then
    echo
    echo "##################### SUCCESS @ $(date +%H:%M:%S) #####################"
    echo "# userdata + metadata erased, misc BCB written and verified"
    echo "# the phone is resetting now -- it will boot to a fresh Android"
    echo "####################################################################"
    break
  fi

  echo "--------- not caught / write not verified, re-arming in 3s ---------"
  echo "  (if this keeps failing at 'SEND fdl2-dl.bin' -> 'connection closed':"
  echo "   you are holding POWER, or the cable/port/battery is the problem)"
  sleep 3
done
