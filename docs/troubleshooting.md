# Troubleshooting

**`SEND fdl2-dl.bin` → `connection closed`** — the phone reset itself mid-upload. You're
holding POWER. Hold only VOL_UP + VOL_DOWN. Other causes, in order: bad cable/port, flat
battery, you let go of a key.

**Hangs on the MyOS logo** — FBE, not a brick. Run `scripts/fix-post-unlock-hang.sh`. The
orange "unlock / skip version" message on the way past is normal.

**The `misc` BCB wipe does nothing** — correct, this bootloader ignores it. I wrote it twice
and verified both writes by reading `misc` back. Don't retry it, go straight to erasing
`userdata` + `metadata`.

**No `1782:4d00`** — hold VOL_UP + VOL_DOWN, tap POWER once, keep holding. `19d2:135x` is
normal USB. `1782:d001` shows up for a couple of seconds before BROM. Watch with
`scripts/watch-usb.sh` or `sudo dmesg -w`.

**Noise that is not an error** — all of these appear in successful runs:
`usb_recv failed : LIBUSB_ERROR_TIMEOUT`, `CHECK_BAUD FAIL`, `FDL2: incompatible partition`,
`DISABLE_TRANSCODE`. If it reaches `Reading Partition List`, it's fine.

**Step 4 looks broken** — `EXEC FDL1` → timeout → `connection closed` *is* the unlock. The
phone reboots itself out of the exploit. Confirm with step 5.

**`gen_spl-unlock` changed nothing** — expected. There's no signcheck pattern in this UFS SPL,
so its output is byte-identical to stock. The unlock goes via the BootROM
`custom_exec_no_verify_65015f08.bin` bypass instead.

**`pkill -f` killed my own shell** — the pattern matched the shell running it. Use
`pkill -x spd_dump`, or `pkill -f 'spd_dum[p] --wait'`. Never an `-f` literal that appears in
your own command line.

**Wrong loaders** — eMMC loaders on a UFS phone can wipe it. UFS `fdl2-*.bin` are 934088
bytes; `spd_dump` also prints `Storage is ufs` when it connects.
