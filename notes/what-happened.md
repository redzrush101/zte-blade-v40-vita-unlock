# What happened

- **22:05** pulled the stock ROM and both unlock packages
- **22:34** built the tools, confirmed UFS + slot `_b`
- **22:53** steps 1-3: backed up SPL + `uboot_b`, erased the SPL, wrote `fdl2-cboot.bin` to `uboot_b`
- **22:57** step 4 ended in `connection closed` — looked broken, wasn't
- **22:59** step 5: `miscdata` held the token → **already unlocked**
- **23:00** step 6: restored stock uboot/SPL, wrote the wipe BCB
- **23:00-23:16** phone hung on the MyOS logo. Wrote the BCB twice, verified by read-back, zero
effect — this bootloader ignores it
- **07:26-07:38** next morning: switched to erasing `userdata` + `metadata` over BROM. Every
attempt died at `SEND fdl2-dl.bin`
- **07:49** found it: POWER + both volume keys were being held. POWER → hard reset. Two keys only
- **07:51** third catch went through: `e userdata e metadata w misc misc-wipe.bin` → `SUCCESS`
- **07:52** booting, 110 GB fresh `/data`, `flash.locked=0`, `verifiedbootstate=orange`

So: the unlock was done an hour before I stopped believing it was, the BCB was a dead end, and
the only real bug was a button.

Evidence stays in the working directory, not here: `phase1..6.log`, `m.bin` (the token),
`fix.log`, `brom_catch.log`, `catch.log` (the one that worked), `pgpt.bin`.
