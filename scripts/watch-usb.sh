#!/usr/bin/env bash
#
# Watch Unisoc devices come and go on USB. Prints a line every time the USB topology
# changes, so you can see the phone land in BROM (1782:4d00) or fall back to its
# normal bootloader/Android USB (19d2:135x).
#
#   1782:4d00  <- BootROM download mode (what the exploit needs)
#   1782:d001  <- seen briefly while the SoC boots
#   19d2:1353  <- phone's normal USB gadget (bootloader/Android, sometimes UMS)
#
# Run it in one terminal, keep holding VOL_UP + VOL_DOWN, and watch.
#
set -u

last=""
while true; do
  cur=""
  for d in /sys/bus/usb/devices/*/; do
    v=$(cat "$d/idVendor" 2>/dev/null) || continue
    p=$(cat "$d/idProduct" 2>/dev/null)
    [ -z "$v" ] && continue
    cur="$cur $(basename "$d")=$v:$p"
  done
  if [ "$cur" != "$last" ]; then
    echo "[$(date +%H:%M:%S)]$cur"
    case "$cur" in
      *1782:4d00*) echo "        ^^ BROM IS UP -- unisoc download mode" ;;
    esac
    last="$cur"
  fi
  sleep 0.5
done