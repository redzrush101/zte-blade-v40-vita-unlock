# What actually happened (the honest version)

I'm keeping this because the useful part of a job like this isn't the sequence that works, it's
the sequence of things that *looked* like they worked. Timestamps are local (CEST), 15-16
September 2026, on a ZTE Blade V40 Vita (`EEA_P606F02`).

## Timeline

**22:05** — grabbed the stock ROM and both unlock packages (eMMC + UFS).

**22:34** — built the tools from the CVE repo (`spd_dump`, `chsize`, `gen_spl-unlock`),
confirmed the phone is **UFS** (`Storage is ufs`) and that it uses slot **`_b`**.

**22:38** — pulled the device's own SPL out of the stock PAC and ran `gen_spl-unlock` on it.
It printed `0xfea8` and produced a 65192-byte `spl-unlock.bin`... which turned out to be
**byte-identical to the stock SPL**. It found no signcheck pattern. At the time that looked
like a problem; it wasn't. The unlock doesn't depend on a patched SPL on this phone.

**22:48** — wrote `unlock.sh`, a Linux port of the vendor's `unlock_autopatch_9230.bat`.

**22:53** — step 1: read `splloader` (256 KB) and `uboot_b` (3 MB), erased `splloader` and
`splloader_bak`. This only worked once the phone was held in BROM correctly — a couple of
earlier attempts caught nothing at all.

**22:57** — step 3: wrote `fdl2-cboot.bin` over `uboot_b`. The phone is now unable to boot
Android, by design.

**22:57** — step 4: sent `spl-unlock.bin`. It ended `usb_recv failed : LIBUSB_ERROR_TIMEOUT`
→ `CHECK_BAUD FAIL` → `connection closed`. Ugly, and completely normal.

**22:59** — step 5: read back `miscdata` at offset 8192. 64 bytes: `f9 ad c9 fe 60 5a bb 51…`
— a 32-byte string plus two 16-byte hashes. **Unlocked.**

**23:00** — step 6: put the stock `uboot_bak.bin` back into `uboot_b`, the SPL back into
`splloader`, wrote `misc-wipe.bin` into `misc`. Textbook.

**23:00 → 23:16** — and then the phone hung on the MyOS logo forever. Boots past an orange
"unlock / skip version" notice, gets to the animation, never finishes. No adb, no recovery.

The next two hours were spent on the wrong theory: that writing a wipe BCB into `misc` would
kick the phone into recovery. I did it at 23:00 and again at 23:16, verifying both writes by
reading the partition back and comparing md5s. It changed nothing. The bootloader on this
device ignores the BCB. That's the single most expensive assumption in this whole job.

**05:27 → 05:38** — the session got compacted and then died outright (the `pkill -f` incident
below almost certainly did it).

**07:26 → 07:38** — fresh session, new approach: stop trusting the BCB, erase `userdata` and
`metadata` directly over BROM. First attempts failed at

```
SEND fdl2-dl.bin to 0x9efffe00
connection closed
```

...every single time, at exactly the same byte.

**07:39 → 07:49** — worked out why: the phone was being held with **POWER + VOL_UP +
VOL_DOWN**. Holding POWER for ~10 seconds makes the PMIC hard-reset the phone, which kills the
USB link in the middle of the FDL2 upload. Two keys, not three.

**07:49** — re-armed the retry loop, held only **VOL_UP + VOL_DOWN**.

**07:51** — attempt 3 got all the way through:

```
Erase Part Done: metadata
Write Part Done: misc, target: 0x800, written: 0x800
Read Part Done: misc+0x0, target: 0x800, read: 0x800
########## SUCCESS: userdata+metadata erased, misc BCB verified ##########
```

**07:52** — the phone booted into Android, setup wizard ran, 110 GB of fresh `/data`.

**07:53** — confirmed from adb:

```
ro.boot.flash.locked        = 0
ro.boot.verifiedbootstate   = orange
ro.boot.vbmeta.device_state = unlocked
```

Done. Unlocked, booting, permanently (the token is in `miscdata`, which survives wipes).

## The three things that ate the most time

**1. Trusting the `misc` BCB.** Every generic "wipe Android over BROM" guide says to write
`boot-recovery` + `recovery\n--wipe_data\n` into `misc` and reboot. The ZTE bootloader on this
device ignores it. Writing it, verifying it, and then watching the phone hang identically is a
genuinely demoralising loop. The real fix is erasing `userdata` and `metadata` yourself.

**2. Holding POWER.** The symptom — `connection closed` at `SEND fdl2-dl.bin` — looks like a
software problem, a driver problem, or a flaky tool. It's a physical hard reset caused by the
key you're holding. It cost two failed attempts and, before that, several rounds of blaming the
cable. Only the volume keys.

**3. Confusing "unlocked" with "bootable".** The unlock itself worked at 22:59, an hour into
the job. Everything after that was the FBE hang. Knowing that the token was already written
would have saved most of the night — so: read `miscdata` and *confirm*, before chasing any
boot symptom.

Honourable mentions: assuming `fastboot getvar` would tell me anything (it returns empty on
this gadget), and reading the benign `CHECK_BAUD FAIL` / `FDL2: incompatible partition`
chatter as errors.

## The `pkill -f` incident

Somewhere around 07:26 a command ran

```sh
sudo pkill -f 'spd_dump --wait'
```

The shell running that command has `spd_dump --wait` in its own command line, so `pkill -f`
matched it and killed it. No output, exit 1, in the logs it just looks like the command
"vanished". That same self-match is the most likely reason the previous terminal session died
outright rather than erroring cleanly.

Use `pkill -x spd_dump` (name match, no `-f`) or `pkill -f 'spd_dum[p] --wait'`. Never an
unbracketed literal in `-f`.

## Evidence

These are in the working directory next to the tools, not in this repo (they're device-specific
and mostly binaries):

| file | what it shows |
|---|---|
| `phase1.log` … `phase6.log` | the six-step unlock, each step's real output |
| `m.bin` | the 64-byte `miscdata` read = the unlock proof |
| `fix.log` | the last attempt to fix the hang via the `misc` BCB (it didn't) |
| `brom_catch.log` | the failed catches, all dying at `SEND fdl2-dl.bin` |
| `catch.log` | the run that finally worked, with the `SUCCESS` line at 07:51:26 |
| `misc_check.bin` | read-back of `misc`, md5 == `misc-wipe.bin` |
| `pgpt.bin`, `partition_1789506957.xml` | the GPT and the 67-partition map |

If you're doing this on another unit, keep your own copies of these. When something goes wrong
later, the first question is always "what did we actually write, and to what offset", and the
answer is only in these files.