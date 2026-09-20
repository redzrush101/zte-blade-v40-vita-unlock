# Windows stock flash and Magisk root

Tested on ZTE 8045 / P606F02, UMS9230 with UFS, using the B06 AS PAC and Magisk 30.7.

## Stock recovery

ResearchDownload R27.23.2902_P1 reliably flashes and performs the final **Reset to Normal**.
Load the PAC and keep its default file selection. Do not use **Select All Files**: that also
selects `EraseSPL`. The PAC's default NV-backup flow preserved IMEI and calibration in testing.

If only `boot_a` is bad and everything else is known stock, the minimal recovery selection is
`FDL1`, `FDL2`, and `BOOT`. Use the full PAC defaults after changes to other boot-chain or
`miscdata` partitions.

## Why a plain Magisk image boot-looped

Magisk patched the ramdisk correctly, but retained B06's signed AVB footer. Its hash descriptor
still described the stock payload, so the patched image failed AVB's internal hash check.

| Image | Payload bytes | Descriptor bytes | AVB verify |
|---|---:|---:|---|
| B06 stock | 36,052,992 | 36,052,992 | pass |
| Magisk output | 36,345,856 | 36,052,992 | fail |
| Re-signed Magisk | 36,345,856 | 36,345,856 | pass |
| Previous working B16 root | 36,343,808 | 36,343,808 | pass |

The old working image and the successful B06 image both use non-ZTE signing keys. An unlocked
bootloader accepts that, but the footer and payload must still agree.

Create the fixed image with:

```powershell
.\scripts\sign-magisk-boot.ps1 `
  -InputImage .\magisk_patched.img `
  -OutputImage .\magisk_patched-signed.img `
  -AvbTool C:\path\to\avbtool.py `
  -Key C:\path\to\rsa4096.pem
```

Then flash the active slot through native fastboot:

```powershell
adb reboot bootloader
fastboot flash boot_a .\magisk_patched-signed.img
fastboot reboot
```

Replace `boot_a` if `ro.boot.slot_suffix` reports `_b`. Tested result: Android booted,
`magiskd` ran, Magisk reported `30.7:MAGISK:R`, and `su -c id` returned `uid=0(root)`.

Tested SHA-256 values:

- B06 PAC: `367E15651E5339016283E546DB036E6237334A1B580E47804FA9CB6EBA9B4B51`
- B06 stock boot: `14CF587819F4A36D7D174AB3C25C5298EEDABA7C1A2DE83CECE182D4357E3F23`
- Re-signed B06 Magisk boot: `2EA3854D8B09836EB98372039DE8D71F1CDB9497A7BA8F186DF3E8B463AD87D6`

Do not relock while any partition is modified or signed with a non-stock key.

## SPD/SFD status

The UFS loaders and addresses are correct:

- FDL1: `0x65000800`
- FDL2: `0x9efffe00`
- Device mode: `1782:4d00`

SFD Tool 3.1.3 reached FDL2, read the correct 67-partition UFS table, and reported successful
64 MiB `boot_a` writes. `FDL2: incompatible partition` is noise if partition enumeration
continues.

Two exit-path problems are confirmed:

- `firstmode 0` writes `00 4d 46 53` at `miscdata+0x2420`; it does not clear the field. Do not
  use it as a normal-boot reset.
- SFD `reset` and `poweroff` receive an ACK but the phone returns as `1782:4d00` while
  ResearchDownload's **Reset to Normal** exits correctly.

The next controlled test is to write the verified signed image, read `boot_a` back in the same
FDL2 session, and compare SHA-256 before resetting. Omit `firstmode`. A matching read-back means
SPD writing works and only its reset path is broken; a mismatch isolates the UFS write path.
