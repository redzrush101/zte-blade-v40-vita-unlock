# Unlocking the ZTE Blade V40 Vita (P606F02) bootloader on Linux

This is a writeup of how I unlocked the bootloader on my **ZTE Blade V40 Vita** — a
Unisoc **UMS9230** phone with **UFS** storage — from Linux, without Windows and without
pulling the phone apart. It uses the public **CVE-2022-38694** BootROM exploit through
[TomKing062's unlock toolkit](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader).

I'm writing it down because the information out there is either a Windows `.bat` file or
fragments of forum posts, and the two things that actually decide whether it works are
buried and undocumented. Those two things cost me an entire night:

1. **Never hold POWER while you're flashing.** Holding it for ~10 seconds makes the PMIC
   hard-reset the phone, which yanks the USB link out from under the transfer. You'll see
   `SEND fdl2-dl.bin to 0x9efffe00` followed by `connection closed`, over and over.
2. **After unlocking, the phone hangs forever on the MyOS logo — and writing the standard
   `misc` BCB does not fix it on this device.** The ZTE bootloader ignores it. You have to
   erase `userdata` and `metadata` directly over BROM. That's step 6 below.

Everything here is verified on real hardware — the phone is unlocked and booting right now.

---

## The device

| | |
|---|---|
| Model | ZTE Blade V40 Vita / `ZTE 8045` |
| Variant | `EEA_P606F02` (EU), codename `P606F02` |
| SoC | Unisoc **UMS9230** (Tiger T606/T616 family) |
| Storage | **UFS** — *not* eMMC, this matters, see below |
| Build it was unlocked on | `ZTE/EEA_P606F02/P606F02:11/RP1A.201005.001/20240603.113112:user/release-keys` |
| OS | Android 11 (SDK 30), MyOS11.0.13_8045_EEA, security patch 2024-06-05 |
| Active slot when unlocked | **`_b`** |
| Encryption | FBE (file-based) — this is what causes the post-unlock hang |

### eMMC vs UFS: pick the right package

The unlock toolkit ships in two flavours and **the loaders are not interchangeable**. The
SupportList wiki literally warns *"UMS9230 UFS devices: Don't use fdl1/2 of UMS9230 EMMC
devices."* Using the eMMC loaders on a UFS phone can erase it.

You don't have to guess which one you have — `spd_dump` tells you outright once it connects:

```
Storage is ufs
```

For this phone, use **`ums9230_universal_unlock_UFS`**. As a sanity check, in the UFS
package `fdl2-dl.bin` and `fdl2-cboot.bin` are both **934088 bytes**; the eMMC ones are
`1062104` / `1047272`. If your files are the bigger ones, you grabbed the wrong zip.

---

## What you need

* A Linux box (I did this on NixOS; Ubuntu/Debian works the same). `libusb-1.0` and `gcc`
  are the only real dependencies.
* `adb` and `fastboot` from the Android platform tools.
* The phone's USB cable. **Use a good one and a port on the back of the machine** — BROM
  uploads are sensitive to flaky cables, and a bad one behaves exactly like the POWER-key
  problem.
* The [CVE-2022-38694_unlock_bootloader](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader)
  repo, plus the **`ums9230_universal_unlock_UFS`** package from its Releases page.
* `sudo` (libusb needs raw USB access).
* Ideally the stock ROM for your exact variant. I had
  `ZTE_Blade_V40_Vita_8045_UMS9230_..._P606F02_AS_GEN_20220720_ID_SPD.zip` and pulled the
  SPL out of the PAC with `misc/efitable2xml.c`. It's a nice safety net rather than a
  requirement, because the scripts here back up what's on the phone before touching it.

Build the tools from the CVE repo:

```sh
git clone https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader.git
cd CVE-2022-38694_unlock_bootloader
gcc chsize.c -o chsize
gcc gen_spl-unlock.c -o gen_spl-unlock
gcc gen_spl-unlock-legacy.c -o gen_spl-unlock-legacy
cd spreadtrum_flash && make          # builds spd_dump
```

If `make` fails on NixOS you're missing `libusb1` in your dev shell. Put `chsize`,
`gen_spl-unlock`, `gen_spl-unlock-legacy` and `spd_dump` next to the UFS package files and
you have a working directory.

A note on `gen_spl-unlock`: on my UFS SPL it found **zero** signcheck patterns and its output
was byte-identical to the stock SPL. That's fine — on this phone the unlock goes through the
BootROM's `custom_exec_no_verify_65015f08.bin` path, not through a patched SPL. Don't panic
if yours looks like it "did nothing"; just confirm it exits 0.

---

## Getting into BROM (1782:4d00)

This is BROM download mode — the BootROM's own USB diag, VID:PID **`1782:4d00`**. It's what
the exploit needs, and it is *not* the same thing as fastboot or the U-Boot "dloader" mode.

**The procedure:**

1. Phone powered **off**.
2. Hold **VOL_UP + VOL_DOWN**.
3. Plug the USB cable in while still holding.
4. **Keep both volume keys held** for the whole operation.

**Do not hold POWER.** If the phone needs a reset to get there, *tap* POWER once — a quick
press and release — with the volume keys already held. Ten seconds of held POWER = hard
reset = dead USB link mid-upload:

```
SEND fdl2-dl.bin to 0x9efffe00
connection closed          <-- that's this, every time
```

Also worth knowing: this phone can end up in a **software boot loop** where it never fully
powers down. That's actually fine, and even convenient — every reset re-runs the BootROM,
and the BootROM samples the keys *at reset*. So holding the volume keys continuously through
a reboot cycle lands you in BROM reliably, and you don't need a clean power-off at all.

You can watch for it with `./scripts/watch-usb.sh`, or by hand:

```sh
for d in /sys/bus/usb/devices/*/; do
  [ "$(cat $d/idVendor 2>/dev/null)" = 1782 ] && echo "BROM at $(basename $d) $(cat $d/idProduct)"
done
```

---

## The unlock

The vendor ships this as `unlock_autopatch_9230.bat`. [`scripts/unlock.sh`](scripts/unlock.sh)
is a straight Linux port of it — same commands, same order, same addresses. Run it step by
step. **Re-enter BROM before every step**, and keep the volume keys held while each one runs.

```sh
cd /path/to/working-dir        # holds spd_dump + the ums9230 UFS package files
sudo /path/to/repo/scripts/unlock.sh 1     # back up SPL + uboot, then erase SPL
sudo /path/to/repo/scripts/unlock.sh 2     # prepare the SPL image locally (no phone)
sudo /path/to/repo/scripts/unlock.sh 3     # write the unlock payload into uboot_b
sudo /path/to/repo/scripts/unlock.sh 4     # run the unlock (the actual exploit)
sudo /path/to/repo/scripts/unlock.sh 5     # read miscdata back and check the token
sudo /path/to/repo/scripts/unlock.sh 6     # restore uboot/SPL, write the wipe BCB
```

What each one does, and what "working" looks like:

**Step 1** reads `splloader` (256 KB) and `uboot_b` (3 MB) into `splloader.bin` and
`uboot.bin`, then erases `splloader` and `splloader_bak`. This is your backup — keep them.
The device is now deliberately unbootable, so it falls into SPL fallback download, which is
exactly what step 4 needs. Seeing `usb_recv failed : LIBUSB_ERROR_TIMEOUT` and
`CHECK_BAUD FAIL` in the middle is normal; the tool retries and carries on.

**Step 2** runs `gen_spl-unlock` on the backup and `chsize` on `uboot.bin`, then renames them
to `u-boot-spl-16k-sign.bin` and `uboot_bak.bin`, ready for the restore in step 6.

**Step 3** writes `fdl2-cboot.bin` over `uboot_b`. **This is not a bootable bootloader** —
it's the patched download agent that performs the unlock. The phone cannot boot Android while
this is in place, which is exactly why step 6 exists.

**Step 4** sends `spl-unlock.bin` as stage 1 in fallback download, and this is where the
unlock happens. Mine ended like this, and it *worked*:

```
SEND spl-unlock.bin to 0x65000800
SEND custom_exec_no_verify_65015f08.bin to 0x65015f08
EXEC FDL1
usb_recv failed : LIBUSB_ERROR_TIMEOUT
CHECK_BAUD FAIL
connection closed
```

That looks like a failure and it isn't — it's the phone rebooting itself out of the exploit.
The wiki warns it "may need twice", so if step 5 shows zeros, just run step 4 again.

**Step 5** is the moment of truth. It reads 64 bytes of `miscdata` at offset 8192:

* all zeros → still locked, run step 4 again
* **32-byte string + 16-byte hash + 16-byte hash → UNLOCKED**

Mine came out like this, saved as `m.bin`:

```
000000 f9 ad c9 fe 60 5a bb 51 b0 52 98 c9 2e 40 ee dc
000010 55 4d 79 d9 19 56 88 3d 59 29 47 0f 26 01 2e 00
000020 a3 23 38 5b 45 06 9f d7 11 e1 ac 1c b6 3e b8 c5
```

The token lives in `miscdata`, which is a normal partition — it survives data wipes and OS
reinstalls. That's why the unlock is permanent.

**Step 6** puts your stock `uboot_bak.bin` back into `uboot_b` and `u-boot-spl-16k-sign.bin`
into `splloader`, then writes `misc-wipe.bin` into `misc`. **Do not skip this.** Leaving
`fdl2-cboot.bin` in `uboot_b` is how you end up with a phone that can't boot at all.

---

## Trap #2: the boot hang, and the fix that actually works

After step 6 the phone boots, shows an orange "unlock / skip version" message, reaches the
MyOS boot animation — and then sits there. Forever. No adb, no recovery, nothing.

**Why:** the file-based-encryption keys live in the TEE (trustos) and are sealed to the
phone's *lock state*. Unlocking changed that state, so the old keys can never be derived
again, so `/data` can never be mounted, so Android spins on that animation until the heat
death of the universe.

**The standard answer does not work here.** Normally you write an Android BCB into `misc`
(`boot-recovery` + `recovery\n--wipe_data\n`) and let recovery wipe `/data`. On this ZTE
bootloader the BCB is simply **ignored** — I wrote it twice, verified both writes by reading
`misc` back, and the phone still hung exactly the same way. If you're stuck at the logo, this
is almost certainly why, and no amount of re-writing the BCB will help.

**What works:** erase `userdata` and `metadata` over BROM directly.

```sh
cd /path/to/working-dir        # same directory as above
sudo /path/to/repo/scripts/fix-post-unlock-hang.sh
```

It arms `spd_dump` with a 900-second window and loops, so a dropped catch doesn't cost you a
cycle. Hold the two volume keys and keep holding; when BROM shows up it runs:

```sh
sudo ./spd_dump --wait 900 exec_addr 0x65015f08 \
    fdl fdl1-dl.bin 0x65000800 fdl fdl2-dl.bin 0x9efffe00 exec \
    e userdata e metadata \
    w misc misc-wipe.bin \
    read_part misc 0 2048 misc_check.bin \
    reset
```

That's the whole fix: erase `metadata` (16 MB — where the FBE key blobs live), erase
`userdata` (112 GB), drop the wipe BCB in for good measure, reboot. Mine caught on the third
attempt and finished inside a minute:

```
Write Part Done: misc, target: 0x800, written: 0x800
Erase Part Done: persist
Erase Part Done: metadata
Write Part Done: misc, target: 0x800, written: 0x800
Read Part Done: misc+0x0, target: 0x800, read: 0x800
########## SUCCESS: userdata+metadata erased, misc BCB verified ##########
```

The phone booted straight into Android after that, with a fresh 110 GB `/data`.

`read_part` is in there on purpose: it reads `misc` back and `cmp`s it against what was
written, so "SUCCESS" means the write actually landed on the device rather than just that the
command didn't error out. Cheap insurance against a flaky USB link lying to you.

One footgun if you write your own version of that script: don't `pkill -f` on a pattern that
also appears in your own command line. `pkill` matches the shell running it and kills your
own session. `pkill -x spd_dump` (process-name match, no `-f`) is safe.

---

## Verifying the unlock

```sh
./scripts/verify-unlock.sh
```

which is just:

```sh
adb shell getprop ro.boot.flash.locked          # 0        = UNLOCKED
adb shell getprop ro.boot.verifiedbootstate     # orange   = unlocked boot state
adb shell getprop ro.boot.vbmeta.device_state   # unlocked
adb shell getprop ro.boot.slot_suffix           # _b  (this phone runs on slot b)
```

On my phone those come out as `0` / `orange` / `unlocked` / `_b`. These are the bootloader
reporting its own state through the kernel command line, so they're authoritative — not a
guess based on a screen message.

`fastboot getvar` is useless here, by the way. The Unisoc U-Boot fastboot gadget is minimal
and returns empty values even for `getvar unlocked`. Don't go looking for confirmation there.

---

## Flashing things afterwards

This is a **VAB** (virtual A/B) device, and the recovery you'd expect doesn't exist as its
own partition — there's no `recovery` partition in the map, it's the boot ramdisk. It's also
sitting on **slot b** when you finish unlocking, so mind your suffixes:

```sh
adb reboot bootloader
fastboot devices
fastboot flash boot_b magisk_patched_boot.img      # note the _b
```

The full 67-partition map as read off my device is in
[`docs/partition-table.md`](docs/partition-table.md), so you can see what you're working with
before flashing anything.

---

## Things I wish I'd known before starting

* **Back up `/data` first.** Several steps wipe it, and the post-unlock fix definitely does.
  There is no way around it — FBE keys and a lock-state change don't mix.
* **Step 1 erases your SPL on purpose.** The phone is unbootable from the end of step 1 until
  step 6 finishes. Don't start this if you have somewhere to be.
* **Keep your working directory.** `splloader.bin`, `uboot_bak.bin`, `misc-wipe.bin` and
  `fdl2-*.bin` are the difference between a recoverable phone and a paperweight. The step 1
  backups are unique to *your* device's firmware revision.
* **Don't use the eMMC loaders on a UFS phone.**
* **Don't hold POWER.**
* **Don't expect the `misc` BCB to save you** — go straight to erasing `userdata`/`metadata`.
* **The battery matters.** A boot-looping phone on a nearly flat battery adds a failure mode
  that looks *identical* to the POWER-key problem: the link dies during the FDL2 upload. If
  you keep failing at the same byte, charge the phone first and try a different cable/port.
* **`1782:4d00` is BROM.** If `lsusb` shows `19d2:135x`, that's the phone's normal
  bootloader/Android USB, not the mode the exploit needs.

More detail — including a blow-by-blow of the session where I got all of this wrong — is in
[`docs/troubleshooting.md`](docs/troubleshooting.md) and
[`notes/what-happened.md`](notes/what-happened.md).

---

## Credits

The exploit is **CVE-2022-38694**, found and documented by NCC Group:
[There's another hole in your SoC: Unisoc ROM vulnerabilities](https://research.nccgroup.com/2022/09/02/theres-another-hole-in-your-soc-unisoc-rom-vulnerabilities/).

The tooling is [TomKing062/CVE-2022-38694_unlock_bootloader](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader).
All credit for the hard part goes there — this repo is only the device-specific notes and the
Linux wrappers I needed to get through it.

The scripts here are MIT (see [`LICENSE`](LICENSE)). They're a thin wrapper around that work,
not a replacement for it.

## Disclaimer

This erases your phone and can brick it. It worked on my `EEA_P606F02` UMS9230 UFS unit
running `MyOS11.0.13_8045_EEA`. Other variants, other firmware revisions and other `ums9230`
phones may need different files or a different key combination. Unlocking a bootloader has
real consequences — no Play Integrity, no banking apps, some DRM at reduced quality, and it's
visible to anyone who looks. It's your phone; know what you're doing.