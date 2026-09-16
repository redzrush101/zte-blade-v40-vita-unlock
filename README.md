# ZTE Blade V40 Vita bootloader unlock — P606F02 / Unisoc UMS9230 / UFS

Linux notes and scripts for unlocking with
[CVE-2022-38694](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader). Done on my
`EEA_P606F02` running MyOS11.0.13_8045_EEA.

**Two things decide whether this works and neither is written down anywhere:**

1. **Never hold POWER while flashing.** ~10 s of POWER = PMIC hard reset = the USB link dies
   mid-upload (`SEND fdl2-dl.bin` → `connection closed`). Hold **VOL_UP + VOL_DOWN** only.
   Tap POWER once if you need a reset.
2. **The phone hangs on the MyOS logo after unlocking, and the usual `misc` wipe BCB does
   nothing** — this bootloader ignores it. Erase `userdata` + `metadata` over BROM instead.

## Device

| | |
|---|---|
| Model | ZTE Blade V40 Vita — `ZTE 8045` / `EEA_P606F02` |
| SoC / storage | Unisoc **UMS9230** / **UFS** |
| Package | `ums9230_universal_unlock_UFS`. UFS `fdl2-*.bin` are 934088 bytes; the eMMC ones are ~1 MB. Wrong loaders can wipe the phone |
| OS / slot | Android 11, MyOS11.0.13 · slot **`_b`** |

## Build the tools

```sh
git clone --recursive https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
cd CVE-2022-38694_unlock_bootloader
gcc chsize.c -o chsize
gcc gen_spl-unlock.c -o gen_spl-unlock
cd spreadtrum_flash && make      # spd_dump
```

Put `chsize`, `gen_spl-unlock`, `spd_dump` and the four files from the UFS package
(`fdl1-dl.bin`, `fdl2-dl.bin`, `fdl2-cboot.bin`, `misc-wipe.bin`) in one working directory.
The scripts below run against that directory.

## Enter BROM

Phone off → hold **VOL_UP + VOL_DOWN** → plug USB → keep holding. You want USB **`1782:4d00`**:

```sh
for d in /sys/bus/usb/devices/*/; do
  [ "$(cat $d/idVendor 2>/dev/null)" = 1782 ] && echo "BROM: $(basename $d)"
done
```

`19d2:135x` is the phone's normal USB, not BROM. A boot-looping phone is fine — every reset
re-runs the BootROM, which re-samples the keys at reset.

## Unlock

One step at a time, re-entering BROM before each. Keep the volume keys held while it runs.

```sh
cd /path/to/working-dir
sudo /path/to/repo/scripts/unlock.sh 1   # back up SPL + uboot_b, erase SPL (won't boot after this)
sudo /path/to/repo/scripts/unlock.sh 2   # prep images locally, phone not needed
sudo /path/to/repo/scripts/unlock.sh 3   # write fdl2-cboot.bin to uboot_b
sudo /path/to/repo/scripts/unlock.sh 4   # the unlock. ends in "connection closed" = success
sudo /path/to/repo/scripts/unlock.sh 5   # read miscdata @8192: 64 zeros = locked, string+2 hashes = unlocked
sudo /path/to/repo/scripts/unlock.sh 6   # restore uboot/SPL. never skip this
```

Step 4 ends in `EXEC FDL1` → timeout → `connection closed`. That is the unlock working, not
failing. If step 5 shows zeros, run step 4 again.

Step 3 leaves the phone unable to boot Android (the payload isn't a real bootloader) — step 6
puts your stock `uboot_bak.bin` back. Don't stop in between.

## Stuck on the MyOS logo

FBE keys in trustos are sealed to the lock state, so `/data` can never mount. Wiping is
mandatory:

```sh
sudo /path/to/repo/scripts/fix-post-unlock-hang.sh
```

Hold the volume keys, it re-arms itself until it catches BROM. Erases `userdata` + `metadata`,
writes the BCB, resets. Caught on the third try and took under a minute.

## Verify

```sh
adb shell getprop ro.boot.flash.locked          # 0
adb shell getprop ro.boot.verifiedbootstate     # orange
adb shell getprop ro.boot.vbmeta.device_state   # unlocked
```

`fastboot getvar` is useless on this device (returns empty for everything), so don't look
there for confirmation.

## Afterwards

VAB device, slot `b`, no `recovery` partition:

```sh
fastboot flash boot_b magisk_patched.img
```

Brick a boot image and you're back in BROM, which still works. Partition map:
[docs/partition-table.md](docs/partition-table.md).

**Re-locking:** possible (zero the `miscdata` token over BROM) but pointless for security —
the BootROM bug is permanent, anyone can re-unlock with these same steps.

Credit: [CVE-2022-38694](https://research.nccgroup.com/2022/09/02/theres-another-hole-in-your-soc-unisoc-rom-vulnerabilities/)
is NCC Group's. Tooling is [TomKing062's](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader).
Scripts here are MIT. It wipes your phone; that's on you.
