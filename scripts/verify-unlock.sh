#!/usr/bin/env bash
#
# Check whether the bootloader on the ZTE Blade V40 Vita (P606F02) is unlocked.
# Needs the phone booted in Android with adb working.
#
set -u

if ! command -v adb >/dev/null; then
  echo "adb not found in PATH" >&2
  exit 1
fi

echo "=== adb devices ==="
adb devices -l

echo
echo "=== bootloader state ==="
locked=$(adb shell getprop ro.boot.flash.locked 2>/dev/null | tr -d '\r')
vbstate=$(adb shell getprop ro.boot.verifiedbootstate 2>/dev/null | tr -d '\r')
vmstate=$(adb shell getprop ro.boot.vbmeta.device_state 2>/dev/null | tr -d '\r')
slot=$(adb shell getprop ro.boot.slot_suffix 2>/dev/null | tr -d '\r')
model=$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')
release=$(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
display=$(adb shell getprop ro.build.display.id 2>/dev/null | tr -d '\r')
patch=$(adb shell getprop ro.build.version.security_patch 2>/dev/null | tr -d '\r')

printf '%-30s %s\n' ro.boot.flash.locked "$locked"
printf '%-30s %s\n' ro.boot.verifiedbootstate "$vbstate"
printf '%-30s %s\n' ro.boot.vbmeta.device_state "$vmstate"
printf '%-30s %s\n' ro.boot.slot_suffix "$slot"
printf '%-30s %s\n' ro.product.model "$model"
printf '%-30s %s\n' ro.build.version.release "$release"
printf '%-30s %s\n' ro.build.display.id "$display"
printf '%-30s %s\n' ro.build.version.security_patch "$patch"

echo
if [ "$locked" = "0" ] && [ "$vmstate" = "unlocked" ]; then
  echo "==> UNLOCKED (flash.locked=0, vbmeta.device_state=unlocked, verifiedbootstate=$vbstate)"
  echo "    these come from the bootloader via the kernel cmdline, so they are authoritative."
elif [ "$locked" = "1" ]; then
  echo "==> LOCKED"
else
  echo "==> inconclusive: is the phone booted in Android with adb authorised?"
fi

echo
echo "=== /data (a freshly wiped phone shows very little used) ==="
adb shell df -h /data 2>/dev/null

echo
echo "note: 'fastboot getvar unlocked' is useless on this device -- the Unisoc U-Boot"
echo "      fastboot gadget returns empty values for everything."

# if the adb device is not visible at all, there is nothing to read
