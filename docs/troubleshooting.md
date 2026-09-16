# Troubleshooting

Every one of these is something I actually hit. Symptoms first, then the cause.

---

## `SEND fdl2-dl.bin to 0x9efffe00` then `connection closed`

**This is the number one time-waster.**

```
SEND fdl1-dl.bin to 0x65000800
SEND custom_exec_no_verify_65015f08.bin to 0x65015f08
EXEC FDL1
usb_recv failed : LIBUSB_ERROR_TIMEOUT
CHECK_BAUD FAIL
CHECK_BAUD FDL1
BSL_REP_VER: "Spreadtrum Boot Block version 1.1\0"
CMD_CONNECT FDL1
KEEP_CHARGE FDL1
SEND fdl2-dl.bin to 0x9efffe00
connection closed                         <-- here
```

`connection closed` means the phone **physically left the USB bus**, not that the transfer was
too slow. FDL1 is small (~60 KB, goes through fine), FDL2 is ~912 KB, and the phone dies
partway through it. In order of likelihood:

1. **You're holding POWER.** Holding it ~10 s triggers a PMIC hard reset. This is the cause
   95% of the time. Hold only **VOL_UP + VOL_DOWN**. If you need to reset the phone into BROM,
   *tap* POWER once.
2. **Cable or port.** A marginal cable behaves identically. Try another cable and a port
   straight off the motherboard, not a hub.
3. **Battery.** A phone that's been boot-looping all night can be nearly flat, and the FDL2
   upload is the highest-current moment in the whole procedure. Charge it first.
4. **You let go of a volume key.** Less likely, but it happens.

The fix for all of them is the same: keep the volume keys held and let the retry loop run.
`scripts/fix-post-unlock-hang.sh` re-arms automatically; it caught on the third attempt for me,
with no intervention.

---

## The phone hangs forever on the MyOS logo after unlocking

That's the FBE/trustos problem, and it's not a brick. See the README section
*"Trap #2: the boot hang"* — erase `userdata` + `metadata` over BROM. There's no way around
wiping; the old encryption keys simply cannot be derived in the unlocked state.

An orange **"unlock / skip version"** message on the way past is *normal* and expected. That's
the bootloader announcing it's unlocked. If you reach the animation, the boot chain is fine and
you're only fighting the encryption state.

---

## The `misc` BCB wipe does nothing

Correct — this ZTE bootloader ignores it. I wrote `misc-wipe.bin` twice, verified both writes
by reading `misc` back and comparing md5s, and the phone hung identically both times. Stop
trying that route and go straight to erasing `userdata` + `metadata`.

(The BCB write isn't harmful. It just isn't the fix here, contrary to every generic "wipe
Android from BROM" guide.)

---

## No `1782:4d00` on USB at all

```sh
for d in /sys/bus/usb/devices/*/; do
  [ "$(cat $d/idVendor 2>/dev/null)" = 1782 ] && echo "BROM at $(basename $d)"
done
```

* Nothing at all → the phone is booted into Android (reset it), or it's fully powered off.
  Hold VOL_UP + VOL_DOWN, tap POWER once, keep holding.
* **`19d2:1353`** → that's the phone's *normal* USB gadget, not BROM. You'll sometimes see it
  with a `usb-storage` / `File-Stor Gadget` interface and a 0-byte LUN. Harmless, but it's not
  the mode you need.
* **`1782:d001`** → seen for a couple of seconds while the SoC comes up. Keep holding, BROM
  follows.
* Watch it live with `scripts/watch-usb.sh` and `sudo dmesg -w` in another terminal. dmesg is
  the fastest way to see the exact re-enumeration timeline.

Remember that a boot-looping phone is *fine* for this: every reset re-runs the BootROM and the
BootROM samples the keys at reset, so holding the volume keys through the loop lands you in
BROM. You don't need a clean power-off, which is lucky, because these phones often won't give
you one.

---

## Things that look like errors but aren't

```
usb_recv failed : LIBUSB_ERROR_TIMEOUT
CHECK_BAUD FAIL
CHECK_BAUD FDL1
FDL2: incompatible partition
DISABLE_TRANSCODE
```

All of these show up in **successful** runs. `CHECK_BAUD FAIL` is the tool retrying the
handshake at a different baud; `FDL2: incompatible partition` is just a reply from the device
during the FDL2 handshake. If the run reaches `Reading Partition List`, you're fine.

And in step 4:

```
SEND spl-unlock.bin to 0x65000800
EXEC FDL1
usb_recv failed : LIBUSB_ERROR_TIMEOUT
CHECK_BAUD FAIL
connection closed
```

That's the **unlock succeeding**. The phone reboots itself out of the exploit and the link
dies with it. Confirm with step 5 — a miscdata token means it worked. The upstream wiki notes
it "may need twice"; if you get zeros, just run step 4 again.

---

## `gen_spl-unlock` made no changes to the SPL

Expected on this device. It found **zero** signcheck patterns in the UFS SPL, so its output was
byte-identical to stock. The unlock still works, because it goes through the BootROM's
`custom_exec_no_verify_65015f08.bin` bypass instead of a patched SPL. Don't chase this.

---

## `pkill -f` killed my own terminal

A real footgun, and it's what took out a whole session for me. If the pattern you pass to
`pkill -f` appears anywhere in the command line of the shell running it, it kills that shell
too — so a command like

```sh
sudo pkill -f 'spd_dump --wait'; ...
```

can kill itself mid-script, along with anything else in the same pkill-able tree. Use either:

```sh
sudo pkill -x spd_dump              # process-name match, no -f: cannot match a shell
```

or the bracket trick, which keeps the literal string out of your own command line:

```sh
sudo pkill -f 'spd_dum[p] --wait'
```

Never put an unbracketed literal in a `pkill -f` in the same command line.

---

## `fastboot getvar unlocked` returns nothing

Expected. The fastboot gadget on this phone is a minimal Unisoc U-Boot implementation; it
answers even `oem device-info` with "unknown cmd" and returns empty for every getvar. Use the
adb props instead (`scripts/verify-unlock.sh`).

---

## Wrong loaders = data loss

If you pulled `fdl1-dl.bin` / `fdl2-dl.bin` from the **eMMC** package for a **UFS** phone (or
the other way round), you can wipe the device by accident. The SupportList wiki warns about
exactly this. Check your files: on a `ums9230` UFS device `fdl2-dl.bin` and `fdl2-cboot.bin`
are both **934088** bytes; the eMMC ones are 1062104 / 1047272. And confirm the storage type
from the tool itself once it connects:

```
Storage is ufs
```

---

## adb says "no permissions" / the device only shows under `lsusb`

libusb and adb need raw USB access, and `spd_dump` wants root. Either run the scripts with
`sudo` (as documented) or install udev rules for `1782:4d00` and `19d2:135*`. Don't fight it —
`sudo` is simpler and this is a one-off job.